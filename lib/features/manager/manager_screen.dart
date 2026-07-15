import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/premium_widgets.dart';
import 'controllers/manager_controller.dart';
import 'models/manager_employee_summary_model.dart';

class ManagerScreen extends StatefulWidget {
  const ManagerScreen({super.key});

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> {
  late Future<List<ManagerEmployeeSummaryModel>> _future;
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _future = ManagerController.loadEmployeeSummaries();
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
    final future = ManagerController.loadEmployeeSummaries();
    setState(() {
      _future = future;
    });
    await future;
  }

  List<ManagerEmployeeSummaryModel> _filtered(
    List<ManagerEmployeeSummaryModel> summaries,
  ) {
    final query = _searchController.text.trim().toLowerCase();

    return summaries.where((summary) {
      final matchesStatus =
          _statusFilter == 'all' || summary.liveStatus == _statusFilter;
      final searchable = [
        summary.employee.name,
        summary.employee.email,
        summary.employee.phone,
        summary.employee.role,
        summary.liveStatus,
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
        title: Text('Manager', style: AppTextStyles.headingSmall),
      ),
      body: FutureBuilder<List<ManagerEmployeeSummaryModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const PremiumLoadingState(label: 'Loading employee overview');
          }

          if (snapshot.hasError) {
            return PremiumErrorState(
              title: 'Manager overview failed to load.',
              error: snapshot.error,
              onRetry: _refresh,
            );
          }

          final summaries = snapshot.data ?? const <ManagerEmployeeSummaryModel>[];
          final filtered = _filtered(summaries);

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
                            _ManagerSummaryCard(summaries: summaries),
                            const SizedBox(height: 16),
                            _ManagerSearchFilters(
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
                if (filtered.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: PremiumEmptyState(
                      icon: Icons.groups_outlined,
                      title: 'No employees found',
                      message: 'Employee search and filters did not match any records.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.crossAxisExtent >= 860;
                        return SliverGrid.builder(
                          itemCount: filtered.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: wide ? 2 : 1,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: wide ? 1.85 : 1.35,
                          ),
                          itemBuilder: (context, index) {
                            return _EmployeeCard(summary: filtered[index]);
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

class _ManagerSummaryCard extends StatelessWidget {
  final List<ManagerEmployeeSummaryModel> summaries;

  const _ManagerSummaryCard({required this.summaries});

  @override
  Widget build(BuildContext context) {
    final online = summaries.where((summary) => summary.liveStatus == 'online').length;
    final onBreak = summaries.where((summary) => summary.liveStatus == 'break').length;
    final completed =
        summaries.where((summary) => summary.liveStatus == 'completed').length;

    return PremiumCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            icon: Icons.supervisor_account_outlined,
            title: 'Manager Foundation',
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 620;
              final cards = [
                _ManagerMetric(
                  icon: Icons.groups_outlined,
                  label: 'Employees',
                  value: summaries.length.toString(),
                  color: AppColors.textPrimary,
                ),
                _ManagerMetric(
                  icon: Icons.radio_button_checked,
                  label: 'Live',
                  value: online.toString(),
                  color: AppColors.success,
                ),
                _ManagerMetric(
                  icon: Icons.free_breakfast_outlined,
                  label: 'Break',
                  value: onBreak.toString(),
                  color: AppColors.warning,
                ),
                _ManagerMetric(
                  icon: Icons.done_all_outlined,
                  label: 'Done',
                  value: completed.toString(),
                  color: AppColors.info,
                ),
              ];

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: wide ? 4 : 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: wide ? 1.45 : 1.28,
                children: cards,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ManagerSearchFilters extends StatelessWidget {
  final TextEditingController searchController;
  final String statusFilter;
  final ValueChanged<String> onFilterChanged;

  const _ManagerSearchFilters({
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
              hintText: 'Search employee, email, phone, role',
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
                  label: 'Live',
                  value: 'online',
                  selectedValue: statusFilter,
                  onSelected: onFilterChanged,
                ),
                _FilterChipButton(
                  label: 'Break',
                  value: 'break',
                  selectedValue: statusFilter,
                  onSelected: onFilterChanged,
                ),
                _FilterChipButton(
                  label: 'Done',
                  value: 'completed',
                  selectedValue: statusFilter,
                  onSelected: onFilterChanged,
                ),
                _FilterChipButton(
                  label: 'Offline',
                  value: 'offline',
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

class _EmployeeCard extends StatelessWidget {
  final ManagerEmployeeSummaryModel summary;

  const _EmployeeCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final status = _statusData(summary.liveStatus);
    final attendance = summary.todayAttendance;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white.withAlpha(18),
                child: Text(
                  _initials(summary.employee.name),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.employee.name.isEmpty
                          ? 'Employee'
                          : summary.employee.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headingSmall.copyWith(
                        fontSize: 18,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary.employee.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              PremiumStatusChip(label: status.label, color: status.color),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SmallStat(
                  label: 'Attendance',
                  value: attendance == null
                      ? 'No record'
                      : _formatDuration(
                          attendance.netWorkingDuration(DateTime.now()),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SmallStat(
                  label: 'Visits',
                  value:
                      '${summary.completedVisits}/${summary.totalVisits} done',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Live status is derived from today attendance. Visit summary is aggregated from customer visit records.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _ManagerMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ManagerMetric({
    required this.icon,
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
            PremiumIconChip(icon: icon, color: color),
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

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;

  const _SmallStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
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

class _StatusData {
  final String label;
  final Color color;

  const _StatusData({required this.label, required this.color});
}

_StatusData _statusData(String status) {
  switch (status) {
    case 'online':
      return const _StatusData(label: 'Live', color: AppColors.success);
    case 'break':
      return const _StatusData(label: 'Break', color: AppColors.warning);
    case 'completed':
      return const _StatusData(label: 'Done', color: AppColors.info);
    default:
      return const _StatusData(label: 'Offline', color: AppColors.textSecondary);
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return 'OR';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  return '${hours}h ${minutes}m';
}
