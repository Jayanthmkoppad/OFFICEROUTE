import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/live_location_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/premium_widgets.dart';
import '../customer_visits/models/customer_visit_model.dart';
import '../manager/models/manager_employee_summary_model.dart';
import '../reports/reports_screen.dart';
import 'attendance_operations_dashboard.dart';
import 'controllers/attendance_controller.dart';
import 'models/attendance_model.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late Future<_AttendanceViewData> _attendanceFuture;
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedOperationsDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  Timer? _clockTimer;
  Timer? _realtimeDebounce;
  Timer? _liveLocationDebounce;
  final List<StreamSubscription<void>> _realtimeSubscriptions = [];
  StreamSubscription<List<LiveLocationModel>>? _liveLocationSubscription;
  Future<void>? _reloadInFlight;
  _AttendanceViewData? _latestData;
  Map<String, LiveLocationModel> _liveLocationsByUserId = const {};
  bool _liveLocationsLoaded = false;
  int _realtimeGeneration = 0;
  bool _isRunningAction = false;
  bool _isRefreshing = false;
  bool _isRealtimeConnected = false;

  @override
  void initState() {
    super.initState();
    final initialLoad = _loadAttendance();
    _attendanceFuture = initialLoad;
    late final Future<void> trackedLoad;
    trackedLoad = initialLoad.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    ).whenComplete(() {
      if (identical(_reloadInFlight, trackedLoad)) {
        _reloadInFlight = null;
      }
    });
    _reloadInFlight = trackedLoad;
    unawaited(_subscribeToRealtime());
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _realtimeDebounce?.cancel();
    _liveLocationDebounce?.cancel();
    for (final subscription in _realtimeSubscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_liveLocationSubscription?.cancel());
    super.dispose();
  }

  Future<_AttendanceViewData> _loadAttendance({
    bool personalMonthOnly = false,
  }) async {
    final cached = _latestData;
    if (personalMonthOnly && cached != null) {
      final updated = cached.copyWith(
        monthRecords:
            await AttendanceController.loadAttendanceForMonth(_visibleMonth),
      );
      _latestData = updated;
      return updated;
    }

    final operationsFuture = AttendanceController.loadOperationsForDate(
      _selectedOperationsDate,
    );
    final previousAttendanceFuture =
        AttendanceController.loadOperationsAttendanceForDate(
      _selectedOperationsDate.subtract(const Duration(days: 1)),
    );
    final operationsMonthFuture = AttendanceController.loadOperationsForMonth(
      _selectedOperationsDate,
    );

    final operations = await operationsFuture;
    final operationsMonth = await operationsMonthFuture;
    final previousAttendance = await previousAttendanceFuture;
    final currentUserId = AttendanceController.currentUserId;
    final selectedIsToday = DateUtils.isSameDay(
      _selectedOperationsDate,
      DateTime.now(),
    );
    final visibleIsOperationsMonth =
        _visibleMonth.year == _selectedOperationsDate.year &&
            _visibleMonth.month == _selectedOperationsDate.month;

    final today = selectedIsToday
        ? _latestRecordForUser(operations.attendance, currentUserId)
        : await AttendanceController.loadTodayAttendance();
    final monthRecords = visibleIsOperationsMonth && currentUserId != null
        ? operationsMonth
            .where((record) => record.userId == currentUserId)
            .toList(growable: false)
        : await AttendanceController.loadAttendanceForMonth(_visibleMonth);

    final data = _AttendanceViewData(
      operationsDate: _selectedOperationsDate,
      today: today,
      monthRecords: monthRecords,
      employeeSummaries: operations.employees,
      operationsAttendance: operations.attendance,
      previousAttendance: previousAttendance,
      operationsMonthAttendance: operationsMonth,
      operationsVisits: operations.visits,
      liveLocationsByUserId: _liveLocationsByUserId,
      liveLocationsLoaded: _liveLocationsLoaded,
    );
    _latestData = data;
    return data;
  }

  Future<void> _refresh({
    bool force = false,
    bool personalMonthOnly = false,
  }) {
    if (!mounted) return Future<void>.value();
    if (!force && _reloadInFlight != null) {
      return _reloadInFlight!;
    }

    final future = _loadAttendance(personalMonthOnly: personalMonthOnly);
    setState(() {
      _attendanceFuture = future;
      _isRefreshing = true;
    });

    Future<void> awaitReload() async {
      var failed = false;
      try {
        await future;
      } catch (_) {
        failed = true;
        rethrow;
      } finally {
        if (identical(_attendanceFuture, future)) {
          _reloadInFlight = null;
          if (mounted) {
            setState(() {
              _isRefreshing = false;
              if (failed) _isRealtimeConnected = false;
            });
          }
        }
      }
    }

    final completion = awaitReload();
    _reloadInFlight = completion;
    return completion;
  }

  Future<void> _runAction(
    Future<AttendanceModel?> Function() action,
  ) async {
    if (_isRunningAction) return;

    setState(() {
      _isRunningAction = true;
    });

    try {
      await action();
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to update attendance. Check GPS, permissions, and connection, then retry.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRunningAction = false;
        });
      }
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + offset);
    });
    unawaited(_refresh(force: true, personalMonthOnly: true));
  }

  Future<void> _subscribeToRealtime() async {
    final generation = ++_realtimeGeneration;
    _realtimeDebounce?.cancel();
    _liveLocationDebounce?.cancel();
    final cancellations = <Future<void>>[
      for (final subscription in _realtimeSubscriptions)
        subscription.cancel(),
      if (_liveLocationSubscription != null)
        _liveLocationSubscription!.cancel(),
    ];
    _realtimeSubscriptions.clear();
    _liveLocationSubscription = null;
    _isRealtimeConnected = false;
    _liveLocationsLoaded = false;
    await Future.wait(cancellations);
    if (!mounted || generation != _realtimeGeneration) return;

    final isToday = DateUtils.isSameDay(
      _selectedOperationsDate,
      DateTime.now(),
    );
    if (!isToday) {
      _liveLocationsByUserId = const {};
    }

    final streams = <Stream<void>>[
      AttendanceController.watchOperationsAttendance(
        _selectedOperationsDate,
      ),
      AttendanceController.watchOperationsVisits(_selectedOperationsDate),
    ];
    if (isToday) {
      streams.add(AttendanceController.watchActiveVisits());
      _liveLocationSubscription = AttendanceController
          .watchOperationsLiveLocations()
          .listen(
        (locations) {
          if (generation != _realtimeGeneration) return;
          _handleLiveLocations(locations);
        },
        onError: (_) {
          if (generation != _realtimeGeneration ||
              !mounted ||
              !_isRealtimeConnected) {
            return;
          }
          setState(() {
            _isRealtimeConnected = false;
          });
        },
      );
    }

    for (final stream in streams) {
      var isInitialSnapshot = true;
      _realtimeSubscriptions.add(
        stream.listen(
          (_) {
            if (generation != _realtimeGeneration || !mounted) return;
            if (!_isRealtimeConnected) {
              setState(() {
                _isRealtimeConnected = true;
              });
            }
            if (isInitialSnapshot) {
              isInitialSnapshot = false;
              return;
            }
            _scheduleRealtimeRefresh();
          },
          onError: (_) {
            if (generation != _realtimeGeneration ||
                !mounted ||
                !_isRealtimeConnected) {
              return;
            }
            setState(() {
              _isRealtimeConnected = false;
            });
          },
        ),
      );
    }
  }

  void _handleLiveLocations(List<LiveLocationModel> locations) {
    if (!DateUtils.isSameDay(_selectedOperationsDate, DateTime.now())) return;
    _liveLocationsLoaded = true;
    _liveLocationsByUserId = Map<String, LiveLocationModel>.unmodifiable({
      for (final location in locations)
        if (location.userId.isNotEmpty) location.userId: location,
    });
    _liveLocationDebounce?.cancel();
    _liveLocationDebounce = Timer(
      const Duration(milliseconds: 500),
      _publishLiveLocations,
    );
  }

  void _publishLiveLocations() {
    if (!mounted) return;
    final inFlight = _reloadInFlight;
    if (inFlight != null) {
      unawaited(
        inFlight.then<void>(
          (_) => _publishLiveLocations(),
          onError: (Object _, StackTrace _) => _publishLiveLocations(),
        ),
      );
      return;
    }

    final current = _latestData;
    if (current == null) return;
    final updated = current.copyWith(
      liveLocationsByUserId: _liveLocationsByUserId,
      liveLocationsLoaded: _liveLocationsLoaded,
    );
    _latestData = updated;
    setState(() {
      _attendanceFuture = Future<_AttendanceViewData>.value(updated);
    });
  }

  void _scheduleRealtimeRefresh() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final inFlight = _reloadInFlight;
      if (inFlight == null) {
        unawaited(_refresh().catchError((Object _) {}));
        return;
      }
      unawaited(
        inFlight.then<void>(
          (_) {
            if (!mounted) return;
            unawaited(_refresh().catchError((Object _) {}));
          },
          onError: (Object _, StackTrace _) {
            if (!mounted) return;
            unawaited(_refresh().catchError((Object _) {}));
          },
        ),
      );
    });
  }

  Future<void> _changeOperationsDate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    if (DateUtils.isSameDay(normalized, _selectedOperationsDate)) return;

    setState(() {
      _selectedOperationsDate = normalized;
      _latestData = null;
    });
    final subscriptionsReady = _subscribeToRealtime();
    final refresh = _refresh(force: true);
    await Future.wait([subscriptionsReady, refresh]);
  }

  void _openReports() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ReportsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Attendance Operations', style: AppTextStyles.headingSmall),
      ),
      body: FutureBuilder<_AttendanceViewData>(
        future: _attendanceFuture,
        builder: (context, snapshot) {
          final availableData = _latestData ?? snapshot.data;
          final hasSelectedDateData = availableData != null &&
              DateUtils.isSameDay(
                availableData.operationsDate,
                _selectedOperationsDate,
              );
          if (snapshot.connectionState == ConnectionState.waiting &&
              !hasSelectedDateData) {
            return const PremiumLoadingState(label: 'Loading attendance');
          }

          if (snapshot.hasError && !hasSelectedDateData) {
            return PremiumEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Attendance is temporarily unavailable',
              message:
                  'Check the connection and Firestore access, then try again.',
              actionLabel: 'Retry',
              onAction: () {
                unawaited(_refresh(force: true).catchError((Object _) {}));
              },
            );
          }

          final data = hasSelectedDateData
              ? availableData
              : _AttendanceViewData.empty;

          return RefreshIndicator(
            onRefresh: () => _refresh(force: true),
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 860;
                final summaryColumn = Column(
                  children: [
                    _TodayAttendanceCard(
                      attendance: data.today,
                      isRunningAction: _isRunningAction,
                      onCheckIn: () => _runAction(AttendanceController.checkIn),
                      onCheckOut: () => _runAction(AttendanceController.checkOut),
                      onStartBreak: () =>
                          _runAction(AttendanceController.startBreak),
                      onEndBreak: () => _runAction(AttendanceController.endBreak),
                    ),
                    const SizedBox(height: 16),
                    _LocationAndSyncCard(attendance: data.today),
                  ],
                );

                final historyColumn = Column(
                  children: [
                    _MonthlySummaryCard(
                      month: _visibleMonth,
                      records: data.monthRecords,
                      onPreviousMonth: () => _changeMonth(-1),
                      onNextMonth: () => _changeMonth(1),
                    ),
                    const SizedBox(height: 16),
                    _CalendarCard(month: _visibleMonth, records: data.monthRecords),
                    const SizedBox(height: 16),
                    _HistoryCard(records: data.monthRecords),
                  ],
                );

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1320),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AttendanceOperationsDashboard(
                            selectedDate: _selectedOperationsDate,
                            employees: data.employeeSummaries,
                            attendanceRecords: data.operationsAttendance,
                            previousAttendanceRecords: data.previousAttendance,
                            monthAttendanceRecords:
                                data.operationsMonthAttendance,
                            visits: data.operationsVisits,
                            liveLocationsByUserId:
                                data.liveLocationsByUserId,
                            liveLocationsLoaded: data.liveLocationsLoaded,
                            realtimeConnected: _isRealtimeConnected,
                            refreshing: _isRefreshing,
                            onDateChanged: _changeOperationsDate,
                            onRefresh: () => _refresh(force: true),
                            onLoadHistory: AttendanceController
                                .loadEmployeeAttendanceHistory,
                            onOpenReports: _openReports,
                          ),
                          const SizedBox(height: 18),
                          const PremiumSectionHeader(
                            icon: Icons.badge_outlined,
                            title: 'My Attendance',
                          ),
                          const SizedBox(height: 14),
                          if (isWide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 5, child: summaryColumn),
                                const SizedBox(width: 16),
                                Expanded(flex: 6, child: historyColumn),
                              ],
                            )
                          else
                            Column(
                              children: [
                                summaryColumn,
                                const SizedBox(height: 16),
                                historyColumn,
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _TodayAttendanceCard extends StatelessWidget {
  final AttendanceModel? attendance;
  final bool isRunningAction;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final VoidCallback onStartBreak;
  final VoidCallback onEndBreak;

  const _TodayAttendanceCard({
    required this.attendance,
    required this.isRunningAction,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onStartBreak,
    required this.onEndBreak,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final status = _attendanceStatus(attendance);
    final canCheckIn = attendance == null;
    final canCheckOut = attendance?.checkInTime != null &&
        attendance?.checkOutTime == null &&
        attendance?.breakStartTime == null;
    final canStartBreak = attendance?.isCheckedIn == true &&
        attendance?.breakStartTime == null;
    final canEndBreak = attendance?.breakStartTime != null;

    return PremiumCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Today's Attendance",
                  style: AppTextStyles.headingMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              PremiumStatusChip(label: status.label, color: status.color),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.timer_outlined,
                  label: 'Working Hours',
                  value: _formatDuration(
                    attendance?.netWorkingDuration(now) ?? Duration.zero,
                  ),
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  icon: Icons.free_breakfast_outlined,
                  label: 'Break Time',
                  value: _formatDuration(
                    attendance?.breakDuration(now) ?? Duration.zero,
                  ),
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TimelineCard(attendance: attendance),
          const SizedBox(height: 16),
          if (isRunningAction) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 16),
          ],
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _AttendanceActionButton(
                icon: Icons.login,
                label: 'Check In',
                enabled: canCheckIn && !isRunningAction,
                onTap: onCheckIn,
              ),
              _AttendanceActionButton(
                icon: Icons.logout,
                label: 'Check Out',
                enabled: canCheckOut && !isRunningAction,
                onTap: onCheckOut,
              ),
              _AttendanceActionButton(
                icon: Icons.pause_circle_outline,
                label: 'Start Break',
                enabled: canStartBreak && !isRunningAction,
                onTap: onStartBreak,
              ),
              _AttendanceActionButton(
                icon: Icons.play_circle_outline,
                label: 'End Break',
                enabled: canEndBreak && !isRunningAction,
                onTap: onEndBreak,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocationAndSyncCard extends StatelessWidget {
  final AttendanceModel? attendance;

  const _LocationAndSyncCard({required this.attendance});

  @override
  Widget build(BuildContext context) {
    final currentAttendance = attendance;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            icon: Icons.security_outlined,
            title: 'Location and Sync',
          ),
          const SizedBox(height: 16),
          _ValidationRow(
            icon: attendance?.hasCheckInLocation == true
                ? Icons.gps_fixed_outlined
                : Icons.gps_off_outlined,
            label: 'Check-in location',
            value: _gpsLabel(
              attendance?.checkInLatitude,
              attendance?.checkInLongitude,
            ),
            color: attendance?.hasCheckInLocation == true
                ? AppColors.success
                : AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          _ValidationRow(
            icon: attendance?.hasCheckOutLocation == true
                ? Icons.gps_fixed_outlined
                : Icons.gps_off_outlined,
            label: 'Check-out location',
            value: _gpsLabel(
              attendance?.checkOutLatitude,
              attendance?.checkOutLongitude,
            ),
            color: attendance?.hasCheckOutLocation == true
                ? AppColors.success
                : AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          _ValidationRow(
            icon: Icons.cloud_done_outlined,
            label: 'Offline handling',
            value: currentAttendance == null
                ? 'No attendance record yet'
                : 'Firestore offline cache active, ${currentAttendance.syncStatus}',
            color: AppColors.info,
          ),
        ],
      ),
    );
  }
}

class _MonthlySummaryCard extends StatelessWidget {
  final DateTime month;
  final List<AttendanceModel> records;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const _MonthlySummaryCard({
    required this.month,
    required this.records,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final completed = records.where((record) => record.checkInTime != null).length;
    final totalWork = records.fold<Duration>(
      Duration.zero,
      (sum, record) => sum + record.netWorkingDuration(now),
    );
    final totalBreak = records.fold<Duration>(
      Duration.zero,
      (sum, record) => sum + record.breakDuration(now),
    );
    final average = completed == 0
        ? Duration.zero
        : Duration(minutes: totalWork.inMinutes ~/ completed);

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPreviousMonth,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  _formatMonth(month),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headingSmall.copyWith(letterSpacing: 0),
                ),
              ),
              IconButton(
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 620;
              final cards = [
                _MetricTile(
                  icon: Icons.event_available_outlined,
                  label: 'Present Days',
                  value: completed.toString(),
                  color: AppColors.success,
                ),
                _MetricTile(
                  icon: Icons.timer_outlined,
                  label: 'Total Hours',
                  value: _formatDuration(totalWork),
                  color: AppColors.info,
                ),
                _MetricTile(
                  icon: Icons.free_breakfast_outlined,
                  label: 'Breaks',
                  value: _formatDuration(totalBreak),
                  color: AppColors.warning,
                ),
                _MetricTile(
                  icon: Icons.analytics_outlined,
                  label: 'Daily Avg',
                  value: _formatDuration(average),
                  color: AppColors.textPrimary,
                ),
              ];

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: wide ? 4 : 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: wide ? 1.35 : 1.25,
                children: cards,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  final DateTime month;
  final List<AttendanceModel> records;

  const _CalendarCard({required this.month, required this.records});

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final recordsByDay = {
      for (final record in records)
        if (record.date != null) record.date!.day: record,
    };

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            icon: Icons.calendar_month_outlined,
            title: 'Calendar',
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final day = index + 1;
              final record = recordsByDay[day];
              final hasRecord = record?.checkInTime != null;
              final completed = record?.checkOutTime != null;

              return DecoratedBox(
                decoration: BoxDecoration(
                  color: hasRecord
                      ? (completed
                          ? AppColors.success.withAlpha(34)
                          : AppColors.info.withAlpha(34))
                      : Colors.white.withAlpha(8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasRecord
                        ? (completed ? AppColors.success : AppColors.info)
                            .withAlpha(76)
                        : Colors.white.withAlpha(18),
                  ),
                ),
                child: Center(
                  child: Text(
                    day.toString(),
                    style: AppTextStyles.caption.copyWith(
                      color: hasRecord
                          ? AppColors.textPrimary
                          : AppColors.textDisabled,
                      fontWeight: hasRecord ? FontWeight.w800 : FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final List<AttendanceModel> records;

  const _HistoryCard({required this.records});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            icon: Icons.history_outlined,
            title: 'Attendance History',
          ),
          const SizedBox(height: 16),
          if (records.isEmpty)
            Text(
              'No attendance records for this month.',
              style: AppTextStyles.caption,
            )
          else
            Column(
              children: records.take(10).map((record) {
                final status = _attendanceStatus(record);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      PremiumTinyDot(color: status.color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _formatDate(record.date),
                          style: AppTextStyles.bodyMedium.copyWith(
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      Text(
                        _formatDuration(
                          record.netWorkingDuration(DateTime.now()),
                        ),
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                );
              }).toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final AttendanceModel? attendance;

  const _TimelineCard({required this.attendance});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: _TimelinePoint(
                icon: Icons.login,
                label: 'Check-in',
                value: _formatTime(context, attendance?.checkInTime),
              ),
            ),
            Container(width: 36, height: 1, color: Colors.white.withAlpha(44)),
            Expanded(
              child: _TimelinePoint(
                icon: Icons.logout,
                label: 'Check-out',
                value: _formatTime(context, attendance?.checkOutTime),
                alignEnd: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelinePoint extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool alignEnd;

  const _TimelinePoint({
    required this.icon,
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PremiumIconChip(icon: icon, color: color),
            const SizedBox(height: 14),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.headingSmall.copyWith(letterSpacing: 0),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _ValidationRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ValidationRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PremiumIconChip(icon: icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.bodyMedium),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttendanceActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _AttendanceActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 142,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 18),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: Colors.white.withAlpha(enabled ? 74 : 20)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _AttendanceViewData {
  final DateTime? operationsDate;
  final AttendanceModel? today;
  final List<AttendanceModel> monthRecords;
  final List<ManagerEmployeeSummaryModel> employeeSummaries;
  final List<AttendanceModel> operationsAttendance;
  final List<AttendanceModel> previousAttendance;
  final List<AttendanceModel> operationsMonthAttendance;
  final List<CustomerVisitModel> operationsVisits;
  final Map<String, LiveLocationModel> liveLocationsByUserId;
  final bool liveLocationsLoaded;

  const _AttendanceViewData({
    required this.operationsDate,
    required this.today,
    required this.monthRecords,
    required this.employeeSummaries,
    required this.operationsAttendance,
    required this.previousAttendance,
    required this.operationsMonthAttendance,
    required this.operationsVisits,
    required this.liveLocationsByUserId,
    required this.liveLocationsLoaded,
  });

  static const empty = _AttendanceViewData(
    operationsDate: null,
    today: null,
    monthRecords: <AttendanceModel>[],
    employeeSummaries: <ManagerEmployeeSummaryModel>[],
    operationsAttendance: <AttendanceModel>[],
    previousAttendance: <AttendanceModel>[],
    operationsMonthAttendance: <AttendanceModel>[],
    operationsVisits: <CustomerVisitModel>[],
    liveLocationsByUserId: <String, LiveLocationModel>{},
    liveLocationsLoaded: false,
  );

  _AttendanceViewData copyWith({
    List<AttendanceModel>? monthRecords,
    Map<String, LiveLocationModel>? liveLocationsByUserId,
    bool? liveLocationsLoaded,
  }) {
    return _AttendanceViewData(
      operationsDate: operationsDate,
      today: today,
      monthRecords: monthRecords ?? this.monthRecords,
      employeeSummaries: employeeSummaries,
      operationsAttendance: operationsAttendance,
      previousAttendance: previousAttendance,
      operationsMonthAttendance: operationsMonthAttendance,
      operationsVisits: operationsVisits,
      liveLocationsByUserId:
          liveLocationsByUserId ?? this.liveLocationsByUserId,
      liveLocationsLoaded:
          liveLocationsLoaded ?? this.liveLocationsLoaded,
    );
  }
}

class _AttendanceStatus {
  final String label;
  final Color color;

  const _AttendanceStatus({required this.label, required this.color});
}

_AttendanceStatus _attendanceStatus(AttendanceModel? attendance) {
  if (attendance == null) {
    return const _AttendanceStatus(
      label: 'Not Checked In',
      color: AppColors.textSecondary,
    );
  }

  if (attendance.breakStartTime != null) {
    return const _AttendanceStatus(label: 'On Break', color: AppColors.warning);
  }

  if (attendance.checkOutTime != null) {
    return const _AttendanceStatus(
      label: 'Checked Out',
      color: AppColors.checkOut,
    );
  }

  return const _AttendanceStatus(label: 'Checked In', color: AppColors.success);
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  return '${hours}h ${minutes}m';
}

String _formatTime(BuildContext context, DateTime? dateTime) {
  if (dateTime == null) return 'N/A';
  return TimeOfDay.fromDateTime(dateTime).format(context);
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Unknown date';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _formatMonth(DateTime month) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  return '${months[month.month - 1]} ${month.year}';
}

String _gpsLabel(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) return 'Not captured';
  return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}

AttendanceModel? _latestRecordForUser(
  List<AttendanceModel> records,
  String? userId,
) {
  if (userId == null) return null;
  AttendanceModel? latest;
  for (final record in records) {
    if (record.userId != userId) continue;
    final recordTime = record.checkInTime ?? record.date;
    final latestTime = latest?.checkInTime ?? latest?.date;
    if (latest == null ||
        (recordTime != null &&
            (latestTime == null || recordTime.isAfter(latestTime)))) {
      latest = record;
    }
  }
  return latest;
}
