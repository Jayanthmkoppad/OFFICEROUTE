import 'package:flutter_test/flutter_test.dart';
import 'package:officeroute/features/auth/session_access_gate.dart';

void main() {
  group('resolveSessionRoleRouteTarget', () {
    test(
      '1. maps role=employee, sessionRole=service_engineer -> serviceEngineer',
      () {
        final target = resolveSessionRoleRouteTarget(
          'employee',
          'service_engineer',
        );
        expect(target, SessionRoleRouteTarget.serviceEngineer);
      },
    );

    test(
      '2. maps role=employee, sessionRole=field_engineer -> serviceEngineer',
      () {
        final target = resolveSessionRoleRouteTarget(
          'employee',
          'field_engineer',
        );
        expect(target, SessionRoleRouteTarget.serviceEngineer);
      },
    );

    test('3. maps role=employee, sessionRole=office_employee -> employee', () {
      final target = resolveSessionRoleRouteTarget(
        'employee',
        'office_employee',
      );
      expect(target, SessionRoleRouteTarget.employee);
    });

    test('4. maps role=employee, sessionRole empty -> employee', () {
      final target = resolveSessionRoleRouteTarget('employee', '');
      expect(target, SessionRoleRouteTarget.employee);
    });

    test('5. maps role=driver, sessionRole=cab_driver -> driver', () {
      final target = resolveSessionRoleRouteTarget('driver', 'cab_driver');
      expect(target, SessionRoleRouteTarget.driver);
    });

    test('6. maps role=manager -> manager', () {
      final target = resolveSessionRoleRouteTarget('manager', '');
      expect(target, SessionRoleRouteTarget.manager);
    });

    test('7. maps exact admin aliases -> administrator', () {
      for (final alias in [
        'admin',
        'administrator',
        'application_owner',
        'owner',
      ]) {
        final target = resolveSessionRoleRouteTarget(alias, '');
        expect(
          target,
          SessionRoleRouteTarget.administrator,
          reason: 'Failed for alias: $alias',
        );
      }
    });

    test('8. maps role=ceo -> unsupported', () {
      expect(
        resolveSessionRoleRouteTarget('ceo', ''),
        SessionRoleRouteTarget.unsupported,
      );
      expect(
        resolveSessionRoleRouteTarget('', 'ceo'),
        SessionRoleRouteTarget.unsupported,
      );
    });

    test('9. normalizes uppercase and surrounding spaces correctly', () {
      expect(
        resolveSessionRoleRouteTarget('  ADMIN  ', ''),
        SessionRoleRouteTarget.administrator,
      );
      expect(
        resolveSessionRoleRouteTarget('employee', '  Office Employee  '),
        SessionRoleRouteTarget.employee,
      );
    });

    test('10. maps unknown role -> unsupported', () {
      expect(
        resolveSessionRoleRouteTarget('guest', 'unknown_role'),
        SessionRoleRouteTarget.unsupported,
      );
      expect(
        resolveSessionRoleRouteTarget('technician', ''),
        SessionRoleRouteTarget.unsupported,
      );
    });

    test('11. maps empty roles -> unsupported', () {
      expect(
        resolveSessionRoleRouteTarget('', ''),
        SessionRoleRouteTarget.unsupported,
      );
      expect(
        resolveSessionRoleRouteTarget('   ', '   '),
        SessionRoleRouteTarget.unsupported,
      );
    });
  });
}
