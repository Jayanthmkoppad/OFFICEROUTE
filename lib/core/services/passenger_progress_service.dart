import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/passenger_progress_model.dart';

/// Firestore service for watching and updating privacy-safe passenger progress documents
/// under `cab_trips/{tripId}/passenger_progress/{employeeId}`.
class PassengerProgressService {
  PassengerProgressService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Set<String> employeeWritableStatuses = {
    'travelling_to_pickup',
    'near_pickup',
    'ready',
  };

  static const Set<String> driverWritableStatuses = {
    'cab_arrived',
    'waiting',
    'picked_up',
    'skipped',
    'no_show',
    'dropped',
  };

  static CollectionReference<Map<String, dynamic>> _progressCollection(
    String tripId,
  ) {
    return _firestore
        .collection('cab_trips')
        .doc(tripId)
        .collection('passenger_progress');
  }

  /// Watches all passenger progress documents for a given trip.
  static Stream<List<PassengerProgressModel>> watchPassengerProgress(
    String tripId,
  ) {
    if (tripId.isEmpty) {
      throw ArgumentError('tripId cannot be empty');
    }
    return _progressCollection(tripId).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => PassengerProgressModel.fromMap(doc.data(), id: doc.id))
          .toList();
      list.sort((a, b) => a.pickupSequence.compareTo(b.pickupSequence));
      return list;
    });
  }

  /// Writes or updates one passenger's sanitized progress document.
  static Future<void> upsertPassengerProgress(
    String tripId,
    PassengerProgressModel progress, {
    bool isEmployeeRole = true,
  }) async {
    if (tripId.isEmpty) {
      throw ArgumentError('tripId cannot be empty');
    }
    if (progress.employeeId.isEmpty) {
      throw ArgumentError('employeeId cannot be empty');
    }

    final allowedStatuses = isEmployeeRole
        ? employeeWritableStatuses
        : driverWritableStatuses;

    if (!allowedStatuses.contains(progress.status)) {
      throw ArgumentError(
        'Invalid status "${progress.status}" for ${isEmployeeRole ? "employee" : "driver"} role',
      );
    }

    await _progressCollection(
      tripId,
    ).doc(progress.employeeId).set(progress.toMap(), SetOptions(merge: true));
  }
}
