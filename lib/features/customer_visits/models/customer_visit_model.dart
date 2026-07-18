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
  final String vehicleNumber;
  final String vehicleType;
  final String vehicleCategory;
  final String fleetName;
  final String dealerName;
  final String complaintId;
  final String dealerPinCode;
  final double? dealerLatitude;
  final double? dealerLongitude;
  final String priority;
  final DateTime? preferredVisitDate;
  final int? expectedDurationMinutes;
  final String serviceCentreName;
  final double? serviceCentreDistanceKm;
  final double? roadDistanceKm;
  final int? estimatedTravelMinutes;
  final double? travelCostEstimate;
  final DateTime? assignedAt;
  final String motorModel;
  final DateTime? motorManufacturingDate;
  final String motorWarrantyStatus;
  final String controllerModel;
  final String controllerFirmware;
  final DateTime? controllerManufacturingDate;
  final String batteryModel;
  final String batterySerialNumber;
  final String batteryChemistry;
  final String batteryCapacity;
  final String batteryNominalVoltage;
  final String batteryWarrantyStatus;
  final String chargerModel;
  final double? vehicleOdometer;
  final double? hoursRun;
  final DateTime? lastServiceDate;
  final List<String> issueCategories;
  final Map<String, String> diagnosticReadings;
  final String actualRootCause;
  final String correctiveAction;
  final String preventiveAction;
  final String engineerRecommendation;
  final String resolutionStatus;
  final List<TechnicalChecklistItem> serviceChecklist;
  final List<VisitTimelineEvent> technicalTimeline;
  final List<String> photoTimelineEvents;
  final List<TechnicalAttachment> technicalAttachments;

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
    this.vehicleNumber = '',
    this.vehicleType = '',
    this.vehicleCategory = '',
    this.fleetName = '',
    this.dealerName = '',
    this.complaintId = '',
    this.dealerPinCode = '',
    this.dealerLatitude,
    this.dealerLongitude,
    this.priority = '',
    this.preferredVisitDate,
    this.expectedDurationMinutes,
    this.serviceCentreName = '',
    this.serviceCentreDistanceKm,
    this.roadDistanceKm,
    this.estimatedTravelMinutes,
    this.travelCostEstimate,
    this.assignedAt,
    this.motorModel = '',
    this.motorManufacturingDate,
    this.motorWarrantyStatus = '',
    this.controllerModel = '',
    this.controllerFirmware = '',
    this.controllerManufacturingDate,
    this.batteryModel = '',
    this.batterySerialNumber = '',
    this.batteryChemistry = '',
    this.batteryCapacity = '',
    this.batteryNominalVoltage = '',
    this.batteryWarrantyStatus = '',
    this.chargerModel = '',
    this.vehicleOdometer,
    this.hoursRun,
    this.lastServiceDate,
    this.issueCategories = const <String>[],
    this.diagnosticReadings = const <String, String>{},
    this.actualRootCause = '',
    this.correctiveAction = '',
    this.preventiveAction = '',
    this.engineerRecommendation = '',
    this.resolutionStatus = '',
    this.serviceChecklist = const <TechnicalChecklistItem>[],
    this.technicalTimeline = const <VisitTimelineEvent>[],
    this.photoTimelineEvents = const <String>[],
    this.technicalAttachments = const <TechnicalAttachment>[],
  });

  factory CustomerVisitModel.fromMap(
    Map<String, dynamic> map, {
    String id = '',
  }) {
    final primaryIssueCategory = (map['issueCategory'] ?? '').toString();
    final storedIssueCategories = _parseStringList(map['issueCategories']);
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
      issueCategory: primaryIssueCategory,
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
      vehicleNumber: (map['vehicleNumber'] ?? '').toString(),
      vehicleType: (map['vehicleType'] ?? '').toString(),
      vehicleCategory: (map['vehicleCategory'] ?? '').toString(),
      fleetName: (map['fleetName'] ?? '').toString(),
      dealerName: (map['dealerName'] ?? '').toString(),
      complaintId: (map['complaintId'] ?? '').toString(),
      dealerPinCode: (map['dealerPinCode'] ?? '').toString(),
      dealerLatitude: _parseDouble(map['dealerLatitude']),
      dealerLongitude: _parseDouble(map['dealerLongitude']),
      priority: (map['priority'] ?? '').toString(),
      preferredVisitDate: _parseDateTime(map['preferredVisitDate']),
      expectedDurationMinutes: _parseIntOrNull(
        map['expectedDurationMinutes'],
      ),
      serviceCentreName: (map['serviceCentreName'] ?? '').toString(),
      serviceCentreDistanceKm: _parseDouble(
        map['serviceCentreDistanceKm'],
      ),
      roadDistanceKm: _parseDouble(map['roadDistanceKm']),
      estimatedTravelMinutes: _parseIntOrNull(
        map['estimatedTravelMinutes'],
      ),
      travelCostEstimate: _parseDouble(map['travelCostEstimate']),
      assignedAt: _parseDateTime(map['assignedAt']),
      motorModel: (map['motorModel'] ?? '').toString(),
      motorManufacturingDate: _parseDateTime(map['motorManufacturingDate']),
      motorWarrantyStatus: (map['motorWarrantyStatus'] ?? '').toString(),
      controllerModel: (map['controllerModel'] ?? '').toString(),
      controllerFirmware: (map['controllerFirmware'] ?? '').toString(),
      controllerManufacturingDate: _parseDateTime(
        map['controllerManufacturingDate'],
      ),
      batteryModel: (map['batteryModel'] ?? '').toString(),
      batterySerialNumber: (map['batterySerialNumber'] ?? '').toString(),
      batteryChemistry: (map['batteryChemistry'] ?? '').toString(),
      batteryCapacity: (map['batteryCapacity'] ?? '').toString(),
      batteryNominalVoltage: (map['batteryNominalVoltage'] ?? '').toString(),
      batteryWarrantyStatus: (map['batteryWarrantyStatus'] ?? '').toString(),
      chargerModel: (map['chargerModel'] ?? '').toString(),
      vehicleOdometer: _parseDouble(map['vehicleOdometer']),
      hoursRun: _parseDouble(map['hoursRun']),
      lastServiceDate: _parseDateTime(map['lastServiceDate']),
      issueCategories: storedIssueCategories.isEmpty &&
              primaryIssueCategory.trim().isNotEmpty
          ? <String>[primaryIssueCategory]
          : storedIssueCategories,
      diagnosticReadings: _parseStringMap(map['diagnosticReadings']),
      actualRootCause: (map['actualRootCause'] ?? '').toString(),
      correctiveAction: (map['correctiveAction'] ?? '').toString(),
      preventiveAction: (map['preventiveAction'] ?? '').toString(),
      engineerRecommendation: (map['engineerRecommendation'] ?? '').toString(),
      resolutionStatus: (map['resolutionStatus'] ?? '').toString(),
      serviceChecklist: _parseMapList(map['serviceChecklist'])
          .map(TechnicalChecklistItem.fromMap)
          .toList(growable: false),
      technicalTimeline: _parseMapList(map['technicalTimeline'])
          .map(VisitTimelineEvent.fromMap)
          .toList(growable: false),
      photoTimelineEvents: _parseStringList(map['photoTimelineEvents']),
      technicalAttachments: _parseMapList(map['technicalAttachments'])
          .map(TechnicalAttachment.fromMap)
          .toList(growable: false),
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
      'vehicleNumber': vehicleNumber,
      'vehicleType': vehicleType,
      'vehicleCategory': vehicleCategory,
      'fleetName': fleetName,
      'dealerName': dealerName,
      'complaintId': complaintId,
      'dealerPinCode': dealerPinCode,
      'dealerLatitude': dealerLatitude,
      'dealerLongitude': dealerLongitude,
      'priority': priority,
      'preferredVisitDate': preferredVisitDate == null
          ? null
          : Timestamp.fromDate(preferredVisitDate!),
      'expectedDurationMinutes': expectedDurationMinutes,
      'serviceCentreName': serviceCentreName,
      'serviceCentreDistanceKm': serviceCentreDistanceKm,
      'roadDistanceKm': roadDistanceKm,
      'estimatedTravelMinutes': estimatedTravelMinutes,
      'travelCostEstimate': travelCostEstimate,
      'assignedAt': assignedAt == null ? null : Timestamp.fromDate(assignedAt!),
      'motorModel': motorModel,
      'motorManufacturingDate': motorManufacturingDate == null
          ? null
          : Timestamp.fromDate(motorManufacturingDate!),
      'motorWarrantyStatus': motorWarrantyStatus,
      'controllerModel': controllerModel,
      'controllerFirmware': controllerFirmware,
      'controllerManufacturingDate': controllerManufacturingDate == null
          ? null
          : Timestamp.fromDate(controllerManufacturingDate!),
      'batteryModel': batteryModel,
      'batterySerialNumber': batterySerialNumber,
      'batteryChemistry': batteryChemistry,
      'batteryCapacity': batteryCapacity,
      'batteryNominalVoltage': batteryNominalVoltage,
      'batteryWarrantyStatus': batteryWarrantyStatus,
      'chargerModel': chargerModel,
      'vehicleOdometer': vehicleOdometer,
      'hoursRun': hoursRun,
      'lastServiceDate': lastServiceDate == null
          ? null
          : Timestamp.fromDate(lastServiceDate!),
      'issueCategories': issueCategories.isEmpty && issueCategory.trim().isNotEmpty
          ? <String>[issueCategory]
          : issueCategories,
      'diagnosticReadings': diagnosticReadings,
      'actualRootCause': actualRootCause,
      'correctiveAction': correctiveAction,
      'preventiveAction': preventiveAction,
      'engineerRecommendation': engineerRecommendation,
      'resolutionStatus': resolutionStatus,
      'serviceChecklist': serviceChecklist
          .map((item) => item.toMap())
          .toList(growable: false),
      'technicalTimeline': technicalTimeline
          .map((event) => event.toMap())
          .toList(growable: false),
      'photoTimelineEvents': photoTimelineEvents,
      'technicalAttachments': technicalAttachments
          .map((attachment) => attachment.toMap())
          .toList(growable: false),
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
    String? vehicleNumber,
    String? vehicleType,
    String? vehicleCategory,
    String? fleetName,
    String? dealerName,
    String? complaintId,
    String? dealerPinCode,
    double? dealerLatitude,
    double? dealerLongitude,
    String? priority,
    DateTime? preferredVisitDate,
    int? expectedDurationMinutes,
    String? serviceCentreName,
    double? serviceCentreDistanceKm,
    double? roadDistanceKm,
    int? estimatedTravelMinutes,
    double? travelCostEstimate,
    DateTime? assignedAt,
    String? motorModel,
    DateTime? motorManufacturingDate,
    String? motorWarrantyStatus,
    String? controllerModel,
    String? controllerFirmware,
    DateTime? controllerManufacturingDate,
    String? batteryModel,
    String? batterySerialNumber,
    String? batteryChemistry,
    String? batteryCapacity,
    String? batteryNominalVoltage,
    String? batteryWarrantyStatus,
    String? chargerModel,
    double? vehicleOdometer,
    double? hoursRun,
    DateTime? lastServiceDate,
    List<String>? issueCategories,
    Map<String, String>? diagnosticReadings,
    String? actualRootCause,
    String? correctiveAction,
    String? preventiveAction,
    String? engineerRecommendation,
    String? resolutionStatus,
    List<TechnicalChecklistItem>? serviceChecklist,
    List<VisitTimelineEvent>? technicalTimeline,
    List<String>? photoTimelineEvents,
    List<TechnicalAttachment>? technicalAttachments,
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
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleCategory: vehicleCategory ?? this.vehicleCategory,
      fleetName: fleetName ?? this.fleetName,
      dealerName: dealerName ?? this.dealerName,
      complaintId: complaintId ?? this.complaintId,
      dealerPinCode: dealerPinCode ?? this.dealerPinCode,
      dealerLatitude: dealerLatitude ?? this.dealerLatitude,
      dealerLongitude: dealerLongitude ?? this.dealerLongitude,
      priority: priority ?? this.priority,
      preferredVisitDate: preferredVisitDate ?? this.preferredVisitDate,
      expectedDurationMinutes:
          expectedDurationMinutes ?? this.expectedDurationMinutes,
      serviceCentreName: serviceCentreName ?? this.serviceCentreName,
      serviceCentreDistanceKm:
          serviceCentreDistanceKm ?? this.serviceCentreDistanceKm,
      roadDistanceKm: roadDistanceKm ?? this.roadDistanceKm,
      estimatedTravelMinutes:
          estimatedTravelMinutes ?? this.estimatedTravelMinutes,
      travelCostEstimate: travelCostEstimate ?? this.travelCostEstimate,
      assignedAt: assignedAt ?? this.assignedAt,
      motorModel: motorModel ?? this.motorModel,
      motorManufacturingDate:
          motorManufacturingDate ?? this.motorManufacturingDate,
      motorWarrantyStatus: motorWarrantyStatus ?? this.motorWarrantyStatus,
      controllerModel: controllerModel ?? this.controllerModel,
      controllerFirmware: controllerFirmware ?? this.controllerFirmware,
      controllerManufacturingDate:
          controllerManufacturingDate ?? this.controllerManufacturingDate,
      batteryModel: batteryModel ?? this.batteryModel,
      batterySerialNumber: batterySerialNumber ?? this.batterySerialNumber,
      batteryChemistry: batteryChemistry ?? this.batteryChemistry,
      batteryCapacity: batteryCapacity ?? this.batteryCapacity,
      batteryNominalVoltage:
          batteryNominalVoltage ?? this.batteryNominalVoltage,
      batteryWarrantyStatus:
          batteryWarrantyStatus ?? this.batteryWarrantyStatus,
      chargerModel: chargerModel ?? this.chargerModel,
      vehicleOdometer: vehicleOdometer ?? this.vehicleOdometer,
      hoursRun: hoursRun ?? this.hoursRun,
      lastServiceDate: lastServiceDate ?? this.lastServiceDate,
      issueCategories: issueCategories ?? this.issueCategories,
      diagnosticReadings: diagnosticReadings ?? this.diagnosticReadings,
      actualRootCause: actualRootCause ?? this.actualRootCause,
      correctiveAction: correctiveAction ?? this.correctiveAction,
      preventiveAction: preventiveAction ?? this.preventiveAction,
      engineerRecommendation:
          engineerRecommendation ?? this.engineerRecommendation,
      resolutionStatus: resolutionStatus ?? this.resolutionStatus,
      serviceChecklist: serviceChecklist ?? this.serviceChecklist,
      technicalTimeline: technicalTimeline ?? this.technicalTimeline,
      photoTimelineEvents: photoTimelineEvents ?? this.photoTimelineEvents,
      technicalAttachments:
          technicalAttachments ?? this.technicalAttachments,
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

  static Map<String, String> _parseStringMap(Object? value) {
    if (value is! Map) return const <String, String>{};
    return <String, String>{
      for (final entry in value.entries)
        if (entry.key.toString().trim().isNotEmpty &&
            entry.value.toString().trim().isNotEmpty)
          entry.key.toString(): entry.value.toString(),
    };
  }

  static List<Map<String, dynamic>> _parseMapList(Object? value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map(
          (item) => item.map(
            (key, nestedValue) => MapEntry(key.toString(), nestedValue),
          ),
        )
        .toList(growable: false);
  }
}

class TechnicalChecklistItem {
  final String id;
  final String label;
  final String status;
  final String comments;
  final String photoReference;
  final DateTime? updatedAt;

  const TechnicalChecklistItem({
    required this.id,
    required this.label,
    this.status = 'pending',
    this.comments = '',
    this.photoReference = '',
    this.updatedAt,
  });

  factory TechnicalChecklistItem.fromMap(Map<String, dynamic> map) {
    return TechnicalChecklistItem(
      id: (map['id'] ?? '').toString(),
      label: (map['label'] ?? '').toString(),
      status: (map['status'] ?? 'pending').toString(),
      comments: (map['comments'] ?? '').toString(),
      photoReference: (map['photoReference'] ?? '').toString(),
      updatedAt: _parseEmbeddedDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'status': status,
      'comments': comments,
      'photoReference': photoReference,
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  TechnicalChecklistItem copyWith({
    String? id,
    String? label,
    String? status,
    String? comments,
    String? photoReference,
    DateTime? updatedAt,
  }) {
    return TechnicalChecklistItem(
      id: id ?? this.id,
      label: label ?? this.label,
      status: status ?? this.status,
      comments: comments ?? this.comments,
      photoReference: photoReference ?? this.photoReference,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class VisitTimelineEvent {
  final String eventType;
  final DateTime occurredAt;
  final double? latitude;
  final double? longitude;
  final String notes;

  const VisitTimelineEvent({
    required this.eventType,
    required this.occurredAt,
    this.latitude,
    this.longitude,
    this.notes = '',
  });

  factory VisitTimelineEvent.fromMap(Map<String, dynamic> map) {
    return VisitTimelineEvent(
      eventType: (map['eventType'] ?? '').toString(),
      occurredAt: _parseEmbeddedDate(map['occurredAt']) ?? DateTime.now(),
      latitude: _parseEmbeddedDouble(map['latitude']),
      longitude: _parseEmbeddedDouble(map['longitude']),
      notes: (map['notes'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventType': eventType,
      'occurredAt': Timestamp.fromDate(occurredAt),
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
    };
  }
}

class TechnicalAttachment {
  final String type;
  final String reference;
  final String eventType;
  final DateTime createdAt;
  final String notes;

  const TechnicalAttachment({
    required this.type,
    required this.reference,
    required this.eventType,
    required this.createdAt,
    this.notes = '',
  });

  factory TechnicalAttachment.fromMap(Map<String, dynamic> map) {
    return TechnicalAttachment(
      type: (map['type'] ?? '').toString(),
      reference: (map['reference'] ?? '').toString(),
      eventType: (map['eventType'] ?? '').toString(),
      createdAt: _parseEmbeddedDate(map['createdAt']) ?? DateTime.now(),
      notes: (map['notes'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'reference': reference,
      'eventType': eventType,
      'createdAt': Timestamp.fromDate(createdAt),
      'notes': notes,
    };
  }
}

DateTime? _parseEmbeddedDate(Object? value) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return null;
}

double? _parseEmbeddedDouble(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
