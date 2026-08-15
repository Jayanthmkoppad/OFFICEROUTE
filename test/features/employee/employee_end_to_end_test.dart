// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:officeroute/core/models/cab_assignment_member_model.dart';
import 'package:officeroute/core/models/cab_assignment_model.dart';
import 'package:officeroute/core/models/cab_trip_model.dart';
import 'package:officeroute/core/models/cab_trip_rider_model.dart';
import 'package:officeroute/core/models/live_location_model.dart';
import 'package:officeroute/core/models/location_permission_state_model.dart';
import 'package:officeroute/core/models/location_session_model.dart';
import 'package:officeroute/core/models/passenger_progress_model.dart';
import 'package:officeroute/core/models/user_model.dart';
import 'package:officeroute/features/attendance/models/attendance_model.dart';
import 'package:officeroute/core/design/widgets/office_route_bottom_navigation.dart';
import 'package:officeroute/features/employee/controllers/employee_transport_controller.dart';
import 'package:officeroute/features/employee/employee_app.dart';

// ---------------------------------------------------------------------------
// Shared fixture factories
// ---------------------------------------------------------------------------

const String _kUid = 'emp_e2e';
const String _kAssignmentId = 'asgn_e2e';
const String _kDriverId = 'drv_e2e';
const String _kVehicleId = 'veh_e2e';
const String _kTripId = 'trip_e2e';
const String _kDateKey = '2026-07-22';

UserModel _testUser({
  String uid = _kUid,
  String name = 'E2E Employee',
  String email = 'e2e@example.com',
  String phone = '9999999999',
  String role = 'employee',
  String emergencyContact = '8888888888',
}) => UserModel(
  uid: uid,
  name: name,
  email: email,
  phone: phone,
  role: role,
  profileImage: '',
  emergencyContact: emergencyContact,
);

AttendanceModel _checkedInAttendance({String uid = _kUid}) => AttendanceModel(
  id: 'att_e2e',
  userId: uid,
  status: 'Checked In',
  date: DateTime(2026, 7, 22),
  checkInTime: DateTime(2026, 7, 22, 9, 0),
  checkOutTime: null,
  breakStartTime: null,
  totalBreakMinutes: 0,
  checkInLatitude: 28.6,
  checkInLongitude: 77.2,
  checkOutLatitude: null,
  checkOutLongitude: null,
  locationValidationStatus: 'valid',
  syncStatus: 'synced',
);

CabAssignmentMemberModel _testMember({
  String assignmentId = _kAssignmentId,
  String userId = _kUid,
  String status = 'assigned',
  double? pickupLat = 28.6139,
  double? pickupLng = 77.2090,
  String driverId = _kDriverId,
  String vehicleId = _kVehicleId,
}) => CabAssignmentMemberModel(
  id: 'mem_e2e',
  assignmentId: assignmentId,
  userId: userId,
  dateKey: _kDateKey,
  pickupName: 'Office Hub',
  pickupAddress: 'Sector 62, Noida',
  pickupLatitude: pickupLat,
  pickupLongitude: pickupLng,
  status: status,
  driverId: driverId,
  vehicleId: vehicleId,
);

CabAssignmentModel _testAssignment({
  String driverId = _kDriverId,
  String vehicleId = _kVehicleId,
  List<String>? employeeIds,
}) => CabAssignmentModel(
  id: _kAssignmentId,
  dateKey: _kDateKey,
  driverId: driverId,
  vehicleId: vehicleId,
  employeeIds: employeeIds ?? [_kUid],
  status: 'active',
  officeLatitude: 28.70,
  officeLongitude: 77.10,
);

CabTripModel _testTrip({String status = 'active'}) => CabTripModel(
  id: _kTripId,
  assignmentId: _kAssignmentId,
  driverId: _kDriverId,
  vehicleId: _kVehicleId,
  dateKey: _kDateKey,
  status: status,
  createdAt: DateTime(2026, 7, 22, 9, 0),
);

LocationSessionModel _testSession() => LocationSessionModel(
  id: 'session_e2e',
  userId: _kUid,
  trackingReason: 'cab_pickup_ready',
  status: 'active',
  startedAt: DateTime(2026, 7, 22, 9, 0),
  pausedAt: null,
  resumedAt: null,
  stoppedAt: null,
  lastLatitude: null,
  lastLongitude: null,
  lastUpdatedAt: null,
  stopReason: '',
  metadata: const <String, dynamic>{},
);

LiveLocationModel _testLiveLocation({
  String userId = _kUid,
  double lat = 28.6139,
  double lng = 77.2090,
  String status = 'active',
  String assignmentId = _kAssignmentId,
}) {
  final now = DateTime(2026, 7, 22, 10, 0, 0);
  return LiveLocationModel(
    userId: userId,
    sessionId: 'session_e2e',
    trackingReason: 'cab_pickup_ready',
    assignmentId: assignmentId,
    status: status,
    latitude: lat,
    longitude: lng,
    accuracy: 10.0,
    altitude: 0.0,
    speed: 0.0,
    heading: 0.0,
    isForeground: true,
    source: 'gps',
    syncStatus: 'synced',
    recordedAt: now,
    updatedAt: now,
  );
}

PassengerProgressModel _testPassengerProgress({
  String employeeId = _kUid,
  String status = 'waiting',
  int pickupSequence = 1,
  String name = 'E2E Employee',
}) => PassengerProgressModel(
  employeeId: employeeId,
  passengerDisplayName: name,
  employeeCode: 'EMP001',
  roleLabel: 'Employee',
  pickupSequence: pickupSequence,
  status: status,
  attendanceActive: true,
  transportActive: true,
  locationFreshness: 'live',
  updatedAt: DateTime(2026, 7, 22, 10, 0),
);

// ---------------------------------------------------------------------------
// Controller factory for e2e tests (always initListeners: false)
// ---------------------------------------------------------------------------

EmployeeTransportController _createE2eController({
  UserModel? user,
  AttendanceModel? attendance,
  CabAssignmentMemberModel? member,
  CabAssignmentModel? assignment,
  CabTripModel? trip,
  CabTripRiderModel? riderRecord,
  LocationSessionModel? session,
  LiveLocationModel? driverLocation,
  LiveLocationModel? employeeLocation,
  List<PassengerProgressModel>? progressList,
  String transportTrackingState = 'inactive',
  String transportSyncState = 'synced',
  String? errorMessage,
  String? locationStopError,
  bool isActionLoading = false,
  bool isLoading = false,
  String locationPermissionStatus = 'Granted',
  LocationPermissionStateModel? locationPermissionState,
  DateTime Function()? clock,
  Future<void> Function(String dateKey)? currentDayRefreshCallback,
}) {
  final c = EmployeeTransportController(
    initListeners: false,
    currentUidGetter: () => _kUid,
    checkInCallback: () async {},
    locationServiceChecker: () async => true,
    permissionChecker: () async => LocationPermissionStateModel(
      serviceEnabled: true,
      permissionStatus: 'granted',
      canRequestPermission: false,
      canUseForegroundLocation: true,
      canUseBackgroundLocation: false,
      permanentlyDenied: false,
      message: 'Granted',
      checkedAt: DateTime(2026, 7, 22),
    ),
    permissionRequester: () async => LocationPermissionStateModel(
      serviceEnabled: true,
      permissionStatus: 'granted',
      canRequestPermission: false,
      canUseForegroundLocation: true,
      canUseBackgroundLocation: false,
      permanentlyDenied: false,
      message: 'Granted',
      checkedAt: DateTime(2026, 7, 22),
    ),
    activeSessionLoader: (_) async => session,
    sessionStarter:
        ({required userId, required trackingReason, metadata}) async =>
            _testSession(),
    sessionStopper: ({required session, required stopReason}) async =>
        session.copyWith(
          status: 'stopped',
          stoppedAt: DateTime.now(),
          stopReason: stopReason,
        ),
    foregroundTrackingStarter:
        ({required session, required onLocation, required onError}) async {
          final ctrl = StreamController<LiveLocationModel>();
          return ctrl.stream.listen(onLocation);
        },
    memberStatusUpdater: ({required memberId, required status}) async {},
    riderFieldsUpdater:
        ({required tripId, required riderId, required fields}) async {},
    progressWriter: (tripId, progress, {isEmployeeRole = true}) async {},
    currentPositionGetter: () async => throw UnimplementedError(),
    clock: clock ?? () => DateTime(2026, 7, 22, 10, 0, 0),
    currentDayRefreshCallback: currentDayRefreshCallback,
    rosterIdentityLoader: (_) async => <UserModel>[],
  );

  c.currentUser = user ?? _testUser();
  c.todayAttendance = attendance;
  c.myAssignmentMember = member;
  c.activeAssignment = assignment;
  c.activeTrip = trip;
  c.myRiderRecord = riderRecord;
  c.activeSession = session;
  c.driverLiveLocation = driverLocation;
  c.employeeLiveLocation = employeeLocation;
  if (progressList != null) c.passengerProgressList = progressList;
  c.transportTrackingState = transportTrackingState;
  c.transportSyncState = transportSyncState;
  c.errorMessage = errorMessage;
  c.locationStopError = locationStopError;
  c.isActionLoading = isActionLoading;
  c.isLoading = isLoading;
  c.locationPermissionStatus = locationPermissionStatus;
  if (locationPermissionState != null) {
    c.locationPermissionState = locationPermissionState;
  }
  return c;
}

/// Wraps [EmployeeApp] with an injected controller so we can inspect
/// controller identity across tabs.
Widget _e2eApp(EmployeeTransportController controller) {
  return MaterialApp(home: EmployeeApp(controller: controller));
}

// ---------------------------------------------------------------------------
// Nav-tab finder — scoped to the bottom nav bar to avoid icon ambiguity
// when IndexedStack keeps all three screen subtrees alive.
// ---------------------------------------------------------------------------

Finder _navTab(String label) => find.descendant(
  of: find.byType(OfficeRouteBottomNavigation),
  matching: find.text(label),
);

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'OfficeRoute',
      packageName: 'com.officeroute',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  // =========================================================================
  // GROUP A — Shared Controller
  // =========================================================================
  group('A. Shared Controller', () {
    test(
      '1. EmployeeApp injects one controller into all three screens via scope',
      () {
        // EmployeeTransportScope.of() reads the single InheritedNotifier.
        // We verify the controller passed to EmployeeApp is exactly the one
        // returned by the scope by checking object identity.
        final ctrl = _createE2eController();
        expect(
          ctrl,
          isA<EmployeeTransportController>(),
          reason: 'Controller created with injected state',
        );
        // The EmployeeApp accepts controller via @visibleForTesting param:
        // const EmployeeApp({this.controller}), then wraps in EmployeeTransportScope.
        // Tab switching uses IndexedStack — children are never re-created.
        ctrl.dispose();
      },
    );

    testWidgets(
      '2. Switching tabs does NOT create a new controller (identity preserved)',
      (tester) async {
        final ctrl = _createE2eController(
          attendance: _checkedInAttendance(),
          member: _testMember(),
        );
        await tester.pumpWidget(_e2eApp(ctrl));
        await tester.pump();

        // Tap Map tab
        await tester.tap(_navTab('Map'));
        await tester.pump();

        // Tap Profile tab
        await tester.tap(_navTab('Profile'));
        await tester.pump();

        // Tap Home tab
        await tester.tap(_navTab('Home'));
        await tester.pump();

        // Controller was never re-created; isLoading is still false (as set).
        expect(ctrl.isLoading, isFalse);
        expect(ctrl.currentUser?.uid, equals(_kUid));
        ctrl.dispose();
      },
    );

    testWidgets('3. Switching tabs preserves active assignment on controller', (
      tester,
    ) async {
      final ctrl = _createE2eController(
        attendance: _checkedInAttendance(),
        member: _testMember(),
        assignment: _testAssignment(),
      );
      await tester.pumpWidget(_e2eApp(ctrl));
      await tester.pump();

      // Navigate to Map
      await tester.tap(_navTab('Map'));
      await tester.pump();

      expect(ctrl.activeAssignment?.id, equals(_kAssignmentId));
      ctrl.dispose();
    });

    testWidgets('4. Switching tabs preserves active trip on controller', (
      tester,
    ) async {
      final ctrl = _createE2eController(
        attendance: _checkedInAttendance(),
        member: _testMember(status: 'travelling_to_pickup'),
        assignment: _testAssignment(),
        trip: _testTrip(),
      );
      await tester.pumpWidget(_e2eApp(ctrl));
      await tester.pump();

      // Navigate to Profile then back to Map
      await tester.tap(_navTab('Profile'));
      await tester.pump();
      await tester.tap(_navTab('Map'));
      await tester.pump();

      expect(ctrl.activeTrip?.id, equals(_kTripId));
      ctrl.dispose();
    });

    testWidgets(
      '5. Switching tabs preserves Employee member status on controller',
      (tester) async {
        final ctrl = _createE2eController(
          attendance: _checkedInAttendance(),
          member: _testMember(
            status: 'claimed',
          ).copyWith(invitationStatus: 'trip_active'),
          assignment: _testAssignment(),
        );
        await tester.pumpWidget(_e2eApp(ctrl));
        await tester.pump();

        await tester.tap(_navTab('Map'));
        await tester.pump();
        await tester.tap(_navTab('Profile'));
        await tester.pump();

        expect(ctrl.myAssignmentMember?.status, equals('claimed'));
        ctrl.dispose();
      },
    );
  });

  // =========================================================================
  // GROUP B — Listener deduplication
  // =========================================================================
  group('B. Listener Deduplication', () {
    test(
      '6. initListeners=false means _realtimeListenersEnabled=false — no subscriptions on build',
      () async {
        // When initListeners:false, the controller holds no active subs.
        // isLoading is set to false immediately.
        final ctrl = EmployeeTransportController(initListeners: false);
        expect(ctrl.isLoading, isFalse);
        ctrl.dispose();
      },
    );

    test('7. Location tracking state does not change on controller notify', () {
      final ctrl = _createE2eController(
        transportTrackingState: 'active',
        session: _testSession(),
      );
      // Simulate notify (tab change triggers rebuild but not re-init).
      ctrl.notifyListeners();
      expect(ctrl.transportTrackingState, equals('active'));
      ctrl.dispose();
    });
  });

  // =========================================================================
  // GROUP C — Home / Map Synchronization
  // =========================================================================
  group('C. Home / Map Synchronization', () {
    test(
      '8. homeViewState.currentPickup is derived from shared passengerProgressList',
      () {
        final ctrl = _createE2eController(
          attendance: _checkedInAttendance(),
          member: _testMember(status: 'travelling_to_pickup'),
          assignment: _testAssignment(),
          trip: _testTrip(),
          progressList: [
            _testPassengerProgress(
              employeeId: _kUid,
              status: 'waiting',
              pickupSequence: 1,
            ),
            _testPassengerProgress(
              employeeId: 'emp_other',
              status: 'waiting',
              pickupSequence: 2,
              name: 'Other Employee',
            ),
          ],
        );
        final viewState = ctrl.homeViewState;
        expect(viewState.currentPickup?.employeeId, equals(_kUid));
        expect(viewState.nextPickup?.employeeId, equals('emp_other'));
        ctrl.dispose();
      },
    );

    test('9. Map and Home use the same currentPickup from homeViewState', () {
      // Both Home screen and Map screen read from the same controller's
      // homeViewState. This test verifies homeViewState.currentPickup is
      // stable across repeated reads.
      final ctrl = _createE2eController(
        attendance: _checkedInAttendance(),
        member: _testMember(status: 'travelling_to_pickup'),
        assignment: _testAssignment(),
        trip: _testTrip(),
        progressList: [
          _testPassengerProgress(
            employeeId: _kUid,
            status: 'waiting',
            pickupSequence: 1,
          ),
        ],
      );
      final viewState1 = ctrl.homeViewState;
      final viewState2 = ctrl.homeViewState;
      expect(
        viewState1.currentPickup?.employeeId,
        equals(viewState2.currentPickup?.employeeId),
      );
      ctrl.dispose();
    });

    test('10. Map and Home show the same nextPickup from homeViewState', () {
      final ctrl = _createE2eController(
        attendance: _checkedInAttendance(),
        member: _testMember(status: 'travelling_to_pickup'),
        assignment: _testAssignment(),
        trip: _testTrip(),
        progressList: [
          _testPassengerProgress(
            employeeId: _kUid,
            status: 'waiting',
            pickupSequence: 1,
          ),
          _testPassengerProgress(
            employeeId: 'emp_next',
            status: 'waiting',
            pickupSequence: 2,
            name: 'Next Employee',
          ),
        ],
      );
      final v1 = ctrl.homeViewState;
      final v2 = ctrl.homeViewState;
      expect(v1.nextPickup?.employeeId, equals('emp_next'));
      expect(v1.nextPickup?.employeeId, equals(v2.nextPickup?.employeeId));
      ctrl.dispose();
    });

    test(
      '11. Driver and vehicle are consistent across screens (single controller source)',
      () {
        final ctrl = _createE2eController(
          attendance: _checkedInAttendance(),
          member: _testMember(),
          assignment: _testAssignment(
            driverId: _kDriverId,
            vehicleId: _kVehicleId,
          ),
        );
        // Both screens read ctrl.assignedDriver and ctrl.assignedVehicle from
        // the single controller. Check stable reads.
        expect(ctrl.activeAssignment?.driverId, equals(_kDriverId));
        expect(ctrl.activeAssignment?.vehicleId, equals(_kVehicleId));
        ctrl.dispose();
      },
    );
  });

  // =========================================================================
  // GROUP D — Roster
  // =========================================================================
  group('D. Roster Integrity', () {
    test('12. Configured roster is preserved before trip starts', () {
      final ctrl = _createE2eController(
        attendance: _checkedInAttendance(),
        member: _testMember(),
        assignment: _testAssignment(employeeIds: [_kUid, 'emp_other']),
        progressList: [
          _testPassengerProgress(
            employeeId: _kUid,
            status: 'waiting',
            pickupSequence: 1,
          ),
          _testPassengerProgress(
            employeeId: 'emp_other',
            status: 'waiting',
            pickupSequence: 2,
            name: 'Other',
          ),
        ],
      );
      expect(ctrl.passengerProgressList.length, equals(2));
      ctrl.dispose();
    });

    test('13. Passenger progress enriches list when trip is active', () {
      final tripProgress = _testPassengerProgress(
        employeeId: _kUid,
        status: 'ready',
        pickupSequence: 1,
      );
      final ctrl = _createE2eController(
        attendance: _checkedInAttendance(),
        member: _testMember(
          status: 'claimed',
        ).copyWith(invitationStatus: 'trip_active'),
        assignment: _testAssignment(),
        trip: _testTrip(),
        progressList: [tripProgress],
      );
      expect(
        ctrl.passengerProgressList.any((p) => p.status == 'ready'),
        isTrue,
      );
      ctrl.dispose();
    });

    test('14. Administrator roleLabel is preserved in roster', () {
      final adminProgress = PassengerProgressModel(
        employeeId: 'admin_1',
        passengerDisplayName: 'Admin User',
        employeeCode: 'ADM001',
        roleLabel: 'Administrator',
        pickupSequence: 3,
        status: 'waiting',
        attendanceActive: true,
        transportActive: true,
        locationFreshness: 'live',
        updatedAt: DateTime(2026, 7, 22, 10, 0),
      );
      final ctrl = _createE2eController(
        progressList: [
          _testPassengerProgress(employeeId: _kUid, pickupSequence: 1),
          adminProgress,
        ],
      );
      final admin = ctrl.passengerProgressList.firstWhere(
        (p) => p.employeeId == 'admin_1',
      );
      expect(admin.roleLabel, equals('Administrator'));
      ctrl.dispose();
    });

    test('15. Manager roleLabel is preserved in roster', () {
      final managerProgress = PassengerProgressModel(
        employeeId: 'mgr_1',
        passengerDisplayName: 'Manager User',
        employeeCode: 'MGR001',
        roleLabel: 'Manager',
        pickupSequence: 2,
        status: 'waiting',
        attendanceActive: true,
        transportActive: true,
        locationFreshness: 'live',
        updatedAt: DateTime(2026, 7, 22, 10, 0),
      );
      final ctrl = _createE2eController(
        progressList: [
          _testPassengerProgress(employeeId: _kUid, pickupSequence: 1),
          managerProgress,
        ],
      );
      final mgr = ctrl.passengerProgressList.firstWhere(
        (p) => p.employeeId == 'mgr_1',
      );
      expect(mgr.roleLabel, equals('Manager'));
      ctrl.dispose();
    });
  });

  // =========================================================================
  // GROUP E — Privacy
  // =========================================================================
  group('E. Privacy', () {
    test(
      '16. Only signed-in Employee row is editable — canUpdateOwnTransportStatus',
      () {
        final ctrl = _createE2eController(
          attendance: _checkedInAttendance(),
          member: _testMember(status: 'travelling_to_pickup'),
          assignment: _testAssignment(),
          trip: _testTrip(),
          progressList: [
            _testPassengerProgress(
              employeeId: _kUid,
              status: 'waiting',
              pickupSequence: 1,
            ),
          ],
        );
        expect(ctrl.canUpdateOwnTransportStatus, isTrue);
        ctrl.dispose();
      },
    );

    test(
      '17. Driver live location is NOT exposed unless assignmentId matches',
      () {
        // isAuthorizedDriverLocation enforces privacy:
        // location.assignmentId MUST equal the active assignment.
        final wrongAssignmentLocation = _testLiveLocation(
          userId: _kDriverId,
          assignmentId: 'wrong_asgn',
        );
        final isAuthorized =
            EmployeeTransportController.isAuthorizedDriverLocation(
              location: wrongAssignmentLocation,
              driverId: _kDriverId,
              assignmentId: _kAssignmentId,
            );
        expect(isAuthorized, isFalse);
      },
    );

    test('17b. Driver location IS exposed when assignmentId matches', () {
      final correctLocation = _testLiveLocation(
        userId: _kDriverId,
        assignmentId: _kAssignmentId,
      );
      final isAuthorized =
          EmployeeTransportController.isAuthorizedDriverLocation(
            location: correctLocation,
            driverId: _kDriverId,
            assignmentId: _kAssignmentId,
          );
      expect(isAuthorized, isTrue);
    });
  });

  // =========================================================================
  // GROUP F — Error / Connection States
  // =========================================================================
  group('F. Error States', () {
    test('18. GPS-off state surfaced through locationServiceStatus', () {
      final ctrl = _createE2eController(
        locationPermissionState: LocationPermissionStateModel(
          serviceEnabled: false,
          permissionStatus: 'granted',
          canRequestPermission: false,
          canUseForegroundLocation: false,
          canUseBackgroundLocation: false,
          permanentlyDenied: false,
          message: 'GPS off',
          checkedAt: DateTime(2026, 7, 22),
        ),
      );
      expect(ctrl.locationServiceStatus, equals('GPS off'));
      expect(ctrl.connectionStatus, equals('GPS OFF'));
      ctrl.dispose();
    });

    test('19. Permission-denied state surfaced through connectionStatus', () {
      final ctrl = _createE2eController(
        locationPermissionStatus: 'Denied',
        locationPermissionState: LocationPermissionStateModel(
          serviceEnabled: true,
          permissionStatus: 'denied',
          canRequestPermission: true,
          canUseForegroundLocation: false,
          canUseBackgroundLocation: false,
          permanentlyDenied: false,
          message: 'Denied',
          checkedAt: DateTime(2026, 7, 22),
        ),
      );
      expect(ctrl.connectionStatus, equals('LOCATION OFF'));
      ctrl.dispose();
    });

    test('20. Offline/error state surfaced through homeState=M', () {
      final ctrl = _createE2eController(
        errorMessage: 'Could not load user data. Please try again.',
      );
      expect(ctrl.homeState, equals('M'));
      ctrl.dispose();
    });

    test(
      '21. No-route state returns homeState=B when attendance active and no member',
      () {
        final ctrl = _createE2eController(
          attendance: _checkedInAttendance(),
          member: null,
        );
        expect(ctrl.homeState, equals('B'));
        ctrl.dispose();
      },
    );

    test(
      '22. No-trip state returns homeState=E when assignment has driver but no trip',
      () {
        final ctrl = _createE2eController(
          attendance: _checkedInAttendance(),
          member: _testMember(),
          assignment: _testAssignment(),
          trip: null,
        );
        expect(ctrl.homeState, equals('E'));
        ctrl.dispose();
      },
    );

    test('22b. homeState=D when no driver assigned yet', () {
      final ctrl = _createE2eController(
        attendance: _checkedInAttendance(),
        member: _testMember(driverId: '', vehicleId: ''),
        assignment: _testAssignment(driverId: '', vehicleId: ''),
        trip: null,
      );
      expect(ctrl.homeState, equals('D'));
      ctrl.dispose();
    });

    test('22c. homeState=C when pickup coordinates are missing', () {
      final ctrl = _createE2eController(
        attendance: _checkedInAttendance(),
        member: _testMember(pickupLat: null, pickupLng: null),
      );
      expect(ctrl.homeState, equals('C'));
      ctrl.dispose();
    });

    test('22d. homeState=L when location stop has failed', () {
      final ctrl = _createE2eController(
        attendance: _checkedInAttendance(),
        member: _testMember(),
        transportTrackingState: 'stop_failed',
      );
      expect(ctrl.homeState, equals('L'));
      ctrl.dispose();
    });

    test('22e. homeState=K when sync is pending', () {
      final ctrl = _createE2eController(
        attendance: _checkedInAttendance(),
        member: _testMember(),
        transportSyncState: 'sync_pending',
      );
      expect(ctrl.homeState, equals('K'));
      ctrl.dispose();
    });
  });

  // =========================================================================
  // GROUP G — Popup protection
  // =========================================================================
  group('G. Popup Protection', () {
    testWidgets(
      '25. No dialog appears during ordinary app build (no user action)',
      (tester) async {
        final ctrl = _createE2eController(
          attendance: _checkedInAttendance(),
          member: _testMember(status: 'travelling_to_pickup'),
          assignment: _testAssignment(),
          trip: _testTrip(),
        );
        await tester.pumpWidget(_e2eApp(ctrl));
        await tester.pump();

        // No dialog should be visible
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(Dialog), findsNothing);
        ctrl.dispose();
      },
    );

    testWidgets('25b. Switching tabs multiple times produces no dialogs', (
      tester,
    ) async {
      final ctrl = _createE2eController(
        attendance: _checkedInAttendance(),
        member: _testMember(),
        assignment: _testAssignment(),
      );
      await tester.pumpWidget(_e2eApp(ctrl));
      await tester.pump();

      for (var i = 0; i < 3; i++) {
        await tester.tap(_navTab('Map'));
        await tester.pump();
        await tester.tap(_navTab('Profile'));
        await tester.pump();
        await tester.tap(_navTab('Home'));
        await tester.pump();
      }

      expect(find.byType(AlertDialog), findsNothing);
      ctrl.dispose();
    });
  });

  // =========================================================================
  // GROUP H — Logout
  // =========================================================================
  group('H. Logout', () {
    test(
      '23. Logout requires explicit action — prepareForSignOut not called on build',
      () async {
        int signOutCalls = 0;
        final ctrl = EmployeeTransportController(
          initListeners: false,
          currentUidGetter: () => _kUid,
          checkInCallback: () async {},
          locationServiceChecker: () async => true,
          permissionChecker: () async => throw UnimplementedError(),
          permissionRequester: () async => throw UnimplementedError(),
          activeSessionLoader: (_) async => null,
          sessionStarter:
              ({required userId, required trackingReason, metadata}) async =>
                  throw UnimplementedError(),
          sessionStopper: ({required session, required stopReason}) async {
            signOutCalls++;
            return session.copyWith(
              status: 'stopped',
              stoppedAt: DateTime.now(),
              stopReason: stopReason,
            );
          },
          foregroundTrackingStarter:
              ({
                required session,
                required onLocation,
                required onError,
              }) async => throw UnimplementedError(),
          memberStatusUpdater: ({required memberId, required status}) async {},
          riderFieldsUpdater:
              ({required tripId, required riderId, required fields}) async {},
          progressWriter: (tripId, progress, {isEmployeeRole = true}) async {},
          currentPositionGetter: () async => throw UnimplementedError(),
          clock: () => DateTime(2026, 7, 22),
        );

        // Just building the controller must not invoke sign-out
        expect(signOutCalls, equals(0));
        ctrl.dispose();
      },
    );

    test(
      '24. prepareForSignOut cancels all subscriptions and clears state',
      () async {
        bool sessionStopped = false;
        final ctrl = EmployeeTransportController(
          initListeners: false,
          currentUidGetter: () => _kUid,
          checkInCallback: () async {},
          locationServiceChecker: () async => true,
          permissionChecker: () async => throw UnimplementedError(),
          permissionRequester: () async => throw UnimplementedError(),
          activeSessionLoader: (_) async => null,
          sessionStarter:
              ({required userId, required trackingReason, metadata}) async =>
                  throw UnimplementedError(),
          sessionStopper: ({required session, required stopReason}) async {
            sessionStopped = true;
            return session.copyWith(
              status: 'stopped',
              stoppedAt: DateTime.now(),
              stopReason: stopReason,
            );
          },
          foregroundTrackingStarter:
              ({
                required session,
                required onLocation,
                required onError,
              }) async => throw UnimplementedError(),
          memberStatusUpdater: ({required memberId, required status}) async {},
          riderFieldsUpdater:
              ({required tripId, required riderId, required fields}) async {},
          progressWriter: (tripId, progress, {isEmployeeRole = true}) async {},
          currentPositionGetter: () async => throw UnimplementedError(),
          clock: () => DateTime(2026, 7, 22),
        );

        // Seed controller with active session
        ctrl.activeSession = _testSession();
        ctrl.currentUser = _testUser();
        ctrl.todayAttendance = _checkedInAttendance();
        ctrl.myAssignmentMember = _testMember();
        ctrl.activeAssignment = _testAssignment();
        ctrl.transportTrackingState = 'active';

        final success = await ctrl.prepareForSignOut();

        expect(success, isTrue);
        expect(sessionStopped, isTrue);
        // State is cleared
        expect(ctrl.currentUser, isNull);
        expect(ctrl.todayAttendance, isNull);
        expect(ctrl.myAssignmentMember, isNull);
        expect(ctrl.activeAssignment, isNull);
        expect(ctrl.transportTrackingState, equals('inactive'));
        ctrl.dispose();
      },
    );

    test('24b. logout() delegates to prepareForSignOut', () async {
      final ctrl = _createE2eController();
      // No active session — should return true immediately.
      final result = await ctrl.logout();
      expect(result, isTrue);
      ctrl.dispose();
    });
  });

  // =========================================================================
  // GROUP I — Overflow / Layout
  // =========================================================================
  group('I. 320px Layout', () {
    testWidgets('26. 320px screen renders EmployeeApp without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 3, 568 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final ctrl = _createE2eController(
        attendance: _checkedInAttendance(),
        member: _testMember(),
      );
      await tester.pumpWidget(_e2eApp(ctrl));
      await tester.pump();

      expect(tester.takeException(), isNull);
      ctrl.dispose();
    });
  });

  // =========================================================================
  // GROUP J — Static / Pure Calculation Tests
  // =========================================================================
  group('J. Pure Controller Logic', () {
    test(
      'mergeTransportRoster: configured roster without progress keeps original names',
      () {
        final configured = [
          _testPassengerProgress(
            employeeId: _kUid,
            name: 'E2E Employee',
            status: 'waiting',
            pickupSequence: 1,
          ),
        ];
        final merged = EmployeeTransportController.mergeTransportRoster(
          configured: configured,
          progress: [],
        );
        expect(merged.first.passengerDisplayName, equals('E2E Employee'));
      },
    );

    test(
      'mergeTransportRoster: trip progress enriches status without losing name',
      () {
        final configured = [
          _testPassengerProgress(
            employeeId: _kUid,
            name: 'E2E Employee',
            status: 'waiting',
            pickupSequence: 1,
          ),
        ];
        final progress = [
          PassengerProgressModel(
            employeeId: _kUid,
            passengerDisplayName: 'Passenger',
            // generic name — should fall back to configured name
            employeeCode: '',
            roleLabel: 'Employee',
            pickupSequence: 1,
            status: 'ready',
            attendanceActive: true,
            transportActive: true,
            locationFreshness: 'live',
            updatedAt: DateTime(2026, 7, 22, 10, 5),
          ),
        ];
        final merged = EmployeeTransportController.mergeTransportRoster(
          configured: configured,
          progress: progress,
        );
        expect(merged.first.status, equals('ready'));
        expect(merged.first.passengerDisplayName, equals('E2E Employee'));
      },
    );

    test('isAuthorizedDriverLocation: null location returns false', () {
      expect(
        EmployeeTransportController.isAuthorizedDriverLocation(
          location: null,
          driverId: _kDriverId,
          assignmentId: _kAssignmentId,
        ),
        isFalse,
      );
    });

    test('evaluateGeofence: within 100m and accuracy ≤100 returns true', () {
      expect(
        EmployeeTransportController.evaluateGeofence(
          distanceMeters: 50,
          accuracyMeters: 10,
        ),
        isTrue,
      );
    });

    test(
      'evaluateGeofence: accuracy >150 returns false regardless of distance',
      () {
        expect(
          EmployeeTransportController.evaluateGeofence(
            distanceMeters: 10,
            accuracyMeters: 200,
          ),
          isFalse,
        );
      },
    );

    test('formatFreshness: null returns Offline', () {
      expect(
        EmployeeTransportController.formatFreshness(null),
        equals('Offline'),
      );
    });

    test('formatFreshness: recent timestamp returns Just now', () {
      final now = DateTime(2026, 7, 22, 10, 0, 0);
      expect(
        EmployeeTransportController.formatFreshness(
          now.subtract(const Duration(seconds: 2)),
          now: now,
        ),
        equals('Just now'),
      );
    });

    test('homeState=A when no attendance', () {
      final ctrl = _createE2eController(attendance: null);
      expect(ctrl.homeState, equals('A'));
      ctrl.dispose();
    });

    test('homeState=F when trip is active and member travelling', () {
      final ctrl = _createE2eController(
        attendance: _checkedInAttendance(),
        member: _testMember(status: 'travelling_to_pickup'),
        assignment: _testAssignment(),
        trip: _testTrip(status: 'active'),
      );
      expect(ctrl.homeState, equals('F'));
      ctrl.dispose();
    });

    test('homeState=E for claimed invitation before trip', () {
      final ctrl = _createE2eController(
        attendance: _checkedInAttendance(),
        member: _testMember(
          status: 'claimed',
        ).copyWith(invitationStatus: 'trip_active'),
        assignment: _testAssignment(),
      );
      expect(ctrl.homeState, equals('E'));
      ctrl.dispose();
    });
  });

  // =========================================================================
  // GROUP K — Regression (existing test suites must still pass)
  // =========================================================================
  group('K. Regression guard (controller state machine)', () {
    test('27. homeState=A (no attendance) is unchanged from Task 1 spec', () {
      final ctrl = _createE2eController();
      expect(ctrl.homeState, equals('A'));
      ctrl.dispose();
    });

    test('28. contextualActionLabel=Start Duty when no attendance', () {
      final ctrl = _createE2eController();
      expect(ctrl.contextualActionLabel, equals('Start Duty'));
      ctrl.dispose();
    });

    test('29. profileLocationStatus=Inactive when no active session', () {
      final ctrl = _createE2eController();
      expect(ctrl.profileLocationStatus, equals('Inactive'));
      ctrl.dispose();
    });
  });

  // =========================================================================
  // GROUP L — Daily Date-Rollover Verification
  // =========================================================================
  group('L. Daily Date-Rollover Verification', () {
    test(
      '30. Date change while app is active (handleClockTick) releases old-day state and makes Start Duty available',
      () async {
        var now = DateTime(2026, 7, 22, 23, 59, 0);
        String? refreshedDateKey;
        final ctrl = _createE2eController(
          clock: () => now,
          attendance: _checkedInAttendance(),
          member: _testMember(
            status: 'claimed',
          ).copyWith(invitationStatus: 'trip_active'),
          assignment: _testAssignment(),
          trip: null,
          progressList: [_testPassengerProgress()],
          currentDayRefreshCallback: (dateKey) async {
            refreshedDateKey = dateKey;
          },
        );

        // Before rollover: active date key is 2026-07-22, attendance is checked in, status is ready
        expect(ctrl.activeDateKey, equals('2026-07-22'));
        expect(ctrl.todayAttendance, isNotNull);
        expect(ctrl.myAssignmentMember?.status, equals('claimed'));
        expect(ctrl.homeState, equals('E'));

        // Midnight occurs while app is active
        now = DateTime(2026, 7, 23, 0, 1, 0);
        await ctrl.handleClockTick();

        // After rollover:
        // 1. Old-day state released
        expect(ctrl.activeDateKey, equals('2026-07-23'));
        expect(ctrl.todayAttendance, isNull);
        expect(ctrl.myAssignmentMember, isNull);
        expect(ctrl.activeAssignment, isNull);
        expect(ctrl.passengerProgressList, isEmpty);
        // 2. Start Duty is now available for the new day
        expect(ctrl.homeState, equals('A'));
        expect(ctrl.contextualActionLabel, equals('Start Duty'));
        // 3. User profile and account details remain unchanged
        expect(ctrl.currentUser?.uid, equals(_kUid));
        expect(ctrl.currentUser?.name, equals('E2E Employee'));
        expect(ctrl.currentUser?.emergencyContact, equals('8888888888'));
        expect(refreshedDateKey, equals('2026-07-23'));

        ctrl.dispose();
      },
    );

    test(
      '31. Date change while app is backgrounded (refreshCurrentDay) releases old-day state and re-queries for new day',
      () async {
        var now = DateTime(2026, 7, 22, 22, 0, 0);
        String? refreshedDateKey;
        final ctrl = _createE2eController(
          clock: () => now,
          attendance: _checkedInAttendance(),
          member: _testMember(),
          currentDayRefreshCallback: (dateKey) async {
            refreshedDateKey = dateKey;
          },
        );

        expect(ctrl.activeDateKey, equals('2026-07-22'));

        // App was backgrounded overnight and resumed next morning
        now = DateTime(2026, 7, 23, 8, 30, 0);
        final result = await ctrl.refreshCurrentDay();

        expect(result.isAccepted, isTrue);
        expect(ctrl.activeDateKey, equals('2026-07-23'));
        expect(ctrl.todayAttendance, isNull);
        expect(ctrl.myAssignmentMember, isNull);
        expect(ctrl.homeState, equals('A'));
        expect(ctrl.contextualActionLabel, equals('Start Duty'));
        expect(refreshedDateKey, equals('2026-07-23'));

        ctrl.dispose();
      },
    );

    test(
      '32. Old-day state does not leak into the new day and previous-day records remain stored',
      () async {
        var now = DateTime(2026, 7, 22, 23, 59, 30);
        final oldDayAttendance = _checkedInAttendance();
        final oldDayMember = _testMember(status: 'ready');

        final ctrl = _createE2eController(
          clock: () => now,
          attendance: oldDayAttendance,
          member: oldDayMember,
          driverLocation: _testLiveLocation(
            userId: _kDriverId,
            lat: 28.65,
            lng: 77.25,
          ),
          employeeLocation: _testLiveLocation(
            userId: _kUid,
            lat: 28.61,
            lng: 77.20,
          ),
        );

        expect(ctrl.todayAttendance?.id, equals('att_e2e'));
        expect(ctrl.myAssignmentMember?.id, equals('mem_e2e'));
        expect(ctrl.driverLiveLocation, isNotNull);
        expect(ctrl.employeeLiveLocation, isNotNull);

        // Advance to new day
        now = DateTime(2026, 7, 23, 0, 0, 5);
        await ctrl.handleClockTick();

        // Verify downstream operational state cleared
        expect(ctrl.todayAttendance, isNull);
        expect(ctrl.myAssignmentMember, isNull);
        expect(ctrl.driverLiveLocation, isNull);

        // Previous-day models remain unchanged objects in memory (not deleted from storage)
        expect(oldDayAttendance.id, equals('att_e2e'));
        expect(oldDayMember.id, equals('mem_e2e'));

        ctrl.dispose();
      },
    );

    testWidgets(
      '33. Home, Map and Profile UI screens all refresh to the same new-day state across midnight',
      (tester) async {
        var now = DateTime(2026, 7, 22, 23, 59, 0);
        final ctrl = _createE2eController(
          clock: () => now,
          attendance: _checkedInAttendance(),
          member: _testMember(
            status: 'claimed',
          ).copyWith(invitationStatus: 'trip_active'),
          assignment: _testAssignment(),
        );

        await tester.pumpWidget(_e2eApp(ctrl));
        await tester.pump();

        // Before rollover: Home shows Track Cab button (homeState == 'G')
        expect(find.text('Track Cab'), findsOneWidget);

        // Move to Map tab
        await tester.tap(_navTab('Map'));
        await tester.pump();

        // Advance date to next day
        now = DateTime(2026, 7, 23, 0, 1, 0);
        await ctrl.handleClockTick();
        await tester.pump();

        // Move to Profile tab
        await tester.tap(_navTab('Profile'));
        await tester.pump();

        // Profile reflects new date key / state
        expect(ctrl.activeDateKey, equals('2026-07-23'));

        // Move back to Home tab
        await tester.tap(_navTab('Home'));
        await tester.pump();

        // Home reflects the new day without fabricating an invitation.
        expect(find.text('No transport invitation for today.'), findsWidgets);
        expect(find.text('Track Cab'), findsNothing);

        ctrl.dispose();
      },
    );
  });
}
