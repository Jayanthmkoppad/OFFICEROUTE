import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Compact live flip clock suitable for an app home/dashboard header.
///
/// No package dependency. Uses the device's local date and time.
class EmployeeFlipClock extends StatefulWidget {
  const EmployeeFlipClock({
    super.key,
    this.use24HourFormat = true,
    this.showSeconds = true,
    this.compact = false,
  });

  final bool use24HourFormat;
  final bool showSeconds;
  final bool compact;

  @override
  State<EmployeeFlipClock> createState() => _EmployeeFlipClockState();
}

class _EmployeeFlipClockState extends State<EmployeeFlipClock> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _scheduleTick();
  }

  void _scheduleTick() {
    _timer?.cancel();
    final now = DateTime.now();
    final delay = Duration(milliseconds: 1000 - now.millisecond);
    _timer = Timer(delay, () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _scheduleTick();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  int get _displayHour {
    if (widget.use24HourFormat) return _now.hour;
    final hour = _now.hour % 12;
    return hour == 0 ? 12 : hour;
  }

  @override
  Widget build(BuildContext context) {
    final hours = _twoDigits(_displayHour);
    final minutes = _twoDigits(_now.minute);
    final seconds = _twoDigits(_now.second);

    return Container(
      padding: EdgeInsets.all(widget.compact ? 12 : 18),
      decoration: BoxDecoration(
        color: const Color(0xFF090909),
        borderRadius: BorderRadius.circular(widget.compact ? 18 : 24),
        border: Border.all(color: const Color(0xFF1E1E1E)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LiveDot(),
              SizedBox(width: 7),
              Text(
                'LIVE',
                style: TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
          SizedBox(height: widget.compact ? 10 : 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FlipPair(value: hours, compact: widget.compact),
                const _ClockSeparator(),
                _FlipPair(value: minutes, compact: widget.compact),
                if (widget.showSeconds) ...[
                  const _ClockSeparator(),
                  _FlipPair(value: seconds, compact: widget.compact),
                ],
              ],
            ),
          ),
          SizedBox(height: widget.compact ? 10 : 15),
          Text(
            _formatDate(_now),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF737373),
              fontFamily: 'monospace',
              fontSize: widget.compact ? 9 : 11,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${weekdays[date.weekday - 1]}, '
        '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _FlipPair extends StatelessWidget {
  const _FlipPair({required this.value, required this.compact});

  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FlipDigit(value: value[0], compact: compact),
        SizedBox(width: compact ? 4 : 7),
        FlipDigit(value: value[1], compact: compact),
      ],
    );
  }
}

class FlipDigit extends StatefulWidget {
  const FlipDigit({super.key, required this.value, this.compact = false});

  final String value;
  final bool compact;

  @override
  State<FlipDigit> createState() => _FlipDigitState();
}

class _FlipDigitState extends State<FlipDigit>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late String _currentValue;
  late String _nextValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
    _nextValue = widget.value;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant FlipDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _currentValue) {
      _nextValue = widget.value;
      _controller
        ..reset()
        ..forward().whenComplete(() {
          if (!mounted) return;
          setState(() => _currentValue = _nextValue);
        });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.compact ? 38.0 : 56.0;
    final height = widget.compact ? 52.0 : 76.0;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final progress = _animation.value;
        final topAngle = progress <= 0.5 ? -math.pi * progress : -math.pi / 2;
        final bottomAngle = progress <= 0.5
            ? math.pi / 2
            : math.pi / 2 * (2 - progress * 2);

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              _DigitCard(value: _nextValue, width: width, height: height),
              if (_controller.isAnimating) ...[
                if (progress <= 0.5)
                  _HalfLeaf(
                    value: _currentValue,
                    width: width,
                    height: height,
                    isTop: true,
                    angle: topAngle,
                  ),
                if (progress > 0.5)
                  _HalfLeaf(
                    value: _nextValue,
                    width: width,
                    height: height,
                    isTop: false,
                    angle: bottomAngle,
                  ),
              ],
              Positioned(
                left: 0,
                right: 0,
                top: height / 2 - 0.75,
                child: Container(height: 1.5, color: const Color(0xFF080808)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DigitCard extends StatelessWidget {
  const _DigitCard({
    required this.value,
    required this.width,
    required this.height,
  });

  final String value;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1D1D1D), Color(0xFF111111)],
        ),
        border: Border.all(color: const Color(0xFF242424)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 12,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: _DigitText(value: value, height: height),
    );
  }
}

class _HalfLeaf extends StatelessWidget {
  const _HalfLeaf({
    required this.value,
    required this.width,
    required this.height,
    required this.isTop,
    required this.angle,
  });

  final String value;
  final double width;
  final double height;
  final bool isTop;
  final double angle;

  @override
  Widget build(BuildContext context) {
    final alignment = isTop ? Alignment.bottomCenter : Alignment.topCenter;

    return Positioned(
      top: isTop ? 0 : height / 2,
      child: Transform(
        alignment: alignment,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.002)
          ..rotateX(angle),
        child: ClipRect(
          child: Align(
            alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            heightFactor: 0.5,
            child: Container(
              width: width,
              height: height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isTop
                      ? const [Color(0xFF202020), Color(0xFF171717)]
                      : const [Color(0xFF101010), Color(0xFF151515)],
                ),
              ),
              child: _DigitText(value: value, height: height),
            ),
          ),
        ),
      ),
    );
  }
}

class _DigitText extends StatelessWidget {
  const _DigitText({required this.value, required this.height});

  final String value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: TextStyle(
        color: const Color(0xFFFFA126),
        fontSize: height * 0.70,
        height: 1,
        fontWeight: FontWeight.w800,
        shadows: const [
          Shadow(color: Color(0xB3FF8A00), blurRadius: 14),
          Shadow(color: Color(0x55FF8A00), blurRadius: 28),
        ],
      ),
    );
  }
}

class _ClockSeparator extends StatelessWidget {
  const _ClockSeparator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 7),
      child: Text(
        ':',
        style: TextStyle(
          color: Color(0xFF3A3A3A),
          fontSize: 32,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.32, end: 1).animate(_controller),
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: Color(0xFFB93623),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0xAAFF4128), blurRadius: 8)],
        ),
      ),
    );
  }
}
