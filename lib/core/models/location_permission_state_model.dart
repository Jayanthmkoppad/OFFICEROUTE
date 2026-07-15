class LocationPermissionStateModel {
  final bool serviceEnabled;
  final String permissionStatus;
  final bool canRequestPermission;
  final bool canUseForegroundLocation;
  final bool canUseBackgroundLocation;
  final bool permanentlyDenied;
  final String message;
  final DateTime checkedAt;

  const LocationPermissionStateModel({
    required this.serviceEnabled,
    required this.permissionStatus,
    required this.canRequestPermission,
    required this.canUseForegroundLocation,
    required this.canUseBackgroundLocation,
    required this.permanentlyDenied,
    required this.message,
    required this.checkedAt,
  });

  bool get canUseLocation => serviceEnabled && canUseForegroundLocation;

  bool get needsUserAction => !serviceEnabled || !canUseForegroundLocation;

  LocationPermissionStateModel copyWith({
    bool? serviceEnabled,
    String? permissionStatus,
    bool? canRequestPermission,
    bool? canUseForegroundLocation,
    bool? canUseBackgroundLocation,
    bool? permanentlyDenied,
    String? message,
    DateTime? checkedAt,
  }) {
    return LocationPermissionStateModel(
      serviceEnabled: serviceEnabled ?? this.serviceEnabled,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      canRequestPermission: canRequestPermission ?? this.canRequestPermission,
      canUseForegroundLocation:
          canUseForegroundLocation ?? this.canUseForegroundLocation,
      canUseBackgroundLocation:
          canUseBackgroundLocation ?? this.canUseBackgroundLocation,
      permanentlyDenied: permanentlyDenied ?? this.permanentlyDenied,
      message: message ?? this.message,
      checkedAt: checkedAt ?? this.checkedAt,
    );
  }
}
