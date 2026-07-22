import 'package:flutter/material.dart';

import '../office_route_colors.dart';
import '../office_route_radii.dart';
import '../office_route_spacing.dart';
import '../office_route_status_style.dart';
import '../office_route_typography.dart';

/// Primary action button adhering to high-contrast accessibility rules.
class OfficeRoutePrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final TransportGlowType glowType;
  final Color? backgroundColor;
  final Color? textColor;

  const OfficeRoutePrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.glowType = TransportGlowType.none,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor =
        backgroundColor ??
        (glowType != TransportGlowType.none
            ? OfficeRouteStatusStyle.getPrimaryColor(glowType)
            : OfficeRouteColors.primaryText);

    final txtColor =
        textColor ??
        (bgColor == OfficeRouteColors.primaryText
            ? OfficeRouteColors.background
            : OfficeRouteColors.primaryText);

    final boxShadow = OfficeRouteStatusStyle.getGlowShadow(glowType);

    return Container(
      decoration: BoxDecoration(
        borderRadius: OfficeRouteRadii.smallRadius,
        boxShadow: boxShadow,
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: txtColor,
          disabledBackgroundColor: OfficeRouteColors.raisedSurface,
          disabledForegroundColor: OfficeRouteColors.disabledText,
          padding: const EdgeInsets.symmetric(
            horizontal: OfficeRouteSpacing.lg,
            vertical: OfficeRouteSpacing.md,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: OfficeRouteRadii.smallRadius,
          ),
          elevation: 0,
          minimumSize: const Size(48, 48),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(txtColor),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: txtColor),
                    const SizedBox(width: OfficeRouteSpacing.xs),
                  ],
                  Text(
                    label,
                    style: OfficeRouteTypography.button.copyWith(
                      color: txtColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
