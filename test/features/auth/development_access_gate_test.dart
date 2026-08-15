import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:officeroute/features/auth/development_access_gate.dart';
import 'package:officeroute/features/auth/login_screen.dart';
import 'package:officeroute/features/auth/widgets/login_text_field.dart';
import 'package:officeroute/features/cab_driver/cab_driver_app.dart';
import 'package:officeroute/features/employee/employee_app.dart';
import 'package:officeroute/features/home/home_screen.dart';
import 'package:officeroute/features/manager/manager_screen.dart';
import 'package:officeroute/features/service_engineer/service_engineer_app.dart';

Widget _buildDevelopmentGate({
  bool debugMode = true,
  bool configured = true,
  String? firebaseUserId = 'firebase-uid-1',
  String? firebaseUserRole,
}) {
  return MaterialApp(
    home: DevelopmentAccessGate(
      debugMode: debugMode,
      configured: configured,
      firebaseUserId: firebaseUserId,
      firebaseUserRole: firebaseUserRole,
      realAuthentication: const LoginScreen(),
      roleAppBuilder: (role) => Scaffold(
        body: Center(
          child: Text('preview_${role.name}', key: Key('preview_${role.name}')),
        ),
      ),
    ),
  );
}

Future<void> _openPreview(WidgetTester tester, DevelopmentTestRole role) async {
  await tester.tap(find.byKey(Key('development_role_${role.name}')));
  await tester.pump();
}

void main() {
  test('release mode always disables DEV role preview', () {
    expect(
      shouldEnableDevelopmentRolePreview(debugMode: false, configured: true),
      isFalse,
    );
    expect(
      shouldEnableDevelopmentRolePreview(debugMode: true, configured: false),
      isFalse,
    );
    expect(
      shouldEnableDevelopmentRolePreview(debugMode: true, configured: true),
      isTrue,
    );
  });

  testWidgets('DEV selector warns preview does not impersonate Firebase', (
    tester,
  ) async {
    var realLoginRequested = false;
    await tester.pumpWidget(
      MaterialApp(
        home: DevelopmentRoleSelector(
          onSelected: (_) {},
          onUseRealLogin: () => realLoginRequested = true,
        ),
      ),
    );
    expect(
      find.textContaining('does not change Firebase identity'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('use_real_login')));
    expect(realLoginRequested, isTrue);
  });

  testWidgets('DEV=true opens Role Preview without email or password fields', (
    tester,
  ) async {
    await tester.pumpWidget(_buildDevelopmentGate());

    expect(find.text('WHO ARE YOU?'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(LoginTextField), findsNothing);
    expect(find.text('Email'), findsNothing);
    expect(find.text('Password'), findsNothing);
    expect(find.textContaining('DEV visual preview only'), findsOneWidget);
  });

  testWidgets('Employee preview opens with persistent DEV identity warning', (
    tester,
  ) async {
    await tester.pumpWidget(_buildDevelopmentGate());
    await _openPreview(tester, DevelopmentTestRole.employee);

    expect(find.byKey(const Key('preview_employee')), findsOneWidget);
    expect(find.text('DEV PREVIEW - EMPLOYEE'), findsOneWidget);
    expect(find.textContaining('Firebase identity unchanged'), findsOneWidget);
  });

  testWidgets('Cab Driver preview opens', (tester) async {
    await tester.pumpWidget(_buildDevelopmentGate());
    await _openPreview(tester, DevelopmentTestRole.cabDriver);

    expect(find.byKey(const Key('preview_cabDriver')), findsOneWidget);
    expect(find.text('DEV PREVIEW - CAB DRIVER'), findsOneWidget);
  });

  testWidgets('Manager preview opens', (tester) async {
    await tester.pumpWidget(_buildDevelopmentGate());
    await _openPreview(tester, DevelopmentTestRole.manager);

    expect(find.byKey(const Key('preview_manager')), findsOneWidget);
    expect(find.text('DEV PREVIEW - MANAGER'), findsOneWidget);
  });

  testWidgets('Admin preview opens', (tester) async {
    await tester.pumpWidget(_buildDevelopmentGate());
    await _openPreview(tester, DevelopmentTestRole.administrator);

    expect(find.byKey(const Key('preview_administrator')), findsOneWidget);
    expect(find.text('DEV PREVIEW - ADMIN'), findsOneWidget);
  });

  testWidgets('Switch DEV Role returns directly to selector', (tester) async {
    await tester.pumpWidget(_buildDevelopmentGate());
    await _openPreview(tester, DevelopmentTestRole.employee);

    await tester.tap(find.byKey(const Key('switch_dev_role')));
    await tester.pump();

    expect(find.text('WHO ARE YOU?'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('system back from preview returns directly to selector', (
    tester,
  ) async {
    await tester.pumpWidget(_buildDevelopmentGate());
    await _openPreview(tester, DevelopmentTestRole.cabDriver);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.text('WHO ARE YOU?'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('role preview preserves the supplied Firebase UID', (
    tester,
  ) async {
    const firebaseUid = 'firebase-uid-unchanged';
    await tester.pumpWidget(_buildDevelopmentGate(firebaseUserId: firebaseUid));

    await _openPreview(tester, DevelopmentTestRole.manager);

    final gate = tester.widget<DevelopmentAccessGate>(
      find.byType(DevelopmentAccessGate),
    );
    expect(gate.firebaseUserId, firebaseUid);
    expect(find.textContaining('Firebase identity unchanged'), findsOneWidget);
  });

  testWidgets('Use Real Login opens the unchanged email/password form', (
    tester,
  ) async {
    await tester.pumpWidget(_buildDevelopmentGate());

    await tester.tap(find.byKey(const Key('use_real_login')));
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(LoginTextField), findsNWidgets(2));
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.textContaining('DEV visual preview only'), findsNothing);
  });

  testWidgets('DEV=false opens normal login without DEV controls', (
    tester,
  ) async {
    await tester.pumpWidget(_buildDevelopmentGate(configured: false));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(LoginTextField), findsNWidgets(2));
    expect(find.byKey(const Key('use_real_login')), findsNothing);
  });

  testWidgets('release path never exposes DEV bypass even when configured', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildDevelopmentGate(debugMode: false, configured: true),
    );

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(LoginTextField), findsNWidgets(2));
    expect(find.text('WHO ARE YOU?'), findsNothing);
  });

  testWidgets('debug selector shows only the five existing role shells', (
    tester,
  ) async {
    DevelopmentTestRole? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: DevelopmentRoleSelector(
          onSelected: (role) => selected = role,
          onUseRealLogin: () {},
        ),
      ),
    );

    expect(find.text('WHO ARE YOU?'), findsOneWidget);
    for (final role in DevelopmentTestRole.values) {
      expect(find.text(role.label), findsOneWidget);
    }
    expect(find.textContaining('Approval'), findsNothing);

    await tester.tap(find.byKey(const Key('development_role_employee')));
    expect(selected, DevelopmentTestRole.employee);
  });

  testWidgets('selector does not persist or mutate role data', (tester) async {
    var selections = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DevelopmentRoleSelector(
          onSelected: (_) => selections++,
          onUseRealLogin: () {},
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('development_role_administrator')));
    expect(selections, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: DevelopmentRoleSelector(
          onSelected: (_) => selections++,
          onUseRealLogin: () {},
        ),
      ),
    );
    expect(find.text('WHO ARE YOU?'), findsOneWidget);
  });

  test('each development role maps to its existing application shell', () {
    expect(
      developmentRoleApp(DevelopmentTestRole.employee),
      isA<EmployeeApp>(),
    );
    expect(
      developmentRoleApp(DevelopmentTestRole.administrator),
      isA<HomeScreen>(),
    );
    expect(
      developmentRoleApp(DevelopmentTestRole.manager),
      isA<ManagerScreen>(),
    );
    expect(
      developmentRoleApp(DevelopmentTestRole.cabDriver),
      isA<CabDriverApp>(),
    );
    expect(
      developmentRoleApp(DevelopmentTestRole.serviceEngineer),
      isA<ServiceEngineerApp>(),
    );
  });
  testWidgets('DEV Admin to Cab Driver explains Firebase identity limitation', (
    tester,
  ) async {
    await tester.pumpWidget(_buildDevelopmentGate(firebaseUserRole: 'admin'));
    await _openPreview(tester, DevelopmentTestRole.cabDriver);
    expect(find.text('Cab Driver UI Preview'), findsOneWidget);
    expect(
      find.textContaining('Firebase identity is currently admin'),
      findsOneWidget,
    );
    expect(find.textContaining('Employee directory unavailable'), findsNothing);
    expect(find.byKey(const Key('preview_cabDriver')), findsNothing);
  });

  testWidgets(
    'DEV non-Employee preview explains invitation identity limitation',
    (tester) async {
      await tester.pumpWidget(_buildDevelopmentGate(firebaseUserRole: 'admin'));
      await _openPreview(tester, DevelopmentTestRole.employee);
      expect(find.text('Employee UI Preview'), findsOneWidget);
      expect(
        find.textContaining('Invitations are linked to Firebase user identity'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('preview_employee')), findsNothing);
    },
  );
}
