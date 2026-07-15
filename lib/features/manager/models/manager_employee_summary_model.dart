import '../../../core/models/employee_model.dart';
import '../../attendance/models/attendance_model.dart';
import '../../customer_visits/models/customer_visit_model.dart';

class ManagerEmployeeSummaryModel {
  final EmployeeModel employee;
  final AttendanceModel? todayAttendance;
  final List<CustomerVisitModel> visits;

  const ManagerEmployeeSummaryModel({
    required this.employee,
    required this.todayAttendance,
    required this.visits,
  });

  int get totalVisits => visits.length;

  int get completedVisits =>
      visits.where((visit) => visit.status == 'completed').length;

  int get activeVisits =>
      visits.where((visit) => visit.status == 'checked_in').length;

  String get liveStatus {
    final attendance = todayAttendance;
    if (attendance == null || attendance.checkInTime == null) return 'offline';
    if (attendance.breakStartTime != null) return 'break';
    if (attendance.checkOutTime != null) return 'completed';
    return 'online';
  }
}
