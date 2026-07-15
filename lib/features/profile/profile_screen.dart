import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'controllers/profile_controller.dart';
import '../../core/models/user_model.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text("Profile", style: AppTextStyles.headingSmall),
      ),
      body: FutureBuilder<UserModel?>(
        future: ProfileController.loadCurrentUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            debugPrint('Profile screen failed to load user document');
            debugPrint('File: lib/features/profile/profile_screen.dart');
            debugPrint('Method: ProfileScreen.build');
            debugPrint('Runtime type: ${snapshot.error.runtimeType}');
            debugPrint('Exception: ${snapshot.error}');
            debugPrint('Stack trace:\n${snapshot.stackTrace}');

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Profile load failed:\n${snapshot.error}',
                  style: AppTextStyles.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final user = snapshot.data;
          if (user == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Profile document not found for the signed-in user.',
                  style: AppTextStyles.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 50,
                  child: Icon(Icons.person, size: 50),
                ),
                const SizedBox(height: 12),
                Text(user.name, style: AppTextStyles.headingSmall),
                const SizedBox(height: 6),
                Text(user.email, style: AppTextStyles.bodyLarge),
              ],
            ),
          );
        },
      ),
    );
  }
}
