import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Visual progress overlay shown while the driver taps Start Duty. Walks the
/// driver through the well-defined Start Duty phases:
///
///   1. Vehicle selected
///   2. Location permission granted
///   3. Attendance check-in
///   4. Location session started
///   5. First GPS fix received
///
/// The step index is driven by the caller as work progresses. If a step
/// fails, the overlay stays paused on that step so the driver can retry.
/// Overlay never fabricates progress; every advance must be explicitly set.
class DriverStartDutyOverlay extends StatelessWidget {
  final int currentStep;
  final String? errorMessage;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  const DriverStartDutyOverlay({
    super.key,
    required this.currentStep,
    this.errorMessage,
    this.onCancel,
    this.onRetry,
  });

  static const List<String> steps = <String>[
    'Vehicle selected',
    'Location permission granted',
    'Attendance check-in',
    'Location session started',
    'First GPS fix received',
  ];

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withAlpha(160),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Starting Duty',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Please wait while we prepare your shift.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 14),
                for (var index = 0; index < steps.length; index++)
                  _StepRow(label: steps[index], state: _stateFor(index)),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(24),
                      border: Border.all(color: AppColors.error.withAlpha(80)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onCancel != null)
                      TextButton(
                        onPressed: onCancel,
                        child: const Text('Cancel'),
                      ),
                    if (errorMessage != null && onRetry != null)
                      FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _StepState _stateFor(int index) {
    if (errorMessage != null && index == currentStep) return _StepState.error;
    if (index < currentStep) return _StepState.done;
    if (index == currentStep) return _StepState.active;
    return _StepState.pending;
  }
}

enum _StepState { pending, active, done, error }

class _StepRow extends StatelessWidget {
  final String label;
  final _StepState state;
  const _StepRow({required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (state) {
      _StepState.done => (Icons.check_circle, AppColors.success),
      _StepState.active => (Icons.autorenew, AppColors.info),
      _StepState.error => (Icons.error_outline, AppColors.error),
      _StepState.pending => (Icons.circle_outlined, AppColors.textDisabled),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: state == _StepState.active
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: state == _StepState.pending
                    ? AppColors.textDisabled
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          if (state == _StepState.active)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}
