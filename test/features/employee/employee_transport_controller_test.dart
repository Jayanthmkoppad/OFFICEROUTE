import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:officeroute/core/models/cab_assignment_member_model.dart';
import 'package:officeroute/core/models/cab_trip_model.dart';
import 'package:officeroute/core/models/cab_trip_rider_model.dart';
import 'package:officeroute/core/models/live_location_model.dart';
import 'package:officeroute/core/models/location_permission_state_model.dart';
import 'package:officeroute/core/models/location_session_model.dart';
import 'package:officeroute/core/models/passenger_progress_model.dart';
import 'package:officeroute/core/services/passenger_progress_service.dart';
import 'package:officeroute/features/employee/controllers/employee_transport_controller.dart';

LocationSessionModel _createTestSession({
  String id = 'session_1',
  String userId = 'emp_123',
  String trackingReason = 'cab_pickup_ready',
  String status = 'active',
}) {
  return LocationSessionModel(
    id: id,
    userId: userId,
    trackingReason: trackingReason,
    status: status,
    startedAt: DateTime.now(),
    pausedAt: null,
    resumedAt: null,
    stoppedAt: null,
    lastLatitude: null,
    lastLongitude: null,
    lastUpdatedAt: null,
    stopReason: '',
    metadata: const <String, dynamic>{},
  );
}

LiveLocationModel _createTestLiveLocation({
  required String userId,
  required double latitude,
  required double longitude,
  String status = 'active',
  double? speed,
  DateTime? updatedAt,
}) {
  final now = updatedAt ?? DateTime(2026, 7, 22, 10, 0, 0);
  return LiveLocationModel(
    userId: userId,
    sessionId: 'session_1',
    trackingReason: 'cab_pickup_ready',
    status: status,
    latitude: latitude,
    longitude: longitude,
    accuracy: 10.0,
    altitude: 0.0,
    speed: speed ?? 0.0,
    heading: 0.0,
    isForeground: true,
    source: 'gps',
    syncStatus: 'synced',
    recordedAt: now,
    updatedAt: now,
  );
}

Position _createTestPosition({
  required double latitude,
  required double longitude,
  double accuracy = 10.0,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.now(),
    accuracy: accuracy,
    altitude: 0.0,
    altitudeAccuracy: 0.0,
    heading: 0.0,
    headingAccuracy: 0.0,
    speed: 0.0,
    speedAccuracy: 0.0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EmployeeTransportController Verified Candidate & Test-Truth Suite', () {
    late bool checkInCalled;
    late bool sessionStarted;
    late bool sessionStopped;
    late String? lastStoppedReason;
    late int progressWriteCount;
    late String? updatedMemberStatus;
    late String? updatedRiderStatus;
    late String? capturedRiderTripId;
    late String? capturedRiderEmployeeId;

    setUp(() {
      checkInCalled = false;
      sessionStarted = false;
      sessionStopped = false;
      lastStoppedReason = null;
      progressWriteCount = 0;
      updatedMemberStatus = null;
      updatedRiderStatus = null;
      capturedRiderTripId = null;
      capturedRiderEmployeeId = null;
    });

    EmployeeTransportController createController({
      String currentUid = 'emp_123',
      CabAssignmentMemberModel? member,
      LocationSessionModel? activeSession,
      bool stopSessionShouldFail = false,
      bool progressWriteShouldFail = false,
      bool memberUpdateShouldFail = false,
      bool riderUpdateShouldFail = false,
      Position? mockPosition,
      DateTime Function()? customClock,
      AssignmentStreamFactory? assignmentStreamFactory,
      TripStreamFactory? tripStreamFactory,
      RiderStreamFactory? riderStreamFactory,
      PassengerProgressStreamFactory? passengerProgressStreamFactory,
      DriverLocationStreamFactory? driverLocationStreamFactory,
    }) {
      final controller = EmployeeTransportController(
        initListeners: false,
        currentUidGetter: () => currentUid,
        checkInCallback: () async {
          checkInCalled = true;
        },
        locationServiceChecker: () async => true,
        permissionChecker: () async => LocationPermissionStateModel(
          serviceEnabled: true,
          permissionStatus: 'granted',
          canRequestPermission: false,
          canUseForegroundLocation: true,
          canUseBackgroundLocation: false,
          permanentlyDenied: false,
          message: 'Granted',
          checkedAt: DateTime.now(),
        ),
        permissionRequester: () async => LocationPermissionStateModel(
          serviceEnabled: true,
          permissionStatus: 'granted',
          canRequestPermission: false,
          canUseForegroundLocation: true,
          canUseBackgroundLocation: false,
          permanentlyDenied: false,
          message: 'Granted',
          checkedAt: DateTime.now(),
        ),
        activeSessionLoader: (userId) async => activeSession,
        sessionStarter: ({required userId, required trackingReason}) async {
          sessionStarted = true;
          return _createTestSession(
            id: 'session_1',
            userId: userId,
            trackingReason: trackingReason,
            status: 'active',
          );
        },
        sessionStopper: ({required session, required stopReason}) async {
          if (stopSessionShouldFail) {
            throw StateError('Backend stop session error');
          }
          sessionStopped = true;
          lastStoppedReason = stopReason;
          return session.copyWith(
            status: 'stopped',
            stoppedAt: DateTime.now(),
            stopReason: stopReason,
          );
        },
        foregroundTrackingStarter:
            ({required session, required onLocation, required onError}) async {
              final streamCtrl = StreamController<LiveLocationModel>();
              return streamCtrl.stream.listen(onLocation);
            },
        memberStatusUpdater: ({required memberId, required status}) async {
          if (memberUpdateShouldFail) {
            throw StateError('Database write error');
          }
          updatedMemberStatus = status;
        },
        riderFieldsUpdater:
            ({required tripId, required riderId, required fields}) async {
              if (riderUpdateShouldFail) {
                throw StateError('Rider update error');
              }
              updatedRiderStatus = fields['status'] as String?;
            },
        progressWriter: (tripId, progress, {isEmployeeRole = true}) async {
          if (progressWriteShouldFail) {
            throw StateError('Progress write error');
          }
          progressWriteCount++;
        },
        currentPositionGetter: () async {
          return mockPosition ??
              _createTestPosition(
                latitude: 28.6139,
                longitude: 77.2090,
                accuracy: 10.0,
              );
        },
        clock: customClock ?? () => DateTime(2026, 7, 22, 10, 0, 0),
        assignmentStreamFactory: assignmentStreamFactory,
        tripStreamFactory: tripStreamFactory,
        riderStreamFactory:
            riderStreamFactory ??
            (tripId, employeeId) {
              capturedRiderTripId = tripId;
              capturedRiderEmployeeId = employeeId;
              return StreamController<CabTripRiderModel?>().stream;
            },
        passengerProgressStreamFactory: passengerProgressStreamFactory,
        driverLocationStreamFactory: driverLocationStreamFactory,
      );

      controller.myAssignmentMember = member;
      controller.activeSession = activeSession;
      if (activeSession != null && member != null) {
        controller.trackingAssignmentId = member.assignmentId;
      }
      return controller;
    }

    test('1. startDuty sets trackingAssignmentId for assignment', () async {
      final member = const CabAssignmentMemberModel(
        id: 'mem_1',
        assignmentId: 'ass_1',
        userId: 'emp_123',
        dateKey: '2026-07-22',
        pickupName: 'Hub',
        pickupAddress: 'Sector 62',
        pickupLatitude: 28.6139,
        pickupLongitude: 77.2090,
      );
      final controller = createController(member: member);

      controller.myRiderRecord = const CabTripRiderModel(
        id: 'r1',
        tripId: 't1',
        employeeId: 'emp_123',
        status: 'assigned',
      );
      final res = await controller.startDuty();

      expect(res.isAccepted, isTrue);
      expect(sessionStarted, isTrue);
      expect(updatedMemberStatus, equals('travelling_to_pickup'));
      expect(updatedRiderStatus, equals('travelling_to_pickup'));
      expect(controller.trackingAssignmentId, equals('ass_1'));
      expect(controller.transportTrackingState, equals('active'));
    });

    test('2. member Start Duty write failure rolls back new session', () async {
      final member = const CabAssignmentMemberModel(
        id: 'mem_1',
        assignmentId: 'ass_1',
        userId: 'emp_123',
        dateKey: '2026-07-22',
        pickupName: 'Hub',
        pickupAddress: 'Sector 62',
        pickupLatitude: 28.6139,
        pickupLongitude: 77.2090,
      );
      final controller = createController(
        member: member,
        memberUpdateShouldFail: true,
      );

      final res = await controller.startDuty();

      expect(checkInCalled, isTrue);
      expect(controller.attendanceActionState, equals('started'));
      expect(sessionStopped, isTrue);
      expect(lastStoppedReason, equals('start_duty_failed'));
      expect(controller.transportTrackingState, equals('inactive'));
      expect(controller.trackingAssignmentId, isNull);
      expect(res.isAccepted, isFalse);
      expect(
        res.message,
        equals('Attendance started, but transport tracking could not start.'),
      );
    });

    test(
      '3. rider Start Duty write failure after member success keeps tracking active and sets sync_pending',
      () async {
        final member = const CabAssignmentMemberModel(
          id: 'mem_1',
          assignmentId: 'ass_1',
          userId: 'emp_123',
          dateKey: '2026-07-22',
          pickupName: 'Hub',
          pickupAddress: 'Sector 62',
          pickupLatitude: 28.6139,
          pickupLongitude: 77.2090,
        );
        final controller = createController(
          member: member,
          riderUpdateShouldFail: true,
        );
        controller.myRiderRecord = const CabTripRiderModel(
          id: 'r_1',
          tripId: 'trip_1',
          employeeId: 'emp_123',
          status: 'assigned',
        );

        final res = await controller.startDuty();

        expect(res.isAccepted, isTrue);
        expect(controller.transportTrackingState, equals('active'));
        expect(controller.transportSyncState, equals('sync_pending'));
        expect(
          res.message,
          equals(
            'Transport tracking started. Trip synchronization is pending.',
          ),
        );
      },
    );

    test(
      '4. progress Start Duty failure keeps tracking active and sets sync_pending',
      () async {
        final member = const CabAssignmentMemberModel(
          id: 'mem_1',
          assignmentId: 'ass_1',
          userId: 'emp_123',
          dateKey: '2026-07-22',
          pickupName: 'Hub',
          pickupAddress: 'Sector 62',
          pickupLatitude: 28.6139,
          pickupLongitude: 77.2090,
        );
        final controller = createController(
          member: member,
          progressWriteShouldFail: true,
        );
        controller.activeTrip = const CabTripModel(
          id: 'trip_1',
          assignmentId: 'ass_1',
          driverId: 'd1',
          status: 'active',
        );

        final res = await controller.startDuty();

        expect(res.isAccepted, isTrue);
        expect(controller.transportTrackingState, equals('active'));
        expect(controller.transportSyncState, equals('sync_pending'));
        expect(
          res.message,
          equals(
            'Transport tracking started. Trip synchronization is pending.',
          ),
        );
      },
    );

    test('5. Ready member failure returns failure', () async {
      bool failMember = false;
      final member = const CabAssignmentMemberModel(
        id: 'mem_1',
        assignmentId: 'ass_1',
        userId: 'emp_123',
        dateKey: '2026-07-22',
        pickupName: 'Hub',
        pickupAddress: 'Sector 62',
        pickupLatitude: 28.6139,
        pickupLongitude: 77.2090,
      );
      final controller = EmployeeTransportController(
        initListeners: false,
        currentUidGetter: () => 'emp_123',
        checkInCallback: () async {},
        locationServiceChecker: () async => true,
        permissionChecker: () async => LocationPermissionStateModel(
          serviceEnabled: true,
          permissionStatus: 'granted',
          canRequestPermission: false,
          canUseForegroundLocation: true,
          canUseBackgroundLocation: false,
          permanentlyDenied: false,
          message: 'Granted',
          checkedAt: DateTime.now(),
        ),
        activeSessionLoader: (userId) async => null,
        sessionStarter: ({required userId, required trackingReason}) async =>
            _createTestSession(),
        sessionStopper: ({required session, required stopReason}) async =>
            session,
        foregroundTrackingStarter:
            ({required session, required onLocation, required onError}) async =>
                StreamController<LiveLocationModel>().stream.listen(onLocation),
        memberStatusUpdater: ({required memberId, required status}) async {
          if (failMember) throw StateError('Member update error');
        },
        currentPositionGetter: () async => _createTestPosition(
          latitude: 28.6139,
          longitude: 77.2090,
          accuracy: 10.0,
        ),
        clock: () => DateTime(2026, 7, 22, 10, 0, 0),
      );
      controller.myAssignmentMember = member;

      await controller.startDuty();
      failMember = true;
      final res = await controller.markReadyAtPickup();

      expect(res.isAccepted, isFalse);
      expect(res.message, equals('Could not confirm Ready. Please try again.'));
    });

    test(
      '6. Ready rider failure after member success returns accepted with sync_pending',
      () async {
        bool failRider = false;
        final member = const CabAssignmentMemberModel(
          id: 'mem_1',
          assignmentId: 'ass_1',
          userId: 'emp_123',
          dateKey: '2026-07-22',
          pickupName: 'Hub',
          pickupAddress: 'Sector 62',
          pickupLatitude: 28.6139,
          pickupLongitude: 77.2090,
        );
        final controller = EmployeeTransportController(
          initListeners: false,
          currentUidGetter: () => 'emp_123',
          checkInCallback: () async {},
          locationServiceChecker: () async => true,
          permissionChecker: () async => LocationPermissionStateModel(
            serviceEnabled: true,
            permissionStatus: 'granted',
            canRequestPermission: false,
            canUseForegroundLocation: true,
            canUseBackgroundLocation: false,
            permanentlyDenied: false,
            message: 'Granted',
            checkedAt: DateTime.now(),
          ),
          activeSessionLoader: (userId) async => null,
          sessionStarter: ({required userId, required trackingReason}) async =>
              _createTestSession(),
          sessionStopper: ({required session, required stopReason}) async =>
              session,
          foregroundTrackingStarter:
              ({
                required session,
                required onLocation,
                required onError,
              }) async => StreamController<LiveLocationModel>().stream.listen(
                onLocation,
              ),
          memberStatusUpdater: ({required memberId, required status}) async {},
          riderFieldsUpdater:
              ({required tripId, required riderId, required fields}) async {
                if (failRider) throw StateError('Rider error');
              },
          currentPositionGetter: () async => _createTestPosition(
            latitude: 28.6139,
            longitude: 77.2090,
            accuracy: 10.0,
          ),
          clock: () => DateTime(2026, 7, 22, 10, 0, 0),
        );
        controller.myAssignmentMember = member;
        controller.myRiderRecord = const CabTripRiderModel(
          id: 'r1',
          tripId: 't1',
          employeeId: 'emp_123',
          status: 'travelling_to_pickup',
        );

        await controller.startDuty();
        failRider = true;
        final res = await controller.markReadyAtPickup();

        expect(res.isAccepted, isTrue);
        expect(controller.transportSyncState, equals('sync_pending'));
        expect(
          res.message,
          equals('Ready confirmed. Trip synchronization is pending.'),
        );
      },
    );

    test(
      '7. Ready progress failure after member success returns accepted with sync_pending',
      () async {
        bool failProgress = false;
        final member = const CabAssignmentMemberModel(
          id: 'mem_1',
          assignmentId: 'ass_1',
          userId: 'emp_123',
          dateKey: '2026-07-22',
          pickupName: 'Hub',
          pickupAddress: 'Sector 62',
          pickupLatitude: 28.6139,
          pickupLongitude: 77.2090,
        );
        final controller = EmployeeTransportController(
          initListeners: false,
          currentUidGetter: () => 'emp_123',
          checkInCallback: () async {},
          locationServiceChecker: () async => true,
          permissionChecker: () async => LocationPermissionStateModel(
            serviceEnabled: true,
            permissionStatus: 'granted',
            canRequestPermission: false,
            canUseForegroundLocation: true,
            canUseBackgroundLocation: false,
            permanentlyDenied: false,
            message: 'Granted',
            checkedAt: DateTime.now(),
          ),
          activeSessionLoader: (userId) async => null,
          sessionStarter: ({required userId, required trackingReason}) async =>
              _createTestSession(),
          sessionStopper: ({required session, required stopReason}) async =>
              session,
          foregroundTrackingStarter:
              ({
                required session,
                required onLocation,
                required onError,
              }) async => StreamController<LiveLocationModel>().stream.listen(
                onLocation,
              ),
          memberStatusUpdater: ({required memberId, required status}) async {},
          progressWriter: (tripId, progress, {isEmployeeRole = true}) async {
            if (failProgress) throw StateError('Progress write error');
          },
          currentPositionGetter: () async => _createTestPosition(
            latitude: 28.6139,
            longitude: 77.2090,
            accuracy: 10.0,
          ),
          clock: () => DateTime(2026, 7, 22, 10, 0, 0),
        );
        controller.myAssignmentMember = member;
        controller.activeTrip = const CabTripModel(
          id: 't1',
          assignmentId: 'ass_1',
          driverId: 'd1',
          status: 'active',
        );

        await controller.startDuty();
        failProgress = true;
        final res = await controller.markReadyAtPickup();

        expect(res.isAccepted, isTrue);
        expect(controller.transportSyncState, equals('sync_pending'));
        expect(
          res.message,
          equals('Ready confirmed. Trip synchronization is pending.'),
        );
      },
    );

    test(
      '8. failed rollback stop keeps activeSession and state stop_failed',
      () async {
        final member = const CabAssignmentMemberModel(
          id: 'mem_1',
          assignmentId: 'ass_1',
          userId: 'emp_123',
          dateKey: '2026-07-22',
          pickupName: 'Hub',
          pickupAddress: 'Sector 62',
          pickupLatitude: 28.6139,
          pickupLongitude: 77.2090,
        );
        final controller = createController(
          member: member,
          memberUpdateShouldFail: true,
          stopSessionShouldFail: true,
        );

        final res = await controller.startDuty();

        expect(res.isAccepted, isFalse);
        expect(controller.activeSession, isNotNull);
        expect(controller.transportTrackingState, equals('stop_failed'));
        expect(
          controller.locationStopError,
          equals(
            'Could not stop location sharing. Check your connection and try again.',
          ),
        );
      },
    );

    test(
      '9. retryStopLocationSharing clears activeSession after success',
      () async {
        final activeSession = _createTestSession(
          id: 's_pickup',
          userId: 'emp_123',
          trackingReason: 'cab_pickup_ready',
          status: 'active',
        );
        final controller = createController(activeSession: activeSession);
        controller.transportTrackingState = 'stop_failed';

        final success = await controller.retryStopLocationSharing();

        expect(success, isTrue);
        expect(controller.activeSession, isNull);
        expect(controller.transportTrackingState, equals('inactive'));
        expect(controller.trackingAssignmentId, isNull);
      },
    );

    test(
      '10. true clock advancement triggers progress write after 16 seconds',
      () async {
        var fakeNow = DateTime(2026, 7, 22, 10, 0, 0);
        final member = const CabAssignmentMemberModel(
          id: 'mem_1',
          assignmentId: 'ass_1',
          userId: 'emp_123',
          dateKey: '2026-07-22',
          pickupName: 'Hub',
          pickupAddress: 'Sector 62',
          pickupLatitude: 28.6139,
          pickupLongitude: 77.2090,
        );
        final controller = createController(
          member: member,
          customClock: () => fakeNow,
        );
        controller.activeTrip = const CabTripModel(
          id: 'trip_1',
          assignmentId: 'ass_1',
          driverId: 'd1',
          status: 'active',
        );

        controller.employeeLiveLocation = _createTestLiveLocation(
          userId: 'emp_123',
          latitude: 28.6139,
          longitude: 77.2090,
          updatedAt: fakeNow,
        );
        await controller.startDuty();
        progressWriteCount = 0;

        // 14 seconds: no write
        fakeNow = fakeNow.add(const Duration(seconds: 14));
        await controller.triggerLocationProgressCheck('emp_123');
        expect(progressWriteCount, equals(0));

        // 16 seconds: exactly one write
        fakeNow = fakeNow.add(const Duration(seconds: 2)); // Total 16s
        await controller.triggerLocationProgressCheck('emp_123');
        expect(progressWriteCount, equals(1));
      },
    );

    test('11. 20-metre movement writes before 15 seconds', () async {
      var fakeNow = DateTime(2026, 7, 22, 10, 0, 0);
      final member = const CabAssignmentMemberModel(
        id: 'mem_1',
        assignmentId: 'ass_1',
        userId: 'emp_123',
        dateKey: '2026-07-22',
        pickupName: 'Hub',
        pickupAddress: 'Sector 62',
        pickupLatitude: 28.6139,
        pickupLongitude: 77.2090,
      );
      final controller = createController(
        member: member,
        customClock: () => fakeNow,
      );
      controller.activeTrip = const CabTripModel(
        id: 'trip_1',
        assignmentId: 'ass_1',
        driverId: 'd1',
        status: 'active',
      );

      controller.employeeLiveLocation = _createTestLiveLocation(
        userId: 'emp_123',
        latitude: 28.6139,
        longitude: 77.2090,
        updatedAt: fakeNow,
      );
      await controller.startDuty();
      progressWriteCount = 0;

      // Only 5 seconds elapsed, but moved 50 meters
      fakeNow = fakeNow.add(const Duration(seconds: 5));
      controller.employeeLiveLocation = _createTestLiveLocation(
        userId: 'emp_123',
        latitude: 28.6145,
        longitude: 77.2090,
        updatedAt: fakeNow,
      );

      await controller.triggerLocationProgressCheck('emp_123');
      expect(progressWriteCount, equals(1));
    });

    test(
      '12. Injected riderStreamFactory receives only tripId and current Employee UID',
      () async {
        final riderCtrl = StreamController<CabTripRiderModel?>.broadcast();

        final controller = createController(
          currentUid: 'emp_123',
          riderStreamFactory: (tripId, empId) {
            capturedRiderTripId = tripId;
            capturedRiderEmployeeId = empId;
            return riderCtrl.stream;
          },
        );

        controller.listenToRiderForTest('trip_99', 'emp_123');
        await pumpEventQueue();

        expect(capturedRiderTripId, equals('trip_99'));
        expect(capturedRiderEmployeeId, equals('emp_123'));
        expect(controller.passengerProgressList, isEmpty);

        await riderCtrl.close();
      },
    );

    test(
      '13. prepareForSignOut clears trackingAssignmentId and activeSession',
      () async {
        final activeSession = _createTestSession(
          id: 's_pickup',
          userId: 'emp_123',
          trackingReason: 'cab_pickup_ready',
          status: 'active',
        );
        final controller = createController(activeSession: activeSession);
        controller.trackingAssignmentId = 'ass_1';

        final success = await controller.prepareForSignOut();

        expect(success, isTrue);
        expect(controller.activeSession, isNull);
        expect(controller.trackingAssignmentId, isNull);
        expect(controller.transportTrackingState, equals('inactive'));
      },
    );

    test('14. logout returns true on success', () async {
      final controller = createController();
      final res = await controller.logout();
      expect(res, isTrue);
    });

    test(
      '15. retryTripSynchronization uses latest member status and sets synced',
      () async {
        final member = const CabAssignmentMemberModel(
          id: 'mem_1',
          assignmentId: 'ass_1',
          userId: 'emp_123',
          dateKey: '2026-07-22',
          pickupName: 'Hub',
          pickupAddress: 'Sector 62',
          pickupLatitude: 28.6139,
          pickupLongitude: 77.2090,
          status: 'ready',
        );
        final controller = createController(member: member);
        controller.myRiderRecord = const CabTripRiderModel(
          id: 'r_1',
          tripId: 'trip_1',
          employeeId: 'emp_123',
          status: 'travelling_to_pickup',
        );

        await controller.retryTripSynchronization();

        expect(updatedRiderStatus, equals('ready'));
        expect(controller.transportSyncState, equals('synced'));
      },
    );

    test(
      '16. markReadyAtPickup rejects if distance > 100m for good accuracy',
      () async {
        final member = const CabAssignmentMemberModel(
          id: 'mem_1',
          assignmentId: 'ass_1',
          userId: 'emp_123',
          dateKey: '2026-07-22',
          pickupName: 'Hub',
          pickupAddress: 'Sector 62',
          pickupLatitude: 28.6139,
          pickupLongitude: 77.2090,
        );

        final mockPos = _createTestPosition(
          latitude: 28.6180,
          longitude: 77.2090,
          accuracy: 10.0,
        );

        final controller = createController(
          member: member,
          mockPosition: mockPos,
        );

        await controller.startDuty();
        final res = await controller.markReadyAtPickup();

        expect(res.isAccepted, isFalse);
        expect(res.message, contains('Move closer'));
        expect(controller.isActionLoading, isFalse);
      },
    );

    test(
      '17. retryAssignmentTransition returns false if pendingAssignmentId is null',
      () async {
        final controller = createController();
        final res = await controller.retryAssignmentTransition();
        expect(res, isFalse);
        expect(controller.isActionLoading, isFalse);
      },
    );

    test('18. evaluateGeofence accurately applies 100m/150m bounds', () {
      expect(
        EmployeeTransportController.evaluateGeofence(
          distanceMeters: 99.0,
          accuracyMeters: 50.0,
        ),
        isTrue,
      );
      expect(
        EmployeeTransportController.evaluateGeofence(
          distanceMeters: 101.0,
          accuracyMeters: 50.0,
        ),
        isFalse,
      );
      expect(
        EmployeeTransportController.evaluateGeofence(
          distanceMeters: 140.0,
          accuracyMeters: 120.0,
        ),
        isTrue,
      );
      expect(
        EmployeeTransportController.evaluateGeofence(
          distanceMeters: 151.0,
          accuracyMeters: 120.0,
        ),
        isFalse,
      );
      expect(
        EmployeeTransportController.evaluateGeofence(
          distanceMeters: 50.0,
          accuracyMeters: 151.0,
        ),
        isFalse,
      );
    });

    test(
      '19. startDuty sets isActionLoading to false on early exception',
      () async {
        final controller = createController(currentUid: '');
        final res = await controller.startDuty();
        expect(res.isAccepted, isFalse);
        expect(controller.isActionLoading, isFalse);
      },
    );
  });

  group('PassengerProgressService Security & Strict Status Validation', () {
    test('Employee role accepts only allowed statuses', () async {
      final validProgress = PassengerProgressModel(
        employeeId: 'emp_123',
        passengerDisplayName: 'Employee Name',
        pickupSequence: 1,
        status: 'ready',
        locationFreshness: 'live',
        updatedAt: DateTime.now(),
      );

      expect(
        PassengerProgressService.employeeWritableStatuses.contains(
          validProgress.status,
        ),
        isTrue,
      );

      final invalidProgress = PassengerProgressModel(
        employeeId: 'emp_123',
        passengerDisplayName: 'Employee Name',
        pickupSequence: 1,
        status: 'picked_up',
        locationFreshness: 'live',
        updatedAt: DateTime.now(),
      );

      expect(
        () => PassengerProgressService.upsertPassengerProgress(
          'trip_123',
          invalidProgress,
          isEmployeeRole: true,
        ),
        throwsArgumentError,
      );
    });

    test('Driver role accepts only allowed statuses', () async {
      final invalidDriverProgress = PassengerProgressModel(
        employeeId: 'emp_123',
        passengerDisplayName: 'Employee Name',
        pickupSequence: 1,
        status: 'travelling_to_pickup',
        locationFreshness: 'live',
        updatedAt: DateTime.now(),
      );

      expect(
        () => PassengerProgressService.upsertPassengerProgress(
          'trip_123',
          invalidDriverProgress,
          isEmployeeRole: false,
        ),
        throwsArgumentError,
      );
    });

    test('Empty tripId or employeeId throws ArgumentError', () {
      expect(
        () => PassengerProgressService.watchPassengerProgress(''),
        throwsArgumentError,
      );

      final emptyEmployeeProgress = PassengerProgressModel(
        employeeId: '',
        passengerDisplayName: 'Test',
        pickupSequence: 1,
        status: 'ready',
        locationFreshness: 'live',
        updatedAt: DateTime.now(),
      );

      expect(
        () => PassengerProgressService.upsertPassengerProgress(
          'trip_123',
          emptyEmployeeProgress,
        ),
        throwsArgumentError,
      );
    });
  });
}
