import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/services/firestore_service.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/session_access_gate.dart';
import 'features/auth/services/auth_service.dart';
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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.mode,
      builder: (context, themeMode, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'OfficeRoute',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
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
              return _AuthenticatedHome(userId: snapshot.data!.uid);
            }

            return Theme(data: AppTheme.darkTheme, child: const LoginScreen());
          },
        ),
      ),
    );
  }
}

class _AuthenticatedHome extends StatefulWidget {
  final String userId;

  const _AuthenticatedHome({required this.userId});

  @override
  State<_AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<_AuthenticatedHome> {
  late Future<void> _themeFuture;

  @override
  void initState() {
    super.initState();
    _themeFuture = _loadStoredTheme();
  }

  @override
  void didUpdateWidget(covariant _AuthenticatedHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _themeFuture = _loadStoredTheme();
    }
  }

  Future<void> _loadStoredTheme() async {
    try {
      final user = await FirestoreService.getUser(widget.userId);
      if (user != null) AppThemeController.setStoredMode(user.themeMode);
    } catch (error, stackTrace) {
      debugPrint('Stored theme load failed');
      debugPrint('File: lib/main.dart');
      debugPrint('Method: _AuthenticatedHomeState._loadStoredTheme');
      debugPrint('Runtime type: ${error.runtimeType}');
      debugPrint('Exception: $error');
      debugPrint('Stack trace:\n$stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _themeFuture,
      builder: (context, _) => SessionAccessGate(userId: widget.userId),
    );
  }
}
