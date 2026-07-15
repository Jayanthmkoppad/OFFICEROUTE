import 'package:cloud_firestore/cloud_firestore.dart';

/// Daily cab assignment connecting one vehicle, one driver, and employees.
///
/// Driver and employee identity fields are references to `users/{uid}` only.
/// This keeps the existing `users` collection as the single source of identity.
class CabAssignmentModel {
  /// Firestore document id.
  final String id;

  /// Stable local-date key in `yyyy-MM-dd` format.
  final String dateKey;

  /// Calendar date for this assignment.
  final DateTime? assignmentDate;

  /// Reference to `users/{uid}` for the assigned driver.
  final String driverId;

  /// Reference to `cab_vehicles/{vehicleId}`.
  final String vehicleId;

  /// References to `users/{uid}` for assigned employees.
  final List<String> employeeIds;

  /// Office destination display name.
  final String officeName;

  /// Office destination address.
  final String officeAddress;

  /// Office destination latitude.
  final double? officeLatitude;

  /// Office destination longitude.
  final double? officeLongitude;

  /// Assignment status, for example `draft`, `active`, or `completed`.
  final String status;

  /// Reference to `users/{uid}` for the manager/admin who assigned the cab.
  final String assignedBy;

  /// Time when this assignment was created.
  final DateTime? assignedAt;

  /// Time when this assignment was last updated.
  final DateTime? updatedAt;

  /// Internal remarks for operations.
  final String remarks;

  /// Creates a daily cab assignment model.
  const CabAssignmentModel({
    this.id = '',
    this.dateKey = '',
    this.assignmentDate,
    this.driverId = '',
    this.vehicleId = '',
    this.employeeIds = const <String>[],
    this.officeName = '',
    this.officeAddress = '',
    this.officeLatitude,
    this.officeLongitude,
    this.status = 'active',
    this.assignedBy = '',
    this.assignedAt,
    this.updatedAt,
    this.remarks = '',
  });

  /// Creates an assignment model from a Firestore document map.
  factory CabAssignmentModel.fromMap(
    Map<String, dynamic> map, {
    String id = '',
  }) {
    final assignedAt = _parseDateTime(map['assignedAt']);
    final assignmentDate = _parseDateTime(map['assignmentDate']);

    return CabAssignmentModel(
      id: id.isNotEmpty ? id : (map['id'] ?? '').toString(),
      dateKey: (map['dateKey'] ?? _dateKeyFromDate(assignmentDate)).toString(),
      assignmentDate: assignmentDate,
      driverId: (map['driverId'] ?? '').toString(),
      vehicleId: (map['vehicleId'] ?? '').toString(),
      employeeIds: _parseStringList(map['employeeIds']),
      officeName: (map['officeName'] ?? '').toString(),
      officeAddress: (map['officeAddress'] ?? '').toString(),
      officeLatitude: _parseNullableDouble(map['officeLatitude']),
      officeLongitude: _parseNullableDouble(map['officeLongitude']),
      status: (map['status'] ?? 'active').toString(),
      assignedBy: (map['assignedBy'] ?? '').toString(),
      assignedAt: assignedAt,
      updatedAt: _parseDateTime(map['updatedAt']),
      remarks: (map['remarks'] ?? '').toString(),
    );
  }

  /// Converts the assignment model to a Firestore-safe document map.
  Map<String, dynamic> toMap() {
    return {
      'dateKey': dateKey,
      'assignmentDate': assignmentDate == null
          ? null
          : Timestamp.fromDate(_dateOnly(assignmentDate!)),
      'driverId': driverId,
      'vehicleId': vehicleId,
      'employeeIds': employeeIds,
      'officeName': officeName,
      'officeAddress': officeAddress,
      'officeLatitude': officeLatitude,
      'officeLongitude': officeLongitude,
      'status': status,
      'assignedBy': assignedBy,
      'assignedAt': assignedAt == null ? null : Timestamp.fromDate(assignedAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      'remarks': remarks,
    };
  }

  /// Returns a copy with selected fields changed.
  CabAssignmentModel copyWith({
    String? id,
    String? dateKey,
    DateTime? assignmentDate,
    String? driverId,
    String? vehicleId,
    List<String>? employeeIds,
    String? officeName,
    String? officeAddress,
    double? officeLatitude,
    double? officeLongitude,
    String? status,
    String? assignedBy,
    DateTime? assignedAt,
    DateTime? updatedAt,
    String? remarks,
  }) {
    return CabAssignmentModel(
      id: id ?? this.id,
      dateKey: dateKey ?? this.dateKey,
      assignmentDate: assignmentDate ?? this.assignmentDate,
      driverId: driverId ?? this.driverId,
      vehicleId: vehicleId ?? this.vehicleId,
      employeeIds: employeeIds ?? this.employeeIds,
      officeName: officeName ?? this.officeName,
      officeAddress: officeAddress ?? this.officeAddress,
      officeLatitude: officeLatitude ?? this.officeLatitude,
      officeLongitude: officeLongitude ?? this.officeLongitude,
      status: status ?? this.status,
      assignedBy: assignedBy ?? this.assignedBy,
      assignedAt: assignedAt ?? this.assignedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      remarks: remarks ?? this.remarks,
    );
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static String _dateKeyFromDate(DateTime? value) {
    if (value == null) return '';
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
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

  static List<String> _parseStringList(Object? value) {
    if (value is List) {
      return value
          .whereType<Object>()
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    return const <String>[];
  }
}
