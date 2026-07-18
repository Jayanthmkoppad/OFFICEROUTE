import '../../auth/services/auth_service.dart';
import '../../map/controllers/location_controller.dart';
import '../models/customer_visit_model.dart';
import '../services/customer_visit_service.dart';

class CustomerVisitController {
  CustomerVisitController._();

  static Future<List<CustomerVisitModel>> loadMyVisits() async {
    final uid = _requiredUserId();
    return CustomerVisitService.fetchVisitsForUser(uid);
  }

  static Future<List<CustomerVisitModel>> loadAllVisits() async {
    _requiredUserId();
    return CustomerVisitService.fetchAllVisits();
  }

  static Future<List<CustomerVisitModel>> searchMyVisits(String query) async {
    final visits = await loadMyVisits();
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return visits;

    return visits.where((visit) {
      final values = [
        visit.customerName,
        visit.dealerName,
        visit.customerAddress,
        visit.customerPhone,
        visit.dealerPinCode,
        visit.complaintId,
        visit.priority,
        visit.serviceCentreName,
        visit.purpose,
        visit.vehicleDetails,
        visit.vehicleNumber,
        visit.motorSerialNumber,
        visit.controllerSerialNumber,
        visit.batterySerialNumber,
        visit.issueCategory,
        visit.issueDescription,
        visit.status,
      ].join(' ').toLowerCase();

      return values.contains(normalizedQuery);
    }).toList(growable: false);
  }

  static Future<List<CustomerVisitModel>> loadCustomerHistory(
    String customerName,
  ) async {
    final uid = _requiredUserId();
    return CustomerVisitService.fetchCustomerHistory(
      userId: uid,
      customerName: customerName,
    );
  }

  static Future<CustomerVisitModel> createVisit({
    required String customerName,
    required String customerAddress,
    required String customerPhone,
    required String purpose,
    required String notes,
    required String vehicleDetails,
    required String motorSerialNumber,
    required String controllerSerialNumber,
    required String warrantyStatus,
    required String issueCategory,
    required String issueDescription,
    required List<String> partsUsed,
    required String technicianNotes,
    String? assignedUserId,
    String dealerName = '',
    String complaintId = '',
    String dealerPinCode = '',
    double? dealerLatitude,
    double? dealerLongitude,
    String priority = '',
    DateTime? preferredVisitDate,
    int? expectedDurationMinutes,
    String serviceCentreName = '',
    double? serviceCentreDistanceKm,
    double? roadDistanceKm,
    int? estimatedTravelMinutes,
    double? travelCostEstimate,
    String vehicleNumber = '',
    String batterySerialNumber = '',
  }) async {
    final uid = _requiredUserId();
    final engineerId = assignedUserId ?? uid;
    return CustomerVisitService.createVisit(
      userId: engineerId,
      customerName: customerName,
      customerAddress: customerAddress,
      customerPhone: customerPhone,
      purpose: purpose,
      notes: notes,
      vehicleDetails: vehicleDetails,
      motorSerialNumber: motorSerialNumber,
      controllerSerialNumber: controllerSerialNumber,
      warrantyStatus: warrantyStatus,
      issueCategory: issueCategory,
      issueDescription: issueDescription,
      partsUsed: partsUsed,
      technicianNotes: technicianNotes,
      dealerName: dealerName,
      complaintId: complaintId,
      dealerPinCode: dealerPinCode,
      dealerLatitude: dealerLatitude,
      dealerLongitude: dealerLongitude,
      priority: priority,
      preferredVisitDate: preferredVisitDate,
      expectedDurationMinutes: expectedDurationMinutes,
      serviceCentreName: serviceCentreName,
      serviceCentreDistanceKm: serviceCentreDistanceKm,
      roadDistanceKm: roadDistanceKm,
      estimatedTravelMinutes: estimatedTravelMinutes,
      travelCostEstimate: travelCostEstimate,
      assignedAt: assignedUserId != null && engineerId.isNotEmpty
          ? DateTime.now()
          : null,
      vehicleNumber: vehicleNumber,
      batterySerialNumber: batterySerialNumber,
    );
  }

  static Future<CustomerVisitModel> updateVisit(CustomerVisitModel visit) {
    _requiredUserId();
    return CustomerVisitService.updateVisit(visit);
  }

  /// Assigns or reassigns an engineer while preserving the visit package.
  static Future<CustomerVisitModel> assignEngineer({
    required CustomerVisitModel visit,
    required String engineerId,
  }) {
    _requiredUserId();
    return CustomerVisitService.assignEngineer(
      visit: visit,
      engineerId: engineerId,
    );
  }

  /// Records a technical service timeline event with the current GPS point.
  static Future<CustomerVisitModel> addTechnicalTimelineEvent({
    required CustomerVisitModel visit,
    required String eventType,
    String notes = '',
  }) async {
    _requiredUserId();
    final location = await LocationController.getCurrentLocation();
    final event = VisitTimelineEvent(
      eventType: eventType,
      occurredAt: DateTime.now(),
      latitude: location.latitude,
      longitude: location.longitude,
      notes: notes,
    );
    return CustomerVisitService.updateVisit(
      visit.copyWith(
        technicalTimeline: <VisitTimelineEvent>[
          ...visit.technicalTimeline,
          event,
        ],
      ),
    );
  }

  static Future<CustomerVisitModel> checkIn(CustomerVisitModel visit) async {
    _requiredUserId();
    final location = await LocationController.getCurrentLocation();
    return CustomerVisitService.checkIn(
      visit: visit,
      latitude: location.latitude,
      longitude: location.longitude,
    );
  }

  static Future<CustomerVisitModel> checkOut(CustomerVisitModel visit) async {
    _requiredUserId();
    final location = await LocationController.getCurrentLocation();
    return CustomerVisitService.checkOut(
      visit: visit,
      latitude: location.latitude,
      longitude: location.longitude,
    );
  }

  static Future<CustomerVisitModel> addPhotoReference({
    required CustomerVisitModel visit,
    required String photoUrl,
  }) {
    _requiredUserId();
    return CustomerVisitService.addPhotoReference(
      visit: visit,
      photoUrl: photoUrl,
    );
  }

  static Future<CustomerVisitModel> completeVisit({
    required CustomerVisitModel visit,
    required String technicianNotes,
    required List<String> partsUsed,
    required String signatureStatus,
    required String videoStatus,
    String? resolutionStatus,
  }) {
    _requiredUserId();
    return CustomerVisitService.completeVisit(
      visit: visit,
      technicianNotes: technicianNotes,
      partsUsed: partsUsed,
      signatureStatus: signatureStatus,
      videoStatus: videoStatus,
      resolutionStatus: resolutionStatus,
    );
  }

  static String _requiredUserId() {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) {
      throw StateError('Customer visit action requires a signed-in user.');
    }

    return uid;
  }
}
