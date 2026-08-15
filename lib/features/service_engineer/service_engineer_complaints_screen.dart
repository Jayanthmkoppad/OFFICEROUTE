import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../customer_visits/controllers/customer_visit_controller.dart';
import '../customer_visits/models/customer_visit_model.dart';

class ServiceEngineerComplaintsScreen extends StatefulWidget {
  const ServiceEngineerComplaintsScreen({super.key});

  @override
  State<ServiceEngineerComplaintsScreen> createState() =>
      _ServiceEngineerComplaintsScreenState();
}

class _ServiceEngineerComplaintsScreenState
    extends State<ServiceEngineerComplaintsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Complaints & Resolution'),
        elevation: 0,
      ),
      body: FutureBuilder<List<CustomerVisitModel>>(
        future: CustomerVisitController.loadMyVisits(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final visits = (snapshot.data ?? const <CustomerVisitModel>[])
              .where(
                (v) =>
                    v.issueDescription.isNotEmpty || v.complaintId.isNotEmpty,
              )
              .toList();

          if (visits.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.assignment_turned_in_outlined,
                    size: 48,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No complaints assigned for inspection',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: visits.length,
              itemBuilder: (context, index) {
                final visit = visits[index];
                return _ComplaintCard(visit: visit);
              },
            ),
          );
        },
      ),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  final CustomerVisitModel visit;

  const _ComplaintCard({required this.visit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                visit.complaintId.isNotEmpty
                    ? 'Complaint #${visit.complaintId}'
                    : 'Service Complaint',
                style: AppTextStyles.bodyLarge.copyWith(
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
                  visit.issueCategory.isNotEmpty
                      ? visit.issueCategory
                      : 'General',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.info,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Customer: ${visit.customerName}',
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Stated Issue: ${visit.issueDescription.isNotEmpty ? visit.issueDescription : visit.purpose}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (visit.technicianNotes.isNotEmpty) ...[
            const Divider(height: 16),
            Text(
              'Technician Inspection Notes:',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              visit.technicianNotes,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
