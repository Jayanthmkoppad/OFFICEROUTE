import 'package:flutter/material.dart';

import '../../core/design/office_route_colors.dart';
import '../../core/design/office_route_radii.dart';
import '../../core/design/office_route_spacing.dart';
import '../../core/design/office_route_status_style.dart';
import '../../core/design/office_route_typography.dart';
import '../../core/design/widgets/office_route_card.dart';
import '../../core/design/widgets/office_route_empty_state.dart';
import '../../core/design/widgets/office_route_live_indicator.dart';
import '../../core/design/widgets/office_route_metric_tile.dart';
import '../../core/design/widgets/office_route_passenger_progress_tile.dart';
import '../../core/design/widgets/office_route_primary_button.dart';
import '../../core/design/widgets/office_route_section_header.dart';
import '../../core/design/widgets/office_route_status_chip.dart';
import 'controllers/employee_transport_controller.dart';

class EmployeeHomeScreen extends StatelessWidget {
  final VoidCallback onNavigateToMap;

  const EmployeeHomeScreen({super.key, required this.onNavigateToMap});

  @override
  Widget build(BuildContext context) {
    final controller = EmployeeTransportScope.of(context);
    final user = controller.currentUser;
    final userName = user?.name.isNotEmpty == true ? user!.name : '—';
    final connStatus = controller.connectionStatus;
    final isTracking = connStatus == 'TRACKING';
    final state = controller.homeState;

    return Scaffold(
      backgroundColor: OfficeRouteColors.background,
      appBar: AppBar(
        backgroundColor: OfficeRouteColors.background,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: OfficeRouteColors.raisedSurface,
              child: Text(
                userName.isNotEmpty && userName != '—'
                    ? userName[0].toUpperCase()
                    : 'E',
                style: OfficeRouteTypography.cardTitle.copyWith(
                  color: OfficeRouteColors.primaryText,
                ),
              ),
            ),
            const SizedBox(width: OfficeRouteSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: OfficeRouteTypography.cardTitle.copyWith(
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    user?.employeeCode.isNotEmpty == true
                        ? user!.employeeCode
                        : '—',
                    style: OfficeRouteTypography.secondary.copyWith(
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: OfficeRouteSpacing.md),
            child: OfficeRouteLiveIndicator(
              label: connStatus,
              isLive: isTracking,
              color: isTracking
                  ? OfficeRouteColors.readyGreen
                  : (connStatus == 'STALE' || connStatus == 'LOCATION OFF'
                        ? OfficeRouteColors.errorRed
                        : OfficeRouteColors.secondaryText),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(OfficeRouteSpacing.md),
          child: _buildStateBody(context, controller, state),
        ),
      ),
    );
  }

  /// Master state router — returns the correct layout for each of the
  /// 13 states (A–M).
  Widget _buildStateBody(
    BuildContext context,
    EmployeeTransportController controller,
    String state,
  ) {
    switch (state) {
      case 'A':
        return _buildStateA(context, controller);
      case 'B':
        return _buildStateB(context, controller);
      case 'C':
        return _buildStateC(context, controller);
      case 'D':
        return _buildStateD(context, controller);
      case 'E':
        return _buildStateE(context, controller);
      case 'F':
        return _buildStateFGHI(context, controller, state);
      case 'G':
        return _buildStateFGHI(context, controller, state);
      case 'H':
        return _buildStateFGHI(context, controller, state);
      case 'I':
        return _buildStateFGHI(context, controller, state);
      case 'J':
        return _buildStateJ(context, controller);
      case 'K':
        return _buildStateK(context, controller);
      case 'L':
        return _buildStateL(context, controller);
      case 'M':
        return _buildStateM(context, controller);
      default:
        return _buildStateA(context, controller);
    }
  }

  // ─── STATE A: Attendance not started ──────────────────────────────

  Widget _buildStateA(
    BuildContext context,
    EmployeeTransportController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroCard(
          context,
          controller,
          headline: 'Start Duty',
          explanation: 'Check in to begin your workday and transport tracking.',
          icon: Icons.flash_on,
          glow: TransportGlowType.liveBlue,
          actionLabel: 'Start Duty',
          onAction: () => _handleStartDuty(context, controller),
        ),
        const SizedBox(height: OfficeRouteSpacing.xl),
      ],
    );
  }

  // ─── STATE B: Attendance active, no route ─────────────────────────

  Widget _buildStateB(
    BuildContext context,
    EmployeeTransportController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAttendanceRow(controller),
        const SizedBox(height: OfficeRouteSpacing.lg),
        OfficeRouteEmptyState(
          key: const Key('no_route_card'),
          title: 'No route assigned for today',
          description:
              'Your Administrator has not assigned a cab route for today.',
          icon: Icons.directions_bus_outlined,
          action: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _actionChip('Refresh Status', Icons.refresh, () {}),
                  const SizedBox(width: OfficeRouteSpacing.xs),
                  _actionChip(
                    'Contact Administrator',
                    Icons.support_agent,
                    () {},
                  ),
                ],
              ),
              const SizedBox(height: OfficeRouteSpacing.xs),
              _actionChip(
                'Setup Test Route (Demo)',
                Icons.science_outlined,
                () => controller.setupTestAssignmentForTesting(),
              ),
            ],
          ),
        ),
        const SizedBox(height: OfficeRouteSpacing.xl),
      ],
    );
  }

  // ─── STATE C: Route assigned, pickup missing ──────────────────────

  Widget _buildStateC(
    BuildContext context,
    EmployeeTransportController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAttendanceRow(controller),
        const SizedBox(height: OfficeRouteSpacing.lg),
        OfficeRouteEmptyState(
          key: const Key('pickup_missing_card'),
          title: 'Pickup point not configured',
          description:
              'Your permanent pickup location must be configured by an Administrator.',
          icon: Icons.location_off_outlined,
          action: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _actionChip('Refresh Status', Icons.refresh, () {}),
              const SizedBox(width: OfficeRouteSpacing.xs),
              _actionChip('Contact Administrator', Icons.support_agent, () {}),
            ],
          ),
        ),
        const SizedBox(height: OfficeRouteSpacing.xl),
      ],
    );
  }

  // ─── STATE D: Pickup OK, Driver pending ───────────────────────────

  Widget _buildStateD(
    BuildContext context,
    EmployeeTransportController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAttendanceRow(controller),
        const SizedBox(height: OfficeRouteSpacing.lg),
        _buildPickupInfoCard(controller),
        const SizedBox(height: OfficeRouteSpacing.lg),
        OfficeRouteCard(
          child: Row(
            children: [
              const Icon(
                Icons.person_search_outlined,
                color: OfficeRouteColors.waitingAmber,
                size: 24,
              ),
              const SizedBox(width: OfficeRouteSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Waiting for driver assignment',
                      style: OfficeRouteTypography.cardTitle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your route has a pickup point but no driver has been assigned yet.',
                      style: OfficeRouteTypography.secondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: OfficeRouteSpacing.xl),
      ],
    );
  }

  // ─── STATE E: Driver assigned, trip not started ───────────────────

  Widget _buildStateE(
    BuildContext context,
    EmployeeTransportController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAttendanceRow(controller),
        const SizedBox(height: OfficeRouteSpacing.lg),
        _buildPickupInfoCard(controller),
        const SizedBox(height: OfficeRouteSpacing.lg),
        _buildTransportInfoCard(controller),
        const SizedBox(height: OfficeRouteSpacing.lg),
        OfficeRouteCard(
          child: Row(
            children: [
              const Icon(
                Icons.schedule,
                color: OfficeRouteColors.waitingAmber,
                size: 24,
              ),
              const SizedBox(width: OfficeRouteSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trip not started yet',
                      style: OfficeRouteTypography.cardTitle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your driver has been assigned. The trip will begin shortly.',
                      style: OfficeRouteTypography.secondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: OfficeRouteSpacing.xl),
      ],
    );
  }

  // ─── STATES F/G/H/I: Active trip + live data ─────────────────────

  Widget _buildStateFGHI(
    BuildContext context,
    EmployeeTransportController controller,
    String state,
  ) {
    final actionLabel = controller.contextualActionLabel;
    final canTrigger =
        actionLabel == "I'm Ready at Pickup" || actionLabel == 'Go to Pickup';

    TransportGlowType glow = TransportGlowType.liveBlue;
    IconData heroIcon = Icons.directions_run;
    String headline = actionLabel;
    String explanation = 'Head to your pickup point.';

    if (state == 'G') {
      glow = TransportGlowType.readyGreen;
      heroIcon = Icons.check_circle;
      explanation = 'Your driver has been notified. Please wait at the pickup.';
    } else if (state == 'H') {
      glow = TransportGlowType.readyGreen;
      heroIcon = Icons.local_taxi;
      explanation = 'Your cab is arriving at the pickup point.';
    } else if (state == 'I') {
      glow = TransportGlowType.readyGreen;
      heroIcon = Icons.directions_car;
      explanation = 'You have been picked up. Enjoy your ride.';
    }

    final empDist = controller.employeeDistanceToPickupMeters;
    final cabDist = controller.cabDistanceToPickupMeters;
    final showMetrics = empDist != null || cabDist != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroCard(
          context,
          controller,
          headline: headline,
          explanation: explanation,
          icon: heroIcon,
          glow: glow,
          actionLabel: canTrigger ? actionLabel : null,
          onAction: canTrigger
              ? () async {
                  if (actionLabel == "I'm Ready at Pickup") {
                    await _handleMarkReady(context, controller);
                  }
                }
              : null,
          showLiveBadge: controller.activeTrip?.status == 'active',
        ),
        const SizedBox(height: OfficeRouteSpacing.lg),
        _buildAttendanceRow(controller),

        // Operational Metrics — only when data exists
        if (showMetrics) ...[
          const SizedBox(height: OfficeRouteSpacing.lg),
          Row(
            children: [
              if (empDist != null)
                Expanded(
                  child: OfficeRouteCard(
                    child: OfficeRouteMetricTile(
                      key: const Key('employee_distance_card'),
                      label: 'You → Pickup',
                      value: '${empDist.round()} m',
                      subtitle: 'Straight-line',
                      icon: Icons.person_pin_circle_outlined,
                      accentColor: OfficeRouteColors.liveBlue,
                    ),
                  ),
                ),
              if (empDist != null && cabDist != null)
                const SizedBox(width: OfficeRouteSpacing.xs),
              if (cabDist != null)
                Expanded(
                  child: OfficeRouteCard(
                    child: OfficeRouteMetricTile(
                      key: const Key('cab_distance_card'),
                      label: 'Cab → Pickup',
                      value: '${cabDist.round()} m',
                      subtitle: 'Straight-line',
                      icon: Icons.directions_car_outlined,
                      accentColor: OfficeRouteColors.readyGreen,
                    ),
                  ),
                ),
            ],
          ),
        ],

        const SizedBox(height: OfficeRouteSpacing.lg),
        _buildTransportInfoCard(controller),

        // Passenger Progress — only when trip data exists
        if (controller.passengerProgressList.isNotEmpty) ...[
          const SizedBox(height: OfficeRouteSpacing.lg),
          const OfficeRouteSectionHeader(
            key: Key('passenger_progress_section'),
            title: 'Trip Passenger Progress',
            subtitle: 'Secure progress updates for assigned passengers',
          ),
          ...controller.passengerProgressList.map(
            (p) => OfficeRoutePassengerProgressTile(
              sequence: p.pickupSequence,
              passengerName: p.passengerDisplayName,
              statusText: p.status.replaceAll('_', ' '),
              statusGlow: (p.status == 'ready' || p.status == 'picked_up')
                  ? TransportGlowType.readyGreen
                  : (p.status == 'travelling_to_pickup'
                        ? TransportGlowType.liveBlue
                        : TransportGlowType.none),
              distanceText: p.distanceToPickupMeters != null
                  ? '${p.distanceToPickupMeters!.round()} m from pickup'
                  : null,
              timeEstimateText: p.estimatedReadyMinutes != null
                  ? '${p.estimatedReadyMinutes} min'
                  : '—',
              freshnessText: p.formatAge(DateTime.now()),
            ),
          ),
        ],

        const SizedBox(height: OfficeRouteSpacing.xl),
      ],
    );
  }

  // ─── STATE J: Trip completed ──────────────────────────────────────

  Widget _buildStateJ(
    BuildContext context,
    EmployeeTransportController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAttendanceRow(controller),
        const SizedBox(height: OfficeRouteSpacing.lg),
        OfficeRouteCard(
          isHero: true,
          glowType: TransportGlowType.readyGreen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OfficeRouteStatusChip(
                label: 'Trip Completed',
                icon: Icons.done_all,
                glowType: TransportGlowType.readyGreen,
              ),
              const SizedBox(height: OfficeRouteSpacing.md),
              Text(
                'Your transport is complete for today.',
                style: OfficeRouteTypography.body,
              ),
              const SizedBox(height: OfficeRouteSpacing.xs),
              Text(
                controller.todayAttendance?.status == 'Checked Out'
                    ? 'Duty completed. See you tomorrow!'
                    : 'Your cab trip has ended. Have a great day!',
                style: OfficeRouteTypography.secondary,
              ),
            ],
          ),
        ),
        const SizedBox(height: OfficeRouteSpacing.xl),
      ],
    );
  }

  // ─── STATE K: Sync pending ────────────────────────────────────────

  Widget _buildStateK(
    BuildContext context,
    EmployeeTransportController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAttendanceRow(controller),
        const SizedBox(height: OfficeRouteSpacing.lg),
        OfficeRouteCard(
          isHero: true,
          glowType: TransportGlowType.waitingAmber,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OfficeRouteStatusChip(
                label: 'Synchronization Pending',
                icon: Icons.sync_problem,
                glowType: TransportGlowType.waitingAmber,
              ),
              const SizedBox(height: OfficeRouteSpacing.md),
              Text(
                controller.contextualStatusMessage,
                style: OfficeRouteTypography.body,
              ),
              const SizedBox(height: OfficeRouteSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OfficeRoutePrimaryButton(
                  key: const Key('retry_sync_button'),
                  label: 'Retry Sync',
                  icon: Icons.sync,
                  isLoading: controller.isActionLoading,
                  glowType: TransportGlowType.waitingAmber,
                  onPressed: controller.isActionLoading
                      ? null
                      : () => controller.retryTripSynchronization(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: OfficeRouteSpacing.xl),
      ],
    );
  }

  // ─── STATE L: Location stop failed ────────────────────────────────

  Widget _buildStateL(
    BuildContext context,
    EmployeeTransportController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAttendanceRow(controller),
        const SizedBox(height: OfficeRouteSpacing.lg),
        OfficeRouteCard(
          isHero: true,
          glowType: TransportGlowType.errorRed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OfficeRouteStatusChip(
                label: 'Location Stop Failed',
                icon: Icons.error_outline,
                glowType: TransportGlowType.errorRed,
              ),
              const SizedBox(height: OfficeRouteSpacing.md),
              Text(
                controller.contextualStatusMessage,
                style: OfficeRouteTypography.body,
              ),
              const SizedBox(height: OfficeRouteSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OfficeRoutePrimaryButton(
                  key: const Key('retry_stop_button'),
                  label: 'Retry Stop',
                  icon: Icons.stop_circle_outlined,
                  isLoading: controller.isActionLoading,
                  glowType: TransportGlowType.errorRed,
                  onPressed: controller.isActionLoading
                      ? null
                      : () => controller.retryStopLocationSharing(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: OfficeRouteSpacing.xl),
      ],
    );
  }

  // ─── STATE M: Offline / Error ─────────────────────────────────────

  Widget _buildStateM(
    BuildContext context,
    EmployeeTransportController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OfficeRouteCard(
          isHero: true,
          glowType: TransportGlowType.errorRed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.cloud_off,
                    color: OfficeRouteColors.errorRed,
                    size: 24,
                  ),
                  const SizedBox(width: OfficeRouteSpacing.xs),
                  Text(
                    'Connection Issue',
                    style: OfficeRouteTypography.cardTitle,
                  ),
                ],
              ),
              const SizedBox(height: OfficeRouteSpacing.md),
              Text(
                controller.contextualStatusMessage.isNotEmpty
                    ? controller.contextualStatusMessage
                    : "You're offline. Live transport updates will resume when your connection returns.",
                style: OfficeRouteTypography.body,
              ),
            ],
          ),
        ),
        const SizedBox(height: OfficeRouteSpacing.xl),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SHARED BUILDING BLOCKS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildHeroCard(
    BuildContext context,
    EmployeeTransportController controller, {
    required String headline,
    required String explanation,
    required IconData icon,
    required TransportGlowType glow,
    String? actionLabel,
    VoidCallback? onAction,
    bool showLiveBadge = false,
  }) {
    final member = controller.myAssignmentMember;
    final pickupName = member?.pickupName.isNotEmpty == true
        ? member!.pickupName
        : null;
    final pickupAddress = member?.pickupAddress.isNotEmpty == true
        ? member!.pickupAddress
        : null;

    return OfficeRouteCard(
      isHero: true,
      glowType: glow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: OfficeRouteStatusChip(
                  label: headline,
                  icon: icon,
                  glowType: glow,
                ),
              ),
              if (showLiveBadge)
                const OfficeRouteStatusChip(
                  label: 'LIVE TRIP',
                  icon: Icons.directions_car,
                  glowType: TransportGlowType.liveBlue,
                ),
            ],
          ),
          const SizedBox(height: OfficeRouteSpacing.md),
          if (pickupName != null) ...[
            Text(
              pickupName,
              style: OfficeRouteTypography.screenTitle.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 4),
          ],
          if (pickupAddress != null) ...[
            Text(
              pickupAddress,
              style: OfficeRouteTypography.secondary.copyWith(
                color: OfficeRouteColors.secondaryText,
              ),
            ),
            const SizedBox(height: OfficeRouteSpacing.xs),
          ],
          Text(explanation, style: OfficeRouteTypography.secondary),
          if (actionLabel != null) ...[
            const SizedBox(height: OfficeRouteSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OfficeRoutePrimaryButton(
                    label: actionLabel,
                    icon: actionLabel == "I'm Ready at Pickup"
                        ? Icons.my_location
                        : Icons.flash_on,
                    glowType: actionLabel == "I'm Ready at Pickup"
                        ? TransportGlowType.readyGreen
                        : TransportGlowType.liveBlue,
                    isLoading: controller.isActionLoading,
                    onPressed: controller.isActionLoading ? null : onAction,
                  ),
                ),
                const SizedBox(width: OfficeRouteSpacing.xs),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: OfficeRouteColors.raisedSurface,
                    padding: const EdgeInsets.all(OfficeRouteSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        OfficeRouteRadii.small,
                      ),
                    ),
                  ),
                  icon: const Icon(
                    Icons.map_outlined,
                    color: OfficeRouteColors.primaryText,
                  ),
                  onPressed: onNavigateToMap,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttendanceRow(EmployeeTransportController controller) {
    final attendance = controller.todayAttendance;
    final status = attendance?.status ?? 'Not checked in';
    final checkInTime = attendance?.checkInTime;
    final timeStr = checkInTime != null
        ? '${checkInTime.hour.toString().padLeft(2, '0')}:${checkInTime.minute.toString().padLeft(2, '0')}'
        : '—';

    return OfficeRouteCard(
      child: Row(
        children: [
          Icon(
            status == 'Checked In'
                ? Icons.check_circle_outline
                : Icons.access_time,
            color: status == 'Checked In'
                ? OfficeRouteColors.readyGreen
                : OfficeRouteColors.secondaryText,
            size: 20,
          ),
          const SizedBox(width: OfficeRouteSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: OfficeRouteTypography.cardTitle.copyWith(fontSize: 14),
                ),
                if (status == 'Checked In')
                  Text(
                    'Check-in time: $timeStr',
                    style: OfficeRouteTypography.secondary,
                  ),
              ],
            ),
          ),
          Text(
            controller.myAssignmentMember == null
                ? 'Transport: Waiting for assignment'
                : '',
            style: OfficeRouteTypography.secondary.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPickupInfoCard(EmployeeTransportController controller) {
    final member = controller.myAssignmentMember;
    final pickupName = member?.pickupName.isNotEmpty == true
        ? member!.pickupName
        : '—';
    final pickupAddress = member?.pickupAddress.isNotEmpty == true
        ? member!.pickupAddress
        : '—';

    return OfficeRouteCard(
      child: Row(
        children: [
          const Icon(
            Icons.location_on_outlined,
            color: OfficeRouteColors.readyGreen,
            size: 24,
          ),
          const SizedBox(width: OfficeRouteSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pickupName,
                  style: OfficeRouteTypography.cardTitle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(pickupAddress, style: OfficeRouteTypography.secondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportInfoCard(EmployeeTransportController controller) {
    final assignment = controller.activeAssignment;
    final driverName = controller.driverDisplayName;
    final vehicleId = assignment?.vehicleId.isNotEmpty == true
        ? assignment!.vehicleId
        : '—';
    final officeName = assignment?.officeName.isNotEmpty == true
        ? assignment!.officeName
        : '—';

    return OfficeRouteCard(
      child: Column(
        children: [
          _buildDetailRow('Assigned Driver', driverName),
          const Divider(color: OfficeRouteColors.divider, height: 16),
          _buildDetailRow('Vehicle ID', vehicleId),
          const Divider(color: OfficeRouteColors.divider, height: 16),
          _buildDetailRow('Cab Speed', controller.cabSpeedDisplay),
          const Divider(color: OfficeRouteColors.divider, height: 16),
          _buildDetailRow('Destination Office', officeName),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: OfficeRouteTypography.secondary),
        Flexible(
          child: Text(
            value,
            style: OfficeRouteTypography.cardTitle.copyWith(fontSize: 14),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _actionChip(String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: OfficeRouteColors.primaryText),
      label: Text(
        label,
        style: OfficeRouteTypography.secondary.copyWith(
          color: OfficeRouteColors.primaryText,
          fontSize: 11,
        ),
      ),
      backgroundColor: OfficeRouteColors.raisedSurface,
      side: const BorderSide(color: OfficeRouteColors.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OfficeRouteRadii.small),
      ),
      onPressed: onTap,
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────

  Future<void> _handleStartDuty(
    BuildContext context,
    EmployeeTransportController controller,
  ) async {
    final res = await controller.startDuty();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor: res.isAccepted
            ? OfficeRouteColors.readyGreen
            : OfficeRouteColors.errorRed,
      ),
    );
  }

  Future<void> _handleMarkReady(
    BuildContext context,
    EmployeeTransportController controller,
  ) async {
    final res = await controller.markReadyAtPickup();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor: res.isAccepted
            ? OfficeRouteColors.readyGreen
            : OfficeRouteColors.errorRed,
      ),
    );
  }
}
