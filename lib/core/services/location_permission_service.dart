import 'package:geolocator/geolocator.dart';

import '../models/location_permission_state_model.dart';

class LocationPermissionService {
  LocationPermissionService._();

  static Future<LocationPermissionStateModel> checkPermissionState() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();

    return _buildState(
      serviceEnabled: serviceEnabled,
      permission: permission,
    );
  }

  static Future<LocationPermissionStateModel> requestForegroundPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return _buildState(
      serviceEnabled: serviceEnabled,
      permission: permission,
    );
  }

  static Future<LocationPermissionStateModel>
      ensureForegroundPermission() async {
    final checkedState = await checkPermissionState();
    if (checkedState.canUseLocation) return checkedState;

    if (checkedState.canRequestPermission) {
      final requestedState = await requestForegroundPermission();
      if (requestedState.canUseLocation) return requestedState;
      throw StateError(requestedState.message);
    }

    throw StateError(checkedState.message);
  }

  static Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }

  static Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }

  static LocationPermissionStateModel _buildState({
    required bool serviceEnabled,
    required LocationPermission permission,
  }) {
    final foregroundAllowed = permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
    final backgroundAllowed = permission == LocationPermission.always;
    final permanentlyDenied = permission == LocationPermission.deniedForever;
    final canRequest = permission == LocationPermission.denied;

    return LocationPermissionStateModel(
      serviceEnabled: serviceEnabled,
      permissionStatus: permission.name,
      canRequestPermission: canRequest,
      canUseForegroundLocation: foregroundAllowed,
      canUseBackgroundLocation: backgroundAllowed,
      permanentlyDenied: permanentlyDenied,
      message: _messageFor(
        serviceEnabled: serviceEnabled,
        permission: permission,
      ),
      checkedAt: DateTime.now(),
    );
  }

  static String _messageFor({
    required bool serviceEnabled,
    required LocationPermission permission,
  }) {
    if (!serviceEnabled) {
      return 'Location services are turned off. Please enable GPS to continue.';
    }

    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return 'Location permission is ready.';
      case LocationPermission.denied:
        return 'Location permission is required to use live tracking.';
      case LocationPermission.deniedForever:
        return 'Location permission is permanently denied. Please enable it from app settings.';
      case LocationPermission.unableToDetermine:
        return 'Location permission status could not be determined.';
    }
  }
}
