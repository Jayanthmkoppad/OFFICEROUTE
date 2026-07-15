import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/cab_assignment_member_model.dart';
import '../models/cab_assignment_model.dart';

class CabAssignmentService {
  CabAssignmentService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('cab_assignments');

  static CollectionReference<Map<String, dynamic>> get _memberCollection =>
      _firestore.collection('cab_assignment_members');

  /// Creates a daily cab assignment document.
  static Future<String> createAssignment(CabAssignmentModel assignment) async {
    try {
      final docRef = await _collection.add(assignment.toMap());
      return docRef.id;
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabAssignmentService.createAssignment',
      );
      rethrow;
    }
  }

  /// Replaces an existing daily cab assignment document.
  static Future<void> updateAssignment(CabAssignmentModel assignment) async {
    if (assignment.id.isEmpty) {
      throw StateError(
        'CabAssignmentService.updateAssignment requires an assignment id.',
      );
    }

    try {
      await _collection.doc(assignment.id).set(assignment.toMap());
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabAssignmentService.updateAssignment',
      );
      rethrow;
    }
  }

  /// Loads one assignment by Firestore document id.
  static Future<CabAssignmentModel?> getAssignment(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      if (!doc.exists) {
        return null;
      }
      return CabAssignmentModel.fromMap(doc.data() ?? {}, id: doc.id);
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabAssignmentService.getAssignment',
      );
      rethrow;
    }
  }

  /// Loads assignments for a driver using the driver user id.
  static Future<List<CabAssignmentModel>> fetchAssignmentsForDriver({
    required String driverId,
  }) async {
    try {
      final snapshot = await _collection
          .where('driverId', isEqualTo: driverId)
          .get();
      final assignments = snapshot.docs
          .map((doc) => CabAssignmentModel.fromMap(doc.data(), id: doc.id))
          .toList();
      assignments.sort(_compareAssignmentsNewestFirst);
      return assignments;
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabAssignmentService.fetchAssignmentsForDriver',
      );
      rethrow;
    }
  }

  /// Loads the current daily assignment for a driver and date key.
  static Future<CabAssignmentModel?> fetchTodayAssignmentForDriver({
    required String driverId,
    required String dateKey,
  }) async {
    try {
      final snapshot = await _collection
          .where('driverId', isEqualTo: driverId)
          .get();
      final assignments = snapshot.docs
          .map((doc) => CabAssignmentModel.fromMap(doc.data(), id: doc.id))
          .where((assignment) => assignment.dateKey == dateKey)
          .toList(growable: false);
      if (assignments.isEmpty) return null;
      final sorted = [...assignments]..sort(_compareAssignmentsNewestFirst);
      return sorted.first;
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabAssignmentService.fetchTodayAssignmentForDriver',
      );
      rethrow;
    }
  }

  /// Loads the current daily assignment lookup for any assigned member.
  static Future<CabAssignmentMemberModel?> fetchTodayMemberAssignment({
    required String userId,
    required String dateKey,
  }) async {
    try {
      final snapshot = await _memberCollection
          .where('userId', isEqualTo: userId)
          .get();
      final members = snapshot.docs
          .map(
            (doc) =>
                CabAssignmentMemberModel.fromMap(doc.data(), id: doc.id),
          )
          .where((member) => member.dateKey == dateKey)
          .toList(growable: false);
      if (members.isEmpty) return null;
      final sorted = [...members]..sort(_compareMembersNewestFirst);
      return sorted.first;
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabAssignmentService.fetchTodayMemberAssignment',
      );
      rethrow;
    }
  }

  /// Loads assignments for one date key.
  static Future<List<CabAssignmentModel>> fetchAssignmentsForDate({
    required String dateKey,
  }) async {
    try {
      final snapshot = await _collection
          .where('dateKey', isEqualTo: dateKey)
          .get();
      final assignments = snapshot.docs
          .map((doc) => CabAssignmentModel.fromMap(doc.data(), id: doc.id))
          .toList();
      assignments.sort(_compareAssignmentsNewestFirst);
      return assignments;
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabAssignmentService.fetchAssignmentsForDate',
      );
      rethrow;
    }
  }

  /// Emits when an assignment for [dateKey] changes.
  static Stream<void> watchAssignmentsForDate(String dateKey) {
    return _collection
        .where('dateKey', isEqualTo: dateKey)
        .snapshots()
        .map<void>((_) {});
  }

  /// Emits when an assignment member for [dateKey] changes.
  static Stream<void> watchMembersForDate(String dateKey) {
    return _memberCollection
        .where('dateKey', isEqualTo: dateKey)
        .snapshots()
        .map<void>((_) {});
  }

  /// Emits when one assignment document changes.
  static Stream<void> watchAssignment(String assignmentId) {
    return _collection.doc(assignmentId).snapshots().map<void>((_) {});
  }

  /// Emits when members of one assignment change.
  static Stream<void> watchMembersForAssignment(String assignmentId) {
    return _memberCollection
        .where('assignmentId', isEqualTo: assignmentId)
        .snapshots()
        .map<void>((_) {});
  }

  /// Emits when today's assignment lookup for one user changes.
  static Stream<void> watchMemberForUser({
    required String userId,
    required String dateKey,
  }) {
    return _memberCollection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map<void>((_) {});
  }

  /// Emits when today's driver assignment changes.
  static Stream<void> watchDriverAssignment({
    required String driverId,
    required String dateKey,
  }) {
    return _collection
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .map<void>((_) {});
  }

  /// Loads member lookup documents for a specific assignment/date.
  static Future<List<CabAssignmentMemberModel>> fetchMembersForAssignment({
    required String assignmentId,
    required String dateKey,
    String? status,
  }) async {
    try {
      final snapshot = await _memberCollection
          .where('assignmentId', isEqualTo: assignmentId)
          .get();
      final members = snapshot.docs
          .map((doc) => CabAssignmentMemberModel.fromMap(doc.data(), id: doc.id))
          .where((member) =>
              member.dateKey == dateKey &&
              (status == null || member.status == status))
          .toList();
      members.sort((left, right) => left.userId.compareTo(right.userId));
      return members;
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabAssignmentService.fetchMembersForAssignment',
      );
      rethrow;
    }
  }

  /// Loads member lookup documents for a date across assignments.
  static Future<List<CabAssignmentMemberModel>> fetchMembersForDate({
    required String dateKey,
    String? status,
  }) async {
    try {
      final snapshot =
          await _memberCollection.where('dateKey', isEqualTo: dateKey).get();
      final members = snapshot.docs
          .map((doc) => CabAssignmentMemberModel.fromMap(doc.data(), id: doc.id))
          .where((member) => status == null || member.status == status)
          .toList();
      members.sort((left, right) => left.userId.compareTo(right.userId));
      return members;
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabAssignmentService.fetchMembersForDate',
      );
      rethrow;
    }
  }

  /// Writes or replaces assignment member lookup documents.
  static Future<void> upsertAssignmentMembers(
    List<CabAssignmentMemberModel> members,
  ) async {
    if (members.isEmpty) return;

    try {
      final batch = _firestore.batch();
      for (final member in members) {
        final id = member.id.isNotEmpty
            ? member.id
            : '${member.dateKey}_${member.userId}';
        batch.set(_memberCollection.doc(id), member.toMap());
      }
      await batch.commit();
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabAssignmentService.upsertAssignmentMembers',
      );
      rethrow;
    }
  }

  /// Updates one member lookup status.
  static Future<void> updateMemberStatus({
    required String memberId,
    required String status,
    String? role,
    String? driverId,
    String? vehicleId,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (role != null) updateData['role'] = role;
      if (driverId != null) updateData['driverId'] = driverId;
      if (vehicleId != null) updateData['vehicleId'] = vehicleId;

      await _memberCollection.doc(memberId).update(updateData);
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabAssignmentService.updateMemberStatus',
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
    debugPrint('File: lib/core/services/cab_assignment_service.dart');
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

  static int _compareAssignmentsNewestFirst(
    CabAssignmentModel left,
    CabAssignmentModel right,
  ) {
    final leftTime = left.assignedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final rightTime =
        right.assignedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return rightTime.compareTo(leftTime);
  }

  static int _compareMembersNewestFirst(
    CabAssignmentMemberModel left,
    CabAssignmentMemberModel right,
  ) {
    final leftTime = left.updatedAt ??
        left.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final rightTime = right.updatedAt ??
        right.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return rightTime.compareTo(leftTime);
  }
}
