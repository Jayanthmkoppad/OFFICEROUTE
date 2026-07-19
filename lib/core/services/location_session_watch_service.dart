import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/location_session_model.dart';

/// Read-only aggregator over the existing `location_sessions` collection
/// so admin views can efficiently see who currently has a valid, active
/// work-location session. This service never writes; it only projects the
/// existing session data.
class LocationSessionWatchService {
  LocationSessionWatchService._();

  static final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('location_sessions');

  /// Streams sessions whose status is `active` or `paused`. Stopped sessions
  /// are excluded so administrators only see people currently working.
  static Stream<List<LocationSessionModel>> watchActiveSessions() {
    return _collection
        .where('status', whereIn: const ['active', 'paused'])
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => LocationSessionModel.fromMap(doc.data(), id: doc.id),
              )
              .toList(growable: false),
        );
  }
}
