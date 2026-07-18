import '../../../core/controllers/cab_management_controller.dart';
import '../../../core/models/cab_assignment_member_model.dart';
import '../../../core/models/cab_assignment_model.dart';
import '../../../core/models/cab_trip_model.dart';
import '../../../core/models/cab_vehicle_model.dart';
import '../../../core/models/live_location_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/live_location_service.dart';
import '../../../core/services/location_session_service.dart';
import '../../../core/services/location_tracking_policy.dart';
import '../../../core/services/cab_assignment_service.dart';
import '../../../core/services/cab_trip_service.dart';
import '../../auth/services/auth_service.dart';
import '../../attendance/services/attendance_service.dart';
import '../../customer_visits/controllers/customer_visit_controller.dart';
import '../../customer_visits/models/customer_visit_model.dart';
import '../../customer_visits/services/customer_visit_service.dart';
import '../../manager/controllers/manager_controller.dart';
import '../../manager/models/manager_employee_summary_model.dart';

/// Loads data for mode-specific overlays on the single Map screen.
class MapModesController {
  MapModesController._();

  /// Returns a stable local-date key in `yyyy-MM-dd` format.
  static String dateKeyFromDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Realtime signals shared by the currently active operations mode.
  static List<Stream<void>> operationalChangeStreams() {
    final dateKey = dateKeyFromDate(DateTime.now());
    return <Stream<void>>[
      AttendanceService.watchAttendanceChanges(),
      CustomerVisitService.watchVisitChanges(),
      LiveLocationService.watchLiveLocationChanges(),
      CabAssignmentService.watchAssignmentsForDate(dateKey),
      CabAssignmentService.watchMembersForDate(dateKey),
      CabTripService.watchTripsForDate(dateKey),
      LocationSessionService.watchSessionChanges(),
    ];
  }

  /// Realtime change signals used by Cab Tracking.
  static List<Stream<void>> cabChangeStreams() => operationalChangeStreams();

  /// Realtime change signals used by Team Tracking.
  static List<Stream<void>> teamChangeStreams() => operationalChangeStreams();

  /// Realtime change signals used by Customer Locations.
  static List<Stream<void>> customerChangeStreams() =>
      operationalChangeStreams();

  /// Realtime change signals used by the Office View summary.
  static List<Stream<void>> officeChangeStreams() => operationalChangeStreams();

  /// Realtime change signals used by the Field Engineer dashboard.
  static List<Stream<void>> fieldEngineerChangeStreams() => teamChangeStreams();

  /// Loads Cab Tracking context for the current signed-in user.
  static Future<CabMapContext> loadCabContext() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) {
      throw StateError('Cab Tracking requires a signed-in user.');
    }

    final currentUser = await FirestoreService.getUser(uid);
    if (currentUser == null) {
      throw StateError('Current user profile not found.');
    }

    final dateKey = dateKeyFromDate(DateTime.now());
    final member = await CabManagementController.loadTodayMemberAssignment(
      userId: uid,
      dateKey: dateKey,
    );
    final driverAssignment =
        await CabManagementController.loadTodayAssignmentForDriver(
          driverId: uid,
          dateKey: dateKey,
        );

    final managerAssignments =
        await CabManagementController.loadAssignmentsForDate(dateKey: dateKey);
    final managerTrips = await CabManagementController.loadTripsForDate(
      dateKey: dateKey,
    );
    final managerMembers =
        await CabManagementController.loadAssignmentMembersForDate(
          dateKey: dateKey,
        );

    final assignment =
        driverAssignment ??
        (member == null
            ? (managerAssignments.isEmpty ? null : managerAssignments.first)
            : await CabManagementController.loadAssignment(
                member.assignmentId,
              ));

    final vehicle = assignment == null
        ? null
        : await CabManagementController.getVehicle(assignment.vehicleId);
    final members = assignment == null
        ? const <CabAssignmentMemberModel>[]
        : await CabManagementController.loadAssignmentMembers(
            assignmentId: assignment.id,
            dateKey: assignment.dateKey,
          );
    final activeTrip = assignment == null
        ? null
        : await CabManagementController.loadActiveTripForAssignment(
            assignmentId: assignment.id,
          );

    final userIds = <String>{
      currentUser.uid,
      if (assignment != null) assignment.driverId,
      for (final item in members) item.userId,
      for (final item in managerMembers) item.userId,
      for (final item in managerAssignments) item.driverId,
    }.where((item) => item.isNotEmpty).toList(growable: false);
    final users = await FirestoreService.fetchUsersByIds(userIds);
    final userMap = <String, UserModel>{
      for (final user in users) user.uid: user,
    };

    final locationIds = <String>{
      if (assignment != null) assignment.driverId,
      for (final item in managerAssignments) item.driverId,
      for (final item in members)
        if (item.status == 'ready') item.userId,
      for (final item in managerMembers)
        if (item.status == 'ready') item.userId,
    }.where((item) => item.isNotEmpty).toList(growable: false);
    final liveLocations = <String, LiveLocationModel>{};
    final locations = await Future.wait(
      locationIds.map(LiveLocationService.fetchLiveLocation),
    );
    for (var index = 0; index < locationIds.length; index++) {
      final location = locations[index];
      if (location != null) {
        liveLocations[locationIds[index]] = location;
      }
    }

    return CabMapContext(
      currentUser: currentUser,
      dateKey: dateKey,
      currentMember: member,
      assignment: assignment,
      vehicle: vehicle,
      members: members,
      usersById: userMap,
      liveLocationsByUserId: liveLocations,
      activeTrip: activeTrip,
      managerAssignments: managerAssignments,
      managerTrips: managerTrips,
      managerMembers: managerMembers,
    );
  }

  /// Loads live team tracking context for managers/admins.
  static Future<TeamMapContext> loadTeamContext() async {
    final summaries = await ManagerController.loadEmployeeSummaries();
    final liveLocations = <String, LiveLocationModel>{};

    final locations = await Future.wait(
      summaries.map(
        (summary) =>
            LiveLocationService.fetchLiveLocation(summary.employee.uid),
      ),
    );
    for (var index = 0; index < summaries.length; index++) {
      final location = locations[index];
      if (location != null) {
        liveLocations[summaries[index].employee.uid] = location;
      }
    }

    return TeamMapContext(
      summaries: summaries,
      liveLocationsByUserId: liveLocations,
    );
  }

  /// Loads customer visit location context.
  static Future<CustomerMapContext> loadCustomerContext() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) {
      throw StateError('Customer locations require a signed-in user.');
    }

    final profile = await FirestoreService.getUser(uid);
    final allVisits = _canManageCab(profile?.role ?? '')
        ? await CustomerVisitController.loadAllVisits()
        : await CustomerVisitController.loadMyVisits();
    final today = DateTime.now();
    final visits = allVisits
        .where((visit) {
          final date = visit.createdAt;
          return date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;
        })
        .toList(growable: false);

    return CustomerMapContext(visits: visits);
  }

  static bool _canManageCab(String role) {
    return role == 'manager' || role == 'admin' || role == 'ceo';
  }
}

/// Cab Tracking data projected for the Map screen.
class CabMapContext {
  /// Signed-in user profile from `users`.
  final UserModel currentUser;

  /// Current local date key.
  final String dateKey;

  /// Current user's assignment member lookup, when assigned as employee/driver.
  final CabAssignmentMemberModel? currentMember;

  /// Focused cab assignment for the current mode.
  final CabAssignmentModel? assignment;

  /// Vehicle linked to [assignment].
  final CabVehicleModel? vehicle;

  /// Members assigned to [assignment].
  final List<CabAssignmentMemberModel> members;

  /// User profiles keyed by uid.
  final Map<String, UserModel> usersById;

  /// Live locations keyed by uid.
  final Map<String, LiveLocationModel> liveLocationsByUserId;

  /// Active trip for [assignment].
  final CabTripModel? activeTrip;

  /// Manager-visible assignments for the current date.
  final List<CabAssignmentModel> managerAssignments;

  /// Manager-visible trips for the current date.
  final List<CabTripModel> managerTrips;

  /// Assignment members across all manager-visible assignments today.
  final List<CabAssignmentMemberModel> managerMembers;

  /// Creates cab map context.
  const CabMapContext({
    required this.currentUser,
    required this.dateKey,
    required this.currentMember,
    required this.assignment,
    required this.vehicle,
    required this.members,
    required this.usersById,
    required this.liveLocationsByUserId,
    required this.activeTrip,
    required this.managerAssignments,
    required this.managerTrips,
    required this.managerMembers,
  });

  /// True when current user is the assignment driver.
  bool get isDriver => assignment?.driverId == currentUser.uid;

  /// True when current user is an assigned employee.
  bool get isEmployee => currentMember?.role == 'employee';

  /// True when current user can manage cab assignments.
  bool get canManage {
    final role = currentUser.role.trim().toLowerCase();
    return const {
      'manager',
      'admin',
      'administrator',
      'application_owner',
      'owner',
      'ceo',
    }.contains(role);
  }

  /// True when current user can mutate cab operations.
  bool get canMutateManagement => canManage;

  /// Employees currently ready for pickup.
  List<CabAssignmentMemberModel> get readyMembers => members
      .where((member) => member.role == 'employee' && member.status == 'ready')
      .toList(growable: false);

  /// Employees marked picked up.
  List<CabAssignmentMemberModel> get pickedUpMembers => members
      .where(
        (member) => member.role == 'employee' && member.status == 'picked_up',
      )
      .toList(growable: false);

  /// Employees marked boarded.
  List<CabAssignmentMemberModel> get boardedMembers => members
      .where(
        (member) => member.role == 'employee' && member.status == 'boarded',
      )
      .toList(growable: false);

  /// Employees marked no-show.
  List<CabAssignmentMemberModel> get noShowMembers => members
      .where(
        (member) => member.role == 'employee' && member.status == 'no_show',
      )
      .toList(growable: false);

  /// Ready employees across all assignments visible in Admin mode.
  List<CabAssignmentMemberModel> get managerReadyMembers => managerMembers
      .where((member) => member.role == 'employee' && member.status == 'ready')
      .toList(growable: false);
}

/// Team Tracking data projected for the Map screen.
class TeamMapContext {
  /// Employee summaries from the Manager module.
  final List<ManagerEmployeeSummaryModel> summaries;

  /// Live locations keyed by employee uid.
  final Map<String, LiveLocationModel> liveLocationsByUserId;

  /// Creates team map context.
  const TeamMapContext({
    required this.summaries,
    required this.liveLocationsByUserId,
  });

  /// Active employees based on attendance-derived live status.
  List<ManagerEmployeeSummaryModel> get activeSummaries => summaries
      .where((summary) {
        final location = liveLocationsByUserId[summary.employee.uid];
        return location != null &&
            location.status == LocationTrackingPolicy.statusActive &&
            !LocationTrackingPolicy.isStale(location.updatedAt, DateTime.now());
      })
      .toList(growable: false);

  /// Employees currently checked in and not on break.
  int get onDutyCount =>
      summaries.where((summary) => summary.liveStatus == 'online').length;

  /// Employees currently on break.
  int get onBreakCount =>
      summaries.where((summary) => summary.liveStatus == 'break').length;

  /// Employees without an active duty session.
  int get offlineCount => summaries.length - onDutyCount - onBreakCount;

  /// Active customer visits across the team.
  int get currentVisitCount =>
      summaries.fold<int>(0, (total, summary) => total + summary.activeVisits);
}

/// Customer Location data projected for the Map screen.
class CustomerMapContext {
  /// Visit records reused from the Customer Visits module.
  final List<CustomerVisitModel> visits;

  /// Creates customer map context.
  const CustomerMapContext({required this.visits});

  /// Visits not completed yet.
  List<CustomerVisitModel> get pendingVisits => visits
      .where((visit) => visit.status != 'completed')
      .toList(growable: false);

  /// Completed visits.
  List<CustomerVisitModel> get completedVisits => visits
      .where((visit) => visit.status == 'completed')
      .toList(growable: false);
}
