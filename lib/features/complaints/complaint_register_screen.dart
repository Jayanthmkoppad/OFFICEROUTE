import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/premium_widgets.dart';
import '../customer_visits/controllers/customer_visit_controller.dart';
import 'controllers/complaint_controller.dart';
import 'models/complaint_model.dart';

class ComplaintRegisterScreen extends StatefulWidget {
  const ComplaintRegisterScreen({super.key});

  @override
  State<ComplaintRegisterScreen> createState() =>
      _ComplaintRegisterScreenState();
}

class _ComplaintRegisterScreenState extends State<ComplaintRegisterScreen> {
  late Future<List<ComplaintModel>> _complaintsFuture;

  final TextEditingController _customerNameController =
      TextEditingController();
  final TextEditingController _customerIdController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _vehicleNumberController =
      TextEditingController();
  final TextEditingController _vehicleModelController = TextEditingController();
  final TextEditingController _vehicleConfigurationController =
      TextEditingController();
  final TextEditingController _motorSerialController = TextEditingController();
  final TextEditingController _motorConfigurationController =
      TextEditingController();
  final TextEditingController _controllerSerialController =
      TextEditingController();
  final TextEditingController _controllerConfigurationController =
      TextEditingController();
  final TextEditingController _batterySerialController =
      TextEditingController();
  final TextEditingController _chargerSerialController =
      TextEditingController();
  final TextEditingController _purchaseDateController =
      TextEditingController();
  final TextEditingController _invoiceController = TextEditingController();
  final TextEditingController _dealerController = TextEditingController();
  final TextEditingController _dealerContactController =
      TextEditingController();
  final TextEditingController _warrantyExpiryController =
      TextEditingController();
  final TextEditingController _issueController = TextEditingController();
  final TextEditingController _plannedDateController = TextEditingController();
  final TextEditingController _plannedTimeController = TextEditingController();

  String _warrantyStatus = 'Unknown';
  String _oemName = 'Other';
  String _complaintCategory = 'General';
  String _complaintPriority = 'Medium';
  String _affectedComponent = 'Other';
  bool _visitRequired = false;
  double? _latitude;
  double? _longitude;
  bool _isSaving = false;
  bool _isCapturingGps = false;
  bool _isVoiceRecording = false;
  bool _isVoicePlaying = false;
  int _voiceRecordingSeconds = 0;
  String? _voiceNoteReference;
  Timer? _voiceTimer;
  final List<String> _photoReferences = <String>[];
  final List<String> _videoReferences = <String>[];

  @override
  void initState() {
    super.initState();
    _complaintsFuture = ComplaintController.loadMyComplaints();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerIdController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _vehicleNumberController.dispose();
    _vehicleModelController.dispose();
    _vehicleConfigurationController.dispose();
    _motorSerialController.dispose();
    _motorConfigurationController.dispose();
    _controllerSerialController.dispose();
    _controllerConfigurationController.dispose();
    _batterySerialController.dispose();
    _chargerSerialController.dispose();
    _purchaseDateController.dispose();
    _invoiceController.dispose();
    _dealerController.dispose();
    _dealerContactController.dispose();
    _warrantyExpiryController.dispose();
    _issueController.dispose();
    _plannedDateController.dispose();
    _plannedTimeController.dispose();
    _voiceTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _complaintsFuture = ComplaintController.loadMyComplaints();
    });
    await _complaintsFuture;
  }

  Future<void> _captureGps() async {
    if (_isCapturingGps) return;

    setState(() {
      _isCapturingGps = true;
    });

    try {
      final gps = await ComplaintController.getCurrentGps();
      if (!mounted) return;
      setState(() {
        _latitude = gps.latitude;
        _longitude = gps.longitude;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GPS capture failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCapturingGps = false;
        });
      }
    }
  }

  void _startVoiceRecording() {
    if (_isVoiceRecording) return;

    _voiceTimer?.cancel();
    setState(() {
      _isVoiceRecording = true;
      _isVoicePlaying = false;
      _voiceRecordingSeconds = 0;
      _voiceNoteReference = null;
    });

    _voiceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isVoiceRecording) return;
      setState(() {
        _voiceRecordingSeconds += 1;
      });
    });
  }

  void _stopVoiceRecording() {
    if (!_isVoiceRecording) return;

    _voiceTimer?.cancel();
    setState(() {
      _isVoiceRecording = false;
      _voiceRecordingSeconds = _voiceRecordingSeconds == 0
          ? 1
          : _voiceRecordingSeconds;
      _voiceNoteReference =
          'voice-note-${DateTime.now().millisecondsSinceEpoch}.m4a';
    });
  }

  void _playVoiceRecording() {
    if (_voiceNoteReference == null || _isVoiceRecording || _isVoicePlaying) {
      return;
    }

    final playbackSeconds = _voiceRecordingSeconds < 1
        ? 1
        : _voiceRecordingSeconds > 5
        ? 5
        : _voiceRecordingSeconds;

    setState(() {
      _isVoicePlaying = true;
    });

    Future<void>.delayed(Duration(seconds: playbackSeconds), () {
      if (!mounted) return;
      setState(() {
        _isVoicePlaying = false;
      });
    });
  }

  void _deleteVoiceRecording() {
    _voiceTimer?.cancel();
    setState(() {
      _isVoiceRecording = false;
      _isVoicePlaying = false;
      _voiceRecordingSeconds = 0;
      _voiceNoteReference = null;
    });
  }

  void _capturePhoto() {
    _addPhotoReference('captured-photo-${DateTime.now().millisecondsSinceEpoch}.jpg');
  }

  void _selectPhotoFromGallery() {
    _addPhotoReference('gallery-photo-${DateTime.now().millisecondsSinceEpoch}.jpg');
  }

  void _addPhotoReference(String reference) {
    setState(() {
      _photoReferences.add(reference);
    });
  }

  void _removePhotoReference(String reference) {
    setState(() {
      _photoReferences.remove(reference);
    });
  }

  void _recordVideo() {
    _addVideoReference('recorded-video-${DateTime.now().millisecondsSinceEpoch}.mp4');
  }

  void _selectVideo() {
    _addVideoReference('selected-video-${DateTime.now().millisecondsSinceEpoch}.mp4');
  }

  void _addVideoReference(String reference) {
    setState(() {
      _videoReferences.add(reference);
    });
  }

  void _removeVideoReference(String reference) {
    setState(() {
      _videoReferences.remove(reference);
    });
  }

  Future<void> _saveComplaint() async {
    if (_isSaving) return;

    final customerName = _customerNameController.text.trim();
    final contactNumber = _contactController.text.trim();
    final vehicleNumber = _vehicleNumberController.text.trim();
    final complaintCategory = _complaintCategory.trim();
    final issue = _issueController.text.trim();

    if (customerName.isEmpty ||
        contactNumber.isEmpty ||
        vehicleNumber.isEmpty ||
        complaintCategory.isEmpty ||
        issue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Customer name, contact number, vehicle number, category, and issue are required.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final complaint = await ComplaintController.registerComplaint(
        customerName: customerName,
        customerId: _customerIdController.text.trim(),
        contactNumber: contactNumber,
        address: _addressController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        vehicleNumber: vehicleNumber,
        vehicleModel: _vehicleModelController.text.trim(),
        motorSerialNumber: _motorSerialController.text.trim(),
        controllerSerialNumber: _controllerSerialController.text.trim(),
        batterySerialNumber: _batterySerialController.text.trim(),
        chargerSerialNumber: _chargerSerialController.text.trim(),
        vehicleConfiguration: _vehicleConfigurationController.text.trim(),
        motorConfiguration: _motorConfigurationController.text.trim(),
        controllerConfiguration:
            _controllerConfigurationController.text.trim(),
        purchaseDate: _parseDate(_purchaseDateController.text),
        invoiceNumber: _invoiceController.text.trim(),
        dealerName: _dealerController.text.trim(),
        dealerContactNumber: _dealerContactController.text.trim(),
        oemName: _oemName,
        warrantyStatus: _warrantyStatus,
        warrantyExpiryDate: _parseDate(_warrantyExpiryController.text),
        complaintCategory: complaintCategory,
        complaintPriority: _complaintPriority,
        affectedComponent: _affectedComponent,
        customerStatedIssue: issue,
        customerVoiceNote: _voiceNoteReference ?? '',
        photoUrls: List<String>.unmodifiable(_photoReferences),
        videoUrls: List<String>.unmodifiable(_videoReferences),
        visitRequired: _visitRequired,
        plannedVisitDateTime: _plannedVisitDateTime(),
      );

      var visitLinked = false;
      Object? visitLinkError;
      if (_visitRequired) {
        try {
          final visit = await CustomerVisitController.createVisit(
            customerName: complaint.customerName,
            customerAddress: complaint.address,
            customerPhone: complaint.contactNumber,
            purpose: 'Complaint: ${complaint.complaintCategory}',
            notes: 'Linked complaint ${complaint.id}',
            vehicleDetails: _vehicleDetailsForVisit(complaint),
            motorSerialNumber: complaint.motorSerialNumber,
            controllerSerialNumber: complaint.controllerSerialNumber,
            warrantyStatus: complaint.warrantyStatus,
            issueCategory: complaint.complaintCategory,
            issueDescription: complaint.customerStatedIssue,
            partsUsed: const <String>[],
            technicianNotes: '',
          );

          await ComplaintController.linkVisit(
            complaint: complaint,
            visitId: visit.id,
            visitStatus: visit.status,
          );
          visitLinked = true;
        } catch (error) {
          visitLinkError = error;
        }
      }

      if (!mounted) return;
      _clearForm();
      await _refresh();
      if (!mounted) return;

      final message = _visitRequired
          ? visitLinked
                ? 'Complaint saved and visit linked.'
                : 'Complaint saved. Visit link failed: $visitLinkError'
          : 'Complaint saved.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Complaint save failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _clearForm() {
    for (final controller in [
      _customerNameController,
      _customerIdController,
      _contactController,
      _addressController,
      _vehicleNumberController,
      _vehicleModelController,
      _vehicleConfigurationController,
      _motorSerialController,
      _motorConfigurationController,
      _controllerSerialController,
      _controllerConfigurationController,
      _batterySerialController,
      _chargerSerialController,
      _purchaseDateController,
      _invoiceController,
      _dealerController,
      _dealerContactController,
      _warrantyExpiryController,
      _issueController,
      _plannedDateController,
      _plannedTimeController,
    ]) {
      controller.clear();
    }

    _voiceTimer?.cancel();
    setState(() {
      _warrantyStatus = 'Unknown';
      _oemName = 'Other';
      _complaintCategory = 'General';
      _complaintPriority = 'Medium';
      _affectedComponent = 'Other';
      _visitRequired = false;
      _latitude = null;
      _longitude = null;
      _isVoiceRecording = false;
      _isVoicePlaying = false;
      _voiceRecordingSeconds = 0;
      _voiceNoteReference = null;
      _photoReferences.clear();
      _videoReferences.clear();
    });
  }

  DateTime? _plannedVisitDateTime() {
    final date = _parseDate(_plannedDateController.text);
    if (date == null) return null;

    final parts = _plannedTimeController.text.trim().split(':');
    if (parts.length != 2) return date;

    final hour = int.tryParse(parts.first);
    final minute = int.tryParse(parts.last);
    if (hour == null || minute == null) return date;

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Complaint Register', style: AppTextStyles.headingSmall),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: _refresh,
        child: FutureBuilder<List<ComplaintModel>>(
          future: _complaintsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const PremiumLoadingState(label: 'Loading complaints');
            }

            if (snapshot.hasError) {
              return PremiumErrorState(
                title: 'Complaints failed to load.',
                error: snapshot.error,
                onRetry: _refresh,
              );
            }

            final complaints = snapshot.data ?? const <ComplaintModel>[];
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ComplaintHeader(complaints: complaints),
                      const SizedBox(height: 16),
                      _ComplaintFormCard(
                        customerNameController: _customerNameController,
                        customerIdController: _customerIdController,
                        contactController: _contactController,
                        addressController: _addressController,
                        vehicleNumberController: _vehicleNumberController,
                        vehicleModelController: _vehicleModelController,
                        vehicleConfigurationController:
                            _vehicleConfigurationController,
                        motorSerialController: _motorSerialController,
                        motorConfigurationController:
                            _motorConfigurationController,
                        controllerSerialController:
                            _controllerSerialController,
                        controllerConfigurationController:
                            _controllerConfigurationController,
                        batterySerialController: _batterySerialController,
                        chargerSerialController: _chargerSerialController,
                        purchaseDateController: _purchaseDateController,
                        invoiceController: _invoiceController,
                        dealerController: _dealerController,
                        dealerContactController: _dealerContactController,
                        warrantyExpiryController: _warrantyExpiryController,
                        issueController: _issueController,
                        plannedDateController: _plannedDateController,
                        plannedTimeController: _plannedTimeController,
                        warrantyStatus: _warrantyStatus,
                        oemName: _oemName,
                        complaintCategory: _complaintCategory,
                        complaintPriority: _complaintPriority,
                        affectedComponent: _affectedComponent,
                        visitRequired: _visitRequired,
                        latitude: _latitude,
                        longitude: _longitude,
                        isCapturingGps: _isCapturingGps,
                        isSaving: _isSaving,
                        isVoiceRecording: _isVoiceRecording,
                        isVoicePlaying: _isVoicePlaying,
                        voiceRecordingSeconds: _voiceRecordingSeconds,
                        voiceNoteReference: _voiceNoteReference,
                        photoReferences: _photoReferences,
                        videoReferences: _videoReferences,
                        onWarrantyChanged: (value) {
                          setState(() {
                            _warrantyStatus = value;
                          });
                        },
                        onOemChanged: (value) {
                          setState(() {
                            _oemName = value;
                          });
                        },
                        onCategoryChanged: (value) {
                          setState(() {
                            _complaintCategory = value;
                          });
                        },
                        onPriorityChanged: (value) {
                          setState(() {
                            _complaintPriority = value;
                          });
                        },
                        onAffectedComponentChanged: (value) {
                          setState(() {
                            _affectedComponent = value;
                          });
                        },
                        onVisitRequiredChanged: (value) {
                          setState(() {
                            _visitRequired = value;
                          });
                        },
                        onCaptureGps: _captureGps,
                        onStartVoiceRecording: _startVoiceRecording,
                        onStopVoiceRecording: _stopVoiceRecording,
                        onPlayVoiceRecording: _playVoiceRecording,
                        onDeleteVoiceRecording: _deleteVoiceRecording,
                        onCapturePhoto: _capturePhoto,
                        onSelectPhoto: _selectPhotoFromGallery,
                        onRemovePhoto: _removePhotoReference,
                        onRecordVideo: _recordVideo,
                        onSelectVideo: _selectVideo,
                        onRemoveVideo: _removeVideoReference,
                        onSave: _saveComplaint,
                      ),
                      const SizedBox(height: 16),
                      _ComplaintHistoryCard(complaints: complaints),
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

class _ComplaintHeader extends StatelessWidget {
  final List<ComplaintModel> complaints;

  const _ComplaintHeader({required this.complaints});

  @override
  Widget build(BuildContext context) {
    final open = complaints
        .where((complaint) => complaint.status != 'closed')
        .length;
    final visitRequired = complaints
        .where((complaint) => complaint.visitRequired)
        .length;
    final closed = complaints
        .where((complaint) => complaint.status == 'closed')
        .length;

    return PremiumCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            icon: Icons.assignment_outlined,
            title: 'Complaint Register',
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 620;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isWide ? 4 : 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: isWide ? 1.8 : 1.45,
                children: [
                  _MetricTile(
                    label: 'Total',
                    value: complaints.length.toString(),
                    color: AppColors.textPrimary,
                  ),
                  _MetricTile(
                    label: 'Open',
                    value: open.toString(),
                    color: AppColors.warning,
                  ),
                  _MetricTile(
                    label: 'Visit Required',
                    value: visitRequired.toString(),
                    color: AppColors.info,
                  ),
                  _MetricTile(
                    label: 'Closed',
                    value: closed.toString(),
                    color: AppColors.success,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ComplaintFormCard extends StatelessWidget {
  final TextEditingController customerNameController;
  final TextEditingController customerIdController;
  final TextEditingController contactController;
  final TextEditingController addressController;
  final TextEditingController vehicleNumberController;
  final TextEditingController vehicleModelController;
  final TextEditingController vehicleConfigurationController;
  final TextEditingController motorSerialController;
  final TextEditingController motorConfigurationController;
  final TextEditingController controllerSerialController;
  final TextEditingController controllerConfigurationController;
  final TextEditingController batterySerialController;
  final TextEditingController chargerSerialController;
  final TextEditingController purchaseDateController;
  final TextEditingController invoiceController;
  final TextEditingController dealerController;
  final TextEditingController dealerContactController;
  final TextEditingController warrantyExpiryController;
  final TextEditingController issueController;
  final TextEditingController plannedDateController;
  final TextEditingController plannedTimeController;
  final String warrantyStatus;
  final String oemName;
  final String complaintCategory;
  final String complaintPriority;
  final String affectedComponent;
  final bool visitRequired;
  final double? latitude;
  final double? longitude;
  final bool isCapturingGps;
  final bool isSaving;
  final bool isVoiceRecording;
  final bool isVoicePlaying;
  final int voiceRecordingSeconds;
  final String? voiceNoteReference;
  final List<String> photoReferences;
  final List<String> videoReferences;
  final ValueChanged<String> onWarrantyChanged;
  final ValueChanged<String> onOemChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onPriorityChanged;
  final ValueChanged<String> onAffectedComponentChanged;
  final ValueChanged<bool> onVisitRequiredChanged;
  final VoidCallback onCaptureGps;
  final VoidCallback onStartVoiceRecording;
  final VoidCallback onStopVoiceRecording;
  final VoidCallback onPlayVoiceRecording;
  final VoidCallback onDeleteVoiceRecording;
  final VoidCallback onCapturePhoto;
  final VoidCallback onSelectPhoto;
  final ValueChanged<String> onRemovePhoto;
  final VoidCallback onRecordVideo;
  final VoidCallback onSelectVideo;
  final ValueChanged<String> onRemoveVideo;
  final VoidCallback onSave;

  const _ComplaintFormCard({
    required this.customerNameController,
    required this.customerIdController,
    required this.contactController,
    required this.addressController,
    required this.vehicleNumberController,
    required this.vehicleModelController,
    required this.vehicleConfigurationController,
    required this.motorSerialController,
    required this.motorConfigurationController,
    required this.controllerSerialController,
    required this.controllerConfigurationController,
    required this.batterySerialController,
    required this.chargerSerialController,
    required this.purchaseDateController,
    required this.invoiceController,
    required this.dealerController,
    required this.dealerContactController,
    required this.warrantyExpiryController,
    required this.issueController,
    required this.plannedDateController,
    required this.plannedTimeController,
    required this.warrantyStatus,
    required this.oemName,
    required this.complaintCategory,
    required this.complaintPriority,
    required this.affectedComponent,
    required this.visitRequired,
    required this.latitude,
    required this.longitude,
    required this.isCapturingGps,
    required this.isSaving,
    required this.isVoiceRecording,
    required this.isVoicePlaying,
    required this.voiceRecordingSeconds,
    required this.voiceNoteReference,
    required this.photoReferences,
    required this.videoReferences,
    required this.onWarrantyChanged,
    required this.onOemChanged,
    required this.onCategoryChanged,
    required this.onPriorityChanged,
    required this.onAffectedComponentChanged,
    required this.onVisitRequiredChanged,
    required this.onCaptureGps,
    required this.onStartVoiceRecording,
    required this.onStopVoiceRecording,
    required this.onPlayVoiceRecording,
    required this.onDeleteVoiceRecording,
    required this.onCapturePhoto,
    required this.onSelectPhoto,
    required this.onRemovePhoto,
    required this.onRecordVideo,
    required this.onSelectVideo,
    required this.onRemoveVideo,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PremiumSectionHeader(
            icon: Icons.edit_note_outlined,
            title: 'Register New Complaint',
          ),
          const SizedBox(height: 16),
          _FormSection(
            title: 'Customer Information',
            children: [
              _ResponsiveRow(
                children: [
                  PremiumTextField(
                    controller: customerNameController,
                    label: 'Customer name',
                    icon: Icons.person_outline,
                  ),
                  PremiumTextField(
                    controller: customerIdController,
                    label: 'Customer ID',
                    icon: Icons.badge_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ResponsiveRow(
                children: [
                  PremiumTextField(
                    controller: contactController,
                    label: 'Contact number',
                    icon: Icons.call_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  PremiumTextField(
                    controller: addressController,
                    label: 'Address',
                    icon: Icons.location_on_outlined,
                    maxLines: 2,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _GpsCaptureRow(
                latitude: latitude,
                longitude: longitude,
                isCapturing: isCapturingGps,
                onCapture: onCaptureGps,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _FormSection(
            title: 'Dealer Information',
            children: [
              _ResponsiveRow(
                children: [
                  PremiumTextField(
                    controller: dealerController,
                    label: 'Dealer name',
                    icon: Icons.store_outlined,
                  ),
                  PremiumTextField(
                    controller: dealerContactController,
                    label: 'Dealer contact number',
                    icon: Icons.call_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _PremiumDropdown(
                label: 'OEM name',
                value: oemName,
                options: const [
                  'Ather',
                  'Bajaj',
                  'Hero Electric',
                  'Ola Electric',
                  'TVS',
                  'Other',
                ],
                onChanged: onOemChanged,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _FormSection(
            title: 'Machine / Vehicle Information',
            children: [
              _ResponsiveRow(
                children: [
                  PremiumTextField(
                    controller: vehicleNumberController,
                    label: 'Vehicle number',
                    icon: Icons.confirmation_number_outlined,
                  ),
                  PremiumTextField(
                    controller: vehicleModelController,
                    label: 'Vehicle model',
                    icon: Icons.two_wheeler_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              PremiumTextField(
                controller: vehicleConfigurationController,
                label: 'Vehicle configuration',
                icon: Icons.tune_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _ResponsiveRow(
                children: [
                  PremiumTextField(
                    controller: motorSerialController,
                    label: 'Motor serial number',
                    icon: Icons.settings_outlined,
                  ),
                  PremiumTextField(
                    controller: controllerSerialController,
                    label: 'Controller serial number',
                    icon: Icons.memory_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ResponsiveRow(
                children: [
                  PremiumTextField(
                    controller: batterySerialController,
                    label: 'Battery serial number',
                    icon: Icons.battery_charging_full_outlined,
                  ),
                  PremiumTextField(
                    controller: chargerSerialController,
                    label: 'Charger serial number',
                    icon: Icons.electrical_services_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ResponsiveRow(
                children: [
                  PremiumTextField(
                    controller: motorConfigurationController,
                    label: 'Motor configuration',
                    icon: Icons.settings_input_component_outlined,
                    maxLines: 3,
                  ),
                  PremiumTextField(
                    controller: controllerConfigurationController,
                    label: 'Controller configuration',
                    icon: Icons.developer_board_outlined,
                    maxLines: 3,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          _FormSection(
            title: 'Purchase Information',
            children: [
              _ResponsiveRow(
                children: [
                  PremiumTextField(
                    controller: purchaseDateController,
                    label: 'Purchase date (YYYY-MM-DD)',
                    icon: Icons.calendar_month_outlined,
                  ),
                  PremiumTextField(
                    controller: invoiceController,
                    label: 'Invoice number',
                    icon: Icons.receipt_long_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ResponsiveRow(
                children: [
                  _PremiumDropdown(
                    label: 'Warranty status',
                    value: warrantyStatus,
                    options: const [
                      'Under Warranty',
                      'Out of Warranty',
                      'Unknown',
                    ],
                    onChanged: onWarrantyChanged,
                  ),
                  PremiumTextField(
                    controller: warrantyExpiryController,
                    label: 'Warranty expiry date (YYYY-MM-DD)',
                    icon: Icons.event_available_outlined,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          _FormSection(
            title: 'Complaint Information',
            children: [
              _ResponsiveRow(
                children: [
                  _PremiumDropdown(
                    label: 'Complaint category',
                    value: complaintCategory,
                    options: const [
                      'General',
                      'Motor',
                      'Controller',
                      'Battery',
                      'Charger',
                      'Wiring',
                      'Software',
                      'Other',
                    ],
                    onChanged: onCategoryChanged,
                  ),
                  _PremiumDropdown(
                    label: 'Priority',
                    value: complaintPriority,
                    options: const ['Low', 'Medium', 'High', 'Critical'],
                    onChanged: onPriorityChanged,
                  ),
                  _PremiumDropdown(
                    label: 'Affected component',
                    value: affectedComponent,
                    options: const [
                      'Motor',
                      'Controller',
                      'Battery',
                      'Charger',
                      'Display',
                      'Wiring',
                      'Brake',
                      'Suspension',
                      'Other',
                    ],
                    onChanged: onAffectedComponentChanged,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              PremiumTextField(
                controller: issueController,
                label: 'Customer stated issue',
                icon: Icons.report_problem_outlined,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              _VoiceRecorderCard(
                isRecording: isVoiceRecording,
                isPlaying: isVoicePlaying,
                durationSeconds: voiceRecordingSeconds,
                reference: voiceNoteReference,
                onStart: onStartVoiceRecording,
                onStop: onStopVoiceRecording,
                onPlay: onPlayVoiceRecording,
                onDelete: onDeleteVoiceRecording,
              ),
              const SizedBox(height: 12),
              _PhotoPickerCard(
                references: photoReferences,
                onCapture: onCapturePhoto,
                onSelect: onSelectPhoto,
                onRemove: onRemovePhoto,
              ),
              const SizedBox(height: 12),
              _VideoPickerCard(
                references: videoReferences,
                onRecord: onRecordVideo,
                onSelect: onSelectVideo,
                onRemove: onRemoveVideo,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _FormSection(
            title: 'Visit Planning',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: visitRequired,
                onChanged: onVisitRequiredChanged,
                title: const Text('Visit required'),
                subtitle: const Text('Creates and links a planned visit.'),
              ),
              if (visitRequired) ...[
                const SizedBox(height: 12),
                _ResponsiveRow(
                  children: [
                    PremiumTextField(
                      controller: plannedDateController,
                      label: 'Planned visit date (YYYY-MM-DD)',
                      icon: Icons.calendar_month_outlined,
                    ),
                    PremiumTextField(
                      controller: plannedTimeController,
                      label: 'Planned visit time (HH:MM)',
                      icon: Icons.schedule_outlined,
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          if (isSaving) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 14),
          ],
          ElevatedButton.icon(
            onPressed: isSaving ? null : onSave,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Complaint'),
          ),
        ],
      ),
    );
  }
}

class _ComplaintHistoryCard extends StatelessWidget {
  final List<ComplaintModel> complaints;

  const _ComplaintHistoryCard({required this.complaints});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            icon: Icons.history_outlined,
            title: 'Recent Complaints',
          ),
          const SizedBox(height: 16),
          if (complaints.isEmpty)
            Text(
              'No complaints registered yet.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 0,
              ),
            )
          else
            Column(
              children: complaints.take(6).map((complaint) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ComplaintTile(complaint: complaint),
                );
              }).toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _ComplaintTile extends StatelessWidget {
  final ComplaintModel complaint;

  const _ComplaintTile({required this.complaint});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(complaint.status);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            PremiumIconChip(icon: Icons.assignment_outlined, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    complaint.customerName.isEmpty
                        ? 'Unnamed customer'
                        : complaint.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${complaint.complaintCategory} - ${complaint.complaintPriority}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(letterSpacing: 0),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    complaint.linkedVisitId.isEmpty
                        ? 'Visit: ${complaint.visitStatus}'
                        : 'Visit linked: ${complaint.linkedVisitId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            PremiumStatusChip(
              label: complaint.status.replaceAll('_', ' '),
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _FormSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title.toUpperCase(),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ResponsiveRow extends StatelessWidget {
  final List<Widget> children;

  const _ResponsiveRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              Expanded(child: children[index]),
              if (index != children.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _GpsCaptureRow extends StatelessWidget {
  final double? latitude;
  final double? longitude;
  final bool isCapturing;
  final VoidCallback onCapture;

  const _GpsCaptureRow({
    required this.latitude,
    required this.longitude,
    required this.isCapturing,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    final hasGps = latitude != null && longitude != null;
    final label = hasGps
        ? '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'
        : '--';

    return LayoutBuilder(
      builder: (context, constraints) {
        final details = Row(
          children: [
            PremiumIconChip(
              icon: Icons.gps_fixed_outlined,
              color: hasGps ? AppColors.success : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'GPS Location: $label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(letterSpacing: 0),
              ),
            ),
          ],
        );

        final button = OutlinedButton(
          onPressed: isCapturing ? null : onCapture,
          child: Text(isCapturing ? 'Capturing' : 'Capture GPS'),
        );

        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withAlpha(22)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: constraints.maxWidth < 460
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      details,
                      const SizedBox(height: 12),
                      button,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: details),
                      const SizedBox(width: 12),
                      button,
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _VoiceRecorderCard extends StatelessWidget {
  final bool isRecording;
  final bool isPlaying;
  final int durationSeconds;
  final String? reference;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  const _VoiceRecorderCard({
    required this.isRecording,
    required this.isPlaying,
    required this.durationSeconds,
    required this.reference,
    required this.onStart,
    required this.onStop,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasRecording = reference != null;
    final status = isRecording
        ? 'Recording ${_formatMediaDuration(durationSeconds)}'
        : isPlaying
        ? 'Playing ${_formatMediaDuration(durationSeconds)}'
        : hasRecording
        ? 'Saved ${_formatMediaDuration(durationSeconds)}'
        : 'No recording yet';

    return _MediaPanel(
      icon: Icons.mic_none_outlined,
      title: 'Customer Voice Note',
      subtitle: status,
      preview: hasRecording
          ? _MediaReferenceTile(
              icon: Icons.graphic_eq_outlined,
              label: reference!,
              onRemove: onDelete,
            )
          : null,
      children: [
        _MediaActionButton(
          icon: Icons.fiber_manual_record,
          label: 'Start Recording',
          color: AppColors.error,
          onPressed: isRecording ? null : onStart,
        ),
        _MediaActionButton(
          icon: Icons.stop_circle_outlined,
          label: 'Stop Recording',
          color: AppColors.warning,
          onPressed: isRecording ? onStop : null,
        ),
        _MediaActionButton(
          icon: Icons.play_circle_outline,
          label: 'Play Recording',
          color: AppColors.info,
          onPressed: hasRecording && !isRecording && !isPlaying ? onPlay : null,
        ),
        _MediaActionButton(
          icon: Icons.delete_outline,
          label: 'Delete Recording',
          color: AppColors.textSecondary,
          onPressed: hasRecording || isRecording ? onDelete : null,
        ),
      ],
    );
  }
}

class _PhotoPickerCard extends StatelessWidget {
  final List<String> references;
  final VoidCallback onCapture;
  final VoidCallback onSelect;
  final ValueChanged<String> onRemove;

  const _PhotoPickerCard({
    required this.references,
    required this.onCapture,
    required this.onSelect,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return _MediaPanel(
      icon: Icons.photo_outlined,
      title: 'Photos',
      subtitle: references.isEmpty
          ? 'No photos added'
          : '${references.length} photo${references.length == 1 ? '' : 's'} added',
      preview: _MediaPreviewWrap(
        emptyLabel: 'Thumbnail preview will appear here.',
        references: references,
        icon: Icons.image_outlined,
        onRemove: onRemove,
      ),
      children: [
        _MediaActionButton(
          icon: Icons.photo_camera_outlined,
          label: 'Capture Photo',
          color: AppColors.info,
          onPressed: onCapture,
        ),
        _MediaActionButton(
          icon: Icons.photo_library_outlined,
          label: 'Select From Gallery',
          color: AppColors.success,
          onPressed: onSelect,
        ),
      ],
    );
  }
}

class _VideoPickerCard extends StatelessWidget {
  final List<String> references;
  final VoidCallback onRecord;
  final VoidCallback onSelect;
  final ValueChanged<String> onRemove;

  const _VideoPickerCard({
    required this.references,
    required this.onRecord,
    required this.onSelect,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return _MediaPanel(
      icon: Icons.videocam_outlined,
      title: 'Videos',
      subtitle: references.isEmpty
          ? 'No videos added'
          : '${references.length} video${references.length == 1 ? '' : 's'} added',
      preview: _MediaPreviewWrap(
        emptyLabel: 'Video preview will appear here.',
        references: references,
        icon: Icons.smart_display_outlined,
        onRemove: onRemove,
      ),
      children: [
        _MediaActionButton(
          icon: Icons.videocam_outlined,
          label: 'Record Video',
          color: AppColors.info,
          onPressed: onRecord,
        ),
        _MediaActionButton(
          icon: Icons.video_library_outlined,
          label: 'Select Video',
          color: AppColors.success,
          onPressed: onSelect,
        ),
      ],
    );
  }
}

class _MediaPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? preview;

  const _MediaPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
    this.preview,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                PremiumIconChip(icon: icon, color: AppColors.textPrimary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: children,
            ),
            if (preview != null) ...[
              const SizedBox(height: 12),
              preview!,
            ],
          ],
        ),
      ),
    );
  }
}

class _MediaActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _MediaActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: onPressed == null ? null : color),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: BorderSide(color: Colors.white.withAlpha(32)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      ),
    );
  }
}

class _MediaPreviewWrap extends StatelessWidget {
  final String emptyLabel;
  final List<String> references;
  final IconData icon;
  final ValueChanged<String> onRemove;

  const _MediaPreviewWrap({
    required this.emptyLabel,
    required this.references,
    required this.icon,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (references.isEmpty) {
      return _EmptyMediaPreview(label: emptyLabel);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: references
          .map(
            (reference) => _MediaReferenceTile(
              icon: icon,
              label: reference,
              onRemove: () => onRemove(reference),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _EmptyMediaPreview extends StatelessWidget {
  final String label;

  const _EmptyMediaPreview({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(70),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _MediaReferenceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onRemove;

  const _MediaReferenceTile({
    required this.icon,
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(70),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withAlpha(22)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(letterSpacing: 0),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(Icons.close, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _PremiumDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white.withAlpha(10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withAlpha(24)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withAlpha(24)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.textPrimary),
        ),
      ),
      dropdownColor: AppColors.surface,
      items: options
          .map((option) => DropdownMenuItem<String>(
                value: option,
                child: Text(option),
              ))
          .toList(growable: false),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withAlpha(16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(46)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.headingSmall.copyWith(
                fontSize: 22,
                color: color,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(letterSpacing: 0),
            ),
          ],
        ),
      ),
    );
  }
}

DateTime? _parseDate(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return DateTime.tryParse(trimmed);
}

String _formatMediaDuration(int seconds) {
  final safeSeconds = seconds < 0 ? 0 : seconds;
  final minutes = safeSeconds ~/ 60;
  final remainingSeconds = safeSeconds % 60;
  final minuteLabel = minutes.toString().padLeft(2, '0');
  final secondLabel = remainingSeconds.toString().padLeft(2, '0');
  return '$minuteLabel:$secondLabel';
}

String _vehicleDetailsForVisit(ComplaintModel complaint) {
  final values = [
    complaint.vehicleNumber,
    complaint.vehicleModel,
  ].where((value) => value.trim().isNotEmpty).toList(growable: false);

  return values.join(' - ');
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'closed':
      return AppColors.success;
    case 'visit_scheduled':
      return AppColors.info;
    case 'registered':
      return AppColors.warning;
    default:
      return AppColors.textSecondary;
  }
}
