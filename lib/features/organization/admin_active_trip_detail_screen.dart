import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/controllers/cab_management_controller.dart';
import '../../core/models/cab_assignment_model.dart';
import '../../core/models/cab_trip_event_model.dart';
import '../../core/models/cab_trip_model.dart';
import '../../core/models/cab_trip_rider_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/cab_trip_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Administrator-facing active trip detail screen. Displays the driver,
/// vehicle, destination, list of riders and a real event timeline sourced
/// from `cab_trips/{tripId}/events`. Nothing is fabricated - missing values
/// show as `—`.
class AdminActiveTripDetailScreen extends StatefulWidget {
  final CabTripModel trip;
  const AdminActiveTripDetailScreen({super.key, required this.trip});

  @override
  State<AdminActiveTripDetailScreen> createState() =>
      _AdminActiveTripDetailScreenState();
}

class _AdminActiveTripDetailScreenState
    extends State<AdminActiveTripDetailScreen> {
  StreamSubscription<void>? _riderSub;
  StreamSubscription<void>? _eventSub;
  Timer? _debounce;

  CabAssignmentModel? _assignment;
  List<CabTripRiderModel> _riders = const [];
  List<CabTripEventModel> _events = const [];
  Map<String, UserModel> _users = const {};
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
    _riderSub = CabTripService.watchRiders(widget.trip.id).listen((_) {
      _scheduleReload();
    });
    _eventSub = CabTripService.watchEvents(widget.trip.id).listen((_) {
      _scheduleReload();
    });
  }

  @override
  void dispose() {
    _riderSub?.cancel();
    _eventSub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _reload);
  }

  Future<void> _reload() async {
    try {
      final assignment = await CabManagementController.loadAssignment(
        widget.trip.assignmentId,
      );
      final riders = await CabManagementController.loadTripRiders(
        widget.trip.id,
      );
      final events = await CabManagementController.loadTripEvents(
        widget.trip.id,
      );
      final userIds = {
        widget.trip.driverId,
        ...riders.map((rider) => rider.employeeId),
      }.where((id) => id.trim().isNotEmpty).toList();
      final users = await FirestoreService.fetchUsersByIds(userIds);
      riders.sort((a, b) => a.pickupOrder.compareTo(b.pickupOrder));
      events.sort(
        (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
          a.createdAt ?? DateTime(1970),
        ),
      );
      if (!mounted) return;
      setState(() {
        _assignment = assignment;
        _riders = riders;
        _events = events;
        _users = {for (final user in users) user.uid: user};
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Trip'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Failed to load trip: $_error'))
          : _content(),
    );
  }

  Widget _content() {
    final driver = _users[widget.trip.driverId];
    final assignment = _assignment;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _summaryCard(driver, assignment),
        const SizedBox(height: 12),
        Text(
          'Riders',
          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (_riders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No riders configured for this trip yet.',
              style: AppTextStyles.caption,
            ),
          )
        else
          ..._riders.map((rider) => _riderTile(rider)),
        const SizedBox(height: 16),
        Text(
          'Timeline',
          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (_events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No events recorded yet.',
              style: AppTextStyles.caption,
            ),
          )
        else
          ..._events.map(_timelineTile),
      ],
    );
  }

  Widget _summaryCard(UserModel? driver, CabAssignmentModel? assignment) {
    final trip = widget.trip;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                foregroundImage: (driver?.profileImage.isNotEmpty ?? false)
                    ? NetworkImage(driver!.profileImage)
                    : null,
                child: Text(
                  driver == null || driver.name.isEmpty
                      ? 'D'
                      : driver.name.substring(0, 1).toUpperCase(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver?.name ?? '—',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${_titleCase(trip.status.replaceAll('_', ' '))} · Trip ${trip.id.substring(0, trip.id.length < 6 ? trip.id.length : 6)}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _kv(
            'Destination',
            assignment?.officeName.isEmpty ?? true
                ? '—'
                : assignment!.officeName,
          ),
          _kv('Address', assignment?.officeAddress ?? '—'),
          _kv('Vehicle', trip.vehicleId.isEmpty ? '—' : trip.vehicleId),
          _kv(
            'Started',
            trip.startedAt == null ? '—' : trip.startedAt!.toLocal().toString(),
          ),
          _kv('Distance', '${trip.distanceKm.toStringAsFixed(1)} km'),
        ],
      ),
    );
  }

  Widget _riderTile(CabTripRiderModel rider) {
    final user = _users[rider.employeeId];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text('${rider.pickupOrder}')),
      title: Text(user?.name ?? rider.employeeId),
      subtitle: Text(
        '${_titleCase(rider.status.replaceAll('_', ' '))} · Waited ${_formatSeconds(rider.waitingDurationSeconds)}',
      ),
      trailing: rider.pickupLatitude == null
          ? const Icon(
              Icons.location_disabled_outlined,
              color: AppColors.textDisabled,
            )
          : const Icon(Icons.location_on_outlined),
    );
  }

  Widget _timelineTile(CabTripEventModel event) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 12),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.info,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.message.isEmpty ? event.eventType : event.message,
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  event.createdAt == null
                      ? '—'
                      : event.createdAt!.toLocal().toString(),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.caption)),
          Flexible(
            child: Text(
              value.trim().isEmpty ? '—' : value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _titleCase(String value) => value
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  String _formatSeconds(int total) {
    if (total <= 0) return '0m';
    final minutes = total ~/ 60;
    return minutes >= 60
        ? '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m'
        : '${minutes}m';
  }
}
