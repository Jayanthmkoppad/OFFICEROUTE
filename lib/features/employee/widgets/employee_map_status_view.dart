import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/design/office_route_colors.dart';
import '../../../core/design/office_route_spacing.dart';
import '../../../core/design/office_route_typography.dart';
import '../../../core/models/live_location_model.dart';
import '../../../core/services/location_tracking_policy.dart';
import '../controllers/employee_transport_controller.dart';

class EmployeeMapStatus {
  const EmployeeMapStatus({
    required this.code,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    this.retryLabel,
  });

  final String code;
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final String? retryLabel;

  factory EmployeeMapStatus.fromController(
    EmployeeTransportController controller,
  ) {
    if (controller.isLoading) {
      return const EmployeeMapStatus(
        code: 'loading',
        title: 'Loading today\'s map',
        message: 'Connecting to your transport operation.',
        icon: Icons.sync,
        color: OfficeRouteColors.liveBlue,
      );
    }

    final diagnostic = controller.homeViewState.diagnosticCode;
    if (diagnostic == 'location_services_disabled') {
      return const EmployeeMapStatus(
        code: 'gps_disabled',
        title: 'GPS is disabled',
        message: 'Enable device Location Services, then retry your location.',
        icon: Icons.location_disabled_outlined,
        color: OfficeRouteColors.errorRed,
        retryLabel: 'Retry location',
      );
    }
    if (diagnostic == 'permission_denied') {
      return const EmployeeMapStatus(
        code: 'permission_denied',
        title: 'Location permission denied',
        message: 'Location permission is required to show your live position.',
        icon: Icons.gps_off_outlined,
        color: OfficeRouteColors.errorRed,
        retryLabel: 'Retry permission',
      );
    }
    if (diagnostic == 'offline') {
      return const EmployeeMapStatus(
        code: 'offline',
        title: 'Transport updates are offline',
        message: 'Last permitted data remains visible while updates reconnect.',
        icon: Icons.cloud_off_outlined,
        color: OfficeRouteColors.waitingAmber,
        retryLabel: 'Retry updates',
      );
    }
    if (diagnostic == 'query_failed') {
      return const EmployeeMapStatus(
        code: 'query_failed',
        title: 'Map data could not update',
        message: 'The transport query failed. Existing safe data is preserved.',
        icon: Icons.sync_problem_outlined,
        color: OfficeRouteColors.errorRed,
        retryLabel: 'Retry updates',
      );
    }
    if (diagnostic == 'pickup_missing') {
      return const EmployeeMapStatus(
        code: 'pickup_missing',
        title: 'Pickup location missing',
        message: 'Contact an Administrator to configure today\'s pickup.',
        icon: Icons.wrong_location_outlined,
        color: OfficeRouteColors.waitingAmber,
        retryLabel: 'Refresh status',
      );
    }
    if (diagnostic == 'office_missing') {
      return const EmployeeMapStatus(
        code: 'destination_missing',
        title: 'Destination missing',
        message: 'Today\'s assignment does not include an office destination.',
        icon: Icons.business_outlined,
        color: OfficeRouteColors.waitingAmber,
        retryLabel: 'Refresh status',
      );
    }
    if (diagnostic == 'driver_pending') {
      return const EmployeeMapStatus(
        code: 'driver_not_assigned',
        title: 'Driver not assigned',
        message: 'Your route exists, but a Driver has not been assigned yet.',
        icon: Icons.person_search_outlined,
        color: OfficeRouteColors.waitingAmber,
        retryLabel: 'Refresh status',
      );
    }
    if (diagnostic == 'vehicle_pending') {
      return const EmployeeMapStatus(
        code: 'vehicle_not_assigned',
        title: 'Vehicle not assigned',
        message: 'Driver assignment exists, but vehicle details are pending.',
        icon: Icons.local_taxi_outlined,
        color: OfficeRouteColors.waitingAmber,
        retryLabel: 'Refresh status',
      );
    }

    final member = controller.myAssignmentMember;
    if (member == null || member.assignmentId.isEmpty) {
      return const EmployeeMapStatus(
        code: 'no_route',
        title: 'No route configured today',
        message: 'No Employee transport route is assigned for today.',
        icon: Icons.route_outlined,
        color: OfficeRouteColors.secondaryText,
        retryLabel: 'Refresh status',
      );
    }
    if (_isStale(controller.employeeLiveLocation, controller.currentTime)) {
      return const EmployeeMapStatus(
        code: 'stale_employee',
        title: 'Your location is stale',
        message: 'Your live location has not updated for over two minutes.',
        icon: Icons.history_toggle_off_outlined,
        color: OfficeRouteColors.waitingAmber,
        retryLabel: 'Refresh location',
      );
    }
    if (_isStale(controller.driverLiveLocation, controller.currentTime)) {
      return const EmployeeMapStatus(
        code: 'stale_driver',
        title: 'Cab location is stale',
        message: 'The assigned cab has not reported a recent location.',
        icon: Icons.history_toggle_off_outlined,
        color: OfficeRouteColors.waitingAmber,
        retryLabel: 'Retry updates',
      );
    }
    if (controller.activeTrip == null) {
      return const EmployeeMapStatus(
        code: 'no_active_trip',
        title: 'Trip not started',
        message: 'Configured route members remain visible before trip start.',
        icon: Icons.schedule_outlined,
        color: OfficeRouteColors.waitingAmber,
        retryLabel: 'Refresh status',
      );
    }
    if (controller.activeAssignment?.driverId.isNotEmpty == true &&
        controller.driverLiveLocation == null) {
      return const EmployeeMapStatus(
        code: 'cab_location_unavailable',
        title: 'Cab location unavailable',
        message: 'The assigned cab has not supplied a permitted live location.',
        icon: Icons.location_searching_outlined,
        color: OfficeRouteColors.waitingAmber,
        retryLabel: 'Retry updates',
      );
    }
    return const EmployeeMapStatus(
      code: 'ready',
      title: 'Live transport connected',
      message: 'Permitted transport locations are updating automatically.',
      icon: Icons.check_circle_outline,
      color: OfficeRouteColors.readyGreen,
    );
  }

  static bool _isStale(LiveLocationModel? location, DateTime now) {
    return location != null &&
        LocationTrackingPolicy.isStale(location.updatedAt, now);
  }
}

class EmployeeMapBrandTitle extends StatelessWidget {
  const EmployeeMapBrandTitle({super.key, required this.controller});

  final EmployeeTransportController controller;

  @override
  Widget build(BuildContext context) {
    final name = controller.currentUser?.name.trim() ?? '';
    final initial = name.isEmpty ? 'E' : name.characters.first.toUpperCase();
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: OfficeRouteColors.raisedSurface,
            shape: BoxShape.circle,
          ),
          child: Text(
            initial,
            style: OfficeRouteTypography.cardTitle.copyWith(letterSpacing: 0),
          ),
        ),
        const SizedBox(width: OfficeRouteSpacing.sm),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OfficeRoute',
                style: OfficeRouteTypography.sectionTitle.copyWith(
                  letterSpacing: 0,
                ),
              ),
              Text(
                controller.connectionStatus.replaceAll('_', ' '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OfficeRouteTypography.secondary.copyWith(
                  fontSize: 10,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class EmployeeMapSheetNotice extends StatelessWidget {
  const EmployeeMapSheetNotice({super.key, required this.state, this.onRetry});

  final EmployeeMapStatus state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          key: Key('employee_map_sheet_state_${state.code}'),
          padding: const EdgeInsets.all(OfficeRouteSpacing.sm),
          decoration: BoxDecoration(
            color: state.color.withValues(alpha: 0.08),
            border: Border.all(color: state.color.withValues(alpha: 0.40)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(state.icon, color: state.color, size: 18),
              const SizedBox(width: OfficeRouteSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.title,
                      style: OfficeRouteTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                    Text(
                      state.message,
                      style: OfficeRouteTypography.secondary.copyWith(
                        fontSize: 10,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              if (state.retryLabel != null && onRetry != null)
                IconButton(
                  key: Key('employee_map_sheet_retry_${state.code}'),
                  tooltip: state.retryLabel,
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  color: state.color,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
