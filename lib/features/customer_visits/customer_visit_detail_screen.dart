import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/premium_widgets.dart';
import 'controllers/customer_visit_controller.dart';
import 'models/customer_visit_model.dart';

class CustomerVisitDetailScreen extends StatefulWidget {
  final CustomerVisitModel visit;

  const CustomerVisitDetailScreen({super.key, required this.visit});

  @override
  State<CustomerVisitDetailScreen> createState() =>
      _CustomerVisitDetailScreenState();
}

class _CustomerVisitDetailScreenState extends State<CustomerVisitDetailScreen> {
  late CustomerVisitModel _visit;
  late Future<List<CustomerVisitModel>> _historyFuture;
  Timer? _timer;
  bool _isRunningAction = false;

  @override
  void initState() {
    super.initState();
    _visit = widget.visit;
    _historyFuture = CustomerVisitController.loadCustomerHistory(
      widget.visit.customerName,
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isTimerActive) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _isTimerActive =>
      _visit.checkInTime != null &&
      _visit.checkOutTime == null &&
      _visit.status != 'completed';

  Future<void> _runVisitAction(
    Future<CustomerVisitModel> Function() action,
  ) async {
    if (_isRunningAction) return;

    setState(() {
      _isRunningAction = true;
    });

    try {
      final updatedVisit = await action();
      if (!mounted) return;
      setState(() {
        _visit = updatedVisit;
        _historyFuture = CustomerVisitController.loadCustomerHistory(
          updatedVisit.customerName,
        );
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Visit update failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRunningAction = false;
        });
      }
    }
  }

  Future<void> _showPhotoDialog() async {
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Photo Evidence', style: AppTextStyles.headingSmall),
          content: PremiumTextField(
            controller: controller,
            label: 'Photo URL or file reference',
            icon: Icons.photo_outlined,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final value = controller.text.trim();
                if (value.isEmpty) return;

                Navigator.pop(context);
                await _runVisitAction(
                  () => CustomerVisitController.addPhotoReference(
                    visit: _visit,
                    photoUrl: value,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  Future<void> _showCompletionDialog() async {
    final notesController = TextEditingController(text: _visit.technicianNotes);
    final partsController = TextEditingController(
      text: _visit.partsUsed.join(', '),
    );
    bool videoReady = _visit.videoPlaceholderStatus == 'ready';
    bool signatureReady = _visit.signaturePlaceholderStatus == 'ready';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text('Complete Visit', style: AppTextStyles.headingSmall),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PremiumTextField(
                      controller: notesController,
                      label: 'Technician notes',
                      icon: Icons.note_alt_outlined,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    PremiumTextField(
                      controller: partsController,
                      label: 'Parts used',
                      icon: Icons.build_outlined,
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: videoReady,
                      onChanged: (value) {
                        setDialogState(() {
                          videoReady = value ?? false;
                        });
                      },
                      title: const Text('Video placeholder ready'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      value: signatureReady,
                      onChanged: (value) {
                        setDialogState(() {
                          signatureReady = value ?? false;
                        });
                      },
                      title: const Text('Signature placeholder ready'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _runVisitAction(
                      () => CustomerVisitController.completeVisit(
                        visit: _visit,
                        technicianNotes: notesController.text.trim(),
                        partsUsed: _splitList(partsController.text),
                        signatureStatus: signatureReady ? 'ready' : 'pending',
                        videoStatus: videoReady ? 'ready' : 'pending',
                      ),
                    );
                  },
                  child: const Text('Complete'),
                ),
              ],
            );
          },
        );
      },
    );

    notesController.dispose();
    partsController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canCheckIn = _visit.checkInTime == null;
    final canCheckOut =
        _visit.checkInTime != null && _visit.checkOutTime == null;
    final canComplete = _visit.checkOutTime != null && _visit.status != 'completed';
    final status = _visitStatus(_visit.status);

    return PopScope<CustomerVisitModel>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_visit);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: Text(
            _visit.customerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.headingSmall,
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 860;
            final mainColumn = Column(
              children: [
                _VisitHeroCard(
                  visit: _visit,
                  statusLabel: status.label,
                  statusColor: status.color,
                  timerLabel: _formatDuration(
                    _visit.visitDuration(DateTime.now()),
                  ),
                ),
                const SizedBox(height: 16),
                _ActionPanel(
                  isBusy: _isRunningAction,
                  canCheckIn: canCheckIn,
                  canCheckOut: canCheckOut,
                  canComplete: canComplete,
                  onCheckIn: () => _runVisitAction(
                    () => CustomerVisitController.checkIn(_visit),
                  ),
                  onCheckOut: () => _runVisitAction(
                    () => CustomerVisitController.checkOut(_visit),
                  ),
                  onComplete: _showCompletionDialog,
                  onAddPhoto: _showPhotoDialog,
                ),
                const SizedBox(height: 16),
                _ServiceDetailsCard(visit: _visit),
              ],
            );

            final secondaryColumn = Column(
              children: [
                _GpsCard(visit: _visit),
                const SizedBox(height: 16),
                _MediaCard(visit: _visit),
                const SizedBox(height: 16),
                _HistoryCard(historyFuture: _historyFuture),
              ],
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: mainColumn),
                            const SizedBox(width: 16),
                            Expanded(flex: 5, child: secondaryColumn),
                          ],
                        )
                      : Column(
                          children: [
                            mainColumn,
                            const SizedBox(height: 16),
                            secondaryColumn,
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _VisitHeroCard extends StatelessWidget {
  final CustomerVisitModel visit;
  final String statusLabel;
  final Color statusColor;
  final String timerLabel;

  const _VisitHeroCard({
    required this.visit,
    required this.statusLabel,
    required this.statusColor,
    required this.timerLabel,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  visit.customerName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headingMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              PremiumStatusChip(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            visit.customerAddress,
            style: AppTextStyles.caption.copyWith(height: 1.4),
          ),
          if (visit.customerPhone.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(visit.customerPhone, style: AppTextStyles.caption),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  icon: Icons.timer_outlined,
                  label: 'Visit timer',
                  value: timerLabel,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoTile(
                  icon: Icons.handyman_outlined,
                  label: 'Issue',
                  value: visit.issueCategory.isEmpty
                      ? 'Unassigned'
                      : visit.issueCategory,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  final bool isBusy;
  final bool canCheckIn;
  final bool canCheckOut;
  final bool canComplete;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final VoidCallback onComplete;
  final VoidCallback onAddPhoto;

  const _ActionPanel({
    required this.isBusy,
    required this.canCheckIn,
    required this.canCheckOut,
    required this.canComplete,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onComplete,
    required this.onAddPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            icon: Icons.play_circle_outline,
            title: 'Visit Actions',
          ),
          const SizedBox(height: 16),
          if (isBusy) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 16),
          ],
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActionButton(
                icon: Icons.login,
                label: 'Check In',
                enabled: canCheckIn && !isBusy,
                onTap: onCheckIn,
              ),
              _ActionButton(
                icon: Icons.logout,
                label: 'Check Out',
                enabled: canCheckOut && !isBusy,
                onTap: onCheckOut,
              ),
              _ActionButton(
                icon: Icons.photo_camera_outlined,
                label: 'Photo',
                enabled: !isBusy,
                onTap: onAddPhoto,
              ),
              _ActionButton(
                icon: Icons.verified_outlined,
                label: 'Complete',
                enabled: canComplete && !isBusy,
                onTap: onComplete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceDetailsCard extends StatelessWidget {
  final CustomerVisitModel visit;

  const _ServiceDetailsCard({required this.visit});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            icon: Icons.engineering_outlined,
            title: 'Service Details',
          ),
          const SizedBox(height: 16),
          _DetailRow(label: 'Vehicle', value: visit.vehicleDetails),
          _DetailRow(label: 'Motor Serial', value: visit.motorSerialNumber),
          _DetailRow(
            label: 'Controller Serial',
            value: visit.controllerSerialNumber,
          ),
          _DetailRow(label: 'Warranty', value: visit.warrantyStatus),
          _DetailRow(label: 'Issue Category', value: visit.issueCategory),
          _DetailRow(label: 'Issue Description', value: visit.issueDescription),
          _DetailRow(
            label: 'Parts Used',
            value: visit.partsUsed.isEmpty ? '' : visit.partsUsed.join(', '),
          ),
          _DetailRow(label: 'Technician Notes', value: visit.technicianNotes),
          _DetailRow(label: 'Internal Notes', value: visit.notes),
        ],
      ),
    );
  }
}

class _GpsCard extends StatelessWidget {
  final CustomerVisitModel visit;

  const _GpsCard({required this.visit});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            icon: Icons.gps_fixed_outlined,
            title: 'GPS Capture',
          ),
          const SizedBox(height: 16),
          _GpsPoint(
            label: 'Check-in',
            time: visit.checkInTime,
            latitude: visit.checkInLatitude,
            longitude: visit.checkInLongitude,
          ),
          const SizedBox(height: 12),
          _GpsPoint(
            label: 'Check-out',
            time: visit.checkOutTime,
            latitude: visit.checkOutLatitude,
            longitude: visit.checkOutLongitude,
          ),
        ],
      ),
    );
  }
}

class _MediaCard extends StatelessWidget {
  final CustomerVisitModel visit;

  const _MediaCard({required this.visit});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            icon: Icons.perm_media_outlined,
            title: 'Media and Sign-off',
          ),
          const SizedBox(height: 16),
          _DetailRow(
            label: 'Photos',
            value: visit.photoUrls.isEmpty
                ? 'No photo references added'
                : visit.photoUrls.join('\n'),
          ),
          _DetailRow(
            label: 'Video',
            value: _placeholderLabel(visit.videoPlaceholderStatus),
          ),
          _DetailRow(
            label: 'Signature',
            value: _placeholderLabel(visit.signaturePlaceholderStatus),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Future<List<CustomerVisitModel>> historyFuture;

  const _HistoryCard({required this.historyFuture});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            icon: Icons.history_outlined,
            title: 'Customer History',
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<CustomerVisitModel>>(
            future: historyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator(minHeight: 2);
              }

              if (snapshot.hasError) {
                return Text(
                  'History unavailable: ${snapshot.error}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.error,
                    height: 1.4,
                  ),
                );
              }

              final visits = snapshot.data ?? const <CustomerVisitModel>[];
              if (visits.isEmpty) {
                return Text(
                  'No previous visits found.',
                  style: AppTextStyles.caption,
                );
              }

              return Column(
                children: visits.take(5).map((visit) {
                  final status = _visitStatus(visit.status);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        PremiumTinyDot(color: status.color),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${_formatDate(visit.createdAt)} - ${status.label}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoTile({
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
            const SizedBox(height: 12),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionButton({
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(
            value.trim().isEmpty ? 'Not provided' : value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: value.trim().isEmpty
                  ? AppColors.textDisabled
                  : AppColors.textPrimary,
              height: 1.35,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _GpsPoint extends StatelessWidget {
  final String label;
  final DateTime? time;
  final double? latitude;
  final double? longitude;

  const _GpsPoint({
    required this.label,
    required this.time,
    required this.latitude,
    required this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    final hasGps = latitude != null && longitude != null;

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
            PremiumIconChip(
              icon: hasGps ? Icons.my_location : Icons.location_disabled,
              color: hasGps ? AppColors.success : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.bodyLarge),
                  const SizedBox(height: 4),
                  Text(
                    hasGps
                        ? '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'
                        : 'GPS not captured',
                    style: AppTextStyles.caption,
                  ),
                  if (time != null)
                    Text(_formatDateTime(context, time!), style: AppTextStyles.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitStatusData {
  final String label;
  final Color color;

  const _VisitStatusData({required this.label, required this.color});
}

_VisitStatusData _visitStatus(String status) {
  switch (status.toLowerCase()) {
    case 'checked_in':
      return const _VisitStatusData(label: 'Checked In', color: AppColors.info);
    case 'checked_out':
      return const _VisitStatusData(
        label: 'Checked Out',
        color: AppColors.warning,
      );
    case 'completed':
      return const _VisitStatusData(label: 'Completed', color: AppColors.success);
    case 'planned':
      return const _VisitStatusData(label: 'Planned', color: AppColors.textSecondary);
    default:
      return const _VisitStatusData(label: 'Open', color: AppColors.textSecondary);
  }
}

List<String> _splitList(String value) {
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${hours}h ${minutes}m ${seconds}s';
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _formatDateTime(BuildContext context, DateTime date) {
  return '${_formatDate(date)} ${TimeOfDay.fromDateTime(date).format(context)}';
}

String _placeholderLabel(String value) {
  return value == 'ready' ? 'Ready for final capture' : 'Pending final capture';
}
