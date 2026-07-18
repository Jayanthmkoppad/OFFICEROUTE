import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/employee_model.dart';
import '../../core/models/live_location_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/premium_widgets.dart';
import '../attendance/models/attendance_model.dart';
import 'models/customer_visit_model.dart';
import 'services/visit_planning_service.dart';
import 'technical_service_definitions.dart';

enum _OperationBucket { today, carryForward, attention, completed, all }

enum _VisitFocus {
  none,
  assigned,
  unassigned,
  travelling,
  checkedIn,
  repairRunning,
  waitingParts,
  pendingCheckout,
  completed,
  cancelled,
  warranty,
  highPriority,
  repeat,
  carryForward,
}

enum _VisitSort { updated, created, customer, status }

enum _VisitAction { open, assign, duplicate, map }

/// Admin-facing field operations workspace backed only by existing data.
class EnterpriseVisitsDashboard extends StatefulWidget {
  final List<CustomerVisitModel> visits;
  final List<EmployeeModel> employees;
  final List<AttendanceModel> attendance;
  final Map<String, LiveLocationModel> liveLocationsByUserId;
  final DateTime selectedDate;
  final bool realtimeConnected;
  final bool refreshing;
  final Future<void> Function() onRefresh;
  final Future<void> Function(DateTime date) onDateChanged;
  final VoidCallback onCreateVisit;
  final ValueChanged<CustomerVisitModel> onOpenVisit;
  final Future<void> Function(
    CustomerVisitModel visit,
    EmployeeModel engineer,
  )
  onAssignEngineer;
  final Future<void> Function(CustomerVisitModel visit) onDuplicateVisit;
  final VoidCallback onOpenMap;

  const EnterpriseVisitsDashboard({
    super.key,
    required this.visits,
    required this.employees,
    required this.attendance,
    required this.liveLocationsByUserId,
    required this.selectedDate,
    required this.realtimeConnected,
    required this.refreshing,
    required this.onRefresh,
    required this.onDateChanged,
    required this.onCreateVisit,
    required this.onOpenVisit,
    required this.onAssignEngineer,
    required this.onDuplicateVisit,
    required this.onOpenMap,
  });

  @override
  State<EnterpriseVisitsDashboard> createState() =>
      _EnterpriseVisitsDashboardState();
}

class _EnterpriseVisitsDashboardState extends State<EnterpriseVisitsDashboard> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _controllerSerialController =
      TextEditingController();
  final TextEditingController _motorSerialController = TextEditingController();
  Timer? _dayRolloverTimer;

  String _statusFilter = 'all';
  String _engineerFilter = 'all';
  String _dealerFilter = 'all';
  String _issueFilter = 'all';
  String _vehicleFilter = 'all';
  String _warrantyFilter = 'all';
  String _serviceCentreFilter = 'all';
  String _priorityFilter = 'all';
  _OperationBucket _operationBucket = _OperationBucket.today;
  _VisitFocus _visitFocus = _VisitFocus.none;
  _VisitSort _visitSort = _VisitSort.updated;
  int _visitPage = 0;
  bool _engineerWorkloadExpanded = false;
  bool _analyticsExpanded = true;
  bool _secondaryAnalyticsExpanded = false;
  bool _technicalAnalyticsExpanded = false;
  bool _technicalAlertsExpanded = true;
  bool _capabilitiesExpanded = false;
  bool _reportsExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onFilterTextChanged);
    _controllerSerialController.addListener(_onFilterTextChanged);
    _motorSerialController.addListener(_onFilterTextChanged);
    _scheduleDayRollover();
  }

  @override
  void didUpdateWidget(covariant EnterpriseVisitsDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final userIds = widget.employees.map((employee) => employee.uid).toSet();
    final dealers = widget.visits.map(_dealerLabelForVisit).toSet();
    final issues = widget.visits.expand(_visitIssueCategories).toSet();
    final vehicles = widget.visits.map((visit) => visit.vehicleDetails).toSet();
    final warranties = widget.visits
        .map((visit) => visit.warrantyStatus)
        .toSet();
    final serviceCentres = widget.visits
        .map((visit) => visit.serviceCentreName)
        .toSet();
    final priorities = widget.visits.map((visit) => visit.priority).toSet();

    if (_engineerFilter != 'all' && !userIds.contains(_engineerFilter)) {
      _engineerFilter = 'all';
    }
    if (_dealerFilter != 'all' && !dealers.contains(_dealerFilter)) {
      _dealerFilter = 'all';
    }
    if (_issueFilter != 'all' && !issues.contains(_issueFilter)) {
      _issueFilter = 'all';
    }
    if (_vehicleFilter != 'all' && !vehicles.contains(_vehicleFilter)) {
      _vehicleFilter = 'all';
    }
    if (_warrantyFilter != 'all' && !warranties.contains(_warrantyFilter)) {
      _warrantyFilter = 'all';
    }
    if (_serviceCentreFilter != 'all' &&
        !serviceCentres.contains(_serviceCentreFilter)) {
      _serviceCentreFilter = 'all';
    }
    if (_priorityFilter != 'all' &&
        !priorities.contains(_priorityFilter)) {
      _priorityFilter = 'all';
    }
  }

  @override
  void dispose() {
    _dayRolloverTimer?.cancel();
    _searchController
      ..removeListener(_onFilterTextChanged)
      ..dispose();
    _controllerSerialController
      ..removeListener(_onFilterTextChanged)
      ..dispose();
    _motorSerialController
      ..removeListener(_onFilterTextChanged)
      ..dispose();
    super.dispose();
  }

  void _scheduleDayRollover() {
    _dayRolloverTimer?.cancel();
    final now = DateTime.now();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _dayRolloverTimer = Timer(nextDay.difference(now), () {
      if (!mounted) return;
      setState(() {
        _operationBucket = _OperationBucket.today;
        _visitFocus = _VisitFocus.none;
        _visitPage = 0;
      });
      unawaited(widget.onDateChanged(DateTime.now()));
      _scheduleDayRollover();
    });
  }

  void _onFilterTextChanged() {
    if (!mounted) return;
    setState(() {
      _visitPage = 0;
    });
  }

  Future<void> _pickOperationsDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: widget.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select operations date',
    );
    if (selected == null || !mounted) return;

    setState(() {
      _operationBucket = _OperationBucket.today;
      _visitFocus = _VisitFocus.none;
      _visitPage = 0;
    });
    await widget.onDateChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final employeesById = {
      for (final employee in widget.employees) employee.uid: employee,
    };
    final metrics = _VisitOperationsMetrics.calculate(
      visits: widget.visits,
      employees: widget.employees,
      attendance: widget.attendance,
      liveLocationsByUserId: widget.liveLocationsByUserId,
      selectedDate: widget.selectedDate,
      now: now,
    );
    final filteredVisits = _filteredVisits(widget.visits);
    final operationVisits = _visitsForBucket(
      filteredVisits,
      widget.selectedDate,
    );

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 96),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildEnterpriseHeader(metrics),
                const SizedBox(height: 10),
                _buildKpiDashboard(metrics),
                const SizedBox(height: 10),
                _buildMorningAndEngineers(metrics),
                const SizedBox(height: 10),
                _buildFilters(employeesById),
                const SizedBox(height: 10),
                _buildLiveVisitBoard(metrics, employeesById, now),
                const SizedBox(height: 10),
                _buildEngineerWorkload(metrics),
                const SizedBox(height: 10),
                _buildDailyOperations(
                  metrics,
                  operationVisits,
                  employeesById,
                  now,
                ),
                const SizedBox(height: 10),
                _buildSmartDispatch(metrics),
                const SizedBox(height: 10),
                _buildAnalytics(metrics, employeesById),
                const SizedBox(height: 10),
                _buildTechnicalAnalytics(metrics, employeesById),
                const SizedBox(height: 10),
                _buildTechnicalAlerts(metrics),
                const SizedBox(height: 10),
                _buildCapabilities(),
                const SizedBox(height: 10),
                _buildReports(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnterpriseHeader(_VisitOperationsMetrics metrics) {
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;
          final title = Row(
            children: [
              const PremiumIconChip(icon: Icons.hub_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enterprise Visits Operations Center',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headingMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatLongDate(widget.selectedDate)} | ${metrics.todayVisits.length} operational visits',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
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
              OutlinedButton.icon(
                onPressed: _pickOperationsDate,
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text(_formatCompactDate(widget.selectedDate)),
              ),
              Tooltip(
                message: 'Refresh visit operations',
                child: IconButton.filledTonal(
                  onPressed: widget.refreshing ? null : widget.onRefresh,
                  icon: widget.refreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 20),
                ),
              ),
              OutlinedButton.icon(
                onPressed: widget.onOpenMap,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Map'),
              ),
              ElevatedButton.icon(
                onPressed: widget.onCreateVisit,
                icon: const Icon(Icons.alt_route_outlined, size: 18),
                label: const Text('Visit Planner'),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [title, const SizedBox(height: 10), actions],
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
    );
  }

  Widget _buildKpiDashboard(_VisitOperationsMetrics metrics) {
    final kpis = <_VisitKpi>[
      _VisitKpi(
        _sameDay(widget.selectedDate, DateTime.now())
            ? 'Today\'s Visits'
            : 'Selected Visits',
        '${metrics.todayVisits.length}',
        Icons.today_outlined,
        AppColors.info,
        selected:
            _operationBucket == _OperationBucket.today &&
            _visitFocus == _VisitFocus.none,
        onTap: () => _focusQueue(
          focus: _VisitFocus.none,
          bucket: _OperationBucket.today,
        ),
      ),
      _VisitKpi(
        'Assigned',
        '${metrics.assignedToday}',
        Icons.assignment_ind_outlined,
        AppColors.success,
        selected: _visitFocus == _VisitFocus.assigned,
        info: 'Visits linked to an existing engineer through userId.',
        onTap: () => _focusQueue(focus: _VisitFocus.assigned),
      ),
      _VisitKpi(
        'Unassigned',
        '${metrics.unassignedToday}',
        Icons.person_off_outlined,
        metrics.unassignedToday > 0 ? AppColors.error : AppColors.textSecondary,
        selected: _visitFocus == _VisitFocus.unassigned,
        info: 'Visits whose userId does not match an existing employee.',
        onTap: () => _focusQueue(focus: _VisitFocus.unassigned),
      ),
      _VisitKpi(
        'Travelling',
        '${metrics.travellingVisits}',
        Icons.route_outlined,
        AppColors.info,
        selected: _visitFocus == _VisitFocus.travelling,
        info:
            'Open visits linked to engineers with fresh location and speed above 5 km/h.',
        onTap: () => _focusQueue(focus: _VisitFocus.travelling),
      ),
      _VisitKpi(
        'Checked In',
        '${metrics.runningVisits.length}',
        Icons.location_on_outlined,
        AppColors.info,
        selected: _visitFocus == _VisitFocus.checkedIn,
        onTap: () => _focusQueue(focus: _VisitFocus.checkedIn),
      ),
      _VisitKpi(
        'Repair Running',
        '${metrics.technical.repairRunningCount}',
        Icons.build_circle_outlined,
        AppColors.info,
        selected: _visitFocus == _VisitFocus.repairRunning,
        info: 'Checked-in visits with a recorded Work Started event.',
        onTap: () => _focusQueue(focus: _VisitFocus.repairRunning),
      ),
      _VisitKpi(
        'Waiting Parts',
        '${metrics.technical.waitingPartsCount}',
        Icons.inventory_2_outlined,
        AppColors.warning,
        selected: _visitFocus == _VisitFocus.waitingParts,
        onTap: () => _focusQueue(focus: _VisitFocus.waitingParts),
      ),
      _VisitKpi(
        'Completed',
        '${metrics.completedToday.length}',
        Icons.task_alt_outlined,
        AppColors.success,
        selected: _visitFocus == _VisitFocus.completed,
        onTap: () => _focusQueue(focus: _VisitFocus.completed),
      ),
      _VisitKpi(
        'Pending Checkout',
        '${metrics.pendingCheckout.length}',
        Icons.logout_outlined,
        AppColors.warning,
        selected: _visitFocus == _VisitFocus.pendingCheckout,
        onTap: () => _focusQueue(focus: _VisitFocus.pendingCheckout),
      ),
      _VisitKpi(
        'Cancelled',
        '${metrics.cancelledToday.length}',
        Icons.cancel_outlined,
        AppColors.error,
        selected: _visitFocus == _VisitFocus.cancelled,
        onTap: () => _focusQueue(focus: _VisitFocus.cancelled),
      ),
      _VisitKpi(
        'Warranty Visits',
        '${metrics.warrantyToday}',
        Icons.verified_user_outlined,
        AppColors.success,
        selected: _visitFocus == _VisitFocus.warranty,
        onTap: () => _focusQueue(focus: _VisitFocus.warranty),
      ),
      _VisitKpi.unavailable(
        'Paid Visits',
        Icons.payments_outlined,
        'CustomerVisitModel has no payment status.',
        onTap: () => _showUnavailable(
          'Paid-visit filtering is unavailable because visits do not store payment status.',
        ),
      ),
      _VisitKpi(
        'High Priority',
        '${metrics.todayVisits.where(_isHighPriorityVisit).length}',
        Icons.priority_high,
        AppColors.error,
        selected: _visitFocus == _VisitFocus.highPriority,
        onTap: () => _focusQueue(focus: _VisitFocus.highPriority),
      ),
      _VisitKpi(
        'Repeat Failures',
        '${metrics.repeatComplaintCount}',
        Icons.replay_outlined,
        AppColors.warning,
        selected: _visitFocus == _VisitFocus.repeat,
        info: 'Repeated customer and issue-category combinations.',
        onTap: () => _focusQueue(focus: _VisitFocus.repeat),
      ),
      _VisitKpi(
        'Carry Forward',
        '${metrics.carryForward.length}',
        Icons.history_toggle_off_outlined,
        AppColors.error,
        selected: _visitFocus == _VisitFocus.carryForward,
        onTap: () => _focusQueue(focus: _VisitFocus.carryForward),
      ),
      _VisitKpi(
        'Avg Completion',
        _formatDuration(metrics.averageVisitDuration),
        Icons.timer_outlined,
        AppColors.info,
        info: 'Average checked-in service duration for completed visits.',
        onTap: () => _focusQueue(focus: _VisitFocus.completed),
      ),
      _VisitKpi.unavailable(
        'Avg Travel',
        Icons.directions_car_outlined,
        'No travel start, route, or ETA timestamps exist.',
        onTap: () => _showUnavailable(
          'Average travel time needs route or travel-session timestamps.',
        ),
      ),
      _VisitKpi(
        'Avg Resolution',
        _formatDuration(metrics.averageResolutionDuration),
        Icons.av_timer_outlined,
        AppColors.info,
        info: 'Average time from visit creation to completion.',
        onTap: () => _focusQueue(focus: _VisitFocus.completed),
      ),
      _VisitKpi(
        'Engineer Utilization',
        '${metrics.engineerUtilization.toStringAsFixed(0)}%',
        Icons.engineering_outlined,
        AppColors.success,
        info: 'Employees with active attendance divided by employee profiles.',
        onTap: () => _showUnavailable(
          'Engineer utilization is an attendance summary; it has no visit-only queue.',
        ),
      ),
      _VisitKpi.unavailable(
        'Customer Satisfaction',
        Icons.sentiment_satisfied_alt_outlined,
        'No customer rating field exists.',
        onTap: () => _showUnavailable(
          'Customer satisfaction needs an approved rating field.',
        ),
      ),
    ];

    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            icon: Icons.dashboard_outlined,
            title: 'Executive Visit KPIs',
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1180
                  ? 7
                  : constraints.maxWidth >= 900
                  ? 6
                  : constraints.maxWidth >= 620
                  ? 4
                  : 3;
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
                        height: 84,
                        child: _VisitKpiCard(kpi: kpi),
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

  Widget _buildMorningAndEngineers(_VisitOperationsMetrics metrics) {
    final insights = metrics.insights;
    final engineerRows = metrics.engineerOperations.take(6).toList();
    final planned = metrics.pendingVisits.length;
    final available = metrics.engineerOperations
        .where((engineer) => engineer.status == 'Available')
        .length;
    final noAttendance = metrics.engineerOperations
        .where((engineer) => engineer.attendanceLabel == 'Absent / no record')
        .length;

    final morning = PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            icon: Icons.wb_sunny_outlined,
            title: 'Smart Morning Operations',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MorningMetric(label: 'Planned', value: '$planned'),
              _MorningMetric(label: 'Available', value: '$available'),
              _MorningMetric(label: 'No Attendance', value: '$noAttendance'),
              _MorningMetric(
                label: 'At Risk',
                value: '${metrics.needsAttention.length}',
              ),
              _MorningMetric(
                label: 'Carry Forward',
                value: '${metrics.carryForward.length}',
              ),
              const _MorningMetric(
                label: 'Branch Ready',
                value: '--',
                tooltip: 'No branch field exists on customer visits.',
              ),
              _MorningMetric(
                label: 'Planned Duration',
                value: _formatDuration(_expectedWorkDuration(metrics.todayVisits)),
                tooltip: 'Sum of recorded expected visit durations.',
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (insights.isEmpty)
            const _InlineVisitState(
              icon: Icons.check_circle_outline,
              title: 'Operations are clear',
              message:
                  'No supported carry-forward or visit exception is active.',
            )
          else
            ...insights
                .take(6)
                .map(
                  (insight) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _OperationInsightRow(insight: insight),
                  ),
                ),
        ],
      ),
    );

    final workforce = PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumSectionHeader(
            icon: Icons.engineering_outlined,
            title: 'Engineer Operations (${metrics.engineerOperations.length})',
          ),
          const SizedBox(height: 10),
          if (engineerRows.isEmpty)
            const _InlineVisitState(
              icon: Icons.person_off_outlined,
              title: 'No engineer data',
              message:
                  'No employee profiles are available in the users collection.',
            )
          else
            ...engineerRows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _EngineerOperationRow(data: row),
              ),
            ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [morning, const SizedBox(height: 10), workforce],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: morning),
            const SizedBox(width: 10),
            Expanded(child: workforce),
          ],
        );
      },
    );
  }

  Widget _buildFilters(Map<String, EmployeeModel> employeesById) {
    final engineers = widget.employees.toList()
      ..sort((a, b) => _employeeName(a).compareTo(_employeeName(b)));
    final dealers = _uniqueNonEmpty(widget.visits.map(_dealerLabelForVisit));
    final issues = _uniqueNonEmpty(widget.visits.expand(_visitIssueCategories));
    final vehicles = _uniqueNonEmpty(
      widget.visits.map((visit) => visit.vehicleDetails),
    );
    final warranties = _uniqueNonEmpty(
      widget.visits.map((visit) => visit.warrantyStatus),
    );
    final serviceCentres = _uniqueNonEmpty(
      widget.visits.map((visit) => visit.serviceCentreName),
    );
    final priorities = _uniqueNonEmpty(
      widget.visits.map((visit) => visit.priority),
    );

    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumSectionHeader(
            icon: Icons.tune_outlined,
            title: 'Search and Filters',
            actionLabel: _hasActiveFilters ? 'Clear' : null,
            onAction: _hasActiveFilters ? _clearFilters : null,
          ),
          const SizedBox(height: 10),
          _FilterGrid(
            children: [
              _CompactTextFilter(
                controller: _searchController,
                label: 'Search visits',
                icon: Icons.search,
              ),
              const _UnavailableFilter(
                label: 'Branch',
                reason: 'CustomerVisitModel has no branchId field.',
              ),
              const _UnavailableFilter(
                label: 'Region',
                reason: 'CustomerVisitModel has no region field.',
              ),
              _CompactDropdownFilter(
                label: 'Service Centre',
                icon: Icons.business_outlined,
                value: _serviceCentreFilter,
                options: ['all', ...serviceCentres],
                labelFor: (value) =>
                    value == 'all' ? 'All Centres' : value,
                onChanged: (value) =>
                    _setFilter(() => _serviceCentreFilter = value),
              ),
              _CompactDropdownFilter(
                label: 'Status',
                icon: Icons.flag_outlined,
                value: _statusFilter,
                options: const [
                  'all',
                  'planned',
                  'checked_in',
                  'checked_out',
                  'completed',
                  'cancelled',
                ],
                labelFor: _statusLabel,
                onChanged: (value) => _setFilter(() => _statusFilter = value),
              ),
              _CompactDropdownFilter(
                label: 'Engineer',
                icon: Icons.engineering_outlined,
                value: _engineerFilter,
                options: ['all', ...engineers.map((employee) => employee.uid)],
                labelFor: (value) => value == 'all'
                    ? 'All Engineers'
                    : _employeeName(employeesById[value]),
                onChanged: (value) => _setFilter(() => _engineerFilter = value),
              ),
              _CompactDropdownFilter(
                label: 'Dealer / Customer',
                icon: Icons.storefront_outlined,
                value: _dealerFilter,
                options: ['all', ...dealers],
                labelFor: (value) =>
                    value == 'all' ? 'All Dealers' : value,
                onChanged: (value) => _setFilter(() => _dealerFilter = value),
              ),
              _CompactDropdownFilter(
                label: 'Warranty',
                icon: Icons.verified_user_outlined,
                value: _warrantyFilter,
                options: ['all', ...warranties],
                labelFor: (value) =>
                    value == 'all' ? 'All Warranty' : value,
                onChanged: (value) =>
                    _setFilter(() => _warrantyFilter = value),
              ),
              _CompactDropdownFilter(
                label: 'Priority',
                icon: Icons.priority_high,
                value: _priorityFilter,
                options: ['all', ...priorities],
                labelFor: (value) =>
                    value == 'all' ? 'All Priorities' : value,
                onChanged: (value) =>
                    _setFilter(() => _priorityFilter = value),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Material(
            color: Colors.transparent,
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              leading: const Icon(Icons.filter_alt_outlined, size: 20),
              title: Text(
                'Additional filters',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Complaint, vehicle, and serial lookup',
                style: AppTextStyles.caption,
              ),
              children: [
                _FilterGrid(
                  children: [
                    _CompactDropdownFilter(
                      label: 'Complaint',
                      icon: Icons.report_problem_outlined,
                      value: _issueFilter,
                      options: ['all', ...issues],
                      labelFor: (value) =>
                          value == 'all' ? 'All Issues' : value,
                      onChanged: (value) =>
                          _setFilter(() => _issueFilter = value),
                    ),
                    _CompactDropdownFilter(
                      label: 'Vehicle',
                      icon: Icons.local_shipping_outlined,
                      value: _vehicleFilter,
                      options: ['all', ...vehicles],
                      labelFor: (value) =>
                          value == 'all' ? 'All Vehicles' : value,
                      onChanged: (value) =>
                          _setFilter(() => _vehicleFilter = value),
                    ),
                    _CompactTextFilter(
                      controller: _controllerSerialController,
                      label: 'Controller serial',
                      icon: Icons.memory_outlined,
                    ),
                    _CompactTextFilter(
                      controller: _motorSerialController,
                      label: 'Motor serial',
                      icon: Icons.settings_input_component_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveVisitBoard(
    _VisitOperationsMetrics metrics,
    Map<String, EmployeeModel> employeesById,
    DateTime now,
  ) {
    final travellingEngineerIds = metrics.engineerOperations
        .where((engineer) => engineer.status == 'Travelling')
        .map((engineer) => engineer.employee.uid)
        .toSet();
    final assigned = metrics.todayVisits
        .where(
          (visit) =>
              employeesById.containsKey(visit.userId) &&
              visit.status.toLowerCase() == 'planned',
        )
        .toList(growable: false);
    final travelling = widget.visits
        .where(
          (visit) =>
              !_isVisitClosed(visit) &&
              travellingEngineerIds.contains(visit.userId),
        )
        .toList(growable: false);
    final repairRunning = widget.visits
        .where(_isRepairRunningVisit)
        .toList(growable: false);
    final waitingCustomer = widget.visits
        .where(
          (visit) =>
              visit.resolutionStatus.toLowerCase() == 'waiting_customer',
        )
        .toList(growable: false);
    final waitingParts = widget.visits
        .where(
          (visit) => visit.resolutionStatus.toLowerCase() == 'waiting_parts',
        )
        .toList(growable: false);
    final columns = <_VisitBoardData>[
      _VisitBoardData(
        title: 'Assigned',
        icon: Icons.assignment_ind_outlined,
        color: AppColors.textSecondary,
        visits: assigned,
      ),
      _VisitBoardData(
        title: 'Travelling',
        icon: Icons.route_outlined,
        color: AppColors.info,
        visits: travelling,
      ),
      _VisitBoardData(
        title: 'Checked In',
        icon: Icons.location_on_outlined,
        color: AppColors.info,
        visits: metrics.runningVisits,
      ),
      _VisitBoardData(
        title: 'Repair Running',
        icon: Icons.build_circle_outlined,
        color: AppColors.info,
        visits: repairRunning,
      ),
      _VisitBoardData(
        title: 'Waiting Customer',
        icon: Icons.person_search_outlined,
        color: AppColors.warning,
        visits: waitingCustomer,
      ),
      _VisitBoardData(
        title: 'Waiting Parts',
        icon: Icons.inventory_2_outlined,
        color: AppColors.warning,
        visits: waitingParts,
      ),
      const _VisitBoardData.unavailable(
        title: 'Invoice Pending',
        icon: Icons.receipt_long_outlined,
        reason: 'No invoice status',
      ),
      const _VisitBoardData.unavailable(
        title: 'Payment Pending',
        icon: Icons.payments_outlined,
        reason: 'No payment status',
      ),
      _VisitBoardData(
        title: 'Completed',
        icon: Icons.task_alt_outlined,
        color: AppColors.success,
        visits: metrics.completedToday,
      ),
      _VisitBoardData(
        title: 'Carry Forward',
        icon: Icons.history_toggle_off_outlined,
        color: AppColors.error,
        visits: metrics.carryForward,
      ),
    ];

    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumSectionHeader(
            icon: Icons.sensors_outlined,
            title: 'Live Visit Board',
            actionLabel: 'Refresh',
            onAction: widget.refreshing ? null : widget.onRefresh,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 292,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: columns.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final column = columns[index];
                return SizedBox(
                  width: 250,
                  child: _VisitBoardColumn(
                    data: column,
                    employeesById: employeesById,
                    liveLocationsByUserId: widget.liveLocationsByUserId,
                    now: now,
                    onOpenVisit: widget.onOpenVisit,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngineerWorkload(_VisitOperationsMetrics metrics) {
    final engineers = _engineerWorkloadExpanded
        ? metrics.engineerOperations
        : metrics.engineerOperations.take(6).toList(growable: false);
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumSectionHeader(
            icon: Icons.groups_2_outlined,
            title: 'Engineer Workload (${metrics.engineerOperations.length})',
            actionLabel: metrics.engineerOperations.length > 6
                ? (_engineerWorkloadExpanded ? 'Show 6' : 'View All')
                : null,
            onAction: metrics.engineerOperations.length > 6
                ? () {
                    setState(() {
                      _engineerWorkloadExpanded = !_engineerWorkloadExpanded;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 10),
          if (engineers.isEmpty)
            const _InlineVisitState(
              icon: Icons.person_off_outlined,
              title: 'No engineer workload available',
              message:
                  'Employee profiles from the users collection appear here.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1040
                    ? 3
                    : constraints.maxWidth >= 680
                    ? 2
                    : 1;
                const gap = 8.0;
                final width =
                    (constraints.maxWidth - ((columns - 1) * gap)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: engineers
                      .map(
                        (engineer) => SizedBox(
                          width: width,
                          child: _EngineerWorkloadCard(data: engineer),
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

  Widget _buildDailyOperations(
    _VisitOperationsMetrics metrics,
    List<CustomerVisitModel> visits,
    Map<String, EmployeeModel> employeesById,
    DateTime now,
  ) {
    const pageSize = 10;
    final pageCount = visits.isEmpty ? 1 : (visits.length + pageSize - 1) ~/ pageSize;
    final page = _visitPage >= pageCount ? pageCount - 1 : _visitPage;
    final visible = visits
        .skip(page * pageSize)
        .take(pageSize)
        .toList(growable: false);
    final sortControl = SizedBox(
      width: 170,
      child: DropdownButtonFormField<_VisitSort>(
        initialValue: _visitSort,
        isDense: true,
        decoration: const InputDecoration(
          labelText: 'Sort',
          prefixIcon: Icon(Icons.sort, size: 18),
          isDense: true,
        ),
        items: _VisitSort.values
            .map(
              (sort) => DropdownMenuItem<_VisitSort>(
                value: sort,
                child: Text(_visitSortLabel(sort)),
              ),
            )
            .toList(growable: false),
        onChanged: (sort) {
          if (sort == null) return;
          setState(() {
            _visitSort = sort;
            _visitPage = 0;
          });
        },
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final heading = PremiumSectionHeader(
              icon: Icons.table_rows_outlined,
              title: 'Enterprise Visit List (${visits.length})',
            );
            if (constraints.maxWidth < 520) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading,
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: sortControl),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: heading),
                const SizedBox(width: 8),
                sortControl,
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _OperationBucket.values
                .map((bucket) {
                  final count = _bucketCount(metrics, bucket);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: _operationBucket == bucket,
                      label: Text('${_bucketLabel(bucket)} $count'),
                      onSelected: (_) {
                        setState(() {
                          _operationBucket = bucket;
                          _visitFocus = _VisitFocus.none;
                          _visitPage = 0;
                        });
                      },
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 8),
        if (visits.isEmpty)
          PremiumCard(
            padding: const EdgeInsets.all(14),
            child: _InlineVisitState(
              icon: _hasActiveFilters
                  ? Icons.search_off_outlined
                  : Icons.event_available_outlined,
              title: _hasActiveFilters
                  ? 'No visits match these filters'
                  : 'No visits in ${_bucketLabel(_operationBucket).toLowerCase()}',
              message: _hasActiveFilters
                  ? 'Clear one or more filters to restore the operations board.'
                  : 'This queue will update automatically when visit data changes.',
              actionLabel: _hasActiveFilters ? 'Clear Filters' : 'Visit Planner',
              onAction: _hasActiveFilters
                  ? _clearFilters
                  : widget.onCreateVisit,
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 900) {
                return _EnterpriseVisitsTable(
                  visits: visible,
                  employeesById: employeesById,
                  onOpenVisit: widget.onOpenVisit,
                  onAssignEngineer: (visit) =>
                      unawaited(_chooseEngineer(visit)),
                  onDuplicateVisit: widget.onDuplicateVisit,
                  onOpenMap: widget.onOpenMap,
                );
              }
              final columns = constraints.maxWidth >= 1060
                  ? 3
                  : constraints.maxWidth >= 680
                  ? 2
                  : 1;
              const gap = 10.0;
              final width =
                  (constraints.maxWidth - ((columns - 1) * gap)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: visible
                    .map(
                      (visit) => SizedBox(
                        width: width,
                        child: _EnterpriseVisitCard(
                          visit: visit,
                          employee: employeesById[visit.userId],
                          now: now,
                          onTap: () => widget.onOpenVisit(visit),
                          onAssign: () => unawaited(_chooseEngineer(visit)),
                          onDuplicate: () =>
                              unawaited(widget.onDuplicateVisit(visit)),
                          onOpenMap: widget.onOpenMap,
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        if (visits.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Page ${page + 1} of $pageCount',
                style: AppTextStyles.caption,
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Previous page',
                onPressed: page > 0
                    ? () => setState(() {
                        _visitPage = page - 1;
                      })
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Next page',
                onPressed: page + 1 < pageCount
                    ? () => setState(() {
                        _visitPage = page + 1;
                      })
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSmartDispatch(_VisitOperationsMetrics metrics) {
    final available = metrics.engineerOperations
        .where((engineer) => engineer.status == 'Available')
        .length;
    final dispatch = metrics.dispatch;
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumSectionHeader(
            icon: Icons.alt_route_outlined,
            title: 'Smart Dispatch Engine',
            actionLabel: 'Open Planner',
            onAction: widget.onCreateVisit,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _MorningMetric(
                label: 'Pending Dispatch',
                value: '${dispatch.pendingDispatches}',
              ),
              _MorningMetric(
                label: 'Service Centres',
                value: '${dispatch.centreUsage.length}',
              ),
              _MorningMetric(
                label: 'Avg Road Distance',
                value: _optionalDistance(dispatch.averageRoadDistanceKm),
              ),
              _MorningMetric(
                label: 'Average ETA',
                value: dispatch.averageEta == null
                    ? '--'
                    : _formatDuration(dispatch.averageEta!),
              ),
              _MorningMetric(
                label: 'Longest Travel',
                value: _optionalDistance(dispatch.longestRoadDistanceKm),
              ),
              _MorningMetric(
                label: 'Shortest Travel',
                value: _optionalDistance(dispatch.shortestRoadDistanceKm),
              ),
              _MorningMetric(
                label: 'Engineer Utilization',
                value: '${metrics.engineerUtilization.toStringAsFixed(0)}%',
              ),
              _MorningMetric(
                label: 'Travel Efficiency',
                value: dispatch.travelEfficiencyPercent == null
                    ? '--'
                    : '${dispatch.travelEfficiencyPercent!.toStringAsFixed(0)}%',
              ),
              _MorningMetric(
                label: 'Assignment Delay',
                value: dispatch.averageAssignmentDelay == null
                    ? '--'
                    : _formatDuration(dispatch.averageAssignmentDelay!),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final centreUsage = _CompactBarPanel(
                title: 'Nearest Centre Usage / Visits',
                icon: Icons.business_outlined,
                values: dispatch.centreUsage,
                color: AppColors.info,
              );
              final status = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '$available engineers currently appear available from attendance and active-visit data.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    dispatch.routeSampleCount == 0
                        ? 'Requires Google Geocoding/Directions API for road distance, ETA, traffic, travel efficiency, and cost estimates. Direct proximity and engineer ranking remain operational when complaint GPS is present.'
                        : '${dispatch.routeSampleCount} visits contain persisted route metrics. Missing route values remain unavailable rather than estimated.',
                    style: AppTextStyles.caption.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  const Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _RequirementChip(label: 'Service-centre registry', available: true),
                      _RequirementChip(label: 'Engineer ranking', available: true),
                      _RequirementChip(label: 'Current GPS', available: true),
                      _RequirementChip(label: 'Workload', available: true),
                      _RequirementChip(label: 'Centre membership', available: false),
                      _RequirementChip(label: 'ETA / Traffic', available: false),
                    ],
                  ),
                ],
              );
              if (constraints.maxWidth < 760) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [status, const SizedBox(height: 12), centreUsage],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: status),
                  const SizedBox(width: 18),
                  Expanded(flex: 2, child: centreUsage),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnalytics(
    _VisitOperationsMetrics metrics,
    Map<String, EmployeeModel> employeesById,
  ) {
    final engineerDistribution = <String, int>{};
    for (final entry in metrics.completedByEngineer.entries) {
      engineerDistribution[_employeeName(employeesById[entry.key])] =
          entry.value;
    }

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
            'Visit Analytics',
            style: AppTextStyles.headingSmall.copyWith(
              fontSize: 18,
              letterSpacing: 0,
            ),
          ),
          subtitle: Text(
            'Status, issue frequency, and engineer output',
            style: AppTextStyles.caption,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            if (_analyticsExpanded) ...[
              const Divider(),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final panels = [
                    _CompactBarPanel(
                      title: 'Visit Status',
                      icon: Icons.donut_small_outlined,
                      values: metrics.statusDistribution,
                      color: AppColors.info,
                    ),
                    _CompactBarPanel(
                      title: 'Issue Frequency',
                      icon: Icons.troubleshoot_outlined,
                      values: metrics.issueDistribution,
                      color: AppColors.warning,
                    ),
                    _CompactBarPanel(
                      title: 'Engineer Output',
                      icon: Icons.engineering_outlined,
                      values: engineerDistribution,
                      color: AppColors.success,
                    ),
                  ];
                  if (constraints.maxWidth < 900) {
                    return Column(
                      children: [
                        for (var i = 0; i < panels.length; i++) ...[
                          panels[i],
                          if (i != panels.length - 1) const Divider(height: 20),
                        ],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: panels[0]),
                      const SizedBox(width: 18),
                      Expanded(child: panels[1]),
                      const SizedBox(width: 18),
                      Expanded(child: panels[2]),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: _secondaryAnalyticsExpanded,
                onExpansionChanged: (expanded) {
                  setState(() {
                    _secondaryAnalyticsExpanded = expanded;
                  });
                },
                leading: const Icon(Icons.insights_outlined, size: 20),
                title: Text(
                  'Secondary analytics',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Dealer activity, warranty work, and unavailable dimensions',
                  style: AppTextStyles.caption,
                ),
                children: [
                  if (_secondaryAnalyticsExpanded)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final dealer = _CompactBarPanel(
                          title: 'Dealer / Customer Activity',
                          icon: Icons.storefront_outlined,
                          values: metrics.dealerDistribution,
                          color: AppColors.info,
                        );
                        final warranty = _CompactBarPanel(
                          title: 'Warranty Distribution',
                          icon: Icons.verified_user_outlined,
                          values: metrics.warrantyDistribution,
                          color: AppColors.success,
                        );
                        if (constraints.maxWidth < 760) {
                          return Column(
                            children: [
                              dealer,
                              const Divider(height: 20),
                              warranty,
                              const SizedBox(height: 8),
                              const _UnavailableAnalyticsNote(),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: dealer),
                                const SizedBox(width: 18),
                                Expanded(child: warranty),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const _UnavailableAnalyticsNote(),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicalAnalytics(
    _VisitOperationsMetrics metrics,
    Map<String, EmployeeModel> employeesById,
  ) {
    final technical = metrics.technical;
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          initiallyExpanded: _technicalAnalyticsExpanded,
          onExpansionChanged: (expanded) {
            setState(() => _technicalAnalyticsExpanded = expanded);
          },
          leading: const PremiumIconChip(
            icon: Icons.precision_manufacturing_outlined,
          ),
          title: Text(
            'Technical Service Analytics',
            style: AppTextStyles.headingSmall.copyWith(
              fontSize: 18,
              letterSpacing: 0,
            ),
          ),
          subtitle: Text(
            '${technical.technicalRecordCount} technical records | ${technical.diagnosticRecordCount} with readings',
            style: AppTextStyles.caption,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            if (_technicalAnalyticsExpanded) ...[
              const Divider(),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _MorningMetric(
                    label: 'Technical Records',
                    value: '${technical.technicalRecordCount}',
                  ),
                  _MorningMetric(
                    label: 'Diagnostics',
                    value: '${technical.diagnosticRecordCount}',
                  ),
                  _MorningMetric(
                    label: 'Avg Repair',
                    value: technical.averageRepairDuration == null
                        ? '--'
                        : _formatDuration(technical.averageRepairDuration!),
                  ),
                  _MorningMetric(
                    label: 'Avg Diagnosis',
                    value: technical.averageDiagnosisDuration == null
                        ? '--'
                        : _formatDuration(technical.averageDiagnosisDuration!),
                  ),
                  _MorningMetric(
                    label: 'First-Time Fix',
                    value: technical.firstTimeFixRate == null
                        ? '--'
                        : '${technical.firstTimeFixRate!.toStringAsFixed(0)}%',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ResponsiveAnalyticsPanels(
                panels: [
                  _CompactBarPanel(
                    title: 'Fault Categories',
                    icon: Icons.category_outlined,
                    values: technical.faultCategories,
                    color: AppColors.warning,
                  ),
                  _CompactBarPanel(
                    title: 'Error Codes',
                    icon: Icons.error_outline,
                    values: technical.errorCodes,
                    color: AppColors.error,
                  ),
                  _CompactBarPanel(
                    title: 'Resolution Status',
                    icon: Icons.verified_outlined,
                    values: technical.resolutionStatuses,
                    color: AppColors.success,
                  ),
                ],
              ),
              const Divider(height: 20),
              _FirstTimeFixPanel(
                values: technical.firstTimeFixByEngineer,
                employeesById: employeesById,
              ),
              const SizedBox(height: 6),
              _TechnicalAnalyticsGroup(
                title: 'Component Fault Analysis',
                panels: [
                  _CompactBarPanel(
                    title: 'Motor Issues',
                    icon: Icons.settings_input_component_outlined,
                    values: technical.motorFaults,
                    color: AppColors.error,
                  ),
                  _CompactBarPanel(
                    title: 'Controller Issues',
                    icon: Icons.memory_outlined,
                    values: technical.controllerFaults,
                    color: AppColors.warning,
                  ),
                  _CompactBarPanel(
                    title: 'Battery Issues',
                    icon: Icons.battery_alert_outlined,
                    values: technical.batteryFaults,
                    color: AppColors.info,
                  ),
                ],
              ),
              _TechnicalAnalyticsGroup(
                title: 'Serviced Component Models',
                panels: [
                  _CompactBarPanel(
                    title: 'Motor Models',
                    icon: Icons.settings_outlined,
                    values: technical.motorModels,
                    color: AppColors.info,
                  ),
                  _CompactBarPanel(
                    title: 'Controller Models',
                    icon: Icons.developer_board_outlined,
                    values: technical.controllerModels,
                    color: AppColors.info,
                  ),
                  _CompactBarPanel(
                    title: 'Battery Models',
                    icon: Icons.battery_std_outlined,
                    values: technical.batteryModels,
                    color: AppColors.info,
                  ),
                ],
              ),
              _TechnicalAnalyticsGroup(
                title: 'Root Cause and Prevention',
                panels: [
                  _CompactBarPanel(
                    title: 'Root Causes',
                    icon: Icons.manage_search_outlined,
                    values: technical.rootCauses,
                    color: AppColors.error,
                  ),
                  _CompactBarPanel(
                    title: 'Preventive Actions',
                    icon: Icons.health_and_safety_outlined,
                    values: technical.preventiveActions,
                    color: AppColors.success,
                  ),
                  _CompactBarPanel(
                    title: 'Pending Issues',
                    icon: Icons.pending_actions_outlined,
                    values: technical.pendingIssues,
                    color: AppColors.warning,
                  ),
                  _CompactBarPanel(
                    title: 'Monthly Repairs',
                    icon: Icons.calendar_month_outlined,
                    values: technical.monthlyRepairs,
                    color: AppColors.info,
                  ),
                ],
              ),
              _TechnicalAnalyticsGroup(
                title: 'Failure Concentration',
                panels: [
                  _CompactBarPanel(
                    title: 'Vehicle Types',
                    icon: Icons.local_shipping_outlined,
                    values: technical.vehicleTypeFailures,
                    color: AppColors.warning,
                  ),
                  _CompactBarPanel(
                    title: 'Dealers',
                    icon: Icons.storefront_outlined,
                    values: technical.dealerFailures,
                    color: AppColors.warning,
                  ),
                  _CompactBarPanel(
                    title: 'Repeat Failure Trend',
                    icon: Icons.replay_outlined,
                    values: technical.repeatFailureTrend,
                    color: AppColors.error,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const _InlineVisitState(
                icon: Icons.lock_outline,
                title: 'Unavailable technical dimensions',
                message:
                    'Diagnosis duration, paid-repair trend, branch repairs, warranty expiry, customer rating, and travel excess require timestamps or fields not present in the approved backend.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicalAlerts(_VisitOperationsMetrics metrics) {
    final alerts = metrics.technical.alerts;
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          initiallyExpanded: _technicalAlertsExpanded,
          onExpansionChanged: (expanded) {
            setState(() => _technicalAlertsExpanded = expanded);
          },
          leading: const PremiumIconChip(icon: Icons.warning_amber_outlined),
          title: Text(
            'Rule-Based Technical Alerts',
            style: AppTextStyles.headingSmall.copyWith(
              fontSize: 18,
              letterSpacing: 0,
            ),
          ),
          subtitle: Text(
            '${alerts.length} supported alerts from collected visit history',
            style: AppTextStyles.caption,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            if (_technicalAlertsExpanded) ...[
              const Divider(),
              const SizedBox(height: 8),
              if (alerts.isEmpty)
                const _InlineVisitState(
                  icon: Icons.check_circle_outline,
                  title: 'No supported technical alerts',
                  message:
                      'Alerts appear when collected serial, diagnostic, resolution, and duration data crosses a rule threshold.',
                )
              else
                ...alerts.take(8).map(
                  (alert) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: _TechnicalAlertRow(alert: alert),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                'Threshold rules: repeated asset = 3 visits, overheating = 2 readings at 80 C, carry-forward = 2 visits, missed checkout = 12 h, long repair = 8 h.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 3),
              Text(
                'Warranty-expiry and excessive-travel alerts remain unavailable because expiry dates and route distance are not recorded.',
                style: AppTextStyles.caption,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilities() {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          initiallyExpanded: _capabilitiesExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _capabilitiesExpanded = expanded;
            });
          },
          leading: const PremiumIconChip(icon: Icons.fact_check_outlined),
          title: Text(
            'Operational Coverage',
            style: AppTextStyles.headingSmall.copyWith(
              fontSize: 18,
              letterSpacing: 0,
            ),
          ),
          subtitle: Text(
            'Supported workflows and exact backend dependencies',
            style: AppTextStyles.caption,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            if (_capabilitiesExpanded) ...[
              const Divider(),
              const SizedBox(height: 8),
              const _CapabilityRow(
                icon: Icons.check_circle_outline,
                title: 'Available now',
                detail:
                    'Create, assign/reassign, duplicate, GPS lifecycle, equipment registry, multi-issue diagnostics, root cause, corrective/preventive action, checklist, resolution, serial history, technical timeline, attachments, analytics, and customer history.',
                available: true,
              ),
              const _CapabilityRow(
                icon: Icons.assignment_ind_outlined,
                title: 'Smart visit planning and ranked dispatch',
                detail:
                    'Complaint prefill, priority, schedule, expected duration, seven-centre proximity, attendance/workload/GPS recommendations, admin override, pending dispatch, assignment, and assignment delay are supported. Employee centre membership and road routing remain unavailable.',
                available: true,
              ),
              const _CapabilityRow(
                icon: Icons.precision_manufacturing_outlined,
                title: 'Technical diagnostics and checklist',
                detail:
                    'Structured readings, component identity, multiple issue classifications, root cause, actions, resolution, checklist results/comments/photos, and GPS service events are embedded in the existing visit document.',
                available: true,
              ),
              const _CapabilityRow(
                icon: Icons.receipt_long_outlined,
                title: 'Expenses, quotations, invoices, and collections',
                detail:
                    'Requires approved expense, reimbursement, quotation, invoice, payment, receipt, amount, GPS receipt, and approval fields/services.',
                available: false,
              ),
              const _CapabilityRow(
                icon: Icons.inventory_2_outlined,
                title: 'Inventory-backed spare parts',
                detail:
                    'Current partsUsed text is supported. Quantity, serial, warranty, and inventory reservation require an approved visit-to-inventory contract.',
                available: false,
              ),
              const _CapabilityRow(
                icon: Icons.perm_media_outlined,
                title: 'Voice, video, and managed uploads',
                detail:
                    'Photo, video, voice-note, and document references can be linked to timeline events. Binary upload, recording, storage ownership, and retention services are not available.',
                available: false,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReports() {
    const reports = [
      'Visit Report',
      'Engineer Report',
      'Dealer Report',
      'Branch Report',
      'Complaint Report',
      'Expense Report',
      'Warranty Report',
      'Invoice Report',
      'Collection Report',
      'Travel Report',
      'Export PDF',
      'Export Excel',
    ];
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          initiallyExpanded: _reportsExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _reportsExpanded = expanded;
            });
          },
          leading: const PremiumIconChip(icon: Icons.description_outlined),
          title: Text(
            'Enterprise Reports',
            style: AppTextStyles.headingSmall.copyWith(
              fontSize: 18,
              letterSpacing: 0,
            ),
          ),
          subtitle: Text(
            'Disabled until an approved organization export API exists',
            style: AppTextStyles.caption,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            if (_reportsExpanded) ...[
              const Divider(),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900
                      ? 4
                      : constraints.maxWidth >= 540
                      ? 3
                      : 2;
                  const gap = 8.0;
                  final width =
                      (constraints.maxWidth - ((columns - 1) * gap)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: reports
                        .map(
                          (report) => SizedBox(
                            width: width,
                            child: _DisabledReportButton(label: report),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _hasActiveFilters =>
      _searchController.text.trim().isNotEmpty ||
      _controllerSerialController.text.trim().isNotEmpty ||
      _motorSerialController.text.trim().isNotEmpty ||
      _statusFilter != 'all' ||
      _engineerFilter != 'all' ||
      _dealerFilter != 'all' ||
      _issueFilter != 'all' ||
      _vehicleFilter != 'all' ||
      _warrantyFilter != 'all' ||
      _serviceCentreFilter != 'all' ||
      _priorityFilter != 'all' ||
      _visitFocus != _VisitFocus.none;

  Future<void> _chooseEngineer(CustomerVisitModel visit) async {
    if (widget.employees.isEmpty) {
      _showUnavailable(
        'No employee profiles are available for assignment.',
      );
      return;
    }

    final employees = widget.employees.toList()
      ..sort((left, right) =>
          _employeeName(left).compareTo(_employeeName(right)));
    final selected = await showDialog<EmployeeModel>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Assign Engineer'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 420),
          child: SizedBox(
            width: 440,
            height: MediaQuery.sizeOf(dialogContext).height * 0.55,
            child: ListView.separated(
              itemCount: employees.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final employee = employees[index];
                final assigned = visit.userId == employee.uid;
                return ListTile(
                  leading: _EmployeeAvatar(employee: employee),
                  title: Text(
                    _employeeName(employee),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    employee.role.trim().isEmpty
                        ? employee.email
                        : _titleCase(employee.role),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: assigned
                      ? const Icon(Icons.check_circle, color: AppColors.success)
                      : const Icon(Icons.chevron_right),
                  onTap: assigned
                      ? null
                      : () => Navigator.pop(dialogContext, employee),
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    await widget.onAssignEngineer(visit, selected);
  }

  void _focusQueue({
    required _VisitFocus focus,
    _OperationBucket bucket = _OperationBucket.all,
  }) {
    _searchController.clear();
    _controllerSerialController.clear();
    _motorSerialController.clear();
    setState(() {
      _statusFilter = 'all';
      _engineerFilter = 'all';
      _dealerFilter = 'all';
      _issueFilter = 'all';
      _vehicleFilter = 'all';
      _warrantyFilter = 'all';
      _serviceCentreFilter = 'all';
      _priorityFilter = 'all';
      _visitFocus = focus;
      _operationBucket = bucket;
      _visitPage = 0;
    });
  }

  void _showUnavailable(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _setFilter(VoidCallback update) {
    setState(() {
      update();
      _visitFocus = _VisitFocus.none;
      _visitPage = 0;
    });
  }

  void _clearFilters() {
    _searchController.clear();
    _controllerSerialController.clear();
    _motorSerialController.clear();
    setState(() {
      _statusFilter = 'all';
      _engineerFilter = 'all';
      _dealerFilter = 'all';
      _issueFilter = 'all';
      _vehicleFilter = 'all';
      _warrantyFilter = 'all';
      _serviceCentreFilter = 'all';
      _priorityFilter = 'all';
      _visitFocus = _VisitFocus.none;
      _visitPage = 0;
    });
  }

  List<CustomerVisitModel> _filteredVisits(List<CustomerVisitModel> visits) {
    final query = _searchController.text.trim().toLowerCase();
    final controllerSerial = _controllerSerialController.text
        .trim()
        .toLowerCase();
    final motorSerial = _motorSerialController.text.trim().toLowerCase();
    final selectedDay = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    );
    final employeeIds = widget.employees
        .map((employee) => employee.uid)
        .toSet();
    final checkedInEngineerIds = visits
        .where((visit) => visit.status.toLowerCase() == 'checked_in')
        .map((visit) => visit.userId)
        .toSet();
    final movingEngineerIds = widget.liveLocationsByUserId.entries
        .where(
          (entry) =>
              !checkedInEngineerIds.contains(entry.key) &&
              DateTime.now().difference(entry.value.updatedAt).abs() <=
                  const Duration(minutes: 5) &&
              entry.value.speed > 1.4,
        )
        .map((entry) => entry.key)
        .toSet();
    final repeatCounts = <String, int>{};
    for (final visit in visits) {
      final key = _repeatKey(visit);
      if (key.isEmpty) continue;
      repeatCounts.update(key, (count) => count + 1, ifAbsent: () => 1);
    }
    final repeatKeys = repeatCounts.entries
        .where((entry) => entry.value > 1)
        .map((entry) => entry.key)
        .toSet();

    final filtered = visits.where((visit) {
      final searchable = [
        visit.customerName,
        visit.dealerName,
        visit.customerAddress,
        visit.customerPhone,
        visit.purpose,
        visit.vehicleDetails,
        visit.vehicleNumber,
        visit.vehicleType,
        visit.vehicleCategory,
        visit.fleetName,
        visit.motorModel,
        visit.motorSerialNumber,
        visit.controllerModel,
        visit.controllerSerialNumber,
        visit.controllerFirmware,
        visit.batteryModel,
        visit.batterySerialNumber,
        visit.batteryChemistry,
        visit.chargerModel,
        visit.issueCategory,
        ...visit.issueCategories,
        visit.issueDescription,
        ...visit.diagnosticReadings.values,
        visit.actualRootCause,
        visit.correctiveAction,
        visit.preventiveAction,
        visit.engineerRecommendation,
        visit.resolutionStatus,
        visit.complaintId,
        visit.dealerPinCode,
        visit.priority,
        visit.serviceCentreName,
        visit.notes,
        visit.technicianNotes,
        visit.status,
      ].join(' ').toLowerCase();
      final matchesFilters =
          (query.isEmpty || searchable.contains(query)) &&
          (controllerSerial.isEmpty ||
              visit.controllerSerialNumber.toLowerCase().contains(
                controllerSerial,
              )) &&
          (motorSerial.isEmpty ||
              visit.motorSerialNumber.toLowerCase().contains(motorSerial)) &&
          (_statusFilter == 'all' || visit.status == _statusFilter) &&
          (_engineerFilter == 'all' || visit.userId == _engineerFilter) &&
          (_dealerFilter == 'all' ||
              _dealerLabelForVisit(visit) == _dealerFilter) &&
          (_issueFilter == 'all' ||
              _visitIssueCategories(visit).contains(_issueFilter)) &&
          (_vehicleFilter == 'all' || visit.vehicleDetails == _vehicleFilter) &&
          (_warrantyFilter == 'all' || visit.warrantyStatus == _warrantyFilter) &&
          (_serviceCentreFilter == 'all' ||
              visit.serviceCentreName == _serviceCentreFilter) &&
          (_priorityFilter == 'all' || visit.priority == _priorityFilter);
      if (!matchesFilters) return false;

      switch (_visitFocus) {
        case _VisitFocus.none:
          return true;
        case _VisitFocus.assigned:
          return _hasActivityOnDay(visit, selectedDay) &&
              employeeIds.contains(visit.userId);
        case _VisitFocus.unassigned:
          return _hasActivityOnDay(visit, selectedDay) &&
              !employeeIds.contains(visit.userId);
        case _VisitFocus.travelling:
          return !_isVisitClosed(visit) &&
              movingEngineerIds.contains(visit.userId);
        case _VisitFocus.checkedIn:
        case _VisitFocus.pendingCheckout:
          return visit.status.toLowerCase() == 'checked_in';
        case _VisitFocus.repairRunning:
          return _isRepairRunningVisit(visit);
        case _VisitFocus.waitingParts:
          return visit.resolutionStatus.toLowerCase() == 'waiting_parts';
        case _VisitFocus.completed:
          return _completedOnDay(visit, selectedDay);
        case _VisitFocus.cancelled:
          return visit.status.toLowerCase() == 'cancelled' &&
              _hasActivityOnDay(visit, selectedDay);
        case _VisitFocus.warranty:
          return _hasActivityOnDay(visit, selectedDay) &&
              visit.warrantyStatus.toLowerCase().contains('under');
        case _VisitFocus.highPriority:
          return _hasActivityOnDay(visit, selectedDay) &&
              _isHighPriorityVisit(visit);
        case _VisitFocus.repeat:
          return repeatKeys.contains(_repeatKey(visit));
        case _VisitFocus.carryForward:
          return _isCarryForward(visit, selectedDay);
      }
    }).toList();
    filtered.sort(_compareVisits);
    return filtered;
  }

  int _compareVisits(CustomerVisitModel left, CustomerVisitModel right) {
    switch (_visitSort) {
      case _VisitSort.updated:
        return right.updatedAt.compareTo(left.updatedAt);
      case _VisitSort.created:
        return right.createdAt.compareTo(left.createdAt);
      case _VisitSort.customer:
        return left.customerName.toLowerCase().compareTo(
          right.customerName.toLowerCase(),
        );
      case _VisitSort.status:
        return left.status.toLowerCase().compareTo(right.status.toLowerCase());
    }
  }

  List<CustomerVisitModel> _visitsForBucket(
    List<CustomerVisitModel> visits,
    DateTime now,
  ) {
    final start = DateTime(now.year, now.month, now.day);
    return visits
        .where((visit) {
          switch (_operationBucket) {
            case _OperationBucket.today:
              return _hasActivityOnDay(visit, start);
            case _OperationBucket.carryForward:
              return _isCarryForward(visit, start);
            case _OperationBucket.attention:
              return _needsAttention(visit, start);
            case _OperationBucket.completed:
              return _completedOnDay(visit, start);
            case _OperationBucket.all:
              return true;
          }
        })
        .toList(growable: false);
  }
}

class _VisitKpi {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? info;
  final bool selected;
  final VoidCallback onTap;

  const _VisitKpi(
    this.label,
    this.value,
    this.icon,
    this.color, {
    this.info,
    this.selected = false,
    required this.onTap,
  });

  const _VisitKpi.unavailable(
    this.label,
    this.icon,
    String reason, {
    required this.onTap,
  })
    : value = '--',
      color = AppColors.textDisabled,
      info = reason,
      selected = false;
}

class _VisitKpiCard extends StatelessWidget {
  final _VisitKpi kpi;

  const _VisitKpiCard({required this.kpi});

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: kpi.selected
          ? kpi.color.withAlpha(20)
          : Colors.white.withAlpha(8),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: kpi.onTap,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: kpi.color.withAlpha(kpi.selected ? 150 : 52),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(kpi.icon, size: 16, color: kpi.color),
                  const Spacer(),
                  if (kpi.info != null)
                    Icon(Icons.info_outline, size: 14, color: kpi.color),
                ],
              ),
              const Spacer(),
              Text(
                kpi.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                kpi.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(height: 1.1),
              ),
            ],
          ),
        ),
      ),
    );
    if (kpi.info == null) return card;
    return Tooltip(message: kpi.info!, child: card);
  }
}

class _MorningMetric extends StatelessWidget {
  final String label;
  final String value;
  final String? tooltip;

  const _MorningMetric({
    required this.label,
    required this.value,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      constraints: const BoxConstraints(minWidth: 94),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}

class _OperationInsightRow extends StatelessWidget {
  final _OperationInsight insight;

  const _OperationInsightRow({required this.insight});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: insight.color.withAlpha(22),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: insight.color.withAlpha(48)),
          ),
          child: Icon(insight.icon, size: 16, color: insight.color),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                insight.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                insight.detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EngineerOperationRow extends StatelessWidget {
  final _EngineerOperation data;

  const _EngineerOperationRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _EmployeeAvatar(employee: data.employee),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _employeeName(data.employee),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '${data.openVisits} open | ${data.completedToday} completed today${data.lastLocationLabel.isEmpty ? '' : ' | ${data.lastLocationLabel}'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        PremiumStatusChip(label: data.status, color: data.color),
      ],
    );
  }
}

class _EngineerWorkloadCard extends StatelessWidget {
  final _EngineerOperation data;

  const _EngineerWorkloadCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: data.healthColor.withAlpha(52)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _EmployeeAvatar(employee: data.employee),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _employeeName(data.employee),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      data.attendanceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              PremiumStatusChip(label: data.healthLabel, color: data.healthColor),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _WorkloadMetric(
                  label: 'Visits',
                  value: '${data.todayVisits}',
                ),
              ),
              Expanded(
                child: _WorkloadMetric(
                  label: 'Done',
                  value: '${data.completedToday}',
                ),
              ),
              Expanded(
                child: _WorkloadMetric(
                  label: 'Running',
                  value: '${data.runningVisits}',
                ),
              ),
              Expanded(
                child: _WorkloadMetric(
                  label: 'Pending',
                  value: '${data.pendingVisits}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _CompactMeta(
                icon: Icons.work_history_outlined,
                label: _formatDuration(data.workingDuration),
              ),
              _CompactMeta(
                icon: Icons.coffee_outlined,
                label: 'Break ${_formatDuration(data.breakDuration)}',
              ),
              _CompactMeta(
                icon: data.gpsFresh
                    ? Icons.gps_fixed_outlined
                    : Icons.gps_off_outlined,
                label: data.gpsFresh ? 'GPS live' : 'GPS unavailable',
              ),
              _CompactMeta(
                icon: Icons.task_alt_outlined,
                label: '${data.completionRate.toStringAsFixed(0)}% complete',
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            '${data.currentLocationLabel}${data.lastLocationLabel.isEmpty ? '' : ' | ${data.lastLocationLabel}'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textDisabled,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Avg ${data.averageDailyVisits.toStringAsFixed(1)} visits/day | Resolution ${_formatDuration(data.averageResolutionDuration)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 4),
          const Tooltip(
            message:
                'Travel, ETA, and distance require route data; rating requires customer feedback.',
            child: Text(
              'Travel --  |  ETA --  |  Distance --  |  Rating --',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkloadMetric extends StatelessWidget {
  final String label;
  final String value;

  const _WorkloadMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}

class _EmployeeAvatar extends StatelessWidget {
  final EmployeeModel? employee;

  const _EmployeeAvatar({required this.employee});

  @override
  Widget build(BuildContext context) {
    final image = employee?.profileImage.trim() ?? '';
    final name = _employeeName(employee);
    return ClipOval(
      child: Container(
        width: 36,
        height: 36,
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

class _FilterGrid extends StatelessWidget {
  final List<Widget> children;

  const _FilterGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1040
            ? 4
            : constraints.maxWidth >= 320
            ? 2
            : 1;
        const gap = 8.0;
        final width = (constraints.maxWidth - ((columns - 1) * gap)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: children
              .map((child) => SizedBox(width: width, height: 48, child: child))
              .toList(growable: false),
        );
      },
    );
  }
}

class _CompactTextFilter extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;

  const _CompactTextFilter({
    required this.controller,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        isDense: true,
      ),
    );
  }
}

class _CompactDropdownFilter extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final List<String> options;
  final String Function(String value) labelFor;
  final ValueChanged<String> onChanged;

  const _CompactDropdownFilter({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.labelFor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$label:$value:${options.length}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        isDense: true,
      ),
      items: options
          .map(
            (option) => DropdownMenuItem<String>(
              value: option,
              child: Text(
                labelFor(option),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(growable: false),
      onChanged: (selected) {
        if (selected != null) onChanged(selected);
      },
    );
  }
}

class _UnavailableFilter extends StatelessWidget {
  final String label;
  final String reason;

  const _UnavailableFilter({required this.label, required this.reason});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: reason,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock_outline, size: 18),
          enabled: false,
          isDense: true,
        ),
        child: const Text('--'),
      ),
    );
  }
}

class _VisitBoardData {
  final String title;
  final IconData icon;
  final Color color;
  final List<CustomerVisitModel> visits;
  final String? unavailableReason;

  const _VisitBoardData({
    required this.title,
    required this.icon,
    required this.color,
    required this.visits,
  }) : unavailableReason = null;

  const _VisitBoardData.unavailable({
    required this.title,
    required this.icon,
    required String reason,
  }) : color = AppColors.textDisabled,
       visits = const <CustomerVisitModel>[],
       unavailableReason = reason;
}

class _VisitBoardColumn extends StatelessWidget {
  final _VisitBoardData data;
  final Map<String, EmployeeModel> employeesById;
  final Map<String, LiveLocationModel> liveLocationsByUserId;
  final DateTime now;
  final ValueChanged<CustomerVisitModel> onOpenVisit;

  const _VisitBoardColumn({
    required this.data,
    required this.employeesById,
    required this.liveLocationsByUserId,
    required this.now,
    required this.onOpenVisit,
  });

  @override
  Widget build(BuildContext context) {
    final visible = data.visits.take(5).toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: data.color.withAlpha(45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(data.icon, size: 17, color: data.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 24),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: data.color.withAlpha(18),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  data.unavailableReason == null ? '${data.visits.length}' : '--',
                  style: AppTextStyles.caption.copyWith(
                    color: data.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (data.unavailableReason != null)
            Expanded(
              child: Center(
                child: _BoardColumnState(
                  icon: Icons.lock_outline,
                  title: 'Unavailable',
                  message: data.unavailableReason!,
                ),
              ),
            )
          else if (visible.isEmpty)
            const Expanded(
              child: Center(
                child: _BoardColumnState(
                  icon: Icons.inbox_outlined,
                  title: 'No visits',
                  message: 'Realtime updates appear here.',
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: visible.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final visit = visible[index];
                  return _VisitBoardTile(
                    visit: visit,
                    employee: employeesById[visit.userId],
                    liveLocation: liveLocationsByUserId[visit.userId],
                    now: now,
                    onTap: () => onOpenVisit(visit),
                  );
                },
              ),
            ),
          if (data.unavailableReason == null && data.visits.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                '+${data.visits.length - 5} more in visit list',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
            ),
        ],
      ),
    );
  }
}

class _BoardColumnState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _BoardColumnState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AppColors.textDisabled),
        const SizedBox(height: 5),
        Text(title, style: AppTextStyles.caption),
        const SizedBox(height: 2),
        Text(
          message,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(color: AppColors.textDisabled),
        ),
      ],
    );
  }
}

class _VisitBoardTile extends StatelessWidget {
  final CustomerVisitModel visit;
  final EmployeeModel? employee;
  final LiveLocationModel? liveLocation;
  final DateTime now;
  final VoidCallback onTap;

  const _VisitBoardTile({
    required this.visit,
    required this.employee,
    required this.liveLocation,
    required this.now,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final location = liveLocation;
    final locationFresh =
        location != null &&
        now.difference(location.updatedAt).abs() <= const Duration(minutes: 5);
    return Material(
      color: Colors.white.withAlpha(7),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      visit.customerName.isEmpty
                          ? 'Unnamed customer'
                          : visit.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    locationFresh
                        ? Icons.gps_fixed_outlined
                        : Icons.gps_off_outlined,
                    size: 13,
                    color: locationFresh
                        ? AppColors.success
                        : AppColors.textDisabled,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                visit.issueCategory.isEmpty
                    ? visit.purpose
                    : visit.issueCategory,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 3),
              Text(
                '${_employeeName(employee)} | ${_formatRelativeTime(visit.updatedAt, now)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textDisabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnterpriseVisitsTable extends StatelessWidget {
  final List<CustomerVisitModel> visits;
  final Map<String, EmployeeModel> employeesById;
  final ValueChanged<CustomerVisitModel> onOpenVisit;
  final ValueChanged<CustomerVisitModel> onAssignEngineer;
  final Future<void> Function(CustomerVisitModel visit) onDuplicateVisit;
  final VoidCallback onOpenMap;

  const _EnterpriseVisitsTable({
    required this.visits,
    required this.employeesById,
    required this.onOpenVisit,
    required this.onAssignEngineer,
    required this.onDuplicateVisit,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withAlpha(18)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          headingRowHeight: 44,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 58,
          columnSpacing: 18,
          horizontalMargin: 12,
          columns: const [
            DataColumn(label: Text('Visit ID')),
            DataColumn(label: Text('Complaint')),
            DataColumn(label: Text('Dealer')),
            DataColumn(label: Text('Customer')),
            DataColumn(label: Text('Engineer')),
            DataColumn(label: Text('Service Centre')),
            DataColumn(label: Text('Priority')),
            DataColumn(label: Text('Warranty')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Travel')),
            DataColumn(label: Text('ETA')),
            DataColumn(label: Text('Current Stage')),
            DataColumn(label: Text('Created')),
            DataColumn(label: Text('Updated')),
            DataColumn(label: Text('Actions')),
          ],
          rows: visits.map((visit) {
            final status = _statusData(visit.status);
            final complaint = visit.issueCategory.isEmpty
                ? visit.purpose
                : visit.issueCategory;
            return DataRow(
              onSelectChanged: (_) => onOpenVisit(visit),
              cells: [
                DataCell(Text(_shortId(visit.id))),
                DataCell(_TableText(complaint)),
                DataCell(_TableText(visit.dealerName)),
                DataCell(_TableText(visit.customerName)),
                DataCell(_TableText(_employeeName(employeesById[visit.userId]))),
                DataCell(_TableText(visit.serviceCentreName)),
                DataCell(_TableText(visit.priority)),
                DataCell(_TableText(visit.warrantyStatus)),
                DataCell(PremiumStatusChip(label: status.label, color: status.color)),
                DataCell(
                  visit.roadDistanceKm == null
                      ? const _UnavailableTableValue(
                          reason: 'Requires Google Directions API',
                        )
                      : Text('${visit.roadDistanceKm!.toStringAsFixed(1)} km'),
                ),
                DataCell(
                  visit.estimatedTravelMinutes == null
                      ? const _UnavailableTableValue(
                          reason: 'Requires Google Directions API',
                        )
                      : Text('${visit.estimatedTravelMinutes} min'),
                ),
                DataCell(Text(status.label)),
                DataCell(Text(_formatDateTime(visit.createdAt))),
                DataCell(Text(_formatDateTime(visit.updatedAt))),
                DataCell(
                  _VisitActionsMenu(
                    onOpen: () => onOpenVisit(visit),
                    onAssign: () => onAssignEngineer(visit),
                    onDuplicate: () => unawaited(onDuplicateVisit(visit)),
                    onOpenMap: onOpenMap,
                  ),
                ),
              ],
            );
          }).toList(growable: false),
        ),
      ),
    );
  }
}

class _TableText extends StatelessWidget {
  final String value;

  const _TableText(this.value);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 170),
      child: Text(
        value.trim().isEmpty ? '--' : value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _UnavailableTableValue extends StatelessWidget {
  final String reason;

  const _UnavailableTableValue({required this.reason});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: reason,
      child: Text('--', style: AppTextStyles.caption),
    );
  }
}

class _VisitActionsMenu extends StatelessWidget {
  final VoidCallback onOpen;
  final VoidCallback onAssign;
  final VoidCallback onDuplicate;
  final VoidCallback onOpenMap;

  const _VisitActionsMenu({
    required this.onOpen,
    required this.onAssign,
    required this.onDuplicate,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_VisitAction>(
      tooltip: 'Visit actions',
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (action) {
        switch (action) {
          case _VisitAction.open:
            onOpen();
            break;
          case _VisitAction.assign:
            onAssign();
            break;
          case _VisitAction.duplicate:
            onDuplicate();
            break;
          case _VisitAction.map:
            onOpenMap();
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<_VisitAction>(
          value: _VisitAction.open,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.open_in_new, size: 18),
            title: Text('Open details'),
          ),
        ),
        PopupMenuItem<_VisitAction>(
          value: _VisitAction.assign,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.assignment_ind_outlined, size: 18),
            title: Text('Assign / reassign'),
          ),
        ),
        PopupMenuItem<_VisitAction>(
          value: _VisitAction.duplicate,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.copy_outlined, size: 18),
            title: Text('Duplicate visit'),
          ),
        ),
        PopupMenuItem<_VisitAction>(
          value: _VisitAction.map,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.map_outlined, size: 18),
            title: Text('Open map'),
          ),
        ),
      ],
    );
  }
}

class _EnterpriseVisitCard extends StatelessWidget {
  final CustomerVisitModel visit;
  final EmployeeModel? employee;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onAssign;
  final VoidCallback onDuplicate;
  final VoidCallback onOpenMap;

  const _EnterpriseVisitCard({
    required this.visit,
    required this.employee,
    required this.now,
    required this.onTap,
    required this.onAssign,
    required this.onDuplicate,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final status = _statusData(visit.status);
    return PremiumCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PremiumIconChip(
                  icon: Icons.business_center_outlined,
                  color: status.color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visit.customerName.isEmpty
                            ? 'Unnamed customer'
                            : visit.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      Text(
                        visit.customerAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                PremiumStatusChip(label: status.label, color: status.color),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              visit.issueCategory.isEmpty ? visit.purpose : visit.issueCategory,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              visit.issueDescription.isEmpty
                  ? 'No issue description recorded.'
                  : visit.issueDescription,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(height: 1.3),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _CompactMeta(
                  icon: Icons.engineering_outlined,
                  label: _employeeName(employee),
                ),
                _CompactMeta(
                  icon: visit.hasGpsCheckIn
                      ? Icons.gps_fixed_outlined
                      : Icons.gps_off_outlined,
                  label: visit.hasGpsCheckIn ? 'GPS verified' : 'GPS pending',
                ),
                _CompactMeta(
                  icon: Icons.timer_outlined,
                  label: _formatDuration(visit.visitDuration(now)),
                ),
                _CompactMeta(
                  icon: Icons.update_outlined,
                  label: _formatRelativeTime(visit.updatedAt, now),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    visit.warrantyStatus.isEmpty
                        ? 'Warranty not recorded'
                        : visit.warrantyStatus,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
                ),
                _VisitActionsMenu(
                  onOpen: onTap,
                  onAssign: onAssign,
                  onDuplicate: onDuplicate,
                  onOpenMap: onOpenMap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CompactMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementChip extends StatelessWidget {
  final String label;
  final bool available;

  const _RequirementChip({required this.label, required this.available});

  @override
  Widget build(BuildContext context) {
    final color = available ? AppColors.success : AppColors.textDisabled;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(54)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            available ? Icons.check_circle_outline : Icons.lock_outline,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _CompactBarPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Map<String, int> values;
  final Color color;

  const _CompactBarPanel({
    required this.title,
    required this.icon,
    required this.values,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final visible = entries.take(5).toList();
    final maximum = visible.isEmpty
        ? 1
        : visible
              .map((entry) => entry.value)
              .reduce((current, next) => current > next ? current : next);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        if (visible.isEmpty)
          Text('No supported data yet.', style: AppTextStyles.caption)
        else
          ...visible.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('${entry.value}', style: AppTextStyles.caption),
                    ],
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: entry.value / maximum,
                      minHeight: 5,
                      color: color,
                      backgroundColor: Colors.white.withAlpha(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ResponsiveAnalyticsPanels extends StatelessWidget {
  final List<Widget> panels;

  const _ResponsiveAnalyticsPanels({required this.panels});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 860) {
          return Column(
            children: [
              for (var index = 0; index < panels.length; index++) ...[
                panels[index],
                if (index != panels.length - 1) const Divider(height: 18),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < panels.length; index++) ...[
              Expanded(child: panels[index]),
              if (index != panels.length - 1) const SizedBox(width: 18),
            ],
          ],
        );
      },
    );
  }
}

class _TechnicalAnalyticsGroup extends StatelessWidget {
  final String title;
  final List<Widget> panels;

  const _TechnicalAnalyticsGroup({
    required this.title,
    required this.panels,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 10),
      leading: const Icon(Icons.insights_outlined, size: 19),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
      ),
      children: [_ResponsiveAnalyticsPanels(panels: panels)],
    );
  }
}

class _FirstTimeFixPanel extends StatelessWidget {
  final Map<String, double> values;
  final Map<String, EmployeeModel> employeesById;

  const _FirstTimeFixPanel({
    required this.values,
    required this.employeesById,
  });

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Engineer First-Time-Fix Rate',
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 7),
        if (entries.isEmpty)
          Text(
            'No completed serial-linked repairs are available yet.',
            style: AppTextStyles.caption,
          )
        else
          ...entries.take(5).map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _employeeName(employeesById[entry.key]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(
                      value: (entry.value / 100).clamp(0.0, 1.0).toDouble(),
                      minHeight: 6,
                      color: AppColors.success,
                      backgroundColor: Colors.white.withAlpha(12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 42,
                    child: Text(
                      '${entry.value.toStringAsFixed(0)}%',
                      textAlign: TextAlign.end,
                      style: AppTextStyles.caption,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TechnicalAlertRow extends StatelessWidget {
  final _TechnicalAlert alert;

  const _TechnicalAlertRow({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: alert.color.withAlpha(12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: alert.color.withAlpha(45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(alert.icon, size: 18, color: alert.color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alert.detail,
                  style: AppTextStyles.caption.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnavailableAnalyticsNote extends StatelessWidget {
  const _UnavailableAnalyticsNote();

  @override
  Widget build(BuildContext context) {
    return const _InlineVisitState(
      icon: Icons.lock_outline,
      title: 'Additional comparisons require approved fields',
      message:
          'Branch, region, travel distance, expense, warranty cost, rating, revenue, and paid-repair analytics are not inferred.',
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final bool available;

  const _CapabilityRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.available,
  });

  @override
  Widget build(BuildContext context) {
    final color = available ? AppColors.success : AppColors.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 9),
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
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: AppTextStyles.caption.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            available ? Icons.check_circle : Icons.lock_outline,
            size: 18,
            color: color,
          ),
        ],
      ),
    );
  }
}

class _DisabledReportButton extends StatelessWidget {
  final String label;

  const _DisabledReportButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Coming Soon: no approved organization visit export API exists.',
      child: SizedBox(
        height: 46,
        child: OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.lock_outline, size: 16),
          label: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class _InlineVisitState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _InlineVisitState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(height: 5),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(height: 1.35),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _VisitOperationsMetrics {
  final List<CustomerVisitModel> visits;
  final List<CustomerVisitModel> todayVisits;
  final List<CustomerVisitModel> runningVisits;
  final List<CustomerVisitModel> completedToday;
  final List<CustomerVisitModel> cancelledToday;
  final List<CustomerVisitModel> pendingCheckout;
  final List<CustomerVisitModel> pendingVisits;
  final List<CustomerVisitModel> carryForward;
  final List<CustomerVisitModel> needsAttention;
  final int repeatComplaintCount;
  final int warrantyToday;
  final int travellingVisits;
  final int assignedToday;
  final int unassignedToday;
  final Duration averageVisitDuration;
  final Duration averageResolutionDuration;
  final double engineerUtilization;
  final List<_OperationInsight> insights;
  final List<_EngineerOperation> engineerOperations;
  final Map<String, int> statusDistribution;
  final Map<String, int> issueDistribution;
  final Map<String, int> completedByEngineer;
  final Map<String, int> dealerDistribution;
  final Map<String, int> warrantyDistribution;
  final VisitDispatchAnalytics dispatch;
  final _TechnicalOperationsMetrics technical;

  const _VisitOperationsMetrics({
    required this.visits,
    required this.todayVisits,
    required this.runningVisits,
    required this.completedToday,
    required this.cancelledToday,
    required this.pendingCheckout,
    required this.pendingVisits,
    required this.carryForward,
    required this.needsAttention,
    required this.repeatComplaintCount,
    required this.warrantyToday,
    required this.travellingVisits,
    required this.assignedToday,
    required this.unassignedToday,
    required this.averageVisitDuration,
    required this.averageResolutionDuration,
    required this.engineerUtilization,
    required this.insights,
    required this.engineerOperations,
    required this.statusDistribution,
    required this.issueDistribution,
    required this.completedByEngineer,
    required this.dealerDistribution,
    required this.warrantyDistribution,
    required this.dispatch,
    required this.technical,
  });

  factory _VisitOperationsMetrics.calculate({
    required List<CustomerVisitModel> visits,
    required List<EmployeeModel> employees,
    required List<AttendanceModel> attendance,
    required Map<String, LiveLocationModel> liveLocationsByUserId,
    required DateTime selectedDate,
    required DateTime now,
  }) {
    final start = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final todayVisits = visits
        .where((visit) => _hasActivityOnDay(visit, start))
        .toList(growable: false);
    final running = visits
        .where((visit) => visit.status.toLowerCase() == 'checked_in')
        .toList(growable: false);
    final completedToday = visits
        .where((visit) => _completedOnDay(visit, start))
        .toList(growable: false);
    final cancelledToday = visits
        .where(
          (visit) =>
              visit.status.toLowerCase() == 'cancelled' &&
              _hasActivityOnDay(visit, start),
        )
        .toList(growable: false);
    final pending = todayVisits
        .where((visit) => visit.status.toLowerCase() == 'planned')
        .toList(growable: false);
    final delayed = visits
        .where((visit) => _isCarryForward(visit, start))
        .toList(growable: false);
    final attention = visits
        .where((visit) => _needsAttention(visit, start))
        .toList(growable: false);

    final repeatGroups = <String, int>{};
    for (final visit in visits) {
      final key =
          '${visit.customerName.trim().toLowerCase()}|${visit.issueCategory.trim().toLowerCase()}';
      if (key == '|') continue;
      repeatGroups.update(key, (count) => count + 1, ifAbsent: () => 1);
    }
    final repeatCount = repeatGroups.values.fold<int>(
      0,
      (total, count) => total + (count > 1 ? count - 1 : 0),
    );

    final completedDurations = completedToday
        .where((visit) => visit.checkInTime != null)
        .map((visit) => visit.visitDuration(now))
        .where((duration) => duration > Duration.zero)
        .toList();
    final averageDuration = completedDurations.isEmpty
        ? Duration.zero
        : Duration(
            milliseconds:
                completedDurations.fold<int>(
                  0,
                  (sum, duration) => sum + duration.inMilliseconds,
                ) ~/
                completedDurations.length,
          );
    final resolutionDurations = completedToday
        .where((visit) => visit.completedAt != null)
        .map((visit) => visit.completedAt!.difference(visit.createdAt))
        .where((duration) => duration > Duration.zero)
        .toList(growable: false);
    final averageResolutionDuration = resolutionDurations.isEmpty
        ? Duration.zero
        : Duration(
            milliseconds:
                resolutionDurations.fold<int>(
                  0,
                  (sum, duration) => sum + duration.inMilliseconds,
                ) ~/
                resolutionDurations.length,
          );

    final attendanceByUser = <String, AttendanceModel>{
      for (final record in attendance) record.userId: record,
    };
    final employeeIds = employees.map((employee) => employee.uid).toSet();
    final assignedToday = todayVisits
        .where((visit) => employeeIds.contains(visit.userId))
        .length;
    final unassignedToday = todayVisits.length - assignedToday;
    final attendedEngineerCount = attendanceByUser.values
        .where((record) => record.checkInTime != null)
        .length;
    final engineerUtilization = employees.isEmpty
        ? 0.0
        : (attendedEngineerCount / employees.length) * 100;
    final engineerOperations = employees.map((employee) {
      final employeeVisits = visits
          .where((visit) => visit.userId == employee.uid)
          .toList(growable: false);
      CustomerVisitModel? activeVisit;
      for (final visit in employeeVisits) {
        if (visit.status.toLowerCase() == 'checked_in') {
          activeVisit = visit;
          break;
        }
      }
      final openVisits = employeeVisits
          .where((visit) => !_isVisitClosed(visit))
          .length;
      final visitsForToday = employeeVisits
          .where((visit) => _hasActivityOnDay(visit, start))
          .toList(growable: false);
      final completedForToday = employeeVisits
          .where((visit) => _completedOnDay(visit, start))
          .length;
      final runningVisits = employeeVisits
          .where((visit) => visit.status.toLowerCase() == 'checked_in')
          .length;
      final pendingVisits = visitsForToday
          .where((visit) => !_isVisitClosed(visit))
          .length;
      final visitDays = employeeVisits
          .map((visit) => '${visit.createdAt.year}-${visit.createdAt.month}-${visit.createdAt.day}')
          .toSet();
      final averageDailyVisits = visitDays.isEmpty
          ? 0.0
          : employeeVisits.length / visitDays.length;
      final resolutionDurations = employeeVisits
          .where((visit) => visit.completedAt != null)
          .map((visit) => visit.completedAt!.difference(visit.createdAt))
          .where((duration) => duration > Duration.zero)
          .toList(growable: false);
      final averageResolutionDuration = resolutionDurations.isEmpty
          ? Duration.zero
          : Duration(
              milliseconds:
                  resolutionDurations.fold<int>(
                    0,
                    (sum, duration) => sum + duration.inMilliseconds,
                  ) ~/
                  resolutionDurations.length,
            );
      final attendanceRecord = attendanceByUser[employee.uid];
      final location = liveLocationsByUserId[employee.uid];
      final locationFresh =
          location != null &&
          now.difference(location.updatedAt).abs() <=
              const Duration(minutes: 5);
      final moving = locationFresh && location.speed > 1.4;

      late final String status;
      late final Color color;
      if (activeVisit != null) {
        status = 'Repairing';
        color = AppColors.info;
      } else if (attendanceRecord?.isOnBreak == true) {
        status = 'On Break';
        color = AppColors.warning;
      } else if (moving) {
        status = 'Travelling';
        color = AppColors.info;
      } else if (attendanceRecord?.isCheckedIn == true) {
        status = 'Available';
        color = AppColors.success;
      } else {
        status = 'Offline';
        color = AppColors.textSecondary;
      }

      final attendanceReference = _sameDay(start, now)
          ? now
          : DateTime(start.year, start.month, start.day, 23, 59, 59);
      final attendanceLabel = attendanceRecord == null
          ? 'Absent / no record'
          : attendanceRecord.isOnBreak
          ? 'On Break'
          : attendanceRecord.isCheckedIn
          ? 'On Duty'
          : attendanceRecord.isCheckedOut
          ? 'Duty Complete'
          : _titleCase(attendanceRecord.status);
      final completionRate = visitsForToday.isEmpty
          ? 0.0
          : (completedForToday / visitsForToday.length) * 100;
      final carriedForEngineer = employeeVisits
          .where((visit) => _isCarryForward(visit, start))
          .length;
      final overloaded = openVisits >= 5 || carriedForEngineer >= 2;
      final atRisk =
          !overloaded && openVisits > 0 && (status == 'Offline' || openVisits >= 3);
      final healthColor = overloaded
          ? AppColors.error
          : atRisk
          ? AppColors.warning
          : AppColors.success;
      final healthLabel = overloaded
          ? 'At Risk'
          : atRisk
          ? 'Watch'
          : 'Healthy';

      return _EngineerOperation(
        employee: employee,
        status: status,
        color: color,
        openVisits: openVisits,
        todayVisits: visitsForToday.length,
        completedToday: completedForToday,
        runningVisits: runningVisits,
        pendingVisits: pendingVisits,
        workingDuration:
            attendanceRecord?.netWorkingDuration(attendanceReference) ??
            Duration.zero,
        breakDuration:
            attendanceRecord?.breakDuration(attendanceReference) ??
            Duration.zero,
        gpsFresh: locationFresh,
        attendanceLabel: attendanceLabel,
        currentLocationLabel: location == null
            ? 'Location unavailable'
            : '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
        completionRate: completionRate,
        averageDailyVisits: averageDailyVisits,
        averageResolutionDuration: averageResolutionDuration,
        healthColor: healthColor,
        healthLabel: healthLabel,
        lastLocationLabel: location == null
            ? ''
            : _formatRelativeTime(location.updatedAt, now),
      );
    }).toList();
    const statusOrder = {
      'Repairing': 0,
      'Travelling': 1,
      'Available': 2,
      'On Break': 3,
      'Offline': 4,
    };
    engineerOperations.sort((a, b) {
      final statusComparison = (statusOrder[a.status] ?? 9).compareTo(
        statusOrder[b.status] ?? 9,
      );
      if (statusComparison != 0) return statusComparison;
      return b.openVisits.compareTo(a.openVisits);
    });
    final travellingEngineerIds = engineerOperations
        .where((engineer) => engineer.status == 'Travelling')
        .map((engineer) => engineer.employee.uid)
        .toSet();

    final statusDistribution = <String, int>{};
    final issueDistribution = <String, int>{};
    final completedByEngineer = <String, int>{};
    final dealerDistribution = <String, int>{};
    final warrantyDistribution = <String, int>{};
    for (final visit in todayVisits) {
      final status = _statusData(visit.status).label;
      statusDistribution.update(
        status,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      final issues = _visitIssueCategories(visit);
      if (issues.isEmpty) {
        issueDistribution.update(
          'Uncategorised',
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      } else {
        for (final issue in issues) {
          issueDistribution.update(
            issue,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
      }
      final dealer = _dealerLabelForVisit(visit).isEmpty
          ? 'Unnamed customer'
          : _dealerLabelForVisit(visit);
      dealerDistribution.update(
        dealer,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      final warranty = visit.warrantyStatus.trim().isEmpty
          ? 'Not recorded'
          : visit.warrantyStatus.trim();
      warrantyDistribution.update(
        warranty,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      if (_completedOnDay(visit, start)) {
        completedByEngineer.update(
          visit.userId,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }

    final insights = _buildInsights(
      visits: visits,
      delayed: delayed,
      running: running,
      repeatCount: repeatCount,
      issueDistribution: issueDistribution,
      dealerDistribution: dealerDistribution,
      employees: employees,
      start: start,
    );

    return _VisitOperationsMetrics(
      visits: visits,
      todayVisits: todayVisits,
      runningVisits: running,
      completedToday: completedToday,
      cancelledToday: cancelledToday,
      pendingCheckout: running,
      pendingVisits: pending,
      carryForward: delayed,
      needsAttention: attention,
      repeatComplaintCount: repeatCount,
      warrantyToday: todayVisits
          .where(
            (visit) => visit.warrantyStatus.toLowerCase().contains('under'),
          )
          .length,
      travellingVisits: visits
          .where(
            (visit) =>
                !_isVisitClosed(visit) &&
                travellingEngineerIds.contains(visit.userId),
          )
          .length,
      assignedToday: assignedToday,
      unassignedToday: unassignedToday,
      averageVisitDuration: averageDuration,
      averageResolutionDuration: averageResolutionDuration,
      engineerUtilization: engineerUtilization,
      insights: insights,
      engineerOperations: engineerOperations,
      statusDistribution: statusDistribution,
      issueDistribution: issueDistribution,
      completedByEngineer: completedByEngineer,
      dealerDistribution: dealerDistribution,
      warrantyDistribution: warrantyDistribution,
      dispatch: VisitPlanningService.calculateDispatchAnalytics(
        visits: visits,
        employeeIds: employeeIds,
      ),
      technical: _TechnicalOperationsMetrics.calculate(
        visits: visits,
        now: now,
      ),
    );
  }
}

class _TechnicalOperationsMetrics {
  final int technicalRecordCount;
  final int diagnosticRecordCount;
  final int repairRunningCount;
  final int waitingPartsCount;
  final Map<String, int> faultCategories;
  final Map<String, int> motorFaults;
  final Map<String, int> controllerFaults;
  final Map<String, int> batteryFaults;
  final Map<String, int> errorCodes;
  final Map<String, int> motorModels;
  final Map<String, int> controllerModels;
  final Map<String, int> batteryModels;
  final Map<String, int> rootCauses;
  final Map<String, int> preventiveActions;
  final Map<String, int> pendingIssues;
  final Map<String, int> resolutionStatuses;
  final Map<String, int> vehicleTypeFailures;
  final Map<String, int> dealerFailures;
  final Map<String, int> monthlyRepairs;
  final Map<String, int> repeatFailureTrend;
  final Map<String, double> firstTimeFixByEngineer;
  final double? firstTimeFixRate;
  final Duration? averageRepairDuration;
  final Duration? averageDiagnosisDuration;
  final List<_TechnicalAlert> alerts;

  const _TechnicalOperationsMetrics({
    required this.technicalRecordCount,
    required this.diagnosticRecordCount,
    required this.repairRunningCount,
    required this.waitingPartsCount,
    required this.faultCategories,
    required this.motorFaults,
    required this.controllerFaults,
    required this.batteryFaults,
    required this.errorCodes,
    required this.motorModels,
    required this.controllerModels,
    required this.batteryModels,
    required this.rootCauses,
    required this.preventiveActions,
    required this.pendingIssues,
    required this.resolutionStatuses,
    required this.vehicleTypeFailures,
    required this.dealerFailures,
    required this.monthlyRepairs,
    required this.repeatFailureTrend,
    required this.firstTimeFixByEngineer,
    required this.firstTimeFixRate,
    required this.averageRepairDuration,
    required this.averageDiagnosisDuration,
    required this.alerts,
  });

  factory _TechnicalOperationsMetrics.calculate({
    required List<CustomerVisitModel> visits,
    required DateTime now,
  }) {
    final faultCategories = <String, int>{};
    final motorFaults = <String, int>{};
    final controllerFaults = <String, int>{};
    final batteryFaults = <String, int>{};
    final errorCodes = <String, int>{};
    final motorModels = <String, int>{};
    final controllerModels = <String, int>{};
    final batteryModels = <String, int>{};
    final rootCauses = <String, int>{};
    final preventiveActions = <String, int>{};
    final pendingIssues = <String, int>{};
    final resolutionStatuses = <String, int>{};
    final vehicleTypeFailures = <String, int>{};
    final dealerFailures = <String, int>{};
    final monthlyRepairs = <String, int>{};
    final repeatFailureTrend = <String, int>{};
    final repairDurations = <Duration>[];
    final diagnosisDurations = <Duration>[];
    var technicalRecordCount = 0;
    var diagnosticRecordCount = 0;

    for (final visit in visits) {
      if (_hasTechnicalRecord(visit)) technicalRecordCount++;
      if (visit.diagnosticReadings.isNotEmpty) diagnosticRecordCount++;
      final issues = _visitIssueCategories(visit);
      for (final issue in issues) {
        _incrementCount(faultCategories, issue);
      }
      final faultLabel = _technicalFaultLabel(visit);
      if (_containsIssue(issues, 'motor') && faultLabel.isNotEmpty) {
        _incrementCount(motorFaults, faultLabel);
      }
      if (_containsIssue(issues, 'controller') && faultLabel.isNotEmpty) {
        _incrementCount(controllerFaults, faultLabel);
      }
      if (_containsIssue(issues, 'battery') && faultLabel.isNotEmpty) {
        _incrementCount(batteryFaults, faultLabel);
      }
      for (final key in const ['errorCode', 'controllerErrorNumber']) {
        final code = visit.diagnosticReadings[key]?.trim() ?? '';
        if (code.isNotEmpty) _incrementCount(errorCodes, code);
      }
      _incrementCount(rootCauses, visit.actualRootCause);
      _incrementCount(preventiveActions, visit.preventiveAction);
      if (!_isTechnicallyClosedVisit(visit)) {
        if (faultLabel.isNotEmpty) {
          _incrementCount(pendingIssues, faultLabel);
        } else {
          for (final issue in issues) {
            _incrementCount(pendingIssues, issue);
          }
        }
      }
      if (visit.resolutionStatus.trim().isNotEmpty) {
        _incrementCount(
          resolutionStatuses,
          technicalValueLabel(visit.resolutionStatus),
        );
      }
      if (issues.isNotEmpty || visit.actualRootCause.isNotEmpty) {
        _incrementCount(vehicleTypeFailures, visit.vehicleType);
        _incrementCount(dealerFailures, visit.dealerName);
      }
      if (_isTechnicallyResolvedVisit(visit)) {
        _incrementCount(motorModels, visit.motorModel);
        _incrementCount(controllerModels, visit.controllerModel);
        _incrementCount(batteryModels, visit.batteryModel);
        final resolvedAt = visit.completedAt ?? visit.checkOutTime ?? visit.updatedAt;
        _incrementCount(monthlyRepairs, _technicalMonthKey(resolvedAt));
        final duration = visit.visitDuration(now);
        if (duration > Duration.zero) repairDurations.add(duration);
      }
      final diagnosisStarts = visit.technicalTimeline
          .where((event) => event.eventType == 'diagnosis_started')
          .toList()
        ..sort((left, right) => left.occurredAt.compareTo(right.occurredAt));
      final diagnosisEnds = visit.technicalTimeline
          .where((event) => event.eventType == 'diagnosis_completed')
          .toList()
        ..sort((left, right) => left.occurredAt.compareTo(right.occurredAt));
      if (diagnosisStarts.isNotEmpty && diagnosisEnds.isNotEmpty) {
        final startedAt = diagnosisStarts.first.occurredAt;
        DateTime? completedAt;
        for (final event in diagnosisEnds) {
          if (event.occurredAt.isAfter(startedAt)) {
            completedAt = event.occurredAt;
            break;
          }
        }
        if (completedAt != null) {
          diagnosisDurations.add(completedAt.difference(startedAt));
        }
      }
    }

    final sortedVisits = visits.toList()
      ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
    final seenAssets = <String>{};
    for (final visit in sortedVisits) {
      final asset = _technicalAssetKey(visit);
      if (asset.isEmpty) continue;
      if (!seenAssets.add(asset)) {
        _incrementCount(
          repeatFailureTrend,
          _technicalMonthKey(visit.createdAt),
        );
      }
    }

    final fixTotals = <String, int>{};
    final firstFixes = <String, int>{};
    for (final visit in sortedVisits.where(_isTechnicallyResolvedVisit)) {
      final asset = _technicalAssetKey(visit);
      if (asset.isEmpty || visit.userId.isEmpty) continue;
      final visitIssues = _visitIssueCategories(visit).toSet();
      final resolvedAt = visit.completedAt ?? visit.checkOutTime ?? visit.updatedAt;
      final hasLaterRepeat = sortedVisits.any((candidate) {
        if (!candidate.createdAt.isAfter(resolvedAt) ||
            _technicalAssetKey(candidate) != asset) {
          return false;
        }
        final candidateIssues = _visitIssueCategories(candidate).toSet();
        return visitIssues.isEmpty ||
            candidateIssues.isEmpty ||
            candidateIssues.any(visitIssues.contains);
      });
      fixTotals.update(visit.userId, (count) => count + 1, ifAbsent: () => 1);
      if (!hasLaterRepeat) {
        firstFixes.update(
          visit.userId,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
    final firstTimeFixByEngineer = <String, double>{
      for (final entry in fixTotals.entries)
        entry.key: ((firstFixes[entry.key] ?? 0) / entry.value) * 100,
    };
    final totalFixAttempts = fixTotals.values.fold<int>(
      0,
      (total, count) => total + count,
    );
    final totalFirstFixes = firstFixes.values.fold<int>(
      0,
      (total, count) => total + count,
    );

    return _TechnicalOperationsMetrics(
      technicalRecordCount: technicalRecordCount,
      diagnosticRecordCount: diagnosticRecordCount,
      repairRunningCount: visits.where(_isRepairRunningVisit).length,
      waitingPartsCount: visits
          .where(
            (visit) =>
                visit.resolutionStatus.toLowerCase() == 'waiting_parts',
          )
          .length,
      faultCategories: faultCategories,
      motorFaults: motorFaults,
      controllerFaults: controllerFaults,
      batteryFaults: batteryFaults,
      errorCodes: errorCodes,
      motorModels: motorModels,
      controllerModels: controllerModels,
      batteryModels: batteryModels,
      rootCauses: rootCauses,
      preventiveActions: preventiveActions,
      pendingIssues: pendingIssues,
      resolutionStatuses: resolutionStatuses,
      vehicleTypeFailures: vehicleTypeFailures,
      dealerFailures: dealerFailures,
      monthlyRepairs: monthlyRepairs,
      repeatFailureTrend: repeatFailureTrend,
      firstTimeFixByEngineer: firstTimeFixByEngineer,
      firstTimeFixRate: totalFixAttempts == 0
          ? null
          : (totalFirstFixes / totalFixAttempts) * 100,
      averageRepairDuration: _averageTechnicalDuration(repairDurations),
      averageDiagnosisDuration: _averageTechnicalDuration(diagnosisDurations),
      alerts: _buildTechnicalAlerts(visits: visits, now: now),
    );
  }
}

class _TechnicalAlert {
  final IconData icon;
  final String title;
  final String detail;
  final Color color;

  const _TechnicalAlert({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
  });
}

class _EngineerOperation {
  final EmployeeModel employee;
  final String status;
  final Color color;
  final int openVisits;
  final int todayVisits;
  final int completedToday;
  final int runningVisits;
  final int pendingVisits;
  final Duration workingDuration;
  final Duration breakDuration;
  final bool gpsFresh;
  final String attendanceLabel;
  final String currentLocationLabel;
  final double completionRate;
  final double averageDailyVisits;
  final Duration averageResolutionDuration;
  final Color healthColor;
  final String healthLabel;
  final String lastLocationLabel;

  const _EngineerOperation({
    required this.employee,
    required this.status,
    required this.color,
    required this.openVisits,
    required this.todayVisits,
    required this.completedToday,
    required this.runningVisits,
    required this.pendingVisits,
    required this.workingDuration,
    required this.breakDuration,
    required this.gpsFresh,
    required this.attendanceLabel,
    required this.currentLocationLabel,
    required this.completionRate,
    required this.averageDailyVisits,
    required this.averageResolutionDuration,
    required this.healthColor,
    required this.healthLabel,
    required this.lastLocationLabel,
  });
}

class _OperationInsight {
  final IconData icon;
  final String title;
  final String detail;
  final Color color;

  const _OperationInsight({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
  });
}

class _StatusData {
  final String label;
  final Color color;

  const _StatusData(this.label, this.color);
}

bool _hasTechnicalRecord(CustomerVisitModel visit) {
  return visit.vehicleNumber.isNotEmpty ||
      visit.vehicleType.isNotEmpty ||
      visit.vehicleCategory.isNotEmpty ||
      visit.fleetName.isNotEmpty ||
      visit.dealerName.isNotEmpty ||
      visit.motorModel.isNotEmpty ||
      visit.motorManufacturingDate != null ||
      visit.motorWarrantyStatus.isNotEmpty ||
      visit.controllerModel.isNotEmpty ||
      visit.controllerFirmware.isNotEmpty ||
      visit.controllerManufacturingDate != null ||
      visit.batteryModel.isNotEmpty ||
      visit.batterySerialNumber.isNotEmpty ||
      visit.batteryChemistry.isNotEmpty ||
      visit.batteryCapacity.isNotEmpty ||
      visit.batteryNominalVoltage.isNotEmpty ||
      visit.batteryWarrantyStatus.isNotEmpty ||
      visit.chargerModel.isNotEmpty ||
      visit.vehicleOdometer != null ||
      visit.hoursRun != null ||
      visit.lastServiceDate != null ||
      visit.issueCategories.length > 1 ||
      visit.diagnosticReadings.isNotEmpty ||
      visit.actualRootCause.isNotEmpty ||
      visit.correctiveAction.isNotEmpty ||
      visit.preventiveAction.isNotEmpty ||
      visit.engineerRecommendation.isNotEmpty ||
      visit.resolutionStatus.isNotEmpty ||
      visit.serviceChecklist.isNotEmpty ||
      visit.technicalTimeline.isNotEmpty ||
      visit.photoTimelineEvents.isNotEmpty ||
      visit.technicalAttachments.isNotEmpty;
}

bool _isRepairRunningVisit(CustomerVisitModel visit) {
  if (visit.status.toLowerCase() != 'checked_in') return false;
  final resolution = visit.resolutionStatus.toLowerCase();
  if (resolution == 'waiting_parts' ||
      resolution == 'waiting_customer' ||
      resolution == 'solved' ||
      resolution == 'cancelled' ||
      resolution == 'carry_forward') {
    return false;
  }
  return visit.technicalTimeline.any(
    (event) => event.eventType == 'work_started',
  );
}

List<String> _visitIssueCategories(CustomerVisitModel visit) {
  final issues = visit.issueCategories.isEmpty
      ? <String>[if (visit.issueCategory.trim().isNotEmpty) visit.issueCategory]
      : visit.issueCategories;
  return issues
      .map((issue) => issue.trim())
      .where((issue) => issue.isNotEmpty)
      .toList(growable: false);
}

bool _containsIssue(List<String> issues, String expected) {
  return issues.any((issue) => issue.toLowerCase() == expected);
}

String _technicalFaultLabel(CustomerVisitModel visit) {
  final rootCause = visit.actualRootCause.trim();
  if (rootCause.isNotEmpty) return rootCause;
  final errorCode = visit.diagnosticReadings['errorCode']?.trim() ?? '';
  if (errorCode.isNotEmpty) return 'Error $errorCode';
  final description = visit.issueDescription.trim();
  return description;
}

void _incrementCount(Map<String, int> values, String rawValue) {
  final value = rawValue.trim();
  if (value.isEmpty) return;
  values.update(value, (count) => count + 1, ifAbsent: () => 1);
}

void _incrementAssetSerialCount(Map<String, int> values, String rawValue) {
  final value = rawValue.trim().toUpperCase();
  if (value.isEmpty) return;
  values.update(value, (count) => count + 1, ifAbsent: () => 1);
}

String _technicalAssetKey(CustomerVisitModel visit) {
  final controller = visit.controllerSerialNumber.trim().toLowerCase();
  if (controller.isNotEmpty) return 'controller:$controller';
  final motor = visit.motorSerialNumber.trim().toLowerCase();
  if (motor.isNotEmpty) return 'motor:$motor';
  final battery = visit.batterySerialNumber.trim().toLowerCase();
  if (battery.isNotEmpty) return 'battery:$battery';
  final vehicle = visit.vehicleNumber.trim().toLowerCase();
  if (vehicle.isNotEmpty) return 'vehicle:$vehicle';
  return '';
}

String _technicalAssetLabel(String assetKey) {
  final separator = assetKey.indexOf(':');
  if (separator <= 0 || separator == assetKey.length - 1) {
    return technicalValueLabel(assetKey);
  }
  final type = technicalValueLabel(assetKey.substring(0, separator));
  final serial = assetKey.substring(separator + 1).toUpperCase();
  return '$type $serial';
}

String _technicalMonthKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  return '${date.year}-$month';
}

bool _isTechnicallyResolvedVisit(CustomerVisitModel visit) {
  final resolution = visit.resolutionStatus.toLowerCase();
  final status = visit.status.toLowerCase();
  return resolution == 'solved' ||
      resolution == 'temporary_fix' ||
      status == 'completed';
}

bool _isTechnicallyClosedVisit(CustomerVisitModel visit) {
  final resolution = visit.resolutionStatus.toLowerCase();
  final status = visit.status.toLowerCase();
  return resolution == 'solved' ||
      resolution == 'cancelled' ||
      status == 'completed' ||
      status == 'cancelled';
}

Duration? _averageTechnicalDuration(List<Duration> durations) {
  if (durations.isEmpty) return null;
  final total = durations.fold<int>(
    0,
    (sum, duration) => sum + duration.inMilliseconds,
  );
  return Duration(milliseconds: total ~/ durations.length);
}

String _dealerLabelForVisit(CustomerVisitModel visit) {
  final dealer = visit.dealerName.trim();
  if (dealer.isNotEmpty) return dealer;
  return visit.customerName.trim();
}

List<_TechnicalAlert> _buildTechnicalAlerts({
  required List<CustomerVisitModel> visits,
  required DateTime now,
}) {
  final alerts = <_TechnicalAlert>[];
  final controllerCounts = <String, int>{};
  final batteryCounts = <String, int>{};
  final vehicleCounts = <String, int>{};
  final motorOverheatCounts = <String, int>{};
  final carryForwardByAsset = <String, int>{};
  final unresolvedByAsset = <String, int>{};
  var missedCheckoutCount = 0;
  var longRepairCount = 0;

  for (final visit in visits) {
    _incrementAssetSerialCount(controllerCounts, visit.controllerSerialNumber);
    _incrementAssetSerialCount(batteryCounts, visit.batterySerialNumber);
    _incrementAssetSerialCount(vehicleCounts, visit.vehicleNumber);
    final motorTemperature = _parseTechnicalNumber(
      visit.diagnosticReadings['motorTemperature'],
    );
    if (motorTemperature != null && motorTemperature >= 80) {
      _incrementAssetSerialCount(
        motorOverheatCounts,
        visit.motorSerialNumber,
      );
    }
    if (visit.resolutionStatus.toLowerCase() == 'carry_forward') {
      final asset = _technicalAssetKey(visit);
      if (asset.isNotEmpty) {
        carryForwardByAsset.update(
          asset,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
    final checkIn = visit.checkInTime;
    if (checkIn != null &&
        visit.checkOutTime == null &&
        now.difference(checkIn) >= const Duration(hours: 12)) {
      missedCheckoutCount++;
    }
    if (checkIn != null &&
        visit.visitDuration(now) >= const Duration(hours: 8)) {
      longRepairCount++;
    }
    if (!_isTechnicallyClosedVisit(visit)) {
      final asset = _technicalAssetKey(visit);
      if (asset.isNotEmpty) {
        unresolvedByAsset.update(
          asset,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
  }

  for (final entry in _highestThresholdEntries(controllerCounts, 3)) {
    alerts.add(
      _TechnicalAlert(
        icon: Icons.memory_outlined,
        title: 'Controller ${entry.key} serviced ${entry.value} times',
        detail: 'Repeated controller service reached the 3-visit threshold.',
        color: AppColors.error,
      ),
    );
  }
  for (final entry in _highestThresholdEntries(batteryCounts, 3)) {
    alerts.add(
      _TechnicalAlert(
        icon: Icons.battery_alert_outlined,
        title: 'Battery ${entry.key} is repeatedly failing',
        detail: '${entry.value} visits are linked to this battery serial.',
        color: AppColors.error,
      ),
    );
  }
  for (final entry in _highestThresholdEntries(vehicleCounts, 3)) {
    alerts.add(
      _TechnicalAlert(
        icon: Icons.local_shipping_outlined,
        title: 'Vehicle ${entry.key} has repeated visits',
        detail: '${entry.value} visits are linked to this vehicle number.',
        color: AppColors.warning,
      ),
    );
  }
  for (final entry in _highestThresholdEntries(motorOverheatCounts, 2)) {
    alerts.add(
      _TechnicalAlert(
        icon: Icons.device_thermostat_outlined,
        title: 'Motor ${entry.key} is repeatedly overheating',
        detail:
            '${entry.value} readings reached or exceeded the 80 C threshold.',
        color: AppColors.error,
      ),
    );
  }
  for (final entry in _highestThresholdEntries(carryForwardByAsset, 2)) {
    alerts.add(
      _TechnicalAlert(
        icon: Icons.history_toggle_off_outlined,
        title: '${_technicalAssetLabel(entry.key)} repeatedly carried forward',
        detail:
            '${entry.value} visits explicitly record Carry Forward resolution.',
        color: AppColors.warning,
      ),
    );
  }
  final repeatedUnresolved = unresolvedByAsset.values
      .where((count) => count >= 2)
      .length;
  if (repeatedUnresolved > 0) {
    alerts.add(
      _TechnicalAlert(
        icon: Icons.report_problem_outlined,
        title: '$repeatedUnresolved assets have repeated unresolved issues',
        detail: 'At least two open visits share the same recorded asset.',
        color: AppColors.error,
      ),
    );
  }
  if (missedCheckoutCount > 0) {
    alerts.add(
      _TechnicalAlert(
        icon: Icons.logout_outlined,
        title: '$missedCheckoutCount engineers may have missed checkout',
        detail: 'Visit check-in has remained open for at least 12 hours.',
        color: AppColors.error,
      ),
    );
  }
  if (longRepairCount > 0) {
    alerts.add(
      _TechnicalAlert(
        icon: Icons.timer_off_outlined,
        title: '$longRepairCount repairs exceed 8 hours',
        detail: 'Duration is calculated from existing visit check-in data.',
        color: AppColors.warning,
      ),
    );
  }
  return alerts;
}

List<MapEntry<String, int>> _highestThresholdEntries(
  Map<String, int> values,
  int threshold,
) {
  final entries = values.entries
      .where((entry) => entry.value >= threshold)
      .toList()
    ..sort((left, right) => right.value.compareTo(left.value));
  return entries.take(3).toList(growable: false);
}

double? _parseTechnicalNumber(String? value) {
  if (value == null) return null;
  final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(value);
  return match == null ? null : double.tryParse(match.group(0)!);
}

List<_OperationInsight> _buildInsights({
  required List<CustomerVisitModel> visits,
  required List<CustomerVisitModel> delayed,
  required List<CustomerVisitModel> running,
  required int repeatCount,
  required Map<String, int> issueDistribution,
  required Map<String, int> dealerDistribution,
  required List<EmployeeModel> employees,
  required DateTime start,
}) {
  final insights = <_OperationInsight>[];
  if (delayed.isNotEmpty) {
    insights.add(
      _OperationInsight(
        icon: Icons.history_toggle_off_outlined,
        title: '${delayed.length} visits carried forward',
        detail: 'Unresolved visits created before today remain visible.',
        color: AppColors.warning,
      ),
    );
  }
  final missedCheckout = running.where((visit) {
    final checkIn = visit.checkInTime;
    return checkIn != null && checkIn.isBefore(start);
  }).length;
  if (missedCheckout > 0) {
    insights.add(
      _OperationInsight(
        icon: Icons.logout_outlined,
        title: '$missedCheckout visits may be missing checkout',
        detail: 'They remain checked in from before today.',
        color: AppColors.error,
      ),
    );
  }
  final pendingEvidence = visits.where((visit) {
    final status = visit.status.toLowerCase();
    final serviceFinished = status == 'checked_out' || status == 'completed';
    return serviceFinished &&
        (visit.photoUrls.isEmpty ||
            visit.signaturePlaceholderStatus.toLowerCase() != 'ready');
  }).length;
  if (pendingEvidence > 0) {
    insights.add(
      _OperationInsight(
        icon: Icons.add_photo_alternate_outlined,
        title: '$pendingEvidence visits need evidence or signature',
        detail:
            'Checked-out or completed visits remain visible until supported sign-off data is ready.',
        color: AppColors.warning,
      ),
    );
  }
  final topIssue = _largestEntry(issueDistribution);
  if (topIssue != null) {
    insights.add(
      _OperationInsight(
        icon: Icons.troubleshoot_outlined,
        title: '${topIssue.key} is the highest-frequency issue',
        detail: '${topIssue.value} visits use this existing issue category.',
        color: AppColors.warning,
      ),
    );
  }
  final openByEngineer = <String, int>{};
  final employeeIds = employees.map((employee) => employee.uid).toSet();
  for (final visit in visits.where((visit) => !_isVisitClosed(visit))) {
    if (!employeeIds.contains(visit.userId)) continue;
    openByEngineer.update(
      visit.userId,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }
  final topWorkload = _largestEntry(openByEngineer);
  final overloadedEngineers = openByEngineer.values
      .where((count) => count >= 5)
      .length;
  if (overloadedEngineers > 0) {
    insights.add(
      _OperationInsight(
        icon: Icons.warning_amber_outlined,
        title: '$overloadedEngineers engineers have heavy workloads',
        detail: 'Five or more unresolved visits are currently linked to them.',
        color: AppColors.error,
      ),
    );
  }
  if (topWorkload != null) {
    EmployeeModel? employee;
    for (final candidate in employees) {
      if (candidate.uid == topWorkload.key) {
        employee = candidate;
        break;
      }
    }
    insights.add(
      _OperationInsight(
        icon: Icons.work_history_outlined,
        title: '${_employeeName(employee)} has the highest open workload',
        detail:
            '${topWorkload.value} unresolved visits are assigned by userId.',
        color: AppColors.info,
      ),
    );
  }
  if (repeatCount > 0) {
    final topDealer = _largestEntry(dealerDistribution);
    insights.add(
      _OperationInsight(
        icon: Icons.replay_outlined,
        title: '$repeatCount repeat complaint occurrences detected',
        detail: topDealer == null
            ? 'Repeated customer and issue-category combinations need review.'
            : '${topDealer.key} has the highest recorded visit volume.',
        color: AppColors.warning,
      ),
    );
  }
  final warrantyAttention = visits.where((visit) {
    return !_isVisitClosed(visit) &&
        visit.warrantyStatus.toLowerCase().contains('under');
  }).length;
  if (warrantyAttention > 0) {
    insights.add(
      _OperationInsight(
        icon: Icons.verified_user_outlined,
        title: '$warrantyAttention warranty visits need attention',
        detail: 'These under-warranty visits are not yet completed.',
        color: AppColors.warning,
      ),
    );
  }
  return insights;
}

MapEntry<String, int>? _largestEntry(Map<String, int> values) {
  if (values.isEmpty) return null;
  return values.entries.reduce(
    (current, next) => next.value > current.value ? next : current,
  );
}

bool _hasActivityOnDay(CustomerVisitModel visit, DateTime day) {
  return _sameDay(visit.createdAt, day) ||
      (visit.checkInTime != null && _sameDay(visit.checkInTime!, day)) ||
      (visit.checkOutTime != null && _sameDay(visit.checkOutTime!, day)) ||
      (visit.completedAt != null && _sameDay(visit.completedAt!, day));
}

bool _completedOnDay(CustomerVisitModel visit, DateTime day) {
  final completedAt = visit.completedAt;
  if (completedAt != null) return _sameDay(completedAt, day);
  return visit.status.toLowerCase() == 'completed' &&
      _sameDay(visit.updatedAt, day);
}

bool _isCarryForward(CustomerVisitModel visit, DateTime start) {
  return !_isVisitClosed(visit) && visit.createdAt.isBefore(start);
}

bool _needsAttention(CustomerVisitModel visit, DateTime start) {
  final status = visit.status.toLowerCase();
  final missingEvidence =
      (status == 'checked_out' || status == 'completed') &&
      (visit.photoUrls.isEmpty ||
          visit.signaturePlaceholderStatus.toLowerCase() != 'ready');
  return _isCarryForward(visit, start) ||
      status == 'checked_out' ||
      (status == 'checked_in' && !visit.hasGpsCheckIn) ||
      missingEvidence;
}

bool _isVisitClosed(CustomerVisitModel visit) {
  final status = visit.status.toLowerCase();
  return status == 'completed' || status == 'cancelled';
}

bool _isHighPriorityVisit(CustomerVisitModel visit) {
  final priority = visit.priority.toLowerCase();
  return priority == 'high' || priority == 'critical';
}

Duration _expectedWorkDuration(List<CustomerVisitModel> visits) {
  final minutes = visits.fold<int>(
    0,
    (total, visit) => total + (visit.expectedDurationMinutes ?? 0),
  );
  return Duration(minutes: minutes);
}

bool _sameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

int _bucketCount(_VisitOperationsMetrics metrics, _OperationBucket bucket) {
  switch (bucket) {
    case _OperationBucket.today:
      return metrics.todayVisits.length;
    case _OperationBucket.carryForward:
      return metrics.carryForward.length;
    case _OperationBucket.attention:
      return metrics.needsAttention.length;
    case _OperationBucket.completed:
      return metrics.completedToday.length;
    case _OperationBucket.all:
      return metrics.visits.length;
  }
}

String _bucketLabel(_OperationBucket bucket) {
  switch (bucket) {
    case _OperationBucket.today:
      return 'Selected Day';
    case _OperationBucket.carryForward:
      return 'Carry Forward';
    case _OperationBucket.attention:
      return 'Needs Attention';
    case _OperationBucket.completed:
      return 'Completed';
    case _OperationBucket.all:
      return 'All Visits';
  }
}

_StatusData _statusData(String status) {
  switch (status.toLowerCase()) {
    case 'checked_in':
      return const _StatusData('Checked In', AppColors.info);
    case 'checked_out':
      return const _StatusData('Checked Out', AppColors.warning);
    case 'completed':
      return const _StatusData('Completed', AppColors.success);
    case 'cancelled':
      return const _StatusData('Cancelled', AppColors.error);
    case 'planned':
      return const _StatusData('Planned', AppColors.textSecondary);
    default:
      return const _StatusData('Open', AppColors.textSecondary);
  }
}

String _statusLabel(String status) {
  if (status == 'all') return 'All Statuses';
  return _statusData(status).label;
}

String _visitSortLabel(_VisitSort sort) {
  switch (sort) {
    case _VisitSort.updated:
      return 'Last updated';
    case _VisitSort.created:
      return 'Created time';
    case _VisitSort.customer:
      return 'Customer';
    case _VisitSort.status:
      return 'Status';
  }
}

String _repeatKey(CustomerVisitModel visit) {
  final customer = visit.customerName.trim().toLowerCase();
  final issue = visit.issueCategory.trim().toLowerCase();
  if (customer.isEmpty && issue.isEmpty) return '';
  return '$customer|$issue';
}

String _employeeName(EmployeeModel? employee) {
  final name = employee?.name.trim() ?? '';
  if (name.isNotEmpty) return name;
  final email = employee?.email.trim() ?? '';
  if (email.isNotEmpty) return email;
  final uid = employee?.uid.trim() ?? '';
  if (uid.isNotEmpty) return 'Engineer ${_shortId(uid)}';
  return 'Unassigned engineer';
}

String _shortId(String value) {
  if (value.length <= 8) return value;
  return value.substring(0, 8);
}

List<String> _uniqueNonEmpty(Iterable<String> values) {
  final unique = values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();
  unique.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return unique;
}

String _formatLongDate(DateTime date) {
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
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
}

String _formatCompactDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _formatDateTime(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/${date.year} $hour:$minute';
}

String _formatDuration(Duration duration) {
  if (duration <= Duration.zero) return '0h 00m';
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  return '${hours}h ${minutes}m';
}

String _optionalDistance(double? kilometers) {
  return kilometers == null ? '--' : '${kilometers.toStringAsFixed(1)} km';
}

String _formatRelativeTime(DateTime time, DateTime now) {
  final difference = now.difference(time).abs();
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  return '${difference.inDays}d ago';
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
