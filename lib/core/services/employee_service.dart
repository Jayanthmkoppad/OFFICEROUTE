import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/employee_model.dart';

class EmployeeService {
  EmployeeService._();

  static Future<List<EmployeeModel>> fetchAllEmployees() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'employee')
          .get();

      return snapshot.docs.map((d) => EmployeeModel.fromMap(d.data())).toList();
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
