import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/live_location_model.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/premium_widgets.dart';
import '../attendance/attendance_screen.dart';
import '../auth/session_approval_center.dart';
import '../attendance/models/attendance_model.dart';
import '../cab_driver/cab_analytics_dashboard.dart';
import '../complaints/complaint_register_screen.dart';
import '../customer_visits/customer_visit_screen.dart';
import '../customer_visits/models/customer_visit_model.dart';
import '../manager/manager_screen.dart';
import '../map/map_screen.dart';
import '../notifications/notification_center_screen.dart';
import '../reports/reports_screen.dart';
import 'controllers/organization_controller.dart';
import 'services/organization_service.dart';

class OrganizationAdminScreen extends StatefulWidget {
  const OrganizationAdminScreen({super.key});

  @override
  State<OrganizationAdminScreen> createState() =>
      _OrganizationAdminScreenState();
}

class _OrganizationAdminScreenState extends State<OrganizationAdminScreen> {
  late Future<OrganizationOperationsSnapshot> _future;
  StreamSubscription<void>? _subscription;
  Timer? _debounce;
  final _search = TextEditingController();
  String _roleFilter = 'all';
  String _sort = 'name';
  int _page = 0;
  static const _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _future = OrganizationController.loadOperations(DateTime.now());
    _subscription = OrganizationController.watchOperations(DateTime.now())
        .listen(
          (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 500), _reload);
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint(
              'Organization realtime stream failed: $error\n$stackTrace',
            );
          },
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = OrganizationController.loadOperations(DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Organization Administration',
          style: AppTextStyles.headingSmall.copyWith(letterSpacing: 0),
        ),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<OrganizationOperationsSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const PremiumLoadingState(
              label: 'Loading organization operations',
            );
          }
          if (snapshot.hasError) {
            return PremiumErrorState(
              title: 'Organization operations failed to load.',
              error: snapshot.error,
              onRetry: _reload,
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return PremiumEmptyState(
              icon: Icons.corporate_fare_outlined,
              title: 'No organization data',
              message: 'No employee operations are currently available.',
              actionLabel: 'Retry',
              onAction: _reload,
            );
          }
          return _content(data);
        },
      ),
    );
  }

  Widget _content(OrganizationOperationsSnapshot data) {
    final attendanceByUser = <String, AttendanceModel>{
      for (final item in data.attendance) item.userId: item,
    };
    final visitsByUser = <String, List<CustomerVisitModel>>{};
    for (final visit in data.visits) {
      visitsByUser.putIfAbsent(visit.userId, () => []).add(visit);
    }
    final locationByUser = <String, LiveLocationModel>{
      for (final item in data.liveLocations) item.userId: item,
    };
    final rows = data.employees
        .map(
          (user) => _EmployeeRow(
            user: user,
            attendance: attendanceByUser[user.uid],
            visits: visitsByUser[user.uid] ?? const <CustomerVisitModel>[],
            location: locationByUser[user.uid],
          ),
        )
        .where(_matches)
        .toList();
    _sortRows(rows);
    final pageCount = mathMax(1, (rows.length / _pageSize).ceil());
    if (_page >= pageCount) _page = pageCount - 1;
    final start = _page * _pageSize;
    final pageRows = rows.skip(start).take(_pageSize).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: [
        const _Section(
          title: 'Session Approval Center',
          icon: Icons.verified_user_outlined,
          initiallyExpanded: true,
          child: SessionApprovalCenter(),
        ),
        _Section(
          title: 'Organization',
          icon: Icons.corporate_fare_outlined,
          initiallyExpanded: true,
          child: _OrganizationOverview(users: data.employees),
        ),
        _Section(
          title: 'Workforce Overview',
          icon: Icons.groups_2_outlined,
          initiallyExpanded: true,
          child: _WorkforceMetrics(
            rows: data.employees
                .map(
                  (user) => _EmployeeRow(
                    user: user,
                    attendance: attendanceByUser[user.uid],
                    visits: visitsByUser[user.uid] ?? const [],
                    location: locationByUser[user.uid],
                  ),
                )
                .toList(),
          ),
        ),
        _Section(
          title: 'Employee Directory',
          icon: Icons.badge_outlined,
          initiallyExpanded: true,
          child: Column(
            children: [
              _DirectoryFilters(
                search: _search,
                role: _roleFilter,
                sort: _sort,
                onChanged: () => setState(() => _page = 0),
                onRoleChanged: (value) => setState(() {
                  _roleFilter = value;
                  _page = 0;
                }),
                onSortChanged: (value) => setState(() {
                  _sort = value;
                  _page = 0;
                }),
              ),
              const SizedBox(height: 10),
              if (pageRows.isEmpty)
                const PremiumEmptyState(
                  icon: Icons.person_search_outlined,
                  title: 'No matching employees',
                  message: 'Adjust search or role filters.',
                )
              else
                _DirectoryTable(rows: pageRows),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${rows.isEmpty ? 0 : start + 1}-${mathMin(start + pageRows.length, rows.length)} of ${rows.length}',
                    style: AppTextStyles.caption,
                  ),
                  IconButton(
                    onPressed: _page > 0 ? () => setState(() => _page--) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('${_page + 1}/$pageCount'),
                  IconButton(
                    onPressed: _page + 1 < pageCount
                        ? () => setState(() => _page++)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        ),
        _Section(
          title: 'Employee Analytics',
          icon: Icons.analytics_outlined,
          child: _EmployeeAnalytics(
            rows: data.employees
                .map(
                  (user) => _EmployeeRow(
                    user: user,
                    attendance: attendanceByUser[user.uid],
                    visits: visitsByUser[user.uid] ?? const [],
                    location: locationByUser[user.uid],
                  ),
                )
                .toList(),
          ),
        ),
        const _Section(
          title: 'Cab Operations Analytics',
          icon: Icons.local_taxi_outlined,
          child: CabAnalyticsDashboard(),
        ),
        const _Section(
          title: 'Organization Documents',
          icon: Icons.folder_copy_outlined,
          child: _Unavailable(
            title: 'Organization documents backend unavailable',
            message:
                'Policies, HR documents, circulars, training, safety manuals, and templates require an approved document model, Firebase Storage ownership rules, and retention policy. No competing collection is created here.',
          ),
        ),
        const _Section(
          title: 'Admin Settings',
          icon: Icons.admin_panel_settings_outlined,
          child: _Unavailable(
            title: 'Organization settings backend unavailable',
            message:
                'Branch preferences, attendance rules, visit preferences, notification rules, profile rules, company information, and support contacts require approved organization configuration models.',
          ),
        ),
        const _Section(
          title: 'Quick Admin Shortcuts',
          icon: Icons.apps_outlined,
          child: _QuickActions(),
        ),
      ],
    );
  }

  bool _matches(_EmployeeRow row) {
    final query = _search.text.trim().toLowerCase();
    if (_roleFilter != 'all' && row.user.role.toLowerCase() != _roleFilter) {
      return false;
    }
    if (query.isEmpty) return true;
    return [
      row.user.name,
      row.user.email,
      row.user.phone,
      row.user.employeeCode,
      row.user.department,
      row.user.designation,
      row.user.branch,
      row.user.role,
    ].join(' ').toLowerCase().contains(query);
  }

  void _sortRows(List<_EmployeeRow> rows) {
    rows.sort(
      (a, b) => switch (_sort) {
        'department' => a.user.department.compareTo(b.user.department),
        'branch' => a.user.branch.compareTo(b.user.branch),
        'status' => a.status.compareTo(b.status),
        _ => a.user.name.toLowerCase().compareTo(b.user.name.toLowerCase()),
      },
    );
  }
}

class _EmployeeRow {
  final UserModel user;
  final AttendanceModel? attendance;
  final List<CustomerVisitModel> visits;
  final LiveLocationModel? location;
  const _EmployeeRow({
    required this.user,
    required this.attendance,
    required this.visits,
    required this.location,
  });
  bool get activeVisit => visits.any((visit) => visit.status == 'checked_in');
  String get status {
    if (activeVisit) return 'On Visit';
    if (attendance?.isOnBreak == true) return 'On Break';
    if (attendance?.isCheckedIn == true) return 'On Duty';
    if (attendance?.isCheckedOut == true) return 'Completed';
    return 'Absent';
  }

  int get completedVisits =>
      visits.where((visit) => visit.status == 'completed').length;
  int get productivity => visits.isEmpty
      ? (attendance?.isCheckedIn == true ? 50 : 0)
      : ((completedVisits / visits.length * 70) +
                (attendance?.isCheckedIn == true ? 30 : 0))
            .round();
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final bool initiallyExpanded;
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
    this.initiallyExpanded = false,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: PremiumCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(
          title,
          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [const Divider(), child],
      ),
    ),
  );
}

class _OrganizationOverview extends StatelessWidget {
  final List<UserModel> users;
  const _OrganizationOverview({required this.users});
  @override
  Widget build(BuildContext context) {
    final branches = users
        .map((user) => user.branch.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final departments = users
        .map((user) => user.department.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final designations = users
        .map((user) => user.designation.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    return Column(
      children: [
        _MetricWrap(
          items: [
            ('Employees', '${users.length}', Icons.groups_outlined),
            ('Branches', '${branches.length}', Icons.account_tree_outlined),
            ('Departments', '${departments.length}', Icons.domain_outlined),
            ('Designations', '${designations.length}', Icons.badge_outlined),
          ],
        ),
        const SizedBox(height: 10),
        const _Unavailable(
          title: 'Company configuration not yet owned',
          message:
              'Company name/logo, working hours, shift templates, holiday calendar, contacts, policies, and multi-company ownership require an approved organization model. Existing employee profile values are summarized without creating substitute records.',
        ),
      ],
    );
  }
}

class _WorkforceMetrics extends StatelessWidget {
  final List<_EmployeeRow> rows;
  const _WorkforceMetrics({required this.rows});
  @override
  Widget build(BuildContext context) {
    int status(String value) => rows.where((row) => row.status == value).length;
    final now = DateTime.now();
    return _MetricWrap(
      items: [
        ('Total', '${rows.length}', Icons.groups_outlined),
        (
          'Present',
          '${rows.where((r) => r.attendance?.checkInTime != null).length}',
          Icons.how_to_reg_outlined,
        ),
        ('Absent', '${status('Absent')}', Icons.person_off_outlined),
        ('On Duty', '${status('On Duty')}', Icons.work_outline),
        ('On Visit', '${status('On Visit')}', Icons.route_outlined),
        (
          'Drivers',
          '${rows.where((r) => r.user.role.toLowerCase().contains('driver')).length}',
          Icons.local_shipping_outlined,
        ),
        (
          'Office Staff',
          '${rows.where((r) => !r.user.role.toLowerCase().contains('driver') && !r.user.role.toLowerCase().contains('manager')).length}',
          Icons.desk_outlined,
        ),
        (
          'Managers',
          '${rows.where((r) => r.user.role.toLowerCase().contains('manager')).length}',
          Icons.supervisor_account_outlined,
        ),
        (
          'New Employees',
          '${rows.where((r) => r.user.joiningDate != null && r.user.joiningDate!.year == now.year && r.user.joiningDate!.month == now.month).length}',
          Icons.person_add_alt,
        ),
        ('Leave', 'N/A', Icons.event_busy_outlined),
        ('Travelling', 'N/A', Icons.alt_route),
        ('Approvals', 'N/A', Icons.approval_outlined),
      ],
    );
  }
}

class _DirectoryFilters extends StatelessWidget {
  final TextEditingController search;
  final String role;
  final String sort;
  final VoidCallback onChanged;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<String> onSortChanged;
  const _DirectoryFilters({
    required this.search,
    required this.role,
    required this.sort,
    required this.onChanged,
    required this.onRoleChanged,
    required this.onSortChanged,
  });
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      SizedBox(
        width: 300,
        child: TextField(
          controller: search,
          onChanged: (_) => onChanged(),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search employee directory',
            isDense: true,
          ),
        ),
      ),
      SizedBox(
        width: 150,
        child: DropdownButtonFormField<String>(
          initialValue: role,
          isDense: true,
          decoration: const InputDecoration(labelText: 'Role'),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All roles')),
            DropdownMenuItem(value: 'employee', child: Text('Employee')),
            DropdownMenuItem(value: 'manager', child: Text('Manager')),
            DropdownMenuItem(value: 'driver', child: Text('Driver')),
          ],
          onChanged: (value) {
            if (value != null) onRoleChanged(value);
          },
        ),
      ),
      SizedBox(
        width: 150,
        child: DropdownButtonFormField<String>(
          initialValue: sort,
          isDense: true,
          decoration: const InputDecoration(labelText: 'Sort'),
          items: const [
            DropdownMenuItem(value: 'name', child: Text('Name')),
            DropdownMenuItem(value: 'department', child: Text('Department')),
            DropdownMenuItem(value: 'branch', child: Text('Branch')),
            DropdownMenuItem(value: 'status', child: Text('Status')),
          ],
          onChanged: (value) {
            if (value != null) onSortChanged(value);
          },
        ),
      ),
    ],
  );
}

class _DirectoryTable extends StatelessWidget {
  final List<_EmployeeRow> rows;
  const _DirectoryTable({required this.rows});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      headingRowHeight: 42,
      dataRowMinHeight: 48,
      dataRowMaxHeight: 58,
      columns: const [
        DataColumn(label: Text('Employee')),
        DataColumn(label: Text('Department')),
        DataColumn(label: Text('Designation')),
        DataColumn(label: Text('Branch')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Attendance')),
        DataColumn(label: Text('Current Visit')),
        DataColumn(label: Text('Phone')),
        DataColumn(label: Text('Email')),
        DataColumn(label: Text('Actions')),
      ],
      rows: rows
          .map(
            (row) => DataRow(
              cells: [
                DataCell(
                  Text(row.user.name.isEmpty ? 'Unnamed' : row.user.name),
                ),
                DataCell(Text(_value(row.user.department))),
                DataCell(Text(_value(row.user.designation))),
                DataCell(Text(_value(row.user.branch))),
                DataCell(Text(row.status)),
                DataCell(Text(row.attendance?.status ?? 'No record')),
                DataCell(Text(row.activeVisit ? 'Active' : 'None')),
                DataCell(Text(_value(row.user.phone))),
                DataCell(Text(_value(row.user.email))),
                DataCell(
                  Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Open employee',
                        onPressed: () => _employeeDialog(context, row),
                        icon: const Icon(Icons.open_in_new, size: 18),
                      ),
                      IconButton(
                        tooltip: 'Location',
                        onPressed: () => _push(context, const MapScreen()),
                        icon: const Icon(Icons.location_on_outlined, size: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
          .toList(),
    ),
  );
}

class _EmployeeAnalytics extends StatelessWidget {
  final List<_EmployeeRow> rows;
  const _EmployeeAnalytics({required this.rows});
  @override
  Widget build(BuildContext context) {
    final present = rows.where((r) => r.attendance?.checkInTime != null).length;
    final visits = rows.fold<int>(0, (sum, row) => sum + row.visits.length);
    final completed = rows.fold<int>(
      0,
      (sum, row) => sum + row.completedVisits,
    );
    final workMinutes = rows.fold<int>(
      0,
      (sum, row) =>
          sum +
          (row.attendance?.netWorkingDuration(DateTime.now()).inMinutes ?? 0),
    );
    final ranked = [...rows]
      ..sort((a, b) => b.productivity.compareTo(a.productivity));
    final branchGroups = <String, int>{};
    final branchCounts = <String, int>{};
    final departmentGroups = <String, int>{};
    final departmentCounts = <String, int>{};
    for (final row in rows) {
      if (row.user.branch.trim().isNotEmpty) {
        branchGroups.update(
          row.user.branch,
          (value) => value + row.productivity,
          ifAbsent: () => row.productivity,
        );
      }
    }
    for (final row in rows) {
      final branch = row.user.branch.trim();
      if (branch.isNotEmpty) {
        branchCounts.update(branch, (value) => value + 1, ifAbsent: () => 1);
      }
      final department = row.user.department.trim();
      if (department.isNotEmpty) {
        departmentGroups.update(
          department,
          (value) => value + row.productivity,
          ifAbsent: () => row.productivity,
        );
        departmentCounts.update(
          department,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }
    final branchRanking = branchGroups.entries.toList()
      ..sort(
        (a, b) => (b.value / branchCounts[b.key]!).compareTo(
          a.value / branchCounts[a.key]!,
        ),
      );
    final departmentRanking = departmentGroups.entries.toList()
      ..sort(
        (a, b) => (b.value / departmentCounts[b.key]!).compareTo(
          a.value / departmentCounts[a.key]!,
        ),
      );
    final travel = rows.fold<double>(
      0,
      (sum, row) =>
          sum +
          row.visits.fold<double>(
            0,
            (visitSum, visit) => visitSum + (visit.roadDistanceKm ?? 0),
          ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetricWrap(
          items: [
            (
              'Attendance',
              rows.isEmpty ? '0%' : '${(present / rows.length * 100).round()}%',
              Icons.event_available_outlined,
            ),
            (
              'Visit Completion',
              visits == 0 ? '0%' : '${(completed / visits * 100).round()}%',
              Icons.task_alt,
            ),
            (
              'Working Hours',
              '${(workMinutes / 60).toStringAsFixed(1)}h',
              Icons.schedule,
            ),
            ('Travel', '${travel.toStringAsFixed(1)} km', Icons.alt_route),
            (
              'Average Productivity',
              rows.isEmpty
                  ? '0%'
                  : '${(rows.fold<int>(0, (sum, row) => sum + row.productivity) / rows.length).round()}%',
              Icons.speed,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Top Engineers', style: AppTextStyles.bodyLarge),
        const SizedBox(height: 6),
        ...ranked
            .take(5)
            .map(
              (row) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.emoji_events_outlined, size: 18),
                title: Text(row.user.name),
                subtitle: Text('${row.completedVisits} completed visits'),
                trailing: Text('${row.productivity}%'),
              ),
            ),
        if (branchGroups.isEmpty)
          const _Unavailable(
            title: 'Branch comparison unavailable',
            message: 'No employee profiles currently contain branch values.',
          ),
        if (branchRanking.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Top Branches', style: AppTextStyles.bodyLarge),
          ...branchRanking
              .take(5)
              .map(
                (entry) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.key),
                  subtitle: Text('${branchCounts[entry.key]} employees'),
                  trailing: Text(
                    '${(entry.value / branchCounts[entry.key]!).round()}%',
                  ),
                ),
              ),
        ],
        if (departmentRanking.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Department Comparison', style: AppTextStyles.bodyLarge),
          ...departmentRanking
              .take(5)
              .map(
                (entry) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.key),
                  subtitle: Text('${departmentCounts[entry.key]} employees'),
                  trailing: Text(
                    '${(entry.value / departmentCounts[entry.key]!).round()}%',
                  ),
                ),
              ),
        ],
      ],
    );
  }
}

class _MetricWrap extends StatelessWidget {
  final List<(String, String, IconData)> items;
  const _MetricWrap({required this.items});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 800
          ? 4
          : constraints.maxWidth >= 480
          ? 3
          : 2;
      final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items
            .map(
              (item) => SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(8),
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.$3, size: 18, color: AppColors.textSecondary),
                      const SizedBox(height: 8),
                      Text(
                        item.$2,
                        style: AppTextStyles.bodyLarge.copyWith(fontSize: 15),
                      ),
                      Text(item.$1, style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class _Unavailable extends StatelessWidget {
  final String title;
  final String message;
  const _Unavailable({required this.title, required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.warning.withAlpha(12),
      border: Border.all(color: AppColors.warning.withAlpha(60)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, color: AppColors.warning),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyLarge.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(message, style: AppTextStyles.caption.copyWith(height: 1.4)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();
  @override
  Widget build(BuildContext context) {
    final actions = <(String, IconData, VoidCallback)>[
      (
        'Attendance',
        Icons.fact_check_outlined,
        () => _push(context, const AttendanceScreen()),
      ),
      (
        'Visits',
        Icons.route_outlined,
        () => _push(context, const CustomerVisitScreen()),
      ),
      ('Map', Icons.map_outlined, () => _push(context, const MapScreen())),
      (
        'Reports',
        Icons.summarize_outlined,
        () => _push(context, const ReportsScreen()),
      ),
      (
        'Analytics',
        Icons.analytics_outlined,
        () => _push(context, const ReportsScreen()),
      ),
      (
        'Fleet',
        Icons.local_shipping_outlined,
        () => _push(context, const MapScreen()),
      ),
      (
        'Employees',
        Icons.groups_outlined,
        () => _push(context, const ManagerScreen()),
      ),
      (
        'Complaints',
        Icons.support_agent_outlined,
        () => _push(context, const ComplaintRegisterScreen()),
      ),
      (
        'Notifications',
        Icons.notifications_outlined,
        () => _push(context, const NotificationCenterScreen()),
      ),
      (
        'Customer',
        Icons.people_outline,
        () => _push(context, const CustomerVisitScreen()),
      ),
      (
        'Branches',
        Icons.account_tree_outlined,
        () => _notice(
          context,
          'Branch configuration backend is not yet approved.',
        ),
      ),
      (
        'Organization',
        Icons.corporate_fare_outlined,
        () =>
            _notice(context, 'You are already in Organization Administration.'),
      ),
      (
        'Settings',
        Icons.settings_outlined,
        () => _notice(
          context,
          'Organization settings backend is not yet approved.',
        ),
      ),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions
          .map(
            (action) => OutlinedButton.icon(
              onPressed: action.$3,
              icon: Icon(action.$2, size: 17),
              label: Text(action.$1),
            ),
          )
          .toList(),
    );
  }
}

void _employeeDialog(
  BuildContext context,
  _EmployeeRow row,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(row.user.name),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_value(row.user.employeeCode)} • ${_value(row.user.role)}'),
            const Divider(),
            Text('Department: ${_value(row.user.department)}'),
            Text('Designation: ${_value(row.user.designation)}'),
            Text('Branch: ${_value(row.user.branch)}'),
            Text('Phone: ${_value(row.user.phone)}'),
            Text('Email: ${_value(row.user.email)}'),
            const SizedBox(height: 12),
            Text('Status: ${row.status}'),
            Text('Attendance: ${row.attendance?.status ?? 'No record'}'),
            Text('Visits today: ${row.visits.length}'),
            Text('Completed: ${row.completedVisits}'),
            Text('Productivity: ${row.productivity}%'),
            Text(
              'Location: ${row.location == null ? 'Unavailable' : '${row.location!.latitude.toStringAsFixed(4)}, ${row.location!.longitude.toStringAsFixed(4)}'}',
            ),
            if (row.visits.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Today timeline'),
              ...([...row.visits]
                    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)))
                  .take(5)
                  .map(
                    (visit) =>
                        Text('• ${visit.customerName} — ${visit.status}'),
                  ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  ),
);

void _push(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
void _notice(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));
String _value(String value) => value.trim().isEmpty ? 'Not configured' : value;
int mathMax(int a, int b) => a > b ? a : b;
int mathMin(int a, int b) => a < b ? a : b;
