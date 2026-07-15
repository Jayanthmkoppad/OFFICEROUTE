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
        visit.customerAddress,
        visit.customerPhone,
        visit.purpose,
        visit.vehicleDetails,
        visit.motorSerialNumber,
        visit.controllerSerialNumber,
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
  }) async {
    final uid = _requiredUserId();
    return CustomerVisitService.createVisit(
      userId: uid,
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
    );
  }

  static Future<CustomerVisitModel> updateVisit(CustomerVisitModel visit) {
    _requiredUserId();
    return CustomerVisitService.updateVisit(visit);
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
  }) {
    _requiredUserId();
    return CustomerVisitService.completeVisit(
      visit: visit,
      technicianNotes: technicianNotes,
      partsUsed: partsUsed,
      signatureStatus: signatureStatus,
      videoStatus: videoStatus,
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
