import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class LiveLocationModel {
  final String userId;
  final String sessionId;
  final String trackingReason;
  final String status;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double altitude;
  final double speed;
  final double heading;
  final bool isForeground;
  final String source;
  final String syncStatus;
  final DateTime recordedAt;
  final DateTime updatedAt;

  const LiveLocationModel({
    required this.userId,
    required this.sessionId,
    required this.trackingReason,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.altitude,
    required this.speed,
    required this.heading,
    required this.isForeground,
    required this.source,
    required this.syncStatus,
    required this.recordedAt,
    required this.updatedAt,
  });

  factory LiveLocationModel.fromPosition({
    required String userId,
    required String sessionId,
    required String trackingReason,
    required String status,
    required Position position,
    required bool isForeground,
    String source = 'geolocator',
    String syncStatus = 'pending',
  }) {
    final now = DateTime.now();

    return LiveLocationModel(
      userId: userId,
      sessionId: sessionId,
      trackingReason: trackingReason,
      status: status,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      altitude: position.altitude,
      speed: position.speed,
      heading: position.heading,
      isForeground: isForeground,
      source: source,
      syncStatus: syncStatus,
      recordedAt: position.timestamp,
      updatedAt: now,
    );
  }

  factory LiveLocationModel.fromMap(Map<String, dynamic> map) {
    return LiveLocationModel(
      userId: map['userId'] ?? '',
      sessionId: map['sessionId'] ?? '',
      trackingReason: map['trackingReason'] ?? '',
      status: map['status'] ?? '',
      latitude: _parseDouble(map['latitude']),
      longitude: _parseDouble(map['longitude']),
      accuracy: _parseDouble(map['accuracy']),
      altitude: _parseDouble(map['altitude']),
      speed: _parseDouble(map['speed']),
      heading: _parseDouble(map['heading']),
      isForeground: map['isForeground'] == true,
      source: map['source'] ?? '',
      syncStatus: map['syncStatus'] ?? 'synced',
      recordedAt: _parseDateTime(map['recordedAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'sessionId': sessionId,
      'trackingReason': trackingReason,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'heading': heading,
      'isForeground': isForeground,
      'source': source,
      'syncStatus': syncStatus,
      'recordedAt': Timestamp.fromDate(recordedAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  LiveLocationModel copyWith({
    String? userId,
    String? sessionId,
    String? trackingReason,
    String? status,
    double? latitude,
    double? longitude,
    double? accuracy,
    double? altitude,
    double? speed,
    double? heading,
    bool? isForeground,
    String? source,
    String? syncStatus,
    DateTime? recordedAt,
    DateTime? updatedAt,
  }) {
    return LiveLocationModel(
      userId: userId ?? this.userId,
      sessionId: sessionId ?? this.sessionId,
      trackingReason: trackingReason ?? this.trackingReason,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      isForeground: isForeground ?? this.isForeground,
      source: source ?? this.source,
      syncStatus: syncStatus ?? this.syncStatus,
      recordedAt: recordedAt ?? this.recordedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  static double _parseDouble(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
