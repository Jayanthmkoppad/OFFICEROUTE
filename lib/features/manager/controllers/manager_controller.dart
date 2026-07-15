import '../models/manager_employee_summary_model.dart';
import '../services/manager_service.dart';

class ManagerController {
  ManagerController._();

  static Future<List<ManagerEmployeeSummaryModel>> loadEmployeeSummaries() {
    return ManagerService.loadEmployeeSummaries();
  }
}
