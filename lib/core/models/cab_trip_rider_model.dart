import 'package:cloud_firestore/cloud_firestore.dart';

/// Per-employee state inside a cab trip.
class CabTripRiderModel {
  /// Firestore document id, normally the employee user id.
  final String id;

  /// Reference to `cab_trips/{tripId}`.
  final String tripId;

  /// Reference to `cab_assignments/{assignmentId}`.
  final String assignmentId;

  /// Reference to `users/{uid}` for the employee.
  final String employeeId;

  /// Rider status, for example `assigned`, `ready`, `picked_up`, or `boarded`.
  final String status;

  /// Time when the employee tapped "I'm Ready".
  final DateTime? readyAt;

  /// Time when the driver reached the pickup.
  final DateTime? pickedUpAt;

  /// Time when the employee boarded the cab.
  final DateTime? boardedAt;

  /// Pickup latitude captured when the employee becomes ready.
  final double? pickupLatitude;

  /// Pickup longitude captured when the employee becomes ready.
  final double? pickupLongitude;

  /// Creation timestamp.
  final DateTime? createdAt;

  /// Last update timestamp.
  final DateTime? updatedAt;

  /// Creates a cab trip rider model.
  const CabTripRiderModel({
    this.id = '',
    this.tripId = '',
    this.assignmentId = '',
    this.employeeId = '',
    this.status = 'assigned',
    this.readyAt,
    this.pickedUpAt,
    this.boardedAt,
    this.pickupLatitude,
    this.pickupLongitude,
    this.createdAt,
    this.updatedAt,
  });

  /// Creates a rider model from a Firestore document map.
  factory CabTripRiderModel.fromMap(
    Map<String, dynamic> map, {
    String id = '',
  }) {
    return CabTripRiderModel(
      id: id.isNotEmpty ? id : (map['id'] ?? '').toString(),
      tripId: (map['tripId'] ?? '').toString(),
      assignmentId: (map['assignmentId'] ?? '').toString(),
      employeeId: (map['employeeId'] ?? '').toString(),
      status: (map['status'] ?? 'assigned').toString(),
      readyAt: _parseDateTime(map['readyAt']),
      pickedUpAt: _parseDateTime(map['pickedUpAt']),
      boardedAt: _parseDateTime(map['boardedAt']),
      pickupLatitude: _parseNullableDouble(map['pickupLatitude']),
      pickupLongitude: _parseNullableDouble(map['pickupLongitude']),
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }

  /// Converts the rider model to a Firestore-safe document map.
  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'assignmentId': assignmentId,
      'employeeId': employeeId,
      'status': status,
      'readyAt': readyAt == null ? null : Timestamp.fromDate(readyAt!),
      'pickedUpAt': pickedUpAt == null ? null : Timestamp.fromDate(pickedUpAt!),
      'boardedAt': boardedAt == null ? null : Timestamp.fromDate(boardedAt!),
      'pickupLatitude': pickupLatitude,
      'pickupLongitude': pickupLongitude,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  /// Returns a copy with selected fields changed.
  CabTripRiderModel copyWith({
    String? id,
    String? tripId,
    String? assignmentId,
    String? employeeId,
    String? status,
    DateTime? readyAt,
    DateTime? pickedUpAt,
    DateTime? boardedAt,
    double? pickupLatitude,
    double? pickupLongitude,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CabTripRiderModel(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      assignmentId: assignmentId ?? this.assignmentId,
      employeeId: employeeId ?? this.employeeId,
      status: status ?? this.status,
      readyAt: readyAt ?? this.readyAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      boardedAt: boardedAt ?? this.boardedAt,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
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

  static double? _parseNullableDouble(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
