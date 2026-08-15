import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../cab_driver/cab_driver_app.dart';
import '../employee/employee_app.dart';
import '../home/home_screen.dart';
import '../manager/manager_screen.dart';
import '../service_engineer/service_engineer_app.dart';

const bool developmentAccessEnabled = bool.fromEnvironment(
  'OFFICEROUTE_DEV_ACCESS',
  defaultValue: false,
);

bool shouldEnableDevelopmentRolePreview({
  required bool debugMode,
  required bool configured,
}) => debugMode && configured;

enum DevelopmentTestRole {
  employee('Employee'),
  administrator('Admin'),
  manager('Manager'),
  cabDriver('Cab Driver'),
  serviceEngineer('Service Engineer');

  const DevelopmentTestRole(this.label);
  final String label;
}

Widget developmentRoleApp(DevelopmentTestRole role) => switch (role) {
  DevelopmentTestRole.employee => const EmployeeApp(),
  DevelopmentTestRole.administrator => const HomeScreen(),
  DevelopmentTestRole.manager => const ManagerScreen(),
  DevelopmentTestRole.cabDriver => const CabDriverApp(),
  DevelopmentTestRole.serviceEngineer => const ServiceEngineerApp(),
};

class DevelopmentAccessGate extends StatefulWidget {
  const DevelopmentAccessGate({
    super.key,
    required this.realAuthentication,
    this.firebaseUserId,
    this.debugMode = kDebugMode,
    this.configured = developmentAccessEnabled,
    this.roleAppBuilder,
    this.firebaseUserRole,
    this.roleLoader,
  });

  final Widget realAuthentication;
  final String? firebaseUserId;
  final bool debugMode;
  final bool configured;
  final Widget Function(DevelopmentTestRole role)? roleAppBuilder;
  final String? firebaseUserRole;
  final Future<String?> Function(String uid)? roleLoader;

  @override
  State<DevelopmentAccessGate> createState() => _DevelopmentAccessGateState();
}

class _DevelopmentAccessGateState extends State<DevelopmentAccessGate> {
  DevelopmentTestRole? _selectedRole;
  bool _useRealLogin = false;
  String? _realRole;
  bool _roleResolved = false;

  @override
  void didUpdateWidget(covariant DevelopmentAccessGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.firebaseUserId != widget.firebaseUserId) {
      _selectedRole = null;
      _useRealLogin = false;
    }
  }

  Future<void> _selectRole(DevelopmentTestRole selected) async {
    debugPrint('DEV_AUTH_UID=${widget.firebaseUserId ?? 'unavailable'}');
    debugPrint('DEV_SELECTED_PREVIEW_ROLE=${selected.name}');
    debugPrint('DEV_IDENTITY_MODE=ui_preview_only');
    setState(() {
      _selectedRole = selected;
      _realRole = widget.firebaseUserRole;
      _roleResolved =
          widget.firebaseUserRole != null || widget.roleLoader == null;
    });
    final uid = widget.firebaseUserId, loader = widget.roleLoader;
    if (widget.firebaseUserRole == null &&
        loader != null &&
        uid != null &&
        uid.isNotEmpty) {
      String? resolved;
      try {
        resolved = await loader(uid);
      } catch (error) {
        debugPrint('DEV_AUTH_ROLE_LOOKUP_ERROR=$error');
      }
      if (mounted && _selectedRole == selected) {
        setState(() {
          _realRole = resolved ?? 'unknown';
          _roleResolved = true;
        });
      }
    }
  }

  void _openRealLogin() {
    setState(() {
      _selectedRole = null;
      _useRealLogin = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!shouldEnableDevelopmentRolePreview(
          debugMode: widget.debugMode,
          configured: widget.configured,
        ) ||
        _useRealLogin) {
      return widget.realAuthentication;
    }
    final role = _selectedRole;
    if (role == null) {
      return DevelopmentRoleSelector(
        onSelected: _selectRole,
        onUseRealLogin: _openRealLogin,
      );
    }
    return _DevelopmentRoleShell(
      role: role,
      roleApp: widget.roleAppBuilder?.call(role) ?? developmentRoleApp(role),
      realRole: _realRole,
      roleResolved: _roleResolved,
      onChangeRole: () => setState(() => _selectedRole = null),
      onUseRealLogin: _openRealLogin,
    );
  }
}

class DevelopmentRoleSelector extends StatelessWidget {
  const DevelopmentRoleSelector({
    super.key,
    required this.onSelected,
    required this.onUseRealLogin,
  });

  final ValueChanged<DevelopmentTestRole> onSelected;
  final VoidCallback onUseRealLogin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WHO ARE YOU?')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.amber.withValues(alpha: 0.15),
            child: const Text(
              'DEV visual preview only. Role preview does not change Firebase identity. Use separate test accounts for Driver/Employee backend testing.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              key: const Key('use_real_login'),
              onPressed: onUseRealLogin,
              icon: const Icon(Icons.login),
              label: const Text('Use Real Login'),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: DevelopmentTestRole.values.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final role = DevelopmentTestRole.values[index];
                return ListTile(
                  key: Key('development_role_${role.name}'),
                  leading: Icon(_icon(role)),
                  title: Text(role.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onSelected(role),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _icon(DevelopmentTestRole role) => switch (role) {
    DevelopmentTestRole.employee => Icons.badge_outlined,
    DevelopmentTestRole.administrator => Icons.admin_panel_settings_outlined,
    DevelopmentTestRole.manager => Icons.supervisor_account_outlined,
    DevelopmentTestRole.cabDriver => Icons.local_taxi_outlined,
    DevelopmentTestRole.serviceEngineer => Icons.engineering_outlined,
  };
}

class _DevelopmentRoleShell extends StatelessWidget {
  const _DevelopmentRoleShell({
    required this.role,
    required this.roleApp,
    required this.onChangeRole,
    required this.realRole,
    required this.roleResolved,
    required this.onUseRealLogin,
  });

  final DevelopmentTestRole role;
  final Widget roleApp;
  final VoidCallback onChangeRole;
  final String? realRole;
  final bool roleResolved;
  final VoidCallback onUseRealLogin;

  Widget _content() {
    if (!roleResolved) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (realRole == null) return roleApp;
    final normalized = realRole!.trim().toLowerCase().replaceAll(' ', '_');
    final expected = role == DevelopmentTestRole.cabDriver
        ? {'cab_driver', 'driver'}
        : role == DevelopmentTestRole.employee
        ? {'employee'}
        : <String>{};
    if (expected.isEmpty || expected.contains(normalized)) return roleApp;
    final isDriver = role == DevelopmentTestRole.cabDriver;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDriver ? 'Cab Driver UI Preview' : 'Employee UI Preview',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isDriver
                        ? 'Firebase identity is currently ${realRole ?? 'unknown'}.\nReal Employee directory and invitations require a real Cab Driver account.'
                        : 'Invitations are linked to Firebase user identity.\nUse a real Employee login to test invitation delivery.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: onUseRealLogin,
                        child: const Text('USE REAL LOGIN'),
                      ),
                      OutlinedButton(
                        onPressed: onChangeRole,
                        child: const Text('SWITCH DEV ROLE'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onChangeRole();
      },
      child: Stack(
        children: [
          Positioned.fill(child: _content()),
          Positioned(
            left: 8,
            right: 8,
            bottom: MediaQuery.paddingOf(context).bottom + 76,
            child: Material(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Preview only - Firebase identity unchanged',
                      style: TextStyle(color: Colors.amber, fontSize: 11),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        children: [
                          TextButton(
                            key: const Key('switch_dev_role'),
                            onPressed: onChangeRole,
                            child: const Text('SWITCH DEV ROLE'),
                          ),
                          TextButton(
                            key: const Key('exit_role_preview'),
                            onPressed: onUseRealLogin,
                            child: const Text('USE REAL LOGIN'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 6,
            right: 8,
            child: Material(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(4),
              child: InkWell(
                key: const Key('change_test_role'),
                onTap: onChangeRole,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  child: Text(
                    'DEV PREVIEW - ${role.label.toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
