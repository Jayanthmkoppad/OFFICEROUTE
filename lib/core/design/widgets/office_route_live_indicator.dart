import 'package:flutter/material.dart';

import '../office_route_colors.dart';
import '../office_route_spacing.dart';

/// Pulsing live status indicator dot with high contrast text for real-time tracking.
class OfficeRouteLiveIndicator extends StatefulWidget {
  final String label;
  final Color color;
  final bool isLive;

  const OfficeRouteLiveIndicator({
    super.key,
    this.label = 'LIVE',
    this.color = OfficeRouteColors.liveBlue,
    this.isLive = true,
  });

  @override
  State<OfficeRouteLiveIndicator> createState() =>
      _OfficeRouteLiveIndicatorState();
}

class _OfficeRouteLiveIndicatorState extends State<OfficeRouteLiveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _animation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimationState();
  }

  @override
  void didUpdateWidget(OfficeRouteLiveIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAnimationState();
  }

  void _updateAnimationState() {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    if (disableAnimations || !widget.isLive) {
      _controller.stop();
      _controller.value = 1.0;
    } else {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayColor = widget.isLive
        ? widget.color
        : OfficeRouteColors.secondaryText;
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final alphaVal = (disableAnimations || !widget.isLive)
                ? 1.0
                : _animation.value;
            return Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: displayColor.withValues(alpha: alphaVal),
                boxShadow: widget.isLive
                    ? [
                        BoxShadow(
                          color: displayColor.withValues(alpha: alphaVal * 0.6),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            );
          },
        ),
        const SizedBox(width: OfficeRouteSpacing.xxs),
        Text(
          widget.label.toUpperCase(),
          style: TextStyle(
            color: displayColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
