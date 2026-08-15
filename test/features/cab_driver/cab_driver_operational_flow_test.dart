import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:officeroute/core/models/cab_assignment_model.dart';
import 'package:officeroute/core/models/cab_driver_shift_model.dart';
import 'package:officeroute/core/models/cab_trip_model.dart';
import 'package:officeroute/core/models/cab_trip_rider_model.dart';
import 'package:officeroute/core/models/user_model.dart';
import 'package:officeroute/features/cab_driver/cab_driver_operational_flow.dart';
import 'package:officeroute/features/cab_driver/controllers/cab_driver_controller.dart';

void main() {
  final now = DateTime(2026, 8, 4, 8, 42);

  CabDriverOperations operations() => CabDriverOperations(
    driver: const UserModel(
      uid: 'driver-1',
      name: 'Alex Driver',
      email: 'alex@example.com',
      phone: '',
      role: 'driver',
      profileImage: '',
    ),
    todayAssignment: const CabAssignmentModel(
      id: 'assignment-1',
      driverId: 'driver-1',
      officeName: 'Tech HQ Office',
      officeAddress: 'One Market Plaza',
    ),
    vehicle: null,
    shift: CabDriverShiftModel(
      id: 'shift-1',
      driverId: 'driver-1',
      shiftDate: '2026-08-04',
      shiftStart: now,
      shiftStatus: 'active',
    ),
    assignments: const [],
    trips: const [CabTripModel(id: 'trip-1', status: 'active')],
    activeTrip: const CabTripModel(id: 'trip-1', status: 'active'),
    members: const [],
    riders: const [
      CabTripRiderModel(
        employeeId: 'employee-1',
        status: 'ready',
        pickupOrder: 1,
      ),
    ],
    events: const [],
    employees: const {
      'employee-1': UserModel(
        uid: 'employee-1',
        name: 'Asha Patil',
        email: 'asha@example.com',
        phone: '',
        role: 'employee',
        profileImage: '',
      ),
    },
    locations: const {},
    loadedAt: now,
  );

  test('screens 14 through 36 have a complete stable catalog', () {
    expect(DriverOperationalPhase.values, hasLength(23));
    expect(DriverOperationalPhase.values.first.screenNumber, 14);
    expect(DriverOperationalPhase.values.last.screenNumber, 36);
    expect(
      DriverOperationalPhase.values.map((phase) => phase.screenNumber).toSet(),
      hasLength(23),
    );
  });

  testWidgets('screen 14 renders live pickup mission from operations data', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CabDriverOperationalFlow(data: operations())),
    );

    expect(find.text('Current Pickup'), findsOneWidget);
    expect(find.text('Asha Patil'), findsOneWidget);
    expect(find.text('MARK ARRIVED'), findsOneWidget);
  });

  testWidgets('screen 19 requires a skip reason before confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CabDriverOperationalFlow(
          data: operations(),
          initialPhase: DriverOperationalPhase.skipPassenger,
        ),
      ),
    );

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'CONFIRM SKIP'),
    );
    expect(button.onPressed, isNull);
    await tester.tap(find.text('Not at Pickup'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'CONFIRM SKIP'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('screen 23 gates office confirmation behind checklist', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CabDriverOperationalFlow(
          data: operations(),
          initialPhase: DriverOperationalPhase.officeArrival,
        ),
      ),
    );

    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'CONFIRM OFFICE ARRIVAL'),
          )
          .onPressed,
      isNull,
    );
    for (final label in const [
      'All passengers dropped',
      'Vehicle empty',
      'Digital log updated',
    ]) {
      await tester.tap(find.text(label));
      await tester.pump();
    }
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'CONFIRM OFFICE ARRIVAL'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('recovery and safety states expose explicit actions', (
    tester,
  ) async {
    for (final phase in const [
      DriverOperationalPhase.gpsDisabled,
      DriverOperationalPhase.permissionRequired,
      DriverOperationalPhase.offlinePendingSync,
      DriverOperationalPhase.recoverTrip,
      DriverOperationalPhase.assignmentCancelled,
      DriverOperationalPhase.queryFailure,
      DriverOperationalPhase.emergencySupport,
      DriverOperationalPhase.notificationDetail,
      DriverOperationalPhase.signOutConfirmation,
      DriverOperationalPhase.newDayReset,
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: CabDriverOperationalFlow(
            data: operations(),
            initialPhase: phase,
          ),
        ),
      );
      expect(find.text(phase.title), findsWidgets);
    }
  });
}
