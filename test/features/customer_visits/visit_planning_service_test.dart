import 'package:flutter_test/flutter_test.dart';
import 'package:officeroute/core/models/employee_model.dart';
import 'package:officeroute/core/models/live_location_model.dart';
import 'package:officeroute/features/attendance/models/attendance_model.dart';
import 'package:officeroute/features/customer_visits/models/customer_visit_model.dart';
import 'package:officeroute/features/customer_visits/services/visit_planning_service.dart';

void main() {
  group('VisitPlanningService', () {
    test('selects Delhi for coordinates in central Delhi', () {
      final result = VisitPlanningService.nearestCentre(
        latitude: 28.6139,
        longitude: 77.2090,
      );

      expect(result.centre.name, 'Delhi');
      expect(result.directDistanceKm, lessThan(0.1));
    });

    test('ranks an on-duty free engineer ahead of an off-duty engineer', () {
      final now = DateTime(2026, 7, 16, 12);
      const available = EmployeeModel(
        uid: 'available',
        name: 'Available Engineer',
        email: 'available@example.com',
        phone: '',
        role: 'employee',
        profileImage: '',
      );
      const offline = EmployeeModel(
        uid: 'offline',
        name: 'Offline Engineer',
        email: 'offline@example.com',
        phone: '',
        role: 'employee',
        profileImage: '',
      );
      final recommendations = VisitPlanningService.rankEngineers(
        employees: const [offline, available],
        attendance: [
          _attendance(
            userId: available.uid,
            now: now,
            checkInTime: now.subtract(const Duration(hours: 2)),
          ),
        ],
        visits: const [],
        liveLocationsByUserId: {
          available.uid: _liveLocation(available.uid, now),
        },
        now: now,
        dealerLatitude: 28.62,
        dealerLongitude: 77.21,
      );

      expect(recommendations.first.employee.uid, available.uid);
      expect(recommendations.first.available, isTrue);
      expect(recommendations.last.recommendation, 'Not Available');
    });

    test('calculates persisted dispatch analytics without inferred routes', () {
      final createdAt = DateTime(2026, 7, 16, 9);
      final visit = _visit(
        createdAt: createdAt,
        assignedAt: createdAt.add(const Duration(minutes: 30)),
      );
      final analytics = VisitPlanningService.calculateDispatchAnalytics(
        visits: [visit],
        employeeIds: const {'engineer-1'},
      );

      expect(analytics.plannedVisitCount, 1);
      expect(analytics.pendingDispatches, 0);
      expect(analytics.centreUsage, {'Delhi': 1});
      expect(analytics.averageRoadDistanceKm, 12);
      expect(analytics.averageEta, const Duration(minutes: 35));
      expect(analytics.averageAssignmentDelay, const Duration(minutes: 30));
      expect(analytics.travelEfficiencyPercent, closeTo(75, 0.01));
    });
  });
}

AttendanceModel _attendance({
  required String userId,
  required DateTime now,
  required DateTime checkInTime,
}) {
  return AttendanceModel(
    id: 'attendance-$userId',
    userId: userId,
    status: 'checked_in',
    date: now,
    checkInTime: checkInTime,
    checkOutTime: null,
    breakStartTime: null,
    totalBreakMinutes: 0,
    checkInLatitude: 28.61,
    checkInLongitude: 77.20,
    checkOutLatitude: null,
    checkOutLongitude: null,
    locationValidationStatus: 'validated',
    syncStatus: 'synced',
  );
}

LiveLocationModel _liveLocation(String userId, DateTime now) {
  return LiveLocationModel(
    userId: userId,
    sessionId: 'session-$userId',
    trackingReason: 'duty',
    status: 'active',
    latitude: 28.61,
    longitude: 77.20,
    accuracy: 5,
    altitude: 0,
    speed: 0,
    heading: 0,
    isForeground: true,
    source: 'test',
    syncStatus: 'synced',
    recordedAt: now,
    updatedAt: now,
  );
}

CustomerVisitModel _visit({
  required DateTime createdAt,
  required DateTime assignedAt,
}) {
  return CustomerVisitModel(
    id: 'visit-1',
    userId: 'engineer-1',
    customerName: 'Customer',
    customerAddress: 'Dealer address',
    customerPhone: '9999999999',
    purpose: 'Complaint service',
    status: 'planned',
    notes: '',
    vehicleDetails: '',
    motorSerialNumber: '',
    controllerSerialNumber: '',
    warrantyStatus: 'Unknown',
    issueCategory: 'Other',
    issueDescription: 'Complaint',
    partsUsed: const [],
    technicianNotes: '',
    photoUrls: const [],
    videoPlaceholderStatus: 'pending',
    signaturePlaceholderStatus: 'pending',
    createdAt: createdAt,
    updatedAt: assignedAt,
    checkInTime: null,
    checkOutTime: null,
    completedAt: null,
    checkInLatitude: null,
    checkInLongitude: null,
    checkOutLatitude: null,
    checkOutLongitude: null,
    complaintId: 'complaint-1',
    priority: 'High',
    preferredVisitDate: createdAt.add(const Duration(days: 1)),
    expectedDurationMinutes: 120,
    serviceCentreName: 'Delhi',
    serviceCentreDistanceKm: 9,
    roadDistanceKm: 12,
    estimatedTravelMinutes: 35,
    assignedAt: assignedAt,
  );
}
