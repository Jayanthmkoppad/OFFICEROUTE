import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:officeroute/core/models/cab_assignment_member_model.dart';
import 'package:officeroute/core/models/cab_driver_shift_model.dart';
import 'package:officeroute/core/models/cab_trip_cancellation.dart';
import 'package:officeroute/core/models/cab_vehicle_model.dart';
import 'package:officeroute/core/models/live_location_model.dart';
import 'package:officeroute/core/models/office_destination.dart';
import 'package:officeroute/core/models/user_model.dart';
import 'package:officeroute/features/cab_driver/cab_driver_app.dart';
import 'package:officeroute/features/cab_driver/controllers/cab_driver_controller.dart';

void main() {
  final now = DateTime(2026, 8, 9, 9);

  UserModel driver({
    String officeName = 'Configured Office',
    String officeAddress = '1 Operations Campus',
    double? officeLatitude = 15.3647,
    double? officeLongitude = 75.1240,
  }) {
    return UserModel(
      uid: 'driver-1',
      name: 'Driver',
      email: 'driver@example.com',
      phone: '',
      role: 'driver',
      profileImage: '',
      branch: 'Hubballi',
      serviceCentre: 'Central',
      officeName: officeName,
      officeAddress: officeAddress,
      officeLatitude: officeLatitude,
      officeLongitude: officeLongitude,
    );
  }

  CabDriverOperations operations(
    UserModel configuredDriver, {
    List<CabAssignmentMemberModel>? invitations,
  }) {
    return CabDriverOperations(
      driver: configuredDriver,
      todayAssignment: null,
      vehicle: const CabVehicleModel(
        id: 'vehicle-1',
        vehicleNumber: 'OR-1',
        registrationNumber: 'OR-1',
      ),
      shift: CabDriverShiftModel(
        id: '2026-08-09_driver-1',
        driverId: 'driver-1',
        vehicleId: 'vehicle-1',
        shiftDate: '2026-08-09',
        shiftStatus: 'active',
        shiftStart: now,
      ),
      assignments: const [],
      trips: const [],
      activeTrip: null,
      members: const [],
      riders: const [],
      events: const [],
      employees: const {},
      locations: {
        'driver-1': LiveLocationModel(
          userId: 'driver-1',
          sessionId: 'session-1',
          trackingReason: 'field_duty',
          latitude: 15.36,
          longitude: 75.12,
          accuracy: 5,
          altitude: 0,
          speed: 0,
          heading: 0,
          status: 'active',
          syncStatus: 'synced',
          source: 'device',
          isForeground: true,
          recordedAt: now,
          updatedAt: now,
        ),
      },
      loadedAt: now,
      invitations:
          invitations ??
          const [
            CabAssignmentMemberModel(
              id: '2026-08-09_employee-1',
              dateKey: '2026-08-09',
              userId: 'employee-1',
              role: 'employee',
              branch: 'Hubballi',
              serviceCentre: 'Central',
              driverId: 'driver-1',
              vehicleId: 'vehicle-1',
              status: 'accepted',
              invitationStatus: 'accepted',
              pickupName: 'Approved pickup',
              pickupAddress: 'Employee gate',
              pickupLatitude: 15.35,
              pickupLongitude: 75.11,
            ),
          ],
    );
  }

  group('Office destination finalization', () {
    test('configured Driver destination is valid', () {
      final destination = OfficeDestination.fromDriver(driver());
      expect(destination, isNotNull);
      expect(destination!.name, 'Configured Office');
      expect(destination.address, '1 Operations Campus');
      expect(destination.latitude, 15.3647);
      expect(destination.longitude, 75.1240);
    });

    test('missing destination is rejected', () {
      expect(
        OfficeDestination.fromDriver(
          driver(
            officeAddress: '',
            officeLatitude: null,
            officeLongitude: null,
          ),
        ),
        isNull,
      );
    });

    for (final malformed in <({double latitude, double longitude})>[
      (latitude: 91, longitude: 75),
      (latitude: 15, longitude: 181),
    ]) {
      test('malformed coordinates are rejected: $malformed', () {
        expect(
          OfficeDestination.fromDriver(
            driver(
              officeLatitude: malformed.latitude,
              officeLongitude: malformed.longitude,
            ),
          ),
          isNull,
        );
      });
    }

    test('configured destination enables Start Trip eligibility', () {
      expect(CabDriverController.canStartTrip(operations(driver())), isTrue);
    });

    test('missing destination blocks Start Trip eligibility', () {
      final data = operations(
        driver(officeAddress: '', officeLatitude: null, officeLongitude: null),
      );
      expect(CabDriverController.canStartTrip(data), isFalse);
    });

    test('zero accepted invitations explains disabled Start Trip', () {
      final data = operations(driver(), invitations: const []);
      expect(CabDriverController.canStartTrip(data), isFalse);
      expect(
        CabDriverController.startTripBlockedReason(data),
        'Waiting for at least one Employee to accept',
      );
    });

    test('accepted invitation without pickup explains disabled Start Trip', () {
      final data = operations(
        driver(),
        invitations: const [
          CabAssignmentMemberModel(
            id: '2026-08-09_employee-1',
            dateKey: '2026-08-09',
            userId: 'employee-1',
            role: 'employee',
            branch: 'Hubballi',
            serviceCentre: 'Central',
            driverId: 'driver-1',
            vehicleId: 'vehicle-1',
            status: 'accepted',
            invitationStatus: 'accepted',
          ),
        ],
      );
      expect(CabDriverController.canStartTrip(data), isFalse);
      expect(
        CabDriverController.startTripBlockedReason(data),
        '1 accepted Employee(s) still need a pickup location',
      );
    });
    testWidgets('missing destination disables review and shows exact message', (
      tester,
    ) async {
      final data = operations(
        driver(officeAddress: '', officeLatitude: null, officeLongitude: null),
      );
      await tester.pumpWidget(
        MaterialApp(home: DriverPassengerSelectionScreen(data: data)),
      );
      expect(find.text('REVIEW 1 ACCEPTED / START TRIP'), findsOneWidget);
      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'REVIEW 1 ACCEPTED / START TRIP'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('configured destination enables passenger review', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DriverPassengerSelectionScreen(data: operations(driver())),
        ),
      );
      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'REVIEW 1 ACCEPTED / START TRIP'),
      );
      expect(button.onPressed, isNotNull);
    });
  });

  group('Trip cancellation contract', () {
    test('all required reasons are present', () {
      expect(
        CabTripCancellationReason.values.map((value) => value.label),
        containsAll(<String>[
          'Vehicle breakdown',
          'Operational instruction',
          'Safety issue',
          'Route inaccessible',
          'Trip created in error',
          'Other',
        ]),
      );
    });

    test('Other requires free-text explanation', () {
      expect(
        () => const CabTripCancellation(
          reason: CabTripCancellationReason.other,
        ).validate(),
        throwsStateError,
      );
      expect(
        () => const CabTripCancellation(
          reason: CabTripCancellationReason.other,
          explanation: 'Road closure reported by Operations',
        ).validate(),
        returnsNormally,
      );
    });
  });

  test(
    'real Driver directory keeps same branch or authorised service centre only',
    () {
      final actualDriver = driver();
      final candidates = [
        const UserModel(
          uid: 'same-branch',
          name: 'A',
          email: '',
          phone: '',
          role: 'Employee',
          profileImage: '',
          branch: 'Hubballi',
        ),
        const UserModel(
          uid: 'same-centre',
          name: 'B',
          email: '',
          phone: '',
          role: 'employee',
          profileImage: '',
          serviceCentre: 'Central',
        ),
        const UserModel(
          uid: 'unrelated',
          name: 'C',
          email: '',
          phone: '',
          role: 'employee',
          profileImage: '',
          branch: 'Other',
          serviceCentre: 'Other',
        ),
        const UserModel(
          uid: 'driver-1',
          name: 'Self',
          email: '',
          phone: '',
          role: 'Employee',
          profileImage: '',
          branch: 'Hubballi',
        ),
      ];
      final result = CabDriverController.filterEligibleEmployees(
        driver: actualDriver,
        candidates: candidates,
      );
      expect(result.map((item) => item.uid), ['same-branch', 'same-centre']);
      expect(result.any((item) => item.uid == 'unrelated'), isFalse);
      expect(result.any((item) => item.uid == actualDriver.uid), isFalse);
    },
  );
}
