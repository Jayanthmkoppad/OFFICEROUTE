import 'package:flutter/material.dart';

import '../office_route_colors.dart';
import '../office_route_radii.dart';
import '../office_route_spacing.dart';
import '../office_route_status_style.dart';
import '../office_route_typography.dart';

/// Privacy-safe passenger progress tile for co-passengers.
/// Shows status summary, sequence, and distance to pickup without exposing exact GPS.
class OfficeRoutePassengerProgressTile extends StatelessWidget {
  final int sequence;
  final String passengerName;
  final String statusText;
  final TransportGlowType statusGlow;
  final String? distanceText;
  final String? timeEstimateText;
  final String freshnessText;

  const OfficeRoutePassengerProgressTile({
    super.key,
    required this.sequence,
    required this.passengerName,
    required this.statusText,
    this.statusGlow = TransportGlowType.none,
    this.distanceText,
    this.timeEstimateText,
    this.freshnessText = 'Just now',
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = OfficeRouteStatusStyle.getPrimaryColor(statusGlow);

    return Container(
      margin: const EdgeInsets.only(bottom: OfficeRouteSpacing.xs),
      padding: const EdgeInsets.all(OfficeRouteSpacing.sm),
      decoration: BoxDecoration(
        color: OfficeRouteColors.primarySurface,
        borderRadius: OfficeRouteRadii.smallRadius,
        border: Border.all(color: OfficeRouteColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: OfficeRouteColors.raisedSurface,
            child: Text(
              '$sequence',
              style: OfficeRouteTypography.tabularData.copyWith(
                fontSize: 12,
                color: OfficeRouteColors.primaryText,
              ),
            ),
          ),
          const SizedBox(width: OfficeRouteSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      passengerName,
                      style: OfficeRouteTypography.cardTitle.copyWith(
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      statusText.toUpperCase(),
                      style: OfficeRouteTypography.secondary.copyWith(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (distanceText != null) ...[
                      Text(
                        distanceText!,
                        style: OfficeRouteTypography.secondary.copyWith(
                          color: OfficeRouteColors.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                      const Text(
                        ' • ',
                        style: TextStyle(
                          color: OfficeRouteColors.secondaryText,
                        ),
                      ),
                    ],
                    if (timeEstimateText != null) ...[
                      Text(
                        timeEstimateText!,
                        style: OfficeRouteTypography.secondary.copyWith(
                          color: OfficeRouteColors.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                      const Text(
                        ' • ',
                        style: TextStyle(
                          color: OfficeRouteColors.secondaryText,
                        ),
                      ),
                    ],
                    Text(
                      freshnessText,
                      style: OfficeRouteTypography.secondary.copyWith(
                        color: OfficeRouteColors.disabledText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
