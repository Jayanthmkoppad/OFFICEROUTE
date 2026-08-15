import 'package:flutter/material.dart';

import 'service_engineer_complaints_screen.dart';
import 'service_engineer_home_screen.dart';
import 'service_engineer_jobs_screen.dart';
import 'service_engineer_map_screen.dart';
import 'service_engineer_profile_screen.dart';

class ServiceEngineerApp extends StatefulWidget {
  const ServiceEngineerApp({super.key});

  @override
  State<ServiceEngineerApp> createState() => _ServiceEngineerAppState();
}

class _ServiceEngineerAppState extends State<ServiceEngineerApp> {
  int _currentIndex = 0;

  void _selectTab(int index) {
    if (index >= 0 && index < 5 && index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ServiceEngineerHomeScreen(onNavigateToJobs: () => _selectTab(1)),
          const ServiceEngineerJobsScreen(),
          const ServiceEngineerMapScreen(),
          const ServiceEngineerComplaintsScreen(),
          const ServiceEngineerProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.handyman_outlined),
            selectedIcon: Icon(Icons.handyman),
            label: 'Jobs',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Complaints',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
