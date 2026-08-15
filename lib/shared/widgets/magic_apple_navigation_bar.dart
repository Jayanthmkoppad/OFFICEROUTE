import 'dart:ui';

import 'package:flutter/material.dart';

/// Reusable Apple-style liquid glass navigation bar.
///
/// Works with 3–6 items and does not require third-party packages.
class MagicAppleNavigationBar extends StatelessWidget {
  const MagicAppleNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 12),
    this.height = 76,
  }) : assert(items.length >= 2);

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<MagicNavigationItem> items;
  final EdgeInsets margin;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      minimum: margin,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / items.length;
          final pillLeft = itemWidth * currentIndex;

          return ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xC916181E)
                      : Colors.white.withValues(alpha: 0.54),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.72),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.34 : 0.12,
                      ),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 520),
                      curve: Curves.easeOutBack,
                      left: pillLeft + 6,
                      top: 6,
                      width: itemWidth - 12,
                      height: height - 12,
                      child: _LiquidPill(isDark: isDark),
                    ),
                    Row(
                      children: List.generate(items.length, (index) {
                        final selected = index == currentIndex;
                        final item = items[index];

                        return Expanded(
                          child: Semantics(
                            selected: selected,
                            button: true,
                            label: item.label,
                            child: InkWell(
                              onTap: () => onTap(index),
                              borderRadius: BorderRadius.circular(24),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.center,
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeOutBack,
                                  scale: selected ? 1.05 : 1,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        selected
                                            ? (item.activeIcon ?? item.icon)
                                            : item.icon,
                                        size: 23,
                                        color: selected
                                            ? colorScheme.onSurface
                                            : colorScheme.onSurface.withValues(
                                                alpha: 0.54,
                                              ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          height: 1,
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: selected
                                              ? colorScheme.onSurface
                                              : colorScheme.onSurface
                                                    .withValues(alpha: 0.50),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LiquidPill extends StatelessWidget {
  const _LiquidPill({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.17),
                  Colors.white.withValues(alpha: 0.06),
                ]
              : [
                  Colors.white.withValues(alpha: 0.92),
                  Colors.white.withValues(alpha: 0.42),
                ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.84),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.40),
            blurRadius: 10,
            offset: const Offset(-3, -3),
          ),
        ],
      ),
      child: Align(
        alignment: const Alignment(-0.45, -0.8),
        child: FractionallySizedBox(
          widthFactor: 0.54,
          heightFactor: 0.18,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: isDark ? 0.16 : 0.56),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MagicNavigationItem {
  const MagicNavigationItem({
    required this.icon,
    required this.label,
    this.activeIcon,
  });

  final IconData icon;
  final IconData? activeIcon;
  final String label;
}
