import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

import 'controllers/auth_controller.dart';
import 'register_screen.dart';
import 'utils/auth_error_mapper.dart';
import 'utils/auth_validator.dart';
import 'widgets/google_signin_button.dart';
import 'widgets/login_text_field.dart';
import 'widgets/primary_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    final validationMessage = AuthValidator.login(
      email: emailController.text,
      password: passwordController.text,
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
      debugPrint('Reached Firebase Authentication');
      await AuthController.login(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      debugPrint('Firebase Login Success');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Login Successful')));
    } catch (error, stackTrace) {
      debugPrint('Firebase Authentication failed');
      debugPrint('File: lib/features/auth/login_screen.dart');
      debugPrint('Method: _LoginScreenState.signIn');
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
                  'Welcome Back',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headingLarge,
                ),

                const SizedBox(height: 8),

                Text(
                  'Track your workforce in real time',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption,
                ),

                const SizedBox(height: 40),

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

                const SizedBox(height: 10),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Forgot Password'),
                  ),
                ),

                const SizedBox(height: 15),

                PrimaryButton(
                  text: isLoading ? 'PLEASE WAIT...' : 'SIGN IN',
                  onPressed: () {
                    if (!isLoading) {
                      signIn();
                    }
                  },
                ),

                const SizedBox(height: 30),

                Row(
                  children: const [
                    Expanded(child: Divider(color: Colors.white24)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.white24)),
                  ],
                ),

                const SizedBox(height: 30),

                GoogleSignInButton(onPressed: () {}),

                const SizedBox(height: 25),

                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: const Text('Create New Account'),
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
