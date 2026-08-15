import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/models/location_permission_state_model.dart';
import '../../core/services/location_permission_service.dart';
import '../../core/services/location_tracking_policy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/premium_widgets.dart';
import '../map/controllers/location_controller.dart';
import 'cab_driver_operational_flow.dart';
import 'controllers/cab_driver_controller.dart';

class DriverLiveTripScreen extends StatefulWidget {
  final CabDriverOperations data;
  final ValueChanged<DriverOperationalPhase> onOpenWorkflow;
  final Future<void> Function() onRetry;

  const DriverLiveTripScreen({
    super.key,
    required this.data,
    required this.onOpenWorkflow,
    required this.onRetry,
  });

  @override
  State<DriverLiveTripScreen> createState() => DriverLiveTripScreenState();
}

class DriverLiveTripScreenState extends State<DriverLiveTripScreen>
    with AutomaticKeepAliveClientMixin {
  GoogleMapController? _mapController;
  LocationPermissionStateModel? _permission;
  bool _checkingPermission = true;
  MapType _mapType = MapType.normal;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPermission();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadPermission({bool request = false}) async {
    if (mounted) setState(() => _checkingPermission = true);
    final state = request
        ? await LocationController.requestLocationPermission()
        : await LocationController.checkLocationPermission();
    if (mounted) {
      setState(() {
        _permission = state;
        _checkingPermission = false;
      });
    }
  }

  Set<String> get permittedMarkerIds =>
      _permittedMarkers.map((marker) => marker.id).toSet();

  List<_DriverMarker> get _permittedMarkers {
    final result = <_DriverMarker>[];
    final driverLocation = widget.data.locations[widget.data.driver.uid];
    if (driverLocation != null) {
      result.add(
        _DriverMarker(
          id: 'driver',
          label: 'Your cab',
          latitude: driverLocation.latitude,
          longitude: driverLocation.longitude,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }

    final pending =
        widget.data.riders
            .where(
              (rider) =>
                  const {'assigned', 'ready', 'waiting'}.contains(rider.status),
            )
            .toList()
          ..sort((a, b) => a.pickupOrder.compareTo(b.pickupOrder));
    for (var index = 0; index < pending.length && index < 2; index++) {
      final rider = pending[index];
      final latitude = rider.pickupLatitude;
      final longitude = rider.pickupLongitude;
      if (latitude == null || longitude == null) continue;
      result.add(
        _DriverMarker(
          id: index == 0 ? 'current-pickup' : 'next-pickup',
          label: index == 0 ? 'Current claimed pickup' : 'Next claimed pickup',
          latitude: latitude,
          longitude: longitude,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            index == 0 ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange,
          ),
        ),
      );
    }

    final assignment = widget.data.todayAssignment;
    if (assignment?.officeLatitude != null &&
        assignment?.officeLongitude != null) {
      result.add(
        _DriverMarker(
          id: 'office',
          label: assignment!.officeName.isEmpty
              ? 'Office destination'
              : assignment.officeName,
          latitude: assignment.officeLatitude!,
          longitude: assignment.officeLongitude!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueViolet,
          ),
        ),
      );
    }
    return result;
  }

  bool get _isStale {
    final location = widget.data.locations[widget.data.driver.uid];
    return location != null &&
        DateTime.now().difference(location.updatedAt) >
            const Duration(minutes: 3);
  }

  bool get _isOffline {
    final location = widget.data.locations[widget.data.driver.uid];
    return location?.status == LocationTrackingPolicy.statusOffline ||
        location?.syncStatus == 'pending';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_checkingPermission) {
      return const PremiumLoadingState(label: 'Checking Driver GPS');
    }
    if (_permission?.serviceEnabled == false) {
      return _permissionState(
        icon: Icons.location_off,
        title: 'GPS is disabled',
        body: 'Enable device location services before using Live Trip.',
        action: 'OPEN LOCATION SETTINGS',
        onPressed: LocationPermissionService.openLocationSettings,
      );
    }
    if (_permission?.canUseLocation != true) {
      return _permissionState(
        icon: Icons.gps_off,
        title: 'Location permission required',
        body: _permission?.message ?? 'Allow location access for Driver duty.',
        action: _permission?.permanentlyDenied == true
            ? 'OPEN APP SETTINGS'
            : 'ALLOW LOCATION',
        onPressed: _permission?.permanentlyDenied == true
            ? LocationPermissionService.openAppSettings
            : () => _loadPermission(request: true),
      );
    }

    final markers = _permittedMarkers;
    if (!widget.data.dutyActive && widget.data.activeTrip == null) {
      return _emptyState(
        title: 'No active Driver trip',
        body: 'Start duty and claim a pickup to use Live Trip.',
        icon: Icons.route_outlined,
      );
    }
    if (widget.data.activeTrip != null && markers.isEmpty) {
      return _emptyState(
        title: 'Active trip needs location data',
        body:
            'The trip is safe. Retry after Driver GPS provides a fresh point.',
        icon: Icons.restore,
        action: 'RETRY',
      );
    }

    final initial = markers.first;
    final googleMarkers = markers
        .map(
          (marker) => Marker(
            markerId: MarkerId(marker.id),
            position: LatLng(marker.latitude, marker.longitude),
            infoWindow: InfoWindow(title: marker.label),
            icon: marker.icon,
          ),
        )
        .toSet();

    return Column(
      children: [
        if (_isOffline)
          _banner(
            Icons.cloud_off,
            'Offline: Driver actions remain queued safely.',
            AppColors.warning,
          ),
        if (_isStale)
          _banner(
            Icons.history,
            'Driver location is stale. Distances are approximate.',
            AppColors.warning,
          ),
        Expanded(
          child: Stack(
            children: [
              GoogleMap(
                key: const PageStorageKey('driver-live-trip-map'),
                initialCameraPosition: CameraPosition(
                  target: LatLng(initial.latitude, initial.longitude),
                  zoom: 14,
                ),
                markers: googleMarkers,
                mapType: _mapType,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                trafficEnabled: false,
                polylines: const {},
                mapToolbarEnabled: true,
                onMapCreated: (controller) => _mapController = controller,
              ),
              Positioned(
                right: 12,
                top: 12,
                child: FloatingActionButton.small(
                  heroTag: 'driver-map-type',
                  onPressed: () => setState(
                    () => _mapType = _mapType == MapType.normal
                        ? MapType.satellite
                        : MapType.normal,
                  ),
                  child: const Icon(Icons.layers),
                ),
              ),
            ],
          ),
        ),
        _routeSummary(markers),
      ],
    );
  }

  Widget _routeSummary(List<_DriverMarker> markers) {
    final driver = markers.where((item) => item.id == 'driver').firstOrNull;
    final target = markers.where((item) => item.id != 'driver').firstOrNull;
    final distance = driver == null || target == null
        ? null
        : LocationTrackingPolicy.distanceMeters(
            driver.latitude,
            driver.longitude,
            target.latitude,
            target.longitude,
          );
    final workflowPhase = widget.data.activeTrip == null
        ? DriverOperationalPhase.recoverTrip
        : widget.data.activeRider == null
        ? DriverOperationalPhase.navigateToOffice
        : DriverOperationalPhase.currentPickup;
    return Material(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              target?.label ?? 'Driver position',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              distance == null
                  ? 'Approximate distance unavailable'
                  : 'Approx. ${(distance / 1000).toStringAsFixed(1)} km straight-line',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: target == null
                        ? null
                        : () async {
                            final url =
                                'https://www.google.com/maps/search/?api=1&query=${target.latitude},${target.longitude}';
                            await Clipboard.setData(ClipboardData(text: url));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Google Maps destination copied. Use the map toolbar to open it.',
                                  ),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('GOOGLE MAPS'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => widget.onOpenWorkflow(workflowPhase),
                    icon: const Icon(Icons.navigation),
                    label: const Text('TRIP ACTION'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _banner(IconData icon, String text, Color color) => Container(
    width: double.infinity,
    color: color.withValues(alpha: 0.12),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );

  Widget _permissionState({
    required IconData icon,
    required String title,
    required String body,
    required String action,
    required Future<dynamic> Function() onPressed,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: PremiumCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.warning),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () async {
                await onPressed();
                await _loadPermission();
              },
              child: Text(action),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _emptyState({
    required String title,
    required String body,
    required IconData icon,
    String? action,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: PremiumCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: widget.onRetry, child: Text(action)),
            ],
          ],
        ),
      ),
    ),
  );
}

class _DriverMarker {
  final String id;
  final String label;
  final double latitude;
  final double longitude;
  final BitmapDescriptor icon;

  const _DriverMarker({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.icon,
  });
}
