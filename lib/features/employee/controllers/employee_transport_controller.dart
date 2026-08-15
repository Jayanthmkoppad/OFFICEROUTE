import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/models/cab_assignment_member_model.dart';
import '../../../core/models/cab_assignment_model.dart';
import '../../../core/models/cab_trip_model.dart';
import '../../../core/models/cab_trip_rider_model.dart';
import '../../../core/models/cab_vehicle_model.dart';
import '../../../core/models/live_location_model.dart';
import '../../../core/models/location_permission_state_model.dart';
import '../../../core/models/location_session_model.dart';
import '../../../core/models/passenger_progress_model.dart';
import '../../../core/models/shared_map_presence_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/cab_assignment_service.dart';
import '../../../core/services/cab_trip_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/location_tracking_policy.dart';
import '../../../core/services/passenger_progress_service.dart';
import '../../../core/services/shared_map_presence_service.dart';
import '../../attendance/controllers/attendance_controller.dart';
import '../../attendance/models/attendance_model.dart';
import '../../map/controllers/location_controller.dart';

/// Lightweight injectable domain stream factory typedefs
typedef AssignmentStreamFactory =
    Stream<CabAssignmentModel?> Function(String assignmentId);
typedef TripStreamFactory =
    Stream<List<CabTripModel>> Function(String assignmentId);
typedef RiderStreamFactory =
    Stream<CabTripRiderModel?> Function(String tripId, String employeeId);
typedef PassengerProgressStreamFactory =
    Stream<List<PassengerProgressModel>> Function(String tripId);
typedef DriverLocationStreamFactory =
    Stream<LiveLocationModel?> Function(String driverId);
typedef UserStreamFactory = Stream<UserModel?> Function(String userId);
typedef VehicleStreamFactory =
    Stream<CabVehicleModel?> Function(String vehicleId);
typedef CurrentDayRefreshCallback = Future<void> Function(String dateKey);
typedef PickupRequestCreator =
    Future<CabAssignmentMemberModel> Function({
      required String userId,
      required String dateKey,
      required String pickupName,
      required String pickupAddress,
      required double pickupLatitude,
      required double pickupLongitude,
      required String branch,
      required String serviceCentre,
    });
typedef PassengerRemarkUpdater =
    Future<void> Function(String tripId, String employeeId, String remark);
typedef RosterIdentityLoader =
    Future<List<UserModel>> Function(List<String> userIds);

/// Employee action result containing acceptance state and a user-friendly message.
class EmployeeActionResult {
  final bool isAccepted;
  final String message;

  const EmployeeActionResult({required this.isAccepted, required this.message});
}

/// Geofence validation result for "I'm Ready at Pickup".
class GeofenceResult {
  final bool isAccepted;
  final double distanceMeters;
  final String message;

  const GeofenceResult({
    required this.isAccepted,
    required this.distanceMeters,
    required this.message,
  });
}

@immutable
class EmployeeHomeViewState {
  const EmployeeHomeViewState({
    required this.stateCode,
    required this.diagnosticCode,
    required this.activeEmployees,
    required this.readyEmployees,
    required this.onboardEmployees,
    required this.remainingEmployees,
    required this.orderedProgress,
    this.currentPickup,
    this.nextPickup,
  });

  final String stateCode;
  final String diagnosticCode;
  final int activeEmployees;
  final int readyEmployees;
  final int onboardEmployees;
  final int remainingEmployees;
  final List<PassengerProgressModel> orderedProgress;
  final PassengerProgressModel? currentPickup;
  final PassengerProgressModel? nextPickup;
}

/// Native Flutter InheritedNotifier scope for EmployeeTransportController.
class EmployeeTransportScope
    extends InheritedNotifier<EmployeeTransportController> {
  const EmployeeTransportScope({
    super.key,
    required EmployeeTransportController controller,
    required super.child,
  }) : super(notifier: controller);

  static EmployeeTransportController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<EmployeeTransportScope>();
    assert(scope != null, 'No EmployeeTransportScope found in context');
    return scope!.notifier!;
  }
}

/// Single role-level transport coordinator for EmployeeApp.
class EmployeeTransportController extends ChangeNotifier {
  UserModel? currentUser;
  AttendanceModel? todayAttendance;
  CabAssignmentMemberModel? myAssignmentMember;
  CabAssignmentModel? activeAssignment;
  CabTripModel? activeTrip;
  CabTripRiderModel? myRiderRecord;
  LiveLocationModel? driverLiveLocation;
  LiveLocationModel? employeeLiveLocation;
  UserModel? assignedDriver;
  CabVehicleModel? assignedVehicle;

  /// Retained active cab pickup location session
  LocationSessionModel? activeSession;

  /// Assignment ID bound to the active session
  String? trackingAssignmentId;

  /// Pending assignment transition ID
  String? pendingAssignmentId;

  /// Privacy-safe passenger progress list read from `cab_trips/{tripId}/passenger_progress/{employeeId}`.
  List<PassengerProgressModel> passengerProgressList = [];
  List<SharedMapPresenceModel> sharedMapPresence = [];
  List<PassengerProgressModel> _configuredRoster = [];
  List<PassengerProgressModel> _tripProgress = [];
  List<String> _configuredRosterIds = [];
  Map<String, UserModel> _rosterUsersById = {};
  final String _presenceDiagnosticCode = 'ok';
  String rosterDiagnosticCode = 'ok';

  /// Explicit decoupled state indicators
  String attendanceActionState = 'none'; // 'none', 'started', 'failed'
  String transportTrackingState =
      'inactive'; // 'inactive', 'active', 'stop_failed'
  String transportSyncState = 'synced'; // 'synced', 'sync_pending'
  String? transportSyncMessage;

  bool isLoading = true;
  bool isActionLoading = false;
  bool isRefreshing = false;
  String? errorMessage;
  String? locationStopError;
  String? passengerProgressSyncError;
  String locationPermissionStatus = 'Unknown';
  LocationPermissionStateModel? locationPermissionState;
  Position? currentDevicePosition;

  // Generation token for stream sync safety
  int _generationToken = 0;
  bool _isDisposed = false;
  bool _isProgressWriting = false;
  bool _isRetrying = false;

  // Throttling state for passenger progress updates
  DateTime? _lastProgressWriteTime;
  double? _lastProgressWriteDistance;
  String? _lastProgressWriteStatus;

  // Named, replaceable subscriptions
  StreamSubscription? _userSubscription;
  StreamSubscription? _attendanceSubscription;
  StreamSubscription? _memberSubscription;
  StreamSubscription? _assignmentSubscription;
  StreamSubscription? _tripSubscription;
  StreamSubscription? _riderSubscription;
  StreamSubscription? _passengerProgressSubscription;
  StreamSubscription? _driverLocationSubscription;
  StreamSubscription? _driverUserSubscription;
  StreamSubscription? _vehicleSubscription;
  StreamSubscription? _employeeLocationSubscription;
  StreamSubscription? _foregroundTrackingSubscription;
  StreamSubscription? _sharedPresenceSubscription;

  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;

  // Lightweight Injectable Dependencies for real testing
  final String? Function()? currentUidGetter;
  final Future<void> Function()? checkInCallback;
  final Future<bool> Function()? locationServiceChecker;
  final Future<LocationPermissionStateModel> Function()? permissionChecker;
  final Future<LocationPermissionStateModel> Function()? permissionRequester;
  final Future<LocationSessionModel?> Function(String userId)?
  activeSessionLoader;
  final Future<LocationSessionModel> Function({
    required String userId,
    required String trackingReason,
    Map<String, dynamic>? metadata,
  })?
  sessionStarter;
  final Future<LocationSessionModel> Function({
    required LocationSessionModel session,
    required String stopReason,
  })?
  sessionStopper;
  final Future<StreamSubscription> Function({
    required LocationSessionModel session,
    required void Function(LiveLocationModel location) onLocation,
    required void Function(Object error, StackTrace stack) onError,
  })?
  foregroundTrackingStarter;
  final Future<void> Function({
    required String memberId,
    required String status,
  })?
  memberStatusUpdater;
  final Future<void> Function({
    required String tripId,
    required String riderId,
    required Map<String, Object?> fields,
  })?
  riderFieldsUpdater;
  final Future<void> Function(
    String tripId,
    PassengerProgressModel progress, {
    bool isEmployeeRole,
  })?
  progressWriter;
  final Future<Position> Function()? currentPositionGetter;
  final DateTime Function()? clock;
  final CurrentDayRefreshCallback? currentDayRefreshCallback;
  final PickupRequestCreator? pickupRequestCreator;
  final PassengerRemarkUpdater? passengerRemarkUpdater;
  final RosterIdentityLoader? rosterIdentityLoader;

  // Injected Stream Factories
  final AssignmentStreamFactory? assignmentStreamFactory;
  final TripStreamFactory? tripStreamFactory;
  final RiderStreamFactory? riderStreamFactory;
  final PassengerProgressStreamFactory? passengerProgressStreamFactory;
  final DriverLocationStreamFactory? driverLocationStreamFactory;
  final UserStreamFactory? userStreamFactory;
  final VehicleStreamFactory? vehicleStreamFactory;
  final bool _realtimeListenersEnabled;

  String _activeDateKey = '';
  Timer? _minuteTimer;

  String get activeDateKey => _activeDateKey;
  DateTime get currentTime => clock?.call() ?? DateTime.now();

  FirebaseAuth get _authObj => auth ?? FirebaseAuth.instance;
  FirebaseFirestore get _dbObj => firestore ?? FirebaseFirestore.instance;

  EmployeeTransportController({
    this.auth,
    this.firestore,
    this.currentUidGetter,
    this.checkInCallback,
    this.locationServiceChecker,
    this.permissionChecker,
    this.permissionRequester,
    this.activeSessionLoader,
    this.sessionStarter,
    this.sessionStopper,
    this.foregroundTrackingStarter,
    this.memberStatusUpdater,
    this.riderFieldsUpdater,
    this.progressWriter,
    this.currentPositionGetter,
    this.clock,
    this.currentDayRefreshCallback,
    this.pickupRequestCreator,
    this.passengerRemarkUpdater,
    this.rosterIdentityLoader,
    this.assignmentStreamFactory,
    this.tripStreamFactory,
    this.riderStreamFactory,
    this.passengerProgressStreamFactory,
    this.driverLocationStreamFactory,
    this.userStreamFactory,
    this.vehicleStreamFactory,
    bool initListeners = true,
  }) : _realtimeListenersEnabled = initListeners {
    if (initListeners) {
      _initRealtimeListeners();
      updateLocationPermissionStatus();
      _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        unawaited(handleClockTick());
      });
    } else {
      isLoading = false;
    }
    _activeDateKey = _todayDateKey();
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> updateLocationPermissionStatus() async {
    try {
      final checker =
          permissionChecker ?? LocationController.checkLocationPermission;
      final status = await checker();
      locationPermissionState = status;
      locationPermissionStatus = status.canUseLocation ? 'Granted' : 'Denied';
      _safeNotifyListeners();
    } catch (_) {
      locationPermissionState = null;
      locationPermissionStatus = 'Denied';
      _safeNotifyListeners();
    }
  }

  String get locationServiceStatus {
    final state = locationPermissionState;
    if (state == null) return 'Checking';
    return state.serviceEnabled ? 'GPS on' : 'GPS off';
  }

  Future<EmployeeActionResult> refreshDeviceLocation() async {
    await updateLocationPermissionStatus();
    final state = locationPermissionState;
    if (state == null) {
      return const EmployeeActionResult(
        isAccepted: false,
        message: 'Could not check location settings.',
      );
    }
    if (!state.serviceEnabled) {
      return const EmployeeActionResult(
        isAccepted: false,
        message: 'GPS is off. Enable Location Services and retry.',
      );
    }
    if (!state.canUseLocation) {
      final requester =
          permissionRequester ?? LocationController.requestLocationPermission;
      locationPermissionState = await requester();
      locationPermissionStatus = locationPermissionState!.canUseLocation
          ? 'Granted'
          : 'Denied';
      if (!locationPermissionState!.canUseLocation) {
        _safeNotifyListeners();
        return const EmployeeActionResult(
          isAccepted: false,
          message: 'Location permission is not granted.',
        );
      }
    }
    try {
      final getter =
          currentPositionGetter ??
          () => Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
      currentDevicePosition = await getter();
      _safeNotifyListeners();
      return const EmployeeActionResult(
        isAccepted: true,
        message: 'Current location updated.',
      );
    } catch (_) {
      return const EmployeeActionResult(
        isAccepted: false,
        message: 'Could not read the current device location.',
      );
    }
  }

  bool get isSharingMapPresence {
    final uid = currentUser?.uid;
    return uid != null &&
        sharedMapPresence.any(
          (item) => item.userId == uid && item.status == 'active',
        );
  }

  Future<EmployeeActionResult> shareCurrentMapPresence() async {
    final locationResult = await refreshDeviceLocation();
    if (!locationResult.isAccepted || currentDevicePosition == null) {
      return locationResult;
    }
    final uid = currentUidGetter?.call() ?? _authObj.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const EmployeeActionResult(
        isAccepted: false,
        message: 'Employee is not authenticated.',
      );
    }
    try {
      final location = LiveLocationModel.fromPosition(
        userId: uid,
        sessionId: 'manual_map_presence',
        trackingReason: LocationTrackingPolicy.reasonFieldDuty,
        status: LocationTrackingPolicy.statusActive,
        position: currentDevicePosition!,
        isForeground: true,
      );
      await SharedMapPresenceService.publish(location);
      return const EmployeeActionResult(
        isAccepted: true,
        message: 'Your location is now visible on the organization map.',
      );
    } catch (_) {
      return const EmployeeActionResult(
        isAccepted: false,
        message: 'Could not share your map location.',
      );
    }
  }

  Future<EmployeeActionResult> stopCurrentMapPresence() async {
    final uid = currentUidGetter?.call() ?? _authObj.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const EmployeeActionResult(
        isAccepted: false,
        message: 'Employee is not authenticated.',
      );
    }
    try {
      await SharedMapPresenceService.markOffline(uid);
      return const EmployeeActionResult(
        isAccepted: true,
        message: 'Organization map sharing stopped.',
      );
    } catch (_) {
      return const EmployeeActionResult(
        isAccepted: false,
        message: 'Could not stop map sharing.',
      );
    }
  }

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  Future<void> openAppSettings() => Geolocator.openAppSettings();

  Future<EmployeeActionResult> saveTravelLocations({
    required String homeAddress,
    required double homeLatitude,
    required double homeLongitude,
    required String pickupAddress,
    required double pickupLatitude,
    required double pickupLongitude,
  }) async {
    final uid = currentUidGetter?.call() ?? _authObj.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const EmployeeActionResult(
        isAccepted: false,
        message: 'Employee is not authenticated.',
      );
    }
    try {
      await _dbObj.collection('users').doc(uid).update({
        'homeAddress': homeAddress.trim(),
        'homeLatitude': homeLatitude,
        'homeLongitude': homeLongitude,
        'preferredPickupAddress': pickupAddress.trim(),
        'preferredPickupLatitude': pickupLatitude,
        'preferredPickupLongitude': pickupLongitude,
      });
      return const EmployeeActionResult(
        isAccepted: true,
        message:
            'Travel locations saved. Today\'s assigned pickup remains administrator-controlled.',
      );
    } catch (_) {
      return const EmployeeActionResult(
        isAccepted: false,
        message: 'Could not save travel locations.',
      );
    }
  }

  Future<EmployeeActionResult> clearPreferredPickup() async {
    final uid = currentUidGetter?.call() ?? _authObj.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const EmployeeActionResult(
        isAccepted: false,
        message: 'Employee is not authenticated.',
      );
    }
    try {
      await _dbObj.collection('users').doc(uid).update({
        'preferredPickupAddress': null,
        'preferredPickupLatitude': null,
        'preferredPickupLongitude': null,
      });
      return const EmployeeActionResult(
        isAccepted: true,
        message: 'Pickup location cleared.',
      );
    } catch (_) {
      return const EmployeeActionResult(
        isAccepted: false,
        message: 'Could not clear pickup location.',
      );
    }
  }

  bool get hasTodayPickupRequest =>
      myAssignmentMember != null &&
      myAssignmentMember!.dateKey == _activeDateKey &&
      myAssignmentMember!.status != 'cancelled';

  bool get canCancelPickupRequest =>
      hasTodayPickupRequest &&
      myAssignmentMember!.driverId.isEmpty &&
      const {'assigned', 'ready'}.contains(myAssignmentMember!.status);

  Future<EmployeeActionResult> requestPickupForToday() async {
    if (isActionLoading) {
      return const EmployeeActionResult(
        isAccepted: false,
        message: 'A transport update is already in progress.',
      );
    }
    final uid = currentUidGetter?.call() ?? _authObj.currentUser?.uid;
    final user = currentUser;
    if (uid == null || uid.isEmpty || user == null) {
      return const EmployeeActionResult(
        isAccepted: false,
        message: 'Employee is not authenticated.',
      );
    }
    final address = user.preferredPickupAddress.trim();
    final lat = user.preferredPickupLatitude;
    final lng = user.preferredPickupLongitude;
    if (address.isEmpty || lat == null || lng == null) {
      return const EmployeeActionResult(
        isAccepted: false,
        message:
            'Configure an approved pickup address before requesting pickup.',
      );
    }
    isActionLoading = true;
    _safeNotifyListeners();
    try {
      final creator =
          pickupRequestCreator ??
          CabAssignmentService.createEmployeePickupRequest;
      final request = await creator(
        userId: uid,
        dateKey: _activeDateKey,
        pickupName: address,
        pickupAddress: address,
        pickupLatitude: lat,
        pickupLongitude: lng,
        branch: user.branch,
        serviceCentre: user.serviceCentre,
      );
      myAssignmentMember = request;
      errorMessage = null;
      return const EmployeeActionResult(
        isAccepted: true,
        message: 'Pickup requested. Waiting for a Driver.',
      );
    } on FirebaseException catch (error) {
      return EmployeeActionResult(
        isAccepted: false,
        message: error.code == 'permission-denied'
            ? 'Pickup request permission was denied.'
            : 'Could not request pickup. Please retry.',
      );
    } finally {
      isActionLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<EmployeeActionResult> markPickupRequestReady() async {
    final member = myAssignmentMember;
    if (member == null ||
        member.driverId.isNotEmpty ||
        member.status != 'assigned') {
      return const EmployeeActionResult(
        isAccepted: false,
        message: 'Only an unclaimed pickup request can be marked Ready.',
      );
    }
    isActionLoading = true;
    _safeNotifyListeners();
    try {
      final updater =
          memberStatusUpdater ??
          CabAssignmentService.updateEmployeePickupRequestStatus;
      await updater(memberId: member.id, status: 'ready');
      myAssignmentMember = member.copyWith(
        status: 'ready',
        updatedAt: currentTime,
      );
      return const EmployeeActionResult(
        isAccepted: true,
        message: 'Ready for pickup. Waiting for Driver selection.',
      );
    } finally {
      isActionLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<EmployeeActionResult> cancelPickupRequest() async {
    final member = myAssignmentMember;
    if (!canCancelPickupRequest || member == null) {
      return const EmployeeActionResult(
        isAccepted: false,
        message: 'This pickup request can no longer be cancelled.',
      );
    }
    isActionLoading = true;
    _safeNotifyListeners();
    try {
      final updater =
          memberStatusUpdater ??
          CabAssignmentService.updateEmployeePickupRequestStatus;
      await updater(memberId: member.id, status: 'cancelled');
      myAssignmentMember = member.copyWith(
        status: 'cancelled',
        updatedAt: currentTime,
      );
      return const EmployeeActionResult(
        isAccepted: true,
        message: 'Pickup request cancelled.',
      );
    } finally {
      isActionLoading = false;
      _safeNotifyListeners();
    }
  }

  bool get hasTransportInvitation =>
      myAssignmentMember != null &&
      myAssignmentMember!.dateKey == _activeDateKey &&
      myAssignmentMember!.invitationStatus != 'not_invited' &&
      myAssignmentMember!.invitationStatus != 'cancelled';

  bool get canRespondToTransportInvitation =>
      hasTransportInvitation &&
      myAssignmentMember!.invitationStatus == 'invited';

  Future<EmployeeActionResult> acceptTransportInvitation({
    String pickupName = '',
    String pickupAddress = '',
    double? pickupLatitude,
    double? pickupLongitude,
  }) async {
    final member = myAssignmentMember;
    final uid = currentUidGetter?.call() ?? _authObj.currentUser?.uid;
    final user = currentUser;
    if (member == null ||
        uid == null ||
        uid.isEmpty ||
        user == null ||
        !canRespondToTransportInvitation) {
      return const EmployeeActionResult(
        isAccepted: false,
        message: 'Transport invitation is no longer available.',
      );
    }
    final address = pickupAddress.trim().isNotEmpty
        ? pickupAddress.trim()
        : (member.pickupAddress.trim().isNotEmpty
              ? member.pickupAddress.trim()
              : user.preferredPickupAddress.trim());
    final name = pickupName.trim().isNotEmpty
        ? pickupName.trim()
        : (member.pickupName.trim().isNotEmpty
              ? member.pickupName.trim()
              : address);
    final latitude =
        pickupLatitude ?? member.pickupLatitude ?? user.preferredPickupLatitude;
    final longitude =
        pickupLongitude ??
        member.pickupLongitude ??
        user.preferredPickupLongitude;
    if (address.isEmpty || latitude == null || longitude == null) {
      return const EmployeeActionResult(
        isAccepted: false,
        message: 'Set your pickup location',
      );
    }
    isActionLoading = true;
    _safeNotifyListeners();
    try {
      final updated = await CabAssignmentService.respondToTransportInvitation(
        memberId: member.id,
        employeeId: uid,
        accept: true,
        pickupName: name,
        pickupAddress: address,
        pickupLatitude: latitude,
        pickupLongitude: longitude,
      );
      myAssignmentMember = updated;
      return const EmployeeActionResult(
        isAccepted: true,
        message: 'Cab invitation accepted.',
      );
    } catch (_) {
      return const EmployeeActionResult(
        isAccepted: false,
        message: 'Could not accept the cab invitation. Please retry.',
      );
    } finally {
      isActionLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<EmployeeActionResult> declineTransportInvitation({
    String reason = '',
  }) async {
    final member = myAssignmentMember;
    final uid = currentUidGetter?.call() ?? _authObj.currentUser?.uid;
    if (member == null ||
        uid == null ||
        uid.isEmpty ||
        !canRespondToTransportInvitation) {
      return const EmployeeActionResult(
        isAccepted: false,
        message: 'Transport invitation is no longer available.',
      );
    }
    isActionLoading = true;
    _safeNotifyListeners();
    try {
      final updated = await CabAssignmentService.respondToTransportInvitation(
        memberId: member.id,
        employeeId: uid,
        accept: false,
        declineReason: reason,
      );
      myAssignmentMember = updated;
      return const EmployeeActionResult(
        isAccepted: true,
        message: 'Cab invitation declined.',
      );
    } catch (_) {
      return const EmployeeActionResult(
        isAccepted: false,
        message: 'Could not decline the cab invitation. Please retry.',
      );
    } finally {
      isActionLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<void> _initRealtimeListeners() async {
    final uid = currentUidGetter?.call() ?? _authObj.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      isLoading = false;
      errorMessage = 'Could not start transport tracking. Please try again.';
      _safeNotifyListeners();
      return;
    }

    final dateKey = _todayDateKey();
    _activeDateKey = dateKey;
    final nowTime = clock?.call() ?? DateTime.now();

    await _cancelAllSubscriptions();
    // Employee transport uses assignment-scoped live_locations. A broad
    // shared_map_presence query would disclose unrelated users' coordinates.
    sharedMapPresence = const <SharedMapPresenceModel>[];

    // 1. User document stream
    _userSubscription = _dbObj
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
          (snap) {
            if (snap.exists && snap.data() != null) {
              currentUser = UserModel.fromMap(snap.data()!);
              if (currentUser!.uid.isNotEmpty) {
                _rosterUsersById[currentUser!.uid] = currentUser!;
              }
              errorMessage = null;
            } else {
              currentUser = null;
            }
            _refreshConfiguredRosterProjection();
            _safeNotifyListeners();
          },
          onError: (Object err) {
            debugPrint('User stream error: $err');
            errorMessage = 'Could not load user data. Please try again.';
            _safeNotifyListeners();
          },
        );

    // 2. Today Attendance stream
    final todayStart = DateTime(nowTime.year, nowTime.month, nowTime.day);
    _attendanceSubscription = _dbObj
        .collection('attendance')
        .where('userId', isEqualTo: uid)
        .where('date', isEqualTo: Timestamp.fromDate(todayStart))
        .snapshots()
        .listen(
          (snap) {
            if (snap.docs.isNotEmpty) {
              todayAttendance = AttendanceModel.fromMap(
                snap.docs.first.data(),
                id: snap.docs.first.id,
              );
              attendanceActionState = 'started';
            } else {
              todayAttendance = null;
              attendanceActionState = 'none';
            }
            errorMessage = null;
            _refreshConfiguredRosterProjection();
            _safeNotifyListeners();
          },
          onError: (Object err) {
            debugPrint('Attendance stream error: $err');
            errorMessage = 'Could not load attendance details.';
            _safeNotifyListeners();
          },
        );

    // 3. Assignment Member stream
    _memberSubscription = _dbObj
        .collection('cab_assignment_members')
        .where('userId', isEqualTo: uid)
        .where('dateKey', isEqualTo: dateKey)
        .snapshots()
        .listen(
          (querySnap) async {
            QueryDocumentSnapshot<Map<String, dynamic>>? targetDoc;
            for (final doc in querySnap.docs) {
              final dk = doc.data()['dateKey'];
              if (dk == dateKey) {
                targetDoc = doc;
                break;
              }
            }

            if (targetDoc != null && targetDoc.data().isNotEmpty) {
              final newMember = CabAssignmentMemberModel.fromMap(
                targetDoc.data(),
                id: targetDoc.id,
              );
              final oldAssignmentId = myAssignmentMember?.assignmentId;
              myAssignmentMember = newMember;
              _refreshConfiguredRosterProjection();
              final newAssignmentId = newMember.assignmentId;

              if (newAssignmentId.isNotEmpty) {
                if (oldAssignmentId != newAssignmentId) {
                  await _handleAssignmentChange(
                    oldAssignmentId,
                    newAssignmentId,
                    uid,
                  );
                }
              } else {
                await _onAssignmentDeletedOrCleared(
                  stopReason: 'assignment_cleared',
                );
              }
              errorMessage = null;
            } else {
              myAssignmentMember = null;
              await _onAssignmentDeletedOrCleared(
                stopReason: 'assignment_deleted',
              );
            }
            isLoading = false;
            _safeNotifyListeners();
          },
          onError: (Object err) {
            debugPrint('Member stream error: $err');
            errorMessage = 'Could not load transport assignment details.';
            isLoading = false;
            _safeNotifyListeners();
          },
        );

    // 4. Employee's own live location stream
    _employeeLocationSubscription = _dbObj
        .collection('live_locations')
        .doc(uid)
        .snapshots()
        .listen(
          (snap) {
            if (snap.exists && snap.data() != null) {
              employeeLiveLocation = LiveLocationModel.fromMap(snap.data()!);
            } else {
              employeeLiveLocation = null;
            }
            _safeNotifyListeners();
          },
          onError: (Object err) {
            debugPrint('Employee location stream error: $err');
            errorMessage = 'Could not update live location.';
            _safeNotifyListeners();
          },
        );
  }

  void _clearDownstreamState() {
    activeAssignment = null;
    activeTrip = null;
    myRiderRecord = null;
    driverLiveLocation = null;
    assignedDriver = null;
    assignedVehicle = null;
    passengerProgressList = [];
    _configuredRoster = [];
    _tripProgress = [];
    _configuredRosterIds = [];
    _rosterUsersById = {};
    rosterDiagnosticCode = 'ok';
  }

  Future<void> _handleAssignmentChange(
    String? oldId,
    String newId,
    String uid,
  ) async {
    _generationToken++;
    final currentToken = _generationToken;

    // 1. Invalidate & await cancellation of all old downstream listeners
    await _cancelSubscription(_assignmentSubscription);
    _assignmentSubscription = null;
    await _cancelSubscription(_tripSubscription);
    _tripSubscription = null;
    await _cancelSubscription(_driverLocationSubscription);
    _driverLocationSubscription = null;
    await _cancelSubscription(_driverUserSubscription);
    _driverUserSubscription = null;
    await _cancelSubscription(_vehicleSubscription);
    _vehicleSubscription = null;
    await _cancelSubscription(_riderSubscription);
    _riderSubscription = null;
    await _cancelSubscription(_passengerProgressSubscription);
    _passengerProgressSubscription = null;

    // 2. Stop old A pickup session if active
    if (activeSession != null &&
        activeSession!.trackingReason ==
            LocationTrackingPolicy.reasonCabPickupReady &&
        trackingAssignmentId == oldId) {
      final stopSuccess = await _stopLocationTrackingSession(
        stopReason: 'assignment_changed',
      );
      if (!stopSuccess) {
        pendingAssignmentId = newId;
        transportTrackingState = 'stop_failed';
        _safeNotifyListeners();
        return;
      }
    }

    // 3. Clear old downstream state
    _clearDownstreamState();
    pendingAssignmentId = null;

    // 4. Attach B listeners
    await _attachAssignmentListeners(newId, uid, currentToken);
  }

  Future<bool> retryAssignmentTransition() async {
    isActionLoading = true;
    _safeNotifyListeners();

    try {
      final uid = currentUidGetter?.call() ?? _authObj.currentUser?.uid;
      if (uid == null || pendingAssignmentId == null) return false;

      final stopSuccess = await _stopLocationTrackingSession(
        stopReason: 'assignment_changed_retry',
      );
      if (stopSuccess) {
        final bId = pendingAssignmentId!;
        pendingAssignmentId = null;
        _clearDownstreamState();
        _generationToken++;
        await _attachAssignmentListeners(bId, uid, _generationToken);
        return true;
      } else {
        transportTrackingState = 'stop_failed';
        return false;
      }
    } finally {
      isActionLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<void> _attachAssignmentListeners(
    String assignmentId,
    String uid,
    int currentToken,
  ) async {
    final assignStream = assignmentStreamFactory != null
        ? assignmentStreamFactory!(assignmentId)
        : _dbObj
              .collection('cab_assignments')
              .doc(assignmentId)
              .snapshots()
              .map(
                (snap) => snap.exists && snap.data() != null
                    ? CabAssignmentModel.fromMap(snap.data()!, id: snap.id)
                    : null,
              );

    _assignmentSubscription = assignStream.listen(
      (assignment) async {
        if (currentToken != _generationToken) return;
        if (assignment != null) {
          final oldDriverId = activeAssignment?.driverId;
          activeAssignment = assignment;
          await _loadConfiguredRoster(assignment, currentToken);
          _listenToVehicle(activeAssignment!.vehicleId, currentToken);

          if (activeAssignment!.driverId.isNotEmpty) {
            if (oldDriverId != activeAssignment!.driverId) {
              _listenToDriverLocation(activeAssignment!.driverId, currentToken);
              _listenToDriverUser(activeAssignment!.driverId, currentToken);
            }
          } else {
            await _cancelSubscription(_driverLocationSubscription);
            _driverLocationSubscription = null;
            driverLiveLocation = null;
            await _cancelSubscription(_driverUserSubscription);
            _driverUserSubscription = null;
            assignedDriver = null;
          }
          errorMessage = null;
        } else {
          await _onAssignmentDeletedOrCleared(stopReason: 'assignment_deleted');
        }
        _safeNotifyListeners();
      },
      onError: (Object err) {
        if (currentToken != _generationToken) return;
        debugPrint('Assignment stream error: $err');
        errorMessage = 'Could not update cab assignment.';
        _safeNotifyListeners();
      },
    );

    final tripStream = tripStreamFactory != null
        ? tripStreamFactory!(assignmentId)
        : _dbObj
              .collection('cab_trips')
              .where('assignmentId', isEqualTo: assignmentId)
              .snapshots()
              .map(
                (snap) => snap.docs
                    .map((d) => CabTripModel.fromMap(d.data(), id: d.id))
                    .toList(),
              );

    _tripSubscription = tripStream.listen(
      (trips) async {
        if (currentToken != _generationToken) return;
        final validTrips = trips
            .where(
              (trip) =>
                  const <String>{
                    'created',
                    'active',
                    'office_arrived',
                  }.contains(trip.status) &&
                  trip.assignmentId == assignmentId &&
                  trip.dateKey == _activeDateKey &&
                  trip.driverId == activeAssignment?.driverId &&
                  trip.vehicleId == activeAssignment?.vehicleId,
            )
            .toList();

        if (validTrips.isNotEmpty) {
          validTrips.sort((a, b) {
            final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
          final newTrip = validTrips.first;
          final oldTripId = activeTrip?.id;
          activeTrip = newTrip;

          if (oldTripId != activeTrip!.id) {
            _listenToRider(activeTrip!.id, uid, currentToken);
            _listenToPassengerProgress(activeTrip!.id, currentToken);
            await _ensureSelfPassengerProgressCreated();
          }
        } else {
          if (activeTrip != null) {
            final stopSuccess = await _stopLocationTrackingSession(
              stopReason: 'trip_ended',
            );
            if (!stopSuccess) {
              transportTrackingState = 'stop_failed';
            }
          }
          activeTrip = null;
          myRiderRecord = null;
          _tripProgress = [];
          _rebuildRoster();
          await _cancelSubscription(_riderSubscription);
          _riderSubscription = null;
          await _cancelSubscription(_passengerProgressSubscription);
          _passengerProgressSubscription = null;
          if (transportTrackingState != 'stop_failed') {
            transportTrackingState = 'inactive';
          }
        }
        _safeNotifyListeners();
      },
      onError: (Object err) {
        if (currentToken != _generationToken) return;
        debugPrint('Trip stream error: $err');
        errorMessage = 'Could not update trip status.';
        _safeNotifyListeners();
      },
    );
  }

  void _listenToDriverLocation(String driverId, int token) async {
    await _cancelSubscription(_driverLocationSubscription);
    _driverLocationSubscription = null;
    driverLiveLocation = null;

    final driverStream = driverLocationStreamFactory != null
        ? driverLocationStreamFactory!(driverId)
        : _dbObj
              .collection('live_locations')
              .doc(driverId)
              .snapshots()
              .map(
                (snap) => snap.exists && snap.data() != null
                    ? LiveLocationModel.fromMap(snap.data()!)
                    : null,
              );

    _driverLocationSubscription = driverStream.listen(
      (location) {
        if (token != _generationToken) return;
        final assignmentId = activeAssignment?.id ?? '';
        final isAuthorized = isAuthorizedDriverLocation(
          location: location,
          driverId: driverId,
          assignmentId: assignmentId,
        );
        driverLiveLocation = isAuthorized ? location : null;
        errorMessage = null;
        _safeNotifyListeners();
      },
      onError: (Object err) {
        if (token != _generationToken) return;
        debugPrint('Driver location error: $err');
        errorMessage = 'Could not update driver location.';
        _safeNotifyListeners();
      },
    );
  }

  void _listenToDriverUser(String driverId, int token) async {
    await _cancelSubscription(_driverUserSubscription);
    if (token != _generationToken) return;
    final stream = userStreamFactory != null
        ? userStreamFactory!(driverId)
        : _dbObj
              .collection('users')
              .doc(driverId)
              .snapshots()
              .map(
                (snap) => snap.exists && snap.data() != null
                    ? UserModel.fromMap(snap.data()!)
                    : null,
              );
    _driverUserSubscription = stream.listen(
      (driver) {
        if (token != _generationToken) return;
        assignedDriver = driver;
        _safeNotifyListeners();
      },
      onError: (Object error) {
        debugPrint('Driver user stream error: $error');
      },
    );
  }

  void _listenToVehicle(String vehicleId, int token) async {
    await _cancelSubscription(_vehicleSubscription);
    assignedVehicle = null;
    if (vehicleId.isEmpty || token != _generationToken) {
      _safeNotifyListeners();
      return;
    }
    final stream = vehicleStreamFactory != null
        ? vehicleStreamFactory!(vehicleId)
        : _dbObj
              .collection('cab_vehicles')
              .doc(vehicleId)
              .snapshots()
              .map(
                (snap) => snap.exists && snap.data() != null
                    ? CabVehicleModel.fromMap(snap.data()!, id: snap.id)
                    : null,
              );
    _vehicleSubscription = stream.listen(
      (vehicle) {
        if (token != _generationToken) return;
        assignedVehicle = vehicle;
        _safeNotifyListeners();
      },
      onError: (Object error) {
        debugPrint('Vehicle stream error: $error');
      },
    );
  }

  /// Listens ONLY to the signed-in Employee's rider document using `riderStreamFactory` or `riders/{myUid}`
  void _listenToRider(String tripId, String myUid, int token) async {
    await _cancelSubscription(_riderSubscription);
    _riderSubscription = null;
    myRiderRecord = null;

    final rStream = riderStreamFactory != null
        ? riderStreamFactory!(tripId, myUid)
        : _dbObj
              .collection('cab_trips')
              .doc(tripId)
              .collection('riders')
              .doc(myUid)
              .snapshots()
              .map(
                (snap) => snap.exists && snap.data() != null
                    ? CabTripRiderModel.fromMap(snap.data()!, id: snap.id)
                    : null,
              );

    _riderSubscription = rStream.listen(
      (rider) async {
        if (token != _generationToken) return;
        if (rider != null) {
          myRiderRecord = rider;
          final status = rider.status;
          if (status == 'picked_up' ||
              status == 'boarded' ||
              status == 'dropped' ||
              status == 'completed') {
            final stopSuccess = await _stopLocationTrackingSession(
              stopReason: 'rider_status_$status',
            );
            if (!stopSuccess) {
              transportTrackingState = 'stop_failed';
            }
          }
        } else {
          myRiderRecord = null;
        }
        errorMessage = null;
        _safeNotifyListeners();
      },
      onError: (Object err) {
        if (token != _generationToken) return;
        debugPrint('Rider stream error: $err');
        errorMessage = 'Could not update rider status.';
        _safeNotifyListeners();
      },
    );
  }

  void _listenToPassengerProgress(String tripId, int token) async {
    await _cancelSubscription(_passengerProgressSubscription);
    final progStream = passengerProgressStreamFactory != null
        ? passengerProgressStreamFactory!(tripId)
        : PassengerProgressService.watchOwnPassengerProgress(
            tripId,
            currentUidGetter?.call() ?? _authObj.currentUser?.uid ?? '',
          );

    _passengerProgressSubscription = progStream.listen(
      (list) {
        if (token != _generationToken) return;
        _tripProgress = list;
        _rebuildRoster();
        _safeNotifyListeners();
      },
      onError: (Object err) {
        if (token != _generationToken) return;
        debugPrint('Passenger progress stream error: $err');
        errorMessage = 'Could not update passenger progress.';
        _safeNotifyListeners();
      },
    );
  }

  /// Single awaited downstream cleanup method for assignment deletion/removal.
  Future<void> _onAssignmentDeletedOrCleared({
    String stopReason = 'assignment_deleted',
  }) async {
    _generationToken++;
    await _cancelSubscription(_assignmentSubscription);
    _assignmentSubscription = null;
    await _cancelSubscription(_tripSubscription);
    _tripSubscription = null;
    await _cancelSubscription(_driverLocationSubscription);
    _driverLocationSubscription = null;
    await _cancelSubscription(_driverUserSubscription);
    _driverUserSubscription = null;
    await _cancelSubscription(_vehicleSubscription);
    _vehicleSubscription = null;
    await _cancelSubscription(_riderSubscription);
    _riderSubscription = null;
    await _cancelSubscription(_passengerProgressSubscription);
    _passengerProgressSubscription = null;

    activeAssignment = null;
    activeTrip = null;
    myRiderRecord = null;
    passengerProgressList = [];
    _configuredRoster = [];
    _tripProgress = [];
    _configuredRosterIds = [];
    _rosterUsersById = {};
    rosterDiagnosticCode = 'ok';
    driverLiveLocation = null;
    assignedDriver = null;
    assignedVehicle = null;

    final stopSuccess = await _stopLocationTrackingSession(
      stopReason: stopReason,
    );
    if (!stopSuccess) {
      transportTrackingState = 'stop_failed';
    } else {
      transportTrackingState = 'inactive';
    }
  }

  Future<void> _loadConfiguredRoster(
    CabAssignmentModel assignment,
    int token,
  ) async {
    final ids = <String>{
      ...assignment.employeeIds.where(
        (id) => id.trim().isNotEmpty && id != assignment.driverId,
      ),
      if (myAssignmentMember?.assignmentId == assignment.id &&
          myAssignmentMember?.userId.trim().isNotEmpty == true &&
          myAssignmentMember?.userId != assignment.driverId)
        myAssignmentMember!.userId,
    }.toList(growable: false);
    _configuredRosterIds = ids;
    _rosterUsersById = {
      if (currentUser?.uid.isNotEmpty == true) currentUser!.uid: currentUser!,
    };
    if (ids.isEmpty) {
      rosterDiagnosticCode = 'no_configured_members';
      _configuredRoster = [];
      _rebuildRoster();
      return;
    }
    rosterDiagnosticCode = 'loading';
    _refreshConfiguredRosterProjection();
    try {
      final loader = rosterIdentityLoader ?? FirestoreService.fetchUsersByIds;
      final users = await loader(ids);
      if (token != _generationToken) return;
      _rosterUsersById.addAll({
        for (final user in users)
          if (user.uid.isNotEmpty) user.uid: user,
      });
      rosterDiagnosticCode = 'ok';
      _refreshConfiguredRosterProjection();
    } catch (error) {
      debugPrint('Configured transport roster load failed: $error');
      if (token != _generationToken) return;
      rosterDiagnosticCode = _rosterErrorCode(error);
      _refreshConfiguredRosterProjection();
    }
  }

  void _refreshConfiguredRosterProjection() {
    if (_configuredRosterIds.isEmpty) {
      _rebuildRoster();
      return;
    }
    _configuredRoster = [
      for (var index = 0; index < _configuredRosterIds.length; index++)
        _configuredPassenger(
          employeeId: _configuredRosterIds[index],
          user: _rosterUsersById[_configuredRosterIds[index]],
          pickupSequence: index + 1,
        ),
    ];
    _rebuildRoster();
  }

  static String _rosterErrorCode(Object error) {
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') return 'permission_denied';
      if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
        return 'offline';
      }
    }
    return 'query_failed';
  }

  PassengerProgressModel _configuredPassenger({
    required String employeeId,
    required int pickupSequence,
    UserModel? user,
  }) {
    final presence = sharedMapPresence
        .where((item) => item.userId == employeeId)
        .firstOrNull;
    final isMe = employeeId == currentUser?.uid;
    final attendanceActive = isMe && todayAttendance?.isCheckedIn == true;
    final ownPermissionDenied =
        isMe &&
        (locationPermissionStatus == 'Denied' ||
            locationPermissionState?.canUseForegroundLocation == false);
    final freshness = ownPermissionDenied
        ? 'permission_denied'
        : presence == null
        ? _presenceDiagnosticCode == 'permission_denied'
              ? 'permission_denied'
              : _presenceDiagnosticCode == 'offline' || attendanceActive
              ? 'offline'
              : 'not_started'
        : currentTime.difference(presence.updatedAt).inMinutes >= 2
        ? 'stale'
        : presence.status == 'active'
        ? 'live'
        : 'offline';
    final role = (user?.role ?? presence?.role ?? 'employee')
        .trim()
        .toLowerCase();
    final roleLabel =
        const {
          'admin',
          'administrator',
          'application_owner',
          'owner',
        }.contains(role)
        ? 'Administrator'
        : role == 'manager'
        ? 'Manager'
        : 'Employee';
    final memberStatus = isMe ? myAssignmentMember?.status : null;
    final configuredStatus = switch (memberStatus) {
      'travelling_to_pickup' => 'on_the_way',
      'ready' => 'ready',
      'not_coming' => 'not_coming',
      'running_late' => 'running_late',
      _ => attendanceActive || presence != null ? 'waiting' : 'not_started',
    };
    return PassengerProgressModel(
      employeeId: employeeId,
      passengerDisplayName: user?.name.trim().isNotEmpty == true
          ? user!.name
          : presence?.displayName.trim().isNotEmpty == true
          ? presence!.displayName
          : 'Route member',
      employeeCode: user?.employeeCode ?? '',
      roleLabel: roleLabel,
      pickupSequence: pickupSequence,
      status: configuredStatus,
      attendanceActive: attendanceActive || presence != null,
      transportActive: true,
      locationFreshness: freshness,
      updatedAt: presence?.updatedAt,
    );
  }

  void _rebuildRoster() {
    passengerProgressList = mergeTransportRoster(
      configured: _configuredRoster,
      progress: _tripProgress,
    );
  }

  bool get canUpdateOwnTransportStatus =>
      activeTrip != null &&
      currentUser?.uid.isNotEmpty == true &&
      passengerProgressList.any(
        (item) => item.employeeId == currentUser!.uid && item.transportActive,
      );

  @visibleForTesting
  static List<PassengerProgressModel> mergeTransportRoster({
    required List<PassengerProgressModel> configured,
    required List<PassengerProgressModel> progress,
  }) {
    final byId = <String, PassengerProgressModel>{
      for (final item in configured) item.employeeId: item,
    };
    for (final update in progress) {
      final base = byId[update.employeeId];
      byId[update.employeeId] = base == null
          ? update
          : PassengerProgressModel(
              employeeId: base.employeeId,
              passengerDisplayName: update.passengerDisplayName == 'Passenger'
                  ? base.passengerDisplayName
                  : update.passengerDisplayName,
              employeeCode: update.employeeCode.isEmpty
                  ? base.employeeCode
                  : update.employeeCode,
              roleLabel: update.roleLabel == 'Employee'
                  ? base.roleLabel
                  : update.roleLabel,
              pickupSequence: update.pickupSequence > 0
                  ? update.pickupSequence
                  : base.pickupSequence,
              status: update.status,
              remark: update.remark,
              attendanceActive:
                  update.attendanceActive || base.attendanceActive,
              transportActive: update.transportActive,
              distanceToPickupMeters: update.distanceToPickupMeters,
              estimatedReadyMinutes: update.estimatedReadyMinutes,
              locationFreshness: update.locationFreshness == 'unknown'
                  ? base.locationFreshness
                  : update.locationFreshness,
              updatedAt: update.updatedAt ?? base.updatedAt,
            );
    }
    final result = byId.values.toList()
      ..sort((a, b) => a.pickupSequence.compareTo(b.pickupSequence));
    return result;
  }

  Future<bool> _stopLocationTrackingSession({
    String stopReason = 'cab_pickup_completed',
  }) async {
    locationStopError = null;
    if (activeSession != null) {
      try {
        final stopper =
            sessionStopper ?? LocationController.stopLocationSession;
        await stopper(session: activeSession!, stopReason: stopReason);
        activeSession = null;
        trackingAssignmentId = null;
      } catch (e) {
        debugPrint('Location session stop error: $e');
        locationStopError =
            'Could not stop location sharing. Check your connection and try again.';
        _safeNotifyListeners();
        return false;
      }
    }

    if (_foregroundTrackingSubscription != null) {
      await _foregroundTrackingSubscription!.cancel();
      _foregroundTrackingSubscription = null;
    }
    transportTrackingState = 'inactive';
    if (employeeLiveLocation != null) {
      employeeLiveLocation = employeeLiveLocation!.copyWith(status: 'offline');
    }
    return true;
  }

  /// Explicit retry method for location session teardown failure.
  Future<bool> retryStopLocationSharing() async {
    isActionLoading = true;
    _safeNotifyListeners();

    if (activeSession?.trackingReason !=
        LocationTrackingPolicy.reasonCabPickupReady) {
      isActionLoading = false;
      _safeNotifyListeners();
      return false;
    }

    final success = await _stopLocationTrackingSession(
      stopReason: 'retry_stop',
    );
    if (success) {
      transportTrackingState = 'inactive';
      activeSession = null;
      trackingAssignmentId = null;
      locationStopError = null;
    } else {
      transportTrackingState = 'stop_failed';
    }
    isActionLoading = false;
    _safeNotifyListeners();
    return success;
  }

  /// Async subscription cancellation helper.
  Future<void> _cancelSubscription(StreamSubscription? sub) async {
    if (sub != null) {
      await sub.cancel();
    }
  }

  Future<void> _cancelAllSubscriptions() async {
    _generationToken++;
    await _cancelSubscription(_userSubscription);
    _userSubscription = null;
    await _cancelSubscription(_attendanceSubscription);
    _attendanceSubscription = null;
    await _cancelSubscription(_memberSubscription);
    _memberSubscription = null;
    await _cancelSubscription(_assignmentSubscription);
    _assignmentSubscription = null;
    await _cancelSubscription(_tripSubscription);
    _tripSubscription = null;
    await _cancelSubscription(_riderSubscription);
    _riderSubscription = null;
    await _cancelSubscription(_passengerProgressSubscription);
    _passengerProgressSubscription = null;
    await _cancelSubscription(_driverLocationSubscription);
    _driverLocationSubscription = null;
    await _cancelSubscription(_driverUserSubscription);
    _driverUserSubscription = null;
    await _cancelSubscription(_vehicleSubscription);
    _vehicleSubscription = null;
    await _cancelSubscription(_employeeLocationSubscription);
    _employeeLocationSubscription = null;
    await _cancelSubscription(_foregroundTrackingSubscription);
    _foregroundTrackingSubscription = null;
    await _cancelSubscription(_sharedPresenceSubscription);
    _sharedPresenceSubscription = null;

    if (transportTrackingState != 'stop_failed') {
      transportTrackingState = 'inactive';
    }
  }

  /// Pure connection/location status resolver.
  String get connectionStatus {
    if (locationPermissionState?.serviceEnabled == false) {
      return 'GPS OFF';
    }
    if (locationPermissionStatus == 'Denied') {
      return 'LOCATION OFF';
    }
    if (errorMessage != null) {
      return 'OFFLINE';
    }

    if (activeSession != null && transportTrackingState == 'active') {
      if (employeeLiveLocation == null) {
        return 'WAITING FOR LOCATION';
      }
      final nowTime = clock?.call() ?? DateTime.now();
      final isDriverStale =
          driverLiveLocation != null &&
          LocationTrackingPolicy.isStale(
            driverLiveLocation!.updatedAt,
            nowTime,
          );
      final isSelfStale =
          employeeLiveLocation != null &&
          LocationTrackingPolicy.isStale(
            employeeLiveLocation!.updatedAt,
            nowTime,
          );
      if (isDriverStale || isSelfStale) {
        return 'STALE';
      }
      if (activeAssignment != null && driverLiveLocation == null) {
        return 'WAITING FOR DRIVER';
      }
      return 'TRACKING';
    }

    if (todayAttendance?.status == 'Checked In' && myAssignmentMember == null) {
      return 'WAITING FOR ROUTE';
    }

    if (activeAssignment != null && driverLiveLocation == null) {
      return 'WAITING FOR DRIVER';
    }

    return 'OFFLINE';
  }

  /// Evaluates real location status for Profile display.
  String get profileLocationStatus {
    if (activeSession == null || transportTrackingState != 'active') {
      return 'Inactive';
    }
    if (employeeLiveLocation == null) {
      return 'Waiting for location';
    }
    if (employeeLiveLocation!.status != LocationTrackingPolicy.statusActive) {
      return 'Offline';
    }
    final nowTime = clock?.call() ?? DateTime.now();
    if (LocationTrackingPolicy.isStale(
      employeeLiveLocation!.updatedAt,
      nowTime,
    )) {
      return 'Stale';
    }
    return 'Active';
  }

  /// Calculates Employee distance to Saved Pickup Point using LocationTrackingPolicy.
  double? get employeeDistanceToPickupMeters {
    final lat = myAssignmentMember?.pickupLatitude;
    final lng = myAssignmentMember?.pickupLongitude;
    final selfLoc = employeeLiveLocation;
    if (lat == null ||
        lng == null ||
        lat == 0.0 ||
        lng == 0.0 ||
        selfLoc == null) {
      return null;
    }
    return LocationTrackingPolicy.distanceMeters(
      selfLoc.latitude,
      selfLoc.longitude,
      lat,
      lng,
    );
  }

  /// Calculates Driver distance to Saved Pickup Point using LocationTrackingPolicy.
  double? get cabDistanceToPickupMeters {
    final lat = myAssignmentMember?.pickupLatitude;
    final lng = myAssignmentMember?.pickupLongitude;
    final driverLoc = driverLiveLocation;
    if (lat == null ||
        lng == null ||
        lat == 0.0 ||
        lng == 0.0 ||
        driverLoc == null) {
      return null;
    }
    return LocationTrackingPolicy.distanceMeters(
      driverLoc.latitude,
      driverLoc.longitude,
      lat,
      lng,
    );
  }

  /// Calculates speed in km/h from m/s. Returns null if driver location is unavailable.
  double? get cabSpeedKmH {
    final speed = driverLiveLocation?.speed;
    if (speed == null) return null;
    return speed * 3.6;
  }

  /// Driver speed display string: returns 'â€”' when unavailable.
  String get cabSpeedDisplay {
    final speed = cabSpeedKmH;
    if (speed == null) return 'â€”';
    return '${speed.round()} km/h';
  }

  /// Driver Name/ID display string.
  String get driverDisplayName {
    if (activeAssignment == null || activeAssignment!.driverId.isEmpty) {
      return 'Not assigned';
    }
    final name = assignedDriver?.name.trim() ?? '';
    return name.isEmpty ? 'Driver details loading' : name;
  }

  String get employeeLocationFreshness =>
      formatFreshness(employeeLiveLocation?.updatedAt, now: currentTime);

  String get driverLocationFreshness =>
      formatFreshness(driverLiveLocation?.updatedAt, now: currentTime);

  String get dutyDurationDisplay {
    final checkIn = todayAttendance?.checkInTime;
    if (checkIn == null) return 'â€”';
    final end = todayAttendance?.checkOutTime ?? currentTime;
    final duration = end.difference(checkIn);
    if (duration.isNegative) return 'â€”';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return hours == 0 ? '${minutes}m' : '${hours}h ${minutes}m';
  }

  Future<EmployeeActionResult> refreshCurrentDay() async {
    if (isRefreshing) {
      return const EmployeeActionResult(
        isAccepted: true,
        message: 'Status refresh already in progress.',
      );
    }
    isRefreshing = true;
    _safeNotifyListeners();
    try {
      final newDateKey = _todayDateKey();
      if (newDateKey != _activeDateKey) {
        final switched = await _rolloverToDate(newDateKey);
        if (!switched) {
          return const EmployeeActionResult(
            isAccepted: true,
            message:
                'Active trip retained until location sharing stops safely.',
          );
        }
      } else {
        await currentDayRefreshCallback?.call(newDateKey);
        await updateLocationPermissionStatus();
      }
      errorMessage = null;
      return const EmployeeActionResult(
        isAccepted: true,
        message: 'Todayâ€™s status is up to date.',
      );
    } catch (error) {
      debugPrint('Current-day refresh error: $error');
      return const EmployeeActionResult(
        isAccepted: false,
        message:
            'Could not refresh status. Check your connection and try again.',
      );
    } finally {
      isRefreshing = false;
      _safeNotifyListeners();
    }
  }

  Future<void> handleClockTick() async {
    if (_isDisposed) return;
    final newDateKey = _todayDateKey();
    if (newDateKey != _activeDateKey) {
      await _rolloverToDate(newDateKey);
    } else {
      _safeNotifyListeners();
    }
  }

  Future<bool> _rolloverToDate(String newDateKey) async {
    final tripIsActive =
        activeTrip != null &&
        const {
          'created',
          'active',
          'office_arrived',
        }.contains(activeTrip!.status);
    if (tripIsActive) {
      _safeNotifyListeners();
      return false;
    }
    if (activeSession != null) {
      final stopped = await _stopLocationTrackingSession(
        stopReason: 'daily_rollover',
      );
      if (!stopped) {
        transportTrackingState = 'stop_failed';
        _safeNotifyListeners();
        return false;
      }
    }
    _activeDateKey = newDateKey;
    todayAttendance = null;
    myAssignmentMember = null;
    _clearDownstreamState();
    isLoading = true;
    await currentDayRefreshCallback?.call(newDateKey);
    if (_realtimeListenersEnabled) {
      await _initRealtimeListeners();
    } else {
      isLoading = false;
      _safeNotifyListeners();
    }
    return true;
  }

  static CabAssignmentMemberModel? selectTodayAssignmentMember(
    Iterable<CabAssignmentMemberModel> members,
    String dateKey,
  ) {
    if (dateKey.trim().isEmpty) return null;
    for (final member in members) {
      if (member.dateKey == dateKey) return member;
    }
    return null;
  }

  static bool isAuthorizedDriverLocation({
    required LiveLocationModel? location,
    required String driverId,
    required String assignmentId,
  }) {
    return location != null &&
        driverId.isNotEmpty &&
        assignmentId.isNotEmpty &&
        location.userId == driverId &&
        location.assignmentId == assignmentId;
  }

  /// Pure static geofence validator using the 100m/150m accuracy rule.
  static bool evaluateGeofence({
    required double distanceMeters,
    required double accuracyMeters,
  }) {
    if (accuracyMeters > 150.0) return false;
    final maxRadius = accuracyMeters <= 100.0 ? 100.0 : 150.0;
    return distanceMeters <= maxRadius;
  }

  /// Authoritative Start Duty sequence with ROLLBACK-STOP FAILURE SAFETY.
  Future<EmployeeActionResult> startDuty() async {
    isActionLoading = true;
    errorMessage = null;
    transportSyncState = 'synced';
    transportSyncMessage = null;
    _safeNotifyListeners();

    bool createdSessionDuringAction = false;
    LocationSessionModel? sessionCreatedDuringAction;

    try {
      final uid = currentUidGetter?.call() ?? _authObj.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        attendanceActionState = 'failed';
        throw StateError('Employee not authenticated');
      }

      final gpsChecker =
          locationServiceChecker ?? Geolocator.isLocationServiceEnabled;
      final gpsEnabled = await gpsChecker();
      if (!gpsEnabled) {
        attendanceActionState = 'failed';
        return const EmployeeActionResult(
          isAccepted: false,
          message: 'GPS services are disabled. Please enable location.',
        );
      }

      final permChecker =
          permissionChecker ?? LocationController.checkLocationPermission;
      var perm = await permChecker();
      if (!perm.canUseLocation) {
        final permReq =
            permissionRequester ?? LocationController.requestLocationPermission;
        perm = await permReq();
        if (!perm.canUseLocation) {
          attendanceActionState = 'failed';
          return const EmployeeActionResult(
            isAccepted: false,
            message: 'GPS location permission denied.',
          );
        }
      }

      // Step 1: Attendance Check-in MUST succeed first
      final checkIn = checkInCallback ?? AttendanceController.checkIn;
      await checkIn();
      attendanceActionState = 'started';

      final member = myAssignmentMember;
      if (member == null || member.assignmentId.isEmpty) {
        if (transportTrackingState != 'stop_failed') {
          transportTrackingState = 'inactive';
        }
        return const EmployeeActionResult(
          isAccepted: true,
          message: 'Attendance started â€” no transport route assigned today.',
        );
      }

      final lat = member.pickupLatitude;
      final lng = member.pickupLongitude;
      if (lat == null || lng == null || lat == 0.0 || lng == 0.0) {
        if (transportTrackingState != 'stop_failed') {
          transportTrackingState = 'inactive';
        }
        return const EmployeeActionResult(
          isAccepted: true,
          message: 'Attendance started â€” pickup point is not configured.',
        );
      }

      final sessionLoader =
          activeSessionLoader ?? LocationController.loadActiveLocationSession;
      var session = await sessionLoader(uid);
      if (session != null &&
          session.trackingReason !=
              LocationTrackingPolicy.reasonCabPickupReady) {
        return EmployeeActionResult(
          isAccepted: false,
          message:
              'Another operational tracking session (${session.trackingReason}) is active.',
        );
      }

      if (session == null) {
        final starter =
            sessionStarter ?? LocationController.startLocationSession;
        session = await starter(
          userId: uid,
          trackingReason: LocationTrackingPolicy.reasonCabPickupReady,
          metadata: <String, dynamic>{'assignmentId': member.assignmentId},
        );
        createdSessionDuringAction = true;
        sessionCreatedDuringAction = session;
      }
      activeSession = session;

      if (_foregroundTrackingSubscription != null) {
        await _foregroundTrackingSubscription!.cancel();
        _foregroundTrackingSubscription = null;
      }

      try {
        final fgStarter =
            foregroundTrackingStarter ??
            LocationController.startForegroundLiveLocationUpdates;
        _foregroundTrackingSubscription = await fgStarter(
          session: session,
          onLocation: (liveLoc) async {
            employeeLiveLocation = liveLoc;
            await _onLocationUpdateProgressCheck(uid);
            _safeNotifyListeners();
          },
          onError: (err, stack) {
            debugPrint('Foreground location stream error: $err');
            errorMessage = 'Could not update live location.';
            _safeNotifyListeners();
          },
        );
      } catch (fgErr) {
        debugPrint('Foreground tracking starter failed: $fgErr');
        if (_foregroundTrackingSubscription != null) {
          await _foregroundTrackingSubscription!.cancel();
          _foregroundTrackingSubscription = null;
        }

        if (createdSessionDuringAction && sessionCreatedDuringAction != null) {
          try {
            final stopper =
                sessionStopper ?? LocationController.stopLocationSession;
            await stopper(
              session: sessionCreatedDuringAction,
              stopReason: 'start_duty_failed',
            );
            activeSession = null;
            trackingAssignmentId = null;
            if (transportTrackingState != 'stop_failed') {
              transportTrackingState = 'inactive';
            }
            locationStopError = null;
          } catch (e) {
            activeSession = sessionCreatedDuringAction;
            trackingAssignmentId = member.assignmentId;
            transportTrackingState = 'stop_failed';
            locationStopError =
                'Could not stop location sharing. Check your connection and try again.';
          }
        }

        errorMessage = 'Could not start transport tracking. Please try again.';
        return const EmployeeActionResult(
          isAccepted: false,
          message:
              'Attendance started, but transport tracking could not start.',
        );
      }

      // --- AUTHORITATIVE MEMBER WRITE ---
      try {
        final memberUpdater =
            memberStatusUpdater ?? CabAssignmentService.updateMemberStatus;
        await memberUpdater(
          memberId: member.id,
          status: 'travelling_to_pickup',
        );
        myAssignmentMember = myAssignmentMember!.copyWith(
          status: 'travelling_to_pickup',
          updatedAt: clock?.call() ?? DateTime.now(),
        );
      } catch (memberErr) {
        debugPrint('Member status update failed during startDuty: $memberErr');
        // Rollback required because authoritative write failed
        if (_foregroundTrackingSubscription != null) {
          await _foregroundTrackingSubscription!.cancel();
          _foregroundTrackingSubscription = null;
        }

        if (createdSessionDuringAction && sessionCreatedDuringAction != null) {
          try {
            final stopper =
                sessionStopper ?? LocationController.stopLocationSession;
            await stopper(
              session: sessionCreatedDuringAction,
              stopReason: 'start_duty_failed',
            );
            activeSession = null;
            trackingAssignmentId = null;
            if (transportTrackingState != 'stop_failed') {
              transportTrackingState = 'inactive';
            }
            locationStopError = null;
          } catch (e) {
            activeSession = sessionCreatedDuringAction;
            trackingAssignmentId = member.assignmentId;
            transportTrackingState = 'stop_failed';
            locationStopError =
                'Could not stop location sharing. Check your connection and try again.';
          }
        } else {
          if (transportTrackingState != 'stop_failed') {
            transportTrackingState = 'inactive';
          }
        }

        errorMessage = 'Could not start transport tracking. Please try again.';
        return const EmployeeActionResult(
          isAccepted: false,
          message:
              'Attendance started, but transport tracking could not start.',
        );
      }

      // Authoritative write succeeded! Live tracking is active.
      transportTrackingState = 'active';
      trackingAssignmentId =
          member.assignmentId; // ONLY set here on full success

      // Secondary sync: Rider & Progress writes
      bool syncFailed = false;
      if (myRiderRecord != null) {
        try {
          final riderId = myRiderRecord!.id.isNotEmpty
              ? myRiderRecord!.id
              : myRiderRecord!.employeeId;
          final riderUpdater =
              riderFieldsUpdater ?? CabTripService.updateRiderFields;
          await riderUpdater(
            tripId: myRiderRecord!.tripId,
            riderId: riderId,
            fields: const <String, Object?>{'status': 'travelling_to_pickup'},
          );
        } catch (rErr) {
          debugPrint('Rider status sync failed: $rErr');
          syncFailed = true;
        }
      }

      try {
        await _ensureSelfPassengerProgressCreated();
      } catch (pErr) {
        debugPrint('Passenger progress sync failed: $pErr');
        syncFailed = true;
      }

      if (syncFailed) {
        transportSyncState = 'sync_pending';
        transportSyncMessage =
            'Transport tracking started. Trip synchronization is pending.';
        return const EmployeeActionResult(
          isAccepted: true,
          message:
              'Transport tracking started. Trip synchronization is pending.',
        );
      }

      transportSyncState = 'synced';
      transportSyncMessage = null;
      return const EmployeeActionResult(
        isAccepted: true,
        message: 'Attendance started and transport tracking active.',
      );
    } catch (e) {
      debugPrint('startDuty outer error: $e');
      errorMessage = 'Could not start transport tracking. Please try again.';
      return const EmployeeActionResult(
        isAccepted: false,
        message: 'Attendance started, but transport tracking could not start.',
      );
    } finally {
      if (transportTrackingState != 'stop_failed') {
        // preserve stop_failed
      }
      isActionLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Automatically creates or refreshes the Employee's own progress document.
  Future<void> _ensureSelfPassengerProgressCreated() async {
    if (_isProgressWriting) return;
    final uid = currentUidGetter?.call() ?? _authObj.currentUser?.uid;
    if (activeTrip == null || uid == null || uid.isEmpty) return;

    _isProgressWriting = true;
    final displayName = currentUser?.name.isNotEmpty == true
        ? currentUser!.name
        : 'Passenger';
    final sequence = myRiderRecord?.pickupOrder ?? 0;
    final memberStatus = myAssignmentMember?.status ?? 'travelling_to_pickup';
    final currentStatus = (memberStatus == 'assigned')
        ? 'travelling_to_pickup'
        : memberStatus;

    try {
      passengerProgressSyncError = null;
      final writer =
          progressWriter ?? PassengerProgressService.upsertPassengerProgress;
      final nowTime = clock?.call() ?? DateTime.now();
      await writer(
        activeTrip!.id,
        PassengerProgressModel(
          employeeId: uid,
          passengerDisplayName: displayName,
          employeeCode: currentUser?.employeeCode ?? '',
          roleLabel: _passengerRoleLabel,
          pickupSequence: sequence,
          status: currentStatus,
          attendanceActive: todayAttendance != null,
          transportActive: currentStatus != 'not_coming',
          distanceToPickupMeters: employeeDistanceToPickupMeters,
          locationFreshness: 'live',
          updatedAt: nowTime,
        ),
      );
      _lastProgressWriteTime = nowTime;
      _lastProgressWriteDistance = employeeDistanceToPickupMeters;
      _lastProgressWriteStatus = currentStatus;
    } catch (e) {
      debugPrint('_ensureSelfPassengerProgressCreated error: $e');
      passengerProgressSyncError = 'Passenger progress sync failed';
      _safeNotifyListeners();
      rethrow;
    } finally {
      _isProgressWriting = false;
    }
  }

  String get _passengerRoleLabel {
    final role = currentUser?.role.trim().toLowerCase() ?? '';
    return const {
          'admin',
          'administrator',
          'application_owner',
          'owner',
        }.contains(role)
        ? 'Administrator'
        : role == 'manager'
        ? 'Manager'
        : 'Employee';
  }

  Future<EmployeeActionResult> updateOwnTransportRemark(String remark) async {
    if (isActionLoading) {
      return const EmployeeActionResult(
        isAccepted: false,
        message: 'A transport update is already in progress.',
      );
    }
    if (!PassengerProgressService.employeeRemarks.contains(remark)) {
      return const EmployeeActionResult(
        isAccepted: false,
        message: 'This transport status is not supported.',
      );
    }
    if (remark == 'ready') {
      final result = await markReadyAtPickup();
      return EmployeeActionResult(
        isAccepted: result.isAccepted,
        message: result.message,
      );
    }
    final trip = activeTrip;
    final uid = currentUidGetter?.call() ?? _authObj.currentUser?.uid;
    if (trip == null || uid == null || uid.isEmpty) {
      return const EmployeeActionResult(
        isAccepted: false,
        message: 'No active trip is available.',
      );
    }

    isActionLoading = true;
    errorMessage = null;
    _safeNotifyListeners();
    final previous = List<PassengerProgressModel>.from(passengerProgressList);
    final index = passengerProgressList.indexWhere(
      (item) => item.employeeId == uid,
    );
    if (index >= 0) {
      passengerProgressList[index] = passengerProgressList[index].copyWith(
        status: remark,
        remark: remark,
        transportActive: remark != 'not_coming',
        updatedAt: currentTime,
      );
      _safeNotifyListeners();
    }
    try {
      final updater =
          passengerRemarkUpdater ?? PassengerProgressService.updateOwnRemark;
      await updater(trip.id, uid, remark);
      return EmployeeActionResult(
        isAccepted: true,
        message: remark == 'not_coming'
            ? 'Transport marked Not coming. Attendance is unchanged.'
            : 'Transport status updated.',
      );
    } catch (_) {
      passengerProgressList = previous;
      errorMessage = 'Could not update transport status.';
      return const EmployeeActionResult(
        isAccepted: false,
        message: 'Could not update transport status. Please try again.',
      );
    } finally {
      isActionLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Throttled passenger progress updates on GPS callbacks.
  Future<void> _onLocationUpdateProgressCheck(String uid) async {
    if (activeTrip == null) return;
    final nowTime = clock?.call() ?? DateTime.now();
    final currentDist = employeeDistanceToPickupMeters;
    final memberStatus = myAssignmentMember?.status ?? 'travelling_to_pickup';
    final currentStatus = (memberStatus == 'assigned')
        ? 'travelling_to_pickup'
        : memberStatus;

    final isTimeThrottled =
        _lastProgressWriteTime == null ||
        nowTime.difference(_lastProgressWriteTime!).inSeconds >= 15;
    final isDistanceMoved =
        _lastProgressWriteDistance == null ||
        (currentDist != null &&
            (currentDist - _lastProgressWriteDistance!).abs() >= 20.0);
    final isStatusChanged = currentStatus != _lastProgressWriteStatus;

    if (isTimeThrottled || isDistanceMoved || isStatusChanged) {
      try {
        await _ensureSelfPassengerProgressCreated();
      } catch (_) {}
    }
  }

  @visibleForTesting
  Future<void> triggerLocationProgressCheck(String uid) async {
    await _onLocationUpdateProgressCheck(uid);
  }

  /// Authoritative Ready confirmation at pickup point.
  Future<GeofenceResult> markReadyAtPickup() async {
    isActionLoading = true;
    errorMessage = null;
    _safeNotifyListeners();

    try {
      final uid = currentUidGetter?.call() ?? _authObj.currentUser?.uid;
      final member = myAssignmentMember;
      if (member == null) {
        return const GeofenceResult(
          isAccepted: false,
          distanceMeters: 9999,
          message: 'No assignment member exists',
        );
      }

      final lat = member.pickupLatitude;
      final lng = member.pickupLongitude;
      if (lat == null || lng == null || lat == 0.0 || lng == 0.0) {
        return const GeofenceResult(
          isAccepted: false,
          distanceMeters: 9999,
          message: 'Pickup coordinates not configured',
        );
      }

      if (_foregroundTrackingSubscription == null) {
        return const GeofenceResult(
          isAccepted: false,
          distanceMeters: 9999,
          message: 'Active location tracking session required',
        );
      }

      final gpsChecker =
          locationServiceChecker ?? Geolocator.isLocationServiceEnabled;
      final gpsEnabled = await gpsChecker();
      if (!gpsEnabled) {
        return const GeofenceResult(
          isAccepted: false,
          distanceMeters: 9999,
          message: 'GPS services are disabled. Please enable location.',
        );
      }

      final posGetter =
          currentPositionGetter ??
          () => Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );

      final pos = await posGetter();

      if (pos.accuracy > 150.0) {
        return const GeofenceResult(
          isAccepted: false,
          distanceMeters: 9999,
          message:
              'GPS accuracy too weak. Please wait for a better signal and try again.',
        );
      }

      final dist = LocationTrackingPolicy.distanceMeters(
        pos.latitude,
        pos.longitude,
        lat,
        lng,
      );

      final isAccepted = evaluateGeofence(
        distanceMeters: dist,
        accuracyMeters: pos.accuracy,
      );

      if (!isAccepted) {
        return GeofenceResult(
          isAccepted: false,
          distanceMeters: dist,
          message:
              'You are ${dist.round()}m away. Move closer to confirm Ready.',
        );
      }

      // --- AUTHORITATIVE MEMBER WRITE ---
      try {
        final memberUpdater =
            memberStatusUpdater ?? CabAssignmentService.updateMemberStatus;
        await memberUpdater(memberId: member.id, status: 'ready');
        myAssignmentMember = myAssignmentMember!.copyWith(
          status: 'ready',
          updatedAt: clock?.call() ?? DateTime.now(),
        );
      } catch (e) {
        debugPrint('Member status update failed in markReadyAtPickup: $e');
        errorMessage = 'Could not confirm Ready. Please try again.';
        return const GeofenceResult(
          isAccepted: false,
          distanceMeters: 9999,
          message: 'Could not confirm Ready. Please try again.',
        );
      }

      // Authoritative Member Write Succeeded! Return Accepted.
      bool syncFailed = false;

      if (myRiderRecord != null) {
        try {
          final riderId = myRiderRecord!.id.isNotEmpty
              ? myRiderRecord!.id
              : myRiderRecord!.employeeId;
          final riderUpdater =
              riderFieldsUpdater ?? CabTripService.updateRiderFields;
          await riderUpdater(
            tripId: myRiderRecord!.tripId,
            riderId: riderId,
            fields: <String, Object?>{
              'status': 'ready',
              'readyAt': Timestamp.now(),
            },
          );
        } catch (rErr) {
          debugPrint('Rider ready sync failed: $rErr');
          syncFailed = true;
        }
      }

      if (activeTrip != null && uid != null) {
        try {
          final displayName = currentUser?.name.isNotEmpty == true
              ? currentUser!.name
              : 'Passenger';
          final writer =
              progressWriter ??
              PassengerProgressService.upsertPassengerProgress;
          final nowTime = clock?.call() ?? DateTime.now();
          await writer(
            activeTrip!.id,
            PassengerProgressModel(
              employeeId: uid,
              passengerDisplayName: displayName,
              employeeCode: currentUser?.employeeCode ?? '',
              roleLabel: _passengerRoleLabel,
              pickupSequence: myRiderRecord?.pickupOrder ?? 0,
              status: 'ready',
              remark: 'ready',
              attendanceActive: todayAttendance != null,
              distanceToPickupMeters: dist,
              locationFreshness: 'live',
              updatedAt: nowTime,
            ),
          );
        } catch (pErr) {
          debugPrint('Passenger progress ready sync failed: $pErr');
          syncFailed = true;
        }
      }

      if (syncFailed) {
        transportSyncState = 'sync_pending';
        transportSyncMessage =
            'Ready confirmed. Trip synchronization is pending.';
        return GeofenceResult(
          isAccepted: true,
          distanceMeters: dist,
          message: 'Ready confirmed. Trip synchronization is pending.',
        );
      }

      transportSyncState = 'synced';
      transportSyncMessage = null;
      return GeofenceResult(
        isAccepted: true,
        distanceMeters: dist,
        message: 'Ready confirmed at pickup point.',
      );
    } catch (e) {
      debugPrint('markReadyAtPickup outer error: $e');
      errorMessage = 'Could not confirm Ready. Please try again.';
      return const GeofenceResult(
        isAccepted: false,
        distanceMeters: 9999,
        message: 'Could not confirm Ready. Please try again.',
      );
    } finally {
      isActionLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Explicit retry method for secondary trip document synchronization.
  Future<void> retryTripSynchronization() async {
    if (_isRetrying) return;
    _isRetrying = true;
    isActionLoading = true;
    _safeNotifyListeners();

    try {
      if (myRiderRecord != null && myAssignmentMember != null) {
        final riderId = myRiderRecord!.id.isNotEmpty
            ? myRiderRecord!.id
            : myRiderRecord!.employeeId;
        final riderUpdater =
            riderFieldsUpdater ?? CabTripService.updateRiderFields;
        await riderUpdater(
          tripId: myRiderRecord!.tripId,
          riderId: riderId,
          fields: <String, Object?>{'status': myAssignmentMember!.status},
        );
      }
      await _ensureSelfPassengerProgressCreated();
      transportSyncState = 'synced';
      transportSyncMessage = null;
    } catch (e) {
      debugPrint('retryTripSynchronization error: $e');
      transportSyncState = 'sync_pending';
      transportSyncMessage = 'Trip synchronization failed. Retry required.';
    } finally {
      _isRetrying = false;
      isActionLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Awaited, safe sign-out sequence.
  Future<bool> prepareForSignOut() async {
    isActionLoading = true;
    errorMessage = null;
    locationStopError = null;
    passengerProgressSyncError = null;
    _safeNotifyListeners();

    try {
      if (activeSession != null) {
        final stopSuccess = await _stopLocationTrackingSession(
          stopReason: 'employee_signed_out',
        );
        if (!stopSuccess) {
          isActionLoading = false;
          _safeNotifyListeners();
          return false;
        }
      } else {
        if (_foregroundTrackingSubscription != null) {
          await _foregroundTrackingSubscription!.cancel();
          _foregroundTrackingSubscription = null;
        }
        transportTrackingState = 'inactive';
      }

      await _cancelAllSubscriptions();
      _clearAllState();

      isActionLoading = false;
      _safeNotifyListeners();
      return true;
    } catch (e) {
      debugPrint('prepareForSignOut error: $e');
      isActionLoading = false;
      locationStopError =
          'Could not stop location sharing. Check your connection and try again.';
      _safeNotifyListeners();
      return false;
    }
  }

  void _clearAllState() {
    currentUser = null;
    todayAttendance = null;
    myAssignmentMember = null;
    activeAssignment = null;
    activeTrip = null;
    myRiderRecord = null;
    driverLiveLocation = null;
    employeeLiveLocation = null;
    passengerProgressList = [];
    activeSession = null;
    trackingAssignmentId = null;
    pendingAssignmentId = null;
    attendanceActionState = 'none';
    transportTrackingState = 'inactive';
    transportSyncState = 'synced';
    transportSyncMessage = null;
    errorMessage = null;
    locationStopError = null;
    passengerProgressSyncError = null;
  }

  /// Computed Home screen state for the 13-state machine (Aâ€“M).
  /// UI reads this single getter to decide its layout.
  String get homeState {
    // M: Offline / error
    if (errorMessage != null) return 'M';
    // L: Location stop failed
    if (transportTrackingState == 'stop_failed') return 'L';
    // K: Sync pending
    if (transportSyncState == 'sync_pending') return 'K';

    // A: Attendance not started
    final attendance = todayAttendance;
    if (attendance == null) return 'A';
    if (attendance.status == 'Checked Out') return 'J';
    if (attendance.status == 'On Break') return 'A';

    final member = myAssignmentMember;
    // B: No current-day pickup request.
    if (member == null || member.status == 'cancelled') return 'B';

    // C: Route assigned, pickup missing
    final lat = member.pickupLatitude;
    final lng = member.pickupLongitude;
    if (lat == null || lng == null || lat == 0.0 || lng == 0.0) return 'C';

    // Check rider terminal states
    final riderStatus = myRiderRecord?.status;
    if (riderStatus == 'completed' || riderStatus == 'dropped') return 'J';
    if (riderStatus == 'picked_up' || riderStatus == 'boarded') return 'I';
    if (riderStatus == 'arrived' ||
        riderStatus == 'waiting' ||
        riderStatus == 'driver_waiting') {
      return 'H';
    }

    // G: Employee ready
    if (member.status == 'ready') return 'G';

    // F: Trip active (travelling_to_pickup or similar)
    if (activeTrip != null &&
        (activeTrip!.status == 'active' ||
            activeTrip!.status == 'created' ||
            activeTrip!.status == 'office_arrived')) {
      return 'F';
    }

    // E: Driver assigned, trip not started.
    if (member.driverId.isNotEmpty ||
        (activeAssignment != null && activeAssignment!.driverId.isNotEmpty)) {
      return 'E';
    }

    // D: Pickup requested, Driver pending.
    return 'D';
  }

  EmployeeHomeViewState get homeViewState {
    final progress =
        passengerProgressList
            .where((item) => item.employeeId.isNotEmpty)
            .toList(growable: false)
          ..sort((a, b) => a.pickupSequence.compareTo(b.pickupSequence));
    const terminal = {
      'picked_up',
      'boarded',
      'completed',
      'dropped',
      'skipped',
      'no_show',
    };
    const onboard = {'picked_up', 'boarded', 'completed', 'dropped'};
    final assignedCount = activeAssignment?.employeeIds.length ?? 0;
    final activeCount = assignedCount > progress.length
        ? assignedCount
        : progress.length;
    final completedCount = progress
        .where((item) => terminal.contains(item.status))
        .length;
    PassengerProgressModel? current;
    PassengerProgressModel? next;
    for (final item in progress) {
      if (terminal.contains(item.status)) continue;
      if (current == null) {
        current = item;
      } else {
        next = item;
        break;
      }
    }

    String diagnostic = 'ok';
    if (locationPermissionState?.serviceEnabled == false) {
      diagnostic = 'location_services_disabled';
    } else if (locationPermissionStatus == 'Denied' ||
        locationPermissionState?.canUseForegroundLocation == false) {
      diagnostic = 'permission_denied';
    } else if (errorMessage != null) {
      final lower = errorMessage!.toLowerCase();
      diagnostic = lower.contains('permission') || lower.contains('denied')
          ? 'permission_denied'
          : lower.contains('offline') || lower.contains('network')
          ? 'offline'
          : 'query_failed';
    } else if (myAssignmentMember == null ||
        myAssignmentMember!.status == 'cancelled') {
      diagnostic = 'no_pickup_request';
    } else if (myAssignmentMember != null &&
        (myAssignmentMember!.pickupLatitude == null ||
            myAssignmentMember!.pickupLongitude == null)) {
      diagnostic = 'pickup_missing';
    } else if (activeAssignment != null &&
        (activeAssignment!.officeLatitude == null ||
            activeAssignment!.officeLongitude == null)) {
      diagnostic = 'office_missing';
    } else if (activeAssignment != null && activeAssignment!.driverId.isEmpty) {
      diagnostic = 'driver_pending';
    } else if (activeAssignment != null &&
        activeAssignment!.vehicleId.isEmpty) {
      diagnostic = 'vehicle_pending';
    }

    return EmployeeHomeViewState(
      stateCode: homeState,
      diagnosticCode: diagnostic,
      activeEmployees: activeCount,
      readyEmployees: progress.where((item) => item.status == 'ready').length,
      onboardEmployees: progress
          .where((item) => onboard.contains(item.status))
          .length,
      remainingEmployees: activeCount > completedCount
          ? activeCount - completedCount
          : 0,
      orderedProgress: List.unmodifiable(progress),
      currentPickup: current,
      nextPickup: next,
    );
  }

  /// Returns a human-readable freshness string from an optional timestamp.
  static String formatFreshness(DateTime? updatedAt, {DateTime? now}) {
    if (updatedAt == null) return 'Offline';
    final current = now ?? DateTime.now();
    final diff = current.difference(updatedAt);

    if (diff.isNegative || diff.inSeconds < 5) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds} sec ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return 'Stale';
  }

  /// Returns a contextual offline/error explanation for the Home screen.
  /// Never uses the word "Approval".
  String get contextualStatusMessage {
    if (transportTrackingState == 'stop_failed') {
      return 'Could not stop location sharing. Please retry or check your connection.';
    }
    if (transportSyncState == 'sync_pending') {
      return transportSyncMessage ??
          'Your attendance was saved. Transport synchronization is pending.';
    }
    if (locationPermissionStatus == 'Denied') {
      return 'Location permission is required for pickup tracking.';
    }
    if (errorMessage != null) {
      return errorMessage!;
    }
    return '';
  }

  /// Pure contextual action label resolver in exact required order.
  String get contextualActionLabel {
    final attendance = todayAttendance;
    if (attendance == null) return 'Start Duty';
    if (attendance.status == 'On Break') return 'On Break';
    if (attendance.status == 'Checked Out') return 'Duty Completed';

    final member = myAssignmentMember;
    if (member == null || member.status == 'cancelled') {
      return 'Request Pickup';
    }

    final riderStatus = myRiderRecord?.status;
    if (riderStatus == 'completed' || riderStatus == 'dropped') {
      return 'Trip Completed';
    }
    if (riderStatus == 'picked_up' || riderStatus == 'boarded') {
      return 'Picked Up';
    }
    if (riderStatus == 'arrived') return 'Cab Has Arrived';

    final memberStatus = member.status;
    if (memberStatus == 'ready') return 'Ready Confirmed';
    if (memberStatus == 'travelling_to_pickup') {
      final dist = employeeDistanceToPickupMeters;
      final acc = employeeLiveLocation?.accuracy ?? 10.0;
      if (dist != null &&
          evaluateGeofence(distanceMeters: dist, accuracyMeters: acc)) {
        return "I'm Ready at Pickup";
      }
      return 'Go to Pickup';
    }
    if (memberStatus == 'assigned') return 'Go to Pickup';
    return 'Go to Pickup';
  }

  Future<bool> logout() => prepareForSignOut();

  String _todayDateKey() {
    final nowTime = clock?.call() ?? DateTime.now();
    return '${nowTime.year}-${nowTime.month.toString().padLeft(2, '0')}-${nowTime.day.toString().padLeft(2, '0')}';
  }

  @visibleForTesting
  void listenToRiderForTest(String tripId, String myUid) {
    _listenToRider(tripId, myUid, _generationToken);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _minuteTimer?.cancel();
    _minuteTimer = null;
    _cancelSubscriptionQuietly(_userSubscription);
    _userSubscription = null;
    _cancelSubscriptionQuietly(_attendanceSubscription);
    _attendanceSubscription = null;
    _cancelSubscriptionQuietly(_memberSubscription);
    _memberSubscription = null;
    _cancelSubscriptionQuietly(_assignmentSubscription);
    _assignmentSubscription = null;
    _cancelSubscriptionQuietly(_tripSubscription);
    _tripSubscription = null;
    _cancelSubscriptionQuietly(_riderSubscription);
    _riderSubscription = null;
    _cancelSubscriptionQuietly(_passengerProgressSubscription);
    _passengerProgressSubscription = null;
    _cancelSubscriptionQuietly(_driverLocationSubscription);
    _driverLocationSubscription = null;
    _cancelSubscriptionQuietly(_driverUserSubscription);
    _driverUserSubscription = null;
    _cancelSubscriptionQuietly(_vehicleSubscription);
    _vehicleSubscription = null;
    _cancelSubscriptionQuietly(_employeeLocationSubscription);
    _employeeLocationSubscription = null;
    _cancelSubscriptionQuietly(_foregroundTrackingSubscription);
    _foregroundTrackingSubscription = null;
    _cancelSubscriptionQuietly(_sharedPresenceSubscription);
    _sharedPresenceSubscription = null;
    super.dispose();
  }

  void _cancelSubscriptionQuietly(StreamSubscription? sub) {
    if (sub != null) {
      sub.cancel().catchError((Object e) {
        debugPrint('Subscription cancel error during dispose: $e');
      });
    }
  }
}
