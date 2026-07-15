import '../../attendance/models/attendance_model.dart';
import '../../customer_visits/models/customer_visit_model.dart';

class ReportSummaryModel {
  final List<AttendanceModel> attendanceRecords;
  final List<CustomerVisitModel> visits;
  final List<ReportBucketModel> weeklyBuckets;
  final List<ReportBucketModel> monthlyBuckets;
  final Duration totalWorkingDuration;
  final Duration totalBreakDuration;
  final double distanceKilometers;

  const ReportSummaryModel({
    required this.attendanceRecords,
    required this.visits,
    required this.weeklyBuckets,
    required this.monthlyBuckets,
    required this.totalWorkingDuration,
    required this.totalBreakDuration,
    required this.distanceKilometers,
  });

  int get completedVisits =>
      visits.where((visit) => visit.status == 'completed').length;

  int get activeVisits =>
      visits.where((visit) => visit.status == 'checked_in').length;

  int get plannedVisits =>
      visits.where((visit) => visit.status == 'planned').length;

  int get presentDays =>
      attendanceRecords.where((record) => record.checkInTime != null).length;
}

class ReportBucketModel {
  final String label;
  final double attendanceHours;
  final int visits;
  final double distanceKilometers;

  const ReportBucketModel({
    required this.label,
    required this.attendanceHours,
    required this.visits,
    required this.distanceKilometers,
  });
}
