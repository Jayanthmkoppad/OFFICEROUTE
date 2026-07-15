import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/complaint_model.dart';

class ComplaintService {
  ComplaintService._();

  static final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('complaints');

  static Future<List<ComplaintModel>> fetchComplaintsForUser(
    String userId,
  ) async {
    try {
      final snapshot = await _collection
          .where('userId', isEqualTo: userId)
          .limit(250)
          .get();

      final complaints = snapshot.docs
          .map((doc) => ComplaintModel.fromMap(doc.data(), id: doc.id))
          .toList();

      complaints.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return complaints;
    } catch (error, stackTrace) {
      _printComplaintException(
        error: error,
        stackTrace: stackTrace,
        method: 'ComplaintService.fetchComplaintsForUser',
      );
      rethrow;
    }
  }

  static Future<List<ComplaintModel>> fetchAllComplaints() async {
    try {
      final snapshot = await _collection.limit(500).get();

      final complaints = snapshot.docs
          .map((doc) => ComplaintModel.fromMap(doc.data(), id: doc.id))
          .toList();

      complaints.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return complaints;
    } catch (error, stackTrace) {
      _printComplaintException(
        error: error,
        stackTrace: stackTrace,
        method: 'ComplaintService.fetchAllComplaints',
      );
      rethrow;
    }
  }

  static Future<ComplaintModel> createComplaint(
    ComplaintModel complaint,
  ) async {
    try {
      final docRef = await _collection.add(complaint.toMap());
      final doc = await docRef.get();
      final data = doc.data();
      if (data == null) {
        throw StateError('Created complaint ${doc.id} has no data.');
      }

      return ComplaintModel.fromMap(data, id: doc.id);
    } catch (error, stackTrace) {
      _printComplaintException(
        error: error,
        stackTrace: stackTrace,
        method: 'ComplaintService.createComplaint',
      );
      rethrow;
    }
  }

  static Future<ComplaintModel> updateComplaint(
    ComplaintModel complaint,
  ) async {
    try {
      final updatedComplaint = complaint.copyWith(updatedAt: DateTime.now());
      await _collection.doc(complaint.id).update(updatedComplaint.toMap());
      return updatedComplaint;
    } catch (error, stackTrace) {
      _printComplaintException(
        error: error,
        stackTrace: stackTrace,
        method: 'ComplaintService.updateComplaint',
      );
      rethrow;
    }
  }

  static Future<ComplaintModel> linkVisit({
    required ComplaintModel complaint,
    required String visitId,
    required String visitStatus,
  }) async {
    try {
      final updatedComplaint = complaint.copyWith(
        linkedVisitId: visitId,
        visitStatus: visitStatus,
        status: 'visit_scheduled',
        updatedAt: DateTime.now(),
      );

      await _collection.doc(complaint.id).update(updatedComplaint.toMap());
      return updatedComplaint;
    } catch (error, stackTrace) {
      _printComplaintException(
        error: error,
        stackTrace: stackTrace,
        method: 'ComplaintService.linkVisit',
      );
      rethrow;
    }
  }

  static void _printComplaintException({
    required Object error,
    required StackTrace stackTrace,
    required String method,
  }) {
    debugPrint('Complaint Firestore exception');
    debugPrint('File: lib/features/complaints/services/complaint_service.dart');
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
