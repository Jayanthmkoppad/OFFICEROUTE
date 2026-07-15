import 'package:cloud_firestore/cloud_firestore.dart';

class LocationSessionModel {
  final String id;
  final String userId;
  final String trackingReason;
  final String status;
  final DateTime startedAt;
  final DateTime? pausedAt;
  final DateTime? resumedAt;
  final DateTime? stoppedAt;
  final double? lastLatitude;
  final double? lastLongitude;
  final DateTime? lastUpdatedAt;
  final String stopReason;
  final Map<String, dynamic> metadata;

  const LocationSessionModel({
    required this.id,
    required this.userId,
    required this.trackingReason,
    required this.status,
    required this.startedAt,
    required this.pausedAt,
    required this.resumedAt,
    required this.stoppedAt,
    required this.lastLatitude,
    required this.lastLongitude,
    required this.lastUpdatedAt,
    required this.stopReason,
    required this.metadata,
  });

  factory LocationSessionModel.started({
    required String userId,
    required String trackingReason,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) {
    return LocationSessionModel(
      id: '',
      userId: userId,
      trackingReason: trackingReason,
      status: 'active',
      startedAt: DateTime.now(),
      pausedAt: null,
      resumedAt: null,
      stoppedAt: null,
      lastLatitude: null,
      lastLongitude: null,
      lastUpdatedAt: null,
      stopReason: '',
      metadata: metadata,
    );
  }

  factory LocationSessionModel.fromMap(
    Map<String, dynamic> map, {
    String id = '',
  }) {
    return LocationSessionModel(
      id: id.isNotEmpty ? id : (map['id'] ?? ''),
      userId: map['userId'] ?? '',
      trackingReason: map['trackingReason'] ?? '',
      status: map['status'] ?? '',
      startedAt: _parseDateTime(map['startedAt']) ?? DateTime.now(),
      pausedAt: _parseDateTime(map['pausedAt']),
      resumedAt: _parseDateTime(map['resumedAt']),
      stoppedAt: _parseDateTime(map['stoppedAt']),
      lastLatitude: _parseNullableDouble(map['lastLatitude']),
      lastLongitude: _parseNullableDouble(map['lastLongitude']),
      lastUpdatedAt: _parseDateTime(map['lastUpdatedAt']),
      stopReason: map['stopReason'] ?? '',
      metadata: _parseMetadata(map['metadata']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'trackingReason': trackingReason,
      'status': status,
      'startedAt': Timestamp.fromDate(startedAt),
      'pausedAt': pausedAt == null ? null : Timestamp.fromDate(pausedAt!),
      'resumedAt': resumedAt == null ? null : Timestamp.fromDate(resumedAt!),
      'stoppedAt': stoppedAt == null ? null : Timestamp.fromDate(stoppedAt!),
      'lastLatitude': lastLatitude,
      'lastLongitude': lastLongitude,
      'lastUpdatedAt': lastUpdatedAt == null
          ? null
          : Timestamp.fromDate(lastUpdatedAt!),
      'stopReason': stopReason,
      'metadata': metadata,
    };
  }

  LocationSessionModel copyWith({
    String? id,
    String? userId,
    String? trackingReason,
    String? status,
    DateTime? startedAt,
    DateTime? pausedAt,
    DateTime? resumedAt,
    DateTime? stoppedAt,
    double? lastLatitude,
    double? lastLongitude,
    DateTime? lastUpdatedAt,
    String? stopReason,
    Map<String, dynamic>? metadata,
    bool clearPausedAt = false,
    bool clearStoppedAt = false,
  }) {
    return LocationSessionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      trackingReason: trackingReason ?? this.trackingReason,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
      resumedAt: resumedAt ?? this.resumedAt,
      stoppedAt: clearStoppedAt ? null : (stoppedAt ?? this.stoppedAt),
      lastLatitude: lastLatitude ?? this.lastLatitude,
      lastLongitude: lastLongitude ?? this.lastLongitude,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      stopReason: stopReason ?? this.stopReason,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isActive => status == 'active';

  bool get isPaused => status == 'paused';

  bool get isStopped => status == 'stopped';

  static DateTime? _parseDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  static double? _parseNullableDouble(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static Map<String, dynamic> _parseMetadata(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const <String, dynamic>{};
  }
}
