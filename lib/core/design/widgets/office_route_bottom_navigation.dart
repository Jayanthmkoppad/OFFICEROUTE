import 'package:flutter/material.dart';

import '../office_route_colors.dart';
import '../office_route_spacing.dart';
import '../office_route_typography.dart';

class OfficeRouteNavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const OfficeRouteNavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// NothingOS-inspired high contrast dark bottom navigation bar.
class OfficeRouteBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<OfficeRouteNavigationItem> items;

  const OfficeRouteBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: OfficeRouteColors.primarySurface,
        border: Border(
          top: BorderSide(color: OfficeRouteColors.border, width: 1.0),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: OfficeRouteSpacing.xs),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isSelected = index == selectedIndex;
            final color = isSelected
                ? OfficeRouteColors.primaryText
                : OfficeRouteColors.secondaryText;

            return InkWell(
              onTap: () => onDestinationSelected(index),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: OfficeRouteSpacing.md,
                  vertical: OfficeRouteSpacing.xxs,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      color: color,
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: OfficeRouteTypography.secondary.copyWith(
                        color: color,
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
