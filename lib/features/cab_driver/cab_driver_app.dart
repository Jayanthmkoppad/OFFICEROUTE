import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/cab_assignment_member_model.dart';
import '../../core/models/cab_trip_cancellation.dart';
import '../../core/models/office_destination.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/premium_widgets.dart';
import '../auth/services/auth_service.dart';
import 'controllers/cab_driver_controller.dart';
import 'cab_driver_workflow_support.dart';
import 'cab_driver_operational_flow.dart';
import 'driver_live_trip_screen.dart';
import 'driver_notifications_screen.dart';
import 'driver_profile_screen.dart';
import 'widgets/driver_start_duty_overlay.dart';

class CabDriverApp extends StatefulWidget {
  const CabDriverApp({super.key});

  @override
  State<CabDriverApp> createState() => _CabDriverAppState();
}

class _CabDriverAppState extends State<CabDriverApp> {
  final CabDriverController _controller = const CabDriverController();
  late Future<CabDriverOperations> _future;
  CabDriverOperations? _lastData;
  final List<StreamSubscription<void>> _subscriptions = [];
  Timer? _debounce;
  Timer? _clock;
  int _index = 0;
  bool _busy = false;
  bool _reloadInFlight = false;
  bool _reloadQueued = false;

  @override
  void initState() {
    super.initState();
    _future = CabDriverController.load();
    for (final stream in CabDriverController.realtimeStreams()) {
      _subscriptions.add(stream.listen((_) => _scheduleReload()));
    }
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _clock?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _reload);
  }

  Future<void> _reload() async {
    if (!mounted) return;
    if (_reloadInFlight) {
      _reloadQueued = true;
      return;
    }
    _reloadInFlight = true;
    try {
      final data = await CabDriverController.load();
      if (!mounted) return;
      setState(() {
        _lastData = data;
        _future = Future<CabDriverOperations>.value(data);
      });
    } catch (error, stackTrace) {
      debugPrint('Driver operation reload failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _reloadInFlight = false;
      if (_reloadQueued && mounted) {
        _reloadQueued = false;
        _scheduleReload();
      }
    }
  }

  Future<void> _action(
    Future<void> Function(CabDriverOperations data) action,
    CabDriverOperations data,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action(data);
      await _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_driverErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleStartDuty(CabDriverOperations data) async {
    final vehicle = await CabDriverWorkflowSupport.resolveDriverVehicle(data);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StartDutyChecklistSheet(
          initialVehicleId: vehicle?.id ?? '',
          initialOfficeDestination: OfficeDestination.fromDriver(data.driver),
          onConfirm:
              ({
                required vehicleId,
                required startOdometer,
                required batteryPercentage,
                required vehicleCondition,
                required officeDestination,
                note,
              }) async {
                await CabDriverWorkflowSupport.startDuty(
                  data,
                  vehicleId: vehicleId,
                  startOdometer: startOdometer,
                  batteryPercentage: batteryPercentage,
                  vehicleCondition: vehicleCondition,
                  officeDestination: officeDestination,
                );
                await _reload();
              },
        );
      },
    );
  }

  void _openOperationalFlow(
    CabDriverOperations data,
    DriverOperationalPhase phase,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CabDriverOperationalFlow(
          data: data,
          initialPhase: phase,
          onReload: _reload,
        ),
      ),
    );
  }

  Future<void> _signOut(CabDriverOperations data) async {
    if (data.activeTrip != null) {
      throw StateError(
        'Complete or cancel the active trip before signing out.',
      );
    }
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _debounce?.cancel();
    _clock?.cancel();
    await CabDriverWorkflowSupport.releaseSession();
    await CabDriverController.releaseSession(data);
    await AuthService.signOut();
  }

  String _driverErrorMessage(Object error) {
    final value = error.toString().toLowerCase();
    if (value.contains('permission-denied') ||
        value.contains('insufficient permissions')) {
      return 'Driver access is not configured for this action. Contact Operations.';
    }
    if (value.contains('unknownhost') ||
        value.contains('network') ||
        value.contains('unavailable')) {
      return 'Network unavailable. Your Driver state is preserved; retry shortly.';
    }
    return error is StateError
        ? error.message.toString()
        : 'The Driver action could not complete. Please retry.';
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _driverTheme(),
      child: FutureBuilder<CabDriverOperations>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _lastData = snapshot.data;
          }
          final cachedData = snapshot.data ?? _lastData;
          if (snapshot.connectionState == ConnectionState.waiting &&
              cachedData == null) {
            return const Scaffold(
              body: PremiumLoadingState(label: 'Loading driver operations'),
            );
          }
          if ((snapshot.hasError || cachedData == null) && cachedData == null) {
            return Scaffold(
              body: PremiumErrorState(
                title: 'Driver operations could not be loaded.',
                error: snapshot.error,
                onRetry: _reload,
              ),
            );
          }
          final data = cachedData;
          final pages = [
            _DriverHome(
              data: data,
              busy: _busy,
              onAction: _action,
              onStartDuty: _handleStartDuty,
              onRetry: _reload,
            ),
            DriverLiveTripScreen(
              key: ValueKey(_controller),
              data: data,
              onRetry: _reload,
              onOpenWorkflow: (phase) => _openOperationalFlow(data, phase),
            ),
            DriverNotificationsScreen(
              key: const PageStorageKey('driver-notifications-tab'),
              data: data,
              onOpenWorkflow: (phase) => _openOperationalFlow(data, phase),
            ),
            DriverProfileScreen(
              key: const PageStorageKey('driver-profile-tab'),
              data: data,
              onSignOut: () => _signOut(data),
              onOpenWorkflow: (phase) => _openOperationalFlow(data, phase),
            ),
          ];
          return Scaffold(
            body: IndexedStack(index: _index, children: pages),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map),
                  label: 'Live Trip',
                ),
                NavigationDestination(
                  icon: Icon(Icons.notifications_outlined),
                  selectedIcon: Icon(Icons.notifications),
                  label: 'Notifications',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

ThemeData _driverTheme() {
  const background = Color(0xFF051424);
  const surface = Color(0xFF122131);
  const cyan = Color(0xFF00F2FF);
  const onSurface = Color(0xFFD4E4FA);
  const outline = Color(0xFF3A494B);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: cyan,
        brightness: Brightness.dark,
        surface: surface,
      ).copyWith(
        primary: cyan,
        onPrimary: const Color(0xFF00363A),
        secondary: const Color(0xFF74F5FF),
        surface: surface,
        onSurface: onSurface,
        outline: outline,
        error: const Color(0xFFFFB4AB),
      );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    cardColor: surface,
    dividerColor: outline.withValues(alpha: 0.55),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: onSurface,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cyan.withValues(alpha: 0.10)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 80,
      backgroundColor: const Color(0xFF010F1F),
      indicatorColor: cyan,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 56),
        foregroundColor: onSurface,
        side: const BorderSide(color: outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textTheme: ThemeData.dark().textTheme.apply(
      bodyColor: onSurface,
      displayColor: onSurface,
    ),
  );
}

/// Nothing-OS styled reason picker used before skipping a pickup. Returns
/// the selected reason (a canonical label or a free-text entry) or null when
/// the driver cancels.
Future<String?> _showSkipReasonDialog(
  BuildContext context,
  CabDriverOperations data,
) async {
  const reasons = <String>[
    'Employee unavailable',
    'Employee cancelled',
    'Wrong location',
    'Driver instructed by Admin',
    'Other',
  ];
  final activeRider = data.activeRider;
  final riderName = activeRider == null
      ? 'this employee'
      : data.employees[activeRider.employeeId]?.name ?? 'this employee';
  final controller = TextEditingController();
  String selected = reasons.first;
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: Text('Skip $riderName?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Choose a reason:'),
                  const SizedBox(height: 8),
                  ...reasons.map(
                    (reason) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        selected == reason
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      title: Text(reason),
                      onTap: () => setState(() => selected = reason),
                    ),
                  ),
                  if (selected == 'Other') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Describe the reason',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final text = selected == 'Other'
                      ? controller.text.trim()
                      : selected;
                  if (text.isEmpty) return;
                  Navigator.pop(dialogContext, text);
                },
                child: const Text('Skip'),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Nothing-OS styled Trip Summary sheet shown before Complete Trip. Every
/// metric comes from live Firestore data; unavailable values are shown as
/// dashes rather than fabricated numbers. Returns true when the driver
/// confirms Complete Trip.
Future<CabTripCancellation?> _showTripCancellationDialog(
  BuildContext context,
) async {
  var selected = CabTripCancellationReason.vehicleBreakdown;
  final explanationController = TextEditingController();
  final result = await showDialog<CabTripCancellation>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          final requiresExplanation =
              selected == CabTripCancellationReason.other;
          final canSubmit =
              !requiresExplanation ||
              explanationController.text.trim().isNotEmpty;
          return AlertDialog(
            title: const Text('Cancel active trip?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This is terminal. Trip history and completed pickup facts will be preserved.',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<CabTripCancellationReason>(
                    initialValue: selected,
                    decoration: const InputDecoration(
                      labelText: 'Cancellation reason',
                    ),
                    items: CabTripCancellationReason.values
                        .map(
                          (reason) => DropdownMenuItem(
                            value: reason,
                            child: Text(reason.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) setState(() => selected = value);
                    },
                  ),
                  if (requiresExplanation)
                    TextField(
                      key: const Key('trip_cancellation_explanation'),
                      controller: explanationController,
                      minLines: 2,
                      maxLines: 4,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Required explanation',
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Keep Trip Active'),
              ),
              FilledButton(
                key: const Key('confirm_trip_cancellation'),
                onPressed: canSubmit
                    ? () => Navigator.pop(
                        dialogContext,
                        CabTripCancellation(
                          reason: selected,
                          explanation: explanationController.text.trim(),
                        ),
                      )
                    : null,
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('Cancel Trip'),
              ),
            ],
          );
        },
      );
    },
  );
  explanationController.dispose();
  return result;
}

Future<bool?> _showTripSummarySheet(
  BuildContext context,
  CabDriverOperations data,
) async {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return FutureBuilder<CabTripSummary?>(
        future: CabDriverWorkflowSupport.summariseActiveTrip(data),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final summary = snapshot.data;
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trip Summary',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Review the summary before completing the trip.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _summaryRow(
                  context,
                  'Employees Transported',
                  summary == null
                      ? 'ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â'
                      : '${summary.completedPickups}',
                ),
                _summaryRow(
                  context,
                  'Total Selected',
                  summary == null
                      ? 'ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â'
                      : '${summary.totalEmployees}',
                ),
                _summaryRow(
                  context,
                  'Skipped',
                  summary == null
                      ? 'ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â'
                      : '${summary.skipped}',
                ),
                _summaryRow(
                  context,
                  'Distance',
                  summary == null || summary.distanceKm <= 0
                      ? 'ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â'
                      : '${summary.distanceKm.toStringAsFixed(1)} km',
                ),
                _summaryRow(
                  context,
                  'Trip Duration',
                  summary == null
                      ? 'ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â'
                      : _humaniseDuration(summary.tripDurationSeconds),
                ),
                _summaryRow(
                  context,
                  'Driving Time',
                  summary == null || summary.drivingSeconds <= 0
                      ? 'ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â'
                      : _humaniseDuration(summary.drivingSeconds),
                ),
                _summaryRow(
                  context,
                  'Waiting Time',
                  summary == null || summary.waitingSeconds <= 0
                      ? 'ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â'
                      : _humaniseDuration(summary.waitingSeconds),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        child: const Text('Not Yet'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        icon: const Icon(Icons.task_alt),
                        label: const Text('Complete Trip'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _summaryRow(BuildContext context, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

String _humaniseDuration(int totalSeconds) {
  if (totalSeconds <= 0) return '0m';
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  if (hours <= 0) return '${minutes}m';
  return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
}

Future<bool> _showStartTripSheet(
  BuildContext context,
  CabDriverOperations data,
) async {
  await Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => DriverPassengerSelectionScreen(data: data),
    ),
  );
  return true;
}

String _duration(Duration duration) =>
    '${duration.inHours}h ${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}m';

String _greeting(DateTime now) => now.hour < 12
    ? 'Good Morning'
    : now.hour < 17
    ? 'Good Afternoon'
    : 'Good Evening';

class _DriverHome extends StatelessWidget {
  final CabDriverOperations data;
  final bool busy;
  final Future<void> Function(
    Future<void> Function(CabDriverOperations data),
    CabDriverOperations data,
  )
  onAction;
  final Future<void> Function(CabDriverOperations data) onStartDuty;
  final Future<void> Function() onRetry;

  const _DriverHome({
    required this.data,
    required this.busy,
    required this.onAction,
    required this.onStartDuty,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OfficeRoute OS'),
        leading: const Icon(Icons.menu),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.wifi, size: 20),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: onRetry,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (!data.dutyActive)
              _buildOffDutyHome(context)
            else if (data.activeTrip != null)
              _buildTripActiveHome(context)
            else
              _buildOnDutyHome(context),
          ],
        ),
      ),
    );
  }

  /// Screen 01 ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Driver Home Off Duty (Stitch PNG 01 reference).
  Widget _buildOffDutyHome(BuildContext context) {
    final now = DateTime.now();
    final driverName = data.driver.name.trim().isNotEmpty
        ? data.driver.name
        : 'Driver';
    final driverCode = data.driver.uid.trim().isNotEmpty
        ? 'ID: ${data.driver.uid.substring(0, data.driver.uid.length.clamp(0, 8))}'
        : 'ID: DRV-001';
    final vehicleReg =
        data.vehicle?.registrationNumber.trim().isNotEmpty == true
        ? data.vehicle!.registrationNumber
        : (data.vehicle?.vehicleNumber.trim().isNotEmpty == true
              ? data.vehicle!.vehicleNumber
              : 'Cab Not Assigned');
    final batteryText = data.shift?.batteryPercentage != null
        ? 'ÃƒÂ¢Ã…Â¡Ã‚Â¡ ${data.shift!.batteryPercentage}%'
        : (data.vehicle != null ? 'Electric Cab' : 'Cab Inactive');
    final driverLoc = data.locations[data.driver.uid];
    final locText = driverLoc != null
        ? 'Lat: ${driverLoc.latitude.toStringAsFixed(3)}, Lng: ${driverLoc.longitude.toStringAsFixed(3)}'
        : 'Location unavailable';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_greeting(now)}, $driverName',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    driverCode,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  const PremiumStatusChip(
                    label: 'OFF DUTY',
                    color: AppColors.textDisabled,
                  ),
                ],
              ),
              const CircleAvatar(
                radius: 28,
                child: Icon(Icons.person, size: 32),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PremiumCard(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.electric_car, color: AppColors.success),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicleReg,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      batteryText,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'NEXT ASSIGNMENT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    data.todayAssignment != null
                        ? 'Active Route'
                        : 'No active route',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.radio_button_unchecked,
                    size: 16,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pickup Hub: ${data.todayAssignment?.officeName ?? 'Not assigned'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(left: 7),
                child: SizedBox(
                  height: 14,
                  child: VerticalDivider(width: 1, thickness: 1.5),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.circle, size: 16, color: AppColors.success),
                  const SizedBox(width: 8),
                  Text(
                    'Drop Point: ${data.todayAssignment?.officeAddress.isNotEmpty == true ? data.todayAssignment!.officeAddress : 'Office'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.groups_outlined, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${data.todayAssignment?.employeeIds.length ?? 0} Employees',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Assignment available after Start Duty',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Current Location',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                locText,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: busy ? null : () => onStartDuty(data),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text(
                    'START DUTY',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Screen 02 ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Driver Home On Duty / Pickups Available (Stitch PNG 02 & PNG 08 semantics).
  Widget _buildOnDutyHome(BuildContext context) {
    final driverName = data.driver.name.trim().isNotEmpty
        ? data.driver.name
        : 'Driver';
    final driverCode = data.driver.uid.trim().isNotEmpty
        ? 'ID: ${data.driver.uid.substring(0, data.driver.uid.length.clamp(0, 8))}'
        : 'ID: DRV-001';
    final vehicleReg =
        data.vehicle?.registrationNumber.trim().isNotEmpty == true
        ? data.vehicle!.registrationNumber
        : (data.vehicle?.vehicleNumber.trim().isNotEmpty == true
              ? data.vehicle!.vehicleNumber
              : 'Cab Active');
    final batteryText = data.shift?.batteryPercentage != null
        ? 'ÃƒÂ¢Ã…Â¡Ã‚Â¡ ${data.shift!.batteryPercentage}%'
        : 'GPS Active';
    final employeeCount = data.openRequestsError != null
        ? '-'
        : '${data.eligibleEmployees.length}';
    final invitedCount =
        '${data.invitations.where((item) => item.invitationStatus != 'cancelled').length}';
    final acceptedCount =
        '${data.invitations.where((item) => item.invitationStatus == 'accepted' || item.invitationStatus == 'trip_active').length}';
    final pendingCount =
        '${data.invitations.where((item) => item.invitationStatus == 'invited').length}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WELCOME BACK,',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Driver $driverName',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    driverCode,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const PremiumStatusChip(
                label: 'ON DUTY',
                color: AppColors.success,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PremiumCard(
          child: Row(
            children: [
              const Icon(Icons.electric_car, color: AppColors.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$vehicleReg ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¢ $batteryText',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Office: ${data.officeDestination?.name ?? 'Not configured'}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Started: ${data.shift?.shiftStart == null ? 'Unavailable' : MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(data.shift!.shiftStart!))}'),
              const SizedBox(height: 4),
              const Text('Trip not started', key: Key('driver_pretrip_status')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 2x2 KPI Cards
        Row(
          children: [
            _kpiCard(
              context,
              'EMPLOYEES',
              employeeCount,
              AppColors.info,
              Icons.people_outline,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DriverPassengerRosterScreen(
                    data: data,
                    initialFilter: 'All',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _kpiCard(
              context,
              'INVITED',
              invitedCount,
              AppColors.success,
              Icons.check_circle_outline,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DriverPassengerRosterScreen(
                    data: data,
                    initialFilter: 'Ready',
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _kpiCard(
              context,
              'ACCEPTED',
              acceptedCount,
              AppColors.warning,
              Icons.how_to_reg_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DriverPassengerRosterScreen(
                    data: data,
                    initialFilter: 'Accepted',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _kpiCard(
              context,
              'PENDING',
              pendingCount,
              AppColors.textDisabled,
              Icons.task_alt,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DriverPassengerRosterScreen(
                    data: data,
                    initialFilter: 'Pending',
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (data.openRequestsError == null && data.eligibleEmployees.isNotEmpty) ...[
          _DriverEmployeeTransportSection(data: data, busy: busy),
          const SizedBox(height: 12),
        ],
        if (data.openRequestsError != null) ...[
          // Truthful Security/Rules notice per prompt
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_outline, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        data.openRequestsError!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Retry'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.headset_mic_outlined, size: 16),
                        label: const Text('Contact Operations'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else if (data.eligibleEmployees.isEmpty) ...[
          // Screen 08 semantics: No Pickup Requests Available
          PremiumCard(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.info.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.radar,
                    size: 40,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No eligible Employees',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                const Text(
                  "No eligible Employees found for this branch or service centre.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Expanded(
                      child: _InfoTile(
                        label: 'Queue position',
                        value: 'Unavailable',
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _InfoTile(
                        label: 'Estimated wait',
                        value: 'Unavailable',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.headset_mic_outlined, size: 16),
                        label: const Text('Contact Operations'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Retry'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Employee Transport (${data.eligibleEmployees.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DriverPassengerSelectionScreen(data: data),
                      ),
                    ),
                    icon: const Icon(Icons.group_add_outlined),
                    label: const Text('SELECT EMPLOYEES / SEND INVITATION'),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _Actions(
          data: data,
          busy: busy,
          onAction: onAction,
          onStartTripSheet: _showStartTripSheet,
          onStartDuty: onStartDuty,
        ),
      ],
    );
  }

  /// Screen 03 ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Driver Home Trip Active (Stitch PNG 03 reference).
  Widget _buildTripActiveHome(BuildContext context) {
    final rider = data.activeRider;
    final riderName = rider != null
        ? (data.employees[rider.employeeId]?.name.trim().isNotEmpty == true
              ? data.employees[rider.employeeId]!.name
              : rider.employeeId)
        : 'Employee';
    final riderRole = rider != null
        ? (data.employees[rider.employeeId]?.role.trim().isNotEmpty == true
              ? data.employees[rider.employeeId]!.role
              : 'Employee')
        : 'Employee';
    final vehicleReg =
        data.vehicle?.registrationNumber.trim().isNotEmpty == true
        ? data.vehicle!.registrationNumber
        : (data.vehicle?.vehicleNumber.trim().isNotEmpty == true
              ? data.vehicle!.vehicleNumber
              : 'Cab Active');
    final durationText = data.activeTrip?.createdAt != null
        ? _duration(DateTime.now().difference(data.activeTrip!.createdAt!))
        : _duration(data.dutyDuration);

    final completedCount = data.riders
        .where((r) => r.status == 'picked_up' || r.status == 'completed')
        .length;
    final riderCountChip =
        '${completedCount + (rider != null ? 1 : 0)}/${data.riders.length}';
    final distText = data.distanceToActiveRiderMeters != null
        ? 'Distance: ${(data.distanceToActiveRiderMeters! / 1000).toStringAsFixed(1)}km'
        : 'Distance: Location unavailable';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ELAPSED TIME',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    durationText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'VEHICLE',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    vehicleReg,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const PremiumStatusChip(
                label: 'TRIP LIVE',
                color: AppColors.success,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(radius: 22, child: Icon(Icons.person)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                riderName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            PremiumStatusChip(
                              label: riderCountChip,
                              color: AppColors.info,
                            ),
                            const SizedBox(width: 4),
                            PremiumStatusChip(
                              label: rider?.status.toUpperCase() ?? 'ACTIVE',
                              color: AppColors.success,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          riderRole,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.phone)),
                ],
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.location_on, size: 18, color: AppColors.info),
                  SizedBox(width: 6),
                  Text(
                    'Active Pickup Point',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Text(
                  distText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Dynamic KPI Row
        Row(
          children: [
            _kpiCard(
              context,
              'TOTAL',
              '${data.riders.length}',
              AppColors.info,
              Icons.groups,
            ),
            const SizedBox(width: 8),
            _kpiCard(
              context,
              'READY',
              '${data.riders.where((r) => r.status == 'ready').length}',
              AppColors.success,
              Icons.check_circle_outline,
            ),
            const SizedBox(width: 8),
            _kpiCard(
              context,
              'PICK',
              '${data.riders.where((r) => r.status == 'picked_up' || r.status == 'completed').length}',
              AppColors.warning,
              Icons.how_to_reg,
            ),
            const SizedBox(width: 8),
            _kpiCard(
              context,
              'REM',
              '${data.riders.where((r) => r.status != 'picked_up' && r.status != 'completed' && r.status != 'skipped').length}',
              AppColors.textDisabled,
              Icons.pending,
            ),
          ],
        ),
        const SizedBox(height: 12),
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TRIP LOG',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              const _TripLogEntry(
                title: 'Duty Started',
                time: '08:00 AM',
                ok: true,
              ),
              const _TripLogEntry(
                title: 'Trip Started',
                time: '08:15 AM',
                ok: true,
              ),
              _TripLogEntry(
                title: riderName,
                time: 'ACTIVE PICKUP',
                active: true,
              ),
              const _TripLogEntry(title: 'Next Pickups', time: 'Pending Route'),
              const _TripLogEntry(
                title: 'Corporate Office',
                time: 'Destination',
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CabDriverOperationalFlow(data: data),
              ),
            ),
            icon: const Icon(Icons.navigation_outlined),
            label: const Text(
              'NAVIGATE TO PICKUP',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _kpiCard(
    BuildContext context,
    String label,
    String value,
    Color color,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverEmployeeTransportSection extends StatefulWidget {
  const _DriverEmployeeTransportSection({required this.data, required this.busy});
  final CabDriverOperations data;
  final bool busy;

  @override
  State<_DriverEmployeeTransportSection> createState() =>
      _DriverEmployeeTransportSectionState();
}

class _DriverEmployeeTransportSectionState
    extends State<_DriverEmployeeTransportSection> {
  final Set<String> _selected = <String>{};
  bool _sending = false;

  Map<String, CabAssignmentMemberModel> get _invitationByEmployee => {
    for (final item in widget.data.invitations) item.userId: item,
  };

  Set<String> get _selectable => widget.data.eligibleEmployees
      .where((employee) {
        final invitation = _invitationByEmployee[employee.uid];
        return invitation == null || invitation.invitationStatus == 'cancelled';
      })
      .map((employee) => employee.uid)
      .toSet();

  @override
  void didUpdateWidget(covariant _DriverEmployeeTransportSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selected.removeWhere((id) => !_selectable.contains(id));
  }

  Future<void> _send() async {
    if (_sending || _selected.isEmpty) return;
    setState(() => _sending = true);
    try {
      await CabDriverController.sendTransportInvitations(
        widget.data,
        _selected.toList(growable: false),
      );
      if (!mounted) return;
      setState(_selected.clear);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transport invitations sent.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitation failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invitations = _invitationByEmployee;
    final selectable = _selectable;
    return PremiumCard(
      key: const Key('driver_employee_transport_section'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('EMPLOYEE TRANSPORT',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: .8)),
          const SizedBox(height: 8),
          Row(children: [
            TextButton(
              onPressed: selectable.isEmpty ? null : () => setState(() {
                _selected..clear()..addAll(selectable);
              }),
              child: const Text('Select All'),
            ),
            TextButton(
              onPressed: _selected.isEmpty ? null : () => setState(_selected.clear),
              child: const Text('Clear'),
            ),
            const Spacer(),
            Text('Selected ${_selected.length}'),
          ]),
          for (final employee in widget.data.eligibleEmployees)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              enabled: selectable.contains(employee.uid),
              value: _selected.contains(employee.uid),
              onChanged: (checked) => setState(() {
                checked == true
                    ? _selected.add(employee.uid)
                    : _selected.remove(employee.uid);
              }),
              title: Text(employee.name.trim().isEmpty ? employee.uid : employee.name),
              subtitle: Text(
                '${employee.employeeCode.trim().isEmpty ? 'Employee code unavailable' : employee.employeeCode} | '
                '${employee.branch.trim().isNotEmpty ? employee.branch : employee.serviceCentre}\n'
                '${employee.preferredPickupAddress.trim().isEmpty ? 'Pickup required' : 'Pickup configured'} | '
                '${(invitations[employee.uid]?.invitationStatus ?? 'not invited').replaceAll('_', ' ')}',
              ),
              isThreeLine: true,
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('driver_send_invitation_button'),
              onPressed: widget.busy || _sending || _selected.isEmpty ? null : _send,
              icon: const Icon(Icons.send_outlined),
              label: Text(_sending ? 'SENDING...' : 'SEND INVITATION'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripLogEntry extends StatelessWidget {
  final String title;
  final String time;
  final bool ok;
  final bool active;
  final bool isLast;

  const _TripLogEntry({
    required this.title,
    required this.time,
    this.ok = false,
    this.active = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = ok
        ? AppColors.success
        : (active ? AppColors.info : AppColors.textDisabled);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(
              active ? Icons.radio_button_checked : Icons.circle,
              size: 14,
              color: dotColor,
            ),
            if (!isLast)
              Container(
                width: 1.5,
                height: 24,
                color: Theme.of(context).dividerColor,
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  final CabDriverOperations data;
  final bool busy;
  final Future<void> Function(
    Future<void> Function(CabDriverOperations),
    CabDriverOperations,
  )
  onAction;
  final Future<bool> Function(BuildContext, CabDriverOperations)
  onStartTripSheet;
  final Future<void> Function(CabDriverOperations) onStartDuty;

  const _Actions({
    required this.data,
    required this.busy,
    required this.onAction,
    required this.onStartTripSheet,
    required this.onStartDuty,
  });

  @override
  Widget build(BuildContext context) {
    final trip = data.activeTrip;
    final state = data.workflowState;
    return PremiumCard(
      child: Wrap(
        spacing: 9,
        runSpacing: 9,
        children: [
          if (state == CabDriverWorkflowState.offDuty)
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      await onStartDuty(data);
                    },
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Start Duty'),
            ),
          if (state == CabDriverWorkflowState.onDuty ||
              (state == CabDriverWorkflowState.tripCompleted && trip == null))
            _button(
              'End Duty',
              Icons.stop_circle_outlined,
              trip == null,
              CabDriverWorkflowSupport.endDuty,
              color: AppColors.error,
            ),
          if (state == CabDriverWorkflowState.onDuty) ...[
            _startTripButton(context, data),
            if (CabDriverController.startTripBlockedReason(data) case final reason?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(reason, key: const Key('driver_start_trip_reason'),
                    style: const TextStyle(color: AppColors.textSecondary)),
              ),
          ],
          if (state == CabDriverWorkflowState.onDuty &&
              !data.hasValidOfficeDestination)
            const Text(
              "Today's office destination is not configured",
              key: Key('driver_office_destination_missing'),
              style: TextStyle(color: AppColors.error),
            ),
          if (state == CabDriverWorkflowState.tripReady)
            _button(
              'Resume Trip',
              Icons.play_arrow,
              true,
              CabDriverWorkflowSupport.startOrResumeTrip,
            ),
          if (state == CabDriverWorkflowState.travellingToPickup)
            _button(
              'Reached Pickup',
              Icons.pin_drop_outlined,
              true,
              CabDriverController.reachedPickup,
            ),
          if (state == CabDriverWorkflowState.waitingAtPickup)
            _button(
              'Picked Up',
              Icons.person_add_alt_1,
              true,
              CabDriverController.pickedUp,
            ),
          if (state == CabDriverWorkflowState.waitingAtPickup)
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final reason = await _showSkipReasonDialog(context, data);
                      if (reason == null || !context.mounted) return;
                      await onAction(
                        (current) => CabDriverWorkflowSupport.skipRider(
                          current,
                          reason: reason,
                        ),
                        data,
                      );
                    },
              icon: const Icon(Icons.skip_next_outlined),
              label: const Text('Skip'),
            ),
          if (state == CabDriverWorkflowState.travellingToOffice)
            _button(
              'Reached Office',
              Icons.flag_outlined,
              true,
              CabDriverWorkflowSupport.reachedDestination,
            ),
          if (trip != null && const {'created', 'active'}.contains(trip.status))
            OutlinedButton.icon(
              key: const Key('driver_cancel_trip_button'),
              onPressed: busy
                  ? null
                  : () async {
                      final cancellation = await _showTripCancellationDialog(
                        context,
                      );
                      if (cancellation == null || !context.mounted) return;
                      await onAction(
                        (current) => CabDriverWorkflowSupport.cancelTrip(
                          current,
                          cancellation,
                        ),
                        data,
                      );
                    },
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel Trip'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
            ),
          if (state == CabDriverWorkflowState.tripCompleted && trip != null)
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final confirmed = await _showTripSummarySheet(
                        context,
                        data,
                      );
                      if (confirmed != true || !context.mounted) return;
                      await onAction(
                        CabDriverWorkflowSupport.completeTrip,
                        data,
                      );
                    },
              icon: const Icon(Icons.task_alt),
              label: const Text('Review & Complete Trip'),
            ),
        ],
      ),
    );
  }

  Widget _startTripButton(BuildContext context, CabDriverOperations data) {
    final canStart = CabDriverController.canStartTrip(data);
    return FilledButton.icon(
      key: const Key('driver_start_trip_button'),
      onPressed: busy || !canStart
          ? null
          : () async {
              final started = await onStartTripSheet(context, data);
              if (started) {
                await onAction((_) async {}, data);
              }
            },
      icon: const Icon(Icons.route_outlined),
      label: const Text('Start Trip'),
    );
  }

  Widget _button(
    String label,
    IconData icon,
    bool enabled,
    Future<void> Function(CabDriverOperations) action, {
    Color? color,
  }) {
    return FilledButton.icon(
      onPressed: enabled && !busy ? () => onAction(action, data) : null,
      icon: Icon(icon),
      label: Text(label),
      style: color == null
          ? null
          : FilledButton.styleFrom(backgroundColor: color),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Screen 09 ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Assignment Details / Pickup Plan Details (Stitch PNG 09 reference).
class DriverPickupPlanDetailsScreen extends StatelessWidget {
  final CabDriverOperations data;

  const DriverPickupPlanDetailsScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final driverName = data.driver.name.trim().isNotEmpty
        ? data.driver.name
        : 'Driver name unavailable';
    final driverCode = data.driver.employeeCode.trim().isNotEmpty
        ? data.driver.employeeCode
        : 'Driver ID unavailable';
    final vehicleReg =
        data.vehicle?.registrationNumber.trim().isNotEmpty == true
        ? data.vehicle!.registrationNumber
        : 'Vehicle registration unavailable';
    final vehicleModel = data.vehicle?.vehicleModel.trim().isNotEmpty == true
        ? data.vehicle!.vehicleModel
        : 'Vehicle model unavailable';
    final destination = data.officeDestination;
    final shiftStart = data.shift?.shiftStart;
    final shiftTime = shiftStart == null
        ? 'Unavailable'
        : MaterialLocalizations.of(
            context,
          ).formatTimeOfDay(TimeOfDay.fromDateTime(shiftStart));
    final manifest = data.openRequests.isNotEmpty
        ? data.openRequests
        : data.members;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pickup Plan Details'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: PremiumStatusChip(
              label: 'CONFIRMED',
              color: AppColors.success,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            data.todayAssignment?.id.trim().isNotEmpty == true
                ? 'ROUTE ID: ${data.todayAssignment!.id}'
                : 'ROUTE ID: Not created',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SHIFT TIME',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      shiftTime,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'DESTINATION',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      destination?.name ??
                          'Office destination is not configured',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PremiumCard(
            child: Row(
              children: [
                const CircleAvatar(radius: 22, child: Icon(Icons.person)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ASSIGNED DRIVER',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        driverName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        driverCode,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PremiumCard(
            child: Row(
              children: [
                const Icon(Icons.directions_car, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'VEHICLE ASSIGNED',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        vehicleModel,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        vehicleReg,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const PremiumCard(
            child: Row(
              children: [
                Icon(Icons.map, color: AppColors.info),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Total distance unavailable',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Manifest (${manifest.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Text(
                'Pickup Window: 07:15 - 07:45',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...manifest.map((member) {
            final empName =
                data.employees[member.userId]?.name ??
                (member.userId.isNotEmpty ? member.userId : 'Passenger');
            final pickupLabel = member.pickupAddress.isNotEmpty
                ? member.pickupAddress
                : (member.pickupName.isNotEmpty
                      ? member.pickupName
                      : 'Pickup Point');
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    empName.isNotEmpty ? empName[0].toUpperCase() : 'P',
                  ),
                ),
                title: Text(
                  empName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  pickupLabel,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.phone),
                  onPressed: () {},
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          const PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.notes, size: 18, color: AppColors.warning),
                    SizedBox(width: 6),
                    Text(
                      'OPERATIONAL NOTES',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'Construction ongoing near Keshwapur Gate. Alternate entry via Hosur Road recommended. Ensure AC is set to 22Ãƒâ€šÃ‚Â°C before first pickup.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.navigation),
              label: const Text(
                'START ROUTE NAVIGATION',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen 10 - Driver invitation response roster.
class DriverPassengerRosterScreen extends StatefulWidget {
  final CabDriverOperations data;
  final String initialFilter;
  const DriverPassengerRosterScreen({
    super.key,
    required this.data,
    this.initialFilter = 'All',
  });

  @override
  State<DriverPassengerRosterScreen> createState() =>
      _DriverPassengerRosterScreenState();
}

class _DriverPassengerRosterScreenState
    extends State<DriverPassengerRosterScreen> {
  late String _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final invitations = widget.data.invitations
        .where((item) {
          if (_filter == 'Accepted') {
            return item.invitationStatus == 'accepted' ||
                item.invitationStatus == 'trip_active';
          }
          if (_filter == 'Pending') return item.invitationStatus == 'invited';
          if (_filter == 'Declined') return item.invitationStatus == 'declined';
          if (_filter == 'Picked Up') {
            return item.status == 'picked_up' || item.status == 'completed';
          }
          return true;
        })
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: Text('Invitation Roster (${invitations.length})')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                for (final value in const [
                  'All',
                  'Accepted',
                  'Pending',
                  'Declined',
                  'Picked Up',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(value),
                      selected: _filter == value,
                      onSelected: (_) => setState(() => _filter = value),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: invitations.isEmpty
                ? const Center(child: Text('No matching invitations.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: invitations.length,
                    itemBuilder: (context, index) {
                      final invitation = invitations[index];
                      final employee = widget.data.employees[invitation.userId];
                      final name = employee?.name.trim().isNotEmpty == true
                          ? employee!.name.trim()
                          : invitation.userId;
                      final pickup = invitation.pickupAddress.trim().isEmpty
                          ? 'Pickup location required'
                          : invitation.pickupAddress.trim();
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(name.isEmpty ? 'E' : name[0]),
                          ),
                          title: Text(name),
                          subtitle: Text(pickup),
                          trailing: PremiumStatusChip(
                            label: invitation.invitationStatus
                                .replaceAll('_', ' ')
                                .toUpperCase(),
                            color: invitation.invitationStatus == 'accepted'
                                ? AppColors.success
                                : invitation.invitationStatus == 'declined'
                                ? AppColors.error
                                : AppColors.warning,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Screen 11 - real active vehicle details.
class DriverVehicleDetailsScreen extends StatelessWidget {
  final CabDriverOperations data;
  const DriverVehicleDetailsScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final vehicle = data.vehicle;
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Details')),
      body: vehicle == null
          ? const Center(child: Text('No configured cab available'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PremiumCard(
                  child: Column(
                    children: [
                      const Icon(Icons.electric_car, size: 52),
                      const SizedBox(height: 8),
                      Text(
                        vehicle.vehicleNumber.isEmpty
                            ? vehicle.id
                            : vehicle.vehicleNumber,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(vehicle.registrationNumber),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                PremiumCard(
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Model'),
                        trailing: Text(
                          vehicle.vehicleModel.isEmpty
                              ? 'Unavailable'
                              : vehicle.vehicleModel,
                        ),
                      ),
                      ListTile(
                        title: const Text('Capacity'),
                        trailing: Text(
                          vehicle.capacity <= 0
                              ? 'Unavailable'
                              : '${vehicle.capacity}',
                        ),
                      ),
                      ListTile(
                        title: const Text('Status'),
                        trailing: Text(vehicle.status),
                      ),
                      ListTile(
                        title: const Text('Battery / Fuel'),
                        trailing: Text(
                          data.shift == null
                              ? 'Unavailable'
                              : '${data.shift!.batteryPercentage}%',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Screen 12 - Driver Employee invitation selection.
class DriverPassengerSelectionScreen extends StatefulWidget {
  final CabDriverOperations data;
  const DriverPassengerSelectionScreen({super.key, required this.data});

  @override
  State<DriverPassengerSelectionScreen> createState() =>
      _DriverPassengerSelectionScreenState();
}

class _DriverPassengerSelectionScreenState
    extends State<DriverPassengerSelectionScreen> {
  final Set<String> _selected = {};
  bool _sending = false;

  Future<void> _send() async {
    if (_sending || _selected.isEmpty) return;
    setState(() => _sending = true);
    try {
      await CabDriverController.sendTransportInvitations(
        widget.data,
        _selected.toList(growable: false),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transport invitations sent.')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invitation failed: $error')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invitationByEmployee = {
      for (final item in widget.data.invitations) item.userId: item,
    };
    final selectable = widget.data.eligibleEmployees
        .where((employee) {
          final current = invitationByEmployee[employee.uid];
          return current == null || current.invitationStatus == 'cancelled';
        })
        .map((employee) => employee.uid)
        .toSet();
    final accepted = widget.data.invitations
        .where(
          (item) =>
              item.invitationStatus == 'accepted' &&
              item.pickupLatitude != null &&
              item.pickupLongitude != null,
        )
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Employee Transport Directory')),
      body: Column(
        children: [
          Row(
            children: [
              TextButton(
                onPressed: selectable.isEmpty
                    ? null
                    : () => setState(() {
                        _selected
                          ..clear()
                          ..addAll(selectable);
                      }),
                child: const Text('Select All'),
              ),
              TextButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () => setState(_selected.clear),
                child: const Text('Clear'),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text('${_selected.length} selected'),
              ),
            ],
          ),
          Expanded(
            child: widget.data.eligibleEmployees.isEmpty
                ? const Center(child: Text('No eligible Employees.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: widget.data.eligibleEmployees.length,
                    itemBuilder: (context, index) {
                      final employee = widget.data.eligibleEmployees[index];
                      final invitation = invitationByEmployee[employee.uid];
                      final status =
                          invitation?.invitationStatus ?? 'not_invited';
                      final canSelect = selectable.contains(employee.uid);
                      final pickupConfigured =
                          employee.preferredPickupAddress.trim().isNotEmpty &&
                          employee.preferredPickupLatitude != null &&
                          employee.preferredPickupLongitude != null;
                      return Card(
                        child: CheckboxListTile(
                          enabled: canSelect,
                          value: _selected.contains(employee.uid),
                          onChanged: (value) => setState(() {
                            if (value == true) {
                              _selected.add(employee.uid);
                            } else {
                              _selected.remove(employee.uid);
                            }
                          }),
                          title: Text(
                            employee.name.trim().isEmpty
                                ? employee.uid
                                : employee.name.trim(),
                          ),
                          subtitle: Text(
                            '${pickupConfigured ? 'Pickup configured' : 'Pickup location required'} | '
                            '${status.replaceAll('_', ' ').toUpperCase()}',
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _sending || _selected.isEmpty ? null : _send,
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('SEND TRANSPORT INVITATION'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          accepted.isEmpty ||
                              !CabDriverController.canStartTrip(widget.data)
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DriverStartTripConfirmationScreen(
                                      data: widget.data,
                                      selectedMemberIds: accepted
                                          .map((item) => item.id)
                                          .toSet(),
                                      onEditSelection: () =>
                                          Navigator.pop(context),
                                    ),
                              ),
                            ),
                      icon: const Icon(Icons.route_outlined),
                      label: Text(
                        accepted.isEmpty
                            ? 'NO ACCEPTED EMPLOYEES'
                            : 'REVIEW ${accepted.length} ACCEPTED / START TRIP',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen 13 ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Start Trip Confirmation (Stitch PNG 13 reference).
class DriverStartTripConfirmationScreen extends StatefulWidget {
  final CabDriverOperations data;
  final Set<String> selectedMemberIds;
  final VoidCallback onEditSelection;

  const DriverStartTripConfirmationScreen({
    super.key,
    required this.data,
    required this.selectedMemberIds,
    required this.onEditSelection,
  });

  @override
  State<DriverStartTripConfirmationScreen> createState() =>
      _DriverStartTripConfirmationScreenState();
}

class _DriverStartTripConfirmationScreenState
    extends State<DriverStartTripConfirmationScreen> {
  bool _submitting = false;

  Future<void> _handleStartTripNow() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final vehicleId = widget.data.vehicle?.id.trim() ?? '';
      final destination = widget.data.officeDestination;
      if (!CabDriverController.canStartTrip(widget.data) ||
          vehicleId.isEmpty ||
          destination == null ||
          widget.selectedMemberIds.isEmpty) {
        throw StateError(
          'Trip conditions changed. Refresh accepted invitations.',
        );
      }

      await CabDriverWorkflowSupport.claimReadyRequestsAndStartTrip(
        widget.data,
        memberIds: widget.selectedMemberIds.toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip started with accepted Employees.')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start trip: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.data.invitations;
    final totalCount = list.length;
    final selectedCount = widget.selectedMemberIds.length;
    final destination = widget.data.officeDestination;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Officeroute OS'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: PremiumStatusChip(label: 'LIVE', color: AppColors.success),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: const [
              Expanded(
                child: PremiumCard(
                  child: Row(
                    children: [
                      Icon(Icons.public, color: AppColors.success),
                      SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NETWORK',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            'Connected',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: PremiumCard(
                  child: Row(
                    children: [
                      Icon(Icons.location_searching, color: AppColors.success),
                      SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GPS SIGNAL',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            'Connected',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Trip Summary',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    PremiumStatusChip(
                      label: '$selectedCount READY',
                      color: AppColors.info,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Verify details before departure',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.business, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DESTINATION',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              destination?.name ??
                                  'Office destination is not configured',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (destination != null)
                              Text(
                                destination.address,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.groups, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'OCCUPANCY',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '$selectedCount of $totalCount Employees selected',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const CircleAvatar(
                        radius: 12,
                        child: Icon(Icons.person, size: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.info),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_user_outlined, color: AppColors.info),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Starting claims only the selected READY requests.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.info,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _submitting || destination == null
                  ? null
                  : _handleStartTripNow,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(
                _submitting ? 'STARTING TRIP...' : 'START TRIP NOW',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _submitting ? null : widget.onEditSelection,
              icon: const Icon(Icons.edit),
              label: const Text('EDIT SELECTION'),
            ),
          ),
        ],
      ),
    );
  }
}
