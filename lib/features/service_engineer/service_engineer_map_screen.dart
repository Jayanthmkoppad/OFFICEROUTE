import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../customer_visits/controllers/customer_visit_controller.dart';
import '../customer_visits/models/customer_visit_model.dart';

class ServiceEngineerMapScreen extends StatefulWidget {
  const ServiceEngineerMapScreen({super.key});

  @override
  State<ServiceEngineerMapScreen> createState() =>
      _ServiceEngineerMapScreenState();
}

class _ServiceEngineerMapScreenState extends State<ServiceEngineerMapScreen> {
  static const LatLng _defaultCenter = LatLng(28.6139, 77.2090);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Field Service Map'), elevation: 0),
      body: FutureBuilder<List<CustomerVisitModel>>(
        future: CustomerVisitController.loadMyVisits(),
        builder: (context, snapshot) {
          final visits = snapshot.data ?? const <CustomerVisitModel>[];
          final markers = <Marker>{};

          for (var i = 0; i < visits.length; i++) {
            final v = visits[i];
            if (v.dealerLatitude != null && v.dealerLongitude != null) {
              markers.add(
                Marker(
                  markerId: MarkerId('job_${v.id}'),
                  position: LatLng(v.dealerLatitude!, v.dealerLongitude!),
                  infoWindow: InfoWindow(
                    title: v.customerName.isNotEmpty
                        ? v.customerName
                        : 'Customer Site',
                    snippet: v.customerAddress,
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueOrange,
                  ),
                ),
              );
            }
          }

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: _defaultCenter,
                  zoom: 12.0,
                ),
                markers: markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: false,
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.handyman, color: AppColors.info),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Displaying ${markers.length} assigned customer sites on field map',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
