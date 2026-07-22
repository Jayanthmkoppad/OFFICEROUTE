import 'package:flutter/material.dart';

import '../office_route_colors.dart';
import '../office_route_spacing.dart';
import '../office_route_typography.dart';

/// Large operational metric tile displaying tabular metrics (ETA, Distance, Counts).
class OfficeRouteMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? accentColor;

  const OfficeRouteMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: accentColor ?? OfficeRouteColors.secondaryText,
              ),
              const SizedBox(width: OfficeRouteSpacing.xxs),
            ],
            Text(
              label.toUpperCase(),
              style: OfficeRouteTypography.secondary.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: OfficeRouteSpacing.xxs),
        Text(
          value,
          style: OfficeRouteTypography.largeMetric.copyWith(
            color: accentColor ?? OfficeRouteColors.primaryText,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: OfficeRouteTypography.secondary.copyWith(fontSize: 11),
          ),
        ],
      ],
    );
  }
}
