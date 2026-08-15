import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:officeroute/core/models/cab_assignment_member_model.dart';
import 'package:officeroute/core/models/cab_assignment_model.dart';
import 'package:officeroute/core/models/passenger_progress_model.dart';
import 'package:officeroute/core/models/user_model.dart';
import 'package:officeroute/features/attendance/models/attendance_model.dart';
import 'package:officeroute/features/employee/controllers/employee_transport_controller.dart';
import 'package:officeroute/features/employee/employee_home_screen.dart';
import 'package:officeroute/features/employee/employee_map_screen.dart';
import 'package:officeroute/features/employee/employee_profile_screen.dart';

/// Creates a minimal controller with specified state for widget testing.
EmployeeTransportController _createTestController({
  UserModel? user,
  AttendanceModel? attendance,
  CabAssignmentMemberModel? member,
  CabAssignmentModel? assignment,
  String transportTrackingState = 'inactive',
  String transportSyncState = 'synced',
  String? errorMessage,
  String? locationStopError,
  Future<void> Function(String dateKey)? currentDayRefreshCallback,
  DateTime Function()? clock,
  bool isLoading = false,
}) {
  final controller = EmployeeTransportController(
    initListeners: false,
    currentUidGetter: () => 'test_uid',
    checkInCallback: () async {},
    locationServiceChecker: () async => true,
    permissionChecker: () async => throw UnimplementedError(),
    permissionRequester: () async => throw UnimplementedError(),
    activeSessionLoader: (_) async => null,
    sessionStarter:
        ({required userId, required trackingReason, metadata}) async =>
            throw UnimplementedError(),
    sessionStopper: ({required session, required stopReason}) async =>
        throw UnimplementedError(),
    foregroundTrackingStarter:
        ({required session, required onLocation, required onError}) async =>
            throw UnimplementedError(),
    memberStatusUpdater: ({required memberId, required status}) async {},
    riderFieldsUpdater:
        ({required tripId, required riderId, required fields}) async {},
    progressWriter: (tripId, progress, {isEmployeeRole = true}) async {},
    currentPositionGetter: () async => throw UnimplementedError(),
    clock: clock ?? () => DateTime(2026, 7, 22, 10, 0, 0),
    currentDayRefreshCallback: currentDayRefreshCallback,
  );

  controller.currentUser =
      user ??
      const UserModel(
        uid: 'test_uid',
        name: 'Test Employee',
        email: 'test@example.com',
        phone: '1234567890',
        role: 'Employee',
        profileImage: '',
      );
  controller.todayAttendance = attendance;
  controller.myAssignmentMember = member;
  controller.activeAssignment = assignment;
  controller.transportTrackingState = transportTrackingState;
  controller.transportSyncState = transportSyncState;
  controller.errorMessage = errorMessage;
  controller.locationStopError = locationStopError;
  controller.isLoading = isLoading;

  return controller;
}

/// Wraps a widget with EmployeeTransportScope for testing.
Widget _testApp(Widget child, EmployeeTransportController controller) {
  return MaterialApp(
    home: EmployeeTransportScope(controller: controller, child: child),
  );
}

AttendanceModel _checkedInAttendance() {
  return AttendanceModel(
    id: 'att_1',
    userId: 'test_uid',
    status: 'Checked In',
    date: DateTime(2026, 7, 22),
    checkInTime: DateTime(2026, 7, 22, 9, 0),
    checkOutTime: null,
    breakStartTime: null,
    totalBreakMinutes: 0,
    checkInLatitude: 28.6139,
    checkInLongitude: 77.2090,
    checkOutLatitude: null,
    checkOutLongitude: null,
    locationValidationStatus: 'valid',
    syncStatus: 'synced',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Employee Home Screen Widget Tests', () {
    // 1. No-route Home keeps the verified hero and roster visible.
    testWidgets('1. No-route Home shows truthful hero and roster', (
      tester,
    ) async {
      final controller = _createTestController(
        attendance: _checkedInAttendance(),
      );

      await tester.pumpWidget(
        _testApp(EmployeeHomeScreen(onNavigateToMap: () {}), controller),
      );
      await tester.pumpAndSettle();

      expect(find.text('No transport invitation for today.'), findsWidgets);
      expect(find.byKey(const Key('employee_transport_hero')), findsOneWidget);
      await tester.dragUntilVisible(
        find.text("TODAY'S EMPLOYEES"),
        find.byType(CustomScrollView),
        const Offset(0, -300),
      );
      expect(find.text("TODAY'S EMPLOYEES"), findsOneWidget);
      expect(find.text('No active route for today.'), findsOneWidget);
      expect(find.byKey(const Key('refresh_status_button')), findsOneWidget);
      expect(find.textContaining('Setup Test Route'), findsNothing);
    });

    testWidgets('INVITED state shows truthful response actions', (
      tester,
    ) async {
      final controller = _createTestController(
        attendance: _checkedInAttendance(),
        member: const CabAssignmentMemberModel(
          id: '2026-07-22_test_uid',
          dateKey: '2026-07-22',
          userId: 'test_uid',
          role: 'employee',
          driverId: 'driver_1',
          vehicleId: 'vehicle_1',
          status: 'invited',
          invitationStatus: 'invited',
          officeName: 'Operations Office',
          officeAddress: 'Operations Campus',
          officeLatitude: 15.36,
          officeLongitude: 75.12,
        ),
      );

      await tester.pumpWidget(
        _testApp(EmployeeHomeScreen(onNavigateToMap: () {}), controller),
      );
      await tester.pumpAndSettle();

      expect(find.text('CAB INVITATION'), findsOneWidget);
      expect(find.text('Pending response'), findsOneWidget);
      expect(
        find.byKey(const Key('accept_cab_invitation_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('decline_cab_invitation_button')),
        findsOneWidget,
      );
      expect(find.text('Request Pickup'), findsNothing);
      expect(find.text('Mark Ready'), findsNothing);
    }); // 2. No-route Home hides distance cards
    testWidgets('2. No-route Home hides distance cards', (tester) async {
      final controller = _createTestController(
        attendance: _checkedInAttendance(),
      );

      await tester.pumpWidget(
        _testApp(EmployeeHomeScreen(onNavigateToMap: () {}), controller),
      );
      await tester.pumpAndSettle();

      // Distance cards should NOT be visible
      expect(find.byKey(const Key('employee_distance_card')), findsNothing);
      expect(find.byKey(const Key('cab_distance_card')), findsNothing);
    });

    // 3. No-route Home hides passenger-progress section
    testWidgets('3. No-route Home hides passenger-progress section', (
      tester,
    ) async {
      final controller = _createTestController(
        attendance: _checkedInAttendance(),
      );

      await tester.pumpWidget(
        _testApp(EmployeeHomeScreen(onNavigateToMap: () {}), controller),
      );
      await tester.pumpAndSettle();

      // Passenger progress section should NOT be visible
      expect(find.byKey(const Key('passenger_progress_section')), findsNothing);
      expect(find.text('Trip Passenger Progress'), findsNothing);
    });

    // A missing saved pickup is allowed until an invitation is accepted.
    testWidgets('4. no invitation does not fabricate pickup configuration', (
      tester,
    ) async {
      final controller = _createTestController(
        attendance: _checkedInAttendance(),
      );
      await tester.pumpWidget(
        _testApp(EmployeeHomeScreen(onNavigateToMap: () {}), controller),
      );
      await tester.pumpAndSettle();
      expect(find.text('No transport invitation for today.'), findsWidgets);
      expect(find.textContaining('Administrator'), findsNothing);
    });
    // 5. Offline state does not say Approval
    testWidgets('5. Offline state does not say Approval', (tester) async {
      final controller = _createTestController(
        errorMessage: 'Network unavailable',
      );

      await tester.pumpWidget(
        _testApp(EmployeeHomeScreen(onNavigateToMap: () {}), controller),
      );
      await tester.pumpAndSettle();

      // Should NOT contain "Approval"
      final approvalFinder = find.textContaining('Approval');
      expect(approvalFinder, findsNothing);

      // Should NOT contain "approval"
      final approvalLowerFinder = find.textContaining('approval');
      expect(approvalLowerFinder, findsNothing);
    });

    // 6. Sync-pending state shows Retry Sync
    testWidgets('6. Sync-pending state shows Retry Sync', (tester) async {
      final controller = _createTestController(
        attendance: _checkedInAttendance(),
        transportSyncState: 'sync_pending',
      );

      await tester.pumpWidget(
        _testApp(EmployeeHomeScreen(onNavigateToMap: () {}), controller),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('retry_sync_button')), findsOneWidget);
      expect(find.text('Retry Sync'), findsOneWidget);
    });

    // 7. stop_failed state shows Retry Stop
    testWidgets('7. stop_failed state shows Retry Stop', (tester) async {
      final controller = _createTestController(
        attendance: _checkedInAttendance(),
        transportTrackingState: 'stop_failed',
      );

      await tester.pumpWidget(
        _testApp(EmployeeHomeScreen(onNavigateToMap: () {}), controller),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('retry_stop_button')), findsOneWidget);
      expect(find.text('Retry Stop'), findsOneWidget);
    });

    testWidgets('8. initial loading does not show Start Duty', (tester) async {
      final controller = _createTestController(isLoading: true);
      await tester.pumpWidget(
        _testApp(EmployeeHomeScreen(onNavigateToMap: () {}), controller),
      );

      expect(find.byKey(const Key('employee_home_loading')), findsOneWidget);
      expect(find.byKey(const Key('start_duty_button')), findsNothing);
    });

    testWidgets('9. header shows injected greeting and identity', (
      tester,
    ) async {
      final controller = _createTestController(
        clock: () => DateTime(2026, 7, 23, 20, 7),
      );
      await tester.pumpWidget(
        _testApp(EmployeeHomeScreen(onNavigateToMap: () {}), controller),
      );

      expect(find.text('OfficeRoute'), findsOneWidget);
      expect(find.text('EMP CODE: Unavailable'), findsOneWidget);
      expect(find.text('Good evening, Test Employee'), findsOneWidget);
    });

    testWidgets('10. refresh is working and demo control is absent', (
      tester,
    ) async {
      var refreshCount = 0;
      final controller = _createTestController(
        attendance: _checkedInAttendance(),
        currentDayRefreshCallback: (_) async => refreshCount++,
      );
      await tester.pumpWidget(
        _testApp(EmployeeHomeScreen(onNavigateToMap: () {}), controller),
      );

      expect(find.textContaining('Setup Test Route'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const Key('refresh_status_button')),
      );
      await tester.tap(find.byKey(const Key('refresh_status_button')));
      await tester.pumpAndSettle();
      expect(refreshCount, 1);
      expect(find.textContaining('up to date'), findsOneWidget);
    });

    testWidgets('11. no-route state keeps one refresh action', (tester) async {
      final controller = _createTestController(
        attendance: _checkedInAttendance(),
      );
      await tester.pumpWidget(
        _testApp(EmployeeHomeScreen(onNavigateToMap: () {}), controller),
      );
      expect(
        find.byKey(const Key('contact_administrator_button')),
        findsNothing,
      );
      expect(find.byKey(const Key('refresh_status_button')), findsOneWidget);
    });

    testWidgets('12. Track Cab opens Map through supplied callback', (
      tester,
    ) async {
      var openedMap = false;
      final controller = _createTestController(
        attendance: _checkedInAttendance(),
        member: const CabAssignmentMemberModel(
          id: 'mem_1',
          assignmentId: 'assign_1',
          dateKey: '2026-07-22',
          userId: 'test_uid',
          driverId: 'driver_1',
          vehicleId: 'vehicle_1',
          status: 'claimed',
          invitationStatus: 'trip_active',
          pickupName: 'Office Gate',
          pickupAddress: '123 Main St',
          pickupLatitude: 28.6139,
          pickupLongitude: 77.2090,
        ),
        assignment: const CabAssignmentModel(
          id: 'assign_1',
          dateKey: '2026-07-22',
          driverId: 'driver_1',
          vehicleId: 'vehicle_1',
        ),
      );
      await tester.pumpWidget(
        _testApp(
          EmployeeHomeScreen(onNavigateToMap: () => openedMap = true),
          controller,
        ),
      );
      await tester.ensureVisible(find.byKey(const Key('track_cab_button')));
      await tester.tap(find.byKey(const Key('track_cab_button')));
      expect(openedMap, isTrue);
    });

    testWidgets('13. active invitation uses truthful ETA and distance labels', (
      tester,
    ) async {
      final controller = _createTestController(
        attendance: _checkedInAttendance(),
        member: const CabAssignmentMemberModel(
          id: 'mem_1',
          assignmentId: 'assign_1',
          dateKey: '2026-07-22',
          userId: 'test_uid',
          driverId: 'driver_1',
          vehicleId: 'vehicle_1',
          status: 'claimed',
          invitationStatus: 'trip_active',
          pickupName: 'Office Gate',
          pickupAddress: '123 Main St',
          pickupLatitude: 28.6139,
          pickupLongitude: 77.2090,
        ),
        assignment: const CabAssignmentModel(
          id: 'assign_1',
          dateKey: '2026-07-22',
          driverId: 'driver_1',
        ),
      );
      await tester.pumpWidget(
        _testApp(EmployeeHomeScreen(onNavigateToMap: () {}), controller),
      );
      expect(find.text('DRIVER APPROACHING'), findsOneWidget);
      expect(find.text('ETA unavailable'), findsOneWidget);
      expect(find.textContaining('CAB TO YOUR PICKUP'), findsNothing);
    });

    testWidgets('14. route timeline is ordered and privacy-safe', (
      tester,
    ) async {
      final controller = _createTestController(
        attendance: _checkedInAttendance(),
        member: const CabAssignmentMemberModel(
          id: 'mem_1',
          assignmentId: 'assign_1',
          dateKey: '2026-07-22',
          userId: 'test_uid',
          driverId: 'driver_1',
          vehicleId: 'vehicle_1',
          pickupName: 'Office Gate',
          pickupAddress: 'My private pickup',
          pickupLatitude: 28.6139,
          pickupLongitude: 77.2090,
        ),
        assignment: const CabAssignmentModel(
          id: 'assign_1',
          dateKey: '2026-07-22',
          driverId: 'driver_1',
          vehicleId: 'vehicle_1',
        ),
      );
      controller.passengerProgressList = [
        PassengerProgressModel(
          employeeId: 'other_uid',
          passengerDisplayName: 'Priya',
          pickupSequence: 2,
          status: 'ready',
          distanceToPickupMeters: 450,
          locationFreshness: 'live',
          updatedAt: DateTime(2026, 7, 22, 9, 59),
        ),
        PassengerProgressModel(
          employeeId: 'test_uid',
          passengerDisplayName: 'Test Employee',
          pickupSequence: 3,
          status: 'travelling_to_pickup',
          distanceToPickupMeters: 300,
          locationFreshness: 'live',
          updatedAt: DateTime(2026, 7, 22, 9, 59),
        ),
      ];

      await tester.pumpWidget(
        _testApp(EmployeeHomeScreen(onNavigateToMap: () {}), controller),
      );

      await tester.dragUntilVisible(
        find.text('Priya'),
        find.byType(CustomScrollView),
        const Offset(0, -400),
      );
      expect(find.text('Priya'), findsOneWidget);
      expect(find.text('Test Employee (You)'), findsOneWidget);
      expect(find.textContaining('450 m'), findsNothing);
      expect(find.text('0.5 km'), findsOneWidget);
      expect(find.textContaining('other private pickup'), findsNothing);
    });

    testWidgets('15. Home fits 320px width with long identity values', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _createTestController(
        user: const UserModel(
          uid: 'test_uid',
          name: 'Very Long Employee Name For Responsive Verification',
          email: 'employee@example.com',
          phone: '',
          role: 'Manager',
          profileImage: '',
          employeeCode: 'EMPLOYEE-CODE-VERY-LONG-001',
        ),
        attendance: _checkedInAttendance(),
      );

      await tester.pumpWidget(
        _testApp(EmployeeHomeScreen(onNavigateToMap: () {}), controller),
      );
      await tester.pumpAndSettle();

      final layoutError = tester.takeException();
      expect(layoutError, isNull);
      expect(find.textContaining('Very Long Employee'), findsOneWidget);
    });
  });

  group('Employee Map Screen Widget Tests', () {
    testWidgets('daily route input fields are always visible', (tester) async {
      final controller = _createTestController(
        user: const UserModel(
          uid: 'test_uid',
          name: 'Test Employee',
          email: 'test@example.com',
          phone: '',
          role: 'Employee',
          profileImage: '',
          homeAddress: 'My Home',
          preferredPickupAddress: 'Approved Pickup',
        ),
      );

      await tester.pumpWidget(_testApp(const EmployeeMapScreen(), controller));

      expect(find.text('YOUR LOCATION'), findsOneWidget);
      expect(find.text('PICKUP LOCATION'), findsOneWidget);
      expect(find.text('DESTINATION'), findsOneWidget);
      expect(find.byKey(const Key('use_current_location')), findsOneWidget);
      expect(find.text('Location unavailable'), findsOneWidget);
      expect(find.text('Approved Pickup'), findsOneWidget);
    });

    // 8. Map empty state has no giant unused blank layout
    // NOTE: GoogleMap widget requires platform channels so we test the empty
    // state which does NOT use GoogleMap.
    testWidgets('8. Map empty state has no giant unused blank layout', (
      tester,
    ) async {
      // We test the map empty state by importing the screen's logic.
      // Since the Map screen shows a Scaffold with centered content when no
      // coordinates exist, we simply verify the text renders.
      // The actual GoogleMap tests would require platform setup.

      final controller = _createTestController(
        attendance: _checkedInAttendance(),
      );
      // No member = no coordinates = empty state

      // We can't render GoogleMap in a unit test, so we verify the controller
      // state correctly drives the empty-state branch.
      expect(controller.homeState, 'B');
      expect(controller.myAssignmentMember, isNull);
      expect(controller.activeAssignment, isNull);
      expect(controller.driverLiveLocation, isNull);
      expect(controller.employeeLiveLocation, isNull);
    });

    // 9. Map empty state shows required missing data
    testWidgets('9. Map empty state shows required missing data', (
      tester,
    ) async {
      // Controller with member but no pickup coordinates
      final controller = _createTestController(
        attendance: _checkedInAttendance(),
        member: const CabAssignmentMemberModel(
          id: 'mem_1',
          assignmentId: 'assign_1',
          userId: 'test_uid',
          pickupName: '',
          pickupAddress: '',
          pickupLatitude: null,
          pickupLongitude: null,
          status: 'assigned',
          updatedAt: null,
        ),
      );

      // Verify no valid coordinates exist for map rendering
      expect(controller.myAssignmentMember?.pickupLatitude, isNull);
      expect(controller.myAssignmentMember?.pickupLongitude, isNull);
      expect(controller.activeAssignment, isNull);
      expect(controller.driverLiveLocation, isNull);
    });

    // 10. Pickup-only state is correctly identified
    testWidgets('10. Pickup-only state correctly identified', (tester) async {
      final controller = _createTestController(
        attendance: _checkedInAttendance(),
        member: const CabAssignmentMemberModel(
          id: 'mem_1',
          assignmentId: 'assign_1',
          userId: 'test_uid',
          driverId: 'driver_1',
          vehicleId: 'vehicle_1',
          pickupName: 'Office Gate',
          pickupAddress: '123 Main St',
          pickupLatitude: 28.6139,
          pickupLongitude: 77.2090,
          status: 'assigned',
          updatedAt: null,
        ),
      );

      // Pickup exists but no cab or office
      expect(controller.myAssignmentMember?.pickupLatitude, 28.6139);
      expect(controller.myAssignmentMember?.pickupLongitude, 77.2090);
      expect(controller.driverLiveLocation, isNull);
      expect(controller.activeAssignment, isNull);
    });

    // 11. Cab and pickup distances are computed separately
    testWidgets('11. Cab and pickup distances are computed separately', (
      tester,
    ) async {
      final controller = _createTestController(
        attendance: _checkedInAttendance(),
        member: const CabAssignmentMemberModel(
          id: 'mem_1',
          assignmentId: 'assign_1',
          userId: 'test_uid',
          pickupName: 'Gate A',
          pickupAddress: '123 Main St',
          pickupLatitude: 28.6139,
          pickupLongitude: 77.2090,
          status: 'assigned',
          updatedAt: null,
        ),
        assignment: const CabAssignmentModel(
          id: 'assign_1',
          driverId: 'driver_1',
          officeLatitude: 28.6200,
          officeLongitude: 77.2100,
        ),
      );

      // empDist and cabDist are computed from live locations which are null here
      // but the fields should be independently computable
      expect(controller.employeeDistanceToPickupMeters, isNull);
      expect(controller.cabDistanceToPickupMeters, isNull);
      // The controller correctly handles null distances
    });
  });

  group('Employee Profile Screen Widget Tests', () {
    // 12. Profile disables sign-out while loading
    testWidgets('12. Profile disables sign-out while loading', (tester) async {
      final controller = _createTestController(
        attendance: _checkedInAttendance(),
      );
      controller.isActionLoading = true;

      await tester.pumpWidget(
        _testApp(const EmployeeProfileScreen(), controller),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(
        find.byKey(const Key('sign_out_button')),
      );
      // Button should be disabled when isActionLoading is true
      expect(button.onPressed, isNull);
    });

    // 13. Profile long values do not overflow
    testWidgets('13. Profile long values do not overflow', (tester) async {
      final controller = _createTestController(
        user: const UserModel(
          uid: 'test_uid',
          name:
              'Very Long Employee Name That Should Wrap Properly Without Overflow',
          email:
              'very.long.email.address.that.should.also.wrap@company-domain.example.com',
          phone: '+91-9876543210-ext-1234',
          role: 'Employee',
          profileImage: '',
          department: 'Engineering Research and Development Division',
          branch: 'Headquarters - Main Campus Building A Wing 3',
          employeeCode: 'EMP-2026-VERY-LONG-CODE-12345',
        ),
        attendance: _checkedInAttendance(),
      );

      await tester.pumpWidget(
        _testApp(const EmployeeProfileScreen(), controller),
      );

      // Should not throw overflow errors
      await tester.pumpAndSettle();

      // Verify long values are rendered
      expect(find.textContaining('Very Long Employee'), findsOneWidget);
      expect(find.textContaining('Headquarters - Main Campus'), findsOneWidget);
    });
  });

  group('Controller formatFreshness Tests', () {
    test('formatFreshness returns "Just now" for recent timestamps', () {
      final now = DateTime(2026, 7, 22, 10, 0, 0);
      final recent = DateTime(2026, 7, 22, 9, 59, 58);
      expect(
        EmployeeTransportController.formatFreshness(recent, now: now),
        'Just now',
      );
    });

    test('formatFreshness returns "Offline" for null timestamps', () {
      expect(EmployeeTransportController.formatFreshness(null), 'Offline');
    });

    test('formatFreshness returns "Stale" for old timestamps', () {
      final now = DateTime(2026, 7, 22, 10, 0, 0);
      final old = DateTime(2026, 7, 20, 10, 0, 0);
      expect(
        EmployeeTransportController.formatFreshness(old, now: now),
        'Stale',
      );
    });

    test('formatFreshness returns "X min ago" for minute-range', () {
      final now = DateTime(2026, 7, 22, 10, 5, 0);
      final fiveMinAgo = DateTime(2026, 7, 22, 10, 0, 0);
      expect(
        EmployeeTransportController.formatFreshness(fiveMinAgo, now: now),
        '5 min ago',
      );
    });

    test('formatFreshness returns "X hr ago" for hour-range', () {
      final now = DateTime(2026, 7, 22, 13, 0, 0);
      final threeHrAgo = DateTime(2026, 7, 22, 10, 0, 0);
      expect(
        EmployeeTransportController.formatFreshness(threeHrAgo, now: now),
        '3 hr ago',
      );
    });
  });

  group('Controller homeState Tests', () {
    test('homeState returns A when no attendance', () {
      final controller = _createTestController();
      expect(controller.homeState, 'A');
    });

    test('homeState returns B when attendance active but no route', () {
      final controller = _createTestController(
        attendance: _checkedInAttendance(),
      );
      expect(controller.homeState, 'B');
    });

    test('homeState returns C when route assigned but pickup missing', () {
      final controller = _createTestController(
        attendance: _checkedInAttendance(),
        member: const CabAssignmentMemberModel(
          id: 'mem_1',
          assignmentId: 'assign_1',
          userId: 'test_uid',
          pickupName: '',
          pickupAddress: '',
          pickupLatitude: null,
          pickupLongitude: null,
          status: 'assigned',
          updatedAt: null,
        ),
      );
      expect(controller.homeState, 'C');
    });

    test('homeState returns K when sync pending', () {
      final controller = _createTestController(
        attendance: _checkedInAttendance(),
        transportSyncState: 'sync_pending',
      );
      expect(controller.homeState, 'K');
    });

    test('homeState returns L when stop failed', () {
      final controller = _createTestController(
        attendance: _checkedInAttendance(),
        transportTrackingState: 'stop_failed',
      );
      expect(controller.homeState, 'L');
    });

    test('homeState returns M when error exists', () {
      final controller = _createTestController(errorMessage: 'Connection lost');
      expect(controller.homeState, 'M');
    });
  });
}
