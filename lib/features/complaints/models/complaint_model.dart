import 'package:cloud_firestore/cloud_firestore.dart';

class ComplaintModel {
  final String id;
  final String userId;
  final String customerName;
  final String customerId;
  final String contactNumber;
  final String address;
  final double? latitude;
  final double? longitude;
  final String vehicleNumber;
  final String vehicleModel;
  final String motorSerialNumber;
  final String controllerSerialNumber;
  final String batterySerialNumber;
  final String chargerSerialNumber;
  final String vehicleConfiguration;
  final String motorConfiguration;
  final String controllerConfiguration;
  final DateTime? purchaseDate;
  final String invoiceNumber;
  final String dealerName;
  final String dealerContactNumber;
  final String oemName;
  final String warrantyStatus;
  final DateTime? warrantyExpiryDate;
  final DateTime complaintDateTime;
  final String complaintCategory;
  final String complaintPriority;
  final String affectedComponent;
  final String customerStatedIssue;
  final String customerVoiceNote;
  final List<String> photoUrls;
  final List<String> videoUrls;
  final String inspectionNotes;
  final String engineerVoiceNote;
  final String actualIssueFound;
  final String rootCause;
  final List<String> partsRequired;
  final double estimatedCost;
  final String estimatedCompletionTime;
  final bool visitRequired;
  final DateTime? plannedVisitDateTime;
  final String assignedEngineerId;
  final String assignedEngineerName;
  final String visitStatus;
  final String linkedVisitId;
  final String solutionProvided;
  final List<String> partsReplaced;
  final double labourCost;
  final double partsCost;
  final double totalCost;
  final String engineerNotes;
  final String customerSignatureStatus;
  final int? customerRating;
  final String customerFeedback;
  final DateTime? closedAt;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ComplaintModel({
    required this.id,
    required this.userId,
    required this.customerName,
    required this.customerId,
    required this.contactNumber,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.vehicleNumber,
    required this.vehicleModel,
    required this.motorSerialNumber,
    required this.controllerSerialNumber,
    required this.batterySerialNumber,
    required this.chargerSerialNumber,
    required this.vehicleConfiguration,
    required this.motorConfiguration,
    required this.controllerConfiguration,
    required this.purchaseDate,
    required this.invoiceNumber,
    required this.dealerName,
    required this.dealerContactNumber,
    required this.oemName,
    required this.warrantyStatus,
    required this.warrantyExpiryDate,
    required this.complaintDateTime,
    required this.complaintCategory,
    required this.complaintPriority,
    required this.affectedComponent,
    required this.customerStatedIssue,
    required this.customerVoiceNote,
    required this.photoUrls,
    required this.videoUrls,
    required this.inspectionNotes,
    required this.engineerVoiceNote,
    required this.actualIssueFound,
    required this.rootCause,
    required this.partsRequired,
    required this.estimatedCost,
    required this.estimatedCompletionTime,
    required this.visitRequired,
    required this.plannedVisitDateTime,
    required this.assignedEngineerId,
    required this.assignedEngineerName,
    required this.visitStatus,
    required this.linkedVisitId,
    required this.solutionProvided,
    required this.partsReplaced,
    required this.labourCost,
    required this.partsCost,
    required this.totalCost,
    required this.engineerNotes,
    required this.customerSignatureStatus,
    required this.customerRating,
    required this.customerFeedback,
    required this.closedAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ComplaintModel.fromMap(
    Map<String, dynamic> map, {
    String id = '',
  }) {
    return ComplaintModel(
      id: id.isNotEmpty ? id : (map['id'] ?? ''),
      userId: map['userId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerId: map['customerId'] ?? '',
      contactNumber: map['contactNumber'] ?? '',
      address: map['address'] ?? '',
      latitude: _parseDouble(map['latitude']),
      longitude: _parseDouble(map['longitude']),
      vehicleNumber: map['vehicleNumber'] ?? '',
      vehicleModel: map['vehicleModel'] ?? '',
      motorSerialNumber: map['motorSerialNumber'] ?? '',
      controllerSerialNumber: map['controllerSerialNumber'] ?? '',
      batterySerialNumber: map['batterySerialNumber'] ?? '',
      chargerSerialNumber: map['chargerSerialNumber'] ?? '',
      vehicleConfiguration: map['vehicleConfiguration'] ?? '',
      motorConfiguration: map['motorConfiguration'] ?? '',
      controllerConfiguration: map['controllerConfiguration'] ?? '',
      purchaseDate: _parseDateTime(map['purchaseDate']),
      invoiceNumber: map['invoiceNumber'] ?? '',
      dealerName: map['dealerName'] ?? '',
      dealerContactNumber: map['dealerContactNumber'] ?? '',
      oemName: map['oemName'] ?? 'Other',
      warrantyStatus: map['warrantyStatus'] ?? 'Unknown',
      warrantyExpiryDate: _parseDateTime(map['warrantyExpiryDate']),
      complaintDateTime:
          _parseDateTime(map['complaintDateTime']) ?? DateTime.now(),
      complaintCategory: map['complaintCategory'] ?? 'General',
      complaintPriority: map['complaintPriority'] ?? 'Medium',
      affectedComponent: map['affectedComponent'] ?? 'Other',
      customerStatedIssue: map['customerStatedIssue'] ?? '',
      customerVoiceNote: map['customerVoiceNote'] ?? '',
      photoUrls: _parseStringList(map['photoUrls']),
      videoUrls: _parseStringList(map['videoUrls']),
      inspectionNotes: map['inspectionNotes'] ?? '',
      engineerVoiceNote: map['engineerVoiceNote'] ?? '',
      actualIssueFound: map['actualIssueFound'] ?? '',
      rootCause: map['rootCause'] ?? '',
      partsRequired: _parseStringList(map['partsRequired']),
      estimatedCost: _parseDouble(map['estimatedCost']) ?? 0,
      estimatedCompletionTime: map['estimatedCompletionTime'] ?? '',
      visitRequired: map['visitRequired'] ?? false,
      plannedVisitDateTime: _parseDateTime(map['plannedVisitDateTime']),
      assignedEngineerId: map['assignedEngineerId'] ?? '',
      assignedEngineerName: map['assignedEngineerName'] ?? '',
      visitStatus: map['visitStatus'] ?? 'not_required',
      linkedVisitId: map['linkedVisitId'] ?? '',
      solutionProvided: map['solutionProvided'] ?? '',
      partsReplaced: _parseStringList(map['partsReplaced']),
      labourCost: _parseDouble(map['labourCost']) ?? 0,
      partsCost: _parseDouble(map['partsCost']) ?? 0,
      totalCost: _parseDouble(map['totalCost']) ?? 0,
      engineerNotes: map['engineerNotes'] ?? '',
      customerSignatureStatus: map['customerSignatureStatus'] ?? 'pending',
      customerRating: _parseIntOrNull(map['customerRating']),
      customerFeedback: map['customerFeedback'] ?? '',
      closedAt: _parseDateTime(map['closedAt']),
      status: map['status'] ?? 'registered',
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'customerName': customerName,
      'customerId': customerId,
      'contactNumber': contactNumber,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'vehicleNumber': vehicleNumber,
      'vehicleModel': vehicleModel,
      'motorSerialNumber': motorSerialNumber,
      'controllerSerialNumber': controllerSerialNumber,
      'batterySerialNumber': batterySerialNumber,
      'chargerSerialNumber': chargerSerialNumber,
      'vehicleConfiguration': vehicleConfiguration,
      'motorConfiguration': motorConfiguration,
      'controllerConfiguration': controllerConfiguration,
      'purchaseDate':
          purchaseDate == null ? null : Timestamp.fromDate(purchaseDate!),
      'invoiceNumber': invoiceNumber,
      'dealerName': dealerName,
      'dealerContactNumber': dealerContactNumber,
      'oemName': oemName,
      'warrantyStatus': warrantyStatus,
      'warrantyExpiryDate': warrantyExpiryDate == null
          ? null
          : Timestamp.fromDate(warrantyExpiryDate!),
      'complaintDateTime': Timestamp.fromDate(complaintDateTime),
      'complaintCategory': complaintCategory,
      'complaintPriority': complaintPriority,
      'affectedComponent': affectedComponent,
      'customerStatedIssue': customerStatedIssue,
      'customerVoiceNote': customerVoiceNote,
      'photoUrls': photoUrls,
      'videoUrls': videoUrls,
      'inspectionNotes': inspectionNotes,
      'engineerVoiceNote': engineerVoiceNote,
      'actualIssueFound': actualIssueFound,
      'rootCause': rootCause,
      'partsRequired': partsRequired,
      'estimatedCost': estimatedCost,
      'estimatedCompletionTime': estimatedCompletionTime,
      'visitRequired': visitRequired,
      'plannedVisitDateTime': plannedVisitDateTime == null
          ? null
          : Timestamp.fromDate(plannedVisitDateTime!),
      'assignedEngineerId': assignedEngineerId,
      'assignedEngineerName': assignedEngineerName,
      'visitStatus': visitStatus,
      'linkedVisitId': linkedVisitId,
      'solutionProvided': solutionProvided,
      'partsReplaced': partsReplaced,
      'labourCost': labourCost,
      'partsCost': partsCost,
      'totalCost': totalCost,
      'engineerNotes': engineerNotes,
      'customerSignatureStatus': customerSignatureStatus,
      'customerRating': customerRating,
      'customerFeedback': customerFeedback,
      'closedAt': closedAt == null ? null : Timestamp.fromDate(closedAt!),
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ComplaintModel copyWith({
    String? id,
    String? userId,
    String? customerName,
    String? customerId,
    String? contactNumber,
    String? address,
    double? latitude,
    double? longitude,
    String? vehicleNumber,
    String? vehicleModel,
    String? motorSerialNumber,
    String? controllerSerialNumber,
    String? batterySerialNumber,
    String? chargerSerialNumber,
    String? vehicleConfiguration,
    String? motorConfiguration,
    String? controllerConfiguration,
    DateTime? purchaseDate,
    String? invoiceNumber,
    String? dealerName,
    String? dealerContactNumber,
    String? oemName,
    String? warrantyStatus,
    DateTime? warrantyExpiryDate,
    DateTime? complaintDateTime,
    String? complaintCategory,
    String? complaintPriority,
    String? affectedComponent,
    String? customerStatedIssue,
    String? customerVoiceNote,
    List<String>? photoUrls,
    List<String>? videoUrls,
    String? inspectionNotes,
    String? engineerVoiceNote,
    String? actualIssueFound,
    String? rootCause,
    List<String>? partsRequired,
    double? estimatedCost,
    String? estimatedCompletionTime,
    bool? visitRequired,
    DateTime? plannedVisitDateTime,
    String? assignedEngineerId,
    String? assignedEngineerName,
    String? visitStatus,
    String? linkedVisitId,
    String? solutionProvided,
    List<String>? partsReplaced,
    double? labourCost,
    double? partsCost,
    double? totalCost,
    String? engineerNotes,
    String? customerSignatureStatus,
    int? customerRating,
    String? customerFeedback,
    DateTime? closedAt,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ComplaintModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      customerName: customerName ?? this.customerName,
      customerId: customerId ?? this.customerId,
      contactNumber: contactNumber ?? this.contactNumber,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      motorSerialNumber: motorSerialNumber ?? this.motorSerialNumber,
      controllerSerialNumber:
          controllerSerialNumber ?? this.controllerSerialNumber,
      batterySerialNumber: batterySerialNumber ?? this.batterySerialNumber,
      chargerSerialNumber: chargerSerialNumber ?? this.chargerSerialNumber,
      vehicleConfiguration:
          vehicleConfiguration ?? this.vehicleConfiguration,
      motorConfiguration: motorConfiguration ?? this.motorConfiguration,
      controllerConfiguration:
          controllerConfiguration ?? this.controllerConfiguration,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      dealerName: dealerName ?? this.dealerName,
      dealerContactNumber: dealerContactNumber ?? this.dealerContactNumber,
      oemName: oemName ?? this.oemName,
      warrantyStatus: warrantyStatus ?? this.warrantyStatus,
      warrantyExpiryDate: warrantyExpiryDate ?? this.warrantyExpiryDate,
      complaintDateTime: complaintDateTime ?? this.complaintDateTime,
      complaintCategory: complaintCategory ?? this.complaintCategory,
      complaintPriority: complaintPriority ?? this.complaintPriority,
      affectedComponent: affectedComponent ?? this.affectedComponent,
      customerStatedIssue: customerStatedIssue ?? this.customerStatedIssue,
      customerVoiceNote: customerVoiceNote ?? this.customerVoiceNote,
      photoUrls: photoUrls ?? this.photoUrls,
      videoUrls: videoUrls ?? this.videoUrls,
      inspectionNotes: inspectionNotes ?? this.inspectionNotes,
      engineerVoiceNote: engineerVoiceNote ?? this.engineerVoiceNote,
      actualIssueFound: actualIssueFound ?? this.actualIssueFound,
      rootCause: rootCause ?? this.rootCause,
      partsRequired: partsRequired ?? this.partsRequired,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      estimatedCompletionTime:
          estimatedCompletionTime ?? this.estimatedCompletionTime,
      visitRequired: visitRequired ?? this.visitRequired,
      plannedVisitDateTime: plannedVisitDateTime ?? this.plannedVisitDateTime,
      assignedEngineerId: assignedEngineerId ?? this.assignedEngineerId,
      assignedEngineerName: assignedEngineerName ?? this.assignedEngineerName,
      visitStatus: visitStatus ?? this.visitStatus,
      linkedVisitId: linkedVisitId ?? this.linkedVisitId,
      solutionProvided: solutionProvided ?? this.solutionProvided,
      partsReplaced: partsReplaced ?? this.partsReplaced,
      labourCost: labourCost ?? this.labourCost,
      partsCost: partsCost ?? this.partsCost,
      totalCost: totalCost ?? this.totalCost,
      engineerNotes: engineerNotes ?? this.engineerNotes,
      customerSignatureStatus:
          customerSignatureStatus ?? this.customerSignatureStatus,
      customerRating: customerRating ?? this.customerRating,
      customerFeedback: customerFeedback ?? this.customerFeedback,
      closedAt: closedAt ?? this.closedAt,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

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

  static int? _parseIntOrNull(Object? value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
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
