import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:officeroute/core/models/passenger_progress_model.dart';
import 'package:officeroute/features/employee/widgets/employee_transport_roster_card.dart';

void main() {
  const own = PassengerProgressModel(
    employeeId: 'me',
    passengerDisplayName: 'Appu',
    employeeCode: '001',
    roleLabel: 'Administrator',
    pickupSequence: 2,
    status: 'waiting',
    distanceToPickupMeters: 143,
    estimatedReadyMinutes: 7,
    locationFreshness: 'live',
  );
  const other = PassengerProgressModel(
    employeeId: 'other',
    passengerDisplayName: 'Jayanth',
    employeeCode: '002',
    pickupSequence: 1,
    status: 'on_the_way',
    distanceToPickupMeters: 1249,
    estimatedReadyMinutes: 7,
    locationFreshness: 'stale',
  );

  Widget subject({
    List<PassengerProgressModel> progress = const [own, other],
    Future<void> Function(String)? onUpdate,
    bool canUpdateOwnStatus = false,
    String diagnosticCode = 'ok',
    bool hasConfiguredRoute = true,
  }) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: EmployeeTransportRosterCard(
          progress: progress,
          currentUserId: 'me',
          onUpdateStatus: onUpdate,
          canUpdateOwnStatus: canUpdateOwnStatus,
          diagnosticCode: diagnosticCode,
          hasConfiguredRoute: hasConfiguredRoute,
          homeStyle: true,
        ),
      ),
    );
  }

  testWidgets('shows five ordered employee transport fields', (tester) async {
    await tester.pumpWidget(subject());
    expect(find.text("TODAY'S EMPLOYEES"), findsOneWidget);
    expect(find.text('Jayanth'), findsOneWidget);
    expect(find.text('Appu (You)'), findsOneWidget);
    expect(find.text('LOCATION'), findsNWidgets(2));
    expect(find.text('DISTANCE'), findsNWidgets(2));
    expect(find.text('ETA'), findsNWidgets(2));
  });

  testWidgets('only own row exposes status editing', (tester) async {
    await tester.pumpWidget(
      subject(onUpdate: (_) async {}, canUpdateOwnStatus: true),
    );
    expect(
      find.byKey(const Key('update_transport_status_button')),
      findsOneWidget,
    );
  });

  testWidgets('sanitizes other employee distance and ETA', (tester) async {
    await tester.pumpWidget(subject());
    expect(find.text('1.2 km'), findsOneWidget);
    expect(find.text('About 5 min'), findsOneWidget);
    expect(find.text('143 m'), findsOneWidget);
    expect(find.text('7 min'), findsOneWidget);
  });

  testWidgets('status sheet exposes all allowed remarks', (tester) async {
    String? selected;
    await tester.pumpWidget(
      subject(
        canUpdateOwnStatus: true,
        onUpdate: (value) async {
          selected = value;
        },
      ),
    );
    await tester.tap(find.byKey(const Key('update_transport_status_button')));
    await tester.pumpAndSettle();
    for (final label in const [
      'Waiting',
      'Go To Pickup',
      'On The Way',
      'Ready',
      'Running Late',
      'Not Coming',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    await tester.tap(find.text('Not Coming'));
    await tester.pumpAndSettle();
    expect(selected, 'not_coming');
  });

  testWidgets('empty route has an honest empty state', (tester) async {
    await tester.pumpWidget(
      subject(progress: const [], hasConfiguredRoute: false),
    );
    expect(find.text('No active route for today.'), findsOneWidget);
  });

  testWidgets('status controls stay hidden outside an active trip', (
    tester,
  ) async {
    await tester.pumpWidget(subject(onUpdate: (_) async {}));
    expect(
      find.byKey(const Key('update_transport_status_button')),
      findsNothing,
    );
  });

  testWidgets('permission failure has a specific roster state', (tester) async {
    await tester.pumpWidget(
      subject(progress: const [], diagnosticCode: 'permission_denied'),
    );
    expect(
      find.text('Permission denied while loading today\'s transport roster.'),
      findsOneWidget,
    );
  });

  testWidgets('roster fits a narrow phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(subject());
    expect(tester.takeException(), isNull);
  });
}
