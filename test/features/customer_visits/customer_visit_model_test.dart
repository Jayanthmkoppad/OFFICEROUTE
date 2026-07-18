import 'package:flutter_test/flutter_test.dart';
import 'package:officeroute/features/customer_visits/models/customer_visit_model.dart';

void main() {
  group('CustomerVisitModel', () {
    test('preserves expanded visit fields through map conversion', () {
      final now = DateTime(2026, 7, 11, 10, 30);
      final visit = CustomerVisitModel(
        id: 'visit-1',
        userId: 'user-1',
        customerName: 'Customer',
        customerAddress: 'Address',
        customerPhone: '9999999999',
        purpose: 'Service',
        status: 'checked_out',
        notes: 'Internal',
        vehicleDetails: 'Vehicle',
        motorSerialNumber: 'M-1',
        controllerSerialNumber: 'C-1',
        warrantyStatus: 'Under Warranty',
        issueCategory: 'Motor',
        issueDescription: 'Noise',
        partsUsed: const ['Bearing', 'Seal'],
        technicianNotes: 'Resolved',
        photoUrls: const ['photo-1'],
        videoPlaceholderStatus: 'ready',
        signaturePlaceholderStatus: 'ready',
        createdAt: now,
        updatedAt: now,
        checkInTime: now,
        checkOutTime: now.add(const Duration(hours: 1)),
        completedAt: now.add(const Duration(hours: 2)),
        checkInLatitude: 12.34,
        checkInLongitude: 56.78,
        checkOutLatitude: 12.35,
        checkOutLongitude: 56.79,
        dealerName: 'Dealer One',
        complaintId: 'complaint-1',
        dealerPinCode: '110001',
        dealerLatitude: 28.6139,
        dealerLongitude: 77.2090,
        priority: 'High',
        preferredVisitDate: now.add(const Duration(days: 1)),
        expectedDurationMinutes: 120,
        serviceCentreName: 'Delhi',
        serviceCentreDistanceKm: 4.2,
        roadDistanceKm: 5.5,
        estimatedTravelMinutes: 24,
        travelCostEstimate: 180,
        assignedAt: now.add(const Duration(minutes: 15)),
      );

      final restored = CustomerVisitModel.fromMap(visit.toMap(), id: visit.id);

      expect(restored.customerPhone, visit.customerPhone);
      expect(restored.vehicleDetails, visit.vehicleDetails);
      expect(restored.motorSerialNumber, visit.motorSerialNumber);
      expect(restored.controllerSerialNumber, visit.controllerSerialNumber);
      expect(restored.partsUsed, visit.partsUsed);
      expect(restored.photoUrls, visit.photoUrls);
      expect(restored.dealerName, visit.dealerName);
      expect(restored.complaintId, visit.complaintId);
      expect(restored.dealerPinCode, visit.dealerPinCode);
      expect(restored.dealerLatitude, visit.dealerLatitude);
      expect(restored.priority, visit.priority);
      expect(restored.preferredVisitDate, visit.preferredVisitDate);
      expect(restored.expectedDurationMinutes, 120);
      expect(restored.serviceCentreName, 'Delhi');
      expect(restored.roadDistanceKm, 5.5);
      expect(restored.estimatedTravelMinutes, 24);
      expect(restored.travelCostEstimate, 180);
      expect(restored.assignedAt, visit.assignedAt);
      expect(restored.hasGpsCheckIn, isTrue);
      expect(restored.hasGpsCheckOut, isTrue);
      expect(restored.visitDuration(now.add(const Duration(hours: 3))).inHours, 1);
    });

    test('uses safe defaults for legacy documents', () {
      final visit = CustomerVisitModel.fromMap(const {
        'customerName': 'Legacy Customer',
      });

      expect(visit.customerName, 'Legacy Customer');
      expect(visit.customerPhone, '');
      expect(visit.partsUsed, isEmpty);
      expect(visit.photoUrls, isEmpty);
      expect(visit.videoPlaceholderStatus, 'pending');
      expect(visit.signaturePlaceholderStatus, 'pending');
      expect(visit.complaintId, '');
      expect(visit.priority, '');
      expect(visit.preferredVisitDate, isNull);
      expect(visit.expectedDurationMinutes, isNull);
      expect(visit.serviceCentreName, '');
      expect(visit.roadDistanceKm, isNull);
      expect(visit.assignedAt, isNull);
    });
  });
}
