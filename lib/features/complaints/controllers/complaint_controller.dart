import '../../auth/services/auth_service.dart';
import '../../map/controllers/location_controller.dart';
import '../models/complaint_model.dart';
import '../services/complaint_service.dart';

class ComplaintController {
  ComplaintController._();

  static Future<List<ComplaintModel>> loadMyComplaints() async {
    final uid = _requiredUserId();
    return ComplaintService.fetchComplaintsForUser(uid);
  }

  static Future<List<ComplaintModel>> loadAllComplaints() async {
    _requiredUserId();
    return ComplaintService.fetchAllComplaints();
  }

  static Future<({double latitude, double longitude})> getCurrentGps() async {
    _requiredUserId();
    final location = await LocationController.getCurrentLocation();
    return (latitude: location.latitude, longitude: location.longitude);
  }

  static Future<ComplaintModel> registerComplaint({
    required String customerName,
    required String customerId,
    required String contactNumber,
    required String address,
    required double? latitude,
    required double? longitude,
    required String vehicleNumber,
    required String vehicleModel,
    required String motorSerialNumber,
    required String controllerSerialNumber,
    required String batterySerialNumber,
    required String chargerSerialNumber,
    required String vehicleConfiguration,
    required String motorConfiguration,
    required String controllerConfiguration,
    required DateTime? purchaseDate,
    required String invoiceNumber,
    required String dealerName,
    required String dealerContactNumber,
    required String oemName,
    required String warrantyStatus,
    required DateTime? warrantyExpiryDate,
    required String complaintCategory,
    required String complaintPriority,
    required String affectedComponent,
    required String customerStatedIssue,
    required String customerVoiceNote,
    required List<String> photoUrls,
    required List<String> videoUrls,
    required bool visitRequired,
    required DateTime? plannedVisitDateTime,
  }) async {
    final uid = _requiredUserId();
    final now = DateTime.now();
    final complaint = ComplaintModel(
      id: '',
      userId: uid,
      customerName: customerName,
      customerId: customerId,
      contactNumber: contactNumber,
      address: address,
      latitude: latitude,
      longitude: longitude,
      vehicleNumber: vehicleNumber,
      vehicleModel: vehicleModel,
      motorSerialNumber: motorSerialNumber,
      controllerSerialNumber: controllerSerialNumber,
      batterySerialNumber: batterySerialNumber,
      chargerSerialNumber: chargerSerialNumber,
      vehicleConfiguration: vehicleConfiguration,
      motorConfiguration: motorConfiguration,
      controllerConfiguration: controllerConfiguration,
      purchaseDate: purchaseDate,
      invoiceNumber: invoiceNumber,
      dealerName: dealerName,
      dealerContactNumber: dealerContactNumber,
      oemName: oemName,
      warrantyStatus: warrantyStatus,
      warrantyExpiryDate: warrantyExpiryDate,
      complaintDateTime: now,
      complaintCategory: complaintCategory,
      complaintPriority: complaintPriority,
      affectedComponent: affectedComponent,
      customerStatedIssue: customerStatedIssue,
      customerVoiceNote: customerVoiceNote,
      photoUrls: photoUrls,
      videoUrls: videoUrls,
      inspectionNotes: '',
      engineerVoiceNote: '',
      actualIssueFound: '',
      rootCause: '',
      partsRequired: const <String>[],
      estimatedCost: 0,
      estimatedCompletionTime: '',
      visitRequired: visitRequired,
      plannedVisitDateTime: plannedVisitDateTime,
      assignedEngineerId: '',
      assignedEngineerName: '',
      visitStatus: visitRequired ? 'pending_schedule' : 'not_required',
      linkedVisitId: '',
      solutionProvided: '',
      partsReplaced: const <String>[],
      labourCost: 0,
      partsCost: 0,
      totalCost: 0,
      engineerNotes: '',
      customerSignatureStatus: 'pending',
      customerRating: null,
      customerFeedback: '',
      closedAt: null,
      status: 'registered',
      createdAt: now,
      updatedAt: now,
    );

    return ComplaintService.createComplaint(complaint);
  }

  static Future<ComplaintModel> updateComplaint(ComplaintModel complaint) {
    _requiredUserId();
    return ComplaintService.updateComplaint(complaint);
  }

  static Future<ComplaintModel> linkVisit({
    required ComplaintModel complaint,
    required String visitId,
    required String visitStatus,
  }) {
    _requiredUserId();
    return ComplaintService.linkVisit(
      complaint: complaint,
      visitId: visitId,
      visitStatus: visitStatus,
    );
  }

  static String _requiredUserId() {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) {
      throw StateError('Complaint action requires a signed-in user.');
    }

    return uid;
  }
}
