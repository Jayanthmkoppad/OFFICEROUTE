import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/live_location_model.dart';
import '../models/location_session_model.dart';
import 'location_tracking_policy.dart';

class LocationSessionService {
  LocationSessionService._();

  static final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('location_sessions');

  static Future<LocationSessionModel> startSession({
    required String userId,
    required String trackingReason,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    try {
      if (!LocationTrackingPolicy.isSupportedTrackingReason(trackingReason)) {
        throw ArgumentError('Unsupported tracking reason: $trackingReason');
      }

      final docRef = _collection.doc();
      final session = LocationSessionModel.started(
        userId: userId,
        trackingReason: trackingReason,
        metadata: metadata,
      ).copyWith(id: docRef.id);

      await docRef.set(session.toMap());
      return session;
    } catch (error, stackTrace) {
      _printLocationSessionException(
        error: error,
        stackTrace: stackTrace,
        method: 'LocationSessionService.startSession',
      );
      rethrow;
    }
  }

  static Future<LocationSessionModel?> fetchActiveSessionForUser(
    String userId,
  ) async {
    try {
      final snapshot = await _collection
          .where('userId', isEqualTo: userId)
          .get();
      final sessions = snapshot.docs
          .map((doc) => LocationSessionModel.fromMap(doc.data(), id: doc.id))
          .where((session) => session.isActive || session.isPaused)
          .toList();
      if (sessions.isEmpty) return null;
      sessions.sort((left, right) => right.startedAt.compareTo(left.startedAt));
      return sessions.first;
    } catch (error, stackTrace) {
      _printLocationSessionException(
        error: error,
        stackTrace: stackTrace,
        method: 'LocationSessionService.fetchActiveSessionForUser',
      );
      rethrow;
    }
  }

  /// Emits whenever a location session visible to the current user changes.
  static Stream<void> watchSessionChanges() {
    return _collection.snapshots().map<void>((_) {});
  }

  static Future<LocationSessionModel> pauseSession(
    LocationSessionModel session,
  ) {
    final updated = session.copyWith(
      status: LocationTrackingPolicy.statusPaused,
      pausedAt: DateTime.now(),
    );
    return _saveSession(
      updated,
      method: 'LocationSessionService.pauseSession',
    );
  }

  static Future<LocationSessionModel> resumeSession(
    LocationSessionModel session,
  ) {
    final updated = session.copyWith(
      status: LocationTrackingPolicy.statusActive,
      resumedAt: DateTime.now(),
      clearPausedAt: true,
    );
    return _saveSession(
      updated,
      method: 'LocationSessionService.resumeSession',
    );
  }

  static Future<LocationSessionModel> stopSession({
    required LocationSessionModel session,
    required String stopReason,
  }) {
    final updated = session.copyWith(
      status: LocationTrackingPolicy.statusStopped,
      stoppedAt: DateTime.now(),
      stopReason: stopReason,
    );
    return _saveSession(
      updated,
      method: 'LocationSessionService.stopSession',
    );
  }

  static Future<void> updateLastLocation({
    required String sessionId,
    required LiveLocationModel location,
  }) async {
    try {
      await _collection.doc(sessionId).update({
        'lastLatitude': location.latitude,
        'lastLongitude': location.longitude,
        'lastUpdatedAt': Timestamp.fromDate(location.recordedAt),
      });
    } catch (error, stackTrace) {
      _printLocationSessionException(
        error: error,
        stackTrace: stackTrace,
        method: 'LocationSessionService.updateLastLocation',
      );
      rethrow;
    }
  }

  static Future<LocationSessionModel> _saveSession(
    LocationSessionModel session, {
    required String method,
  }) async {
    try {
      await _collection.doc(session.id).set(session.toMap());
      return session;
    } catch (error, stackTrace) {
      _printLocationSessionException(
        error: error,
        stackTrace: stackTrace,
        method: method,
      );
      rethrow;
    }
  }

  static void _printLocationSessionException({
    required Object error,
    required StackTrace stackTrace,
    required String method,
  }) {
    debugPrint('Location session Firestore exception');
    debugPrint('File: lib/core/services/location_session_service.dart');
    debugPrint('Method: $method');
    debugPrint('Runtime type: ${error.runtimeType}');

    if (error is FirebaseException) {
      debugPrint('FirebaseException.plugin: ${error.plugin}');
      debugPrint('FirebaseException.code: ${error.code}');
      debugPrint('FirebaseException.message: ${error.message}');
    }

    debugPrint('Exception: $error');
    debugPrint('Stack trace:\n$stackTrace');
  }
}
