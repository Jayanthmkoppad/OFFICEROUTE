import '../../../core/models/user_model.dart';
import '../../../core/services/firestore_service.dart';

class ProfileService {
  ProfileService._();

  static Future<UserModel?> getProfile(String uid) async {
    return await FirestoreService.getUser(uid);
  }
}
