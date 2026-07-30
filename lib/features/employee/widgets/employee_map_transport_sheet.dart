import 'package:flutter/material.dart';

import '../../../core/design/office_route_colors.dart';
import '../../../core/design/office_route_radii.dart';
import '../../../core/design/office_route_spacing.dart';
import '../../../core/design/office_route_typography.dart';
import '../../../core/models/passenger_progress_model.dart';
import '../../../core/services/location_tracking_policy.dart';
import '../controllers/employee_transport_controller.dart';

class EmployeeMapKpiHeader extends StatelessWidget {
  const EmployeeMapKpiHeader({
    super.key,
    required this.controller,
    required this.cabDistanceMeters,
    required this.employeeDistanceMeters,
    required this.hasActiveTrip,
    required this.cabLocationIsFresh,
  });

  final EmployeeTransportController controller;
  final double? cabDistanceMeters;
  final double? employeeDistanceMeters;
  final bool hasActiveTrip;
  final bool cabLocationIsFresh;

  @override
  Widget build(BuildContext context) {
    final ownId = controller.currentUser?.uid ?? '';
    final ownProgress = controller.passengerProgressList
        .where((item) => item.employeeId == ownId)
        .firstOrNull;
    final eta = ownProgress?.estimatedReadyMinutes;
    final rawStatus =
        controller.myRiderRecord?.status ??
        controller.myAssignmentMember?.status ??
        'waiting';
    final hasCab = controller.driverLiveLocation != null;
    final live = hasActiveTrip && hasCab && cabLocationIsFresh;
    final indicator = !hasActiveTrip
        ? 'WAITING'
        : !hasCab
        ? 'OFFLINE'
        : cabLocationIsFresh
        ? 'LIVE'
        : 'STALE';
    final indicatorColor = live
        ? OfficeRouteColors.readyGreen
        : indicator == 'STALE'
        ? OfficeRouteColors.waitingAmber
        : OfficeRouteColors.secondaryText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CAB TO YOUR PICKUP',
                    key: const Key('map_sheet_title'),
                    style: OfficeRouteTypography.cardTitle.copyWith(
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Status: ${_titleCase(rawStatus)}',
                    style: OfficeRouteTypography.secondary.copyWith(
                      color: _statusColor(rawStatus),
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              key: const Key('map_live_indicator'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: indicatorColor.withValues(alpha: 0.12),
                border: Border.all(color: indicatorColor),
                borderRadius: BorderRadius.circular(OfficeRouteRadii.pill),
              ),
              child: Text(
                indicator,
                style: OfficeRouteTypography.secondary.copyWith(
                  color: indicatorColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: OfficeRouteSpacing.sm),
        Container(
          constraints: const BoxConstraints(minHeight: 70),
          decoration: BoxDecoration(
            color: OfficeRouteColors.raisedSurface,
            border: Border.all(color: OfficeRouteColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: _MapMetric(
                  label: 'CAB DISTANCE',
                  value: employeeMapFormatDistance(cabDistanceMeters),
                ),
              ),
              const _MetricDivider(),
              Expanded(
                child: _MapMetric(
                  label: 'YOUR DISTANCE',
                  value: employeeMapFormatDistance(employeeDistanceMeters),
                ),
              ),
              const _MetricDivider(),
              Expanded(
                child: _MapMetric(
                  label: 'ETA',
                  value: eta == null ? 'Unavailable' : '$eta min',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _titleCase(String value) => value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  static Color _statusColor(String value) {
    if (const {'ready', 'picked_up', 'boarded'}.contains(value)) {
      return OfficeRouteColors.readyGreen;
    }
    if (const {'running_late', 'not_coming'}.contains(value)) {
      return OfficeRouteColors.errorRed;
    }
    return OfficeRouteColors.waitingAmber;
  }
}

class EmployeeMapPickupPair extends StatelessWidget {
  const EmployeeMapPickupPair({
    super.key,
    required this.current,
    required this.next,
    required this.hasActiveTrip,
  });

  final PassengerProgressModel? current;
  final PassengerProgressModel? next;
  final bool hasActiveTrip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PICKUP PROGRESS',
          style: OfficeRouteTypography.secondary.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: OfficeRouteSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _PickupSummary(
                key: const Key('map_current_pickup'),
                label: 'CURRENT PICKUP',
                progress: current,
                emptyLabel: hasActiveTrip ? 'Unavailable' : 'Trip not started',
                configuredOnly: !hasActiveTrip,
                accent: OfficeRouteColors.liveBlue,
              ),
            ),
            const SizedBox(width: OfficeRouteSpacing.xs),
            Expanded(
              child: _PickupSummary(
                key: const Key('map_next_pickup'),
                label: 'NEXT PICKUP',
                progress: next,
                emptyLabel: hasActiveTrip
                    ? 'No next pickup'
                    : 'Trip not started',
                configuredOnly: !hasActiveTrip,
                accent: OfficeRouteColors.waitingAmber,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class EmployeeMapDriverVehicleCard extends StatelessWidget {
  const EmployeeMapDriverVehicleCard({super.key, required this.controller});

  final EmployeeTransportController controller;

  @override
  Widget build(BuildContext context) {
    final driver = controller.assignedDriver;
    final vehicle = controller.assignedVehicle;
    final driverName = driver?.name.trim().isNotEmpty == true
        ? driver!.name.trim()
        : controller.activeAssignment?.driverId.isNotEmpty == true
        ? 'Driver details unavailable'
        : 'Driver not assigned';
    final driverLocation = controller.driverLiveLocation;
    final locationState = driverLocation == null
        ? 'Offline'
        : LocationTrackingPolicy.isStale(
            driverLocation.updatedAt,
            controller.currentTime,
          )
        ? 'Stale'
        : 'Live';
    final vehicleParts = <String>[
      if (vehicle?.vehicleNumber.trim().isNotEmpty == true)
        vehicle!.vehicleNumber.trim(),
      if (vehicle?.vehicleModel.trim().isNotEmpty == true)
        vehicle!.vehicleModel.trim(),
      if (vehicle?.registrationNumber.trim().isNotEmpty == true)
        vehicle!.registrationNumber.trim(),
    ];
    final initial = driverName.startsWith('Driver ')
        ? 'D'
        : driverName.characters.first.toUpperCase();

    return Container(
      key: const Key('map_driver_vehicle'),
      padding: const EdgeInsets.all(OfficeRouteSpacing.sm),
      decoration: BoxDecoration(
        color: OfficeRouteColors.raisedSurface,
        border: Border.all(color: OfficeRouteColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: OfficeRouteColors.liveBlue.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: OfficeRouteTypography.cardTitle.copyWith(
                color: OfficeRouteColors.liveBlue,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: OfficeRouteSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driverName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OfficeRouteTypography.cardTitle.copyWith(
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  vehicleParts.isEmpty
                      ? 'Vehicle details unavailable'
                      : vehicleParts.join(' | '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: OfficeRouteTypography.secondary.copyWith(
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  'Driver location: $locationState',
                  style: OfficeRouteTypography.secondary.copyWith(
                    fontSize: 10,
                    letterSpacing: 0,
                  ),
                ),
                if (vehicle?.status.trim().isNotEmpty == true)
                  Text(
                    'Vehicle status: ${vehicle!.status.trim()}',
                    style: OfficeRouteTypography.secondary.copyWith(
                      fontSize: 10,
                      letterSpacing: 0,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(
            Icons.local_taxi_outlined,
            color: OfficeRouteColors.secondaryText,
          ),
        ],
      ),
    );
  }
}

class _MapMetric extends StatelessWidget {
  const _MapMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: OfficeRouteTypography.cardTitle.copyWith(
              fontSize: 13,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OfficeRouteTypography.secondary.copyWith(
              fontSize: 9,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 38,
      color: OfficeRouteColors.border.withValues(alpha: 0.65),
    );
  }
}

class _PickupSummary extends StatelessWidget {
  const _PickupSummary({
    super.key,
    required this.label,
    required this.progress,
    required this.emptyLabel,
    required this.configuredOnly,
    required this.accent,
  });

  final String label;
  final PassengerProgressModel? progress;
  final String emptyLabel;
  final bool configuredOnly;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final displayName = progress?.passengerDisplayName.trim() ?? '';
    final value = displayName.isEmpty ? emptyLabel : displayName;
    final status = progress?.status.trim().replaceAll('_', ' ') ?? '';
    final detail = progress == null
        ? configuredOnly
              ? 'Waiting for active trip'
              : ''
        : [
            if (progress!.pickupSequence > 0)
              'Pickup ${progress!.pickupSequence}',
            if (status.isNotEmpty) status,
          ].join(' | ');
    return Container(
      padding: const EdgeInsets.all(OfficeRouteSpacing.sm),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(OfficeRouteRadii.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: OfficeRouteTypography.secondary.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
              fontSize: 9,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: OfficeRouteTypography.body.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: OfficeRouteTypography.secondary.copyWith(
                fontSize: 9,
                letterSpacing: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String employeeMapFormatDistance(double? meters) {
  if (meters == null || !meters.isFinite || meters < 0) {
    return 'Unavailable';
  }
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

List<PassengerProgressModel> employeeMapPrivacySafeRoster(
  List<PassengerProgressModel> source,
  String currentUserId,
) {
  return source
      .map((item) {
        final isOwn = item.employeeId == currentUserId;
        final distance = item.distanceToPickupMeters;
        final eta = item.estimatedReadyMinutes;
        return PassengerProgressModel(
          employeeId: item.employeeId,
          passengerDisplayName: item.passengerDisplayName,
          employeeCode: item.employeeCode,
          roleLabel: item.roleLabel,
          pickupSequence: item.pickupSequence,
          status: item.status,
          remark: item.remark,
          attendanceActive: item.attendanceActive,
          transportActive: item.transportActive,
          distanceToPickupMeters: isOwn || distance == null
              ? distance
              : (distance / 100).round() * 100,
          estimatedReadyMinutes: isOwn || eta == null
              ? eta
              : (eta / 5).round() * 5,
          locationFreshness: item.locationFreshness,
          updatedAt: item.updatedAt,
        );
      })
      .toList(growable: false);
}
