import 'package:flutter/material.dart';

import 'widgets/employee_home_dashboard.dart';

class EmployeeHomeScreen extends StatelessWidget {
  const EmployeeHomeScreen({super.key, required this.onNavigateToMap});

  final VoidCallback onNavigateToMap;

  @override
  Widget build(BuildContext context) {
    return EmployeeHomeDashboard(onNavigateToMap: onNavigateToMap);
  }
}
