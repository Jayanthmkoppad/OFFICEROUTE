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

  /// Employee user ids linked to this trip.
  final List<String> employeeIds;

  /// Configured office destination and operational scope.
  final String officeName;
  final String officeAddress;
  final double? officeLatitude;
  final double? officeLongitude;
  final String branch;
  final String serviceCentre;

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
  final String cancellationReason;
  final String cancellationExplanation;
  final String cancelledBy;
  final DateTime? cancelledAt;
  final double distanceKm;
  final int durationSeconds;
  final int drivingSeconds;
  final int idleSeconds;

  /// Creates a cab trip model.
  const CabTripModel({
    this.id = '',
    this.assignmentId = '',
    this.dateKey = '',
    this.driverId = '',
    this.vehicleId = '',
    this.employeeIds = const <String>[],
    this.officeName = '',
    this.officeAddress = '',
    this.officeLatitude,
    this.officeLongitude,
    this.branch = '',
    this.serviceCentre = '',
    this.status = 'created',
    this.activeLocationSessionId = '',
    this.createdAt,
    this.startedAt,
    this.officeArrivedAt,
    this.completedAt,
    this.updatedAt,
    this.remarks = '',
    this.cancellationReason = '',
    this.cancellationExplanation = '',
    this.cancelledBy = '',
    this.cancelledAt,
    this.distanceKm = 0,
    this.durationSeconds = 0,
    this.drivingSeconds = 0,
    this.idleSeconds = 0,
  });

  /// Creates a trip model from a Firestore document map.
  factory CabTripModel.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return CabTripModel(
      id: id.isNotEmpty ? id : (map['id'] ?? '').toString(),
      assignmentId: (map['assignmentId'] ?? '').toString(),
      dateKey: (map['dateKey'] ?? '').toString(),
      driverId: (map['driverId'] ?? '').toString(),
      vehicleId: (map['vehicleId'] ?? '').toString(),
      employeeIds: _parseStringList(map['employeeIds']),
      officeName: (map['officeName'] ?? '').toString(),
      officeAddress: (map['officeAddress'] ?? '').toString(),
      officeLatitude: _parseNullableDouble(map['officeLatitude']),
      officeLongitude: _parseNullableDouble(map['officeLongitude']),
      branch: (map['branch'] ?? '').toString(),
      serviceCentre: (map['serviceCentre'] ?? '').toString(),
      status: (map['status'] ?? 'created').toString(),
      activeLocationSessionId: (map['activeLocationSessionId'] ?? '')
          .toString(),
      createdAt: _parseDateTime(map['createdAt']),
      startedAt: _parseDateTime(map['startedAt']),
      officeArrivedAt: _parseDateTime(map['officeArrivedAt']),
      completedAt: _parseDateTime(map['completedAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
      remarks: (map['remarks'] ?? '').toString(),
      cancellationReason: (map['cancellationReason'] ?? '').toString(),
      cancellationExplanation: (map['cancellationExplanation'] ?? '')
          .toString(),
      cancelledBy: (map['cancelledBy'] ?? '').toString(),
      cancelledAt: _parseDateTime(map['cancelledAt']),
      distanceKm: _parseDouble(map['distanceKm']),
      durationSeconds: _parseInt(map['durationSeconds']),
      drivingSeconds: _parseInt(map['drivingSeconds']),
      idleSeconds: _parseInt(map['idleSeconds']),
    );
  }

  /// Converts the trip model to a Firestore-safe document map.
  Map<String, dynamic> toMap() {
    return {
      'assignmentId': assignmentId,
      'dateKey': dateKey,
      'driverId': driverId,
      'vehicleId': vehicleId,
      'employeeIds': employeeIds,
      'officeName': officeName,
      'officeAddress': officeAddress,
      'officeLatitude': officeLatitude,
      'officeLongitude': officeLongitude,
      'branch': branch,
      'serviceCentre': serviceCentre,
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
      'cancellationReason': cancellationReason,
      'cancellationExplanation': cancellationExplanation,
      'cancelledBy': cancelledBy,
      'cancelledAt': cancelledAt == null
          ? null
          : Timestamp.fromDate(cancelledAt!),
      'distanceKm': distanceKm,
      'durationSeconds': durationSeconds,
      'drivingSeconds': drivingSeconds,
      'idleSeconds': idleSeconds,
    };
  }

  /// Returns a copy with selected fields changed.
  CabTripModel copyWith({
    String? id,
    String? assignmentId,
    String? dateKey,
    String? driverId,
    String? vehicleId,
    List<String>? employeeIds,
    String? officeName,
    String? officeAddress,
    double? officeLatitude,
    double? officeLongitude,
    String? branch,
    String? serviceCentre,
    String? status,
    String? activeLocationSessionId,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? officeArrivedAt,
    DateTime? completedAt,
    DateTime? updatedAt,
    String? remarks,
    String? cancellationReason,
    String? cancellationExplanation,
    String? cancelledBy,
    DateTime? cancelledAt,
    double? distanceKm,
    int? durationSeconds,
    int? drivingSeconds,
    int? idleSeconds,
  }) {
    return CabTripModel(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
      dateKey: dateKey ?? this.dateKey,
      driverId: driverId ?? this.driverId,
      vehicleId: vehicleId ?? this.vehicleId,
      employeeIds: employeeIds ?? this.employeeIds,
      officeName: officeName ?? this.officeName,
      officeAddress: officeAddress ?? this.officeAddress,
      officeLatitude: officeLatitude ?? this.officeLatitude,
      officeLongitude: officeLongitude ?? this.officeLongitude,
      branch: branch ?? this.branch,
      serviceCentre: serviceCentre ?? this.serviceCentre,
      status: status ?? this.status,
      activeLocationSessionId:
          activeLocationSessionId ?? this.activeLocationSessionId,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      officeArrivedAt: officeArrivedAt ?? this.officeArrivedAt,
      completedAt: completedAt ?? this.completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      remarks: remarks ?? this.remarks,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancellationExplanation:
          cancellationExplanation ?? this.cancellationExplanation,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      distanceKm: distanceKm ?? this.distanceKm,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      drivingSeconds: drivingSeconds ?? this.drivingSeconds,
      idleSeconds: idleSeconds ?? this.idleSeconds,
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
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  static List<String> _parseStringList(Object? value) {
    if (value is! List) return const <String>[];
    return value.map((item) => item.toString()).toList(growable: false);
  }

  static double _parseDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  static int _parseInt(Object? value) {
    if (value is num) return value.round();
    return int.tryParse('$value') ?? 0;
  }
}
