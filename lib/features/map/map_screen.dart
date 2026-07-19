import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/controllers/cab_management_controller.dart';
import '../../core/models/cab_assignment_member_model.dart';
import '../../core/models/cab_trip_event_model.dart';
import '../../core/models/cab_trip_model.dart';
import '../../core/models/cab_trip_rider_model.dart';
import '../../core/models/live_location_model.dart';
import '../../core/models/location_model.dart';
import '../../core/models/location_session_model.dart';
import '../../core/services/location_tracking_policy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../attendance/controllers/attendance_controller.dart';
import '../attendance/models/attendance_model.dart';
import '../auth/services/auth_service.dart';
import '../customer_visits/controllers/customer_visit_controller.dart';
import '../customer_visits/models/customer_visit_model.dart';
import '../manager/models/manager_employee_summary_model.dart';
import 'controllers/location_controller.dart';
import 'controllers/map_modes_controller.dart';

class MapScreen extends StatefulWidget {
  final bool cabDriverMode;

  const MapScreen({super.key, this.cabDriverMode = false});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late Future<_MapScreenData> _mapFuture;
  late Future<_MapModePayload> _modeFuture;
  GoogleMapController? _mapController;
  MapType _mapType = MapType.normal;
  late _MapMode _selectedMode;
  bool _followMe = true;
  bool _isCameraAnimating = false;
  bool _modeActionBusy = false;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  StreamSubscription<LiveLocationModel>? _cabLocationSubscription;
  LocationSessionModel? _employeePickupSession;
  final List<StreamSubscription<void>> _modeSyncSubscriptions = [];
  Timer? _modeSyncDebounce;
  String? _modeSyncSignature;
  String? _selectedMarkerId;
  BitmapDescriptor? _cabMarkerIcon;
  LatLng? _animatedCabPosition;
  Timer? _cabAnimationTimer;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.cabDriverMode
        ? _MapMode.cabTracking
        : _MapMode.fieldEngineer;
    _mapFuture = _loadMapData();
    _modeFuture = _loadAndConfigureModePayload(_selectedMode);
    unawaited(_loadCabMarkerIcon());
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
    _modeSyncDebounce?.cancel();
    _cabAnimationTimer?.cancel();
    for (final subscription in _modeSyncSubscriptions) {
      subscription.cancel();
    }
    _cabLocationSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<_MapScreenData> _loadMapData() async {
    final location = await LocationController.getCurrentLocation();
    final attendance = await _tryLoadAttendance();
    final visits = await _tryLoadVisits();

    return _MapScreenData(
      location: location,
      attendance: attendance,
      visits: visits,
    );
  }

  Future<AttendanceModel?> _tryLoadAttendance() async {
    try {
      return AttendanceController.loadTodayAttendance();
    } catch (_) {
      return null;
    }
  }

  Future<List<CustomerVisitModel>> _tryLoadVisits() async {
    try {
      return CustomerVisitController.loadMyVisits();
    } catch (_) {
      return const <CustomerVisitModel>[];
    }
  }

  Future<_MapModePayload> _loadModePayload(_MapMode mode) async {
    switch (mode) {
      case _MapMode.cabTracking:
        final cab = await MapModesController.loadCabContext();
        if (cab.isEmployee && cab.currentMember?.status == 'boarded') {
          unawaited(_stopEmployeePickupSharingQuietly(cab.currentUser.uid));
        }
        return _MapModePayload(
          cab: cab,
          customer: widget.cabDriverMode
              ? await MapModesController.loadCustomerContext()
              : null,
        );
      case _MapMode.customerLocations:
        return _MapModePayload(
          customer: await MapModesController.loadCustomerContext(),
        );
      case _MapMode.teamTracking:
        return _MapModePayload(
          team: await MapModesController.loadTeamContext(),
        );
      case _MapMode.officeView:
        final cab = await MapModesController.loadCabContext();
        final team = await MapModesController.loadTeamContext();
        final customer = await MapModesController.loadCustomerContext();
        return _MapModePayload(cab: cab, team: team, customer: customer);
      case _MapMode.fieldEngineer:
        return _MapModePayload(
          team: await MapModesController.loadTeamContext(),
          customer: await MapModesController.loadCustomerContext(),
        );
    }
  }

  Future<_MapModePayload> _loadAndConfigureModePayload(_MapMode mode) async {
    final payload = await _loadModePayload(mode);
    if (widget.cabDriverMode) _animateCabMarker(payload.cab);
    if (mounted && mode == _selectedMode) {
      await _configureModeSync(mode, payload);
    }
    return payload;
  }

  Future<void> _configureModeSync(
    _MapMode mode,
    _MapModePayload payload,
  ) async {
    final cab = payload.cab;
    final memberIds = cab?.members.map((member) => member.userId).toList()
      ?..sort();
    final signature =
        '${mode.name}|${cab?.assignment?.id ?? ''}|'
        '${memberIds?.join(',') ?? ''}';
    if (_modeSyncSignature == signature) return;
    _modeSyncSignature = signature;

    await Future.wait(
      _modeSyncSubscriptions.map((subscription) => subscription.cancel()),
    );
    _modeSyncSubscriptions.clear();

    final streams = switch (mode) {
      _MapMode.fieldEngineer => MapModesController.fieldEngineerChangeStreams(),
      _MapMode.cabTracking when cab != null =>
        MapModesController.cabChangeStreams(),
      _MapMode.customerLocations => MapModesController.customerChangeStreams(),
      _MapMode.teamTracking => MapModesController.teamChangeStreams(),
      _MapMode.officeView when cab != null =>
        MapModesController.officeChangeStreams(),
      _ => const <Stream<void>>[],
    };

    for (final stream in streams) {
      _modeSyncSubscriptions.add(
        stream.listen(
          (_) => _scheduleRealtimeRefresh(mode),
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Map mode realtime listener failed: $error');
            debugPrintStack(stackTrace: stackTrace);
          },
        ),
      );
    }
  }

  void _scheduleRealtimeRefresh(_MapMode mode) {
    _modeSyncDebounce?.cancel();
    _modeSyncDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || mode != _selectedMode) return;
      if (mode == _MapMode.fieldEngineer) {
        unawaited(_refreshMapFromRealtime());
      } else {
        unawaited(_refreshModeFromRealtime(mode));
      }
    });
  }

  Future<void> _refreshMapFromRealtime() async {
    try {
      final data = await _loadMapData();
      if (!mounted || _selectedMode != _MapMode.fieldEngineer) return;
      setState(() {
        _mapFuture = Future<_MapScreenData>.value(data);
      });
    } catch (error, stackTrace) {
      debugPrint('Field Engineer realtime refresh failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _refreshModeFromRealtime(_MapMode mode) async {
    try {
      final payload = await _loadModePayload(mode);
      if (!mounted || mode != _selectedMode) return;
      await _configureModeSync(mode, payload);
      setState(() {
        _modeFuture = Future<_MapModePayload>.value(payload);
      });
    } catch (error, stackTrace) {
      debugPrint('${mode.label} realtime refresh failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _reloadMap() async {
    setState(() {
      _mapFuture = _loadMapData();
      _modeFuture = _loadAndConfigureModePayload(_selectedMode);
      _now = DateTime.now();
    });
    await _mapFuture;
    await _modeFuture;
  }

  Future<void> _reloadMode() async {
    setState(() {
      _modeFuture = _loadAndConfigureModePayload(_selectedMode);
      _now = DateTime.now();
    });
    await _modeFuture;
  }

  void _selectMode(_MapMode mode) {
    if (widget.cabDriverMode) return;
    if (_selectedMode == mode) return;
    setState(() {
      _selectedMode = mode;
      _modeFuture = _loadAndConfigureModePayload(mode);
    });
  }

  Future<void> _loadCabMarkerIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(108, 72);
    final body = Paint()..color = AppColors.primary;
    final glass = Paint()..color = AppColors.info;
    final wheel = Paint()..color = AppColors.background;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 25, 92, 32),
        const Radius.circular(10),
      ),
      body,
    );
    final roof = Path()
      ..moveTo(27, 25)
      ..lineTo(40, 10)
      ..lineTo(76, 10)
      ..lineTo(90, 25)
      ..close();
    canvas.drawPath(roof, body);
    canvas.drawRect(const Rect.fromLTWH(43, 14, 14, 11), glass);
    canvas.drawRect(const Rect.fromLTWH(61, 14, 14, 11), glass);
    canvas.drawCircle(const Offset(30, 58), 9, wheel);
    canvas.drawCircle(const Offset(80, 58), 9, wheel);
    final image = await recorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (!mounted || bytes == null) return;
    setState(() {
      _cabMarkerIcon = BitmapDescriptor.bytes(
        bytes.buffer.asUint8List(),
        width: 54,
        height: 36,
      );
    });
  }

  void _animateCabMarker(CabMapContext? cab) {
    if (cab == null) return;
    final assignment = cab.assignment;
    if (assignment == null) return;
    final location = cab.liveLocationsByUserId[assignment.driverId];
    if (location == null) return;
    final target = LatLng(location.latitude, location.longitude);
    final start = _animatedCabPosition ?? target;
    _cabAnimationTimer?.cancel();
    var step = 0;
    _cabAnimationTimer = Timer.periodic(const Duration(milliseconds: 25), (
      timer,
    ) {
      step++;
      final progress = Curves.easeInOut.transform((step / 20).clamp(0, 1));
      if (mounted) {
        setState(() {
          _animatedCabPosition = LatLng(
            start.latitude + (target.latitude - start.latitude) * progress,
            start.longitude + (target.longitude - start.longitude) * progress,
          );
        });
      }
      if (step >= 20) timer.cancel();
    });
  }

  Future<void> _centerOn(LocationModel location) async {
    final controller = _mapController;
    if (controller == null) return;

    _isCameraAnimating = true;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(location.latitude, location.longitude),
          zoom: 16,
        ),
      ),
    );

    Future<void>.delayed(const Duration(milliseconds: 450), () {
      _isCameraAnimating = false;
    });
  }

  void _toggleMapType() {
    setState(() {
      _mapType = _mapType == MapType.normal ? MapType.hybrid : MapType.normal;
    });
  }

  void _toggleFollowMe(LocationModel location) {
    setState(() {
      _followMe = !_followMe;
    });

    if (!_followMe) return;
    _centerOn(location);
  }

  Future<void> _runCabAction(Future<void> Function() action) async {
    if (_modeActionBusy) return;
    setState(() {
      _modeActionBusy = true;
    });

    try {
      await action();
      await _reloadMode();
    } catch (error, stackTrace) {
      debugPrint('Map action failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to complete action. Please retry.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _modeActionBusy = false;
        });
      }
    }
  }

  Future<void> _startCabTrip(CabMapContext cab) async {
    final assignment = cab.assignment;
    if (assignment == null || !cab.isDriver) {
      throw StateError('Only the assigned driver can start this trip.');
    }

    var session = await LocationController.loadActiveLocationSession(
      cab.currentUser.uid,
    );
    session ??= await LocationController.startLocationSession(
      userId: cab.currentUser.uid,
      trackingReason: LocationTrackingPolicy.reasonCabTrip,
      metadata: <String, dynamic>{
        'assignmentId': assignment.id,
        'vehicleId': assignment.vehicleId,
      },
    );

    await _cabLocationSubscription?.cancel();
    _cabLocationSubscription =
        await LocationController.startForegroundLiveLocationUpdates(
          session: session,
        );

    final now = DateTime.now();
    final activeTrip = cab.activeTrip;
    final trip = activeTrip == null
        ? await CabManagementController.createTrip(
            CabTripModel(
              assignmentId: assignment.id,
              dateKey: assignment.dateKey,
              driverId: assignment.driverId,
              vehicleId: assignment.vehicleId,
              status: 'active',
              activeLocationSessionId: session.id,
              createdAt: now,
              startedAt: now,
              updatedAt: now,
            ),
          )
        : await CabManagementController.updateTrip(
            activeTrip.copyWith(
              status: 'active',
              activeLocationSessionId: session.id,
              startedAt: activeTrip.startedAt ?? now,
              updatedAt: now,
            ),
          );

    await CabManagementController.updateAssignmentStatus(
      assignmentId: assignment.id,
      status: 'started',
    );
    await CabManagementController.addTripEvent(
      CabTripEventModel(
        tripId: trip.id,
        assignmentId: assignment.id,
        actorUserId: cab.currentUser.uid,
        eventType: 'trip_started',
        message: 'Driver started cab trip.',
        createdAt: now,
      ),
    );
  }

  Future<void> _completeCabTrip(CabMapContext cab) async {
    final assignment = cab.assignment;
    if (assignment == null) {
      throw StateError('No cab assignment is selected.');
    }
    final now = DateTime.now();
    final activeTrip = cab.activeTrip;
    if (activeTrip != null) {
      await CabManagementController.updateTrip(
        activeTrip.copyWith(
          status: 'completed',
          completedAt: now,
          updatedAt: now,
        ),
      );
      await CabManagementController.addTripEvent(
        CabTripEventModel(
          tripId: activeTrip.id,
          assignmentId: assignment.id,
          actorUserId: cab.currentUser.uid,
          eventType: 'trip_completed',
          message: 'Cab trip completed.',
          createdAt: now,
        ),
      );
    }

    await CabManagementController.updateAssignmentStatus(
      assignmentId: assignment.id,
      status: 'completed',
    );

    final session = await LocationController.loadActiveLocationSession(
      assignment.driverId,
    );
    if (session != null &&
        session.trackingReason == LocationTrackingPolicy.reasonCabTrip) {
      await LocationController.stopLocationSession(
        session: session,
        stopReason: 'cab_trip_completed',
      );
    }
    await _cabLocationSubscription?.cancel();
    _cabLocationSubscription = null;
  }

  Future<void> _markCabMemberStatus(
    CabMapContext cab,
    CabAssignmentMemberModel member,
    String status,
  ) async {
    final assignment = cab.assignment;
    if (assignment == null || !cab.isDriver) {
      throw StateError('Only the assigned driver can update pickup status.');
    }
    if (member.id.isEmpty) {
      throw StateError('Cab assignment member id is missing.');
    }

    await CabManagementController.updateAssignmentMemberStatus(
      memberId: member.id,
      status: status,
    );

    final now = DateTime.now();
    final trip = cab.activeTrip;
    if (trip == null) return;

    final liveLocation = cab.liveLocationsByUserId[member.userId];
    await CabManagementController.upsertTripRider(
      CabTripRiderModel(
        id: member.userId,
        tripId: trip.id,
        assignmentId: assignment.id,
        employeeId: member.userId,
        status: status,
        pickedUpAt: status == 'picked_up' ? now : null,
        boardedAt: status == 'boarded' ? now : null,
        pickupLatitude: liveLocation?.latitude,
        pickupLongitude: liveLocation?.longitude,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await CabManagementController.addTripEvent(
      CabTripEventModel(
        tripId: trip.id,
        assignmentId: assignment.id,
        actorUserId: cab.currentUser.uid,
        eventType: 'rider_$status',
        message: 'Rider status changed to $status.',
        createdAt: now,
        metadata: <String, dynamic>{'employeeId': member.userId},
      ),
    );
  }

  Future<void> _markEmployeeReady(CabMapContext cab) async {
    final assignment = cab.assignment;
    final member = cab.currentMember;
    if (assignment == null || member == null || !cab.isEmployee) {
      throw StateError('No employee cab assignment found for today.');
    }
    if (member.id.isEmpty) {
      throw StateError('Cab assignment member id is missing.');
    }

    await CabManagementController.updateAssignmentMemberStatus(
      memberId: member.id,
      status: 'ready',
    );

    _employeePickupSession = await LocationController.startLocationSession(
      userId: cab.currentUser.uid,
      trackingReason: LocationTrackingPolicy.reasonCabPickupReady,
      metadata: <String, dynamic>{
        'assignmentId': assignment.id,
        'driverId': assignment.driverId,
      },
    );
    await _cabLocationSubscription?.cancel();
    _cabLocationSubscription =
        await LocationController.startForegroundLiveLocationUpdates(
          session: _employeePickupSession!,
        );
  }

  Future<void> _cancelEmployeePickup(CabMapContext cab) async {
    final member = cab.currentMember;
    if (member == null || member.id.isEmpty) {
      throw StateError('No employee cab assignment found for today.');
    }

    await CabManagementController.updateAssignmentMemberStatus(
      memberId: member.id,
      status: 'assigned',
    );
    await _stopEmployeePickupSharingQuietly(cab.currentUser.uid);
  }

  Future<void> _stopEmployeePickupSharingQuietly(String userId) async {
    final session =
        _employeePickupSession ??
        await LocationController.loadActiveLocationSession(userId);
    if (session == null ||
        session.trackingReason != LocationTrackingPolicy.reasonCabPickupReady) {
      return;
    }

    await _cabLocationSubscription?.cancel();
    _cabLocationSubscription = null;
    _employeePickupSession = null;
    await LocationController.stopLocationSession(
      session: session,
      stopReason: 'cab_pickup_cancelled_or_boarded',
    );
  }

  Future<void> _startCustomerVisit(CustomerVisitModel visit) async {
    await _runCabAction(() async {
      await CustomerVisitController.checkIn(visit);
      await _reloadMap();
    });
  }

  Future<void> _runDutyAction(String action) async {
    if (_modeActionBusy) return;
    setState(() => _modeActionBusy = true);
    try {
      switch (action) {
        case 'start':
          await _startFieldDuty();
          break;
        case 'break':
          await _pauseFieldDuty();
          break;
        case 'resume':
          await _resumeFieldDuty();
          break;
        case 'end':
          await _endFieldDuty();
          break;
      }
      await _reloadMap();
    } catch (error, stackTrace) {
      debugPrint('Duty action failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to complete action. Please retry.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _modeActionBusy = false);
    }
  }

  Future<void> _startFieldDuty() async {
    final permission = await LocationController.checkLocationPermission();
    if (!permission.canUseLocation) {
      final requested = await LocationController.requestLocationPermission();
      if (!requested.canUseLocation) throw StateError(requested.message);
    }
    final attendance = await AttendanceController.checkIn();
    final uid = AuthService.currentUser?.uid;
    if (uid == null || attendance == null) {
      throw StateError('Unable to start duty for the signed-in user.');
    }
    var session = await LocationController.loadActiveLocationSession(uid);
    if (session == null) {
      session = await LocationController.startLocationSession(
        userId: uid,
        trackingReason: LocationTrackingPolicy.reasonFieldDuty,
        metadata: <String, dynamic>{'attendanceId': attendance.id},
      );
    } else if (session.isPaused) {
      session = await LocationController.resumeLocationSession(session);
    }
    await _cabLocationSubscription?.cancel();
    _cabLocationSubscription =
        await LocationController.startForegroundLiveLocationUpdates(
          session: session,
        );
  }

  Future<void> _pauseFieldDuty() async {
    await AttendanceController.startBreak();
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    final session = await LocationController.loadActiveLocationSession(uid);
    await _cabLocationSubscription?.cancel();
    _cabLocationSubscription = null;
    if (session != null && session.isActive) {
      await LocationController.pauseLocationSession(session);
    }
  }

  Future<void> _resumeFieldDuty() async {
    await AttendanceController.endBreak();
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    var session = await LocationController.loadActiveLocationSession(uid);
    if (session == null) {
      session = await LocationController.startLocationSession(
        userId: uid,
        trackingReason: LocationTrackingPolicy.reasonFieldDuty,
      );
    } else if (session.isPaused) {
      session = await LocationController.resumeLocationSession(session);
    }
    await _cabLocationSubscription?.cancel();
    _cabLocationSubscription =
        await LocationController.startForegroundLiveLocationUpdates(
          session: session,
        );
  }

  Future<void> _endFieldDuty() async {
    await AttendanceController.checkOut();
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    final session = await LocationController.loadActiveLocationSession(uid);
    await _cabLocationSubscription?.cancel();
    _cabLocationSubscription = null;
    if (session != null) {
      await LocationController.stopLocationSession(
        session: session,
        stopReason: 'duty_ended',
      );
    }
  }

  Future<void> _focusEmployee(LiveLocationModel? location) async {
    if (location == null || _mapController == null) return;
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(location.latitude, location.longitude),
        17,
      ),
    );
  }

  Future<void> _selectMarker(String markerId, LatLng position) async {
    if (mounted) setState(() => _selectedMarkerId = markerId);
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(CameraUpdate.newLatLngZoom(position, 17));
    await controller.showMarkerInfoWindow(MarkerId(markerId));
  }

  void _showPlaceholder(String label) {
    if (label == 'Global Search') {
      _showSearchFoundation();
      return;
    }
    if (label == 'Map Filters' || label == 'Map Layers') {
      _showFilterFoundation(initialSection: label);
      return;
    }
    if (label == 'Map Legend') {
      _showMapLegend();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label is reserved for the next approved step.')),
    );
  }

  void _showSearchFoundation() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0B0B0B),
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelHeader(title: 'Operations Search'),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Employee, driver, customer, vehicle or visit',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onSubmitted: (_) => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Backend search is not available yet.'),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Search is prepared. Results stay disabled until an indexed search contract is approved.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterFoundation({required String initialSection}) {
    const filters = <String>[
      'Branch',
      'Region',
      'Office',
      'Department',
      'Designation',
      'Engineer',
      'Driver',
      'Vehicle',
      'Visit Status',
      'Attendance',
      'Trip Status',
      'Date',
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0B0B0B),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PanelHeader(title: initialSection),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final filter in filters)
                    _StatusPill(
                      label: filter,
                      color: AppColors.textSecondary,
                      compact: true,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Filter controls are read-only until the corresponding backend fields exist.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMapLegend() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0B0B0B),
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PanelHeader(title: 'Map Legend'),
              SizedBox(height: 12),
              _InlineStatusRow(
                title: 'Active engineer / ready employee',
                meta: 'Green',
                color: AppColors.success,
              ),
              _InlineStatusRow(
                title: 'Cab / current location',
                meta: 'Blue',
                color: AppColors.info,
              ),
              _InlineStatusRow(
                title: 'Break / pending customer',
                meta: 'Yellow',
                color: AppColors.warning,
              ),
              _InlineStatusRow(
                title: 'Office',
                meta: 'Violet',
                color: Color(0xFF9C7CFF),
              ),
              _InlineStatusRow(
                title: 'Selected marker',
                meta: 'Rose',
                color: Color(0xFFFF5A8A),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: FutureBuilder<_MapScreenData>(
        future: _mapFuture,
        builder: (context, mapSnapshot) {
          if (mapSnapshot.connectionState == ConnectionState.waiting) {
            return const _MapLoadingView();
          }

          if (mapSnapshot.hasError) {
            return _MapErrorView(error: mapSnapshot.error, onRetry: _reloadMap);
          }

          final data = mapSnapshot.data;
          if (data == null) {
            return _MapErrorView(
              error: 'Location unavailable',
              onRetry: _reloadMap,
            );
          }

          return FutureBuilder<_MapModePayload>(
            future: _modeFuture,
            builder: (context, modeSnapshot) {
              return _MapExperience(
                data: data,
                now: _now,
                mode: _selectedMode,
                modePayload: modeSnapshot.data ?? const _MapModePayload(),
                modeLoading:
                    modeSnapshot.connectionState == ConnectionState.waiting,
                modeError: modeSnapshot.error,
                modeActionBusy: _modeActionBusy,
                selectedMarkerId: _selectedMarkerId,
                mapType: _mapType,
                followMe: _followMe,
                cabDriverMode: widget.cabDriverMode,
                cabMarkerIcon: _cabMarkerIcon,
                animatedCabPosition: _animatedCabPosition,
                onMapCreated: (controller) {
                  _mapController = controller;
                },
                onCameraMoveStarted: () {
                  if (!_followMe || _isCameraAnimating) return;
                  setState(() {
                    _followMe = false;
                  });
                },
                onModeSelected: _selectMode,
                onModeRetry: _reloadMode,
                onRecenter: () => _centerOn(data.location),
                onToggleMapType: _toggleMapType,
                onToggleFollowMe: () => _toggleFollowMe(data.location),
                onStartCabTrip: (cab) =>
                    _runCabAction(() => _startCabTrip(cab)),
                onCompleteCabTrip: (cab) =>
                    _runCabAction(() => _completeCabTrip(cab)),
                onMarkCabMemberStatus: (cab, member, status) => _runCabAction(
                  () => _markCabMemberStatus(cab, member, status),
                ),
                onEmployeeReady: (cab) =>
                    _runCabAction(() => _markEmployeeReady(cab)),
                onCancelEmployeePickup: (cab) =>
                    _runCabAction(() => _cancelEmployeePickup(cab)),
                onStartCustomerVisit: _startCustomerVisit,
                onDutyAction: _runDutyAction,
                onFocusEmployee: _focusEmployee,
                onMarkerSelected: _selectMarker,
                onPlaceholder: _showPlaceholder,
              );
            },
          );
        },
      ),
    );
  }
}

class _MapExperience extends StatelessWidget {
  final _MapScreenData data;
  final DateTime now;
  final _MapMode mode;
  final _MapModePayload modePayload;
  final bool modeLoading;
  final Object? modeError;
  final bool modeActionBusy;
  final String? selectedMarkerId;
  final MapType mapType;
  final bool followMe;
  final bool cabDriverMode;
  final BitmapDescriptor? cabMarkerIcon;
  final LatLng? animatedCabPosition;
  final ValueChanged<GoogleMapController> onMapCreated;
  final VoidCallback onCameraMoveStarted;
  final ValueChanged<_MapMode> onModeSelected;
  final VoidCallback onModeRetry;
  final VoidCallback onRecenter;
  final VoidCallback onToggleMapType;
  final VoidCallback onToggleFollowMe;
  final ValueChanged<CabMapContext> onStartCabTrip;
  final ValueChanged<CabMapContext> onCompleteCabTrip;
  final void Function(
    CabMapContext cab,
    CabAssignmentMemberModel member,
    String status,
  )
  onMarkCabMemberStatus;
  final ValueChanged<CabMapContext> onEmployeeReady;
  final ValueChanged<CabMapContext> onCancelEmployeePickup;
  final ValueChanged<CustomerVisitModel> onStartCustomerVisit;
  final ValueChanged<String> onDutyAction;
  final ValueChanged<LiveLocationModel?> onFocusEmployee;
  final void Function(String markerId, LatLng position) onMarkerSelected;
  final ValueChanged<String> onPlaceholder;

  const _MapExperience({
    required this.data,
    required this.now,
    required this.mode,
    required this.modePayload,
    required this.modeLoading,
    required this.modeError,
    required this.modeActionBusy,
    required this.selectedMarkerId,
    required this.mapType,
    required this.followMe,
    required this.cabDriverMode,
    required this.cabMarkerIcon,
    required this.animatedCabPosition,
    required this.onMapCreated,
    required this.onCameraMoveStarted,
    required this.onModeSelected,
    required this.onModeRetry,
    required this.onRecenter,
    required this.onToggleMapType,
    required this.onToggleFollowMe,
    required this.onStartCabTrip,
    required this.onCompleteCabTrip,
    required this.onMarkCabMemberStatus,
    required this.onEmployeeReady,
    required this.onCancelEmployeePickup,
    required this.onStartCustomerVisit,
    required this.onDutyAction,
    required this.onFocusEmployee,
    required this.onMarkerSelected,
    required this.onPlaceholder,
  });

  @override
  Widget build(BuildContext context) {
    final position = LatLng(data.location.latitude, data.location.longitude);
    final currentVisit = _currentVisit(data.visits);
    final duty = _DutySnapshot.fromAttendance(data.attendance);

    return Stack(
      fit: StackFit.expand,
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: position, zoom: 16),
          onMapCreated: onMapCreated,
          onCameraMoveStarted: onCameraMoveStarted,
          markers: _markersForMode(
            data,
            mode,
            modePayload,
            selectedMarkerId,
            onMarkerSelected,
            cabMarkerIcon,
            animatedCabPosition,
            cabDriverMode,
          ),
          polylines: _cabRoutePolylines(modePayload.cab),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          indoorViewEnabled: false,
          buildingsEnabled: false,
          trafficEnabled: cabDriverMode,
          compassEnabled: false,
          zoomGesturesEnabled: true,
          scrollGesturesEnabled: true,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: true,
          mapType: mapType,
          style: _darkMapStyle,
        ),
        Positioned(
          left: 14,
          right: 14,
          top: 0,
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TopMapOverlay(duty: duty, now: now),
                const SizedBox(height: 8),
                if (!cabDriverMode) ...[
                  _TrackingModePill(
                    currentMode: mode,
                    onSelected: onModeSelected,
                  ),
                  const SizedBox(height: 8),
                  _AdminStatusStrip(mode: mode, now: now),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          right: 14,
          top: MediaQuery.of(context).padding.top + 166,
          child: _FloatingMapControls(
            followMe: followMe,
            mapType: mapType,
            onRecenter: onRecenter,
            onToggleMapType: onToggleMapType,
            onToggleFollowMe: onToggleFollowMe,
            onRefresh: onModeRetry,
            onUtility: onPlaceholder,
            showUtilities: !cabDriverMode,
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 12,
          child: SafeArea(
            top: false,
            child: _ModeBottomPanel(
              cabDriverMode: cabDriverMode,
              mode: mode,
              location: data.location,
              duty: duty,
              currentVisit: currentVisit,
              payload: modePayload,
              modeLoading: modeLoading,
              modeError: modeError,
              modeActionBusy: modeActionBusy,
              onRetry: onModeRetry,
              onStartCabTrip: onStartCabTrip,
              onCompleteCabTrip: onCompleteCabTrip,
              onMarkCabMemberStatus: onMarkCabMemberStatus,
              onEmployeeReady: onEmployeeReady,
              onCancelEmployeePickup: onCancelEmployeePickup,
              onStartCustomerVisit: onStartCustomerVisit,
              onDutyAction: onDutyAction,
              onFocusEmployee: onFocusEmployee,
              onPlaceholder: onPlaceholder,
            ),
          ),
        ),
      ],
    );
  }
}

class _TopMapOverlay extends StatelessWidget {
  final _DutySnapshot duty;
  final DateTime now;

  const _TopMapOverlay({required this.duty, required this.now});

  @override
  Widget build(BuildContext context) {
    return _MapSurface(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final veryCompact = constraints.maxWidth < 360;
          final status = _StatusPill(
            label: duty.headerLabel,
            color: duty.color,
            compact: true,
          );
          final time = _TimePill(time: _formatClock(now), compact: veryCompact);
          return Row(
            children: [
              const Expanded(child: _OfficeRouteBrand()),
              SizedBox(width: veryCompact ? 6 : 8),
              Flexible(child: status),
              SizedBox(width: veryCompact ? 6 : 8),
              time,
            ],
          );
        },
      ),
    );
  }
}

class _TrackingModePill extends StatelessWidget {
  final _MapMode currentMode;
  final ValueChanged<_MapMode> onSelected;

  const _TrackingModePill({
    required this.currentMode,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: PopupMenuButton<_MapMode>(
        tooltip: 'Select map mode',
        initialValue: currentMode,
        position: PopupMenuPosition.under,
        offset: const Offset(0, 8),
        color: const Color(0xF20B0B0B),
        elevation: 10,
        surfaceTintColor: AppColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.white.withAlpha(34)),
        ),
        onSelected: onSelected,
        itemBuilder: (context) {
          return _MapMode.values
              .map((mode) {
                final selected = mode == currentMode;
                return PopupMenuItem<_MapMode>(
                  value: mode,
                  child: Row(
                    children: [
                      Icon(
                        mode.icon,
                        size: 18,
                        color: selected
                            ? AppColors.info
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          mode.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      if (selected)
                        const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: AppColors.info,
                        ),
                    ],
                  ),
                );
              })
              .toList(growable: false);
        },
        child: _MapSurface(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(currentMode.icon, size: 17, color: AppColors.info),
              const SizedBox(width: 8),
              Text(
                currentMode.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminStatusStrip extends StatelessWidget {
  final _MapMode mode;
  final DateTime now;

  const _AdminStatusStrip({required this.mode, required this.now});

  @override
  Widget build(BuildContext context) {
    return _MapSurface(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _StatusPill(
              label: _formatShortDate(now),
              color: AppColors.textSecondary,
              compact: true,
            ),
            const SizedBox(width: 6),
            const _StatusPill(
              label: 'Firestore Live',
              color: AppColors.success,
              compact: true,
            ),
            const SizedBox(width: 6),
            const _StatusPill(
              label: 'GPS Active',
              color: AppColors.success,
              compact: true,
            ),
            const SizedBox(width: 6),
            const _StatusPill(
              label: 'Internet --',
              color: AppColors.warning,
              compact: true,
            ),
            const SizedBox(width: 6),
            _StatusPill(
              label: mode.label,
              color: AppColors.info,
              compact: true,
            ),
            const SizedBox(width: 6),
            const _StatusPill(
              label: 'All Branches',
              color: AppColors.textSecondary,
              compact: true,
            ),
            const SizedBox(width: 6),
            const _StatusPill(
              label: 'All Regions',
              color: AppColors.textSecondary,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeBottomPanel extends StatelessWidget {
  final bool cabDriverMode;
  final _MapMode mode;
  final LocationModel location;
  final _DutySnapshot duty;
  final CustomerVisitModel? currentVisit;
  final _MapModePayload payload;
  final bool modeLoading;
  final Object? modeError;
  final bool modeActionBusy;
  final VoidCallback onRetry;
  final ValueChanged<CabMapContext> onStartCabTrip;
  final ValueChanged<CabMapContext> onCompleteCabTrip;
  final void Function(
    CabMapContext cab,
    CabAssignmentMemberModel member,
    String status,
  )
  onMarkCabMemberStatus;
  final ValueChanged<CabMapContext> onEmployeeReady;
  final ValueChanged<CabMapContext> onCancelEmployeePickup;
  final ValueChanged<CustomerVisitModel> onStartCustomerVisit;
  final ValueChanged<String> onDutyAction;
  final ValueChanged<LiveLocationModel?> onFocusEmployee;
  final ValueChanged<String> onPlaceholder;

  const _ModeBottomPanel({
    required this.cabDriverMode,
    required this.mode,
    required this.location,
    required this.duty,
    required this.currentVisit,
    required this.payload,
    required this.modeLoading,
    required this.modeError,
    required this.modeActionBusy,
    required this.onRetry,
    required this.onStartCabTrip,
    required this.onCompleteCabTrip,
    required this.onMarkCabMemberStatus,
    required this.onEmployeeReady,
    required this.onCancelEmployeePickup,
    required this.onStartCustomerVisit,
    required this.onDutyAction,
    required this.onFocusEmployee,
    required this.onPlaceholder,
  });

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.47;

    return _MapSurface(
      padding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(child: _buildPanel(context)),
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    if (mode == _MapMode.fieldEngineer) {
      return _FieldEngineerPanel(
        location: location,
        duty: duty,
        currentVisit: currentVisit,
        team: payload.team,
        isBusy: modeActionBusy,
        onDutyAction: onDutyAction,
        onFocusEmployee: onFocusEmployee,
        onPlaceholder: onPlaceholder,
      );
    }

    if (modeLoading) {
      return _ModeLoadingPanel(title: mode.label);
    }

    if (modeError != null) {
      return _ModeErrorPanel(title: mode.label, onRetry: onRetry);
    }

    switch (mode) {
      case _MapMode.cabTracking:
        return _CabTrackingPanel(
          cabDriverMode: cabDriverMode,
          cab: payload.cab,
          isBusy: modeActionBusy,
          onStartTrip: onStartCabTrip,
          onCompleteTrip: onCompleteCabTrip,
          onMarkMemberStatus: onMarkCabMemberStatus,
          onEmployeeReady: onEmployeeReady,
          onCancelEmployeePickup: onCancelEmployeePickup,
          onRefresh: onRetry,
          onPlaceholder: onPlaceholder,
        );
      case _MapMode.customerLocations:
        return _CustomerLocationsPanel(
          contextData: payload.customer,
          isBusy: modeActionBusy,
          onStartVisit: onStartCustomerVisit,
          onPlaceholder: onPlaceholder,
        );
      case _MapMode.teamTracking:
        return _TeamTrackingPanel(
          contextData: payload.team,
          onFocusEmployee: onFocusEmployee,
        );
      case _MapMode.officeView:
        return _OfficeViewPanel(
          cab: payload.cab,
          team: payload.team,
          customer: payload.customer,
        );
      case _MapMode.fieldEngineer:
        return _FieldEngineerPanel(
          location: location,
          duty: duty,
          currentVisit: currentVisit,
          team: payload.team,
          isBusy: modeActionBusy,
          onDutyAction: onDutyAction,
          onFocusEmployee: onFocusEmployee,
          onPlaceholder: onPlaceholder,
        );
    }
  }
}

class _FieldEngineerPanel extends StatelessWidget {
  final LocationModel location;
  final _DutySnapshot duty;
  final CustomerVisitModel? currentVisit;
  final TeamMapContext? team;
  final bool isBusy;
  final ValueChanged<String> onDutyAction;
  final ValueChanged<LiveLocationModel?> onFocusEmployee;
  final ValueChanged<String> onPlaceholder;

  const _FieldEngineerPanel({
    required this.location,
    required this.duty,
    required this.currentVisit,
    required this.team,
    required this.isBusy,
    required this.onDutyAction,
    required this.onFocusEmployee,
    required this.onPlaceholder,
  });

  @override
  Widget build(BuildContext context) {
    final visit = currentVisit;
    final visitLabel = visit == null || visit.customerName.trim().isEmpty
        ? '--'
        : visit.customerName.trim();
    final visitMeta = visit == null
        ? 'No active visit'
        : _titleCase(visit.status.replaceAll('_', ' '));
    final engineers = team?.summaries ?? const <ManagerEmployeeSummaryModel>[];
    final selected = engineers.isEmpty ? null : engineers.first;
    final selectedLocation = selected == null
        ? null
        : team?.liveLocationsByUserId[selected.employee.uid];

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = constraints.maxWidth < 420
            ? (constraints.maxWidth - 8) / 2
            : (constraints.maxWidth - 16) / 3;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PanelHeader(
              title: 'Field Engineer Operations',
              trailing: _StatusPill(
                label: 'GPS Active',
                color: AppColors.success,
                compact: true,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: constraints.maxWidth,
                  child: _InfoTile(
                    icon: Icons.pin_drop_outlined,
                    label: 'Coordinates',
                    value: _formatCoordinates(location),
                    color: AppColors.info,
                  ),
                ),
                _MetricTile(
                  icon: Icons.engineering_outlined,
                  label: 'Engineers Online',
                  value: (team?.activeSummaries.length ?? 0).toString(),
                ),
                _MetricTile(
                  icon: Icons.work_outline_rounded,
                  label: 'On Duty',
                  value: (team?.onDutyCount ?? 0).toString(),
                ),
                _MetricTile(
                  icon: Icons.coffee_outlined,
                  label: 'On Break',
                  value: (team?.onBreakCount ?? 0).toString(),
                ),
                _MetricTile(
                  icon: Icons.wifi_off_outlined,
                  label: 'Offline',
                  value: (team?.offlineCount ?? 0).toString(),
                ),
                _MetricTile(
                  icon: Icons.business_center_outlined,
                  label: 'Active Visits',
                  value: (team?.currentVisitCount ?? 0).toString(),
                ),
                const _MetricTile(
                  icon: Icons.report_problem_outlined,
                  label: 'Active Complaints',
                  value: '--',
                ),
                SizedBox(
                  width: tileWidth,
                  child: const _InfoTile(
                    icon: Icons.gps_fixed_outlined,
                    label: 'GPS Status',
                    value: 'Active',
                    color: AppColors.success,
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: const _InfoTile(
                    icon: Icons.speed_outlined,
                    label: 'Accuracy',
                    value: '--',
                    color: AppColors.warning,
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: _InfoTile(
                    icon: Icons.work_history_outlined,
                    label: 'Working Status',
                    value: duty.detailLabel,
                    color: duty.color,
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  child: _InfoTile(
                    icon: Icons.business_center_outlined,
                    label: 'Current Visit',
                    value: visitLabel,
                    meta: visitMeta,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (selected == null)
              const _DashboardEmptyState(
                icon: Icons.engineering_outlined,
                message: 'No field engineers are available.',
              )
            else ...[
              _TeamEmployeeCard(
                summary: selected,
                location: selectedLocation,
                onTap: () => onFocusEmployee(selectedLocation),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SmallCount(
                    label: "Today's Visits",
                    value: selected.totalVisits,
                  ),
                  _SmallCount(label: 'Active', value: selected.activeVisits),
                  const _SmallCount(label: 'GPS Lost', value: 0),
                  const _SmallCount(label: 'Low Battery', value: 0),
                  const _SmallCount(label: 'Weak Internet', value: 0),
                ],
              ),
              const SizedBox(height: 10),
              _ActionRow(
                children: [
                  _MiniActionButton(
                    icon: Icons.my_location_outlined,
                    label: 'Locate',
                    enabled: selectedLocation != null,
                    onPressed: () => onFocusEmployee(selectedLocation),
                  ),
                  _MiniActionButton(
                    icon: Icons.call_outlined,
                    label: 'Call',
                    enabled: false,
                    onPressed: () => onPlaceholder('Call Engineer'),
                  ),
                  _MiniActionButton(
                    icon: Icons.message_outlined,
                    label: 'Message',
                    enabled: false,
                    onPressed: () => onPlaceholder('Message Engineer'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            _ActionRow(
              children: [
                _MiniActionButton(
                  icon: duty.detailLabel == 'Off Duty'
                      ? Icons.play_arrow_rounded
                      : duty.detailLabel == 'On Break'
                      ? Icons.play_circle_outline_rounded
                      : Icons.coffee_outlined,
                  label: duty.detailLabel == 'Off Duty'
                      ? 'Start Duty'
                      : duty.detailLabel == 'On Break'
                      ? 'Resume'
                      : 'Start Break',
                  enabled: !isBusy && duty.detailLabel != 'Duty Complete',
                  onPressed: () => onDutyAction(
                    duty.detailLabel == 'Off Duty'
                        ? 'start'
                        : duty.detailLabel == 'On Break'
                        ? 'resume'
                        : 'break',
                  ),
                ),
                _MiniActionButton(
                  icon: Icons.stop_circle_outlined,
                  label: 'End Duty',
                  enabled:
                      !isBusy &&
                      duty.detailLabel != 'Off Duty' &&
                      duty.detailLabel != 'Duty Complete',
                  color: AppColors.error,
                  onPressed: () => onDutyAction('end'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CabTrackingPanel extends StatelessWidget {
  final bool cabDriverMode;
  final CabMapContext? cab;
  final bool isBusy;
  final ValueChanged<CabMapContext> onStartTrip;
  final ValueChanged<CabMapContext> onCompleteTrip;
  final void Function(
    CabMapContext cab,
    CabAssignmentMemberModel member,
    String status,
  )
  onMarkMemberStatus;
  final ValueChanged<CabMapContext> onEmployeeReady;
  final ValueChanged<CabMapContext> onCancelEmployeePickup;
  final VoidCallback onRefresh;
  final ValueChanged<String> onPlaceholder;

  const _CabTrackingPanel({
    required this.cabDriverMode,
    required this.cab,
    required this.isBusy,
    required this.onStartTrip,
    required this.onCompleteTrip,
    required this.onMarkMemberStatus,
    required this.onEmployeeReady,
    required this.onCancelEmployeePickup,
    required this.onRefresh,
    required this.onPlaceholder,
  });

  @override
  Widget build(BuildContext context) {
    final data = cab;
    if (data == null) {
      return const _EmptyModePanel(
        title: 'Cab Tracking',
        message: 'Cab data is temporarily unavailable.',
      );
    }
    if (data.assignment == null) {
      return _UnassignedCabPanel(
        cab: data,
        isBusy: isBusy,
        onRefresh: onRefresh,
        onContactManager: () => onPlaceholder('Contact Manager'),
      );
    }

    if (data.canManage) {
      return _ManagerCabPanel(
        cab: data,
        isBusy: isBusy,
        onCompleteTrip: onCompleteTrip,
        onRefresh: onRefresh,
        onPlaceholder: onPlaceholder,
      );
    }

    if (data.isDriver) {
      return _DriverCabPanel(
        readOnlyWorkflow: cabDriverMode,
        cab: data,
        isBusy: isBusy,
        onStartTrip: onStartTrip,
        onCompleteTrip: onCompleteTrip,
        onMarkMemberStatus: onMarkMemberStatus,
        onNavigate: () => onPlaceholder('Navigate'),
      );
    }

    return _EmployeeCabPanel(
      cab: data,
      isBusy: isBusy,
      onEmployeeReady: onEmployeeReady,
      onCancelEmployeePickup: onCancelEmployeePickup,
      onPlaceholder: onPlaceholder,
    );
  }
}

class _UnassignedCabPanel extends StatelessWidget {
  final CabMapContext cab;
  final bool isBusy;
  final VoidCallback onRefresh;
  final VoidCallback onContactManager;

  const _UnassignedCabPanel({
    required this.cab,
    required this.isBusy,
    required this.onRefresh,
    required this.onContactManager,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _PanelHeader(
          title: 'Cab Tracking',
          trailing: _StatusPill(
            label: 'Unassigned',
            color: AppColors.warning,
            compact: true,
          ),
        ),
        const SizedBox(height: 10),
        const _DashboardEmptyState(
          icon: Icons.no_transfer_outlined,
          message: 'No Cab Assigned',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            const _MetricTile(
              icon: Icons.local_taxi_outlined,
              label: 'Vehicle',
              value: 'Unassigned',
            ),
            _MetricTile(
              icon: Icons.person_outline,
              label: 'Driver',
              value: cab.currentUser.role == 'driver'
                  ? cab.currentUser.name
                  : 'Unassigned',
            ),
            const _MetricTile(
              icon: Icons.route_outlined,
              label: 'Trip Status',
              value: 'Not Scheduled',
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SmallCount(label: 'Ready', value: 0),
            _SmallCount(label: 'Boarded', value: 0),
            _SmallCount(label: 'Waiting', value: 0),
          ],
        ),
        const SizedBox(height: 12),
        _ActionRow(
          children: [
            _MiniActionButton(
              icon: Icons.refresh_rounded,
              label: 'Refresh',
              enabled: !isBusy,
              onPressed: onRefresh,
            ),
            _MiniActionButton(
              icon: Icons.support_agent_outlined,
              label: 'Contact Manager',
              enabled: false,
              onPressed: onContactManager,
            ),
          ],
        ),
      ],
    );
  }
}

double? _distanceBetweenLocations(
  LiveLocationModel? from,
  LiveLocationModel? to,
) {
  if (from == null || to == null) return null;
  return LocationTrackingPolicy.distanceMeters(
    from.latitude,
    from.longitude,
    to.latitude,
    to.longitude,
  );
}

int? _etaSecondsForDistance(double? distanceMeters, double? liveSpeed) {
  if (distanceMeters == null) return null;
  final metersPerSecond = liveSpeed != null && liveSpeed > 1 ? liveSpeed : 8.33;
  return (distanceMeters / metersPerSecond).round().clamp(60, 86400).toInt();
}

String _formatPickupDistance(double? distanceMeters) {
  if (distanceMeters == null) return '--';
  if (distanceMeters >= 1000) {
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }
  return '${distanceMeters.round()} m';
}

String _formatPickupEta(int? etaSeconds) {
  if (etaSeconds == null) return '--';
  return '${(etaSeconds / 60).ceil()} min';
}

List<CabAssignmentMemberModel> _pendingPickupMembers(CabMapContext cab) {
  final members = cab.members
      .where(
        (member) =>
            member.role == 'employee' &&
            const {'assigned', 'ready', 'waiting'}.contains(member.status),
      )
      .toList(growable: false);
  members.sort((a, b) {
    const priority = <String, int>{'waiting': 0, 'ready': 1, 'assigned': 2};
    final first = priority[a.status] ?? 9;
    final second = priority[b.status] ?? 9;
    if (first != second) return first.compareTo(second);
    final aName = cab.usersById[a.userId]?.name ?? a.userId;
    final bName = cab.usersById[b.userId]?.name ?? b.userId;
    return aName.toLowerCase().compareTo(bName.toLowerCase());
  });
  return members;
}

class _DriverCabPanel extends StatelessWidget {
  final bool readOnlyWorkflow;
  final CabMapContext cab;
  final bool isBusy;
  final ValueChanged<CabMapContext> onStartTrip;
  final ValueChanged<CabMapContext> onCompleteTrip;
  final void Function(
    CabMapContext cab,
    CabAssignmentMemberModel member,
    String status,
  )
  onMarkMemberStatus;
  final VoidCallback onNavigate;

  const _DriverCabPanel({
    required this.readOnlyWorkflow,
    required this.cab,
    required this.isBusy,
    required this.onStartTrip,
    required this.onCompleteTrip,
    required this.onMarkMemberStatus,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final assignment = cab.assignment!;
    final vehicle = cab.vehicle;
    final driver = cab.usersById[assignment.driverId];
    final tripStatus = cab.activeTrip?.status ?? assignment.status;
    final driverLocation = cab.liveLocationsByUserId[assignment.driverId];
    final pendingMembers = _pendingPickupMembers(cab);
    final nextMember = pendingMembers.isEmpty ? null : pendingMembers.first;
    final nextLocation = nextMember == null
        ? null
        : cab.liveLocationsByUserId[nextMember.userId];
    final distanceMeters = _distanceBetweenLocations(
      driverLocation,
      nextLocation,
    );
    final etaSeconds = _etaSecondsForDistance(
      distanceMeters,
      driverLocation?.speed,
    );
    final nextName = nextMember == null
        ? '--'
        : cab.usersById[nextMember.userId]?.name ?? 'Employee';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _PanelHeader(
          title: 'Driver Cab Tracking',
          trailing: _StatusPill(
            label: _titleCase(tripStatus.replaceAll('_', ' ')),
            color: _cabStatusColor(tripStatus),
            compact: true,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetricTile(
              icon: Icons.person_outline,
              label: 'Driver',
              value: driver?.name ?? '--',
            ),
            _MetricTile(
              icon: Icons.local_taxi_outlined,
              label: 'Vehicle',
              value: vehicle?.vehicleNumber ?? '--',
            ),
            _MetricTile(
              icon: Icons.apartment_outlined,
              label: 'Office',
              value: assignment.officeName.isEmpty
                  ? '--'
                  : assignment.officeName,
            ),
            _MetricTile(
              icon: Icons.alt_route_outlined,
              label: 'Route',
              value: assignment.officeAddress.isNotEmpty
                  ? assignment.officeAddress
                  : (assignment.officeName.isNotEmpty
                        ? assignment.officeName
                        : '--'),
            ),
            _MetricTile(
              icon: Icons.person_pin_circle_outlined,
              label: 'Next Employee',
              value: nextName,
            ),
            _MetricTile(
              icon: Icons.straighten_outlined,
              label: 'Next Distance',
              value: _formatPickupDistance(distanceMeters),
            ),
            _MetricTile(
              icon: Icons.schedule_outlined,
              label: 'Live ETA',
              value: _formatPickupEta(etaSeconds),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _CabCounts(cab: cab),
        const SizedBox(height: 12),
        _DriverPickupQueue(cab: cab, driverLocation: driverLocation),
        const SizedBox(height: 12),
        if (!readOnlyWorkflow) ...[
          _ActionRow(
            children: [
              _MiniActionButton(
                icon: Icons.play_arrow_rounded,
                label: 'Start Trip',
                enabled:
                    !isBusy &&
                    assignment.status != 'started' &&
                    assignment.status != 'completed',
                onPressed: () => onStartTrip(cab),
              ),
              _MiniActionButton(
                icon: Icons.flag_outlined,
                label: 'Complete',
                enabled:
                    !isBusy &&
                    assignment.status != 'completed' &&
                    (assignment.status == 'started' ||
                        cab.activeTrip?.status == 'active'),
                onPressed: () => onCompleteTrip(cab),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _EmployeeActionList(cab: cab, onMarkMemberStatus: onMarkMemberStatus),
        ],
      ],
    );
  }
}

class _DriverPickupQueue extends StatelessWidget {
  final CabMapContext cab;
  final LiveLocationModel? driverLocation;

  const _DriverPickupQueue({required this.cab, required this.driverLocation});

  @override
  Widget build(BuildContext context) {
    final members = cab.members
        .where((member) => member.role == 'employee')
        .toList(growable: false);

    if (members.isEmpty) {
      return const _DashboardEmptyState(
        icon: Icons.groups_outlined,
        message: 'No employees selected for this trip yet.',
      );
    }

    members.sort((a, b) {
      const priority = <String, int>{
        'waiting': 0,
        'ready': 1,
        'assigned': 2,
        'picked_up': 3,
        'boarded': 4,
        'dropped': 5,
        'no_show': 6,
      };
      final first = priority[a.status] ?? 9;
      final second = priority[b.status] ?? 9;
      if (first != second) return first.compareTo(second);
      final aName = cab.usersById[a.userId]?.name ?? a.userId;
      final bName = cab.usersById[b.userId]?.name ?? b.userId;
      return aName.toLowerCase().compareTo(bName.toLowerCase());
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PanelHeader(title: 'Pickup Queue'),
        const SizedBox(height: 8),
        for (final member in members.take(8))
          _DriverPickupQueueRow(
            cab: cab,
            member: member,
            driverLocation: driverLocation,
          ),
      ],
    );
  }
}

class _DriverPickupQueueRow extends StatelessWidget {
  final CabMapContext cab;
  final CabAssignmentMemberModel member;
  final LiveLocationModel? driverLocation;

  const _DriverPickupQueueRow({
    required this.cab,
    required this.member,
    required this.driverLocation,
  });

  @override
  Widget build(BuildContext context) {
    final profile = cab.usersById[member.userId];
    final location = cab.liveLocationsByUserId[member.userId];
    final distance = _distanceBetweenLocations(driverLocation, location);
    final eta = _etaSecondsForDistance(distance, driverLocation?.speed);

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(84),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(22)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.info.withAlpha(24),
                child: Text(
                  profile == null || profile.name.trim().isEmpty
                      ? '?'
                      : profile.name.trim()[0].toUpperCase(),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?.name ?? 'Employee',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_titleCase(member.status.replaceAll('_', ' '))} | '
                      '${_formatPickupDistance(distance)} | '
                      '${_formatPickupEta(eta)}',
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
              const SizedBox(width: 6),
              Icon(
                location == null
                    ? Icons.location_off_outlined
                    : Icons.location_on_outlined,
                color: location == null ? AppColors.warning : AppColors.success,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployeeCabPanel extends StatelessWidget {
  final CabMapContext cab;
  final bool isBusy;
  final ValueChanged<CabMapContext> onEmployeeReady;
  final ValueChanged<CabMapContext> onCancelEmployeePickup;
  final ValueChanged<String> onPlaceholder;

  const _EmployeeCabPanel({
    required this.cab,
    required this.isBusy,
    required this.onEmployeeReady,
    required this.onCancelEmployeePickup,
    required this.onPlaceholder,
  });

  @override
  Widget build(BuildContext context) {
    final assignment = cab.assignment!;
    final member = cab.currentMember;
    final driver = cab.usersById[assignment.driverId];
    final status = member?.status ?? 'assigned';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _PanelHeader(
          title: 'Employee Cab Pickup',
          trailing: _StatusPill(
            label: _titleCase(status.replaceAll('_', ' ')),
            color: _cabStatusColor(status),
            compact: true,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetricTile(
              icon: Icons.person_outline,
              label: 'Driver',
              value: driver?.name ?? '--',
            ),
            _MetricTile(
              icon: Icons.local_taxi_outlined,
              label: 'Cab Number',
              value: cab.vehicle?.vehicleNumber ?? '--',
            ),
            const _MetricTile(
              icon: Icons.timer_outlined,
              label: 'ETA',
              value: 'Placeholder',
            ),
            const _MetricTile(
              icon: Icons.social_distance_outlined,
              label: 'Distance',
              value: 'Placeholder',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ActionRow(
          children: [
            _MiniActionButton(
              icon: Icons.check_circle_outline,
              label: "I'm Ready",
              enabled: !isBusy && status != 'ready' && status != 'boarded',
              onPressed: () => onEmployeeReady(cab),
            ),
            _MiniActionButton(
              icon: Icons.cancel_outlined,
              label: 'Cancel',
              enabled: !isBusy && status == 'ready',
              onPressed: () => onCancelEmployeePickup(cab),
            ),
            _MiniActionButton(
              icon: Icons.emergency_outlined,
              label: 'Emergency',
              enabled: false,
              color: AppColors.error,
              onPressed: () => onPlaceholder('Emergency'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ManagerCabPanel extends StatelessWidget {
  final CabMapContext cab;
  final bool isBusy;
  final ValueChanged<CabMapContext> onCompleteTrip;
  final VoidCallback onRefresh;
  final ValueChanged<String> onPlaceholder;

  const _ManagerCabPanel({
    required this.cab,
    required this.isBusy,
    required this.onCompleteTrip,
    required this.onRefresh,
    required this.onPlaceholder,
  });

  @override
  Widget build(BuildContext context) {
    final assignment = cab.assignment;
    final runningTrips = cab.managerTrips
        .where((trip) => trip.status == 'active')
        .length;
    final completedTrips = cab.managerTrips
        .where((trip) => trip.status == 'completed')
        .length;
    final idleCabs = math.max(0, cab.managerAssignments.length - runningTrips);
    final waitingEmployees = cab.managerMembers
        .where(
          (member) => member.status == 'assigned' || member.status == 'ready',
        )
        .length;
    final pickedUpEmployees = cab.managerMembers
        .where((member) => member.status == 'picked_up')
        .length;
    final boardedEmployees = cab.managerMembers
        .where((member) => member.status == 'boarded')
        .length;
    final remainingEmployees = cab.managerMembers
        .where((member) => member.status == 'assigned')
        .length;
    final driverCount = cab.managerAssignments
        .map((assignment) => assignment.driverId)
        .where((driverId) => driverId.isNotEmpty)
        .toSet()
        .length;
    final driverLocation = assignment == null
        ? null
        : cab.liveLocationsByUserId[assignment.driverId];
    final currentSpeed = driverLocation == null
        ? '--'
        : '${(driverLocation.speed * 3.6).round()} km/h';
    final currentPickup = cab.managerMembers.firstWhere(
      (member) => member.role == 'employee' && member.status == 'ready',
      orElse: () => cab.managerMembers.firstWhere(
        (member) => member.role == 'employee' && member.status == 'assigned',
        orElse: () => CabAssignmentMemberModel(),
      ),
    );
    final nextPickup = cab.managerMembers.firstWhere(
      (member) => member.role == 'employee' && member.status == 'assigned',
      orElse: () => CabAssignmentMemberModel(),
    );
    final currentPickupName = currentPickup.userId.isEmpty
        ? '--'
        : cab.usersById[currentPickup.userId]?.name ?? '--';
    final nextPickupName = nextPickup.userId.isEmpty
        ? '--'
        : cab.usersById[nextPickup.userId]?.name ?? '--';
    final totalAssigned = cab.managerMembers
        .where((member) => member.role == 'employee')
        .length;
    final progressPercent = totalAssigned == 0
        ? 0
        : ((pickedUpEmployees + boardedEmployees) * 100 ~/ totalAssigned);
    final lastSync = driverLocation == null
        ? '--'
        : '${driverLocation.updatedAt.hour.toString().padLeft(2, '0')}:${driverLocation.updatedAt.minute.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _PanelHeader(
          title: 'Manager Cab Dashboard',
          trailing: const _StatusPill(
            label: 'Admin',
            color: AppColors.info,
            compact: true,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetricTile(
              icon: Icons.route_outlined,
              label: 'Running Trips',
              value: runningTrips.toString(),
            ),
            _MetricTile(
              icon: Icons.local_taxi_outlined,
              label: "Today's Active Cabs",
              value: cab.managerAssignments.length.toString(),
            ),
            _MetricTile(
              icon: Icons.groups_outlined,
              label: 'Drivers',
              value: driverCount.toString(),
            ),
            _MetricTile(
              icon: Icons.local_parking_outlined,
              label: 'Idle Cabs',
              value: idleCabs.toString(),
            ),
            _MetricTile(
              icon: Icons.task_alt_outlined,
              label: 'Trips Completed',
              value: completedTrips.toString(),
            ),
            _MetricTile(
              icon: Icons.hourglass_bottom_outlined,
              label: 'Employees Waiting',
              value: waitingEmployees.toString(),
            ),
            _MetricTile(
              icon: Icons.hail_outlined,
              label: 'Picked Up',
              value: pickedUpEmployees.toString(),
            ),
            _MetricTile(
              icon: Icons.event_seat_outlined,
              label: 'Boarded',
              value: boardedEmployees.toString(),
            ),
            _MetricTile(
              icon: Icons.person_off_outlined,
              label: 'Remaining',
              value: remainingEmployees.toString(),
            ),
            _MetricTile(
              icon: Icons.speed_outlined,
              label: 'Current Speed',
              value: currentSpeed,
            ),
            _MetricTile(
              icon: Icons.gps_fixed_outlined,
              label: 'GPS Status',
              value: driverLocation == null ? 'Offline' : 'Active',
            ),
            _MetricTile(
              icon: Icons.sync_outlined,
              label: 'Last Sync',
              value: lastSync,
            ),
            _MetricTile(
              icon: Icons.emoji_transportation_outlined,
              label: 'Trip Progress',
              value: '$progressPercent%',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _InfoTile(
          icon: Icons.person_outline,
          label: 'Driver',
          value: cab.usersById[assignment?.driverId ?? '']?.name ?? '--',
          color: AppColors.info,
        ),
        const SizedBox(height: 6),
        _InfoTile(
          icon: Icons.person_pin_circle_outlined,
          label: 'Current Pickup',
          value: currentPickupName,
          color: AppColors.warning,
        ),
        const SizedBox(height: 6),
        _InfoTile(
          icon: Icons.arrow_forward_outlined,
          label: 'Next Pickup',
          value: nextPickupName,
          color: AppColors.textPrimary,
        ),
        const SizedBox(height: 12),
        _ActionRow(
          children: [
            _MiniActionButton(
              icon: Icons.dashboard_outlined,
              label: 'Open Driver Dashboard',
              enabled: true,
              onPressed: () => onPlaceholder('Open Driver Dashboard'),
            ),
            _MiniActionButton(
              icon: Icons.track_changes_outlined,
              label: 'Track Live',
              enabled: true,
              onPressed: () => onPlaceholder('Track Live'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ActionRow(
          children: [
            _MiniActionButton(
              icon: Icons.call_outlined,
              label: 'Call Driver',
              enabled: true,
              onPressed: () => onPlaceholder('Call Driver'),
            ),
            _MiniActionButton(
              icon: Icons.refresh_rounded,
              label: 'Refresh',
              enabled: !isBusy,
              onPressed: onRefresh,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ActionRow(
          children: [
            _MiniActionButton(
              icon: Icons.flag_outlined,
              label: 'Complete Trip',
              enabled:
                  !isBusy &&
                  cab.canMutateManagement &&
                  assignment != null &&
                  cab.activeTrip != null &&
                  cab.activeTrip!.status == 'active',
              onPressed: () => onCompleteTrip(cab),
            ),
          ],
        ),
      ],
    );
  }
}

class _TeamTrackingPanel extends StatelessWidget {
  final TeamMapContext? contextData;
  final ValueChanged<LiveLocationModel?> onFocusEmployee;

  const _TeamTrackingPanel({
    required this.contextData,
    required this.onFocusEmployee,
  });

  @override
  Widget build(BuildContext context) {
    final data = contextData;
    if (data == null) {
      return const _EmptyModePanel(
        title: 'Team Tracking',
        message: 'Team data is unavailable.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _PanelHeader(title: 'Team Tracking'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetricTile(
              icon: Icons.groups_outlined,
              label: 'Engineers',
              value: data.summaries.length.toString(),
            ),
            _MetricTile(
              icon: Icons.badge_outlined,
              label: 'Drivers',
              value: data.summaries
                  .where((item) => item.employee.role == 'driver')
                  .length
                  .toString(),
            ),
            _MetricTile(
              icon: Icons.admin_panel_settings_outlined,
              label: 'Managers',
              value: data.summaries
                  .where((item) => item.employee.role == 'manager')
                  .length
                  .toString(),
            ),
            _MetricTile(
              icon: Icons.work_outline_rounded,
              label: 'On Duty',
              value: data.onDutyCount.toString(),
            ),
            _MetricTile(
              icon: Icons.coffee_outlined,
              label: 'On Break',
              value: data.onBreakCount.toString(),
            ),
            _MetricTile(
              icon: Icons.wifi_off_outlined,
              label: 'Offline',
              value: data.offlineCount.toString(),
            ),
            const _MetricTile(
              icon: Icons.route_outlined,
              label: 'Traveling',
              value: '--',
            ),
            const _MetricTile(
              icon: Icons.event_busy_outlined,
              label: 'Leave',
              value: '--',
            ),
            _MetricTile(
              icon: Icons.business_center_outlined,
              label: 'Current Visits',
              value: data.currentVisitCount.toString(),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (data.summaries.isEmpty)
          const _DashboardEmptyState(
            icon: Icons.groups_outlined,
            message: 'No employees are available for today.',
          )
        else
          for (final summary in data.summaries.take(8))
            _TeamEmployeeCard(
              summary: summary,
              location: data.liveLocationsByUserId[summary.employee.uid],
              onTap: () => onFocusEmployee(
                data.liveLocationsByUserId[summary.employee.uid],
              ),
            ),
      ],
    );
  }
}

class _TeamEmployeeCard extends StatelessWidget {
  final ManagerEmployeeSummaryModel summary;
  final LiveLocationModel? location;
  final VoidCallback onTap;

  const _TeamEmployeeCard({
    required this.summary,
    required this.location,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final employee = summary.employee;
    final activeVisit = _activeVisitFor(summary.visits);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(84),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withAlpha(22)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.info.withAlpha(28),
                backgroundImage: employee.profileImage.trim().isEmpty
                    ? null
                    : NetworkImage(employee.profileImage),
                child: employee.profileImage.trim().isEmpty
                    ? Text(
                        employee.name.trim().isEmpty
                            ? '?'
                            : employee.name.trim()[0].toUpperCase(),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.name.isEmpty ? 'Employee' : employee.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      activeVisit?.customerName ?? 'No current visit',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      location == null
                          ? 'Location unavailable'
                          : 'Updated ${_relativeTime(location!.updatedAt)}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textDisabled,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(
                label: _titleCase(summary.liveStatus),
                color: _teamStatusColor(summary.liveStatus),
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerLocationsPanel extends StatelessWidget {
  final CustomerMapContext? contextData;
  final bool isBusy;
  final ValueChanged<CustomerVisitModel> onStartVisit;
  final ValueChanged<String> onPlaceholder;

  const _CustomerLocationsPanel({
    required this.contextData,
    required this.isBusy,
    required this.onStartVisit,
    required this.onPlaceholder,
  });

  @override
  Widget build(BuildContext context) {
    final data = contextData;
    if (data == null) {
      return const _EmptyModePanel(
        title: 'Customer Locations',
        message: 'Customer visit data is unavailable.',
      );
    }

    final distance = _visitDistanceLabel(data.visits);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _PanelHeader(title: 'Customer Locations'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetricTile(
              icon: Icons.place_outlined,
              label: "Today's Customers",
              value: data.visits.length.toString(),
            ),
            _MetricTile(
              icon: Icons.pending_actions_outlined,
              label: 'Pending',
              value: data.pendingVisits.length.toString(),
            ),
            _MetricTile(
              icon: Icons.task_alt_outlined,
              label: 'Completed',
              value: data.completedVisits.length.toString(),
            ),
            _MetricTile(
              icon: Icons.social_distance_outlined,
              label: 'Distance',
              value: distance,
            ),
            const _MetricTile(
              icon: Icons.emergency_outlined,
              label: 'Emergency',
              value: '--',
            ),
            const _MetricTile(
              icon: Icons.repeat_rounded,
              label: 'Repeat Customers',
              value: '--',
            ),
            const _MetricTile(
              icon: Icons.verified_user_outlined,
              label: 'Warranty Expiring',
              value: '--',
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (data.visits.isEmpty)
          const _DashboardEmptyState(
            icon: Icons.location_off_outlined,
            message: 'No customer visits are scheduled for today.',
          )
        else
          for (final visit in data.visits.take(8))
            _VisitActionRow(
              visit: visit,
              isBusy: isBusy,
              onStartVisit: onStartVisit,
              onNavigate: () => onPlaceholder('Navigate'),
            ),
      ],
    );
  }
}

class _OfficeViewPanel extends StatelessWidget {
  final CabMapContext? cab;
  final TeamMapContext? team;
  final CustomerMapContext? customer;

  const _OfficeViewPanel({
    required this.cab,
    required this.team,
    required this.customer,
  });

  @override
  Widget build(BuildContext context) {
    final employees = team?.summaries.length ?? 0;
    final present =
        team?.summaries
            .where((summary) => summary.todayAttendance?.checkInTime != null)
            .length ??
        0;
    final visits = customer?.visits ?? const <CustomerVisitModel>[];
    final runningTrips =
        cab?.managerTrips.where((trip) => trip.status == 'active').length ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _PanelHeader(title: 'Office View'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetricTile(
              icon: Icons.how_to_reg_outlined,
              label: "Today's Attendance",
              value: '$present / $employees',
            ),
            _MetricTile(
              icon: Icons.check_circle_outline,
              label: 'Present',
              value: present.toString(),
            ),
            _MetricTile(
              icon: Icons.person_off_outlined,
              label: 'Absent',
              value: (employees - present).toString(),
            ),
            _MetricTile(
              icon: Icons.route_outlined,
              label: 'Running Trips',
              value: runningTrips.toString(),
            ),
            _MetricTile(
              icon: Icons.engineering_outlined,
              label: 'Engineers Active',
              value: (team?.activeSummaries.length ?? 0).toString(),
            ),
            _MetricTile(
              icon: Icons.groups_outlined,
              label: 'Employees',
              value: employees.toString(),
            ),
            _MetricTile(
              icon: Icons.badge_outlined,
              label: 'Drivers',
              value:
                  (team?.summaries
                              .where((item) => item.employee.role == 'driver')
                              .length ??
                          0)
                      .toString(),
            ),
            const _MetricTile(
              icon: Icons.report_problem_outlined,
              label: 'Complaints',
              value: '--',
            ),
            const _MetricTile(
              icon: Icons.payments_outlined,
              label: 'Revenue',
              value: '--',
            ),
            _MetricTile(
              icon: Icons.business_center_outlined,
              label: 'Visits',
              value: visits.length.toString(),
            ),
            _MetricTile(
              icon: Icons.pending_actions_outlined,
              label: 'Pending',
              value: visits
                  .where((visit) => visit.status != 'completed')
                  .length
                  .toString(),
            ),
            _MetricTile(
              icon: Icons.task_alt_outlined,
              label: 'Completed',
              value: visits
                  .where((visit) => visit.status == 'completed')
                  .length
                  .toString(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _PanelHeader(title: 'Recent Activity'),
        const SizedBox(height: 8),
        if (cab?.assignment == null ||
            cab?.assignment?.officeLatitude == null ||
            cab?.assignment?.officeLongitude == null) ...[
          const _DashboardEmptyState(
            icon: Icons.apartment_outlined,
            message: 'No office location is available for today.',
          ),
          const SizedBox(height: 8),
        ],
        if (runningTrips == 0 && present == 0 && visits.isEmpty)
          const _DashboardEmptyState(
            icon: Icons.history_toggle_off_outlined,
            message: 'No operational activity has been recorded today.',
          )
        else ...[
          if (runningTrips > 0)
            _InlineStatusRow(
              title:
                  '$runningTrips cab trip${runningTrips == 1 ? '' : 's'} running',
              meta: 'Live',
              color: AppColors.info,
            ),
          if (present > 0)
            _InlineStatusRow(
              title: '$present employee${present == 1 ? '' : 's'} present',
              meta: 'Today',
              color: AppColors.success,
            ),
          for (final visit in visits.take(3))
            _InlineStatusRow(
              title: visit.customerName.isEmpty
                  ? 'Customer visit'
                  : visit.customerName,
              meta: _titleCase(visit.status.replaceAll('_', ' ')),
              color: visit.status == 'completed'
                  ? AppColors.success
                  : AppColors.warning,
            ),
        ],
      ],
    );
  }
}

class _EmployeeActionList extends StatelessWidget {
  final CabMapContext cab;
  final void Function(
    CabMapContext cab,
    CabAssignmentMemberModel member,
    String status,
  )
  onMarkMemberStatus;

  const _EmployeeActionList({
    required this.cab,
    required this.onMarkMemberStatus,
  });

  @override
  Widget build(BuildContext context) {
    final candidates = cab.members
        .where(
          (member) =>
              member.role == 'employee' &&
              const {
                'assigned',
                'ready',
                'waiting',
                'picked_up',
              }.contains(member.status),
        )
        .take(8)
        .toList(growable: false);

    if (candidates.isEmpty) {
      return const Text(
        'No selected employees yet.',
        style: AppTextStyles.bodyMedium,
      );
    }

    return Column(
      children: [
        for (final member in candidates)
          _EmployeePickupRow(
            cab: cab,
            member: member,
            onMarkMemberStatus: onMarkMemberStatus,
          ),
      ],
    );
  }
}

class _EmployeePickupRow extends StatelessWidget {
  final CabMapContext cab;
  final CabAssignmentMemberModel member;
  final void Function(
    CabMapContext cab,
    CabAssignmentMemberModel member,
    String status,
  )
  onMarkMemberStatus;

  const _EmployeePickupRow({
    required this.cab,
    required this.member,
    required this.onMarkMemberStatus,
  });

  @override
  Widget build(BuildContext context) {
    final profile = cab.usersById[member.userId];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(84),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withAlpha(22)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile?.name ?? 'Employee',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              _ActionRow(
                children: [
                  _MiniActionButton(
                    icon: Icons.near_me_outlined,
                    label: 'Picked Up',
                    enabled: member.status == 'ready',
                    onPressed: () =>
                        onMarkMemberStatus(cab, member, 'picked_up'),
                  ),
                  _MiniActionButton(
                    icon: Icons.event_seat_outlined,
                    label: 'Boarded',
                    enabled:
                        member.status == 'ready' ||
                        member.status == 'picked_up',
                    onPressed: () => onMarkMemberStatus(cab, member, 'boarded'),
                  ),
                  _MiniActionButton(
                    icon: Icons.person_off_outlined,
                    label: 'No Show',
                    enabled: member.status == 'ready',
                    color: AppColors.error,
                    onPressed: () => onMarkMemberStatus(cab, member, 'no_show'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CabCounts extends StatelessWidget {
  final CabMapContext cab;

  const _CabCounts({required this.cab});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _SmallCount(label: 'Assigned', value: cab.members.length),
        _SmallCount(
          label: 'Waiting',
          value: cab.members
              .where((member) => member.status == 'assigned')
              .length,
        ),
        _SmallCount(label: 'Ready', value: cab.readyMembers.length),
        _SmallCount(label: 'Picked Up', value: cab.pickedUpMembers.length),
        _SmallCount(label: 'Boarded', value: cab.boardedMembers.length),
        _SmallCount(label: 'No Show', value: cab.noShowMembers.length),
      ],
    );
  }
}

class _VisitActionRow extends StatelessWidget {
  final CustomerVisitModel visit;
  final bool isBusy;
  final ValueChanged<CustomerVisitModel> onStartVisit;
  final VoidCallback onNavigate;

  const _VisitActionRow({
    required this.visit,
    required this.isBusy,
    required this.onStartVisit,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(84),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withAlpha(22)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visit.customerName.isEmpty
                          ? 'Customer'
                          : visit.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_titleCase(visit.status.replaceAll('_', ' '))} - '
                      'updated ${_relativeTime(visit.updatedAt)}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _IconActionButton(
                icon: Icons.navigation_outlined,
                label: 'Navigate',
                enabled: false,
                onPressed: onNavigate,
              ),
              const SizedBox(width: 8),
              _IconActionButton(
                icon: Icons.play_arrow_rounded,
                label: 'Start Visit',
                enabled: !isBusy && visit.status == 'planned',
                onPressed: () => onStartVisit(visit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _PanelHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class _ModeLoadingPanel extends StatelessWidget {
  final String title;

  const _ModeLoadingPanel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PanelHeader(title: title),
        const SizedBox(height: 12),
        const _PulseDots(),
        const SizedBox(height: 8),
        Text(
          'Loading...',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _ModeErrorPanel extends StatelessWidget {
  final String title;
  final VoidCallback onRetry;

  const _ModeErrorPanel({required this.title, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _PanelHeader(title: title),
        const SizedBox(height: 8),
        Text(
          title == 'Office View' ? 'No Office Data' : 'Unable to load data',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            height: 1.35,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 10),
        _MiniActionButton(
          icon: Icons.refresh_rounded,
          label: 'Retry',
          enabled: true,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

class _EmptyModePanel extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyModePanel({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _PanelHeader(title: title),
        const SizedBox(height: 8),
        Text(
          message,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            height: 1.35,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _DashboardEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _DashboardEmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(84),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(22)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 142,
      child: _InfoTile(
        icon: icon,
        label: label,
        value: value,
        color: AppColors.info,
      ),
    );
  }
}

class _SmallCount extends StatelessWidget {
  final String label;
  final int value;

  const _SmallCount({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(84),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          '$label $value',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _InlineStatusRow extends StatelessWidget {
  final String title;
  final String meta;
  final Color color;

  const _InlineStatusRow({
    required this.title,
    required this.meta,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            meta,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final List<Widget> children;

  const _ActionRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          Expanded(child: children[index]),
          if (index != children.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;
  final Color? color;
  final String disabledTooltip;

  const _MiniActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.color,
  }) : disabledTooltip = 'Coming Soon';

  @override
  Widget build(BuildContext context) {
    final foreground = enabled
        ? (color ?? AppColors.info)
        : AppColors.textDisabled;
    return Tooltip(
      message: enabled ? label : disabledTooltip,
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 16),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          disabledForegroundColor: AppColors.textDisabled,
          side: BorderSide(color: foreground.withAlpha(enabled ? 80 : 40)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;
  final String disabledTooltip;

  const _IconActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.enabled = true,
  }) : disabledTooltip = 'Coming Soon';

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: enabled ? label : disabledTooltip,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(84),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled
                  ? AppColors.info.withAlpha(70)
                  : AppColors.textDisabled.withAlpha(40),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? AppColors.info : AppColors.textDisabled,
          ),
        ),
      ),
    );
  }
}

class _OfficeRouteBrand extends StatelessWidget {
  const _OfficeRouteBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _DotMatrix(),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'OFFICEROUTE',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _DotMatrix extends StatelessWidget {
  const _DotMatrix();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: List<Widget>.generate(
          16,
          (index) => Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: index.isEven
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingMapControls extends StatelessWidget {
  final bool followMe;
  final MapType mapType;
  final VoidCallback onRecenter;
  final VoidCallback onToggleMapType;
  final VoidCallback onToggleFollowMe;
  final VoidCallback onRefresh;
  final ValueChanged<String> onUtility;
  final bool showUtilities;

  const _FloatingMapControls({
    required this.followMe,
    required this.mapType,
    required this.onRecenter,
    required this.onToggleMapType,
    required this.onToggleFollowMe,
    required this.onRefresh,
    required this.onUtility,
    this.showUtilities = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MapControlButton(
          icon: Icons.my_location_outlined,
          label: 'Recenter',
          onPressed: onRecenter,
        ),
        const SizedBox(height: 8),
        _MapControlButton(
          icon: mapType == MapType.normal
              ? Icons.layers_outlined
              : Icons.map_outlined,
          label: 'Map type',
          onPressed: onToggleMapType,
        ),
        const SizedBox(height: 8),
        _MapControlButton(
          icon: followMe ? Icons.navigation : Icons.navigation_outlined,
          label: followMe ? 'Following' : 'Follow me',
          active: followMe,
          onPressed: onToggleFollowMe,
        ),
        const SizedBox(height: 8),
        _MapControlButton(
          icon: Icons.refresh_rounded,
          label: 'Refresh',
          onPressed: onRefresh,
        ),
        if (showUtilities) ...[
          const SizedBox(height: 8),
          _MapUtilitiesMenu(onSelected: onUtility),
        ],
      ],
    );
  }
}

class _MapUtilitiesMenu extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const _MapUtilitiesMenu({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Search, filters and legend',
      color: const Color(0xF20B0B0B),
      surfaceTintColor: AppColors.transparent,
      onSelected: onSelected,
      itemBuilder: (context) => const <PopupMenuEntry<String>>[
        PopupMenuItem(value: 'Global Search', child: Text('Search')),
        PopupMenuItem(value: 'Map Filters', child: Text('Filters')),
        PopupMenuItem(value: 'Map Layers', child: Text('Layers')),
        PopupMenuItem(value: 'Map Legend', child: Text('Legend')),
      ],
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xE60B0B0B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.textPrimary.withAlpha(30)),
        ),
        child: const Icon(
          Icons.tune_rounded,
          color: AppColors.textPrimary,
          size: 21,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? meta;
  final Color color;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.meta,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(84),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withAlpha(22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withAlpha(54)),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (meta != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      meta!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _MapSurface({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xF20B0B0B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(28)),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onPressed;

  const _MapControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.info : AppColors.textPrimary;

    return Tooltip(
      message: label,
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xE60B0B0B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withAlpha(active ? 72 : 30)),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool compact;

  const _StatusPill({
    required this.label,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 11,
          vertical: compact ? 6 : 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimePill extends StatelessWidget {
  final String time;
  final bool compact;

  const _TimePill({required this.time, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(28)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 11,
          vertical: compact ? 7 : 8,
        ),
        child: Text(
          time,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: compact ? 12.5 : null,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _MapLoadingView extends StatelessWidget {
  const _MapLoadingView();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF0B0B0B),
      child: Center(child: _PulseDots()),
    );
  }
}

class _MapErrorView extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _MapErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final normalizedError = '$error'.toLowerCase();
    final message =
        normalizedError.contains('permission') ||
            normalizedError.contains('denied')
        ? 'Location permission denied. Enable location access and retry.'
        : normalizedError.contains('service') || normalizedError.contains('gps')
        ? 'GPS is unavailable. Enable location services and retry.'
        : 'Unable to load data';
    return ColoredBox(
      color: const Color(0xFF0B0B0B),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _MapSurface(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Location unavailable',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headingSmall.copyWith(letterSpacing: 0),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Retry Location'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PulseDots extends StatefulWidget {
  const _PulseDots();

  @override
  State<_PulseDots> createState() => _PulseDotsState();
}

class _PulseDotsState extends State<_PulseDots>
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < 3; index++) ...[
              Opacity(
                opacity: _dotOpacity(index),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.textPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              if (index != 2) const SizedBox(width: 7),
            ],
          ],
        );
      },
    );
  }

  double _dotOpacity(int index) {
    final phase = ((_controller.value - index * 0.18) % 1 + 1) % 1;
    return 0.25 + 0.75 * (1 - (2 * phase - 1).abs());
  }
}

class _MapScreenData {
  final LocationModel location;
  final AttendanceModel? attendance;
  final List<CustomerVisitModel> visits;

  const _MapScreenData({
    required this.location,
    required this.attendance,
    required this.visits,
  });
}

class _MapModePayload {
  final CabMapContext? cab;
  final TeamMapContext? team;
  final CustomerMapContext? customer;

  const _MapModePayload({this.cab, this.team, this.customer});
}

class _DutySnapshot {
  final String headerLabel;
  final String detailLabel;
  final Color color;

  const _DutySnapshot({
    required this.headerLabel,
    required this.detailLabel,
    required this.color,
  });

  factory _DutySnapshot.fromAttendance(AttendanceModel? attendance) {
    if (attendance == null || attendance.checkInTime == null) {
      return const _DutySnapshot(
        headerLabel: 'Off Duty',
        detailLabel: 'Off Duty',
        color: AppColors.textSecondary,
      );
    }

    if (attendance.isOnBreak) {
      return const _DutySnapshot(
        headerLabel: 'On Duty',
        detailLabel: 'On Break',
        color: AppColors.warning,
      );
    }

    if (attendance.isCheckedOut) {
      return const _DutySnapshot(
        headerLabel: 'Off Duty',
        detailLabel: 'Duty Complete',
        color: AppColors.textSecondary,
      );
    }

    return const _DutySnapshot(
      headerLabel: 'On Duty',
      detailLabel: 'On Duty',
      color: AppColors.success,
    );
  }
}

enum _MapMode {
  fieldEngineer,
  cabTracking,
  customerLocations,
  teamTracking,
  officeView,
}

extension _MapModeDetails on _MapMode {
  String get label {
    switch (this) {
      case _MapMode.fieldEngineer:
        return 'Field Engineer';
      case _MapMode.cabTracking:
        return 'Cab Tracking';
      case _MapMode.customerLocations:
        return 'Customer Locations';
      case _MapMode.teamTracking:
        return 'Team Tracking';
      case _MapMode.officeView:
        return 'Office View';
    }
  }

  IconData get icon {
    switch (this) {
      case _MapMode.cabTracking:
        return Icons.local_taxi_outlined;
      case _MapMode.customerLocations:
        return Icons.location_city_outlined;
      case _MapMode.teamTracking:
        return Icons.groups_outlined;
      case _MapMode.officeView:
        return Icons.apartment_outlined;
      case _MapMode.fieldEngineer:
        return Icons.person_pin_circle_outlined;
    }
  }
}

Set<Marker> _markersForMode(
  _MapScreenData data,
  _MapMode mode,
  _MapModePayload payload,
  String? selectedMarkerId,
  void Function(String markerId, LatLng position) onMarkerSelected,
  BitmapDescriptor? cabMarkerIcon,
  LatLng? animatedCabPosition,
  bool cabDriverMode,
) {
  switch (mode) {
    case _MapMode.cabTracking:
    case _MapMode.officeView:
      final markers = _cabMarkers(
        data,
        payload.cab,
        selectedMarkerId,
        onMarkerSelected,
        cabMarkerIcon,
        animatedCabPosition,
      );
      if (cabDriverMode && payload.customer != null) {
        markers.addAll(
          _customerMarkers(
            data,
            payload.customer,
            selectedMarkerId,
            onMarkerSelected,
          ),
        );
      }
      return markers;
    case _MapMode.teamTracking:
      return _teamMarkers(
        data,
        payload.team,
        selectedMarkerId,
        onMarkerSelected,
      );
    case _MapMode.customerLocations:
      return _customerMarkers(
        data,
        payload.customer,
        selectedMarkerId,
        onMarkerSelected,
      );
    case _MapMode.fieldEngineer:
      return payload.team == null
          ? _fieldEngineerMarkers(data, selectedMarkerId, onMarkerSelected)
          : _teamMarkers(
              data,
              payload.team,
              selectedMarkerId,
              onMarkerSelected,
            );
  }
}

Set<Marker> _fieldEngineerMarkers(
  _MapScreenData data,
  String? selectedMarkerId,
  void Function(String markerId, LatLng position) onMarkerSelected,
) {
  final position = LatLng(data.location.latitude, data.location.longitude);
  const markerId = 'current_location';
  return {
    Marker(
      markerId: const MarkerId(markerId),
      position: position,
      icon: _markerIcon(
        selected: selectedMarkerId == markerId,
        hue: BitmapDescriptor.hueAzure,
      ),
      infoWindow: const InfoWindow(title: 'OfficeRoute location'),
      onTap: () => onMarkerSelected(markerId, position),
    ),
  };
}

Set<Marker> _cabMarkers(
  _MapScreenData data,
  CabMapContext? cab,
  String? selectedMarkerId,
  void Function(String markerId, LatLng position) onMarkerSelected,
  BitmapDescriptor? cabMarkerIcon,
  LatLng? animatedCabPosition,
) {
  final markers = <Marker>{
    ..._fieldEngineerMarkers(data, selectedMarkerId, onMarkerSelected),
  };
  final assignment = cab?.assignment;
  if (cab == null || assignment == null) return markers;

  final driverLocation = cab.liveLocationsByUserId[assignment.driverId];
  if (driverLocation != null) {
    const markerId = 'cab_driver';
    final position =
        animatedCabPosition ??
        LatLng(driverLocation.latitude, driverLocation.longitude);
    markers.add(
      Marker(
        markerId: const MarkerId(markerId),
        position: position,
        icon:
            cabMarkerIcon ??
            _markerIcon(
              selected: selectedMarkerId == markerId,
              hue: BitmapDescriptor.hueAzure,
            ),
        infoWindow: InfoWindow(
          title: cab.usersById[assignment.driverId]?.name ?? 'Driver',
          snippet: 'Updated ${_relativeTime(driverLocation.updatedAt)}',
        ),
        onTap: () => onMarkerSelected(markerId, position),
      ),
    );
  }

  for (final member in cab.members.where(
    (member) => member.role == 'employee',
  )) {
    final location = cab.liveLocationsByUserId[member.userId];
    if (location == null) continue;
    final profile = cab.usersById[member.userId];
    final markerId = 'employee_';
    final position = LatLng(location.latitude, location.longitude);
    markers.add(
      Marker(
        markerId: MarkerId(markerId),
        position: position,
        icon: _markerIcon(
          selected: selectedMarkerId == markerId,
          hue: member.status == 'picked_up' || member.status == 'boarded'
              ? BitmapDescriptor.hueOrange
              : member.status == 'waiting' || member.status == 'ready'
              ? BitmapDescriptor.hueGreen
              : BitmapDescriptor.hueYellow,
        ),
        infoWindow: InfoWindow(
          title: profile?.name ?? 'Employee',
          snippet: ' - ',
        ),
        onTap: () => onMarkerSelected(markerId, position),
      ),
    );
  }

  if (assignment.officeLatitude != null && assignment.officeLongitude != null) {
    const markerId = 'office_destination';
    final position = LatLng(
      assignment.officeLatitude!,
      assignment.officeLongitude!,
    );
    markers.add(
      Marker(
        markerId: const MarkerId(markerId),
        position: position,
        icon: _markerIcon(
          selected: selectedMarkerId == markerId,
          hue: BitmapDescriptor.hueViolet,
        ),
        infoWindow: InfoWindow(
          title: assignment.officeName.isEmpty
              ? 'Office'
              : assignment.officeName,
        ),
        onTap: () => onMarkerSelected(markerId, position),
      ),
    );
  }

  for (final fleetAssignment in cab.managerAssignments) {
    if (fleetAssignment.id == assignment.id) continue;
    final location = cab.liveLocationsByUserId[fleetAssignment.driverId];
    if (location != null) {
      final markerId = 'cab_driver_${fleetAssignment.id}';
      final position = LatLng(location.latitude, location.longitude);
      markers.add(
        Marker(
          markerId: MarkerId(markerId),
          position: position,
          icon: _markerIcon(
            selected: selectedMarkerId == markerId,
            hue: BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(
            title: cab.usersById[fleetAssignment.driverId]?.name ?? 'Driver',
            snippet: 'Updated ${_relativeTime(location.updatedAt)}',
          ),
          onTap: () => onMarkerSelected(markerId, position),
        ),
      );
    }

    final officeLatitude = fleetAssignment.officeLatitude;
    final officeLongitude = fleetAssignment.officeLongitude;
    if (officeLatitude != null && officeLongitude != null) {
      final markerId = 'office_${fleetAssignment.id}';
      final position = LatLng(officeLatitude, officeLongitude);
      markers.add(
        Marker(
          markerId: MarkerId(markerId),
          position: position,
          icon: _markerIcon(
            selected: selectedMarkerId == markerId,
            hue: BitmapDescriptor.hueViolet,
          ),
          infoWindow: InfoWindow(
            title: fleetAssignment.officeName.isEmpty
                ? 'Office'
                : fleetAssignment.officeName,
          ),
          onTap: () => onMarkerSelected(markerId, position),
        ),
      );
    }
  }

  final focusedReadyIds = cab.readyMembers.map((item) => item.userId).toSet();
  for (final member in cab.managerReadyMembers) {
    if (focusedReadyIds.contains(member.userId)) continue;
    final location = cab.liveLocationsByUserId[member.userId];
    if (location == null) continue;
    final markerId = 'ready_${member.userId}';
    final position = LatLng(location.latitude, location.longitude);
    markers.add(
      Marker(
        markerId: MarkerId(markerId),
        position: position,
        icon: _markerIcon(
          selected: selectedMarkerId == markerId,
          hue: BitmapDescriptor.hueGreen,
        ),
        infoWindow: InfoWindow(
          title: cab.usersById[member.userId]?.name ?? 'Ready Employee',
          snippet: 'Ready - ${_relativeTime(location.updatedAt)}',
        ),
        onTap: () => onMarkerSelected(markerId, position),
      ),
    );
  }

  return markers;
}

Set<Marker> _teamMarkers(
  _MapScreenData data,
  TeamMapContext? team,
  String? selectedMarkerId,
  void Function(String markerId, LatLng position) onMarkerSelected,
) {
  final markers = <Marker>{
    ..._fieldEngineerMarkers(data, selectedMarkerId, onMarkerSelected),
  };
  if (team == null) return markers;

  for (final summary in team.activeSummaries) {
    final location = team.liveLocationsByUserId[summary.employee.uid];
    if (location == null) continue;
    final markerId = 'team_${summary.employee.uid}';
    final position = LatLng(location.latitude, location.longitude);
    markers.add(
      Marker(
        markerId: MarkerId(markerId),
        position: position,
        icon: _markerIcon(
          selected: selectedMarkerId == markerId,
          hue: summary.liveStatus == 'break'
              ? BitmapDescriptor.hueYellow
              : BitmapDescriptor.hueGreen,
        ),
        infoWindow: InfoWindow(
          title: summary.employee.name,
          snippet:
              '${_titleCase(summary.liveStatus)} - ${_relativeTime(location.updatedAt)}',
        ),
        onTap: () => onMarkerSelected(markerId, position),
      ),
    );
  }

  return markers;
}

Set<Polyline> _cabRoutePolylines(CabMapContext? cab) {
  final assignment = cab?.assignment;
  if (cab == null || assignment == null) return const <Polyline>{};
  final points = <LatLng>[];
  final driver = cab.liveLocationsByUserId[assignment.driverId];
  if (driver != null) points.add(LatLng(driver.latitude, driver.longitude));
  for (final member in cab.readyMembers) {
    final location = cab.liveLocationsByUserId[member.userId];
    if (location != null) {
      points.add(LatLng(location.latitude, location.longitude));
    }
  }
  if (assignment.officeLatitude != null && assignment.officeLongitude != null) {
    points.add(LatLng(assignment.officeLatitude!, assignment.officeLongitude!));
  }
  if (points.length < 2) return const <Polyline>{};
  return {
    Polyline(
      polylineId: const PolylineId('cab_active_route'),
      points: points,
      color: AppColors.info,
      width: 5,
      geodesic: true,
    ),
  };
}

Set<Marker> _customerMarkers(
  _MapScreenData data,
  CustomerMapContext? customer,
  String? selectedMarkerId,
  void Function(String markerId, LatLng position) onMarkerSelected,
) {
  final markers = <Marker>{
    ..._fieldEngineerMarkers(data, selectedMarkerId, onMarkerSelected),
  };
  if (customer == null) return markers;

  for (final visit in customer.visits) {
    final latitude = visit.checkInLatitude ?? visit.checkOutLatitude;
    final longitude = visit.checkInLongitude ?? visit.checkOutLongitude;
    if (latitude == null || longitude == null) continue;
    final markerId = 'customer_${visit.id}';
    final position = LatLng(latitude, longitude);

    markers.add(
      Marker(
        markerId: MarkerId(markerId),
        position: position,
        icon: _markerIcon(
          selected: selectedMarkerId == markerId,
          hue: visit.status == 'completed'
              ? BitmapDescriptor.hueGreen
              : BitmapDescriptor.hueOrange,
        ),
        infoWindow: InfoWindow(
          title: visit.customerName.isEmpty ? 'Customer' : visit.customerName,
          snippet: _titleCase(visit.status.replaceAll('_', ' ')),
        ),
        onTap: () => onMarkerSelected(markerId, position),
      ),
    );
  }

  return markers;
}

BitmapDescriptor _markerIcon({required bool selected, required double hue}) {
  return BitmapDescriptor.defaultMarkerWithHue(
    selected ? BitmapDescriptor.hueRose : hue,
  );
}

CustomerVisitModel? _currentVisit(List<CustomerVisitModel> visits) {
  for (final visit in visits) {
    final activeByTime =
        visit.checkInTime != null && visit.checkOutTime == null;
    final activeByStatus = {
      'checked_in',
      'active',
      'in_progress',
      'on_site',
    }.contains(visit.status.toLowerCase());

    if (activeByTime || activeByStatus) return visit;
  }

  return null;
}

CustomerVisitModel? _activeVisitFor(List<CustomerVisitModel> visits) {
  return _currentVisit(visits);
}

String _relativeTime(DateTime timestamp) {
  final difference = DateTime.now().difference(timestamp);
  if (difference.isNegative || difference.inSeconds < 30) return 'just now';
  if (difference.inMinutes < 1) return '${difference.inSeconds}s ago';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  return '${difference.inDays}d ago';
}

String _visitDistanceLabel(List<CustomerVisitModel> visits) {
  var kilometers = 0.0;
  var hasDistance = false;
  for (final visit in visits) {
    final startLat = visit.checkInLatitude;
    final startLng = visit.checkInLongitude;
    final endLat = visit.checkOutLatitude;
    final endLng = visit.checkOutLongitude;
    if (startLat == null ||
        startLng == null ||
        endLat == null ||
        endLng == null) {
      continue;
    }
    hasDistance = true;
    kilometers += _haversineKilometers(startLat, startLng, endLat, endLng);
  }
  return hasDistance ? '${kilometers.toStringAsFixed(1)} km' : '0.0 km';
}

double _haversineKilometers(
  double latitude1,
  double longitude1,
  double latitude2,
  double longitude2,
) {
  const earthRadiusKm = 6371.0;
  final lat1 = latitude1 * math.pi / 180;
  final lat2 = latitude2 * math.pi / 180;
  final deltaLat = (latitude2 - latitude1) * math.pi / 180;
  final deltaLng = (longitude2 - longitude1) * math.pi / 180;
  final value =
      math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
      math.cos(lat1) *
          math.cos(lat2) *
          math.sin(deltaLng / 2) *
          math.sin(deltaLng / 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(value), math.sqrt(1 - value));
}

String _formatCoordinates(LocationModel location) {
  return '${location.latitude.toStringAsFixed(5)}, '
      '${location.longitude.toStringAsFixed(5)}';
}

String _formatClock(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final suffix = time.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

String _formatShortDate(DateTime date) {
  const months = <String>[
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
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _titleCase(String value) {
  return value
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) {
        if (part.length == 1) return part.toUpperCase();
        return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
      })
      .join(' ');
}

Color _cabStatusColor(String status) {
  switch (status) {
    case 'active':
    case 'started':
    case 'ready':
    case 'picked_up':
      return AppColors.info;
    case 'completed':
    case 'boarded':
      return AppColors.success;
    case 'no_show':
    case 'cancelled':
      return AppColors.error;
    default:
      return AppColors.textSecondary;
  }
}

Color _teamStatusColor(String status) {
  switch (status) {
    case 'online':
      return AppColors.success;
    case 'break':
      return AppColors.warning;
    case 'completed':
      return AppColors.textSecondary;
    default:
      return AppColors.textDisabled;
  }
}

const String _darkMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      { "color": "#0B0B0B" }
    ]
  },
  {
    "elementType": "labels.icon",
    "stylers": [
      { "visibility": "off" }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      { "color": "#8A8A8A" }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      { "color": "#0B0B0B" }
    ]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry",
    "stylers": [
      { "color": "#1F1F1F" }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [
      { "color": "#111111" }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [
      { "color": "#0F1711" }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      { "color": "#1C1C1C" }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [
      { "color": "#2A2A2A" }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      { "color": "#242424" }
    ]
  },
  {
    "featureType": "transit",
    "elementType": "geometry",
    "stylers": [
      { "color": "#101010" }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      { "color": "#050A12" }
    ]
  }
]
''';
