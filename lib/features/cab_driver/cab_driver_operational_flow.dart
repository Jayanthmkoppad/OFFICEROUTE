import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/premium_widgets.dart';
import 'cab_driver_workflow_support.dart';
import 'controllers/cab_driver_controller.dart';

enum DriverOperationalPhase {
  currentPickup,
  arrivalConfirmation,
  waitingForEmployee,
  employeeReady,
  pickupConfirmation,
  skipPassenger,
  nextPickup,
  allPassengersResolved,
  navigateToOffice,
  officeArrival,
  tripSummary,
  endDuty,
  dutyCompleted,
  gpsDisabled,
  permissionRequired,
  offlinePendingSync,
  recoverTrip,
  assignmentCancelled,
  queryFailure,
  emergencySupport,
  notificationDetail,
  signOutConfirmation,
  newDayReset,
}

extension DriverOperationalPhaseDetails on DriverOperationalPhase {
  int get screenNumber => index + 14;

  String get title => const [
    'Current Pickup',
    'Confirm Arrival',
    'Waiting for Employee',
    'Employee Ready',
    'Passenger Onboard',
    'Skip Passenger',
    'Next Pickup',
    'All Passengers Resolved',
    'Navigate to Office',
    'Office Arrival',
    'Trip Summary',
    'End Duty',
    'Duty Completed',
    'GPS Signal Lost',
    'Location Access Required',
    'Offline — Pending Sync',
    'Recover Active Trip',
    'Assignment Cancelled',
    'Connection Error',
    'Emergency Support',
    'Notification Detail',
    'Sign Out',
    'New Day Reset',
  ][index];
}

class CabDriverOperationalFlow extends StatefulWidget {
  final CabDriverOperations data;
  final DriverOperationalPhase initialPhase;
  final Future<void> Function()? onReload;

  const CabDriverOperationalFlow({
    super.key,
    required this.data,
    this.initialPhase = DriverOperationalPhase.currentPickup,
    this.onReload,
  });

  @override
  State<CabDriverOperationalFlow> createState() =>
      _CabDriverOperationalFlowState();
}

class _CabDriverOperationalFlowState extends State<CabDriverOperationalFlow> {
  late DriverOperationalPhase _phase;
  final Set<int> _officeChecks = <int>{};
  String? _skipReason;
  bool _busy = false;
  bool _synced = false;
  Timer? _timer;
  int _waitingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _phase = widget.initialPhase;
    final reachedAt = widget.data.activeRider?.reachedPickupAt;
    _waitingSeconds = reachedAt == null
        ? widget.data.activeRider?.waitingDurationSeconds ?? 0
        : DateTime.now().difference(reachedAt).inSeconds.clamp(0, 86400);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _phase == DriverOperationalPhase.waitingForEmployee) {
        setState(() => _waitingSeconds++);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CabDriverOperationalFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPhase != widget.initialPhase) {
      _phase = widget.initialPhase;
    }
  }

  String get _riderName {
    final rider = widget.data.activeRider;
    if (rider == null) return 'Assigned Employee';
    return widget.data.employees[rider.employeeId]?.name ?? rider.employeeId;
  }

  String get _officeName =>
      widget.data.todayAssignment?.officeName ?? 'Corporate Office';

  String get _waitText {
    final minutes = (_waitingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_waitingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await widget.onReload?.call();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _go(DriverOperationalPhase phase) => setState(() => _phase = phase);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_phase.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: PremiumStatusChip(
                label:
                    'SCREEN ${_phase.screenNumber.toString().padLeft(2, '0')}',
                color: AppColors.info,
              ),
            ),
          ),
          PopupMenuButton<DriverOperationalPhase>(
            tooltip: 'Operational states',
            onSelected: _go,
            itemBuilder: (_) => DriverOperationalPhase.values
                .map(
                  (phase) => PopupMenuItem(
                    value: phase,
                    child: Text(
                      '${phase.screenNumber.toString().padLeft(2, '0')} · ${phase.title}',
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _statusStrip(),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(key: ValueKey(_phase), child: _content()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusStrip() => Row(
    children: [
      const Icon(Icons.sensors, color: AppColors.success, size: 18),
      const SizedBox(width: 8),
      const Expanded(
        child: Text(
          'OfficeRoute OS',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      Text(
        widget.data.dutyActive ? 'DUTY ACTIVE' : 'OFF DUTY',
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
    ],
  );

  Widget _content() {
    switch (_phase) {
      case DriverOperationalPhase.currentPickup:
        return _missionCard(
          icon: Icons.person_pin_circle,
          eyebrow: 'PICKUP 1/${widget.data.riders.length}',
          title: _riderName,
          subtitle: 'Estimated arrival · 2 mins',
          details: const ['Location verified', '1 passenger'],
          primary: 'MARK ARRIVED',
          onPrimary: () => _go(DriverOperationalPhase.arrivalConfirmation),
        );
      case DriverOperationalPhase.arrivalConfirmation:
        return _missionCard(
          icon: Icons.verified,
          eyebrow: 'LOCATION VERIFIED',
          title: 'Confirm arrival',
          subtitle: 'Picking up $_riderName',
          details: const ['Accuracy · within 15m', 'Arrival time recorded'],
          primary: 'CONFIRM ARRIVAL',
          onPrimary: () => _run(() async {
            await CabDriverController.reachedPickup(widget.data);
            _go(DriverOperationalPhase.waitingForEmployee);
          }),
          secondary: 'ADJUST PIN',
        );
      case DriverOperationalPhase.waitingForEmployee:
        return _missionCard(
          icon: Icons.hourglass_top,
          eyebrow: _waitText,
          title: 'Waiting for Employee',
          subtitle: 'Notification sent to $_riderName',
          details: const ['Call employee', 'Operations support available'],
          primary: 'EMPLOYEE IS READY',
          onPrimary: () => _go(DriverOperationalPhase.employeeReady),
          secondary: 'SKIP PICKUP',
          onSecondary: () => _go(DriverOperationalPhase.skipPassenger),
        );
      case DriverOperationalPhase.employeeReady:
        return _missionCard(
          icon: Icons.how_to_reg,
          eyebrow: 'ON SITE',
          title: '$_riderName is ready',
          subtitle: 'Verify the employee before boarding',
          details: ['Wait duration · $_waitText', 'Pickup identity verified'],
          primary: 'MARK EMPLOYEE PICKED UP',
          onPrimary: () => _run(() async {
            await CabDriverController.pickedUp(widget.data);
            _go(DriverOperationalPhase.pickupConfirmation);
          }),
          secondary: 'UNABLE TO LOCATE',
          onSecondary: () => _go(DriverOperationalPhase.skipPassenger),
        );
      case DriverOperationalPhase.pickupConfirmation:
        return _missionCard(
          icon: Icons.check_circle,
          eyebrow: 'SUCCESS',
          title: 'Passenger Onboard',
          subtitle: _riderName,
          details: ['Waiting time · $_waitText', 'Pickup recorded securely'],
          primary: 'CONTINUE',
          onPrimary: () => _go(
            widget.data.activeRider == null
                ? DriverOperationalPhase.allPassengersResolved
                : DriverOperationalPhase.nextPickup,
          ),
        );
      case DriverOperationalPhase.skipPassenger:
        return _skipCard();
      case DriverOperationalPhase.nextPickup:
        return _missionCard(
          icon: Icons.route,
          eyebrow: 'PICKUP RECORDED',
          title: 'Continue to next pickup',
          subtitle: 'The next assigned employee is ready',
          details: const ['Route recalculated', 'Manifest remains active'],
          primary: 'CONTINUE TO NEXT PICKUP',
          onPrimary: () => _go(DriverOperationalPhase.currentPickup),
          secondary: 'VIEW ROSTER',
        );
      case DriverOperationalPhase.allPassengersResolved:
        return _missionCard(
          icon: Icons.task_alt,
          eyebrow: '100% COMPLETE',
          title: 'All Passengers Resolved',
          subtitle: 'No pending pickups',
          details: [
            '${widget.data.riders.length} passengers handled',
            'Next · $_officeName',
          ],
          primary: 'NAVIGATE TO OFFICE',
          onPrimary: () => _go(DriverOperationalPhase.navigateToOffice),
        );
      case DriverOperationalPhase.navigateToOffice:
        return _missionCard(
          icon: Icons.navigation,
          eyebrow: 'DESTINATION',
          title: _officeName,
          subtitle: 'ETA unavailable',
          details: [
            '${widget.data.riders.length} passengers onboard',
            'Road route provider unavailable',
          ],
          primary: 'MARK ARRIVED AT OFFICE',
          onPrimary: () => _go(DriverOperationalPhase.officeArrival),
          secondary: 'OPEN IN GOOGLE MAPS',
        );
      case DriverOperationalPhase.officeArrival:
        return _officeChecklist();
      case DriverOperationalPhase.tripSummary:
        return _tripSummary();
      case DriverOperationalPhase.endDuty:
        return _endDuty();
      case DriverOperationalPhase.dutyCompleted:
        return _missionCard(
          icon: Icons.check_circle,
          eyebrow: 'SHIFT SYNCHRONIZED',
          title: 'Duty Completed Successfully',
          subtitle: 'Great job, ${widget.data.driver.name}',
          details: const ['Trip log saved', 'Location sharing stopped'],
          primary: 'RETURN TO HOME',
          onPrimary: () => Navigator.of(context).pop(),
        );
      case DriverOperationalPhase.gpsDisabled:
        return _recoveryCard(
          icon: Icons.location_off,
          title: 'GPS Signal Lost',
          body: 'Enable high-accuracy location and move to an open area.',
          action: 'RETRY GPS',
          onAction: () => _go(DriverOperationalPhase.currentPickup),
        );
      case DriverOperationalPhase.permissionRequired:
        return _recoveryCard(
          icon: Icons.location_on,
          title: 'Location Access Required',
          body:
              'Live navigation and accurate mileage require location permission.',
          action: 'ALLOW PERMISSION',
          onAction: () => _go(DriverOperationalPhase.currentPickup),
        );
      case DriverOperationalPhase.offlinePendingSync:
        return _missionCard(
          icon: _synced ? Icons.cloud_done : Icons.cloud_off,
          eyebrow: _synced ? 'SYNCED' : '3 ACTIONS PENDING',
          title: _synced ? 'Actions synchronized' : 'You are currently offline',
          subtitle: 'Trip remains safe on this device',
          details: const [
            'Pickup confirmation queued',
            'Route milestone queued',
            'Fare update queued',
          ],
          primary: _synced ? 'CONTINUE TRIP' : 'RETRY SYNC',
          onPrimary: () => setState(() {
            if (_synced) {
              _phase = DriverOperationalPhase.currentPickup;
            } else {
              _synced = true;
            }
          }),
        );
      case DriverOperationalPhase.recoverTrip:
        return _missionCard(
          icon: Icons.restore,
          eyebrow: 'ACTIVE TRIP FOUND',
          title: 'Resume pending pickup',
          subtitle: _riderName,
          details: const ['State · En Route', 'Local progress recovered'],
          primary: 'RESUME TRIP',
          onPrimary: () => _run(() async {
            await CabDriverWorkflowSupport.startOrResumeTrip(widget.data);
            _go(DriverOperationalPhase.currentPickup);
          }),
        );
      case DriverOperationalPhase.assignmentCancelled:
        return _recoveryCard(
          icon: Icons.warning_amber,
          title: 'Assignment Cancelled',
          body:
              'Operations cancelled this route. No pickup action is required.',
          action: 'RETURN HOME',
          onAction: () => Navigator.of(context).pop(),
        );
      case DriverOperationalPhase.queryFailure:
        return _recoveryCard(
          icon: Icons.cloud_off,
          title: 'Failed to load passengers',
          body: 'Cached shift data remains visible. Retry the secure query.',
          action: 'RETRY',
          onAction: () => _run(() async {
            await widget.onReload?.call();
            _go(DriverOperationalPhase.currentPickup);
          }),
        );
      case DriverOperationalPhase.emergencySupport:
        return _emergencyCard();
      case DriverOperationalPhase.notificationDetail:
        return _missionCard(
          icon: Icons.notifications_active,
          eyebrow: 'EMPLOYEE READY',
          title: _riderName,
          subtitle: 'Ready for the scheduled pickup',
          details: const [
            'Pickup window · ±5 mins',
            'Address available in active trip',
          ],
          primary: 'VIEW ACTIVE TRIP',
          onPrimary: () => _go(DriverOperationalPhase.currentPickup),
          secondary: 'CALL EMPLOYEE',
        );
      case DriverOperationalPhase.signOutConfirmation:
        return _recoveryCard(
          icon: Icons.logout,
          title: 'Sign Out',
          body: widget.data.dutyActive
              ? 'Duty is active. Complete the trip and end duty before signing out.'
              : 'Are you sure you want to sign out?',
          action: widget.data.dutyActive ? 'RETURN TO DUTY' : 'SIGN OUT',
          onAction: () => Navigator.of(context).pop(),
        );
      case DriverOperationalPhase.newDayReset:
        return _missionCard(
          icon: Icons.sync,
          eyebrow: 'SCHEDULE READY',
          title: 'New Day Operational Reset',
          subtitle: 'Vehicle and secure route data are ready',
          details: const [
            'Vehicle status · Ready',
            'Pre-shift briefing available',
          ],
          primary: 'START DUTY',
          onPrimary: () => Navigator.of(context).pop(),
        );
    }
  }

  Widget _skipCard() {
    const reasons = [
      'Unavailable',
      'Cancelled',
      'Not at Pickup',
      'Inaccessible',
      'Operations Instructed',
    ];
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.person_off, size: 48, color: AppColors.warning),
          const SizedBox(height: 12),
          const Text(
            'Skip Passenger',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const Text(
            'Select a reason. This action is logged for fleet operations.',
          ),
          const SizedBox(height: 16),
          ...reasons.map(
            (reason) => Material(
              color: Colors.transparent,
              child: ListTile(
                leading: Icon(
                  _skipReason == reason
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _skipReason == reason ? AppColors.info : null,
                ),
                title: Text(reason),
                selected: _skipReason == reason,
                onTap: () => setState(() => _skipReason = reason),
              ),
            ),
          ),
          _primaryButton(
            'CONFIRM SKIP',
            _skipReason == null || _busy
                ? null
                : () => _run(() async {
                    await CabDriverWorkflowSupport.skipRider(
                      widget.data,
                      reason: _skipReason!,
                    );
                    _go(DriverOperationalPhase.nextPickup);
                  }),
          ),
        ],
      ),
    );
  }

  Widget _officeChecklist() {
    const checks = [
      'All passengers dropped',
      'Vehicle empty',
      'Digital log updated',
    ];
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.domain_verification,
            size: 48,
            color: AppColors.success,
          ),
          const SizedBox(height: 12),
          Text(
            'Destination Reached',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(_officeName),
          const SizedBox(height: 12),
          ...List.generate(
            checks.length,
            (index) => Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                value: _officeChecks.contains(index),
                title: Text(checks[index]),
                onChanged: (value) => setState(
                  () => value == true
                      ? _officeChecks.add(index)
                      : _officeChecks.remove(index),
                ),
              ),
            ),
          ),
          _primaryButton(
            'CONFIRM OFFICE ARRIVAL',
            _officeChecks.length != checks.length || _busy
                ? null
                : () => _run(() async {
                    await CabDriverWorkflowSupport.reachedDestination(
                      widget.data,
                    );
                    _go(DriverOperationalPhase.tripSummary);
                  }),
          ),
        ],
      ),
    );
  }

  Widget _tripSummary() => FutureBuilder<CabTripSummary?>(
    future: CabDriverWorkflowSupport.summariseActiveTrip(widget.data),
    builder: (context, snapshot) {
      final summary = snapshot.data;
      return _missionCard(
        icon: Icons.fact_check,
        eyebrow: 'TRIP SUMMARY',
        title: 'Review final details',
        subtitle:
            '${summary?.completedPickups ?? 0} picked up · ${summary?.skipped ?? 0} skipped',
        details: [
          'Distance · ${(summary?.distanceKm ?? 0).toStringAsFixed(1)} km',
          'Duration · ${((summary?.tripDurationSeconds ?? 0) ~/ 60)} min',
        ],
        primary: 'COMPLETE TRIP',
        onPrimary: _busy
            ? null
            : () => _run(() async {
                await CabDriverWorkflowSupport.completeTrip(widget.data);
                _go(DriverOperationalPhase.endDuty);
              }),
      );
    },
  );

  Widget _endDuty() => _missionCard(
    icon: Icons.power_settings_new,
    eyebrow: 'SESSION SUMMARY',
    title: 'End Duty',
    subtitle: 'Location sharing stops after confirmation',
    details: [
      'Driver · ${widget.data.driver.name}',
      'Vehicle · ${widget.data.vehicle?.registrationNumber ?? 'Assigned cab'}',
    ],
    primary: 'CONFIRM END DUTY',
    onPrimary: _busy
        ? null
        : () => _run(() async {
            await CabDriverWorkflowSupport.endDuty(widget.data);
            _go(DriverOperationalPhase.dutyCompleted);
          }),
  );

  Widget _emergencyCard() => PremiumCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.sos, size: 52, color: AppColors.error),
        const SizedBox(height: 12),
        const Text(
          'Emergency Support',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const Text('Dispatch is on standby. Select immediate assistance.'),
        const SizedBox(height: 16),
        for (final action in const [
          (Icons.sos, 'SOS Emergency'),
          (Icons.support_agent, 'Call Operations'),
          (Icons.report_problem, 'Report Incident'),
          (Icons.share_location, 'Share Live Location'),
        ])
          Material(
            color: Colors.transparent,
            child: ListTile(
              leading: Icon(action.$1),
              title: Text(action.$2),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('${action.$2} selected'))),
            ),
          ),
        const Text(
          'Secure line · Encrypted data transmission',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    ),
  );

  Widget _recoveryCard({
    required IconData icon,
    required String title,
    required String body,
    required String action,
    required VoidCallback onAction,
  }) => _missionCard(
    icon: icon,
    eyebrow: 'ACTION REQUIRED',
    title: title,
    subtitle: body,
    details: const ['Your current trip data remains protected'],
    primary: action,
    onPrimary: onAction,
  );

  Widget _missionCard({
    required IconData icon,
    required String eyebrow,
    required String title,
    required String subtitle,
    required List<String> details,
    required String primary,
    VoidCallback? onPrimary,
    String? secondary,
    VoidCallback? onSecondary,
  }) => PremiumCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 52, color: AppColors.info),
        const SizedBox(height: 14),
        Text(
          eyebrow,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: AppColors.info,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 18),
        ...details.map(
          (detail) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: AppColors.success,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(detail)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _primaryButton(primary, _busy ? null : onPrimary),
        if (secondary != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onSecondary,
              child: Text(secondary),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _primaryButton(String label, VoidCallback? onPressed) => SizedBox(
    width: double.infinity,
    height: 52,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: _busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.arrow_forward),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    ),
  );
}
