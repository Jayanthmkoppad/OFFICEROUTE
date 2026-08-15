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
    'waiting',
    'go_to_pickup',
    'on_the_way',
    'running_late',
    'not_coming',
  };

  static const Set<String> employeeRemarks = {
    'waiting',
    'go_to_pickup',
    'on_the_way',
    'ready',
    'running_late',
    'not_coming',
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

  /// Watches all passenger progress documents for a given trip. Admin/Driver
  /// surfaces use this only where Firestore rules authorize trip-wide access.
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

  /// Watches only one Employee's privacy-safe progress document.
  static Stream<List<PassengerProgressModel>> watchOwnPassengerProgress(
    String tripId,
    String employeeId,
  ) {
    if (tripId.isEmpty || employeeId.isEmpty) {
      throw ArgumentError('tripId and employeeId cannot be empty');
    }
    return _progressCollection(tripId).doc(employeeId).snapshots().map((doc) {
      final data = doc.data();
      return data == null
          ? const <PassengerProgressModel>[]
          : <PassengerProgressModel>[
              PassengerProgressModel.fromMap(data, id: doc.id),
            ];
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

  static Future<void> updateOwnRemark(
    String tripId,
    String employeeId,
    String remark,
  ) async {
    if (tripId.isEmpty || employeeId.isEmpty) {
      throw ArgumentError('tripId and employeeId cannot be empty');
    }
    if (!employeeRemarks.contains(remark) || remark == 'ready') {
      throw ArgumentError('Invalid direct employee remark "$remark"');
    }
    await _progressCollection(tripId).doc(employeeId).update({
      'status': remark,
      'remark': remark,
      'transportActive': remark != 'not_coming',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
