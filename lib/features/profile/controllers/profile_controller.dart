import 'package:flutter/foundation.dart';

import '../../../core/models/user_model.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/location_permission_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/services/auth_service.dart';
import '../../notifications/models/notification_preferences_model.dart';
import '../services/profile_service.dart';

class ProfileController {
  ProfileController._();

  static Future<UserModel?> loadCurrentUser() async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      debugPrint('Profile load skipped because Firebase currentUser is null.');
      return null;
    }

    try {
      final user = await FirestoreService.getOrCreateUser(
        uid: currentUser.uid,
        email: currentUser.email ?? '',
        name: _fallbackDisplayName(currentUser.email),
      );
      AppThemeController.setStoredMode(user.themeMode);
      return user;
    } catch (error, stackTrace) {
      debugPrint('Profile controller exception');
      debugPrint(
        'File: lib/features/profile/controllers/profile_controller.dart',
      );
      debugPrint('Method: ProfileController.loadCurrentUser');
      debugPrint('Runtime type: ${error.runtimeType}');
      debugPrint('Exception: $error');
      debugPrint('Stack trace:\n$stackTrace');
      rethrow;
    }
  }

  static Future<ProfileOperationsSnapshot> loadOperations() async {
    final user = await loadCurrentUser();
    if (user == null) {
      throw StateError('Profile operations require a signed-in user.');
    }
    return ProfileService.loadOperations(user);
  }

  static Stream<void> watchOperations() {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return const Stream<void>.empty();
    return ProfileService.watchOperations(uid);
  }

  static Future<void> updatePhone(String phone) async {
    final uid = _requiredUserId();
    await ProfileService.updatePhone(uid: uid, phone: phone);
  }

  static Future<void> updateProfileDetails(Map<String, Object?> fields) {
    return ProfileService.updateProfileDetails(
      uid: _requiredUserId(),
      fields: fields,
    );
  }

  static Future<void> updateThemeMode(String mode) async {
    await updateProfileDetails(<String, Object?>{'themeMode': mode});
    AppThemeController.setStoredMode(mode);
  }

  static Future<NotificationPreferencesModel> updateNotificationPreferences(
    NotificationPreferencesModel preferences,
  ) {
    return ProfileService.updateNotificationPreferences(
      uid: _requiredUserId(),
      preferences: preferences,
    );
  }

  static Future<void> requestPasswordReset() async {
    final email = AuthService.currentUser?.email;
    if (email == null || email.trim().isEmpty) {
      throw StateError('The signed-in account does not have an email address.');
    }
    await AuthService.resetPassword(email: email);
  }

  static Future<void> openLocationSettings() {
    return LocationPermissionService.openLocationSettings().then((_) {});
  }

  static Future<void> openAppSettings() {
    return LocationPermissionService.openAppSettings().then((_) {});
  }

  static Future<void> logout() => AuthService.signOut();

  static String _requiredUserId() {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) {
      throw StateError('Profile action requires a signed-in user.');
    }
    return uid;
  }

  static String _fallbackDisplayName(String? email) {
    final trimmedEmail = email?.trim() ?? '';
    final separatorIndex = trimmedEmail.indexOf('@');
    if (separatorIndex <= 0) {
      return 'Employee';
    }

    return trimmedEmail.substring(0, separatorIndex);
  }
}
