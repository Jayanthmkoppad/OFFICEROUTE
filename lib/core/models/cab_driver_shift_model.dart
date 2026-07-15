import 'package:cloud_firestore/cloud_firestore.dart';

/// Daily operational shift for a cab driver.
///
/// This model references the driver with [driverId]. Driver name, email, phone,
/// and role remain exclusively in the existing `users` collection.
class CabDriverShiftModel {
  /// Firestore document id.
  final String id;

  /// Reference to `users/{uid}` for the driver.
  final String driverId;

  /// Reference to `cab_vehicles/{vehicleId}`.
  final String vehicleId;

  /// Stable local-date key in `yyyy-MM-dd` format.
  final String shiftDate;

  /// Time when the driver started the shift.
  final DateTime? shiftStart;

  /// Time when the driver ended the shift.
  final DateTime? shiftEnd;

  /// Shift status, for example `scheduled`, `active`, or `completed`.
  final String shiftStatus;

  /// Optional textual starting location label.
  final String startLocation;

  /// Optional textual ending location label.
  final String endLocation;

  /// Total distance captured for the shift, in kilometers.
  final double totalDistance;

  /// Total trips completed in this shift.
  final int totalTrips;

  /// Total employees transported in this shift.
  final int totalEmployees;

  /// Internal remarks for operations.
  final String remarks;

  /// Creates a cab driver shift model.
  const CabDriverShiftModel({
    this.id = '',
    this.driverId = '',
    this.vehicleId = '',
    this.shiftDate = '',
    this.shiftStart,
    this.shiftEnd,
    this.shiftStatus = 'scheduled',
    this.startLocation = '',
    this.endLocation = '',
    this.totalDistance = 0.0,
    this.totalTrips = 0,
    this.totalEmployees = 0,
    this.remarks = '',
  });

  /// Creates a driver shift model from a Firestore document map.
  factory CabDriverShiftModel.fromMap(
    Map<String, dynamic> map, {
    String id = '',
  }) {
    return CabDriverShiftModel(
      id: id.isNotEmpty ? id : (map['id'] ?? '').toString(),
      driverId: (map['driverId'] ?? '').toString(),
      vehicleId: (map['vehicleId'] ?? '').toString(),
      shiftDate: (map['shiftDate'] ?? '').toString(),
      shiftStart: _parseDateTime(map['shiftStart']),
      shiftEnd: _parseDateTime(map['shiftEnd']),
      shiftStatus: (map['shiftStatus'] ?? 'scheduled').toString(),
      startLocation: (map['startLocation'] ?? '').toString(),
      endLocation: (map['endLocation'] ?? '').toString(),
      totalDistance: _parseDouble(map['totalDistance']),
      totalTrips: _parseInt(map['totalTrips']),
      totalEmployees: _parseInt(map['totalEmployees']),
      remarks: (map['remarks'] ?? '').toString(),
    );
  }

  /// Converts the shift model to a Firestore-safe document map.
  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'vehicleId': vehicleId,
      'shiftDate': shiftDate,
      'shiftStart': shiftStart == null ? null : Timestamp.fromDate(shiftStart!),
      'shiftEnd': shiftEnd == null ? null : Timestamp.fromDate(shiftEnd!),
      'shiftStatus': shiftStatus,
      'startLocation': startLocation,
      'endLocation': endLocation,
      'totalDistance': totalDistance,
      'totalTrips': totalTrips,
      'totalEmployees': totalEmployees,
      'remarks': remarks,
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

  static double _parseDouble(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static int _parseInt(Object? value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
