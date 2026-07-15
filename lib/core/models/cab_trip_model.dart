import 'package:cloud_firestore/cloud_firestore.dart';

/// Trip instance created from a daily cab assignment.
///
/// Live coordinates are intentionally not stored here. Cab live location uses
/// the existing Location Foundation (`live_locations` and `location_sessions`).
class CabTripModel {
  /// Firestore document id.
  final String id;

  /// Reference to `cab_assignments/{assignmentId}`.
  final String assignmentId;

  /// Stable local-date key in `yyyy-MM-dd` format.
  final String dateKey;

  /// Reference to `users/{uid}` for the driver.
  final String driverId;

  /// Reference to `cab_vehicles/{vehicleId}`.
  final String vehicleId;

  /// Trip status, for example `created`, `active`, or `completed`.
  final String status;

  /// Active `location_sessions/{sessionId}` used by cab live tracking.
  final String activeLocationSessionId;

  /// Time when the trip document was created.
  final DateTime? createdAt;

  /// Time when the driver started the trip.
  final DateTime? startedAt;

  /// Time when the cab reached office.
  final DateTime? officeArrivedAt;

  /// Time when the trip was completed.
  final DateTime? completedAt;

  /// Last update timestamp.
  final DateTime? updatedAt;

  /// Internal remarks for operations.
  final String remarks;

  /// Creates a cab trip model.
  const CabTripModel({
    this.id = '',
    this.assignmentId = '',
    this.dateKey = '',
    this.driverId = '',
    this.vehicleId = '',
    this.status = 'created',
    this.activeLocationSessionId = '',
    this.createdAt,
    this.startedAt,
    this.officeArrivedAt,
    this.completedAt,
    this.updatedAt,
    this.remarks = '',
  });

  /// Creates a trip model from a Firestore document map.
  factory CabTripModel.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return CabTripModel(
      id: id.isNotEmpty ? id : (map['id'] ?? '').toString(),
      assignmentId: (map['assignmentId'] ?? '').toString(),
      dateKey: (map['dateKey'] ?? '').toString(),
      driverId: (map['driverId'] ?? '').toString(),
      vehicleId: (map['vehicleId'] ?? '').toString(),
      status: (map['status'] ?? 'created').toString(),
      activeLocationSessionId:
          (map['activeLocationSessionId'] ?? '').toString(),
      createdAt: _parseDateTime(map['createdAt']),
      startedAt: _parseDateTime(map['startedAt']),
      officeArrivedAt: _parseDateTime(map['officeArrivedAt']),
      completedAt: _parseDateTime(map['completedAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
      remarks: (map['remarks'] ?? '').toString(),
    );
  }

  /// Converts the trip model to a Firestore-safe document map.
  Map<String, dynamic> toMap() {
    return {
      'assignmentId': assignmentId,
      'dateKey': dateKey,
      'driverId': driverId,
      'vehicleId': vehicleId,
      'status': status,
      'activeLocationSessionId': activeLocationSessionId,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'startedAt': startedAt == null ? null : Timestamp.fromDate(startedAt!),
      'officeArrivedAt': officeArrivedAt == null
          ? null
          : Timestamp.fromDate(officeArrivedAt!),
      'completedAt': completedAt == null
          ? null
          : Timestamp.fromDate(completedAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      'remarks': remarks,
    };
  }

  /// Returns a copy with selected fields changed.
  CabTripModel copyWith({
    String? id,
    String? assignmentId,
    String? dateKey,
    String? driverId,
    String? vehicleId,
    String? status,
    String? activeLocationSessionId,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? officeArrivedAt,
    DateTime? completedAt,
    DateTime? updatedAt,
    String? remarks,
  }) {
    return CabTripModel(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
      dateKey: dateKey ?? this.dateKey,
      driverId: driverId ?? this.driverId,
      vehicleId: vehicleId ?? this.vehicleId,
      status: status ?? this.status,
      activeLocationSessionId:
          activeLocationSessionId ?? this.activeLocationSessionId,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      officeArrivedAt: officeArrivedAt ?? this.officeArrivedAt,
      completedAt: completedAt ?? this.completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      remarks: remarks ?? this.remarks,
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
}
