import 'package:flutter/material.dart';

/// Corner radius constants for the OfficeRoute design system.
class OfficeRouteRadii {
  OfficeRouteRadii._();

  static const double small = 12.0;
  static const double card = 16.0;
  static const double hero = 24.0;
  static const double pill = 999.0;

  static const BorderRadius smallRadius = BorderRadius.all(
    Radius.circular(small),
  );
  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius heroRadius = BorderRadius.all(
    Radius.circular(hero),
  );
  static const BorderRadius pillRadius = BorderRadius.all(
    Radius.circular(pill),
  );
}
