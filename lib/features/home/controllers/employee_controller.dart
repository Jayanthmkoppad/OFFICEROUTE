import '../../../core/models/employee_model.dart';
import '../../../core/services/employee_service.dart';

class EmployeeController {
  EmployeeController._();

  static Future<List<EmployeeModel>> fetchAll() async {
    return await EmployeeService.fetchAllEmployees();
  }
}
