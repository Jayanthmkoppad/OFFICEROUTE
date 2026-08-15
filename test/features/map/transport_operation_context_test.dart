import 'package:flutter_test/flutter_test.dart';
import 'package:officeroute/core/models/cab_assignment_member_model.dart';
import 'package:officeroute/core/models/cab_assignment_model.dart';
import 'package:officeroute/core/models/live_location_model.dart';
import 'package:officeroute/core/models/user_model.dart';
import 'package:officeroute/features/map/controllers/map_modes_controller.dart';

void main() {
  final now = DateTime(2026, 7, 25, 9);
  const assignment = CabAssignmentModel(
    id: 'assignment-1',
    dateKey: '2026-07-25',
    driverId: 'driver-1',
    vehicleId: 'vehicle-1',
    employeeIds: ['admin-1'],
  );

  LiveLocationModel location({
    required String userId,
    required String assignmentId,
  }) {
    return LiveLocationModel(
      userId: userId,
      sessionId: 'session-1',
      assignmentId: assignmentId,
      trackingReason: 'cab_trip',
      status: 'active',
      latitude: 12,
      longitude: 77,
      accuracy: 10,
      altitude: 0,
      speed: 0,
      heading: 0,
      isForeground: true,
      source: 'test',
      syncStatus: 'synced',
      recordedAt: now,
      updatedAt: now,
    );
  }

  test('driver location must match the focused assignment', () {
    expect(
      MapModesController.locationMatchesOperation(
        location(userId: 'driver-1', assignmentId: 'assignment-1'),
        focusedAssignment: assignment,
        managerAssignments: const [],
        canManage: false,
      ),
      isTrue,
    );
    expect(
      MapModesController.locationMatchesOperation(
        location(userId: 'driver-1', assignmentId: 'old-assignment'),
        focusedAssignment: assignment,
        managerAssignments: const [],
        canManage: false,
      ),
      isFalse,
    );
  });

  test('unassigned employee location is rejected', () {
    expect(
      MapModesController.locationMatchesOperation(
        location(userId: 'employee-2', assignmentId: 'assignment-1'),
        focusedAssignment: assignment,
        managerAssignments: const [],
        canManage: false,
      ),
      isFalse,
    );
  });

  test('administrator route member remains a transport passenger', () {
    const admin = UserModel(
      uid: 'admin-1',
      name: 'Admin User',
      email: 'admin@example.com',
      phone: '',
      role: 'administrator',
      profileImage: '',
    );
    const member = CabAssignmentMemberModel(
      id: 'member-1',
      assignmentId: 'assignment-1',
      dateKey: '2026-07-25',
      userId: 'admin-1',
      role: 'administrator',
      status: 'ready',
    );
    const context = CabMapContext(
      currentUser: admin,
      dateKey: '2026-07-25',
      currentMember: member,
      assignment: assignment,
      vehicle: null,
      members: [member],
      usersById: {'admin-1': admin},
      liveLocationsByUserId: {},
      activeTrip: null,
      managerAssignments: [],
      managerTrips: [],
      managerMembers: [],
    );

    expect(context.isEmployee, isTrue);
    expect(context.readyMembers.single.userId, 'admin-1');
    expect(context.canManage, isTrue);
  });

  test('location without an operation assignment is rejected', () {
    expect(
      MapModesController.locationMatchesOperation(
        location(userId: 'driver-1', assignmentId: ''),
        focusedAssignment: assignment,
        managerAssignments: const [assignment],
        canManage: true,
      ),
      isFalse,
    );
  });
}
