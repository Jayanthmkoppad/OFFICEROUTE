import 'package:flutter/material.dart';

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
        children: const [
          _PlaceholderTab(
            title: 'Service Engineer Desk',
            subtitle:
                'Field duty home dashboard will be implemented in Stage 1C.',
            icon: Icons.engineering_outlined,
          ),
          _PlaceholderTab(
            title: 'Assigned Customer Visits',
            subtitle:
                'Job dispatch and site check-in will be implemented in Stage 1C.',
            icon: Icons.handyman_outlined,
          ),
          _PlaceholderTab(
            title: 'Field Service Map',
            subtitle:
                'Customer visit location map will be implemented in Stage 1C.',
            icon: Icons.map_outlined,
          ),
          _PlaceholderTab(
            title: 'Service Complaints',
            subtitle:
                'Complaint inspection and resolution will be implemented in Stage 1C.',
            icon: Icons.assignment_outlined,
          ),
          _PlaceholderTab(
            title: 'Service Engineer Profile',
            subtitle:
                'Field skills and certifications will be implemented in Stage 1C.',
            icon: Icons.person_outline,
          ),
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

class _PlaceholderTab extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _PlaceholderTab({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), elevation: 0),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 56,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
