import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/employee_model.dart';
import '../../core/models/live_location_model.dart';
import '../../core/services/employee_service.dart';
import '../../core/services/live_location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/premium_widgets.dart';
import '../attendance/models/attendance_model.dart';
import '../attendance/services/attendance_service.dart';
import '../complaints/controllers/complaint_controller.dart';
import '../map/map_screen.dart';
import 'controllers/customer_visit_controller.dart';
import 'customer_visit_detail_screen.dart';
import 'enterprise_visits_dashboard.dart';
import 'models/customer_visit_model.dart';
import 'services/customer_visit_service.dart';
import 'smart_visit_planner_dialog.dart';

class CustomerVisitScreen extends StatefulWidget {
  const CustomerVisitScreen({super.key});

  @override
  State<CustomerVisitScreen> createState() => _CustomerVisitScreenState();
}

class _CustomerVisitScreenState extends State<CustomerVisitScreen> {
  List<CustomerVisitModel> _visits = const <CustomerVisitModel>[];
  List<EmployeeModel> _employees = const <EmployeeModel>[];
  List<AttendanceModel> _attendance = const <AttendanceModel>[];
  Map<String, LiveLocationModel> _liveLocations =
      const <String, LiveLocationModel>{};

  StreamSubscription<void>? _visitSubscription;
  StreamSubscription<void>? _attendanceSubscription;
  StreamSubscription<List<LiveLocationModel>>? _liveLocationSubscription;
  Timer? _visitReloadDebounce;
  Timer? _attendanceReloadDebounce;

  bool _loading = true;
  bool _refreshing = false;
  bool _loadInProgress = false;
  bool _visitReloadInProgress = false;
  bool _attendanceReloadInProgress = false;
  bool _attendanceReloadPending = false;
  bool _realtimeConnected = false;
  Object? _loadError;
  DateTime _operationsDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    unawaited(_loadOperations(showLoading: true));
    _subscribeToOperations();
  }

  @override
  void dispose() {
    _visitReloadDebounce?.cancel();
    _attendanceReloadDebounce?.cancel();
    unawaited(_visitSubscription?.cancel());
    unawaited(_attendanceSubscription?.cancel());
    unawaited(_liveLocationSubscription?.cancel());
    super.dispose();
  }

  void _subscribeToOperations() {
    _visitSubscription = CustomerVisitService.watchVisitChanges().listen(
      (_) {
        if (mounted && !_realtimeConnected) {
          setState(() {
            _realtimeConnected = true;
          });
        }
        _scheduleVisitRefresh();
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _realtimeConnected = false;
        });
      },
    );

    _attendanceSubscription = AttendanceService.watchAttendanceChanges().listen(
      (_) => _scheduleAttendanceRefresh(),
      onError: (_) {},
    );

    _liveLocationSubscription = LiveLocationService.watchLiveLocations().listen(
      (locations) {
        if (!mounted) return;
        setState(() {
          _liveLocations = {
            for (final location in locations) location.userId: location,
          };
        });
      },
      onError: (_) {},
    );
  }

  void _scheduleVisitRefresh() {
    _visitReloadDebounce?.cancel();
    _visitReloadDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      unawaited(_reloadVisits());
    });
  }

  void _scheduleAttendanceRefresh() {
    _attendanceReloadDebounce?.cancel();
    _attendanceReloadDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      unawaited(_reloadAttendance());
    });
  }

  Future<void> _loadOperations({bool showLoading = false}) async {
    if (_loadInProgress) return;
    _loadInProgress = true;

    if (mounted) {
      setState(() {
        if (showLoading && _visits.isEmpty) _loading = true;
        if (!showLoading) _refreshing = true;
        _loadError = null;
      });
    }

    try {
      final selectedDate = _operationsDate;
      final visitsFuture = CustomerVisitController.loadAllVisits();
      final employeesFuture = _loadEmployeesSafely();
      final attendanceFuture = _loadAttendanceSafely(selectedDate);
      final visits = await visitsFuture;
      final employees = await employeesFuture;
      final attendance = await attendanceFuture;

      if (!mounted) return;
      final attendanceMatchesSelection = _sameDate(
        selectedDate,
        _operationsDate,
      );
      setState(() {
        _visits = visits;
        _employees = employees;
        if (attendanceMatchesSelection) {
          _attendance = attendance;
        } else {
          _attendanceReloadPending = true;
        }
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
      });
    } finally {
      _loadInProgress = false;
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
        if (_attendanceReloadPending && !_attendanceReloadInProgress) {
          _attendanceReloadPending = false;
          unawaited(_reloadAttendance());
        }
      }
    }
  }

  Future<void> _refresh() {
    return _loadOperations();
  }

  Future<List<EmployeeModel>> _loadEmployeesSafely() async {
    try {
      return await EmployeeService.fetchAllEmployees();
    } catch (_) {
      return const <EmployeeModel>[];
    }
  }

  Future<List<AttendanceModel>> _loadAttendanceSafely(DateTime day) async {
    try {
      return await AttendanceService.fetchAttendanceForDate(day);
    } catch (_) {
      return const <AttendanceModel>[];
    }
  }

  Future<void> _reloadVisits() async {
    if (_loadInProgress || _visitReloadInProgress) return;
    _visitReloadInProgress = true;
    try {
      final visits = await CustomerVisitController.loadAllVisits();
      if (!mounted) return;
      setState(() {
        _visits = visits;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _realtimeConnected = false;
      });
    } finally {
      _visitReloadInProgress = false;
    }
  }

  Future<void> _reloadAttendance() async {
    if (_loadInProgress) {
      _attendanceReloadPending = true;
      return;
    }
    if (_attendanceReloadInProgress) {
      _attendanceReloadPending = true;
      return;
    }
    _attendanceReloadInProgress = true;
    final requestedDate = _operationsDate;
    try {
      final records = await AttendanceService.fetchAttendanceForDate(
        requestedDate,
      );
      if (!mounted || !_sameDate(requestedDate, _operationsDate)) return;
      setState(() {
        _attendance = records;
      });
    } catch (_) {
      // Attendance is supplementary; visit operations remain available.
    } finally {
      _attendanceReloadInProgress = false;
      if (_attendanceReloadPending && mounted) {
        _attendanceReloadPending = false;
        unawaited(_reloadAttendance());
      }
    }
  }

  Future<void> _openVisit(CustomerVisitModel visit) async {
    final updatedVisit = await Navigator.of(context).push<CustomerVisitModel>(
      MaterialPageRoute(
        builder: (_) => CustomerVisitDetailScreen(
          visit: visit,
          operationVisits: _visits,
          employees: _employees,
        ),
      ),
    );

    if (!mounted || updatedVisit == null) return;
    await _refresh();
  }

  Future<void> _changeOperationsDate(DateTime date) async {
    final selectedDate = DateTime(date.year, date.month, date.day);
    if (_sameDate(_operationsDate, selectedDate)) return;

    setState(() {
      _operationsDate = selectedDate;
      _attendance = const <AttendanceModel>[];
    });
    await _reloadAttendance();
  }

  bool _sameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  Future<void> _duplicateVisit(CustomerVisitModel visit) async {
    try {
      await CustomerVisitController.createVisit(
        customerName: visit.customerName,
        customerAddress: visit.customerAddress,
        customerPhone: visit.customerPhone,
        purpose: visit.purpose,
        notes: visit.notes,
        vehicleDetails: visit.vehicleDetails,
        motorSerialNumber: visit.motorSerialNumber,
        controllerSerialNumber: visit.controllerSerialNumber,
        warrantyStatus: visit.warrantyStatus,
        issueCategory: visit.issueCategory,
        issueDescription: visit.issueDescription,
        partsUsed: visit.partsUsed,
        technicianNotes: visit.technicianNotes,
      );
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visit duplicated as a new visit.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Visit could not be duplicated. Check the connection and retry.',
          ),
        ),
      );
    }
  }

  Future<void> _assignEngineer(
    CustomerVisitModel visit,
    EmployeeModel engineer,
  ) async {
    try {
      final updatedVisit = await CustomerVisitController.assignEngineer(
        visit: visit,
        engineerId: engineer.uid,
      );
      var complaintLinkFailed = false;
      if (updatedVisit.complaintId.isNotEmpty) {
        try {
          final complaints = await ComplaintController.loadAllComplaints();
          final complaintIndex = complaints.indexWhere(
            (item) => item.id == updatedVisit.complaintId,
          );
          if (complaintIndex >= 0) {
            await ComplaintController.linkVisit(
              complaint: complaints[complaintIndex],
              visitId: updatedVisit.id,
              visitStatus: 'assigned',
            );
          } else {
            complaintLinkFailed = true;
          }
        } catch (_) {
          complaintLinkFailed = true;
        }
      }
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      final engineerLabel = engineer.name.trim().isNotEmpty
          ? engineer.name.trim()
          : engineer.email.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            complaintLinkFailed
                ? 'Visit assigned, but the linked complaint status could not be updated.'
                : engineerLabel.isEmpty
                ? 'Visit assignment updated.'
                : 'Visit assigned to $engineerLabel.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Engineer assignment could not be saved. Check the connection and retry.',
          ),
        ),
      );
    }
  }

  Future<void> _showCreateVisitDialog() async {
    final now = DateTime.now();
    final planningAttendance = _sameDate(_operationsDate, now)
        ? _attendance
        : await _loadAttendanceSafely(now);
    if (!mounted) return;
    final result = await SmartVisitPlannerDialog.show(
      context,
      visits: _visits,
      employees: _employees,
      attendance: planningAttendance,
      liveLocationsByUserId: _liveLocations,
      onOpenMap: _openMapFoundation,
    );
    if (!mounted || result == null) return;
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.complaintLinkFailed
              ? 'Visit created, but the complaint link could not be updated.'
              : result.visit.userId.isEmpty
              ? 'Visit plan saved as pending dispatch.'
              : 'Visit package created and assigned.',
        ),
      ),
    );
  }

  void _openMapFoundation() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MapScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Visit Operations', style: AppTextStyles.headingSmall),
      ),
      body: _loading && _visits.isEmpty
          ? const PremiumLoadingState(label: 'Loading visit operations')
          : _loadError != null && _visits.isEmpty
          ? PremiumErrorState(
              title: 'Visit operations could not be loaded.',
              error: 'Unable to load data. Check the connection and retry.',
              onRetry: _refresh,
            )
          : EnterpriseVisitsDashboard(
              visits: _visits,
              employees: _employees,
              attendance: _attendance,
              liveLocationsByUserId: _liveLocations,
              selectedDate: _operationsDate,
              realtimeConnected: _realtimeConnected,
              refreshing: _refreshing,
              onRefresh: _refresh,
              onDateChanged: _changeOperationsDate,
              onCreateVisit: _showCreateVisitDialog,
              onOpenVisit: _openVisit,
              onAssignEngineer: _assignEngineer,
              onDuplicateVisit: _duplicateVisit,
              onOpenMap: _openMapFoundation,
            ),
    );
  }
}
