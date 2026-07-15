import '../../auth/services/auth_service.dart';
import '../../map/controllers/location_controller.dart';
import '../models/attendance_model.dart';
import '../services/attendance_service.dart';

class AttendanceController {
  AttendanceController._();

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
}
