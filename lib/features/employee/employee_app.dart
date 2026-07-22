import 'package:flutter/material.dart';

import '../../core/design/widgets/office_route_bottom_navigation.dart';
import 'controllers/employee_transport_controller.dart';
import 'employee_home_screen.dart';
import 'employee_map_screen.dart';
import 'employee_profile_screen.dart';

class EmployeeApp extends StatefulWidget {
  const EmployeeApp({super.key});

  @override
  State<EmployeeApp> createState() => _EmployeeAppState();
}

class _EmployeeAppState extends State<EmployeeApp> {
  late final EmployeeTransportController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = EmployeeTransportController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (index >= 0 && index < 3 && index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EmployeeTransportScope(
      controller: _controller,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            EmployeeHomeScreen(onNavigateToMap: () => _selectTab(1)),
            const EmployeeMapScreen(),
            const EmployeeProfileScreen(),
          ],
        ),
        bottomNavigationBar: OfficeRouteBottomNavigation(
          selectedIndex: _currentIndex,
          onDestinationSelected: _selectTab,
          items: const [
            OfficeRouteNavigationItem(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: 'Home',
            ),
            OfficeRouteNavigationItem(
              icon: Icons.map_outlined,
              selectedIcon: Icons.map,
              label: 'Map',
            ),
            OfficeRouteNavigationItem(
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
