import 'dart:async';

import '../../../core/models/live_location_model.dart';
import '../../../core/models/location_model.dart';
import '../../../core/models/location_permission_state_model.dart';
import '../../../core/models/location_session_model.dart';
import '../../../core/services/live_location_service.dart';
import '../../../core/services/location_permission_service.dart';
import '../../../core/services/location_session_service.dart';
import '../../../core/services/location_service.dart';

class LocationController {
  LocationController._();

  static Future<LocationModel> getCurrentLocation() async {
    return await LocationService.getCurrentLocation();
  }

  static Future<LocationPermissionStateModel> checkLocationPermission() {
    return LocationPermissionService.checkPermissionState();
  }

  static Future<LocationPermissionStateModel> requestLocationPermission() {
    return LocationPermissionService.requestForegroundPermission();
  }

  static Future<LocationSessionModel> startLocationSession({
    required String userId,
    required String trackingReason,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) {
    return LocationSessionService.startSession(
      userId: userId,
      trackingReason: trackingReason,
      metadata: metadata,
    );
  }

  static Future<LocationSessionModel?> loadActiveLocationSession(
    String userId,
  ) {
    return LocationSessionService.fetchActiveSessionForUser(userId);
  }

  static Future<LocationSessionModel> pauseLocationSession(
    LocationSessionModel session,
  ) async {
    final pausedSession = await LocationSessionService.pauseSession(session);
    await LiveLocationService.markPaused(
      userId: session.userId,
      sessionId: session.id,
      trackingReason: session.trackingReason,
    );
    return pausedSession;
  }

  static Future<LocationSessionModel> resumeLocationSession(
    LocationSessionModel session,
  ) {
    return LocationSessionService.resumeSession(session);
  }

  static Future<LocationSessionModel> stopLocationSession({
    required LocationSessionModel session,
    required String stopReason,
  }) async {
    final stoppedSession = await LocationSessionService.stopSession(
      session: session,
      stopReason: stopReason,
    );
    await LiveLocationService.markOffline(
      userId: session.userId,
      sessionId: session.id,
      trackingReason: session.trackingReason,
    );
    return stoppedSession;
  }

  static Future<StreamSubscription<LiveLocationModel>>
      startForegroundLiveLocationUpdates({
    required LocationSessionModel session,
    void Function(LiveLocationModel location)? onLocation,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    return LiveLocationService.startForegroundTracking(
      session: session,
      onLocation: onLocation,
      onError: onError,
    );
  }

  static Future<LiveLocationModel?> loadLiveLocation(String userId) {
    return LiveLocationService.fetchLiveLocation(userId);
  }
}
