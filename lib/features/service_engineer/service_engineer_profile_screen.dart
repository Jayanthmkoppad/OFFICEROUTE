import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../auth/services/auth_service.dart';

class ServiceEngineerProfileScreen extends StatefulWidget {
  const ServiceEngineerProfileScreen({super.key});

  @override
  State<ServiceEngineerProfileScreen> createState() =>
      _ServiceEngineerProfileScreenState();
}

class _ServiceEngineerProfileScreenState
    extends State<ServiceEngineerProfileScreen> {
  Stream<UserModel?> _watchCurrentUser() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return Stream.value(null);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) {
          if (!snap.exists || snap.data() == null) return null;
          return UserModel.fromMap(snap.data()!);
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Field Engineer Profile'), elevation: 0),
      body: StreamBuilder<UserModel?>(
        stream: _watchCurrentUser(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          final name = user?.name.isNotEmpty == true
              ? user!.name
              : 'Service Engineer';
          final email = user?.email ?? '—';
          final phone = user?.phone.isNotEmpty == true ? user!.phone : '—';
          final empCode = user?.employeeCode.isNotEmpty == true
              ? user!.employeeCode
              : 'ENG-—';
          final serviceCentre = user?.serviceCentre.isNotEmpty == true
              ? user!.serviceCentre
              : 'Central Service Hub';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderCard(name: name, email: email, empCode: empCode),
                const SizedBox(height: 16),
                _InfoCard(
                  title: 'TECHNICAL CREDENTIALS',
                  rows: [
                    _DetailRow(label: 'Field Role', value: 'Service Engineer'),
                    _DetailRow(label: 'Service Centre', value: serviceCentre),
                    _DetailRow(label: 'Phone', value: phone),
                    _DetailRow(label: 'Email', value: email),
                    const _DetailRow(
                      label: 'Location Accuracy',
                      value: 'High Accuracy',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await AuthService.signOut();
                    },
                    icon: const Icon(Icons.logout, color: AppColors.error),
                    label: Text(
                      'Sign Out',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String name;
  final String email;
  final String empCode;

  const _HeaderCard({
    required this.name,
    required this.email,
    required this.empCode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.card,
            child: Text(
              name[0].toUpperCase(),
              style: AppTextStyles.headingMedium.copyWith(
                color: AppColors.info,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.headingSmall.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Service Engineer • $empCode',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: AppTextStyles.caption.copyWith(color: AppColors.info),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<_DetailRow> rows;

  const _InfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
