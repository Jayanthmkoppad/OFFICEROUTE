/// Vehicle master data used by Cab Management.
///
/// Driver identity is not duplicated here. The optional [driverId] is only a
/// reference to `users/{uid}` for the currently preferred/default driver.
class CabVehicleModel {
  /// Firestore document id.
  final String id;

  /// Human-readable fleet number shown to operations users.
  final String vehicleNumber;

  /// Vehicle make/model label.
  final String vehicleModel;

  /// Government registration number.
  final String registrationNumber;

  /// Maximum number of employees this cab can carry.
  final int capacity;

  /// Operational status, for example `available`, `assigned`, or `inactive`.
  final String status;

  /// Optional reference to `users/{uid}` for the preferred/default driver.
  final String driverId;

  /// Internal remarks for operations.
  final String remarks;

  /// Creates a cab vehicle model.
  const CabVehicleModel({
    this.id = '',
    this.vehicleNumber = '',
    this.vehicleModel = '',
    this.registrationNumber = '',
    this.capacity = 0,
    this.status = 'available',
    this.driverId = '',
    this.remarks = '',
  });

  /// Creates a vehicle model from a Firestore document map.
  factory CabVehicleModel.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return CabVehicleModel(
      id: id.isNotEmpty ? id : (map['id'] ?? '').toString(),
      vehicleNumber: (map['vehicleNumber'] ?? '').toString(),
      vehicleModel: (map['vehicleModel'] ?? '').toString(),
      registrationNumber: (map['registrationNumber'] ?? '').toString(),
      capacity: _parseInt(map['capacity']),
      status: (map['status'] ?? 'available').toString(),
      driverId: (map['driverId'] ?? '').toString(),
      remarks: (map['remarks'] ?? '').toString(),
    );
  }

  /// Converts the vehicle model to a Firestore-safe document map.
  Map<String, dynamic> toMap() {
    return {
      'vehicleNumber': vehicleNumber,
      'vehicleModel': vehicleModel,
      'registrationNumber': registrationNumber,
      'capacity': capacity,
      'status': status,
      'driverId': driverId,
      'remarks': remarks,
    };
  }

  static int _parseInt(Object? value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
