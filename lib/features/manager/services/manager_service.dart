import '../../../core/services/employee_service.dart';
import '../../attendance/models/attendance_model.dart';
import '../../attendance/services/attendance_service.dart';
import '../../customer_visits/services/customer_visit_service.dart';
import '../models/manager_employee_summary_model.dart';

class ManagerService {
  ManagerService._();

  static Future<List<ManagerEmployeeSummaryModel>> loadEmployeeSummaries() async {
    final employeesFuture = EmployeeService.fetchAllEmployees();
    final attendanceFuture = AttendanceService.fetchAllAttendance();
    final visitsFuture = CustomerVisitService.fetchAllVisits();

    final employees = await employeesFuture;
    final attendance = await attendanceFuture;
    final visits = await visitsFuture;
    final today = DateTime.now();

    return employees.map((employee) {
      final todayAttendance = _todayAttendanceFor(
        attendance: attendance,
        userId: employee.uid,
        today: today,
      );
      final employeeVisits = visits
          .where((visit) => visit.userId == employee.uid)
          .toList(growable: false);

      return ManagerEmployeeSummaryModel(
        employee: employee,
        todayAttendance: todayAttendance,
        visits: employeeVisits,
      );
    }).toList(growable: false);
  }

  static AttendanceModel? _todayAttendanceFor({
    required List<AttendanceModel> attendance,
    required String userId,
    required DateTime today,
  }) {
    for (final record in attendance) {
      final date = record.date;
      if (record.userId == userId &&
          date != null &&
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day) {
        return record;
      }
    }

    return null;
  }
}
