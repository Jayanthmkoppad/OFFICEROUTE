import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/controllers/cab_management_controller.dart';
import '../../core/models/cab_assignment_member_model.dart';
import '../../core/models/cab_assignment_model.dart';
import '../../core/models/cab_trip_model.dart';
import '../../core/models/live_location_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/cab_assignment_service.dart';
import '../../core/services/cab_trip_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/live_location_service.dart';
import '../../core/services/location_tracking_policy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../auth/services/auth_service.dart';

/// Dedicated Employee live cab tracking map. Shows the driver's live cab
/// marker and the employee's own pickup marker. Values come exclusively from
/// live Firestore data; if data is missing the UI shows `—` rather than
/// fabricating numbers.
class EmployeeLiveCabTrackingScreen extends StatefulWidget {
  const EmployeeLiveCabTrackingScreen({super.key});

  @override
  State<EmployeeLiveCabTrackingScreen> createState() =>
      _EmployeeLiveCabTrackingScreenState();
}

class _EmployeeLiveCabTrackingScreenState
    extends State<EmployeeLiveCabTrackingScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<void>? _driverLocationSub;
  StreamSubscription<void>? _employeeLocationSub;
  StreamSubscription<void>? _memberSub;
  Timer? _debounce;

  CabAssignmentMemberModel? _member;
  CabAssignmentModel? _assignment;
  CabTripModel? _activeTrip;
  UserModel? _driver;
  LiveLocationModel? _driverLocation;
  LiveLocationModel? _employeeLocation;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  @override
  void dispose() {
    _driverLocationSub?.cancel();
    _employeeLocationSub?.cancel();
    _memberSub?.cancel();
    _debounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _reload);
  }

  Future<void> _reload() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = StateError('Sign in required to track your cab.');
      });
      return;
    }
    try {
      final today = _todayKey();
      final member = await CabManagementController.loadTodayMemberAssignment(
        userId: uid,
        dateKey: today,
      );
      CabAssignmentModel? assignment;
      CabTripModel? activeTrip;
      UserModel? driver;
      LiveLocationModel? driverLocation;
      LiveLocationModel? employeeLocation =
          await LiveLocationService.fetchLiveLocation(uid);
      if (member != null) {
        assignment = await CabManagementController.loadAssignment(
          member.assignmentId,
        );
        if (assignment != null) {
          activeTrip = await CabTripService.fetchActiveTripForAssignment(
            assignmentId: assignment.id,
          );
        }
        if (member.driverId.isNotEmpty) {
          driver = await FirestoreService.getUser(member.driverId);
          driverLocation = await LiveLocationService.fetchLiveLocation(
            member.driverId,
          );
          _driverLocationSub?.cancel();
          _driverLocationSub = LiveLocationService.watchLiveLocation(
            member.driverId,
          ).listen((_) => _refreshDriverLocation(member.driverId));
        }
        _memberSub?.cancel();
        _memberSub = CabAssignmentService.watchMemberForUser(
          userId: uid,
          dateKey: today,
        ).listen((_) => _scheduleReload());
      }
      _employeeLocationSub?.cancel();
      _employeeLocationSub = LiveLocationService.watchLiveLocation(
        uid,
      ).listen((_) => _refreshEmployeeLocation(uid));
      if (!mounted) return;
      setState(() {
        _member = member;
        _assignment = assignment;
        _activeTrip = activeTrip;
        _driver = driver;
        _driverLocation = driverLocation;
        _employeeLocation = employeeLocation;
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

  Future<void> _refreshDriverLocation(String driverId) async {
    try {
      final location = await LiveLocationService.fetchLiveLocation(driverId);
      if (!mounted) return;
      setState(() => _driverLocation = location);
    } catch (_) {}
  }

  Future<void> _refreshEmployeeLocation(String userId) async {
    try {
      final location = await LiveLocationService.fetchLiveLocation(userId);
      if (!mounted) return;
      setState(() => _employeeLocation = location);
    } catch (_) {}
  }

  double? _distanceMeters() {
    final driver = _driverLocation;
    final employee = _employeeLocation;
    if (driver == null || employee == null) return null;
    return LocationTrackingPolicy.distanceMeters(
      driver.latitude,
      driver.longitude,
      employee.latitude,
      employee.longitude,
    );
  }

  int? _etaSeconds() {
    final distance = _distanceMeters();
    final speed = _driverLocation?.speed ?? 0;
    if (distance == null || speed <= 1) return null;
    return (distance / speed).round();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Track My Cab')),
        body: Center(child: Text('Unable to track cab: $_error')),
      );
    }
    if (_member == null || _assignment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Track My Cab')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'You do not have a cab assignment for today. If this is a mistake, please contact your operations team.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final assignment = _assignment!;
    final markers = <Marker>{};
    if (_driverLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(
            _driverLocation!.latitude,
            _driverLocation!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: _driver?.name ?? 'Driver',
            snippet:
                'Cab ${assignment.vehicleId.isEmpty ? '—' : assignment.vehicleId}',
          ),
        ),
      );
    }
    if (_employeeLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('me'),
          position: LatLng(
            _employeeLocation!.latitude,
            _employeeLocation!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueYellow,
          ),
          infoWindow: const InfoWindow(title: 'You'),
        ),
      );
    }
    final initial = _driverLocation != null
        ? LatLng(_driverLocation!.latitude, _driverLocation!.longitude)
        : (_employeeLocation != null
              ? LatLng(
                  _employeeLocation!.latitude,
                  _employeeLocation!.longitude,
                )
              : const LatLng(12.9716, 77.5946));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track My Cab'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: initial, zoom: 14),
              markers: markers,
              onMapCreated: (controller) => _mapController = controller,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
            ),
          ),
          _statusPanel(assignment),
        ],
      ),
    );
  }

  Widget _statusPanel(CabAssignmentModel assignment) {
    final distance = _distanceMeters();
    final eta = _etaSeconds();
    final status = _activeTrip?.status ?? _member?.status ?? assignment.status;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.local_taxi_outlined, color: AppColors.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _driver?.name ?? 'Driver',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.info.withAlpha(24),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.info.withAlpha(80)),
                ),
                child: Text(
                  _titleCase(status.replaceAll('_', ' ')),
                  style: const TextStyle(
                    color: AppColors.info,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _kv(
            'Vehicle',
            assignment.vehicleId.isEmpty ? '—' : assignment.vehicleId,
          ),
          _kv('Destination', assignment.officeName),
          _kv(
            'Distance to cab',
            distance == null
                ? '—'
                : distance < 1000
                ? '${distance.round()} m'
                : '${(distance / 1000).toStringAsFixed(1)} km',
          ),
          _kv(
            'ETA',
            eta == null
                ? '—'
                : eta < 60
                ? '${eta}s'
                : '${(eta / 60).round()} min',
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
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
