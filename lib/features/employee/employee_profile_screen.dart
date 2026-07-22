import 'package:flutter/material.dart';

import '../../core/design/office_route_colors.dart';
import '../../core/design/office_route_radii.dart';
import '../../core/design/office_route_spacing.dart';
import '../../core/design/office_route_typography.dart';
import '../../core/design/widgets/office_route_card.dart';
import '../auth/services/auth_service.dart';
import 'controllers/employee_transport_controller.dart';

class EmployeeProfileScreen extends StatefulWidget {
  const EmployeeProfileScreen({super.key});

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  bool _isSigningOut = false;

  @override
  Widget build(BuildContext context) {
    final controller = EmployeeTransportScope.of(context);
    final user = controller.currentUser;

    final name = user?.name.isNotEmpty == true ? user!.name : '—';
    final email = user?.email ?? '—';
    final phone = user?.phone.isNotEmpty == true ? user!.phone : '—';
    final empCode = user?.employeeCode.isNotEmpty == true
        ? user!.employeeCode
        : '—';
    final branch = user?.branch.isNotEmpty == true ? user!.branch : '—';
    final dept = user?.department.isNotEmpty == true ? user!.department : '—';

    final attendanceStatus =
        controller.todayAttendance?.status ?? 'Not checked in';
    final locationSharingStatus = controller.profileLocationStatus;

    // Pickup status with admin context
    final hasPickup =
        controller.myAssignmentMember?.pickupName.isNotEmpty == true;
    final pickupStatus = hasPickup
        ? 'Configured'
        : 'Not configured by Administrator';

    final pickupPoint = hasPickup
        ? controller.myAssignmentMember!.pickupName
        : 'Not configured';

    final assignedRoute =
        controller.activeAssignment?.officeName.isNotEmpty == true
        ? controller.activeAssignment!.officeName
        : 'Waiting for assignment';

    // Better freshness formatting
    final empLoc = controller.employeeLiveLocation;
    final lastLocationFreshness = EmployeeTransportController.formatFreshness(
      empLoc?.updatedAt,
    );

    return Scaffold(
      backgroundColor: OfficeRouteColors.background,
      appBar: AppBar(
        backgroundColor: OfficeRouteColors.background,
        elevation: 0,
        title: const Text(
          'Employee Profile',
          style: OfficeRouteTypography.sectionTitle,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(OfficeRouteSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Identity Header Card
            OfficeRouteCard(
              isHero: true,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: OfficeRouteColors.primarySurface,
                    child: Text(
                      name.isNotEmpty && name != '—'
                          ? name[0].toUpperCase()
                          : 'E',
                      style: OfficeRouteTypography.screenTitle.copyWith(
                        color: OfficeRouteColors.primaryText,
                      ),
                    ),
                  ),
                  const SizedBox(width: OfficeRouteSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: OfficeRouteTypography.screenTitle.copyWith(
                            fontSize: 20,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Employee Code: $empCode',
                          style: OfficeRouteTypography.secondary,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: OfficeRouteTypography.secondary.copyWith(
                            color: OfficeRouteColors.liveBlue,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: OfficeRouteSpacing.lg),

            // Corporate Details Card
            OfficeRouteCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CORPORATE IDENTITY',
                    style: OfficeRouteTypography.secondary.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: OfficeRouteSpacing.sm),
                  _buildProfileRow('Department', dept),
                  const Divider(color: OfficeRouteColors.divider, height: 16),
                  _buildProfileRow('Branch Location', branch),
                  const Divider(color: OfficeRouteColors.divider, height: 16),
                  _buildProfileRow('Phone Number', phone),
                  const Divider(color: OfficeRouteColors.divider, height: 16),
                  _buildProfileRow('Saved Pickup Point', pickupPoint),
                  const Divider(color: OfficeRouteColors.divider, height: 16),
                  _buildProfileRow(
                    'Pickup Status',
                    pickupStatus,
                    valueColor: hasPickup
                        ? OfficeRouteColors.readyGreen
                        : OfficeRouteColors.waitingAmber,
                  ),
                ],
              ),
            ),

            const SizedBox(height: OfficeRouteSpacing.lg),

            // Live Operational Info Card
            OfficeRouteCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LIVE OPERATIONAL STATUS',
                    style: OfficeRouteTypography.secondary.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: OfficeRouteSpacing.sm),
                  _buildProfileRow('Attendance Status', attendanceStatus),
                  const Divider(color: OfficeRouteColors.divider, height: 16),
                  _buildProfileRow(
                    'Location Permission',
                    controller.locationPermissionStatus,
                  ),
                  const Divider(color: OfficeRouteColors.divider, height: 16),
                  _buildProfileRow('Location Sharing', locationSharingStatus),
                  const Divider(color: OfficeRouteColors.divider, height: 16),
                  _buildProfileRow(
                    'Last Location Freshness',
                    lastLocationFreshness,
                  ),
                  const Divider(color: OfficeRouteColors.divider, height: 16),
                  _buildProfileRow('Assigned Route/Destination', assignedRoute),
                ],
              ),
            ),

            const SizedBox(height: OfficeRouteSpacing.lg),

            // Sign Out Button with loading guard
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('sign_out_button'),
                onPressed: (_isSigningOut || controller.isActionLoading)
                    ? null
                    : () => _handleSignOut(controller),
                icon: _isSigningOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            OfficeRouteColors.errorRed,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.logout,
                        color: OfficeRouteColors.errorRed,
                      ),
                label: Text(
                  _isSigningOut ? 'Signing Out…' : 'Sign Out',
                  style: OfficeRouteTypography.button.copyWith(
                    color: _isSigningOut
                        ? OfficeRouteColors.disabledText
                        : OfficeRouteColors.errorRed,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: OfficeRouteSpacing.md,
                  ),
                  side: BorderSide(
                    color: _isSigningOut
                        ? OfficeRouteColors.disabledText
                        : OfficeRouteColors.errorRed,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: OfficeRouteRadii.smallRadius,
                  ),
                ),
              ),
            ),

            const SizedBox(height: OfficeRouteSpacing.xl),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSignOut(EmployeeTransportController controller) async {
    setState(() => _isSigningOut = true);
    try {
      final success = await controller.prepareForSignOut();
      if (success && mounted) {
        await AuthService.signOut();
      } else if (!success && mounted) {
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
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  Widget _buildProfileRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OfficeRouteSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: OfficeRouteTypography.secondary),
          const SizedBox(width: OfficeRouteSpacing.sm),
          Expanded(
            child: Text(
              value,
              style: OfficeRouteTypography.body.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
              textAlign: TextAlign.end,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}
