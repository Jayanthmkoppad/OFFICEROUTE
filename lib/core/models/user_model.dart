import 'package:cloud_firestore/cloud_firestore.dart';

enum SessionApprovalStatus {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected'),
  suspended('Suspended'),
  blocked('Blocked');

  final String firestoreValue;

  const SessionApprovalStatus(this.firestoreValue);

  static SessionApprovalStatus fromFirestore(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    return SessionApprovalStatus.values.firstWhere(
      (status) => status.firestoreValue.toLowerCase() == normalized,
      orElse: () => SessionApprovalStatus.pending,
    );
  }
}

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String profileImage;
  final String department;
  final String designation;
  final String branch;
  final String reportingManager;
  final DateTime? joiningDate;
  final String employeeCode;
  final String emergencyContact;
  final String bloodGroup;
  final List<String> skills;
  final List<String> certifications;
  final String themeMode;
  final String language;
  final String locationAccuracy;
  final bool biometricEnabled;
  final String serviceCentre;
  final String vehicleNumber;
  final String reportingRegion;
  final String remarks;
  final bool sessionApproved;
  final SessionApprovalStatus approvalStatus;
  final DateTime? requestedAt;
  final DateTime? approvedAt;
  final String approvedBy;
  final String deviceId;
  final String deviceModel;
  final String platform;
  final String appVersion;
  final String loginProvider;
  final String sessionRole;
  final DateTime? lastLogin;
  final DateTime? lastSeen;
  final bool isFirstLogin;
  final String status;
  final String rejectionReason;
  final String administratorRemarks;
  final String licenseNumber;
  final String pendingDeviceId;
  final String pendingDeviceModel;
  final String pendingDevicePlatform;
  final String pendingDeviceAppVersion;
  final DateTime? deviceRequestAt;
  final SessionApprovalStatus deviceApprovalStatus;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.profileImage,
    this.department = '',
    this.designation = '',
    this.branch = '',
    this.reportingManager = '',
    this.joiningDate,
    this.employeeCode = '',
    this.emergencyContact = '',
    this.bloodGroup = '',
    this.skills = const <String>[],
    this.certifications = const <String>[],
    this.themeMode = 'system',
    this.language = 'system',
    this.locationAccuracy = 'high',
    this.biometricEnabled = false,
    this.serviceCentre = '',
    this.vehicleNumber = '',
    this.reportingRegion = '',
    this.remarks = '',
    this.sessionApproved = false,
    this.approvalStatus = SessionApprovalStatus.pending,
    this.requestedAt,
    this.approvedAt,
    this.approvedBy = '',
    this.deviceId = '',
    this.deviceModel = '',
    this.platform = '',
    this.appVersion = '',
    this.loginProvider = '',
    this.sessionRole = '',
    this.lastLogin,
    this.lastSeen,
    this.isFirstLogin = true,
    this.status = 'pending_approval',
    this.rejectionReason = '',
    this.administratorRemarks = '',
    this.licenseNumber = '',
    this.pendingDeviceId = '',
    this.pendingDeviceModel = '',
    this.pendingDevicePlatform = '',
    this.pendingDeviceAppVersion = '',
    this.deviceRequestAt,
    this.deviceApprovalStatus = SessionApprovalStatus.approved,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final role = (map['role'] ?? '').toString();
    final normalizedRole = role.trim().toLowerCase().replaceAll(' ', '_');
    final legacyAdministrator =
        !map.containsKey('sessionApproved') &&
        const <String>{
          'admin',
          'administrator',
          'application_owner',
          'owner',
        }.contains(normalizedRole);
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: role,
      profileImage: map['profileImage'] ?? '',
      department: (map['department'] ?? '').toString(),
      designation: (map['designation'] ?? '').toString(),
      branch: (map['branch'] ?? '').toString(),
      reportingManager: (map['reportingManager'] ?? '').toString(),
      joiningDate: _date(map['joiningDate']),
      employeeCode: (map['employeeCode'] ?? '').toString(),
      emergencyContact: (map['emergencyContact'] ?? '').toString(),
      bloodGroup: (map['bloodGroup'] ?? '').toString(),
      skills: _strings(map['skills']),
      certifications: _strings(map['certifications']),
      themeMode: (map['themeMode'] ?? 'system').toString(),
      language: (map['language'] ?? 'system').toString(),
      locationAccuracy: (map['locationAccuracy'] ?? 'high').toString(),
      biometricEnabled: map['biometricEnabled'] == true,
      serviceCentre: (map['serviceCentre'] ?? '').toString(),
      vehicleNumber: (map['vehicleNumber'] ?? '').toString(),
      reportingRegion: (map['reportingRegion'] ?? '').toString(),
      remarks: (map['remarks'] ?? '').toString(),
      sessionApproved: map['sessionApproved'] == true || legacyAdministrator,
      approvalStatus: map.containsKey('approvalStatus')
          ? SessionApprovalStatus.fromFirestore(map['approvalStatus'])
          : legacyAdministrator
          ? SessionApprovalStatus.approved
          : SessionApprovalStatus.pending,
      requestedAt: _date(map['requestedAt']),
      approvedAt: _date(map['approvedAt']),
      approvedBy: (map['approvedBy'] ?? '').toString(),
      deviceId: (map['deviceId'] ?? '').toString(),
      deviceModel: (map['deviceModel'] ?? '').toString(),
      platform: (map['platform'] ?? '').toString(),
      appVersion: (map['appVersion'] ?? '').toString(),
      loginProvider: (map['loginProvider'] ?? '').toString(),
      sessionRole: (map['sessionRole'] ?? '').toString(),
      lastLogin: _date(map['lastLogin']),
      lastSeen: _date(map['lastSeen']),
      isFirstLogin: map['isFirstLogin'] != false,
      status:
          (map['status'] ??
                  (legacyAdministrator ? 'active' : 'pending_approval'))
              .toString(),
      rejectionReason: (map['rejectionReason'] ?? '').toString(),
      administratorRemarks: (map['administratorRemarks'] ?? '').toString(),
      licenseNumber: (map['licenseNumber'] ?? '').toString(),
      pendingDeviceId: (map['pendingDeviceId'] ?? '').toString(),
      pendingDeviceModel: (map['pendingDeviceModel'] ?? '').toString(),
      pendingDevicePlatform: (map['pendingDevicePlatform'] ?? '').toString(),
      pendingDeviceAppVersion: (map['pendingDeviceAppVersion'] ?? '')
          .toString(),
      deviceRequestAt: _date(map['deviceRequestAt']),
      deviceApprovalStatus: map.containsKey('deviceApprovalStatus')
          ? SessionApprovalStatus.fromFirestore(map['deviceApprovalStatus'])
          : SessionApprovalStatus.approved,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'profileImage': profileImage,
      'department': department,
      'designation': designation,
      'branch': branch,
      'reportingManager': reportingManager,
      'joiningDate': joiningDate == null
          ? null
          : Timestamp.fromDate(joiningDate!),
      'employeeCode': employeeCode,
      'emergencyContact': emergencyContact,
      'bloodGroup': bloodGroup,
      'skills': skills,
      'certifications': certifications,
      'themeMode': themeMode,
      'language': language,
      'locationAccuracy': locationAccuracy,
      'biometricEnabled': biometricEnabled,
      'serviceCentre': serviceCentre,
      'vehicleNumber': vehicleNumber,
      'reportingRegion': reportingRegion,
      'remarks': remarks,
      'sessionApproved': sessionApproved,
      'approvalStatus': approvalStatus.firestoreValue,
      'requestedAt': requestedAt == null
          ? null
          : Timestamp.fromDate(requestedAt!),
      'approvedAt': approvedAt == null ? null : Timestamp.fromDate(approvedAt!),
      'approvedBy': approvedBy,
      'deviceId': deviceId,
      'deviceModel': deviceModel,
      'platform': platform,
      'appVersion': appVersion,
      'loginProvider': loginProvider,
      'sessionRole': sessionRole,
      'lastLogin': lastLogin == null ? null : Timestamp.fromDate(lastLogin!),
      'lastSeen': lastSeen == null ? null : Timestamp.fromDate(lastSeen!),
      'isFirstLogin': isFirstLogin,
      'status': status,
      'rejectionReason': rejectionReason,
      'administratorRemarks': administratorRemarks,
      'licenseNumber': licenseNumber,
      'pendingDeviceId': pendingDeviceId,
      'pendingDeviceModel': pendingDeviceModel,
      'pendingDevicePlatform': pendingDevicePlatform,
      'pendingDeviceAppVersion': pendingDeviceAppVersion,
      'deviceRequestAt': deviceRequestAt == null
          ? null
          : Timestamp.fromDate(deviceRequestAt!),
      'deviceApprovalStatus': deviceApprovalStatus.firestoreValue,
    };
  }

  static DateTime? _date(Object? value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static List<String> _strings(Object? value) {
    if (value is! Iterable) return const <String>[];
    return value
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
  }
}
