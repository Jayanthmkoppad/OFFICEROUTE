import '../models/cab_assignment_member_model.dart';
import '../models/cab_assignment_model.dart';
import '../models/cab_driver_shift_model.dart';
import '../models/cab_trip_event_model.dart';
import '../models/cab_trip_model.dart';
import '../models/cab_trip_rider_model.dart';
import '../models/cab_vehicle_model.dart';
import '../models/user_model.dart';
import '../services/cab_assignment_service.dart';
import '../services/cab_driver_shift_service.dart';
import '../services/cab_trip_service.dart';
import '../services/cab_vehicle_service.dart';
import '../services/firestore_service.dart';

/// Facade for reusable Cab Management backend operations.
class CabManagementController {
  CabManagementController._();

  /// Loads all registered cab vehicles.
  static Future<List<CabVehicleModel>> loadVehicles() async {
    return CabVehicleService.fetchAllVehicles();
  }

  /// Loads one cab vehicle by id.
  static Future<CabVehicleModel?> getVehicle(String id) async {
    return CabVehicleService.getVehicle(id);
  }

  /// Creates one cab vehicle.
  static Future<String> createVehicle(CabVehicleModel vehicle) async {
    return CabVehicleService.createVehicle(vehicle);
  }

  /// Updates one cab vehicle.
  static Future<void> updateVehicle(CabVehicleModel vehicle) async {
    await CabVehicleService.updateVehicle(vehicle);
  }

  /// Loads assignments for a driver.
  static Future<List<CabAssignmentModel>> loadAssignmentsForDriver({
    required String driverId,
  }) async {
    return CabAssignmentService.fetchAssignmentsForDriver(driverId: driverId);
  }

  /// Creates one daily cab assignment.
  static Future<String> createAssignment(CabAssignmentModel assignment) async {
    return CabAssignmentService.createAssignment(assignment);
  }

  /// Updates one daily cab assignment.
  static Future<void> updateAssignment(CabAssignmentModel assignment) async {
    await CabAssignmentService.updateAssignment(assignment);
  }

  /// Loads driver shifts for one driver.
  static Future<List<CabDriverShiftModel>> loadShiftsForDriver({
    required String driverId,
  }) async {
    return CabDriverShiftService.fetchShiftsForDriver(driverId: driverId);
  }

  /// Loads all driver shifts.
  static Future<List<CabDriverShiftModel>> loadAllShifts() async {
    return CabDriverShiftService.fetchAllShifts();
  }

  /// Creates a driver shift.
  static Future<String> createShift(CabDriverShiftModel shift) async {
    return CabDriverShiftService.createShift(shift);
  }

  /// Updates a driver shift.
  static Future<void> updateShift(CabDriverShiftModel shift) async {
    await CabDriverShiftService.updateShift(shift);
  }

  /// Loads today's assignment for a driver.
  static Future<CabAssignmentModel?> loadTodayAssignmentForDriver({
    required String driverId,
    required String dateKey,
  }) async {
    return CabAssignmentService.fetchTodayAssignmentForDriver(
      driverId: driverId,
      dateKey: dateKey,
    );
  }

  /// Loads today's assignment lookup for a driver or employee.
  static Future<CabAssignmentMemberModel?> loadTodayMemberAssignment({
    required String userId,
    required String dateKey,
  }) async {
    return CabAssignmentService.fetchTodayMemberAssignment(
      userId: userId,
      dateKey: dateKey,
    );
  }

  /// Loads one cab assignment by id.
  static Future<CabAssignmentModel?> loadAssignment(String assignmentId) {
    return CabAssignmentService.getAssignment(assignmentId);
  }

  /// Loads assignments for one date key.
  static Future<List<CabAssignmentModel>> loadAssignmentsForDate({
    required String dateKey,
  }) {
    return CabAssignmentService.fetchAssignmentsForDate(dateKey: dateKey);
  }

  /// Loads assignment members for one assignment.
  static Future<List<CabAssignmentMemberModel>> loadAssignmentMembers({
    required String assignmentId,
    required String dateKey,
    String? status,
  }) async {
    return CabAssignmentService.fetchMembersForAssignment(
      assignmentId: assignmentId,
      dateKey: dateKey,
      status: status,
    );
  }

  /// Loads assignment members across all assignments for one date key.
  static Future<List<CabAssignmentMemberModel>> loadAssignmentMembersForDate({
    required String dateKey,
    String? status,
  }) {
    return CabAssignmentService.fetchMembersForDate(
      dateKey: dateKey,
      status: status,
    );
  }

  /// Creates or replaces assignment member lookup records.
  static Future<void> upsertAssignmentMembers(
    List<CabAssignmentMemberModel> members,
  ) {
    return CabAssignmentService.upsertAssignmentMembers(members);
  }

  /// Updates one assignment status.
  static Future<void> updateAssignmentStatus({
    required String assignmentId,
    required String status,
  }) async {
    final assignment = await CabAssignmentService.getAssignment(assignmentId);
    if (assignment == null) {
      throw StateError('Assignment not found: $assignmentId');
    }

    final updated = assignment.copyWith(status: status);
    await CabAssignmentService.updateAssignment(updated);
  }

  /// Updates one assignment member status.
  static Future<void> updateAssignmentMemberStatus({
    required String memberId,
    required String status,
  }) async {
    await CabAssignmentService.updateMemberStatus(
      memberId: memberId,
      status: status,
    );
  }

  /// Loads users from the existing `users` collection by uid.
  static Future<List<UserModel>> loadUsersByIds(List<String> uids) async {
    return await FirestoreService.fetchUsersByIds(uids);
  }

  /// Loads users from the existing `users` collection by role.
  static Future<List<UserModel>> loadUsersByRole(String role) {
    return FirestoreService.fetchUsersByRole(role);
  }

  /// Creates a cab trip.
  static Future<CabTripModel> createTrip(CabTripModel trip) {
    return CabTripService.createTrip(trip);
  }

  /// Updates a cab trip.
  static Future<CabTripModel> updateTrip(CabTripModel trip) {
    return CabTripService.updateTrip(trip);
  }

  /// Loads the active trip for an assignment.
  static Future<CabTripModel?> loadActiveTripForAssignment({
    required String assignmentId,
  }) {
    return CabTripService.fetchActiveTripForAssignment(
      assignmentId: assignmentId,
    );
  }

  /// Loads cab trips for one date key.
  static Future<List<CabTripModel>> loadTripsForDate({
    required String dateKey,
  }) {
    return CabTripService.fetchTripsForDate(dateKey: dateKey);
  }

  /// Writes or replaces a cab trip rider.
  static Future<void> upsertTripRider(CabTripRiderModel rider) {
    return CabTripService.upsertRider(rider);
  }

  /// Loads rider records for one trip.
  static Future<List<CabTripRiderModel>> loadTripRiders(String tripId) {
    return CabTripService.fetchRiders(tripId);
  }

  /// Adds an immutable cab trip audit event.
  static Future<void> addTripEvent(CabTripEventModel event) {
    return CabTripService.addEvent(event);
  }

  /// Loads driver profile data from the existing `users` collection.
  static Future<Map<String, dynamic>?> getDriverProfile(String driverId) async {
    final user = await FirestoreService.getUser(driverId);
    if (user == null) {
      return null;
    }

    return {
      'uid': user.uid,
      'name': user.name,
      'email': user.email,
      'phone': user.phone,
      'role': user.role,
      'profileImage': user.profileImage,
    };
  }
}
