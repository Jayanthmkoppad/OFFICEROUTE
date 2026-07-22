import 'package:flutter/material.dart';

import '../office_route_colors.dart';
import '../office_route_radii.dart';
import '../office_route_spacing.dart';
import '../office_route_typography.dart';

/// Quiet, inline empty state card for missing assignments or unconfigured states.
class OfficeRouteEmptyState extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Widget? action;

  const OfficeRouteEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.info_outline,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(OfficeRouteSpacing.lg),
      decoration: BoxDecoration(
        color: OfficeRouteColors.raisedSurface,
        borderRadius: OfficeRouteRadii.cardRadius,
        border: Border.all(color: OfficeRouteColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: OfficeRouteColors.secondaryText),
          const SizedBox(height: OfficeRouteSpacing.xs),
          Text(
            title,
            style: OfficeRouteTypography.cardTitle.copyWith(
              color: OfficeRouteColors.primaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: OfficeRouteSpacing.xxs),
          Text(
            description,
            style: OfficeRouteTypography.secondary.copyWith(
              color: OfficeRouteColors.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: OfficeRouteSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}
