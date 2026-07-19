import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/controllers/cab_management_controller.dart';
import '../../core/models/cab_trip_model.dart';
import '../../core/services/cab_trip_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

enum _FleetRange { day, week, month }

/// Administrator Fleet Analytics screen with day/week/month bounded
/// Firestore queries. All numbers are computed from real trip documents;
/// unavailable values render as `—`.
class AdminFleetAnalyticsScreen extends StatefulWidget {
  const AdminFleetAnalyticsScreen({super.key});

  @override
  State<AdminFleetAnalyticsScreen> createState() =>
      _AdminFleetAnalyticsScreenState();
}

class _AdminFleetAnalyticsScreenState extends State<AdminFleetAnalyticsScreen> {
  _FleetRange _range = _FleetRange.day;
  StreamSubscription<void>? _sub;
  Timer? _debounce;

  bool _loading = true;
  Object? _error;
  _FleetSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
    _sub = CabTripService.watchAllTrips().listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), _reload);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final trips = await CabManagementController.loadAllTrips();
      final now = DateTime.now();
      final start = switch (_range) {
        _FleetRange.day => DateTime(now.year, now.month, now.day),
        _FleetRange.week => DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1)),
        _FleetRange.month => DateTime(now.year, now.month, 1),
      };
      final filtered = trips.where((trip) {
        final reference = trip.startedAt ?? trip.createdAt;
        return reference != null && !reference.isBefore(start);
      }).toList();
      if (!mounted) return;
      setState(() {
        _snapshot = _FleetSnapshot.fromTrips(filtered);
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
      appBar: AppBar(title: const Text('Fleet Analytics')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Fleet analytics failed: $_error'))
          : _content(),
    );
  }

  Widget _content() {
    final snapshot = _snapshot!;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          SegmentedButton<_FleetRange>(
            segments: const [
              ButtonSegment(value: _FleetRange.day, label: Text('Day')),
              ButtonSegment(value: _FleetRange.week, label: Text('Week')),
              ButtonSegment(value: _FleetRange.month, label: Text('Month')),
            ],
            selected: {_range},
            onSelectionChanged: (value) {
              setState(() {
                _range = value.first;
                _loading = true;
              });
              unawaited(_reload());
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metric('Total Trips', '${snapshot.totalTrips}'),
              _metric('Completed', '${snapshot.completedTrips}'),
              _metric('Active', '${snapshot.activeTrips}'),
              _metric('Cancelled/Skipped', '${snapshot.cancelledTrips}'),
              _metric(
                'Distance',
                snapshot.totalDistanceKm <= 0
                    ? '—'
                    : '${snapshot.totalDistanceKm.toStringAsFixed(1)} km',
              ),
              _metric(
                'Driving Hours',
                snapshot.drivingHours <= 0
                    ? '—'
                    : '${snapshot.drivingHours.toStringAsFixed(1)}h',
              ),
              _metric(
                'Idle Hours',
                snapshot.idleHours <= 0
                    ? '—'
                    : '${snapshot.idleHours.toStringAsFixed(1)}h',
              ),
              _metric(
                'Avg Trip Duration',
                snapshot.averageTripMinutes <= 0
                    ? '—'
                    : '${snapshot.averageTripMinutes.toStringAsFixed(1)}m',
              ),
              _metric(
                'Utilisation',
                snapshot.utilisationPercent == null
                    ? '—'
                    : '${snapshot.utilisationPercent!.toStringAsFixed(0)}%',
              ),
              _metric('Vehicles Used', '${snapshot.vehiclesUsed}'),
              _metric('Drivers Active', '${snapshot.driversActive}'),
            ],
          ),
          const SizedBox(height: 16),
          if (snapshot.topDrivers.isNotEmpty) ...[
            Text(
              'Top Drivers by Trips',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ...snapshot.topDrivers
                .take(5)
                .map(
                  (entry) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.person_outline,
                      color: AppColors.info,
                    ),
                    title: Text(entry.key),
                    trailing: Text('${entry.value}'),
                  ),
                ),
          ],
          const SizedBox(height: 16),
          if (snapshot.perStatus.isNotEmpty) ...[
            Text(
              'Status Breakdown',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ...snapshot.perStatus.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(_label(entry.key))),
                    Text('${entry.value}'),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(String label, String value) => Container(
    width: 150,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption),
      ],
    ),
  );

  String _label(String status) => status
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _FleetSnapshot {
  final int totalTrips;
  final int completedTrips;
  final int activeTrips;
  final int cancelledTrips;
  final double totalDistanceKm;
  final double drivingHours;
  final double idleHours;
  final double averageTripMinutes;
  final double? utilisationPercent;
  final int vehiclesUsed;
  final int driversActive;
  final List<MapEntry<String, int>> topDrivers;
  final Map<String, int> perStatus;

  const _FleetSnapshot({
    required this.totalTrips,
    required this.completedTrips,
    required this.activeTrips,
    required this.cancelledTrips,
    required this.totalDistanceKm,
    required this.drivingHours,
    required this.idleHours,
    required this.averageTripMinutes,
    required this.utilisationPercent,
    required this.vehiclesUsed,
    required this.driversActive,
    required this.topDrivers,
    required this.perStatus,
  });

  factory _FleetSnapshot.fromTrips(List<CabTripModel> trips) {
    final completed = trips
        .where((trip) => trip.status == 'completed')
        .toList();
    final active = trips
        .where(
          (trip) => const {
            'active',
            'office_arrived',
            'created',
          }.contains(trip.status),
        )
        .toList();
    final cancelled = trips
        .where(
          (trip) =>
              const {'cancelled', 'skipped', 'aborted'}.contains(trip.status),
        )
        .toList();
    final totalDistanceKm = trips.fold<double>(
      0,
      (sum, trip) => sum + trip.distanceKm,
    );
    final drivingSeconds = trips.fold<int>(
      0,
      (sum, trip) => sum + trip.drivingSeconds,
    );
    final idleSeconds = trips.fold<int>(
      0,
      (sum, trip) => sum + trip.idleSeconds,
    );
    final durationsSeconds = completed.map((trip) => trip.durationSeconds);
    final averageTripMinutes = durationsSeconds.isEmpty
        ? 0.0
        : durationsSeconds.reduce((a, b) => a + b) /
              durationsSeconds.length /
              60;
    final vehiclesUsed = trips
        .map((trip) => trip.vehicleId.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;
    final driverCounts = <String, int>{};
    for (final trip in trips) {
      final id = trip.driverId.trim();
      if (id.isEmpty) continue;
      driverCounts.update(id, (value) => value + 1, ifAbsent: () => 1);
    }
    final topDrivers = driverCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final perStatus = <String, int>{};
    for (final trip in trips) {
      perStatus.update(trip.status, (value) => value + 1, ifAbsent: () => 1);
    }
    final utilisation = trips.isEmpty
        ? null
        : (completed.length / trips.length) * 100.0;
    return _FleetSnapshot(
      totalTrips: trips.length,
      completedTrips: completed.length,
      activeTrips: active.length,
      cancelledTrips: cancelled.length,
      totalDistanceKm: totalDistanceKm,
      drivingHours: drivingSeconds / 3600,
      idleHours: idleSeconds / 3600,
      averageTripMinutes: averageTripMinutes,
      utilisationPercent: utilisation,
      vehiclesUsed: vehiclesUsed,
      driversActive: driverCounts.length,
      topDrivers: topDrivers,
      perStatus: perStatus,
    );
  }
}
