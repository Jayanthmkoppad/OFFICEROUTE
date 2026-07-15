import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerVisitModel {
  final String id;
  final String userId;
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final String purpose;
  final String status;
  final String notes;
  final String vehicleDetails;
  final String motorSerialNumber;
  final String controllerSerialNumber;
  final String warrantyStatus;
  final String issueCategory;
  final String issueDescription;
  final List<String> partsUsed;
  final String technicianNotes;
  final List<String> photoUrls;
  final String videoPlaceholderStatus;
  final String signaturePlaceholderStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final DateTime? completedAt;
  final double? checkInLatitude;
  final double? checkInLongitude;
  final double? checkOutLatitude;
  final double? checkOutLongitude;

  const CustomerVisitModel({
    required this.id,
    required this.userId,
    required this.customerName,
    required this.customerAddress,
    required this.customerPhone,
    required this.purpose,
    required this.status,
    required this.notes,
    required this.vehicleDetails,
    required this.motorSerialNumber,
    required this.controllerSerialNumber,
    required this.warrantyStatus,
    required this.issueCategory,
    required this.issueDescription,
    required this.partsUsed,
    required this.technicianNotes,
    required this.photoUrls,
    required this.videoPlaceholderStatus,
    required this.signaturePlaceholderStatus,
    required this.createdAt,
    required this.updatedAt,
    required this.checkInTime,
    required this.checkOutTime,
    required this.completedAt,
    required this.checkInLatitude,
    required this.checkInLongitude,
    required this.checkOutLatitude,
    required this.checkOutLongitude,
  });

  factory CustomerVisitModel.fromMap(
    Map<String, dynamic> map, {
    String id = '',
  }) {
    return CustomerVisitModel(
      id: id.isNotEmpty ? id : (map['id'] ?? ''),
      userId: map['userId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerAddress: map['customerAddress'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      purpose: map['purpose'] ?? '',
      status: map['status'] ?? 'planned',
      notes: map['notes'] ?? '',
      vehicleDetails: map['vehicleDetails'] ?? '',
      motorSerialNumber: map['motorSerialNumber'] ?? '',
      controllerSerialNumber: map['controllerSerialNumber'] ?? '',
      warrantyStatus: map['warrantyStatus'] ?? '',
      issueCategory: map['issueCategory'] ?? '',
      issueDescription: map['issueDescription'] ?? '',
      partsUsed: _parseStringList(map['partsUsed']),
      technicianNotes: map['technicianNotes'] ?? '',
      photoUrls: _parseStringList(map['photoUrls']),
      videoPlaceholderStatus: map['videoPlaceholderStatus'] ?? 'pending',
      signaturePlaceholderStatus:
          map['signaturePlaceholderStatus'] ?? 'pending',
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updatedAt']) ?? DateTime.now(),
      checkInTime: _parseDateTime(map['checkInTime']),
      checkOutTime: _parseDateTime(map['checkOutTime']),
      completedAt: _parseDateTime(map['completedAt']),
      checkInLatitude: _parseDouble(map['checkInLatitude']),
      checkInLongitude: _parseDouble(map['checkInLongitude']),
      checkOutLatitude: _parseDouble(map['checkOutLatitude']),
      checkOutLongitude: _parseDouble(map['checkOutLongitude']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'customerName': customerName,
      'customerAddress': customerAddress,
      'customerPhone': customerPhone,
      'purpose': purpose,
      'status': status,
      'notes': notes,
      'vehicleDetails': vehicleDetails,
      'motorSerialNumber': motorSerialNumber,
      'controllerSerialNumber': controllerSerialNumber,
      'warrantyStatus': warrantyStatus,
      'issueCategory': issueCategory,
      'issueDescription': issueDescription,
      'partsUsed': partsUsed,
      'technicianNotes': technicianNotes,
      'photoUrls': photoUrls,
      'videoPlaceholderStatus': videoPlaceholderStatus,
      'signaturePlaceholderStatus': signaturePlaceholderStatus,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'checkInTime': checkInTime == null
          ? null
          : Timestamp.fromDate(checkInTime!),
      'checkOutTime': checkOutTime == null
          ? null
          : Timestamp.fromDate(checkOutTime!),
      'completedAt': completedAt == null
          ? null
          : Timestamp.fromDate(completedAt!),
      'checkInLatitude': checkInLatitude,
      'checkInLongitude': checkInLongitude,
      'checkOutLatitude': checkOutLatitude,
      'checkOutLongitude': checkOutLongitude,
    };
  }

  CustomerVisitModel copyWith({
    String? id,
    String? userId,
    String? customerName,
    String? customerAddress,
    String? customerPhone,
    String? purpose,
    String? status,
    String? notes,
    String? vehicleDetails,
    String? motorSerialNumber,
    String? controllerSerialNumber,
    String? warrantyStatus,
    String? issueCategory,
    String? issueDescription,
    List<String>? partsUsed,
    String? technicianNotes,
    List<String>? photoUrls,
    String? videoPlaceholderStatus,
    String? signaturePlaceholderStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    DateTime? completedAt,
    double? checkInLatitude,
    double? checkInLongitude,
    double? checkOutLatitude,
    double? checkOutLongitude,
  }) {
    return CustomerVisitModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      customerName: customerName ?? this.customerName,
      customerAddress: customerAddress ?? this.customerAddress,
      customerPhone: customerPhone ?? this.customerPhone,
      purpose: purpose ?? this.purpose,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      vehicleDetails: vehicleDetails ?? this.vehicleDetails,
      motorSerialNumber: motorSerialNumber ?? this.motorSerialNumber,
      controllerSerialNumber:
          controllerSerialNumber ?? this.controllerSerialNumber,
      warrantyStatus: warrantyStatus ?? this.warrantyStatus,
      issueCategory: issueCategory ?? this.issueCategory,
      issueDescription: issueDescription ?? this.issueDescription,
      partsUsed: partsUsed ?? this.partsUsed,
      technicianNotes: technicianNotes ?? this.technicianNotes,
      photoUrls: photoUrls ?? this.photoUrls,
      videoPlaceholderStatus:
          videoPlaceholderStatus ?? this.videoPlaceholderStatus,
      signaturePlaceholderStatus:
          signaturePlaceholderStatus ?? this.signaturePlaceholderStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      completedAt: completedAt ?? this.completedAt,
      checkInLatitude: checkInLatitude ?? this.checkInLatitude,
      checkInLongitude: checkInLongitude ?? this.checkInLongitude,
      checkOutLatitude: checkOutLatitude ?? this.checkOutLatitude,
      checkOutLongitude: checkOutLongitude ?? this.checkOutLongitude,
    );
  }

  Duration visitDuration(DateTime now) {
    final startedAt = checkInTime;
    if (startedAt == null) return Duration.zero;

    final endAt = checkOutTime ?? completedAt ?? now;
    if (endAt.isBefore(startedAt)) return Duration.zero;
    return endAt.difference(startedAt);
  }

  bool get hasGpsCheckIn =>
      checkInLatitude != null && checkInLongitude != null;

  bool get hasGpsCheckOut =>
      checkOutLatitude != null && checkOutLongitude != null;

  static DateTime? _parseDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  static double? _parseDouble(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static List<String> _parseStringList(Object? value) {
    if (value is List) {
      return value
          .whereType<Object>()
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    return const <String>[];
  }
}
