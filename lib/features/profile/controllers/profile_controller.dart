import 'package:flutter/foundation.dart';

import '../../../core/models/user_model.dart';
import '../../../core/services/firestore_service.dart';
import '../../auth/services/auth_service.dart';

class ProfileController {
  ProfileController._();

  static Future<UserModel?> loadCurrentUser() async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      debugPrint('Profile load skipped because Firebase currentUser is null.');
      return null;
    }

    try {
      return await FirestoreService.getOrCreateUser(
        uid: currentUser.uid,
        email: currentUser.email ?? '',
        name: _fallbackDisplayName(currentUser.email),
      );
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

  static String _fallbackDisplayName(String? email) {
    final trimmedEmail = email?.trim() ?? '';
    final separatorIndex = trimmedEmail.indexOf('@');
    if (separatorIndex <= 0) {
      return 'Employee';
    }

    return trimmedEmail.substring(0, separatorIndex);
  }
}
