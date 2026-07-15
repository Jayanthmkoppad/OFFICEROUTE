import 'package:cloud_firestore/cloud_firestore.dart';

/// Optimized daily lookup entry for a user assigned to a cab.
///
/// Store these documents in `cab_assignment_members` using a stable id such as
/// `{dateKey}_{userId}`. This avoids expensive array scans when a driver or
/// employee opens Cab Tracking.
class CabAssignmentMemberModel {
  /// Firestore document id.
  final String id;

  /// Reference to `cab_assignments/{assignmentId}`.
  final String assignmentId;

  /// Stable local-date key in `yyyy-MM-dd` format.
  final String dateKey;

  /// Reference to `users/{uid}` for this member.
  final String userId;

  /// Member role for the assignment, usually `driver` or `employee`.
  final String role;

  /// Reference to `users/{uid}` for the assigned cab driver.
  final String driverId;

  /// Reference to `cab_vehicles/{vehicleId}`.
  final String vehicleId;

  /// Member status, for example `assigned`, `ready`, or `boarded`.
  final String status;

  /// Creation timestamp.
  final DateTime? createdAt;

  /// Last update timestamp.
  final DateTime? updatedAt;

  /// Creates a cab assignment member lookup model.
  const CabAssignmentMemberModel({
    this.id = '',
    this.assignmentId = '',
    this.dateKey = '',
    this.userId = '',
    this.role = 'employee',
    this.driverId = '',
    this.vehicleId = '',
    this.status = 'assigned',
    this.createdAt,
    this.updatedAt,
  });

  /// Creates a member lookup model from a Firestore document map.
  factory CabAssignmentMemberModel.fromMap(
    Map<String, dynamic> map, {
    String id = '',
  }) {
    return CabAssignmentMemberModel(
      id: id.isNotEmpty ? id : (map['id'] ?? '').toString(),
      assignmentId: (map['assignmentId'] ?? '').toString(),
      dateKey: (map['dateKey'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      role: (map['role'] ?? 'employee').toString(),
      driverId: (map['driverId'] ?? '').toString(),
      vehicleId: (map['vehicleId'] ?? '').toString(),
      status: (map['status'] ?? 'assigned').toString(),
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }

  /// Converts the member lookup model to a Firestore-safe document map.
  Map<String, dynamic> toMap() {
    return {
      'assignmentId': assignmentId,
      'dateKey': dateKey,
      'userId': userId,
      'role': role,
      'driverId': driverId,
      'vehicleId': vehicleId,
      'status': status,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  /// Returns a copy with selected fields changed.
  CabAssignmentMemberModel copyWith({
    String? id,
    String? assignmentId,
    String? dateKey,
    String? userId,
    String? role,
    String? driverId,
    String? vehicleId,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CabAssignmentMemberModel(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
      dateKey: dateKey ?? this.dateKey,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      driverId: driverId ?? this.driverId,
      vehicleId: vehicleId ?? this.vehicleId,
      status: status ?? this.status,
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
}
