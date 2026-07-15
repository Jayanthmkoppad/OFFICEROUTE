import 'dart:math' as math;

import '../../attendance/models/attendance_model.dart';
import '../../attendance/services/attendance_service.dart';
import '../../auth/services/auth_service.dart';
import '../../customer_visits/models/customer_visit_model.dart';
import '../../customer_visits/services/customer_visit_service.dart';
import '../models/report_summary_model.dart';

class ReportsService {
  ReportsService._();

  static Future<ReportSummaryModel> loadMySummary() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) {
      throw StateError('Reports require a signed-in user.');
    }

    final attendanceFuture = AttendanceService.fetchAttendanceForUser(uid);
    final visitsFuture = CustomerVisitService.fetchVisitsForUser(uid);
    final attendance = await attendanceFuture;
    final visits = await visitsFuture;
    final now = DateTime.now();

    return ReportSummaryModel(
      attendanceRecords: attendance,
      visits: visits,
      weeklyBuckets: _weeklyBuckets(attendance, visits, now),
      monthlyBuckets: _monthlyBuckets(attendance, visits, now),
      totalWorkingDuration: attendance.fold<Duration>(
        Duration.zero,
        (sum, record) => sum + record.netWorkingDuration(now),
      ),
      totalBreakDuration: attendance.fold<Duration>(
        Duration.zero,
        (sum, record) => sum + record.breakDuration(now),
      ),
      distanceKilometers: visits.fold<double>(
        0,
        (sum, visit) => sum + _visitDistance(visit),
      ),
    );
  }

  static List<ReportBucketModel> _weeklyBuckets(
    List<AttendanceModel> attendance,
    List<CustomerVisitModel> visits,
    DateTime now,
  ) {
    final start = DateTime(now.year, now.month, now.day - 6);

    return List.generate(7, (index) {
      final day = DateTime(start.year, start.month, start.day + index);
      final dayAttendance = attendance.where((record) {
        final date = record.date;
        return date != null &&
            date.year == day.year &&
            date.month == day.month &&
            date.day == day.day;
      });
      final dayVisits = visits.where((visit) => _isSameDay(visit.createdAt, day));

      return ReportBucketModel(
        label: '${day.day}/${day.month}',
        attendanceHours: dayAttendance.fold<double>(
          0,
          (sum, record) => sum + record.netWorkingDuration(now).inMinutes / 60,
        ),
        visits: dayVisits.length,
        distanceKilometers: dayVisits.fold<double>(
          0,
          (sum, visit) => sum + _visitDistance(visit),
        ),
      );
    });
  }

  static List<ReportBucketModel> _monthlyBuckets(
    List<AttendanceModel> attendance,
    List<CustomerVisitModel> visits,
    DateTime now,
  ) {
    return List.generate(6, (index) {
      final month = DateTime(now.year, now.month - (5 - index));
      final monthAttendance = attendance.where((record) {
        final date = record.date;
        return date != null &&
            date.year == month.year &&
            date.month == month.month;
      });
      final monthVisits = visits.where((visit) {
        return visit.createdAt.year == month.year &&
            visit.createdAt.month == month.month;
      });

      return ReportBucketModel(
        label: _monthLabel(month),
        attendanceHours: monthAttendance.fold<double>(
          0,
          (sum, record) => sum + record.netWorkingDuration(now).inMinutes / 60,
        ),
        visits: monthVisits.length,
        distanceKilometers: monthVisits.fold<double>(
          0,
          (sum, visit) => sum + _visitDistance(visit),
        ),
      );
    });
  }

  static double _visitDistance(CustomerVisitModel visit) {
    final startLat = visit.checkInLatitude;
    final startLng = visit.checkInLongitude;
    final endLat = visit.checkOutLatitude;
    final endLng = visit.checkOutLongitude;

    if (startLat == null || startLng == null || endLat == null || endLng == null) {
      return 0;
    }

    return _haversineKilometers(startLat, startLng, endLat, endLng);
  }

  static double _haversineKilometers(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(endLat - startLat);
    final dLng = _degreesToRadians(endLng - startLng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(startLat)) *
            math.cos(_degreesToRadians(endLat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _monthLabel(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return months[date.month - 1];
  }
}
