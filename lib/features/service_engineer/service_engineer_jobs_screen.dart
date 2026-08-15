import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../customer_visits/controllers/customer_visit_controller.dart';
import '../customer_visits/models/customer_visit_model.dart';

class ServiceEngineerJobsScreen extends StatefulWidget {
  const ServiceEngineerJobsScreen({super.key});

  @override
  State<ServiceEngineerJobsScreen> createState() =>
      _ServiceEngineerJobsScreenState();
}

class _ServiceEngineerJobsScreenState extends State<ServiceEngineerJobsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assigned Customer Visits'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search customer, dealer, serial numbers...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<CustomerVisitModel>>(
              future: CustomerVisitController.searchMyVisits(_searchQuery),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final visits = snapshot.data ?? const <CustomerVisitModel>[];

                if (visits.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.assignment_outlined,
                          size: 48,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No customer visits found',
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: visits.length,
                    itemBuilder: (context, index) {
                      final visit = visits[index];
                      return _JobItemCard(
                        visit: visit,
                        onUpdate: () => setState(() {}),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _JobItemCard extends StatelessWidget {
  final CustomerVisitModel visit;
  final VoidCallback onUpdate;

  const _JobItemCard({required this.visit, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final isCheckedIn = visit.checkInTime != null && visit.checkOutTime == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCheckedIn ? AppColors.info : AppColors.border,
        ),
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
                  visit.status.toUpperCase(),
                  style: AppTextStyles.caption.copyWith(
                    color: visit.status == 'completed'
                        ? AppColors.success
                        : AppColors.info,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (visit.dealerName.isNotEmpty)
            Text(
              'Dealer: ${visit.dealerName}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          Text(
            visit.customerAddress,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const Divider(height: 20),
          _SerialInfoRow(label: 'Motor S/N', value: visit.motorSerialNumber),
          _SerialInfoRow(
            label: 'Controller S/N',
            value: visit.controllerSerialNumber,
          ),
          _SerialInfoRow(
            label: 'Battery S/N',
            value: visit.batterySerialNumber,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isCheckedIn ? 'Site Check-In Active' : 'Not Checked In',
                style: AppTextStyles.caption.copyWith(
                  color: isCheckedIn
                      ? AppColors.success
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (visit.status != 'completed')
                ElevatedButton.icon(
                  onPressed: () async {
                    if (isCheckedIn) {
                      await CustomerVisitController.checkOut(visit);
                    } else {
                      await CustomerVisitController.checkIn(visit);
                    }
                    onUpdate();
                  },
                  icon: Icon(
                    isCheckedIn ? Icons.logout : Icons.login,
                    size: 16,
                  ),
                  label: Text(isCheckedIn ? 'Check Out' : 'Check In'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCheckedIn
                        ? AppColors.warning
                        : AppColors.info,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SerialInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _SerialInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
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
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
