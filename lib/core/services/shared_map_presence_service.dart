import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/live_location_model.dart';
import '../models/shared_map_presence_model.dart';
import '../models/user_model.dart';

class SharedMapPresenceService {
  SharedMapPresenceService._();

  static final _collection = FirebaseFirestore.instance.collection(
    'shared_map_presence',
  );
  static final Map<String, UserModel> _identityCache = {};

  static Stream<List<SharedMapPresenceModel>> watchActivePresence() {
    return _collection
        .where('status', whereIn: const ['active', 'paused'])
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SharedMapPresenceModel.fromMap(doc.data()))
              .where(
                (item) =>
                    item.userId.isNotEmpty &&
                    item.latitude != 0 &&
                    item.longitude != 0,
              )
              .toList(growable: false),
        );
  }

  static Future<void> publish(LiveLocationModel location) async {
    var user = _identityCache[location.userId];
    if (user == null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(location.userId)
          .get();
      final data = snapshot.data();
      if (data == null) return;
      user = UserModel.fromMap(data);
      _identityCache[location.userId] = user;
    }
    await _collection.doc(location.userId).set({
      'userId': location.userId,
      'displayName': user.name,
      'role': user.role,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'status': location.status,
      'updatedAt': Timestamp.fromDate(location.updatedAt),
    });
  }

  static Future<void> markOffline(String userId) {
    return _collection.doc(userId).set({
      'userId': userId,
      'status': 'offline',
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }
}
