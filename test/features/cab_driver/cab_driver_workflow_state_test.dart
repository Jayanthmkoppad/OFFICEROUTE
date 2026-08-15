import 'package:flutter_test/flutter_test.dart';
import 'package:officeroute/core/models/cab_driver_shift_model.dart';
import 'package:officeroute/core/models/cab_trip_model.dart';
import 'package:officeroute/core/models/cab_trip_rider_model.dart';
import 'package:officeroute/core/models/user_model.dart';
import 'package:officeroute/features/cab_driver/controllers/cab_driver_controller.dart';

void main() {
  final shiftStart = DateTime(2026, 7, 25, 8);

  CabDriverOperations operations({
    CabDriverShiftModel? shift,
    CabTripModel? activeTrip,
    List<CabTripModel> trips = const [],
    List<CabTripRiderModel> riders = const [],
  }) {
    return CabDriverOperations(
      driver: const UserModel(
        uid: 'driver-1',
        name: 'Driver',
        email: 'driver@example.com',
        phone: '',
        role: 'driver',
        profileImage: '',
      ),
      todayAssignment: null,
      vehicle: null,
      shift: shift,
      assignments: const [],
      trips: trips,
      activeTrip: activeTrip,
      members: const [],
      riders: riders,
      events: const [],
      employees: const {},
      locations: const {},
      loadedAt: shiftStart,
    );
  }

  CabDriverShiftModel activeShift({DateTime? start}) => CabDriverShiftModel(
    id: 'shift-1',
    driverId: 'driver-1',
    shiftDate: '2026-07-25',
    shiftStart: start ?? shiftStart,
    shiftStatus: 'active',
  );

  test('off duty exposes one unambiguous workflow state', () {
    expect(operations().workflowState, CabDriverWorkflowState.offDuty);
  });

  test('active duty without a trip is on duty', () {
    expect(
      operations(shift: activeShift()).workflowState,
      CabDriverWorkflowState.onDuty,
    );
  });

  test('created trip is ready to resume', () {
    const trip = CabTripModel(id: 'trip-1', status: 'created');
    expect(
      operations(
        shift: activeShift(),
        activeTrip: trip,
        trips: const [trip],
      ).workflowState,
      CabDriverWorkflowState.tripReady,
    );
  });

  test('active trip with pending rider travels to pickup', () {
    const trip = CabTripModel(id: 'trip-1', status: 'active');
    const rider = CabTripRiderModel(employeeId: 'employee-1', status: 'ready');
    expect(
      operations(
        shift: activeShift(),
        activeTrip: trip,
        trips: const [trip],
        riders: const [rider],
      ).workflowState,
      CabDriverWorkflowState.travellingToPickup,
    );
  });

  test('waiting rider exposes pickup controls only', () {
    const trip = CabTripModel(id: 'trip-1', status: 'active');
    const rider = CabTripRiderModel(
      employeeId: 'employee-1',
      status: 'waiting',
    );
    expect(
      operations(
        shift: activeShift(),
        activeTrip: trip,
        trips: const [trip],
        riders: const [rider],
      ).workflowState,
      CabDriverWorkflowState.waitingAtPickup,
    );
  });

  test('active trip without pending riders travels to office', () {
    const trip = CabTripModel(id: 'trip-1', status: 'active');
    expect(
      operations(
        shift: activeShift(),
        activeTrip: trip,
        trips: const [trip],
      ).workflowState,
      CabDriverWorkflowState.travellingToOffice,
    );
  });

  test('office arrival waits for explicit completion', () {
    const trip = CabTripModel(id: 'trip-1', status: 'office_arrived');
    expect(
      operations(
        shift: activeShift(),
        activeTrip: trip,
        trips: const [trip],
      ).workflowState,
      CabDriverWorkflowState.tripCompleted,
    );
  });

  test('completed trip during current shift allows end duty', () {
    final trip = CabTripModel(
      id: 'trip-1',
      status: 'completed',
      completedAt: shiftStart.add(const Duration(hours: 1)),
    );
    expect(
      operations(shift: activeShift(), trips: [trip]).workflowState,
      CabDriverWorkflowState.tripCompleted,
    );
  });

  test('new shift after an earlier completed trip can start again', () {
    final trip = CabTripModel(
      id: 'trip-1',
      status: 'completed',
      completedAt: shiftStart,
    );
    expect(
      operations(
        shift: activeShift(start: shiftStart.add(const Duration(hours: 2))),
        trips: [trip],
      ).workflowState,
      CabDriverWorkflowState.onDuty,
    );
  });
}
