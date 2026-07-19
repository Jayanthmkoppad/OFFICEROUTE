import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/controllers/cab_management_controller.dart';
import '../../../core/models/cab_assignment_member_model.dart';
import '../../../core/models/cab_assignment_model.dart';
import '../../../core/models/cab_trip_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/cab_assignment_service.dart';
import '../../../core/services/cab_trip_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/services/auth_service.dart';
import '../../cab_tracking/employee_live_cab_tracking_screen.dart';

/// Employee-facing cab tracking card shown on the Home dashboard when the
/// signed-in user has today's cab assignment. Renders driver, vehicle, ETA
/// hints and the current cab trip status. Values come from live Firestore
/// data; unavailable metrics show `—` rather than being fabricated.
class EmployeeCabTrackingCard extends StatefulWidget {
  const EmployeeCabTrackingCard({super.key});

  @override
  State<EmployeeCabTrackingCard> createState() =>
      _EmployeeCabTrackingCardState();
}

class _EmployeeCabTrackingCardState extends State<EmployeeCabTrackingCard> {
  StreamSubscription<void>? _memberSub;
  StreamSubscription<void>? _tripSub;
  Timer? _debounce;
  bool _loading = true;
  Object? _error;

  CabAssignmentMemberModel? _member;
  CabAssignmentModel? _assignment;
  CabTripModel? _activeTrip;
  UserModel? _driver;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
    final uid = AuthService.currentUser?.uid;
    if (uid != null) {
      _memberSub = CabAssignmentService.watchMemberForUser(
        userId: uid,
        dateKey: _todayKey(),
      ).listen((_) => _scheduleReload());
    }
  }

  @override
  void dispose() {
    _memberSub?.cancel();
    _tripSub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _reload);
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _reload() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _member = null;
        _assignment = null;
        _activeTrip = null;
      });
      return;
    }
    try {
      final today = _todayKey();
      final member = await CabManagementController.loadTodayMemberAssignment(
        userId: uid,
        dateKey: today,
      );
      if (member == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _member = null;
          _assignment = null;
          _activeTrip = null;
          _driver = null;
          _error = null;
        });
        return;
      }
      final assignment = await CabManagementController.loadAssignment(
        member.assignmentId,
      );
      CabTripModel? activeTrip;
      if (assignment != null) {
        activeTrip = await CabTripService.fetchActiveTripForAssignment(
          assignmentId: assignment.id,
        );
      }
      _tripSub?.cancel();
      if (activeTrip != null) {
        _tripSub = CabTripService.watchRiders(activeTrip.id).listen((_) {
          _scheduleReload();
        });
      }
      UserModel? driver;
      if (member.driverId.isNotEmpty) {
        driver = await FirestoreService.getUser(member.driverId);
      }
      if (!mounted) return;
      setState(() {
        _member = member;
        _assignment = assignment;
        _activeTrip = activeTrip;
        _driver = driver;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _wrapper(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_error != null) {
      return _wrapper(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Cab tracking unavailable: $_error',
            style: AppTextStyles.caption,
          ),
        ),
      );
    }
    if (_member == null || _assignment == null) {
      return const SizedBox.shrink();
    }

    final assignment = _assignment!;
    final driver = _driver;
    final trip = _activeTrip;
    final status = trip?.status ?? _member?.status ?? assignment.status;
    return _wrapper(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                foregroundImage: (driver?.profileImage.isNotEmpty ?? false)
                    ? NetworkImage(driver!.profileImage)
                    : null,
                child: Text(
                  driver == null || driver.name.isEmpty
                      ? 'D'
                      : driver.name.substring(0, 1).toUpperCase(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver?.name ?? '—',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${_titleCase(status.replaceAll('_', ' '))} · Cab ${assignment.vehicleId.isEmpty ? '—' : assignment.vehicleId}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Track'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EmployeeLiveCabTrackingScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          _row('Destination', assignment.officeName),
          _row(
            'Pickup Status',
            _titleCase(_member!.status.replaceAll('_', ' ')),
          ),
          _row(
            'Trip Started',
            trip?.startedAt == null
                ? '—'
                : trip!.startedAt!.toLocal().toString(),
          ),
        ],
      ),
    );
  }

  Widget _wrapper(Widget child) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.info.withAlpha(14),
        border: Border.all(color: AppColors.info.withAlpha(56)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.caption)),
          Flexible(
            child: Text(
              value.trim().isEmpty ? '—' : value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _titleCase(String value) => value
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
