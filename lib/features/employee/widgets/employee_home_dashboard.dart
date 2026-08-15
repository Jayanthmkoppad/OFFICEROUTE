import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../shared/widgets/transport_location_picker.dart';

import '../../../core/models/passenger_progress_model.dart';
import '../controllers/employee_transport_controller.dart';
import 'employee_transport_roster_card.dart';

class EmployeeHomeDashboard extends StatelessWidget {
  const EmployeeHomeDashboard({super.key, required this.onNavigateToMap});

  final VoidCallback onNavigateToMap;

  @override
  Widget build(BuildContext context) {
    final controller = EmployeeTransportScope.of(context);
    final state = controller.homeViewState;

    return Scaffold(
      backgroundColor: _HomeColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _HomeColors.accent,
          onRefresh: () => _refresh(context, controller),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _TopBar(controller: controller)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                sliver: SliverList.list(
                  children: [
                    _Welcome(controller: controller),
                    const SizedBox(height: 16),
                    _TransportHero(
                      controller: controller,
                      state: state,
                      onOpenMap: onNavigateToMap,
                      onRefresh: () => _refresh(context, controller),
                    ),
                    if (controller.activeTrip != null) ...[
                      const SizedBox(height: 12),
                      _KpiGrid(controller: controller, state: state),
                    ],
                    if (controller.activeAssignment != null) ...[
                      const SizedBox(height: 24),
                      _MapPreview(
                        controller: controller,
                        onOpenMap: onNavigateToMap,
                      ),
                    ],
                    if (controller.activeTrip != null &&
                        state.currentPickup != null) ...[
                      const SizedBox(height: 24),
                      _PickupProgress(
                        controller: controller,
                        current: state.currentPickup!,
                        next: state.nextPickup,
                      ),
                    ],
                    if (controller.activeAssignment != null) ...[
                      const SizedBox(height: 24),
                      const _SectionLabel('YOUR CAB'),
                      const SizedBox(height: 8),
                      _CabCard(
                        controller: controller,
                        onTrack: onNavigateToMap,
                      ),
                    ],
                    const SizedBox(height: 24),
                    _AttendancePrivacy(controller: controller),
                    const SizedBox(height: 24),
                    EmployeeTransportRosterCard(
                      progress: state.orderedProgress,
                      currentUserId: controller.currentUser?.uid ?? '',
                      isUpdating: controller.isActionLoading,
                      canUpdateOwnStatus:
                          controller.canUpdateOwnTransportStatus,
                      diagnosticCode: controller.rosterDiagnosticCode,
                      hasConfiguredRoute: controller.activeAssignment != null,
                      homeStyle: true,
                      routeLabel: _rosterLabel(controller),
                      onUpdateStatus: (status) async {
                        final result = await controller
                            .updateOwnTransportRemark(status);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(result.message)));
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _rosterLabel(EmployeeTransportController controller) {
    if (controller.activeAssignment == null) {
      return 'No active route for today';
    }
    if (controller.activeTrip == null) {
      return 'Configured route Ã‚Â· Trip not started';
    }
    return 'Live pickup progress Ã‚Â· Same route only';
  }

  static Future<void> _refresh(
    BuildContext context,
    EmployeeTransportController controller,
  ) async {
    final result = await controller.refreshCurrentDay();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});

  final EmployeeTransportController controller;

  @override
  Widget build(BuildContext context) {
    final user = controller.currentUser;
    final name = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : 'Employee';
    final code = user?.employeeCode.trim().isNotEmpty == true
        ? user!.employeeCode.trim()
        : 'Unavailable';
    final status = _status(controller);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: _HomeColors.background,
        border: Border(bottom: BorderSide(color: _HomeColors.border)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _HomeColors.avatar,
            foregroundImage: user?.profileImage.trim().isNotEmpty == true
                ? NetworkImage(user!.profileImage.trim())
                : null,
            child: Text(
              name.characters.first.toUpperCase(),
              style: _HomeText.title,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('OfficeRoute', style: _HomeText.brand),
                Text(
                  'EMP CODE: $code',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _HomeText.micro,
                ),
              ],
            ),
          ),
          _StatusPill(label: status.$1, color: status.$2),
          const SizedBox(width: 8),
          const Icon(
            Icons.notifications_none,
            color: _HomeColors.accent,
            size: 20,
          ),
        ],
      ),
    );
  }

  (String, Color) _status(EmployeeTransportController controller) {
    final diagnostic = controller.homeViewState.diagnosticCode;
    if (diagnostic == 'location_services_disabled') {
      return ('GPS OFF', _HomeColors.amber);
    }
    if (diagnostic == 'offline') return ('OFFLINE', _HomeColors.error);
    if (diagnostic == 'permission_denied') {
      return ('LOCATION OFF', _HomeColors.amber);
    }
    final invitation = controller.myAssignmentMember?.invitationStatus;
    if (invitation == 'invited') return ('INVITED', _HomeColors.amber);
    if (invitation == 'accepted' || invitation == 'trip_active') {
      return ('ACCEPTED', _HomeColors.green);
    }
    if (invitation == 'declined') return ('DECLINED', _HomeColors.muted);
    if (controller.activeAssignment != null) {
      return ('CONNECTED', _HomeColors.accent);
    }
    return ('NO INVITATION', _HomeColors.muted);
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.controller});
  final EmployeeTransportController controller;

  @override
  Widget build(BuildContext context) {
    final now = controller.currentTime;
    final name = controller.currentUser?.name.trim().isNotEmpty == true
        ? controller.currentUser!.name.trim()
        : 'Employee';
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final invitation = controller.myAssignmentMember?.invitationStatus;
    final message = controller.activeTrip != null
        ? 'Your office trip is active.'
        : invitation == 'invited'
        ? 'A Driver has invited you to today'
              's office trip.'
        : invitation == 'accepted'
        ? 'Invitation accepted. Waiting for the Driver to start the trip.'
        : 'No transport invitation for today.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$greeting, $name', style: _HomeText.title),
        const SizedBox(height: 2),
        Text(message, style: _HomeText.bodyMuted),
      ],
    );
  }
}

class _TransportHero extends StatelessWidget {
  const _TransportHero({
    required this.controller,
    required this.state,
    required this.onOpenMap,
    required this.onRefresh,
  });
  final EmployeeTransportController controller;
  final EmployeeHomeViewState state;
  final VoidCallback onOpenMap;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoading) {
      return const _HomeCard(
        key: Key('employee_home_loading'),
        color: _HomeColors.hero,
        padding: EdgeInsets.all(21),
        child: SizedBox(
          height: 124,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final content = _heroContent(controller, state);
    return _HomeCard(
      key: const Key('employee_transport_hero'),
      color: _HomeColors.hero,
      padding: const EdgeInsets.all(21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(content.eyebrow, style: _HomeText.eyebrow),
                    const SizedBox(height: 6),
                    Text(content.value, style: _HomeText.heroValue),
                    if (content.helper.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(content.helper, style: _HomeText.micro),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Status', style: _HomeText.bodyMuted),
                  Text(content.arrival, style: _HomeText.title),
                ],
              ),
            ],
          ),
          if (controller.myAssignmentMember != null &&
              controller.myAssignmentMember!.invitationStatus !=
                  'not_invited') ...[
            const SizedBox(height: 16),
            _InvitationDetails(controller: controller),
          ],
          const SizedBox(height: 16),
          _HeroActions(
            controller: controller,
            onOpenMap: onOpenMap,
            onRefresh: onRefresh,
          ),
        ],
      ),
    );
  }

  _HeroContent _heroContent(
    EmployeeTransportController controller,
    EmployeeHomeViewState state,
  ) {
    final diagnostic = state.diagnosticCode;
    if (diagnostic == 'offline' || diagnostic == 'query_failed') {
      return const _HeroContent(
        'CAB SERVICE',
        'Unable to load transport',
        'Check your connection and retry.',
        'Unavailable',
      );
    }
    final member = controller.myAssignmentMember;
    if (member == null ||
        member.invitationStatus == 'not_invited' ||
        member.invitationStatus == 'cancelled') {
      return const _HeroContent(
        'CAB SERVICE',
        'NO CAB INVITATION',
        'No transport invitation for today.',
        'Not invited',
      );
    }
    if (member.invitationStatus == 'declined') {
      return const _HeroContent(
        'CAB INVITATION',
        'Invitation declined',
        'You are not included in today'
            's pickup plan.',
        'Declined',
      );
    }
    if (member.invitationStatus == 'invited') {
      final destination = member.officeName.trim().isEmpty
          ? 'Office destination'
          : member.officeName.trim();
      return _HeroContent(
        'CAB INVITATION',
        'Cab available for today'
            's office trip',
        'Destination: $destination',
        'Pending response',
      );
    }
    if (member.invitationStatus == 'accepted' &&
        controller.activeTrip == null) {
      return _HeroContent(
        'CAB SERVICE',
        'ACCEPTED',
        'Waiting for Driver to start the trip.',
        'Accepted',
      );
    }
    final riderStatus = controller.myRiderRecord?.status ?? '';
    final tripStatus = controller.activeTrip?.status ?? '';
    if (riderStatus == 'completed' ||
        riderStatus == 'dropped' ||
        tripStatus == 'completed') {
      return const _HeroContent(
        'CAB SERVICE',
        'TRIP COMPLETED',
        'Arrived at office.',
        'Completed',
      );
    }
    if (riderStatus == 'picked_up' || riderStatus == 'boarded') {
      return const _HeroContent(
        'CAB SERVICE',
        'ONBOARD',
        'You are onboard. Destination: office.',
        'Onboard',
      );
    }
    if (riderStatus == 'arrived' ||
        riderStatus == 'waiting' ||
        riderStatus == 'driver_waiting') {
      return const _HeroContent(
        'CAB SERVICE',
        'DRIVER ARRIVED',
        'Your Driver is waiting at your pickup.',
        'Arrived',
      );
    }
    final distance = controller.cabDistanceToPickupMeters;
    return _HeroContent(
      'CAB SERVICE',
      'DRIVER APPROACHING',
      distance == null
          ? 'ETA unavailable'
          : 'Approx. ${_formatDistance(distance)} away - ETA unavailable',
      'Trip active',
    );
  }
}

class _HeroActions extends StatelessWidget {
  const _HeroActions({
    required this.controller,
    required this.onOpenMap,
    required this.onRefresh,
  });
  final EmployeeTransportController controller;
  final VoidCallback onOpenMap;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (controller.transportTrackingState == 'stop_failed') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          key: const Key('retry_stop_button'),
          onPressed: controller.isActionLoading
              ? null
              : controller.retryStopLocationSharing,
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('Retry Stop'),
        ),
      );
    }
    if (controller.transportSyncState == 'sync_pending') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          key: const Key('retry_sync_button'),
          onPressed: controller.isActionLoading
              ? null
              : controller.retryTripSynchronization,
          icon: const Icon(Icons.sync),
          label: const Text('Retry Sync'),
        ),
      );
    }
    final member = controller.myAssignmentMember;
    if (member == null ||
        member.invitationStatus == 'not_invited' ||
        member.invitationStatus == 'cancelled' ||
        member.invitationStatus == 'declined') {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: const Key('refresh_status_button'),
          onPressed: controller.isRefreshing ? null : onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      );
    }
    if (member.invitationStatus == 'invited') {
      return Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              key: const Key('accept_cab_invitation_button'),
              onPressed: controller.isActionLoading
                  ? null
                  : () => _accept(context),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Accept'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('decline_cab_invitation_button'),
              onPressed: controller.isActionLoading
                  ? null
                  : () => _decline(context),
              icon: const Icon(Icons.close),
              label: const Text('Decline'),
            ),
          ),
        ],
      );
    }
    final riderStatus = controller.myRiderRecord?.status ?? '';
    if (riderStatus == 'arrived' ||
        riderStatus == 'waiting' ||
        riderStatus == 'driver_waiting') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: const Key('employee_ready_to_board_button'),
          onPressed: controller.isActionLoading
              ? null
              : () => _readyToBoard(context),
          child: const Text("I'M READY"),
        ),
      );
    }
    if (member.invitationStatus == 'accepted' &&
        controller.activeAssignment == null) {
      return const SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: null,
          child: Text('Accepted - waiting for trip'),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: const Key('track_cab_button'),
        onPressed: onOpenMap,
        icon: const Icon(Icons.navigation_outlined),
        label: const Text('Track Cab'),
      ),
    );
  }

  Future<void> _accept(BuildContext context) async {
    var result = await controller.acceptTransportInvitation();
    if (!context.mounted) return;
    if (!result.isAccepted && result.message == 'Set your pickup location') {
      final user = controller.currentUser;
      final savedLat = user?.preferredPickupLatitude;
      final savedLng = user?.preferredPickupLongitude;
      final selection = await TransportLocationPicker.show(
        context,
        title: 'Set your pickup location',
        initialSelection: savedLat == null || savedLng == null
            ? null
            : TransportLocationSelection(
                label: user!.preferredPickupAddress,
                address: user.preferredPickupAddress,
                latitude: savedLat,
                longitude: savedLng,
              ),
      );
      if (selection == null || !context.mounted) return;
      await controller.saveTravelLocations(
        homeAddress: user?.homeAddress ?? '',
        homeLatitude: user?.homeLatitude ?? selection.latitude,
        homeLongitude: user?.homeLongitude ?? selection.longitude,
        pickupAddress: selection.address,
        pickupLatitude: selection.latitude,
        pickupLongitude: selection.longitude,
      );
      result = await controller.acceptTransportInvitation(
        pickupName: selection.label,
        pickupAddress: selection.address,
        pickupLatitude: selection.latitude,
        pickupLongitude: selection.longitude,
      );
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _decline(BuildContext context) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Decline cab invitation'),
        children: [
          for (final value in const [
            'Not travelling today',
            'Own transport',
            'Leave / unavailable',
            'Other',
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, value),
              child: Text(value),
            ),
        ],
      ),
    );
    if (reason == null || !context.mounted) return;
    final result = await controller.declineTransportInvitation(reason: reason);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _readyToBoard(BuildContext context) async {
    final result = await controller.markReadyAtPickup();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }
}

class _InvitationDetails extends StatelessWidget {
  const _InvitationDetails({required this.controller});
  final EmployeeTransportController controller;
  @override
  Widget build(BuildContext context) {
    final m = controller.myAssignmentMember!, v = controller.assignedVehicle;
    final vehicle = v?.registrationNumber.trim().isNotEmpty == true
        ? v!.registrationNumber.trim()
        : v?.vehicleNumber.trim().isNotEmpty == true
        ? v!.vehicleNumber.trim()
        : m.vehicleId.trim().isEmpty
        ? 'Vehicle unavailable'
        : m.vehicleId.trim();
    final pickup = m.pickupName.trim().isNotEmpty
        ? m.pickupName.trim()
        : m.pickupAddress.trim().isNotEmpty
        ? m.pickupAddress.trim()
        : 'Pickup location required';
    final office = m.officeName.trim().isNotEmpty
        ? m.officeName.trim()
        : m.officeAddress.trim().isNotEmpty
        ? m.officeAddress.trim()
        : 'Office destination unavailable';
    final sent = m.invitedAt == null
        ? 'Sent time unavailable'
        : MaterialLocalizations.of(
            context,
          ).formatTimeOfDay(TimeOfDay.fromDateTime(m.invitedAt!.toLocal()));
    return Column(
      key: const Key('employee_invitation_details'),
      children: [
        _r('Driver', controller.driverDisplayName),
        _r('Vehicle', vehicle),
        _r('Office', office),
        _r('Pickup', pickup),
        if (m.invitationStatus == 'invited') _r('Sent', sent),
      ],
    );
  }

  Widget _r(String l, String v) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 72, child: Text(l, style: _HomeText.bodyMuted)),
        Expanded(child: Text(v, style: _HomeText.bodyMuted)),
      ],
    ),
  );
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.controller, required this.state});

  final EmployeeTransportController controller;
  final EmployeeHomeViewState state;

  @override
  Widget build(BuildContext context) {
    final own = state.orderedProgress
        .where((item) => item.employeeId == controller.currentUser?.uid)
        .firstOrNull;
    final items = [
      _Kpi(
        'MY DISTANCE',
        controller.employeeDistanceToPickupMeters == null
            ? 'Unavailable'
            : _formatDistance(controller.employeeDistanceToPickupMeters!),
        controller.employeeDistanceToPickupMeters == null
            ? 'Location unavailable'
            : 'Straight-line',
      ),
      _Kpi(
        'MY ETA',
        own?.estimatedReadyMinutes == null
            ? 'Unavailable'
            : '${own!.estimatedReadyMinutes} min',
        own?.estimatedReadyMinutes == null
            ? 'Traffic ETA unavailable'
            : 'Shared route estimate',
      ),
      _Kpi('ROUTE POSITION', _routePosition(controller, state), 'Today'),
      _Kpi(
        'ONBOARD STATUS',
        '${state.onboardEmployees}/${state.activeEmployees}',
        '${state.remainingEmployees} remaining',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 92,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _HomeCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(item.label, style: _HomeText.eyebrowMuted),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(item.value, style: _HomeText.title),
              ),
              Text(
                item.helper,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _HomeText.micro,
              ),
            ],
          ),
        );
      },
    );
  }

  String _routePosition(
    EmployeeTransportController controller,
    EmployeeHomeViewState state,
  ) {
    final uid = controller.currentUser?.uid;
    if (uid == null || uid.isEmpty) return 'Unavailable';
    final own = state.orderedProgress
        .where((item) => item.employeeId == uid)
        .firstOrNull;
    if (own == null) return 'Unavailable';
    if (const {'picked_up', 'boarded'}.contains(own.status)) return 'Onboard';
    if (state.currentPickup?.employeeId == uid) return 'Current';
    if (state.nextPickup?.employeeId == uid) return 'Next';
    return own.pickupSequence > 0 ? 'Stop ${own.pickupSequence}' : 'Assigned';
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.controller, required this.onOpenMap});

  final EmployeeTransportController controller;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final points = _points(controller);
    final center = points.isNotEmpty ? points.first.$2 : const LatLng(0, 0);
    final markers = {
      for (final point in points)
        Marker(
          markerId: MarkerId(point.$1),
          position: point.$2,
          infoWindow: InfoWindow(title: point.$3),
        ),
    };

    return Semantics(
      button: true,
      label: 'Open live transport map',
      child: InkWell(
        key: const Key('home_map_shortcut'),
        onTap: onOpenMap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 192,
          decoration: BoxDecoration(
            color: _HomeColors.card,
            border: Border.all(color: _HomeColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: center,
                      zoom: 12.5,
                    ),
                    markers: markers,
                    liteModeEnabled: true,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    myLocationButtonEnabled: false,
                    compassEnabled: false,
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: _MapBadge(isLive: controller.activeTrip != null),
              ),
              const Positioned(right: 12, bottom: 12, child: _RoundMapButton()),
            ],
          ),
        ),
      ),
    );
  }

  List<(String, LatLng, String)> _points(
    EmployeeTransportController controller,
  ) {
    final points = <(String, LatLng, String)>[];
    final own = controller.employeeLiveLocation;
    if (own != null) {
      points.add(('employee', LatLng(own.latitude, own.longitude), 'You'));
    }
    final pickup = controller.myAssignmentMember;
    if (pickup?.pickupLatitude != null && pickup?.pickupLongitude != null) {
      points.add((
        'pickup',
        LatLng(pickup!.pickupLatitude!, pickup.pickupLongitude!),
        'Your pickup',
      ));
    }
    final driver = controller.driverLiveLocation;
    if (driver != null) {
      points.add(('driver', LatLng(driver.latitude, driver.longitude), 'Cab'));
    }
    final office = controller.activeAssignment;
    if (office?.officeLatitude != null && office?.officeLongitude != null) {
      points.add((
        'office',
        LatLng(office!.officeLatitude!, office.officeLongitude!),
        office.officeName.isEmpty ? 'Office' : office.officeName,
      ));
    }
    return points;
  }
}

class _PickupProgress extends StatelessWidget {
  const _PickupProgress({
    required this.controller,
    required this.current,
    required this.next,
  });

  final EmployeeTransportController controller;
  final PassengerProgressModel current;
  final PassengerProgressModel? next;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 16,
            child: Column(
              children: [
                const Expanded(
                  child: VerticalDivider(
                    color: _HomeColors.green,
                    thickness: 2,
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: _HomeColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const Expanded(
                  child: VerticalDivider(
                    color: _HomeColors.border,
                    thickness: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                _PickupTile(
                  label: 'CURRENT PICKUP',
                  progress: current,
                  isMe: current.employeeId == controller.currentUser?.uid,
                  highlighted: false,
                ),
                if (next != null) ...[
                  const SizedBox(height: 12),
                  _PickupTile(
                    label: next!.employeeId == controller.currentUser?.uid
                        ? 'NEXT PICKUP (YOU)'
                        : 'NEXT PICKUP',
                    progress: next!,
                    isMe: next!.employeeId == controller.currentUser?.uid,
                    highlighted:
                        next!.employeeId == controller.currentUser?.uid,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickupTile extends StatelessWidget {
  const _PickupTile({
    required this.label,
    required this.progress,
    required this.isMe,
    required this.highlighted,
  });

  final String label;
  final PassengerProgressModel progress;
  final bool isMe;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      color: highlighted
          ? _HomeColors.accent.withValues(alpha: 0.10)
          : _HomeColors.hero,
      borderColor: highlighted
          ? _HomeColors.accent.withValues(alpha: 0.35)
          : _HomeColors.border,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: highlighted
                      ? _HomeText.eyebrow
                      : _HomeText.eyebrowMuted,
                ),
                const SizedBox(height: 2),
                Text(
                  '${isMe ? 'You' : progress.passengerDisplayName} Ã‚Â· Stop ${progress.pickupSequence}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _HomeText.title,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _statusLabel(progress.status),
            textAlign: TextAlign.end,
            style: _HomeText.eyebrow.copyWith(
              color: progress.status == 'ready'
                  ? _HomeColors.green
                  : _HomeColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _CabCard extends StatelessWidget {
  const _CabCard({required this.controller, required this.onTrack});

  final EmployeeTransportController controller;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    final vehicle = controller.assignedVehicle;
    final vehicleText = vehicle?.registrationNumber.trim().isNotEmpty == true
        ? vehicle!.registrationNumber.trim()
        : vehicle?.vehicleNumber.trim().isNotEmpty == true
        ? vehicle!.vehicleNumber.trim()
        : controller.activeAssignment?.vehicleId.trim().isNotEmpty == true
        ? controller.activeAssignment!.vehicleId.trim()
        : 'Vehicle pending';

    return _HomeCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _HomeColors.avatar,
                  border: Border.all(color: _HomeColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.directions_car_filled_outlined,
                  color: _HomeColors.accent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.driverDisplayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _HomeText.title,
                    ),
                    Text(
                      vehicleText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _HomeText.bodyMuted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  controller.driverLocationFreshness,
                  textAlign: TextAlign.end,
                  style: _HomeText.micro.copyWith(color: _HomeColors.green),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onTrack,
              icon: const Icon(Icons.location_on_outlined),
              label: const Text('Track'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendancePrivacy extends StatelessWidget {
  const _AttendancePrivacy({required this.controller});

  final EmployeeTransportController controller;

  @override
  Widget build(BuildContext context) {
    final attendance = controller.todayAttendance;
    final checkedIn = attendance?.isCheckedIn == true;

    return _HomeCard(
      key: const Key('attendance_privacy_card'),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: checkedIn
                  ? _HomeColors.green.withValues(alpha: 0.12)
                  : _HomeColors.avatar,
              shape: BoxShape.circle,
            ),
            child: Icon(
              checkedIn ? Icons.check_circle_outline : Icons.schedule,
              size: 18,
              color: checkedIn ? _HomeColors.green : _HomeColors.muted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  checkedIn
                      ? 'Attendance Checked In'
                      : attendance?.status ?? 'Attendance Not Started',
                  style: _HomeText.title,
                ),
                Text(
                  controller.profileLocationStatus == 'Active'
                      ? 'Route-safe location status shared'
                      : 'Exact location is not shown in the roster',
                  style: _HomeText.micro,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(_clock(attendance?.checkInTime), style: _HomeText.eyebrowMuted),
        ],
      ),
    );
  }

  String _clock(DateTime? value) {
    if (value == null) return 'Unavailable';
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    return '${hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')} '
        '${value.hour < 12 ? 'AM' : 'PM'}';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: _HomeText.eyebrowMuted);
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = _HomeColors.card,
    this.borderColor = _HomeColors.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('employee_status_${label.toLowerCase().replaceAll(' ', '_')}'),
      constraints: const BoxConstraints(maxWidth: 104),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _HomeText.micro.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MapBadge extends StatelessWidget {
  const _MapBadge({required this.isLive});

  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _HomeColors.background.withValues(alpha: 0.82),
        border: Border.all(color: _HomeColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isLive ? _HomeColors.green : _HomeColors.amber,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isLive ? 'Live Tracking' : 'Route Preview',
            style: _HomeText.micro.copyWith(
              color: _HomeColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundMapButton extends StatelessWidget {
  const _RoundMapButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _HomeColors.background.withValues(alpha: 0.88),
        border: Border.all(color: _HomeColors.border),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.open_in_full,
        size: 17,
        color: _HomeColors.primary,
      ),
    );
  }
}

class _HeroContent {
  const _HeroContent(this.eyebrow, this.value, this.helper, this.arrival);

  final String eyebrow;
  final String value;
  final String helper;
  final String arrival;
}

class _Kpi {
  const _Kpi(this.label, this.value, this.helper);

  final String label;
  final String value;
  final String helper;
}

class _HomeColors {
  const _HomeColors._();

  static const background = Color(0xFF051424);
  static const card = Color(0xFF122131);
  static const hero = Color(0xFF1C2B3C);
  static const avatar = Color(0xFF273647);
  static const border = Color(0xFF3A494B);
  static const primary = Color(0xFFD4E4FA);
  static const muted = Color(0xFFB9CACB);
  static const accent = Color(0xFF00F2FF);
  static const green = Color(0xFF4AE183);
  static const amber = Color(0xFFEEC209);
  static const error = Color(0xFFFFB4AB);
}

class _HomeText {
  const _HomeText._();

  static const title = TextStyle(
    color: _HomeColors.primary,
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w700,
  );
  static const brand = TextStyle(
    color: _HomeColors.accent,
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w700,
  );
  static const bodyMuted = TextStyle(
    color: _HomeColors.muted,
    fontSize: 14,
    height: 1.42,
  );
  static const eyebrow = TextStyle(
    color: _HomeColors.accent,
    fontSize: 12,
    height: 1.33,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
  );
  static const eyebrowMuted = TextStyle(
    color: _HomeColors.muted,
    fontSize: 12,
    height: 1.33,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
  );
  static const micro = TextStyle(
    color: _HomeColors.muted,
    fontSize: 10,
    height: 1.5,
  );
  static const heroValue = TextStyle(
    color: _HomeColors.primary,
    fontSize: 28,
    height: 1.14,
    fontWeight: FontWeight.w600,
  );
}

String _formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

String _statusLabel(String value) {
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
