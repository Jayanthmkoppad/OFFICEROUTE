import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models/user_model.dart';
import '../../../core/services/firestore_service.dart';
import '../../notifications/services/notification_service.dart';
import '../services/auth_service.dart';
import '../services/session_device_service.dart';

class SessionApprovalController {
  SessionApprovalController._();

  static User get _user {
    final user = AuthService.currentUser;
    if (user == null) {
      throw StateError('Session approval requires an authenticated user.');
    }
    return user;
  }

  static Future<SessionDeviceMetadata> loadDeviceMetadata() {
    return SessionDeviceService.load();
  }

  static bool get isBootstrapAdministrator =>
      (_user.email ?? '').trim().toLowerCase() ==
      FirestoreService.bootstrapAdministratorEmail;

  static Future<void> ensureBootstrapAdministrator() {
    final user = _user;
    return FirestoreService.ensureBootstrapAdministrator(
      uid: user.uid,
      email: user.email ?? FirestoreService.bootstrapAdministratorEmail,
      name: user.displayName ?? 'Administrator',
    );
  }

  static Stream<UserSessionSnapshot> watchCurrentSession() {
    return FirestoreService.watchUserSession(_user.uid);
  }

  static Future<UserSessionSnapshot> refreshCurrentSession() {
    return FirestoreService.refreshUserSession(_user.uid);
  }

  static bool isApprovedForDevice(
    UserModel user,
    SessionDeviceMetadata device,
  ) {
    if (!user.sessionApproved ||
        user.approvalStatus != SessionApprovalStatus.approved) {
      return false;
    }
    return user.deviceId.isNotEmpty && user.deviceId == device.deviceId;
  }

  static bool isLegacyAdministrator(UserModel user) {
    final role = user.role.trim().toLowerCase().replaceAll(' ', '_');
    return user.sessionApproved &&
        const <String>{
          'admin',
          'administrator',
          'application_owner',
          'owner',
        }.contains(role);
  }

  static bool hasPendingDeviceRequest(
    UserModel user,
    SessionDeviceMetadata device,
  ) =>
      user.pendingDeviceId == device.deviceId &&
      user.deviceApprovalStatus == SessionApprovalStatus.pending;

  static Future<void> requestDeviceChange({
    required UserModel user,
    required SessionDeviceMetadata device,
  }) async {
    final created = await FirestoreService.submitDeviceChangeRequest(
      uid: user.uid,
      deviceId: device.deviceId,
      deviceModel: device.deviceModel,
      platform: device.platform,
      appVersion: device.appVersion,
    );
    if (created) {
      await _notifyBootstrapAdministrator(
        title: 'New Device Login Request',
        body: '${user.name} requested access from ${device.deviceModel}.',
        type: 'session_device_request',
      );
    }
  }

  static Future<void> submitAccessRequest({
    required Map<String, Object?> details,
    required SessionDeviceMetadata device,
    String previousApprovalStatus = 'Not Requested',
  }) async {
    final user = _user;
    final provider = user.providerData.isEmpty
        ? 'password'
        : user.providerData.first.providerId;
    final selectedRole = (details['role'] ?? '').toString();
    final existingRole = switch (selectedRole) {
      'cab_driver' => 'driver',
      'manager' => 'manager',
      'service_engineer' || 'office_employee' => 'employee',
      _ => selectedRole,
    };
    await FirestoreService.submitSessionAccessRequest(
      uid: user.uid,
      fields: <String, Object?>{
        'role': existingRole,
        'sessionRole': selectedRole,
        'email': user.email ?? '',
        'displayName': details['name'] ?? details['driverName'] ?? '',
        'name': details['name'] ?? details['driverName'] ?? '',
        'phone': details['phone'] ?? '',
        'employeeId': details['employeeId'] ?? details['driverId'] ?? '',
        'employeeCode': details['employeeId'] ?? details['driverId'] ?? '',
        'branch': details['branch'] ?? '',
        'department': details['department'] ?? '',
        'designation': details['designation'] ?? '',
        'serviceCentre': details['serviceCentre'] ?? '',
        'vehicleNumber': details['vehicleNumber'] ?? '',
        'reportingRegion': details['reportingRegion'] ?? '',
        'remarks': details['remarks'] ?? '',
        'deviceId': device.deviceId,
        'deviceModel': device.deviceModel,
        'platform': device.platform,
        'appVersion': device.appVersion,
        'loginProvider': provider,
        'previousApprovalStatus': previousApprovalStatus,
      },
    );
    await _notifyBootstrapAdministrator(
      title: 'New Session Access Request',
      body:
          '${details['name'] ?? details['driverName'] ?? user.email ?? 'User'} requested ${details['role']} access.',
      type: 'session_access_request',
    );
  }

  static Future<List<UserModel>> loadApprovalRequests() {
    return FirestoreService.fetchSessionApprovalUsers();
  }

  static Stream<void> watchApprovalRequests() {
    return FirestoreService.watchSessionApprovalUsers();
  }

  static Future<void> reviewRequest({
    required UserModel user,
    required SessionApprovalStatus status,
    String reason = '',
    String remarks = '',
  }) async {
    final actor = _user;
    await FirestoreService.reviewSessionAccess(
      actorUid: actor.uid,
      actorEmail: actor.email ?? '',
      targetUid: user.uid,
      newStatus: status,
      reason: reason,
      administratorRemarks: remarks,
    );

    final approved = status == SessionApprovalStatus.approved;
    await _notifyUserSafely(
      userId: user.uid,
      title: approved ? 'Account approved' : 'Access request updated',
      body: approved
          ? 'Your account has been approved.'
          : status == SessionApprovalStatus.rejected
          ? 'Your request was rejected. ${reason.trim()}'.trim()
          : 'Your account status is now ${status.firestoreValue}.',
      type: 'session_approval',
    );
  }

  static Future<void> reviewDeviceRequest({
    required UserModel user,
    required SessionApprovalStatus status,
    String reason = '',
  }) async {
    final actor = _user;
    await FirestoreService.reviewDeviceChange(
      actorUid: actor.uid,
      actorEmail: actor.email ?? '',
      targetUid: user.uid,
      newStatus: status,
      reason: reason,
    );
    await _notifyUserSafely(
      userId: user.uid,
      title: 'Device request ${status.firestoreValue.toLowerCase()}',
      body: reason.trim().isEmpty
          ? 'Your new device request is ${status.firestoreValue.toLowerCase()}.'
          : reason.trim(),
      type: 'session_device_review',
    );
  }

  static Future<void> _notifyBootstrapAdministrator({
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      final administrator = await FirestoreService.findUserByEmail(
        FirestoreService.bootstrapAdministratorEmail,
      );
      if (administrator == null) return;
      await NotificationService.createLocalNotification(
        userId: administrator.uid,
        title: title,
        body: body,
        type: type,
      );
    } catch (error, stackTrace) {
      debugPrint('Administrator session notification deferred: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> _notifyUserSafely({
    required String userId,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      await NotificationService.createLocalNotification(
        userId: userId,
        title: title,
        body: body,
        type: type,
      );
    } catch (error, stackTrace) {
      debugPrint('Session result notification deferred: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> markCurrentSessionSeen() {
    return FirestoreService.markSessionSeen(_user.uid);
  }

  static Future<void> logout() => AuthService.signOut();
}
