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

  /// Branch scope copied from the Employee profile for secure Driver queries.
  final String branch;

  /// Service-centre scope copied from the Employee profile.
  final String serviceCentre;

  /// Start of the operational day represented by [dateKey].
  final DateTime? operationalDay;

  /// Reference to `users/{uid}` for the assigned cab driver.
  final String driverId;

  /// Reference to `cab_vehicles/{vehicleId}`.
  final String vehicleId;

  /// Member status, for example `assigned`, `ready`, or `boarded`.
  final String status;

  /// Invitation lifecycle, separate from trip/rider progress.
  final String invitationStatus;

  /// Active Driver shift that created the invitation.
  final String shiftId;

  /// Optional Employee-provided decline reason.
  final String declineReason;

  /// Time the Driver sent the invitation.
  final DateTime? invitedAt;

  /// Time the Employee accepted or declined.
  final DateTime? respondedAt;

  /// Immutable office destination snapshot shown with the invitation.
  final String officeName;
  final String officeAddress;
  final double? officeLatitude;
  final double? officeLongitude;

  /// Snapshot of assigned pickup location name.
  final String pickupName;

  /// Snapshot of assigned pickup address.
  final String pickupAddress;

  /// Snapshot of assigned pickup latitude.
  final double? pickupLatitude;

  /// Snapshot of assigned pickup longitude.
  final double? pickupLongitude;

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
    this.branch = '',
    this.serviceCentre = '',
    this.operationalDay,
    this.driverId = '',
    this.vehicleId = '',
    this.status = 'assigned',
    this.invitationStatus = 'not_invited',
    this.shiftId = '',
    this.declineReason = '',
    this.invitedAt,
    this.respondedAt,
    this.officeName = '',
    this.officeAddress = '',
    this.officeLatitude,
    this.officeLongitude,
    this.pickupName = '',
    this.pickupAddress = '',
    this.pickupLatitude,
    this.pickupLongitude,
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
      branch: (map['branch'] ?? '').toString(),
      serviceCentre: (map['serviceCentre'] ?? '').toString(),
      operationalDay: _parseDateTime(map['operationalDay']),
      driverId: (map['driverId'] ?? '').toString(),
      vehicleId: (map['vehicleId'] ?? '').toString(),
      status: (map['status'] ?? 'assigned').toString(),
      invitationStatus: (map['invitationStatus'] ?? 'not_invited').toString(),
      shiftId: (map['shiftId'] ?? '').toString(),
      declineReason: (map['declineReason'] ?? '').toString(),
      invitedAt: _parseDateTime(map['invitedAt']),
      respondedAt: _parseDateTime(map['respondedAt']),
      officeName: (map['officeName'] ?? '').toString(),
      officeAddress: (map['officeAddress'] ?? '').toString(),
      officeLatitude: _parseNullableDouble(map['officeLatitude']),
      officeLongitude: _parseNullableDouble(map['officeLongitude']),
      pickupName: (map['pickupName'] ?? '').toString(),
      pickupAddress: (map['pickupAddress'] ?? '').toString(),
      pickupLatitude: _parseNullableDouble(map['pickupLatitude']),
      pickupLongitude: _parseNullableDouble(map['pickupLongitude']),
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
      'branch': branch,
      'serviceCentre': serviceCentre,
      'operationalDay': operationalDay == null
          ? null
          : Timestamp.fromDate(operationalDay!),
      'driverId': driverId,
      'vehicleId': vehicleId,
      'status': status,
      'invitationStatus': invitationStatus,
      'shiftId': shiftId,
      'declineReason': declineReason,
      'invitedAt': invitedAt == null ? null : Timestamp.fromDate(invitedAt!),
      'respondedAt': respondedAt == null
          ? null
          : Timestamp.fromDate(respondedAt!),
      'officeName': officeName,
      'officeAddress': officeAddress,
      'officeLatitude': officeLatitude,
      'officeLongitude': officeLongitude,
      'pickupName': pickupName,
      'pickupAddress': pickupAddress,
      'pickupLatitude': pickupLatitude,
      'pickupLongitude': pickupLongitude,
      'pickupValid':
          pickupName.trim().isNotEmpty &&
          pickupAddress.trim().isNotEmpty &&
          pickupLatitude != null &&
          pickupLongitude != null &&
          pickupLatitude!.isFinite &&
          pickupLongitude!.isFinite &&
          pickupLatitude! >= -90 &&
          pickupLatitude! <= 90 &&
          pickupLongitude! >= -180 &&
          pickupLongitude! <= 180,
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
    String? branch,
    String? serviceCentre,
    DateTime? operationalDay,
    String? driverId,
    String? vehicleId,
    String? status,
    String? invitationStatus,
    String? shiftId,
    String? declineReason,
    DateTime? invitedAt,
    DateTime? respondedAt,
    String? officeName,
    String? officeAddress,
    double? officeLatitude,
    double? officeLongitude,
    String? pickupName,
    String? pickupAddress,
    double? pickupLatitude,
    double? pickupLongitude,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CabAssignmentMemberModel(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
      dateKey: dateKey ?? this.dateKey,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      branch: branch ?? this.branch,
      serviceCentre: serviceCentre ?? this.serviceCentre,
      operationalDay: operationalDay ?? this.operationalDay,
      driverId: driverId ?? this.driverId,
      vehicleId: vehicleId ?? this.vehicleId,
      status: status ?? this.status,
      invitationStatus: invitationStatus ?? this.invitationStatus,
      shiftId: shiftId ?? this.shiftId,
      declineReason: declineReason ?? this.declineReason,
      invitedAt: invitedAt ?? this.invitedAt,
      respondedAt: respondedAt ?? this.respondedAt,
      officeName: officeName ?? this.officeName,
      officeAddress: officeAddress ?? this.officeAddress,
      officeLatitude: officeLatitude ?? this.officeLatitude,
      officeLongitude: officeLongitude ?? this.officeLongitude,
      pickupName: pickupName ?? this.pickupName,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      createdAt: createdAt is DateTime ? createdAt : this.createdAt,
      updatedAt: updatedAt is DateTime ? updatedAt : this.updatedAt,
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
