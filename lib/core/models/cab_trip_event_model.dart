import 'package:cloud_firestore/cloud_firestore.dart';

/// Immutable audit event for a cab trip.
class CabTripEventModel {
  /// Firestore document id.
  final String id;

  /// Reference to `cab_trips/{tripId}`.
  final String tripId;

  /// Reference to `cab_assignments/{assignmentId}`.
  final String assignmentId;

  /// Reference to `users/{uid}` for the actor who caused the event.
  final String actorUserId;

  /// Event type, for example `trip_created`, `ready`, or `boarded`.
  final String eventType;

  /// Human-readable audit message.
  final String message;

  /// Event timestamp.
  final DateTime? createdAt;

  /// Additional event metadata without identity duplication.
  final Map<String, dynamic> metadata;

  /// Creates a cab trip audit event model.
  const CabTripEventModel({
    this.id = '',
    this.tripId = '',
    this.assignmentId = '',
    this.actorUserId = '',
    this.eventType = '',
    this.message = '',
    this.createdAt,
    this.metadata = const <String, dynamic>{},
  });

  /// Creates an event model from a Firestore document map.
  factory CabTripEventModel.fromMap(
    Map<String, dynamic> map, {
    String id = '',
  }) {
    return CabTripEventModel(
      id: id.isNotEmpty ? id : (map['id'] ?? '').toString(),
      tripId: (map['tripId'] ?? '').toString(),
      assignmentId: (map['assignmentId'] ?? '').toString(),
      actorUserId: (map['actorUserId'] ?? '').toString(),
      eventType: (map['eventType'] ?? '').toString(),
      message: (map['message'] ?? '').toString(),
      createdAt: _parseDateTime(map['createdAt']),
      metadata: _parseMetadata(map['metadata']),
    );
  }

  /// Converts the event model to a Firestore-safe document map.
  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'assignmentId': assignmentId,
      'actorUserId': actorUserId,
      'eventType': eventType,
      'message': message,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'metadata': metadata,
    };
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
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
