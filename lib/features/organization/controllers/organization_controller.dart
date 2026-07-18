import '../services/organization_service.dart';

class OrganizationController {
  OrganizationController._();

  static Future<OrganizationOperationsSnapshot> loadOperations(DateTime day) {
    return OrganizationService.loadOperations(day);
  }

  static Stream<void> watchOperations(DateTime day) {
    return OrganizationService.watchOperations(day);
  }
}
