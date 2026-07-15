import 'package:firebase_auth/firebase_auth.dart';

class AuthErrorMapper {
  AuthErrorMapper._();

  static String message(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'email-already-in-use' => 'An account already exists for this email.',
        'invalid-credential' ||
        'user-not-found' ||
        'wrong-password' => 'The email or password is incorrect.',
        'invalid-email' => 'Please enter a valid email address.',
        'user-disabled' => 'This account has been disabled.',
        'weak-password' => 'Please choose a stronger password.',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        'network-request-failed' =>
          'Check your internet connection and try again.',
        'operation-not-allowed' =>
          'This sign-in method is not currently available.',
        _ =>
          'Authentication failed (${error.code}): '
              '${error.message ?? error.toString()}',
      };
    }

    if (error is FirebaseException) {
      return 'Firebase ${error.plugin} error (${error.code}): '
          '${error.message ?? error.toString()}';
    }

    return 'Unexpected error (${error.runtimeType}): $error';
  }
}
