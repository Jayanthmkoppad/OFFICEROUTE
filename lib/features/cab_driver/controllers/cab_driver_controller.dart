import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/controllers/cab_management_controller.dart';
import '../../../core/models/cab_assignment_member_model.dart';
import '../../../core/models/cab_assignment_model.dart';
import '../../../core/models/cab_driver_shift_model.dart';
import '../../../core/models/cab_trip_event_model.dart';
import '../../../core/models/cab_trip_model.dart';
import '../../../core/models/cab_trip_rider_model.dart';
import '../../../core/models/cab_vehicle_model.dart';
import '../../../core/models/live_location_model.dart';
import '../../../core/models/location_history_point_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/employee_model.dart';
import '../../../core/services/cab_assignment_service.dart';
import '../../../core/services/cab_driver_shift_service.dart';
import '../../../core/services/cab_trip_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/live_location_service.dart';
import '../../../core/services/location_history_service.dart';
import '../../../core/services/location_tracking_policy.dart';
import '../../attendance/controllers/attendance_controller.dart';
import '../../auth/services/auth_service.dart';
import '../../cab_tracking/controllers/cab_tracking_controller.dart';
import '../../map/controllers/location_controller.dart';
import '../../notifications/services/notification_service.dart';
import '../../attendance/services/attendance_service.dart';
import '../../../core/services/employee_service.dart';

class CabDriverOperations {
  final UserModel driver;
  final CabAssignmentModel? todayAssignment;
  final CabVehicleModel? vehicle;
  final CabDriverShiftModel? shift;
  final List<CabAssignmentModel> assignments;
  final List<CabTripModel> trips;
  final CabTripModel? activeTrip;
  final List<CabAssignmentMemberModel> members;
  final List<CabTripRiderModel> riders;
  final List<CabTripEventModel> events;
  final Map<String, UserModel> employees;
  final Map<String, LiveLocationModel> locations;
  final DateTime loadedAt;

  const CabDriverOperations({
    required this.driver,
    required this.todayAssignment,
    required this.vehicle,
    required this.shift,
    required this.assignments,
    required this.trips,
    required this.activeTrip,
    required this.members,
    required this.riders,
    required this.events,
    required this.employees,
    required this.locations,
    required this.loadedAt,
  });

  bool get dutyActive => shift?.shiftStatus == 'active';

  CabTripRiderModel? get activeRider {
    final pending =
        riders
            .where(
              (rider) =>
                  const {'assigned', 'ready', 'waiting'}.contains(rider.status),
            )
            .toList()
          ..sort((a, b) => a.pickupOrder.compareTo(b.pickupOrder));
    return pending.firstOrNull;
  }

  Duration get dutyDuration {
    final start = shift?.shiftStart;
    if (start == null) return Duration.zero;
    return (shift?.shiftEnd ?? DateTime.now()).difference(start);
  }

  double? get distanceToActiveRiderMeters {
    final rider = activeRider;
    final driverLocation = locations[driver.uid];
    final employeeLocation = rider == null ? null : locations[rider.employeeId];
    if (driverLocation == null || employeeLocation == null) return null;
    return LocationTrackingPolicy.distanceMeters(
      driverLocation.latitude,
      driverLocation.longitude,
      employeeLocation.latitude,
      employeeLocation.longitude,
    );
  }
}

class CabDriverController {
  CabDriverController._();

  static const arrivalThresholdMeters = 500.0;
  static StreamSubscription<LiveLocationModel>? _locationSubscription;

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String get _uid {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) throw StateError('Cab Driver requires a signed-in user.');
    return uid;
  }

  static Future<CabDriverOperations> load() async {
    final uid = _uid;
    final today = dateKey(DateTime.now());
    final driver = await FirestoreService.getUser(uid);
    if (driver == null) throw StateError('Driver profile was not found.');
    final assignments = await CabManagementController.loadAssignmentsForDriver(
      driverId: uid,
    );
    final trips = await CabManagementController.loadTripsForDriver(uid);
    final todayAssignment = assignments
        .where((assignment) => assignment.dateKey == today)
        .firstOrNull;
    final shift = await CabManagementController.loadTodayShiftForDriver(
      driverId: uid,
      dateKey: today,
    );
    final activeTrip = trips
        .where(
          (trip) =>
              trip.dateKey == today &&
              const {
                'created',
                'active',
                'office_arrived',
              }.contains(trip.status),
        )
        .firstOrNull;
    final vehicle = todayAssignment == null
        ? null
        : await CabManagementController.getVehicle(todayAssignment.vehicleId);
    final members = todayAssignment == null
        ? const <CabAssignmentMemberModel>[]
        : await CabManagementController.loadAssignmentMembers(
            assignmentId: todayAssignment.id,
            dateKey: todayAssignment.dateKey,
          );
    final riders = activeTrip == null
        ? const <CabTripRiderModel>[]
        : await CabManagementController.loadTripRiders(activeTrip.id);
    final events = activeTrip == null
        ? const <CabTripEventModel>[]
        : await CabManagementController.loadTripEvents(activeTrip.id);
    final employeeIds = members
        .where((member) => member.role == 'employee')
        .map((member) => member.userId)
        .toList();
    final users = await FirestoreService.fetchUsersByIds(employeeIds);
    final locations = <String, LiveLocationModel>{};
    for (final userId in <String>{uid, ...employeeIds}) {
      final location = await LiveLocationService.fetchLiveLocation(userId);
      if (location != null) locations[userId] = location;
    }
    return CabDriverOperations(
      driver: driver,
      todayAssignment: todayAssignment,
      vehicle: vehicle,
      shift: shift,
      assignments: assignments,
      trips: trips,
      activeTrip: activeTrip,
      members: members,
      riders: riders,
      events: events,
      employees: {for (final user in users) user.uid: user},
      locations: locations,
      loadedAt: DateTime.now(),
    );
  }

  static List<Stream<void>> realtimeStreams() {
    final uid = _uid;
    final today = dateKey(DateTime.now());
    return [
      FirestoreService.watchUser(uid),
      CabAssignmentService.watchDriverAssignment(driverId: uid, dateKey: today),
      CabTripService.watchTripsForDriver(uid),
      CabDriverShiftService.watchShiftsForDriver(uid),
      LiveLocationService.watchLiveLocationChanges(),
    ];
  }

  static Future<CabAssignmentModel> _ensureTodayAssignment(
    CabDriverOperations data,
  ) async {
    if (data.todayAssignment != null) return data.todayAssignment!;

    final now = DateTime.now();
    final assignment = CabAssignmentModel(
      dateKey: dateKey(now),
      assignmentDate: now,
      driverId: data.driver.uid,
      vehicleId: data.vehicle?.id ?? '',
      employeeIds: const <String>[],
      officeName: data.driver.branch.isNotEmpty ? data.driver.branch : 'Office',
      officeAddress: '',
      officeLatitude: null,
      officeLongitude: null,
      status: 'active',
      assignedBy: data.driver.uid,
      assignedAt: now,
      updatedAt: now,
    );

    final assignmentId = await CabManagementController.createAssignment(
      assignment,
    );
    final created = assignment.copyWith(id: assignmentId);
    await CabManagementController.upsertAssignmentMembers([
      CabAssignmentMemberModel(
        id: '${created.dateKey}_${data.driver.uid}',
        assignmentId: created.id,
        dateKey: created.dateKey,
        userId: data.driver.uid,
        role: 'driver',
        driverId: data.driver.uid,
        vehicleId: created.vehicleId,
        status: 'active',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    return created;
  }

  static Future<List<EmployeeModel>> _fetchEligiblePickupEmployees() async {
    final today = DateTime.now();
    final attendanceRecords = await AttendanceService.fetchAttendanceForDate(
      today,
    );
    final activeUserIds = attendanceRecords
        .where((record) => record.isCheckedIn)
        .map((record) => record.userId)
        .toSet();
    final employees = await EmployeeService.fetchAllEmployees();
    return employees
        .where((employee) => activeUserIds.contains(employee.uid))
        .toList();
  }

  static Future<void> startDuty(CabDriverOperations data) async {
    if (data.dutyActive) return;
    final permission = await LocationController.checkLocationPermission();
    if (!permission.canUseLocation) {
      final requested = await LocationController.requestLocationPermission();
      if (!requested.canUseLocation) {
        throw StateError('Location permission is required to start duty.');
      }
    }
    await AttendanceController.checkIn();
    final assignment = await _ensureTodayAssignment(data);
    await CabManagementController.createShift(
      CabDriverShiftModel(
        driverId: data.driver.uid,
        vehicleId: assignment.vehicleId,
        shiftDate: assignment.dateKey,
        shiftStart: DateTime.now(),
        shiftStatus: 'active',
      ),
    );
    var session = await LocationController.loadActiveLocationSession(
      data.driver.uid,
    );
    if (session == null) {
      session = await LocationController.startLocationSession(
        userId: data.driver.uid,
        trackingReason: LocationTrackingPolicy.reasonFieldDuty,
        metadata: {'assignmentId': assignment.id},
      );
    } else if (session.trackingReason !=
        LocationTrackingPolicy.reasonFieldDuty) {
      session = await LocationController.resumeLocationSession(session);
    }
    await _locationSubscription?.cancel();
    _locationSubscription =
        await LocationController.startForegroundLiveLocationUpdates(
          session: session,
        );
  }

  static Future<void> endDuty(CabDriverOperations data) async {
    final shift = data.shift;
    if (shift == null || !data.dutyActive) return;
    if (data.activeTrip != null) {
      throw StateError('Complete the current trip before ending duty.');
    }
    await AttendanceController.checkOut();
    await CabManagementController.updateShift(
      CabDriverShiftModel(
        id: shift.id,
        driverId: shift.driverId,
        vehicleId: shift.vehicleId,
        shiftDate: shift.shiftDate,
        shiftStart: shift.shiftStart,
        shiftEnd: DateTime.now(),
        shiftStatus: 'completed',
        startLocation: shift.startLocation,
        endLocation: shift.endLocation,
        totalDistance: shift.totalDistance,
        totalTrips: shift.totalTrips,
        totalEmployees: shift.totalEmployees,
        remarks: shift.remarks,
      ),
    );
  }

  static Future<void> startOrResumeTrip(CabDriverOperations data) async {
    final assignment = await _ensureTodayAssignment(data);
    if (!data.dutyActive) {
      throw StateError('Start duty before starting a trip.');
    }
    if (assignment.driverId != data.driver.uid) {
      throw StateError('No driver assignment exists for today.');
    }
    var employeeIds = data.members
        .where((member) => member.role == 'employee')
        .map((member) => member.userId)
        .toList();
    if (employeeIds.isEmpty) {
      employeeIds = (await _fetchEligiblePickupEmployees())
          .map((employee) => employee.uid)
          .toList();
    }
    await startTripWithEmployees(data, employeeIds);
  }

  static Future<void> startTripWithEmployees(
    CabDriverOperations data,
    List<String> employeeIds,
  ) async {
    if (!data.dutyActive) {
      throw StateError('Start duty before starting a trip.');
    }
    final assignment = await _ensureTodayAssignment(data);
    if (assignment.driverId != data.driver.uid) {
      throw StateError('No driver assignment exists for today.');
    }
    if (employeeIds.isEmpty) {
      throw StateError('Select at least one employee for the pickup trip.');
    }
    var session = await CabTrackingController.loadActiveDriverSession(
      data.driver.uid,
    );
    session ??= await CabTrackingController.startDriverSession(
      driverId: data.driver.uid,
      assignmentId: assignment.id,
    );
    await _locationSubscription?.cancel();
    _locationSubscription =
        await CabTrackingController.startDriverLiveLocationUpdates(
          session: session,
        );
    final now = DateTime.now();
    final trip = data.activeTrip == null
        ? await CabManagementController.createTrip(
            CabTripModel(
              assignmentId: assignment.id,
              dateKey: assignment.dateKey,
              driverId: data.driver.uid,
              vehicleId: assignment.vehicleId,
              status: 'active',
              activeLocationSessionId: session.id,
              createdAt: now,
              startedAt: now,
              updatedAt: now,
            ),
          )
        : await CabManagementController.updateTrip(
            data.activeTrip!.copyWith(
              status: 'active',
              activeLocationSessionId: session.id,
              startedAt: data.activeTrip!.startedAt ?? now,
              updatedAt: now,
            ),
          );
    await CabManagementController.updateAssignment(
      assignment.copyWith(
        employeeIds: employeeIds,
        status: 'started',
        updatedAt: now,
      ),
    );
    await _upsertAssignmentMembersForEmployees(data, assignment, employeeIds);
    await _initializeRiders(data, trip, employeeIds: employeeIds);
    await _event(data, trip, 'trip_started', 'Driver started cab trip.');
    await _notify(
      assignment.assignedBy,
      'Trip started',
      '${data.driver.name} started trip ${trip.id}.',
      'cab_trip_started',
    );
    final refreshed = await load();
    await _notifyNextRider(refreshed);
  }

  static Future<void> _upsertAssignmentMembersForEmployees(
    CabDriverOperations data,
    CabAssignmentModel assignment,
    List<String> employeeIds,
  ) async {
    final now = DateTime.now();
    final members = <CabAssignmentMemberModel>[];
    for (final employeeId in employeeIds.toSet()) {
      members.add(
        CabAssignmentMemberModel(
          id: '${assignment.dateKey}_$employeeId',
          assignmentId: assignment.id,
          dateKey: assignment.dateKey,
          userId: employeeId,
          role: 'employee',
          driverId: assignment.driverId,
          vehicleId: assignment.vehicleId,
          status: 'assigned',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    await CabManagementController.upsertAssignmentMembers(members);
  }

  static Future<void> reachedPickup(CabDriverOperations data) async {
    final trip = data.activeTrip;
    final rider = data.activeRider;
    if (trip == null || rider == null) throw StateError('No active pickup.');
    final distance = data.distanceToActiveRiderMeters;
    if (distance == null || distance > arrivalThresholdMeters) {
      throw StateError('Cab must be within 500 m of the active pickup.');
    }
    final now = DateTime.now();
    await CabManagementController.updateTripRiderFields(
      tripId: trip.id,
      riderId: rider.employeeId,
      fields: {'status': 'waiting', 'reachedPickupAt': Timestamp.fromDate(now)},
    );
    await _updateMember(data, rider.employeeId, 'waiting');
    await _event(
      data,
      trip,
      'pickup_reached',
      'Cab reached employee pickup.',
      employeeId: rider.employeeId,
    );
    await _notify(
      rider.employeeId,
      'Cab reached',
      'Your cab has reached the pickup point.',
      'cab_reached',
    );
  }

  static Future<void> pickedUp(CabDriverOperations data) async {
    final trip = data.activeTrip;
    final rider = data.activeRider;
    if (trip == null || rider == null || rider.status != 'waiting') {
      throw StateError('Reach the active pickup before confirming pickup.');
    }
    final now = DateTime.now();
    final waiting = now.difference(rider.reachedPickupAt ?? now).inSeconds;
    final delay = rider.readyAt == null
        ? 0
        : now.difference(rider.readyAt!).inSeconds;
    await CabManagementController.updateTripRiderFields(
      tripId: trip.id,
      riderId: rider.employeeId,
      fields: {
        'status': 'picked_up',
        'pickedUpAt': Timestamp.fromDate(now),
        'boardedAt': Timestamp.fromDate(now),
        'waitingDurationSeconds': waiting,
        'pickupDelaySeconds': delay,
      },
    );
    await _updateMember(data, rider.employeeId, 'picked_up');
    await _event(
      data,
      trip,
      'rider_picked_up',
      'Employee picked up.',
      employeeId: rider.employeeId,
      metadata: {'waitingDurationSeconds': waiting},
    );
    await _notify(
      rider.employeeId,
      'Picked up',
      'Your pickup has been confirmed.',
      'cab_picked_up',
    );
    if (waiting > 300) {
      await _notify(
        data.todayAssignment?.assignedBy ?? '',
        'Pickup waiting alert',
        '${data.employees[rider.employeeId]?.name ?? 'Employee'} waited ${(waiting / 60).round()} minutes.',
        'cab_waiting_alert',
      );
    }
    await _notifyNextRider(await load());
  }

  static Future<void> reachedDestination(CabDriverOperations data) async {
    final trip = data.activeTrip;
    final assignment = data.todayAssignment;
    if (trip == null || assignment == null) throw StateError('No active trip.');
    final now = DateTime.now();
    await CabManagementController.updateTrip(
      trip.copyWith(
        status: 'office_arrived',
        officeArrivedAt: now,
        updatedAt: now,
      ),
    );
    for (final rider in data.riders.where(
      (item) => const {'picked_up', 'boarded'}.contains(item.status),
    )) {
      await CabManagementController.updateTripRiderFields(
        tripId: trip.id,
        riderId: rider.employeeId,
        fields: {'status': 'dropped', 'droppedAt': Timestamp.fromDate(now)},
      );
      await _updateMember(data, rider.employeeId, 'dropped');
      await _notify(
        rider.employeeId,
        'Dropped',
        'You have reached ${assignment.officeName}.',
        'cab_dropped',
      );
    }
    await _event(data, trip, 'destination_reached', 'Cab reached destination.');
    await completeTrip(await load());
  }

  static Future<void> completeTrip(CabDriverOperations data) async {
    final trip = data.activeTrip;
    final assignment = data.todayAssignment;
    if (trip == null || assignment == null) throw StateError('No active trip.');
    if (data.riders.any(
      (rider) => !const {'dropped', 'no_show'}.contains(rider.status),
    )) {
      throw StateError('All employees must be dropped before completion.');
    }
    final now = DateTime.now();
    final points = trip.activeLocationSessionId.isEmpty
        ? const <LocationHistoryPointModel>[]
        : await LocationHistoryService.fetchSessionPoints(
            trip.activeLocationSessionId,
          );
    var distanceMeters = 0.0;
    var drivingSeconds = 0;
    for (var index = 1; index < points.length; index++) {
      distanceMeters += LocationTrackingPolicy.distanceMeters(
        points[index - 1].latitude,
        points[index - 1].longitude,
        points[index].latitude,
        points[index].longitude,
      );
      if (points[index].speed > 1) {
        drivingSeconds += points[index].recordedAt
            .difference(points[index - 1].recordedAt)
            .inSeconds
            .clamp(0, 300)
            .toInt();
      }
    }
    final duration = now.difference(trip.startedAt ?? now).inSeconds;
    await CabManagementController.updateTrip(
      trip.copyWith(
        status: 'completed',
        completedAt: now,
        updatedAt: now,
        distanceKm: distanceMeters / 1000,
        durationSeconds: duration,
        drivingSeconds: drivingSeconds,
        idleSeconds: (duration - drivingSeconds).clamp(0, duration),
      ),
    );
    await CabManagementController.updateAssignmentStatus(
      assignmentId: assignment.id,
      status: 'completed',
    );
    final session = await CabTrackingController.loadActiveDriverSession(
      data.driver.uid,
    );
    if (session != null) {
      await CabTrackingController.stopDriverSession(session: session);
    }
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    final shift = data.shift;
    if (shift != null) {
      await CabManagementController.updateShift(
        CabDriverShiftModel(
          id: shift.id,
          driverId: shift.driverId,
          vehicleId: shift.vehicleId,
          shiftDate: shift.shiftDate,
          shiftStart: shift.shiftStart,
          shiftEnd: shift.shiftEnd,
          shiftStatus: shift.shiftStatus,
          startLocation: shift.startLocation,
          endLocation: shift.endLocation,
          totalDistance: shift.totalDistance + distanceMeters / 1000,
          totalTrips: shift.totalTrips + 1,
          totalEmployees:
              shift.totalEmployees +
              data.riders.where((r) => r.status == 'dropped').length,
          remarks: shift.remarks,
        ),
      );
    }
    await _event(data, trip, 'trip_completed', 'Cab trip completed.');
    await _notify(
      data.driver.uid,
      'Trip completed',
      'The current trip is complete.',
      'cab_trip_completed',
    );
    await _notify(
      assignment.assignedBy,
      'Trip completed',
      '${data.driver.name} completed trip ${trip.id}.',
      'cab_trip_completed',
    );
  }

  static Future<void> _initializeRiders(
    CabDriverOperations data,
    CabTripModel trip, {
    List<String>? employeeIds,
  }) async {
    final selectedEmployeeIds = employeeIds != null
        ? employeeIds.toSet()
        : data.members
              .where((member) => member.role == 'employee')
              .map((member) => member.userId)
              .toSet();

    final members = selectedEmployeeIds.map((userId) {
      final member = data.members.firstWhere(
        (item) => item.userId == userId && item.role == 'employee',
        orElse: () => CabAssignmentMemberModel(
          id: '${data.todayAssignment?.dateKey ?? dateKey(DateTime.now())}_$userId',
          assignmentId: trip.assignmentId,
          dateKey: data.todayAssignment?.dateKey ?? dateKey(DateTime.now()),
          userId: userId,
          role: 'employee',
          driverId: data.driver.uid,
          vehicleId: data.todayAssignment?.vehicleId ?? '',
          status: 'assigned',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      return member;
    }).toList();

    final driverLocation = data.locations[data.driver.uid];
    members.sort((a, b) {
      if (driverLocation == null) return a.userId.compareTo(b.userId);
      double distance(CabAssignmentMemberModel member) {
        final location = data.locations[member.userId];
        if (location == null) return double.infinity;
        return LocationTrackingPolicy.distanceMeters(
          driverLocation.latitude,
          driverLocation.longitude,
          location.latitude,
          location.longitude,
        );
      }

      return distance(a).compareTo(distance(b));
    });
    for (var index = 0; index < members.length; index++) {
      final member = members[index];
      final location = data.locations[member.userId];
      await CabManagementController.upsertTripRider(
        CabTripRiderModel(
          id: member.userId,
          tripId: trip.id,
          assignmentId: trip.assignmentId,
          employeeId: member.userId,
          status: member.status == 'ready' ? 'ready' : 'assigned',
          readyAt: member.updatedAt,
          pickupLatitude: location?.latitude,
          pickupLongitude: location?.longitude,
          pickupOrder: index + 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  static Future<void> _updateMember(
    CabDriverOperations data,
    String employeeId,
    String status,
  ) async {
    final member = data.members
        .where((item) => item.userId == employeeId)
        .firstOrNull;
    if (member == null || member.id.isEmpty) return;
    await CabManagementController.updateAssignmentMemberStatus(
      memberId: member.id,
      status: status,
    );
  }

  static Future<void> _notifyNextRider(CabDriverOperations data) async {
    final next = data.activeRider;
    if (next == null) return;
    final name = data.employees[next.employeeId]?.name ?? 'employee';
    await _notify(
      next.employeeId,
      'Cab is arriving',
      'Your cab is arriving. Please be ready.',
      'cab_arriving',
    );
    await _notify(
      data.driver.uid,
      'Next employee',
      'Proceed to $name for the next pickup.',
      'cab_next_employee',
    );
  }

  static Future<void> _event(
    CabDriverOperations data,
    CabTripModel trip,
    String type,
    String message, {
    String? employeeId,
    Map<String, dynamic> metadata = const {},
  }) {
    return CabManagementController.addTripEvent(
      CabTripEventModel(
        tripId: trip.id,
        assignmentId: trip.assignmentId,
        actorUserId: data.driver.uid,
        eventType: type,
        message: message,
        createdAt: DateTime.now(),
        metadata: {
          ...employeeId == null
              ? const <String, dynamic>{}
              : <String, dynamic>{'employeeId': employeeId},
          ...metadata,
        },
      ),
    );
  }

  static Future<void> _notify(
    String userId,
    String title,
    String body,
    String type,
  ) async {
    if (userId.trim().isEmpty) return;
    await NotificationService.createLocalNotification(
      userId: userId,
      title: title,
      body: body,
      type: type,
    );
  }
}
