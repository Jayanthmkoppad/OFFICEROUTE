import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Current User
  static User? get currentUser => _auth.currentUser;

  // Authentication State
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Login
  static Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } catch (error, stackTrace) {
      _printAuthException(
        error: error,
        stackTrace: stackTrace,
        method: 'AuthService.signIn',
      );
      rethrow;
    }
  }

  // Register
  static Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } catch (error, stackTrace) {
      _printAuthException(
        error: error,
        stackTrace: stackTrace,
        method: 'AuthService.register',
      );
      rethrow;
    }
  }

  // Logout
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (error, stackTrace) {
      _printAuthException(
        error: error,
        stackTrace: stackTrace,
        method: 'AuthService.signOut',
      );
      rethrow;
    }
  }

  // Forgot Password
  static Future<void> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (error, stackTrace) {
      _printAuthException(
        error: error,
        stackTrace: stackTrace,
        method: 'AuthService.resetPassword',
      );
      rethrow;
    }
  }

  static void _printAuthException({
    required Object error,
    required StackTrace stackTrace,
    required String method,
  }) {
    debugPrint('Firebase Authentication exception');
    debugPrint('File: lib/features/auth/services/auth_service.dart');
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
