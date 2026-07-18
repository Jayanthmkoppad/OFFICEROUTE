import 'dart:async';

import '../../../core/models/live_location_model.dart';
import '../../../core/models/location_permission_state_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/live_location_service.dart';
import '../../../core/services/location_permission_service.dart';
import '../../attendance/models/attendance_model.dart';
import '../../complaints/models/complaint_model.dart';
import '../../complaints/services/complaint_service.dart';
import '../../customer_visits/models/customer_visit_model.dart';
import '../../notifications/models/app_notification_model.dart';
import '../../notifications/models/notification_preferences_model.dart';
import '../../notifications/services/notification_service.dart';
import '../../organization/services/organization_service.dart';
import '../../reports/models/report_summary_model.dart';
import '../../reports/services/reports_service.dart';

typedef ProfileOperationsSnapshot = ({
  UserModel user,
  AttendanceModel? todayAttendance,
  List<AttendanceModel> attendance,
  List<CustomerVisitModel> visits,
  List<AppNotificationModel> notifications,
  NotificationPreferencesModel notificationPreferences,
  List<ComplaintModel> complaints,
  ReportSummaryModel report,
  LiveLocationModel? liveLocation,
  LocationPermissionStateModel locationPermission,
  OrganizationOperationsSnapshot organization,
  DateTime loadedAt,
});

// Backend limitation: Tasks, approvals, reimbursements, shift policies, and
// actual route metrics remain projections only after their owning modules are
// approved. Profile must never create substitute domain collections.

class ProfileService {
  ProfileService._();

  static Future<UserModel?> getProfile(String uid) async {
    return await FirestoreService.getUser(uid);
  }

  /// Builds the Phase 1 personal operations projection from existing modules.
  static Future<ProfileOperationsSnapshot> loadOperations(
    UserModel user,
  ) async {
    final reportFuture = ReportsService.loadMySummary();
    final notificationsFuture =
        NotificationService.fetchNotificationsForUser(user.uid);
    final preferencesFuture = NotificationService.loadPreferences(user.uid);
    final complaintsFuture = ComplaintService.fetchComplaintsForUser(user.uid);
    final liveLocationFuture = LiveLocationService.fetchLiveLocation(user.uid);
    final permissionFuture = LocationPermissionService.checkPermissionState();
    final organizationFuture = OrganizationService.loadOperations(DateTime.now());

    final report = await reportFuture;
    final now = DateTime.now();
    AttendanceModel? todayAttendance;
    for (final record in report.attendanceRecords) {
      final date = record.date;
      if (date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        todayAttendance = record;
        break;
      }
    }

    return (
      user: user,
      todayAttendance: todayAttendance,
      attendance: List<AttendanceModel>.unmodifiable(report.attendanceRecords),
      visits: List<CustomerVisitModel>.unmodifiable(report.visits),
      notifications:
          List<AppNotificationModel>.unmodifiable(await notificationsFuture),
      notificationPreferences: await preferencesFuture,
      complaints: List<ComplaintModel>.unmodifiable(await complaintsFuture),
      report: report,
      liveLocation: await liveLocationFuture,
      locationPermission: await permissionFuture,
      organization: await organizationFuture,
      loadedAt: DateTime.now(),
    );
  }

  /// Merges existing realtime module signals into one profile invalidation feed.
  static Stream<void> watchOperations(String userId) {
    late final StreamController<void> controller;
    final subscriptions = <StreamSubscription<void>>[];

    controller = StreamController<void>(
      onListen: () {
        final streams = <Stream<void>>[
          OrganizationService.watchOperations(DateTime.now()),
          NotificationService.watchNotificationsForUser(userId),
          NotificationService.watchPreferences(userId),
        ];
        for (final stream in streams) {
          subscriptions.add(
            stream.listen(
              (_) => controller.add(null),
              onError: controller.addError,
            ),
          );
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  static Future<void> updatePhone({
    required String uid,
    required String phone,
  }) {
    return FirestoreService.updateUserFields(
      uid: uid,
      fields: <String, Object?>{'phone': phone.trim()},
    );
  }

  static Future<void> updateProfileDetails({
    required String uid,
    required Map<String, Object?> fields,
  }) {
    return FirestoreService.updateUserFields(uid: uid, fields: fields);
  }

  static Future<NotificationPreferencesModel> updateNotificationPreferences({
    required String uid,
    required NotificationPreferencesModel preferences,
  }) {
    return NotificationService.updatePreferences(
      userId: uid,
      preferences: preferences,
    );
  }

}
