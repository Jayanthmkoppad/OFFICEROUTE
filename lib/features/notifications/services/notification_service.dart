import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/app_notification_model.dart';
import '../models/notification_preferences_model.dart';

class NotificationService {
  NotificationService._();

  static final CollectionReference<Map<String, dynamic>> _notifications =
      FirebaseFirestore.instance.collection('notifications');
  static final CollectionReference<Map<String, dynamic>> _preferences =
      FirebaseFirestore.instance.collection('notification_preferences');

  static Future<List<AppNotificationModel>> fetchNotificationsForUser(
    String userId,
  ) async {
    try {
      final snapshot = await _notifications
          .where('userId', isEqualTo: userId)
          .limit(100)
          .get();

      final notifications = snapshot.docs
          .map((doc) => AppNotificationModel.fromMap(doc.data(), id: doc.id))
          .toList();

      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notifications;
    } catch (error, stackTrace) {
      _printNotificationException(
        error: error,
        stackTrace: stackTrace,
        method: 'NotificationService.fetchNotificationsForUser',
      );
      rethrow;
    }
  }

  /// Emits whenever notifications for one user change.
  static Stream<void> watchNotificationsForUser(String userId) {
    return _notifications
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map<void>((_) {});
  }

  /// Emits whenever one user's existing preference document changes.
  static Stream<void> watchPreferences(String userId) {
    return _preferences.doc(userId).snapshots().map<void>((_) {});
  }

  static Future<AppNotificationModel> createLocalNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      final notification = AppNotificationModel(
        id: '',
        userId: userId,
        title: title,
        body: body,
        type: type,
        source: 'local_in_app',
        isRead: false,
        createdAt: DateTime.now(),
        readAt: null,
      );

      final docRef = await _notifications.add(notification.toMap());
      final doc = await docRef.get();
      final data = doc.data();
      if (data == null) {
        throw StateError('Created notification ${doc.id} has no data.');
      }

      return AppNotificationModel.fromMap(data, id: doc.id);
    } catch (error, stackTrace) {
      _printNotificationException(
        error: error,
        stackTrace: stackTrace,
        method: 'NotificationService.createLocalNotification',
      );
      rethrow;
    }
  }

  static Future<void> markAsRead(AppNotificationModel notification) async {
    try {
      await _notifications
          .doc(notification.id)
          .update(
            notification.copyWith(isRead: true, readAt: DateTime.now()).toMap(),
          );
    } catch (error, stackTrace) {
      _printNotificationException(
        error: error,
        stackTrace: stackTrace,
        method: 'NotificationService.markAsRead',
      );
      rethrow;
    }
  }

  static Future<void> markAllAsRead(String userId) async {
    try {
      final notifications = await fetchNotificationsForUser(userId);
      final unread = notifications.where((item) => !item.isRead);
      final batch = FirebaseFirestore.instance.batch();

      for (final notification in unread) {
        batch.update(
          _notifications.doc(notification.id),
          notification.copyWith(isRead: true, readAt: DateTime.now()).toMap(),
        );
      }

      await batch.commit();
    } catch (error, stackTrace) {
      _printNotificationException(
        error: error,
        stackTrace: stackTrace,
        method: 'NotificationService.markAllAsRead',
      );
      rethrow;
    }
  }

  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _notifications.doc(notificationId).delete();
    } catch (error, stackTrace) {
      _printNotificationException(
        error: error,
        stackTrace: stackTrace,
        method: 'NotificationService.deleteNotification',
      );
      rethrow;
    }
  }

  static Future<NotificationPreferencesModel> loadPreferences(
    String userId,
  ) async {
    try {
      final doc = await _preferences.doc(userId).get();
      if (!doc.exists || doc.data() == null) {
        final defaults = NotificationPreferencesModel.defaults();
        await _preferences.doc(userId).set(defaults.toMap());
        return defaults;
      }

      return NotificationPreferencesModel.fromMap(doc.data()!);
    } catch (error, stackTrace) {
      _printNotificationException(
        error: error,
        stackTrace: stackTrace,
        method: 'NotificationService.loadPreferences',
      );
      rethrow;
    }
  }

  static Future<NotificationPreferencesModel> updatePreferences({
    required String userId,
    required NotificationPreferencesModel preferences,
  }) async {
    try {
      await _preferences.doc(userId).set(preferences.toMap());
      return preferences;
    } catch (error, stackTrace) {
      _printNotificationException(
        error: error,
        stackTrace: stackTrace,
        method: 'NotificationService.updatePreferences',
      );
      rethrow;
    }
  }

  static void _printNotificationException({
    required Object error,
    required StackTrace stackTrace,
    required String method,
  }) {
    debugPrint('Notification Firestore exception');
    debugPrint(
      'File: lib/features/notifications/services/notification_service.dart',
    );
    debugPrint('Method: $method');
    debugPrint('Runtime type: ${error.runtimeType}');

    if (error is FirebaseException) {
      debugPrint('FirebaseException.plugin: ${error.plugin}');
      debugPrint('FirebaseException.code: ${error.code}');
      debugPrint('FirebaseException.message: ${error.message}');
    }

    debugPrint('Exception: $error');
    debugPrint('Stack trace:\n$stackTrace');
  }
}
