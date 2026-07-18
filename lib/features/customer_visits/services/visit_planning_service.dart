import 'dart:math' as math;

import '../../../core/models/employee_model.dart';
import '../../../core/models/live_location_model.dart';
import '../../attendance/models/attendance_model.dart';
import '../models/customer_visit_model.dart';

/// Static OfficeRoute service-centre reference used until branch ownership is
/// introduced by the approved Branch Management phase.
class VisitServiceCentre {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String region;

  const VisitServiceCentre({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.region,
  });
}

/// Nearest-centre result based on direct geographic distance.
class VisitLocationAssessment {
  final VisitServiceCentre centre;
  final double directDistanceKm;

  const VisitLocationAssessment({
    required this.centre,
    required this.directDistanceKm,
  });
}

/// Explainable engineer recommendation derived from existing operations data.
class EngineerDispatchRecommendation {
  final EmployeeModel employee;
  final double score;
  final String recommendation;
  final int stars;
  final bool onDuty;
  final bool onBreak;
  final bool travelling;
  final bool overtime;
  final bool gpsFresh;
  final int activeVisits;
  final int pendingWorkload;
  final int completedToday;
  final double completionRate;
  final Duration currentShift;
  final double? directDistanceKm;

  const EngineerDispatchRecommendation({
    required this.employee,
    required this.score,
    required this.recommendation,
    required this.stars,
    required this.onDuty,
    required this.onBreak,
    required this.travelling,
    required this.overtime,
    required this.gpsFresh,
    required this.activeVisits,
    required this.pendingWorkload,
    required this.completedToday,
    required this.completionRate,
    required this.currentShift,
    required this.directDistanceKm,
  });

  bool get available => recommendation != 'Not Available';
}

/// Dispatch analytics calculated from persisted visit-planning fields only.
class VisitDispatchAnalytics {
  final int plannedVisitCount;
  final int pendingDispatches;
  final int routeSampleCount;
  final Map<String, int> centreUsage;
  final double? averageRoadDistanceKm;
  final double? longestRoadDistanceKm;
  final double? shortestRoadDistanceKm;
  final Duration? averageEta;
  final Duration? averageAssignmentDelay;
  final double? travelEfficiencyPercent;

  const VisitDispatchAnalytics({
    required this.plannedVisitCount,
    required this.pendingDispatches,
    required this.routeSampleCount,
    required this.centreUsage,
    required this.averageRoadDistanceKm,
    required this.longestRoadDistanceKm,
    required this.shortestRoadDistanceKm,
    required this.averageEta,
    required this.averageAssignmentDelay,
    required this.travelEfficiencyPercent,
  });
}

class VisitPlanningService {
  VisitPlanningService._();

  /// City reference coordinates approved for the temporary service-centre
  /// registry. They are not a replacement for future branch records.
  static const serviceCentres = <VisitServiceCentre>[
    VisitServiceCentre(
      id: 'delhi',
      name: 'Delhi',
      latitude: 28.6139,
      longitude: 77.2090,
      region: 'North',
    ),
    VisitServiceCentre(
      id: 'lucknow',
      name: 'Lucknow',
      latitude: 26.8467,
      longitude: 80.9462,
      region: 'Uttar Pradesh Central',
    ),
    VisitServiceCentre(
      id: 'meerut',
      name: 'Meerut',
      latitude: 28.9845,
      longitude: 77.7064,
      region: 'Uttar Pradesh West',
    ),
    VisitServiceCentre(
      id: 'varanasi',
      name: 'Varanasi',
      latitude: 25.3176,
      longitude: 82.9739,
      region: 'Uttar Pradesh East',
    ),
    VisitServiceCentre(
      id: 'gorakhpur',
      name: 'Gorakhpur',
      latitude: 26.7606,
      longitude: 83.3732,
      region: 'Uttar Pradesh East',
    ),
    VisitServiceCentre(
      id: 'patna',
      name: 'Patna',
      latitude: 25.5941,
      longitude: 85.1376,
      region: 'Bihar',
    ),
    VisitServiceCentre(
      id: 'kolkata',
      name: 'Kolkata',
      latitude: 22.5726,
      longitude: 88.3639,
      region: 'East',
    ),
  ];

  static VisitServiceCentre? centreByName(String name) {
    final normalized = name.trim().toLowerCase();
    for (final centre in serviceCentres) {
      if (centre.name.toLowerCase() == normalized) return centre;
    }
    return null;
  }

  /// Calculates the nearest temporary centre using direct distance. Road
  /// distance and ETA remain owned by a future Google Routes integration.
  static VisitLocationAssessment nearestCentre({
    required double latitude,
    required double longitude,
  }) {
    var nearest = serviceCentres.first;
    var nearestDistance = directDistanceKm(
      latitude,
      longitude,
      nearest.latitude,
      nearest.longitude,
    );
    for (final centre in serviceCentres.skip(1)) {
      final distance = directDistanceKm(
        latitude,
        longitude,
        centre.latitude,
        centre.longitude,
      );
      if (distance < nearestDistance) {
        nearest = centre;
        nearestDistance = distance;
      }
    }
    return VisitLocationAssessment(
      centre: nearest,
      directDistanceKm: nearestDistance,
    );
  }

  static double directDistanceKm(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    const earthRadiusKm = 6371.0;
    final latitudeDelta = _radians(endLatitude - startLatitude);
    final longitudeDelta = _radians(endLongitude - startLongitude);
    final startLatitudeRadians = _radians(startLatitude);
    final endLatitudeRadians = _radians(endLatitude);
    final haversine = math.sin(latitudeDelta / 2) *
            math.sin(latitudeDelta / 2) +
        math.cos(startLatitudeRadians) *
            math.cos(endLatitudeRadians) *
            math.sin(longitudeDelta / 2) *
            math.sin(longitudeDelta / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
  }

  /// Ranks employees without claiming unavailable centre membership,
  /// expertise, route distance, or shift-roster data.
  static List<EngineerDispatchRecommendation> rankEngineers({
    required List<EmployeeModel> employees,
    required List<AttendanceModel> attendance,
    required List<CustomerVisitModel> visits,
    required Map<String, LiveLocationModel> liveLocationsByUserId,
    required DateTime now,
    double? dealerLatitude,
    double? dealerLongitude,
  }) {
    final attendanceByUser = <String, AttendanceModel>{};
    for (final record in attendance) {
      final existing = attendanceByUser[record.userId];
      final existingTime = existing?.checkInTime ?? existing?.date;
      final candidateTime = record.checkInTime ?? record.date;
      if (existing == null ||
          (candidateTime != null &&
              (existingTime == null || candidateTime.isAfter(existingTime)))) {
        attendanceByUser[record.userId] = record;
      }
    }

    final recommendations = <EngineerDispatchRecommendation>[];
    for (final employee in employees) {
      final employeeVisits = visits
          .where((visit) => visit.userId == employee.uid)
          .toList(growable: false);
      final activeVisits = employeeVisits.where(_isActiveVisit).length;
      final pendingWorkload = employeeVisits.where(_isOpenVisit).length;
      final completedVisits = employeeVisits.where(_isCompletedVisit).length;
      final completedToday = employeeVisits.where((visit) {
        final completedAt = visit.completedAt;
        return completedAt != null && _sameDay(completedAt, now);
      }).length;
      final completionRate = employeeVisits.isEmpty
          ? 0.0
          : (completedVisits / employeeVisits.length) * 100;

      final attendanceRecord = attendanceByUser[employee.uid];
      final onDuty = attendanceRecord?.isCheckedIn == true;
      final onBreak = attendanceRecord?.isOnBreak == true;
      final currentShift = attendanceRecord?.netWorkingDuration(now) ?? Duration.zero;
      final overtime = currentShift > const Duration(hours: 8);

      final location = liveLocationsByUserId[employee.uid];
      final gpsFresh = location != null &&
          now.difference(location.updatedAt).abs() <= const Duration(minutes: 5);
      final travelling = gpsFresh && location.speed > 1.4;
      final directDistance = gpsFresh &&
              dealerLatitude != null &&
              dealerLongitude != null
          ? directDistanceKm(
              location.latitude,
              location.longitude,
              dealerLatitude,
              dealerLongitude,
            )
          : null;

      var score = 35.0;
      score += onDuty ? 30 : -35;
      if (onBreak) score -= 25;
      score -= math.min(activeVisits * 18, 36);
      score -= math.min(pendingWorkload * 4, 20);
      if (travelling) score -= 8;
      if (gpsFresh) score += 5;
      if (directDistance != null) {
        if (directDistance <= 20) {
          score += 10;
        } else if (directDistance <= 50) {
          score += 5;
        } else if (directDistance > 100) {
          score -= 10;
        }
      }
      score += completionRate * 0.15;
      score += math.min(completedToday * 2, 6);
      if (overtime) score -= 25;
      score = score.clamp(0.0, 100.0).toDouble();

      late final String recommendation;
      late final int stars;
      if (!onDuty) {
        recommendation = 'Not Available';
        stars = 0;
      } else if (onBreak ||
          activeVisits > 0 ||
          pendingWorkload >= 4 ||
          travelling ||
          overtime) {
        recommendation = 'Busy';
        stars = 2;
      } else if (score >= 80) {
        recommendation = 'Best Choice';
        stars = 4;
      } else if (score >= 55) {
        recommendation = 'Good';
        stars = 3;
      } else {
        recommendation = 'Busy';
        stars = 2;
      }

      recommendations.add(
        EngineerDispatchRecommendation(
          employee: employee,
          score: score,
          recommendation: recommendation,
          stars: stars,
          onDuty: onDuty,
          onBreak: onBreak,
          travelling: travelling,
          overtime: overtime,
          gpsFresh: gpsFresh,
          activeVisits: activeVisits,
          pendingWorkload: pendingWorkload,
          completedToday: completedToday,
          completionRate: completionRate,
          currentShift: currentShift,
          directDistanceKm: directDistance,
        ),
      );
    }

    recommendations.sort((left, right) {
      final availability = _recommendationOrder(left.recommendation).compareTo(
        _recommendationOrder(right.recommendation),
      );
      if (availability != 0) return availability;
      return right.score.compareTo(left.score);
    });
    return recommendations;
  }

  static VisitDispatchAnalytics calculateDispatchAnalytics({
    required List<CustomerVisitModel> visits,
    required Set<String> employeeIds,
  }) {
    final planningVisits = visits.where(_hasPlanningData).toList(growable: false);
    final centreUsage = <String, int>{};
    final roadDistances = <double>[];
    final etaMinutes = <int>[];
    final assignmentDelays = <Duration>[];
    final efficiencySamples = <double>[];

    for (final visit in planningVisits) {
      final centre = visit.serviceCentreName.trim();
      if (centre.isNotEmpty) {
        centreUsage.update(centre, (count) => count + 1, ifAbsent: () => 1);
      }
      final roadDistance = visit.roadDistanceKm;
      if (roadDistance != null && roadDistance > 0) {
        roadDistances.add(roadDistance);
        final directDistance = visit.serviceCentreDistanceKm;
        if (directDistance != null && directDistance > 0) {
          efficiencySamples.add(
            ((directDistance / roadDistance) * 100).clamp(0.0, 100.0).toDouble(),
          );
        }
      }
      final eta = visit.estimatedTravelMinutes;
      if (eta != null && eta > 0) etaMinutes.add(eta);
      final assignedAt = visit.assignedAt;
      if (assignedAt != null && !assignedAt.isBefore(visit.createdAt)) {
        assignmentDelays.add(assignedAt.difference(visit.createdAt));
      }
    }

    roadDistances.sort();
    return VisitDispatchAnalytics(
      plannedVisitCount: planningVisits.length,
      pendingDispatches: planningVisits
          .where((visit) => !employeeIds.contains(visit.userId))
          .length,
      routeSampleCount: roadDistances.length,
      centreUsage: centreUsage,
      averageRoadDistanceKm: _averageDouble(roadDistances),
      longestRoadDistanceKm: roadDistances.isEmpty ? null : roadDistances.last,
      shortestRoadDistanceKm: roadDistances.isEmpty ? null : roadDistances.first,
      averageEta: etaMinutes.isEmpty
          ? null
          : Duration(minutes: etaMinutes.reduce((a, b) => a + b) ~/ etaMinutes.length),
      averageAssignmentDelay: _averageDuration(assignmentDelays),
      travelEfficiencyPercent: _averageDouble(efficiencySamples),
    );
  }

  static String extractPinCode(String address) {
    final match = RegExp(r'\b[1-9][0-9]{5}\b').firstMatch(address);
    return match?.group(0) ?? '';
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  static bool _hasPlanningData(CustomerVisitModel visit) {
    return visit.complaintId.isNotEmpty ||
        visit.dealerPinCode.isNotEmpty ||
        visit.priority.isNotEmpty ||
        visit.preferredVisitDate != null ||
        visit.expectedDurationMinutes != null ||
        visit.serviceCentreName.isNotEmpty;
  }

  static bool _isOpenVisit(CustomerVisitModel visit) {
    final status = visit.status.toLowerCase();
    return status != 'completed' && status != 'cancelled';
  }

  static bool _isActiveVisit(CustomerVisitModel visit) {
    final status = visit.status.toLowerCase();
    return status == 'checked_in' ||
        status == 'active' ||
        status == 'in_progress' ||
        status == 'on_site';
  }

  static bool _isCompletedVisit(CustomerVisitModel visit) {
    return visit.status.toLowerCase() == 'completed';
  }

  static int _recommendationOrder(String recommendation) {
    switch (recommendation) {
      case 'Best Choice':
        return 0;
      case 'Good':
        return 1;
      case 'Busy':
        return 2;
      default:
        return 3;
    }
  }

  static bool _sameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  static double? _averageDouble(List<double> values) {
    if (values.isEmpty) return null;
    return values.reduce((left, right) => left + right) / values.length;
  }

  static Duration? _averageDuration(List<Duration> values) {
    if (values.isEmpty) return null;
    final total = values.fold<int>(
      0,
      (sum, duration) => sum + duration.inMilliseconds,
    );
    return Duration(milliseconds: total ~/ values.length);
  }
}
