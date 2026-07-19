import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/employee_model.dart';

class EmployeeService {
  EmployeeService._();

  /// Returns all usable user profiles for cab pickup selection.
  ///
  /// OfficeRoute treats every signed-in/approved profile as a possible pickup
  /// person for testing and operations. Admin/manager accounts are therefore
  /// visible in the cab selector too, while the driver screen removes only the
  /// currently signed-in driver from the list.
  static Future<List<EmployeeModel>> fetchAllEmployees() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      final users = snapshot.docs
          .map((doc) {
            final data = doc.data();
            return EmployeeModel.fromMap({
              ...data,
              'uid': (data['uid'] ?? doc.id).toString(),
            });
          })
          .where((employee) {
            return employee.uid.trim().isNotEmpty &&
                (employee.name.trim().isNotEmpty ||
                    employee.email.trim().isNotEmpty ||
                    employee.phone.trim().isNotEmpty);
          })
          .toList();

      users.sort((a, b) {
        final aName = a.name.trim().isEmpty ? a.email : a.name;
        final bName = b.name.trim().isEmpty ? b.email : b.name;
        return aName.toLowerCase().compareTo(bName.toLowerCase());
      });

      return users;
    } catch (error, stackTrace) {
      debugPrint('Firestore exception');
      debugPrint('File: lib/core/services/employee_service.dart');
      debugPrint('Method: EmployeeService.fetchAllEmployees');
      debugPrint('Runtime type: ${error.runtimeType}');

      if (error is FirebaseException) {
        debugPrint('FirebaseException.plugin: ${error.plugin}');
        debugPrint('FirebaseException.code: ${error.code}');
        debugPrint('FirebaseException.message: ${error.message}');
      }

      debugPrint('Exception: $error');
      debugPrint('Stack trace:\n$stackTrace');
      rethrow;
    }
  }
}
