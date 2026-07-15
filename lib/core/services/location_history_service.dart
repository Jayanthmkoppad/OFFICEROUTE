import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/location_history_point_model.dart';

class LocationHistoryService {
  LocationHistoryService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _pointsCollection(
    String sessionId,
  ) {
    return _firestore
        .collection('location_sessions')
        .doc(sessionId)
        .collection('points');
  }

  static Future<LocationHistoryPointModel> addPoint(
    LocationHistoryPointModel point,
  ) async {
    try {
      final docRef = _pointsCollection(point.sessionId).doc();
      final savedPoint = LocationHistoryPointModel(
        id: docRef.id,
        userId: point.userId,
        sessionId: point.sessionId,
        trackingReason: point.trackingReason,
        sequence: point.sequence,
        latitude: point.latitude,
        longitude: point.longitude,
        accuracy: point.accuracy,
        speed: point.speed,
        heading: point.heading,
        source: point.source,
        syncStatus: point.syncStatus,
        recordedAt: point.recordedAt,
      );

      await docRef.set(savedPoint.toMap());
      return savedPoint;
    } catch (error, stackTrace) {
      _printLocationHistoryException(
        error: error,
        stackTrace: stackTrace,
        method: 'LocationHistoryService.addPoint',
      );
      rethrow;
    }
  }

  static Future<List<LocationHistoryPointModel>> fetchSessionPoints(
    String sessionId,
  ) async {
    try {
      final snapshot = await _pointsCollection(sessionId)
          .orderBy('sequence')
          .limit(1000)
          .get();

      return snapshot.docs
          .map((doc) => LocationHistoryPointModel.fromMap(
                doc.data(),
                id: doc.id,
              ))
          .toList(growable: false);
    } catch (error, stackTrace) {
      _printLocationHistoryException(
        error: error,
        stackTrace: stackTrace,
        method: 'LocationHistoryService.fetchSessionPoints',
      );
      rethrow;
    }
  }

  static void _printLocationHistoryException({
    required Object error,
    required StackTrace stackTrace,
    required String method,
  }) {
    debugPrint('Location history Firestore exception');
    debugPrint('File: lib/core/services/location_history_service.dart');
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
