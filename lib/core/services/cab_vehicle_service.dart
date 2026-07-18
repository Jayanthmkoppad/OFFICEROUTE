import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/cab_vehicle_model.dart';

class CabVehicleService {
  CabVehicleService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('cab_vehicles');

  static Future<String> createVehicle(CabVehicleModel vehicle) async {
    try {
      final docRef = await _collection.add(vehicle.toMap());
      return docRef.id;
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabVehicleService.createVehicle',
      );
      rethrow;
    }
  }

  static Future<void> updateVehicle(CabVehicleModel vehicle) async {
    if (vehicle.id.isEmpty) {
      throw StateError(
        'CabVehicleService.updateVehicle requires a vehicle id.',
      );
    }

    try {
      await _collection.doc(vehicle.id).set(vehicle.toMap());
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabVehicleService.updateVehicle',
      );
      rethrow;
    }
  }

  static Future<CabVehicleModel?> getVehicle(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      if (!doc.exists) {
        return null;
      }
      return CabVehicleModel.fromMap(doc.data() ?? {}, id: doc.id);
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabVehicleService.getVehicle',
      );
      rethrow;
    }
  }

  static Future<List<CabVehicleModel>> fetchAllVehicles() async {
    try {
      final snapshot = await _collection.orderBy('vehicleNumber').get();
      return snapshot.docs
          .map((doc) => CabVehicleModel.fromMap(doc.data(), id: doc.id))
          .toList();
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabVehicleService.fetchAllVehicles',
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
    debugPrint('File: lib/core/services/cab_vehicle_service.dart');
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
