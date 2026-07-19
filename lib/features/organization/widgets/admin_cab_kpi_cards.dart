import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/cab_assignment_model.dart';
import '../../../core/models/cab_trip_model.dart';
import '../../../core/models/live_location_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/cab_assignment_service.dart';
import '../../../core/services/cab_trip_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/live_location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../admin_live_people_map_screen.dart';
import '../admin_fleet_analytics_screen.dart';
import '../admin_active_trip_detail_screen.dart';

/// Realtime cab operations KPI strip that lives inside the existing
/// Administrator dashboard. Values are computed from live Firestore streams
/// - trips, assignments, users and live locations. Nothing is fabricated;
/// unavailable metrics show as `--`.
class AdminCabKpiCards extends StatefulWidget {
  const AdminCabKpiCards({super.key});

  @override
  State<AdminCabKpiCards> createState() => _AdminCabKpiCardsState();
}

class _AdminCabKpiCardsState extends State<AdminCabKpiCards> {
  late String _dateKey;
  StreamSubscription<void>? _tripSub;
  StreamSubscription<void>? _assignmentSub;
  StreamSubscription<List<LiveLocationModel>>? _liveSub;
  Timer? _debounce;

  List<CabTripModel> _trips = const [];
  List<CabAssignmentModel> _assignments = const [];
  List<LiveLocationModel> _liveLocations = const [];
  Map<String, UserModel> _drivers = const {};
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _dateKey = _todayKey();
    unawaited(_reload());
    _tripSub = CabTripService.watchTripsForDate(
      _dateKey,
    ).listen((_) => _scheduleReload(), onError: (_) {});
    _assignmentSub = CabAssignmentService.watchAssignmentsForDate(
      _dateKey,
    ).listen((_) => _scheduleReload(), onError: (_) {});
    _liveSub = LiveLocationService.watchLiveLocations().listen((locations) {
      if (!mounted) return;
      setState(() => _liveLocations = locations);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _tripSub?.cancel();
    _assignmentSub?.cancel();
    _liveSub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      unawaited(_reload());
    });
  }

  Future<void> _reload() async {
    try {
      final trips = await CabTripService.fetchTripsForDate(dateKey: _dateKey);
      final assignments = await CabAssignmentService.fetchAssignmentsForDate(
        dateKey: _dateKey,
      );
      final drivers = await FirestoreService.fetchUsersByRole('driver');
      if (!mounted) return;
      setState(() {
        _trips = trips;
        _assignments = assignments;
        _drivers = {for (final user in drivers) user.uid: user};
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

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _wrapper(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_error != null) {
      return _wrapper(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text('Cab KPIs could not load: $_error'),
        ),
      );
    }

    final activeTrips = _trips
        .where(
          (trip) => const {'active', 'office_arrived'}.contains(trip.status),
        )
        .toList();
    final completedTrips = _trips
        .where((trip) => trip.status == 'completed')
        .toList();
    final onDutyDrivers = _liveLocations
        .where(
          (location) =>
              _drivers.containsKey(location.userId) &&
              location.status == 'active',
        )
        .length;
    final totalDrivers = _drivers.length;
    final totalEmployeesToday = _assignments.fold<int>(
      0,
      (sum, assignment) => sum + assignment.employeeIds.length,
    );
    final vehiclesInUse = activeTrips
        .map((trip) => trip.vehicleId.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;
    final totalKm = completedTrips.fold<double>(
      0,
      (sum, trip) => sum + trip.distanceKm,
    );

    return _wrapper(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _KpiWrap(
            items: [
              (
                'Active Trips',
                '${activeTrips.length}',
                Icons.route_outlined,
                AppColors.info,
              ),
              (
                'Completed Today',
                '${completedTrips.length}',
                Icons.task_alt_outlined,
                AppColors.success,
              ),
              (
                'Drivers On Duty',
                totalDrivers == 0 ? '--' : '$onDutyDrivers/$totalDrivers',
                Icons.directions_car_outlined,
                AppColors.warning,
              ),
              (
                'Employees Assigned',
                '$totalEmployeesToday',
                Icons.groups_2_outlined,
                AppColors.primary,
              ),
              (
                'Vehicles In Use',
                '$vehiclesInUse',
                Icons.local_taxi_outlined,
                AppColors.info,
              ),
              (
                'Distance Today',
                '${totalKm.toStringAsFixed(1)} km',
                Icons.speed_outlined,
                AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (activeTrips.isNotEmpty)
            _ActiveTripsList(
              trips: activeTrips,
              assignments: _assignments,
              drivers: _drivers,
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.map_outlined),
                label: const Text('Live People Map'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminLivePeopleMapScreen(),
                  ),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Fleet Analytics'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminFleetAnalyticsScreen(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _wrapper(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: child,
    );
  }
}

class _KpiWrap extends StatelessWidget {
  final List<(String, String, IconData, Color)> items;
  const _KpiWrap({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 6
            : constraints.maxWidth >= 600
            ? 3
            : 2;
        final gap = 8.0;
        final width = (constraints.maxWidth - ((columns - 1) * gap)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _KpiTile(
                    label: item.$1,
                    value: item.$2,
                    icon: item.$3,
                    color: item.$4,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withAlpha(14),
        border: Border.all(color: color.withAlpha(56)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveTripsList extends StatelessWidget {
  final List<CabTripModel> trips;
  final List<CabAssignmentModel> assignments;
  final Map<String, UserModel> drivers;
  const _ActiveTripsList({
    required this.trips,
    required this.assignments,
    required this.drivers,
  });

  @override
  Widget build(BuildContext context) {
    final byAssignment = <String, CabAssignmentModel>{
      for (final assignment in assignments) assignment.id: assignment,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Active Trips',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (final trip in trips)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.route_outlined, color: AppColors.info),
            title: Text(
              drivers[trip.driverId]?.name ??
                  'Driver ${trip.driverId.substring(0, trip.driverId.length < 6 ? trip.driverId.length : 6)}',
            ),
            subtitle: Text(
              '${_label(trip.status)} · ${byAssignment[trip.assignmentId]?.officeName ?? 'Destination pending'}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AdminActiveTripDetailScreen(trip: trip),
              ),
            ),
          ),
      ],
    );
  }

  String _label(String status) => status
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
