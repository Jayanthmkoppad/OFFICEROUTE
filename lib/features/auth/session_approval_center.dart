import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/premium_widgets.dart';
import 'controllers/session_approval_controller.dart';

class SessionApprovalCenter extends StatefulWidget {
  final String initialRequestQuery;
  final ValueChanged<UserModel>? onRequestProcessed;

  const SessionApprovalCenter({
    super.key,
    this.initialRequestQuery = '',
    this.onRequestProcessed,
  });

  @override
  State<SessionApprovalCenter> createState() => _SessionApprovalCenterState();
}

class _SessionApprovalCenterState extends State<SessionApprovalCenter> {
  late Future<List<UserModel>> _future;
  StreamSubscription<void>? _subscription;
  Timer? _debounce;
  final TextEditingController _search = TextEditingController();
  SessionApprovalStatus? _status = SessionApprovalStatus.pending;
  String _role = 'all';
  String _branch = 'all';
  String _department = 'all';
  String _sort = 'requested_desc';
  bool _deviceOnly = false;
  bool _initialRequestOpened = false;
  int _page = 0;
  static const _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _future = SessionApprovalController.loadApprovalRequests();
    _subscription = SessionApprovalController.watchApprovalRequests().listen(
      (_) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 400), _reload);
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Session approval listener failed: $error\n$stackTrace');
      },
    );
    _search.addListener(_filtersChanged);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _debounce?.cancel();
    _search
      ..removeListener(_filtersChanged)
      ..dispose();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _future = SessionApprovalController.loadApprovalRequests());
  }

  void _filtersChanged() {
    if (mounted) setState(() => _page = 0);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const PremiumLoadingState(label: 'Loading session requests');
        }
        if (snapshot.hasError) {
          return PremiumErrorState(
            title: 'Session approvals could not be loaded.',
            error: snapshot.error,
            onRetry: _reload,
          );
        }
        final all = snapshot.data ?? const <UserModel>[];
        if (all.isEmpty) {
          return PremiumEmptyState(
            icon: Icons.verified_user_outlined,
            title: 'No access requests',
            message: 'Employee session requests will appear here in realtime.',
            actionLabel: 'Refresh',
            onAction: _reload,
          );
        }
        _openInitialRequest(all);
        return _content(all);
      },
    );
  }

  void _openInitialRequest(List<UserModel> users) {
    if (_initialRequestOpened || widget.initialRequestQuery.trim().isEmpty) {
      return;
    }
    final query = widget.initialRequestQuery.toLowerCase();
    final pending =
        users
            .where(
              (user) => user.approvalStatus == SessionApprovalStatus.pending,
            )
            .toList()
          ..sort((a, b) => _time(b).compareTo(_time(a)));
    if (pending.isEmpty) return;
    final matched = pending.where((user) {
      final name = user.name.trim().toLowerCase();
      final email = user.email.trim().toLowerCase();
      return (name.isNotEmpty && query.contains(name)) ||
          (email.isNotEmpty && query.contains(email));
    }).firstOrNull;
    final user = matched ?? pending.first;
    _initialRequestOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showDetails(user);
    });
  }

  Widget _content(List<UserModel> all) {
    final roles = _values(all.map(_approvalRole));
    final branches = _values(all.map((user) => user.branch));
    final departments = _values(all.map((user) => user.department));
    final query = _search.text.trim().toLowerCase();
    final recentApprovals =
        all.where((user) => user.approvedAt != null).toList()
          ..sort((a, b) => b.approvedAt!.compareTo(a.approvedAt!));
    final filtered = all.where((user) {
      if (_deviceOnly && !_hasDeviceRequest(user)) return false;
      if (_status != null && user.approvalStatus != _status) return false;
      if (_role != 'all' && _approvalRole(user) != _role) return false;
      if (_branch != 'all' && user.branch != _branch) return false;
      if (_department != 'all' && user.department != _department) return false;
      if (query.isEmpty) return true;
      return <String>[
        user.name,
        user.email,
        user.phone,
        user.employeeCode,
        _approvalRole(user),
        user.branch,
        user.department,
      ].join(' ').toLowerCase().contains(query);
    }).toList();
    filtered.sort(_compare);

    final pageCount = filtered.isEmpty
        ? 1
        : (filtered.length / _pageSize).ceil();
    final page = _page.clamp(0, pageCount - 1);
    final start = page * _pageSize;
    final rows = filtered.skip(start).take(_pageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SummaryChip(
              label: 'Pending Requests',
              count: all
                  .where(
                    (user) =>
                        user.approvalStatus == SessionApprovalStatus.pending,
                  )
                  .length,
              onTap: () => setState(() {
                _deviceOnly = false;
                _status = SessionApprovalStatus.pending;
              }),
            ),
            _SummaryChip(
              label: 'Approved',
              count: all
                  .where(
                    (user) =>
                        user.approvalStatus == SessionApprovalStatus.approved,
                  )
                  .length,
              onTap: () => setState(() {
                _deviceOnly = false;
                _status = SessionApprovalStatus.approved;
              }),
            ),
            _SummaryChip(
              label: 'Rejected',
              count: all
                  .where(
                    (user) =>
                        user.approvalStatus == SessionApprovalStatus.rejected,
                  )
                  .length,
              onTap: () => setState(() {
                _deviceOnly = false;
                _status = SessionApprovalStatus.rejected;
              }),
            ),
            _SummaryChip(
              label: 'Blocked',
              count: all
                  .where(
                    (user) =>
                        user.approvalStatus == SessionApprovalStatus.blocked,
                  )
                  .length,
              onTap: () => setState(() {
                _deviceOnly = false;
                _status = SessionApprovalStatus.blocked;
              }),
            ),
            _SummaryChip(
              label: 'Device Requests',
              count: all.where(_hasDeviceRequest).length,
              onTap: () => setState(() {
                _deviceOnly = true;
                _status = null;
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (recentApprovals.isNotEmpty) ...[
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Recent Approvals'),
            children: recentApprovals
                .take(5)
                .map(
                  (user) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.verified_user_outlined,
                      color: AppColors.success,
                    ),
                    title: Text(_configured(user.name)),
                    subtitle: Text(_label(_approvalRole(user))),
                    trailing: Text(_dateTime(user.approvedAt)),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: 260,
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Search requests',
                ),
              ),
            ),
            _Filter<String>(
              label: 'Status',
              value: _status?.firestoreValue ?? 'All',
              values: [
                'All',
                ...SessionApprovalStatus.values.map(
                  (item) => item.firestoreValue,
                ),
              ],
              onChanged: (value) => setState(() {
                _deviceOnly = false;
                _status = value == 'All'
                    ? null
                    : SessionApprovalStatus.fromFirestore(value);
                _page = 0;
              }),
            ),
            _Filter<String>(
              label: 'Role',
              value: _role,
              values: ['all', ...roles],
              onChanged: (value) => setState(() {
                _role = value;
                _page = 0;
              }),
            ),
            _Filter<String>(
              label: 'Branch',
              value: _branch,
              values: ['all', ...branches],
              onChanged: (value) => setState(() {
                _branch = value;
                _page = 0;
              }),
            ),
            _Filter<String>(
              label: 'Department',
              value: _department,
              values: ['all', ...departments],
              onChanged: (value) => setState(() {
                _department = value;
                _page = 0;
              }),
            ),
            _Filter<String>(
              label: 'Sort',
              value: _sort,
              values: const [
                'requested_desc',
                'requested_asc',
                'employee',
                'status',
              ],
              onChanged: (value) => setState(() => _sort = value),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const PremiumEmptyState(
            icon: Icons.filter_alt_off_outlined,
            title: 'No matching requests',
            message: 'Adjust the approval filters or search text.',
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Employee')),
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('Role')),
                DataColumn(label: Text('Branch')),
                DataColumn(label: Text('Department')),
                DataColumn(label: Text('Requested')),
                DataColumn(label: Text('Device')),
                DataColumn(label: Text('Platform')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: rows.map(_row).toList(),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '${filtered.isEmpty ? 0 : start + 1}-${start + rows.length} of ${filtered.length}',
            ),
            IconButton(
              onPressed: page > 0
                  ? () => setState(() => _page = page - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text('${page + 1}/$pageCount'),
            IconButton(
              onPressed: page + 1 < pageCount
                  ? () => setState(() => _page = page + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }

  DataRow _row(UserModel user) {
    final deviceRequest = _hasDeviceRequest(user);
    return DataRow(
      cells: [
        DataCell(Text(_configured(user.name))),
        DataCell(Text(_configured(user.email))),
        DataCell(Text(_label(_approvalRole(user)))),
        DataCell(Text(_configured(user.branch))),
        DataCell(Text(_configured(user.department))),
        DataCell(
          Text(
            _dateTime(deviceRequest ? user.deviceRequestAt : user.requestedAt),
          ),
        ),
        DataCell(
          Text(
            _configured(
              deviceRequest ? user.pendingDeviceModel : user.deviceModel,
            ),
          ),
        ),
        DataCell(
          Text(
            _configured(
              deviceRequest ? user.pendingDevicePlatform : user.platform,
            ),
          ),
        ),
        DataCell(
          _StatusChip(
            status: deviceRequest
                ? user.deviceApprovalStatus
                : user.approvalStatus,
          ),
        ),
        DataCell(
          Row(
            children: [
              IconButton(
                tooltip: 'View details',
                onPressed: () => _showDetails(user),
                icon: const Icon(Icons.visibility_outlined),
              ),
              IconButton(
                tooltip: deviceRequest ? 'Approve new device' : 'Approve',
                onPressed: () => deviceRequest
                    ? _reviewDevice(user, SessionApprovalStatus.approved)
                    : _processFromTable(user, () => _approve(user)),
                icon: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.success,
                ),
              ),
              IconButton(
                tooltip: deviceRequest ? 'Reject new device' : 'Reject',
                onPressed: () => deviceRequest
                    ? _rejectDevice(user)
                    : _processFromTable(user, () => _reject(user)),
                icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
              ),
              PopupMenuButton<SessionApprovalStatus>(
                tooltip: 'More account actions',
                onSelected: (status) => _review(user: user, status: status),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: SessionApprovalStatus.suspended,
                    child: Text('Suspend'),
                  ),
                  const PopupMenuItem(
                    value: SessionApprovalStatus.blocked,
                    child: Text('Block'),
                  ),
                  if (user.approvalStatus == SessionApprovalStatus.blocked ||
                      user.approvalStatus == SessionApprovalStatus.suspended)
                    const PopupMenuItem(
                      value: SessionApprovalStatus.approved,
                      child: Text('Unblock'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _hasDeviceRequest(UserModel user) =>
      user.pendingDeviceId.isNotEmpty &&
      user.deviceApprovalStatus != SessionApprovalStatus.approved;

  Future<void> _reviewDevice(
    UserModel user,
    SessionApprovalStatus status, {
    String reason = '',
  }) async {
    try {
      await SessionApprovalController.reviewDeviceRequest(
        user: user,
        status: status,
        reason: reason,
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Device review failed: $error')));
    }
  }

  Future<void> _rejectDevice(UserModel user) async {
    final result = await showDialog<({String reason, String remarks})>(
      context: context,
      builder: (_) => const _RejectDialog(),
    );
    if (result == null) return;
    await _reviewDevice(
      user,
      SessionApprovalStatus.rejected,
      reason: result.reason,
    );
  }

  int _compare(UserModel a, UserModel b) => switch (_sort) {
    'requested_asc' => _time(a).compareTo(_time(b)),
    'employee' => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    'status' => a.approvalStatus.index.compareTo(b.approvalStatus.index),
    _ => _time(b).compareTo(_time(a)),
  };

  DateTime _time(UserModel user) =>
      user.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  Future<bool> _approve(UserModel user) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Approve session access?'),
            content: Text(
              '${_configured(user.name)} will receive access on ${_configured(user.deviceModel)}.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Approve'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return false;
    return _review(user: user, status: SessionApprovalStatus.approved);
  }

  Future<bool> _reject(UserModel user) async {
    final result = await showDialog<({String reason, String remarks})>(
      context: context,
      builder: (_) => const _RejectDialog(),
    );
    if (result == null) return false;
    return _review(
      user: user,
      status: SessionApprovalStatus.rejected,
      reason: result.reason,
      remarks: result.remarks,
    );
  }

  Future<bool> _review({
    required UserModel user,
    required SessionApprovalStatus status,
    String reason = '',
    String remarks = '',
  }) async {
    try {
      await SessionApprovalController.reviewRequest(
        user: user,
        status: status,
        reason: reason,
        remarks: remarks,
      );
      _reload();
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Review failed: $error')));
      }
      return false;
    }
  }

  Future<void> _processFromTable(
    UserModel user,
    Future<bool> Function() action,
  ) async {
    if (await action()) widget.onRequestProcessed?.call(user);
  }

  Future<void> _showDetails(UserModel user) async {
    final processed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_configured(user.name)),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              children:
                  <(String, String)>[
                        ('Firebase Email', user.email),
                        ('Phone', user.phone),
                        ('Employee ID', user.employeeCode),
                        ('Role', _label(_approvalRole(user))),
                        ('Branch', user.branch),
                        ('Department', user.department),
                        ('Designation', user.designation),
                        ('Service Centre', user.serviceCentre),
                        ('Vehicle Number', user.vehicleNumber),
                        ('Reporting Region', user.reportingRegion),
                        ('Remarks', user.remarks),
                        ('Device', user.deviceModel),
                        ('Device ID', user.deviceId),
                        ('Pending Device', user.pendingDeviceModel),
                        ('Pending Device ID', user.pendingDeviceId),
                        ('Pending Device Platform', user.pendingDevicePlatform),
                        ('Device Request', _dateTime(user.deviceRequestAt)),
                        (
                          'Device Approval',
                          user.deviceApprovalStatus.firestoreValue,
                        ),
                        ('OS / Platform', user.platform),
                        ('Application', user.appVersion),
                        ('Login Provider', user.loginProvider),
                        ('Login Time', _dateTime(user.lastLogin)),
                        ('First Login', user.isFirstLogin ? 'Yes' : 'No'),
                        ('Requested', _dateTime(user.requestedAt)),
                        ('Approved', _dateTime(user.approvedAt)),
                        ('Approved By', user.approvedBy),
                        ('Status', user.approvalStatus.firestoreValue),
                      ]
                      .map(
                        (item) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.$1),
                          subtitle: Text(_configured(item.$2)),
                        ),
                      )
                      .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Close'),
          ),
          OutlinedButton(
            onPressed: () async {
              if (await _reject(user) && dialogContext.mounted) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Reject'),
          ),
          FilledButton(
            onPressed: () async {
              if (await _approve(user) && dialogContext.mounted) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (processed == true) widget.onRequestProcessed?.call(user);
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback onTap;

  const _SummaryChip({
    required this.label,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ActionChip(
    onPressed: onTap,
    avatar: CircleAvatar(child: Text('$count')),
    label: Text(label),
  );
}

class _Filter<T extends Object> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> values;
  final ValueChanged<T> onChanged;

  const _Filter({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 165,
    child: DropdownButtonFormField<T>(
      initialValue: values.contains(value) ? value : values.first,
      decoration: InputDecoration(labelText: label),
      items: values
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(_label('$item'), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    ),
  );
}

class _StatusChip extends StatelessWidget {
  final SessionApprovalStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SessionApprovalStatus.approved => AppColors.success,
      SessionApprovalStatus.pending => AppColors.warning,
      SessionApprovalStatus.rejected ||
      SessionApprovalStatus.blocked => AppColors.error,
      SessionApprovalStatus.suspended => AppColors.info,
    };
    return Chip(
      label: Text(status.firestoreValue),
      side: BorderSide(color: color.withAlpha(80)),
      backgroundColor: color.withAlpha(20),
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  final _remarks = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    _remarks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reject access request'),
    content: Form(
      key: _formKey,
      child: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _reason,
              decoration: const InputDecoration(labelText: 'Reason'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Reason is required.'
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _remarks,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Administrator remarks',
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
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(context, (
            reason: _reason.text.trim(),
            remarks: _remarks.text.trim(),
          ));
        },
        child: const Text('Reject'),
      ),
    ],
  );
}

List<String> _values(Iterable<String> values) {
  final result =
      values.where((value) => value.trim().isNotEmpty).toSet().toList()..sort();
  return result;
}

String _configured(String value) =>
    value.trim().isEmpty ? 'Not configured' : value;

String _approvalRole(UserModel user) =>
    user.sessionRole.trim().isEmpty ? user.role : user.sessionRole;

String _label(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _dateTime(DateTime? value) {
  if (value == null) return 'Not available';
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
