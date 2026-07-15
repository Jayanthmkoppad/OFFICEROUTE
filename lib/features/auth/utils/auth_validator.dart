class AuthValidator {
  AuthValidator._();

  static final RegExp _emailPattern = RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
  );

  static String? login({
    required String email,
    required String password,
  }) {
    final emailError = _validateEmail(email);
    if (emailError != null) return emailError;

    if (password.isEmpty) {
      return 'Please enter your password.';
    }

    return null;
  }

  static String? registration({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) {
    if (name.trim().isEmpty) {
      return 'Please enter your full name.';
    }

    final emailError = _validateEmail(email);
    if (emailError != null) return emailError;

    if (password.isEmpty) {
      return 'Please enter a password.';
    }

    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }

    if (password != confirmPassword) {
      return 'Passwords do not match.';
    }

    return null;
  }

  static String? _validateEmail(String email) {
    final normalizedEmail = email.trim();

    if (normalizedEmail.isEmpty) {
      return 'Please enter your email address.';
    }

    if (!_emailPattern.hasMatch(normalizedEmail)) {
      return 'Please enter a valid email address.';
    }

    return null;
  }
}
