import 'package:flutter/material.dart';

/// Premium monochrome color palette with semantic transport status glows.
/// Inspired by NothingOS & high-end live transport applications.
class OfficeRouteColors {
  OfficeRouteColors._();

  // Core Monochrome Surfaces
  static const Color background = Color(0xFF000000);
  static const Color primarySurface = Color(0xFF121212);
  static const Color raisedSurface = Color(0xFF181818);
  static const Color card = Color(0xFF181818);
  static const Color border = Color(0xFF2A2A2A);
  static const Color divider = Color(0xFF202020);

  // Typography Colors
  static const Color primaryText = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFFB3B3B3);
  static const Color disabledText = Color(0xFF6F6F6F);

  // Brand & Semantic Status Colors
  static const Color brandRed = Color(0xFFE2201F);
  static const Color liveBlue = Color(0xFF3B82F6);
  static const Color readyGreen = Color(0xFF22C55E);
  static const Color waitingAmber = Color(0xFFFFB020);
  static const Color errorRed = Color(0xFFFF4D4F);

  // Semantic Glow Colors
  static Color blueGlow(double opacity) => liveBlue.withValues(alpha: opacity);
  static Color greenGlow(double opacity) =>
      readyGreen.withValues(alpha: opacity);
  static Color amberGlow(double opacity) =>
      waitingAmber.withValues(alpha: opacity);
  static Color redGlow(double opacity) => errorRed.withValues(alpha: opacity);
}
