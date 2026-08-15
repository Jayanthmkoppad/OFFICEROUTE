import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../customer_visits/controllers/customer_visit_controller.dart';
import '../customer_visits/models/customer_visit_model.dart';

class ServiceEngineerHomeScreen extends StatefulWidget {
  final VoidCallback onNavigateToJobs;

  const ServiceEngineerHomeScreen({super.key, required this.onNavigateToJobs});

  @override
  State<ServiceEngineerHomeScreen> createState() =>
      _ServiceEngineerHomeScreenState();
}

class _ServiceEngineerHomeScreenState extends State<ServiceEngineerHomeScreen> {
  bool _isOnDuty = true;

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
      appBar: AppBar(title: const Text('Field Engineer Desk'), elevation: 0),
      body: StreamBuilder<UserModel?>(
        stream: _watchCurrentUser(),
        builder: (context, userSnap) {
          final user = userSnap.data;
          final name = user?.name.isNotEmpty == true
              ? user!.name
              : 'Service Engineer';

          return FutureBuilder<List<CustomerVisitModel>>(
            future: CustomerVisitController.loadMyVisits(),
            builder: (context, visitsSnap) {
              final visits = visitsSnap.data ?? const <CustomerVisitModel>[];
              final activeVisits = visits
                  .where((v) => v.status != 'completed')
                  .toList();

              return RefreshIndicator(
                onRefresh: () async => setState(() {}),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _EngineerHeaderCard(
                        name: name,
                        isOnDuty: _isOnDuty,
                        onDutyChanged: (val) => setState(() => _isOnDuty = val),
                      ),
                      const SizedBox(height: 16),
                      _JobSummaryMetricsRow(
                        totalJobs: visits.length,
                        activeJobs: activeVisits.length,
                        completedJobs: visits.length - activeVisits.length,
                      ),
                      const SizedBox(height: 16),
                      if (activeVisits.isNotEmpty) ...[
                        Text(
                          'ACTIVE JOB SITE',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _ActiveJobCard(
                          visit: activeVisits.first,
                          onPressed: widget.onNavigateToJobs,
                        ),
                        const SizedBox(height: 16),
                      ],
                      _QuickActionShortcutCard(
                        title: 'View Assigned Customer Visits',
                        subtitle:
                            'Check-in to customer sites & record inspection data',
                        icon: Icons.handyman_outlined,
                        onPressed: widget.onNavigateToJobs,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EngineerHeaderCard extends StatelessWidget {
  final String name;
  final bool isOnDuty;
  final ValueChanged<bool> onDutyChanged;

  const _EngineerHeaderCard({
    required this.name,
    required this.isOnDuty,
    required this.onDutyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.card,
            child: Text(
              name[0].toUpperCase(),
              style: AppTextStyles.headingSmall.copyWith(color: AppColors.info),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Field Service Engineer',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isOnDuty,
            onChanged: onDutyChanged,
            activeThumbColor: AppColors.success,
          ),
        ],
      ),
    );
  }
}

class _JobSummaryMetricsRow extends StatelessWidget {
  final int totalJobs;
  final int activeJobs;
  final int completedJobs;

  const _JobSummaryMetricsRow({
    required this.totalJobs,
    required this.activeJobs,
    required this.completedJobs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MetricCard(
          title: 'Assigned',
          value: '$totalJobs',
          color: AppColors.info,
        ),
        const SizedBox(width: 10),
        _MetricCard(
          title: 'Active',
          value: '$activeJobs',
          color: AppColors.warning,
        ),
        const SizedBox(width: 10),
        _MetricCard(
          title: 'Completed',
          value: '$completedJobs',
          color: AppColors.success,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTextStyles.headingMedium.copyWith(color: color),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveJobCard extends StatelessWidget {
  final CustomerVisitModel visit;
  final VoidCallback onPressed;

  const _ActiveJobCard({required this.visit, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                visit.customerName.isNotEmpty
                    ? visit.customerName
                    : 'Customer Site',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  visit.priority.toUpperCase(),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            visit.customerAddress,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(38),
            ),
            child: const Text('Open Job Details'),
          ),
        ],
      ),
    );
  }
}

class _QuickActionShortcutCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onPressed;

  const _QuickActionShortcutCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.info, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
