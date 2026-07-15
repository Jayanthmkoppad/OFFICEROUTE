import '../models/report_summary_model.dart';
import '../services/reports_service.dart';

class ReportsController {
  ReportsController._();

  static Future<ReportSummaryModel> loadMySummary() {
    return ReportsService.loadMySummary();
  }
}
