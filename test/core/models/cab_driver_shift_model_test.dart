import 'package:flutter_test/flutter_test.dart';
import 'package:officeroute/core/models/cab_driver_shift_model.dart';

void main() {
  group('CabDriverShiftModel', () {
    test('converts to and from a map without losing data', () {
      final shift = CabDriverShiftModel(
        id: 'shift-1',
        driverId: 'driver-1',
        vehicleId: 'vehicle-1',
        shiftDate: '2026-07-12',
        shiftStart: DateTime.utc(2026, 7, 12, 8, 0),
        shiftEnd: DateTime.utc(2026, 7, 12, 17, 0),
        shiftStatus: 'active',
        startLocation: 'Depot',
        endLocation: 'Office',
        totalDistance: 42.5,
        totalTrips: 6,
        totalEmployees: 12,
        remarks: 'On schedule',
      );

      final restoredShift = CabDriverShiftModel.fromMap(
        shift.toMap(),
        id: shift.id,
      );

      expect(restoredShift.id, shift.id);
      expect(restoredShift.driverId, shift.driverId);
      expect(restoredShift.vehicleId, shift.vehicleId);
      expect(restoredShift.shiftDate, shift.shiftDate);
      expect(restoredShift.shiftStart?.toUtc(), shift.shiftStart?.toUtc());
      expect(restoredShift.shiftEnd?.toUtc(), shift.shiftEnd?.toUtc());
      expect(restoredShift.shiftStatus, shift.shiftStatus);
      expect(restoredShift.startLocation, shift.startLocation);
      expect(restoredShift.endLocation, shift.endLocation);
      expect(restoredShift.totalDistance, shift.totalDistance);
      expect(restoredShift.totalTrips, shift.totalTrips);
      expect(restoredShift.totalEmployees, shift.totalEmployees);
      expect(restoredShift.remarks, shift.remarks);
    });

    test('uses empty defaults for missing fields', () {
      final shift = CabDriverShiftModel.fromMap(const {});

      expect(shift.toMap(), {
        'driverId': '',
        'vehicleId': '',
        'shiftDate': '',
        'shiftStart': null,
        'shiftEnd': null,
        'shiftStatus': 'scheduled',
        'startLocation': '',
        'endLocation': '',
        'totalDistance': 0.0,
        'totalTrips': 0,
        'totalEmployees': 0,
        'remarks': '',
      });
    });
  });
}
