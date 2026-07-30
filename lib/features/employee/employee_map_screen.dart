import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/design/office_route_colors.dart';
import '../../core/design/office_route_radii.dart';
import '../../core/design/office_route_spacing.dart';
import '../../core/design/office_route_typography.dart';
import '../../core/models/live_location_model.dart';
import '../../core/design/widgets/office_route_card.dart';
import '../../core/services/location_tracking_policy.dart';
import 'controllers/employee_transport_controller.dart';
import 'widgets/employee_map_status_view.dart';
import 'widgets/employee_map_transport_sheet.dart';
import 'widgets/employee_transport_roster_card.dart';

typedef EmployeeMapSurfaceBuilder =
    Widget Function(
      BuildContext context, {
      required CameraPosition initialCameraPosition,
      required Set<Marker> markers,
      required void Function(GoogleMapController controller) onMapCreated,
    });

class EmployeeMapScreen extends StatefulWidget {
  const EmployeeMapScreen({super.key, this.mapSurfaceBuilder});

  @visibleForTesting
  final EmployeeMapSurfaceBuilder? mapSurfaceBuilder;

  @override
  State<EmployeeMapScreen> createState() => _EmployeeMapScreenState();
}

class _EmployeeMapScreenState extends State<EmployeeMapScreen> {
  static const _darkMapStyle =
      '[{"elementType":"geometry","stylers":[{"color":"#1b1b1b"}]},'
      '{"elementType":"labels.text.fill","stylers":[{"color":"#9a9a9a"}]},'
      '{"featureType":"water","elementType":"geometry","stylers":[{"color":"#090909"}]}]';

  GoogleMapController? _mapController;
  String? _selectedTitle;
  String? _selectedDetails;
  String _markerSetSignature = '';

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = EmployeeTransportScope.of(context);

    // Collect all available coordinates
    final pickupLat = controller.myAssignmentMember?.pickupLatitude;
    final pickupLng = controller.myAssignmentMember?.pickupLongitude;
    final hasPickup =
        pickupLat != null &&
        pickupLng != null &&
        pickupLat != 0.0 &&
        pickupLng != 0.0;

    final savedPickupLat = controller.currentUser?.preferredPickupLatitude;
    final savedPickupLng = controller.currentUser?.preferredPickupLongitude;
    final hasSavedPickup =
        savedPickupLat != null &&
        savedPickupLng != null &&
        savedPickupLat != 0.0 &&
        savedPickupLng != 0.0;

    final driverLoc = controller.driverLiveLocation;
    final hasCab =
        driverLoc != null &&
        driverLoc.latitude != 0.0 &&
        driverLoc.longitude != 0.0;

    final officeLat = controller.activeAssignment?.officeLatitude;
    final officeLng = controller.activeAssignment?.officeLongitude;
    final hasOffice =
        officeLat != null &&
        officeLng != null &&
        officeLat != 0.0 &&
        officeLng != 0.0;

    final empLoc = controller.employeeLiveLocation;
    final devicePosition = controller.currentDevicePosition;
    final hasEmployee =
        (empLoc != null && empLoc.latitude != 0.0 && empLoc.longitude != 0.0) ||
        (devicePosition != null &&
            devicePosition.latitude != 0.0 &&
            devicePosition.longitude != 0.0);
    final hasAnyCoordinates =
        hasPickup || hasSavedPickup || hasCab || hasOffice || hasEmployee;

    if (!hasAnyCoordinates) {
      return _buildEmptyState(context, controller);
    }

    return _buildMapView(
      context,
      controller,
      hasPickup: hasPickup,
      hasCab: hasCab,
      hasOffice: hasOffice,
      hasEmployee: hasEmployee,
    );
  }

  // ─── EMPTY STATE ──────────────────────────────────────────────────

  Widget _buildEmptyState(
    BuildContext context,
    EmployeeTransportController controller,
  ) {
    final member = controller.myAssignmentMember;
    final hasPickupConfigured =
        member?.pickupLatitude != null &&
        member?.pickupLongitude != null &&
        member!.pickupLatitude != 0.0 &&
        member.pickupLongitude != 0.0;
    final hasAssignment = member != null && member.assignmentId.isNotEmpty;
    final hasOffice =
        controller.activeAssignment?.officeLatitude != null &&
        controller.activeAssignment?.officeLongitude != null;
    final mapState = EmployeeMapStatus.fromController(controller);

    return Scaffold(
      backgroundColor: OfficeRouteColors.background,
      appBar: AppBar(
        backgroundColor: OfficeRouteColors.background,
        elevation: 0,
        toolbarHeight: 64,
        title: EmployeeMapBrandTitle(controller: controller),
        actions: const [
          Icon(
            Icons.notifications_none_outlined,
            semanticLabel: 'Transport notifications',
          ),
          SizedBox(width: OfficeRouteSpacing.md),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(OfficeRouteSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Map illustration using Flutter icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: OfficeRouteColors.raisedSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: OfficeRouteColors.border, width: 2),
                ),
                child: controller.isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(mapState.icon, size: 40, color: mapState.color),
              ),
              const SizedBox(height: OfficeRouteSpacing.lg),

              Text(
                mapState.title,
                key: Key('employee_map_state_${mapState.code}'),
                style: OfficeRouteTypography.screenTitle.copyWith(
                  letterSpacing: 0,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: OfficeRouteSpacing.xs),
              Text(
                mapState.message,
                style: OfficeRouteTypography.secondary.copyWith(
                  letterSpacing: 0,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: OfficeRouteSpacing.md),
              _DailyRouteFields(
                controller: controller,
                onUseCurrentLocation: () async {
                  final result = await controller.refreshDeviceLocation();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(result.message)));
                },
              ),

              const SizedBox(height: OfficeRouteSpacing.lg),

              // Required information checklist
              OfficeRouteCard(
                key: const Key('map_required_info_card'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REQUIRED INFORMATION',
                      style: OfficeRouteTypography.secondary.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: OfficeRouteSpacing.sm),
                    _buildChecklistItem(
                      'Saved pickup point',
                      hasPickupConfigured,
                    ),
                    const SizedBox(height: OfficeRouteSpacing.xs),
                    _buildChecklistItem(
                      'Today\'s cab assignment',
                      hasAssignment,
                    ),
                    const SizedBox(height: OfficeRouteSpacing.xs),
                    _buildChecklistItem('Office destination', hasOffice),
                  ],
                ),
              ),

              const SizedBox(height: OfficeRouteSpacing.lg),

              // Action buttons
              Wrap(
                alignment: WrapAlignment.center,
                spacing: OfficeRouteSpacing.xs,
                runSpacing: OfficeRouteSpacing.xs,
                children: [
                  if (mapState.retryLabel != null)
                    _buildMapActionChip(
                      controller.isRefreshing
                          ? 'Updating'
                          : mapState.retryLabel!,
                      Icons.refresh,
                      controller.isRefreshing
                          ? () {}
                          : () => _retryMapData(context, controller, mapState),
                    ),
                  _buildMapActionChip(
                    controller.isSharingMapPresence
                        ? 'Stop Sharing'
                        : 'Share My Location',
                    controller.isSharingMapPresence
                        ? Icons.location_disabled_outlined
                        : Icons.my_location,
                    () => _togglePresence(context, controller),
                  ),
                  _buildMapActionChip(
                    controller.locationPermissionState?.serviceEnabled == false
                        ? 'Open GPS Settings'
                        : 'App Permission',
                    Icons.settings_outlined,
                    () {
                      if (controller.locationPermissionState?.serviceEnabled ==
                          false) {
                        controller.openLocationSettings();
                      } else {
                        controller.openAppSettings();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: OfficeRouteSpacing.xs),
              Text(
                '${controller.locationPermissionStatus} • ${controller.locationServiceStatus}',
                style: OfficeRouteTypography.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── MAP VIEW ─────────────────────────────────────────────────────

  Widget _buildMapView(
    BuildContext context,
    EmployeeTransportController controller, {
    required bool hasPickup,
    required bool hasCab,
    required bool hasOffice,
    required bool hasEmployee,
  }) {
    final markers = <Marker>{};
    final boundsPoints = <LatLng>[];

    LatLng? cameraTarget;
    LatLng? pickupLatLng;
    LatLng? cabLatLng;
    LatLng? employeeLatLng;

    final savedPickupLatLng = _validCoordinate(
      controller.currentUser?.preferredPickupLatitude,
      controller.currentUser?.preferredPickupLongitude,
    );
    if (savedPickupLatLng != null) {
      cameraTarget ??= savedPickupLatLng;
      boundsPoints.add(savedPickupLatLng);
      markers.add(
        Marker(
          markerId: const MarkerId('employee_saved_pickup'),
          position: savedPickupLatLng,
          zIndexInt: 3,
          infoWindow: const InfoWindow(
            title: 'Saved pickup',
            snippet: 'Your preferred pickup location',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          onTap: () => _selectMarker('Saved pickup', [
            controller.currentUser?.preferredPickupAddress ?? '',
            _straightLineSentence(
              _distanceBetween(
                _employeeCoordinate(controller),
                savedPickupLatLng,
              ),
              'from you',
            ),
          ]),
        ),
      );
    }

    // Today's signed-in Employee pickup.
    if (hasPickup) {
      final lat = controller.myAssignmentMember!.pickupLatitude!;
      final lng = controller.myAssignmentMember!.pickupLongitude!;
      pickupLatLng = LatLng(lat, lng);
      cameraTarget ??= pickupLatLng;
      boundsPoints.add(pickupLatLng);
      final currentPickup = controller.homeViewState.currentPickup;
      final isCurrentOwnPickup =
          currentPickup != null &&
          currentPickup.employeeId == controller.currentUser?.uid;
      markers.add(
        Marker(
          markerId: MarkerId(
            isCurrentOwnPickup
                ? 'current_operational_pickup'
                : 'today_assigned_pickup',
          ),
          position: pickupLatLng,
          zIndexInt: isCurrentOwnPickup ? 8 : 5,
          infoWindow: InfoWindow(
            title: controller.myAssignmentMember?.pickupName.isNotEmpty == true
                ? controller.myAssignmentMember!.pickupName
                : 'Today\'s pickup',
            snippet: isCurrentOwnPickup
                ? 'Current operational pickup'
                : 'Your assigned pickup',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isCurrentOwnPickup
                ? BitmapDescriptor.hueOrange
                : BitmapDescriptor.hueViolet,
          ),
          onTap: () => _selectMarker(
            isCurrentOwnPickup ? 'Current pickup' : 'Today\'s pickup',
            [
              controller.myAssignmentMember?.pickupAddress ?? '',
              _straightLineSentence(
                _distanceBetween(_employeeCoordinate(controller), pickupLatLng),
                'from you',
              ),
            ],
          ),
        ),
      );
    }

    // 2. Cab Live Location
    if (hasCab) {
      final driverLoc = controller.driverLiveLocation!;
      cabLatLng = LatLng(driverLoc.latitude, driverLoc.longitude);
      cameraTarget ??= cabLatLng;
      boundsPoints.add(cabLatLng);
      markers.add(
        Marker(
          markerId: const MarkerId('assigned_cab'),
          position: cabLatLng,
          zIndexInt: 7,
          infoWindow: const InfoWindow(
            title: 'Assigned Cab',
            snippet: 'Authorized Driver live location',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          onTap: () => _selectMarker('Assigned Cab', [
            _driverName(controller),
            controller.assignedVehicle?.registrationNumber ?? '',
            _straightLineSentence(
              _distanceBetween(cabLatLng, pickupLatLng ?? savedPickupLatLng),
              'to your pickup',
            ),
            'Updated ${controller.driverLocationFreshness}',
          ]),
        ),
      );
    }

    // 3. Destination Office
    if (hasOffice) {
      final officeLat = controller.activeAssignment!.officeLatitude!;
      final officeLng = controller.activeAssignment!.officeLongitude!;
      final officeLatLng = LatLng(officeLat, officeLng);
      cameraTarget ??= officeLatLng;
      boundsPoints.add(officeLatLng);
      markers.add(
        Marker(
          markerId: const MarkerId('office_destination'),
          position: officeLatLng,
          infoWindow: InfoWindow(
            title: controller.activeAssignment?.officeName.isNotEmpty == true
                ? controller.activeAssignment!.officeName
                : 'Destination Office',
            snippet:
                controller.activeAssignment?.officeAddress ??
                'Destination Office Location',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          onTap: () => _selectMarker(
            controller.activeAssignment?.officeName.isNotEmpty == true
                ? controller.activeAssignment!.officeName
                : 'Office Destination',
            [controller.activeAssignment?.officeAddress ?? ''],
          ),
        ),
      );
    }

    // 4. Employee Own Live Location
    if (hasEmployee) {
      employeeLatLng = _employeeCoordinate(controller)!;
      cameraTarget = employeeLatLng;
      boundsPoints.add(employeeLatLng);
      markers.add(
        Marker(
          markerId: const MarkerId('signed_in_employee'),
          position: employeeLatLng,
          zIndexInt: 9,
          infoWindow: const InfoWindow(
            title: 'You',
            snippet: 'Signed-in Employee location',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          onTap: () => _selectMarker('Your location', [
            _employeeLocationSource(controller),
            'Updated ${_employeeFreshness(controller)}',
          ]),
        ),
      );
    }

    final mapState = EmployeeMapStatus.fromController(controller);
    final partialStatusText = mapState.code == 'ready' ? null : mapState.title;

    final effectivePickup = pickupLatLng ?? savedPickupLatLng;
    final empDist = _distanceBetween(employeeLatLng, effectivePickup);
    final cabDist = _distanceBetween(cabLatLng, effectivePickup);
    final markerSignature =
        markers
            .map(
              (marker) =>
                  '${marker.markerId.value}:'
                  '${marker.position.latitude.toStringAsFixed(4)}:'
                  '${marker.position.longitude.toStringAsFixed(4)}',
            )
            .toList()
          ..sort();
    _scheduleMarkerFit(markerSignature.join('|'), boundsPoints);

    final hasActiveTrip =
        controller.activeTrip != null &&
        const {
          'created',
          'active',
          'office_arrived',
        }.contains(controller.activeTrip!.status);

    return Scaffold(
      backgroundColor: OfficeRouteColors.background,
      appBar: AppBar(
        backgroundColor: OfficeRouteColors.background,
        elevation: 0,
        toolbarHeight: 64,
        title: EmployeeMapBrandTitle(controller: controller),
        actions: const [
          Icon(
            Icons.notifications_none_outlined,
            semanticLabel: 'Transport notifications',
          ),
          SizedBox(width: OfficeRouteSpacing.md),
        ],
      ),
      body: Stack(
        children: [
          widget.mapSurfaceBuilder?.call(
                context,
                initialCameraPosition: CameraPosition(
                  target: cameraTarget!,
                  zoom: 14,
                ),
                markers: markers,
                onMapCreated: (mapController) =>
                    _onMapCreated(mapController, boundsPoints),
              ) ??
              GoogleMap(
                key: const Key('employee_live_google_map'),
                initialCameraPosition: CameraPosition(
                  target: cameraTarget!,
                  zoom: 14,
                ),
                markers: markers,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false,
                zoomControlsEnabled: false,
                style: _darkMapStyle,
                onMapCreated: (mapController) =>
                    _onMapCreated(mapController, boundsPoints),
              ),

          Positioned(
            top: OfficeRouteSpacing.sm,
            left: OfficeRouteSpacing.sm,
            right: OfficeRouteSpacing.sm,
            child: _DailyRouteFields(
              controller: controller,
              compact: true,
              onUseCurrentLocation: () async {
                final result = await controller.refreshDeviceLocation();
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(result.message)));
              },
            ),
          ),

          // Partial-data status banner
          if (partialStatusText != null)
            Positioned(
              top: 190,
              left: OfficeRouteSpacing.md,
              right: OfficeRouteSpacing.md,
              child: OfficeRouteCard(
                key: Key('employee_map_inline_state_${mapState.code}'),
                child: Row(
                  children: [
                    Icon(mapState.icon, color: mapState.color, size: 18),
                    const SizedBox(width: OfficeRouteSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            partialStatusText,
                            style: OfficeRouteTypography.body.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                            ),
                          ),
                          Text(
                            mapState.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: OfficeRouteTypography.secondary.copyWith(
                              fontSize: 10,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (mapState.retryLabel != null)
                      IconButton(
                        key: Key('employee_map_retry_${mapState.code}'),
                        tooltip: mapState.retryLabel,
                        onPressed: controller.isRefreshing
                            ? null
                            : () =>
                                  _retryMapData(context, controller, mapState),
                        icon: const Icon(Icons.refresh, size: 18),
                      ),
                  ],
                ),
              ),
            ),

          if (_selectedTitle != null)
            Positioned(
              top: partialStatusText == null ? 190 : 258,
              left: 16,
              right: 64,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    padding: const EdgeInsets.all(OfficeRouteSpacing.md),
                    decoration: BoxDecoration(
                      color: OfficeRouteColors.background.withAlpha(205),
                      border: Border.all(color: OfficeRouteColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: OfficeRouteColors.primaryText,
                        ),
                        const SizedBox(width: OfficeRouteSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedTitle!,
                                style: OfficeRouteTypography.cardTitle,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedDetails ?? '',
                                style: OfficeRouteTypography.secondary,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close details',
                          onPressed: () => setState(() {
                            _selectedTitle = null;
                            _selectedDetails = null;
                          }),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Map controls (right side)
          Positioned(
            right: OfficeRouteSpacing.md,
            top: 248,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMapControlButton(
                  icon: Icons.fit_screen_outlined,
                  tooltip: 'Fit all locations',
                  onTap: () => _fitBounds(boundsPoints),
                ),
                if (pickupLatLng != null || savedPickupLatLng != null) ...[
                  const SizedBox(height: OfficeRouteSpacing.xs),
                  _buildMapControlButton(
                    icon: Icons.location_on_outlined,
                    tooltip: 'Center on saved pickup',
                    onTap: () => _animateTo(savedPickupLatLng ?? pickupLatLng!),
                  ),
                ],
                if (hasCab) ...[
                  const SizedBox(height: OfficeRouteSpacing.xs),
                  _buildMapControlButton(
                    icon: Icons.directions_car_outlined,
                    tooltip: 'Center on cab',
                    onTap: () => _animateTo(cabLatLng!),
                  ),
                ],
                const SizedBox(height: OfficeRouteSpacing.xs),
                _buildMapControlButton(
                  icon: Icons.my_location,
                  tooltip: 'Center on my location',
                  onTap: employeeLatLng == null
                      ? () => _refreshDeviceLocation(context, controller)
                      : () => _animateTo(employeeLatLng!),
                ),
              ],
            ),
          ),

          // Stable draggable transport KPI sheet.
          DraggableScrollableSheet(
            key: const Key('employee_map_transport_sheet'),
            initialChildSize: 0.40,
            minChildSize: 0.20,
            maxChildSize: 0.80,
            snap: true,
            snapSizes: const [0.20, 0.40, 0.80],
            builder: (context, scrollController) => ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(OfficeRouteRadii.hero),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: OfficeRouteColors.primarySurface.withValues(
                      alpha: 0.94,
                    ),
                    border: const Border(
                      top: BorderSide(color: OfficeRouteColors.border),
                    ),
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: OfficeRouteColors.secondaryText,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: OfficeRouteSpacing.sm),
                      EmployeeMapKpiHeader(
                        controller: controller,
                        cabDistanceMeters: cabDist,
                        employeeDistanceMeters: empDist,
                        hasActiveTrip: hasActiveTrip,
                        cabLocationIsFresh: !_isLocationStale(
                          controller.driverLiveLocation,
                          controller.currentTime,
                        ),
                      ),
                      const SizedBox(height: OfficeRouteSpacing.xs),
                      Text(
                        'Distances are straight-line. Road routing and traffic ETA are unavailable.',
                        key: const Key('map_distance_disclosure'),
                        style: OfficeRouteTypography.secondary.copyWith(
                          fontSize: 10,
                          letterSpacing: 0,
                        ),
                      ),
                      if (mapState.code != 'ready') ...[
                        const SizedBox(height: OfficeRouteSpacing.xs),
                        EmployeeMapSheetNotice(
                          state: mapState,
                          onRetry: () =>
                              _retryMapData(context, controller, mapState),
                        ),
                      ],
                      const SizedBox(height: OfficeRouteSpacing.xs),
                      EmployeeMapPickupPair(
                        current: controller.homeViewState.currentPickup,
                        next: controller.homeViewState.nextPickup,
                        hasActiveTrip: hasActiveTrip,
                      ),
                      const SizedBox(height: OfficeRouteSpacing.xs),
                      EmployeeMapDriverVehicleCard(controller: controller),
                      const SizedBox(height: OfficeRouteSpacing.xs),
                      EmployeeTransportRosterCard(
                        key: const Key('map_today_employees'),
                        progress: employeeMapPrivacySafeRoster(
                          controller.passengerProgressList,
                          controller.currentUser?.uid ?? '',
                        ),
                        isUpdating: controller.isActionLoading,
                        canUpdateOwnStatus:
                            controller.canUpdateOwnTransportStatus,
                        onUpdateStatus: (status) async {
                          final result = await controller
                              .updateOwnTransportRemark(status);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(result.message)),
                          );
                        },
                        currentUserId: controller.currentUser?.uid ?? '',
                        diagnosticCode: controller.rosterDiagnosticCode,
                        hasConfiguredRoute:
                            controller
                                .myAssignmentMember
                                ?.assignmentId
                                .isNotEmpty ==
                            true,
                        routeLabel: hasActiveTrip
                            ? 'Privacy-safe live pickup progress'
                            : 'Configured route members before trip start',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── MAP HELPERS ──────────────────────────────────────────────────

  Widget _buildMapControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: OfficeRouteColors.raisedSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OfficeRouteRadii.small),
        side: const BorderSide(color: OfficeRouteColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OfficeRouteRadii.small),
        child: Padding(
          padding: const EdgeInsets.all(OfficeRouteSpacing.sm),
          child: Icon(icon, size: 20, color: OfficeRouteColors.primaryText),
        ),
      ),
    );
  }

  Widget _buildChecklistItem(String label, bool isComplete) {
    return Row(
      children: [
        Icon(
          isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: isComplete
              ? OfficeRouteColors.readyGreen
              : OfficeRouteColors.disabledText,
        ),
        const SizedBox(width: OfficeRouteSpacing.xs),
        Text(
          label,
          style: OfficeRouteTypography.body.copyWith(
            color: isComplete
                ? OfficeRouteColors.primaryText
                : OfficeRouteColors.disabledText,
          ),
        ),
      ],
    );
  }

  Widget _buildMapActionChip(String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: OfficeRouteColors.primaryText),
      label: Text(
        label,
        style: OfficeRouteTypography.secondary.copyWith(
          color: OfficeRouteColors.primaryText,
          fontSize: 11,
        ),
      ),
      backgroundColor: OfficeRouteColors.raisedSurface,
      side: const BorderSide(color: OfficeRouteColors.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OfficeRouteRadii.small),
      ),
      onPressed: onTap,
    );
  }

  Future<void> _togglePresence(
    BuildContext context,
    EmployeeTransportController controller,
  ) async {
    final result = controller.isSharingMapPresence
        ? await controller.stopCurrentMapPresence()
        : await controller.shareCurrentMapPresence();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  void _animateTo(LatLng target) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16.0));
  }

  void _selectMarker(String title, List<String> details) {
    setState(() {
      _selectedTitle = title;
      _selectedDetails = details
          .where((value) => value.trim().isNotEmpty)
          .join('\n');
    });
  }

  void _fitBounds(List<LatLng> points) {
    final mapController = _mapController;
    if (points.isEmpty || mapController == null) return;
    if (points.length == 1 || points.every((point) => point == points.first)) {
      mapController.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15));
      return;
    }

    var south = points.first.latitude;
    var north = points.first.latitude;
    var west = points.first.longitude;
    var east = points.first.longitude;
    for (final point in points.skip(1)) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      if (point.longitude < west) west = point.longitude;
      if (point.longitude > east) east = point.longitude;
    }
    if (south == north && west == east) {
      mapController.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15));
      return;
    }
    mapController.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        72,
      ),
    );
  }

  void _onMapCreated(GoogleMapController mapController, List<LatLng> points) {
    _mapController = mapController;
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitBounds(points);
    });
  }

  void _scheduleMarkerFit(String signature, List<LatLng> points) {
    if (signature == _markerSetSignature) return;
    _markerSetSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitBounds(points);
    });
  }

  Future<void> _refreshDeviceLocation(
    BuildContext context,
    EmployeeTransportController controller,
  ) async {
    final result = await controller.refreshDeviceLocation();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _retryMapData(
    BuildContext context,
    EmployeeTransportController controller,
    EmployeeMapStatus state,
  ) async {
    final locationRetry = const {
      'gps_disabled',
      'permission_denied',
      'stale_employee',
    }.contains(state.code);
    final result = locationRetry
        ? await controller.refreshDeviceLocation()
        : await controller.refreshCurrentDay();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  static LatLng? _validCoordinate(double? latitude, double? longitude) {
    if (latitude == null ||
        longitude == null ||
        latitude == 0 ||
        longitude == 0) {
      return null;
    }
    return LatLng(latitude, longitude);
  }

  static LatLng? _employeeCoordinate(EmployeeTransportController controller) {
    final live = controller.employeeLiveLocation;
    final device = controller.currentDevicePosition;
    if (device != null &&
        (live == null || device.timestamp.isAfter(live.updatedAt))) {
      return _validCoordinate(device.latitude, device.longitude);
    }
    return _validCoordinate(live?.latitude, live?.longitude) ??
        _validCoordinate(device?.latitude, device?.longitude);
  }

  static String _employeeLocationSource(
    EmployeeTransportController controller,
  ) {
    final live = controller.employeeLiveLocation;
    final device = controller.currentDevicePosition;
    if (device != null &&
        (live == null || device.timestamp.isAfter(live.updatedAt))) {
      return 'Current device location';
    }
    return live == null ? 'Location unavailable' : 'Live shared location';
  }

  static String _employeeFreshness(EmployeeTransportController controller) {
    final live = controller.employeeLiveLocation;
    final device = controller.currentDevicePosition;
    final timestamp =
        device != null &&
            (live == null || device.timestamp.isAfter(live.updatedAt))
        ? device.timestamp
        : live?.updatedAt;
    return EmployeeTransportController.formatFreshness(
      timestamp,
      now: controller.currentTime,
    );
  }

  static bool _isLocationStale(LiveLocationModel? location, DateTime now) {
    return location != null &&
        LocationTrackingPolicy.isStale(location.updatedAt, now);
  }

  static double? _distanceBetween(LatLng? start, LatLng? end) {
    if (start == null || end == null) return null;
    return LocationTrackingPolicy.distanceMeters(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }

  static String _formatDistance(double? meters) {
    if (meters == null) return 'Unavailable';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  static String _straightLineSentence(double? meters, String suffix) {
    if (meters == null) return 'Straight-line distance unavailable';
    return '${_formatDistance(meters)} straight-line $suffix';
  }

  static String _driverName(EmployeeTransportController controller) {
    final name = controller.assignedDriver?.name.trim() ?? '';
    if (name.isNotEmpty) return name;
    return controller.activeAssignment?.driverId.isNotEmpty == true
        ? 'Driver details unavailable'
        : 'Driver not assigned';
  }
}

class _DailyRouteFields extends StatelessWidget {
  const _DailyRouteFields({
    required this.controller,
    this.compact = false,
    this.onUseCurrentLocation,
  });

  final EmployeeTransportController controller;
  final bool compact;
  final Future<void> Function()? onUseCurrentLocation;

  @override
  Widget build(BuildContext context) {
    final user = controller.currentUser;
    final member = controller.myAssignmentMember;
    final assignment = controller.activeAssignment;
    final yourLocation =
        controller.currentDevicePosition != null ||
            controller.employeeLiveLocation != null
        ? 'Current GPS location'
        : 'Location unavailable';
    final pickup = member?.pickupAddress.trim().isNotEmpty == true
        ? member!.pickupAddress
        : user?.preferredPickupAddress.trim().isNotEmpty == true
        ? user!.preferredPickupAddress
        : 'Approved pickup unavailable';
    final destination = assignment?.officeAddress.trim().isNotEmpty == true
        ? assignment!.officeAddress
        : assignment?.officeName.trim().isNotEmpty == true
        ? assignment!.officeName
        : 'Office destination unavailable';

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.all(compact ? 10 : 14),
          decoration: BoxDecoration(
            color: OfficeRouteColors.background.withAlpha(220),
            border: Border.all(color: OfficeRouteColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RouteField(
                label: 'YOUR LOCATION',
                value: yourLocation,
                icon: Icons.my_location,
                trailing: IconButton(
                  key: const Key('use_current_location'),
                  tooltip: 'Use Current Location',
                  onPressed: onUseCurrentLocation,
                  icon: const Icon(Icons.gps_fixed, size: 18),
                ),
              ),
              const Divider(color: OfficeRouteColors.divider, height: 8),
              _RouteField(
                label: 'PICKUP LOCATION',
                value: pickup,
                icon: Icons.location_on_outlined,
              ),
              const Divider(color: OfficeRouteColors.divider, height: 8),
              _RouteField(
                label: 'DESTINATION',
                value: destination,
                icon: Icons.business_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteField extends StatelessWidget {
  const _RouteField({
    required this.label,
    required this.value,
    required this.icon,
    this.trailing,
  });

  final String label;
  final String value;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: OfficeRouteColors.secondaryText),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: OfficeRouteTypography.secondary.copyWith(fontSize: 9),
              ),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: OfficeRouteTypography.body.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
