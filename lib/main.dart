import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/services/auth_service.dart';
import 'features/home/home_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error, stackTrace) {
    debugPrint('Firebase initialization failed');
    debugPrint('File: lib/main.dart');
    debugPrint('Method: main');
    debugPrint('Runtime type: ${error.runtimeType}');
    debugPrint('Exception: $error');
    debugPrint('Stack trace:\n$stackTrace');

    runApp(FirebaseStartupErrorApp(error: error, stackTrace: stackTrace));
    return;
  }

  runApp(const OfficeRouteApp());
}

class FirebaseStartupErrorApp extends StatelessWidget {
  final Object error;
  final StackTrace stackTrace;

  const FirebaseStartupErrorApp({
    super.key,
    required this.error,
    required this.stackTrace,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OfficeRoute',
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Firebase initialization failed:\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class OfficeRouteApp extends StatelessWidget {
  const OfficeRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OfficeRoute',
      theme: AppTheme.darkTheme,
      home: StreamBuilder(
        stream: AuthService.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('Firebase auth state stream failed');
            debugPrint('File: lib/main.dart');
            debugPrint('Method: OfficeRouteApp.build');
            debugPrint('Runtime type: ${snapshot.error.runtimeType}');
            debugPrint('Exception: ${snapshot.error}');
            debugPrint('Stack trace:\n${snapshot.stackTrace}');

            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Authentication state error:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            return const HomeScreen();
          }

          return const LoginScreen();
        },
      ),
    );
  }
}
