import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:officeroute/core/models/cab_assignment_member_model.dart';
import 'package:officeroute/core/models/cab_assignment_model.dart';
import 'package:officeroute/core/models/cab_trip_model.dart';
import 'package:officeroute/core/models/cab_vehicle_model.dart';
import 'package:officeroute/core/models/live_location_model.dart';
import 'package:officeroute/core/models/location_permission_state_model.dart';
import 'package:officeroute/core/models/passenger_progress_model.dart';
import 'package:officeroute/core/models/user_model.dart';
import 'package:officeroute/features/employee/controllers/employee_transport_controller.dart';
import 'package:officeroute/features/employee/employee_app.dart';
import 'package:officeroute/features/employee/employee_map_screen.dart';
import 'package:officeroute/features/employee/widgets/employee_map_status_view.dart';
import 'package:officeroute/features/employee/widgets/employee_map_transport_sheet.dart';

const _member = CabAssignmentMemberModel(
  id: 'member_self',
  assignmentId: 'assignment_1',
  dateKey: '2026-07-30',
  userId: 'self',
  driverId: 'driver_1',
  vehicleId: 'vehicle_1',
  pickupName: 'North Gate',
  pickupAddress: 'Approved pickup address',
  pickupLatitude: 12.9719,
  pickupLongitude: 77.5949,
);

const _assignment = CabAssignmentModel(
  id: 'assignment_1',
  dateKey: '2026-07-30',
  driverId: 'driver_1',
  vehicleId: 'vehicle_1',
  employeeIds: ['self', 'admin_1', 'manager_1'],
  officeName: 'Office HQ',
  officeAddress: 'Office destination address',
  officeLatitude: 12.9850,
  officeLongitude: 77.6050,
);

const _trip = CabTripModel(
  id: 'trip_1',
  assignmentId: 'assignment_1',
  driverId: 'driver_1',
  vehicleId: 'vehicle_1',
  status: 'active',
);

EmployeeTransportController _controller({
  CabAssignmentMemberModel? member,
  CabAssignmentModel? assignment,
  CabTripModel? trip,
}) {
  final controller = EmployeeTransportController(
    initListeners: false,
    currentUidGetter: () => 'self',
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
    clock: () => DateTime(2026, 7, 30, 10),
  );
  controller.currentUser = const UserModel(
    uid: 'self',
    name: 'Appu Employee',
    email: 'appu@example.com',
    phone: '',
    role: 'Employee',
    profileImage: '',
    employeeCode: 'EMP-001',
    homeAddress: 'Private home must not be used as live location',
    preferredPickupAddress: 'Saved pickup address',
    preferredPickupLatitude: 12.9722,
    preferredPickupLongitude: 77.5952,
  );
  controller.myAssignmentMember = member;
  controller.activeAssignment = assignment;
  controller.activeTrip = trip;
  controller.isLoading = false;
  controller.locationPermissionStatus = 'Granted';
  return controller;
}

LiveLocationModel _location({
  required String userId,
  required double latitude,
  required double longitude,
  DateTime? updatedAt,
}) {
  final timestamp = updatedAt ?? DateTime(2026, 7, 30, 9, 59, 30);
  return LiveLocationModel(
    userId: userId,
    sessionId: 'session_$userId',
    assignmentId: 'assignment_1',
    trackingReason: userId == 'self' ? 'employee_transport' : 'cab_trip',
    status: 'active',
    latitude: latitude,
    longitude: longitude,
    accuracy: 8,
    altitude: 0,
    speed: 0,
    heading: 0,
    isForeground: true,
    source: 'geolocator',
    syncStatus: 'synced',
    recordedAt: timestamp,
    updatedAt: timestamp,
  );
}

List<PassengerProgressModel> _roster({bool authoritativeEta = true}) => [
  PassengerProgressModel(
    employeeId: 'self',
    passengerDisplayName: 'Appu Employee',
    employeeCode: 'EMP-001',
    roleLabel: 'Employee',
    pickupSequence: 1,
    status: 'ready',
    attendanceActive: true,
    distanceToPickupMeters: 42,
    estimatedReadyMinutes: authoritativeEta ? 7 : null,
    locationFreshness: 'live',
  ),
  const PassengerProgressModel(
    employeeId: 'admin_1',
    passengerDisplayName: 'Jayanth Admin',
    roleLabel: 'Administrator',
    pickupSequence: 2,
    status: 'on_the_way',
    attendanceActive: true,
    distanceToPickupMeters: 1234,
    estimatedReadyMinutes: 13,
    locationFreshness: 'live',
  ),
  const PassengerProgressModel(
    employeeId: 'manager_1',
    passengerDisplayName: 'Meera Manager',
    roleLabel: 'Manager',
    pickupSequence: 3,
    status: 'waiting',
    attendanceActive: true,
    locationFreshness: 'stale',
  ),
];

Widget _mapApp(
  EmployeeTransportController controller, {
  ValueChanged<Set<Marker>>? onMarkers,
}) {
  return MaterialApp(
    home: EmployeeTransportScope(
      controller: controller,
      child: EmployeeMapScreen(
        mapSurfaceBuilder:
            (
              context, {
              required initialCameraPosition,
              required markers,
              required onMapCreated,
            }) {
              onMarkers?.call(markers);
              return const ColoredBox(
                key: Key('fake_map_surface'),
                color: Colors.black,
              );
            },
      ),
    ),
  );
}

void main() {
  group('Employee Map status resolver', () {
    test('distinguishes loading, no route, GPS, permission and failures', () {
      final controller = _controller();
      addTearDown(controller.dispose);

      controller.isLoading = true;
      expect(EmployeeMapStatus.fromController(controller).code, 'loading');
      controller.isLoading = false;
      expect(EmployeeMapStatus.fromController(controller).code, 'no_route');

      controller.locationPermissionState = LocationPermissionStateModel(
        serviceEnabled: false,
        permissionStatus: 'denied',
        canRequestPermission: true,
        canUseForegroundLocation: false,
        canUseBackgroundLocation: false,
        permanentlyDenied: false,
        message: 'GPS disabled',
        checkedAt: DateTime(2026, 7, 30),
      );
      expect(EmployeeMapStatus.fromController(controller).code, 'gps_disabled');

      controller.locationPermissionState = LocationPermissionStateModel(
        serviceEnabled: true,
        permissionStatus: 'denied',
        canRequestPermission: true,
        canUseForegroundLocation: false,
        canUseBackgroundLocation: false,
        permanentlyDenied: false,
        message: 'Permission denied',
        checkedAt: DateTime(2026, 7, 30),
      );
      expect(
        EmployeeMapStatus.fromController(controller).code,
        'permission_denied',
      );

      controller.locationPermissionState = null;
      controller.locationPermissionStatus = 'Granted';
      controller.errorMessage = 'network offline';
      expect(EmployeeMapStatus.fromController(controller).code, 'offline');
      controller.errorMessage = 'query failed unexpectedly';
      expect(EmployeeMapStatus.fromController(controller).code, 'query_failed');
    });

    test('distinguishes missing configuration, pre-trip and stale data', () {
      final controller = _controller(
        member: const CabAssignmentMemberModel(
          id: 'member_self',
          assignmentId: 'assignment_1',
          userId: 'self',
        ),
      );
      addTearDown(controller.dispose);
      expect(
        EmployeeMapStatus.fromController(controller).code,
        'pickup_missing',
      );

      controller.myAssignmentMember = _member;
      controller.activeAssignment = const CabAssignmentModel(
        id: 'assignment_1',
        driverId: 'driver_1',
        vehicleId: 'vehicle_1',
      );
      expect(
        EmployeeMapStatus.fromController(controller).code,
        'destination_missing',
      );

      controller.activeAssignment = const CabAssignmentModel(
        id: 'assignment_1',
        vehicleId: 'vehicle_1',
        officeLatitude: 12.985,
        officeLongitude: 77.605,
      );
      expect(
        EmployeeMapStatus.fromController(controller).code,
        'driver_not_assigned',
      );

      controller.activeAssignment = const CabAssignmentModel(
        id: 'assignment_1',
        driverId: 'driver_1',
        officeLatitude: 12.985,
        officeLongitude: 77.605,
      );
      expect(
        EmployeeMapStatus.fromController(controller).code,
        'vehicle_not_assigned',
      );

      controller.activeAssignment = _assignment;
      expect(
        EmployeeMapStatus.fromController(controller).code,
        'no_active_trip',
      );

      controller.activeTrip = _trip;
      controller.employeeLiveLocation = _location(
        userId: 'self',
        latitude: 12.9716,
        longitude: 77.5946,
        updatedAt: DateTime(2026, 7, 30, 9, 55),
      );
      expect(
        EmployeeMapStatus.fromController(controller).code,
        'stale_employee',
      );

      controller.employeeLiveLocation = _location(
        userId: 'self',
        latitude: 12.9716,
        longitude: 77.5946,
      );
      expect(
        EmployeeMapStatus.fromController(controller).code,
        'cab_location_unavailable',
      );
    });
  });

  testWidgets('renders truthful no-route state with a retry control', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_mapApp(controller));
    await tester.pump();

    expect(
      find.byKey(const Key('employee_map_sheet_state_no_route')),
      findsOneWidget,
    );
    expect(find.text('No route configured today'), findsWidgets);
    expect(
      find.byKey(const Key('employee_map_sheet_retry_no_route')),
      findsOneWidget,
    );
    expect(find.textContaining('Private home'), findsNothing);
  });

  testWidgets('renders only permitted markers and truthful transport details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 884));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _controller(
      member: _member,
      assignment: _assignment,
      trip: _trip,
    );
    addTearDown(controller.dispose);
    controller.employeeLiveLocation = _location(
      userId: 'self',
      latitude: 12.9716,
      longitude: 77.5946,
    );
    controller.driverLiveLocation = _location(
      userId: 'driver_1',
      latitude: 12.9680,
      longitude: 77.5900,
    );
    controller.assignedDriver = const UserModel(
      uid: 'driver_1',
      name: 'Ravi Driver',
      email: '',
      phone: 'private-number',
      role: 'Driver',
      profileImage: '',
    );
    controller.assignedVehicle = const CabVehicleModel(
      id: 'vehicle_1',
      vehicleNumber: 'CAB-07',
      vehicleModel: 'Sedan',
      registrationNumber: 'KA01AB1234',
      status: 'assigned',
    );
    controller.passengerProgressList = _roster();
    Set<Marker> captured = {};

    await tester.pumpWidget(
      _mapApp(controller, onMarkers: (markers) => captured = markers),
    );
    await tester.pump();

    expect(find.byKey(const Key('fake_map_surface')), findsOneWidget);
    expect(captured.map((marker) => marker.markerId.value).toSet(), {
      'signed_in_employee',
      'employee_saved_pickup',
      'current_operational_pickup',
      'assigned_cab',
      'office_destination',
    });
    expect(find.byKey(const Key('map_sheet_title')), findsOneWidget);
    expect(find.text('CAB DISTANCE'), findsOneWidget);
    expect(find.text('YOUR DISTANCE'), findsOneWidget);
    expect(find.text('7 min'), findsAtLeastNWidgets(1));
    expect(find.byKey(const Key('map_current_pickup')), findsOneWidget);
    expect(find.byKey(const Key('map_next_pickup')), findsOneWidget);
    expect(find.textContaining('private-number'), findsNothing);
    expect(find.textContaining('Private home'), findsNothing);
    expect(find.textContaining('straight-line'), findsOneWidget);
    expect(find.textContaining('traffic ETA are unavailable'), findsOneWidget);

    final sheet = find.byKey(const Key('employee_map_transport_sheet'));
    final sheetList = find.descendant(
      of: sheet,
      matching: find.byType(ListView),
    );
    await tester.drag(sheetList, const Offset(0, -460));
    await tester.pumpAndSettle();
    expect(find.text('Ravi Driver'), findsOneWidget);
    await tester.drag(sheetList, const Offset(0, -420));
    await tester.pumpAndSettle();

    expect(find.text('Jayanth Admin'), findsOneWidget);
    expect(find.text('Meera Manager'), findsOneWidget);
    expect(
      find.byKey(const Key('update_transport_status_button')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps configured participants before trip and ETA unavailable', (
    tester,
  ) async {
    final controller = _controller(member: _member, assignment: _assignment);
    addTearDown(controller.dispose);
    controller.passengerProgressList = _roster(authoritativeEta: false);

    await tester.pumpWidget(_mapApp(controller));
    await tester.pump();

    expect(find.text('Trip not started'), findsAtLeastNWidgets(1));
    expect(find.text('Unavailable'), findsWidgets);

    final sheet = find.byKey(const Key('employee_map_transport_sheet'));
    final sheetList = find.descendant(
      of: sheet,
      matching: find.byType(ListView),
    );
    await tester.drag(sheetList, const Offset(0, -460));
    await tester.pumpAndSettle();
    await tester.drag(sheetList, const Offset(0, -420));
    await tester.pumpAndSettle();

    expect(
      find.text('Configured route members before trip start'),
      findsOneWidget,
    );
    expect(find.text('Jayanth Admin'), findsOneWidget);
    expect(find.text('Meera Manager'), findsOneWidget);
    expect(
      find.byKey(const Key('update_transport_status_button')),
      findsNothing,
    );
  });

  testWidgets('requested Android sizes and long addresses do not overflow', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _controller(
      member: _member,
      assignment: _assignment,
      trip: _trip,
    );
    addTearDown(controller.dispose);
    controller.passengerProgressList = _roster();
    controller.currentUser = const UserModel(
      uid: 'self',
      name: 'Appu Employee With A Long Responsive Display Name',
      email: 'appu@example.com',
      phone: '',
      role: 'Employee',
      profileImage: '',
      preferredPickupAddress:
          'Long saved pickup address near the north entrance and service road',
      preferredPickupLatitude: 12.9722,
      preferredPickupLongitude: 77.5952,
    );
    controller.myAssignmentMember = _member.copyWith(
      pickupAddress:
          'Long assigned pickup address beside the north security entrance',
    );
    controller.activeAssignment = _assignment.copyWith(
      officeAddress:
          'Long office destination address in the central business district',
    );

    for (final size in const [
      Size(320, 800),
      Size(360, 800),
      Size(390, 884),
      Size(412, 915),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(_mapApp(controller));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'overflow at $size');
    }

    await tester.pumpWidget(_mapApp(controller));
    await tester.pump();

    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home Map Profile navigation preserves the Map State object', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: EmployeeApp(controller: controller)),
    );
    await tester.pump();

    final mapFinder = find.byType(EmployeeMapScreen, skipOffstage: false);
    final originalState = tester.state(mapFinder);
    await tester.tap(find.widgetWithText(InkWell, 'Map'));
    await tester.pump();
    await tester.tap(find.widgetWithText(InkWell, 'Profile'));
    await tester.pump();
    await tester.tap(find.widgetWithText(InkWell, 'Home'));
    await tester.pump();

    expect(tester.state(mapFinder), same(originalState));
    expect(find.byKey(const Key('employee_tab_stack')), findsOneWidget);
  });

  test('privacy sanitizer rounds only other participants', () {
    final safe = employeeMapPrivacySafeRoster(_roster(), 'self');
    expect(safe.first.distanceToPickupMeters, 42);
    expect(safe.first.estimatedReadyMinutes, 7);
    expect(safe[1].distanceToPickupMeters, 1200);
    expect(safe[1].estimatedReadyMinutes, 15);
    expect(employeeMapFormatDistance(null), 'Unavailable');
  });
}
