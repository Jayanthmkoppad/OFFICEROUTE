import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/controllers/cab_management_controller.dart';
import '../../core/models/cab_trip_rider_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/cab_trip_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/premium_widgets.dart';

enum CabAnalyticsRange { day, week, month }

class CabAnalyticsSnapshot {
  final int totalTrips;
  final int completedTrips;
  final double averageWaitingMinutes;
  final String longestWaitingEmployee;
  final double averagePickupDelayMinutes;
  final double averageTripMinutes;
  final double totalDistanceKm;
  final double totalDrivingHours;
  final double idleHours;
  final int passengersPicked;
  final int missedPickups;
  final int driverPerformanceScore;
  final int employeeWaitingScore;
  final String branchPickupPerformance;
  final List<String> insights;

  const CabAnalyticsSnapshot({
    required this.totalTrips,
    required this.completedTrips,
    required this.averageWaitingMinutes,
    required this.longestWaitingEmployee,
    required this.averagePickupDelayMinutes,
    required this.averageTripMinutes,
    required this.totalDistanceKm,
    required this.totalDrivingHours,
    required this.idleHours,
    required this.passengersPicked,
    required this.missedPickups,
    required this.driverPerformanceScore,
    required this.employeeWaitingScore,
    required this.branchPickupPerformance,
    required this.insights,
  });
}

class CabAnalyticsController {
  CabAnalyticsController._();

  static Future<CabAnalyticsSnapshot> load(CabAnalyticsRange range) async {
    final allTrips = await CabManagementController.loadAllTrips();
    final now = DateTime.now();
    final start = switch (range) {
      CabAnalyticsRange.day => DateTime(now.year, now.month, now.day),
      CabAnalyticsRange.week => DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1)),
      CabAnalyticsRange.month => DateTime(now.year, now.month),
    };
    final trips = allTrips.where((trip) {
      final timestamp = trip.startedAt ?? trip.createdAt;
      return timestamp != null && !timestamp.isBefore(start);
    }).toList();
    final riderLists = await Future.wait(
      trips.map((trip) => CabManagementController.loadTripRiders(trip.id)),
    );
    final riders = riderLists.expand((items) => items).toList();
    final employeeIds = riders
        .map((rider) => rider.employeeId)
        .toSet()
        .toList();
    final users = await FirestoreService.fetchUsersByIds(employeeIds);
    final usersById = {for (final user in users) user.uid: user};

    final completed = trips
        .where((trip) => trip.status == 'completed')
        .toList();
    final waiting = riders
        .where((rider) => rider.waitingDurationSeconds > 0)
        .toList();
    final delays = riders
        .where((rider) => rider.pickupDelaySeconds > 0)
        .toList();
    final picked = riders
        .where(
          (rider) =>
              const {'picked_up', 'boarded', 'dropped'}.contains(rider.status),
        )
        .length;
    final missed = riders.where((rider) => rider.status == 'no_show').length;
    final averageWaitSeconds = _average(
      waiting.map((rider) => rider.waitingDurationSeconds),
    );
    final averageDelaySeconds = _average(
      delays.map((rider) => rider.pickupDelaySeconds),
    );
    final averageTripSeconds = _average(
      completed.map((trip) => trip.durationSeconds),
    );
    final longest = waiting.isEmpty
        ? null
        : waiting.reduce(
            (a, b) =>
                a.waitingDurationSeconds >= b.waitingDurationSeconds ? a : b,
          );
    final completionRate = trips.isEmpty
        ? 0.0
        : completed.length / trips.length;
    final punctuality = (1 - (averageDelaySeconds / 900)).clamp(0.0, 1.0);
    final waitQuality = (1 - (averageWaitSeconds / 900)).clamp(0.0, 1.0);
    final performance =
        ((completionRate * 55) + (punctuality * 25) + (waitQuality * 20))
            .round();
    final waitingScore = (waitQuality * 100).round();
    final branchScore = _branchPerformance(riders, usersById);
    final insights = _insights(
      averageWaitSeconds: averageWaitSeconds,
      averageDelaySeconds: averageDelaySeconds,
      longest: longest,
      usersById: usersById,
      completionRate: completionRate,
    );

    return CabAnalyticsSnapshot(
      totalTrips: trips.length,
      completedTrips: completed.length,
      averageWaitingMinutes: averageWaitSeconds / 60,
      longestWaitingEmployee: longest == null
          ? '--'
          : (usersById[longest.employeeId]?.name ?? longest.employeeId),
      averagePickupDelayMinutes: averageDelaySeconds / 60,
      averageTripMinutes: averageTripSeconds / 60,
      totalDistanceKm: trips.fold(0, (sum, trip) => sum + trip.distanceKm),
      totalDrivingHours:
          trips.fold<int>(0, (sum, trip) => sum + trip.drivingSeconds) / 3600,
      idleHours:
          trips.fold<int>(0, (sum, trip) => sum + trip.idleSeconds) / 3600,
      passengersPicked: picked,
      missedPickups: missed,
      driverPerformanceScore: performance,
      employeeWaitingScore: waitingScore,
      branchPickupPerformance: branchScore,
      insights: insights,
    );
  }

  static double _average(Iterable<int> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static String _branchPerformance(
    List<CabTripRiderModel> riders,
    Map<String, UserModel> users,
  ) {
    final waits = <String, List<int>>{};
    for (final rider in riders.where(
      (item) => item.waitingDurationSeconds > 0,
    )) {
      final branch = users[rider.employeeId]?.branch.trim();
      if (branch == null || branch.isEmpty) continue;
      waits.putIfAbsent(branch, () => []).add(rider.waitingDurationSeconds);
    }
    if (waits.isEmpty) return '--';
    final ranked = waits.entries.toList()
      ..sort((a, b) => _average(a.value).compareTo(_average(b.value)));
    final best = ranked.first;
    return '${best.key} • ${(_average(best.value) / 60).toStringAsFixed(1)}m avg';
  }

  static List<String> _insights({
    required double averageWaitSeconds,
    required double averageDelaySeconds,
    required CabTripRiderModel? longest,
    required Map<String, UserModel> usersById,
    required double completionRate,
  }) {
    final result = <String>[];
    if (averageWaitSeconds > 300) {
      result.add(
        'Average employee waiting is ${(averageWaitSeconds / 60).toStringAsFixed(1)} minutes.',
      );
    }
    if (averageDelaySeconds > 300) {
      result.add(
        'Average pickup delay is ${(averageDelaySeconds / 60).toStringAsFixed(1)} minutes.',
      );
    }
    if (longest != null && longest.waitingDurationSeconds > 300) {
      final name = usersById[longest.employeeId]?.name ?? longest.employeeId;
      result.add(
        '$name recorded the longest wait at ${(longest.waitingDurationSeconds / 60).toStringAsFixed(1)} minutes.',
      );
    }
    if (completionRate == 1) {
      result.add('All scheduled cab trips in this period were completed.');
    }
    if (result.isEmpty) {
      result.add('No operational exceptions detected for this period.');
    }
    return result;
  }
}

class CabAnalyticsDashboard extends StatefulWidget {
  const CabAnalyticsDashboard({super.key});

  @override
  State<CabAnalyticsDashboard> createState() => _CabAnalyticsDashboardState();
}

class _CabAnalyticsDashboardState extends State<CabAnalyticsDashboard> {
  CabAnalyticsRange _range = CabAnalyticsRange.day;
  late Future<CabAnalyticsSnapshot> _future;
  StreamSubscription<void>? _subscription;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _future = CabAnalyticsController.load(_range);
    _subscription = CabTripService.watchAllTrips().listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), _reload);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _future = CabAnalyticsController.load(_range));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<CabAnalyticsRange>(
          segments: const [
            ButtonSegment(value: CabAnalyticsRange.day, label: Text('Daily')),
            ButtonSegment(value: CabAnalyticsRange.week, label: Text('Weekly')),
            ButtonSegment(
              value: CabAnalyticsRange.month,
              label: Text('Monthly'),
            ),
          ],
          selected: {_range},
          onSelectionChanged: (value) {
            _range = value.first;
            _reload();
          },
        ),
        const SizedBox(height: 10),
        FutureBuilder<CabAnalyticsSnapshot>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const PremiumLoadingState(label: 'Loading cab analytics');
            }
            if (snapshot.hasError) {
              return PremiumErrorState(
                title: 'Cab analytics failed to load.',
                error: snapshot.error,
                onRetry: _reload,
              );
            }
            final data = snapshot.data;
            if (data == null) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _AnalyticsMetric('Total Trips', '${data.totalTrips}'),
                    _AnalyticsMetric('Completed', '${data.completedTrips}'),
                    _AnalyticsMetric(
                      'Avg Wait',
                      '${data.averageWaitingMinutes.toStringAsFixed(1)}m',
                    ),
                    _AnalyticsMetric(
                      'Longest Wait',
                      data.longestWaitingEmployee,
                    ),
                    _AnalyticsMetric(
                      'Pickup Delay',
                      '${data.averagePickupDelayMinutes.toStringAsFixed(1)}m',
                    ),
                    _AnalyticsMetric(
                      'Trip Duration',
                      '${data.averageTripMinutes.toStringAsFixed(1)}m',
                    ),
                    _AnalyticsMetric(
                      'Distance',
                      '${data.totalDistanceKm.toStringAsFixed(1)} km',
                    ),
                    _AnalyticsMetric(
                      'Driving',
                      '${data.totalDrivingHours.toStringAsFixed(1)}h',
                    ),
                    _AnalyticsMetric(
                      'Idle',
                      '${data.idleHours.toStringAsFixed(1)}h',
                    ),
                    _AnalyticsMetric('Passengers', '${data.passengersPicked}'),
                    _AnalyticsMetric('Missed', '${data.missedPickups}'),
                    _AnalyticsMetric(
                      'Driver Score',
                      '${data.driverPerformanceScore}%',
                    ),
                    _AnalyticsMetric(
                      'Waiting Score',
                      '${data.employeeWaitingScore}%',
                    ),
                    _AnalyticsMetric(
                      'Branch Performance',
                      data.branchPickupPerformance,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Smart insights',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                ...data.insights.map(
                  (insight) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.insights_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(insight, style: AppTextStyles.bodyMedium),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AnalyticsMetric extends StatelessWidget {
  final String label;
  final String value;
  const _AnalyticsMetric(this.label, this.value);

  @override
  Widget build(BuildContext context) => Container(
    width: 150,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption),
      ],
    ),
  );
}
