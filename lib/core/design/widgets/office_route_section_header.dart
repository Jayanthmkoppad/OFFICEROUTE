import 'package:flutter/material.dart';

import '../office_route_colors.dart';
import '../office_route_spacing.dart';
import '../office_route_typography.dart';

/// Section header component with title, subtitle, and optional trailing widget.
class OfficeRouteSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const OfficeRouteSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OfficeRouteSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: OfficeRouteTypography.sectionTitle),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: OfficeRouteTypography.secondary.copyWith(
                      color: OfficeRouteColors.secondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
