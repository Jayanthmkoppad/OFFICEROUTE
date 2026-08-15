import 'package:cloud_firestore/cloud_firestore.dart';

class SharedMapPresenceModel {
  const SharedMapPresenceModel({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.updatedAt,
  });

  final String userId;
  final String displayName;
  final String role;
  final double latitude;
  final double longitude;
  final String status;
  final DateTime updatedAt;

  factory SharedMapPresenceModel.fromMap(Map<String, dynamic> map) {
    return SharedMapPresenceModel(
      userId: (map['userId'] ?? '').toString(),
      displayName: (map['displayName'] ?? '').toString(),
      role: (map['role'] ?? '').toString(),
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      status: (map['status'] ?? 'offline').toString(),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
