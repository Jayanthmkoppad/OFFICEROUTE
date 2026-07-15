import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/premium_widgets.dart';
import 'controllers/customer_visit_controller.dart';
import 'customer_visit_detail_screen.dart';
import 'models/customer_visit_model.dart';

class CustomerVisitScreen extends StatefulWidget {
  const CustomerVisitScreen({super.key});

  @override
  State<CustomerVisitScreen> createState() => _CustomerVisitScreenState();
}

class _CustomerVisitScreenState extends State<CustomerVisitScreen> {
  late Future<List<CustomerVisitModel>> _visitsFuture;
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _visitsFuture = CustomerVisitController.loadMyVisits();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _visitsFuture = CustomerVisitController.loadMyVisits();
    });
    await _visitsFuture;
  }

  Future<void> _openVisit(CustomerVisitModel visit) async {
    final updatedVisit = await Navigator.of(context).push<CustomerVisitModel>(
      MaterialPageRoute(
        builder: (_) => CustomerVisitDetailScreen(visit: visit),
      ),
    );

    if (!mounted) return;
    if (updatedVisit != null) {
      await _refresh();
    }
  }

  Future<void> _showCreateVisitDialog() async {
    final visitCreated = await showDialog<bool>(
          context: context,
          builder: (_) => const _CreateVisitDialog(),
        ) ??
        false;
    if (!mounted || !visitCreated) return;

    await _refresh();
  }

  List<CustomerVisitModel> _filteredVisits(List<CustomerVisitModel> visits) {
    final query = _searchController.text.trim().toLowerCase();

    return visits.where((visit) {
      final matchesStatus =
          _statusFilter == 'all' || visit.status == _statusFilter;
      final searchable = [
        visit.customerName,
        visit.customerAddress,
        visit.customerPhone,
        visit.purpose,
        visit.vehicleDetails,
        visit.motorSerialNumber,
        visit.controllerSerialNumber,
        visit.issueCategory,
        visit.issueDescription,
        visit.status,
      ].join(' ').toLowerCase();

      return matchesStatus && (query.isEmpty || searchable.contains(query));
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Customer Visits', style: AppTextStyles.headingSmall),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateVisitDialog,
        icon: const Icon(Icons.add),
        label: const Text('Visit'),
      ),
      body: FutureBuilder<List<CustomerVisitModel>>(
        future: _visitsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const PremiumLoadingState(label: 'Loading customer visits');
          }

          if (snapshot.hasError) {
            return PremiumErrorState(
              title: 'Customer visits failed to load.',
              error: snapshot.error,
              onRetry: _refresh,
            );
          }

          final visits = snapshot.data ?? const <CustomerVisitModel>[];
          final filteredVisits = _filteredVisits(visits);

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _VisitHeader(visits: visits),
                            const SizedBox(height: 16),
                            _VisitSearchAndFilters(
                              searchController: _searchController,
                              statusFilter: _statusFilter,
                              onFilterChanged: (value) {
                                setState(() {
                                  _statusFilter = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (filteredVisits.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: PremiumEmptyState(
                      icon: Icons.business_center_outlined,
                      title: visits.isEmpty
                          ? 'No customer visits yet'
                          : 'No visits match this search',
                      message: visits.isEmpty
                          ? 'Create the first customer visit to start tracking service work.'
                          : 'Try a different customer, serial number, status, or issue category.',
                      actionLabel: visits.isEmpty ? 'Create Visit' : null,
                      onAction: visits.isEmpty ? _showCreateVisitDialog : null,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.crossAxisExtent >= 760;
                        return SliverGrid.builder(
                          itemCount: filteredVisits.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isWide ? 2 : 1,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: isWide ? 1.95 : 1.35,
                          ),
                          itemBuilder: (context, index) {
                            final visit = filteredVisits[index];
                            return _CustomerVisitTile(
                              visit: visit,
                              onTap: () => _openVisit(visit),
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CreateVisitDialog extends StatefulWidget {
  const _CreateVisitDialog();

  @override
  State<_CreateVisitDialog> createState() => _CreateVisitDialogState();
}

class _CreateVisitDialogState extends State<_CreateVisitDialog> {
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerAddressController =
      TextEditingController();
  final TextEditingController _customerPhoneController =
      TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _vehicleController = TextEditingController();
  final TextEditingController _motorSerialController = TextEditingController();
  final TextEditingController _controllerSerialController =
      TextEditingController();
  final TextEditingController _issueDescriptionController =
      TextEditingController();
  final TextEditingController _partsController = TextEditingController();
  final TextEditingController _technicianNotesController =
      TextEditingController();

  String _warrantyStatus = 'Under Warranty';
  String _issueCategory = 'Inspection';

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerAddressController.dispose();
    _customerPhoneController.dispose();
    _purposeController.dispose();
    _notesController.dispose();
    _vehicleController.dispose();
    _motorSerialController.dispose();
    _controllerSerialController.dispose();
    _issueDescriptionController.dispose();
    _partsController.dispose();
    _technicianNotesController.dispose();
    super.dispose();
  }

  Future<void> _saveVisit() async {
    final customerName = _customerNameController.text.trim();
    final customerAddress = _customerAddressController.text.trim();
    final purpose = _purposeController.text.trim();

    if (customerName.isEmpty || customerAddress.isEmpty || purpose.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer name, address, and purpose are required.'),
        ),
      );
      return;
    }

    try {
      await CustomerVisitController.createVisit(
        customerName: customerName,
        customerAddress: customerAddress,
        customerPhone: _customerPhoneController.text.trim(),
        purpose: purpose,
        notes: _notesController.text.trim(),
        vehicleDetails: _vehicleController.text.trim(),
        motorSerialNumber: _motorSerialController.text.trim(),
        controllerSerialNumber: _controllerSerialController.text.trim(),
        warrantyStatus: _warrantyStatus,
        issueCategory: _issueCategory,
        issueDescription: _issueDescriptionController.text.trim(),
        partsUsed: _splitList(_partsController.text),
        technicianNotes: _technicianNotesController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Visit creation failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('New Customer Visit', style: AppTextStyles.headingSmall),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PremiumTextField(
                controller: _customerNameController,
                label: 'Customer name',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 12),
              PremiumTextField(
                controller: _customerAddressController,
                label: 'Customer address',
                icon: Icons.location_on_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              PremiumTextField(
                controller: _customerPhoneController,
                label: 'Customer phone',
                icon: Icons.call_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              PremiumTextField(
                controller: _purposeController,
                label: 'Purpose',
                icon: Icons.flag_outlined,
              ),
              const SizedBox(height: 12),
              PremiumTextField(
                controller: _vehicleController,
                label: 'Vehicle details',
                icon: Icons.two_wheeler_outlined,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PremiumTextField(
                      controller: _motorSerialController,
                      label: 'Motor serial',
                      icon: Icons.confirmation_number_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PremiumTextField(
                      controller: _controllerSerialController,
                      label: 'Controller serial',
                      icon: Icons.memory_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PremiumDropdown(
                      label: 'Warranty',
                      value: _warrantyStatus,
                      options: const [
                        'Under Warranty',
                        'Out of Warranty',
                        'Unknown',
                      ],
                      onChanged: (value) {
                        setState(() {
                          _warrantyStatus = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PremiumDropdown(
                      label: 'Issue category',
                      value: _issueCategory,
                      options: const [
                        'Inspection',
                        'Motor',
                        'Controller',
                        'Battery',
                        'Wiring',
                        'Software',
                        'Other',
                      ],
                      onChanged: (value) {
                        setState(() {
                          _issueCategory = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              PremiumTextField(
                controller: _issueDescriptionController,
                label: 'Issue description',
                icon: Icons.report_problem_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              PremiumTextField(
                controller: _partsController,
                label: 'Parts used',
                icon: Icons.build_outlined,
              ),
              const SizedBox(height: 12),
              PremiumTextField(
                controller: _technicianNotesController,
                label: 'Technician notes',
                icon: Icons.note_alt_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              PremiumTextField(
                controller: _notesController,
                label: 'Internal notes',
                icon: Icons.notes_outlined,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveVisit,
          child: const Text('Save Visit'),
        ),
      ],
    );
  }
}

class _VisitHeader extends StatelessWidget {
  final List<CustomerVisitModel> visits;

  const _VisitHeader({required this.visits});

  @override
  Widget build(BuildContext context) {
    final active = visits.where((visit) => visit.status == 'checked_in').length;
    final completed = visits.where((visit) => visit.status == 'completed').length;
    final pending = visits.where((visit) => visit.status == 'planned').length;

    return PremiumCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            icon: Icons.route_outlined,
            title: 'Visit Workspace',
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 620;
              final cards = [
                _HeaderMetric(
                  label: 'Total',
                  value: visits.length.toString(),
                  color: AppColors.textPrimary,
                ),
                _HeaderMetric(
                  label: 'Planned',
                  value: pending.toString(),
                  color: AppColors.textSecondary,
                ),
                _HeaderMetric(
                  label: 'Active',
                  value: active.toString(),
                  color: AppColors.info,
                ),
                _HeaderMetric(
                  label: 'Complete',
                  value: completed.toString(),
                  color: AppColors.success,
                ),
              ];

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isWide ? 4 : 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: isWide ? 1.8 : 1.45,
                children: cards,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HeaderMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PremiumTinyDot(color: color),
            const Spacer(),
            Text(
              value,
              style: AppTextStyles.headingSmall.copyWith(letterSpacing: 0),
            ),
            const SizedBox(height: 4),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

class _VisitSearchAndFilters extends StatelessWidget {
  final TextEditingController searchController;
  final String statusFilter;
  final ValueChanged<String> onFilterChanged;

  const _VisitSearchAndFilters({
    required this.searchController,
    required this.statusFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        children: [
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search customer, vehicle, issue, serial number',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white.withAlpha(10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: Colors.white.withAlpha(24)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: Colors.white.withAlpha(24)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppColors.textPrimary),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChipButton(
                  label: 'All',
                  value: 'all',
                  selectedValue: statusFilter,
                  onSelected: onFilterChanged,
                ),
                _FilterChipButton(
                  label: 'Planned',
                  value: 'planned',
                  selectedValue: statusFilter,
                  onSelected: onFilterChanged,
                ),
                _FilterChipButton(
                  label: 'Active',
                  value: 'checked_in',
                  selectedValue: statusFilter,
                  onSelected: onFilterChanged,
                ),
                _FilterChipButton(
                  label: 'Checked Out',
                  value: 'checked_out',
                  selectedValue: statusFilter,
                  onSelected: onFilterChanged,
                ),
                _FilterChipButton(
                  label: 'Completed',
                  value: 'completed',
                  selectedValue: statusFilter,
                  onSelected: onFilterChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final String value;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  const _FilterChipButton({
    required this.label,
    required this.value,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == selectedValue;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(value),
        selectedColor: Colors.white.withAlpha(42),
        backgroundColor: Colors.white.withAlpha(10),
        labelStyle: AppTextStyles.caption.copyWith(
          color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          letterSpacing: 0,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: Colors.white.withAlpha(selected ? 54 : 22)),
        ),
      ),
    );
  }
}

class _CustomerVisitTile extends StatelessWidget {
  final CustomerVisitModel visit;
  final VoidCallback onTap;

  const _CustomerVisitTile({required this.visit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = _visitStatus(visit.status);
    final timer = visit.visitDuration(DateTime.now());

    return PremiumCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PremiumIconChip(icon: Icons.business_center_outlined, color: status.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visit.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headingSmall.copyWith(
                        fontSize: 18,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      visit.customerAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PremiumStatusChip(label: status.label, color: status.color),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            visit.purpose,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyLarge.copyWith(letterSpacing: 0),
          ),
          const SizedBox(height: 8),
          Text(
            visit.issueDescription.isEmpty
                ? 'No issue description added.'
                : visit.issueDescription,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(height: 1.35),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _MiniMeta(
                  icon: Icons.timer_outlined,
                  label: _formatShortDuration(timer),
                ),
              ),
              Expanded(
                child: _MiniMeta(
                  icon: visit.hasGpsCheckIn
                      ? Icons.gps_fixed_outlined
                      : Icons.gps_off_outlined,
                  label: visit.hasGpsCheckIn ? 'GPS captured' : 'GPS pending',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption,
          ),
        ),
      ],
    );
  }
}

class _PremiumDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _PremiumDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: options
          .map((option) => DropdownMenuItem(value: option, child: Text(option)))
          .toList(growable: false),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white.withAlpha(10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withAlpha(24)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withAlpha(24)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _VisitStatusData {
  final String label;
  final Color color;

  const _VisitStatusData({required this.label, required this.color});
}

_VisitStatusData _visitStatus(String status) {
  switch (status.toLowerCase()) {
    case 'checked_in':
      return const _VisitStatusData(label: 'Active', color: AppColors.info);
    case 'checked_out':
      return const _VisitStatusData(label: 'Checked Out', color: AppColors.warning);
    case 'completed':
      return const _VisitStatusData(label: 'Done', color: AppColors.success);
    case 'planned':
      return const _VisitStatusData(label: 'Planned', color: AppColors.textSecondary);
    default:
      return const _VisitStatusData(label: 'Open', color: AppColors.textSecondary);
  }
}

List<String> _splitList(String value) {
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String _formatShortDuration(Duration duration) {
  if (duration == Duration.zero) return '0h 00m';
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  return '${hours}h ${minutes}m';
}
