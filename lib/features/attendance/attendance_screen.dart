import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/premium_widgets.dart';
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
  Timer? _clockTimer;
  bool _isRunningAction = false;

  @override
  void initState() {
    super.initState();
    _attendanceFuture = _loadAttendance();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<_AttendanceViewData> _loadAttendance() async {
    final todayFuture = AttendanceController.loadTodayAttendance();
    final monthFuture = AttendanceController.loadAttendanceForMonth(_visibleMonth);

    return _AttendanceViewData(
      today: await todayFuture,
      monthRecords: await monthFuture,
    );
  }

  Future<void> _refresh() async {
    final future = _loadAttendance();
    setState(() {
      _attendanceFuture = future;
    });
    await future;
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance update failed: $error')),
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
      _attendanceFuture = _loadAttendance();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Attendance', style: AppTextStyles.headingSmall),
      ),
      body: FutureBuilder<_AttendanceViewData>(
        future: _attendanceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const PremiumLoadingState(label: 'Loading attendance');
          }

          if (snapshot.hasError) {
            return PremiumErrorState(
              title: 'Attendance failed to load.',
              error: snapshot.error,
              onRetry: _refresh,
            );
          }

          final data = snapshot.data ??
              const _AttendanceViewData(
                today: null,
                monthRecords: <AttendanceModel>[],
              );

          return RefreshIndicator(
            onRefresh: _refresh,
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
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 5, child: summaryColumn),
                                const SizedBox(width: 16),
                                Expanded(flex: 6, child: historyColumn),
                              ],
                            )
                          : Column(
                              children: [
                                summaryColumn,
                                const SizedBox(height: 16),
                                historyColumn,
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
            value: attendance == null
                ? 'No attendance record yet'
                : 'Firestore offline cache active, ${attendance!.syncStatus}',
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
            const Spacer(),
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
  final AttendanceModel? today;
  final List<AttendanceModel> monthRecords;

  const _AttendanceViewData({
    required this.today,
    required this.monthRecords,
  });
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
