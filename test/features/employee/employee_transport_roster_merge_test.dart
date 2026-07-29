import 'package:flutter_test/flutter_test.dart';
import 'package:officeroute/core/models/passenger_progress_model.dart';
import 'package:officeroute/features/employee/controllers/employee_transport_controller.dart';

void main() {
  const configuredEmployee = PassengerProgressModel(
    employeeId: 'employee-1',
    passengerDisplayName: 'Appu',
    employeeCode: 'EMP-001',
    pickupSequence: 1,
    status: 'not_started',
    locationFreshness: 'not_started',
  );
  const configuredAdministrator = PassengerProgressModel(
    employeeId: 'admin-1',
    passengerDisplayName: 'Admin User',
    employeeCode: 'ADM-001',
    roleLabel: 'Administrator',
    pickupSequence: 2,
    status: 'waiting',
    attendanceActive: true,
    locationFreshness: 'live',
  );
  const configuredManager = PassengerProgressModel(
    employeeId: 'manager-1',
    passengerDisplayName: 'Manager User',
    employeeCode: 'MGR-001',
    roleLabel: 'Manager',
    pickupSequence: 3,
    status: 'waiting',
    attendanceActive: true,
    locationFreshness: 'live',
  );

  test('all configured route roles appear without an active trip', () {
    final roster = EmployeeTransportController.mergeTransportRoster(
      configured: const [
        configuredEmployee,
        configuredAdministrator,
        configuredManager,
      ],
      progress: const [],
    );

    expect(roster, hasLength(3));
    expect(roster.first.status, 'not_started');
    expect(roster[1].roleLabel, 'Administrator');
    expect(roster.last.roleLabel, 'Manager');
  });

  test('trip progress enriches the same configured row', () {
    const progress = PassengerProgressModel(
      employeeId: 'employee-1',
      passengerDisplayName: 'Passenger',
      pickupSequence: 1,
      status: 'ready',
      remark: 'ready',
      distanceToPickupMeters: 84,
      estimatedReadyMinutes: 0,
      locationFreshness: 'live',
    );

    final roster = EmployeeTransportController.mergeTransportRoster(
      configured: const [configuredEmployee, configuredAdministrator],
      progress: const [progress],
    );
    final employee = roster.first;

    expect(employee.passengerDisplayName, 'Appu');
    expect(employee.employeeCode, 'EMP-001');
    expect(employee.status, 'ready');
    expect(employee.distanceToPickupMeters, 84);
    expect(employee.estimatedReadyMinutes, 0);
  });

  test('progress cannot remove configured administrators from the roster', () {
    final roster = EmployeeTransportController.mergeTransportRoster(
      configured: const [configuredEmployee, configuredAdministrator],
      progress: const [
        PassengerProgressModel(
          employeeId: 'employee-1',
          passengerDisplayName: 'Appu',
          pickupSequence: 1,
          status: 'on_the_way',
          locationFreshness: 'live',
        ),
      ],
    );

    expect(
      roster.any(
        (item) =>
            item.employeeId == 'admin-1' && item.roleLabel == 'Administrator',
      ),
      isTrue,
    );
  });

  test('trip-only passenger is retained for live operation recovery', () {
    final roster = EmployeeTransportController.mergeTransportRoster(
      configured: const [],
      progress: const [
        PassengerProgressModel(
          employeeId: 'employee-1',
          passengerDisplayName: 'Appu',
          pickupSequence: 1,
          status: 'waiting',
          locationFreshness: 'live',
        ),
      ],
    );

    expect(roster.single.employeeId, 'employee-1');
  });
}
