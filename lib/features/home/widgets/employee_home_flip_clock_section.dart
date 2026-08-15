import 'package:flutter/material.dart';

import '../../../shared/widgets/employee_flip_clock.dart';

/// Ready-to-use clock section for the employee dashboard.
///
/// Place this widget near the top of HomeDashboard.
class EmployeeHomeFlipClockSection extends StatelessWidget {
  const EmployeeHomeFlipClockSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmployeeFlipClock(use24HourFormat: true, showSeconds: true);
  }
}
