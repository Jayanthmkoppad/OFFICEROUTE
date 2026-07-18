import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/live_location_model.dart';
import '../models/location_history_point_model.dart';
import '../models/location_session_model.dart';
import 'location_history_service.dart';
import 'location_permission_service.dart';
import 'location_session_service.dart';
import 'location_tracking_policy.dart';

class LiveLocationService {
  LiveLocationService._();

  static final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('live_locations');

  static Stream<LiveLocationModel> foregroundLocationStream({
    required String userId,
    required String sessionId,
    required String trackingReason,
    LocationAccuracy accuracy = LocationAccuracy.best,
    int distanceFilterMeters = 20,
  }) {
    final settings = LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilterMeters,
    );

    return Geolocator.getPositionStream(locationSettings: settings).map(
      (position) => LiveLocationModel.fromPosition(
        userId: userId,
        sessionId: sessionId,
        trackingReason: trackingReason,
        status: LocationTrackingPolicy.statusActive,
        position: position,
        isForeground: true,
      ),
    );
  }

  static Future<StreamSubscription<LiveLocationModel>>
      startForegroundTracking({
    required LocationSessionModel session,
    void Function(LiveLocationModel location)? onLocation,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    await LocationPermissionService.ensureForegroundPermission();

    LiveLocationModel? lastLiveLocation;
    LiveLocationModel? lastHistoryLocation;
    var historySequence = 0;

    return foregroundLocationStream(
      userId: session.userId,
      sessionId: session.id,
      trackingReason: session.trackingReason,
      distanceFilterMeters:
          LocationTrackingPolicy.minimumLiveDistanceMeters.round(),
    ).listen(
      (location) {
        unawaited(
          _processForegroundLocation(
            location: location,
            historySequence: historySequence,
            previousLiveLocation: lastLiveLocation,
            previousHistoryLocation: lastHistoryLocation,
            onLiveLocationAccepted: (acceptedLocation) {
              lastLiveLocation = acceptedLocation;
              onLocation?.call(acceptedLocation);
            },
            onHistoryLocationAccepted: (acceptedLocation) {
              lastHistoryLocation = acceptedLocation;
              historySequence += 1;
            },
          ),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        _printLiveLocationException(
          error: error,
          stackTrace: stackTrace,
          method: 'LiveLocationService.startForegroundTracking.stream',
        );
        onError?.call(error, stackTrace);
      },
    );
  }

  static Future<void> writeLiveLocation(LiveLocationModel location) async {
    try {
      await _collection.doc(location.userId).set(location.toMap());
    } catch (error, stackTrace) {
      _printLiveLocationException(
        error: error,
        stackTrace: stackTrace,
        method: 'LiveLocationService.writeLiveLocation',
      );
      rethrow;
    }
  }

  static Future<LiveLocationModel?> fetchLiveLocation(String userId) async {
    try {
      final doc = await _collection.doc(userId).get();
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return LiveLocationModel.fromMap(data);
    } catch (error, stackTrace) {
      _printLiveLocationException(
        error: error,
        stackTrace: stackTrace,
        method: 'LiveLocationService.fetchLiveLocation',
      );
      rethrow;
    }
  }

  /// Emits whenever a live-location document visible to the user changes.
  static Stream<void> watchLiveLocationChanges() {
    return _collection.snapshots().map<void>((_) {});
  }

  /// Streams active or intentionally paused locations for operations views.
  ///
  /// This is a read-only projection of the existing `live_locations`
  /// collection. It does not start tracking or write location data.
  static Stream<List<LiveLocationModel>> watchLiveLocations() {
    return _collection
        .where('status', whereIn: const [
          LocationTrackingPolicy.statusActive,
          LocationTrackingPolicy.statusPaused,
        ])
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LiveLocationModel.fromMap(doc.data()))
              .toList(growable: false),
        );
  }

  /// Emits whenever one user's live-location document changes.
  static Stream<void> watchLiveLocation(String userId) {
    return _collection.doc(userId).snapshots().map<void>((_) {});
  }

  static Future<void> markPaused({
    required String userId,
    required String sessionId,
    required String trackingReason,
  }) async {
    await _updateTrackingStatus(
      userId: userId,
      sessionId: sessionId,
      trackingReason: trackingReason,
      status: LocationTrackingPolicy.statusPaused,
    );
  }

  static Future<void> markOffline({
    required String userId,
    required String sessionId,
    required String trackingReason,
  }) async {
    await _updateTrackingStatus(
      userId: userId,
      sessionId: sessionId,
      trackingReason: trackingReason,
      status: LocationTrackingPolicy.statusOffline,
    );
  }

  static Future<void> _processForegroundLocation({
    required LiveLocationModel location,
    required int historySequence,
    required LiveLocationModel? previousLiveLocation,
    required LiveLocationModel? previousHistoryLocation,
    required ValueChanged<LiveLocationModel> onLiveLocationAccepted,
    required ValueChanged<LiveLocationModel> onHistoryLocationAccepted,
  }) async {
    try {
      if (LocationTrackingPolicy.shouldWriteLiveLocation(
        previous: previousLiveLocation,
        next: location,
      )) {
        await writeLiveLocation(location);
        await LocationSessionService.updateLastLocation(
          sessionId: location.sessionId,
          location: location,
        );
        onLiveLocationAccepted(location);
      }

      if (LocationTrackingPolicy.shouldWriteHistoryPoint(
        previousHistoryLocation: previousHistoryLocation,
        next: location,
      )) {
        final point = LocationHistoryPointModel.fromLiveLocation(
          location: location,
          sequence: historySequence + 1,
        );
        await LocationHistoryService.addPoint(point);
        onHistoryLocationAccepted(location);
      }
    } catch (error, stackTrace) {
      _printLiveLocationException(
        error: error,
        stackTrace: stackTrace,
        method: 'LiveLocationService._processForegroundLocation',
      );
    }
  }

  static Future<void> _updateTrackingStatus({
    required String userId,
    required String sessionId,
    required String trackingReason,
    required String status,
  }) async {
    try {
      await _collection.doc(userId).set({
        'userId': userId,
        'sessionId': sessionId,
        'trackingReason': trackingReason,
        'status': status,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      }, SetOptions(merge: true));
    } catch (error, stackTrace) {
      _printLiveLocationException(
        error: error,
        stackTrace: stackTrace,
        method: 'LiveLocationService._updateTrackingStatus',
      );
      rethrow;
    }
  }

  static void _printLiveLocationException({
    required Object error,
    required StackTrace stackTrace,
    required String method,
  }) {
    debugPrint('Live location Firestore exception');
    debugPrint('File: lib/core/services/live_location_service.dart');
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
