import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/customer_visit_model.dart';

class CustomerVisitService {
  CustomerVisitService._();

  static final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('customer_visits');

  static Future<List<CustomerVisitModel>> fetchVisitsForUser(
    String userId,
  ) async {
    try {
      final snapshot = await _collection
          .where('userId', isEqualTo: userId)
          .limit(250)
          .get();

      final visits = snapshot.docs
          .map((doc) => CustomerVisitModel.fromMap(doc.data(), id: doc.id))
          .toList();

      visits.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return visits;
    } catch (error, stackTrace) {
      _printCustomerVisitException(
        error: error,
        stackTrace: stackTrace,
        method: 'CustomerVisitService.fetchVisitsForUser',
      );
      rethrow;
    }
  }

  static Future<List<CustomerVisitModel>> fetchAllVisits() async {
    try {
      final snapshot = await _collection.limit(500).get();

      final visits = snapshot.docs
          .map((doc) => CustomerVisitModel.fromMap(doc.data(), id: doc.id))
          .toList();

      visits.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return visits;
    } catch (error, stackTrace) {
      _printCustomerVisitException(
        error: error,
        stackTrace: stackTrace,
        method: 'CustomerVisitService.fetchAllVisits',
      );
      rethrow;
    }
  }

  /// Loads visits with lifecycle activity on one operational day.
  static Future<List<CustomerVisitModel>> fetchOperationalVisitsForDate(
    DateTime day,
  ) async {
    try {
      final start = DateTime(day.year, day.month, day.day);
      final end = start.add(const Duration(days: 1));
      final createdFuture = _collection
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThan: Timestamp.fromDate(end))
          .get();
      final startedFuture = _collection
          .where('checkInTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('checkInTime', isLessThan: Timestamp.fromDate(end))
          .get();
      final checkedOutFuture = _collection
          .where('checkOutTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('checkOutTime', isLessThan: Timestamp.fromDate(end))
          .get();
      final completedFuture = _collection
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('completedAt', isLessThan: Timestamp.fromDate(end))
          .get();
      final snapshotFutures = <Future<QuerySnapshot<Map<String, dynamic>>>>[
        createdFuture,
        startedFuture,
        checkedOutFuture,
        completedFuture,
      ];
      final now = DateTime.now();
      final isToday = day.year == now.year &&
          day.month == now.month &&
          day.day == now.day;
      if (isToday) {
        snapshotFutures.add(
          _collection.where('status', isEqualTo: 'checked_in').get(),
        );
      }
      final snapshots = await Future.wait(snapshotFutures);
      final visitsById = <String, CustomerVisitModel>{};
      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          visitsById[doc.id] = CustomerVisitModel.fromMap(
            doc.data(),
            id: doc.id,
          );
        }
      }
      final visits = visitsById.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return visits;
    } catch (error, stackTrace) {
      _printCustomerVisitException(
        error: error,
        stackTrace: stackTrace,
        method: 'CustomerVisitService.fetchOperationalVisitsForDate',
      );
      rethrow;
    }
  }

  /// Emits when visits updated on one operational day change.
  static Stream<void> watchVisitsForDate(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return _collection
        .where('updatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('updatedAt', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map<void>((_) {});
  }

  /// Emits when the active visit set changes.
  static Stream<void> watchActiveVisitChanges() {
    return _collection
        .where('status', isEqualTo: 'checked_in')
        .snapshots()
        .map<void>((_) {});
  }

  /// Emits whenever a customer visit visible to the user changes.
  static Stream<void> watchVisitChanges() {
    return _collection.snapshots().map<void>((_) {});
  }

  /// Emits whenever a customer visit for one user changes.
  static Stream<void> watchVisitsForUser(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map<void>((_) {});
  }

  static Future<List<CustomerVisitModel>> fetchCustomerHistory({
    required String userId,
    required String customerName,
  }) async {
    try {
      final snapshot = await _collection
          .where('userId', isEqualTo: userId)
          .where('customerName', isEqualTo: customerName)
          .limit(50)
          .get();

      final visits = snapshot.docs
          .map((doc) => CustomerVisitModel.fromMap(doc.data(), id: doc.id))
          .toList();

      visits.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return visits;
    } catch (error, stackTrace) {
      _printCustomerVisitException(
        error: error,
        stackTrace: stackTrace,
        method: 'CustomerVisitService.fetchCustomerHistory',
      );
      rethrow;
    }
  }

  static Future<CustomerVisitModel> createVisit({
    required String userId,
    required String customerName,
    required String customerAddress,
    required String customerPhone,
    required String purpose,
    required String notes,
    required String vehicleDetails,
    required String motorSerialNumber,
    required String controllerSerialNumber,
    required String warrantyStatus,
    required String issueCategory,
    required String issueDescription,
    required List<String> partsUsed,
    required String technicianNotes,
    String dealerName = '',
    String complaintId = '',
    String dealerPinCode = '',
    double? dealerLatitude,
    double? dealerLongitude,
    String priority = '',
    DateTime? preferredVisitDate,
    int? expectedDurationMinutes,
    String serviceCentreName = '',
    double? serviceCentreDistanceKm,
    double? roadDistanceKm,
    int? estimatedTravelMinutes,
    double? travelCostEstimate,
    DateTime? assignedAt,
    String vehicleNumber = '',
    String batterySerialNumber = '',
  }) async {
    try {
      final now = DateTime.now();
      final visit = CustomerVisitModel(
        id: '',
        userId: userId,
        customerName: customerName,
        customerAddress: customerAddress,
        customerPhone: customerPhone,
        purpose: purpose,
        status: 'planned',
        notes: notes,
        vehicleDetails: vehicleDetails,
        motorSerialNumber: motorSerialNumber,
        controllerSerialNumber: controllerSerialNumber,
        warrantyStatus: warrantyStatus,
        issueCategory: issueCategory,
        issueDescription: issueDescription,
        partsUsed: partsUsed,
        technicianNotes: technicianNotes,
        photoUrls: const <String>[],
        videoPlaceholderStatus: 'pending',
        signaturePlaceholderStatus: 'pending',
        createdAt: now,
        updatedAt: now,
        checkInTime: null,
        checkOutTime: null,
        completedAt: null,
        checkInLatitude: null,
        checkInLongitude: null,
        checkOutLatitude: null,
        checkOutLongitude: null,
        dealerName: dealerName,
        complaintId: complaintId,
        dealerPinCode: dealerPinCode,
        dealerLatitude: dealerLatitude,
        dealerLongitude: dealerLongitude,
        priority: priority,
        preferredVisitDate: preferredVisitDate,
        expectedDurationMinutes: expectedDurationMinutes,
        serviceCentreName: serviceCentreName,
        serviceCentreDistanceKm: serviceCentreDistanceKm,
        roadDistanceKm: roadDistanceKm,
        estimatedTravelMinutes: estimatedTravelMinutes,
        travelCostEstimate: travelCostEstimate,
        assignedAt: assignedAt == null ? null : now,
        vehicleNumber: vehicleNumber,
        batterySerialNumber: batterySerialNumber,
      );

      final docRef = await _collection.add(visit.toMap());
      final doc = await docRef.get();
      final data = doc.data();
      if (data == null) {
        throw StateError('Created customer visit ${doc.id} has no data.');
      }

      return CustomerVisitModel.fromMap(data, id: doc.id);
    } catch (error, stackTrace) {
      _printCustomerVisitException(
        error: error,
        stackTrace: stackTrace,
        method: 'CustomerVisitService.createVisit',
      );
      rethrow;
    }
  }

  static Future<CustomerVisitModel> updateVisit(CustomerVisitModel visit) async {
    try {
      final updatedVisit = visit.copyWith(updatedAt: DateTime.now());
      await _collection.doc(visit.id).update(updatedVisit.toMap());
      return updatedVisit;
    } catch (error, stackTrace) {
      _printCustomerVisitException(
        error: error,
        stackTrace: stackTrace,
        method: 'CustomerVisitService.updateVisit',
      );
      rethrow;
    }
  }

  /// Assigns or reassigns a planned visit and records the assignment time.
  static Future<CustomerVisitModel> assignEngineer({
    required CustomerVisitModel visit,
    required String engineerId,
  }) async {
    final now = DateTime.now();
    return updateVisit(
      visit.copyWith(
        userId: engineerId,
        assignedAt: visit.assignedAt ?? now,
        updatedAt: now,
      ),
    );
  }

  static Future<CustomerVisitModel> checkIn({
    required CustomerVisitModel visit,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final updatedVisit = visit.copyWith(
        status: 'checked_in',
        checkInTime: DateTime.now(),
        checkInLatitude: latitude,
        checkInLongitude: longitude,
        updatedAt: DateTime.now(),
      );

      await _collection.doc(visit.id).update(updatedVisit.toMap());
      return updatedVisit;
    } catch (error, stackTrace) {
      _printCustomerVisitException(
        error: error,
        stackTrace: stackTrace,
        method: 'CustomerVisitService.checkIn',
      );
      rethrow;
    }
  }

  static Future<CustomerVisitModel> checkOut({
    required CustomerVisitModel visit,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final updatedVisit = visit.copyWith(
        status: 'checked_out',
        checkOutTime: DateTime.now(),
        checkOutLatitude: latitude,
        checkOutLongitude: longitude,
        updatedAt: DateTime.now(),
      );

      await _collection.doc(visit.id).update(updatedVisit.toMap());
      return updatedVisit;
    } catch (error, stackTrace) {
      _printCustomerVisitException(
        error: error,
        stackTrace: stackTrace,
        method: 'CustomerVisitService.checkOut',
      );
      rethrow;
    }
  }

  static Future<CustomerVisitModel> addPhotoReference({
    required CustomerVisitModel visit,
    required String photoUrl,
  }) async {
    try {
      final updatedVisit = visit.copyWith(
        photoUrls: [...visit.photoUrls, photoUrl],
        updatedAt: DateTime.now(),
      );

      await _collection.doc(visit.id).update(updatedVisit.toMap());
      return updatedVisit;
    } catch (error, stackTrace) {
      _printCustomerVisitException(
        error: error,
        stackTrace: stackTrace,
        method: 'CustomerVisitService.addPhotoReference',
      );
      rethrow;
    }
  }

  static Future<CustomerVisitModel> completeVisit({
    required CustomerVisitModel visit,
    required String technicianNotes,
    required List<String> partsUsed,
    required String signatureStatus,
    required String videoStatus,
    String? resolutionStatus,
  }) async {
    try {
      final now = DateTime.now();
      final updatedVisit = visit.copyWith(
        status: 'completed',
        technicianNotes: technicianNotes,
        partsUsed: partsUsed,
        signaturePlaceholderStatus: signatureStatus,
        videoPlaceholderStatus: videoStatus,
        resolutionStatus: resolutionStatus ?? visit.resolutionStatus,
        completedAt: now,
        updatedAt: now,
      );

      await _collection.doc(visit.id).update(updatedVisit.toMap());
      return updatedVisit;
    } catch (error, stackTrace) {
      _printCustomerVisitException(
        error: error,
        stackTrace: stackTrace,
        method: 'CustomerVisitService.completeVisit',
      );
      rethrow;
    }
  }

  static void _printCustomerVisitException({
    required Object error,
    required StackTrace stackTrace,
    required String method,
  }) {
    debugPrint('Customer visit Firestore exception');
    debugPrint(
      'File: lib/features/customer_visits/services/customer_visit_service.dart',
    );
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
