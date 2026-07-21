import 'package:flutter_test/flutter_test.dart';
import 'package:officeroute/core/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('converts to and from a map without losing data', () {
      const user = UserModel(
        uid: 'user-1',
        name: 'Test User',
        email: 'test@example.com',
        phone: '1234567890',
        role: 'employee',
        profileImage: 'profile.png',
      );

      final restoredUser = UserModel.fromMap(user.toMap());

      expect(restoredUser.uid, user.uid);
      expect(restoredUser.name, user.name);
      expect(restoredUser.email, user.email);
      expect(restoredUser.phone, user.phone);
      expect(restoredUser.role, user.role);
      expect(restoredUser.profileImage, user.profileImage);
    });

    test('uses empty defaults for missing fields', () {
      final user = UserModel.fromMap(const {});

      expect(user.uid, '');
      expect(user.name, '');
      expect(user.email, '');
      expect(user.phone, '');
      expect(user.role, '');
      expect(user.profileImage, '');
    });
  });
}
