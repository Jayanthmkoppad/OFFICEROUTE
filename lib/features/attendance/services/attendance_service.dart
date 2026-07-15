import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/attendance_model.dart';

class AttendanceService {
  AttendanceService._();

  static final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('attendance');

  static Future<AttendanceModel?> fetchTodayAttendance(String userId) async {
    try {
      final now = DateTime.now();
      return _fetchAttendanceForDay(userId, DateTime(now.year, now.month, now.day));
    } catch (error, stackTrace) {
      _printAttendanceException(
        error: error,
        stackTrace: stackTrace,
        method: 'AttendanceService.fetchTodayAttendance',
      );
      rethrow;
    }
  }

  static Future<List<AttendanceModel>> fetchAttendanceForUser(
    String userId,
  ) async {
    try {
      final snapshot = await _collection
          .where('userId', isEqualTo: userId)
          .limit(400)
          .get();
      final records = snapshot.docs
          .map((doc) => AttendanceModel.fromMap(doc.data(), id: doc.id))
          .toList();

      records.sort((a, b) {
        final aDate = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return records;
    } catch (error, stackTrace) {
      _printAttendanceException(
        error: error,
        stackTrace: stackTrace,
        method: 'AttendanceService.fetchAttendanceForUser',
      );
      rethrow;
    }
  }

  static Future<List<AttendanceModel>> fetchAllAttendance() async {
    try {
      final snapshot = await _collection.limit(1000).get();
      final records = snapshot.docs
          .map((doc) => AttendanceModel.fromMap(doc.data(), id: doc.id))
          .toList();

      records.sort((a, b) {
        final aDate = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return records;
    } catch (error, stackTrace) {
      _printAttendanceException(
        error: error,
        stackTrace: stackTrace,
        method: 'AttendanceService.fetchAllAttendance',
      );
      rethrow;
    }
  }

  /// Emits whenever an attendance document visible to the user changes.
  static Stream<void> watchAttendanceChanges() {
    return _collection.snapshots().map<void>((_) {});
  }

  /// Emits whenever attendance for one user changes.
  static Stream<void> watchAttendanceForUser(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map<void>((_) {});
  }

  static Future<List<AttendanceModel>> fetchAttendanceForMonth({
    required String userId,
    required DateTime month,
  }) async {
    final records = await fetchAttendanceForUser(userId);
    return records.where((record) {
      final date = record.date;
      return date != null && date.year == month.year && date.month == month.month;
    }).toList(growable: false);
  }

  static Future<AttendanceModel> checkIn({
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final existing = await _fetchAttendanceForDay(userId, todayDate);

      if (existing != null) {
        return existing;
      }

      final docRef = await _collection.add(
        AttendanceModel(
          id: '',
          userId: userId,
          status: 'Checked In',
          date: todayDate,
          checkInTime: now,
          checkOutTime: null,
          breakStartTime: null,
          totalBreakMinutes: 0,
          checkInLatitude: latitude,
          checkInLongitude: longitude,
          checkOutLatitude: null,
          checkOutLongitude: null,
          locationValidationStatus: 'validated',
          syncStatus: 'synced',
        ).toMap(),
      );

      final newDoc = await docRef.get();
      final data = newDoc.data();
      if (data == null) {
        throw StateError('Created attendance ${newDoc.id} has no data.');
      }

      return AttendanceModel.fromMap(data, id: newDoc.id);
    } catch (error, stackTrace) {
      _printAttendanceException(
        error: error,
        stackTrace: stackTrace,
        method: 'AttendanceService.checkIn',
      );
      rethrow;
    }
  }

  static Future<AttendanceModel?> checkOut({
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final model = await _fetchAttendanceForDay(userId, todayDate);

      if (model == null) return null;

      final breakMinutes = model.breakStartTime == null
          ? model.totalBreakMinutes
          : model.totalBreakMinutes +
              now.difference(model.breakStartTime!).inMinutes;
      final updated = model.copyWith(
        status: 'Checked Out',
        checkOutTime: now,
        checkOutLatitude: latitude,
        checkOutLongitude: longitude,
        locationValidationStatus: 'validated',
        syncStatus: 'synced',
        totalBreakMinutes: breakMinutes,
        clearBreakStartTime: true,
      );

      await _collection.doc(model.id).set(updated.toMap());
      return updated;
    } catch (error, stackTrace) {
      _printAttendanceException(
        error: error,
        stackTrace: stackTrace,
        method: 'AttendanceService.checkOut',
      );
      rethrow;
    }
  }

  static Future<AttendanceModel?> startBreak(String userId) async {
    try {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final model = await _fetchAttendanceForDay(userId, todayDate);
      if (model == null || model.checkOutTime != null) return model;

      final updated = model.copyWith(
        status: 'On Break',
        breakStartTime: now,
        syncStatus: 'synced',
      );

      await _collection.doc(model.id).set(updated.toMap());
      return updated;
    } catch (error, stackTrace) {
      _printAttendanceException(
        error: error,
        stackTrace: stackTrace,
        method: 'AttendanceService.startBreak',
      );
      rethrow;
    }
  }

  static Future<AttendanceModel?> endBreak(String userId) async {
    try {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final model = await _fetchAttendanceForDay(userId, todayDate);
      if (model == null || model.breakStartTime == null) return model;

      final updated = model.copyWith(
        status: 'Checked In',
        totalBreakMinutes:
            model.totalBreakMinutes + now.difference(model.breakStartTime!).inMinutes,
        clearBreakStartTime: true,
        syncStatus: 'synced',
      );

      await _collection.doc(model.id).set(updated.toMap());
      return updated;
    } catch (error, stackTrace) {
      _printAttendanceException(
        error: error,
        stackTrace: stackTrace,
        method: 'AttendanceService.endBreak',
      );
      rethrow;
    }
  }

  static Future<AttendanceModel?> _fetchAttendanceForDay(
    String userId,
    DateTime day,
  ) async {
    final dateTimestamp = Timestamp.fromDate(DateTime(day.year, day.month, day.day));

    final snapshot = await _collection
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: dateTimestamp)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    return AttendanceModel.fromMap(doc.data(), id: doc.id);
  }

  static void _printAttendanceException({
    required Object error,
    required StackTrace stackTrace,
    required String method,
  }) {
    debugPrint('Attendance Firestore exception');
    debugPrint('File: lib/features/attendance/services/attendance_service.dart');
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
