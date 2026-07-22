import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/models/cab_assignment_member_model.dart';
import '../../../core/models/cab_assignment_model.dart';
import '../../../core/models/cab_trip_model.dart';
import '../../../core/models/cab_trip_rider_model.dart';
import '../../../core/models/live_location_model.dart';
import '../../../core/models/location_permission_state_model.dart';
import '../../../core/models/location_session_model.dart';
import '../../../core/models/passenger_progress_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/cab_assignment_service.dart';
import '../../../core/services/cab_trip_service.dart';
import '../../../core/services/location_tracking_policy.dart';
import '../../../core/services/passenger_progress_service.dart';
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

  /// Retained active cab pickup location session
  LocationSessionModel? activeSession;

  /// Assignment ID bound to the active session
  String? trackingAssignmentId;

  /// Pending assignment transition ID
  String? pendingAssignmentId;

  /// Privacy-safe passenger progress list read from `cab_trips/{tripId}/passenger_progress/{employeeId}`.
  List<PassengerProgressModel> passengerProgressList = [];

  /// Explicit decoupled state indicators
  String attendanceActionState = 'none'; // 'none', 'started', 'failed'
  String transportTrackingState =
      'inactive'; // 'inactive', 'active', 'stop_failed'
  String transportSyncState = 'synced'; // 'synced', 'sync_pending'
  String? transportSyncMessage;

  bool isLoading = true;
  bool isActionLoading = false;
  String? errorMessage;
  String? locationStopError;
  String? passengerProgressSyncError;
  String locationPermissionStatus = 'Unknown';

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
  StreamSubscription? _employeeLocationSubscription;
  StreamSubscription? _foregroundTrackingSubscription;

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

  // Injected Stream Factories
  final AssignmentStreamFactory? assignmentStreamFactory;
  final TripStreamFactory? tripStreamFactory;
  final RiderStreamFactory? riderStreamFactory;
  final PassengerProgressStreamFactory? passengerProgressStreamFactory;
  final DriverLocationStreamFactory? driverLocationStreamFactory;

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
    this.assignmentStreamFactory,
    this.tripStreamFactory,
    this.riderStreamFactory,
    this.passengerProgressStreamFactory,
    this.driverLocationStreamFactory,
    bool initListeners = true,
  }) {
    if (initListeners) {
      _initRealtimeListeners();
      updateLocationPermissionStatus();
    } else {
      isLoading = false;
    }
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
      locationPermissionStatus = status.canUseLocation ? 'Granted' : 'Denied';
      _safeNotifyListeners();
    } catch (_) {
      locationPermissionStatus = 'Denied';
    }
  }

  void _initRealtimeListeners() async {
    final uid = currentUidGetter?.call() ?? _authObj.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      isLoading = false;
      errorMessage = 'Could not start transport tracking. Please try again.';
      _safeNotifyListeners();
      return;
    }

    final dateKey = _todayDateKey();
    final nowTime = clock?.call() ?? DateTime.now();

    await _cancelAllSubscriptions();

    // 1. User document stream
    _userSubscription = _dbObj
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
          (snap) {
            if (snap.exists && snap.data() != null) {
              currentUser = UserModel.fromMap(snap.data()!);
              errorMessage = null;
            } else {
              currentUser = null;
            }
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
        .snapshots()
        .listen(
          (querySnap) async {
            QueryDocumentSnapshot<Map<String, dynamic>>? targetDoc;
            for (final doc in querySnap.docs) {
              final dk = doc.data()['dateKey'];
              if (dk == dateKey || dk == null || dk == '') {
                targetDoc = doc;
                break;
              }
            }
            if (targetDoc == null && querySnap.docs.isNotEmpty) {
              targetDoc = querySnap.docs.first;
            }

            if (targetDoc != null && targetDoc.data().isNotEmpty) {
              final newMember = CabAssignmentMemberModel.fromMap(
                targetDoc.data(),
                id: targetDoc.id,
              );
              final oldAssignmentId = myAssignmentMember?.assignmentId;
              myAssignmentMember = newMember;
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
    passengerProgressList = [];
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

          if (activeAssignment!.driverId.isNotEmpty) {
            if (oldDriverId != activeAssignment!.driverId) {
              _listenToDriverLocation(activeAssignment!.driverId, currentToken);
            }
          } else {
            await _cancelSubscription(_driverLocationSubscription);
            _driverLocationSubscription = null;
            driverLiveLocation = null;
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
              (t) => const <String>{
                'created',
                'active',
                'office_arrived',
              }.contains(t.status),
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
          passengerProgressList = [];
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
        driverLiveLocation = location;
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
        : PassengerProgressService.watchPassengerProgress(tripId);

    _passengerProgressSubscription = progStream.listen(
      (list) {
        if (token != _generationToken) return;
        passengerProgressList = list;
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
    await _cancelSubscription(_riderSubscription);
    _riderSubscription = null;
    await _cancelSubscription(_passengerProgressSubscription);
    _passengerProgressSubscription = null;

    activeAssignment = null;
    activeTrip = null;
    myRiderRecord = null;
    passengerProgressList = [];
    driverLiveLocation = null;

    final stopSuccess = await _stopLocationTrackingSession(
      stopReason: stopReason,
    );
    if (!stopSuccess) {
      transportTrackingState = 'stop_failed';
    } else {
      transportTrackingState = 'inactive';
    }
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
    await _cancelSubscription(_employeeLocationSubscription);
    _employeeLocationSubscription = null;
    await _cancelSubscription(_foregroundTrackingSubscription);
    _foregroundTrackingSubscription = null;

    if (transportTrackingState != 'stop_failed') {
      transportTrackingState = 'inactive';
    }
  }

  /// Pure connection/location status resolver.
  String get connectionStatus {
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

  /// Driver speed display string: returns '—' when unavailable.
  String get cabSpeedDisplay {
    final speed = cabSpeedKmH;
    if (speed == null) return '—';
    return '${speed.round()} km/h';
  }

  /// Driver Name/ID display string.
  String get driverDisplayName {
    if (activeAssignment == null || activeAssignment!.driverId.isEmpty) {
      return 'Not assigned';
    }
    return 'Driver assigned';
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
          message: 'Attendance started — no transport route assigned today.',
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
          message: 'Attendance started — pickup point is not configured.',
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
          pickupSequence: sequence,
          status: currentStatus,
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
              pickupSequence: myRiderRecord?.pickupOrder ?? 0,
              status: 'ready',
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

  /// Computed Home screen state for the 13-state machine (A–M).
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
    // B: Attendance active, no route
    if (member == null || member.assignmentId.isEmpty) return 'B';

    // C: Route assigned, pickup missing
    final lat = member.pickupLatitude;
    final lng = member.pickupLongitude;
    if (lat == null || lng == null || lat == 0.0 || lng == 0.0) return 'C';

    // Check rider terminal states
    final riderStatus = myRiderRecord?.status;
    if (riderStatus == 'completed' || riderStatus == 'dropped') return 'J';
    if (riderStatus == 'picked_up' || riderStatus == 'boarded') return 'I';
    if (riderStatus == 'arrived') return 'H';

    // G: Employee ready
    if (member.status == 'ready') return 'G';

    // F: Trip active (travelling_to_pickup or similar)
    if (activeTrip != null &&
        (activeTrip!.status == 'active' ||
            activeTrip!.status == 'created' ||
            activeTrip!.status == 'office_arrived')) {
      return 'F';
    }

    // E: Driver assigned, trip not started
    if (activeAssignment != null && activeAssignment!.driverId.isNotEmpty) {
      return 'E';
    }

    // D: Route and pickup configured, driver pending
    return 'D';
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

  /// Creates an active test cab assignment in Firestore for the current employee
  /// so the live transport features (Start Duty, Ready, Live Map, Driver, Metrics)
  /// can be tested live on real devices without waiting for an Admin UI.
  Future<void> setupTestAssignmentForTesting() async {
    isActionLoading = true;
    _safeNotifyListeners();

    try {
      final uid = currentUidGetter?.call() ?? _authObj.currentUser?.uid;
      if (uid == null || uid.isEmpty) return;

      final dateKey = _todayDateKey();
      final assignmentId = 'assign_demo_$uid';
      final tripId = 'trip_demo_$uid';
      final driverId = 'driver_demo_101';

      double pickupLat = 15.3647;
      double pickupLng = 75.1240;
      try {
        if (currentPositionGetter != null) {
          final pos = await currentPositionGetter!();
          pickupLat = pos.latitude;
          pickupLng = pos.longitude;
        } else {
          final loc = await LocationController.getCurrentLocation();
          pickupLat = loc.latitude;
          pickupLng = loc.longitude;
        }
      } catch (_) {}

      final officeLat = pickupLat + 0.0050;
      final officeLng = pickupLng + 0.0050;
      final cabLat = pickupLat - 0.0020;
      final cabLng = pickupLng - 0.0020;

      final memberMap = <String, dynamic>{
        'id': '${dateKey}_$uid',
        'assignmentId': assignmentId,
        'dateKey': dateKey,
        'userId': uid,
        'role': 'employee',
        'driverId': driverId,
        'vehicleId': 'KA-25-CAB-8899',
        'status': 'assigned',
        'pickupName': 'Central Bus Station Pickup',
        'pickupAddress': 'Main Station Road, Hubli',
        'pickupLatitude': pickupLat,
        'pickupLongitude': pickupLng,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _dbObj
          .collection('cab_assignment_members')
          .doc('${dateKey}_$uid')
          .set(memberMap, SetOptions(merge: true));

      final assignmentMap = <String, dynamic>{
        'id': assignmentId,
        'dateKey': dateKey,
        'driverId': driverId,
        'vehicleId': 'KA-25-CAB-8899',
        'employeeIds': [uid],
        'officeName': 'Hubli Tech Park HQ',
        'officeAddress': 'Airport Road, Hubli',
        'officeLatitude': officeLat,
        'officeLongitude': officeLng,
        'status': 'active',
        'assignedBy': 'System Admin',
        'assignedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _dbObj
          .collection('cab_assignments')
          .doc(assignmentId)
          .set(assignmentMap, SetOptions(merge: true));

      final tripMap = <String, dynamic>{
        'id': tripId,
        'assignmentId': assignmentId,
        'driverId': driverId,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _dbObj
          .collection('cab_trips')
          .doc(tripId)
          .set(tripMap, SetOptions(merge: true));

      final driverLocationMap = <String, dynamic>{
        'userId': driverId,
        'sessionId': 'session_driver_demo',
        'trackingReason': 'driver_active_trip',
        'status': 'active',
        'latitude': cabLat,
        'longitude': cabLng,
        'accuracy': 8.0,
        'speed': 32.5,
        'heading': 45.0,
        'isForeground': true,
        'source': 'gps',
        'syncStatus': 'synced',
        'recordedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _dbObj
          .collection('live_locations')
          .doc(driverId)
          .set(driverLocationMap, SetOptions(merge: true));
    } catch (e) {
      debugPrint('setupTestAssignmentForTesting error: $e');
    } finally {
      isActionLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Removes the test cab assignment documents from Firestore for this employee.
  Future<void> clearTestAssignmentForTesting() async {
    isActionLoading = true;
    _safeNotifyListeners();

    try {
      final uid = currentUidGetter?.call() ?? _authObj.currentUser?.uid;
      if (uid == null || uid.isEmpty) return;

      final dateKey = _todayDateKey();
      await _dbObj
          .collection('cab_assignment_members')
          .doc('${dateKey}_$uid')
          .delete();
    } catch (e) {
      debugPrint('clearTestAssignmentForTesting error: $e');
    } finally {
      isActionLoading = false;
      _safeNotifyListeners();
    }
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
    if (member == null || member.assignmentId.isEmpty) {
      return 'No route assigned today';
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
    _cancelSubscriptionQuietly(_employeeLocationSubscription);
    _employeeLocationSubscription = null;
    _cancelSubscriptionQuietly(_foregroundTrackingSubscription);
    _foregroundTrackingSubscription = null;
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
