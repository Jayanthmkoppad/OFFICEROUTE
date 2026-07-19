import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/controllers/cab_management_controller.dart';
import '../../core/models/cab_assignment_member_model.dart';
import '../../core/models/cab_assignment_model.dart';
import '../../core/models/cab_trip_event_model.dart';
import '../../core/models/cab_vehicle_model.dart';
import '../../core/models/live_location_model.dart';
import '../../core/services/location_tracking_policy.dart';
import '../map/controllers/location_controller.dart';
import '../notifications/services/notification_service.dart';
import 'controllers/cab_driver_controller.dart';

/// Live-data summary displayed before the driver explicitly completes a trip.
class CabTripSummary {
  final int totalEmployees;
  final int completedPickups;
  final int skipped;
  final double distanceKm;
  final int tripDurationSeconds;
  final int drivingSeconds;
  final int waitingSeconds;

  const CabTripSummary({
    required this.totalEmployees,
    required this.completedPickups,
    required this.skipped,
    required this.distanceKm,
    required this.tripDurationSeconds,
    required this.drivingSeconds,
    required this.waitingSeconds,
  });
}

/// Compatibility layer that completes the Driver UI workflow without replacing
/// the existing [CabDriverController] implementation.
class CabDriverWorkflowSupport {
  CabDriverWorkflowSupport._();

  static StreamSubscription<LiveLocationModel>? _fieldDutySubscription;

  static Future<CabVehicleModel?> resolveDriverVehicle(
    CabDriverOperations data,
  ) async {
    final current = data.vehicle;
    if (current != null && current.id.trim().isNotEmpty) return current;

    final vehicles = (await CabManagementController.loadVehicles())
        .where(
          (vehicle) =>
              vehicle.id.trim().isNotEmpty &&
              vehicle.status.trim().toLowerCase() != 'inactive',
        )
        .toList(growable: false);

    for (final vehicle in vehicles) {
      if (vehicle.driverId.trim().isNotEmpty &&
          vehicle.driverId == data.driver.uid) {
        return vehicle;
      }
    }

    final preferred = data.driver.vehicleNumber.trim().toLowerCase();
    if (preferred.isNotEmpty) {
      for (final vehicle in vehicles) {
        if (vehicle.id.toLowerCase() == preferred ||
            vehicle.vehicleNumber.trim().toLowerCase() == preferred ||
            vehicle.registrationNumber.trim().toLowerCase() == preferred) {
          return vehicle;
        }
      }
    }

    return _createFallbackVehicleForDriver(data);
  }

  static Future<CabVehicleModel?> _createFallbackVehicleForDriver(
    CabDriverOperations data,
  ) async {
    final uid = data.driver.uid.trim();
    if (uid.isEmpty) return null;

    final profileVehicle = data.driver.vehicleNumber.trim();
    final suffixLength = uid.length < 6 ? uid.length : 6;
    final fallbackNumber = profileVehicle.isNotEmpty
        ? profileVehicle
        : 'CAB-${uid.substring(0, suffixLength).toUpperCase()}';

    final draft = CabVehicleModel(
      id: fallbackNumber,
      vehicleNumber: fallbackNumber,
      vehicleModel: 'Office Cab',
      registrationNumber: profileVehicle.isEmpty
          ? fallbackNumber
          : profileVehicle,
      capacity: 4,
      status: 'available',
      driverId: uid,
      remarks:
          'Auto-created during driver Start Duty. Admin can update vehicle master.',
    );

    try {
      final vehicleId = await CabManagementController.createVehicle(draft);
      return CabVehicleModel(
        id: vehicleId,
        vehicleNumber: draft.vehicleNumber,
        vehicleModel: draft.vehicleModel,
        registrationNumber: draft.registrationNumber,
        capacity: draft.capacity,
        status: draft.status,
        driverId: draft.driverId,
        remarks: draft.remarks,
      );
    } catch (_) {
      // Some Firestore rules may not allow cab drivers to create vehicle master
      // records. Start Duty must still work, so we keep a safe operational
      // fallback vehicle id for shift/assignment records.
      return draft;
    }
  }

  static Future<void> startDuty(
    CabDriverOperations data, {
    required String vehicleId,
  }) async {
    if (data.dutyActive) return;
    final normalizedVehicleId = vehicleId.trim();
    if (normalizedVehicleId.isEmpty) {
      throw StateError('Select a valid cab before starting duty.');
    }

    final fetchedVehicle = await CabManagementController.getVehicle(
      normalizedVehicleId,
    );
    final vehicle =
        fetchedVehicle ??
        CabVehicleModel(
          id: normalizedVehicleId,
          vehicleNumber: normalizedVehicleId,
          vehicleModel: 'Office Cab',
          registrationNumber: normalizedVehicleId,
          capacity: 4,
          status: 'available',
          driverId: data.driver.uid,
          remarks: 'Operational fallback cab for Start Duty.',
        );
    if (vehicle.status.trim().toLowerCase() == 'inactive') {
      throw StateError('The selected cab is inactive. Choose another cab.');
    }

    final now = DateTime.now();
    final today = CabDriverController.dateKey(now);
    CabAssignmentModel assignment;

    final existing = data.todayAssignment;
    if (existing == null || existing.id.trim().isEmpty) {
      final draft = CabAssignmentModel(
        dateKey: today,
        assignmentDate: now,
        driverId: data.driver.uid,
        vehicleId: vehicle.id,
        employeeIds: const <String>[],
        officeName: data.driver.branch.trim().isEmpty
            ? 'Office'
            : data.driver.branch.trim(),
        officeAddress: '',
        officeLatitude: null,
        officeLongitude: null,
        status: 'active',
        assignedBy: data.driver.uid,
        assignedAt: now,
        updatedAt: now,
        remarks: 'Operational assignment created automatically at Start Duty.',
      );
      final assignmentId = await CabManagementController.createAssignment(
        draft,
      );
      assignment = draft.copyWith(id: assignmentId);
    } else {
      assignment = existing.copyWith(
        vehicleId: vehicle.id,
        status: existing.status == 'completed' ? 'active' : existing.status,
        assignedBy: existing.assignedBy.trim().isEmpty
            ? data.driver.uid
            : existing.assignedBy,
        updatedAt: now,
      );
      await CabManagementController.updateAssignment(assignment);
    }

    await CabManagementController.upsertAssignmentMembers([
      CabAssignmentMemberModel(
        id: '${assignment.dateKey}_${data.driver.uid}',
        assignmentId: assignment.id,
        dateKey: assignment.dateKey,
        userId: data.driver.uid,
        role: 'driver',
        driverId: data.driver.uid,
        vehicleId: vehicle.id,
        status: 'active',
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    final adjustedAssignments = <CabAssignmentModel>[
      ...data.assignments.where((item) => item.id != assignment.id),
      assignment,
    ];
    final adjusted = CabDriverOperations(
      driver: data.driver,
      todayAssignment: assignment,
      vehicle: vehicle,
      shift: data.shift,
      assignments: adjustedAssignments,
      trips: data.trips,
      activeTrip: data.activeTrip,
      members: data.members,
      riders: data.riders,
      events: data.events,
      employees: data.employees,
      locations: data.locations,
      loadedAt: data.loadedAt,
    );

    await CabDriverController.startDuty(adjusted);
  }

  static Future<void> startTripWithEmployees(
    CabDriverOperations data,
    List<String> employeeIds,
  ) async {
    await _prepareForCabTrip(data.driver.uid);
    await CabDriverController.startTripWithEmployees(data, employeeIds);
  }

  static Future<void> startOrResumeTrip(CabDriverOperations data) async {
    await _prepareForCabTrip(data.driver.uid);
    await CabDriverController.startOrResumeTrip(data);
  }

  static Future<void> completeTrip(CabDriverOperations data) async {
    await CabDriverController.completeTrip(data);
    if (!data.dutyActive) return;

    var session = await LocationController.loadActiveLocationSession(
      data.driver.uid,
    );
    if (session != null &&
        session.trackingReason != LocationTrackingPolicy.reasonFieldDuty) {
      await LocationController.stopLocationSession(
        session: session,
        stopReason: 'cab_trip_completed_resume_field_duty',
      );
      session = null;
    }
    session ??= await LocationController.startLocationSession(
      userId: data.driver.uid,
      trackingReason: LocationTrackingPolicy.reasonFieldDuty,
      metadata: <String, dynamic>{
        'assignmentId': data.todayAssignment?.id ?? '',
      },
    );
    await _fieldDutySubscription?.cancel();
    _fieldDutySubscription =
        await LocationController.startForegroundLiveLocationUpdates(
          session: session,
        );
  }

  static Future<void> endDuty(CabDriverOperations data) async {
    await CabDriverController.endDuty(data);
    await _fieldDutySubscription?.cancel();
    _fieldDutySubscription = null;
    final session = await LocationController.loadActiveLocationSession(
      data.driver.uid,
    );
    if (session != null) {
      await LocationController.stopLocationSession(
        session: session,
        stopReason: 'driver_duty_ended',
      );
    }
  }

  static Future<void> _prepareForCabTrip(String driverId) async {
    await _fieldDutySubscription?.cancel();
    _fieldDutySubscription = null;
    final session = await LocationController.loadActiveLocationSession(
      driverId,
    );
    if (session != null &&
        session.trackingReason == LocationTrackingPolicy.reasonFieldDuty) {
      await LocationController.stopLocationSession(
        session: session,
        stopReason: 'cab_trip_started',
      );
    }
  }

  static Future<void> skipRider(
    CabDriverOperations data, {
    required String reason,
  }) async {
    final trip = data.activeTrip;
    final rider = data.activeRider;
    if (trip == null || rider == null) {
      throw StateError('No active employee pickup is available to skip.');
    }
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw StateError('A skip reason is required.');
    }

    final now = DateTime.now();
    final waitingSeconds = rider.reachedPickupAt == null
        ? rider.waitingDurationSeconds
        : now
              .difference(rider.reachedPickupAt!)
              .inSeconds
              .clamp(0, 86400)
              .toInt();

    await CabManagementController.updateTripRiderFields(
      tripId: trip.id,
      riderId: rider.employeeId,
      fields: <String, Object?>{
        'status': 'no_show',
        'skipReason': normalizedReason,
        'waitingDurationSeconds': waitingSeconds,
        'updatedAt': Timestamp.fromDate(now),
      },
    );
    await _updateMemberStatus(data, rider.employeeId, 'no_show');
    await CabManagementController.addTripEvent(
      CabTripEventModel(
        tripId: trip.id,
        assignmentId: trip.assignmentId,
        actorUserId: data.driver.uid,
        eventType: 'rider_skipped',
        message: 'Employee pickup skipped: $normalizedReason',
        createdAt: now,
        metadata: <String, dynamic>{
          'employeeId': rider.employeeId,
          'reason': normalizedReason,
        },
      ),
    );
    await NotificationService.createLocalNotification(
      userId: rider.employeeId,
      title: 'Cab pickup skipped',
      body: normalizedReason,
      type: 'cab_pickup_skipped',
    );

    final remaining =
        data.riders
            .where(
              (item) =>
                  item.employeeId != rider.employeeId &&
                  const {'assigned', 'ready', 'waiting'}.contains(item.status),
            )
            .toList()
          ..sort((a, b) => a.pickupOrder.compareTo(b.pickupOrder));
    if (remaining.isNotEmpty) {
      final next = remaining.first;
      await NotificationService.createLocalNotification(
        userId: next.employeeId,
        title: 'Cab is arriving',
        body: 'Your cab is proceeding to your pickup. Please be ready.',
        type: 'cab_arriving',
      );
    }
  }

  /// Marks office arrival and drops boarded riders, but intentionally does not
  /// auto-complete the trip. Completion remains an explicit driver action.
  static Future<void> reachedDestination(CabDriverOperations data) async {
    final trip = data.activeTrip;
    final assignment = data.todayAssignment;
    if (trip == null || assignment == null) {
      throw StateError('No active trip is available.');
    }
    if (data.activeRider != null) {
      throw StateError('Finish or skip all pending pickups first.');
    }

    final now = DateTime.now();
    await CabManagementController.updateTrip(
      trip.copyWith(
        status: 'office_arrived',
        officeArrivedAt: now,
        updatedAt: now,
      ),
    );

    for (final rider in data.riders.where(
      (item) => const {'picked_up', 'boarded'}.contains(item.status),
    )) {
      await CabManagementController.updateTripRiderFields(
        tripId: trip.id,
        riderId: rider.employeeId,
        fields: <String, Object?>{
          'status': 'dropped',
          'droppedAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        },
      );
      await _updateMemberStatus(data, rider.employeeId, 'dropped');
      await NotificationService.createLocalNotification(
        userId: rider.employeeId,
        title: 'Reached office',
        body: 'You have reached ${assignment.officeName}.',
        type: 'cab_dropped',
      );
    }

    await CabManagementController.addTripEvent(
      CabTripEventModel(
        tripId: trip.id,
        assignmentId: trip.assignmentId,
        actorUserId: data.driver.uid,
        eventType: 'destination_reached',
        message: 'Cab reached ${assignment.officeName}.',
        createdAt: now,
      ),
    );
  }

  static Future<CabTripSummary?> summariseActiveTrip(CabDriverOperations data) {
    final trip = data.activeTrip;
    if (trip == null) return Future<CabTripSummary?>.value(null);

    final totalEmployees = data.riders.length;
    final completedPickups = data.riders
        .where(
          (rider) =>
              const {'picked_up', 'boarded', 'dropped'}.contains(rider.status),
        )
        .length;
    final skipped = data.riders
        .where((rider) => const {'no_show', 'skipped'}.contains(rider.status))
        .length;
    final waitingSeconds = data.riders.fold<int>(
      0,
      (total, rider) => total + rider.waitingDurationSeconds,
    );
    final endedAt = trip.officeArrivedAt ?? trip.completedAt ?? DateTime.now();
    final liveDuration = trip.startedAt == null
        ? 0
        : endedAt.difference(trip.startedAt!).inSeconds.clamp(0, 86400).toInt();

    return Future<CabTripSummary?>.value(
      CabTripSummary(
        totalEmployees: totalEmployees,
        completedPickups: completedPickups,
        skipped: skipped,
        distanceKm: trip.distanceKm,
        tripDurationSeconds: trip.durationSeconds > 0
            ? trip.durationSeconds
            : liveDuration,
        drivingSeconds: trip.drivingSeconds,
        waitingSeconds: waitingSeconds,
      ),
    );
  }

  static Future<void> _updateMemberStatus(
    CabDriverOperations data,
    String employeeId,
    String status,
  ) async {
    for (final member in data.members) {
      if (member.userId == employeeId && member.id.trim().isNotEmpty) {
        await CabManagementController.updateAssignmentMemberStatus(
          memberId: member.id,
          status: status,
        );
        return;
      }
    }
  }
}
