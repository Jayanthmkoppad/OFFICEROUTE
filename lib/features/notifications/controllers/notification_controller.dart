import '../../auth/services/auth_service.dart';
import '../models/app_notification_model.dart';
import '../models/notification_preferences_model.dart';
import '../services/notification_service.dart';

class NotificationController {
  NotificationController._();

  static Future<List<AppNotificationModel>> loadMyNotifications() {
    final uid = _requiredUserId();
    return NotificationService.fetchNotificationsForUser(uid);
  }

  static Future<NotificationPreferencesModel> loadPreferences() {
    final uid = _requiredUserId();
    return NotificationService.loadPreferences(uid);
  }

  static Future<AppNotificationModel> createLocalNotification({
    required String title,
    required String body,
    required String type,
  }) {
    final uid = _requiredUserId();
    return NotificationService.createLocalNotification(
      userId: uid,
      title: title,
      body: body,
      type: type,
    );
  }

  static Future<void> markAsRead(AppNotificationModel notification) {
    _requiredUserId();
    return NotificationService.markAsRead(notification);
  }

  static Future<void> markAllAsRead() {
    final uid = _requiredUserId();
    return NotificationService.markAllAsRead(uid);
  }

  static Future<NotificationPreferencesModel> updatePreferences(
    NotificationPreferencesModel preferences,
  ) {
    final uid = _requiredUserId();
    return NotificationService.updatePreferences(
      userId: uid,
      preferences: preferences,
    );
  }

  static String _requiredUserId() {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) {
      throw StateError('Notification action requires a signed-in user.');
    }

    return uid;
  }
}
