import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

import 'controllers/auth_controller.dart';
import 'utils/auth_error_mapper.dart';
import 'utils/auth_validator.dart';
import 'widgets/login_text_field.dart';
import 'widgets/primary_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    final validationMessage = AuthValidator.registration(
      name: nameController.text,
      email: emailController.text,
      password: passwordController.text,
      confirmPassword: confirmPasswordController.text,
    );

    if (validationMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationMessage)));
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await AuthController.register(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully')),
      );

      Navigator.pop(context);
    } catch (error, stackTrace) {
      debugPrint('Firebase Registration failed');
      debugPrint('File: lib/features/auth/register_screen.dart');
      debugPrint('Method: _RegisterScreenState.register');
      debugPrint('Runtime type: ${error.runtimeType}');
      if (error is FirebaseAuthException) {
        debugPrint('FirebaseAuthException.code: ${error.code}');
        debugPrint('FirebaseAuthException.message: ${error.message}');
      }
      debugPrint('Exception: $error');
      debugPrint('Stack trace:\n$stackTrace');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AuthErrorMapper.message(error))));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 90,
                    height: 90,
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Create Account',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headingLarge,
                ),

                const SizedBox(height: 8),

                Text(
                  'Start managing your workforce',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption,
                ),

                const SizedBox(height: 40),

                LoginTextField(
                  hintText: 'Full Name',
                  icon: Icons.person_outline,
                  controller: nameController,
                ),

                const SizedBox(height: 18),

                LoginTextField(
                  hintText: 'Email',
                  icon: Icons.email_outlined,
                  controller: emailController,
                ),

                const SizedBox(height: 18),

                LoginTextField(
                  hintText: 'Password',
                  icon: Icons.lock_outline,
                  controller: passwordController,
                  obscureText: true,
                ),

                const SizedBox(height: 18),

                LoginTextField(
                  hintText: 'Confirm Password',
                  icon: Icons.lock_outline,
                  controller: confirmPasswordController,
                  obscureText: true,
                ),

                const SizedBox(height: 30),

                PrimaryButton(
                  text: isLoading ? 'PLEASE WAIT...' : 'CREATE ACCOUNT',
                  onPressed: isLoading ? () {} : register,
                ),

                const SizedBox(height: 20),

                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Already have an account? Sign In'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
