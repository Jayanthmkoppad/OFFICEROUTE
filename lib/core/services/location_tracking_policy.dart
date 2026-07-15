import 'dart:math' as math;

import '../models/live_location_model.dart';

class LocationTrackingPolicy {
  LocationTrackingPolicy._();

  static const String reasonFieldDuty = 'field_duty';
  static const String reasonActiveVisit = 'active_visit';
  static const String reasonCabTrip = 'cab_trip';
  static const String reasonCabPickupReady = 'cab_pickup_ready';

  static const String statusActive = 'active';
  static const String statusPaused = 'paused';
  static const String statusStopped = 'stopped';
  static const String statusOffline = 'offline';

  static const Duration minimumLiveUpdateInterval = Duration(seconds: 5);
  static const Duration minimumHistoryUpdateInterval = Duration(seconds: 30);
  static const Duration staleLocationAfter = Duration(minutes: 2);

  static const double minimumLiveDistanceMeters = 20;
  static const double minimumHistoryDistanceMeters = 50;
  static const double maximumAcceptedAccuracyMeters = 100;

  static bool isSupportedTrackingReason(String trackingReason) {
    return <String>{
      reasonFieldDuty,
      reasonActiveVisit,
      reasonCabTrip,
      reasonCabPickupReady,
    }.contains(trackingReason);
  }

  static bool canStartTracking({
    required String trackingReason,
    required bool isDutyActive,
    required bool isVisitActive,
    required bool isCabTripActive,
  }) {
    if (!isSupportedTrackingReason(trackingReason)) return false;

    switch (trackingReason) {
      case reasonFieldDuty:
        return isDutyActive;
      case reasonActiveVisit:
        return isVisitActive;
      case reasonCabTrip:
        return isCabTripActive;
      case reasonCabPickupReady:
        return isDutyActive || isCabTripActive;
      default:
        return false;
    }
  }

  static bool shouldWriteLiveLocation({
    required LiveLocationModel next,
    LiveLocationModel? previous,
  }) {
    if (previous == null) return true;
    if (previous.status != next.status) return true;
    if (next.accuracy > maximumAcceptedAccuracyMeters) return false;

    final elapsed = next.recordedAt.difference(previous.recordedAt).abs();
    if (elapsed >= minimumLiveUpdateInterval) return true;

    final movedMeters = distanceMeters(
      previous.latitude,
      previous.longitude,
      next.latitude,
      next.longitude,
    );

    return movedMeters >= minimumLiveDistanceMeters;
  }

  static bool shouldWriteHistoryPoint({
    required LiveLocationModel next,
    LiveLocationModel? previousHistoryLocation,
  }) {
    if (previousHistoryLocation == null) return true;
    if (next.accuracy > maximumAcceptedAccuracyMeters) return false;

    final elapsed =
        next.recordedAt.difference(previousHistoryLocation.recordedAt).abs();
    final movedMeters = distanceMeters(
      previousHistoryLocation.latitude,
      previousHistoryLocation.longitude,
      next.latitude,
      next.longitude,
    );

    return elapsed >= minimumHistoryUpdateInterval ||
        movedMeters >= minimumHistoryDistanceMeters;
  }

  static bool isStale(DateTime lastUpdatedAt, DateTime now) {
    return now.difference(lastUpdatedAt) > staleLocationAfter;
  }

  static double distanceMeters(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    const earthRadiusMeters = 6371000.0;
    final startLatRad = _degreesToRadians(startLatitude);
    final endLatRad = _degreesToRadians(endLatitude);
    final deltaLat = _degreesToRadians(endLatitude - startLatitude);
    final deltaLng = _degreesToRadians(endLongitude - startLongitude);

    final haversine = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(startLatRad) *
            math.cos(endLatRad) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    final angularDistance = 2 * math.atan2(
      math.sqrt(haversine),
      math.sqrt(1 - haversine),
    );

    return earthRadiusMeters * angularDistance;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}
