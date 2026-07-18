import '../../../core/models/live_location_model.dart';
import '../../../core/services/employee_service.dart';
import '../../../core/services/live_location_service.dart';
import '../../auth/services/auth_service.dart';
import '../../customer_visits/models/customer_visit_model.dart';
import '../../customer_visits/services/customer_visit_service.dart';
import '../../manager/models/manager_employee_summary_model.dart';
import '../../map/controllers/location_controller.dart';
import '../models/attendance_model.dart';
import '../services/attendance_service.dart';

/// Date-scoped admin projection built entirely from existing domain models.
typedef AttendanceOperationsResult = ({
  List<ManagerEmployeeSummaryModel> employees,
  List<AttendanceModel> attendance,
  List<CustomerVisitModel> visits,
});

class AttendanceController {
  AttendanceController._();

  /// Returns the authenticated user id without changing existing auth flow.
  static String? get currentUserId => AuthService.currentUser?.uid;

  static Future<AttendanceModel?> loadTodayAttendance() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return null;
    return AttendanceService.fetchTodayAttendance(uid);
  }

  static Future<AttendanceModel?> checkIn() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return null;
    final location = await LocationController.getCurrentLocation();
    return AttendanceService.checkIn(
      userId: uid,
      latitude: location.latitude,
      longitude: location.longitude,
    );
  }

  static Future<AttendanceModel?> checkOut() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return null;
    final location = await LocationController.getCurrentLocation();
    return AttendanceService.checkOut(
      userId: uid,
      latitude: location.latitude,
      longitude: location.longitude,
    );
  }

  static Future<AttendanceModel?> startBreak() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return null;
    return AttendanceService.startBreak(uid);
  }

  static Future<AttendanceModel?> endBreak() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return null;
    return AttendanceService.endBreak(uid);
  }

  static Future<List<AttendanceModel>> loadAttendanceHistory() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return const <AttendanceModel>[];
    return AttendanceService.fetchAttendanceForUser(uid);
  }

  static Future<List<AttendanceModel>> loadAttendanceForMonth(
    DateTime month,
  ) async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return const <AttendanceModel>[];
    return AttendanceService.fetchAttendanceForMonth(userId: uid, month: month);
  }

  /// Loads the employee operations snapshot for one selected calendar day.
  ///
  /// The result reuses the existing employee, attendance, visit, and manager
  /// summary models. Attendance and visits are queried by date so the admin
  /// dashboard never falls back to the legacy collection-wide reads.
  static Future<AttendanceOperationsResult> loadOperationsForDate(
    DateTime day,
  ) async {
    final employeesFuture = EmployeeService.fetchAllEmployees();
    final attendanceFuture = AttendanceService.fetchAttendanceForDate(day);
    final visitsFuture =
        CustomerVisitService.fetchOperationalVisitsForDate(day);

    final employees = await employeesFuture;
    final attendance = await attendanceFuture;
    final visits = await visitsFuture;

    final attendanceByUser = <String, AttendanceModel>{};
    for (final record in attendance) {
      final current = attendanceByUser[record.userId];
      final currentTime = current?.checkInTime ?? current?.date;
      final recordTime = record.checkInTime ?? record.date;
      if (current == null ||
          (recordTime != null &&
              (currentTime == null || recordTime.isAfter(currentTime)))) {
        attendanceByUser[record.userId] = record;
      }
    }

    final visitsByUser = <String, List<CustomerVisitModel>>{};
    for (final visit in visits) {
      visitsByUser.putIfAbsent(visit.userId, () => []).add(visit);
    }

    final summaries = employees
        .map(
          (employee) => ManagerEmployeeSummaryModel(
            employee: employee,
            todayAttendance: attendanceByUser[employee.uid],
            visits: List<CustomerVisitModel>.unmodifiable(
              visitsByUser[employee.uid] ?? const <CustomerVisitModel>[],
            ),
          ),
        )
        .toList(growable: false)
      ..sort(
        (a, b) => a.employee.name.toLowerCase().compareTo(
              b.employee.name.toLowerCase(),
            ),
      );

    return (
      employees: summaries,
      attendance: List<AttendanceModel>.unmodifiable(attendance),
      visits: List<CustomerVisitModel>.unmodifiable(visits),
    );
  }

  /// Loads organization attendance for a calendar month using a date range.
  static Future<List<AttendanceModel>> loadOperationsForMonth(
    DateTime month,
  ) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    return AttendanceService.fetchAttendanceForRange(start: start, end: end);
  }

  /// Loads organization attendance for one selected calendar day.
  static Future<List<AttendanceModel>> loadOperationsAttendanceForDate(
    DateTime day,
  ) {
    return AttendanceService.fetchAttendanceForDate(day);
  }

  /// Loads the existing attendance history for a selected employee.
  static Future<List<AttendanceModel>> loadEmployeeAttendanceHistory(
    String userId,
  ) {
    return AttendanceService.fetchAttendanceForUser(userId);
  }

  /// Emits when attendance for the selected operations day changes.
  static Stream<void> watchOperationsAttendance(DateTime day) {
    return AttendanceService.watchAttendanceForDate(day);
  }

  /// Emits when visits updated on the selected operations day change.
  static Stream<void> watchOperationsVisits(DateTime day) {
    return CustomerVisitService.watchVisitsForDate(day);
  }

  /// Emits when the active customer visit set changes.
  static Stream<void> watchActiveVisits() {
    return CustomerVisitService.watchActiveVisitChanges();
  }

  /// Streams current live locations without starting or changing tracking.
  static Stream<List<LiveLocationModel>> watchOperationsLiveLocations() {
    return LiveLocationService.watchLiveLocations();
  }
}
