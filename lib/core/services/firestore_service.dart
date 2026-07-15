import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';

class FirestoreService {
  FirestoreService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> createUser({
    required String uid,
    required String name,
    required String email,
  }) async {
    try {
      final user = UserModel(
        uid: uid,
        name: name,
        email: email,
        phone: '',
        role: 'employee',
        profileImage: '',
      );

      await _firestore.collection('users').doc(uid).set(user.toMap());
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'FirestoreService.createUser',
      );
      rethrow;
    }
  }

  static Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists) {
        debugPrint('Firestore document not found: users/$uid');
        return null;
      }

      final data = doc.data();
      if (data == null) {
        throw StateError('Firestore document users/$uid has no data.');
      }

      return UserModel.fromMap(data);
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'FirestoreService.getUser',
      );
      rethrow;
    }
  }

  static Future<UserModel> getOrCreateUser({
    required String uid,
    required String email,
    required String name,
  }) async {
    final existingUser = await getUser(uid);
    if (existingUser != null) {
      return existingUser;
    }

    await createUser(uid: uid, name: name, email: email);

    final createdUser = await getUser(uid);
    if (createdUser == null) {
      throw StateError(
        'Firestore document users/$uid was created but could not be loaded.',
      );
    }

    return createdUser;
  }

  static Future<List<UserModel>> fetchUsersByIds(List<String> uids) async {
    if (uids.isEmpty) return const <UserModel>[];

    final query = _firestore.collection('users');
    final users = <UserModel>[];

    if (uids.length <= 10) {
      final snapshot = await query.where('uid', whereIn: uids).get();
      users.addAll(snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .where((user) => user.uid.isNotEmpty));
    } else {
      for (final uid in uids) {
        final user = await getUser(uid);
        if (user != null && user.uid.isNotEmpty) {
          users.add(user);
        }
      }
    }

    return users;
  }

  /// Loads users by role from the existing `users` collection.
  ///
  /// Cab features must use this method for driver/employee identity instead of
  /// duplicating names, phone numbers, or roles in cab-specific collections.
  static Future<List<UserModel>> fetchUsersByRole(String role) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: role)
          .get();

      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .where((user) => user.uid.isNotEmpty)
          .toList(growable: false);
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'FirestoreService.fetchUsersByRole',
      );
      rethrow;
    }
  }

  static Future<void> updateUser(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).update(user.toMap());
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'FirestoreService.updateUser',
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
    debugPrint('File: lib/core/services/firestore_service.dart');
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
