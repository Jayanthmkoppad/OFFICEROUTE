import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/design/office_route_colors.dart';
import '../../core/design/office_route_radii.dart';
import '../../core/design/office_route_spacing.dart';
import '../../core/design/office_route_typography.dart';
import '../../core/design/widgets/office_route_card.dart';
import '../../core/design/widgets/office_route_status_chip.dart';
import '../../core/design/office_route_status_style.dart';
import '../auth/services/auth_service.dart';
import 'controllers/employee_transport_controller.dart';

// ---------------------------------------------------------------------------
// EmployeeProfileScreen — Task 3 implementation.
// Visual source of truth: attached Figma PNG export.
// Functional source of truth: existing models, controller, auth service.
// ---------------------------------------------------------------------------
class EmployeeProfileScreen extends StatefulWidget {
  const EmployeeProfileScreen({super.key});

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  bool _isSigningOut = false;
  String _appVersion = 'Loading…';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  /// Loads real package version from PackageInfo.
  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = '${info.version}+${info.buildNumber}';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _appVersion = 'Unavailable';
        });
      }
    }
  }

  // ── identity helpers ──────────────────────────────────────────────────────

  /// Returns up to 2 initials from name; falls back to 'E'.
  String _initials(String name) {
    if (name.isEmpty) return 'E';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  // ── sign-out ──────────────────────────────────────────────────────────────

  Future<void> _handleSignOut(EmployeeTransportController controller) async {
    // Single confirmation dialog — not called from build or listeners.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OfficeRouteColors.raisedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: OfficeRouteRadii.cardRadius,
        ),
        title: const Text('Sign Out', style: OfficeRouteTypography.cardTitle),
        content: const Text(
          'Are you sure you want to sign out? Location sharing will be stopped.',
          style: OfficeRouteTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Sign Out',
              style: OfficeRouteTypography.button.copyWith(
                color: OfficeRouteColors.errorRed,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSigningOut = true);
    try {
      final success = await controller.prepareForSignOut();
      if (!mounted) return;
      if (success) {
        await AuthService.signOut();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              controller.locationStopError ??
                  'Could not stop location sharing. Check your connection and try again.',
            ),
            backgroundColor: OfficeRouteColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  // ── attendance display ────────────────────────────────────────────────────

  String _attendanceLabel(EmployeeTransportController controller) {
    final att = controller.todayAttendance;
    if (att == null) return 'Not checked in';
    final s = att.status.trim().toLowerCase();
    if (s == 'checked in' || s == 'checkedin') return 'Checked in';
    if (s == 'checked out' || s == 'checkedout') return 'Checked out';
    return att.status.isNotEmpty ? att.status : 'Attendance unavailable';
  }

  Color _attendanceColor(EmployeeTransportController controller) {
    final label = _attendanceLabel(controller);
    if (label == 'Checked in') return OfficeRouteColors.readyGreen;
    if (label == 'Checked out') return OfficeRouteColors.liveBlue;
    if (label.startsWith('Not')) return OfficeRouteColors.waitingAmber;
    return OfficeRouteColors.secondaryText;
  }

  // ── location-sharing label ────────────────────────────────────────────────

  String _locationLabel(EmployeeTransportController controller) {
    final perm = controller.locationPermissionStatus;
    final gps = controller.locationServiceStatus;
    if (gps == 'GPS off') return 'GPS disabled';
    if (perm == 'Denied') return 'Permission denied';
    return controller.profileLocationStatus;
  }

  Color _locationColor(String label) {
    switch (label) {
      case 'Active':
        return OfficeRouteColors.readyGreen;
      case 'Stale':
        return OfficeRouteColors.waitingAmber;
      case 'GPS disabled':
      case 'Permission denied':
        return OfficeRouteColors.errorRed;
      default:
        return OfficeRouteColors.secondaryText;
    }
  }

  // ── transport-profile enabled badge ──────────────────────────────────────

  bool _transportProfileEnabled(EmployeeTransportController controller) {
    return controller.myAssignmentMember != null ||
        controller.activeAssignment != null;
  }

  // ── today's operation card ────────────────────────────────────────────────

  String _routeLabel(EmployeeTransportController controller) {
    final vehicle = controller.assignedVehicle;
    final assign = controller.activeAssignment;
    if (vehicle != null && vehicle.vehicleNumber.isNotEmpty) {
      return 'Bus Route ${vehicle.vehicleNumber}';
    }
    if (assign != null && assign.officeName.isNotEmpty) {
      return assign.officeName;
    }
    return 'No assignment today';
  }

  String _driverLabel(EmployeeTransportController controller) {
    final driver = controller.assignedDriver;
    if (driver != null && driver.name.isNotEmpty) {
      return driver.name;
    }
    return 'Driver unavailable';
  }

  bool _isLiveTracking(EmployeeTransportController controller) {
    return controller.activeSession != null &&
        controller.transportTrackingState == 'active';
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final controller = EmployeeTransportScope.of(context);
    final user = controller.currentUser;
    final isLoading = controller.isLoading;

    if (isLoading) {
      return Scaffold(
        backgroundColor: OfficeRouteColors.background,
        body: const Center(
          child: CircularProgressIndicator(
            key: Key('profile_loading_indicator'),
            color: OfficeRouteColors.liveBlue,
          ),
        ),
      );
    }

    if (user == null) {
      return Scaffold(
        backgroundColor: OfficeRouteColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(OfficeRouteSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.person_off_outlined,
                  size: 56,
                  color: OfficeRouteColors.secondaryText,
                ),
                const SizedBox(height: OfficeRouteSpacing.md),
                Text(
                  'Profile unavailable',
                  style: OfficeRouteTypography.sectionTitle.copyWith(
                    color: OfficeRouteColors.secondaryText,
                  ),
                ),
                if (controller.errorMessage != null) ...[
                  const SizedBox(height: OfficeRouteSpacing.sm),
                  Text(
                    controller.errorMessage!,
                    style: OfficeRouteTypography.secondary,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // ── computed display values ──────────────────────────────────────────────
    final name = user.name.isNotEmpty ? user.name : 'Employee';
    final empCode = user.employeeCode.isNotEmpty
        ? user.employeeCode
        : 'Unavailable';
    final branch = user.branch.isNotEmpty ? user.branch : 'Unavailable';

    final homeAddr = user.homeAddress.isNotEmpty
        ? user.homeAddress
        : 'Not saved';
    final hasPickup =
        controller.myAssignmentMember?.pickupName.isNotEmpty == true;
    final pickupName = hasPickup
        ? controller.myAssignmentMember!.pickupName
        : (user.preferredPickupAddress.isNotEmpty
              ? user.preferredPickupAddress
              : 'Pickup not configured');
    final officeAddr =
        controller.activeAssignment?.officeAddress.isNotEmpty == true
        ? controller.activeAssignment!.officeAddress
        : 'No assignment today';

    final transportEnabled = _transportProfileEnabled(controller);
    final attendanceLabel = _attendanceLabel(controller);
    final attendanceColor = _attendanceColor(controller);
    final locationLabel = _locationLabel(controller);
    final locationColor = _locationColor(locationLabel);

    final isLive = _isLiveTracking(controller);

    return Scaffold(
      backgroundColor: OfficeRouteColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: OfficeRouteSpacing.md,
            vertical: OfficeRouteSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Identity hero card (avatar, name, emp code, branch)
              _IdentityHeroCard(
                name: name,
                empCode: empCode,
                branch: branch,
                profileImageUrl: user.profileImage,
                initials: _initials(name),
              ),

              const SizedBox(height: OfficeRouteSpacing.lg),

              // 2. Transport profile section
              _SectionLabel(
                label: 'TRANSPORT PROFILE',
                trailing: OfficeRouteStatusChip(
                  key: const Key('transport_profile_status_chip'),
                  label: transportEnabled ? 'ENABLED' : 'NOT SET',
                  icon: transportEnabled
                      ? Icons.check_circle_outline
                      : Icons.radio_button_unchecked,
                  glowType: transportEnabled
                      ? TransportGlowType.readyGreen
                      : TransportGlowType.none,
                ),
              ),
              const SizedBox(height: OfficeRouteSpacing.xs),
              _TransportProfileCard(
                homeAddress: homeAddr,
                pickupPoint: pickupName,
                officeDestination: officeAddr,
              ),

              const SizedBox(height: OfficeRouteSpacing.lg),

              // 3. Today's operation
              _SectionLabel(label: "TODAY'S OPERATION"),
              const SizedBox(height: OfficeRouteSpacing.xs),
              _TodayOperationCard(
                isLive: isLive,
                routeLabel: _routeLabel(controller),
                driverLabel: _driverLabel(controller),
                hasAssignment: controller.activeAssignment != null,
              ),

              const SizedBox(height: OfficeRouteSpacing.md),

              // 4. Stats row matching Figma (Total Trips & On-Time %)
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      key: const Key('total_trips_stat_tile'),
                      value: 'Unavailable',
                      label: 'Total Trips',
                    ),
                  ),
                  const SizedBox(width: OfficeRouteSpacing.sm),
                  Expanded(
                    child: _StatTile(
                      key: const Key('on_time_stat_tile'),
                      value: 'Unavailable',
                      label: 'On-Time',
                      valueColor: OfficeRouteColors.readyGreen,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: OfficeRouteSpacing.sm),

              // 5. Status summary row (attendance + location)
              Row(
                children: [
                  Expanded(
                    child: _StatusTile(
                      key: const Key('attendance_status_tile'),
                      label: 'Attendance',
                      value: attendanceLabel,
                      valueColor: attendanceColor,
                    ),
                  ),
                  const SizedBox(width: OfficeRouteSpacing.sm),
                  Expanded(
                    child: _StatusTile(
                      key: const Key('location_status_tile'),
                      label: 'Location',
                      value: locationLabel,
                      valueColor: locationColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: OfficeRouteSpacing.lg),

              // 6. Settings / account rows
              OfficeRouteCard(
                child: Column(
                  children: [
                    _SettingsRow(
                      key: const Key('data_privacy_row'),
                      icon: Icons.shield_outlined,
                      label: 'Data Privacy Agreement',
                      onTap: () {},
                    ),
                    Divider(color: OfficeRouteColors.divider, height: 1),
                    _SettingsRow(
                      key: const Key('app_permissions_row'),
                      icon: Icons.security_outlined,
                      label: 'App Permissions',
                      onTap: () => controller.openAppSettings(),
                    ),
                    Divider(color: OfficeRouteColors.divider, height: 1),
                    _SettingsRow(
                      key: const Key('app_version_row'),
                      icon: Icons.info_outline,
                      label: 'App Version',
                      trailing: Text(
                        _appVersion,
                        style: OfficeRouteTypography.secondary,
                      ),
                      showChevron: false,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: OfficeRouteSpacing.lg),

              // 7. Action buttons
              _ActionButton(
                key: const Key('request_change_button'),
                icon: Icons.edit_outlined,
                label: 'Request Change',
                iconColor: OfficeRouteColors.liveBlue,
                textColor: OfficeRouteColors.liveBlue,
                borderColor: OfficeRouteColors.liveBlue.withValues(alpha: 0.5),
                onPressed: () => _showRequestChangeDialog(controller),
              ),
              const SizedBox(height: OfficeRouteSpacing.sm),
              _ActionButton(
                key: const Key('emergency_contact_button'),
                icon: Icons.contact_emergency_outlined,
                label: 'Emergency Contact',
                onPressed: () =>
                    _showEmergencyContact(context, user.emergencyContact),
              ),

              const SizedBox(height: OfficeRouteSpacing.sm),

              // 8. Sign Out
              _SignOutButton(
                isSigningOut: _isSigningOut,
                isDisabled: controller.isActionLoading,
                onPressed: (_isSigningOut || controller.isActionLoading)
                    ? null
                    : () => _handleSignOut(controller),
              ),

              const SizedBox(height: OfficeRouteSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  // ── dialogs / sheets ──────────────────────────────────────────────────────

  void _showEmergencyContact(BuildContext context, String contact) {
    final hasContact = contact.trim().isNotEmpty;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OfficeRouteColors.raisedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: OfficeRouteRadii.cardRadius,
        ),
        title: const Text(
          'Emergency Contact',
          style: OfficeRouteTypography.cardTitle,
        ),
        content: Text(
          hasContact ? contact : 'Emergency contact not configured',
          style: OfficeRouteTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRequestChangeDialog(
    EmployeeTransportController controller,
  ) async {
    final user = controller.currentUser;
    if (user == null) return;

    final homeCtrl = TextEditingController(text: user.homeAddress);
    final pickupCtrl = TextEditingController(text: user.preferredPickupAddress);
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              backgroundColor: OfficeRouteColors.raisedSurface,
              shape: RoundedRectangleBorder(
                borderRadius: OfficeRouteRadii.cardRadius,
              ),
              title: const Text(
                'Request Change',
                style: OfficeRouteTypography.cardTitle,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      key: const Key('home_address_field'),
                      controller: homeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Home address',
                        prefixIcon: Icon(Icons.home_outlined),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: OfficeRouteSpacing.md),
                    TextField(
                      key: const Key('preferred_pickup_field'),
                      controller: pickupCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Preferred pickup address',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: OfficeRouteSpacing.sm),
                    Text(
                      'Pickup and destination assignments are controlled by the Administrator.',
                      style: OfficeRouteTypography.secondary,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  key: const Key('save_request_change_button'),
                  onPressed: saving
                      ? null
                      : () async {
                          final home = homeCtrl.text.trim();
                          final pickup = pickupCtrl.text.trim();
                          if (home.isEmpty || pickup.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Enter both address labels.'),
                              ),
                            );
                            return;
                          }
                          setStateDialog(() => saving = true);
                          final result = await controller.saveTravelLocations(
                            homeAddress: home,
                            homeLatitude: 0.0,
                            homeLongitude: 0.0,
                            pickupAddress: pickup,
                            pickupLatitude: 0.0,
                            pickupLongitude: 0.0,
                          );
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(result.message)),
                              );
                            }
                          }
                        },
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    homeCtrl.dispose();
    pickupCtrl.dispose();
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Private sub-widgets
// ────────────────────────────────────────────────────────────────────────────

/// Hero identity card matching Figma PNG (square rounded avatar, bold name, emp code & branch).
class _IdentityHeroCard extends StatelessWidget {
  const _IdentityHeroCard({
    required this.name,
    required this.empCode,
    required this.branch,
    required this.profileImageUrl,
    required this.initials,
  });

  final String name;
  final String empCode;
  final String branch;
  final String profileImageUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return OfficeRouteCard(
      isHero: true,
      child: Row(
        children: [
          // Avatar: 56x56 square with rounded corners matching Figma PNG
          _ProfileAvatar(
            imageUrl: profileImageUrl,
            initials: initials,
            size: 56,
          ),
          const SizedBox(width: OfficeRouteSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  key: const Key('profile_name_text'),
                  style: OfficeRouteTypography.screenTitle.copyWith(
                    fontSize: 19,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  '$empCode  •  $branch',
                  key: const Key('profile_code_branch_text'),
                  style: OfficeRouteTypography.secondary,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar widget — rounded rectangle container matching Figma frame.
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.imageUrl,
    required this.initials,
    required this.size,
  });

  final String imageUrl;
  final String initials;
  final double size;

  bool get _hasValidUrl =>
      imageUrl.isNotEmpty &&
      (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(14);
    if (_hasValidUrl) {
      return ClipRRect(
        key: const Key('profile_avatar_image'),
        borderRadius: borderRadius,
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _InitialsAvatar(
            initials: initials,
            size: size,
            borderRadius: borderRadius,
          ),
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return _InitialsAvatar(
              initials: initials,
              size: size,
              borderRadius: borderRadius,
            );
          },
        ),
      );
    }
    return _InitialsAvatar(
      key: const Key('profile_avatar_initials'),
      initials: initials,
      size: size,
      borderRadius: borderRadius,
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({
    super.key,
    required this.initials,
    required this.size,
    required this.borderRadius,
  });

  final String initials;
  final double size;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: OfficeRouteColors.liveBlue.withValues(alpha: 0.2),
        borderRadius: borderRadius,
        border: Border.all(
          color: OfficeRouteColors.liveBlue.withValues(alpha: 0.4),
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.45,
            fontWeight: FontWeight.w700,
            color: OfficeRouteColors.liveBlue,
          ),
        ),
      ),
    );
  }
}

/// Inline section label with optional trailing widget.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: OfficeRouteTypography.secondary.copyWith(
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Transport profile card — 3 address rows matching Figma PNG.
class _TransportProfileCard extends StatelessWidget {
  const _TransportProfileCard({
    required this.homeAddress,
    required this.pickupPoint,
    required this.officeDestination,
  });

  final String homeAddress;
  final String pickupPoint;
  final String officeDestination;

  @override
  Widget build(BuildContext context) {
    return OfficeRouteCard(
      child: Column(
        children: [
          _AddressRow(
            key: const Key('home_address_row'),
            icon: Icons.home_outlined,
            label: 'Home Address',
            value: homeAddress,
          ),
          Divider(
            color: OfficeRouteColors.divider,
            height: OfficeRouteSpacing.lg,
          ),
          _AddressRow(
            key: const Key('pickup_point_row'),
            icon: Icons.location_on_outlined,
            label: 'Pickup Point',
            value: pickupPoint,
          ),
          Divider(
            color: OfficeRouteColors.divider,
            height: OfficeRouteSpacing.lg,
          ),
          _AddressRow(
            key: const Key('office_destination_row'),
            icon: Icons.business_outlined,
            label: 'Office Destination',
            value: officeDestination,
          ),
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: OfficeRouteColors.secondaryText),
        const SizedBox(width: OfficeRouteSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: OfficeRouteTypography.secondary),
              const SizedBox(height: 2),
              Text(value, style: OfficeRouteTypography.body, softWrap: true),
            ],
          ),
        ),
      ],
    );
  }
}

/// Today's operation card — live tracking badge, route, driver, action icons.
class _TodayOperationCard extends StatelessWidget {
  const _TodayOperationCard({
    required this.isLive,
    required this.routeLabel,
    required this.driverLabel,
    required this.hasAssignment,
  });

  final bool isLive;
  final String routeLabel;
  final String driverLabel;
  final bool hasAssignment;

  @override
  Widget build(BuildContext context) {
    final glowType = isLive
        ? TransportGlowType.liveBlue
        : TransportGlowType.none;

    return OfficeRouteCard(
      glowType: glowType,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isLive) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: OfficeRouteColors.liveBlue,
                  ),
                ),
                const SizedBox(width: OfficeRouteSpacing.xxs),
                Text(
                  'Live Tracking',
                  style: OfficeRouteTypography.secondary.copyWith(
                    color: OfficeRouteColors.liveBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else ...[
                Expanded(
                  child: Text(
                    hasAssignment ? 'Assignment today' : 'No assignment today',
                    style: OfficeRouteTypography.secondary.copyWith(
                      color: hasAssignment
                          ? OfficeRouteColors.waitingAmber
                          : OfficeRouteColors.secondaryText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const Spacer(),
              Text('ETA: Unavailable', style: OfficeRouteTypography.secondary),
            ],
          ),
          if (hasAssignment) ...[
            const SizedBox(height: OfficeRouteSpacing.sm),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(OfficeRouteSpacing.xs),
                  decoration: BoxDecoration(
                    color: OfficeRouteColors.raisedSurface,
                    borderRadius: OfficeRouteRadii.smallRadius,
                    border: Border.all(color: OfficeRouteColors.border),
                  ),
                  child: const Icon(
                    Icons.directions_bus_outlined,
                    size: 20,
                    color: OfficeRouteColors.primaryText,
                  ),
                ),
                const SizedBox(width: OfficeRouteSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        routeLabel,
                        style: OfficeRouteTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        'Driver: $driverLabel',
                        style: OfficeRouteTypography.secondary,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: OfficeRouteSpacing.xs),
                _CircleIconButton(
                  icon: Icons.call_outlined,
                  tooltip: 'Call driver',
                  onPressed: null,
                ),
                const SizedBox(width: OfficeRouteSpacing.xs),
                _CircleIconButton(
                  icon: Icons.my_location_outlined,
                  tooltip: 'Track on map',
                  onPressed: null,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: OfficeRouteRadii.pillRadius,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: OfficeRouteColors.primarySurface,
            border: Border.all(color: OfficeRouteColors.border),
          ),
          child: Icon(
            icon,
            size: 18,
            color: onPressed != null
                ? OfficeRouteColors.primaryText
                : OfficeRouteColors.disabledText,
          ),
        ),
      ),
    );
  }
}

/// Stat card matching Figma PNG (e.g. 124 Total Trips / 98% On-Time).
class _StatTile extends StatelessWidget {
  const _StatTile({
    super.key,
    required this.value,
    required this.label,
    this.valueColor = OfficeRouteColors.primaryText,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OfficeRouteSpacing.md,
        vertical: OfficeRouteSpacing.md,
      ),
      decoration: BoxDecoration(
        color: OfficeRouteColors.primarySurface,
        borderRadius: OfficeRouteRadii.cardRadius,
        border: Border.all(color: OfficeRouteColors.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: OfficeRouteTypography.secondary,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

/// Small status tile used for attendance and location pairs.
class _StatusTile extends StatelessWidget {
  const _StatusTile({
    super.key,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(OfficeRouteSpacing.md),
      decoration: BoxDecoration(
        color: OfficeRouteColors.primarySurface,
        borderRadius: OfficeRouteRadii.cardRadius,
        border: Border.all(color: OfficeRouteColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: OfficeRouteTypography.secondary),
          const SizedBox(height: 4),
          Text(
            value,
            style: OfficeRouteTypography.body.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

/// Settings list row with optional trailing widget.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: OfficeRouteRadii.cardRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: OfficeRouteSpacing.sm),
        child: Row(
          children: [
            Icon(icon, size: 20, color: OfficeRouteColors.secondaryText),
            const SizedBox(width: OfficeRouteSpacing.sm),
            Expanded(child: Text(label, style: OfficeRouteTypography.body)),
            ?trailing,
            if (showChevron)
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: OfficeRouteColors.secondaryText,
              ),
          ],
        ),
      ),
    );
  }
}

/// Action button matching Figma PNG style.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.iconColor,
    this.textColor,
    this.borderColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? iconColor;
  final Color? textColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor =
        textColor ??
        (onPressed != null
            ? OfficeRouteColors.primaryText
            : OfficeRouteColors.disabledText);
    final effectiveIconColor = iconColor ?? effectiveTextColor;
    final effectiveBorderColor =
        borderColor ??
        (onPressed != null
            ? OfficeRouteColors.border
            : OfficeRouteColors.disabledText.withValues(alpha: 0.3));

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: effectiveIconColor),
        label: Text(
          label,
          style: OfficeRouteTypography.button.copyWith(
            color: effectiveTextColor,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: OfficeRouteSpacing.md),
          side: BorderSide(color: effectiveBorderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }
}

/// Sign-out button — light red background matching Figma PNG.
class _SignOutButton extends StatelessWidget {
  const _SignOutButton({
    required this.isSigningOut,
    required this.isDisabled,
    required this.onPressed,
  });

  final bool isSigningOut;
  final bool isDisabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        key: const Key('sign_out_button'),
        onPressed: onPressed,
        icon: isSigningOut
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE53935)),
                ),
              )
            : const Icon(
                Icons.logout_outlined,
                size: 18,
                color: Color(0xFFE53935),
              ),
        label: Text(
          isSigningOut ? 'Signing Out…' : 'Sign Out',
          style: OfficeRouteTypography.button.copyWith(
            color: const Color(0xFFE53935),
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled
              ? const Color(0xFFF5D6D6).withValues(alpha: 0.4)
              : const Color(0xFFF5D6D6),
          foregroundColor: const Color(0xFFE53935),
          padding: const EdgeInsets.symmetric(vertical: OfficeRouteSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
