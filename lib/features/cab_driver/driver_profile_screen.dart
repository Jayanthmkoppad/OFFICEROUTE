import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/models/location_permission_state_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/premium_widgets.dart';
import '../map/controllers/location_controller.dart';
import 'cab_driver_operational_flow.dart';
import 'controllers/cab_driver_controller.dart';

class DriverProfileScreen extends StatefulWidget {
  final CabDriverOperations data;
  final Future<void> Function() onSignOut;
  final ValueChanged<DriverOperationalPhase> onOpenWorkflow;

  const DriverProfileScreen({
    super.key,
    required this.data,
    required this.onSignOut,
    required this.onOpenWorkflow,
  });

  @override
  State<DriverProfileScreen> createState() => DriverProfileScreenState();
}

class DriverProfileScreenState extends State<DriverProfileScreen>
    with AutomaticKeepAliveClientMixin {
  LocationPermissionStateModel? _permission;
  String _appVersion = 'Unavailable';
  bool _signingOut = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadDeviceState();
  }

  Future<void> _loadDeviceState() async {
    final permission = await LocationController.checkLocationPermission();
    final package = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _permission = permission;
        _appVersion = '${package.version}+${package.buildNumber}';
      });
    }
  }

  String get _initials {
    final parts = widget.data.driver.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'DR';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  bool get _hasUnresolvedTrip => widget.data.activeTrip != null;

  Future<void> _confirmSignOut() async {
    final allowed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          _hasUnresolvedTrip ? Icons.warning_amber : Icons.logout,
          color: _hasUnresolvedTrip ? AppColors.warning : AppColors.error,
        ),
        title: const Text('Sign Out'),
        content: Text(
          _hasUnresolvedTrip
              ? 'An unresolved Driver trip is active. Complete or cancel it before signing out.'
              : 'Signing out will stop Driver location sharing and operational subscriptions. Trip history is preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          if (!_hasUnresolvedTrip)
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('SIGN OUT'),
            ),
        ],
      ),
    );
    if (allowed != true || !mounted) return;
    setState(() => _signingOut = true);
    try {
      await widget.onSignOut();
    } catch (_) {
      if (mounted) {
        setState(() => _signingOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign out could not complete. Please retry.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final driver = widget.data.driver;
    final location = widget.data.locations[driver.uid];
    final centre = driver.serviceCentre.isNotEmpty
        ? driver.serviceCentre
        : driver.branch.isNotEmpty
        ? driver.branch
        : 'Not configured';
    final vehicle = widget.data.vehicle?.registrationNumber.isNotEmpty == true
        ? widget.data.vehicle!.registrationNumber
        : driver.vehicleNumber.isNotEmpty
        ? driver.vehicleNumber
        : 'Not assigned';

    return ListView(
      key: const PageStorageKey('driver-profile-list'),
      padding: const EdgeInsets.all(16),
      children: [
        PremiumCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundImage: driver.profileImage.isEmpty
                    ? null
                    : NetworkImage(driver.profileImage),
                child: driver.profileImage.isEmpty
                    ? Text(
                        _initials,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      driver.employeeCode.isEmpty
                          ? 'Driver code unavailable'
                          : driver.employeeCode,
                    ),
                    const SizedBox(height: 6),
                    PremiumStatusChip(
                      label: widget.data.dutyActive ? 'ON DUTY' : 'OFF DUTY',
                      color: widget.data.dutyActive
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _section('DRIVER INFORMATION', [
          _row(
            Icons.badge,
            'Role',
            driver.role.isEmpty ? 'Driver' : driver.role,
          ),
          _row(
            Icons.phone,
            'Phone',
            driver.phone.isEmpty ? 'Not configured' : driver.phone,
          ),
          _row(Icons.apartment, 'Branch / Service Centre', centre),
          _row(Icons.directions_car, 'Active Vehicle', vehicle),
        ]),
        const SizedBox(height: 12),
        _section('OPERATIONAL STATUS', [
          _row(
            Icons.gps_fixed,
            'GPS',
            _permission == null
                ? 'Checking'
                : _permission!.serviceEnabled
                ? 'Enabled'
                : 'Disabled',
          ),
          _row(
            Icons.privacy_tip,
            'Location Permission',
            _permission?.permissionStatus ?? 'Checking',
          ),
          _row(
            Icons.share_location,
            'Location Sharing',
            location == null ? 'Inactive' : location.status,
          ),
          _row(
            Icons.sync,
            'Last Synchronization',
            _formatTime(widget.data.loadedAt),
          ),
          _row(Icons.info_outline, 'App Version', _appVersion),
        ]),
        const SizedBox(height: 12),
        _section('SUPPORT & PRIVACY', [
          _action(
            Icons.shield_outlined,
            'Data Privacy',
            () => _showInfo(
              'Data Privacy',
              'Driver location is shared only during authorized duty and trip operations. Historical trip records are preserved securely.',
            ),
          ),
          _action(Icons.app_settings_alt, 'App Permissions', () async {
            await LocationController.requestLocationPermission();
            await _loadDeviceState();
          }),
          _action(
            Icons.help_outline,
            'Help',
            () => _showInfo(
              'Driver Help',
              'For assignment or vehicle assistance, contact your service centre or Operations.',
            ),
          ),
          _action(
            Icons.sos,
            'Emergency Support',
            () =>
                widget.onOpenWorkflow(DriverOperationalPhase.emergencySupport),
          ),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: _signingOut ? null : _confirmSignOut,
            icon: _signingOut
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            label: const Text('SIGN OUT'),
          ),
        ),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) => PremiumCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1,
            fontWeight: FontWeight.w900,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );

  Widget _row(IconData icon, String label, String value) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(label),
    trailing: Flexible(
      child: Text(
        value,
        textAlign: TextAlign.end,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );

  Widget _action(IconData icon, String label, VoidCallback action) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(label),
    trailing: const Icon(Icons.chevron_right),
    onTap: action,
  );

  Future<void> _showInfo(String title, String body) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CLOSE'),
        ),
      ],
    ),
  );

  static String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
