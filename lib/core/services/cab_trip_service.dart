import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/cab_trip_cancellation.dart';
import '../models/cab_trip_event_model.dart';
import '../models/cab_trip_model.dart';
import '../models/cab_trip_rider_model.dart';

/// Firestore service for cab trip creation and lifecycle updates.
class CabTripService {
  CabTripService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('cab_trips');

  /// Creates a cab trip document.
  static Future<CabTripModel> createTrip(CabTripModel trip) async {
    try {
      final docRef = await _collection.add(trip.toMap());
      final doc = await docRef.get();
      final data = doc.data();
      if (data == null) {
        throw StateError('Created cab trip ${doc.id} has no data.');
      }
      return CabTripModel.fromMap(data, id: doc.id);
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabTripService.createTrip',
      );
      rethrow;
    }
  }

  /// Replaces a cab trip document.
  static Future<CabTripModel> updateTrip(CabTripModel trip) async {
    if (trip.id.isEmpty) {
      throw StateError('CabTripService.updateTrip requires a trip id.');
    }

    try {
      final updated = trip.copyWith(updatedAt: DateTime.now());
      await _collection.doc(trip.id).set(updated.toMap());
      return updated;
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabTripService.updateTrip',
      );
      rethrow;
    }
  }

  /// Loads the active trip for an assignment.
  static Future<CabTripModel?> fetchActiveTripForAssignment({
    required String assignmentId,
  }) async {
    try {
      final snapshot = await _collection
          .where('assignmentId', isEqualTo: assignmentId)
          .get();
      final trips = snapshot.docs
          .map((doc) => CabTripModel.fromMap(doc.data(), id: doc.id))
          .where(
            (trip) => const <String>{
              'created',
              'active',
              'office_arrived',
            }.contains(trip.status),
          )
          .toList();
      if (trips.isEmpty) return null;
      trips.sort(_compareTripsNewestFirst);
      return trips.first;
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabTripService.fetchActiveTripForAssignment',
      );
      rethrow;
    }
  }

  /// Loads cab trips for one date key.
  static Future<List<CabTripModel>> fetchTripsForDate({
    required String dateKey,
  }) async {
    try {
      final snapshot = await _collection
          .where('dateKey', isEqualTo: dateKey)
          .get();
      final trips = snapshot.docs
          .map((doc) => CabTripModel.fromMap(doc.data(), id: doc.id))
          .toList();
      trips.sort(_compareTripsNewestFirst);
      return trips;
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabTripService.fetchTripsForDate',
      );
      rethrow;
    }
  }

  /// Loads all trips assigned to one driver without duplicating trip data.
  static Future<List<CabTripModel>> fetchTripsForDriver(String driverId) async {
    final snapshot = await _collection
        .where('driverId', isEqualTo: driverId)
        .get();
    final trips = snapshot.docs
        .map((doc) => CabTripModel.fromMap(doc.data(), id: doc.id))
        .toList();
    trips.sort(_compareTripsNewestFirst);
    return trips;
  }

  static Future<List<CabTripModel>> fetchAllTrips() async {
    final snapshot = await _collection.get();
    final trips = snapshot.docs
        .map((doc) => CabTripModel.fromMap(doc.data(), id: doc.id))
        .toList();
    trips.sort(_compareTripsNewestFirst);
    return trips;
  }

  /// Emits when a cab trip for [dateKey] changes.
  static Stream<void> watchTripsForDate(String dateKey) {
    return _collection
        .where('dateKey', isEqualTo: dateKey)
        .snapshots()
        .map<void>((_) {});
  }

  /// Emits when trips linked to one assignment change.
  static Stream<void> watchTripsForAssignment(String assignmentId) {
    return _collection
        .where('assignmentId', isEqualTo: assignmentId)
        .snapshots()
        .map<void>((_) {});
  }

  static Stream<void> watchTripsForDriver(String driverId) {
    return _collection
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .map<void>((_) {});
  }

  static Stream<void> watchAllTrips() =>
      _collection.snapshots().map<void>((_) {});

  /// Writes or replaces a rider document under a trip.
  static Future<void> upsertRider(CabTripRiderModel rider) async {
    if (rider.tripId.isEmpty) {
      throw StateError('CabTripService.upsertRider requires a trip id.');
    }

    try {
      final id = rider.id.isNotEmpty ? rider.id : rider.employeeId;
      await _collection
          .doc(rider.tripId)
          .collection('riders')
          .doc(id)
          .set(rider.toMap(), SetOptions(merge: true));
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabTripService.upsertRider',
      );
      rethrow;
    }
  }

  static Future<void> updateRiderFields({
    required String tripId,
    required String riderId,
    required Map<String, Object?> fields,
  }) {
    return _collection.doc(tripId).collection('riders').doc(riderId).set(
      <String, Object?>{...fields, 'updatedAt': Timestamp.now()},
      SetOptions(merge: true),
    );
  }

  static Stream<void> watchRiders(String tripId) {
    return _collection
        .doc(tripId)
        .collection('riders')
        .snapshots()
        .map<void>((_) {});
  }

  static Future<List<CabTripEventModel>> fetchEvents(String tripId) async {
    final snapshot = await _collection.doc(tripId).collection('events').get();
    final events = snapshot.docs
        .map((doc) => CabTripEventModel.fromMap(doc.data(), id: doc.id))
        .toList();
    events.sort(
      (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
        a.createdAt ?? DateTime(1970),
      ),
    );
    return events;
  }

  static Stream<void> watchEvents(String tripId) {
    return _collection
        .doc(tripId)
        .collection('events')
        .snapshots()
        .map<void>((_) {});
  }

  /// Loads rider documents under a trip.
  static Future<List<CabTripRiderModel>> fetchRiders(String tripId) async {
    try {
      final snapshot = await _collection.doc(tripId).collection('riders').get();
      return snapshot.docs
          .map((doc) => CabTripRiderModel.fromMap(doc.data(), id: doc.id))
          .toList(growable: false);
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabTripService.fetchRiders',
      );
      rethrow;
    }
  }

  /// Adds an immutable trip audit event.
  static Future<void> addEvent(CabTripEventModel event) async {
    if (event.tripId.isEmpty) {
      throw StateError('CabTripService.addEvent requires a trip id.');
    }

    try {
      await _collection
          .doc(event.tripId)
          .collection('events')
          .add(event.toMap());
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabTripService.addEvent',
      );
      rethrow;
    }
  }

  /// Atomically terminally cancels a Driver-owned trip without erasing history.
  static Future<void> cancelTripByDriver({
    required String tripId,
    required String driverId,
    required CabTripCancellation cancellation,
  }) async {
    cancellation.validate();
    final normalizedTripId = tripId.trim();
    final normalizedDriverId = driverId.trim();
    if (normalizedTripId.isEmpty || normalizedDriverId.isEmpty) {
      throw StateError('Trip and Driver are required for cancellation.');
    }

    final tripRef = _collection.doc(normalizedTripId);
    await _firestore.runTransaction<void>((transaction) async {
      final tripSnapshot = await transaction.get(tripRef);
      final tripData = tripSnapshot.data();
      if (!tripSnapshot.exists || tripData == null) {
        throw StateError('The trip no longer exists.');
      }
      if ((tripData['driverId'] ?? '').toString() != normalizedDriverId) {
        throw StateError('Only the assigned Driver may cancel this trip.');
      }
      final currentStatus = (tripData['status'] ?? '').toString();
      if (!const {'created', 'active'}.contains(currentStatus)) {
        throw StateError('Only an active trip may be cancelled.');
      }

      final assignmentId = (tripData['assignmentId'] ?? '').toString();
      final dateKey = (tripData['dateKey'] ?? '').toString();
      final employeeIds = (tripData['employeeIds'] is List)
          ? (tripData['employeeIds'] as List)
                .map((value) => value.toString())
                .where((value) => value.trim().isNotEmpty)
                .toList(growable: false)
          : const <String>[];
      if (assignmentId.isEmpty || dateKey.isEmpty || employeeIds.isEmpty) {
        throw StateError('Trip linkage is incomplete and cannot be cancelled.');
      }

      final assignmentRef = _firestore
          .collection('cab_assignments')
          .doc(assignmentId);
      final assignmentSnapshot = await transaction.get(assignmentRef);
      if (!assignmentSnapshot.exists ||
          assignmentSnapshot.data()?['driverId'] != normalizedDriverId) {
        throw StateError('The linked assignment is invalid.');
      }

      final riderSnapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      final memberSnapshots =
          <String, DocumentSnapshot<Map<String, dynamic>>>{};
      final progressSnapshots =
          <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final employeeId in employeeIds) {
        riderSnapshots[employeeId] = await transaction.get(
          tripRef.collection('riders').doc(employeeId),
        );
        memberSnapshots[employeeId] = await transaction.get(
          _firestore
              .collection('cab_assignment_members')
              .doc('${dateKey}_$employeeId'),
        );
        progressSnapshots[employeeId] = await transaction.get(
          tripRef.collection('passenger_progress').doc(employeeId),
        );
      }

      final summary = cancellation.safeSummary;
      transaction.update(tripRef, <String, Object?>{
        'status': 'cancelled',
        'cancellationReason': cancellation.reason.label,
        'cancellationExplanation': cancellation.explanation.trim(),
        'cancelledBy': normalizedDriverId,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(assignmentRef, <String, Object?>{
        'status': 'cancelled',
        'cancellationReason': cancellation.reason.label,
        'cancellationExplanation': cancellation.explanation.trim(),
        'cancelledBy': normalizedDriverId,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      const preservedStatuses = <String>{
        'picked_up',
        'boarded',
        'dropped',
        'completed',
        'no_show',
        'skipped',
      };
      for (final employeeId in employeeIds) {
        final riderSnapshot = riderSnapshots[employeeId]!;
        final riderStatus = (riderSnapshot.data()?['status'] ?? '').toString();
        if (riderSnapshot.exists) {
          transaction.update(riderSnapshot.reference, <String, Object?>{
            'status': preservedStatuses.contains(riderStatus)
                ? riderStatus
                : 'cancelled',
            'tripCancellationReason': cancellation.reason.label,
            'tripCancelledAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        final memberSnapshot = memberSnapshots[employeeId]!;
        final memberStatus = (memberSnapshot.data()?['status'] ?? '')
            .toString();
        if (memberSnapshot.exists) {
          transaction.update(memberSnapshot.reference, <String, Object?>{
            'status': preservedStatuses.contains(memberStatus)
                ? memberStatus
                : 'cancelled',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        final progressSnapshot = progressSnapshots[employeeId]!;
        final progressStatus = (progressSnapshot.data()?['status'] ?? '')
            .toString();
        if (progressSnapshot.exists) {
          transaction.update(progressSnapshot.reference, <String, Object?>{
            'status': preservedStatuses.contains(progressStatus)
                ? progressStatus
                : 'cancelled',
            'remark': 'trip_cancelled',
            'transportActive': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        final notificationRef = _firestore
            .collection('notifications')
            .doc('${normalizedTripId}_${employeeId}_cancelled');
        transaction.set(notificationRef, <String, Object?>{
          'id': notificationRef.id,
          'userId': employeeId,
          'recipientUserId': employeeId,
          'title': 'Cab trip cancelled',
          'body': 'Your cab trip was cancelled: $summary.',
          'type': 'cab_trip_cancelled',
          'source': 'trip_event',
          'tripId': normalizedTripId,
          'assignmentId': assignmentId,
          'driverId': normalizedDriverId,
          'cancellationReason': cancellation.reason.label,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'readAt': null,
        });
      }

      transaction.set(
        tripRef.collection('events').doc('${normalizedTripId}_cancelled'),
        <String, Object?>{
          'tripId': normalizedTripId,
          'assignmentId': assignmentId,
          'actorUserId': normalizedDriverId,
          'eventType': 'trip_cancelled',
          'message': summary,
          'createdAt': FieldValue.serverTimestamp(),
          'metadata': <String, Object?>{
            'reason': cancellation.reason.label,
            'explanation': cancellation.explanation.trim(),
          },
        },
      );
    });
  }

  static void _printFirestoreException({
    required Object error,
    required StackTrace stackTrace,
    required String method,
  }) {
    debugPrint('Cab trip Firestore exception');
    debugPrint('File: lib/core/services/cab_trip_service.dart');
    debugPrint('Method: $method');
    debugPrint('Runtime type: ${error.runtimeType}');

    if (error is FirebaseException) {
      debugPrint('FirebaseException.plugin: ${error.plugin}');
      debugPrint('FirebaseException.code: ${error.code}');
      debugPrint('FirebaseException.message: ${error.message}');
    }

    debugPrint('Exception: $error');
    debugPrint('Stack trace:\n$stackTrace');
  }

  static int _compareTripsNewestFirst(CabTripModel left, CabTripModel right) {
    final leftTime = left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final rightTime = right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return rightTime.compareTo(leftTime);
  }
}
