import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/premium_widgets.dart';
import '../home/home_screen.dart';
import '../manager/manager_screen.dart';
import '../cab_driver/cab_driver_app.dart';
import 'controllers/session_approval_controller.dart';
import 'services/session_device_service.dart';

class SessionAccessGate extends StatefulWidget {
  final String userId;

  const SessionAccessGate({super.key, required this.userId});

  @override
  State<SessionAccessGate> createState() => _SessionAccessGateState();
}

class _SessionAccessGateState extends State<SessionAccessGate> {
  Future<SessionDeviceMetadata>? _deviceFuture;
  Stream<({UserModel? user, bool isFromCache})>? _sessionStream;
  bool _editingRejectedRequest = false;
  bool _sessionSeenRecorded = false;
  bool _bootstrapRepairStarted = false;
  bool _deviceRequestStarted = false;

  @override
  void initState() {
    super.initState();
    _initializeAccessChecks();
  }

  @override
  void didUpdateWidget(covariant SessionAccessGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _initializeAccessChecks();
      _editingRejectedRequest = false;
      _sessionSeenRecorded = false;
      _bootstrapRepairStarted = false;
      _deviceRequestStarted = false;
    }
  }

  void _initializeAccessChecks() {
    if (SessionApprovalController.isBootstrapAdministrator) {
      _deviceFuture = null;
      _sessionStream = null;
      return;
    }
    _deviceFuture = SessionApprovalController.loadDeviceMetadata();
    _sessionStream = SessionApprovalController.watchCurrentSession();
  }

  @override
  Widget build(BuildContext context) {
    if (SessionApprovalController.isBootstrapAdministrator) {
      if (!_bootstrapRepairStarted) {
        _bootstrapRepairStarted = true;
        unawaited(
          SessionApprovalController.ensureBootstrapAdministrator().catchError((
            Object error,
            StackTrace stackTrace,
          ) {
            debugPrint('Bootstrap profile repair deferred: $error');
            debugPrintStack(stackTrace: stackTrace);
          }),
        );
      }
      return const HomeScreen();
    }
    return FutureBuilder<SessionDeviceMetadata>(
      future: _deviceFuture!,
      builder: (context, deviceSnapshot) {
        if (deviceSnapshot.connectionState != ConnectionState.done) {
          return const _SessionLoadingView();
        }
        if (deviceSnapshot.hasError || deviceSnapshot.data == null) {
          return _SessionErrorView(
            message: 'Device information could not be loaded.',
            error: deviceSnapshot.error,
            onRetry: () => setState(() {
              _deviceFuture = SessionApprovalController.loadDeviceMetadata();
            }),
          );
        }
        return StreamBuilder<({UserModel? user, bool isFromCache})>(
          stream: _sessionStream!,
          builder: (context, sessionSnapshot) {
            if (sessionSnapshot.connectionState == ConnectionState.waiting &&
                !sessionSnapshot.hasData) {
              return const _SessionLoadingView();
            }
            if (sessionSnapshot.hasError) {
              return _WaitingView(
                user: null,
                offline: true,
                onRefresh: _refresh,
              );
            }

            final session = sessionSnapshot.data;
            final user = session?.user;
            final device = deviceSnapshot.data!;
            if (user == null) {
              return SessionSetupScreen(device: device);
            }

            if (session!.isFromCache) {
              return _WaitingView(
                user: user,
                offline: true,
                onRefresh: _refresh,
              );
            }

            if (user.approvalStatus == SessionApprovalStatus.suspended ||
                user.approvalStatus == SessionApprovalStatus.blocked) {
              return _RestrictedView(user: user);
            }

            if (user.sessionApproved &&
                user.approvalStatus == SessionApprovalStatus.approved) {
              if (SessionApprovalController.isApprovedForDevice(user, device)) {
                _recordSeen();
                return _dashboardFor(user);
              }
              if (SessionApprovalController.hasPendingDeviceRequest(
                user,
                device,
              )) {
                return _DeviceWaitingView(user: user, device: device);
              }
              if (user.pendingDeviceId == device.deviceId &&
                  user.deviceApprovalStatus == SessionApprovalStatus.rejected) {
                return _DeviceRejectedView(
                  user: user,
                  onRetry: () => _requestDeviceChange(user, device),
                );
              }
              _requestDeviceChange(user, device);
              return _DeviceWaitingView(user: user, device: device);
            }

            if (user.approvalStatus == SessionApprovalStatus.rejected &&
                !_editingRejectedRequest) {
              return _RejectedView(
                user: user,
                onEdit: () => setState(() => _editingRejectedRequest = true),
              );
            }

            if (user.approvalStatus == SessionApprovalStatus.pending &&
                user.requestedAt != null &&
                !_editingRejectedRequest) {
              return _WaitingView(
                user: user,
                offline: false,
                onRefresh: _refresh,
              );
            }

            return SessionSetupScreen(
              device: device,
              existingUser: user,
              onSubmitted: () {
                if (mounted) {
                  setState(() => _editingRejectedRequest = false);
                }
              },
            );
          },
        );
      },
    );
  }

  void _requestDeviceChange(UserModel user, SessionDeviceMetadata device) {
    if (_deviceRequestStarted) return;
    _deviceRequestStarted = true;
    unawaited(
      SessionApprovalController.requestDeviceChange(user: user, device: device)
          .catchError((Object error, StackTrace stackTrace) {
            debugPrint('Device access request failed: $error');
            debugPrintStack(stackTrace: stackTrace);
          })
          .whenComplete(() {
            if (mounted) _deviceRequestStarted = false;
          }),
    );
  }

  Future<void> _refresh() async {
    try {
      await SessionApprovalController.refreshCurrentSession();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Still offline. Approval will retry automatically.'),
        ),
      );
    }
  }

  void _recordSeen() {
    if (_sessionSeenRecorded) return;
    _sessionSeenRecorded = true;
    unawaited(
      SessionApprovalController.markCurrentSessionSeen().catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        debugPrint('Session last-seen update deferred: $error');
        debugPrintStack(stackTrace: stackTrace);
      }),
    );
  }

  Widget _dashboardFor(UserModel user) {
    final role = (user.sessionRole.isEmpty ? user.role : user.sessionRole)
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_');
    if (role == 'manager') return const ManagerScreen();
    if (role == 'cab_driver' || role == 'driver') {
      return const CabDriverApp();
    }
    return const HomeScreen();
  }
}

class SessionSetupScreen extends StatefulWidget {
  final SessionDeviceMetadata device;
  final UserModel? existingUser;
  final VoidCallback? onSubmitted;

  const SessionSetupScreen({
    super.key,
    required this.device,
    this.existingUser,
    this.onSubmitted,
  });

  @override
  State<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends State<SessionSetupScreen> {
  Map<String, Object?>? _details;
  bool _submitting = false;

  Future<void> _selectRole(_SessionRole role) async {
    final result = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) =>
          _RoleDetailsSheet(role: role, existingUser: widget.existingUser),
    );
    if (result != null && mounted) setState(() => _details = result);
  }

  Future<void> _submit() async {
    final details = _details;
    if (details == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await SessionApprovalController.submitAccessRequest(
        details: details,
        device: widget.device,
        previousApprovalStatus:
            widget.existingUser?.approvalStatus.firestoreValue ??
            'Not Requested',
      );
      widget.onSubmitted?.call();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Access request failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final provider =
        firebaseUser?.providerData.firstOrNull?.providerId ?? 'password';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Setup'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: SessionApprovalController.logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PremiumCard(
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          width: 58,
                          height: 58,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome to OfficeRoute',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                firebaseUser?.email ?? 'Authenticated employee',
                              ),
                              Text(
                                'Login provider: $provider',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Select your role',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth >= 620
                          ? (constraints.maxWidth - 10) / 2
                          : constraints.maxWidth;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _SessionRole.values
                            .map(
                              (role) => SizedBox(
                                width: width,
                                child: _RoleCard(
                                  role: role,
                                  selected: _details?['role'] == role.value,
                                  onTap: () => _selectRole(role),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                  if (_details != null) ...[
                    const SizedBox(height: 14),
                    _DetailsSummary(details: _details!),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined),
                      label: const Text('Submit Access Request'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _SessionRole {
  serviceEngineer(
    'Service Engineer',
    'service_engineer',
    Icons.engineering_outlined,
  ),
  cabDriver('Cab Driver', 'cab_driver', Icons.local_taxi_outlined),
  officeEmployee(
    'Office Employee',
    'office_employee',
    Icons.business_center_outlined,
  ),
  manager('Manager', 'manager', Icons.supervisor_account_outlined);

  final String label;
  final String value;
  final IconData icon;

  const _SessionRole(this.label, this.value, this.icon);
}

class _RoleCard extends StatelessWidget {
  final _SessionRole role;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primary.withAlpha(20) : colors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(role.icon, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  role.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Icon(selected ? Icons.check_circle : Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleDetailsSheet extends StatefulWidget {
  final _SessionRole role;
  final UserModel? existingUser;

  const _RoleDetailsSheet({required this.role, this.existingUser});

  @override
  State<_RoleDetailsSheet> createState() => _RoleDetailsSheetState();
}

class _RoleDetailsSheetState extends State<_RoleDetailsSheet> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    final user = widget.existingUser;
    _controllers = {
      for (final field in _fieldsFor(widget.role))
        field.key: TextEditingController(text: _existingValue(user, field.key)),
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
    if (!_formKey.currentState!.validate()) return;
    final values = <String, Object?>{
      'role': widget.role.value,
      for (final entry in _controllers.entries)
        entry.key: entry.value.text.trim(),
    };
    Navigator.pop(context, values);
  }

  @override
  Widget build(BuildContext context) {
    final fields = _fieldsFor(widget.role);
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 14,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.role.label,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 14),
              ...fields.map(
                (field) => Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: TextFormField(
                    controller: _controllers[field.key],
                    keyboardType: field.phone
                        ? TextInputType.phone
                        : TextInputType.text,
                    maxLines: field.key == 'remarks' ? 3 : 1,
                    decoration: InputDecoration(labelText: field.label),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return '${field.label} is required.';
                      if (field.phone &&
                          !RegExp(r'^\+?[0-9]{7,15}$').hasMatch(text)) {
                        return 'Enter a valid mobile number.';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('Save Details'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _FormFieldSpec = ({String key, String label, bool phone});

List<_FormFieldSpec> _fieldsFor(_SessionRole role) {
  const name = (key: 'name', label: 'Name', phone: false);
  const mobile = (key: 'phone', label: 'Mobile Number', phone: true);
  const employeeId = (key: 'employeeId', label: 'Employee ID', phone: false);
  const branch = (key: 'branch', label: 'Branch', phone: false);
  const department = (key: 'department', label: 'Department', phone: false);
  const designation = (key: 'designation', label: 'Designation', phone: false);
  const remarks = (key: 'remarks', label: 'Remarks', phone: false);
  return switch (role) {
    _SessionRole.serviceEngineer => const [
      name,
      mobile,
      employeeId,
      branch,
      (key: 'serviceCentre', label: 'Service Centre', phone: false),
      designation,
      remarks,
    ],
    _SessionRole.cabDriver => const [
      (key: 'driverName', label: 'Driver Name', phone: false),
      mobile,
      (key: 'driverId', label: 'Driver ID', phone: false),
      branch,
      (key: 'vehicleNumber', label: 'Vehicle Number', phone: false),
      remarks,
    ],
    _SessionRole.officeEmployee => const [
      name,
      mobile,
      employeeId,
      branch,
      department,
      designation,
      remarks,
    ],
    _SessionRole.manager => const [
      name,
      mobile,
      employeeId,
      branch,
      department,
      designation,
      (key: 'reportingRegion', label: 'Reporting Region', phone: false),
      remarks,
    ],
  };
}

String _existingValue(UserModel? user, String key) {
  if (user == null) return '';
  return switch (key) {
    'name' || 'driverName' => user.name,
    'phone' => user.phone,
    'employeeId' || 'driverId' => user.employeeCode,
    'branch' => user.branch,
    'department' => user.department,
    'designation' => user.designation,
    'serviceCentre' => user.serviceCentre,
    'vehicleNumber' => user.vehicleNumber,
    'reportingRegion' => user.reportingRegion,
    'remarks' => user.remarks,
    _ => '',
  };
}

class _DetailsSummary extends StatelessWidget {
  final Map<String, Object?> details;

  const _DetailsSummary({required this.details});

  @override
  Widget build(BuildContext context) {
    final role = _SessionRole.values.firstWhere(
      (item) => item.value == details['role'],
    );
    final rows = <(String, String)>[
      ('Role', role.label),
      ('Branch', '${details['branch'] ?? ''}'),
      if ('${details['department'] ?? ''}'.isNotEmpty)
        ('Department', '${details['department']}'),
      if ('${details['designation'] ?? ''}'.isNotEmpty)
        ('Designation', '${details['designation']}'),
      ('Mobile', '${details['phone'] ?? ''}'),
      ('Employee ID', '${details['employeeId'] ?? details['driverId'] ?? ''}'),
    ];
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Request Summary',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          ...rows.map(
            (row) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
              ),
              title: Text(row.$1),
              trailing: SizedBox(
                width: 220,
                child: Text(
                  row.$2,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingView extends StatelessWidget {
  final UserModel? user;
  final bool offline;
  final Future<void> Function() onRefresh;

  const _WaitingView({
    required this.user,
    required this.offline,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final role = user == null
        ? 'Not available'
        : _sessionRoleLabel(
            user!.sessionRole.isEmpty ? user!.role : user!.sessionRole,
          );
    final submitted = _sessionDateTime(user?.requestedAt);
    return _CenteredSessionScaffold(
      icon: offline ? Icons.cloud_off_outlined : Icons.schedule_outlined,
      title: offline
          ? 'Waiting for a secure connection'
          : 'Awaiting Administrator Approval',
      message: offline
          ? 'OfficeRoute cannot confirm your approval while offline. It will retry automatically.'
          : 'Request Submitted\n\nRole: $role\nSubmitted: $submitted\n\nThe Administrator must approve your account before you can access OfficeRoute.',
      status: user?.approvalStatus.firestoreValue,
      actions: [
        FilledButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh Status'),
        ),
        OutlinedButton.icon(
          onPressed: SessionApprovalController.logout,
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ],
    );
  }
}

class _RejectedView extends StatelessWidget {
  final UserModel user;
  final VoidCallback onEdit;

  const _RejectedView({required this.user, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final detail = [
      user.rejectionReason,
      user.administratorRemarks,
    ].where((value) => value.trim().isNotEmpty).join('\n');
    return _CenteredSessionScaffold(
      icon: Icons.cancel_outlined,
      iconColor: AppColors.error,
      title: 'Request Rejected',
      message: detail.isEmpty
          ? 'The administrator rejected this access request.'
          : detail,
      status: user.approvalStatus.firestoreValue,
      actions: [
        FilledButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Retry Session Setup'),
        ),
        OutlinedButton.icon(
          onPressed: SessionApprovalController.logout,
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ],
    );
  }
}

class _RestrictedView extends StatelessWidget {
  final UserModel user;

  const _RestrictedView({required this.user});

  @override
  Widget build(BuildContext context) => _CenteredSessionScaffold(
    icon: Icons.gpp_bad_outlined,
    iconColor: AppColors.error,
    title: 'Account Suspended',
    message: user.administratorRemarks.trim().isEmpty
        ? 'Contact your OfficeRoute administrator for assistance.'
        : user.administratorRemarks,
    status: user.approvalStatus.firestoreValue,
    actions: [
      OutlinedButton.icon(
        onPressed: SessionApprovalController.logout,
        icon: const Icon(Icons.logout),
        label: const Text('Logout'),
      ),
    ],
  );
}

class _DeviceWaitingView extends StatelessWidget {
  final UserModel user;
  final SessionDeviceMetadata device;

  const _DeviceWaitingView({required this.user, required this.device});

  @override
  Widget build(BuildContext context) => _CenteredSessionScaffold(
    icon: Icons.phonelink_lock_outlined,
    title: 'Waiting for Device Approval',
    message:
        'New Device Login Request\n\nDevice: ${device.deviceModel}\nSubmitted: ${_sessionDateTime(user.deviceRequestAt)}\n\nYour approved account remains protected while the Administrator reviews this device.',
    status: user.deviceApprovalStatus.firestoreValue,
    actions: [
      OutlinedButton.icon(
        onPressed: SessionApprovalController.logout,
        icon: const Icon(Icons.logout),
        label: const Text('Logout'),
      ),
    ],
  );
}

class _DeviceRejectedView extends StatelessWidget {
  final UserModel user;
  final VoidCallback onRetry;

  const _DeviceRejectedView({required this.user, required this.onRetry});

  @override
  Widget build(BuildContext context) => _CenteredSessionScaffold(
    icon: Icons.phonelink_erase_outlined,
    iconColor: AppColors.error,
    title: 'Device Request Rejected',
    message: user.administratorRemarks.trim().isEmpty
        ? 'This device was not approved. Contact your Administrator or retry the request.'
        : user.administratorRemarks,
    status: user.deviceApprovalStatus.firestoreValue,
    actions: [
      FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Retry Device Request'),
      ),
      OutlinedButton.icon(
        onPressed: SessionApprovalController.logout,
        icon: const Icon(Icons.logout),
        label: const Text('Logout'),
      ),
    ],
  );
}

class _CenteredSessionScaffold extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String message;
  final String? status;
  final List<Widget> actions;

  const _CenteredSessionScaffold({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.message,
    this.status,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: PremiumCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PremiumIconChip(icon: icon, color: iconColor),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(message, textAlign: TextAlign.center),
                  if (status != null) ...[
                    const SizedBox(height: 12),
                    Chip(label: Text(status!)),
                  ],
                  const SizedBox(height: 20),
                  ...actions.map(
                    (action) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: SizedBox(width: double.infinity, child: action),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SessionLoadingView extends StatelessWidget {
  const _SessionLoadingView();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: PremiumLoadingState(label: 'Verifying secure session'),
  );
}

class _SessionErrorView extends StatelessWidget {
  final String message;
  final Object? error;
  final VoidCallback onRetry;

  const _SessionErrorView({
    required this.message,
    this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    body: PremiumErrorState(title: message, error: error, onRetry: onRetry),
  );
}

String _sessionRoleLabel(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _sessionDateTime(DateTime? value) {
  if (value == null) return 'Syncing…';
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
