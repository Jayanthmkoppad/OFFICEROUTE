import 'package:flutter/material.dart';
import 'office_route_colors.dart';

/// Typography hierarchy for the NothingOS-inspired OfficeRoute design system.
class OfficeRouteTypography {
  OfficeRouteTypography._();

  static const String fontPackage = '';

  static const TextStyle screenTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: OfficeRouteColors.primaryText,
    letterSpacing: -0.5,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: OfficeRouteColors.primaryText,
    letterSpacing: -0.2,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: OfficeRouteColors.primaryText,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: OfficeRouteColors.primaryText,
  );

  static const TextStyle secondary = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: OfficeRouteColors.secondaryText,
  );

  static const TextStyle largeMetric = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: OfficeRouteColors.primaryText,
    fontFeatures: [FontFeature.tabularFigures()],
    letterSpacing: -0.5,
  );

  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: OfficeRouteColors.primaryText,
  );

  static const TextStyle tabularData = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: OfficeRouteColors.primaryText,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
