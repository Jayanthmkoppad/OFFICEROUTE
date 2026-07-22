import 'package:flutter/material.dart';

import '../office_route_colors.dart';
import '../office_route_radii.dart';
import '../office_route_spacing.dart';
import '../office_route_status_style.dart';

/// Dark monochrome card container with optional semantic glow borders.
class OfficeRouteCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final TransportGlowType glowType;
  final VoidCallback? onTap;
  final bool isHero;

  const OfficeRouteCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(OfficeRouteSpacing.md),
    this.margin = EdgeInsets.zero,
    this.glowType = TransportGlowType.none,
    this.onTap,
    this.isHero = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = isHero
        ? OfficeRouteRadii.heroRadius
        : OfficeRouteRadii.cardRadius;
    final boxShadow = OfficeRouteStatusStyle.getGlowShadow(glowType);
    final borderColor = glowType != TransportGlowType.none
        ? OfficeRouteStatusStyle.getPrimaryColor(
            glowType,
          ).withValues(alpha: 0.5)
        : OfficeRouteColors.border;

    Widget cardContent = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: isHero
            ? OfficeRouteColors.raisedSurface
            : OfficeRouteColors.primarySurface,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: boxShadow,
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: cardContent,
      );
    }

    return cardContent;
  }
}
