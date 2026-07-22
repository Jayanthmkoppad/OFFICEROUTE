import 'package:flutter/material.dart';

import '../office_route_radii.dart';
import '../office_route_spacing.dart';
import '../office_route_status_style.dart';
import '../office_route_typography.dart';

/// Semantic status chip combining icon, text, and optional glow for accessibility.
class OfficeRouteStatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final TransportGlowType glowType;
  final bool isPill;

  const OfficeRouteStatusChip({
    super.key,
    required this.label,
    required this.icon,
    this.glowType = TransportGlowType.none,
    this.isPill = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = OfficeRouteStatusStyle.getPrimaryColor(glowType);
    final borderRadius = isPill
        ? OfficeRouteRadii.pillRadius
        : OfficeRouteRadii.smallRadius;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OfficeRouteSpacing.sm,
        vertical: OfficeRouteSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: borderRadius,
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: OfficeRouteSpacing.xxs),
          Text(
            label.toUpperCase(),
            style: OfficeRouteTypography.secondary.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
