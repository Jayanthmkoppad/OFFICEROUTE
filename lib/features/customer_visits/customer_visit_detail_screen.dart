import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/employee_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/premium_widgets.dart';
import '../map/map_screen.dart';
import 'controllers/customer_visit_controller.dart';
import 'models/customer_visit_model.dart';
import 'services/customer_visit_service.dart';
import 'technical_service_definitions.dart';
import 'technical_service_editor.dart';

class CustomerVisitDetailScreen extends StatefulWidget {
  final CustomerVisitModel visit;
  final List<CustomerVisitModel> operationVisits;
  final List<EmployeeModel> employees;

  const CustomerVisitDetailScreen({
    super.key,
    required this.visit,
    this.operationVisits = const <CustomerVisitModel>[],
    this.employees = const <EmployeeModel>[],
  });

  @override
  State<CustomerVisitDetailScreen> createState() =>
      _CustomerVisitDetailScreenState();
}

class _CustomerVisitDetailScreenState extends State<CustomerVisitDetailScreen> {
  late CustomerVisitModel _visit;
  late Future<List<CustomerVisitModel>> _historyFuture;
  Timer? _timer;
  bool _isRunningAction = false;

  @override
  void initState() {
    super.initState();
    _visit = widget.visit;
    _historyFuture = widget.operationVisits.isNotEmpty
        ? Future<List<CustomerVisitModel>>.value(widget.operationVisits)
        : CustomerVisitService.fetchCustomerHistory(
            userId: widget.visit.userId,
            customerName: widget.visit.customerName,
          );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isTimerActive) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _isTimerActive =>
      _visit.checkInTime != null &&
      _visit.checkOutTime == null &&
      _visit.status != 'completed' &&
      _visit.status != 'cancelled';

  Future<void> _runVisitAction(
    Future<CustomerVisitModel> Function() action,
  ) async {
    if (_isRunningAction) return;

    setState(() {
      _isRunningAction = true;
    });

    try {
      final updatedVisit = await action();
      if (!mounted) return;
      setState(() {
        _visit = updatedVisit;
        _historyFuture = _historyFuture.then((visits) {
          final updatedVisits = visits.toList();
          final index = updatedVisits.indexWhere(
            (visit) => visit.id == updatedVisit.id,
          );
          if (index == -1) {
            updatedVisits.add(updatedVisit);
          } else {
            updatedVisits[index] = updatedVisit;
          }
          return updatedVisits;
        });
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Visit update could not be saved. Check the connection and retry.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRunningAction = false;
        });
      }
    }
  }

  Future<void> _showPhotoDialog() async {
    final controller = TextEditingController();
    var eventType = 'general';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text('Photo Evidence', style: AppTextStyles.headingSmall),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PremiumTextField(
                    controller: controller,
                    label: 'Photo URL or file reference',
                    icon: Icons.photo_outlined,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: eventType,
                    decoration: const InputDecoration(
                      labelText: 'Timeline event',
                    ),
                    items: _mediaTimelineEventTypes
                        .map(
                          (event) => DropdownMenuItem(
                            value: event,
                            child: Text(technicalValueLabel(event)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => eventType = value);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final value = controller.text.trim();
                  if (value.isEmpty) return;
                  final eventLinks = _visit.photoTimelineEvents
                      .take(_visit.photoUrls.length)
                      .toList();
                  while (eventLinks.length < _visit.photoUrls.length) {
                    eventLinks.add('general');
                  }
                  Navigator.pop(context);
                  await _runVisitAction(
                    () => CustomerVisitController.updateVisit(
                      _visit.copyWith(
                        photoUrls: <String>[..._visit.photoUrls, value],
                        photoTimelineEvents: <String>[
                          ...eventLinks,
                          eventType,
                        ],
                      ),
                    ),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();
  }

  Future<void> _showTechnicalServiceEditor() async {
    final updated = await TechnicalServiceEditorDialog.show(context, _visit);
    if (updated == null || !mounted) return;
    await _runVisitAction(() => CustomerVisitController.updateVisit(updated));
  }

  Future<void> _showChecklistEditor() async {
    final checklist = await TechnicalChecklistEditorDialog.show(
      context,
      _visit.serviceChecklist,
    );
    if (checklist == null || !mounted) return;
    await _runVisitAction(
      () => CustomerVisitController.updateVisit(
        _visit.copyWith(serviceChecklist: checklist),
      ),
    );
  }

  Future<void> _showTimelineEventDialog() async {
    var eventType = technicalTimelineEventTypes.first;
    final notesController = TextEditingController();
    final shouldRecord =
        await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text(
                'Record GPS Timeline Event',
                style: AppTextStyles.headingSmall,
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: eventType,
                      decoration: const InputDecoration(labelText: 'Event'),
                      items: technicalTimelineEventTypes
                          .map(
                            (event) => DropdownMenuItem(
                              value: event,
                              child: Text(technicalValueLabel(event)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => eventType = value);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    PremiumTextField(
                      controller: notesController,
                      label: 'Notes (optional)',
                      icon: Icons.notes_outlined,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text('Capture GPS Event'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (shouldRecord && mounted) {
      await _runVisitAction(
        () => CustomerVisitController.addTechnicalTimelineEvent(
          visit: _visit,
          eventType: eventType,
          notes: notesController.text.trim(),
        ),
      );
    }
    notesController.dispose();
  }

  Future<void> _showAttachmentDialog() async {
    final referenceController = TextEditingController();
    final notesController = TextEditingController();
    var attachmentType = technicalAttachmentTypes.first;
    var eventType = 'general';
    final shouldSave =
        await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text(
                'Add Technical Attachment',
                style: AppTextStyles.headingSmall,
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: attachmentType,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: technicalAttachmentTypes
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(technicalValueLabel(type)),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => attachmentType = value);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      PremiumTextField(
                        controller: referenceController,
                        label: 'URL or file reference',
                        icon: Icons.attach_file,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: eventType,
                        decoration: const InputDecoration(
                          labelText: 'Timeline event',
                        ),
                        items: _mediaTimelineEventTypes
                            .map(
                              (event) => DropdownMenuItem(
                                value: event,
                                child: Text(technicalValueLabel(event)),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => eventType = value);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      PremiumTextField(
                        controller: notesController,
                        label: 'Notes',
                        icon: Icons.notes_outlined,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (referenceController.text.trim().isEmpty) return;
                    Navigator.pop(context, true);
                  },
                  child: const Text('Save Attachment'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (shouldSave && mounted) {
      final attachment = TechnicalAttachment(
        type: attachmentType,
        reference: referenceController.text.trim(),
        eventType: eventType,
        createdAt: DateTime.now(),
        notes: notesController.text.trim(),
      );
      await _runVisitAction(
        () => CustomerVisitController.updateVisit(
          _visit.copyWith(
            technicalAttachments: <TechnicalAttachment>[
              ..._visit.technicalAttachments,
              attachment,
            ],
            videoPlaceholderStatus: attachmentType == 'video'
                ? 'ready'
                : _visit.videoPlaceholderStatus,
          ),
        ),
      );
    }
    referenceController.dispose();
    notesController.dispose();
  }

  void _openMapFoundation() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MapScreen()));
  }

  Future<void> _showEditDetailsDialog() async {
    final customerNameController = TextEditingController(
      text: _visit.customerName,
    );
    final customerAddressController = TextEditingController(
      text: _visit.customerAddress,
    );
    final customerPhoneController = TextEditingController(
      text: _visit.customerPhone,
    );
    final purposeController = TextEditingController(text: _visit.purpose);
    final vehicleController = TextEditingController(
      text: _visit.vehicleDetails,
    );
    final motorSerialController = TextEditingController(
      text: _visit.motorSerialNumber,
    );
    final controllerSerialController = TextEditingController(
      text: _visit.controllerSerialNumber,
    );
    final issueDescriptionController = TextEditingController(
      text: _visit.issueDescription,
    );
    final partsController = TextEditingController(
      text: _visit.partsUsed.join(', '),
    );
    final technicianNotesController = TextEditingController(
      text: _visit.technicianNotes,
    );
    final notesController = TextEditingController(text: _visit.notes);
    var warranty = _visit.warrantyStatus.isEmpty
        ? 'Unknown'
        : _visit.warrantyStatus;
    var issueCategory = _visit.issueCategory.isEmpty
        ? 'Other'
        : _visit.issueCategory;
    String? validationMessage;
    final warrantyOptions = <String>{
      'Under Warranty',
      'Out of Warranty',
      'Unknown',
      warranty,
    }.toList(growable: false);
    final issueOptions = <String>{
      'Inspection',
      'Motor',
      'Controller',
      'Battery',
      'Wiring',
      'Software',
      'Other',
      ...technicalIssueCategories,
      issueCategory,
    }.toList(growable: false);

    final save =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  backgroundColor: AppColors.surface,
                  title: Text(
                    'Edit Visit Details',
                    style: AppTextStyles.headingSmall,
                  ),
                  content: SizedBox(
                    width: 580,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PremiumTextField(
                            controller: customerNameController,
                            label: 'Customer name',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 10),
                          PremiumTextField(
                            controller: customerAddressController,
                            label: 'Customer address',
                            icon: Icons.location_on_outlined,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 10),
                          PremiumTextField(
                            controller: customerPhoneController,
                            label: 'Customer phone',
                            icon: Icons.call_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 10),
                          PremiumTextField(
                            controller: purposeController,
                            label: 'Purpose',
                            icon: Icons.flag_outlined,
                          ),
                          const SizedBox(height: 10),
                          PremiumTextField(
                            controller: vehicleController,
                            label: 'Vehicle details',
                            icon: Icons.local_shipping_outlined,
                          ),
                          const SizedBox(height: 10),
                          PremiumTextField(
                            controller: motorSerialController,
                            label: 'Motor serial',
                            icon: Icons.settings_input_component_outlined,
                          ),
                          const SizedBox(height: 10),
                          PremiumTextField(
                            controller: controllerSerialController,
                            label: 'Controller serial',
                            icon: Icons.memory_outlined,
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: warranty,
                            items: warrantyOptions
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value == null) return;
                              setDialogState(() {
                                warranty = value;
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'Warranty',
                              prefixIcon: Icon(Icons.verified_user_outlined),
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: issueCategory,
                            items: issueOptions
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value == null) return;
                              setDialogState(() {
                                issueCategory = value;
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'Issue category',
                              prefixIcon: Icon(Icons.report_problem_outlined),
                            ),
                          ),
                          const SizedBox(height: 10),
                          PremiumTextField(
                            controller: issueDescriptionController,
                            label: 'Issue description',
                            icon: Icons.troubleshoot_outlined,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 10),
                          PremiumTextField(
                            controller: partsController,
                            label: 'Parts used',
                            icon: Icons.build_outlined,
                          ),
                          const SizedBox(height: 10),
                          PremiumTextField(
                            controller: technicianNotesController,
                            label: 'Technician notes',
                            icon: Icons.note_alt_outlined,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 10),
                          PremiumTextField(
                            controller: notesController,
                            label: 'Internal notes',
                            icon: Icons.notes_outlined,
                            maxLines: 2,
                          ),
                          if (validationMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              validationMessage!,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (customerNameController.text.trim().isEmpty ||
                            customerAddressController.text.trim().isEmpty ||
                            purposeController.text.trim().isEmpty) {
                          setDialogState(() {
                            validationMessage =
                                'Customer name, address, and purpose are required.';
                          });
                          return;
                        }
                        Navigator.pop(context, true);
                      },
                      child: const Text('Save Changes'),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;

    final updatedVisit = _visit.copyWith(
      customerName: customerNameController.text.trim(),
      customerAddress: customerAddressController.text.trim(),
      customerPhone: customerPhoneController.text.trim(),
      purpose: purposeController.text.trim(),
      vehicleDetails: vehicleController.text.trim(),
      motorSerialNumber: motorSerialController.text.trim(),
      controllerSerialNumber: controllerSerialController.text.trim(),
      warrantyStatus: warranty,
      issueCategory: issueCategory,
      issueCategories: <String>[
        issueCategory,
        ..._visit.issueCategories.where((issue) => issue != issueCategory),
      ],
      issueDescription: issueDescriptionController.text.trim(),
      partsUsed: _splitList(partsController.text),
      technicianNotes: technicianNotesController.text.trim(),
      notes: notesController.text.trim(),
    );

    customerNameController.dispose();
    customerAddressController.dispose();
    customerPhoneController.dispose();
    purposeController.dispose();
    vehicleController.dispose();
    motorSerialController.dispose();
    controllerSerialController.dispose();
    issueDescriptionController.dispose();
    partsController.dispose();
    technicianNotesController.dispose();
    notesController.dispose();

    if (!save || !mounted) return;
    await _runVisitAction(
      () => CustomerVisitController.updateVisit(updatedVisit),
    );
  }

  Future<void> _showCompletionDialog() async {
    final notesController = TextEditingController(text: _visit.technicianNotes);
    final partsController = TextEditingController(
      text: _visit.partsUsed.join(', '),
    );
    bool videoReady = _visit.videoPlaceholderStatus == 'ready';
    bool signatureReady = _visit.signaturePlaceholderStatus == 'ready';
    var resolutionStatus = technicalResolutionStatuses.contains(
      _visit.resolutionStatus,
    )
        ? _visit.resolutionStatus
        : 'pending';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text('Complete Visit', style: AppTextStyles.headingSmall),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PremiumTextField(
                      controller: notesController,
                      label: 'Technician notes',
                      icon: Icons.note_alt_outlined,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    PremiumTextField(
                      controller: partsController,
                      label: 'Parts used',
                      icon: Icons.build_outlined,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: resolutionStatus,
                      decoration: const InputDecoration(
                        labelText: 'Technical resolution',
                      ),
                      items: technicalResolutionStatuses
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(technicalValueLabel(status)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => resolutionStatus = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: videoReady,
                      onChanged: (value) {
                        setDialogState(() {
                          videoReady = value ?? false;
                        });
                      },
                      title: const Text('Video placeholder ready'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      value: signatureReady,
                      onChanged: (value) {
                        setDialogState(() {
                          signatureReady = value ?? false;
                        });
                      },
                      title: const Text('Signature placeholder ready'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _runVisitAction(
                      () => CustomerVisitController.completeVisit(
                        visit: _visit,
                        technicianNotes: notesController.text.trim(),
                        partsUsed: _splitList(partsController.text),
                        signatureStatus: signatureReady ? 'ready' : 'pending',
                        videoStatus: videoReady ? 'ready' : 'pending',
                        resolutionStatus: resolutionStatus,
                      ),
                    );
                  },
                  child: const Text('Complete'),
                ),
              ],
            );
          },
        );
      },
    );

    notesController.dispose();
    partsController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canCheckIn = _visit.checkInTime == null;
    final canCheckOut =
        _visit.checkInTime != null && _visit.checkOutTime == null;
    final canComplete =
        _visit.checkOutTime != null && _visit.status != 'completed';
    final status = _visitStatus(_visit.status);
    final employeesById = <String, EmployeeModel>{
      for (final employee in widget.employees) employee.uid: employee,
    };

    return PopScope<CustomerVisitModel>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_visit);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: Text(
            _visit.customerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.headingSmall,
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 860;
            final mainColumn = Column(
              children: [
                _VisitHeroCard(
                  visit: _visit,
                  statusLabel: status.label,
                  statusColor: status.color,
                  timerLabel: _formatDuration(
                    _visit.visitDuration(DateTime.now()),
                  ),
                ),
                const SizedBox(height: 16),
                _ActionPanel(
                  isBusy: _isRunningAction,
                  canCheckIn: canCheckIn,
                  canCheckOut: canCheckOut,
                  canComplete: canComplete,
                  onCheckIn: () => _runVisitAction(
                    () => CustomerVisitController.checkIn(_visit),
                  ),
                  onCheckOut: () => _runVisitAction(
                    () => CustomerVisitController.checkOut(_visit),
                  ),
                  onComplete: _showCompletionDialog,
                  onAddPhoto: _showPhotoDialog,
                  onEdit: _showEditDetailsDialog,
                  onTechnicalRecord: _showTechnicalServiceEditor,
                ),
                const SizedBox(height: 10),
                _VisitTimelineCard(
                  visit: _visit,
                  onRecordEvent: _showTimelineEventDialog,
                ),
                const SizedBox(height: 10),
                _ServiceDetailsCard(
                  visit: _visit,
                  onEdit: _showTechnicalServiceEditor,
                ),
              ],
            );

            final secondaryColumn = Column(
              children: [
                if (_hasDispatchPackage(_visit)) ...[
                  _DispatchVisitPackageCard(
                    visit: _visit,
                    engineer: employeesById[_visit.userId],
                    onOpenMap: _openMapFoundation,
                  ),
                  const SizedBox(height: 10),
                ],
                _GpsCard(visit: _visit),
                const SizedBox(height: 10),
                _MediaCard(
                  visit: _visit,
                  onAddAttachment: _showAttachmentDialog,
                ),
                const SizedBox(height: 10),
                _ServiceChecklistCard(
                  visit: _visit,
                  onEdit: _showChecklistEditor,
                ),
                const SizedBox(height: 10),
                _SerialHistoryCard(
                  currentVisit: _visit,
                  visitsFuture: _historyFuture,
                  employeesById: employeesById,
                ),
                const SizedBox(height: 10),
                _HistoryCard(
                  currentVisit: _visit,
                  historyFuture: _historyFuture,
                ),
              ],
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: mainColumn),
                            const SizedBox(width: 10),
                            Expanded(flex: 5, child: secondaryColumn),
                          ],
                        )
                      : Column(
                          children: [
                            mainColumn,
                            const SizedBox(height: 10),
                            secondaryColumn,
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _VisitHeroCard extends StatelessWidget {
  final CustomerVisitModel visit;
  final String statusLabel;
  final Color statusColor;
  final String timerLabel;

  const _VisitHeroCard({
    required this.visit,
    required this.statusLabel,
    required this.statusColor,
    required this.timerLabel,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  visit.customerName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headingMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              PremiumStatusChip(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            visit.customerAddress,
            style: AppTextStyles.caption.copyWith(height: 1.4),
          ),
          if (visit.customerPhone.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(visit.customerPhone, style: AppTextStyles.caption),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  icon: Icons.timer_outlined,
                  label: 'Visit timer',
                  value: timerLabel,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InfoTile(
                  icon: Icons.handyman_outlined,
                  label: 'Issue',
                  value: visit.issueCategory.isEmpty
                      ? 'Unassigned'
                      : visit.issueCategory,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  final bool isBusy;
  final bool canCheckIn;
  final bool canCheckOut;
  final bool canComplete;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final VoidCallback onComplete;
  final VoidCallback onAddPhoto;
  final VoidCallback onEdit;
  final VoidCallback onTechnicalRecord;

  const _ActionPanel({
    required this.isBusy,
    required this.canCheckIn,
    required this.canCheckOut,
    required this.canComplete,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onComplete,
    required this.onAddPhoto,
    required this.onEdit,
    required this.onTechnicalRecord,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            icon: Icons.play_circle_outline,
            title: 'Visit Actions',
          ),
          const SizedBox(height: 10),
          if (isBusy) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActionButton(
                icon: Icons.login,
                label: 'Check In',
                enabled: canCheckIn && !isBusy,
                onTap: onCheckIn,
              ),
              _ActionButton(
                icon: Icons.logout,
                label: 'Check Out',
                enabled: canCheckOut && !isBusy,
                onTap: onCheckOut,
              ),
              _ActionButton(
                icon: Icons.photo_camera_outlined,
                label: 'Photo',
                enabled: !isBusy,
                onTap: onAddPhoto,
              ),
              _ActionButton(
                icon: Icons.edit_outlined,
                label: 'Edit Details',
                enabled: !isBusy,
                onTap: onEdit,
              ),
              _ActionButton(
                icon: Icons.precision_manufacturing_outlined,
                label: 'Technical Record',
                enabled: !isBusy,
                onTap: onTechnicalRecord,
              ),
              _ActionButton(
                icon: Icons.verified_outlined,
                label: 'Complete',
                enabled: canComplete && !isBusy,
                onTap: onComplete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VisitTimelineCard extends StatelessWidget {
  final CustomerVisitModel visit;
  final VoidCallback onRecordEvent;

  const _VisitTimelineCard({
    required this.visit,
    required this.onRecordEvent,
  });

  @override
  Widget build(BuildContext context) {
    final records = <_RecordedTimelinePoint>[
      _RecordedTimelinePoint(
        eventType: 'assignment',
        label: 'Assignment',
        time: visit.createdAt,
        notes: visit.userId.isEmpty ? 'Engineer not assigned' : 'Owner recorded',
      ),
      for (final event in visit.technicalTimeline)
        _RecordedTimelinePoint(
          eventType: event.eventType,
          label: technicalValueLabel(event.eventType),
          time: event.occurredAt,
          latitude: event.latitude,
          longitude: event.longitude,
          notes: event.notes,
        ),
      if (visit.checkInTime != null)
        _RecordedTimelinePoint(
          eventType: 'check_in',
          label: 'Check-In',
          time: visit.checkInTime!,
          latitude: visit.checkInLatitude,
          longitude: visit.checkInLongitude,
        ),
      if (visit.checkOutTime != null)
        _RecordedTimelinePoint(
          eventType: 'check_out',
          label: 'Checkout',
          time: visit.checkOutTime!,
          latitude: visit.checkOutLatitude,
          longitude: visit.checkOutLongitude,
        ),
      if (visit.completedAt != null)
        _RecordedTimelinePoint(
          eventType: 'completed',
          label: 'Completed',
          time: visit.completedAt!,
        ),
    ]..sort((left, right) => left.time.compareTo(right.time));
    final steps = <_VisitTimelineStep>[];
    for (var index = 0; index < records.length; index++) {
      final record = records[index];
      final next = index + 1 < records.length ? records[index + 1] : null;
      final duration = next?.time.difference(record.time);
      final gps = record.latitude == null || record.longitude == null
          ? 'GPS --'
          : '${record.latitude!.toStringAsFixed(5)}, ${record.longitude!.toStringAsFixed(5)}';
      final details = <String>[
        _formatDateTime(context, record.time),
        gps,
        if (duration != null && duration >= Duration.zero)
          _formatShortDuration(duration),
        if (record.notes.trim().isNotEmpty) record.notes.trim(),
      ];
      steps.add(
        _VisitTimelineStep(
          record.label,
          details.join(' | '),
          _VisitStepState.complete,
        ),
      );
    }
    final recordedTypes = records.map((record) => record.eventType).toSet();
    for (final eventType in technicalTimelineEventTypes) {
      if (!recordedTypes.contains(eventType)) {
        steps.add(
          _VisitTimelineStep(
            technicalValueLabel(eventType),
            'Pending GPS event',
            _VisitStepState.pending,
          ),
        );
      }
    }
    steps.addAll([
      _VisitTimelineStep(
        'Diagnosis',
        visit.issueDescription.isEmpty ? 'Not recorded' : 'Details recorded',
        visit.issueDescription.isEmpty
            ? _VisitStepState.pending
            : _VisitStepState.complete,
      ),
      _VisitTimelineStep(
        'Repair',
        visit.correctiveAction.isEmpty && visit.technicianNotes.isEmpty
            ? 'Not recorded'
            : 'Corrective action recorded',
        visit.correctiveAction.isEmpty && visit.technicianNotes.isEmpty
            ? _VisitStepState.pending
            : _VisitStepState.complete,
      ),
      _VisitTimelineStep(
        'Parts Used',
        visit.partsUsed.isEmpty
            ? 'No parts recorded'
            : '${visit.partsUsed.length} recorded',
        visit.partsUsed.isEmpty
            ? _VisitStepState.pending
            : _VisitStepState.complete,
      ),
      const _VisitTimelineStep.unavailable(
        'Complaint',
        'No complaintId is stored on the visit.',
      ),
      const _VisitTimelineStep.unavailable(
        'Invoice',
        'No invoice field or service exists.',
      ),
      const _VisitTimelineStep.unavailable(
        'Payment',
        'No payment or collection field exists.',
      ),
    ]);

    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumSectionHeader(
            icon: Icons.account_tree_outlined,
            title: 'GPS Service Timeline',
            actionLabel: 'Record Event',
            onAction: onRecordEvent,
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 560 ? 3 : 2;
              const gap = 8.0;
              final width =
                  (constraints.maxWidth - ((columns - 1) * gap)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: steps
                    .map(
                      (step) => SizedBox(
                        width: width,
                        child: _VisitTimelineTile(step: step),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ServiceChecklistCard extends StatelessWidget {
  final CustomerVisitModel visit;
  final VoidCallback onEdit;

  const _ServiceChecklistCard({
    required this.visit,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final savedById = <String, TechnicalChecklistItem>{
      for (final item in visit.serviceChecklist) item.id: item,
    };
    final technicalItems = <TechnicalChecklistItem>[
      for (final definition in technicalChecklistDefinitions.entries)
        savedById.remove(definition.key) ??
            TechnicalChecklistItem(
              id: definition.key,
              label: definition.value,
            ),
      ...savedById.values,
    ];
    final evidenceItems = <_ChecklistItem>[
      _ChecklistItem('GPS Check-in', visit.hasGpsCheckIn),
      _ChecklistItem('GPS Checkout', visit.hasGpsCheckOut),
      _ChecklistItem('Photos Uploaded', visit.photoUrls.isNotEmpty),
      _ChecklistItem(
        'Video Ready',
        visit.videoPlaceholderStatus == 'ready',
      ),
      _ChecklistItem(
        'Technical Attachments',
        visit.technicalAttachments.isNotEmpty,
      ),
      _ChecklistItem(
        'Signature Taken',
        visit.signaturePlaceholderStatus == 'ready',
      ),
    ];
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumSectionHeader(
            icon: Icons.fact_check_outlined,
            title: 'Technical Checklist',
            actionLabel: 'Update',
            onAction: onEdit,
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 420 ? 2 : 1;
              const gap = 8.0;
              final width =
                  (constraints.maxWidth - ((columns - 1) * gap)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: technicalItems
                    .map(
                      (item) => SizedBox(
                        width: width,
                        child: _TechnicalChecklistTile(item: item),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
          const Divider(height: 18),
          Text(
            'Evidence readiness',
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          ...evidenceItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: _ChecklistTile(item: item),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordedTimelinePoint {
  final String eventType;
  final String label;
  final DateTime time;
  final double? latitude;
  final double? longitude;
  final String notes;

  const _RecordedTimelinePoint({
    required this.eventType,
    required this.label,
    required this.time,
    this.latitude,
    this.longitude,
    this.notes = '',
  });
}

enum _VisitStepState { complete, pending, unavailable }

class _VisitTimelineStep {
  final String label;
  final String detail;
  final _VisitStepState state;

  const _VisitTimelineStep(this.label, this.detail, this.state);

  const _VisitTimelineStep.unavailable(this.label, this.detail)
    : state = _VisitStepState.unavailable;
}

class _VisitTimelineTile extends StatelessWidget {
  final _VisitTimelineStep step;

  const _VisitTimelineTile({required this.step});

  @override
  Widget build(BuildContext context) {
    final color = switch (step.state) {
      _VisitStepState.complete => AppColors.success,
      _VisitStepState.pending => AppColors.warning,
      _VisitStepState.unavailable => AppColors.textDisabled,
    };
    final icon = switch (step.state) {
      _VisitStepState.complete => Icons.check_circle_outline,
      _VisitStepState.pending => Icons.schedule_outlined,
      _VisitStepState.unavailable => Icons.lock_outline,
    };
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(48)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TechnicalChecklistTile extends StatelessWidget {
  final TechnicalChecklistItem item;

  const _TechnicalChecklistTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final status = item.status.toLowerCase();
    final color = switch (status) {
      'pass' => AppColors.success,
      'fail' => AppColors.error,
      'not_applicable' => AppColors.textDisabled,
      _ => AppColors.warning,
    };
    final icon = switch (status) {
      'pass' => Icons.check_circle_outline,
      'fail' => Icons.cancel_outlined,
      'not_applicable' => Icons.remove_circle_outline,
      _ => Icons.schedule_outlined,
    };
    final detail = <String>[
      technicalValueLabel(status),
      if (item.comments.trim().isNotEmpty) item.comments.trim(),
      if (item.photoReference.trim().isNotEmpty) 'Photo attached',
    ].join(' | ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(45)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistItem {
  final String label;
  final bool complete;

  const _ChecklistItem(this.label, this.complete);
}

class _ChecklistTile extends StatelessWidget {
  final _ChecklistItem item;

  const _ChecklistTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.complete
        ? AppColors.success
        : AppColors.warning;
    return Row(
      children: [
        Icon(
          item.complete
              ? Icons.check_box_outlined
              : Icons.check_box_outline_blank,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption,
          ),
        ),
      ],
    );
  }
}

class _ServiceDetailsCard extends StatelessWidget {
  final CustomerVisitModel visit;
  final VoidCallback onEdit;

  const _ServiceDetailsCard({required this.visit, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final issues = visit.issueCategories.isEmpty
        ? <String>[if (visit.issueCategory.isNotEmpty) visit.issueCategory]
        : visit.issueCategories;
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumSectionHeader(
            icon: Icons.engineering_outlined,
            title: 'Technical Service Record',
            actionLabel: 'Edit',
            onAction: onEdit,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              PremiumStatusChip(
                label: technicalValueLabel(
                  visit.resolutionStatus.isEmpty
                      ? 'pending'
                      : visit.resolutionStatus,
                ),
                color: _resolutionColor(visit.resolutionStatus),
                icon: Icons.verified_outlined,
              ),
              PremiumStatusChip(
                label: visit.warrantyStatus.isEmpty
                    ? 'Warranty --'
                    : visit.warrantyStatus,
                color: AppColors.info,
                icon: Icons.verified_user_outlined,
              ),
              PremiumStatusChip(
                label: '${visit.diagnosticReadings.length} readings',
                color: AppColors.textSecondary,
                icon: Icons.monitor_heart_outlined,
              ),
              PremiumStatusChip(
                label: '${visit.partsUsed.length} parts',
                color: AppColors.warning,
                icon: Icons.build_outlined,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _TechnicalExpansionSection(
            title: 'Equipment Registry',
            icon: Icons.precision_manufacturing_outlined,
            children: [
              _TechnicalValue('Customer', visit.customerName),
              _TechnicalValue('Dealer', visit.dealerName),
              _TechnicalValue('Vehicle Details', visit.vehicleDetails),
              _TechnicalValue('Vehicle Number', visit.vehicleNumber),
              _TechnicalValue('Vehicle Type', visit.vehicleType),
              _TechnicalValue('Vehicle Category', visit.vehicleCategory),
              _TechnicalValue('Fleet', visit.fleetName),
              _TechnicalValue(
                'Odometer',
                _numberWithUnit(visit.vehicleOdometer, 'km'),
              ),
              _TechnicalValue(
                'Hours Run',
                _numberWithUnit(visit.hoursRun, 'h'),
              ),
              _TechnicalValue(
                'Last Service',
                _optionalDate(visit.lastServiceDate),
              ),
              _TechnicalValue('Motor Model', visit.motorModel),
              _TechnicalValue('Motor Serial', visit.motorSerialNumber),
              _TechnicalValue(
                'Motor Manufacturing',
                _optionalDate(visit.motorManufacturingDate),
              ),
              _TechnicalValue('Motor Warranty', visit.motorWarrantyStatus),
              _TechnicalValue('Controller Model', visit.controllerModel),
              _TechnicalValue(
                'Controller Serial',
                visit.controllerSerialNumber,
              ),
              _TechnicalValue(
                'Controller Firmware',
                visit.controllerFirmware,
              ),
              _TechnicalValue(
                'Controller Manufacturing',
                _optionalDate(visit.controllerManufacturingDate),
              ),
              _TechnicalValue('Battery Model', visit.batteryModel),
              _TechnicalValue('Battery Serial', visit.batterySerialNumber),
              _TechnicalValue('Battery Chemistry', visit.batteryChemistry),
              _TechnicalValue('Battery Capacity', visit.batteryCapacity),
              _TechnicalValue(
                'Battery Voltage',
                visit.batteryNominalVoltage,
              ),
              _TechnicalValue(
                'Battery Warranty',
                visit.batteryWarrantyStatus,
              ),
              _TechnicalValue('Charger Model', visit.chargerModel),
            ],
          ),
          _TechnicalExpansionSection(
            title: 'Diagnostics and Measurements',
            icon: Icons.monitor_heart_outlined,
            children: [
              _TechnicalValue(
                'Issue Classification',
                issues.isEmpty ? '' : issues.join(', '),
              ),
              for (final field in technicalDiagnosticFields)
                _TechnicalValue(
                  field.label,
                  _diagnosticValue(visit, field),
                ),
              for (final entry in visit.diagnosticReadings.entries)
                if (!technicalDiagnosticFields.any(
                  (field) => field.key == entry.key,
                ))
                  _TechnicalValue(technicalValueLabel(entry.key), entry.value),
            ],
          ),
          _TechnicalExpansionSection(
            title: 'Root Cause and Resolution',
            icon: Icons.troubleshoot_outlined,
            children: [
              _TechnicalValue('Observed Issue', visit.issueDescription),
              _TechnicalValue('Actual Root Cause', visit.actualRootCause),
              _TechnicalValue('Corrective Action', visit.correctiveAction),
              _TechnicalValue('Preventive Action', visit.preventiveAction),
              _TechnicalValue(
                'Engineer Recommendation',
                visit.engineerRecommendation,
              ),
              _TechnicalValue(
                'Resolution',
                technicalValueLabel(visit.resolutionStatus),
              ),
              _TechnicalValue(
                'Parts Replaced',
                visit.partsUsed.isEmpty ? '' : visit.partsUsed.join(', '),
              ),
              _TechnicalValue('Technician Notes', visit.technicianNotes),
              _TechnicalValue('Internal Notes', visit.notes),
            ],
          ),
        ],
      ),
    );
  }
}

class _TechnicalValue {
  final String label;
  final String value;

  const _TechnicalValue(this.label, this.value);
}

class _TechnicalExpansionSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_TechnicalValue> children;

  const _TechnicalExpansionSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final recorded = children.where((item) => item.value.trim().isNotEmpty).length;
    return Material(
      color: Colors.transparent,
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        leading: Icon(icon, size: 19),
        title: Text(
          title,
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$recorded/${children.length}', style: AppTextStyles.caption),
            const SizedBox(width: 3),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 520 ? 2 : 1;
              const gap = 8.0;
              final width =
                  (constraints.maxWidth - ((columns - 1) * gap)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: children
                    .map(
                      (item) => SizedBox(
                        width: width,
                        child: _CompactTechnicalValue(item: item),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _CompactTechnicalValue extends StatelessWidget {
  final _TechnicalValue item;

  const _CompactTechnicalValue({required this.item});

  @override
  Widget build(BuildContext context) {
    final missing = item.value.trim().isEmpty || item.value == 'Not recorded';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.label, style: AppTextStyles.caption),
          const SizedBox(height: 2),
          Text(
            missing ? 'Not recorded' : item.value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              color: missing ? AppColors.textDisabled : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DispatchVisitPackageCard extends StatelessWidget {
  final CustomerVisitModel visit;
  final EmployeeModel? engineer;
  final VoidCallback onOpenMap;

  const _DispatchVisitPackageCard({
    required this.visit,
    required this.engineer,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final assigned = visit.userId.trim().isNotEmpty;
    final engineerName = _employeeDisplayName(engineer, visit.userId);
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumSectionHeader(
            icon: Icons.inventory_2_outlined,
            title: 'Engineer Visit Package',
            actionLabel: 'Map',
            onAction: onOpenMap,
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              PremiumStatusChip(
                label: assigned ? 'Assigned' : 'Pending Dispatch',
                color: assigned ? AppColors.success : AppColors.warning,
                icon: assigned
                    ? Icons.assignment_ind_outlined
                    : Icons.pending_actions_outlined,
              ),
              PremiumStatusChip(
                label: visit.priority.isEmpty ? 'Priority --' : visit.priority,
                color: _priorityColor(visit.priority),
                icon: Icons.priority_high,
              ),
              PremiumStatusChip(
                label: visit.serviceCentreName.isEmpty
                    ? 'Centre --'
                    : visit.serviceCentreName,
                color: AppColors.info,
                icon: Icons.business_outlined,
              ),
            ],
          ),
          const SizedBox(height: 6),
          _TechnicalExpansionSection(
            title: 'Dispatch and Schedule',
            icon: Icons.alt_route_outlined,
            children: [
              _TechnicalValue('Assigned Engineer', engineerName),
              _TechnicalValue('Assigned At', _optionalDateTime(visit.assignedAt)),
              _TechnicalValue(
                'Preferred Visit',
                _optionalDate(visit.preferredVisitDate),
              ),
              _TechnicalValue(
                'Expected Duration',
                _expectedDurationLabel(visit.expectedDurationMinutes),
              ),
              _TechnicalValue('Service Centre', visit.serviceCentreName),
              _TechnicalValue(
                'Direct Centre Distance',
                _numberWithUnit(visit.serviceCentreDistanceKm, 'km'),
              ),
              _TechnicalValue(
                'Road Distance',
                visit.roadDistanceKm == null
                    ? 'Requires Google Directions API'
                    : _numberWithUnit(visit.roadDistanceKm, 'km'),
              ),
              _TechnicalValue(
                'Travel ETA',
                visit.estimatedTravelMinutes == null
                    ? 'Requires Google Directions API'
                    : _expectedDurationLabel(visit.estimatedTravelMinutes),
              ),
              _TechnicalValue(
                'Travel Cost',
                visit.travelCostEstimate == null
                    ? 'Requires route and cost policy'
                    : 'INR ${visit.travelCostEstimate!.toStringAsFixed(2)}',
              ),
              _TechnicalValue(
                'Dealer Coordinates',
                visit.dealerLatitude == null || visit.dealerLongitude == null
                    ? 'Requires Google Geocoding API'
                    : '${visit.dealerLatitude!.toStringAsFixed(5)}, ${visit.dealerLongitude!.toStringAsFixed(5)}',
              ),
            ],
          ),
          _TechnicalExpansionSection(
            title: 'Dealer, Complaint, and Customer',
            icon: Icons.storefront_outlined,
            children: [
              _TechnicalValue('Dealer', visit.dealerName),
              _TechnicalValue('Dealer Address', visit.customerAddress),
              _TechnicalValue('Dealer PIN', visit.dealerPinCode),
              _TechnicalValue('Complaint ID', visit.complaintId),
              _TechnicalValue('Complaint', visit.issueDescription),
              _TechnicalValue('Customer', visit.customerName),
              _TechnicalValue('Customer Contact', visit.customerPhone),
              _TechnicalValue('Internal Notes', visit.notes),
              _TechnicalValue(
                'Technical Checklist',
                '${technicalChecklistDefinitions.length} checks available',
              ),
              const _TechnicalValue(
                'Navigation',
                'Requires Google Directions/Routes API',
              ),
            ],
          ),
          Text(
            'The Map action reuses the existing map foundation. A targeted planned-visit marker requires approved map input support and geocoded coordinates.',
            style: AppTextStyles.caption.copyWith(height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _GpsCard extends StatelessWidget {
  final CustomerVisitModel visit;

  const _GpsCard({required this.visit});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            icon: Icons.gps_fixed_outlined,
            title: 'GPS Capture',
          ),
          const SizedBox(height: 10),
          _GpsPoint(
            label: 'Check-in',
            time: visit.checkInTime,
            latitude: visit.checkInLatitude,
            longitude: visit.checkInLongitude,
          ),
          const SizedBox(height: 12),
          _GpsPoint(
            label: 'Check-out',
            time: visit.checkOutTime,
            latitude: visit.checkOutLatitude,
            longitude: visit.checkOutLongitude,
          ),
        ],
      ),
    );
  }
}

class _MediaCard extends StatelessWidget {
  final CustomerVisitModel visit;
  final VoidCallback onAddAttachment;

  const _MediaCard({
    required this.visit,
    required this.onAddAttachment,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumSectionHeader(
            icon: Icons.perm_media_outlined,
            title: 'Media and Sign-off',
            actionLabel: 'Add',
            onAction: onAddAttachment,
          ),
          const SizedBox(height: 10),
          _DetailRow(
            label: 'Photos',
            value: visit.photoUrls.isEmpty
                ? 'No photo references added'
                : List<String>.generate(visit.photoUrls.length, (index) {
                    final event = index < visit.photoTimelineEvents.length
                        ? visit.photoTimelineEvents[index]
                        : 'general';
                    return '${visit.photoUrls[index]} (${technicalValueLabel(event)})';
                  }).join('\n'),
          ),
          _DetailRow(
            label: 'Video',
            value: _placeholderLabel(visit.videoPlaceholderStatus),
          ),
          _DetailRow(
            label: 'Signature',
            value: _placeholderLabel(visit.signaturePlaceholderStatus),
          ),
          if (visit.technicalAttachments.isEmpty)
            const _DetailRow(
              label: 'Voice Notes / Documents',
              value: '',
            )
          else
            ...visit.technicalAttachments.map(
              (attachment) => _DetailRow(
                label: technicalValueLabel(attachment.type),
                value:
                    '${attachment.reference}\n${technicalValueLabel(attachment.eventType)} | ${_formatDate(attachment.createdAt)}${attachment.notes.isEmpty ? '' : '\n${attachment.notes}'}',
              ),
            ),
        ],
      ),
    );
  }
}

class _SerialHistoryCard extends StatelessWidget {
  final CustomerVisitModel currentVisit;
  final Future<List<CustomerVisitModel>> visitsFuture;
  final Map<String, EmployeeModel> employeesById;

  const _SerialHistoryCard({
    required this.currentVisit,
    required this.visitsFuture,
    required this.employeesById,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PremiumSectionHeader(
            icon: Icons.qr_code_2_outlined,
            title: 'Serial Number History',
          ),
          const SizedBox(height: 4),
          Text(
            'Derived from existing visit records. No duplicate history is stored.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<CustomerVisitModel>>(
            future: visitsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator(minHeight: 2);
              }
              if (snapshot.hasError) {
                return Text(
                  'Serial history is temporarily unavailable.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.error),
                );
              }
              final visits = snapshot.data ?? const <CustomerVisitModel>[];
              final histories = <_SerialHistoryData>[
                if (currentVisit.vehicleNumber.trim().isNotEmpty)
                  _buildSerialHistory(
                    label: 'Vehicle',
                    serial: currentVisit.vehicleNumber,
                    currentVisitId: currentVisit.id,
                    visits: visits,
                    serialFor: (visit) => visit.vehicleNumber,
                  ),
                if (currentVisit.motorSerialNumber.trim().isNotEmpty)
                  _buildSerialHistory(
                    label: 'Motor',
                    serial: currentVisit.motorSerialNumber,
                    currentVisitId: currentVisit.id,
                    visits: visits,
                    serialFor: (visit) => visit.motorSerialNumber,
                  ),
                if (currentVisit.controllerSerialNumber.trim().isNotEmpty)
                  _buildSerialHistory(
                    label: 'Controller',
                    serial: currentVisit.controllerSerialNumber,
                    currentVisitId: currentVisit.id,
                    visits: visits,
                    serialFor: (visit) => visit.controllerSerialNumber,
                  ),
                if (currentVisit.batterySerialNumber.trim().isNotEmpty)
                  _buildSerialHistory(
                    label: 'Battery',
                    serial: currentVisit.batterySerialNumber,
                    currentVisitId: currentVisit.id,
                    visits: visits,
                    serialFor: (visit) => visit.batterySerialNumber,
                  ),
              ];
              if (histories.isEmpty) {
                return Text(
                  'Add a vehicle, motor, controller, or battery serial number to build service history.',
                  style: AppTextStyles.caption.copyWith(height: 1.4),
                );
              }
              return Column(
                children: histories
                    .map(
                      (history) => _SerialHistoryPanel(
                        data: history,
                        employeesById: employeesById,
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SerialHistoryData {
  final String label;
  final String serial;
  final String currentVisitId;
  final List<CustomerVisitModel> visits;

  const _SerialHistoryData({
    required this.label,
    required this.serial,
    required this.currentVisitId,
    required this.visits,
  });
}

class _SerialHistoryPanel extends StatelessWidget {
  final _SerialHistoryData data;
  final Map<String, EmployeeModel> employeesById;

  const _SerialHistoryPanel({
    required this.data,
    required this.employeesById,
  });

  @override
  Widget build(BuildContext context) {
    final visits = data.visits.toList()
      ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
    final complaintFrequency = <String, int>{};
    for (final visit in visits) {
      final issues = visit.issueCategories.isEmpty
          ? <String>[if (visit.issueCategory.isNotEmpty) visit.issueCategory]
          : visit.issueCategories;
      for (final issue in issues) {
        complaintFrequency.update(
          issue,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
    final topComplaint = _largestStringCount(complaintFrequency);
    final repaired = visits.where(_isTechnicallyResolved).length;
    final pending = visits.where((visit) => !_isTechnicallyClosed(visit)).length;
    final warrantyHistory = visits
        .map((visit) => _serialWarrantyFor(visit, data.label).trim())
        .where((status) => status.isNotEmpty)
        .toSet()
        .join(', ');
    final engineers = visits
        .where((visit) => visit.id != data.currentVisitId)
        .map((visit) => _employeeDisplayName(employeesById[visit.userId], visit.userId))
        .toSet()
        .join(', ');
    return Material(
      color: Colors.transparent,
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        leading: const Icon(Icons.qr_code_scanner_outlined, size: 19),
        title: Text(
          '${data.label}: ${data.serial}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${visits.length} visits | ${visits.length > 1 ? visits.length - 1 : 0} repeat failures',
          style: AppTextStyles.caption,
        ),
        children: [
          _DetailRow(label: 'Total Visits', value: '${visits.length}'),
          _DetailRow(
            label: 'First Visit',
            value: visits.isEmpty ? '' : _formatDate(visits.first.createdAt),
          ),
          _DetailRow(
            label: 'Last Visit',
            value: visits.isEmpty ? '' : _formatDate(visits.last.createdAt),
          ),
          _DetailRow(
            label: 'Complaint Frequency',
            value: topComplaint == null
                ? ''
                : '${topComplaint.key} (${topComplaint.value})',
          ),
          _DetailRow(
            label: 'Repair History',
            value: '$repaired resolved / ${visits.length} total',
          ),
          _DetailRow(label: 'Warranty History', value: warrantyHistory),
          _DetailRow(label: 'Pending Issues', value: '$pending'),
          _DetailRow(label: 'Previous Engineers', value: engineers),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final CustomerVisitModel currentVisit;
  final Future<List<CustomerVisitModel>> historyFuture;

  const _HistoryCard({
    required this.currentVisit,
    required this.historyFuture,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            icon: Icons.history_outlined,
            title: 'Customer Service History',
          ),
          const SizedBox(height: 4),
          Text(
            'Derived from loaded visit records; history is never duplicated.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<CustomerVisitModel>>(
            future: historyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator(minHeight: 2);
              }

              if (snapshot.hasError) {
                return Text(
                  'Customer history is temporarily unavailable.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.error,
                    height: 1.4,
                  ),
                );
              }

              final visits = (snapshot.data ?? const <CustomerVisitModel>[])
                  .where(
                    (visit) =>
                        visit.customerName.trim().toLowerCase() ==
                        currentVisit.customerName.trim().toLowerCase(),
                  )
                  .toList()
                ..sort(
                  (left, right) => right.createdAt.compareTo(left.createdAt),
                );
              if (visits.isEmpty) {
                return Text(
                  'No previous visits found.',
                  style: AppTextStyles.caption,
                );
              }

              return Column(
                children: visits
                    .take(5)
                    .map((visit) {
                      final status = _visitStatus(visit.status);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            PremiumTinyDot(color: status.color),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${_formatDate(visit.createdAt)} - ${status.label}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption,
                              ),
                            ),
                          ],
                        ),
                      );
                    })
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PremiumIconChip(icon: icon, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 142,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 18),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: Colors.white.withAlpha(enabled ? 74 : 20)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(
            value.trim().isEmpty ? 'Not provided' : value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: value.trim().isEmpty
                  ? AppColors.textDisabled
                  : AppColors.textPrimary,
              height: 1.35,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _GpsPoint extends StatelessWidget {
  final String label;
  final DateTime? time;
  final double? latitude;
  final double? longitude;

  const _GpsPoint({
    required this.label,
    required this.time,
    required this.latitude,
    required this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    final hasGps = latitude != null && longitude != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            PremiumIconChip(
              icon: hasGps ? Icons.my_location : Icons.location_disabled,
              color: hasGps ? AppColors.success : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.bodyLarge),
                  const SizedBox(height: 4),
                  Text(
                    hasGps
                        ? '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'
                        : 'GPS not captured',
                    style: AppTextStyles.caption,
                  ),
                  if (time != null)
                    Text(
                      _formatDateTime(context, time!),
                      style: AppTextStyles.caption,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitStatusData {
  final String label;
  final Color color;

  const _VisitStatusData({required this.label, required this.color});
}

_VisitStatusData _visitStatus(String status) {
  switch (status.toLowerCase()) {
    case 'checked_in':
      return const _VisitStatusData(label: 'Checked In', color: AppColors.info);
    case 'checked_out':
      return const _VisitStatusData(
        label: 'Checked Out',
        color: AppColors.warning,
      );
    case 'completed':
      return const _VisitStatusData(
        label: 'Completed',
        color: AppColors.success,
      );
    case 'cancelled':
      return const _VisitStatusData(
        label: 'Cancelled',
        color: AppColors.error,
      );
    case 'planned':
      return const _VisitStatusData(
        label: 'Planned',
        color: AppColors.textSecondary,
      );
    default:
      return const _VisitStatusData(
        label: 'Open',
        color: AppColors.textSecondary,
      );
  }
}

List<String> _splitList(String value) {
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${hours}h ${minutes}m ${seconds}s';
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _formatDateTime(BuildContext context, DateTime date) {
  return '${_formatDate(date)} ${TimeOfDay.fromDateTime(date).format(context)}';
}

const _mediaTimelineEventTypes = <String>[
  'general',
  'assignment',
  'check_in',
  ...technicalTimelineEventTypes,
  'check_out',
  'completed',
];

_SerialHistoryData _buildSerialHistory({
  required String label,
  required String serial,
  required String currentVisitId,
  required List<CustomerVisitModel> visits,
  required String Function(CustomerVisitModel visit) serialFor,
}) {
  final normalized = serial.trim().toLowerCase();
  return _SerialHistoryData(
    label: label,
    serial: serial,
    currentVisitId: currentVisitId,
    visits: visits
        .where((visit) => serialFor(visit).trim().toLowerCase() == normalized)
        .toList(growable: false),
  );
}

MapEntry<String, int>? _largestStringCount(Map<String, int> values) {
  if (values.isEmpty) return null;
  return values.entries.reduce(
    (current, next) => next.value > current.value ? next : current,
  );
}

bool _isTechnicallyResolved(CustomerVisitModel visit) {
  final resolution = visit.resolutionStatus.toLowerCase();
  final status = visit.status.toLowerCase();
  return resolution == 'solved' ||
      resolution == 'temporary_fix' ||
      status == 'completed';
}

bool _isTechnicallyClosed(CustomerVisitModel visit) {
  final resolution = visit.resolutionStatus.toLowerCase();
  final status = visit.status.toLowerCase();
  return resolution == 'solved' ||
      resolution == 'cancelled' ||
      status == 'completed' ||
      status == 'cancelled';
}

String _serialWarrantyFor(CustomerVisitModel visit, String component) {
  switch (component.toLowerCase()) {
    case 'motor':
      return visit.motorWarrantyStatus.isEmpty
          ? visit.warrantyStatus
          : visit.motorWarrantyStatus;
    case 'battery':
      return visit.batteryWarrantyStatus.isEmpty
          ? visit.warrantyStatus
          : visit.batteryWarrantyStatus;
    default:
      return visit.warrantyStatus;
  }
}

String _employeeDisplayName(EmployeeModel? employee, String userId) {
  final name = employee?.name.trim() ?? '';
  if (name.isNotEmpty) return name;
  final email = employee?.email.trim() ?? '';
  if (email.isNotEmpty) return email;
  if (userId.isEmpty) return 'Unassigned';
  return userId.length <= 8 ? userId : userId.substring(0, 8);
}

Color _resolutionColor(String resolutionStatus) {
  switch (resolutionStatus.toLowerCase()) {
    case 'solved':
      return AppColors.success;
    case 'cancelled':
      return AppColors.error;
    case 'temporary_fix':
    case 'waiting_parts':
    case 'waiting_customer':
    case 'need_factory_support':
    case 'warranty_approval_pending':
    case 'replacement_required':
    case 'carry_forward':
      return AppColors.warning;
    default:
      return AppColors.textSecondary;
  }
}

String _optionalDate(DateTime? date) => date == null ? '' : _formatDate(date);

String _numberWithUnit(double? value, String unit) {
  if (value == null) return '';
  final number = value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
  return '$number $unit';
}

String _diagnosticValue(
  CustomerVisitModel visit,
  TechnicalFieldDefinition field,
) {
  final value = visit.diagnosticReadings[field.key]?.trim() ?? '';
  if (value.isEmpty || field.unit == null) return value;
  if (value.toLowerCase().endsWith(field.unit!.toLowerCase())) return value;
  return '$value ${field.unit}';
}

String _formatShortDuration(Duration duration) {
  if (duration.inMinutes < 1) return '${duration.inSeconds}s';
  if (duration.inHours < 1) return '${duration.inMinutes}m';
  final minutes = duration.inMinutes.remainder(60);
  return '${duration.inHours}h ${minutes}m';
}

bool _hasDispatchPackage(CustomerVisitModel visit) {
  return visit.complaintId.isNotEmpty ||
      visit.dealerPinCode.isNotEmpty ||
      visit.priority.isNotEmpty ||
      visit.preferredVisitDate != null ||
      visit.expectedDurationMinutes != null ||
      visit.serviceCentreName.isNotEmpty;
}

String _expectedDurationLabel(int? minutes) {
  if (minutes == null || minutes <= 0) return '';
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes.remainder(60);
  if (hours == 0) return '${remainingMinutes}m';
  if (remainingMinutes == 0) return '${hours}h';
  return '${hours}h ${remainingMinutes}m';
}

String _optionalDateTime(DateTime? date) {
  if (date == null) return '';
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${_formatDate(date)} $hour:$minute';
}

Color _priorityColor(String priority) {
  switch (priority.toLowerCase()) {
    case 'critical':
      return AppColors.error;
    case 'high':
      return AppColors.warning;
    case 'low':
      return AppColors.textSecondary;
    default:
      return AppColors.info;
  }
}

String _placeholderLabel(String value) {
  return value == 'ready' ? 'Ready for final capture' : 'Pending final capture';
}
