import 'package:cloud_firestore/cloud_firestore.dart';

/// Privacy-safe passenger progress projection model stored under
/// `cab_trips/{tripId}/passenger_progress/{employeeId}`.
///
/// Strictly excludes raw GPS coordinates, addresses, and location history.
class PassengerProgressModel {
  final String employeeId;
  final String passengerDisplayName;
  final String employeeCode;
  final String roleLabel;
  final int pickupSequence;
  final String status;
  final String remark;
  final bool attendanceActive;
  final bool transportActive;
  final double? distanceToPickupMeters;
  final int? estimatedReadyMinutes;

  /// Stable state representation: 'live', 'stale', 'offline', 'unknown'.
  final String locationFreshness;
  final DateTime? updatedAt;

  const PassengerProgressModel({
    required this.employeeId,
    required this.passengerDisplayName,
    this.employeeCode = '',
    this.roleLabel = 'Employee',
    required this.pickupSequence,
    required this.status,
    this.remark = '',
    this.attendanceActive = false,
    this.transportActive = true,
    this.distanceToPickupMeters,
    this.estimatedReadyMinutes,
    required this.locationFreshness,
    this.updatedAt,
  });

  factory PassengerProgressModel.fromMap(
    Map<String, dynamic> map, {
    String id = '',
  }) {
    DateTime? parseTimestamp(Object? value) {
      if (value is DateTime) return value;
      if (value is Timestamp) return value.toDate();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }

    double? parseDouble(Object? value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    int? parseInt(Object? value) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    return PassengerProgressModel(
      employeeId: id.isNotEmpty ? id : (map['employeeId'] ?? '').toString(),
      passengerDisplayName: (map['passengerDisplayName'] ?? 'Passenger')
          .toString(),
      employeeCode: (map['employeeCode'] ?? '').toString(),
      roleLabel: (map['roleLabel'] ?? 'Employee').toString(),
      pickupSequence: parseInt(map['pickupSequence']) ?? 0,
      status: (map['status'] ?? 'assigned').toString(),
      remark: (map['remark'] ?? '').toString(),
      attendanceActive: map['attendanceActive'] == true,
      transportActive: map['transportActive'] != false,
      distanceToPickupMeters: parseDouble(map['distanceToPickupMeters']),
      estimatedReadyMinutes: parseInt(map['estimatedReadyMinutes']),
      locationFreshness: (map['locationFreshness'] ?? 'unknown').toString(),
      updatedAt: parseTimestamp(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'passengerDisplayName': passengerDisplayName,
      'employeeCode': employeeCode,
      'roleLabel': roleLabel,
      'pickupSequence': pickupSequence,
      'status': status,
      'remark': remark,
      'attendanceActive': attendanceActive,
      'transportActive': transportActive,
      'distanceToPickupMeters': distanceToPickupMeters,
      'estimatedReadyMinutes': estimatedReadyMinutes,
      'locationFreshness': locationFreshness,
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : Timestamp.now(),
    };
  }

  /// Calculates human-readable age text from [updatedAt] relative to [now].
  String formatAge(DateTime now) {
    final updated = updatedAt;
    if (updated == null) return '—';
    final diff = now.difference(updated);
    if (diff.inSeconds < 0) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  PassengerProgressModel copyWith({
    String? employeeId,
    String? passengerDisplayName,
    String? employeeCode,
    String? roleLabel,
    int? pickupSequence,
    String? status,
    String? remark,
    bool? attendanceActive,
    bool? transportActive,
    double? distanceToPickupMeters,
    int? estimatedReadyMinutes,
    String? locationFreshness,
    DateTime? updatedAt,
  }) {
    return PassengerProgressModel(
      employeeId: employeeId ?? this.employeeId,
      passengerDisplayName: passengerDisplayName ?? this.passengerDisplayName,
      employeeCode: employeeCode ?? this.employeeCode,
      roleLabel: roleLabel ?? this.roleLabel,
      pickupSequence: pickupSequence ?? this.pickupSequence,
      status: status ?? this.status,
      remark: remark ?? this.remark,
      attendanceActive: attendanceActive ?? this.attendanceActive,
      transportActive: transportActive ?? this.transportActive,
      distanceToPickupMeters:
          distanceToPickupMeters ?? this.distanceToPickupMeters,
      estimatedReadyMinutes:
          estimatedReadyMinutes ?? this.estimatedReadyMinutes,
      locationFreshness: locationFreshness ?? this.locationFreshness,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
