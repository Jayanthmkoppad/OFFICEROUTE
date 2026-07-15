import 'package:flutter_test/flutter_test.dart';
import 'package:officeroute/features/attendance/models/attendance_model.dart';

void main() {
  group('AttendanceModel', () {
    test('calculates net working duration after breaks', () {
      final start = DateTime(2026, 7, 11, 9);
      final end = DateTime(2026, 7, 11, 17);
      final attendance = AttendanceModel(
        id: 'attendance-1',
        userId: 'user-1',
        status: 'Checked Out',
        date: DateTime(2026, 7, 11),
        checkInTime: start,
        checkOutTime: end,
        breakStartTime: null,
        totalBreakMinutes: 45,
        checkInLatitude: 12.34,
        checkInLongitude: 56.78,
        checkOutLatitude: 12.35,
        checkOutLongitude: 56.79,
        locationValidationStatus: 'validated',
        syncStatus: 'synced',
      );

      expect(attendance.grossWorkingDuration(end).inHours, 8);
      expect(attendance.breakDuration(end).inMinutes, 45);
      expect(attendance.netWorkingDuration(end).inMinutes, 435);
      expect(attendance.hasCheckInLocation, isTrue);
      expect(attendance.hasCheckOutLocation, isTrue);
    });

    test('loads legacy documents with safe defaults', () {
      final attendance = AttendanceModel.fromMap(const {
        'userId': 'user-1',
        'status': 'Checked In',
      });

      expect(attendance.totalBreakMinutes, 0);
      expect(attendance.locationValidationStatus, 'not_validated');
      expect(attendance.syncStatus, 'synced');
      expect(attendance.hasCheckInLocation, isFalse);
    });
  });
}
