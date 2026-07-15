import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String id;
  final String userId;
  final String status;
  final DateTime? date;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final DateTime? breakStartTime;
  final int totalBreakMinutes;
  final double? checkInLatitude;
  final double? checkInLongitude;
  final double? checkOutLatitude;
  final double? checkOutLongitude;
  final String locationValidationStatus;
  final String syncStatus;

  const AttendanceModel({
    required this.id,
    required this.userId,
    required this.status,
    required this.date,
    required this.checkInTime,
    required this.checkOutTime,
    required this.breakStartTime,
    required this.totalBreakMinutes,
    required this.checkInLatitude,
    required this.checkInLongitude,
    required this.checkOutLatitude,
    required this.checkOutLongitude,
    required this.locationValidationStatus,
    required this.syncStatus,
  });

  factory AttendanceModel.fromMap(Map<String, dynamic> map, {String id = ''}) {
    DateTime? parseTimestamp(Object? value) {
      if (value is DateTime) return value;
      if (value is Timestamp) return value.toDate();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }

    return AttendanceModel(
      id: id.isNotEmpty ? id : (map['id'] ?? ''),
      userId: map['userId'] ?? '',
      status: map['status'] ?? '',
      date: parseTimestamp(map['date']),
      checkInTime: parseTimestamp(map['checkInTime']),
      checkOutTime: parseTimestamp(map['checkOutTime']),
      breakStartTime: parseTimestamp(map['breakStartTime']),
      totalBreakMinutes: _parseInt(map['totalBreakMinutes']),
      checkInLatitude: _parseDouble(map['checkInLatitude']),
      checkInLongitude: _parseDouble(map['checkInLongitude']),
      checkOutLatitude: _parseDouble(map['checkOutLatitude']),
      checkOutLongitude: _parseDouble(map['checkOutLongitude']),
      locationValidationStatus:
          map['locationValidationStatus'] ?? 'not_validated',
      syncStatus: map['syncStatus'] ?? 'synced',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'status': status,
      'date': date != null ? Timestamp.fromDate(DateTime(date!.year, date!.month, date!.day)) : null,
      'checkInTime': checkInTime != null ? Timestamp.fromDate(checkInTime!) : null,
      'checkOutTime': checkOutTime != null ? Timestamp.fromDate(checkOutTime!) : null,
      'breakStartTime': breakStartTime != null
          ? Timestamp.fromDate(breakStartTime!)
          : null,
      'totalBreakMinutes': totalBreakMinutes,
      'checkInLatitude': checkInLatitude,
      'checkInLongitude': checkInLongitude,
      'checkOutLatitude': checkOutLatitude,
      'checkOutLongitude': checkOutLongitude,
      'locationValidationStatus': locationValidationStatus,
      'syncStatus': syncStatus,
    };
  }

  AttendanceModel copyWith({
    String? id,
    String? userId,
    String? status,
    DateTime? date,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    DateTime? breakStartTime,
    int? totalBreakMinutes,
    double? checkInLatitude,
    double? checkInLongitude,
    double? checkOutLatitude,
    double? checkOutLongitude,
    String? locationValidationStatus,
    String? syncStatus,
    bool clearBreakStartTime = false,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      date: date ?? this.date,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      breakStartTime: clearBreakStartTime
          ? null
          : (breakStartTime ?? this.breakStartTime),
      totalBreakMinutes: totalBreakMinutes ?? this.totalBreakMinutes,
      checkInLatitude: checkInLatitude ?? this.checkInLatitude,
      checkInLongitude: checkInLongitude ?? this.checkInLongitude,
      checkOutLatitude: checkOutLatitude ?? this.checkOutLatitude,
      checkOutLongitude: checkOutLongitude ?? this.checkOutLongitude,
      locationValidationStatus:
          locationValidationStatus ?? this.locationValidationStatus,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  bool get isToday {
    if (date == null) return false;
    final now = DateTime.now();
    return date!.year == now.year && date!.month == now.month && date!.day == now.day;
  }

  bool get isCheckedIn => checkInTime != null && checkOutTime == null;

  bool get isCheckedOut => checkOutTime != null;

  bool get isOnBreak => breakStartTime != null && checkOutTime == null;

  bool get hasCheckInLocation =>
      checkInLatitude != null && checkInLongitude != null;

  bool get hasCheckOutLocation =>
      checkOutLatitude != null && checkOutLongitude != null;

  Duration grossWorkingDuration(DateTime now) {
    final start = checkInTime;
    if (start == null) return Duration.zero;

    final end = checkOutTime ?? now;
    if (end.isBefore(start)) return Duration.zero;
    return end.difference(start);
  }

  Duration breakDuration(DateTime now) {
    final activeBreakStart = breakStartTime;
    final activeBreakMinutes = activeBreakStart == null
        ? 0
        : now.difference(activeBreakStart).inMinutes;

    return Duration(minutes: totalBreakMinutes + activeBreakMinutes);
  }

  Duration netWorkingDuration(DateTime now) {
    final gross = grossWorkingDuration(now);
    final breaks = breakDuration(now);
    if (breaks >= gross) return Duration.zero;
    return gross - breaks;
  }

  static int _parseInt(Object? value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double? _parseDouble(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
