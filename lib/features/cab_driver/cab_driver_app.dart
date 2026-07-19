import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/cab_assignment_model.dart';
import '../../core/models/cab_trip_event_model.dart';
import '../../core/models/cab_trip_model.dart';
import '../../core/models/cab_trip_rider_model.dart';
import '../../core/models/cab_vehicle_model.dart';
import '../../core/models/live_location_model.dart';
import '../../core/models/user_model.dart';
import '../../core/controllers/cab_management_controller.dart';
import '../../core/models/employee_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/location_tracking_policy.dart';
import '../../core/services/employee_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/premium_widgets.dart';
import '../attendance/services/attendance_service.dart';
import '../auth/services/auth_service.dart';
import '../map/map_screen.dart';
import '../notifications/notification_center_screen.dart';
import 'controllers/cab_driver_controller.dart';
import 'cab_driver_workflow_support.dart';
import 'widgets/driver_start_duty_overlay.dart';

class CabDriverApp extends StatefulWidget {
  const CabDriverApp({super.key});

  @override
  State<CabDriverApp> createState() => _CabDriverAppState();
}

class _CabDriverAppState extends State<CabDriverApp> {
  late Future<CabDriverOperations> _future;
  final List<StreamSubscription<void>> _subscriptions = [];
  Timer? _debounce;
  Timer? _clock;
  int _index = 0;
  bool _busy = false;
  int _startDutyStep = -1;
  String? _startDutyError;

  @override
  void initState() {
    super.initState();
    _future = CabDriverController.load();
    for (final stream in CabDriverController.realtimeStreams()) {
      _subscriptions.add(stream.listen((_) => _scheduleReload()));
    }
    _clock = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _scheduleReload(),
    );
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

  void _reload() {
    if (!mounted) return;
    setState(() => _future = CabDriverController.load());
  }

  Future<void> _action(
    Future<void> Function(CabDriverOperations data) action,
    CabDriverOperations data,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action(data);
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Drives the Start Duty overlay. Advances [_startDutyStep] as each phase
  /// completes; on failure, holds on the failing step with an error message.
  Future<void> _handleStartDuty(CabDriverOperations data) async {
    setState(() {
      _startDutyStep = 0;
      _startDutyError = null;
    });
    try {
      var resolved = await CabDriverWorkflowSupport.resolveDriverVehicle(data);
      if (resolved == null) {
        if (!mounted) return;
        resolved = await _showVehicleSelectionSheet(context, data);
        if (resolved == null) {
          setState(() => _startDutyStep = -1);
          return;
        }
      }
      setState(() => _startDutyStep = 1);
      // The controller itself advances through permission, attendance and
      // location session steps. We tick the overlay optimistically because
      // startDuty either completes end-to-end or throws; on throw we hold at
      // whichever step failed so the driver can retry.
      setState(() => _startDutyStep = 2);
      final vehicleId = resolved.id;
      await _action(
        (current) =>
            CabDriverWorkflowSupport.startDuty(current, vehicleId: vehicleId),
        data,
      );
      setState(() {
        _startDutyStep = 4;
      });
      // Give the overlay a moment to show completion.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() => _startDutyStep = -1);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _startDutyError = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CabDriverOperations>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: PremiumLoadingState(label: 'Loading driver operations'),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            body: PremiumErrorState(
              title: 'Driver operations could not be loaded.',
              error: snapshot.error,
              onRetry: _reload,
            ),
          );
        }
        final data = snapshot.data!;
        final pages = [
          _DriverHome(
            data: data,
            busy: _busy,
            onAction: _action,
            onStartDuty: _handleStartDuty,
          ),
          const MapScreen(cabDriverMode: true),
          _DriverTrips(data: data),
          _DriverProfile(data: data),
        ];
        return Scaffold(
          body: Stack(
            children: [
              IndexedStack(index: _index, children: pages),
              if (_startDutyStep >= 0)
                DriverStartDutyOverlay(
                  currentStep: _startDutyStep,
                  errorMessage: _startDutyError,
                  onCancel: () => setState(() {
                    _startDutyStep = -1;
                    _startDutyError = null;
                  }),
                  onRetry: _startDutyError == null
                      ? null
                      : () => setState(() => _startDutyError = null),
                ),
            ],
          ),
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
                label: 'Live Map',
              ),
              NavigationDestination(
                icon: Icon(Icons.route_outlined),
                selectedIcon: Icon(Icons.route),
                label: 'Trips',
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
    );
  }
}

class _PickupCandidate {
  final EmployeeModel employee;
  final LiveLocationModel? location;
  final double? distanceMeters;

  _PickupCandidate({
    required this.employee,
    required this.location,
    required this.distanceMeters,
  });
}

Future<List<_PickupCandidate>> _loadPickupCandidates(
  CabDriverOperations data,
) async {
  final attendanceRecords = await AttendanceService.fetchAttendanceForDate(
    DateTime.now(),
  );
  final activeUserIds = attendanceRecords
      .where((record) => record.isCheckedIn)
      .map((record) => record.userId)
      .toSet();
  final employees = await EmployeeService.fetchAllEmployees();
  final driverLocation = data.locations[data.driver.uid];
  final candidates = employees
      .where(
        (employee) =>
            employee.uid.trim().isNotEmpty &&
            employee.uid != data.driver.uid &&
            activeUserIds.contains(employee.uid),
      )
      .map((employee) {
        final location = data.locations[employee.uid];
        final distance = driverLocation == null || location == null
            ? null
            : LocationTrackingPolicy.distanceMeters(
                driverLocation.latitude,
                driverLocation.longitude,
                location.latitude,
                location.longitude,
              );
        return _PickupCandidate(
          employee: employee,
          location: location,
          distanceMeters: distance,
        );
      })
      .toList();
  candidates.sort((a, b) {
    if (a.distanceMeters == null) return 1;
    if (b.distanceMeters == null) return -1;
    return a.distanceMeters!.compareTo(b.distanceMeters!);
  });
  return candidates;
}

/// Nothing-OS styled bottom sheet for the driver to pick their vehicle before
/// starting duty. Returns the selected [CabVehicleModel] or `null` if the
/// driver cancelled. Only lists non-inactive vehicles from `cab_vehicles`.
Future<CabVehicleModel?> _showVehicleSelectionSheet(
  BuildContext context,
  CabDriverOperations data,
) async {
  return showModalBottomSheet<CabVehicleModel>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return FutureBuilder<List<CabVehicleModel>>(
        future: CabManagementController.loadVehicles(),
        builder: (context, snapshot) {
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
                  'Select Vehicle',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose the cab you will drive today.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('Could not load vehicles: ${snapshot.error}'),
                    ),
                  )
                else
                  _buildVehicleList(context, snapshot.data ?? const [], data),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _buildVehicleList(
  BuildContext context,
  List<CabVehicleModel> vehicles,
  CabDriverOperations data,
) {
  final activeVehicles = vehicles
      .where(
        (vehicle) =>
            vehicle.id.trim().isNotEmpty &&
            vehicle.status.trim().toLowerCase() != 'inactive',
      )
      .toList();
  if (activeVehicles.isEmpty) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text('No vehicles are available. Contact your operations team.'),
      ),
    );
  }
  final preferredId = data.driver.vehicleNumber.trim();
  activeVehicles.sort((a, b) {
    final aPreferred =
        a.id == preferredId ||
        a.vehicleNumber.toLowerCase() == preferredId.toLowerCase();
    final bPreferred =
        b.id == preferredId ||
        b.vehicleNumber.toLowerCase() == preferredId.toLowerCase();
    if (aPreferred && !bPreferred) return -1;
    if (!aPreferred && bPreferred) return 1;
    return a.vehicleNumber.compareTo(b.vehicleNumber);
  });
  return Flexible(
    child: ListView.separated(
      shrinkWrap: true,
      itemCount: activeVehicles.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final vehicle = activeVehicles[index];
        final isPreferred =
            vehicle.id == preferredId ||
            vehicle.vehicleNumber.toLowerCase() == preferredId.toLowerCase();
        return Material(
          color: Theme.of(context).colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isPreferred
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.pop(context, vehicle),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.local_taxi_outlined, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.vehicleNumber.isEmpty
                              ? 'Vehicle ${vehicle.id}'
                              : vehicle.vehicleNumber,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (vehicle.vehicleModel.isNotEmpty)
                              vehicle.vehicleModel,
                            if (vehicle.capacity > 0)
                              'Capacity ${vehicle.capacity}',
                            vehicle.status,
                          ].join(' · '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (isPreferred)
                    const Icon(Icons.check_circle, color: AppColors.success)
                  else
                    const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        );
      },
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
                  summary == null ? '—' : '${summary.completedPickups}',
                ),
                _summaryRow(
                  context,
                  'Total Selected',
                  summary == null ? '—' : '${summary.totalEmployees}',
                ),
                _summaryRow(
                  context,
                  'Skipped',
                  summary == null ? '—' : '${summary.skipped}',
                ),
                _summaryRow(
                  context,
                  'Distance',
                  summary == null || summary.distanceKm <= 0
                      ? '—'
                      : '${summary.distanceKm.toStringAsFixed(1)} km',
                ),
                _summaryRow(
                  context,
                  'Trip Duration',
                  summary == null
                      ? '—'
                      : _humaniseDuration(summary.tripDurationSeconds),
                ),
                _summaryRow(
                  context,
                  'Driving Time',
                  summary == null || summary.drivingSeconds <= 0
                      ? '—'
                      : _humaniseDuration(summary.drivingSeconds),
                ),
                _summaryRow(
                  context,
                  'Waiting Time',
                  summary == null || summary.waitingSeconds <= 0
                      ? '—'
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

Future<void> _showStartTripSheet(
  BuildContext context,
  CabDriverOperations data,
) async {
  final candidates = await _loadPickupCandidates(data);
  if (!context.mounted) return;
  if (candidates.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No eligible employees found for pickup.')),
    );
    return;
  }

  final selected = <String>{};
  var search = '';

  await showModalBottomSheet<void>(
    isScrollControlled: true,
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final filtered = candidates.where((candidate) {
            final query = search.toLowerCase();
            return query.isEmpty ||
                candidate.employee.name.toLowerCase().contains(query) ||
                candidate.employee.email.toLowerCase().contains(query) ||
                candidate.employee.uid.toLowerCase().contains(query);
          }).toList();
          final allSelected =
              filtered.isNotEmpty && selected.length == filtered.length;
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
                  'Start Pickup Trip',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Select employees for today\'s pickup.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search employees',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => search = value),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: filtered.isEmpty
                            ? null
                            : () => setState(() {
                                if (allSelected) {
                                  selected.clear();
                                } else {
                                  selected.addAll(
                                    filtered.map((item) => item.employee.uid),
                                  );
                                }
                              }),
                        child: Text(
                          allSelected ? 'Clear Selection' : 'Select All',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No employee matches your search.'),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final distanceLabel = item.distanceMeters == null
                            ? 'Distance unknown'
                            : '${item.distanceMeters!.round()} m';
                        final orderLabel = item.distanceMeters == null
                            ? 'Order: N/A'
                            : 'Pickup order ${index + 1}';
                        return CheckboxListTile(
                          value: selected.contains(item.employee.uid),
                          onChanged: (value) => setState(() {
                            if (value == true) {
                              selected.add(item.employee.uid);
                            } else {
                              selected.remove(item.employee.uid);
                            }
                          }),
                          title: Text(item.employee.name),
                          subtitle: Text(
                            '${item.employee.uid} · ${item.employee.role} · $distanceLabel · $orderLabel',
                          ),
                          secondary: CircleAvatar(
                            backgroundImage:
                                item.employee.profileImage.isNotEmpty
                                ? NetworkImage(item.employee.profileImage)
                                : null,
                            child: item.employee.profileImage.isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: selected.isEmpty
                            ? null
                            : () async {
                                Navigator.of(context).pop();
                                await CabDriverWorkflowSupport.startTripWithEmployees(
                                  data,
                                  selected.toList(),
                                );
                              },
                        child: const Text('Start Trip'),
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

class _DriverHome extends StatelessWidget {
  final CabDriverOperations data;
  final bool busy;
  final Future<void> Function(
    Future<void> Function(CabDriverOperations data),
    CabDriverOperations data,
  )
  onAction;
  final Future<void> Function(CabDriverOperations data) onStartDuty;

  const _DriverHome({
    required this.data,
    required this.busy,
    required this.onAction,
    required this.onStartDuty,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final completed = data.trips
        .where(
          (trip) =>
              trip.dateKey == CabDriverController.dateKey(now) &&
              trip.status == 'completed',
        )
        .length;
    final todayTrips = data.trips
        .where((trip) => trip.dateKey == CabDriverController.dateKey(now))
        .length;
    final remaining = data.assignments
        .where(
          (assignment) =>
              assignment.dateKey == CabDriverController.dateKey(now) &&
              assignment.status != 'completed',
        )
        .length;
    final rider = data.activeRider;
    final riderName = rider == null
        ? null
        : data.employees[rider.employeeId]?.name;
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Operations')),
      body: RefreshIndicator(
        onRefresh: () => CabDriverController.load().then((_) {}),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          children: [
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(now),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.driver.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      PremiumStatusChip(
                        label: data.dutyActive ? 'On Duty' : 'Off Duty',
                        color: data.dutyActive
                            ? AppColors.success
                            : AppColors.textDisabled,
                      ),
                      PremiumStatusChip(
                        label: data.vehicle?.vehicleNumber ?? 'No Vehicle',
                        color: AppColors.info,
                      ),
                      PremiumStatusChip(
                        label: _duration(data.dutyDuration),
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _Metrics(
              items: [
                ('Today Trips', '$todayTrips', Icons.route_outlined),
                ('Completed', '$completed', Icons.task_alt_outlined),
                ('Remaining', '$remaining', Icons.pending_actions_outlined),
                (
                  'Duty Timer',
                  _duration(data.dutyDuration),
                  Icons.timer_outlined,
                ),
              ],
            ),
            const SizedBox(height: 10),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Current Trip',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _Detail(
                    'Status',
                    _label(data.activeTrip?.status ?? 'No active trip'),
                  ),
                  _Detail(
                    'Destination',
                    data.todayAssignment?.officeName ?? 'Not assigned',
                  ),
                  _Detail('Active Pickup', riderName ?? 'No pending pickup'),
                  _Detail(
                    'Pickup Distance',
                    data.distanceToActiveRiderMeters == null
                        ? 'Location unavailable'
                        : '${data.distanceToActiveRiderMeters!.round()} m',
                  ),
                  if (rider?.status == 'waiting')
                    _Detail(
                      'Waiting Time',
                      _duration(
                        DateTime.now().difference(
                          rider?.reachedPickupAt ?? DateTime.now(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _Actions(
              data: data,
              busy: busy,
              onAction: onAction,
              onStartTripSheet: _showStartTripSheet,
              onStartDuty: onStartDuty,
            ),
          ],
        ),
      ),
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
  final Future<void> Function(BuildContext, CabDriverOperations)
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
    final rider = data.activeRider;
    return PremiumCard(
      child: Wrap(
        spacing: 9,
        runSpacing: 9,
        children: [
          if (!data.dutyActive)
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      await onStartDuty(data);
                    },
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Start Duty'),
            ),
          if (data.dutyActive)
            _button(
              'End Duty',
              Icons.stop_circle_outlined,
              trip == null,
              CabDriverWorkflowSupport.endDuty,
              color: AppColors.error,
            ),
          if (data.dutyActive && trip == null) _startTripButton(context, data),
          if (data.dutyActive && trip?.status == 'created')
            _button(
              'Resume Trip',
              Icons.play_arrow,
              true,
              CabDriverWorkflowSupport.startOrResumeTrip,
            ),
          if (trip?.status == 'active' &&
              rider != null &&
              rider.status != 'waiting')
            _button(
              'Reached Pickup',
              Icons.pin_drop_outlined,
              (data.distanceToActiveRiderMeters ?? double.infinity) <=
                  CabDriverController.arrivalThresholdMeters,
              CabDriverController.reachedPickup,
            ),
          if (trip?.status == 'active' && rider?.status == 'waiting')
            _button(
              'Picked Up',
              Icons.person_add_alt_1,
              true,
              CabDriverController.pickedUp,
            ),
          if (trip?.status == 'active' && rider?.status == 'waiting')
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
          if (trip?.status == 'active' && rider == null)
            _button(
              'Reached Office',
              Icons.flag_outlined,
              true,
              CabDriverWorkflowSupport.reachedDestination,
            ),
          if (trip?.status == 'office_arrived')
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
    return FilledButton.icon(
      onPressed: busy ? null : () => onStartTripSheet(context, data),
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

class _DriverTrips extends StatelessWidget {
  final CabDriverOperations data;
  const _DriverTrips({required this.data});

  @override
  Widget build(BuildContext context) {
    final today = CabDriverController.dateKey(DateTime.now());
    final upcoming = data.assignments
        .where((item) => item.dateKey.compareTo(today) > 0)
        .toList();
    final running = data.trips
        .where(
          (trip) => const {'active', 'office_arrived'}.contains(trip.status),
        )
        .toList();
    final completed = data.trips
        .where((trip) => trip.status == 'completed')
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Trips')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _TripSection(
            title: "Today's Trips",
            trips: data.trips.where((trip) => trip.dateKey == today).toList(),
            data: data,
          ),
          _AssignmentSection(title: 'Upcoming Trips', assignments: upcoming),
          _TripSection(title: 'Running Trips', trips: running, data: data),
          _TripSection(title: 'Completed Trips', trips: completed, data: data),
        ],
      ),
    );
  }
}

class _TripSection extends StatelessWidget {
  final String title;
  final List<CabTripModel> trips;
  final CabDriverOperations data;
  const _TripSection({
    required this.title,
    required this.trips,
    required this.data,
  });

  @override
  Widget build(BuildContext context) => PremiumCard(
    child: ExpansionTile(
      initiallyExpanded: true,
      tilePadding: EdgeInsets.zero,
      title: Text(title),
      children: trips.isEmpty
          ? [
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('No trips'),
              ),
            ]
          : trips
                .map(
                  (trip) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.route_outlined),
                    title: Text(_label(trip.status)),
                    subtitle: Text(
                      '${trip.dateKey} • ${trip.distanceKm.toStringAsFixed(1)} km • ${_duration(Duration(seconds: trip.durationSeconds))}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _tripDetails(context, trip, data),
                  ),
                )
                .toList(),
    ),
  );
}

class _AssignmentSection extends StatelessWidget {
  final String title;
  final List<CabAssignmentModel> assignments;
  const _AssignmentSection({required this.title, required this.assignments});
  @override
  Widget build(BuildContext context) => PremiumCard(
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(title),
      children: assignments.isEmpty
          ? [
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('No upcoming trips'),
              ),
            ]
          : assignments
                .map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text(item.officeName),
                    subtitle: Text('${item.dateKey} • ${item.officeAddress}'),
                  ),
                )
                .toList(),
    ),
  );
}

class _DriverProfile extends StatelessWidget {
  final CabDriverOperations data;
  const _DriverProfile({required this.data});

  @override
  Widget build(BuildContext context) {
    final completed = data.trips
        .where((trip) => trip.status == 'completed')
        .toList();
    final km = completed.fold<double>(0, (sum, trip) => sum + trip.distanceKm);
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Profile')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          PremiumCard(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 42,
                  foregroundImage: data.driver.profileImage.isEmpty
                      ? null
                      : NetworkImage(data.driver.profileImage),
                  child: Text(
                    data.driver.name.isEmpty
                        ? 'D'
                        : data.driver.name[0].toUpperCase(),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  data.driver.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(data.vehicle?.vehicleNumber ?? 'No vehicle assigned'),
                Text(
                  'License: ${data.driver.licenseNumber.isEmpty ? 'Not configured' : data.driver.licenseNumber}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _Metrics(
            items: [
              (
                "Today's KM",
                '${data.shift?.totalDistance.toStringAsFixed(1) ?? '0.0'} km',
                Icons.speed,
              ),
              ('Trips', '${completed.length}', Icons.route_outlined),
              (
                'Duty Hours',
                _duration(data.dutyDuration),
                Icons.timer_outlined,
              ),
              ('Total KM', '${km.toStringAsFixed(1)} km', Icons.alt_route),
            ],
          ),
          const SizedBox(height: 10),
          PremiumCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notification Settings'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationCenterScreen(),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Theme'),
                  subtitle: Text(data.driver.themeMode),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _themeDialog(context, data.driver.uid),
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.error),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: AuthService.signOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  final List<(String, String, IconData)> items;
  const _Metrics({required this.items});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 8) / 2;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items
            .map(
              (item) => SizedBox(
                width: width,
                child: PremiumCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.$3, size: 18),
                      const SizedBox(height: 8),
                      Text(
                        item.$2,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        item.$1,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class _Detail extends StatelessWidget {
  final String label;
  final String value;
  const _Detail(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Flexible(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
}

Future<void> _tripDetails(
  BuildContext context,
  CabTripModel trip,
  CabDriverOperations data,
) async {
  var riders = data.riders.where((rider) => rider.tripId == trip.id).toList();
  var events = data.events.where((event) => event.tripId == trip.id).toList();
  if (riders.isEmpty) {
    riders = await CabManagementController.loadTripRiders(trip.id);
  }
  if (events.isEmpty) {
    events = await CabManagementController.loadTripEvents(trip.id);
  }
  if (!context.mounted) return;
  final missingIds = riders
      .map((rider) => rider.employeeId)
      .where((id) => !data.employees.containsKey(id))
      .toSet()
      .toList();
  final historicalUsers = missingIds.isEmpty
      ? const <UserModel>[]
      : await FirestoreService.fetchUsersByIds(missingIds);
  if (!context.mounted) return;
  final users = {
    ...data.employees,
    for (final user in historicalUsers) user.uid: user,
  };
  riders.sort((a, b) => a.pickupOrder.compareTo(b.pickupOrder));
  events.sort(
    (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
      a.createdAt ?? DateTime(1970),
    ),
  );
  final loadedRiders = List<CabTripRiderModel>.unmodifiable(riders);
  final loadedEvents = List<CabTripEventModel>.unmodifiable(events);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .75,
      maxChildSize: .95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            'Trip Details',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          _Detail('Status', _label(trip.status)),
          _Detail('Distance', '${trip.distanceKm.toStringAsFixed(1)} km'),
          _Detail(
            'Duration',
            _duration(Duration(seconds: trip.durationSeconds)),
          ),
          _Detail(
            'Driving Time',
            _duration(Duration(seconds: trip.drivingSeconds)),
          ),
          _Detail('Idle Time', _duration(Duration(seconds: trip.idleSeconds))),
          const Divider(),
          Text(
            'Pickup Order & Employees',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ...loadedRiders.map(
            (rider) => ListTile(
              leading: CircleAvatar(child: Text('${rider.pickupOrder}')),
              title: Text(users[rider.employeeId]?.name ?? rider.employeeId),
              subtitle: Text(
                '${_label(rider.status)} • Waiting ${_duration(Duration(seconds: rider.waitingDurationSeconds))}',
              ),
            ),
          ),
          const Divider(),
          Text('Timeline', style: Theme.of(context).textTheme.titleMedium),
          ...loadedEvents.map(
            (event) => ListTile(
              leading: const Icon(Icons.timeline),
              title: Text(event.message),
              subtitle: Text(event.createdAt?.toLocal().toString() ?? ''),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _themeDialog(BuildContext context, String uid) async {
  final value = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Theme'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'system'),
          child: const Text('System'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'dark'),
          child: const Text('Dark'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'light'),
          child: const Text('Light'),
        ),
      ],
    ),
  );
  if (value == null) return;
  await FirestoreService.updateUserFields(
    uid: uid,
    fields: {'themeMode': value},
  );
  AppThemeController.setStoredMode(value);
}

String _duration(Duration duration) =>
    '${duration.inHours}h ${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}m';
String _label(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
String _greeting(DateTime now) => now.hour < 12
    ? 'Good Morning'
    : now.hour < 17
    ? 'Good Afternoon'
    : 'Good Evening';
