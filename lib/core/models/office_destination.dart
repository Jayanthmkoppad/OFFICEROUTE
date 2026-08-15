import 'cab_driver_shift_model.dart';
import 'user_model.dart';

/// Validated office destination resolved from the existing Driver profile.
///
/// The users document remains the configuration source. Assignments and trips
/// store immutable destination snapshots for operational history.
class OfficeDestination {
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  const OfficeDestination({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  static OfficeDestination? fromShift(CabDriverShiftModel? shift) {
    if (shift == null) return null;
    return _validated(
      name: shift.officeName,
      address: shift.officeAddress,
      latitude: shift.officeLatitude,
      longitude: shift.officeLongitude,
    );
  }

  static OfficeDestination? fromDriver(UserModel driver) {
    final configuredName = driver.officeName.trim();
    final name = configuredName.isNotEmpty
        ? configuredName
        : (driver.serviceCentre.trim().isNotEmpty
              ? driver.serviceCentre.trim()
              : driver.branch.trim());
    final address = driver.officeAddress.trim();
    final latitude = driver.officeLatitude;
    final longitude = driver.officeLongitude;
    return _validated(
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
    );
  }

  static OfficeDestination? _validated({
    required String name,
    required String address,
    required double? latitude,
    required double? longitude,
  }) {
    final normalizedName = name.trim();
    final normalizedAddress = address.trim();
    if (normalizedName.isEmpty ||
        normalizedAddress.isEmpty ||
        latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return OfficeDestination(
      name: normalizedName,
      address: normalizedAddress,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
