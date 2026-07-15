import 'dart:async';

import '../../../core/models/cab_assignment_member_model.dart';
import '../../../core/models/cab_assignment_model.dart';
import '../../../core/models/cab_trip_event_model.dart';
import '../../../core/models/cab_trip_model.dart';
import '../../../core/models/cab_trip_rider_model.dart';
import '../../../core/models/cab_vehicle_model.dart';
import '../../../core/models/live_location_model.dart';
import '../../../core/models/location_session_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/controllers/cab_management_controller.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/live_location_service.dart';
import '../../map/controllers/location_controller.dart';

class CabTrackingController {
  CabTrackingController._();

  /// Loads today's assignment for a driver.
  static Future<CabAssignmentModel?> loadTodayAssignment({
    required String driverId,
    required String dateKey,
  }) {
    return CabManagementController.loadTodayAssignmentForDriver(
      driverId: driverId,
      dateKey: dateKey,
    );
  }

  /// Loads today's assignment lookup for any assigned cab member.
  static Future<CabAssignmentMemberModel?> loadTodayMemberAssignment({
    required String userId,
    required String dateKey,
  }) {
    return CabManagementController.loadTodayMemberAssignment(
      userId: userId,
      dateKey: dateKey,
    );
  }

  /// Loads one cab assignment.
  static Future<CabAssignmentModel?> loadAssignment(String assignmentId) {
    return CabManagementController.loadAssignment(assignmentId);
  }

  /// Loads assignments for one date key.
  static Future<List<CabAssignmentModel>> loadAssignmentsForDate(
    String dateKey,
  ) {
    return CabManagementController.loadAssignmentsForDate(dateKey: dateKey);
  }

  /// Loads one cab vehicle.
  static Future<CabVehicleModel?> loadVehicle(String vehicleId) {
    return CabManagementController.getVehicle(vehicleId);
  }

  /// Loads one driver profile from the existing `users` collection.
  static Future<UserModel?> loadDriverProfile(String driverId) async {
    final profile = await FirestoreService.getUser(driverId);
    return profile;
  }

  /// Loads assignment members for an assignment/date.
  static Future<List<CabAssignmentMemberModel>> loadAssignmentMembers({
    required String assignmentId,
    required String dateKey,
    String? status,
  }) {
    return CabManagementController.loadAssignmentMembers(
      assignmentId: assignmentId,
      dateKey: dateKey,
      status: status,
    );
  }

  /// Loads assignment members for a date.
  static Future<List<CabAssignmentMemberModel>> loadAssignmentMembersForDate({
    required String dateKey,
    String? status,
  }) {
    return CabManagementController.loadAssignmentMembersForDate(
      dateKey: dateKey,
      status: status,
    );
  }

  /// Loads users by id from the existing `users` collection.
  static Future<List<UserModel>> loadUsersByIds(List<String> uids) {
    return FirestoreService.fetchUsersByIds(uids);
  }

  /// Loads users by role from the existing `users` collection.
  static Future<List<UserModel>> loadUsersByRole(String role) {
    return FirestoreService.fetchUsersByRole(role);
  }

  /// Loads the latest live location for a user.
  static Future<LiveLocationModel?> loadLiveLocation(String userId) {
    return LiveLocationService.fetchLiveLocation(userId);
  }

  /// Loads an active cab driver location session.
  static Future<LocationSessionModel?> loadActiveDriverSession(String driverId) {
    return LocationController.loadActiveLocationSession(driverId);
  }

  /// Starts a cab driver live location session.
  static Future<LocationSessionModel> startDriverSession({
    required String driverId,
    required String assignmentId,
  }) {
    return LocationController.startLocationSession(
      userId: driverId,
      trackingReason: 'cab_trip',
      metadata: <String, dynamic>{
        'assignmentId': assignmentId,
      },
    );
  }

  /// Starts foreground live location updates for a driver session.
  static Future<StreamSubscription<LiveLocationModel>>
      startDriverLiveLocationUpdates({
    required LocationSessionModel session,
    void Function(LiveLocationModel location)? onLocation,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    return LocationController.startForegroundLiveLocationUpdates(
      session: session,
      onLocation: onLocation,
      onError: onError,
    );
  }

  /// Stops a cab driver live location session.
  static Future<LocationSessionModel> stopDriverSession({
    required LocationSessionModel session,
  }) {
    return LocationController.stopLocationSession(
      session: session,
      stopReason: 'cab_trip_completed',
    );
  }

  /// Starts an employee ready-for-pickup sharing session.
  static Future<LocationSessionModel> startEmployeeReadySession({
    required String employeeId,
    required String assignmentId,
    required String driverId,
  }) {
    return LocationController.startLocationSession(
      userId: employeeId,
      trackingReason: 'cab_pickup_ready',
      metadata: <String, dynamic>{
        'assignmentId': assignmentId,
        'driverId': driverId,
      },
    );
  }

  /// Stops an employee ready-for-pickup sharing session.
  static Future<LocationSessionModel> stopEmployeeReadySession({
    required LocationSessionModel session,
  }) {
    return LocationController.stopLocationSession(
      session: session,
      stopReason: 'cab_pickup_cancelled_or_boarded',
    );
  }

  /// Starts foreground updates for an employee pickup sharing session.
  static Future<StreamSubscription<LiveLocationModel>>
      startEmployeeReadyLiveLocationUpdates({
    required LocationSessionModel session,
    void Function(LiveLocationModel location)? onLocation,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    return LocationController.startForegroundLiveLocationUpdates(
      session: session,
      onLocation: onLocation,
      onError: onError,
    );
  }

  /// Updates one assignment status.
  static Future<void> updateAssignmentStatus({
    required String assignmentId,
    required String status,
  }) async {
    await CabManagementController.updateAssignmentStatus(
      assignmentId: assignmentId,
      status: status,
    );
  }

  /// Updates one assignment member status.
  static Future<void> updateMemberStatus({
    required String memberId,
    required String status,
  }) {
    return CabManagementController.updateAssignmentMemberStatus(
      memberId: memberId,
      status: status,
    );
  }

  /// Creates a cab trip record.
  static Future<CabTripModel> createTrip(CabTripModel trip) {
    return CabManagementController.createTrip(trip);
  }

  /// Updates a cab trip record.
  static Future<CabTripModel> updateTrip(CabTripModel trip) {
    return CabManagementController.updateTrip(trip);
  }

  /// Loads active trip for an assignment.
  static Future<CabTripModel?> loadActiveTripForAssignment(
    String assignmentId,
  ) {
    return CabManagementController.loadActiveTripForAssignment(
      assignmentId: assignmentId,
    );
  }

  /// Loads cab trips for a date.
  static Future<List<CabTripModel>> loadTripsForDate(String dateKey) {
    return CabManagementController.loadTripsForDate(dateKey: dateKey);
  }

  /// Writes or replaces a cab trip rider.
  static Future<void> upsertTripRider(CabTripRiderModel rider) {
    return CabManagementController.upsertTripRider(rider);
  }

  /// Loads cab trip riders.
  static Future<List<CabTripRiderModel>> loadTripRiders(String tripId) {
    return CabManagementController.loadTripRiders(tripId);
  }

  /// Adds a cab trip event.
  static Future<void> addTripEvent(CabTripEventModel event) {
    return CabManagementController.addTripEvent(event);
  }
}
