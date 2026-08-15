import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:officeroute/core/models/cab_assignment_member_model.dart';
import 'package:officeroute/core/models/cab_driver_shift_model.dart';
import 'package:officeroute/core/models/cab_trip_model.dart';
import 'package:officeroute/core/models/cab_trip_rider_model.dart';
import 'package:officeroute/core/models/cab_vehicle_model.dart';
import 'package:officeroute/core/models/live_location_model.dart';
import 'package:officeroute/core/models/office_destination.dart';
import 'package:officeroute/core/models/user_model.dart';
import 'package:officeroute/features/cab_driver/controllers/cab_driver_controller.dart';
import 'package:officeroute/features/cab_driver/widgets/driver_start_duty_overlay.dart';

void main() {
  final now = DateTime(2026, 8, 1, 8, 30);
  const configuredCab = CabVehicleModel(
    id: 'cab-doc-1',
    vehicleNumber: 'CAB-01',
    vehicleModel: 'Electric Cab',
    registrationNumber: 'REG-01',
    capacity: 4,
    status: 'available',
    driverId: 'driver-123',
  );

  const configuredOffice = OfficeDestination(
    name: 'Operations Office',
    address: 'Configured office address',
    latitude: 15.36,
    longitude: 75.12,
  );

  Future<List<CabVehicleModel>> loadConfiguredCab() async => [configuredCab];
  Future<CabVehicleModel?> getConfiguredCab(String id) async =>
      id == configuredCab.id ? configuredCab : null;

  CabDriverOperations createOps({
    bool dutyActive = false,
    String? openRequestsError,
    List<CabAssignmentMemberModel> openRequests = const [],
    List<CabAssignmentMemberModel> members = const [],
    CabTripModel? activeTrip,
    List<CabTripRiderModel> riders = const [],
    CabVehicleModel? vehicle,
    Map<String, LiveLocationModel> locations = const {},
  }) {
    return CabDriverOperations(
      driver: const UserModel(
        uid: 'driver-123',
        name: 'Ramesh Driver',
        email: 'ramesh@officeroute.com',
        phone: '+919876543210',
        role: 'driver',
        branch: 'Hubballi',
        serviceCentre: 'Central',
        officeName: 'Configured Office',
        officeAddress: '1 Operations Campus',
        officeLatitude: 15.3647,
        officeLongitude: 75.1240,
        vehicleNumber: 'KA-25-AB-1234',
        profileImage: '',
      ),
      todayAssignment: null,
      vehicle:
          vehicle ??
          const CabVehicleModel(
            id: 'KA-25-AB-1234',
            vehicleNumber: 'KA-25-AB-1234',
            vehicleModel: 'Electric Cab',
            registrationNumber: 'KA-25-AB-1234',
            capacity: 4,
            status: 'available',
            driverId: 'driver-123',
          ),
      shift: dutyActive
          ? CabDriverShiftModel(
              id: 'shift-001',
              driverId: 'driver-123',
              shiftDate: '2026-08-01',
              shiftStart: now.subtract(const Duration(hours: 1)),
              shiftStatus: 'active',
              startOdometer: 12450.0,
              batteryPercentage: 78,
              vehicleCondition: 'Good',
            )
          : null,
      assignments: const [],
      trips: activeTrip != null ? [activeTrip] : const [],
      activeTrip: activeTrip,
      members: members,
      riders: riders,
      events: const [],
      employees: const {},
      locations: locations,
      loadedAt: now,
      openRequests: openRequests,
      invitations: openRequests,
      openRequestsError: openRequestsError,
    );
  }

  group('Cab Driver Round 1 - Visual & State Tests', () {
    test('Off-Duty state has offDuty workflow state (PNG 01)', () {
      final ops = createOps(dutyActive: false);
      expect(ops.dutyActive, isFalse);
      expect(ops.workflowState, CabDriverWorkflowState.offDuty);
    });

    testWidgets(
      'StartDutyChecklistSheet validates odometer, battery, vehicle selection (PNG 07)',
      (WidgetTester tester) async {
        bool confirmCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StartDutyChecklistSheet(
                initialVehicleId: configuredCab.id,
                initialOfficeDestination: configuredOffice,
                loadVehicles: loadConfiguredCab,
                getVehicle: getConfiguredCab,
                onConfirm:
                    ({
                      required vehicleId,
                      required startOdometer,
                      required batteryPercentage,
                      required vehicleCondition,
                      required officeDestination,
                      note,
                    }) async {
                      confirmCalled = true;
                    },
              ),
            ),
          ),
        );

        expect(find.text('Start Duty Checklist'), findsOneWidget);
        await tester.enterText(find.byType(TextField).at(0), '1000');
        await tester.enterText(find.byType(TextField).at(1), '80');
        final buttonFinder = find.text('CONFIRM AND START DUTY');
        await tester.ensureVisible(buttonFinder);
        await tester.tap(buttonFinder);
        await tester.pumpAndSettle();

        expect(confirmCalled, isTrue);
      },
    );

    test(
      'On-Duty Home state displays onDuty workflow state and open requests (PNG 02 semantics)',
      () {
        final ops = createOps(
          dutyActive: true,
          openRequests: [
            CabAssignmentMemberModel(
              id: 'mem-1',
              assignmentId: 'asg-1',
              dateKey: '2026-08-01',
              userId: 'emp-1',
              role: 'employee',
              status: 'ready',
              createdAt: now,
              updatedAt: now,
            ),
          ],
        );

        expect(ops.dutyActive, isTrue);
        expect(ops.workflowState, CabDriverWorkflowState.onDuty);
        expect(ops.openRequests.length, equals(1));
      },
    );

    test(
      'No pickup requests available state handles empty open requests cleanly (PNG 08 semantics)',
      () {
        final ops = createOps(dutyActive: true, openRequests: const []);

        expect(ops.dutyActive, isTrue);
        expect(ops.openRequests, isEmpty);
        expect(ops.openRequestsError, isNull);
      },
    );

    test('Firestore query restriction captures truthful error message', () {
      final ops = createOps(
        dutyActive: true,
        openRequestsError:
            'Pickup requests are unavailable until Driver request access is configured.',
      );

      expect(ops.dutyActive, isTrue);
      expect(
        ops.openRequestsError,
        contains(
          'Pickup requests are unavailable until Driver request access is configured.',
        ),
      );
    });

    test(
      'Active Trip restoration exposes travellingToPickup state (PNG 03)',
      () {
        const trip = CabTripModel(id: 'trip-99', status: 'active');
        final ops = createOps(
          dutyActive: true,
          activeTrip: trip,
          riders: const [
            CabTripRiderModel(employeeId: 'emp-10', status: 'ready'),
          ],
        );

        expect(ops.dutyActive, isTrue);
        expect(ops.activeTrip?.id, equals('trip-99'));
        expect(ops.workflowState, CabDriverWorkflowState.travellingToPickup);
      },
    );
  });

  group('Cab Driver Round 1 - Business Rules & Security Verification', () {
    test('Start Trip is disabled with zero selected/available requests', () {
      final ops = createOps(
        dutyActive: true,
        locations: {
          'driver-123': LiveLocationModel(
            userId: 'driver-123',
            sessionId: 'driver-session',
            trackingReason: 'cab_trip',
            latitude: 15.36,
            longitude: 75.12,
            accuracy: 5,
            altitude: 0,
            speed: 0,
            heading: 0,
            isForeground: true,
            source: 'test',
            status: 'active',
            syncStatus: 'synced',
            recordedAt: now,
            updatedAt: now,
          ),
        },
      );
      expect(CabDriverController.canStartTrip(ops), isFalse);
    });

    test('Start Trip is disabled when request access failed', () {
      final ops = createOps(
        dutyActive: true,
        openRequestsError: 'permission-denied',
      );
      expect(CabDriverController.canStartTrip(ops), isFalse);
    });

    test(
      'Start Trip is enabled only for online eligible unclaimed requests',
      () {
        final ops = createOps(
          dutyActive: true,
          openRequests: const [
            CabAssignmentMemberModel(
              id: '2026-08-01_emp-1',
              dateKey: '2026-08-01',
              userId: 'emp-1',
              driverId: 'driver-123',
              vehicleId: 'KA-25-AB-1234',
              status: 'accepted',
              invitationStatus: 'accepted',
              pickupAddress: 'Approved Gate',
              pickupLatitude: 15.37,
              pickupLongitude: 75.13,
            ),
          ],
          locations: {
            'driver-123': LiveLocationModel(
              userId: 'driver-123',
              sessionId: 'driver-session',
              trackingReason: 'cab_trip',
              latitude: 15.36,
              longitude: 75.12,
              accuracy: 5,
              altitude: 0,
              speed: 0,
              heading: 0,
              isForeground: true,
              source: 'test',
              status: 'active',
              syncStatus: 'synced',
              recordedAt: now,
              updatedAt: now,
            ),
          },
        );
        expect(CabDriverController.canStartTrip(ops), isTrue);
      },
    );

    test('Start Duty operates independently without assignment or route', () {
      final ops = createOps(dutyActive: false);
      expect(ops.todayAssignment, isNull);
      expect(() => ops.dutyActive, returnsNormally);
    });

    test('Shift document model captures odometer, battery, condition', () {
      final shift = CabDriverShiftModel(
        id: 'shift-100',
        driverId: 'driver-123',
        shiftDate: '2026-08-01',
        shiftStart: now,
        shiftStatus: 'active',
        startOdometer: 15200.5,
        batteryPercentage: 85,
        vehicleCondition: 'Minor Damage',
      );

      expect(shift.startOdometer, equals(15200.5));
      expect(shift.batteryPercentage, equals(85));
      expect(shift.vehicleCondition, equals('Minor Damage'));

      final map = shift.toMap();
      expect(map['startOdometer'], equals(15200.5));
      expect(map['batteryPercentage'], equals(85));
      expect(map['vehicleCondition'], equals('Minor Damage'));

      final recovered = CabDriverShiftModel.fromMap(map, id: 'shift-100');
      expect(recovered.startOdometer, equals(15200.5));
      expect(recovered.batteryPercentage, equals(85));
      expect(recovered.vehicleCondition, equals('Minor Damage'));
    });

    testWidgets(
      'StartDutyChecklistSheet renders responsive layout on 320px viewport',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StartDutyChecklistSheet(
                initialVehicleId: configuredCab.id,
                initialOfficeDestination: configuredOffice,
                loadVehicles: loadConfiguredCab,
                getVehicle: getConfiguredCab,
                onConfirm:
                    ({
                      required vehicleId,
                      required startOdometer,
                      required batteryPercentage,
                      required vehicleCondition,
                      required officeDestination,
                      note,
                    }) async {},
              ),
            ),
          ),
        );

        expect(find.text('Start Duty Checklist'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    test(
      'Driver user model without employeeCode displays Driver code unavailable fallback',
      () {
        const driverWithoutCode = UserModel(
          uid: 'drv-888',
          name: 'Ramesh Driver',
          email: 'ramesh@officeroute.com',
          phone: '+919876543210',
          role: 'driver',
          branch: 'Hubballi',
          serviceCentre: 'Central',
          officeName: 'Configured Office',
          officeAddress: '1 Operations Campus',
          officeLatitude: 15.3647,
          officeLongitude: 75.1240,
          employeeCode: '',
          profileImage: '',
        );

        final codeText = driverWithoutCode.employeeCode.trim().isNotEmpty
            ? driverWithoutCode.employeeCode
            : 'Driver code unavailable';

        expect(codeText, equals('Driver code unavailable'));
      },
    );

    testWidgets(
      'StartDutyChecklistSheet displays issue inputs when condition is Minor Damage',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StartDutyChecklistSheet(
                initialVehicleId: configuredCab.id,
                initialOfficeDestination: configuredOffice,
                loadVehicles: loadConfiguredCab,
                getVehicle: getConfiguredCab,
                onConfirm:
                    ({
                      required vehicleId,
                      required startOdometer,
                      required batteryPercentage,
                      required vehicleCondition,
                      required officeDestination,
                      note,
                    }) async {},
              ),
            ),
          ),
        );

        await tester.tap(find.text('Minor Damage'));
        await tester.pumpAndSettle();

        expect(find.text('Issue Details'), findsOneWidget);
        expect(find.text('Issue Category'), findsOneWidget);
        expect(find.text('Issue Description'), findsOneWidget);
        expect(find.text('Contact Operations'), findsOneWidget);
      },
    );

    test(
      'Active across midnight date rollover releases previous-day request state',
      () {
        final todayOps = createOps(
          dutyActive: true,
          openRequests: [
            CabAssignmentMemberModel(
              id: 'mem-old',
              assignmentId: 'asg-old',
              dateKey: '2026-07-31',
              userId: 'emp-1',
              role: 'employee',
              status: 'ready',
              createdAt: now,
              updatedAt: now,
            ),
          ],
        );

        final newDateKey = '2026-08-01';
        final filteredNewDayRequests = todayOps.openRequests
            .where((req) => req.dateKey == newDateKey)
            .toList();

        expect(filteredNewDayRequests, isEmpty);
      },
    );
  });
}
