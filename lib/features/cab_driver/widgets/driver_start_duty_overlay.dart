import 'package:flutter/material.dart';

import '../../../core/models/cab_vehicle_model.dart';
import '../../../core/models/office_destination.dart';
import '../../../core/services/cab_vehicle_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/transport_location_picker.dart';

/// Visual progress overlay shown while the driver taps Start Duty. Walks the
/// driver through the well-defined Start Duty phases:
///
///   1. Vehicle selected
///   2. Location permission granted
///   3. Attendance check-in
///   4. Location session started
///   5. First GPS fix received
///
/// The step index is driven by the caller as work progresses. If a step
/// fails, the overlay stays paused on that step so the driver can retry.
/// Overlay never fabricates progress; every advance must be explicitly set.
class DriverStartDutyOverlay extends StatelessWidget {
  final int currentStep;
  final String? errorMessage;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  const DriverStartDutyOverlay({
    super.key,
    required this.currentStep,
    this.errorMessage,
    this.onCancel,
    this.onRetry,
  });

  static const List<String> steps = <String>[
    'Vehicle selected',
    'Location permission granted',
    'Attendance check-in',
    'Location session started',
    'First GPS fix received',
  ];

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.overlay,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Starting Duty',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Please wait while we prepare your shift.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 14),
                for (var index = 0; index < steps.length; index++)
                  _StepRow(label: steps[index], state: _stateFor(index)),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(24),
                      border: Border.all(color: AppColors.error.withAlpha(80)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onCancel != null)
                      TextButton(
                        onPressed: onCancel,
                        child: const Text('Cancel'),
                      ),
                    if (errorMessage != null && onRetry != null)
                      FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _StepState _stateFor(int index) {
    if (errorMessage != null && index == currentStep) return _StepState.error;
    if (index < currentStep) return _StepState.done;
    if (index == currentStep) return _StepState.active;
    return _StepState.pending;
  }
}

enum _StepState { pending, active, done, error }

class _StepRow extends StatelessWidget {
  final String label;
  final _StepState state;
  const _StepRow({required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (state) {
      _StepState.done => (Icons.check_circle, AppColors.success),
      _StepState.active => (Icons.autorenew, AppColors.info),
      _StepState.error => (Icons.error_outline, AppColors.error),
      _StepState.pending => (Icons.circle_outlined, AppColors.textDisabled),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: state == _StepState.active
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: state == _StepState.pending
                    ? AppColors.textDisabled
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          if (state == _StepState.active)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

/// Start Duty Checklist Modal Sheet (Stitch PNG 07 visual reference).
/// Collects vehicle confirmation, starting odometer, battery %, condition,
/// and pre-shift checklist before confirming Start Duty.
class StartDutyChecklistSheet extends StatefulWidget {
  final String? initialVehicleId;
  final OfficeDestination? initialOfficeDestination;
  final Future<List<CabVehicleModel>> Function()? loadVehicles;
  final Future<CabVehicleModel?> Function(String id)? getVehicle;
  final Future<void> Function({
    required String vehicleId,
    required double startOdometer,
    required int batteryPercentage,
    required String vehicleCondition,
    required OfficeDestination officeDestination,
    String? note,
  })
  onConfirm;

  const StartDutyChecklistSheet({
    super.key,
    this.initialVehicleId,
    this.initialOfficeDestination,
    this.loadVehicles,
    this.getVehicle,
    required this.onConfirm,
  });

  @override
  State<StartDutyChecklistSheet> createState() =>
      _StartDutyChecklistSheetState();
}

class _StartDutyChecklistSheetState extends State<StartDutyChecklistSheet> {
  late TextEditingController _odometerController;
  late TextEditingController _batteryController;
  late TextEditingController _noteController;
  late TextEditingController _issueCategoryController;
  late TextEditingController _issueDescriptionController;
  String _selectedVehicleId = '';
  List<CabVehicleModel> _availableVehicles = const [];
  bool _vehiclesLoading = true;
  String? _vehiclesError;
  OfficeDestination? _officeDestination;
  String _vehicleCondition = 'Good';
  bool _emergencyEquipmentConfirmed = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _odometerController = TextEditingController();
    _batteryController = TextEditingController();
    _noteController = TextEditingController();
    _issueCategoryController = TextEditingController();
    _issueDescriptionController = TextEditingController();
    _officeDestination = widget.initialOfficeDestination;
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _vehiclesLoading = true;
      _vehiclesError = null;
    });
    try {
      final loaded =
          await (widget.loadVehicles?.call() ??
              CabVehicleService.fetchAllVehicles());
      final vehicles = loaded
          .where(
            (vehicle) =>
                vehicle.id.trim().isNotEmpty &&
                vehicle.status.trim().toLowerCase() != 'inactive',
          )
          .toList(growable: false);
      final initialVehicleId = widget.initialVehicleId?.trim() ?? '';
      final initialExists = vehicles.any(
        (vehicle) => vehicle.id == initialVehicleId,
      );
      if (!mounted) return;
      setState(() {
        _availableVehicles = vehicles;
        _selectedVehicleId = initialExists
            ? initialVehicleId
            : (vehicles.length == 1 ? vehicles.single.id : '');
        _vehiclesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _availableVehicles = const [];
        _selectedVehicleId = '';
        _vehiclesLoading = false;
        _vehiclesError = 'Unable to load configured cabs';
      });
    }
  }

  @override
  void dispose() {
    _odometerController.dispose();
    _batteryController.dispose();
    _noteController.dispose();
    _issueCategoryController.dispose();
    _issueDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    if (_isSubmitting) return;
    final odo = double.tryParse(_odometerController.text.trim());
    if (odo == null || odo < 0) {
      setState(
        () => _errorMessage = 'Please enter a valid starting odometer reading.',
      );
      return;
    }
    final batt = int.tryParse(_batteryController.text.trim());
    if (batt == null || batt < 0 || batt > 100) {
      setState(
        () => _errorMessage = 'Please enter a valid battery level (0-100%).',
      );
      return;
    }
    if (_selectedVehicleId.trim().isEmpty) {
      setState(() => _errorMessage = 'Please select a valid vehicle.');
      return;
    }
    if (_officeDestination == null) {
      setState(
        () => _errorMessage =
            'Select today'
            's office destination',
      );
      return;
    }
    if (!_emergencyEquipmentConfirmed) {
      setState(
        () => _errorMessage =
            'Please confirm emergency equipment before starting duty.',
      );
      return;
    }

    final selectedVehicle =
        await (widget.getVehicle?.call(_selectedVehicleId) ??
            CabVehicleService.getVehicle(_selectedVehicleId));
    if (selectedVehicle == null) {
      if (mounted) {
        setState(
          () => _errorMessage = 'The selected cab is no longer available',
        );
      }
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final combinedNote = <String>[];
    if (_noteController.text.trim().isNotEmpty) {
      combinedNote.add(_noteController.text.trim());
    }
    if (_vehicleCondition != 'Good' &&
        _issueDescriptionController.text.trim().isNotEmpty) {
      combinedNote.add(
        '[Issue: ${_issueCategoryController.text.trim()}] ${_issueDescriptionController.text.trim()}',
      );
    }

    try {
      await widget.onConfirm(
        vehicleId: _selectedVehicleId,
        startOdometer: odo,
        batteryPercentage: batt,
        vehicleCondition: _vehicleCondition,
        officeDestination: _officeDestination!,
        note: combinedNote.isEmpty ? null : combinedNote.join(' | '),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Start Duty Checklist',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              'Confirm vehicle and pre-shift details before starting.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 16),
            const Text(
              'Selected Vehicle',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            if (_vehiclesLoading)
              const Row(
                children: [
                  SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Loading configured cabs...',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            else if (_vehiclesError != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _vehiclesError!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                  TextButton.icon(
                    onPressed: _loadVehicles,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              )
            else if (_availableVehicles.isEmpty)
              const InputDecorator(
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.electric_car),
                  border: OutlineInputBorder(),
                ),
                child: Text('No configured cab available'),
              )
            else
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedVehicleId.isEmpty
                    ? null
                    : _selectedVehicleId,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.electric_car),
                  border: OutlineInputBorder(),
                  hintText: 'Select a configured cab',
                ),
                selectedItemBuilder: (context) => _availableVehicles
                    .map(
                      (vehicle) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _vehicleSelectionLabel(vehicle),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                items: _availableVehicles
                    .map(
                      (vehicle) => DropdownMenuItem<String>(
                        value: vehicle.id,
                        child: Text(
                          _vehicleLabel(vehicle),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(
                        () => _selectedVehicleId = value?.trim() ?? '',
                      ),
              ),
            const SizedBox(height: 16),
            const Text(
              'OFFICE DESTINATION',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            InputDecorator(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.business_outlined),
                border: OutlineInputBorder(),
              ),
              child: _officeDestination == null
                  ? const Text(
                      'Select today'
                      's office destination',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _officeDestination!.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(_officeDestination!.address),
                      ],
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (widget.initialOfficeDestination != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(
                              () => _officeDestination =
                                  widget.initialOfficeDestination,
                            ),
                      child: const Text('Use Saved Office'),
                    ),
                  ),
                if (widget.initialOfficeDestination != null)
                  const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _isSubmitting
                        ? null
                        : () async {
                            final current = _officeDestination;
                            final selection =
                                await TransportLocationPicker.show(
                                  context,
                                  title: 'Office destination',
                                  initialSelection: current == null
                                      ? null
                                      : TransportLocationSelection(
                                          label: current.name,
                                          address: current.address,
                                          latitude: current.latitude,
                                          longitude: current.longitude,
                                        ),
                                );
                            if (selection == null || !mounted) return;
                            setState(
                              () => _officeDestination = OfficeDestination(
                                name: selection.label,
                                address: selection.address,
                                latitude: selection.latitude,
                                longitude: selection.longitude,
                              ),
                            );
                          },
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Choose on Map'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Starting Odometer (km)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _odometerController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.speed),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Battery / Fuel (%)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _batteryController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.battery_charging_full),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Vehicle Condition',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: ['Good', 'Minor Damage', 'Needs Maintenance'].map((
                cond,
              ) {
                final selected = _vehicleCondition == cond;
                return ChoiceChip(
                  label: Text(cond),
                  selected: selected,
                  onSelected: (val) {
                    if (val) setState(() => _vehicleCondition = cond);
                  },
                );
              }).toList(),
            ),
            if (_vehicleCondition != 'Good') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withAlpha(80)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Issue Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _issueCategoryController,
                      decoration: const InputDecoration(
                        labelText: 'Issue Category',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _issueDescriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Issue Description',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.headset_mic, size: 16),
                      label: const Text('Contact Operations'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Optional Driver Note',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'e.g. Cleaned vehicle before shift',
              ),
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Pre-Shift System Checks',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const _CheckItem(label: 'GPS Location Services Enabled', ok: true),
            const _CheckItem(label: 'Location Permission Granted', ok: true),
            const _CheckItem(
              label: 'Network / Sync Connection Online',
              ok: true,
            ),
            InkWell(
              onTap: () => setState(
                () => _emergencyEquipmentConfirmed =
                    !_emergencyEquipmentConfirmed,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _emergencyEquipmentConfirmed,
                        onChanged: (val) => setState(
                          () => _emergencyEquipmentConfirmed = val ?? true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Emergency equipment confirmed (First Aid, Spare/Kit)',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed:
                    _vehiclesLoading ||
                        _availableVehicles.isEmpty ||
                        _selectedVehicleId.isEmpty ||
                        _officeDestination == null ||
                        _isSubmitting
                    ? null
                    : _handleConfirm,
                icon: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: const Text(
                  'CONFIRM AND START DUTY',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _vehicleSelectionLabel(CabVehicleModel vehicle) {
    final vehicleNumber = vehicle.vehicleNumber.trim();
    if (vehicleNumber.isNotEmpty) return vehicleNumber;
    final registration = vehicle.registrationNumber.trim();
    return registration.isEmpty ? vehicle.id : registration;
  }

  String _vehicleLabel(CabVehicleModel vehicle) {
    final parts = <String>[
      vehicle.vehicleNumber.trim(),
      vehicle.registrationNumber.trim(),
    ].where((part) => part.isNotEmpty).toList(growable: false);
    final identity = parts.isEmpty ? vehicle.id : parts.join(' / ');
    final model = vehicle.vehicleModel.trim();
    return model.isEmpty ? identity : '$identity - $model';
  }
}

class _CheckItem extends StatelessWidget {
  final String label;
  final bool ok;
  const _CheckItem({required this.label, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.warning_amber_rounded,
            color: ok ? AppColors.success : AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
