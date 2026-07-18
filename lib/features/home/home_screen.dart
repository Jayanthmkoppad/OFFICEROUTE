import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/location_model.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../attendance/attendance_screen.dart';
import '../attendance/controllers/attendance_controller.dart';
import '../attendance/models/attendance_model.dart';
import '../complaints/complaint_register_screen.dart';
import '../customer_visits/controllers/customer_visit_controller.dart';
import '../customer_visits/customer_visit_screen.dart';
import '../customer_visits/models/customer_visit_model.dart';
import '../map/controllers/location_controller.dart';
import '../map/map_screen.dart';
import '../notifications/notification_center_screen.dart';
import '../profile/controllers/profile_controller.dart';
import '../profile/profile_screen.dart';
import '../reports/reports_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void _selectTab(int index) {
    if (index == _currentIndex) return;

    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildPage() {
    switch (_currentIndex) {
      case 1:
        return const MapScreen();
      case 2:
        return const AttendanceScreen();
      case 3:
        return const CustomerVisitScreen();
      case 4:
        return const ProfileScreen();
      case 0:
      default:
        return HomeDashboard(onNavigate: _selectTab);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _buildPage(),
        ),
      ),
      bottomNavigationBar: _PremiumBottomNavigation(
        currentIndex: _currentIndex,
        onTap: _selectTab,
      ),
    );
  }
}

class HomeDashboard extends StatefulWidget {
  final ValueChanged<int> onNavigate;

  const HomeDashboard({super.key, required this.onNavigate});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard>
    with SingleTickerProviderStateMixin {
  late Future<_DashboardData> _dashboardFuture;
  late AnimationController _introController;
  late Animation<Offset> _slideAnimation;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboardData();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero).animate(
          CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic),
        );
    _introController.forward();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _introController.dispose();
    super.dispose();
  }

  Future<void> _refreshDashboard() async {
    final refreshedFuture = _loadDashboardData();
    setState(() {
      _dashboardFuture = refreshedFuture;
      _now = DateTime.now();
    });
    await refreshedFuture;
  }

  Future<_DashboardData> _loadDashboardData() async {
    final profileFuture = _guardDashboardLoad<UserModel?>(
      method: 'ProfileController.loadCurrentUser',
      loader: ProfileController.loadCurrentUser,
    );
    final attendanceFuture = _guardDashboardLoad<AttendanceModel?>(
      method: 'AttendanceController.loadTodayAttendance',
      loader: AttendanceController.loadTodayAttendance,
    );
    final visitsFuture = _guardDashboardLoad<List<CustomerVisitModel>>(
      method: 'CustomerVisitController.loadMyVisits',
      loader: CustomerVisitController.loadMyVisits,
    );
    final locationFuture = _guardDashboardLoad<LocationModel>(
      method: 'LocationController.getCurrentLocation',
      loader: LocationController.getCurrentLocation,
    );

    return _DashboardData(
      profile: await profileFuture,
      attendance: await attendanceFuture,
      visits: await visitsFuture,
      location: await locationFuture,
    );
  }

  Future<_DashboardValue<T>> _guardDashboardLoad<T>({
    required String method,
    required Future<T> Function() loader,
  }) async {
    try {
      return _DashboardValue<T>.loaded(await loader());
    } catch (error, stackTrace) {
      debugPrint('Home dashboard data load failed');
      debugPrint('File: lib/features/home/home_screen.dart');
      debugPrint('Method: $method');
      debugPrint('Runtime type: ${error.runtimeType}');
      debugPrint('Exception: $error');
      debugPrint('Stack trace:\n$stackTrace');
      return _DashboardValue<T>.failed(error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: _refreshDashboard,
        child: FutureBuilder<_DashboardData>(
          future: _dashboardFuture,
          builder: (context, snapshot) {
            final content = snapshot.hasData
                ? _DashboardContent(
                    data: snapshot.data!,
                    now: _now,
                    onNavigate: widget.onNavigate,
                  )
                : snapshot.hasError
                ? _DashboardErrorView(error: snapshot.error)
                : _DashboardLoadingView(now: _now);

            return FadeTransition(
              opacity: _introController,
              child: SlideTransition(position: _slideAnimation, child: content),
            );
          },
        ),
      ),
    );
  }
}

class _PremiumBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _PremiumBottomNavigation({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xF20A0A0A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1F1F1F)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.transparent,
            elevation: 0,
            selectedItemColor: AppColors.textPrimary,
            unselectedItemColor: AppColors.textDisabled,
            selectedLabelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
            onTap: onTap,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.map_outlined),
                activeIcon: Icon(Icons.map),
                label: 'Map',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.fact_check_outlined),
                activeIcon: Icon(Icons.fact_check),
                label: 'Attendance',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.business_center_outlined),
                activeIcon: Icon(Icons.business_center),
                label: 'Visits',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final _DashboardData data;
  final DateTime now;
  final ValueChanged<int> onNavigate;

  const _DashboardContent({
    required this.data,
    required this.now,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final user = data.profile.value;
    final attendance = data.attendance.value;
    final visits = data.visits.value ?? const <CustomerVisitModel>[];
    final todayVisits = visits
        .where((visit) => _isVisitForDay(visit, now))
        .toList(growable: false);
    final employeeName = _employeeName(user);
    final dutyStatus = _DutyStatus.fromAttendance(attendance);
    final workingHours = _formatWorkingDuration(attendance, now);
    final nextVisit = _nextVisit(todayVisits);

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 360 ? 14.0 : 20.0;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            12,
            horizontalPadding,
            18,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeroPanel(
                    greeting: _greetingFor(now),
                    employeeName: employeeName,
                    role: _roleLabel(user),
                    avatarUrl: user?.profileImage ?? '',
                    currentTime: _formatClock(context, now),
                    currentDate: _formatDate(now),
                    onOpenNotifications: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationCenterScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _TodayOperationsCard(
                    status: dutyStatus,
                    workingHours: workingHours,
                    todayVisits: todayVisits,
                    visitsError: data.visits.error,
                  ),
                  const SizedBox(height: 12),
                  _QuickActionsCard(
                    onOpenAttendance: () => onNavigate(2),
                    onOpenVisits: () => onNavigate(3),
                    onOpenComplaint: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ComplaintRegisterScreen(),
                        ),
                      );
                    },
                    onOpenReports: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReportsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _OperationsHubCard(
                    todayVisits: todayVisits,
                    visitsError: data.visits.error,
                  ),
                  const SizedBox(height: 12),
                  _NextAssignmentCard(
                    visit: nextVisit,
                    visitsError: data.visits.error,
                    onOpenVisits: () => onNavigate(3),
                  ),
                  const SizedBox(height: 12),
                  _ProductivityCard(
                    todayVisits: todayVisits,
                    visitsError: data.visits.error,
                    now: now,
                  ),
                  const SizedBox(height: 12),
                  _AttendanceSummaryCard(
                    attendance: attendance,
                    attendanceError: data.attendance.error,
                    workingHours: workingHours,
                    onOpenAttendance: () => onNavigate(2),
                  ),
                  const SizedBox(height: 12),
                  _MapPreviewCard(
                    location: data.location.value,
                    locationError: data.location.error,
                    onOpenMap: () => onNavigate(1),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeroPanel extends StatelessWidget {
  final String greeting;
  final String employeeName;
  final String role;
  final String avatarUrl;
  final String currentTime;
  final String currentDate;
  final VoidCallback onOpenNotifications;

  const _HeroPanel({
    required this.greeting,
    required this.employeeName,
    required this.role,
    required this.avatarUrl,
    required this.currentTime,
    required this.currentDate,
    required this.onOpenNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _DotMatrix(width: 42, dotCount: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'OFFICEROUTE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _LiveTimePill(time: currentTime, date: currentDate),
              const SizedBox(width: 10),
              _NotificationButton(onPressed: onOpenNotifications),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      employeeName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _ProfileAvatar(name: employeeName, imageUrl: avatarUrl),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _NotificationButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withAlpha(32)),
          ),
          child: const Icon(
            Icons.notifications_none_outlined,
            color: AppColors.textPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _TodayOperationsCard extends StatelessWidget {
  final _DutyStatus status;
  final String workingHours;
  final List<CustomerVisitModel> todayVisits;
  final Object? visitsError;

  const _TodayOperationsCard({
    required this.status,
    required this.workingHours,
    required this.todayVisits,
    required this.visitsError,
  });

  @override
  Widget build(BuildContext context) {
    final completedVisits = _visitCountByStatus(todayVisits, 'completed');
    final totalVisits = todayVisits.length;
    final openIssues = _openIssueCount(todayVisits);
    final progress = totalVisits == 0 ? 0.0 : completedVisits / totalVisits;
    final hasVisitData = visitsError == null;

    final metrics = [
      _OperationDatum(
        icon: Icons.person_pin_circle_outlined,
        label: 'DUTY STATUS',
        value: status.label,
        meta: 'Current',
        color: status.color,
      ),
      _OperationDatum(
        icon: Icons.timer_outlined,
        label: 'WORKING HOURS',
        value: workingHours,
        meta: 'Today',
        color: AppColors.info,
        tabular: true,
      ),
      _OperationDatum(
        icon: Icons.business_center_outlined,
        label: "TODAY'S VISITS",
        value: hasVisitData ? totalVisits.toString() : '--',
        meta: hasVisitData ? 'Scheduled' : 'Unavailable',
        color: AppColors.warning,
        tabular: true,
      ),
      _OperationDatum(
        icon: Icons.insights_outlined,
        label: 'PROGRESS',
        value: hasVisitData
            ? totalVisits == 0
                  ? '0%'
                  : '${(progress * 100).round()}%'
            : '--',
        meta: hasVisitData ? '$completedVisits/$totalVisits done' : '--',
        color: AppColors.success,
        progress: hasVisitData && totalVisits > 0 ? progress : null,
        tabular: true,
      ),
      _OperationDatum(
        icon: Icons.report_problem_outlined,
        label: 'OPEN ISSUES',
        value: hasVisitData ? openIssues.toString() : '--',
        meta: hasVisitData
            ? openIssues == 0
                  ? 'Clear'
                  : 'Pending'
            : 'Unavailable',
        color: openIssues == 0 ? AppColors.textSecondary : AppColors.error,
        tabular: true,
      ),
    ];

    return _PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: "Today's Operations"),
          const SizedBox(height: 12),
          _MetricWrap(children: metrics),
        ],
      ),
    );
  }
}

class _OperationDatum extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String meta;
  final Color color;
  final bool tabular;
  final double? progress;

  const _OperationDatum({
    required this.icon,
    required this.label,
    required this.value,
    required this.meta,
    required this.color,
    this.tabular = false,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: AppTextStyles.headingSmall.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                  letterSpacing: 0,
                  fontFeatures: tabular
                      ? const [FontFeature.tabularFigures()]
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 0,
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  color: color,
                  backgroundColor: Colors.white.withAlpha(18),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricWrap extends StatelessWidget {
  final List<Widget> children;

  const _MetricWrap({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? children.length
            : constraints.maxWidth >= 520
            ? 3
            : 2;
        final gap = columns == 1 ? 0.0 : 8.0;
        final tileWidth =
            (constraints.maxWidth - ((columns - 1) * gap)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: 8,
          children: [
            for (final child in children)
              SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}

class _OperationsHubCard extends StatelessWidget {
  final List<CustomerVisitModel> todayVisits;
  final Object? visitsError;

  const _OperationsHubCard({
    required this.todayVisits,
    required this.visitsError,
  });

  @override
  Widget build(BuildContext context) {
    final hasVisitData = visitsError == null;
    final planned = _visitCountByStatus(todayVisits, 'planned');
    final active = _visitCountByStatus(todayVisits, 'checked_in');
    final completed = _visitCountByStatus(todayVisits, 'completed');
    final pending = hasVisitData
        ? todayVisits
              .where((visit) => visit.status.toLowerCase() != 'completed')
              .length
        : 0;

    return _PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Operations Hub'),
          const SizedBox(height: 12),
          _MetricWrap(
            children: [
              _OperationDatum(
                icon: Icons.event_available_outlined,
                label: 'PLANNED',
                value: hasVisitData ? planned.toString() : '--',
                meta: 'Visits',
                color: AppColors.textSecondary,
                tabular: true,
              ),
              _OperationDatum(
                icon: Icons.check_circle_outline,
                label: 'COMPLETED',
                value: hasVisitData ? completed.toString() : '--',
                meta: 'Visits',
                color: AppColors.success,
                tabular: true,
              ),
              _OperationDatum(
                icon: Icons.radio_button_checked,
                label: 'ACTIVE',
                value: hasVisitData ? active.toString() : '--',
                meta: 'Now',
                color: AppColors.info,
                tabular: true,
              ),
              _OperationDatum(
                icon: Icons.pending_actions_outlined,
                label: 'PENDING',
                value: hasVisitData ? pending.toString() : '--',
                meta: 'Not completed',
                color: AppColors.warning,
                tabular: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductivityCard extends StatelessWidget {
  final List<CustomerVisitModel> todayVisits;
  final Object? visitsError;
  final DateTime now;

  const _ProductivityCard({
    required this.todayVisits,
    required this.visitsError,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final hasVisitData = visitsError == null;
    final averageVisitDuration = hasVisitData
        ? _formatAverageVisitDuration(todayVisits, now)
        : '--';

    return _PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Productivity'),
          const SizedBox(height: 12),
          _MetricWrap(
            children: [
              const _OperationDatum(
                icon: Icons.route_outlined,
                label: 'DISTANCE',
                value: '--',
                meta: 'km',
                color: AppColors.textSecondary,
                tabular: true,
              ),
              _OperationDatum(
                icon: Icons.timer_outlined,
                label: 'AVG VISIT TIME',
                value: averageVisitDuration,
                meta: hasVisitData ? 'Per visit' : 'Unavailable',
                color: AppColors.info,
                tabular: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceSummaryCard extends StatelessWidget {
  final AttendanceModel? attendance;
  final Object? attendanceError;
  final String workingHours;
  final VoidCallback onOpenAttendance;

  const _AttendanceSummaryCard({
    required this.attendance,
    required this.attendanceError,
    required this.workingHours,
    required this.onOpenAttendance,
  });

  @override
  Widget build(BuildContext context) {
    final status = _DutyStatus.fromAttendance(attendance);
    final checkIn = attendance?.checkInTime == null
        ? 'Not marked'
        : _formatTime(context, attendance!.checkInTime!);
    final checkOut = attendance?.checkOutTime == null
        ? 'Pending'
        : _formatTime(context, attendance!.checkOutTime!);

    return _PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.fact_check_outlined,
            title: 'Attendance Snapshot',
            actionLabel: 'Open',
            onAction: onOpenAttendance,
          ),
          const SizedBox(height: 12),
          if (attendanceError != null)
            _InlineError(message: 'Attendance summary is unavailable.')
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 520;
                final tiles = [
                  _DetailBlock(
                    label: 'Status',
                    value: status.label,
                    color: status.color,
                  ),
                  _DetailBlock(
                    label: 'Working Hours',
                    value: workingHours,
                    color: AppColors.info,
                  ),
                  _DetailBlock(
                    label: 'Check In',
                    value: checkIn,
                    color: AppColors.success,
                  ),
                  _DetailBlock(
                    label: 'Check Out',
                    value: checkOut,
                    color: AppColors.warning,
                  ),
                ];

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tiles.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isCompact ? 2 : 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: isCompact ? 1.65 : 1.55,
                  ),
                  itemBuilder: (context, index) => tiles[index],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _NextAssignmentCard extends StatelessWidget {
  final CustomerVisitModel? visit;
  final Object? visitsError;
  final VoidCallback onOpenVisits;

  const _NextAssignmentCard({
    required this.visit,
    required this.visitsError,
    required this.onOpenVisits,
  });

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.business_center_outlined,
            title: 'Next Assignment',
            actionLabel: 'Open Visit',
            onAction: onOpenVisits,
          ),
          const SizedBox(height: 12),
          if (visitsError != null)
            _InlineError(message: 'Customer visits are unavailable.')
          else if (visit == null)
            Text(
              'No visits scheduled today.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 0,
              ),
            )
          else
            _NextVisitRow(visit: visit!, onTap: onOpenVisits),
        ],
      ),
    );
  }
}

class _NextVisitRow extends StatelessWidget {
  final CustomerVisitModel visit;
  final VoidCallback onTap;

  const _NextVisitRow({required this.visit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = _visitStatus(visit.status);
    final address = visit.customerAddress.trim().isEmpty
        ? '--'
        : visit.customerAddress.trim();
    final time = _formatTime(context, visit.checkInTime ?? visit.createdAt);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 390;
        final details = Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Next Visit',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                visit.customerName.trim().isEmpty
                    ? '--'
                    : visit.customerName.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(letterSpacing: 0),
                    ),
                  ),
                ],
              ),
              if (isCompact) ...[
                const SizedBox(height: 3),
                Text(
                  'Time: $time',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        );

        return Material(
          color: AppColors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(8),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withAlpha(22)),
              ),
              child: Row(
                children: [
                  _IndexBadge(label: '1', color: status.color),
                  const SizedBox(width: 12),
                  details,
                  const SizedBox(width: 10),
                  if (!isCompact) ...[
                    Text(
                      time,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _StatusPill(
                        label: status.label,
                        color: status.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _IndexBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _IndexBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withAlpha(20),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyMedium.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _MapPreviewCard extends StatelessWidget {
  final LocationModel? location;
  final Object? locationError;
  final VoidCallback onOpenMap;

  const _MapPreviewCard({
    required this.location,
    required this.locationError,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final hasLocation = location != null;

    return _PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.map_outlined,
            title: 'Live Map Preview',
            actionLabel: 'Open Map',
            onAction: onOpenMap,
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 188,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _MapPreviewPainter()),
                  if (!hasLocation)
                    Container(
                      alignment: Alignment.center,
                      color: Colors.black.withAlpha(80),
                      child: Text(
                        locationError == null
                            ? 'Waiting for location signal'
                            : 'Location unavailable',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasLocation
                            ? AppColors.info.withAlpha(28)
                            : Colors.white.withAlpha(18),
                        border: Border.all(
                          color: hasLocation
                              ? AppColors.info.withAlpha(70)
                              : Colors.white.withAlpha(44),
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasLocation
                                ? AppColors.info
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MapStatusBar(
            location: location,
            locationError: locationError,
            onOpenMap: onOpenMap,
          ),
        ],
      ),
    );
  }
}

class _MapStatusBar extends StatelessWidget {
  final LocationModel? location;
  final Object? locationError;
  final VoidCallback onOpenMap;

  const _MapStatusBar({
    required this.location,
    required this.locationError,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final hasLocation = location != null;
    final statusText = hasLocation
        ? 'Location signal active'
        : locationError == null
        ? 'Location pending'
        : 'Location unavailable';
    final coordinateText = hasLocation
        ? '${location!.latitude.toStringAsFixed(5)}, '
              '${location!.longitude.toStringAsFixed(5)}'
        : '--';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 380;
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TinyStatusDot(
                  color: hasLocation ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Coordinates: $coordinateText  |  Accuracy: --',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              details,
              const SizedBox(height: 10),
              _OutlinedActionButton(label: 'Open Map', onPressed: onOpenMap),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: details),
            const SizedBox(width: 12),
            _OutlinedActionButton(label: 'Open Map', onPressed: onOpenMap),
          ],
        );
      },
    );
  }
}

class _OutlinedActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _OutlinedActionButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: BorderSide(color: Colors.white.withAlpha(42)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        visualDensity: VisualDensity.compact,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  final VoidCallback onOpenAttendance;
  final VoidCallback onOpenVisits;
  final VoidCallback onOpenComplaint;
  final VoidCallback onOpenReports;

  const _QuickActionsCard({
    required this.onOpenAttendance,
    required this.onOpenVisits,
    required this.onOpenComplaint,
    required this.onOpenReports,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickActionData(
        label: 'Attendance',
        icon: Icons.fact_check_outlined,
        color: AppColors.info,
        onPressed: onOpenAttendance,
      ),
      _QuickActionData(
        label: 'Visits',
        icon: Icons.business_center_outlined,
        color: AppColors.warning,
        onPressed: onOpenVisits,
      ),
      _QuickActionData(
        label: 'Complaint Register',
        icon: Icons.assignment_outlined,
        color: AppColors.success,
        onPressed: onOpenComplaint,
      ),
      _QuickActionData(
        label: 'Reports',
        icon: Icons.analytics_outlined,
        color: AppColors.error,
        onPressed: onOpenReports,
      ),
    ];

    return _PremiumCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          for (var index = 0; index < actions.length; index++) ...[
            Expanded(child: _QuickActionButton(data: actions[index])),
            if (index != actions.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _QuickActionData {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _QuickActionData({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });
}

class _QuickActionButton extends StatefulWidget {
  final _QuickActionData data;

  const _QuickActionButton({required this.data});

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: widget.data.onPressed,
          onHighlightChanged: (value) {
            setState(() {
              _pressed = value;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 76,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withAlpha(22)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.data.icon, color: widget.data.color, size: 19),
                const SizedBox(height: 5),
                Flexible(
                  child: Text(
                    widget.data.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 10.5,
                      height: 1.08,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          _IconChip(icon: icon!, color: AppColors.textPrimary),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.headingSmall.copyWith(
              fontSize: 16,
              letterSpacing: 0,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          _ActionLink(label: actionLabel!, onPressed: onAction!),
      ],
    );
  }
}

class _ActionLink extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _ActionLink({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(62)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TinyStatusDot(color: color),
            const SizedBox(width: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _PremiumCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1F1F1F)),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _LiveTimePill extends StatelessWidget {
  final String time;
  final String date;

  const _LiveTimePill({required this.time, required this.date});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              time,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              date,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String name;
  final String imageUrl;

  const _ProfileAvatar({required this.name, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl.trim();
    final hasNetworkImage =
        trimmedUrl.startsWith('http://') || trimmedUrl.startsWith('https://');

    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withAlpha(46)),
        color: Colors.white.withAlpha(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasNetworkImage
          ? Image.network(
              trimmedUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _AvatarInitials(name: name),
            )
          : _AvatarInitials(name: name),
    );
  }
}

class _AvatarInitials extends StatelessWidget {
  final String name;

  const _AvatarInitials({required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        _initialsFor(name),
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DetailBlock({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TinyStatusDot(color: color),
            const SizedBox(height: 7),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.headingSmall.copyWith(
                fontSize: 18,
                height: 1.05,
                letterSpacing: 0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(letterSpacing: 0),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.error.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(letterSpacing: 0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardLoadingView extends StatelessWidget {
  final DateTime now;

  const _DashboardLoadingView({required this.now});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PremiumCard(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _DotMatrix(width: 42, dotCount: 18),
                        const Spacer(),
                        _LiveTimePill(
                          time: _formatClock(context, now),
                          date: _formatDate(now),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Preparing dashboard',
                      style: AppTextStyles.headingMedium.copyWith(
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _DotLoader(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardErrorView extends StatelessWidget {
  final Object? error;

  const _DashboardErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: _PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.error_outline,
              title: 'Dashboard Error',
            ),
            const SizedBox(height: 14),
            Text(
              'Home dashboard failed to load: $error',
              style: AppTextStyles.bodyMedium.copyWith(letterSpacing: 0),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconChip({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(56)),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _TinyStatusDot extends StatelessWidget {
  final Color color;

  const _TinyStatusDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _DotLoader extends StatefulWidget {
  const _DotLoader();

  @override
  State<_DotLoader> createState() => _DotLoaderState();
}

class _DotLoaderState extends State<_DotLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _opacityFor(int index) {
    final value = (_controller.value - (index * 0.15)) % 1;
    return 0.3 + (0.7 * (1 - ((2 * value) - 1).abs()));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return Padding(
              padding: EdgeInsets.only(right: index == 2 ? 0 : 7),
              child: Opacity(
                opacity: _opacityFor(index),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.textPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _DotMatrix extends StatelessWidget {
  final double width;
  final int dotCount;

  const _DotMatrix({required this.width, required this.dotCount});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: List.generate(dotCount, (index) {
          final opacity = index.isEven ? 112 : 54;
          return Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(opacity),
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}

class _DashboardData {
  final _DashboardValue<UserModel?> profile;
  final _DashboardValue<AttendanceModel?> attendance;
  final _DashboardValue<List<CustomerVisitModel>> visits;
  final _DashboardValue<LocationModel> location;

  const _DashboardData({
    required this.profile,
    required this.attendance,
    required this.visits,
    required this.location,
  });
}

class _DashboardValue<T> {
  final T? value;
  final Object? error;
  final StackTrace? stackTrace;

  const _DashboardValue._({this.value, this.error, this.stackTrace});

  factory _DashboardValue.loaded(T value) {
    return _DashboardValue<T>._(value: value);
  }

  factory _DashboardValue.failed(Object error, StackTrace stackTrace) {
    return _DashboardValue<T>._(error: error, stackTrace: stackTrace);
  }
}

class _DutyStatus {
  final String label;
  final Color color;

  const _DutyStatus({required this.label, required this.color});

  factory _DutyStatus.fromAttendance(AttendanceModel? attendance) {
    if (attendance?.checkInTime == null) {
      return const _DutyStatus(
        label: 'Off Duty',
        color: AppColors.textSecondary,
      );
    }

    if (attendance?.checkOutTime != null) {
      return const _DutyStatus(
        label: 'Shift Complete',
        color: AppColors.checkOut,
      );
    }

    return const _DutyStatus(label: 'On Duty', color: AppColors.success);
  }
}

class _VisitStatus {
  final String label;
  final Color color;

  const _VisitStatus({required this.label, required this.color});
}

class _MapPreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = const Color(0xFF070707);
    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(12)
      ..strokeWidth = 1;
    final routePaint = Paint()
      ..color = Colors.white.withAlpha(92)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final minorRoadPaint = Paint()
      ..color = Colors.white.withAlpha(22)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawRect(Offset.zero & size, backgroundPaint);

    for (double x = -30; x < size.width + 40; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x + 42, size.height), gridPaint);
    }

    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 10), gridPaint);
    }

    final path = Path()
      ..moveTo(size.width * 0.05, size.height * 0.70)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.52,
        size.width * 0.42,
        size.height * 0.78,
        size.width * 0.56,
        size.height * 0.48,
      )
      ..cubicTo(
        size.width * 0.70,
        size.height * 0.22,
        size.width * 0.82,
        size.height * 0.42,
        size.width * 0.96,
        size.height * 0.22,
      );

    for (var index = 0; index < 5; index++) {
      final y = size.height * (0.18 + (index * 0.16));
      canvas.drawLine(
        Offset(size.width * 0.04, y),
        Offset(size.width * 0.95, y + (index.isEven ? 18 : -12)),
        minorRoadPaint,
      );
    }

    canvas.drawPath(path, routePaint);
    final center = Offset(size.width * 0.50, size.height * 0.52);
    canvas.drawCircle(
      center,
      46,
      Paint()..color = AppColors.info.withAlpha(16),
    );
    canvas.drawCircle(
      center,
      30,
      Paint()..color = AppColors.info.withAlpha(26),
    );
    canvas.drawCircle(center, 14, Paint()..color = AppColors.info);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _employeeName(UserModel? user) {
  final name = user?.name.trim() ?? '';
  if (name.isNotEmpty) return name;

  final email = user?.email.trim() ?? '';
  final separatorIndex = email.indexOf('@');
  if (separatorIndex > 0) {
    return email.substring(0, separatorIndex);
  }

  return 'Employee';
}

String _roleLabel(UserModel? user) {
  final role = user?.role.trim() ?? '';
  if (role.isEmpty) return 'Field Employee';

  return role
      .split(RegExp(r'[\s_-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _greetingFor(DateTime dateTime) {
  final hour = dateTime.hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

String _formatClock(BuildContext context, DateTime dateTime) {
  return TimeOfDay.fromDateTime(dateTime).format(context);
}

String _formatTime(BuildContext context, DateTime dateTime) {
  return TimeOfDay.fromDateTime(dateTime).format(context);
}

String _formatDate(DateTime dateTime) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${dateTime.day} ${months[dateTime.month - 1]}';
}

String _formatWorkingDuration(AttendanceModel? attendance, DateTime now) {
  final checkIn = attendance?.checkInTime;
  if (checkIn == null) return '0h 00m';

  final checkOut = attendance?.checkOutTime;
  final endTime = checkOut ?? now;
  if (endTime.isBefore(checkIn)) return '0h 00m';

  final duration = endTime.difference(checkIn);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  return '${hours}h ${minutes}m';
}

bool _isVisitForDay(CustomerVisitModel visit, DateTime day) {
  return _isSameDay(visit.createdAt, day) ||
      _isSameDay(visit.checkInTime, day) ||
      _isSameDay(visit.checkOutTime, day);
}

int _visitCountByStatus(List<CustomerVisitModel> visits, String status) {
  return visits
      .where((visit) => visit.status.toLowerCase() == status.toLowerCase())
      .length;
}

String _formatAverageVisitDuration(
  List<CustomerVisitModel> visits,
  DateTime now,
) {
  final durations = visits
      .map((visit) => visit.visitDuration(now))
      .where((duration) => duration.inSeconds > 0)
      .toList(growable: false);

  if (durations.isEmpty) return '--';

  final totalSeconds = durations.fold<int>(
    0,
    (sum, duration) => sum + duration.inSeconds,
  );
  final average = Duration(seconds: (totalSeconds / durations.length).round());

  return _formatCompactDuration(average);
}

String _formatCompactDuration(Duration duration) {
  if (duration.inSeconds <= 0) return '--';

  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }

  if (minutes == 0) return '<1m';
  return '${minutes}m';
}

int _openIssueCount(List<CustomerVisitModel> visits) {
  return visits.where((visit) {
    final isComplete = visit.status.toLowerCase() == 'completed';
    final hasIssue =
        visit.issueCategory.trim().isNotEmpty ||
        visit.issueDescription.trim().isNotEmpty;
    return !isComplete && hasIssue;
  }).length;
}

CustomerVisitModel? _nextVisit(List<CustomerVisitModel> visits) {
  if (visits.isEmpty) return null;

  for (final visit in visits) {
    if (visit.status.toLowerCase() == 'checked_in') {
      return visit;
    }
  }

  for (final visit in visits) {
    if (visit.status.toLowerCase() == 'planned') {
      return visit;
    }
  }

  return visits.first;
}

_VisitStatus _visitStatus(String status) {
  switch (status.toLowerCase()) {
    case 'checked_in':
      return const _VisitStatus(label: 'Active', color: AppColors.info);
    case 'checked_out':
      return const _VisitStatus(label: 'Checked Out', color: AppColors.warning);
    case 'completed':
      return const _VisitStatus(label: 'Done', color: AppColors.success);
    case 'planned':
      return const _VisitStatus(label: 'Planned', color: AppColors.warning);
    default:
      return const _VisitStatus(label: 'Open', color: AppColors.textSecondary);
  }
}

bool _isSameDay(DateTime? a, DateTime b) {
  if (a == null) return false;

  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _initialsFor(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);

  if (parts.isEmpty) return 'OR';
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }

  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
