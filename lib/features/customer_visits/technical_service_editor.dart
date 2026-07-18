import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'models/customer_visit_model.dart';
import 'technical_service_definitions.dart';

class TechnicalServiceEditorDialog extends StatefulWidget {
  final CustomerVisitModel visit;

  const TechnicalServiceEditorDialog({super.key, required this.visit});

  static Future<CustomerVisitModel?> show(
    BuildContext context,
    CustomerVisitModel visit,
  ) {
    return showDialog<CustomerVisitModel>(
      context: context,
      builder: (context) => TechnicalServiceEditorDialog(visit: visit),
    );
  }

  @override
  State<TechnicalServiceEditorDialog> createState() =>
      _TechnicalServiceEditorDialogState();
}

class _TechnicalServiceEditorDialogState
    extends State<TechnicalServiceEditorDialog> {
  late final Map<String, TextEditingController> _equipment;
  late final Map<String, TextEditingController> _diagnostics;
  late final TextEditingController _observedIssueController;
  late final TextEditingController _rootCauseController;
  late final TextEditingController _correctiveActionController;
  late final TextEditingController _preventiveActionController;
  late final TextEditingController _recommendationController;
  late final TextEditingController _partsController;
  late final Set<String> _selectedIssues;

  late String _warrantyStatus;
  late String _resolutionStatus;
  DateTime? _motorManufacturingDate;
  DateTime? _controllerManufacturingDate;
  DateTime? _lastServiceDate;
  String? _validationMessage;

  CustomerVisitModel get _visit => widget.visit;

  @override
  void initState() {
    super.initState();
    _equipment = <String, TextEditingController>{
      'vehicleNumber': TextEditingController(text: _visit.vehicleNumber),
      'vehicleType': TextEditingController(text: _visit.vehicleType),
      'vehicleCategory': TextEditingController(text: _visit.vehicleCategory),
      'fleetName': TextEditingController(text: _visit.fleetName),
      'dealerName': TextEditingController(text: _visit.dealerName),
      'motorModel': TextEditingController(text: _visit.motorModel),
      'motorSerialNumber': TextEditingController(
        text: _visit.motorSerialNumber,
      ),
      'motorWarrantyStatus': TextEditingController(
        text: _visit.motorWarrantyStatus,
      ),
      'controllerModel': TextEditingController(text: _visit.controllerModel),
      'controllerSerialNumber': TextEditingController(
        text: _visit.controllerSerialNumber,
      ),
      'controllerFirmware': TextEditingController(
        text: _visit.controllerFirmware,
      ),
      'batteryModel': TextEditingController(text: _visit.batteryModel),
      'batterySerialNumber': TextEditingController(
        text: _visit.batterySerialNumber,
      ),
      'batteryChemistry': TextEditingController(
        text: _visit.batteryChemistry,
      ),
      'batteryCapacity': TextEditingController(text: _visit.batteryCapacity),
      'batteryNominalVoltage': TextEditingController(
        text: _visit.batteryNominalVoltage,
      ),
      'batteryWarrantyStatus': TextEditingController(
        text: _visit.batteryWarrantyStatus,
      ),
      'chargerModel': TextEditingController(text: _visit.chargerModel),
      'vehicleOdometer': TextEditingController(
        text: _numberText(_visit.vehicleOdometer),
      ),
      'hoursRun': TextEditingController(text: _numberText(_visit.hoursRun)),
    };
    _diagnostics = <String, TextEditingController>{
      for (final field in technicalDiagnosticFields)
        field.key: TextEditingController(
          text: _visit.diagnosticReadings[field.key] ?? '',
        ),
    };
    _observedIssueController = TextEditingController(
      text: _visit.issueDescription,
    );
    _rootCauseController = TextEditingController(text: _visit.actualRootCause);
    _correctiveActionController = TextEditingController(
      text: _visit.correctiveAction,
    );
    _preventiveActionController = TextEditingController(
      text: _visit.preventiveAction,
    );
    _recommendationController = TextEditingController(
      text: _visit.engineerRecommendation,
    );
    _partsController = TextEditingController(
      text: _visit.partsUsed.join(', '),
    );
    _selectedIssues = <String>{
      ..._visit.issueCategories,
      if (_visit.issueCategories.isEmpty && _visit.issueCategory.isNotEmpty)
        _visit.issueCategory,
    };
    _warrantyStatus = _visit.warrantyStatus.isEmpty
        ? 'Unknown'
        : _visit.warrantyStatus;
    _resolutionStatus = technicalResolutionStatuses.contains(
      _visit.resolutionStatus,
    )
        ? _visit.resolutionStatus
        : 'pending';
    _motorManufacturingDate = _visit.motorManufacturingDate;
    _controllerManufacturingDate = _visit.controllerManufacturingDate;
    _lastServiceDate = _visit.lastServiceDate;
  }

  @override
  void dispose() {
    for (final controller in _equipment.values) {
      controller.dispose();
    }
    for (final controller in _diagnostics.values) {
      controller.dispose();
    }
    _observedIssueController.dispose();
    _rootCauseController.dispose();
    _correctiveActionController.dispose();
    _preventiveActionController.dispose();
    _recommendationController.dispose();
    _partsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
        title: Row(
          children: [
            const Icon(Icons.precision_manufacturing_outlined, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Technical Service Record',
                style: AppTextStyles.headingSmall,
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780, maxHeight: 650),
          child: SizedBox(
            width: 780,
            height: MediaQuery.sizeOf(context).height * 0.66,
            child: Column(
              children: [
                const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(icon: Icon(Icons.directions_car_outlined), text: 'Equipment'),
                    Tab(icon: Icon(Icons.monitor_heart_outlined), text: 'Diagnostics'),
                    Tab(icon: Icon(Icons.troubleshoot_outlined), text: 'Root Cause'),
                    Tab(icon: Icon(Icons.verified_outlined), text: 'Resolution'),
                  ],
                ),
                if (_validationMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _validationMessage!,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildEquipmentTab(),
                      _buildDiagnosticsTab(),
                      _buildRootCauseTab(),
                      _buildResolutionTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save Technical Record'),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 4, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EditorSection(
            title: 'Vehicle and Ownership',
            icon: Icons.local_shipping_outlined,
            child: _EditorGrid(
              children: [
                _ReadOnlyField(label: 'Customer', value: _visit.customerName),
                _EditorField(
                  controller: _equipment['dealerName']!,
                  label: 'Dealer',
                ),
                _EditorField(
                  controller: _equipment['vehicleNumber']!,
                  label: 'Vehicle Number',
                ),
                _EditorField(
                  controller: _equipment['vehicleType']!,
                  label: 'Vehicle Type',
                ),
                _EditorField(
                  controller: _equipment['vehicleCategory']!,
                  label: 'Vehicle Category',
                ),
                _EditorField(
                  controller: _equipment['fleetName']!,
                  label: 'Fleet',
                ),
                _EditorField(
                  controller: _equipment['vehicleOdometer']!,
                  label: 'Vehicle Odometer',
                  keyboardType: TextInputType.number,
                ),
                _EditorField(
                  controller: _equipment['hoursRun']!,
                  label: 'Hours Run',
                  keyboardType: TextInputType.number,
                ),
                _DateField(
                  label: 'Last Service Date',
                  value: _lastServiceDate,
                  onChanged: (date) => setState(() => _lastServiceDate = date),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _warrantyStatus,
                  decoration: const InputDecoration(labelText: 'Warranty Status'),
                  items: <String>{
                    'Under Warranty',
                    'Out of Warranty',
                    'Unknown',
                    _warrantyStatus,
                  }
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setState(() => _warrantyStatus = value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _EditorSection(
            title: 'Motor',
            icon: Icons.settings_input_component_outlined,
            child: _EditorGrid(
              children: [
                _EditorField(
                  controller: _equipment['motorModel']!,
                  label: 'Motor Model',
                ),
                _EditorField(
                  controller: _equipment['motorSerialNumber']!,
                  label: 'Motor Serial Number',
                ),
                _DateField(
                  label: 'Motor Manufacturing Date',
                  value: _motorManufacturingDate,
                  onChanged: (date) =>
                      setState(() => _motorManufacturingDate = date),
                ),
                _EditorField(
                  controller: _equipment['motorWarrantyStatus']!,
                  label: 'Motor Warranty',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _EditorSection(
            title: 'Controller',
            icon: Icons.memory_outlined,
            child: _EditorGrid(
              children: [
                _EditorField(
                  controller: _equipment['controllerModel']!,
                  label: 'Controller Model',
                ),
                _EditorField(
                  controller: _equipment['controllerSerialNumber']!,
                  label: 'Controller Serial Number',
                ),
                _EditorField(
                  controller: _equipment['controllerFirmware']!,
                  label: 'Controller Firmware',
                ),
                _DateField(
                  label: 'Controller Manufacturing Date',
                  value: _controllerManufacturingDate,
                  onChanged: (date) =>
                      setState(() => _controllerManufacturingDate = date),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _EditorSection(
            title: 'Battery and Charger',
            icon: Icons.battery_charging_full_outlined,
            child: _EditorGrid(
              children: [
                _EditorField(
                  controller: _equipment['batteryModel']!,
                  label: 'Battery Model',
                ),
                _EditorField(
                  controller: _equipment['batterySerialNumber']!,
                  label: 'Battery Serial Number',
                ),
                _EditorField(
                  controller: _equipment['batteryChemistry']!,
                  label: 'Battery Chemistry',
                ),
                _EditorField(
                  controller: _equipment['batteryCapacity']!,
                  label: 'Battery Capacity',
                ),
                _EditorField(
                  controller: _equipment['batteryNominalVoltage']!,
                  label: 'Battery Voltage',
                ),
                _EditorField(
                  controller: _equipment['batteryWarrantyStatus']!,
                  label: 'Battery Warranty',
                ),
                _EditorField(
                  controller: _equipment['chargerModel']!,
                  label: 'Charger Model',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsTab() {
    final categories = <String>{
      ...technicalIssueCategories,
      ..._selectedIssues,
    }.toList(growable: false);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 4, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EditorSection(
            title: 'Issue Classification',
            icon: Icons.category_outlined,
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: categories.map((category) {
                final selected = _selectedIssues.contains(category);
                return FilterChip(
                  label: Text(category),
                  selected: selected,
                  onSelected: (enabled) {
                    setState(() {
                      if (enabled) {
                        _selectedIssues.add(category);
                      } else {
                        _selectedIssues.remove(category);
                      }
                    });
                  },
                );
              }).toList(growable: false),
            ),
          ),
          const SizedBox(height: 10),
          _EditorSection(
            title: 'Measured Readings',
            icon: Icons.monitor_heart_outlined,
            child: _EditorGrid(
              children: technicalDiagnosticFields
                  .map(
                    (field) => _EditorField(
                      controller: _diagnostics[field.key]!,
                      label: field.unit == null
                          ? field.label
                          : '${field.label} (${field.unit})',
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRootCauseTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 4, bottom: 12),
      child: _EditorSection(
        title: 'Failure Analysis and Action',
        icon: Icons.manage_search_outlined,
        child: Column(
          children: [
            _EditorField(
              controller: _observedIssueController,
              label: 'Observed Issue',
              maxLines: 3,
            ),
            const SizedBox(height: 9),
            _EditorField(
              controller: _rootCauseController,
              label: 'Actual Root Cause',
              maxLines: 3,
            ),
            const SizedBox(height: 9),
            _EditorField(
              controller: _correctiveActionController,
              label: 'Corrective Action',
              maxLines: 3,
            ),
            const SizedBox(height: 9),
            _EditorField(
              controller: _preventiveActionController,
              label: 'Preventive Action',
              maxLines: 3,
            ),
            const SizedBox(height: 9),
            _EditorField(
              controller: _recommendationController,
              label: 'Engineer Recommendation',
              maxLines: 3,
            ),
            const SizedBox(height: 9),
            _EditorField(
              controller: _partsController,
              label: 'Parts Replaced (comma separated)',
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResolutionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 4, bottom: 12),
      child: _EditorSection(
        title: 'Technical Resolution',
        icon: Icons.verified_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: technicalResolutionStatuses.contains(
                _resolutionStatus,
              )
                  ? _resolutionStatus
                  : 'pending',
              decoration: const InputDecoration(labelText: 'Resolution Status'),
              items: technicalResolutionStatuses
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(technicalValueLabel(status)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) setState(() => _resolutionStatus = value);
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Visit lifecycle status remains separate from technical resolution. Checkout and completion continue through the existing visit actions.',
              style: AppTextStyles.caption.copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    try {
      final odometer = _optionalDouble(
        _equipment['vehicleOdometer']!.text,
        'Vehicle odometer',
      );
      final hoursRun = _optionalDouble(
        _equipment['hoursRun']!.text,
        'Hours run',
      );
      final issues = _selectedIssues.toList(growable: false);
      final diagnostics = Map<String, String>.of(_visit.diagnosticReadings);
      for (final entry in _diagnostics.entries) {
        final value = entry.value.text.trim();
        if (value.isEmpty) {
          diagnostics.remove(entry.key);
        } else {
          diagnostics[entry.key] = value;
        }
      }
      final updated = _visit.copyWith(
        vehicleNumber: _equipment['vehicleNumber']!.text.trim(),
        vehicleType: _equipment['vehicleType']!.text.trim(),
        vehicleCategory: _equipment['vehicleCategory']!.text.trim(),
        fleetName: _equipment['fleetName']!.text.trim(),
        dealerName: _equipment['dealerName']!.text.trim(),
        motorModel: _equipment['motorModel']!.text.trim(),
        motorSerialNumber: _equipment['motorSerialNumber']!.text.trim(),
        motorManufacturingDate: _motorManufacturingDate,
        motorWarrantyStatus:
            _equipment['motorWarrantyStatus']!.text.trim(),
        controllerModel: _equipment['controllerModel']!.text.trim(),
        controllerSerialNumber:
            _equipment['controllerSerialNumber']!.text.trim(),
        controllerFirmware:
            _equipment['controllerFirmware']!.text.trim(),
        controllerManufacturingDate: _controllerManufacturingDate,
        batteryModel: _equipment['batteryModel']!.text.trim(),
        batterySerialNumber:
            _equipment['batterySerialNumber']!.text.trim(),
        batteryChemistry: _equipment['batteryChemistry']!.text.trim(),
        batteryCapacity: _equipment['batteryCapacity']!.text.trim(),
        batteryNominalVoltage:
            _equipment['batteryNominalVoltage']!.text.trim(),
        batteryWarrantyStatus:
            _equipment['batteryWarrantyStatus']!.text.trim(),
        chargerModel: _equipment['chargerModel']!.text.trim(),
        vehicleOdometer: odometer,
        hoursRun: hoursRun,
        lastServiceDate: _lastServiceDate,
        warrantyStatus: _warrantyStatus,
        issueCategories: issues,
        issueCategory: issues.isEmpty ? _visit.issueCategory : issues.first,
        issueDescription: _observedIssueController.text.trim(),
        diagnosticReadings: diagnostics,
        actualRootCause: _rootCauseController.text.trim(),
        correctiveAction: _correctiveActionController.text.trim(),
        preventiveAction: _preventiveActionController.text.trim(),
        engineerRecommendation: _recommendationController.text.trim(),
        resolutionStatus: _resolutionStatus,
        partsUsed: _splitValues(_partsController.text),
      );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } on FormatException catch (error) {
      setState(() {
        _validationMessage = error.message.toString();
      });
    }
  }
}

class TechnicalChecklistEditorDialog extends StatefulWidget {
  final List<TechnicalChecklistItem> items;

  const TechnicalChecklistEditorDialog({super.key, required this.items});

  static Future<List<TechnicalChecklistItem>?> show(
    BuildContext context,
    List<TechnicalChecklistItem> items,
  ) {
    return showDialog<List<TechnicalChecklistItem>>(
      context: context,
      builder: (context) => TechnicalChecklistEditorDialog(items: items),
    );
  }

  @override
  State<TechnicalChecklistEditorDialog> createState() =>
      _TechnicalChecklistEditorDialogState();
}

class _TechnicalChecklistEditorDialogState
    extends State<TechnicalChecklistEditorDialog> {
  late final List<TechnicalChecklistItem> _items;
  late final Map<String, TextEditingController> _comments;
  late final Map<String, TextEditingController> _photos;

  @override
  void initState() {
    super.initState();
    final existingById = <String, TechnicalChecklistItem>{
      for (final item in widget.items) item.id: item,
    };
    _items = <TechnicalChecklistItem>[
      for (final definition in technicalChecklistDefinitions.entries)
        existingById.remove(definition.key) ??
            TechnicalChecklistItem(
              id: definition.key,
              label: definition.value,
            ),
      ...existingById.values,
    ];
    _comments = <String, TextEditingController>{
      for (final item in _items)
        item.id: TextEditingController(text: item.comments),
    };
    _photos = <String, TextEditingController>{
      for (final item in _items)
        item.id: TextEditingController(text: item.photoReference),
    };
  }

  @override
  void dispose() {
    for (final controller in _comments.values) {
      controller.dispose();
    }
    for (final controller in _photos.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('Technical Checklist', style: AppTextStyles.headingSmall),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 620),
        child: SizedBox(
          width: 700,
          height: MediaQuery.sizeOf(context).height * 0.66,
          child: ListView.separated(
            itemCount: _items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = _items[index];
              return _ChecklistEditorRow(
                item: item,
                commentsController: _comments[item.id]!,
                photoController: _photos[item.id]!,
                onStatusChanged: (status) {
                  setState(() {
                    _items[index] = item.copyWith(status: status);
                  });
                },
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            final now = DateTime.now();
            final result = _items
                .map(
                  (item) => item.copyWith(
                    comments: _comments[item.id]!.text.trim(),
                    photoReference: _photos[item.id]!.text.trim(),
                    updatedAt: now,
                  ),
                )
                .toList(growable: false);
            Navigator.pop(context, result);
          },
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text('Save Checklist'),
        ),
      ],
    );
  }
}

class _ChecklistEditorRow extends StatelessWidget {
  final TechnicalChecklistItem item;
  final TextEditingController commentsController;
  final TextEditingController photoController;
  final ValueChanged<String> onStatusChanged;

  const _ChecklistEditorRow({
    required this.item,
    required this.commentsController,
    required this.photoController,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final status = technicalChecklistStatuses.contains(item.status)
        ? item.status
        : 'pending';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Text(
                item.label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              );
              final selector = SizedBox(
                width: 170,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('${item.id}:$status'),
                  initialValue: status,
                  isDense: true,
                  decoration: const InputDecoration(labelText: 'Result'),
                  items: technicalChecklistStatuses
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(technicalValueLabel(value)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) onStatusChanged(value);
                  },
                ),
              );
              if (constraints.maxWidth < 420) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [title, const SizedBox(height: 7), selector],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 8),
                  selector,
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          _EditorGrid(
            children: [
              _EditorField(
                controller: commentsController,
                label: 'Comments',
                maxLines: 2,
              ),
              _EditorField(
                controller: photoController,
                label: 'Photo URL or file reference',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditorSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _EditorSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _EditorGrid extends StatelessWidget {
  final List<Widget> children;

  const _EditorGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 2 : 1;
        const gap = 9.0;
        final width =
            (constraints.maxWidth - ((columns - 1) * gap)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(growable: false),
        );
      },
    );
  }
}

class _EditorField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;

  const _EditorField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, isDense: true),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, enabled: false, isDense: true),
      child: Text(
        value.trim().isEmpty ? 'Not recorded' : value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, isDense: true),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value == null ? 'Not recorded' : _dateText(value!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Select date',
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              final selected = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now(),
                firstDate: DateTime(1990),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (selected != null) onChanged(selected);
            },
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
          ),
        ],
      ),
    );
  }
}

double? _optionalDouble(String value, String label) {
  final normalized = value.trim();
  if (normalized.isEmpty) return null;
  final parsed = double.tryParse(normalized);
  if (parsed == null || parsed < 0) {
    throw FormatException('$label must be a valid non-negative number.');
  }
  return parsed;
}

String _numberText(double? value) {
  if (value == null) return '';
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}

List<String> _splitValues(String value) {
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String _dateText(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
