import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/premium_widgets.dart';
import 'controllers/reports_controller.dart';
import 'models/report_summary_model.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<ReportSummaryModel> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = ReportsController.loadMySummary();
  }

  Future<void> _refresh() async {
    final future = ReportsController.loadMySummary();
    setState(() {
      _summaryFuture = future;
    });
    await future;
  }

  void _showExportPlaceholder(String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$format export placeholder is ready for backend wiring.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Reports', style: AppTextStyles.headingSmall),
      ),
      body: FutureBuilder<ReportSummaryModel>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const PremiumLoadingState(label: 'Loading analytics');
          }

          if (snapshot.hasError) {
            return PremiumErrorState(
              title: 'Reports failed to load.',
              error: snapshot.error,
              onRetry: _refresh,
            );
          }

          final summary = snapshot.data;
          if (summary == null) {
            return PremiumEmptyState(
              icon: Icons.analytics_outlined,
              title: 'No analytics yet',
              message: 'Attendance and visit data will generate reports here.',
              actionLabel: 'Refresh',
              onAction: _refresh,
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ReportHero(summary: summary),
                      const SizedBox(height: 16),
                      _DashboardCards(summary: summary),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 860;
                          final weekly = _ChartCard(
                            title: 'Weekly Charts',
                            icon: Icons.stacked_bar_chart_outlined,
                            buckets: summary.weeklyBuckets,
                          );
                          final monthly = _ChartCard(
                            title: 'Monthly Charts',
                            icon: Icons.bar_chart_outlined,
                            buckets: summary.monthlyBuckets,
                          );

                          if (!isWide) {
                            return Column(
                              children: [
                                weekly,
                                const SizedBox(height: 16),
                                monthly,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: weekly),
                              const SizedBox(width: 16),
                              Expanded(child: monthly),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _ExportCard(onExport: _showExportPlaceholder),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReportHero extends StatelessWidget {
  final ReportSummaryModel summary;

  const _ReportHero({required this.summary});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            icon: Icons.analytics_outlined,
            title: 'Reports and Analytics',
          ),
          const SizedBox(height: 18),
          Text(
            'Firestore aggregation across attendance, visits, and GPS captures.',
            style: AppTextStyles.caption.copyWith(height: 1.45),
          ),
          const SizedBox(height: 18),
          PremiumStatusChip(
            label: '${summary.attendanceRecords.length} attendance records',
            color: AppColors.info,
          ),
        ],
      ),
    );
  }
}

class _DashboardCards extends StatelessWidget {
  final ReportSummaryModel summary;

  const _DashboardCards({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _ReportMetric(
        icon: Icons.fact_check_outlined,
        label: 'Present Days',
        value: summary.presentDays.toString(),
        color: AppColors.success,
      ),
      _ReportMetric(
        icon: Icons.timer_outlined,
        label: 'Working Hours',
        value: _formatDuration(summary.totalWorkingDuration),
        color: AppColors.info,
      ),
      _ReportMetric(
        icon: Icons.business_center_outlined,
        label: 'Completed Visits',
        value: summary.completedVisits.toString(),
        color: AppColors.warning,
      ),
      _ReportMetric(
        icon: Icons.route_outlined,
        label: 'Distance',
        value: '${summary.distanceKilometers.toStringAsFixed(1)} km',
        color: AppColors.textPrimary,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: wide ? 4 : 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: wide ? 1.25 : 1.12,
          children: cards,
        );
      },
    );
  }
}

class _ReportMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ReportMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
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
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<ReportBucketModel> buckets;

  const _ChartCard({
    required this.title,
    required this.icon,
    required this.buckets,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumSectionHeader(icon: icon, title: title),
          const SizedBox(height: 18),
          SizedBox(
            height: 220,
            child: CustomPaint(
              painter: _ReportChartPainter(buckets: buckets),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              PremiumTinyDot(color: AppColors.info),
              SizedBox(width: 6),
              Text('Hours'),
              SizedBox(width: 14),
              PremiumTinyDot(color: AppColors.warning),
              SizedBox(width: 6),
              Text('Visits'),
              SizedBox(width: 14),
              PremiumTinyDot(color: AppColors.success),
              SizedBox(width: 6),
              Text('Distance'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExportCard extends StatelessWidget {
  final ValueChanged<String> onExport;

  const _ExportCard({required this.onExport});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            icon: Icons.file_download_outlined,
            title: 'Export Placeholders',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ExportButton(label: 'PDF', onTap: () => onExport('PDF')),
              _ExportButton(label: 'CSV', onTap: () => onExport('CSV')),
              _ExportButton(label: 'Excel', onTap: () => onExport('Excel')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ExportButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.file_download_outlined, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: Colors.white.withAlpha(54)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _ReportChartPainter extends CustomPainter {
  final List<ReportBucketModel> buckets;

  const _ReportChartPainter({required this.buckets});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(18)
      ..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final maxValue = buckets.fold<double>(1, (maxValue, bucket) {
      return [
        maxValue,
        bucket.attendanceHours,
        bucket.visits.toDouble(),
        bucket.distanceKilometers,
      ].reduce((a, b) => a > b ? a : b);
    });

    for (var i = 0; i <= 4; i++) {
      final y = size.height - 28 - (i * (size.height - 48) / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (buckets.isEmpty) return;

    final groupWidth = size.width / buckets.length;
    final barWidth = (groupWidth / 5).clamp(4.0, 14.0);
    for (var index = 0; index < buckets.length; index++) {
      final bucket = buckets[index];
      final centerX = index * groupWidth + groupWidth / 2;
      _drawBar(
        canvas,
        size,
        centerX - barWidth,
        barWidth,
        bucket.attendanceHours / maxValue,
        AppColors.info,
      );
      _drawBar(
        canvas,
        size,
        centerX,
        barWidth,
        bucket.visits / maxValue,
        AppColors.warning,
      );
      _drawBar(
        canvas,
        size,
        centerX + barWidth,
        barWidth,
        bucket.distanceKilometers / maxValue,
        AppColors.success,
      );

      textPainter.text = TextSpan(
        text: bucket.label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10,
          letterSpacing: 0,
        ),
      );
      textPainter.layout(maxWidth: groupWidth);
      textPainter.paint(
        canvas,
        Offset(centerX - textPainter.width / 2, size.height - 16),
      );
    }
  }

  void _drawBar(
    Canvas canvas,
    Size size,
    double x,
    double width,
    double ratio,
    Color color,
  ) {
    final chartHeight = size.height - 48;
    final height = (chartHeight * ratio.clamp(0, 1)).clamp(2.0, chartHeight);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, size.height - 28 - height, width, height),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, Paint()..color = color.withAlpha(190));
  }

  @override
  bool shouldRepaint(covariant _ReportChartPainter oldDelegate) {
    return oldDelegate.buckets != buckets;
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  return '${hours}h ${minutes}m';
}
