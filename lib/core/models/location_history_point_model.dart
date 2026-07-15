import 'package:cloud_firestore/cloud_firestore.dart';

import 'live_location_model.dart';

class LocationHistoryPointModel {
  final String id;
  final String userId;
  final String sessionId;
  final String trackingReason;
  final int sequence;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed;
  final double heading;
  final String source;
  final String syncStatus;
  final DateTime recordedAt;

  const LocationHistoryPointModel({
    required this.id,
    required this.userId,
    required this.sessionId,
    required this.trackingReason,
    required this.sequence,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.speed,
    required this.heading,
    required this.source,
    required this.syncStatus,
    required this.recordedAt,
  });

  factory LocationHistoryPointModel.fromLiveLocation({
    required LiveLocationModel location,
    required int sequence,
  }) {
    return LocationHistoryPointModel(
      id: '',
      userId: location.userId,
      sessionId: location.sessionId,
      trackingReason: location.trackingReason,
      sequence: sequence,
      latitude: location.latitude,
      longitude: location.longitude,
      accuracy: location.accuracy,
      speed: location.speed,
      heading: location.heading,
      source: location.source,
      syncStatus: location.syncStatus,
      recordedAt: location.recordedAt,
    );
  }

  factory LocationHistoryPointModel.fromMap(
    Map<String, dynamic> map, {
    String id = '',
  }) {
    return LocationHistoryPointModel(
      id: id.isNotEmpty ? id : (map['id'] ?? ''),
      userId: map['userId'] ?? '',
      sessionId: map['sessionId'] ?? '',
      trackingReason: map['trackingReason'] ?? '',
      sequence: _parseInt(map['sequence']),
      latitude: _parseDouble(map['latitude']),
      longitude: _parseDouble(map['longitude']),
      accuracy: _parseDouble(map['accuracy']),
      speed: _parseDouble(map['speed']),
      heading: _parseDouble(map['heading']),
      source: map['source'] ?? '',
      syncStatus: map['syncStatus'] ?? 'synced',
      recordedAt: _parseDateTime(map['recordedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'sessionId': sessionId,
      'trackingReason': trackingReason,
      'sequence': sequence,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'speed': speed,
      'heading': heading,
      'source': source,
      'syncStatus': syncStatus,
      'recordedAt': Timestamp.fromDate(recordedAt),
    };
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  static int _parseInt(Object? value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseDouble(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
