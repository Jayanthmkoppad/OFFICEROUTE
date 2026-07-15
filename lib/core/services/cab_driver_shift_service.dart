import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/cab_driver_shift_model.dart';

class CabDriverShiftService {
  CabDriverShiftService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('cab_driver_shifts');

  static Future<String> createShift(CabDriverShiftModel shift) async {
    try {
      final docRef = await _collection.add(shift.toMap());
      return docRef.id;
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabDriverShiftService.createShift',
      );
      rethrow;
    }
  }

  static Future<void> updateShift(CabDriverShiftModel shift) async {
    if (shift.id.isEmpty) {
      throw StateError('CabDriverShiftService.updateShift requires a shift id.');
    }

    try {
      await _collection.doc(shift.id).set(shift.toMap());
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabDriverShiftService.updateShift',
      );
      rethrow;
    }
  }

  static Future<CabDriverShiftModel?> getShift(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      if (!doc.exists) {
        return null;
      }
      return CabDriverShiftModel.fromMap(doc.data() ?? {}, id: doc.id);
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabDriverShiftService.getShift',
      );
      rethrow;
    }
  }

  static Future<List<CabDriverShiftModel>> fetchShiftsForDriver({
    required String driverId,
  }) async {
    try {
      final snapshot = await _collection
          .where('driverId', isEqualTo: driverId)
          .orderBy('shiftDate', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => CabDriverShiftModel.fromMap(doc.data(), id: doc.id))
          .toList();
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabDriverShiftService.fetchShiftsForDriver',
      );
      rethrow;
    }
  }

  static Future<List<CabDriverShiftModel>> fetchAllShifts() async {
    try {
      final snapshot = await _collection.orderBy('shiftDate', descending: false).get();
      return snapshot.docs
          .map((doc) => CabDriverShiftModel.fromMap(doc.data(), id: doc.id))
          .toList();
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabDriverShiftService.fetchAllShifts',
      );
      rethrow;
    }
  }

  static void _printFirestoreException({
    required Object error,
    required StackTrace stackTrace,
    required String method,
  }) {
    debugPrint('Firestore exception');
    debugPrint('File: lib/core/services/cab_driver_shift_service.dart');
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
}
