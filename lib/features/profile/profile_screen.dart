import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/premium_widgets.dart';
import '../attendance/attendance_screen.dart';
import '../attendance/models/attendance_model.dart';
import '../complaints/complaint_register_screen.dart';
import '../customer_visits/customer_visit_detail_screen.dart';
import '../customer_visits/customer_visit_screen.dart';
import '../customer_visits/models/customer_visit_model.dart';
import '../map/map_screen.dart';
import '../notifications/models/notification_preferences_model.dart';
import '../notifications/notification_center_screen.dart';
import '../organization/organization_admin_screen.dart';
import '../organization/services/organization_service.dart';
import '../reports/reports_screen.dart';
import 'controllers/profile_controller.dart';
import 'services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<ProfileOperationsSnapshot> _future;
  StreamSubscription<void>? _subscription;
  Timer? _reloadDebounce;
  Timer? _clock;
  DateTime _now = DateTime.now();
  _PerformanceRange _performanceRange = _PerformanceRange.month;
  final GlobalKey _settingsKey = GlobalKey();
  final ExpansibleController _settingsController = ExpansibleController();

  @override
  void initState() {
    super.initState();
    _future = ProfileController.loadOperations();
    _subscription = ProfileController.watchOperations().listen(
      (_) {
        _reloadDebounce?.cancel();
        _reloadDebounce = Timer(const Duration(milliseconds: 450), _reload);
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Profile realtime stream failed: $error\n$stackTrace');
      },
    );
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _reloadDebounce?.cancel();
    _clock?.cancel();
    _settingsController.dispose();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _now = DateTime.now();
      _future = ProfileController.loadOperations();
    });
  }

  Future<void> _refresh() async {
    final future = ProfileController.loadOperations();
    setState(() {
      _future = future;
      _now = DateTime.now();
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Personal Operations Center',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                letterSpacing: 0,
              ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh profile operations',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<ProfileOperationsSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const _ProfileSkeleton();
          }
          if (snapshot.hasError) {
            debugPrint('Profile operations failed: ${snapshot.error}');
            debugPrint('Stack trace:\n${snapshot.stackTrace}');
            return PremiumErrorState(
              title: 'Personal operations could not be loaded.',
              error: snapshot.error,
              onRetry: _reload,
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return PremiumEmptyState(
              icon: Icons.person_off_outlined,
              title: 'Profile unavailable',
              message: 'No signed-in profile could be resolved.',
              actionLabel: 'Retry',
              onAction: _reload,
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: _ProfileContent(
              data: data,
              now: _now,
              performanceRange: _performanceRange,
              onRangeChanged: (value) {
                setState(() => _performanceRange = value);
              },
              onReload: _reload,
              settingsKey: _settingsKey,
              settingsController: _settingsController,
            ),
          );
        },
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  final ProfileOperationsSnapshot data;
  final DateTime now;
  final _PerformanceRange performanceRange;
  final ValueChanged<_PerformanceRange> onRangeChanged;
  final VoidCallback onReload;
  final GlobalKey settingsKey;
  final ExpansibleController settingsController;

  const _ProfileContent({
    required this.data,
    required this.now,
    required this.performanceRange,
    required this.onRangeChanged,
    required this.onReload,
    required this.settingsKey,
    required this.settingsController,
  });

  @override
  Widget build(BuildContext context) {
    final todayVisits = data.visits.where((v) => _isVisitToday(v, now)).toList();
    final upcoming = data.visits.where((v) {
      final date = v.preferredVisitDate;
      return date != null && date.isAfter(now) && v.status != 'completed';
    }).toList()..sort((a, b) => a.preferredVisitDate!.compareTo(b.preferredVisitDate!));
    final unread = data.notifications.where((n) => !n.isRead).length;
    final completed = todayVisits.where((v) => v.status == 'completed').length;
    final pending = todayVisits.length - completed;
    final attendance = data.todayAttendance;
    final working = attendance?.netWorkingDuration(now) ?? Duration.zero;
    final breaks = attendance?.breakDuration(now) ?? Duration.zero;
    final distance = todayVisits.fold<double>(
      0,
      (sum, visit) => sum + (visit.roadDistanceKm ?? 0),
    );
    final expenseEstimate = todayVisits.fold<double>(
      0,
      (sum, visit) => sum + (visit.travelCostEstimate ?? 0),
    );
    final organization = _OrganizationProjection.from(
      data.organization,
      data.user.uid,
      now,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < 420 ? 12.0 : 18.0;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(padding, 8, padding, 24),
          children: [
            _IdentityHeader(data: data, now: now, onReload: onReload),
            const SizedBox(height: 10),
            _SmartSummary(
              attendance: attendance != null,
              completedVisits: completed,
              distance: distance,
              unread: unread,
              organization: organization,
            ),
            const SizedBox(height: 10),
            _OperationsSection(
              title: 'Today Snapshot',
              icon: Icons.dashboard_outlined,
              initiallyExpanded: true,
              child: _MetricGrid(
                metrics: [
                  _Metric('Attendance', attendance?.status ?? 'Not started', Icons.badge_outlined, () => _push(context, const AttendanceScreen())),
                  _Metric('Working Hours', _duration(working), Icons.schedule, () => _push(context, const AttendanceScreen())),
                  _Metric("Today's Visits", '${todayVisits.length}', Icons.route_outlined, () => _push(context, const CustomerVisitScreen())),
                  _Metric('Pending Visits', '$pending', Icons.pending_actions_outlined, () => _push(context, const CustomerVisitScreen())),
                  _Metric('Completed Visits', '$completed', Icons.task_alt, () => _push(context, const CustomerVisitScreen())),
                  _Metric('Travel Distance', '${distance.toStringAsFixed(1)} km', Icons.alt_route, () => _push(context, const MapScreen())),
                  _Metric('Break Time', _duration(breaks), Icons.free_breakfast_outlined, () => _push(context, const AttendanceScreen())),
                  _Metric('Overtime', 'Not available', Icons.more_time, () => _unsupported(context, 'No approved working-hours or overtime policy exists.')),
                  _Metric('Notifications', '$unread unread', Icons.notifications_outlined, () => _push(context, const NotificationCenterScreen())),
                  _Metric('Approvals', 'Not available', Icons.approval_outlined, () => _unsupported(context, 'Approval backend is not available in Phase 1.')),
                  _Metric('Expense Summary', 'INR ${expenseEstimate.toStringAsFixed(0)} estimate', Icons.receipt_long_outlined, () => _push(context, const CustomerVisitScreen())),
                  _Metric('Pending Tasks', 'Not available', Icons.task_outlined, () => _unsupported(context, 'A task backend is not implemented.')),
                ],
              ),
            ),
            _OperationsSection(
              title: 'My Performance',
              icon: Icons.insights_outlined,
              initiallyExpanded: true,
              trailing: _RangeSelector(value: performanceRange, onChanged: onRangeChanged),
              child: _PerformanceGrid(
                data: data,
                now: now,
                range: performanceRange,
                organization: organization,
              ),
            ),
            _OperationsSection(
              title: 'My Operations',
              icon: Icons.work_outline,
              initiallyExpanded: true,
              child: _MyOperations(data: data, todayVisits: todayVisits, upcoming: upcoming),
            ),
            _OperationsSection(
              title: 'Organization Overview',
              icon: Icons.corporate_fare_outlined,
              initiallyExpanded: true,
              child: _OrganizationOverview(
                projection: organization,
                onViewAll: () =>
                    _push(context, const OrganizationAdminScreen()),
              ),
            ),
            _OperationsSection(
              title: 'Employee Directory',
              icon: Icons.groups_outlined,
              child: _EmployeeDirectoryPreview(
                projection: organization,
                onViewAll: () =>
                    _push(context, const OrganizationAdminScreen()),
              ),
            ),
            _OperationsSection(
              title: 'Organization Analytics',
              icon: Icons.analytics_outlined,
              child: _OrganizationAnalytics(
                projection: organization,
                onViewAll: () =>
                    _push(context, const OrganizationAdminScreen()),
              ),
            ),
            KeyedSubtree(
              key: settingsKey,
              child: _OperationsSection(
                title: 'Personal Settings',
                icon: Icons.tune,
                controller: settingsController,
                child: _PersonalSettings(data: data, onReload: onReload),
              ),
            ),
            _OperationsSection(
              title: 'Account Health',
              icon: Icons.health_and_safety_outlined,
              child: _AccountHealth(data: data),
            ),
            _OperationsSection(
              title: 'Admin Quick Actions',
              icon: Icons.admin_panel_settings_outlined,
              child: _AdminActions(
                onOpenSettings: () {
                  settingsController.expand();
                  final target = settingsKey.currentContext;
                  if (target != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (target.mounted) {
                        Scrollable.ensureVisible(
                          target,
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    });
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _IdentityHeader extends StatelessWidget {
  final ProfileOperationsSnapshot data;
  final DateTime now;
  final VoidCallback onReload;

  const _IdentityHeader({required this.data, required this.now, required this.onReload});

  @override
  Widget build(BuildContext context) {
    final user = data.user;
    final live = data.liveLocation;
    final isOnline = live != null && now.difference(live.updatedAt).inMinutes <= 10;
    final visit = data.visits.where((v) => v.status == 'checked_in').firstOrNull;
    final duty = _dutyStatus(data.todayAttendance?.status, visit != null);
    final completion = _profileCompletion(user);
    final lastSync = <DateTime>[
      data.loadedAt,
      if (live != null) live.updatedAt,
      ...data.visits.map((v) => v.updatedAt),
    ].reduce((a, b) => a.isAfter(b) ? a : b);

    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(name: user.name, url: user.profileImage),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name.isEmpty ? 'Employee' : user.name, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22, letterSpacing: 0)),
                    const SizedBox(height: 4),
                    Text(user.email, style: Theme.of(context).textTheme.bodySmall?.copyWith(letterSpacing: 0)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        PremiumStatusChip(label: duty, color: duty == 'Off Duty' ? AppColors.textDisabled : AppColors.success),
                        PremiumStatusChip(label: isOnline ? 'Online' : 'Offline', color: isOnline ? AppColors.online : AppColors.offline),
                        PremiumStatusChip(label: data.locationPermission.serviceEnabled ? 'GPS On' : 'GPS Off', color: data.locationPermission.serviceEnabled ? AppColors.info : AppColors.warning),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit profile details',
                onPressed: () => _editProfileDetails(context, user, onReload),
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoGrid(items: [
            ('Employee ID', user.employeeCode.trim().isEmpty ? user.uid : user.employeeCode),
            ('Role', user.role.isEmpty ? 'Not configured' : user.role),
            ('Designation', _configured(user.designation)),
            ('Department', _configured(user.department)),
            ('Branch', _configured(user.branch)),
            ('Reporting Manager', _configured(user.reportingManager)),
            ('Joining Date', user.joiningDate == null ? 'Not configured' : _dateOnly(user.joiningDate!)),
            ('Experience', _experience(user.joiningDate, now)),
            ('Emergency', _configured(user.emergencyContact)),
            ('Blood Group', _configured(user.bloodGroup)),
            ('Skills', user.skills.isEmpty ? 'Not configured' : user.skills.join(', ')),
            ('Certifications', user.certifications.isEmpty ? 'Not configured' : '${user.certifications.length}'),
            ('Current Status', duty),
            ('Current Visit', visit == null ? 'No active visit' : visit.customerName),
            ('Profile Completion', '$completion%'),
            ('Last Sync', _dateTime(lastSync)),
          ]),
        ],
      ),
    );
  }
}

class _SmartSummary extends StatelessWidget {
  final bool attendance;
  final int completedVisits;
  final double distance;
  final int unread;
  final _OrganizationProjection organization;

  const _SmartSummary({
    required this.attendance,
    required this.completedVisits,
    required this.distance,
    required this.unread,
    required this.organization,
  });

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      attendance ? 'Attendance is active today.' : 'Attendance has not started today.',
      'Completed $completedVisits visit${completedVisits == 1 ? '' : 's'} today.',
      'Planned travel is ${distance.toStringAsFixed(1)} km.',
      '$unread unread notification${unread == 1 ? '' : 's'}.',
      if (organization.topBranch != null)
        '${organization.topBranch} has the highest branch productivity today.',
    ];
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumIconChip(icon: Icons.auto_awesome_outlined, color: AppColors.info),
          const SizedBox(width: 12),
          Expanded(child: Text(lines.join('  •  '), style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45, letterSpacing: 0))),
        ],
      ),
    );
  }
}

class _OperationsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final bool initiallyExpanded;
  final Widget? trailing;
  final ExpansibleController? controller;

  const _OperationsSection({required this.title, required this.icon, required this.child, this.initiallyExpanded = false, this.trailing, this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: AppColors.transparent),
        child: PremiumCard(
          padding: EdgeInsets.zero,
          child: ExpansionTile(
            controller: controller,
            initiallyExpanded: initiallyExpanded,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            leading: Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
            title: Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0)),
            trailing: trailing ?? const Icon(Icons.expand_more, size: 20),
            children: [const Divider(height: 12), child],
          ),
        ),
      ),
    );
  }
}

class _Metric {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  const _Metric(this.label, this.value, this.icon, this.onTap);
}

class _MetricGrid extends StatelessWidget {
  final List<_Metric> metrics;
  const _MetricGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900 ? 4 : constraints.maxWidth >= 560 ? 3 : 2;
      final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: metrics.map((metric) => SizedBox(width: width, child: _MetricTile(metric: metric))).toList(),
      );
    });
  }
}

class _MetricTile extends StatelessWidget {
  final _Metric metric;
  const _MetricTile({required this.metric});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: metric.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 82),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(border: Border.all(color: colors.outlineVariant), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(metric.icon, size: 18, color: colors.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(metric.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14, letterSpacing: 0)),
            const SizedBox(height: 2),
            Text(metric.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11, letterSpacing: 0)),
          ]),
        ),
      ),
    );
  }
}

enum _PerformanceRange { today, week, month }

class _RangeSelector extends StatelessWidget {
  final _PerformanceRange value;
  final ValueChanged<_PerformanceRange> onChanged;
  const _RangeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_PerformanceRange>(
      segments: const [
        ButtonSegment(value: _PerformanceRange.today, label: Text('D')),
        ButtonSegment(value: _PerformanceRange.week, label: Text('W')),
        ButtonSegment(value: _PerformanceRange.month, label: Text('M')),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
    );
  }
}

class _PerformanceGrid extends StatelessWidget {
  final ProfileOperationsSnapshot data;
  final DateTime now;
  final _PerformanceRange range;
  final _OrganizationProjection organization;
  const _PerformanceGrid({
    required this.data,
    required this.now,
    required this.range,
    required this.organization,
  });

  @override
  Widget build(BuildContext context) {
    final start = switch (range) {
      _PerformanceRange.today => DateTime(now.year, now.month, now.day),
      _PerformanceRange.week => DateTime(now.year, now.month, now.day - 6),
      _PerformanceRange.month => DateTime(now.year, now.month),
    };
    final endExclusive = now.add(const Duration(days: 1));
    final previousStart = switch (range) {
      _PerformanceRange.today => DateTime(now.year, now.month, now.day - 1),
      _PerformanceRange.week => DateTime(now.year, now.month, now.day - 13),
      _PerformanceRange.month => DateTime(now.year, now.month - 1),
    };
    final attendance = data.attendance.where((r) => r.date != null && !r.date!.isBefore(start) && r.date!.isBefore(endExclusive)).toList();
    final visits = data.visits.where((v) => !_visitDate(v).isBefore(start) && _visitDate(v).isBefore(endExclusive)).toList();
    final completed = visits.where((v) => v.status == 'completed').length;
    final completion = visits.isEmpty ? 0.0 : completed / visits.length;
    final present = attendance.where((r) => r.checkInTime != null).length;
    final attendanceRate = attendance.isEmpty ? 0.0 : present / attendance.length;
    final gpsEligible = visits.where((v) => v.checkInTime != null || v.checkOutTime != null).toList();
    final gpsComplete = gpsEligible.where((v) => v.checkInLatitude != null && v.checkOutLatitude != null).length;
    final gps = gpsEligible.isEmpty ? 0.0 : gpsComplete / gpsEligible.length;
    final productivity = _personalScore(
      data: data,
      start: start,
      endExclusive: endExclusive,
    );
    final previousScore = _personalScore(
      data: data,
      start: previousStart,
      endExclusive: start,
    );
    final trend = productivity - previousScore;
    final working = attendance.fold<Duration>(
      Duration.zero,
      (sum, record) => sum + record.netWorkingDuration(now),
    );
    final monthStart = DateTime(now.year, now.month);
    final quarterStart = DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1);
    final yearStart = DateTime(now.year);
    return _MetricGrid(metrics: [
      _Metric('Attendance', '${(attendanceRate * 100).round()}%', Icons.event_available_outlined, () => _push(context, const AttendanceScreen())),
      _Metric('Visit Completion', '${(completion * 100).round()}%', Icons.task_alt, () => _push(context, const CustomerVisitScreen())),
      _Metric('Productivity', '$productivity% ${_trend(trend)}', Icons.speed, () => _push(context, const ReportsScreen())),
      _Metric('Working Hours', _duration(working), Icons.schedule, () => _push(context, const AttendanceScreen())),
      _Metric('Punctuality', 'Not available', Icons.alarm_on_outlined, () => _unsupported(context, 'Shift schedule data is not available.')),
      _Metric('GPS Compliance', '${(gps * 100).round()}%', Icons.gps_fixed, () => _push(context, const MapScreen())),
      _Metric('Travel Efficiency', 'Not available', Icons.route, () => _unsupported(context, 'Actual route distance is not stored for comparison.')),
      _Metric('Monthly Performance', '${_personalScore(data: data, start: monthStart, endExclusive: now.add(const Duration(days: 1)))}%', Icons.calendar_month_outlined, () => _push(context, const ReportsScreen())),
      _Metric('Quarterly Performance', '${_personalScore(data: data, start: quarterStart, endExclusive: now.add(const Duration(days: 1)))}%', Icons.date_range_outlined, () => _push(context, const ReportsScreen())),
      _Metric('Yearly Performance', '${_personalScore(data: data, start: yearStart, endExclusive: now.add(const Duration(days: 1)))}%', Icons.insights_outlined, () => _push(context, const ReportsScreen())),
      _Metric('Company Rank', _rankLabel(organization.companyRank, organization.employees.length), Icons.emoji_events_outlined, () => _push(context, const OrganizationAdminScreen())),
      _Metric('Branch Rank', _rankLabel(organization.branchRank, organization.branchPeerCount), Icons.account_tree_outlined, () => _push(context, const OrganizationAdminScreen())),
      _Metric('Department Rank', _rankLabel(organization.departmentRank, organization.departmentPeerCount), Icons.domain_outlined, () => _push(context, const OrganizationAdminScreen())),
    ]);
  }
}

class _MyOperations extends StatelessWidget {
  final ProfileOperationsSnapshot data;
  final List<CustomerVisitModel> todayVisits;
  final List<CustomerVisitModel> upcoming;
  const _MyOperations({required this.data, required this.todayVisits, required this.upcoming});

  @override
  Widget build(BuildContext context) {
    final active = todayVisits.where((v) => v.status == 'checked_in').firstOrNull;
    final recent = _activities(data).take(4).toList();
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final carryForward = data.visits.where((visit) =>
        _visitDate(visit).isBefore(todayStart) && visit.status != 'completed').length;
    final currentActivity = active == null
        ? (recent.firstOrNull?.title ?? 'No current activity')
        : 'Visit • ${active.customerName}';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _MetricGrid(metrics: [
        _Metric("Today's Visits", '${todayVisits.length}', Icons.route_outlined, () => _push(context, const CustomerVisitScreen())),
        _Metric('Upcoming', '${upcoming.length}', Icons.upcoming_outlined, () => _push(context, const CustomerVisitScreen())),
        _Metric('Carry Forward', '$carryForward', Icons.redo, () => _push(context, const CustomerVisitScreen())),
        _Metric("Today's Attendance", data.todayAttendance?.status ?? 'Not started', Icons.fact_check_outlined, () => _push(context, const AttendanceScreen())),
        _Metric('Current Duty', active == null ? (data.todayAttendance?.status ?? 'Off Duty') : 'Customer Visit', Icons.work_history_outlined, () => active == null ? _push(context, const AttendanceScreen()) : _push(context, CustomerVisitDetailScreen(visit: active))),
        _Metric('Current Activity', currentActivity, Icons.timeline_outlined, () => active == null ? _push(context, const AttendanceScreen()) : _push(context, CustomerVisitDetailScreen(visit: active))),
        _Metric('Current Location', data.liveLocation == null ? 'Unavailable' : '${data.liveLocation!.latitude.toStringAsFixed(4)}, ${data.liveLocation!.longitude.toStringAsFixed(4)}', Icons.my_location, () => _push(context, const MapScreen())),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: () => active == null ? _push(context, const CustomerVisitScreen()) : _push(context, CustomerVisitDetailScreen(visit: active)), icon: const Icon(Icons.open_in_new, size: 17), label: const Text('Open Visit'))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: () => _push(context, const AttendanceScreen()), icon: const Icon(Icons.badge_outlined, size: 17), label: const Text('Attendance'))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: () => _push(context, const MapScreen()), icon: const Icon(Icons.my_location, size: 17), label: const Text('Locate Me'))),
      ]),
      const SizedBox(height: 10),
      _PreviewList(items: recent.map((a) => (a.title, _dateTime(a.time), a.icon)).toList(), empty: 'No recent operational activity.'),
      const Divider(height: 18),
      _CompactPreviewHeader(
        title: 'Recent Notifications',
        onViewAll: () => _push(context, const NotificationCenterScreen()),
      ),
      _PreviewList(
        items: data.notifications
            .take(3)
            .map((item) => (item.title, _dateTime(item.createdAt), Icons.notifications_outlined))
            .toList(),
        empty: 'No recent notifications.',
      ),
      _CompactPreviewHeader(
        title: 'Recent Complaints',
        onViewAll: () => _push(context, const ComplaintRegisterScreen()),
      ),
      _PreviewList(
        items: data.complaints
            .take(3)
            .map((item) => (item.customerName, item.status, Icons.support_agent_outlined))
            .toList(),
        empty: 'No recent complaints.',
      ),
      const _UnsupportedDomain(
        title: 'Recent Tasks unavailable',
        message: 'No approved task model or service exists. Profile does not create a substitute task collection.',
      ),
    ]);
  }
}

class _OrganizationOverview extends StatelessWidget {
  final _OrganizationProjection projection;
  final VoidCallback onViewAll;

  const _OrganizationOverview({
    required this.projection,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetricGrid(metrics: [
          _Metric('Total Employees', '${projection.employees.length}', Icons.groups_outlined, onViewAll),
          _Metric('Present', '${projection.present}', Icons.how_to_reg_outlined, onViewAll),
          _Metric('Absent', '${projection.absent}', Icons.person_off_outlined, onViewAll),
          _Metric('Leave', '${projection.leave}', Icons.event_busy_outlined, onViewAll),
          _Metric('On Visit', '${projection.onVisit}', Icons.route_outlined, onViewAll),
          _Metric('Travelling', '${projection.travelling}', Icons.alt_route, onViewAll),
          _Metric('Drivers', '${projection.drivers}', Icons.local_shipping_outlined, onViewAll),
          _Metric('Office Staff', '${projection.officeStaff}', Icons.desk_outlined, onViewAll),
          _Metric('Managers', '${projection.managers}', Icons.supervisor_account_outlined, onViewAll),
          _Metric('Branches', '${projection.branchScores.length}', Icons.account_tree_outlined, onViewAll),
          _Metric('Departments', '${projection.departmentScores.length}', Icons.domain_outlined, onViewAll),
          _Metric('Pending Approvals', 'Not available', Icons.approval_outlined, () => _unsupported(context, 'No approval model or service exists.')),
        ]),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onViewAll,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('View Organization'),
          ),
        ),
      ],
    );
  }
}

class _EmployeeDirectoryPreview extends StatelessWidget {
  final _OrganizationProjection projection;
  final VoidCallback onViewAll;

  const _EmployeeDirectoryPreview({
    required this.projection,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (projection.employees.isEmpty) {
      return PremiumEmptyState(
        icon: Icons.person_search_outlined,
        title: 'No employees',
        message: 'The existing users collection has no directory entries.',
        actionLabel: 'Retry in Organization',
        onAction: onViewAll,
      );
    }
    final rows = projection.employees.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 38,
            dataRowMinHeight: 44,
            dataRowMaxHeight: 52,
            columns: const [
              DataColumn(label: Text('Employee')),
              DataColumn(label: Text('Department')),
              DataColumn(label: Text('Designation')),
              DataColumn(label: Text('Branch')),
              DataColumn(label: Text('Attendance')),
              DataColumn(label: Text('Visit')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Phone')),
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('Performance')),
              DataColumn(label: Text('Location')),
            ],
            rows: rows
                .map(
                  (row) => DataRow(
                    onSelectChanged: (_) => onViewAll(),
                    cells: [
                      DataCell(Text(_configured(row.user.name))),
                      DataCell(Text(_configured(row.user.department))),
                      DataCell(Text(_configured(row.user.designation))),
                      DataCell(Text(_configured(row.user.branch))),
                      DataCell(Text(row.attendance?.status ?? 'No record')),
                      DataCell(Text(row.activeVisit ? 'Active' : 'None')),
                      DataCell(Text(row.status)),
                      DataCell(Text(_configured(row.user.phone))),
                      DataCell(Text(_configured(row.user.email))),
                      DataCell(Text('${row.score}%')),
                      DataCell(Icon(row.hasLocation ? Icons.location_on : Icons.location_off, size: 17)),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onViewAll,
            child: Text('Search, filter, sort and paginate all ${projection.employees.length} employees'),
          ),
        ),
      ],
    );
  }
}

class _OrganizationAnalytics extends StatelessWidget {
  final _OrganizationProjection projection;
  final VoidCallback onViewAll;

  const _OrganizationAnalytics({
    required this.projection,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetricGrid(metrics: [
          _Metric('Attendance', '${projection.attendanceRate}%', Icons.event_available_outlined, onViewAll),
          _Metric('Visit Completion', '${projection.visitCompletion}%', Icons.task_alt, onViewAll),
          _Metric('Productivity', '${projection.averageProductivity}%', Icons.speed, onViewAll),
          _Metric('Travel', '${projection.travelDistance.toStringAsFixed(1)} km', Icons.alt_route, onViewAll),
          _Metric('Working Hours', _duration(projection.workingTime), Icons.schedule, onViewAll),
        ]),
        const SizedBox(height: 12),
        _ComparisonBars(title: 'Branch Comparison', values: projection.branchScores),
        const SizedBox(height: 12),
        _ComparisonBars(title: 'Department Comparison', values: projection.departmentScores),
        const SizedBox(height: 12),
        Text('Top Engineers', style: AppTextStyles.bodyLarge),
        ...projection.employees.take(5).map(
          (employee) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.emoji_events_outlined, size: 18),
            title: Text(_configured(employee.user.name)),
            subtitle: Text('${employee.completedVisits} completed visits'),
            trailing: Text('${employee.score}%'),
            onTap: onViewAll,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: onViewAll, child: const Text('View Analytics')),
        ),
      ],
    );
  }
}

class _ComparisonBars extends StatelessWidget {
  final String title;
  final Map<String, int> values;

  const _ComparisonBars({required this.title, required this.values});

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.take(5).toList();
    if (entries.isEmpty) {
      return _UnsupportedDomain(
        title: '$title unavailable',
        message: 'Employee profiles do not yet contain enough grouping data.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.bodyLarge),
        const SizedBox(height: 8),
        ...entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              children: [
                SizedBox(
                  width: 105,
                  child: Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: entry.value / 100,
                      minHeight: 7,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(width: 34, child: Text('${entry.value}%')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactPreviewHeader extends StatelessWidget {
  final String title;
  final VoidCallback onViewAll;

  const _CompactPreviewHeader({required this.title, required this.onViewAll});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14))),
          TextButton(onPressed: onViewAll, child: const Text('View All')),
        ],
      );

}

class _OrganizationProjection {
  final List<_OrganizationEmployee> employees;
  final int present;
  final int absent;
  final int leave;
  final int onVisit;
  final int travelling;
  final int drivers;
  final int officeStaff;
  final int managers;
  final int attendanceRate;
  final int visitCompletion;
  final int averageProductivity;
  final double travelDistance;
  final Duration workingTime;
  final Map<String, int> branchScores;
  final Map<String, int> departmentScores;
  final String? topBranch;
  final int? companyRank;
  final int? branchRank;
  final int? departmentRank;
  final int branchPeerCount;
  final int departmentPeerCount;

  const _OrganizationProjection({
    required this.employees,
    required this.present,
    required this.absent,
    required this.leave,
    required this.onVisit,
    required this.travelling,
    required this.drivers,
    required this.officeStaff,
    required this.managers,
    required this.attendanceRate,
    required this.visitCompletion,
    required this.averageProductivity,
    required this.travelDistance,
    required this.workingTime,
    required this.branchScores,
    required this.departmentScores,
    required this.topBranch,
    required this.companyRank,
    required this.branchRank,
    required this.departmentRank,
    required this.branchPeerCount,
    required this.departmentPeerCount,
  });

  factory _OrganizationProjection.from(
    OrganizationOperationsSnapshot data,
    String currentUserId,
    DateTime now,
  ) {
    final attendanceByUser = <String, AttendanceModel>{
      for (final attendance in data.attendance) attendance.userId: attendance,
    };
    final visitsByUser = <String, List<CustomerVisitModel>>{};
    for (final visit in data.visits) {
      visitsByUser.putIfAbsent(visit.userId, () => []).add(visit);
    }
    final locationIds = data.liveLocations.map((item) => item.userId).toSet();
    final employees = data.employees
        .map(
          (user) => _OrganizationEmployee(
            user: user,
            attendance: attendanceByUser[user.uid],
            visits: visitsByUser[user.uid] ?? const <CustomerVisitModel>[],
            hasLocation: locationIds.contains(user.uid),
          ),
        )
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final completed = employees.fold<int>(0, (sum, item) => sum + item.completedVisits);
    final totalVisits = employees.fold<int>(0, (sum, item) => sum + item.visits.length);
    final present = employees.where((item) => item.attendance?.checkInTime != null).length;
    final groupBranches = _groupScores(employees, (item) => item.user.branch);
    final groupDepartments = _groupScores(employees, (item) => item.user.department);
    final current = employees.where((item) => item.user.uid == currentUserId).firstOrNull;
    final branchPeers = current == null || current.user.branch.trim().isEmpty
        ? const <_OrganizationEmployee>[]
        : employees.where((item) => item.user.branch == current.user.branch).toList();
    final departmentPeers = current == null || current.user.department.trim().isEmpty
        ? const <_OrganizationEmployee>[]
        : employees.where((item) => item.user.department == current.user.department).toList();
    return _OrganizationProjection(
      employees: employees,
      present: present,
      absent: employees.where((item) => item.status == 'Absent').length,
      leave: employees.where((item) => item.status == 'Leave').length,
      onVisit: employees.where((item) => item.activeVisit).length,
      travelling: employees.where((item) => item.status == 'Travelling').length,
      drivers: employees.where((item) => item.user.role.toLowerCase().contains('driver')).length,
      officeStaff: employees.where((item) {
        final role = item.user.role.toLowerCase();
        return !role.contains('driver') && !role.contains('manager');
      }).length,
      managers: employees.where((item) => item.user.role.toLowerCase().contains('manager')).length,
      attendanceRate: employees.isEmpty ? 0 : (present / employees.length * 100).round(),
      visitCompletion: totalVisits == 0 ? 0 : (completed / totalVisits * 100).round(),
      averageProductivity: employees.isEmpty
          ? 0
          : (employees.fold<int>(0, (sum, item) => sum + item.score) / employees.length).round(),
      travelDistance: employees.fold<double>(0, (sum, item) => sum + item.travelDistance),
      workingTime: employees.fold<Duration>(
        Duration.zero,
        (sum, item) => sum + (item.attendance?.netWorkingDuration(now) ?? Duration.zero),
      ),
      branchScores: groupBranches,
      departmentScores: groupDepartments,
      topBranch: groupBranches.isEmpty ? null : groupBranches.keys.first,
      companyRank: current == null ? null : employees.indexOf(current) + 1,
      branchRank: current == null ? null : _peerRank(branchPeers, current),
      departmentRank: current == null ? null : _peerRank(departmentPeers, current),
      branchPeerCount: branchPeers.length,
      departmentPeerCount: departmentPeers.length,
    );
  }
}

class _OrganizationEmployee {
  final UserModel user;
  final AttendanceModel? attendance;
  final List<CustomerVisitModel> visits;
  final bool hasLocation;
  final int score;

  _OrganizationEmployee({
    required this.user,
    required this.attendance,
    required this.visits,
    required this.hasLocation,
  }) : score = _employeeScore(attendance, visits);

  bool get activeVisit => visits.any((visit) => visit.status == 'checked_in');
  int get completedVisits => visits.where((visit) => visit.status == 'completed').length;
  double get travelDistance => visits.fold<double>(0, (sum, visit) => sum + (visit.roadDistanceKm ?? 0));

  String get status {
    if (activeVisit) return 'On Visit';
    final normalized = attendance?.status.toLowerCase() ?? '';
    if (normalized.contains('leave')) return 'Leave';
    if (normalized.contains('travel')) return 'Travelling';
    if (attendance?.isOnBreak == true) return 'On Break';
    if (attendance?.isCheckedIn == true) return 'On Duty';
    if (attendance?.isCheckedOut == true) return 'Completed';
    return 'Absent';
  }
}

class _UnsupportedDomain extends StatelessWidget {
  final String title;
  final String message;
  const _UnsupportedDomain({required this.title, required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.warning.withAlpha(12), border: Border.all(color: AppColors.warning.withAlpha(65)), borderRadius: BorderRadius.circular(12)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppTextStyles.bodyLarge.copyWith(fontSize: 14)), const SizedBox(height: 4), Text(message, style: AppTextStyles.caption.copyWith(height: 1.4, letterSpacing: 0))])),
    ]),
  );
}

class _PersonalSettings extends StatelessWidget {
  final ProfileOperationsSnapshot data;
  final VoidCallback onReload;
  const _PersonalSettings({required this.data, required this.onReload});

  @override
  Widget build(BuildContext context) {
    final prefs = data.notificationPreferences;
    return Column(children: [
      _SettingTile(icon: Icons.phone_outlined, title: 'Phone', subtitle: data.user.phone.isEmpty ? 'Add phone number' : data.user.phone, onTap: () => _editPhone(context, data.user.phone, onReload)),
      _SettingTile(icon: Icons.email_outlined, title: 'Email', subtitle: data.user.email, onTap: () => _unsupported(context, 'Email changes require Firebase Authentication reauthentication and are not safely supported by the current auth flow.')),
      _SettingTile(icon: Icons.emergency_outlined, title: 'Emergency Contact', subtitle: _configured(data.user.emergencyContact), onTap: () => _editProfileDetails(context, data.user, onReload)),
      _SettingTile(icon: Icons.language, title: 'Language', subtitle: data.user.language == 'system' ? 'System default' : data.user.language.toUpperCase(), onTap: () => _selectStoredPreference(context: context, title: 'Language preference', current: data.user.language, values: const ['system', 'en', 'hi'], field: 'language', onReload: onReload, note: 'The preference is stored. Full runtime localization remains TODO because translation resources do not exist.')),
      _SettingTile(icon: Icons.palette_outlined, title: 'Theme', subtitle: data.user.themeMode, onTap: () => _selectTheme(context, data.user.themeMode, onReload)),
      SwitchListTile.adaptive(dense: true, contentPadding: EdgeInsets.zero, title: const Text('In-app notifications'), subtitle: const Text('Firestore-backed notification preference'), value: prefs.localInAppNotifications, onChanged: (value) => _updatePrefs(context, prefs.copyWith(localInAppNotifications: value), onReload)),
      SwitchListTile.adaptive(dense: true, contentPadding: EdgeInsets.zero, title: const Text('Attendance reminders'), value: prefs.attendanceReminders, onChanged: (value) => _updatePrefs(context, prefs.copyWith(attendanceReminders: value), onReload)),
      SwitchListTile.adaptive(dense: true, contentPadding: EdgeInsets.zero, title: const Text('Visit alerts'), value: prefs.visitAlerts, onChanged: (value) => _updatePrefs(context, prefs.copyWith(visitAlerts: value), onReload)),
      _SettingTile(icon: Icons.gps_fixed, title: 'GPS Preferences', subtitle: data.locationPermission.message, onTap: ProfileController.openLocationSettings),
      _SettingTile(icon: Icons.high_quality_outlined, title: 'Location Accuracy', subtitle: data.user.locationAccuracy, onTap: () => _selectStoredPreference(context: context, title: 'Location accuracy preference', current: data.user.locationAccuracy, values: const ['low', 'balanced', 'high', 'best'], field: 'locationAccuracy', onReload: onReload, note: 'The preference is stored. Existing tracking services retain their approved accuracy policy until centrally integrated.')),
      _SettingTile(icon: Icons.privacy_tip_outlined, title: 'Privacy & Permissions', subtitle: 'Open application settings', onTap: ProfileController.openAppSettings),
      _SettingTile(icon: Icons.lock_reset, title: 'Change Password', subtitle: 'Send a secure reset email', onTap: () => _resetPassword(context)),
      _SettingTile(icon: Icons.logout, title: 'Logout', subtitle: 'End this session', destructive: true, onTap: () => _logout(context)),
    ]);
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final FutureOr<void> Function() onTap;
  final bool destructive;
  const _SettingTile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.destructive = false});
  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, size: 20, color: destructive ? AppColors.error : Theme.of(context).colorScheme.onSurfaceVariant),
    title: Text(title, style: TextStyle(color: destructive ? AppColors.error : null)),
    subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
    trailing: const Icon(Icons.chevron_right, size: 18),
    onTap: () async => onTap(),
  );
}

class _AccountHealth extends StatelessWidget {
  final ProfileOperationsSnapshot data;
  const _AccountHealth({required this.data});
  @override
  Widget build(BuildContext context) {
    final completion = _profileCompletion(data.user);
    final missingFields = _missingProfileFields(data.user);
    final missing = missingFields.length;
    final missingContacts = [data.user.phone, data.user.emergencyContact]
        .where((value) => value.trim().isEmpty)
        .length;
    final notificationEnabled = data.notificationPreferences.localInAppNotifications;
    return _MetricGrid(metrics: [
      _Metric('Profile Completion', '$completion%', Icons.person_search_outlined, () {}),
      _Metric('Missing Fields', '$missing', Icons.rule_outlined, () => _unsupported(context, missingFields.isEmpty ? 'No required profile fields are missing.' : 'Missing: ${missingFields.join(', ')}.')),
      _Metric('Missing Contacts', '$missingContacts', Icons.contact_phone_outlined, () => _unsupported(context, missingContacts == 0 ? 'Phone and emergency contact are complete.' : 'Complete phone and emergency contact details.')),
      _Metric('GPS Enabled', data.locationPermission.serviceEnabled ? 'Yes' : 'No', Icons.gps_fixed, ProfileController.openLocationSettings),
      _Metric('Notifications', notificationEnabled ? 'Enabled' : 'Disabled', Icons.notifications_active_outlined, () => _push(context, const NotificationCenterScreen())),
      _Metric('Location Permission', data.locationPermission.permissionStatus, Icons.location_searching, ProfileController.openAppSettings),
      _Metric('Theme', data.user.themeMode, Icons.palette_outlined, () {}),
      _Metric('Language', data.user.language, Icons.language, () {}),
      _Metric('Last Successful Sync', _dateTime(data.loadedAt), Icons.cloud_done_outlined, () {}),
      _Metric('Security', 'Firebase Auth active', Icons.verified_user_outlined, () => _resetPassword(context)),
    ]);
  }
}

String _dutyStatus(String? attendanceStatus, bool inVisit) {
  if (inVisit) return 'In Visit';
  final normalized = attendanceStatus?.trim().toLowerCase() ?? '';
  if (normalized.contains('break')) return 'On Break';
  if (normalized.contains('travel')) return 'Travelling';
  if (normalized.contains('leave')) return 'Leave';
  if (normalized.contains('checked in') || normalized.contains('on duty')) {
    return 'On Duty';
  }
  return 'Off Duty';
}

class _AdminActions extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const _AdminActions({required this.onOpenSettings});
  @override
  Widget build(BuildContext context) => _MetricGrid(metrics: [
    _Metric('Attendance', 'Open', Icons.fact_check_outlined, () => _push(context, const AttendanceScreen())),
    _Metric('Visits', 'Open', Icons.route_outlined, () => _push(context, const CustomerVisitScreen())),
    _Metric('Map', 'Open', Icons.map_outlined, () => _push(context, const MapScreen())),
    _Metric('Complaints', 'Open', Icons.support_agent_outlined, () => _push(context, const ComplaintRegisterScreen())),
    _Metric('Employees', 'Open', Icons.groups_outlined, () => _push(context, const OrganizationAdminScreen())),
    _Metric('Organization', 'Phase 2', Icons.corporate_fare_outlined, () => _push(context, const OrganizationAdminScreen())),
    _Metric('Reports', 'Open', Icons.summarize_outlined, () => _push(context, const ReportsScreen())),
    _Metric('Analytics', 'Open', Icons.analytics_outlined, () => _push(context, const ReportsScreen())),
    _Metric('Notifications', 'Open', Icons.notifications_outlined, () => _push(context, const NotificationCenterScreen())),
    _Metric('Settings', 'Open', Icons.settings_outlined, onOpenSettings),
  ]);
}

class _InfoGrid extends StatelessWidget {
  final List<(String, String)> items;
  const _InfoGrid({required this.items});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final columns = constraints.maxWidth >= 700 ? 4 : constraints.maxWidth >= 430 ? 3 : 2;
    final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
    return Wrap(spacing: 8, runSpacing: 8, children: items.map((item) => SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.$1, style: AppTextStyles.caption.copyWith(fontSize: 10)), const SizedBox(height: 2), Text(item.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyMedium.copyWith(fontSize: 12, fontWeight: FontWeight.w600))]))).toList());
  });
}

class _PreviewList extends StatelessWidget {
  final List<(String, String, IconData)> items;
  final String empty;
  const _PreviewList({required this.items, required this.empty});
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return Text(empty, style: AppTextStyles.caption);
    return Column(children: items.map((item) => ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(item.$3, size: 18), title: Text(item.$1, maxLines: 1, overflow: TextOverflow.ellipsis), trailing: Text(item.$2, style: AppTextStyles.caption))).toList());
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String url;
  const _Avatar({required this.name, required this.url});
  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: 34,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      foregroundImage: url.trim().isEmpty ? null : NetworkImage(url),
      child: Text(initial, style: AppTextStyles.headingMedium),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
    padding: const EdgeInsets.all(16),
    children: List.generate(6, (index) => Container(
      height: index == 0 ? 210 : 96,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(18), border: Border.all(color: colors.outlineVariant)),
      child: const LinearProgressIndicator(minHeight: 2, backgroundColor: AppColors.transparent),
    )),
  );
  }
}

class _ActivityItem {
  final String title;
  final DateTime time;
  final IconData icon;
  const _ActivityItem(this.title, this.time, this.icon);
}

List<_ActivityItem> _activities(ProfileOperationsSnapshot data) {
  final result = <_ActivityItem>[];
  for (final record in data.attendance) {
    if (record.checkInTime != null) result.add(_ActivityItem('Attendance checked in', record.checkInTime!, Icons.login));
    if (record.breakStartTime != null) result.add(_ActivityItem('Break started', record.breakStartTime!, Icons.free_breakfast_outlined));
    if (record.checkOutTime != null) result.add(_ActivityItem('Attendance checked out', record.checkOutTime!, Icons.logout));
  }
  for (final visit in data.visits) {
    result.add(_ActivityItem('Visit assigned • ${visit.customerName}', visit.assignedAt ?? visit.createdAt, Icons.assignment_ind_outlined));
    if (visit.checkInTime != null) result.add(_ActivityItem('Visit opened • ${visit.customerName}', visit.checkInTime!, Icons.pin_drop_outlined));
    if (visit.completedAt != null) result.add(_ActivityItem('Visit completed • ${visit.customerName}', visit.completedAt!, Icons.task_alt));
  }
  for (final notification in data.notifications) {
    result.add(_ActivityItem('Notification • ${notification.title}', notification.createdAt, Icons.notifications_outlined));
  }
  for (final complaint in data.complaints) {
    result.add(_ActivityItem('Complaint • ${complaint.customerName}', complaint.createdAt, Icons.support_agent_outlined));
  }
  result.sort((a, b) => b.time.compareTo(a.time));
  return result;
}

class _PhoneEditDialog extends StatefulWidget {
  final String current;

  const _PhoneEditDialog({required this.current});

  @override
  State<_PhoneEditDialog> createState() => _PhoneEditDialogState();
}

class _PhoneEditDialogState extends State<_PhoneEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.current);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update phone'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.phone,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Phone number'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ProfileDetailsDialog extends StatefulWidget {
  final UserModel user;

  const _ProfileDetailsDialog({required this.user});

  @override
  State<_ProfileDetailsDialog> createState() => _ProfileDetailsDialogState();
}

class _ProfileDetailsDialogState extends State<_ProfileDetailsDialog> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _controllers = <String, TextEditingController>{
      'name': TextEditingController(text: user.name),
      'phone': TextEditingController(text: user.phone),
      'employeeCode': TextEditingController(text: user.employeeCode),
      'department': TextEditingController(text: user.department),
      'designation': TextEditingController(text: user.designation),
      'branch': TextEditingController(text: user.branch),
      'reportingManager': TextEditingController(text: user.reportingManager),
      'joiningDate': TextEditingController(
        text: user.joiningDate == null ? '' : _isoDate(user.joiningDate!),
      ),
      'emergencyContact': TextEditingController(text: user.emergencyContact),
      'bloodGroup': TextEditingController(text: user.bloodGroup),
      'skills': TextEditingController(text: user.skills.join(', ')),
      'certifications': TextEditingController(
        text: user.certifications.join(', '),
      ),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    Navigator.pop(
      context,
      _controllers.map((key, controller) => MapEntry(key, controller.text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Profile details'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final entry in _controllers.entries)
                SizedBox(
                  width: entry.key == 'skills' ||
                          entry.key == 'certifications'
                      ? 590
                      : 285,
                  child: TextField(
                    controller: entry.value,
                    decoration: InputDecoration(
                      labelText: _fieldLabel(entry.key),
                      helperText: entry.key == 'joiningDate'
                          ? 'YYYY-MM-DD'
                          : entry.key == 'skills' ||
                                  entry.key == 'certifications'
                              ? 'Comma separated'
                              : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

Future<void> _updatePrefs(BuildContext context, NotificationPreferencesModel prefs, VoidCallback reload) async {
  try { await ProfileController.updateNotificationPreferences(prefs); reload(); } catch (error) { if (context.mounted) _unsupported(context, '$error'); }
}

Future<void> _editPhone(BuildContext context, String current, VoidCallback reload) async {
  final value = await showDialog<String>(
    context: context,
    builder: (_) => _PhoneEditDialog(current: current),
  );
  if (value == null) return;
  try { await ProfileController.updatePhone(value); reload(); } catch (error) { if (context.mounted) _unsupported(context, '$error'); }
}

Future<void> _editProfileDetails(
  BuildContext context,
  UserModel user,
  VoidCallback reload,
) async {
  final values = await showDialog<Map<String, String>>(
    context: context,
    builder: (_) => _ProfileDetailsDialog(user: user),
  );
  if (values == null) return;
  final joiningText = values['joiningDate']!.trim();
  final joiningDate = joiningText.isEmpty ? null : DateTime.tryParse(joiningText);
  if (joiningText.isNotEmpty && joiningDate == null) {
    if (context.mounted) {
      _unsupported(context, 'Joining date must use YYYY-MM-DD.');
    }
    return;
  }
  try {
    await ProfileController.updateProfileDetails(<String, Object?>{
      'name': values['name']!.trim(),
      'phone': values['phone']!.trim(),
      'employeeCode': values['employeeCode']!.trim(),
      'department': values['department']!.trim(),
      'designation': values['designation']!.trim(),
      'branch': values['branch']!.trim(),
      'reportingManager': values['reportingManager']!.trim(),
      'joiningDate': joiningDate,
      'emergencyContact': values['emergencyContact']!.trim(),
      'bloodGroup': values['bloodGroup']!.trim(),
      'skills': _commaValues(values['skills']!),
      'certifications': _commaValues(values['certifications']!),
    });
    reload();
  } catch (error) {
    if (context.mounted) _unsupported(context, '$error');
  }
}

Future<void> _selectTheme(
  BuildContext context,
  String current,
  VoidCallback reload,
) async {
  final selected = await _selectValue(
    context: context,
    title: 'Runtime theme',
    current: current,
    values: const ['system', 'dark', 'light'],
  );
  if (selected == null) return;
  try {
    await ProfileController.updateThemeMode(selected);
    reload();
  } catch (error) {
    if (context.mounted) _unsupported(context, '$error');
  }
}

Future<void> _selectStoredPreference({
  required BuildContext context,
  required String title,
  required String current,
  required List<String> values,
  required String field,
  required VoidCallback onReload,
  required String note,
}) async {
  final selected = await _selectValue(
    context: context,
    title: title,
    current: current,
    values: values,
  );
  if (selected == null) return;
  try {
    await ProfileController.updateProfileDetails(<String, Object?>{
      field: selected,
    });
    onReload();
    if (context.mounted) _unsupported(context, note);
  } catch (error) {
    if (context.mounted) _unsupported(context, '$error');
  }
}

Future<String?> _selectValue({
  required BuildContext context,
  required String title,
  required String current,
  required List<String> values,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(title),
      children: values
          .map(
            (value) => SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, value),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value[0].toUpperCase() + value.substring(1),
                    ),
                  ),
                  if (value == current) const Icon(Icons.check, size: 18),
                ],
              ),
            ),
          )
          .toList(),
    ),
  );
}

Future<void> _resetPassword(BuildContext context) async {
  try {
    await ProfileController.requestPasswordReset();
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent.')));
  } catch (error) { if (context.mounted) _unsupported(context, '$error'); }
}

Future<void> _logout(BuildContext context) async {
  final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Logout?'), content: const Text('This will end the current OfficeRoute session.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout'))])) ?? false;
  if (confirmed) await ProfileController.logout();
}

void _push(BuildContext context, Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

void _unsupported(BuildContext context, String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

DateTime _visitDate(CustomerVisitModel visit) => visit.preferredVisitDate ?? visit.createdAt;

bool _isVisitToday(CustomerVisitModel visit, DateTime now) {
  final date = _visitDate(visit);
  return date.year == now.year && date.month == now.month && date.day == now.day;
}

String _duration(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  return '${hours}h ${minutes}m';
}

String _configured(String value) =>
    value.trim().isEmpty ? 'Not configured' : value;

String _experience(DateTime? joiningDate, DateTime now) {
  if (joiningDate == null || joiningDate.isAfter(now)) return 'Not available';
  var months = (now.year - joiningDate.year) * 12 + now.month - joiningDate.month;
  if (now.day < joiningDate.day) months--;
  final years = months ~/ 12;
  final remainingMonths = months.remainder(12);
  return '${years}y ${remainingMonths}m';
}

String _dateOnly(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

List<String> _commaValues(String value) => value
    .split(',')
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList(growable: false);

String _fieldLabel(String key) => switch (key) {
  'employeeCode' => 'Employee Code',
  'reportingManager' => 'Reporting Manager',
  'joiningDate' => 'Joining Date',
  'emergencyContact' => 'Emergency Contact',
  'bloodGroup' => 'Blood Group',
  _ => key[0].toUpperCase() + key.substring(1),
};

Map<String, String> _profileFields(UserModel user) => <String, String>{
  'name': user.name,
  'email': user.email,
  'phone': user.phone,
  'role': user.role,
  'department': user.department,
  'designation': user.designation,
  'branch': user.branch,
  'reporting manager': user.reportingManager,
  'employee code': user.employeeCode,
  'emergency contact': user.emergencyContact,
  'blood group': user.bloodGroup,
  'joining date': user.joiningDate?.toIso8601String() ?? '',
  'skills': user.skills.join(','),
  'certifications': user.certifications.join(','),
};

int _profileCompletion(UserModel user) {
  final fields = _profileFields(user).values;
  return (fields.where((value) => value.trim().isNotEmpty).length /
          fields.length *
          100)
      .round();
}

List<String> _missingProfileFields(UserModel user) => _profileFields(user)
    .entries
    .where((entry) => entry.value.trim().isEmpty)
    .map((entry) => entry.key)
    .toList(growable: false);

int _personalScore({
  required ProfileOperationsSnapshot data,
  required DateTime start,
  required DateTime endExclusive,
}) {
  final attendance = data.attendance.where((record) {
    final date = record.date;
    return date != null &&
        !date.isBefore(start) &&
        date.isBefore(endExclusive);
  }).toList();
  final visits = data.visits.where((visit) {
    final date = _visitDate(visit);
    return !date.isBefore(start) && date.isBefore(endExclusive);
  }).toList();
  final attendanceRate = attendance.isEmpty
      ? 0.0
      : attendance.where((record) => record.checkInTime != null).length /
          attendance.length;
  final visitRate = visits.isEmpty
      ? 0.0
      : visits.where((visit) => visit.status == 'completed').length /
          visits.length;
  final gpsEligible = visits
      .where((visit) => visit.checkInTime != null || visit.checkOutTime != null)
      .toList();
  final gpsRate = gpsEligible.isEmpty
      ? 0.0
      : gpsEligible
              .where((visit) =>
                  visit.checkInLatitude != null &&
                  visit.checkOutLatitude != null)
              .length /
          gpsEligible.length;
  if (attendance.isEmpty && visits.isEmpty) return 0;
  return ((attendanceRate * .35 + visitRate * .45 + gpsRate * .20) * 100)
      .round();
}

int _employeeScore(
  AttendanceModel? attendance,
  List<CustomerVisitModel> visits,
) {
  final attendanceScore = attendance?.checkInTime == null ? 0.0 : 1.0;
  final visitScore = visits.isEmpty
      ? 0.0
      : visits.where((visit) => visit.status == 'completed').length /
          visits.length;
  final gpsEligible = visits
      .where((visit) => visit.checkInTime != null || visit.checkOutTime != null)
      .toList();
  final gpsScore = gpsEligible.isEmpty
      ? 0.0
      : gpsEligible
              .where((visit) =>
                  visit.checkInLatitude != null &&
                  visit.checkOutLatitude != null)
              .length /
          gpsEligible.length;
  return ((attendanceScore * .30 + visitScore * .60 + gpsScore * .10) * 100)
      .round();
}

Map<String, int> _groupScores(
  List<_OrganizationEmployee> employees,
  String Function(_OrganizationEmployee employee) selector,
) {
  final totals = <String, int>{};
  final counts = <String, int>{};
  for (final employee in employees) {
    final group = selector(employee).trim();
    if (group.isEmpty) continue;
    totals.update(group, (value) => value + employee.score,
        ifAbsent: () => employee.score);
    counts.update(group, (value) => value + 1, ifAbsent: () => 1);
  }
  final entries = totals.entries
      .map((entry) => MapEntry(entry.key, (entry.value / counts[entry.key]!).round()))
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return Map<String, int>.fromEntries(entries);
}

int? _peerRank(
  List<_OrganizationEmployee> peers,
  _OrganizationEmployee current,
) {
  if (peers.isEmpty) return null;
  final sorted = [...peers]..sort((a, b) => b.score.compareTo(a.score));
  final index = sorted.indexWhere((item) => item.user.uid == current.user.uid);
  return index < 0 ? null : index + 1;
}

String _rankLabel(int? rank, int total) {
  if (rank == null || total == 0) return 'Not available';
  return '#$rank of $total';
}

String _trend(int value) {
  if (value > 0) return '↑$value';
  if (value < 0) return '↓${value.abs()}';
  return '→0';
}

String _dateTime(DateTime date) {
  final now = DateTime.now();
  final sameDay = date.year == now.year && date.month == now.month && date.day == now.day;
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '${sameDay ? 'Today' : '${date.day}/${date.month}/${date.year}'} $hour:$minute $period';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
