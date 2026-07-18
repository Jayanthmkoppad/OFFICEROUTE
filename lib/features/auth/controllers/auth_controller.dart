import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../../../core/services/firestore_service.dart';

class AuthController {
  AuthController._();

  static Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential = await AuthService.register(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw StateError('Registration succeeded but Firebase user is null.');
      }

      await FirestoreService.createUser(
        uid: user.uid,
        name: name,
        email: email,
      );

      debugPrint('Firestore user document created: users/${user.uid}');
    } catch (error, stackTrace) {
      _printControllerException(
        error: error,
        stackTrace: stackTrace,
        method: 'AuthController.register',
      );
      rethrow;
    }
  }

  static Future<void> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await AuthService.signIn(
        email: email,
        password: password,
      );

      final user = credential.user ?? AuthService.currentUser;
      if (user == null) {
        throw StateError('Login succeeded but Firebase user is null.');
      }

      if ((user.email ?? email).trim().toLowerCase() ==
          FirestoreService.bootstrapAdministratorEmail) {
        try {
          await FirestoreService.ensureBootstrapAdministrator(
            uid: user.uid,
            email: user.email ?? email,
            name: user.displayName ?? _fallbackDisplayName(email),
          );
        } catch (error, stackTrace) {
          debugPrint('Bootstrap administrator profile repair deferred: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
        return;
      }

      final profile = await FirestoreService.getOrCreateUser(
        uid: user.uid,
        email: user.email ?? email.trim(),
        name: _fallbackDisplayName(user.email ?? email),
      );

      debugPrint('Firestore user document loaded: users/${profile.uid}');
    } catch (error, stackTrace) {
      _printControllerException(
        error: error,
        stackTrace: stackTrace,
        method: 'AuthController.login',
      );
      rethrow;
    }
  }

  static Future<void> logout() async {
    await AuthService.signOut();
  }

  static String _fallbackDisplayName(String email) {
    final trimmedEmail = email.trim();
    final separatorIndex = trimmedEmail.indexOf('@');
    if (separatorIndex <= 0) {
      return 'Employee';
    }

    return trimmedEmail.substring(0, separatorIndex);
  }

  static void _printControllerException({
    required Object error,
    required StackTrace stackTrace,
    required String method,
  }) {
    debugPrint('Authentication controller exception');
    debugPrint('File: lib/features/auth/controllers/auth_controller.dart');
    debugPrint('Method: $method');
    debugPrint('Runtime type: ${error.runtimeType}');

    if (error is FirebaseAuthException) {
      debugPrint('FirebaseAuthException.code: ${error.code}');
      debugPrint('FirebaseAuthException.message: ${error.message}');
    }

    debugPrint('Exception: $error');
    debugPrint('Stack trace:\n$stackTrace');
  }
}
