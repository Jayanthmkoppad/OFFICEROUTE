import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:officeroute/core/models/live_location_model.dart';
import 'package:officeroute/core/models/location_session_model.dart';

void main() {
  group('LiveLocationModel Assignment ID Tests', () {
    test('1. LiveLocationModel retains assignmentId in toMap and fromMap', () {
      final now = DateTime.now();
      final model = LiveLocationModel(
        userId: 'emp_101',
        sessionId: 'session_1',
        assignmentId: 'assign_999',
        trackingReason: 'cab_pickup_ready',
        status: 'active',
        latitude: 15.3647,
        longitude: 75.1240,
        accuracy: 10.0,
        altitude: 0.0,
        speed: 5.0,
        heading: 0.0,
        isForeground: true,
        source: 'gps',
        syncStatus: 'synced',
        recordedAt: now,
        updatedAt: now,
      );

      final map = model.toMap();
      expect(map['assignmentId'], 'assign_999');

      final reconstructed = LiveLocationModel.fromMap(map);
      expect(reconstructed.assignmentId, 'assign_999');
    });

    test('2. LiveLocationModel.fromPosition propagates assignmentId', () {
      final pos = Position(
        longitude: 75.1240,
        latitude: 15.3647,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 12.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );

      final cabModel = LiveLocationModel.fromPosition(
        userId: 'emp_101',
        sessionId: 'session_1',
        assignmentId: 'assign_999',
        trackingReason: 'cab_pickup_ready',
        status: 'active',
        position: pos,
        isForeground: true,
      );

      expect(cabModel.assignmentId, 'assign_999');

      final nonCabModel = LiveLocationModel.fromPosition(
        userId: 'emp_101',
        sessionId: 'session_1',
        trackingReason: 'field_duty',
        status: 'active',
        position: pos,
        isForeground: true,
      );

      expect(nonCabModel.assignmentId, isNull);
    });

    test('3. copyWith preserves or updates assignmentId', () {
      final now = DateTime.now();
      final original = LiveLocationModel(
        userId: 'emp_101',
        sessionId: 'session_1',
        assignmentId: 'assign_1',
        trackingReason: 'cab_pickup_ready',
        status: 'active',
        latitude: 15.36,
        longitude: 75.12,
        accuracy: 5.0,
        altitude: 0.0,
        speed: 0.0,
        heading: 0.0,
        isForeground: true,
        source: 'gps',
        syncStatus: 'synced',
        recordedAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(status: 'offline');
      expect(updated.assignmentId, 'assign_1');

      final reassigned = original.copyWith(assignmentId: 'assign_2');
      expect(reassigned.assignmentId, 'assign_2');
    });

    test(
      '4. LocationSessionModel assignmentId getter extracts from metadata',
      () {
        final session = LocationSessionModel.started(
          userId: 'emp_101',
          trackingReason: 'cab_pickup_ready',
          metadata: {'assignmentId': 'assign_meta_77'},
        );

        expect(session.assignmentId, 'assign_meta_77');
      },
    );
  });
}
