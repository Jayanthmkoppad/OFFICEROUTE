import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:officeroute/core/models/cab_assignment_member_model.dart';
import 'package:officeroute/core/models/cab_driver_shift_model.dart';
import 'package:officeroute/core/models/cab_vehicle_model.dart';
import 'package:officeroute/core/models/user_model.dart';
import 'package:officeroute/features/cab_driver/cab_driver_app.dart';
import 'package:officeroute/features/cab_driver/controllers/cab_driver_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockDriver = UserModel(
    uid: 'drv_101',
    name: 'Alex Driver',
    email: 'alex@company.com',
    phone: '9876543210',
    profileImage: '',
    role: 'driver',
    branch: 'Hubballi',
    serviceCentre: 'Central',
    officeName: 'Configured Office',
    officeAddress: '1 Operations Campus',
    officeLatitude: 15.3647,
    officeLongitude: 75.1240,
    employeeCode: '99283-DX',
  );

  final mockVehicle = const CabVehicleModel(
    id: 'veh_101',
    registrationNumber: 'KA-25-AB-1234',
    vehicleModel: 'Toyota Innova Hycross',
  );

  final mockShift = CabDriverShiftModel(
    id: '2026-07-31_drv_101',
    driverId: 'drv_101',
    vehicleId: 'veh_101',
    shiftStatus: 'active',
    shiftStart: DateTime.now(),
    batteryPercentage: 78,
    startOdometer: 45280,
    officeName: 'Configured Office',
    officeAddress: '1 Operations Campus',
    officeLatitude: 15.3647,
    officeLongitude: 75.1240,
  );

  final mockMembers = [
    const CabAssignmentMemberModel(
      id: '2026-07-31_emp_1',
      userId: 'emp_1',
      dateKey: '2026-07-31',
      driverId: 'drv_101',
      vehicleId: 'veh_101',
      status: 'accepted',
      invitationStatus: 'accepted',
      pickupName: 'Vidya Nagar Circle',
      pickupAddress: 'Vidya Nagar, Hubballi',
      pickupLatitude: 15.36,
      pickupLongitude: 75.12,
      branch: 'Hubballi',
    ),
    const CabAssignmentMemberModel(
      id: '2026-07-31_emp_2',
      userId: 'emp_2',
      dateKey: '2026-07-31',
      driverId: 'drv_101',
      vehicleId: 'veh_101',
      status: 'invited',
      invitationStatus: 'invited',
      pickupName: 'Keshwapur Gate',
      pickupAddress: 'Keshwapur, Hubballi',
      pickupLatitude: 15.37,
      pickupLongitude: 75.13,
      branch: 'Hubballi',
    ),
  ];

  final Map<String, UserModel> mockEmployees = {
    'emp_1': UserModel(
      uid: 'emp_1',
      name: 'Rohan Kulkarni',
      email: 'rohan@company.com',
      phone: '9876543211',
      profileImage: '',
      role: 'employee',
    ),
    'emp_2': UserModel(
      uid: 'emp_2',
      name: 'Priya Deshpande',
      email: 'priya@company.com',
      phone: '9876543212',
      profileImage: '',
      role: 'employee',
    ),
  };

  final mockOperations = CabDriverOperations(
    driver: mockDriver,
    todayAssignment: null,
    vehicle: mockVehicle,
    shift: mockShift,
    assignments: const [],
    trips: const [],
    activeTrip: null,
    members: mockMembers,
    riders: const [],
    events: const [],
    employees: mockEmployees,
    locations: const {},
    loadedAt: DateTime.now(),
    openRequests: [mockMembers.first],
    invitations: mockMembers,
    eligibleEmployees: mockEmployees.values.toList(),
  );

  group('Cab Driver Round 2 — Screens 09, 10, 11, 12, 13 Widget Tests', () {
    testWidgets(
      'Screen 09 — Pickup Plan Details renders manifest and route info',
      (tester) async {
        tester.view.physicalSize = const Size(412, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: DriverPickupPlanDetailsScreen(data: mockOperations),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Pickup Plan Details'), findsOneWidget);
        expect(find.text('Configured Office'), findsOneWidget);
        expect(find.text('Alex Driver'), findsOneWidget);
        expect(find.text('Total distance unavailable'), findsOneWidget);
        expect(find.text('Rohan Kulkarni'), findsOneWidget);
        expect(find.text('Priya Deshpande'), findsNothing);
        expect(find.text('START ROUTE NAVIGATION'), findsOneWidget);
      },
    );

    testWidgets('Screen 10 — Assigned Passenger Roster filters correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DriverPassengerRosterScreen(
            data: mockOperations,
            initialFilter: 'All',
          ),
        ),
      );

      expect(find.text('Invitation Roster (2)'), findsOneWidget);
      expect(find.text('Rohan Kulkarni'), findsOneWidget);
      expect(find.text('Priya Deshpande'), findsOneWidget);

      await tester.tap(find.text('Accepted'));
      await tester.pumpAndSettle();

      expect(find.text('Invitation Roster (1)'), findsOneWidget);
      expect(find.text('Rohan Kulkarni'), findsOneWidget);
      expect(find.text('Priya Deshpande'), findsNothing);
    });

    testWidgets(
      'Screen 11 — Vehicle Details renders specifications and battery level',
      (tester) async {
        tester.view.physicalSize = const Size(412, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(home: DriverVehicleDetailsScreen(data: mockOperations)),
        );
        await tester.pumpAndSettle();

        expect(find.text('KA-25-AB-1234'), findsWidgets);
        expect(find.text('available'), findsOneWidget);
        expect(find.text('78%'), findsOneWidget);
      },
    );

    testWidgets(
      'Screen 12 — Start Trip Passenger Selection manages selection count',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: DriverPassengerSelectionScreen(data: mockOperations),
          ),
        );

        expect(find.text('Employee Transport Directory'), findsOneWidget);
        expect(find.text('0 selected'), findsOneWidget);
        expect(find.text('REVIEW 1 ACCEPTED / START TRIP'), findsOneWidget);
      },
    );

    testWidgets(
      'Screen 13 — Start Trip Confirmation renders trip summary and start button',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: DriverStartTripConfirmationScreen(
              data: mockOperations,
              selectedMemberIds: {'2026-07-31_emp_1'},
              onEditSelection: () {},
            ),
          ),
        );

        expect(find.text('Trip Summary'), findsOneWidget);
        expect(find.text('1 of 2 Employees selected'), findsOneWidget);
        expect(find.text('START TRIP NOW'), findsOneWidget);
        expect(find.text('EDIT SELECTION'), findsOneWidget);
      },
    );
  });
}
