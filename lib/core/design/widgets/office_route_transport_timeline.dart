import 'package:flutter/material.dart';

import '../office_route_colors.dart';
import '../office_route_spacing.dart';
import '../office_route_status_style.dart';
import '../office_route_typography.dart';

class OfficeRouteTimelineStep {
  final String title;
  final String? subtitle;
  final String? timeText;
  final TransportGlowType glowType;
  final bool isCompleted;
  final bool isActive;

  const OfficeRouteTimelineStep({
    required this.title,
    this.subtitle,
    this.timeText,
    this.glowType = TransportGlowType.none,
    this.isCompleted = false,
    this.isActive = false,
  });
}

/// Operational transport timeline widget for trip progress visualisation.
class OfficeRouteTransportTimeline extends StatelessWidget {
  final List<OfficeRouteTimelineStep> steps;

  const OfficeRouteTransportTimeline({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isLast = index == steps.length - 1;
        final color = step.isActive || step.isCompleted
            ? OfficeRouteStatusStyle.getPrimaryColor(step.glowType)
            : OfficeRouteColors.disabledText;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: step.isCompleted
                        ? color
                        : (step.isActive
                              ? color.withValues(alpha: 0.2)
                              : OfficeRouteColors.primarySurface),
                    border: Border.all(color: color, width: 2),
                    boxShadow: step.isActive
                        ? OfficeRouteStatusStyle.getGlowShadow(step.glowType)
                        : null,
                  ),
                  child: step.isCompleted
                      ? const Icon(
                          Icons.check,
                          size: 12,
                          color: OfficeRouteColors.background,
                        )
                      : null,
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 36,
                    color: step.isCompleted ? color : OfficeRouteColors.border,
                  ),
              ],
            ),
            const SizedBox(width: OfficeRouteSpacing.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: OfficeRouteSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          step.title,
                          style: OfficeRouteTypography.cardTitle.copyWith(
                            fontSize: 14,
                            color: step.isActive || step.isCompleted
                                ? OfficeRouteColors.primaryText
                                : OfficeRouteColors.secondaryText,
                            fontWeight: step.isActive
                                ? FontWeight.bold
                                : FontWeight.w600,
                          ),
                        ),
                        if (step.timeText != null)
                          Text(
                            step.timeText!,
                            style: OfficeRouteTypography.secondary.copyWith(
                              fontSize: 11,
                              color: OfficeRouteColors.secondaryText,
                            ),
                          ),
                      ],
                    ),
                    if (step.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        step.subtitle!,
                        style: OfficeRouteTypography.secondary.copyWith(
                          color: OfficeRouteColors.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
