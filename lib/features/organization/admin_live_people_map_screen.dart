import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/models/cab_trip_model.dart';
import '../../core/models/live_location_model.dart';
import '../../core/models/location_session_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/cab_assignment_service.dart';
import '../../core/services/cab_trip_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/live_location_service.dart';
import '../../core/services/location_session_watch_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'admin_active_trip_detail_screen.dart';

/// Administrator's all-people live map. Aggregates drivers, employees,
/// field engineers and service engineers - but only shows a user when they
/// currently have a valid, active work-location session, so users who are
/// off duty never appear. Includes freshness states (Online/Stale/Offline),
/// lightweight grid clustering, role/status filters and marker detail
/// bottom sheets.
class AdminLivePeopleMapScreen extends StatefulWidget {
  const AdminLivePeopleMapScreen({super.key});

  @override
  State<AdminLivePeopleMapScreen> createState() =>
      _AdminLivePeopleMapScreenState();
}

enum _RoleFilter { all, driver, employee, engineer }

enum _StatusFilter { any, activeTrip, waiting, online, stale }

class _AdminLivePeopleMapScreenState extends State<AdminLivePeopleMapScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<List<LiveLocationModel>>? _liveSub;
  StreamSubscription<List<LocationSessionModel>>? _sessionSub;
  StreamSubscription<void>? _tripSub;
  StreamSubscription<void>? _assignmentSub;
  Timer? _reloadDebounce;
  Timer? _freshnessTicker;

  List<LiveLocationModel> _liveLocations = const [];
  List<LocationSessionModel> _sessions = const [];
  Map<String, UserModel> _usersById = const {};
  List<CabTripModel> _trips = const [];
  double _currentZoom = 12;
  _RoleFilter _role = _RoleFilter.all;
  _StatusFilter _status = _StatusFilter.any;
  DateTime _now = DateTime.now();
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _liveSub = LiveLocationService.watchLiveLocations().listen((locations) {
      if (!mounted) return;
      setState(() => _liveLocations = locations);
    });
    _sessionSub = LocationSessionWatchService.watchActiveSessions().listen((
      sessions,
    ) {
      if (!mounted) return;
      setState(() => _sessions = sessions);
    });
    final today = _todayKey();
    _tripSub = CabTripService.watchTripsForDate(today).listen((_) {
      _scheduleReload();
    });
    _assignmentSub = CabAssignmentService.watchAssignmentsForDate(today).listen(
      (_) {
        _scheduleReload();
      },
    );
    _freshnessTicker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
    unawaited(_reload());
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _sessionSub?.cancel();
    _tripSub?.cancel();
    _assignmentSub?.cancel();
    _reloadDebounce?.cancel();
    _freshnessTicker?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  void _scheduleReload() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 400), _reload);
  }

  Future<void> _reload() async {
    try {
      final today = _todayKey();
      final users = await FirestoreService.fetchAllUsers();
      final trips = await CabTripService.fetchTripsForDate(dateKey: today);
      if (!mounted) return;
      setState(() {
        _usersById = {for (final user in users) user.uid: user};
        _trips = trips;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  _Freshness _freshnessFor(LiveLocationModel location) {
    if (location.status == 'offline' || location.status == 'stopped') {
      return _Freshness.offline;
    }
    final age = _now.difference(location.updatedAt);
    if (age.inSeconds <= 60 && location.status == 'active') {
      return _Freshness.online;
    }
    if (age.inMinutes <= 5) return _Freshness.stale;
    return _Freshness.offline;
  }

  String _roleGroup(String rawRole) {
    final role = rawRole.trim().toLowerCase();
    if (role.contains('driver')) return 'driver';
    if (role.contains('engineer')) return 'engineer';
    return 'employee';
  }

  List<_PersonPoint> _visiblePeople() {
    // Only include users with a valid active/paused location session AND a
    // fresh (non-offline-status) live location entry.
    final sessionUserIds = _sessions.map((session) => session.userId).toSet();
    final tripsByDriver = <String, CabTripModel>{
      for (final trip in _trips.where(
        (trip) => const {'active', 'office_arrived'}.contains(trip.status),
      ))
        trip.driverId: trip,
    };
    final points = <_PersonPoint>[];
    for (final location in _liveLocations) {
      if (!sessionUserIds.contains(location.userId)) continue;
      final user = _usersById[location.userId];
      if (user == null) continue;
      final group = _roleGroup(user.role);
      final freshness = _freshnessFor(location);
      final activeTrip = tripsByDriver[user.uid];
      points.add(
        _PersonPoint(
          user: user,
          location: location,
          freshness: freshness,
          group: group,
          activeTrip: activeTrip,
        ),
      );
    }

    // Apply role filter.
    var filtered = points.where((point) {
      switch (_role) {
        case _RoleFilter.all:
          return true;
        case _RoleFilter.driver:
          return point.group == 'driver';
        case _RoleFilter.employee:
          return point.group == 'employee';
        case _RoleFilter.engineer:
          return point.group == 'engineer';
      }
    }).toList();

    // Apply status filter.
    filtered = filtered.where((point) {
      switch (_status) {
        case _StatusFilter.any:
          return true;
        case _StatusFilter.activeTrip:
          return point.activeTrip != null;
        case _StatusFilter.waiting:
          return point.location.trackingReason == 'cab_pickup_ready';
        case _StatusFilter.online:
          return point.freshness == _Freshness.online;
        case _StatusFilter.stale:
          return point.freshness == _Freshness.stale;
      }
    }).toList();

    return filtered;
  }

  /// Lightweight grid clustering. Groups points by a lat/lng bucket whose
  /// size depends on the current zoom. Clusters of >= 2 points render as
  /// numeric circle markers; singletons render as their normal marker.
  Set<Marker> _buildMarkers(List<_PersonPoint> points) {
    if (points.isEmpty) return const {};

    final zoom = _currentZoom.clamp(3.0, 21.0);
    // A rough bucket size in degrees. Higher zoom => smaller bucket.
    final bucketSize = math.max(0.001, 40.0 / math.pow(2, zoom).toDouble());

    final buckets = <String, List<_PersonPoint>>{};
    for (final point in points) {
      final latBucket = (point.location.latitude / bucketSize).floor();
      final lngBucket = (point.location.longitude / bucketSize).floor();
      final key = '$latBucket:$lngBucket';
      buckets.putIfAbsent(key, () => []).add(point);
    }

    final markers = <Marker>{};
    for (final entry in buckets.entries) {
      final bucket = entry.value;
      if (bucket.length == 1) {
        markers.add(_singleMarker(bucket.first));
      } else {
        markers.add(_clusterMarker(entry.key, bucket));
      }
    }
    return markers;
  }

  Marker _singleMarker(_PersonPoint point) {
    return Marker(
      markerId: MarkerId('person_${point.user.uid}'),
      position: LatLng(point.location.latitude, point.location.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(_hueForPoint(point)),
      infoWindow: InfoWindow(
        title: point.user.name.isEmpty ? point.user.uid : point.user.name,
        snippet:
            '${_titleCase(point.group)} · ${_freshnessLabel(point.freshness)}',
      ),
      onTap: () => _openMarkerSheet(point),
    );
  }

  Marker _clusterMarker(String bucketKey, List<_PersonPoint> bucket) {
    final avgLat =
        bucket.fold<double>(0, (sum, point) => sum + point.location.latitude) /
        bucket.length;
    final avgLng =
        bucket.fold<double>(0, (sum, point) => sum + point.location.longitude) /
        bucket.length;
    return Marker(
      markerId: MarkerId('cluster_$bucketKey'),
      position: LatLng(avgLat, avgLng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: InfoWindow(
        title: '${bucket.length} people',
        snippet: 'Tap to see people in this area',
      ),
      onTap: () => _openClusterSheet(bucket),
    );
  }

  double _hueForPoint(_PersonPoint point) {
    if (point.freshness == _Freshness.offline) {
      return BitmapDescriptor.hueViolet;
    }
    if (point.freshness == _Freshness.stale) {
      return BitmapDescriptor.hueOrange;
    }
    switch (point.group) {
      case 'driver':
        return BitmapDescriptor.hueGreen;
      case 'engineer':
        return BitmapDescriptor.hueCyan;
      case 'employee':
      default:
        return BitmapDescriptor.hueYellow;
    }
  }

  String _freshnessLabel(_Freshness freshness) {
    switch (freshness) {
      case _Freshness.online:
        return 'Online';
      case _Freshness.stale:
        return 'Stale';
      case _Freshness.offline:
        return 'Offline';
    }
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  void _openMarkerSheet(_PersonPoint point) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => _MarkerDetailSheet(
        point: point,
        onOpenTrip: () {
          Navigator.of(context).pop();
          final trip = point.activeTrip;
          if (trip == null) return;
          Navigator.of(this.context).push(
            MaterialPageRoute(
              builder: (_) => AdminActiveTripDetailScreen(trip: trip),
            ),
          );
        },
      ),
    );
  }

  void _openClusterSheet(List<_PersonPoint> points) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => _ClusterSheet(
        points: points,
        onOpenPerson: (point) {
          Navigator.of(context).pop();
          _openMarkerSheet(point);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live People Map')),
        body: Center(child: Text('Failed to load map: $_error')),
      );
    }
    final points = _visiblePeople();
    final markers = _buildMarkers(points);
    final initial = points.isEmpty
        ? const LatLng(12.9716, 77.5946)
        : LatLng(
            points.first.location.latitude,
            points.first.location.longitude,
          );
    return Scaffold(
      appBar: AppBar(title: const Text('Live People Map')),
      body: Column(
        children: [
          _MapFilterBar(
            role: _role,
            status: _status,
            counts: _counts(points),
            onRoleChanged: (value) => setState(() => _role = value),
            onStatusChanged: (value) => setState(() => _status = value),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: initial, zoom: 12),
              markers: markers,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              onMapCreated: (controller) => _mapController = controller,
              onCameraMove: (position) {
                if ((position.zoom - _currentZoom).abs() < 0.5) return;
                setState(() => _currentZoom = position.zoom);
              },
            ),
          ),
        ],
      ),
    );
  }

  Map<String, int> _counts(List<_PersonPoint> points) {
    return {
      'all': points.length,
      'driver': points.where((point) => point.group == 'driver').length,
      'employee': points.where((point) => point.group == 'employee').length,
      'engineer': points.where((point) => point.group == 'engineer').length,
      'trip': points.where((point) => point.activeTrip != null).length,
      'online': points
          .where((point) => point.freshness == _Freshness.online)
          .length,
      'stale': points
          .where((point) => point.freshness == _Freshness.stale)
          .length,
    };
  }
}

enum _Freshness { online, stale, offline }

class _PersonPoint {
  final UserModel user;
  final LiveLocationModel location;
  final _Freshness freshness;
  final String group;
  final CabTripModel? activeTrip;

  const _PersonPoint({
    required this.user,
    required this.location,
    required this.freshness,
    required this.group,
    required this.activeTrip,
  });
}

class _MapFilterBar extends StatelessWidget {
  final _RoleFilter role;
  final _StatusFilter status;
  final Map<String, int> counts;
  final ValueChanged<_RoleFilter> onRoleChanged;
  final ValueChanged<_StatusFilter> onStatusChanged;

  const _MapFilterBar({
    required this.role,
    required this.status,
    required this.counts,
    required this.onRoleChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip(
              'All (${counts['all'] ?? 0})',
              selected: role == _RoleFilter.all,
              onTap: () => onRoleChanged(_RoleFilter.all),
            ),
            _chip(
              'Drivers (${counts['driver'] ?? 0})',
              selected: role == _RoleFilter.driver,
              onTap: () => onRoleChanged(_RoleFilter.driver),
            ),
            _chip(
              'Employees (${counts['employee'] ?? 0})',
              selected: role == _RoleFilter.employee,
              onTap: () => onRoleChanged(_RoleFilter.employee),
            ),
            _chip(
              'Engineers (${counts['engineer'] ?? 0})',
              selected: role == _RoleFilter.engineer,
              onTap: () => onRoleChanged(_RoleFilter.engineer),
            ),
            const SizedBox(width: 16),
            _chip(
              'Any Status',
              selected: status == _StatusFilter.any,
              onTap: () => onStatusChanged(_StatusFilter.any),
            ),
            _chip(
              'Active Trips (${counts['trip'] ?? 0})',
              selected: status == _StatusFilter.activeTrip,
              onTap: () => onStatusChanged(_StatusFilter.activeTrip),
            ),
            _chip(
              'Waiting',
              selected: status == _StatusFilter.waiting,
              onTap: () => onStatusChanged(_StatusFilter.waiting),
            ),
            _chip(
              'Online (${counts['online'] ?? 0})',
              selected: status == _StatusFilter.online,
              onTap: () => onStatusChanged(_StatusFilter.online),
            ),
            _chip(
              'Stale (${counts['stale'] ?? 0})',
              selected: status == _StatusFilter.stale,
              onTap: () => onStatusChanged(_StatusFilter.stale),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: selected,
        label: Text(label),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _MarkerDetailSheet extends StatelessWidget {
  final _PersonPoint point;
  final VoidCallback onOpenTrip;
  const _MarkerDetailSheet({required this.point, required this.onOpenTrip});

  @override
  Widget build(BuildContext context) {
    final user = point.user;
    final location = point.location;
    final coord =
        '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}';
    final ago = _humanAgo(location.updatedAt);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                foregroundImage: user.profileImage.isEmpty
                    ? null
                    : NetworkImage(user.profileImage),
                child: Text(
                  user.name.isEmpty
                      ? '?'
                      : user.name.substring(0, 1).toUpperCase(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name.isEmpty ? user.uid : user.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${_titleCase(point.group)} · ${user.branch.isEmpty ? '—' : user.branch}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              _StatusChip(freshness: point.freshness),
            ],
          ),
          const Divider(height: 20),
          _row('Employee code', user.employeeCode),
          _row('Phone', user.phone),
          _row('Department', user.department),
          _row('Coordinates', coord),
          _row(
            'Accuracy',
            location.accuracy <= 0
                ? '—'
                : '${location.accuracy.toStringAsFixed(1)} m',
          ),
          _row(
            'Speed',
            location.speed <= 0
                ? '—'
                : '${location.speed.toStringAsFixed(1)} m/s',
          ),
          _row('Last update', ago),
          if (point.group == 'driver' && point.activeTrip != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onOpenTrip,
              icon: const Icon(Icons.route_outlined),
              label: const Text('Open Active Trip'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    final display = value.trim().isEmpty ? '—' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.caption)),
          Flexible(
            child: Text(
              display,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  String _humanAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ClusterSheet extends StatelessWidget {
  final List<_PersonPoint> points;
  final ValueChanged<_PersonPoint> onOpenPerson;
  const _ClusterSheet({required this.points, required this.onOpenPerson});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${points.length} people in this cluster',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: points.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final point = points[index];
                    return ListTile(
                      leading: CircleAvatar(
                        foregroundImage: point.user.profileImage.isEmpty
                            ? null
                            : NetworkImage(point.user.profileImage),
                        child: Text(
                          point.user.name.isEmpty
                              ? '?'
                              : point.user.name.substring(0, 1).toUpperCase(),
                        ),
                      ),
                      title: Text(
                        point.user.name.isEmpty
                            ? point.user.uid
                            : point.user.name,
                      ),
                      subtitle: Text(
                        '${point.group[0].toUpperCase()}${point.group.substring(1)} · ${point.freshness.name}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onOpenPerson(point),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final _Freshness freshness;
  const _StatusChip({required this.freshness});
  @override
  Widget build(BuildContext context) {
    final color = switch (freshness) {
      _Freshness.online => AppColors.success,
      _Freshness.stale => AppColors.warning,
      _Freshness.offline => AppColors.textDisabled,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        freshness.name[0].toUpperCase() + freshness.name.substring(1),
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
