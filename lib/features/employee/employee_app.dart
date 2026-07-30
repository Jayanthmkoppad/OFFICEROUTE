import 'package:flutter/material.dart';

import '../../core/design/widgets/office_route_bottom_navigation.dart';
import 'controllers/employee_transport_controller.dart';
import 'employee_home_screen.dart';
import 'employee_map_screen.dart';
import 'employee_profile_screen.dart';

class EmployeeApp extends StatefulWidget {
  const EmployeeApp({super.key, this.controller});

  @visibleForTesting
  final EmployeeTransportController? controller;

  @override
  State<EmployeeApp> createState() => _EmployeeAppState();
}

class _EmployeeAppState extends State<EmployeeApp> with WidgetsBindingObserver {
  late final EmployeeTransportController _controller;
  late final bool _ownsController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? EmployeeTransportController();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.refreshCurrentDay();
    }
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
          key: const Key('employee_tab_stack'),
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
