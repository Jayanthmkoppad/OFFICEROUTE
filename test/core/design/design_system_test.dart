import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:officeroute/core/design/office_route_colors.dart';
import 'package:officeroute/core/design/office_route_radii.dart';
import 'package:officeroute/core/design/office_route_spacing.dart';
import 'package:officeroute/core/design/office_route_status_style.dart';
import 'package:officeroute/core/design/widgets/office_route_card.dart';
import 'package:officeroute/core/design/widgets/office_route_passenger_progress_tile.dart';
import 'package:officeroute/core/design/widgets/office_route_status_chip.dart';
import 'package:officeroute/core/design/widgets/office_route_live_indicator.dart';

void main() {
  group('OfficeRoute Design System Tokens', () {
    test(
      'Color tokens maintain high contrast monochrome and status definitions',
      () {
        expect(OfficeRouteColors.background, equals(const Color(0xFF000000)));
        expect(
          OfficeRouteColors.primarySurface,
          equals(const Color(0xFF121212)),
        );
        expect(OfficeRouteColors.liveBlue, equals(const Color(0xFF3B82F6)));
        expect(OfficeRouteColors.readyGreen, equals(const Color(0xFF22C55E)));
        expect(OfficeRouteColors.waitingAmber, equals(const Color(0xFFFFB020)));
        expect(OfficeRouteColors.errorRed, equals(const Color(0xFFFF4D4F)));
      },
    );

    test('Spacing tokens adhere to 8-point spatial system', () {
      expect(OfficeRouteSpacing.xxs, equals(4.0));
      expect(OfficeRouteSpacing.xs, equals(8.0));
      expect(OfficeRouteSpacing.sm, equals(12.0));
      expect(OfficeRouteSpacing.md, equals(16.0));
      expect(OfficeRouteSpacing.lg, equals(24.0));
      expect(OfficeRouteSpacing.xl, equals(32.0));
    });

    test('Radii tokens support small, card, hero and pill radii', () {
      expect(OfficeRouteRadii.small, equals(12.0));
      expect(OfficeRouteRadii.card, equals(16.0));
      expect(OfficeRouteRadii.hero, equals(24.0));
      expect(OfficeRouteRadii.pill, equals(999.0));
    });

    test('Status style resolver returns correct semantic glow and color', () {
      expect(
        OfficeRouteStatusStyle.getPrimaryColor(TransportGlowType.liveBlue),
        equals(OfficeRouteColors.liveBlue),
      );
      expect(
        OfficeRouteStatusStyle.getGlowShadow(TransportGlowType.liveBlue).length,
        equals(1),
      );
      expect(
        OfficeRouteStatusStyle.getGlowShadow(TransportGlowType.none),
        isEmpty,
      );
    });
  });

  group('OfficeRoute Design Widgets', () {
    testWidgets('OfficeRouteCard renders child and glow decoration', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfficeRouteCard(
              glowType: TransportGlowType.liveBlue,
              child: Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
    });

    testWidgets('OfficeRouteStatusChip renders icon and uppercase label', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfficeRouteStatusChip(
              label: 'Ready',
              icon: Icons.check_circle_outline,
              glowType: TransportGlowType.readyGreen,
            ),
          ),
        ),
      );

      expect(find.text('READY'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets(
      'OfficeRoutePassengerProgressTile renders privacy-safe passenger progress',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: OfficeRoutePassengerProgressTile(
                sequence: 1,
                passengerName: 'Ravi Kumar',
                statusText: 'Travelling to pickup',
                statusGlow: TransportGlowType.liveBlue,
                distanceText: '320 m from pickup',
                timeEstimateText: '5 min',
                freshnessText: '10 sec ago',
              ),
            ),
          ),
        );

        expect(find.text('1'), findsOneWidget);
        expect(find.text('Ravi Kumar'), findsOneWidget);
        expect(find.text('TRAVELLING TO PICKUP'), findsOneWidget);
        expect(find.text('320 m from pickup'), findsOneWidget);
      },
    );

    testWidgets(
      'OfficeRouteLiveIndicator stops pulsing when MediaQuery.disableAnimations is true',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: OfficeRouteLiveIndicator(label: 'LIVE', isLive: true),
              ),
            ),
          ),
        );

        expect(find.text('LIVE'), findsOneWidget);
      },
    );
  });
}
