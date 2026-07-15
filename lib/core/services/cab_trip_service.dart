import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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
          .set(rider.toMap());
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabTripService.upsertRider',
      );
      rethrow;
    }
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

  static int _compareTripsNewestFirst(
    CabTripModel left,
    CabTripModel right,
  ) {
    final leftTime = left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final rightTime =
        right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return rightTime.compareTo(leftTime);
  }
}
