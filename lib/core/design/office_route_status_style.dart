import 'package:flutter/material.dart';

import 'office_route_colors.dart';

enum TransportGlowType { none, liveBlue, readyGreen, waitingAmber, errorRed }

class OfficeRouteStatusStyle {
  OfficeRouteStatusStyle._();

  static Color getPrimaryColor(TransportGlowType type) {
    switch (type) {
      case TransportGlowType.liveBlue:
        return OfficeRouteColors.liveBlue;
      case TransportGlowType.readyGreen:
        return OfficeRouteColors.readyGreen;
      case TransportGlowType.waitingAmber:
        return OfficeRouteColors.waitingAmber;
      case TransportGlowType.errorRed:
        return OfficeRouteColors.errorRed;
      case TransportGlowType.none:
        return OfficeRouteColors.secondaryText;
    }
  }

  static List<BoxShadow> getGlowShadow(TransportGlowType type) {
    if (type == TransportGlowType.none) return const <BoxShadow>[];

    final color = getPrimaryColor(type);
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.3),
        blurRadius: 16,
        spreadRadius: 1,
      ),
    ];
  }
}
