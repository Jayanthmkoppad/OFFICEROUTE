import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';

typedef UserSessionSnapshot = ({UserModel? user, bool isFromCache});

class FirestoreService {
  FirestoreService._();

  static const bootstrapAdministratorEmail = 'jayanthmkoppad2@gmail.com';

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

  static Future<void> ensureBootstrapAdministrator({
    required String uid,
    required String email,
    required String name,
  }) {
    final now = Timestamp.now();
    return _firestore.collection('users').doc(uid).set(<String, Object?>{
      'uid': uid,
      'email': email.trim().toLowerCase(),
      'name': name.trim().isEmpty ? 'Administrator' : name.trim(),
      'role': 'application_owner',
      'sessionRole': 'application_owner',
      'sessionApproved': true,
      'approvalStatus': SessionApprovalStatus.approved.firestoreValue,
      'status': 'active',
      'isFirstLogin': false,
      'lastLogin': now,
      'lastSeen': now,
    }, SetOptions(merge: true));
  }

  static Future<UserModel?> findUserByEmail(String email) async {
    final snapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return UserModel.fromMap(snapshot.docs.first.data());
  }

  /// Emits whenever the existing `users/{uid}` profile document changes.
  static Stream<void> watchUser(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map<void>((_) {});
  }

  /// Realtime, metadata-aware session state for the authenticated access gate.
  /// Cached approval is never treated as a fresh authorization decision.
  static Stream<UserSessionSnapshot> watchUserSession(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots(includeMetadataChanges: true)
        .map(
          (doc) => (
            user: doc.exists && doc.data() != null
                ? UserModel.fromMap(doc.data()!)
                : null,
            isFromCache: doc.metadata.isFromCache,
          ),
        );
  }

  static Future<UserSessionSnapshot> refreshUserSession(String uid) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    return (
      user: doc.exists && doc.data() != null
          ? UserModel.fromMap(doc.data()!)
          : null,
      isFromCache: false,
    );
  }

  /// Emits whenever the existing organization user directory changes.
  static Stream<void> watchUsers() {
    return _firestore.collection('users').snapshots().map<void>((_) {});
  }

  /// Updates supported personal fields without replacing unrelated user data.
  static Future<void> updateUserFields({
    required String uid,
    required Map<String, Object?> fields,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).update(fields);
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'FirestoreService.updateUserFields',
      );
      rethrow;
    }
  }

  static Future<void> submitSessionAccessRequest({
    required String uid,
    required Map<String, Object?> fields,
  }) async {
    final now = Timestamp.now();
    await _firestore
        .collection('users')
        .doc(uid)
        .set(
          <String, Object?>{
            ...fields,
            'uid': uid,
            'sessionApproved': false,
            'approvalStatus': SessionApprovalStatus.pending.firestoreValue,
            'requestedAt': now,
            'approvedAt': null,
            'approvedBy': '',
            'rejectionReason': '',
            'administratorRemarks': '',
            'lastLogin': now,
            'lastSeen': now,
            'isFirstLogin': true,
            'status': 'pending_approval',
            'approvalHistory': FieldValue.arrayUnion(<Map<String, Object?>>[
              <String, Object?>{
                'actorId': uid,
                'changedAt': now,
                'oldValue': fields['previousApprovalStatus'] ?? 'Not Requested',
                'newValue': SessionApprovalStatus.pending.firestoreValue,
                'reason': 'Access request submitted',
              },
            ]),
          }..remove('previousApprovalStatus'),
          SetOptions(merge: true),
        );
  }

  static Future<bool> submitDeviceChangeRequest({
    required String uid,
    required String deviceId,
    required String deviceModel,
    required String platform,
    required String appVersion,
  }) async {
    final reference = _firestore.collection('users').doc(uid);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();
      if (data == null) throw StateError('User profile no longer exists.');
      final existingId = (data['pendingDeviceId'] ?? '').toString();
      final existingStatus = SessionApprovalStatus.fromFirestore(
        data['deviceApprovalStatus'],
      );
      if (existingId == deviceId &&
          existingStatus == SessionApprovalStatus.pending) {
        return false;
      }
      final now = Timestamp.now();
      transaction.update(reference, <String, Object?>{
        'pendingDeviceId': deviceId,
        'pendingDeviceModel': deviceModel,
        'pendingDevicePlatform': platform,
        'pendingDeviceAppVersion': appVersion,
        'deviceRequestAt': now,
        'deviceApprovalStatus': SessionApprovalStatus.pending.firestoreValue,
        'lastSeen': now,
      });
      return true;
    });
  }

  static Future<List<UserModel>> fetchSessionApprovalUsers() async {
    final users = await fetchAllUsers();
    return users
        .where(
          (user) =>
              user.requestedAt != null ||
              (user.pendingDeviceId.isNotEmpty &&
                  user.deviceApprovalStatus !=
                      SessionApprovalStatus.approved) ||
              user.approvalStatus != SessionApprovalStatus.approved,
        )
        .toList(growable: false);
  }

  static Stream<void> watchSessionApprovalUsers() => watchUsers();

  static Future<void> reviewSessionAccess({
    required String actorUid,
    required String actorEmail,
    required String targetUid,
    required SessionApprovalStatus newStatus,
    String reason = '',
    String administratorRemarks = '',
  }) async {
    final actorRef = _firestore.collection('users').doc(actorUid);
    final targetRef = _firestore.collection('users').doc(targetUid);

    await _firestore.runTransaction((transaction) async {
      final actorDoc = await transaction.get(actorRef);
      final targetDoc = await transaction.get(targetRef);
      final actorData = actorDoc.data();
      final targetData = targetDoc.data();
      final legacyAdministrator =
          actorData != null &&
          !actorData.containsKey('sessionApproved') &&
          _isAdministratorRole(actorData['role']);
      final bootstrapAdministrator =
          actorEmail.trim().toLowerCase() == bootstrapAdministratorEmail;
      final approvedAdministrator =
          actorData != null &&
          actorData['sessionApproved'] == true &&
          SessionApprovalStatus.fromFirestore(actorData['approvalStatus']) ==
              SessionApprovalStatus.approved &&
          _isAdministratorRole(actorData['role']);
      if (!bootstrapAdministrator &&
          !legacyAdministrator &&
          !approvedAdministrator) {
        throw StateError('Only an administrator can review session access.');
      }
      if (targetData == null) {
        throw StateError('The requested user no longer exists.');
      }

      final oldStatus = SessionApprovalStatus.fromFirestore(
        targetData['approvalStatus'],
      );
      final now = Timestamp.now();
      final approved = newStatus == SessionApprovalStatus.approved;
      transaction.update(targetRef, <String, Object?>{
        'sessionApproved': approved,
        'approvalStatus': newStatus.firestoreValue,
        'approvedAt': approved ? now : null,
        'approvedBy': approved ? actorUid : '',
        'rejectionReason': reason.trim(),
        'administratorRemarks': administratorRemarks.trim(),
        'status': approved ? 'active' : newStatus.firestoreValue.toLowerCase(),
        'isFirstLogin': !approved,
        'lastSeen': now,
        'approvalHistory': FieldValue.arrayUnion(<Map<String, Object?>>[
          <String, Object?>{
            'actorId': actorUid,
            'changedAt': now,
            'oldValue': oldStatus.firestoreValue,
            'newValue': newStatus.firestoreValue,
            'reason': reason.trim(),
            'remarks': administratorRemarks.trim(),
          },
        ]),
      });
    });
  }

  static Future<void> reviewDeviceChange({
    required String actorUid,
    required String actorEmail,
    required String targetUid,
    required SessionApprovalStatus newStatus,
    String reason = '',
  }) async {
    final actorRef = _firestore.collection('users').doc(actorUid);
    final targetRef = _firestore.collection('users').doc(targetUid);
    await _firestore.runTransaction((transaction) async {
      final actorData = (await transaction.get(actorRef)).data();
      final targetData = (await transaction.get(targetRef)).data();
      final bootstrap =
          actorEmail.trim().toLowerCase() == bootstrapAdministratorEmail;
      final approvedAdmin =
          actorData != null &&
          _isAdministratorRole(actorData['role']) &&
          (actorData['sessionApproved'] == true ||
              !actorData.containsKey('sessionApproved'));
      if (!bootstrap && !approvedAdmin) {
        throw StateError('Only an administrator can review device access.');
      }
      if (targetData == null) {
        throw StateError('User profile no longer exists.');
      }
      final pendingDeviceId = (targetData['pendingDeviceId'] ?? '').toString();
      if (pendingDeviceId.isEmpty) {
        throw StateError('No pending device request exists.');
      }
      final now = Timestamp.now();
      final approved = newStatus == SessionApprovalStatus.approved;
      final blocked = newStatus == SessionApprovalStatus.blocked;
      transaction.update(targetRef, <String, Object?>{
        if (approved) 'deviceId': pendingDeviceId,
        if (approved)
          'deviceModel': (targetData['pendingDeviceModel'] ?? '').toString(),
        if (approved)
          'platform': (targetData['pendingDevicePlatform'] ?? '').toString(),
        if (approved)
          'appVersion': (targetData['pendingDeviceAppVersion'] ?? '')
              .toString(),
        if (approved) 'pendingDeviceId': '',
        if (approved) 'pendingDeviceModel': '',
        if (approved) 'pendingDevicePlatform': '',
        if (approved) 'pendingDeviceAppVersion': '',
        'deviceApprovalStatus': newStatus.firestoreValue,
        if (blocked) 'sessionApproved': false,
        if (blocked)
          'approvalStatus': SessionApprovalStatus.blocked.firestoreValue,
        if (blocked) 'status': 'blocked',
        'administratorRemarks': reason.trim(),
        'lastSeen': now,
        'approvalHistory': FieldValue.arrayUnion(<Map<String, Object?>>[
          <String, Object?>{
            'actorId': actorUid,
            'changedAt': now,
            'oldValue': 'New Device Pending',
            'newValue': 'Device ${newStatus.firestoreValue}',
            'reason': reason.trim(),
          },
        ]),
      });
    });
  }

  static Future<void> markSessionSeen(String uid) {
    return updateUserFields(
      uid: uid,
      fields: <String, Object?>{
        'lastSeen': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'isFirstLogin': false,
      },
    );
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
      users.addAll(
        snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data()))
            .where((user) => user.uid.isNotEmpty),
      );
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

  /// Loads the existing user directory for organization administration.
  static Future<List<UserModel>> fetchAllUsers({int limit = 500}) async {
    try {
      final snapshot = await _firestore.collection('users').limit(limit).get();
      final users = snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .where((user) => user.uid.isNotEmpty)
          .toList(growable: false);
      users.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return users;
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'FirestoreService.fetchAllUsers',
      );
      rethrow;
    }
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

  static bool _isAdministratorRole(Object? value) {
    final role = value?.toString().trim().toLowerCase().replaceAll(' ', '_');
    return const <String>{
      'admin',
      'administrator',
      'application_owner',
      'owner',
    }.contains(role);
  }
}
