import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final String source;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.source,
    required this.isRead,
    required this.createdAt,
    required this.readAt,
  });

  factory AppNotificationModel.fromMap(
    Map<String, dynamic> map, {
    String id = '',
  }) {
    return AppNotificationModel(
      id: id.isNotEmpty ? id : (map['id'] ?? ''),
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? 'general',
      source: map['source'] ?? 'in_app',
      isRead: map['isRead'] ?? false,
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      readAt: _parseDateTime(map['readAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'source': source,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'readAt': readAt == null ? null : Timestamp.fromDate(readAt!),
    };
  }

  AppNotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    String? type,
    String? source,
    bool? isRead,
    DateTime? createdAt,
    DateTime? readAt,
  }) {
    return AppNotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      source: source ?? this.source,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
