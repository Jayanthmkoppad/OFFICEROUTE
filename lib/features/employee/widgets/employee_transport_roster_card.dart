import 'package:flutter/material.dart';

import '../../../core/design/office_route_colors.dart';
import '../../../core/design/office_route_spacing.dart';
import '../../../core/design/office_route_typography.dart';
import '../../../core/design/widgets/office_route_card.dart';
import '../../../core/models/passenger_progress_model.dart';

class EmployeeTransportRosterCard extends StatelessWidget {
  const EmployeeTransportRosterCard({
    super.key,
    required this.progress,
    required this.currentUserId,
    this.canUpdateOwnStatus = false,
    this.diagnosticCode = 'ok',
    this.hasConfiguredRoute = false,
    this.homeStyle = false,
    this.onUpdateStatus,
    this.isUpdating = false,
    this.routeLabel,
  });

  final List<PassengerProgressModel> progress;
  final String currentUserId;
  final bool canUpdateOwnStatus;
  final String diagnosticCode;
  final bool hasConfiguredRoute;
  final bool homeStyle;
  final Future<void> Function(String status)? onUpdateStatus;
  final bool isUpdating;
  final String? routeLabel;

  @override
  Widget build(BuildContext context) {
    final ordered = [...progress]
      ..sort((a, b) => a.pickupSequence.compareTo(b.pickupSequence));
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (homeStyle)
          Row(
            children: [
              const Expanded(
                child: Text(
                  "TODAY'S EMPLOYEES",
                  style: OfficeRouteTypography.cardTitle,
                ),
              ),
              Text(
                '${ordered.length} Total',
                style: OfficeRouteTypography.secondary,
              ),
            ],
          )
        else
          const Text(
            "TODAY'S EMPLOYEES",
            style: OfficeRouteTypography.cardTitle,
          ),
        const SizedBox(height: 3),
        Text(
          routeLabel ?? 'Live pickup progress for the current route',
          style: OfficeRouteTypography.secondary,
        ),
        if (homeStyle) ...[
          const SizedBox(height: 3),
          Text(
            'Distance is straight-line. Traffic ETA appears only when supplied by the live trip.',
            style: OfficeRouteTypography.secondary.copyWith(fontSize: 10),
          ),
        ],
        const SizedBox(height: OfficeRouteSpacing.sm),
        if (ordered.isEmpty)
          Padding(
            key: Key('roster_empty_$diagnosticCode'),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                homeStyle
                    ? _emptyMessage
                    : 'No employees are assigned to an active route.',
                style: OfficeRouteTypography.secondary,
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          for (var index = 0; index < ordered.length; index++) ...[
            _PassengerRow(
              item: ordered[index],
              isCurrentUser: ordered[index].employeeId == currentUserId,
              canEdit:
                  canUpdateOwnStatus &&
                  ordered[index].employeeId == currentUserId &&
                  onUpdateStatus != null,
              isUpdating: isUpdating,
              onUpdateStatus: onUpdateStatus,
              homeStyle: homeStyle,
            ),
            if (index != ordered.length - 1)
              homeStyle
                  ? const SizedBox(height: OfficeRouteSpacing.sm)
                  : const Divider(color: OfficeRouteColors.divider),
          ],
      ],
    );
    return homeStyle ? content : OfficeRouteCard(child: content);
  }

  String get _emptyMessage => switch (diagnosticCode) {
    'loading' => 'Loading configured route members...',
    'permission_denied' =>
      'Permission denied while loading today\'s transport roster.',
    'offline' =>
      'Roster unavailable offline. Live updates will resume automatically.',
    'query_failed' => 'The transport roster query could not be completed.',
    'no_configured_members' =>
      'No passengers are configured for today\'s route.',
    _ when !hasConfiguredRoute => 'No active route for today.',
    _ => 'No employees are available for today\'s route.',
  };
}

class _PassengerRow extends StatelessWidget {
  const _PassengerRow({
    required this.item,
    required this.isCurrentUser,
    required this.canEdit,
    required this.isUpdating,
    required this.onUpdateStatus,
    required this.homeStyle,
  });

  final PassengerProgressModel item;
  final bool isCurrentUser;
  final bool canEdit;
  final bool isUpdating;
  final Future<void> Function(String status)? onUpdateStatus;
  final bool homeStyle;

  @override
  Widget build(BuildContext context) {
    final status = item.remark.isNotEmpty ? item.remark : item.status;
    return Container(
      key: Key('transport_employee_${item.employeeId}'),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? OfficeRouteColors.liveBlue.withValues(alpha: 0.08)
            : homeStyle
            ? OfficeRouteColors.raisedSurface
            : Colors.transparent,
        border: homeStyle
            ? Border.all(
                color: isCurrentUser
                    ? OfficeRouteColors.liveBlue.withValues(alpha: 0.35)
                    : OfficeRouteColors.divider,
              )
            : isCurrentUser
            ? Border.all(
                color: OfficeRouteColors.liveBlue.withValues(alpha: 0.35),
              )
            : null,
        borderRadius: BorderRadius.circular(homeStyle ? 8 : 6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.passengerDisplayName}${isCurrentUser ? ' (You)' : ''}',
                  style: OfficeRouteTypography.cardTitle,
                ),
              ),
              Flexible(
                child: Text(
                  _label(status),
                  textAlign: TextAlign.end,
                  style: OfficeRouteTypography.secondary.copyWith(
                    color: _statusColor(status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            [
              if (item.employeeCode.isNotEmpty) item.employeeCode,
              item.roleLabel,
            ].join(' | '),
            style: OfficeRouteTypography.secondary,
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(child: _Metric('LOCATION', _location(item))),
              Expanded(
                child: _Metric('DISTANCE', _distance(item, isCurrentUser)),
              ),
              Expanded(child: _Metric('ETA', _eta(item, isCurrentUser))),
            ],
          ),
          if (canEdit) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('update_transport_status_button'),
                onPressed: isUpdating
                    ? null
                    : () => _showStatusSheet(context, onUpdateStatus!),
                icon: isUpdating
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Update Status'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showStatusSheet(
    BuildContext context,
    Future<void> Function(String status) update,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: OfficeRouteColors.raisedSurface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in const [
              'waiting',
              'go_to_pickup',
              'on_the_way',
              'ready',
              'running_late',
              'not_coming',
            ])
              ListTile(
                title: Text(_label(option)),
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      ),
    );
    if (selected != null) await update(selected);
  }

  static String _location(PassengerProgressModel item) {
    if (const {'picked_up', 'boarded'}.contains(item.status)) return 'Onboard';
    if (const {'dropped', 'completed'}.contains(item.status)) {
      return 'Completed';
    }
    if (item.status == 'ready') return 'At pickup';
    return switch (item.locationFreshness) {
      'live' => 'Live',
      'stale' => 'Stale',
      'offline' => 'Offline',
      'permission_denied' => 'Permission denied',
      'not_started' => 'Not started',
      _ => 'Unavailable',
    };
  }

  static String _distance(PassengerProgressModel item, bool own) {
    final meters = item.distanceToPickupMeters;
    if (const {'picked_up', 'boarded'}.contains(item.status)) return 'Onboard';
    if (item.status == 'ready' && meters != null && meters <= 100) {
      return 'At pickup';
    }
    if (meters == null) return 'Unavailable';
    if (own && meters < 1000) return '${meters.round()} m';
    final rounded = own ? meters : (meters / 100).round() * 100;
    return '${(rounded / 1000).toStringAsFixed(1)} km';
  }

  static String _eta(PassengerProgressModel item, bool own) {
    final minutes = item.estimatedReadyMinutes;
    if (const {'picked_up', 'boarded'}.contains(item.status)) return 'Onboard';
    if (minutes == null) return 'Unavailable';
    final safeMinutes = own ? minutes : ((minutes / 5).round() * 5);
    return own ? '$safeMinutes min' : 'About $safeMinutes min';
  }

  static String _label(String value) => value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  static Color _statusColor(String value) {
    if (const {'ready', 'picked_up', 'dropped'}.contains(value)) {
      return OfficeRouteColors.readyGreen;
    }
    if (const {'running_late', 'not_coming'}.contains(value)) {
      return OfficeRouteColors.errorRed;
    }
    return OfficeRouteColors.waitingAmber;
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: OfficeRouteTypography.secondary.copyWith(fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: OfficeRouteTypography.tabularData,
        ),
      ],
    );
  }
}
