import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/live_location_model.dart';
import '../../core/services/location_tracking_policy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/premium_widgets.dart';
import '../customer_visits/models/customer_visit_model.dart';
import '../manager/models/manager_employee_summary_model.dart';
import 'models/attendance_model.dart';

/// Supported employee filters backed by the current attendance schemas.
enum AttendanceOperationsFilter {
  all,
  present,
  absent,
  onDuty,
  offDuty,
  onBreak,
  inVisit,
  gpsException,
  syncPending,
  missedCheckout,
  multipleCheckIn,
  offline,
  available,
}

enum _EmployeeSort { name, status, workingHours, visits }

enum _AnalyticsRange { day, week, month }

/// Enterprise attendance presentation built from existing domain data.
class AttendanceOperationsDashboard extends StatefulWidget {
  final DateTime selectedDate;
  final List<ManagerEmployeeSummaryModel> employees;
  final List<AttendanceModel> attendanceRecords;
  final List<AttendanceModel> previousAttendanceRecords;
  final List<AttendanceModel> monthAttendanceRecords;
  final List<CustomerVisitModel> visits;
  final Map<String, LiveLocationModel> liveLocationsByUserId;
  final bool liveLocationsLoaded;
  final bool realtimeConnected;
  final bool refreshing;
  final Future<void> Function(DateTime date) onDateChanged;
  final Future<void> Function() onRefresh;
  final Future<List<AttendanceModel>> Function(String userId) onLoadHistory;
  final VoidCallback onOpenReports;

  const AttendanceOperationsDashboard({
    super.key,
    required this.selectedDate,
    required this.employees,
    required this.attendanceRecords,
    required this.previousAttendanceRecords,
    required this.monthAttendanceRecords,
    required this.visits,
    required this.liveLocationsByUserId,
    required this.liveLocationsLoaded,
    required this.realtimeConnected,
    required this.refreshing,
    required this.onDateChanged,
    required this.onRefresh,
    required this.onLoadHistory,
    required this.onOpenReports,
  });

  @override
  State<AttendanceOperationsDashboard> createState() =>
      _AttendanceOperationsDashboardState();
}

class _AttendanceOperationsDashboardState
    extends State<AttendanceOperationsDashboard> {
  static const int _pageSize = 8;
  static const int _previewItemCount = 5;

  final TextEditingController _searchController = TextEditingController();
  AttendanceOperationsFilter _filter = AttendanceOperationsFilter.all;
  _EmployeeSort _sort = _EmployeeSort.name;
  _AnalyticsRange _analyticsRange = _AnalyticsRange.month;
  int _page = 0;
  bool _analyticsExpanded = true;
  bool _showAllEmployees = false;
  bool _showAllInsights = false;
  bool _showAllExceptions = false;
  bool _showAllActivity = false;
  bool _organizationHealthExpanded = false;
  bool _heatmapExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant AttendanceOperationsDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateUtils.isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      _page = 0;
      _showAllEmployees = false;
      _showAllInsights = false;
      _showAllExceptions = false;
      _showAllActivity = false;
    }
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() {
      _page = 0;
      _showAllEmployees = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _OperationsMetrics.calculate(
      selectedDate: widget.selectedDate,
      employees: widget.employees,
      attendanceRecords: widget.attendanceRecords,
      previousAttendanceRecords: widget.previousAttendanceRecords,
      visits: widget.visits,
      liveLocationsByUserId: widget.liveLocationsByUserId,
      liveLocationsLoaded: widget.liveLocationsLoaded,
    );
    final filteredEmployees = _filteredEmployees(metrics);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        const SizedBox(height: 10),
        _buildSnapshot(metrics),
        const SizedBox(height: 10),
        _buildHealthAndInsights(metrics),
        const SizedBox(height: 10),
        _buildLiveWorkforce(metrics),
        const SizedBox(height: 10),
        _buildEmployeeDirectory(filteredEmployees),
        const SizedBox(height: 10),
        _buildExceptionsAndActivity(metrics),
        const SizedBox(height: 10),
        _buildAnalytics(metrics),
        const SizedBox(height: 10),
        _buildHeatmap(metrics),
        const SizedBox(height: 10),
        _buildKpisAndSummary(metrics),
        const SizedBox(height: 10),
        _buildOrganizationHealth(),
        const SizedBox(height: 10),
        _buildReportsAndActions(),
      ],
    );
  }

  Widget _buildHeader() {
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Row(
                children: [
                  const PremiumIconChip(icon: Icons.monitor_heart_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Workforce Control Center',
                          style: AppTextStyles.headingMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatLongDate(widget.selectedDate),
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PremiumStatusChip(
                    label: widget.realtimeConnected ? 'Live' : 'Reconnecting',
                    color: widget.realtimeConnected
                        ? AppColors.success
                        : AppColors.warning,
                    icon: widget.realtimeConnected
                        ? Icons.wifi_tethering
                        : Icons.sync,
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Refresh attendance operations',
                    child: IconButton(
                      onPressed: widget.refreshing ? null : _requestRefresh,
                      icon: widget.refreshing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                    ),
                  ),
                ],
              );
              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title,
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 12),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900 ? 3 : 2;
              final controlWidth =
                  (constraints.maxWidth - ((columns - 1) * 8)) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: controlWidth,
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(
                        _formatShortDate(widget.selectedDate),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  _UnavailableSelector(
                    width: controlWidth,
                    icon: Icons.business_outlined,
                    label: 'All Branches',
                    reason:
                        'Unavailable: users do not currently store a branch field.',
                  ),
                  _UnavailableSelector(
                    width: controlWidth,
                    icon: Icons.groups_2_outlined,
                    label: 'All Departments',
                    reason:
                        'Unavailable: users do not currently store a department field.',
                  ),
                  SizedBox(
                    width: controlWidth,
                    height: 46,
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search employee',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: controlWidth,
                    height: 46,
                    child: PopupMenuButton<AttendanceOperationsFilter>(
                      initialValue: _filter,
                      onSelected: _setFilter,
                      itemBuilder: (context) => AttendanceOperationsFilter.values
                          .map(
                            (filter) => PopupMenuItem(
                              value: filter,
                              child: Text(_filterLabel(filter)),
                            ),
                          )
                          .toList(growable: false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.filter_list),
                          suffixIcon: Icon(Icons.arrow_drop_down),
                          isDense: true,
                        ),
                        child: Text(
                          _filterLabel(_filter),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: controlWidth,
                    height: 46,
                    child: PopupMenuButton<_EmployeeSort>(
                      initialValue: _sort,
                      onSelected: (sort) {
                        setState(() {
                          _sort = sort;
                          _page = 0;
                          _showAllEmployees = false;
                        });
                      },
                      itemBuilder: (context) => _EmployeeSort.values
                          .map(
                            (sort) => PopupMenuItem(
                              value: sort,
                              child: Text(_sortLabel(sort)),
                            ),
                          )
                          .toList(growable: false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.sort),
                          suffixIcon: Icon(Icons.arrow_drop_down),
                          isDense: true,
                        ),
                        child: Text(
                          _sortLabel(_sort),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSnapshot(_OperationsMetrics metrics) {
    final cards = <_SnapshotMetric>[
      _SnapshotMetric(
        label: 'Present',
        value: '${metrics.present}',
        icon: Icons.how_to_reg_outlined,
        color: AppColors.success,
        filter: AttendanceOperationsFilter.present,
      ),
      _SnapshotMetric(
        label: 'Absent',
        value: '${metrics.absent}',
        icon: Icons.person_off_outlined,
        color: AppColors.error,
        filter: AttendanceOperationsFilter.absent,
      ),
      _SnapshotMetric.unavailable(
        label: 'Leave',
        icon: Icons.event_busy_outlined,
        reason: 'The attendance schema has no leave status or leave records.',
      ),
      _SnapshotMetric.unavailable(
        label: 'Holiday',
        icon: Icons.celebration_outlined,
        reason: 'No holiday calendar exists in the approved backend.',
      ),
      _SnapshotMetric(
        label: 'On Duty',
        value: '${metrics.onDuty}',
        icon: Icons.play_circle_outline,
        color: AppColors.info,
        filter: AttendanceOperationsFilter.onDuty,
      ),
      _SnapshotMetric(
        label: 'Off Duty',
        value: '${metrics.offDuty}',
        icon: Icons.stop_circle_outlined,
        color: AppColors.textSecondary,
        filter: AttendanceOperationsFilter.offDuty,
      ),
      _SnapshotMetric(
        label: 'On Break',
        value: '${metrics.onBreak}',
        icon: Icons.free_breakfast_outlined,
        color: AppColors.warning,
        filter: AttendanceOperationsFilter.onBreak,
      ),
      _SnapshotMetric.unavailable(
        label: 'Travelling',
        icon: Icons.route_outlined,
        reason:
            'Attendance and visit records do not expose a travelling state.',
      ),
      _SnapshotMetric(
        label: 'In Visit',
        value: '${metrics.inVisit}',
        icon: Icons.location_on_outlined,
        color: AppColors.info,
        filter: AttendanceOperationsFilter.inVisit,
      ),
      _SnapshotMetric.unavailable(
        label: 'Late Arrival',
        icon: Icons.schedule_outlined,
        reason: 'Shift start times and late-arrival rules are not stored.',
      ),
      _SnapshotMetric.unavailable(
        label: 'Early Logout',
        icon: Icons.running_with_errors_outlined,
        reason: 'Shift end times and early-logout rules are not stored.',
      ),
      _SnapshotMetric.unavailable(
        label: 'Overtime',
        icon: Icons.more_time_outlined,
        reason: 'No approved overtime threshold or approval fields exist.',
      ),
      _SnapshotMetric(
        label: 'GPS Exception',
        value: '${metrics.gpsExceptions}',
        icon: Icons.gps_off_outlined,
        color: AppColors.error,
        filter: AttendanceOperationsFilter.gpsException,
      ),
      _SnapshotMetric.unavailable(
        label: 'Corrections',
        icon: Icons.edit_calendar_outlined,
        reason: 'No attendance-correction model or approval API exists.',
      ),
      _SnapshotMetric(
        label: 'Sync Pending',
        value: '${metrics.syncPending}',
        icon: Icons.cloud_sync_outlined,
        color: AppColors.warning,
        filter: AttendanceOperationsFilter.syncPending,
      ),
      _SnapshotMetric(
        label: 'Missed Checkout',
        value: '${metrics.missedCheckoutIds.length}',
        icon: Icons.logout_outlined,
        color: AppColors.error,
        filter: AttendanceOperationsFilter.missedCheckout,
      ),
      _SnapshotMetric(
        label: 'Multiple Check-in',
        value: '${metrics.duplicateCheckInIds.length}',
        icon: Icons.content_copy_outlined,
        color: AppColors.warning,
        filter: AttendanceOperationsFilter.multipleCheckIn,
      ),
    ];

    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            icon: Icons.dashboard_outlined,
            title: 'Workforce Snapshot',
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1100
                  ? 6
                  : constraints.maxWidth >= 760
                      ? 5
                      : constraints.maxWidth >= 480
                          ? 3
                          : 2;
              final width = (constraints.maxWidth - ((columns - 1) * 8)) /
                  columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: cards
                    .map(
                      (metric) => SizedBox(
                        width: width,
                        height: 92,
                        child: _SnapshotCard(
                          metric: metric,
                          onTap: () => _activateMetric(metric),
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHealthAndInsights(_OperationsMetrics metrics) {
    final insights = metrics.insights;
    final visibleInsights = _showAllInsights
        ? insights
        : insights.take(3).toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        final health = _HealthScoreCard(metrics: metrics);
        final insightCard = PremiumCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumSectionHeader(
                icon: Icons.lightbulb_outline,
                title: 'Smart Operations Insights',
                actionLabel: insights.length > 3
                    ? (_showAllInsights ? 'Show 3' : 'View All')
                    : null,
                onAction: insights.length > 3
                    ? () {
                        setState(() {
                          _showAllInsights = !_showAllInsights;
                        });
                      }
                    : null,
              ),
              const SizedBox(height: 10),
              if (insights.isEmpty)
                const _InlineEmptyState(
                  icon: Icons.query_stats_outlined,
                  title: 'No operational insight yet',
                  message:
                      'Insights appear when employee attendance is available for the selected date.',
                )
              else
                ...visibleInsights.map(
                  (insight) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _InfoRow(
                      icon: insight.icon,
                      title: insight.title,
                      detail: insight.detail,
                      color: insight.color,
                    ),
                  ),
                ),
            ],
          ),
        );

        if (!wide) {
          return Column(
            children: [health, const SizedBox(height: 10), insightCard],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: health),
            const SizedBox(width: 10),
            Expanded(flex: 6, child: insightCard),
          ],
        );
      },
    );
  }

  Widget _buildLiveWorkforce(_OperationsMetrics metrics) {
    final statuses = [
      if (metrics.liveStatusApplicable)
        _SnapshotMetric(
          label: 'Available',
          value: '${metrics.available}',
          icon: Icons.check_circle_outline,
          color: AppColors.success,
          filter: AttendanceOperationsFilter.available,
        )
      else
        _SnapshotMetric.unavailable(
          label: 'Available',
          icon: Icons.check_circle_outline,
          reason: metrics.selectedDateIsToday
              ? 'Live availability is loading from live_locations.'
              : 'Live availability is shown only for today.',
        ),
      _SnapshotMetric(
        label: 'On Duty',
        value: '${metrics.onDuty}',
        icon: Icons.badge_outlined,
        color: AppColors.info,
        filter: AttendanceOperationsFilter.onDuty,
      ),
      _SnapshotMetric(
        label: 'On Break',
        value: '${metrics.onBreak}',
        icon: Icons.pause_circle_outline,
        color: AppColors.warning,
        filter: AttendanceOperationsFilter.onBreak,
      ),
      _SnapshotMetric(
        label: 'In Visit',
        value: '${metrics.inVisit}',
        icon: Icons.handyman_outlined,
        color: AppColors.info,
        filter: AttendanceOperationsFilter.inVisit,
      ),
      if (metrics.liveStatusApplicable)
        _SnapshotMetric(
          label: 'Offline',
          value: '${metrics.offline}',
          icon: Icons.wifi_off_outlined,
          color: AppColors.textSecondary,
          filter: AttendanceOperationsFilter.offline,
        )
      else
        _SnapshotMetric.unavailable(
          label: 'Offline',
          icon: Icons.wifi_off_outlined,
          reason: metrics.selectedDateIsToday
              ? 'Live offline state is loading from live_locations.'
              : 'Live offline state is shown only for today.',
        ),
      _SnapshotMetric(
        label: 'Absent',
        value: '${metrics.absent}',
        icon: Icons.person_off_outlined,
        color: AppColors.error,
        filter: AttendanceOperationsFilter.absent,
      ),
      _SnapshotMetric.unavailable(
        label: 'Travelling',
        icon: Icons.route_outlined,
        reason:
            'Attendance and visit records do not expose a travelling state.',
      ),
      _SnapshotMetric.unavailable(
        label: 'Leave',
        icon: Icons.event_busy_outlined,
        reason: 'A leave source is not available in the existing backend.',
      ),
    ];

    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            icon: Icons.wifi_tethering,
            title: 'Live Workforce Status',
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1040
                  ? 8
                  : constraints.maxWidth >= 700
                      ? 4
                      : 2;
              const gap = 8.0;
              final width =
                  (constraints.maxWidth - ((columns - 1) * gap)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: statuses
                    .map(
                      (status) => SizedBox(
                        width: width,
                        height: 88,
                        child: _SnapshotCard(
                          metric: status,
                          onTap: () => _activateMetric(status),
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeDirectory(
    List<ManagerEmployeeSummaryModel> filteredEmployees,
  ) {
    final pageSize = _showAllEmployees ? _pageSize : _previewItemCount;
    final maxPage = filteredEmployees.isEmpty
        ? 0
        : (filteredEmployees.length - 1) ~/ pageSize;
    final safePage = _page > maxPage ? maxPage : _page;
    final start = safePage * pageSize;
    final end = math.min(start + pageSize, filteredEmployees.length);
    final pageEmployees = filteredEmployees.sublist(start, end);

    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumSectionHeader(
            icon: Icons.groups_outlined,
            title: 'Employee Operations (${filteredEmployees.length})',
            actionLabel: filteredEmployees.length > _previewItemCount
                ? (_showAllEmployees ? 'Show 5' : 'View All')
                : null,
            onAction: filteredEmployees.length > _previewItemCount
                ? () {
                    setState(() {
                      _showAllEmployees = !_showAllEmployees;
                      _page = 0;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 10),
          if (filteredEmployees.isEmpty)
            const _InlineEmptyState(
              icon: Icons.person_search_outlined,
              title: 'No employees match this view',
              message: 'Clear the search or choose another status filter.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 840) {
                  return _buildEmployeeTable(pageEmployees);
                }
                return _buildEmployeeCards(pageEmployees);
              },
            ),
          if (_showAllEmployees && filteredEmployees.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${start + 1}-$end of ${filteredEmployees.length}',
                  style: AppTextStyles.caption,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: safePage == 0
                      ? null
                      : () {
                          setState(() {
                            _page = safePage - 1;
                          });
                        },
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '${safePage + 1} / ${maxPage + 1}',
                  style: AppTextStyles.caption,
                ),
                IconButton(
                  tooltip: 'Next page',
                  onPressed: safePage >= maxPage
                      ? null
                      : () {
                          setState(() {
                            _page = safePage + 1;
                          });
                        },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmployeeTable(
    List<ManagerEmployeeSummaryModel> employees,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 54,
        dataRowMaxHeight: 60,
        horizontalMargin: 8,
        columnSpacing: 16,
        columns: const [
          DataColumn(label: Text('Employee')),
          DataColumn(label: Text('Employee ID')),
          DataColumn(label: Text('Designation')),
          DataColumn(label: Text('Department')),
          DataColumn(label: Text('Branch')),
          DataColumn(label: Text('Current Status')),
          DataColumn(label: Text('Shift')),
          DataColumn(label: Text('Working Hours')),
          DataColumn(label: Text('Visits')),
          DataColumn(label: Text('Break')),
          DataColumn(label: Text('Overtime')),
          DataColumn(label: Text('Attendance')),
          DataColumn(label: Text('Actions')),
        ],
        rows: employees.map((summary) {
          final attendance = summary.todayAttendance;
          final status = _employeeStatus(summary);
          final statusColor = _statusColor(status);
          return DataRow(
            cells: [
              DataCell(
                SizedBox(
                  width: 190,
                  child: Row(
                    children: [
                      _EmployeeAvatar(summary: summary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _employeeName(summary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              summary.employee.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              DataCell(Text(_shortId(summary.employee.uid))),
              const DataCell(
                _UnavailableValue(
                  reason: 'Designation is not stored in users.',
                ),
              ),
              const DataCell(
                _UnavailableValue(
                  reason: 'Department is not stored in users.',
                ),
              ),
              const DataCell(
                _UnavailableValue(reason: 'Branch is not stored in users.'),
              ),
              DataCell(PremiumStatusChip(label: status, color: statusColor)),
              const DataCell(
                _UnavailableValue(reason: 'No shift model is available.'),
              ),
              DataCell(
                Text(
                  _formatDuration(
                    attendance?.netWorkingDuration(DateTime.now()) ??
                        Duration.zero,
                  ),
                ),
              ),
              DataCell(Text('${summary.totalVisits}')),
              DataCell(
                Text(
                  _formatDuration(
                    attendance?.breakDuration(DateTime.now()) ?? Duration.zero,
                  ),
                ),
              ),
              const DataCell(
                _UnavailableValue(
                  reason: 'No approved overtime policy or field exists.',
                ),
              ),
              DataCell(
                Text(attendance?.checkInTime == null ? 'Absent' : 'Present'),
              ),
              DataCell(
                IconButton(
                  tooltip: 'Employee actions',
                  onPressed: () => _showEmployeeActions(summary),
                  icon: const Icon(Icons.more_horiz),
                ),
              ),
            ],
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildEmployeeCards(
    List<ManagerEmployeeSummaryModel> employees,
  ) {
    return Column(
      children: employees.map((summary) {
        final attendance = summary.todayAttendance;
        final status = _employeeStatus(summary);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withAlpha(22)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _EmployeeAvatar(summary: summary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _employeeName(summary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _shortId(summary.employee.uid),
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  PremiumStatusChip(
                    label: status,
                    color: _statusColor(status),
                  ),
                  IconButton(
                    tooltip: 'Employee actions',
                    onPressed: () => _showEmployeeActions(summary),
                    icon: const Icon(Icons.more_horiz),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _CompactValue(
                      label: 'Work',
                      value: _formatDuration(
                        attendance?.netWorkingDuration(DateTime.now()) ??
                            Duration.zero,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _CompactValue(
                      label: 'Break',
                      value: _formatDuration(
                        attendance?.breakDuration(DateTime.now()) ??
                            Duration.zero,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _CompactValue(
                      label: 'Visits',
                      value: '${summary.totalVisits}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildExceptionsAndActivity(_OperationsMetrics metrics) {
    final exceptions = metrics.exceptions;
    final activity = metrics.activity;
    final visibleExceptions = _showAllExceptions
        ? exceptions
        : exceptions.take(_previewItemCount).toList(growable: false);
    final visibleActivity = _showAllActivity
        ? activity
        : activity.take(_previewItemCount).toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        final exceptionCard = PremiumCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumSectionHeader(
                icon: Icons.report_problem_outlined,
                title: 'Attendance Exceptions (${exceptions.length})',
                actionLabel: exceptions.length > _previewItemCount
                    ? (_showAllExceptions ? 'Show 5' : 'View All')
                    : null,
                onAction: exceptions.length > _previewItemCount
                    ? () {
                        setState(() {
                          _showAllExceptions = !_showAllExceptions;
                        });
                      }
                    : null,
              ),
              const SizedBox(height: 10),
              if (exceptions.isEmpty)
                const _InlineEmptyState(
                  icon: Icons.verified_outlined,
                  title: 'No supported exceptions',
                  message:
                      'No GPS, sync, duplicate check-in, or missed-checkout exceptions were found.',
                )
              else
                ...visibleExceptions.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _InfoRow(
                      icon: item.icon,
                      title: item.employee,
                      detail: item.detail,
                      color: item.color,
                    ),
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                'Late, early logout, long-break, and correction exceptions require approved shift and correction rules.',
                style: AppTextStyles.caption.copyWith(height: 1.4),
              ),
            ],
          ),
        );
        final activityCard = PremiumCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumSectionHeader(
                icon: Icons.history_toggle_off_outlined,
                title: 'Live Activity',
                actionLabel: activity.length > _previewItemCount
                    ? (_showAllActivity ? 'Show 5' : 'View All')
                    : null,
                onAction: activity.length > _previewItemCount
                    ? () {
                        setState(() {
                          _showAllActivity = !_showAllActivity;
                        });
                      }
                    : null,
              ),
              const SizedBox(height: 10),
              if (activity.isEmpty)
                const _InlineEmptyState(
                  icon: Icons.hourglass_empty_outlined,
                  title: 'No activity for this date',
                  message:
                      'Duty and visit events will appear here as Firestore updates arrive.',
                )
              else
                ...visibleActivity.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _InfoRow(
                      icon: item.icon,
                      title: item.title,
                      detail:
                          '${item.employee} - ${_formatClock(item.timestamp)}',
                      color: item.color,
                    ),
                  ),
                ),
            ],
          ),
        );
        if (!wide) {
          return Column(
            children: [exceptionCard, const SizedBox(height: 10), activityCard],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: exceptionCard),
            const SizedBox(width: 10),
            Expanded(child: activityCard),
          ],
        );
      },
    );
  }

  Widget _buildOrganizationHealth() {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          initiallyExpanded: _organizationHealthExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _organizationHealthExpanded = expanded;
            });
          },
          leading: const PremiumIconChip(icon: Icons.account_tree_outlined),
          title: Text(
            'Organization Health',
            style: AppTextStyles.headingSmall.copyWith(
              fontSize: 18,
              letterSpacing: 0,
            ),
          ),
          subtitle: Text(
            'Branch and department readiness',
            style: AppTextStyles.caption,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            if (_organizationHealthExpanded) ...[
              const Divider(),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 720;
                  const branch = _UnavailablePanel(
                    icon: Icons.business_outlined,
                    title: 'Branch Health',
                    message:
                        'Branch comparison is unavailable because user profiles do not contain branch or region identifiers.',
                  );
                  const department = _UnavailablePanel(
                    icon: Icons.groups_2_outlined,
                    title: 'Department Health',
                    message:
                        'Department comparison is unavailable because user profiles do not contain department or designation fields.',
                  );
                  if (!wide) {
                    return const Column(
                      children: [branch, SizedBox(height: 8), department],
                    );
                  }
                  return const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: branch),
                      SizedBox(width: 8),
                      Expanded(child: department),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalytics(_OperationsMetrics metrics) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          initiallyExpanded: _analyticsExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _analyticsExpanded = expanded;
            });
          },
          leading: const PremiumIconChip(icon: Icons.analytics_outlined),
          title: Text(
            'Attendance Analytics',
            style: AppTextStyles.headingSmall.copyWith(
              fontSize: 18,
              letterSpacing: 0,
            ),
          ),
          subtitle: Text(
            'Date-scoped trends loaded on demand',
            style: AppTextStyles.caption,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            if (_analyticsExpanded) ...[
              const Divider(),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<_AnalyticsRange>(
                    segments: const [
                      ButtonSegment(
                        value: _AnalyticsRange.day,
                        icon: Icon(Icons.today_outlined),
                        label: Text('Day'),
                      ),
                      ButtonSegment(
                        value: _AnalyticsRange.week,
                        icon: Icon(Icons.view_week_outlined),
                        label: Text('Week'),
                      ),
                      ButtonSegment(
                        value: _AnalyticsRange.month,
                        icon: Icon(Icons.calendar_month_outlined),
                        label: Text('Month'),
                      ),
                    ],
                    selected: {_analyticsRange},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _analyticsRange = selection.first;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_analyticsRange == _AnalyticsRange.day)
                _DailyAnalyticsPanel(metrics: metrics)
              else if (_analyticsRange == _AnalyticsRange.week)
                _WeeklyAttendanceTrend(
                  month: widget.selectedDate,
                  employeeCount: metrics.totalEmployees,
                  records: widget.monthAttendanceRecords,
                  employeeIds: metrics.employeeIds,
                )
              else ...[
                _MonthlyAttendanceTrend(
                  month: widget.selectedDate,
                  employeeCount: metrics.totalEmployees,
                  records: widget.monthAttendanceRecords,
                  employeeIds: metrics.employeeIds,
                ),
                const SizedBox(height: 12),
                _MonthlyWorkHoursTrend(
                  month: widget.selectedDate,
                  records: widget.monthAttendanceRecords,
                  employeeIds: metrics.employeeIds,
                ),
              ],
              const SizedBox(height: 10),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 4),
                leading: const Icon(Icons.compare_arrows_outlined, size: 20),
                title: Text(
                  'Secondary analytics',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Advanced comparisons and unavailable dimensions',
                  style: AppTextStyles.caption,
                ),
                children: const [
                  _UnavailablePanel(
                    icon: Icons.compare_arrows_outlined,
                    title: 'Advanced comparisons',
                    message:
                        'Late, overtime, punctuality, shift, branch, and department trends require fields not present in the existing schemas.',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmap(_OperationsMetrics metrics) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          initiallyExpanded: _heatmapExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _heatmapExpanded = expanded;
            });
          },
          leading: const PremiumIconChip(
            icon: Icons.calendar_view_month_outlined,
          ),
          title: Text(
            'Monthly Attendance Heatmap',
            style: AppTextStyles.headingSmall.copyWith(
              fontSize: 18,
              letterSpacing: 0,
            ),
          ),
          subtitle: Text(
            'Daily organization presence rate',
            style: AppTextStyles.caption,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            if (_heatmapExpanded) ...[
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Unsupported leave, holiday, late, and overtime colors are not inferred.',
                style: AppTextStyles.caption.copyWith(height: 1.35),
              ),
              const SizedBox(height: 10),
              _AttendanceHeatmap(
                month: widget.selectedDate,
                employeeCount: metrics.totalEmployees,
                employeeIds: metrics.employeeIds,
                records: widget.monthAttendanceRecords,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKpisAndSummary(_OperationsMetrics metrics) {
    final kpis = [
      _KpiValue('Attendance Rate', _formatPercent(metrics.attendanceRate)),
      _KpiValue('Absenteeism', _formatPercent(1 - metrics.attendanceRate)),
      _KpiValue('Average Check-in', metrics.averageCheckInLabel),
      _KpiValue('Average Checkout', metrics.averageCheckOutLabel),
      _KpiValue('Average Break', _formatDuration(metrics.averageBreak)),
      _KpiValue('Average Work', _formatDuration(metrics.averageWork)),
      _KpiValue('GPS Compliance', _formatPercent(metrics.gpsCompliance)),
      _KpiValue(
        'Checkout Discipline',
        metrics.checkoutComplianceLabel,
      ),
      _KpiValue('Visits Completed', '${metrics.completedVisits}'),
      _KpiValue('Workforce Health', '${metrics.healthScore}/100'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        final kpiCard = PremiumCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumSectionHeader(
                icon: Icons.speed_outlined,
                title: 'Enterprise KPIs',
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 620
                      ? 5
                      : constraints.maxWidth >= 420
                          ? 3
                          : 2;
                  const gap = 8.0;
                  final width =
                      (constraints.maxWidth - ((columns - 1) * gap)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: kpis
                        .map(
                          (kpi) => SizedBox(
                            width: width,
                            child: _CompactValue(
                              label: kpi.label,
                              value: kpi.value,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Shift compliance, correction rate, overtime, leave, and productivity index are hidden until their approved data sources exist.',
                style: AppTextStyles.caption.copyWith(height: 1.4),
              ),
            ],
          ),
        );
        final summaryCard = PremiumCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumSectionHeader(
                icon: Icons.summarize_outlined,
                title: 'Operations Summary',
              ),
              const SizedBox(height: 10),
              Text(
                metrics.generatedSummary,
                style: AppTextStyles.bodyMedium.copyWith(
                  height: 1.4,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Generated locally from the selected attendance and visit records. No external AI is used.',
                style: AppTextStyles.caption.copyWith(height: 1.4),
              ),
            ],
          ),
        );
        if (!wide) {
          return Column(
            children: [kpiCard, const SizedBox(height: 10), summaryCard],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: kpiCard),
            const SizedBox(width: 10),
            Expanded(flex: 4, child: summaryCard),
          ],
        );
      },
    );
  }

  Widget _buildReportsAndActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        final reports = PremiumCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumSectionHeader(
                icon: Icons.description_outlined,
                title: 'Reports',
              ),
              const SizedBox(height: 10),
              _buildOperationGrid(
                children: [
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: widget.onOpenReports,
                      icon: const Icon(Icons.open_in_new, size: 17),
                      label: const Text(
                        'Open Existing Reports',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const _DisabledOperation(
                    label: 'Admin Attendance Exports',
                    reason:
                        'The existing reports controller is user-scoped and has no organization export API.',
                  ),
                  const _DisabledOperation(
                    label: 'Payroll / Overtime Reports',
                    reason:
                        'Payroll and approved overtime fields are not available.',
                  ),
                  const _DisabledOperation(
                    label: 'Branch / Department Reports',
                    reason:
                        'Branch and department identifiers are not stored on users.',
                  ),
                ],
              ),
            ],
          ),
        );
        final actions = PremiumCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumSectionHeader(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Admin Actions',
              ),
              const SizedBox(height: 10),
              _buildOperationGrid(
                children: const [
                  _DisabledOperation(
                    label: 'Approve / Reject Correction',
                    reason:
                        'No attendance-correction model, status field, or approval API exists.',
                  ),
                  _DisabledOperation(
                    label: 'Approve Overtime',
                    reason:
                        'No overtime request model or approval service exists.',
                  ),
                  _DisabledOperation(
                    label: 'Force End Duty',
                    reason:
                        'AttendanceService has no admin-authorized force-checkout API.',
                  ),
                ],
              ),
            ],
          ),
        );
        if (!wide) {
          return Column(
            children: [reports, const SizedBox(height: 10), actions],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: reports),
            const SizedBox(width: 10),
            Expanded(child: actions),
          ],
        );
      },
    );
  }

  Widget _buildOperationGrid({required List<Widget> children}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 300 ? 2 : 1;
        const gap = 8.0;
        final width =
            (constraints.maxWidth - ((columns - 1) * gap)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: children
              .map(
                (child) => SizedBox(
                  width: width,
                  child: child,
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  List<ManagerEmployeeSummaryModel> _filteredEmployees(
    _OperationsMetrics metrics,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = widget.employees.where((summary) {
      final employee = summary.employee;
      final matchesSearch = query.isEmpty ||
          employee.name.toLowerCase().contains(query) ||
          employee.email.toLowerCase().contains(query) ||
          employee.phone.toLowerCase().contains(query) ||
          employee.uid.toLowerCase().contains(query);
      if (!matchesSearch) return false;

      final attendance = summary.todayAttendance;
      switch (_filter) {
        case AttendanceOperationsFilter.all:
          return true;
        case AttendanceOperationsFilter.present:
          return attendance?.checkInTime != null;
        case AttendanceOperationsFilter.absent:
          return attendance?.checkInTime == null;
        case AttendanceOperationsFilter.onDuty:
          return attendance?.isCheckedIn == true &&
              attendance?.isOnBreak != true &&
              summary.activeVisits == 0;
        case AttendanceOperationsFilter.offDuty:
          return summary.activeVisits == 0 &&
              attendance?.isCheckedOut == true;
        case AttendanceOperationsFilter.onBreak:
          return summary.activeVisits == 0 &&
              attendance?.isOnBreak == true;
        case AttendanceOperationsFilter.inVisit:
          return summary.activeVisits > 0;
        case AttendanceOperationsFilter.gpsException:
          return metrics.gpsExceptionIds.contains(employee.uid);
        case AttendanceOperationsFilter.syncPending:
          return attendance != null && attendance.syncStatus != 'synced';
        case AttendanceOperationsFilter.missedCheckout:
          return metrics.missedCheckoutIds.contains(employee.uid);
        case AttendanceOperationsFilter.multipleCheckIn:
          return metrics.duplicateCheckInIds.contains(employee.uid);
        case AttendanceOperationsFilter.offline:
          return metrics.liveStatusApplicable &&
              !metrics.onlineLocationIds.contains(employee.uid);
        case AttendanceOperationsFilter.available:
          return metrics.liveStatusApplicable &&
              metrics.activeLocationIds.contains(employee.uid) &&
              attendance?.isCheckedIn == true &&
              attendance?.isOnBreak != true &&
              summary.activeVisits == 0;
      }
    }).toList();

    filtered.sort((a, b) {
      switch (_sort) {
        case _EmployeeSort.name:
          return _employeeName(a).toLowerCase().compareTo(
                _employeeName(b).toLowerCase(),
              );
        case _EmployeeSort.status:
          return _employeeStatus(a).compareTo(_employeeStatus(b));
        case _EmployeeSort.workingHours:
          final now = DateTime.now();
          int minutesFor(ManagerEmployeeSummaryModel summary) {
            final attendance = summary.todayAttendance;
            if (attendance == null) return 0;
            if (attendance.checkOutTime == null &&
                !DateUtils.isSameDay(widget.selectedDate, now)) {
              return 0;
            }
            return attendance
                .netWorkingDuration(attendance.checkOutTime ?? now)
                .inMinutes;
          }

          final aMinutes = minutesFor(a);
          final bMinutes = minutesFor(b);
          return bMinutes.compareTo(aMinutes);
        case _EmployeeSort.visits:
          return b.totalVisits.compareTo(a.totalVisits);
      }
    });
    return filtered;
  }

  void _setFilter(AttendanceOperationsFilter filter) {
    setState(() {
      _filter = filter;
      _page = 0;
      _showAllEmployees = false;
    });
  }

  void _activateMetric(_SnapshotMetric metric) {
    final filter = metric.filter;
    if (filter != null) {
      _setFilter(filter);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(metric.unavailableReason ?? 'Metric unavailable.')),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select operations date',
    );
    if (picked != null && mounted) {
      try {
        await widget.onDateChanged(picked);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to load attendance for that date. Check the connection and retry.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _requestRefresh() async {
    try {
      await widget.onRefresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to refresh attendance. Check the connection and retry.',
          ),
        ),
      );
    }
  }

  void _showEmployeeActions(ManagerEmployeeSummaryModel summary) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _employeeName(summary),
                style: AppTextStyles.headingSmall.copyWith(letterSpacing: 0),
              ),
              const SizedBox(height: 6),
              Text(_shortId(summary.employee.uid), style: AppTextStyles.caption),
              const SizedBox(height: 14),
              _ActionTile(
                icon: Icons.timeline_outlined,
                title: 'View Today\'s Timeline',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showTimeline(summary);
                },
              ),
              _ActionTile(
                icon: Icons.history_outlined,
                title: 'View Attendance History',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showHistory(summary);
                },
              ),
              _ActionTile(
                icon: Icons.handyman_outlined,
                title: 'View Today\'s Visits',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showVisits(summary);
                },
              ),
              const Divider(height: 24),
              const _DisabledActionTile(
                icon: Icons.person_outline,
                title: 'View Profile',
                reason:
                    'ProfileScreen only supports the authenticated user and accepts no employee id.',
              ),
              const _DisabledActionTile(
                icon: Icons.map_outlined,
                title: 'Locate on Map',
                reason:
                    'MapScreen accepts no employee target for focused navigation.',
              ),
              const _DisabledActionTile(
                icon: Icons.edit_calendar_outlined,
                title: 'Approve Correction',
                reason: 'No attendance-correction backend exists.',
              ),
              const _DisabledActionTile(
                icon: Icons.call_outlined,
                title: 'Call',
                reason: 'No platform phone launcher is configured.',
              ),
              const _DisabledActionTile(
                icon: Icons.message_outlined,
                title: 'Message',
                reason: 'No platform messaging launcher is configured.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTimeline(ManagerEmployeeSummaryModel summary) {
    final attendance = summary.todayAttendance;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${_employeeName(summary)} Timeline',
                style: AppTextStyles.headingSmall.copyWith(letterSpacing: 0),
              ),
              const SizedBox(height: 16),
              if (attendance == null)
                const _InlineEmptyState(
                  icon: Icons.event_busy_outlined,
                  title: 'No attendance record',
                  message: 'This employee has no record for the selected date.',
                )
              else ...[
                _InfoRow(
                  icon: Icons.login,
                  title: 'Duty Started',
                  detail: _formatClock(attendance.checkInTime),
                  color: AppColors.success,
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.pause_circle_outline,
                  title: attendance.isOnBreak ? 'Break Active' : 'Break Total',
                  detail: _formatDuration(
                    attendance.breakDuration(DateTime.now()),
                  ),
                  color: AppColors.warning,
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.logout,
                  title: 'Duty Ended',
                  detail: _formatClock(attendance.checkOutTime),
                  color: AppColors.textSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showHistory(ManagerEmployeeSummaryModel summary) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${_employeeName(summary)} History',
                  style: AppTextStyles.headingSmall.copyWith(letterSpacing: 0),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: FutureBuilder<List<AttendanceModel>>(
                    future: widget.onLoadHistory(summary.employee.uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      if (snapshot.hasError) {
                        return const _InlineEmptyState(
                          icon: Icons.cloud_off_outlined,
                          title: 'History unavailable',
                          message:
                              'The attendance history could not be loaded. Try again later.',
                        );
                      }
                      final records = snapshot.data ?? const <AttendanceModel>[];
                      if (records.isEmpty) {
                        return const _InlineEmptyState(
                          icon: Icons.history_outlined,
                          title: 'No attendance history',
                          message: 'No records exist for this employee.',
                        );
                      }
                      return ListView.separated(
                        itemCount: records.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (context, index) {
                          final record = records[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_formatShortDate(record.date)),
                            subtitle: Text(
                              '${_formatClock(record.checkInTime)} - ${_formatClock(record.checkOutTime)}',
                            ),
                            trailing: Text(
                              _formatDuration(
                                record.netWorkingDuration(DateTime.now()),
                              ),
                              style: AppTextStyles.caption,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showVisits(ManagerEmployeeSummaryModel summary) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.64,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${_employeeName(summary)} Visits',
                  style: AppTextStyles.headingSmall.copyWith(letterSpacing: 0),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: summary.visits.isEmpty
                      ? const _InlineEmptyState(
                          icon: Icons.location_off_outlined,
                          title: 'No visits for this date',
                          message:
                              'Customer visits assigned to this employee will appear here.',
                        )
                      : ListView.separated(
                          itemCount: summary.visits.length,
                          separatorBuilder: (_, _) => const Divider(),
                          itemBuilder: (context, index) {
                            final visit = summary.visits[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const PremiumIconChip(
                                icon: Icons.handyman_outlined,
                                color: AppColors.info,
                              ),
                              title: Text(
                                visit.customerName.isEmpty
                                    ? 'Customer visit'
                                    : visit.customerName,
                              ),
                              subtitle: Text(
                                visit.customerAddress.isEmpty
                                    ? visit.purpose
                                    : visit.customerAddress,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: PremiumStatusChip(
                                label: _titleCase(visit.status),
                                color: visit.status == 'completed'
                                    ? AppColors.success
                                    : visit.status == 'checked_in'
                                        ? AppColors.info
                                        : AppColors.textSecondary,
                              ),
                            );
                          },
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

class _UnavailableSelector extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final String reason;

  const _UnavailableSelector({
    required this.width,
    required this.icon,
    required this.label,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: reason,
      child: SizedBox(
        width: width,
        height: 46,
        child: OutlinedButton.icon(
          onPressed: null,
          icon: Icon(icon, size: 18),
          label: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _SnapshotMetric {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final AttendanceOperationsFilter? filter;
  final String? unavailableReason;

  const _SnapshotMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.filter,
  }) : unavailableReason = null;

  const _SnapshotMetric.unavailable({
    required this.label,
    required this.icon,
    required String reason,
  })  : value = '--',
        color = AppColors.textDisabled,
        filter = null,
        unavailableReason = reason;
}

class _SnapshotCard extends StatelessWidget {
  final _SnapshotMetric metric;
  final VoidCallback onTap;

  const _SnapshotCard({required this.metric, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withAlpha(8),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: metric.color.withAlpha(52)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(metric.icon, size: 16, color: metric.color),
                  const Spacer(),
                  if (metric.unavailableReason != null)
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: metric.color,
                    ),
                ],
              ),
              const Spacer(),
              Text(
                metric.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.headingSmall.copyWith(
                  color: metric.color == AppColors.textDisabled
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                metric.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthScoreCard extends StatelessWidget {
  final _OperationsMetrics metrics;

  const _HealthScoreCard({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            icon: Icons.health_and_safety_outlined,
            title: 'Workforce Health',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: metrics.healthScore / 100,
                        strokeWidth: 6,
                        backgroundColor: Colors.white.withAlpha(18),
                        color: metrics.healthColor,
                      ),
                    ),
                    Text(
                      '${metrics.healthScore}',
                      style: AppTextStyles.headingMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PremiumStatusChip(
                      label: metrics.healthLabel,
                      color: metrics.healthColor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Attendance ${_formatPercent(metrics.attendanceRate)}',
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'GPS ${_formatPercent(metrics.gpsCompliance)}',
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Checkout ${metrics.checkoutComplianceLabel}',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            metrics.healthFormulaDescription,
            style: AppTextStyles.caption.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _InlineEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(18)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withAlpha(22),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withAlpha(48)),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmployeeAvatar extends StatelessWidget {
  final ManagerEmployeeSummaryModel summary;

  const _EmployeeAvatar({required this.summary});

  @override
  Widget build(BuildContext context) {
    final image = summary.employee.profileImage.trim();
    final name = _employeeName(summary);
    return ClipOval(
      child: Container(
        width: 40,
        height: 40,
        color: Colors.white.withAlpha(14),
        child: image.isEmpty
            ? Center(
                child: Text(
                  name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.person_outline),
              ),
      ),
    );
  }
}

class _UnavailableValue extends StatelessWidget {
  final String reason;

  const _UnavailableValue({required this.reason});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: reason,
      child: Text('--', style: AppTextStyles.caption),
    );
  }
}

class _CompactValue extends StatelessWidget {
  final String label;
  final String value;

  const _CompactValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(18)),
      ),
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
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

class _UnavailablePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _UnavailablePanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumIconChip(icon: icon, color: AppColors.textDisabled),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: AppTextStyles.caption.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DisabledOperation extends StatelessWidget {
  final String label;
  final String reason;

  const _DisabledOperation({required this.label, required this.reason});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: reason,
      child: SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.lock_outline, size: 17),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _DisabledActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String reason;

  const _DisabledActionTile({
    required this.icon,
    required this.title,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: reason,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          enabled: false,
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(reason, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.lock_outline, size: 18),
        ),
      ),
    );
  }
}

class _DailyAnalyticsPanel extends StatelessWidget {
  final _OperationsMetrics metrics;

  const _DailyAnalyticsPanel({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final values = [
      _KpiValue('Present', '${metrics.present}'),
      _KpiValue('Absent', '${metrics.absent}'),
      _KpiValue('On Duty', '${metrics.onDuty}'),
      _KpiValue('On Break', '${metrics.onBreak}'),
      _KpiValue('In Visit', '${metrics.inVisit}'),
      _KpiValue('Attendance', _formatPercent(metrics.attendanceRate)),
      _KpiValue('Average Work', _formatDuration(metrics.averageWork)),
      _KpiValue('Average Break', _formatDuration(metrics.averageBreak)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720
            ? 4
            : constraints.maxWidth >= 420
                ? 3
                : 2;
        const gap = 8.0;
        final width =
            (constraints.maxWidth - ((columns - 1) * gap)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: values
              .map(
                (value) => SizedBox(
                  width: width,
                  child: _CompactValue(
                    label: value.label,
                    value: value.value,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _WeeklyAttendanceTrend extends StatelessWidget {
  final DateTime month;
  final int employeeCount;
  final Set<String> employeeIds;
  final List<AttendanceModel> records;

  const _WeeklyAttendanceTrend({
    required this.month,
    required this.employeeCount,
    required this.employeeIds,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final counts = _uniqueAttendanceByDay(records, employeeIds);
    if (employeeCount == 0 || counts.isEmpty) {
      return const _InlineEmptyState(
        icon: Icons.view_week_outlined,
        title: 'No weekly trend available',
        message: 'Attendance records are required to build this chart.',
      );
    }

    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final weekCount = (daysInMonth / 7).ceil();
    final weeklyRates = List<double>.generate(weekCount, (weekIndex) {
      final firstDay = weekIndex * 7 + 1;
      final lastDay = math.min(firstDay + 6, daysInMonth);
      final recordedDays = <double>[];
      for (var day = firstDay; day <= lastDay; day++) {
        final present = counts[day];
        if (present == null) continue;
        recordedDays.add(present.length / employeeCount);
      }
      if (recordedDays.isEmpty) return 0;
      return recordedDays.fold<double>(0.0, (sum, rate) => sum + rate) /
          recordedDays.length;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Average Attendance by 7-day Period',
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(
          'Only days containing attendance records are included; no work calendar is inferred.',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(weekCount, (index) {
            final rate = weeklyRates[index];
            return Expanded(
              child: Tooltip(
                message: 'Week ${index + 1}: ${_formatPercent(rate)}',
                child: Column(
                  children: [
                    SizedBox(
                      height: 110,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: 24,
                          height: math.max(3.0, rate * 104),
                          decoration: BoxDecoration(
                            color: _rateColor(rate),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text('W${index + 1}', style: AppTextStyles.caption),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _MonthlyAttendanceTrend extends StatelessWidget {
  final DateTime month;
  final int employeeCount;
  final Set<String> employeeIds;
  final List<AttendanceModel> records;

  const _MonthlyAttendanceTrend({
    required this.month,
    required this.employeeCount,
    required this.employeeIds,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final counts = _uniqueAttendanceByDay(records, employeeIds);
    if (employeeCount == 0 || counts.isEmpty) {
      return const _InlineEmptyState(
        icon: Icons.bar_chart_outlined,
        title: 'No monthly trend available',
        message: 'Attendance records are required to build this chart.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Attendance %',
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(days, (index) {
              final day = index + 1;
              final rate = (counts[day]?.length ?? 0) / employeeCount;
              return Tooltip(
                message: 'Day $day: ${_formatPercent(rate)}',
                child: SizedBox(
                  width: 30,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 104,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 14,
                            height: math.max(3.0, rate * 100),
                            decoration: BoxDecoration(
                              color: _rateColor(rate),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('$day', style: AppTextStyles.caption),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _MonthlyWorkHoursTrend extends StatelessWidget {
  final DateTime month;
  final Set<String> employeeIds;
  final List<AttendanceModel> records;

  const _MonthlyWorkHoursTrend({
    required this.month,
    required this.employeeIds,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final dailyHours = <int, List<double>>{};
    final now = DateTime.now();
    for (final record in records) {
      final date = record.date;
      if (date == null || !employeeIds.contains(record.userId)) continue;
      if (record.checkOutTime == null && !DateUtils.isSameDay(date, now)) {
        continue;
      }
      final reference = record.checkOutTime ?? now;
      dailyHours.putIfAbsent(date.day, () => []).add(
            record.netWorkingDuration(reference).inMinutes / 60,
          );
    }
    if (dailyHours.isEmpty) {
      return const _InlineEmptyState(
        icon: Icons.timer_off_outlined,
        title: 'No working-hours trend',
        message: 'Completed duty records are required for this chart.',
      );
    }

    final averages = <int, double>{};
    for (final entry in dailyHours.entries) {
      averages[entry.key] =
          entry.value.fold<double>(0.0, (sum, value) => sum + value) /
              entry.value.length;
    }
    final peakHours = averages.values.fold<double>(
      0.0,
      (current, value) => value > current ? value : current,
    );
    final maxHours = peakHours < 1.0 ? 1.0 : peakHours;
    final days = DateUtils.getDaysInMonth(month.year, month.month);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Average Working Hours',
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(days, (index) {
              final day = index + 1;
              final hours = averages[day] ?? 0;
              return Tooltip(
                message: 'Day $day: ${hours.toStringAsFixed(1)} hours',
                child: SizedBox(
                  width: 30,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 104,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 14,
                            height: math.max(
                              3.0,
                              (hours / maxHours) * 100,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.info,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('$day', style: AppTextStyles.caption),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _AttendanceHeatmap extends StatelessWidget {
  final DateTime month;
  final int employeeCount;
  final Set<String> employeeIds;
  final List<AttendanceModel> records;

  const _AttendanceHeatmap({
    required this.month,
    required this.employeeCount,
    required this.employeeIds,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final leading = DateTime(month.year, month.month).weekday % 7;
    final counts = _uniqueAttendanceByDay(records, employeeIds);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
              .map(
                (label) => Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: leading + days,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 7,
            crossAxisSpacing: 7,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (context, index) {
            if (index < leading) return const SizedBox.shrink();
            final day = index - leading + 1;
            final present = counts[day]?.length ?? 0;
            final rate = employeeCount == 0 ? 0.0 : present / employeeCount;
            final color = _rateColor(rate);
            return Tooltip(
              message:
                  'Day $day: $present/$employeeCount present (${_formatPercent(rate)})',
              child: Container(
                decoration: BoxDecoration(
                  color: color.withAlpha(rate == 0 ? 10 : 38),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withAlpha(90)),
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: AppTextStyles.caption.copyWith(
                      color: rate == 0
                          ? AppColors.textDisabled
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _KpiValue {
  final String label;
  final String value;

  const _KpiValue(this.label, this.value);
}

class _InsightItem {
  final IconData icon;
  final String title;
  final String detail;
  final Color color;

  const _InsightItem({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
  });
}

class _ExceptionItem {
  final IconData icon;
  final String employee;
  final String detail;
  final Color color;
  final int severity;

  const _ExceptionItem({
    required this.icon,
    required this.employee,
    required this.detail,
    required this.color,
    required this.severity,
  });
}

class _ActivityItem {
  final IconData icon;
  final String title;
  final String employee;
  final DateTime timestamp;
  final Color color;

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.employee,
    required this.timestamp,
    required this.color,
  });
}

class _OperationsMetrics {
  final int totalEmployees;
  final int present;
  final int absent;
  final int available;
  final int onDuty;
  final int offDuty;
  final int onBreak;
  final int inVisit;
  final int offline;
  final bool selectedDateIsToday;
  final bool liveStatusApplicable;
  final int gpsExceptions;
  final int syncPending;
  final int completedVisits;
  final double attendanceRate;
  final double gpsCompliance;
  final double checkoutCompliance;
  final bool checkoutDisciplineApplicable;
  final Duration averageBreak;
  final Duration averageWork;
  final String averageCheckInLabel;
  final String averageCheckOutLabel;
  final int healthScore;
  final Set<String> employeeIds;
  final Set<String> activeLocationIds;
  final Set<String> onlineLocationIds;
  final Set<String> gpsExceptionIds;
  final Set<String> missedCheckoutIds;
  final Set<String> duplicateCheckInIds;
  final List<_InsightItem> insights;
  final List<_ExceptionItem> exceptions;
  final List<_ActivityItem> activity;

  const _OperationsMetrics({
    required this.totalEmployees,
    required this.present,
    required this.absent,
    required this.available,
    required this.onDuty,
    required this.offDuty,
    required this.onBreak,
    required this.inVisit,
    required this.offline,
    required this.selectedDateIsToday,
    required this.liveStatusApplicable,
    required this.gpsExceptions,
    required this.syncPending,
    required this.completedVisits,
    required this.attendanceRate,
    required this.gpsCompliance,
    required this.checkoutCompliance,
    required this.checkoutDisciplineApplicable,
    required this.averageBreak,
    required this.averageWork,
    required this.averageCheckInLabel,
    required this.averageCheckOutLabel,
    required this.healthScore,
    required this.employeeIds,
    required this.activeLocationIds,
    required this.onlineLocationIds,
    required this.gpsExceptionIds,
    required this.missedCheckoutIds,
    required this.duplicateCheckInIds,
    required this.insights,
    required this.exceptions,
    required this.activity,
  });

  factory _OperationsMetrics.calculate({
    required DateTime selectedDate,
    required List<ManagerEmployeeSummaryModel> employees,
    required List<AttendanceModel> attendanceRecords,
    required List<AttendanceModel> previousAttendanceRecords,
    required List<CustomerVisitModel> visits,
    required Map<String, LiveLocationModel> liveLocationsByUserId,
    required bool liveLocationsLoaded,
  }) {
    final employeeIds = employees.map((item) => item.employee.uid).toSet();
    final presentEmployees = employees
        .where((item) => item.todayAttendance?.checkInTime != null)
        .toList(growable: false);
    final present = presentEmployees.length;
    final totalEmployees = employees.length;
    final absent = math.max(0, totalEmployees - present);
    final onBreak = employees
        .where(
          (item) => item.activeVisits == 0 &&
              item.todayAttendance?.isOnBreak == true,
        )
        .length;
    final inVisit = employees.where((item) => item.activeVisits > 0).length;
    final onDuty = employees.where((item) {
      final attendance = item.todayAttendance;
      return attendance?.isCheckedIn == true &&
          attendance?.isOnBreak != true &&
          item.activeVisits == 0;
    }).length;
    final offDuty = employees
        .where(
          (item) => item.activeVisits == 0 &&
              item.todayAttendance?.isCheckedOut == true,
        )
        .length;
    final liveNow = DateTime.now();
    final selectedDateIsToday = DateUtils.isSameDay(selectedDate, liveNow);
    final liveStatusApplicable = selectedDateIsToday && liveLocationsLoaded;
    final onlineLocationIds = liveStatusApplicable
        ? employees.where((summary) {
            final location = liveLocationsByUserId[summary.employee.uid];
            if (location == null) return false;
            if (location.status == LocationTrackingPolicy.statusPaused) {
              return summary.todayAttendance?.isOnBreak == true;
            }
            return location.status == LocationTrackingPolicy.statusActive &&
                !LocationTrackingPolicy.isStale(location.updatedAt, liveNow);
          }).map((summary) => summary.employee.uid).toSet()
        : <String>{};
    final activeLocationIds = liveStatusApplicable
        ? employees.where((summary) {
            final location = liveLocationsByUserId[summary.employee.uid];
            return location != null &&
                location.status == LocationTrackingPolicy.statusActive &&
                !LocationTrackingPolicy.isStale(location.updatedAt, liveNow);
          }).map((summary) => summary.employee.uid).toSet()
        : <String>{};
    final available = employees.where((summary) {
      final attendance = summary.todayAttendance;
      return activeLocationIds.contains(summary.employee.uid) &&
          attendance?.isCheckedIn == true &&
          attendance?.isOnBreak != true &&
          summary.activeVisits == 0;
    }).length;
    final offline = liveStatusApplicable
        ? math.max(0, totalEmployees - onlineLocationIds.length)
        : 0;

    final gpsExceptionIds = <String>{};
    var syncPending = 0;
    for (final summary in presentEmployees) {
      final attendance = summary.todayAttendance!;
      final validation = attendance.locationValidationStatus.toLowerCase();
      final gpsValid = attendance.hasCheckInLocation &&
          (validation == 'validated' || validation == 'valid');
      if (!gpsValid) gpsExceptionIds.add(summary.employee.uid);
      if (attendance.syncStatus.toLowerCase() != 'synced') syncPending++;
    }

    final recordsByUser = <String, List<AttendanceModel>>{};
    for (final record in attendanceRecords) {
      if (!employeeIds.contains(record.userId)) continue;
      recordsByUser.putIfAbsent(record.userId, () => []).add(record);
    }
    final duplicateCheckInIds = recordsByUser.entries
        .where((entry) => entry.value.length > 1)
        .map((entry) => entry.key)
        .toSet();

    final today = DateTime.now();
    final selectedDay = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final currentDay = DateTime(today.year, today.month, today.day);
    final isPastDate = selectedDay.isBefore(currentDay);
    final missedCheckoutIds = isPastDate
        ? employees
            .where(
              (item) => item.todayAttendance?.checkInTime != null &&
                  item.todayAttendance?.checkOutTime == null,
            )
            .map((item) => item.employee.uid)
            .toSet()
        : <String>{};

    final attendanceRate = totalEmployees == 0 ? 0.0 : present / totalEmployees;
    final previousPresent = previousAttendanceRecords
        .where((record) => employeeIds.contains(record.userId))
        .map((record) => record.userId)
        .toSet()
        .length;
    final previousAttendanceRate =
        totalEmployees == 0 ? 0.0 : previousPresent / totalEmployees;
    final gpsCompliance = present == 0
        ? 0.0
        : (present - gpsExceptionIds.length) / present;
    final checkoutCompliance = present == 0
        ? 0.0
        : isPastDate
            ? (present - missedCheckoutIds.length) / present
            : 0.0;

    final nowReference = DateTime.now();
    final workingRecords = presentEmployees.where((summary) {
      final attendance = summary.todayAttendance!;
      return attendance.checkOutTime != null ||
          DateUtils.isSameDay(selectedDate, nowReference);
    }).toList(growable: false);
    final totalWorkMinutes = workingRecords.fold<int>(0, (sum, summary) {
      final attendance = summary.todayAttendance!;
      return sum +
          attendance
              .netWorkingDuration(attendance.checkOutTime ?? nowReference)
              .inMinutes;
    });
    final averageWork = workingRecords.isEmpty
        ? Duration.zero
        : Duration(minutes: totalWorkMinutes ~/ workingRecords.length);
    final totalBreakMinutes = workingRecords.fold<int>(0, (sum, summary) {
      final attendance = summary.todayAttendance!;
      return sum +
          attendance
              .breakDuration(attendance.checkOutTime ?? nowReference)
              .inMinutes;
    });
    final averageBreak = workingRecords.isEmpty
        ? Duration.zero
        : Duration(minutes: totalBreakMinutes ~/ workingRecords.length);

    final checkIns = presentEmployees
        .map((item) => item.todayAttendance?.checkInTime)
        .whereType<DateTime>()
        .toList(growable: false);
    final checkOuts = presentEmployees
        .map((item) => item.todayAttendance?.checkOutTime)
        .whereType<DateTime>()
        .toList(growable: false);
    final averageCheckInLabel = _averageTimeLabel(checkIns);
    final averageCheckOutLabel = _averageTimeLabel(checkOuts);

    // Historical health includes checkout discipline because checkout is due.
    // Current-day health excludes checkout instead of assuming a future result.
    // Shift, late, correction, overtime, and leave factors are excluded until
    // their approved backend fields and policies exist.
    final rawHealthScore = isPastDate
        ? ((attendanceRate * 60) +
                (gpsCompliance * 25) +
                (checkoutCompliance * 15))
            .round()
        : ((attendanceRate * 70) + (gpsCompliance * 30)).round();
    final healthScore = math.max(0, math.min(100, rawHealthScore));

    final nameByUser = <String, String>{
      for (final summary in employees)
        summary.employee.uid: _employeeName(summary),
    };
    final exceptions = <_ExceptionItem>[];
    for (final id in missedCheckoutIds) {
      exceptions.add(
        _ExceptionItem(
          icon: Icons.logout_outlined,
          employee: nameByUser[id] ?? _shortId(id),
          detail: 'Duty started but no checkout was recorded.',
          color: AppColors.error,
          severity: 4,
        ),
      );
    }
    for (final id in duplicateCheckInIds) {
      exceptions.add(
        _ExceptionItem(
          icon: Icons.content_copy_outlined,
          employee: nameByUser[id] ?? _shortId(id),
          detail: 'Multiple attendance documents exist for this date.',
          color: AppColors.error,
          severity: 4,
        ),
      );
    }
    for (final id in gpsExceptionIds) {
      exceptions.add(
        _ExceptionItem(
          icon: Icons.gps_off_outlined,
          employee: nameByUser[id] ?? _shortId(id),
          detail: 'Check-in GPS is missing or not validated.',
          color: AppColors.warning,
          severity: 3,
        ),
      );
    }
    for (final summary in presentEmployees) {
      final attendance = summary.todayAttendance!;
      if (attendance.syncStatus.toLowerCase() == 'synced') continue;
      exceptions.add(
        _ExceptionItem(
          icon: Icons.cloud_sync_outlined,
          employee: _employeeName(summary),
          detail: 'Offline sync status: ${_titleCase(attendance.syncStatus)}.',
          color: AppColors.warning,
          severity: 2,
        ),
      );
    }
    exceptions.sort((a, b) => b.severity.compareTo(a.severity));

    final activity = <_ActivityItem>[];
    for (final record in attendanceRecords) {
      if (!employeeIds.contains(record.userId)) continue;
      final employee = nameByUser[record.userId] ?? _shortId(record.userId);
      final checkIn = record.checkInTime;
      if (checkIn != null) {
        activity.add(
          _ActivityItem(
            icon: Icons.login,
            title: 'Duty Started',
            employee: employee,
            timestamp: checkIn,
            color: AppColors.success,
          ),
        );
      }
      final breakStart = record.breakStartTime;
      if (breakStart != null) {
        activity.add(
          _ActivityItem(
            icon: Icons.pause_circle_outline,
            title: 'Break Started',
            employee: employee,
            timestamp: breakStart,
            color: AppColors.warning,
          ),
        );
      }
      final checkOut = record.checkOutTime;
      if (checkOut != null) {
        activity.add(
          _ActivityItem(
            icon: Icons.logout,
            title: 'Duty Ended',
            employee: employee,
            timestamp: checkOut,
            color: AppColors.textSecondary,
          ),
        );
      }
    }
    for (final visit in visits) {
      if (!employeeIds.contains(visit.userId)) continue;
      final employee = nameByUser[visit.userId] ?? _shortId(visit.userId);
      final started = visit.checkInTime;
      if (started != null && DateUtils.isSameDay(started, selectedDate)) {
        activity.add(
          _ActivityItem(
            icon: Icons.location_on_outlined,
            title: 'Visit Started',
            employee: employee,
            timestamp: started,
            color: AppColors.info,
          ),
        );
      }
      final finished = visit.completedAt ?? visit.checkOutTime;
      if (finished != null && DateUtils.isSameDay(finished, selectedDate)) {
        activity.add(
          _ActivityItem(
            icon: Icons.task_alt_outlined,
            title: 'Visit Finished',
            employee: employee,
            timestamp: finished,
            color: AppColors.success,
          ),
        );
      }
    }
    activity.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final insights = <_InsightItem>[];
    if (totalEmployees > 0 &&
        previousAttendanceRecords.isNotEmpty &&
        (attendanceRate - previousAttendanceRate).abs() >= 0.005) {
      final improved = attendanceRate > previousAttendanceRate;
      insights.add(
        _InsightItem(
          icon: improved ? Icons.trending_up : Icons.trending_down,
          title: improved
              ? 'Attendance improved from yesterday'
              : 'Attendance is below yesterday',
          detail:
              '${_formatPercent(previousAttendanceRate)} to ${_formatPercent(attendanceRate)}.',
          color: improved ? AppColors.success : AppColors.warning,
        ),
      );
    }
    if (onDuty > 0) {
      insights.add(
        _InsightItem(
          icon: Icons.badge_outlined,
          title: '$onDuty employees are actively on duty',
          detail: 'Break and active-visit employees are shown separately.',
          color: AppColors.info,
        ),
      );
    }
    if (checkIns.isNotEmpty) {
      insights.add(
        _InsightItem(
          icon: Icons.schedule_outlined,
          title: 'Average check-in is $averageCheckInLabel',
          detail: 'Calculated from ${checkIns.length} real check-in records.',
          color: AppColors.info,
        ),
      );
    }
    if (gpsExceptionIds.isNotEmpty) {
      insights.add(
        _InsightItem(
          icon: Icons.gps_off_outlined,
          title: '${gpsExceptionIds.length} GPS exceptions need attention',
          detail: 'Check-in coordinates or validation are missing.',
          color: AppColors.warning,
        ),
      );
    }
    if (inVisit > 0) {
      insights.add(
        _InsightItem(
          icon: Icons.handyman_outlined,
          title: '$inVisit employees are inside customer visits',
          detail: 'Derived from active customer visit records.',
          color: AppColors.success,
        ),
      );
    }

    final completedVisits =
        visits.where((visit) => visit.status == 'completed').length;

    return _OperationsMetrics(
      totalEmployees: totalEmployees,
      present: present,
      absent: absent,
      available: available,
      onDuty: onDuty,
      offDuty: offDuty,
      onBreak: onBreak,
      inVisit: inVisit,
      offline: offline,
      selectedDateIsToday: selectedDateIsToday,
      liveStatusApplicable: liveStatusApplicable,
      gpsExceptions: gpsExceptionIds.length,
      syncPending: syncPending,
      completedVisits: completedVisits,
      attendanceRate: attendanceRate,
      gpsCompliance: gpsCompliance,
      checkoutCompliance: checkoutCompliance,
      checkoutDisciplineApplicable: isPastDate,
      averageBreak: averageBreak,
      averageWork: averageWork,
      averageCheckInLabel: averageCheckInLabel,
      averageCheckOutLabel: averageCheckOutLabel,
      healthScore: healthScore,
      employeeIds: Set<String>.unmodifiable(employeeIds),
      activeLocationIds: Set<String>.unmodifiable(activeLocationIds),
      onlineLocationIds: Set<String>.unmodifiable(onlineLocationIds),
      gpsExceptionIds: Set<String>.unmodifiable(gpsExceptionIds),
      missedCheckoutIds: Set<String>.unmodifiable(missedCheckoutIds),
      duplicateCheckInIds: Set<String>.unmodifiable(duplicateCheckInIds),
      insights: List<_InsightItem>.unmodifiable(insights),
      exceptions: List<_ExceptionItem>.unmodifiable(exceptions),
      activity: List<_ActivityItem>.unmodifiable(activity),
    );
  }

  String get healthLabel {
    if (healthScore >= 90) return 'Excellent';
    if (healthScore >= 75) return 'Good';
    if (healthScore >= 55) return 'Average';
    return 'Critical';
  }

  Color get healthColor {
    if (healthScore >= 90) return AppColors.success;
    if (healthScore >= 75) return AppColors.info;
    if (healthScore >= 55) return AppColors.warning;
    return AppColors.error;
  }

  String get checkoutComplianceLabel => checkoutDisciplineApplicable
      ? _formatPercent(checkoutCompliance)
      : 'N/A';

  String get healthFormulaDescription {
    if (checkoutDisciplineApplicable) {
      return 'Score uses available dimensions: attendance 60%, GPS 25%, and checkout discipline 15%.';
    }
    return 'Current-day score uses available dimensions: attendance 70% and GPS compliance 30%; checkout is not yet due.';
  }

  String get generatedSummary {
    if (totalEmployees == 0) {
      return 'No employee profiles are available for the selected operations view.';
    }
    final parts = <String>[
      'Attendance is ${_formatPercent(attendanceRate)} with $present of $totalEmployees employees present.',
    ];
    if (averageCheckInLabel != 'N/A') {
      parts.add('Average check-in is $averageCheckInLabel.');
    }
    parts.add('GPS compliance is ${_formatPercent(gpsCompliance)}.');
    if (onDuty > 0) parts.add('$onDuty employees remain actively on duty.');
    if (inVisit > 0) parts.add('$inVisit employees are in customer visits.');
    if (exceptions.isNotEmpty) {
      parts.add('${exceptions.length} supported exceptions need review.');
    }
    parts.add('Overall workforce health is $healthLabel.');
    return parts.join(' ');
  }
}

Map<int, Set<String>> _uniqueAttendanceByDay(
  List<AttendanceModel> records,
  Set<String> employeeIds,
) {
  final byDay = <int, Set<String>>{};
  for (final record in records) {
    final date = record.date;
    if (date == null || !employeeIds.contains(record.userId)) continue;
    byDay.putIfAbsent(date.day, () => <String>{}).add(record.userId);
  }
  return byDay;
}

Color _rateColor(double rate) {
  if (rate >= 0.8) return AppColors.success;
  if (rate >= 0.5) return AppColors.warning;
  if (rate > 0) return AppColors.error;
  return AppColors.textDisabled;
}

String _filterLabel(AttendanceOperationsFilter filter) {
  switch (filter) {
    case AttendanceOperationsFilter.all:
      return 'All Employees';
    case AttendanceOperationsFilter.present:
      return 'Present';
    case AttendanceOperationsFilter.absent:
      return 'Absent';
    case AttendanceOperationsFilter.onDuty:
      return 'On Duty';
    case AttendanceOperationsFilter.offDuty:
      return 'Off Duty';
    case AttendanceOperationsFilter.onBreak:
      return 'On Break';
    case AttendanceOperationsFilter.inVisit:
      return 'In Visit';
    case AttendanceOperationsFilter.gpsException:
      return 'GPS Exception';
    case AttendanceOperationsFilter.syncPending:
      return 'Sync Pending';
    case AttendanceOperationsFilter.missedCheckout:
      return 'Missed Checkout';
    case AttendanceOperationsFilter.multipleCheckIn:
      return 'Multiple Check-in';
    case AttendanceOperationsFilter.offline:
      return 'Offline';
    case AttendanceOperationsFilter.available:
      return 'Available';
  }
}

String _sortLabel(_EmployeeSort sort) {
  switch (sort) {
    case _EmployeeSort.name:
      return 'Sort: Name';
    case _EmployeeSort.status:
      return 'Sort: Status';
    case _EmployeeSort.workingHours:
      return 'Sort: Working Hours';
    case _EmployeeSort.visits:
      return 'Sort: Visits';
  }
}

String _employeeStatus(ManagerEmployeeSummaryModel summary) {
  final attendance = summary.todayAttendance;
  if (summary.activeVisits > 0) return 'In Visit';
  if (attendance?.isOnBreak == true) return 'On Break';
  if (attendance?.checkInTime == null) return 'Absent';
  if (attendance?.isCheckedOut == true) return 'Off Duty';
  return 'On Duty';
}

Color _statusColor(String status) {
  switch (status) {
    case 'On Duty':
      return AppColors.info;
    case 'On Break':
      return AppColors.warning;
    case 'In Visit':
      return AppColors.success;
    case 'Off Duty':
      return AppColors.textSecondary;
    default:
      return AppColors.error;
  }
}

String _employeeName(ManagerEmployeeSummaryModel summary) {
  final name = summary.employee.name.trim();
  if (name.isNotEmpty) return name;
  final email = summary.employee.email.trim();
  if (email.isNotEmpty) return email;
  return _shortId(summary.employee.uid);
}

String _shortId(String id) {
  final trimmed = id.trim();
  if (trimmed.isEmpty) return 'Unknown ID';
  if (trimmed.length <= 10) return trimmed;
  return '${trimmed.substring(0, 8)}...';
}

String _formatLongDate(DateTime date) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
}

String _formatShortDate(DateTime? date) {
  if (date == null) return 'Unknown date';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _formatClock(DateTime? time) {
  if (time == null) return 'N/A';
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

String _averageTimeLabel(List<DateTime> values) {
  if (values.isEmpty) return 'N/A';
  final averageMinutes = values.fold<int>(
        0,
        (sum, value) => sum + value.hour * 60 + value.minute,
      ) ~/
      values.length;
  final hour24 = averageMinutes ~/ 60;
  final minute = averageMinutes.remainder(60).toString().padLeft(2, '0');
  final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '$hour:$minute ${hour24 >= 12 ? 'PM' : 'AM'}';
}

String _formatDuration(Duration duration) {
  final safeMinutes = math.max(0, duration.inMinutes);
  final hours = safeMinutes ~/ 60;
  final minutes = safeMinutes.remainder(60).toString().padLeft(2, '0');
  return '${hours}h ${minutes}m';
}

String _formatPercent(double value) {
  final safe = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
  return '${(safe * 100).round()}%';
}

String _titleCase(String value) {
  final normalized = value.trim().replaceAll('_', ' ');
  if (normalized.isEmpty) return 'Unknown';
  return normalized
      .split(RegExp(r'\s+'))
      .map(
        (word) => word.isEmpty
            ? word
            : '${word.substring(0, 1).toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}
