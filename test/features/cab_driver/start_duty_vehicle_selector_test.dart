import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:officeroute/core/models/cab_vehicle_model.dart';
import 'package:officeroute/core/models/office_destination.dart';
import 'package:officeroute/features/cab_driver/widgets/driver_start_duty_overlay.dart';

void main() {
  const cabOne = CabVehicleModel(
    id: 'cab-document-1',
    vehicleNumber: 'CAB-01',
    vehicleModel: 'Electric',
    registrationNumber: 'REG-01',
    capacity: 4,
    status: 'available',
  );
  const configuredOffice = OfficeDestination(
    name: 'Office',
    address: 'Configured office',
    latitude: 15.36,
    longitude: 75.12,
  );
  const cabTwo = CabVehicleModel(
    id: 'cab-document-2',
    vehicleNumber: 'CAB-02',
    vehicleModel: 'Hybrid',
    registrationNumber: 'REG-02',
    capacity: 6,
    status: 'assigned',
  );

  Widget sheet({
    String? initialVehicleId,
    required Future<List<CabVehicleModel>> Function() loadVehicles,
    Future<CabVehicleModel?> Function(String id)? getVehicle,
    Future<void> Function({
      required String vehicleId,
      required double startOdometer,
      required int batteryPercentage,
      required String vehicleCondition,
      required OfficeDestination officeDestination,
      String? note,
    })?
    onConfirm,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: StartDutyChecklistSheet(
          initialVehicleId: initialVehicleId,
          initialOfficeDestination: configuredOffice,
          loadVehicles: loadVehicles,
          getVehicle:
              getVehicle ??
              (id) async =>
                  id == cabOne.id ? cabOne : (id == cabTwo.id ? cabTwo : null),
          onConfirm:
              onConfirm ??
              ({
                required vehicleId,
                required startOdometer,
                required batteryPercentage,
                required vehicleCondition,
                required officeDestination,
                note,
              }) async {},
        ),
      ),
    );
  }

  Finder confirmButton() =>
      find.widgetWithText(FilledButton, 'CONFIRM AND START DUTY');

  Future<void> enterOperationalValues(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), '1000');
    await tester.enterText(find.byType(TextField).at(1), '80');
  }

  testWidgets('configured vehicles load and dropdown shows real data', (
    tester,
  ) async {
    await tester.pumpWidget(sheet(loadVehicles: () async => [cabOne, cabTwo]));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('Select a configured cab'), findsOneWidget);
    expect(find.textContaining('KA-25-AB-1234'), findsNothing);
    expect(find.text('12450'), findsNothing);
    expect(find.text('78'), findsNothing);
    expect(find.text('Tire / Brakes'), findsNothing);
    expect(tester.widget<FilledButton>(confirmButton()).onPressed, isNull);
  });

  testWidgets('valid document ID preselects and is submitted', (tester) async {
    String? submittedId;
    await tester.pumpWidget(
      sheet(
        initialVehicleId: cabTwo.id,
        loadVehicles: () async => [cabOne, cabTwo],
        onConfirm:
            ({
              required vehicleId,
              required startOdometer,
              required batteryPercentage,
              required vehicleCondition,
              required officeDestination,
              note,
            }) async {
              submittedId = vehicleId;
            },
      ),
    );
    await tester.pumpAndSettle();
    await enterOperationalValues(tester);
    await tester.ensureVisible(confirmButton());
    await tester.tap(confirmButton());
    await tester.pumpAndSettle();

    expect(submittedId, cabTwo.id);
  });

  testWidgets(
    'invalid initial ID creates no fallback when multiple cabs exist',
    (tester) async {
      await tester.pumpWidget(
        sheet(
          initialVehicleId: 'missing-document',
          loadVehicles: () async => [cabOne, cabTwo],
        ),
      );
      await tester.pumpAndSettle();

      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdown.initialValue, isNull);
      expect(tester.widget<FilledButton>(confirmButton()).onPressed, isNull);
    },
  );

  testWidgets('one usable cab auto-selects while inactive cab is rejected', (
    tester,
  ) async {
    const inactiveCab = CabVehicleModel(
      id: 'inactive-document',
      vehicleNumber: 'CAB-X',
      status: 'inactive',
    );
    await tester.pumpWidget(
      sheet(loadVehicles: () async => [inactiveCab, cabOne]),
    );
    await tester.pumpAndSettle();

    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(dropdown.initialValue, cabOne.id);
    expect(tester.widget<FilledButton>(confirmButton()).onPressed, isNotNull);
  });

  testWidgets('loading and no-vehicle states keep Start Duty disabled', (
    tester,
  ) async {
    final completer = Completer<List<CabVehicleModel>>();
    await tester.pumpWidget(sheet(loadVehicles: () => completer.future));
    await tester.pump();

    expect(find.text('Loading configured cabs...'), findsOneWidget);
    expect(tester.widget<FilledButton>(confirmButton()).onPressed, isNull);

    completer.complete(const []);
    await tester.pumpAndSettle();

    expect(find.text('No configured cab available'), findsOneWidget);
    expect(tester.widget<FilledButton>(confirmButton()).onPressed, isNull);
  });

  testWidgets('vehicle removed before confirmation blocks Start Duty', (
    tester,
  ) async {
    var confirmed = false;
    await tester.pumpWidget(
      sheet(
        loadVehicles: () async => [cabOne],
        getVehicle: (_) async => null,
        onConfirm:
            ({
              required vehicleId,
              required startOdometer,
              required batteryPercentage,
              required vehicleCondition,
              required officeDestination,
              note,
            }) async {
              confirmed = true;
            },
      ),
    );
    await tester.pumpAndSettle();
    await enterOperationalValues(tester);
    await tester.ensureVisible(confirmButton());
    await tester.tap(confirmButton());
    await tester.pumpAndSettle();

    expect(
      find.text('The selected cab is no longer available'),
      findsOneWidget,
    );
    expect(confirmed, isFalse);
  });

  testWidgets('vehicle load failure is truthful and retryable', (tester) async {
    await tester.pumpWidget(
      sheet(loadVehicles: () async => throw StateError('offline')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to load configured cabs'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.widget<FilledButton>(confirmButton()).onPressed, isNull);
  });
}
