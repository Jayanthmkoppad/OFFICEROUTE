import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TransportLocationSelection {
  const TransportLocationSelection({
    required this.label,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final String address;
  final double latitude;
  final double longitude;

  bool get isValid =>
      label.trim().isNotEmpty &&
      address.trim().isNotEmpty &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}

/// Reusable coordinate-backed picker for Driver destinations and Employee
/// pickup locations. Address search is intentionally not simulated when no
/// geocoding provider is configured.
class TransportLocationPicker extends StatefulWidget {
  const TransportLocationPicker({
    super.key,
    required this.title,
    this.initialSelection,
  });

  final String title;
  final TransportLocationSelection? initialSelection;

  static Future<TransportLocationSelection?> show(
    BuildContext context, {
    required String title,
    TransportLocationSelection? initialSelection,
  }) {
    return Navigator.of(context).push<TransportLocationSelection>(
      MaterialPageRoute(
        builder: (_) => TransportLocationPicker(
          title: title,
          initialSelection: initialSelection,
        ),
      ),
    );
  }

  @override
  State<TransportLocationPicker> createState() =>
      _TransportLocationPickerState();
}

class _TransportLocationPickerState extends State<TransportLocationPicker> {
  late final TextEditingController _labelController;
  late final TextEditingController _addressController;
  LatLng? _selection;
  bool _locating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSelection;
    _labelController = TextEditingController(text: initial?.label ?? '');
    _addressController = TextEditingController(text: initial?.address ?? '');
    if (initial != null) {
      _selection = LatLng(initial.latitude, initial.longitude);
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Location services are disabled.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Location permission is required.');
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _selection = LatLng(position.latitude, position.longitude);
        _labelController.text = _labelController.text.trim().isEmpty
            ? 'Current map location'
            : _labelController.text;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _confirm() {
    final point = _selection;
    if (point == null) {
      setState(() => _error = 'Select a point on the map.');
      return;
    }
    final coordinateText =
        '${point.latitude.toStringAsFixed(6)}, '
        '${point.longitude.toStringAsFixed(6)}';
    final selection = TransportLocationSelection(
      label: _labelController.text.trim().isEmpty
          ? 'Selected coordinates'
          : _labelController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? coordinateText
          : _addressController.text.trim(),
      latitude: point.latitude,
      longitude: point.longitude,
    );
    if (!selection.isValid) {
      setState(() => _error = 'Select a valid location.');
      return;
    }
    Navigator.pop(context, selection);
  }

  @override
  Widget build(BuildContext context) {
    final initialTarget = _selection ?? const LatLng(0, 0);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialTarget,
                zoom: _selection == null ? 4.5 : 16,
              ),
              myLocationButtonEnabled: false,
              myLocationEnabled: false,
              markers: _selection == null
                  ? const <Marker>{}
                  : {
                      Marker(
                        markerId: const MarkerId('transport_location'),
                        position: _selection!,
                        draggable: true,
                        onDragEnd: (point) =>
                            setState(() => _selection = point),
                      ),
                    },
              onTap: (point) => setState(() {
                _selection = point;
                _error = null;
              }),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _labelController,
                    decoration: const InputDecoration(
                      labelText: 'Location label',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address (optional without geocoding)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_selection != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_selection!.latitude.toStringAsFixed(6)}, '
                        '${_selection!.longitude.toStringAsFixed(6)}',
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _locating ? null : _useCurrentLocation,
                          icon: _locating
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.my_location),
                          label: const Text('Current location'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: _confirm,
                          child: const Text('Confirm Location'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
