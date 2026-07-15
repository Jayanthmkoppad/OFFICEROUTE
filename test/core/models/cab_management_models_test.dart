import 'package:flutter_test/flutter_test.dart';
import 'package:officeroute/core/models/cab_assignment_member_model.dart';
import 'package:officeroute/core/models/cab_assignment_model.dart';
import 'package:officeroute/core/models/cab_trip_event_model.dart';
import 'package:officeroute/core/models/cab_trip_model.dart';
import 'package:officeroute/core/models/cab_trip_rider_model.dart';
import 'package:officeroute/core/models/cab_vehicle_model.dart';

void main() {
  group('CabVehicleModel', () {
    test('converts to and from a map without losing data', () {
      const vehicle = CabVehicleModel(
        id: 'vehicle-1',
        vehicleNumber: 'KA-01-1234',
        vehicleModel: 'Toyota Etios',
        registrationNumber: 'KA01AB1234',
        capacity: 4,
        status: 'available',
        driverId: 'driver-1',
        remarks: 'Ready',
      );

      final restoredVehicle = CabVehicleModel.fromMap(
        vehicle.toMap(),
        id: vehicle.id,
      );

      expect(restoredVehicle.id, vehicle.id);
      expect(restoredVehicle.vehicleNumber, vehicle.vehicleNumber);
      expect(restoredVehicle.vehicleModel, vehicle.vehicleModel);
      expect(restoredVehicle.registrationNumber, vehicle.registrationNumber);
      expect(restoredVehicle.capacity, vehicle.capacity);
      expect(restoredVehicle.status, vehicle.status);
      expect(restoredVehicle.driverId, vehicle.driverId);
      expect(restoredVehicle.remarks, vehicle.remarks);
    });

    test('uses empty defaults for missing fields', () {
      final vehicle = CabVehicleModel.fromMap(const {});

      expect(vehicle.toMap(), {
        'vehicleNumber': '',
        'vehicleModel': '',
        'registrationNumber': '',
        'capacity': 0,
        'status': 'available',
        'driverId': '',
        'remarks': '',
      });
    });
  });

  group('CabAssignmentModel', () {
    test('converts to and from a map without losing data', () {
      final assignment = CabAssignmentModel(
        id: 'assignment-1',
        driverId: 'driver-1',
        vehicleId: 'vehicle-1',
        assignedAt: DateTime.utc(2026, 7, 12, 8, 0),
        status: 'active',
        assignedBy: 'manager-1',
        remarks: 'Primary vehicle',
      );

      final restored = CabAssignmentModel.fromMap(
        assignment.toMap(),
        id: assignment.id,
      );

      expect(restored.id, assignment.id);
      expect(restored.driverId, assignment.driverId);
      expect(restored.vehicleId, assignment.vehicleId);
      expect(restored.assignedAt?.toUtc(), assignment.assignedAt?.toUtc());
      expect(restored.status, assignment.status);
      expect(restored.assignedBy, assignment.assignedBy);
      expect(restored.remarks, assignment.remarks);
    });

    test('uses empty defaults for missing fields', () {
      final assignment = CabAssignmentModel.fromMap(const {});

      expect(assignment.toMap(), {
        'dateKey': '',
        'assignmentDate': null,
        'driverId': '',
        'vehicleId': '',
        'employeeIds': const <String>[],
        'officeName': '',
        'officeAddress': '',
        'officeLatitude': null,
        'officeLongitude': null,
        'status': 'active',
        'assignedBy': '',
        'assignedAt': null,
        'updatedAt': null,
        'remarks': '',
      });
    });
  });

  group('CabAssignmentMemberModel', () {
    test('converts to and from a map without losing data', () {
      final now = DateTime.utc(2026, 7, 12, 8);
      final member = CabAssignmentMemberModel(
        id: 'member-1',
        assignmentId: 'assignment-1',
        dateKey: '2026-07-12',
        userId: 'employee-1',
        role: 'employee',
        driverId: 'driver-1',
        vehicleId: 'vehicle-1',
        status: 'ready',
        createdAt: now,
        updatedAt: now,
      );

      final restored = CabAssignmentMemberModel.fromMap(
        member.toMap(),
        id: member.id,
      );

      expect(restored.id, member.id);
      expect(restored.assignmentId, member.assignmentId);
      expect(restored.dateKey, member.dateKey);
      expect(restored.userId, member.userId);
      expect(restored.role, member.role);
      expect(restored.driverId, member.driverId);
      expect(restored.vehicleId, member.vehicleId);
      expect(restored.status, member.status);
      expect(restored.createdAt?.toUtc(), member.createdAt?.toUtc());
      expect(restored.updatedAt?.toUtc(), member.updatedAt?.toUtc());
    });
  });

  group('CabTripModel', () {
    test('converts to and from a map without losing data', () {
      final now = DateTime.utc(2026, 7, 12, 9);
      final trip = CabTripModel(
        id: 'trip-1',
        assignmentId: 'assignment-1',
        dateKey: '2026-07-12',
        driverId: 'driver-1',
        vehicleId: 'vehicle-1',
        status: 'active',
        activeLocationSessionId: 'session-1',
        createdAt: now,
        startedAt: now,
        officeArrivedAt: now.add(const Duration(hours: 1)),
        completedAt: now.add(const Duration(hours: 2)),
        updatedAt: now,
        remarks: 'Morning trip',
      );

      final restored = CabTripModel.fromMap(trip.toMap(), id: trip.id);

      expect(restored.id, trip.id);
      expect(restored.assignmentId, trip.assignmentId);
      expect(restored.dateKey, trip.dateKey);
      expect(restored.driverId, trip.driverId);
      expect(restored.vehicleId, trip.vehicleId);
      expect(restored.status, trip.status);
      expect(restored.activeLocationSessionId, trip.activeLocationSessionId);
      expect(restored.createdAt?.toUtc(), trip.createdAt?.toUtc());
      expect(restored.startedAt?.toUtc(), trip.startedAt?.toUtc());
      expect(restored.officeArrivedAt?.toUtc(), trip.officeArrivedAt?.toUtc());
      expect(restored.completedAt?.toUtc(), trip.completedAt?.toUtc());
      expect(restored.updatedAt?.toUtc(), trip.updatedAt?.toUtc());
      expect(restored.remarks, trip.remarks);
    });
  });

  group('CabTripRiderModel', () {
    test('converts to and from a map without losing data', () {
      final now = DateTime.utc(2026, 7, 12, 9, 30);
      final rider = CabTripRiderModel(
        id: 'employee-1',
        tripId: 'trip-1',
        assignmentId: 'assignment-1',
        employeeId: 'employee-1',
        status: 'boarded',
        readyAt: now,
        pickedUpAt: now.add(const Duration(minutes: 10)),
        boardedAt: now.add(const Duration(minutes: 15)),
        pickupLatitude: 12.34,
        pickupLongitude: 56.78,
        createdAt: now,
        updatedAt: now,
      );

      final restored = CabTripRiderModel.fromMap(
        rider.toMap(),
        id: rider.id,
      );

      expect(restored.id, rider.id);
      expect(restored.tripId, rider.tripId);
      expect(restored.assignmentId, rider.assignmentId);
      expect(restored.employeeId, rider.employeeId);
      expect(restored.status, rider.status);
      expect(restored.readyAt?.toUtc(), rider.readyAt?.toUtc());
      expect(restored.pickedUpAt?.toUtc(), rider.pickedUpAt?.toUtc());
      expect(restored.boardedAt?.toUtc(), rider.boardedAt?.toUtc());
      expect(restored.pickupLatitude, rider.pickupLatitude);
      expect(restored.pickupLongitude, rider.pickupLongitude);
      expect(restored.createdAt?.toUtc(), rider.createdAt?.toUtc());
      expect(restored.updatedAt?.toUtc(), rider.updatedAt?.toUtc());
    });
  });

  group('CabTripEventModel', () {
    test('converts to and from a map without losing data', () {
      final now = DateTime.utc(2026, 7, 12, 10);
      final event = CabTripEventModel(
        id: 'event-1',
        tripId: 'trip-1',
        assignmentId: 'assignment-1',
        actorUserId: 'driver-1',
        eventType: 'trip_started',
        message: 'Trip started',
        createdAt: now,
        metadata: const <String, dynamic>{'source': 'test'},
      );

      final restored = CabTripEventModel.fromMap(
        event.toMap(),
        id: event.id,
      );

      expect(restored.id, event.id);
      expect(restored.tripId, event.tripId);
      expect(restored.assignmentId, event.assignmentId);
      expect(restored.actorUserId, event.actorUserId);
      expect(restored.eventType, event.eventType);
      expect(restored.message, event.message);
      expect(restored.createdAt?.toUtc(), event.createdAt?.toUtc());
      expect(restored.metadata, event.metadata);
    });
  });
}
