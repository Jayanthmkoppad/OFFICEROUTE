import 'package:flutter/material.dart';

/// Animation and motion curves for responsive interactive elements.
class OfficeRouteMotion {
  OfficeRouteMotion._();

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 350);

  static const Curve defaultCurve = Curves.fastOutSlowIn;
  static const Curve easeInOut = Curves.easeInOut;
}
