import 'dart:async';

import '../../../core/models/live_location_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/live_location_service.dart';
import '../../attendance/models/attendance_model.dart';
import '../../attendance/services/attendance_service.dart';
import '../../customer_visits/models/customer_visit_model.dart';
import '../../customer_visits/services/customer_visit_service.dart';

typedef OrganizationOperationsSnapshot = ({
  List<UserModel> employees,
  List<AttendanceModel> attendance,
  List<CustomerVisitModel> visits,
  List<LiveLocationModel> liveLocations,
  DateTime loadedAt,
});

class OrganizationService {
  OrganizationService._();

  /// Phase 2 read projection over already-approved operational collections.
  static Future<OrganizationOperationsSnapshot> loadOperations(
    DateTime day,
  ) async {
    final employeesFuture = FirestoreService.fetchAllUsers();
    final attendanceFuture = AttendanceService.fetchAttendanceForDate(day);
    final visitsFuture = CustomerVisitService.fetchOperationalVisitsForDate(day);
    final locationsFuture = LiveLocationService.watchLiveLocations()
        .first
        .timeout(
          const Duration(seconds: 8),
          onTimeout: () => const <LiveLocationModel>[],
        );

    return (
      employees: List<UserModel>.unmodifiable(await employeesFuture),
      attendance: List<AttendanceModel>.unmodifiable(await attendanceFuture),
      visits: List<CustomerVisitModel>.unmodifiable(await visitsFuture),
      liveLocations:
          List<LiveLocationModel>.unmodifiable(await locationsFuture),
      loadedAt: DateTime.now(),
    );
  }

  static Stream<void> watchOperations(DateTime day) {
    late final StreamController<void> controller;
    final subscriptions = <StreamSubscription<void>>[];
    controller = StreamController<void>(
      onListen: () {
        final streams = <Stream<void>>[
          FirestoreService.watchUsers(),
          AttendanceService.watchAttendanceForDate(day),
          CustomerVisitService.watchVisitsForDate(day),
          LiveLocationService.watchLiveLocationChanges(),
        ];
        for (final stream in streams) {
          subscriptions.add(
            stream.listen(
              (_) => controller.add(null),
              onError: controller.addError,
            ),
          );
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }
}
