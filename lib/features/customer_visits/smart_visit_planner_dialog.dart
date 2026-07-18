import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/employee_model.dart';
import '../../core/models/live_location_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/premium_widgets.dart';
import '../attendance/models/attendance_model.dart';
import '../complaints/controllers/complaint_controller.dart';
import '../complaints/models/complaint_model.dart';
import 'controllers/customer_visit_controller.dart';
import 'models/customer_visit_model.dart';
import 'services/visit_planning_service.dart';
import 'technical_service_definitions.dart';

class SmartVisitPlannerResult {
  final CustomerVisitModel visit;
  final bool complaintLinkFailed;

  const SmartVisitPlannerResult({
    required this.visit,
    required this.complaintLinkFailed,
  });
}

class SmartVisitPlannerDialog extends StatefulWidget {
  final List<CustomerVisitModel> visits;
  final List<EmployeeModel> employees;
  final List<AttendanceModel> attendance;
  final Map<String, LiveLocationModel> liveLocationsByUserId;
  final VoidCallback onOpenMap;

  const SmartVisitPlannerDialog({
    super.key,
    required this.visits,
    required this.employees,
    required this.attendance,
    required this.liveLocationsByUserId,
    required this.onOpenMap,
  });

  static Future<SmartVisitPlannerResult?> show(
    BuildContext context, {
    required List<CustomerVisitModel> visits,
    required List<EmployeeModel> employees,
    required List<AttendanceModel> attendance,
    required Map<String, LiveLocationModel> liveLocationsByUserId,
    required VoidCallback onOpenMap,
  }) {
    return showDialog<SmartVisitPlannerResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SmartVisitPlannerDialog(
        visits: visits,
        employees: employees,
        attendance: attendance,
        liveLocationsByUserId: liveLocationsByUserId,
        onOpenMap: onOpenMap,
      ),
    );
  }

  @override
  State<SmartVisitPlannerDialog> createState() =>
      _SmartVisitPlannerDialogState();
}

class _SmartVisitPlannerDialogState extends State<SmartVisitPlannerDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _dealerNameController = TextEditingController();
  final TextEditingController _dealerAddressController =
      TextEditingController();
  final TextEditingController _dealerPinController = TextEditingController();
  final TextEditingController _complaintSummaryController =
      TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerContactController =
      TextEditingController();
  final TextEditingController _expectedDurationController =
      TextEditingController(text: '120');
  final TextEditingController _internalNotesController =
      TextEditingController();

  List<ComplaintModel> _complaints = const <ComplaintModel>[];
  ComplaintModel? _selectedComplaint;
  String? _complaintsError;
  bool _loadingComplaints = true;
  bool _saving = false;
  bool _suppressAddressListener = false;
  String? _validationMessage;

  String _priority = 'Medium';
  DateTime? _preferredVisitDate;
  double? _dealerLatitude;
  double? _dealerLongitude;
  String? _selectedCentreName;
  bool _centreSelectedAutomatically = false;
  String? _selectedEngineerId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _dealerAddressController.addListener(_onDealerAddressChanged);
    _selectInitialEngineer();
    unawaited(_loadComplaints());
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _dealerAddressController
      ..removeListener(_onDealerAddressChanged)
      ..dispose();
    _dealerNameController.dispose();
    _dealerPinController.dispose();
    _complaintSummaryController.dispose();
    _customerNameController.dispose();
    _customerContactController.dispose();
    _expectedDurationController.dispose();
    _internalNotesController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!mounted || _tabController.indexIsChanging) return;
    setState(() {});
  }

  Future<void> _loadComplaints() async {
    if (mounted) {
      setState(() {
        _loadingComplaints = true;
        _complaintsError = null;
      });
    }
    try {
      final complaints = await ComplaintController.loadAllComplaints();
      if (!mounted) return;
      setState(() {
        _complaints = complaints
            .where(
              (complaint) =>
                  complaint.visitRequired &&
                  complaint.linkedVisitId.trim().isEmpty &&
                  complaint.status.toLowerCase() != 'closed',
            )
            .toList(growable: false);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _complaintsError = 'Registered complaints could not be loaded.';
      });
    } finally {
      if (mounted) setState(() => _loadingComplaints = false);
    }
  }

  void _selectInitialEngineer() {
    final recommendations = _rankEngineers();
    for (final recommendation in recommendations) {
      if (recommendation.available) {
        _selectedEngineerId = recommendation.employee.uid;
        return;
      }
    }
  }

  List<EngineerDispatchRecommendation> _rankEngineers() {
    return VisitPlanningService.rankEngineers(
      employees: widget.employees,
      attendance: widget.attendance,
      visits: widget.visits,
      liveLocationsByUserId: widget.liveLocationsByUserId,
      now: DateTime.now(),
      dealerLatitude: _dealerLatitude,
      dealerLongitude: _dealerLongitude,
    );
  }

  void _onDealerAddressChanged() {
    if (_suppressAddressListener ||
        (_dealerLatitude == null && _dealerLongitude == null)) {
      return;
    }
    setState(() {
      _dealerLatitude = null;
      _dealerLongitude = null;
      _selectedCentreName = null;
      _centreSelectedAutomatically = false;
    });
  }

  void _selectComplaint(String complaintId) {
    if (complaintId.isEmpty) {
      setState(() {
        _selectedComplaint = null;
        _dealerLatitude = null;
        _dealerLongitude = null;
        _selectedCentreName = null;
        _centreSelectedAutomatically = false;
      });
      return;
    }
    ComplaintModel? selected;
    for (final complaint in _complaints) {
      if (complaint.id == complaintId) {
        selected = complaint;
        break;
      }
    }
    if (selected == null) return;

    _suppressAddressListener = true;
    _dealerNameController.text = selected.dealerName;
    _dealerAddressController.text = selected.address;
    _dealerPinController.text = VisitPlanningService.extractPinCode(
      selected.address,
    );
    _complaintSummaryController.text = selected.customerStatedIssue;
    _customerNameController.text = selected.customerName;
    _customerContactController.text = selected.contactNumber;
    _priority = _normalizedPriority(selected.complaintPriority);
    _preferredVisitDate = selected.plannedVisitDateTime;
    _dealerLatitude = selected.latitude;
    _dealerLongitude = selected.longitude;
    _selectedCentreName = null;
    _centreSelectedAutomatically = false;
    _suppressAddressListener = false;

    final latitude = _dealerLatitude;
    final longitude = _dealerLongitude;
    if (latitude != null && longitude != null) {
      final assessment = VisitPlanningService.nearestCentre(
        latitude: latitude,
        longitude: longitude,
      );
      _selectedCentreName = assessment.centre.name;
      _centreSelectedAutomatically = true;
    }
    final assignedEngineerExists = widget.employees.any(
      (employee) => employee.uid == selected?.assignedEngineerId,
    );
    if (assignedEngineerExists) {
      _selectedEngineerId = selected.assignedEngineerId;
    } else {
      _selectedEngineerId = null;
      final recommendations = _rankEngineers();
      for (final recommendation in recommendations) {
        if (recommendation.available) {
          _selectedEngineerId = recommendation.employee.uid;
          break;
        }
      }
    }
    setState(() {
      _selectedComplaint = selected;
      _validationMessage = null;
    });
  }

  VisitServiceCentre? get _selectedCentre {
    final centreName = _selectedCentreName;
    return centreName == null
        ? null
        : VisitPlanningService.centreByName(centreName);
  }

  double? get _directCentreDistance {
    final latitude = _dealerLatitude;
    final longitude = _dealerLongitude;
    final centre = _selectedCentre;
    if (latitude == null || longitude == null || centre == null) return null;
    return VisitPlanningService.directDistanceKm(
      latitude,
      longitude,
      centre.latitude,
      centre.longitude,
    );
  }

  EmployeeModel? get _selectedEngineer {
    final selectedId = _selectedEngineerId;
    if (selectedId == null) return null;
    for (final employee in widget.employees) {
      if (employee.uid == selectedId) return employee;
    }
    return null;
  }

  EngineerDispatchRecommendation? get _selectedRecommendation {
    final selectedId = _selectedEngineerId;
    if (selectedId == null) return null;
    for (final recommendation in _rankEngineers()) {
      if (recommendation.employee.uid == selectedId) return recommendation;
    }
    return null;
  }

  Future<void> _pickPreferredDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _preferredVisitDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Preferred visit date',
    );
    if (selected == null || !mounted) return;
    setState(() => _preferredVisitDate = selected);
  }

  Future<void> _save({required bool assignEngineer}) async {
    if (_saving) return;
    final duration = int.tryParse(_expectedDurationController.text.trim());
    final pinCode = _dealerPinController.text.trim();
    final missingFields = <String>[
      if (_dealerNameController.text.trim().isEmpty) 'dealer name',
      if (_dealerAddressController.text.trim().isEmpty) 'dealer address',
      if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(pinCode)) 'valid PIN code',
      if (_complaintSummaryController.text.trim().isEmpty)
        'complaint summary',
      if (_customerNameController.text.trim().isEmpty) 'customer name',
      if (_customerContactController.text.trim().isEmpty) 'customer contact',
      if (_preferredVisitDate == null) 'preferred visit date',
      if (duration == null || duration <= 0) 'expected duration',
      if (_selectedCentre == null) 'service centre',
      if (assignEngineer && _selectedEngineer == null) 'engineer',
    ];
    if (missingFields.isNotEmpty) {
      setState(() {
        _validationMessage = 'Complete ${missingFields.join(', ')}.';
      });
      _tabController.animateTo(_selectedCentre == null ? 1 : 0);
      return;
    }

    setState(() {
      _saving = true;
      _validationMessage = null;
    });
    try {
      final complaint = _selectedComplaint;
      final selectedEngineerId = assignEngineer ? _selectedEngineerId : '';
      final issueCategory = _complaintIssueCategory(complaint);
      final visit = await CustomerVisitController.createVisit(
        customerName: _customerNameController.text.trim(),
        customerAddress: _dealerAddressController.text.trim(),
        customerPhone: _customerContactController.text.trim(),
        purpose: 'Complaint service',
        notes: _internalNotesController.text.trim(),
        vehicleDetails: complaint?.vehicleModel.trim() ?? '',
        motorSerialNumber: complaint?.motorSerialNumber.trim() ?? '',
        controllerSerialNumber:
            complaint?.controllerSerialNumber.trim() ?? '',
        warrantyStatus: complaint?.warrantyStatus.trim().isNotEmpty == true
            ? complaint!.warrantyStatus.trim()
            : 'Unknown',
        issueCategory: issueCategory,
        issueDescription: _complaintSummaryController.text.trim(),
        partsUsed: const <String>[],
        technicianNotes: '',
        assignedUserId: selectedEngineerId,
        dealerName: _dealerNameController.text.trim(),
        complaintId: complaint?.id ?? '',
        dealerPinCode: pinCode,
        dealerLatitude: _dealerLatitude,
        dealerLongitude: _dealerLongitude,
        priority: _priority,
        preferredVisitDate: _preferredVisitDate,
        expectedDurationMinutes: duration,
        serviceCentreName: _selectedCentre!.name,
        serviceCentreDistanceKm: _directCentreDistance,
        roadDistanceKm: null,
        estimatedTravelMinutes: null,
        travelCostEstimate: null,
        vehicleNumber: complaint?.vehicleNumber.trim() ?? '',
        batterySerialNumber: complaint?.batterySerialNumber.trim() ?? '',
      );

      var complaintLinkFailed = false;
      if (complaint != null) {
        try {
          await ComplaintController.linkVisit(
            complaint: complaint,
            visitId: visit.id,
            visitStatus: assignEngineer ? 'assigned' : 'pending_schedule',
          );
        } catch (_) {
          complaintLinkFailed = true;
        }
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        SmartVisitPlannerResult(
          visit: visit,
          complaintLinkFailed: complaintLinkFailed,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _validationMessage =
            'The visit package could not be saved. Check the connection and retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      titlePadding: const EdgeInsets.fromLTRB(18, 14, 10, 0),
      title: Row(
        children: [
          const PremiumIconChip(icon: Icons.alt_route_outlined),
          const SizedBox(width: 9),
          Expanded(
            child: Text('Smart Visit Planner', style: AppTextStyles.headingSmall),
          ),
          IconButton(
            tooltip: 'Close planner',
            onPressed: _saving ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 720),
        child: SizedBox(
          width: 980,
          height: MediaQuery.sizeOf(context).height * 0.74,
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(icon: Icon(Icons.edit_location_alt_outlined), text: 'Plan'),
                  Tab(icon: Icon(Icons.engineering_outlined), text: 'Dispatch'),
                  Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Package'),
                ],
              ),
              if (_validationMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _PlannerNotice(
                    icon: Icons.error_outline,
                    message: _validationMessage!,
                    color: AppColors.error,
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPlanTab(),
                    _buildDispatchTab(),
                    _buildPackageTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        OutlinedButton.icon(
          onPressed: _saving ? null : () => _save(assignEngineer: false),
          icon: const Icon(Icons.schedule_outlined, size: 18),
          label: const Text('Save Pending'),
        ),
        ElevatedButton.icon(
          onPressed: _saving || _selectedEngineer == null
              ? null
              : () => _save(assignEngineer: true),
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.assignment_ind_outlined, size: 18),
          label: const Text('Assign and Create'),
        ),
      ],
    );
  }

  Widget _buildPlanTab() {
    final complaintItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '', child: Text('Manual visit plan')),
      ..._complaints.map(
        (complaint) => DropdownMenuItem(
          value: complaint.id,
          child: Text(
            '${complaint.customerName} - ${_shortText(complaint.customerStatedIssue, 42)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 4, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PlannerSection(
            title: 'Registered Complaint',
            icon: Icons.report_problem_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_loadingComplaints)
                  const LinearProgressIndicator(minHeight: 2)
                else if (_complaintsError != null)
                  _PlannerNotice(
                    icon: Icons.cloud_off_outlined,
                    message:
                        '$_complaintsError Manual planning remains available.',
                    color: AppColors.warning,
                    actionLabel: 'Retry',
                    onAction: _loadComplaints,
                  )
                else
                  DropdownButtonFormField<String>(
                    key: ValueKey(_selectedComplaint?.id ?? 'manual'),
                    initialValue: _selectedComplaint?.id ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Complaint source',
                      prefixIcon: Icon(Icons.link_outlined),
                    ),
                    items: complaintItems,
                    onChanged: (value) => _selectComplaint(value ?? ''),
                  ),
                if (!_loadingComplaints &&
                    _complaintsError == null &&
                    _complaints.isEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    'No unlinked complaints requiring a visit are available. Create a manual plan below.',
                    style: AppTextStyles.caption.copyWith(height: 1.35),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 9),
          _PlannerSection(
            title: 'Dealer and Complaint',
            icon: Icons.storefront_outlined,
            child: _PlannerGrid(
              children: [
                _PlannerTextField(
                  controller: _dealerNameController,
                  label: 'Dealer Name',
                  icon: Icons.store_outlined,
                ),
                _PlannerTextField(
                  controller: _dealerPinController,
                  label: 'Dealer PIN Code',
                  icon: Icons.pin_drop_outlined,
                  keyboardType: TextInputType.number,
                ),
                _PlannerTextField(
                  controller: _dealerAddressController,
                  label: 'Dealer Address',
                  icon: Icons.location_on_outlined,
                  maxLines: 3,
                  spanFullWidth: true,
                ),
                _PlannerTextField(
                  controller: _complaintSummaryController,
                  label: 'Complaint Summary',
                  icon: Icons.troubleshoot_outlined,
                  maxLines: 3,
                  spanFullWidth: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          _PlannerSection(
            title: 'Schedule and Customer',
            icon: Icons.event_available_outlined,
            child: _PlannerGrid(
              children: [
                _PlannerDropdown(
                  label: 'Priority',
                  value: _priority,
                  icon: Icons.priority_high,
                  options: const ['Critical', 'High', 'Medium', 'Low'],
                  onChanged: (value) => setState(() => _priority = value),
                ),
                _PlannerDateField(
                  label: 'Preferred Visit Date',
                  value: _preferredVisitDate,
                  onTap: _pickPreferredDate,
                ),
                _PlannerTextField(
                  controller: _expectedDurationController,
                  label: 'Expected Duration (minutes)',
                  icon: Icons.timer_outlined,
                  keyboardType: TextInputType.number,
                ),
                _PlannerTextField(
                  controller: _customerNameController,
                  label: 'Customer Name',
                  icon: Icons.person_outline,
                ),
                _PlannerTextField(
                  controller: _customerContactController,
                  label: 'Customer Contact',
                  icon: Icons.call_outlined,
                  keyboardType: TextInputType.phone,
                ),
                _PlannerTextField(
                  controller: _internalNotesController,
                  label: 'Internal Notes',
                  icon: Icons.notes_outlined,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDispatchTab() {
    final recommendations = _rankEngineers();
    final directDistance = _directCentreDistance;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 4, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PlannerSection(
            title: 'Smart Location Engine',
            icon: Icons.location_searching_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PlannerGrid(
                  children: [
                    _PlannerDropdown(
                      label: _centreSelectedAutomatically
                          ? 'Nearest Service Centre'
                          : 'Service Centre (manual fallback)',
                      value: _selectedCentreName ?? '',
                      icon: Icons.business_outlined,
                      options: [
                        '',
                        ...VisitPlanningService.serviceCentres.map(
                          (centre) => centre.name,
                        ),
                      ],
                      labelFor: (value) =>
                          value.isEmpty ? 'Select centre' : value,
                      onChanged: (value) {
                        setState(() {
                          _selectedCentreName = value.isEmpty ? null : value;
                          _centreSelectedAutomatically = false;
                        });
                      },
                    ),
                    _PlannerReadOnlyField(
                      label: 'Centre Region',
                      value: _selectedCentre?.region ?? '',
                      icon: Icons.public_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DispatchMetric(
                      label: 'Direct Distance',
                      value: directDistance == null
                          ? '--'
                          : '${directDistance.toStringAsFixed(1)} km',
                      icon: Icons.straighten_outlined,
                    ),
                    const _DispatchMetric(
                      label: 'Road Distance',
                      value: 'Requires API',
                      icon: Icons.route_outlined,
                    ),
                    const _DispatchMetric(
                      label: 'Travel ETA',
                      value: 'Requires API',
                      icon: Icons.schedule_outlined,
                    ),
                    const _DispatchMetric(
                      label: 'Travel Cost',
                      value: 'Requires policy',
                      icon: Icons.currency_rupee,
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                _PlannerNotice(
                  icon: _dealerLatitude == null
                      ? Icons.api_outlined
                      : Icons.gps_fixed_outlined,
                  message: _dealerLatitude == null
                      ? 'Requires Google Geocoding/Directions API. Choose a service centre manually; no distance or ETA is fabricated.'
                      : 'Complaint GPS is available. Nearest centre uses direct distance; road distance and ETA still require Google Directions/Routes API.',
                  color: _dealerLatitude == null
                      ? AppColors.warning
                      : AppColors.info,
                  actionLabel: 'Open Existing Map',
                  onAction: widget.onOpenMap,
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          _PlannerSection(
            title: 'Engineer Recommendation',
            icon: Icons.engineering_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _PlannerNotice(
                  icon: Icons.info_outline,
                  message:
                      'Ranking uses attendance, duty state, active visits, live GPS, direct proximity, pending workload, current shift, completed visits, overtime, and completion rate. Employee service-centre membership is not stored, so no centre affiliation is claimed.',
                  color: AppColors.info,
                ),
                const SizedBox(height: 9),
                if (recommendations.isEmpty)
                  Text(
                    'No employees are available in the existing users collection.',
                    style: AppTextStyles.caption,
                  )
                else
                  ...recommendations.take(8).map(
                    (recommendation) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: _EngineerRecommendationTile(
                        recommendation: recommendation,
                        selected:
                            recommendation.employee.uid == _selectedEngineerId,
                        onTap: () {
                          setState(() {
                            _selectedEngineerId = recommendation.employee.uid;
                          });
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageTab() {
    final recommendations = _rankEngineers();
    final selected = _selectedRecommendation;
    final alternatives = recommendations
        .where((item) => item.employee.uid != _selectedEngineerId)
        .take(3)
        .map((item) => _employeeName(item.employee))
        .join(', ');
    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 4, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PlannerSection(
            title: 'Compact Dispatch Card',
            icon: Icons.dashboard_customize_outlined,
            child: _PlannerGrid(
              children: [
                _PlannerReadOnlyField(
                  label: 'Nearest Centre',
                  value: _selectedCentre?.name ?? '',
                  icon: Icons.business_outlined,
                ),
                _PlannerReadOnlyField(
                  label: 'Direct Distance',
                  value: _directCentreDistance == null
                      ? ''
                      : '${_directCentreDistance!.toStringAsFixed(1)} km',
                  icon: Icons.straighten_outlined,
                ),
                const _PlannerReadOnlyField(
                  label: 'Road Distance / ETA',
                  value: 'Requires Google Directions API',
                  icon: Icons.route_outlined,
                ),
                _PlannerReadOnlyField(
                  label: 'Suggested Engineer',
                  value: selected == null
                      ? ''
                      : '${_employeeName(selected.employee)} - ${selected.recommendation}',
                  icon: Icons.engineering_outlined,
                ),
                _PlannerReadOnlyField(
                  label: 'Alternative Engineers',
                  value: alternatives,
                  icon: Icons.groups_outlined,
                ),
                const _PlannerReadOnlyField(
                  label: 'Travel Cost Estimate',
                  value: 'Requires route and cost policy',
                  icon: Icons.currency_rupee,
                ),
                _PlannerReadOnlyField(
                  label: 'Visit Priority',
                  value: _priority,
                  icon: Icons.priority_high,
                ),
                _PlannerReadOnlyField(
                  label: 'Schedule Status',
                  value: _selectedEngineer == null
                      ? 'Pending Dispatch'
                      : selected?.available == true
                      ? 'Ready to Assign'
                      : 'Admin Override',
                  icon: Icons.event_available_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          _PlannerSection(
            title: 'Engineer Visit Package',
            icon: Icons.inventory_2_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PackageRow('Dealer', _dealerNameController.text),
                _PackageRow('Dealer Address', _dealerAddressController.text),
                _PackageRow('Dealer PIN', _dealerPinController.text),
                _PackageRow('Complaint', _complaintSummaryController.text),
                _PackageRow('Priority', _priority),
                _PackageRow('Customer', _customerNameController.text),
                _PackageRow('Customer Contact', _customerContactController.text),
                _PackageRow(
                  'Preferred Visit',
                  _preferredVisitDate == null
                      ? ''
                      : _formatDate(_preferredVisitDate!),
                ),
                _PackageRow(
                  'Expected Duration',
                  _expectedDurationController.text.trim().isEmpty
                      ? ''
                      : '${_expectedDurationController.text.trim()} minutes',
                ),
                _PackageRow('Internal Notes', _internalNotesController.text),
                _PackageRow(
                  'Checklist',
                  '${technicalChecklistDefinitions.length} technical checks available',
                ),
                _PackageRow(
                  'Map Coordinates',
                  _dealerLatitude == null || _dealerLongitude == null
                      ? 'Requires Google Geocoding API'
                      : '${_dealerLatitude!.toStringAsFixed(5)}, ${_dealerLongitude!.toStringAsFixed(5)}',
                ),
                const _PackageRow(
                  'Navigation',
                  'Requires Google Directions/Routes API',
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: widget.onOpenMap,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Open Existing Map'),
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

class _PlannerSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _PlannerSection({
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

class _PlannerGrid extends StatelessWidget {
  final List<Widget> children;

  const _PlannerGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 2 : 1;
        const gap = 9.0;
        final itemWidth =
            (constraints.maxWidth - ((columns - 1) * gap)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: children.map((child) {
            final fullWidth = child is _PlannerTextField && child.spanFullWidth;
            return SizedBox(
              width: fullWidth ? constraints.maxWidth : itemWidth,
              child: child,
            );
          }).toList(growable: false),
        );
      },
    );
  }
}

class _PlannerTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool spanFullWidth;

  const _PlannerTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.spanFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 19),
        isDense: true,
      ),
    );
  }
}

class _PlannerDropdown extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final String Function(String value)? labelFor;

  const _PlannerDropdown({
    required this.label,
    required this.value,
    required this.icon,
    required this.options,
    required this.onChanged,
    this.labelFor,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$label:$value'),
      initialValue: options.contains(value) ? value : options.first,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 19),
        isDense: true,
      ),
      items: options
          .map(
            (option) => DropdownMenuItem(
              value: option,
              child: Text(
                labelFor?.call(option) ?? option,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(growable: false),
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}

class _PlannerDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  const _PlannerDateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_month_outlined, size: 19),
          suffixIcon: const Icon(Icons.chevron_right, size: 19),
          isDense: true,
        ),
        child: Text(value == null ? 'Select date' : _formatDate(value!)),
      ),
    );
  }
}

class _PlannerReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _PlannerReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final missing = value.trim().isEmpty;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 19),
        isDense: true,
        enabled: false,
      ),
      child: Text(
        missing ? 'Not available' : value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: missing ? AppColors.textDisabled : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _PlannerNotice extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _PlannerNotice({
    required this.icon,
    required this.message,
    required this.color,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(height: 1.35),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 6),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _DispatchMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DispatchMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withAlpha(18)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(label, style: AppTextStyles.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EngineerRecommendationTile extends StatelessWidget {
  final EngineerDispatchRecommendation recommendation;
  final bool selected;
  final VoidCallback onTap;

  const _EngineerRecommendationTile({
    required this.recommendation,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (recommendation.recommendation) {
      'Best Choice' => AppColors.success,
      'Good' => AppColors.info,
      'Busy' => AppColors.warning,
      _ => AppColors.textSecondary,
    };
    final distance = recommendation.directDistanceKm;
    final metrics = <String>[
      recommendation.onBreak
          ? 'On break'
          : recommendation.onDuty
          ? 'On duty'
          : 'Off duty',
      '${recommendation.activeVisits} active',
      '${recommendation.pendingWorkload} pending',
      '${recommendation.completedToday} completed today',
      '${recommendation.completionRate.toStringAsFixed(0)}% completion',
      _durationLabel(recommendation.currentShift),
      if (recommendation.travelling) 'Travelling',
      if (recommendation.overtime) 'Overtime',
      if (distance != null) '${distance.toStringAsFixed(1)} km direct',
    ];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected ? color.withAlpha(15) : Colors.white.withAlpha(5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? color.withAlpha(100) : Colors.white.withAlpha(18),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withAlpha(30),
                child: Text(
                  _employeeInitials(recommendation.employee),
                  style: AppTextStyles.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _employeeName(recommendation.employee),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        PremiumStatusChip(
                          label: recommendation.recommendation,
                          color: color,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        for (var index = 0; index < 4; index++)
                          Icon(
                            index < recommendation.stars
                                ? Icons.star
                                : Icons.star_border,
                            size: 14,
                            color: color,
                          ),
                        const SizedBox(width: 6),
                        Text(
                          'Score ${recommendation.score.toStringAsFixed(0)}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      metrics.join(' | '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 20,
                color: selected ? color : AppColors.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackageRow extends StatelessWidget {
  final String label;
  final String value;

  const _PackageRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final missing = value.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: AppTextStyles.caption),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              missing ? 'Not provided' : value,
              style: AppTextStyles.bodyMedium.copyWith(
                color: missing ? AppColors.textDisabled : AppColors.textPrimary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _normalizedPriority(String value) {
  switch (value.trim().toLowerCase()) {
    case 'critical':
    case 'urgent':
      return 'Critical';
    case 'high':
      return 'High';
    case 'low':
      return 'Low';
    default:
      return 'Medium';
  }
}

String _complaintIssueCategory(ComplaintModel? complaint) {
  if (complaint == null) return 'Other';
  final component = complaint.affectedComponent.trim();
  if (component.isNotEmpty) return component;
  final category = complaint.complaintCategory.trim();
  return category.isEmpty ? 'Other' : category;
}

String _employeeName(EmployeeModel employee) {
  if (employee.name.trim().isNotEmpty) return employee.name.trim();
  if (employee.email.trim().isNotEmpty) return employee.email.trim();
  return employee.uid.length <= 8
      ? employee.uid
      : employee.uid.substring(0, 8);
}

String _employeeInitials(EmployeeModel employee) {
  final source = _employeeName(employee).trim();
  if (source.isEmpty) return '--';
  final parts = source.split(RegExp(r'\s+'));
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String _shortText(String value, int maximum) {
  final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) return 'No summary';
  if (normalized.length <= maximum) return normalized;
  return '${normalized.substring(0, maximum - 3)}...';
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _durationLabel(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  return '${hours}h ${minutes}m shift';
}
