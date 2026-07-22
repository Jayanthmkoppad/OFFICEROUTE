import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/design/office_route_colors.dart';
import '../../core/design/office_route_radii.dart';
import '../../core/design/office_route_spacing.dart';
import '../../core/design/office_route_status_style.dart';
import '../../core/design/office_route_typography.dart';
import '../../core/design/widgets/office_route_card.dart';
import '../../core/design/widgets/office_route_passenger_progress_tile.dart';
import '../../core/design/widgets/office_route_status_chip.dart';
import 'controllers/employee_transport_controller.dart';

class EmployeeMapScreen extends StatefulWidget {
  const EmployeeMapScreen({super.key});

  @override
  State<EmployeeMapScreen> createState() => _EmployeeMapScreenState();
}

class _EmployeeMapScreenState extends State<EmployeeMapScreen> {
  GoogleMapController? _mapController;
  bool _isSheetExpanded = false;

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
    final hasEmployee =
        empLoc != null && empLoc.latitude != 0.0 && empLoc.longitude != 0.0;

    final hasAnyCoordinates = hasPickup || hasCab || hasOffice || hasEmployee;

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

    return Scaffold(
      backgroundColor: OfficeRouteColors.background,
      appBar: AppBar(
        backgroundColor: OfficeRouteColors.background,
        elevation: 0,
        title: const Text(
          'Live Transport Map',
          style: OfficeRouteTypography.sectionTitle,
        ),
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
                child: const Icon(
                  Icons.map_outlined,
                  size: 40,
                  color: OfficeRouteColors.secondaryText,
                ),
              ),
              const SizedBox(height: OfficeRouteSpacing.lg),

              Text(
                'Map unavailable',
                style: OfficeRouteTypography.screenTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: OfficeRouteSpacing.xs),
              Text(
                'Your pickup point and today\'s route have not been configured.',
                style: OfficeRouteTypography.secondary,
                textAlign: TextAlign.center,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMapActionChip('Refresh', Icons.refresh, () {}),
                  const SizedBox(width: OfficeRouteSpacing.xs),
                  _buildMapActionChip(
                    'Contact Administrator',
                    Icons.support_agent,
                    () {},
                  ),
                ],
              ),
              const SizedBox(height: OfficeRouteSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMapActionChip(
                    'Setup Test Route (Demo)',
                    Icons.science_outlined,
                    () => controller.setupTestAssignmentForTesting(),
                  ),
                  const SizedBox(width: OfficeRouteSpacing.xs),
                  _buildMapActionChip(
                    'Return Home',
                    Icons.home_outlined,
                    () => Navigator.of(context).maybePop(),
                  ),
                ],
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

    // 1. Saved Pickup
    if (hasPickup) {
      final lat = controller.myAssignmentMember!.pickupLatitude!;
      final lng = controller.myAssignmentMember!.pickupLongitude!;
      pickupLatLng = LatLng(lat, lng);
      cameraTarget ??= pickupLatLng;
      boundsPoints.add(pickupLatLng);
      markers.add(
        Marker(
          markerId: const MarkerId('employee_pickup'),
          position: pickupLatLng,
          infoWindow: InfoWindow(
            title: controller.myAssignmentMember?.pickupName.isNotEmpty == true
                ? controller.myAssignmentMember!.pickupName
                : 'My Pickup Point',
            snippet: 'Saved Employee Pickup',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
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
          infoWindow: InfoWindow(
            title: 'Assigned Cab',
            snippet: 'Driver Live Location (${controller.cabSpeedDisplay})',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
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
          markerId: const MarkerId('destination_office'),
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
        ),
      );
    }

    // 4. Employee Own Live Location
    if (hasEmployee) {
      final empLoc = controller.employeeLiveLocation!;
      final empLatLng = LatLng(empLoc.latitude, empLoc.longitude);
      cameraTarget ??= empLatLng;
      boundsPoints.add(empLatLng);
      markers.add(
        Marker(
          markerId: const MarkerId('employee_own_live'),
          position: empLatLng,
          infoWindow: const InfoWindow(
            title: 'My Location',
            snippet: 'Current Location',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    // Determine partial-data status text
    String? partialStatusText;
    if (hasPickup && !hasCab && !hasOffice) {
      partialStatusText = 'Waiting for cab assignment';
    }

    // Build distance display info
    final empDist = controller.employeeDistanceToPickupMeters;
    final cabDist = controller.cabDistanceToPickupMeters;
    final freshness = EmployeeTransportController.formatFreshness(
      controller.employeeLiveLocation?.updatedAt,
    );

    final hasActiveTrip =
        controller.activeTrip != null &&
        (controller.activeTrip!.status == 'active' ||
            controller.activeTrip!.status == 'office_arrived');

    return Scaffold(
      backgroundColor: OfficeRouteColors.background,
      appBar: AppBar(
        backgroundColor: OfficeRouteColors.background,
        elevation: 0,
        title: const Text(
          'Live Transport Map',
          style: OfficeRouteTypography.sectionTitle,
        ),
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: cameraTarget!,
              zoom: 14.0,
            ),
            markers: markers,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (c) {
              _mapController = c;
              if (boundsPoints.length >= 2) {
                _fitBounds(boundsPoints);
              }
            },
          ),

          // Partial-data status banner
          if (partialStatusText != null)
            Positioned(
              top: OfficeRouteSpacing.md,
              left: OfficeRouteSpacing.md,
              right: OfficeRouteSpacing.md,
              child: OfficeRouteCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: OfficeRouteColors.waitingAmber,
                      size: 18,
                    ),
                    const SizedBox(width: OfficeRouteSpacing.xs),
                    Expanded(
                      child: Text(
                        partialStatusText,
                        style: OfficeRouteTypography.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Map controls (right side)
          Positioned(
            right: OfficeRouteSpacing.md,
            bottom: hasActiveTrip ? 200 : OfficeRouteSpacing.xl + 80,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Fit all markers
                if (boundsPoints.length >= 2)
                  _buildMapControlButton(
                    icon: Icons.fit_screen,
                    tooltip: 'Fit all markers',
                    onTap: () => _fitBounds(boundsPoints),
                  ),
                if (hasPickup) ...[
                  const SizedBox(height: OfficeRouteSpacing.xs),
                  _buildMapControlButton(
                    icon: Icons.location_on_outlined,
                    tooltip: 'Center on pickup',
                    onTap: () => _animateTo(pickupLatLng!),
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
                  tooltip: 'Recenter',
                  onTap: () {
                    if (cameraTarget != null) _animateTo(cameraTarget);
                  },
                ),
              ],
            ),
          ),

          // Bottom distance / info overlay
          Positioned(
            left: OfficeRouteSpacing.md,
            right: OfficeRouteSpacing.md,
            bottom: OfficeRouteSpacing.md,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Distance chips row
                if (empDist != null || cabDist != null)
                  OfficeRouteCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (empDist != null)
                          _buildDistanceChip(
                            'You → Pickup',
                            '${empDist.round()} m',
                            Icons.person_pin_circle_outlined,
                            OfficeRouteColors.liveBlue,
                          ),
                        if (empDist != null && cabDist != null)
                          Container(
                            width: 1,
                            height: 30,
                            color: OfficeRouteColors.divider,
                          ),
                        if (cabDist != null)
                          _buildDistanceChip(
                            'Cab → Pickup',
                            '${cabDist.round()} m',
                            Icons.directions_car_outlined,
                            OfficeRouteColors.readyGreen,
                          ),
                        if (hasEmployee)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: OfficeRouteSpacing.xs,
                            ),
                            child: Text(
                              freshness,
                              style: OfficeRouteTypography.secondary.copyWith(
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                // Active trip sheet
                if (hasActiveTrip) ...[
                  const SizedBox(height: OfficeRouteSpacing.xs),
                  _buildTripSheet(controller),
                ],
              ],
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

  Widget _buildDistanceChip(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: OfficeRouteTypography.secondary.copyWith(fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: OfficeRouteTypography.tabularData.copyWith(
            color: color,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildTripSheet(EmployeeTransportController controller) {
    return OfficeRouteCard(
      isHero: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isSheetExpanded = !_isSheetExpanded),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (controller.activeTrip?.status == 'active')
                      const OfficeRouteStatusChip(
                        label: 'LIVE TRIP',
                        icon: Icons.directions_car,
                        glowType: TransportGlowType.liveBlue,
                      )
                    else
                      const OfficeRouteStatusChip(
                        label: 'TRIP INFO',
                        icon: Icons.map,
                        glowType: TransportGlowType.none,
                      ),
                    const SizedBox(width: OfficeRouteSpacing.xs),
                    Text(
                      controller.contextualActionLabel,
                      style: OfficeRouteTypography.secondary,
                    ),
                  ],
                ),
                Icon(
                  _isSheetExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                  color: OfficeRouteColors.primaryText,
                ),
              ],
            ),
          ),
          if (_isSheetExpanded) ...[
            const Divider(color: OfficeRouteColors.divider, height: 20),
            if (controller.passengerProgressList.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView(
                  shrinkWrap: true,
                  children: controller.passengerProgressList
                      .map(
                        (p) => OfficeRoutePassengerProgressTile(
                          sequence: p.pickupSequence,
                          passengerName: p.passengerDisplayName,
                          statusText: p.status.replaceAll('_', ' '),
                          statusGlow:
                              (p.status == 'ready' || p.status == 'picked_up')
                              ? TransportGlowType.readyGreen
                              : (p.status == 'travelling_to_pickup'
                                    ? TransportGlowType.liveBlue
                                    : TransportGlowType.none),
                          distanceText: p.distanceToPickupMeters != null
                              ? '${p.distanceToPickupMeters!.round()} m from pickup'
                              : null,
                          timeEstimateText: p.estimatedReadyMinutes != null
                              ? '${p.estimatedReadyMinutes} min'
                              : '—',
                          freshnessText: p.formatAge(DateTime.now()),
                        ),
                      )
                      .toList(),
                ),
              )
            else
              Text(
                'Passenger progress is not available yet.',
                style: OfficeRouteTypography.secondary,
              ),
          ],
        ],
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

  void _animateTo(LatLng target) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16.0));
  }

  void _fitBounds(List<LatLng> points) {
    if (points.length < 2 || _mapController == null) return;
    var sw = LatLng(points[0].latitude, points[0].longitude);
    var ne = LatLng(points[0].latitude, points[0].longitude);
    for (final p in points) {
      if (p.latitude < sw.latitude) {
        sw = LatLng(p.latitude, sw.longitude);
      }
      if (p.longitude < sw.longitude) {
        sw = LatLng(sw.latitude, p.longitude);
      }
      if (p.latitude > ne.latitude) {
        ne = LatLng(p.latitude, ne.longitude);
      }
      if (p.longitude > ne.longitude) {
        ne = LatLng(ne.latitude, p.longitude);
      }
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: sw, northeast: ne),
        60.0,
      ),
    );
  }
}
