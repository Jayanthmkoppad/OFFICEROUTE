import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/cab_assignment_member_model.dart';
import '../models/cab_assignment_model.dart';
import '../models/office_destination.dart';
import '../models/user_model.dart';

class CabAssignmentService {
  CabAssignmentService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('cab_assignments');

  static CollectionReference<Map<String, dynamic>> get _memberCollection =>
      _firestore.collection('cab_assignment_members');

  /// Creates a daily cab assignment document.
  static Future<String> createAssignment(CabAssignmentModel assignment) async {
    try {
      final docRef = await _collection.add(assignment.toMap());
      return docRef.id;
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabAssignmentService.createAssignment',
      );
      rethrow;
    }
  }

  /// Replaces an existing daily cab assignment document.
  static Future<void> updateAssignment(CabAssignmentModel assignment) async {
    if (assignment.id.isEmpty) {
      throw StateError(
        'CabAssignmentService.updateAssignment requires an assignment id.',
      );
    }

    try {
      await _collection.doc(assignment.id).set(assignment.toMap());
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabAssignmentService.updateAssignment',
      );
      rethrow;
    }
  }

  /// Loads one assignment by Firestore document id.
  static Future<CabAssignmentModel?> getAssignment(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      if (!doc.exists) {
        return null;
      }
      return CabAssignmentModel.fromMap(doc.data() ?? {}, id: doc.id);
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabAssignmentService.getAssignment',
      );
      rethrow;
    }
  }

  /// Loads assignments for a driver using the driver user id.
  static Future<List<CabAssignmentModel>> fetchAssignmentsForDriver({
    required String driverId,
  }) async {
    try {
      final snapshot = await _collection
          .where('driverId', isEqualTo: driverId)
          .get();
      final assignments = snapshot.docs
          .map((doc) => CabAssignmentModel.fromMap(doc.data(), id: doc.id))
          .toList();
      assignments.sort(_compareAssignmentsNewestFirst);
      return assignments;
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabAssignmentService.fetchAssignmentsForDriver',
      );
      rethrow;
    }
  }

  /// Loads the current daily assignment for a driver and date key.
  static Future<CabAssignmentModel?> fetchTodayAssignmentForDriver({
    required String driverId,
    required String dateKey,
  }) async {
    try {
      final snapshot = await _collection
          .where('driverId', isEqualTo: driverId)
          .get();
      final assignments = snapshot.docs
          .map((doc) => CabAssignmentModel.fromMap(doc.data(), id: doc.id))
          .where((assignment) => assignment.dateKey == dateKey)
          .toList(growable: false);
      if (assignments.isEmpty) return null;
      final sorted = [...assignments]..sort(_compareAssignmentsNewestFirst);
      return sorted.first;
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabAssignmentService.fetchTodayAssignmentForDriver',
      );
      rethrow;
    }
  }

  /// Loads the current daily assignment lookup for any assigned member.
  static Future<CabAssignmentMemberModel?> fetchTodayMemberAssignment({
    required String userId,
    required String dateKey,
  }) async {
    try {
      final snapshot = await _memberCollection
          .where('userId', isEqualTo: userId)
          .get();
      final members = snapshot.docs
          .map(
            (doc) => CabAssignmentMemberModel.fromMap(doc.data(), id: doc.id),
          )
          .where((member) => member.dateKey == dateKey)
          .toList(growable: false);
      if (members.isEmpty) return null;
      final sorted = [...members]..sort(_compareMembersNewestFirst);
      return sorted.first;
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabAssignmentService.fetchTodayMemberAssignment',
      );
      rethrow;
    }
  }

  /// Loads assignments for one date key.
  static Future<List<CabAssignmentModel>> fetchAssignmentsForDate({
    required String dateKey,
  }) async {
    try {
      final snapshot = await _collection
          .where('dateKey', isEqualTo: dateKey)
          .get();
      final assignments = snapshot.docs
          .map((doc) => CabAssignmentModel.fromMap(doc.data(), id: doc.id))
          .toList();
      assignments.sort(_compareAssignmentsNewestFirst);
      return assignments;
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabAssignmentService.fetchAssignmentsForDate',
      );
      rethrow;
    }
  }

  /// Emits when an assignment for [dateKey] changes.
  static Stream<void> watchAssignmentsForDate(String dateKey) {
    return _collection
        .where('dateKey', isEqualTo: dateKey)
        .snapshots()
        .map<void>((_) {});
  }

  /// Emits when an assignment member for [dateKey] changes.
  static Stream<void> watchMembersForDate(String dateKey) {
    return _memberCollection
        .where('dateKey', isEqualTo: dateKey)
        .snapshots()
        .map<void>((_) {});
  }

  /// Emits when this Driver's current-day invitations change.
  static Stream<void> watchInvitationsForDriver({
    required String driverId,
    required String dateKey,
  }) {
    return _memberCollection
        .where('dateKey', isEqualTo: dateKey)
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .map<void>((_) {});
  }

  /// Emits when one assignment document changes.
  static Stream<void> watchAssignment(String assignmentId) {
    return _collection.doc(assignmentId).snapshots().map<void>((_) {});
  }

  /// Emits when members of one assignment change.
  static Stream<void> watchMembersForAssignment(String assignmentId) {
    return _memberCollection
        .where('assignmentId', isEqualTo: assignmentId)
        .snapshots()
        .map<void>((_) {});
  }

  /// Emits when today's assignment lookup for one user changes.
  static Stream<void> watchMemberForUser({
    required String userId,
    required String dateKey,
  }) {
    return _memberCollection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map<void>((_) {});
  }

  /// Emits when today's driver assignment changes.
  static Stream<void> watchDriverAssignment({
    required String driverId,
    required String dateKey,
  }) {
    return _collection
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .map<void>((_) {});
  }

  /// Loads member lookup documents for a specific assignment/date.
  static Future<List<CabAssignmentMemberModel>> fetchMembersForAssignment({
    required String assignmentId,
    required String dateKey,
    String? status,
  }) async {
    try {
      final snapshot = await _memberCollection
          .where('assignmentId', isEqualTo: assignmentId)
          .get();
      final members = snapshot.docs
          .map(
            (doc) => CabAssignmentMemberModel.fromMap(doc.data(), id: doc.id),
          )
          .where(
            (member) =>
                member.dateKey == dateKey &&
                (status == null || member.status == status),
          )
          .toList();
      members.sort((left, right) => left.userId.compareTo(right.userId));
      return members;
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabAssignmentService.fetchMembersForAssignment',
      );
      rethrow;
    }
  }

  /// Loads member lookup documents for a date across assignments.
  static Future<List<CabAssignmentMemberModel>> fetchMembersForDate({
    required String dateKey,
    String? status,
  }) async {
    try {
      final snapshot = await _memberCollection
          .where('dateKey', isEqualTo: dateKey)
          .get();
      final members = snapshot.docs
          .map(
            (doc) => CabAssignmentMemberModel.fromMap(doc.data(), id: doc.id),
          )
          .where((member) => status == null || member.status == status)
          .toList();
      members.sort((left, right) => left.userId.compareTo(right.userId));
      return members;
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabAssignmentService.fetchMembersForDate',
      );
      rethrow;
    }
  }

  /// Writes or replaces assignment member lookup documents.
  static Future<void> upsertAssignmentMembers(
    List<CabAssignmentMemberModel> members,
  ) async {
    if (members.isEmpty) return;

    try {
      final batch = _firestore.batch();
      for (final member in members) {
        final id = member.id.isNotEmpty
            ? member.id
            : '${member.dateKey}_${member.userId}';
        batch.set(_memberCollection.doc(id), member.toMap());
      }
      await batch.commit();
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabAssignmentService.upsertAssignmentMembers',
      );
      rethrow;
    }
  }

  /// Updates one member lookup status.
  static Future<void> updateMemberStatus({
    required String memberId,
    required String status,
    String? role,
    String? driverId,
    String? vehicleId,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (role != null) updateData['role'] = role;
      if (driverId != null) updateData['driverId'] = driverId;
      if (vehicleId != null) updateData['vehicleId'] = vehicleId;

      await _memberCollection.doc(memberId).update(updateData);
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabAssignmentService.updateMemberStatus',
      );
      rethrow;
    }
  }

  /// Creates idempotent Driver-owned invitations for eligible Employees.
  static Future<void> sendTransportInvitations({
    required String driverId,
    required String vehicleId,
    required String shiftId,
    required String dateKey,
    required String branch,
    required String serviceCentre,
    required OfficeDestination destination,
    required List<UserModel> employees,
  }) async {
    if (employees.isEmpty) {
      throw StateError('Select at least one eligible Employee.');
    }
    final shiftRef = _firestore.collection('cab_driver_shifts').doc(shiftId);
    await _firestore.runTransaction<void>((transaction) async {
      final shift = await transaction.get(shiftRef);
      final shiftData = shift.data();
      if (!shift.exists ||
          shiftData == null ||
          shiftData['driverId'] != driverId ||
          shiftData['vehicleId'] != vehicleId ||
          shiftData['shiftStatus'] != 'active' ||
          shiftData['shiftDate'] != dateKey) {
        throw StateError('An active Driver duty is required.');
      }
      for (final employee in employees) {
        final sameScope =
            (branch.trim().isNotEmpty &&
                employee.branch.trim() == branch.trim()) ||
            (branch.trim().isEmpty &&
                serviceCentre.trim().isNotEmpty &&
                employee.serviceCentre.trim() == serviceCentre.trim());
        if (employee.uid.isEmpty ||
            employee.role.trim().toLowerCase() != 'employee' ||
            !sameScope) {
          throw StateError('An Employee is outside the Driver scope.');
        }
        final memberId = '${dateKey}_${employee.uid}';
        final memberRef = _memberCollection.doc(memberId);
        final existing = await transaction.get(memberRef);
        if (existing.exists) {
          final data = existing.data()!;
          if (data['driverId'] == driverId &&
              data['shiftId'] == shiftId &&
              data['invitationStatus'] != 'cancelled') {
            continue;
          }
          throw StateError(
            'Employee ${employee.uid} already has transport activity today.',
          );
        }
        final pickupAddress = employee.preferredPickupAddress.trim();
        final pickupLatitude = employee.preferredPickupLatitude;
        final pickupLongitude = employee.preferredPickupLongitude;
        final pickupValid =
            pickupAddress.isNotEmpty &&
            pickupLatitude != null &&
            pickupLongitude != null &&
            pickupLatitude.isFinite &&
            pickupLongitude.isFinite &&
            pickupLatitude >= -90 &&
            pickupLatitude <= 90 &&
            pickupLongitude >= -180 &&
            pickupLongitude <= 180;
        final now = DateTime.now();
        final invitation = CabAssignmentMemberModel(
          id: memberId,
          dateKey: dateKey,
          userId: employee.uid,
          role: 'employee',
          branch: employee.branch.trim(),
          serviceCentre: employee.serviceCentre.trim(),
          operationalDay: DateTime.parse(dateKey),
          driverId: driverId,
          vehicleId: vehicleId,
          status: 'invited',
          invitationStatus: 'invited',
          shiftId: shiftId,
          invitedAt: now,
          officeName: destination.name,
          officeAddress: destination.address,
          officeLatitude: destination.latitude,
          officeLongitude: destination.longitude,
          pickupName: pickupValid ? pickupAddress : '',
          pickupAddress: pickupValid ? pickupAddress : '',
          pickupLatitude: pickupValid ? pickupLatitude : null,
          pickupLongitude: pickupValid ? pickupLongitude : null,
          createdAt: now,
          updatedAt: now,
        );
        transaction.set(memberRef, invitation.toMap());
        final notificationRef = _firestore
            .collection('notifications')
            .doc('${shiftId}_${employee.uid}_invited');
        transaction.set(notificationRef, <String, Object?>{
          'id': notificationRef.id,
          'userId': employee.uid,
          'title':
              'Cab available for today'
              's office trip',
          'body':
              '${destination.name} - view Driver, cab, destination and respond.',
          'type': 'cab_transport_invitation',
          'source': 'transport_invitation',
          'driverId': driverId,
          'shiftId': shiftId,
          'memberId': memberId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'readAt': null,
        });
      }
    });
  }

  /// Applies the signed-in Employee's response without changing Driver-owned
  /// vehicle, shift, destination, identity, assignment, or trip fields.
  static Future<CabAssignmentMemberModel> respondToTransportInvitation({
    required String memberId,
    required String employeeId,
    required bool accept,
    String declineReason = '',
    String pickupName = '',
    String pickupAddress = '',
    double? pickupLatitude,
    double? pickupLongitude,
  }) async {
    final ref = _memberCollection.doc(memberId);
    return _firestore.runTransaction<CabAssignmentMemberModel>((
      transaction,
    ) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists || snapshot.data() == null) {
        throw StateError('Transport invitation is no longer available.');
      }
      final current = CabAssignmentMemberModel.fromMap(
        snapshot.data()!,
        id: snapshot.id,
      );
      if (current.userId != employeeId ||
          current.invitationStatus != 'invited' ||
          current.status != 'invited') {
        throw StateError('Transport invitation cannot be changed.');
      }
      final now = DateTime.now();
      if (!accept) {
        final declined = current.copyWith(
          status: 'declined',
          invitationStatus: 'declined',
          declineReason: declineReason.trim(),
          respondedAt: now,
          updatedAt: now,
        );
        transaction.update(ref, <String, Object?>{
          'status': 'declined',
          'invitationStatus': 'declined',
          'declineReason': declineReason.trim(),
          'respondedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return declined;
      }
      final normalizedAddress = pickupAddress.trim().isNotEmpty
          ? pickupAddress.trim()
          : current.pickupAddress.trim();
      final normalizedName = pickupName.trim().isNotEmpty
          ? pickupName.trim()
          : (current.pickupName.trim().isNotEmpty
                ? current.pickupName.trim()
                : normalizedAddress);
      final latitude = pickupLatitude ?? current.pickupLatitude;
      final longitude = pickupLongitude ?? current.pickupLongitude;
      if (normalizedName.isEmpty ||
          normalizedAddress.isEmpty ||
          latitude == null ||
          longitude == null ||
          !latitude.isFinite ||
          !longitude.isFinite ||
          latitude < -90 ||
          latitude > 90 ||
          longitude < -180 ||
          longitude > 180) {
        throw StateError('Set your pickup location before accepting.');
      }
      final accepted = current.copyWith(
        status: 'accepted',
        invitationStatus: 'accepted',
        pickupName: normalizedName,
        pickupAddress: normalizedAddress,
        pickupLatitude: latitude,
        pickupLongitude: longitude,
        respondedAt: now,
        updatedAt: now,
      );
      transaction.update(ref, <String, Object?>{
        'status': 'accepted',
        'invitationStatus': 'accepted',
        'declineReason': '',
        'pickupName': normalizedName,
        'pickupAddress': normalizedAddress,
        'pickupLatitude': latitude,
        'pickupLongitude': longitude,
        'pickupValid': true,
        'respondedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return accepted;
    });
  }

  /// Creates the signed-in Employee's stable current-day pickup request.
  /// The deterministic document id prevents duplicate requests after retries.
  static Future<CabAssignmentMemberModel> createEmployeePickupRequest({
    required String userId,
    required String dateKey,
    required String pickupName,
    required String pickupAddress,
    required double pickupLatitude,
    required double pickupLongitude,
    required String branch,
    required String serviceCentre,
    required String activeLocationSessionId,
  }) async {
    final id = '${dateKey}_$userId';
    final ref = _memberCollection.doc(id);
    final now = DateTime.now();
    return _firestore.runTransaction<CabAssignmentMemberModel>((tx) async {
      final existing = await tx.get(ref);
      if (existing.exists && existing.data() != null) {
        return CabAssignmentMemberModel.fromMap(existing.data()!, id: id);
      }
      final request = CabAssignmentMemberModel(
        id: id,
        assignmentId: '',
        dateKey: dateKey,
        userId: userId,
        role: 'employee',
        branch: branch.trim(),
        serviceCentre: serviceCentre.trim(),
        operationalDay: DateTime.parse(dateKey),
        driverId: '',
        vehicleId: '',
        status: 'assigned',
        pickupName: pickupName.trim(),
        pickupAddress: pickupAddress.trim(),
        pickupLatitude: pickupLatitude,
        pickupLongitude: pickupLongitude,
        createdAt: now,
        updatedAt: now,
      );
      tx.set(ref, request.toMap());
      return request;
    });
  }

  /// Updates only an Employee-owned, unclaimed request readiness/cancellation.
  static Future<void> updateEmployeePickupRequestStatus({
    required String memberId,
    required String status,
  }) async {
    if (!const {'assigned', 'ready', 'cancelled'}.contains(status)) {
      throw StateError('Unsupported Employee pickup request status.');
    }
    await _memberCollection.doc(memberId).update(<String, Object?>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Loads open unclaimed member requests for a date.
  static Future<List<CabAssignmentMemberModel>> fetchOpenRequestsForDate({
    required String dateKey,
    required String branch,
    required String serviceCentre,
    required String activeLocationSessionId,
  }) async {
    try {
      final snapshot = await _memberCollection
          .where('dateKey', isEqualTo: dateKey)
          .where('operationalDay', isEqualTo: DateTime.parse(dateKey))
          .where('role', isEqualTo: 'employee')
          .where('pickupValid', isEqualTo: true)
          .where('driverId', isEqualTo: '')
          .where('status', isEqualTo: 'ready')
          .where(
            branch.trim().isNotEmpty ? 'branch' : 'serviceCentre',
            isEqualTo: branch.trim().isNotEmpty
                ? branch.trim()
                : serviceCentre.trim(),
          )
          .get();
      final members = snapshot.docs
          .map(
            (doc) => CabAssignmentMemberModel.fromMap(doc.data(), id: doc.id),
          )
          .where(
            (member) =>
                member.driverId.trim().isEmpty &&
                member.pickupAddress.trim().isNotEmpty &&
                member.status == 'ready',
          )
          .toList();
      members.sort((a, b) => a.userId.compareTo(b.userId));
      return members;
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabAssignmentService.fetchOpenRequestsForDate',
      );
      rethrow;
    }
  }

  /// Atomically claims selected unclaimed member requests and creates an active trip document in a single Firestore transaction.
  static Future<String> claimMembersAndCreateTripTransaction({
    required String driverId,
    required String vehicleId,
    required String dateKey,
    required List<String> memberIds,
    required String officeName,
    required String officeAddress,
    required double officeLatitude,
    required double officeLongitude,
    required String branch,
    required String serviceCentre,
    required String activeLocationSessionId,
  }) async {
    if (memberIds.isEmpty) {
      throw StateError('Cannot create trip with zero selected passengers.');
    }
    if (officeName.trim().isEmpty ||
        officeAddress.trim().isEmpty ||
        !officeLatitude.isFinite ||
        !officeLongitude.isFinite ||
        officeLatitude < -90 ||
        officeLatitude > 90 ||
        officeLongitude < -180 ||
        officeLongitude > 180) {
      throw StateError('Office destination is not configured.');
    }
    if (branch.trim().isEmpty && serviceCentre.trim().isEmpty) {
      throw StateError('Driver branch or service centre is not configured.');
    }

    try {
      return await _firestore.runTransaction<String>((transaction) async {
        // 1. Verify driver active shift exists
        final shiftDocRef = _firestore
            .collection('cab_driver_shifts')
            .doc('${dateKey}_$driverId');
        final shiftDoc = await transaction.get(shiftDocRef);
        if (!shiftDoc.exists || shiftDoc.data()?['shiftStatus'] != 'active') {
          throw StateError(
            'Active driver duty shift is required to start a trip.',
          );
        }
        if ((shiftDoc.data()?['vehicleId'] ?? '').toString() != vehicleId) {
          throw StateError(
            'The selected vehicle does not match the active shift.',
          );
        }

        // 2. Re-read every selected member request inside the transaction
        final memberDocs = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final id in memberIds) {
          final ref = _memberCollection.doc(id);
          final doc = await transaction.get(ref);
          if (!doc.exists) {
            throw StateError('Selected request $id no longer exists.');
          }
          final data = doc.data()!;
          final currentDriver = (data['driverId'] ?? '').toString();
          final currentStatus = (data['status'] ?? '').toString();
          final date = (data['dateKey'] ?? '').toString();
          final pickupAddr = (data['pickupAddress'] ?? '').toString();
          final requestBranch = (data['branch'] ?? '').toString();
          final requestCentre = (data['serviceCentre'] ?? '').toString();

          if (date != dateKey) {
            throw StateError(
              'Request $id is for date $date, expected $dateKey.',
            );
          }
          final invitationStatus = (data['invitationStatus'] ?? '').toString();
          final invitationShiftId = (data['shiftId'] ?? '').toString();
          if (currentDriver != driverId) {
            throw StateError('Invitation $id does not belong to this Driver.');
          }
          if (currentStatus != 'accepted' || invitationStatus != 'accepted') {
            throw StateError(
              'Invitation $id is not accepted ($currentStatus).',
            );
          }
          if (invitationShiftId != shiftDocRef.id) {
            throw StateError('Invitation $id belongs to another duty.');
          }
          if (pickupAddr.trim().isEmpty) {
            throw StateError(
              'Request $id is missing an approved pickup address.',
            );
          }
          final sameScope =
              (branch.trim().isNotEmpty && requestBranch == branch.trim()) ||
              (branch.trim().isEmpty &&
                  serviceCentre.trim().isNotEmpty &&
                  requestCentre == serviceCentre.trim());
          if (!sameScope) {
            throw StateError(
              'Request $id is outside the Driver operational scope.',
            );
          }
          memberDocs.add(doc);
        }

        // 3. Create the new cab trip document
        final tripId = 'trip_${dateKey}_$driverId';
        final tripRef = _firestore.collection('cab_trips').doc(tripId);
        final existingTrip = await transaction.get(tripRef);
        if (existingTrip.exists && existingTrip.data()?['status'] == 'active') {
          return tripId; // Idempotent recovery
        }

        final empIds = memberDocs
            .map((doc) => doc.data()!['userId'].toString())
            .toList();
        final assignmentId = 'plan_${dateKey}_$driverId';
        final assignmentRef = _firestore
            .collection('cab_assignments')
            .doc(assignmentId);
        transaction.set(assignmentRef, <String, Object?>{
          'dateKey': dateKey,
          'assignmentDate': Timestamp.fromDate(DateTime.parse(dateKey)),
          'driverId': driverId,
          'vehicleId': vehicleId,
          'employeeIds': empIds,
          'officeName': officeName.trim(),
          'officeAddress': officeAddress.trim(),
          'officeLatitude': officeLatitude,
          'officeLongitude': officeLongitude,
          'branch': branch.trim(),
          'serviceCentre': serviceCentre.trim(),
          'status': 'started',
          'assignedBy': driverId,
          'assignedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'remarks': 'Created from accepted Driver invitations.',
        });

        transaction.set(tripRef, {
          'driverId': driverId,
          'vehicleId': vehicleId,
          'assignmentId': assignmentId,
          'dateKey': dateKey,
          'status': 'active',
          'activeLocationSessionId': activeLocationSessionId,
          'startedAt': FieldValue.serverTimestamp(),
          'officeName': officeName.trim(),
          'officeAddress': officeAddress.trim(),
          'officeLatitude': officeLatitude,
          'officeLongitude': officeLongitude,
          'branch': branch.trim(),
          'serviceCentre': serviceCentre.trim(),
          'employeeIds': empIds,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 4. Update member lookup documents & create riders under cab_trips/{tripId}/riders
        int pickupOrder = 1;
        for (final doc in memberDocs) {
          final mData = doc.data()!;
          final empId = mData['userId'].toString();

          transaction.update(doc.reference, {
            'assignmentId': assignmentId,
            'driverId': driverId,
            'vehicleId': vehicleId,
            'status': 'claimed',
            'invitationStatus': 'trip_active',
            'updatedAt': FieldValue.serverTimestamp(),
          });

          final riderRef = tripRef.collection('riders').doc(empId);
          final sequence = pickupOrder++;
          transaction.set(riderRef, {
            'tripId': tripId,
            'assignmentId': assignmentId,
            'employeeId': empId,
            'status': 'ready',
            'pickupOrder': sequence,
            'pickupName': mData['pickupName'] ?? '',
            'pickupAddress': mData['pickupAddress'] ?? '',
            'pickupLatitude': mData['pickupLatitude'],
            'pickupLongitude': mData['pickupLongitude'],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          transaction.set(
            tripRef.collection('passenger_progress').doc(empId),
            <String, Object?>{
              'employeeId': empId,
              'passengerDisplayName': '',
              'employeeCode': '',
              'roleLabel': 'Employee',
              'pickupSequence': sequence,
              'status': 'ready',
              'remark': 'ready',
              'attendanceActive': false,
              'transportActive': true,
              'distanceToPickupMeters': null,
              'estimatedReadyMinutes': null,
              'locationFreshness': 'unknown',
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );

          final notificationRef = _firestore
              .collection('notifications')
              .doc('${tripId}_${empId}_started');
          transaction.set(notificationRef, <String, Object?>{
            'id': notificationRef.id,
            'userId': empId,
            'title': 'Driver assigned',
            'body':
                'Your Driver and vehicle are assigned. The trip has started.',
            'type': 'cab_trip_started',
            'source': 'trip_event',
            'tripId': tripId,
            'assignmentId': assignmentId,
            'driverId': driverId,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
            'readAt': null,
          });
        }

        return tripId;
      });
    } catch (error, stackTrace) {
      _printFirestoreException(
        error: error,
        stackTrace: stackTrace,
        method: 'CabAssignmentService.claimMembersAndCreateTripTransaction',
      );
      rethrow;
    }
  }

  static void _printFirestoreException({
    required Object error,
    required StackTrace stackTrace,
    required String method,
  }) {
    debugPrint('Firestore exception');
    debugPrint('File: lib/core/services/cab_assignment_service.dart');
    debugPrint('Method: $method');
    debugPrint('Runtime type: ${error.runtimeType}');

    if (error is FirebaseException) {
      debugPrint('FirebaseException.plugin: ${error.plugin}');
      debugPrint('FirebaseException.code: ${error.code}');
      debugPrint('FirebaseException.message: ${error.message}');
    }

    debugPrint('Exception: $error');
    debugPrint('Stack trace:\n$stackTrace');
  }

  static int _compareAssignmentsNewestFirst(
    CabAssignmentModel left,
    CabAssignmentModel right,
  ) {
    final leftTime = left.assignedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final rightTime =
        right.assignedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return rightTime.compareTo(leftTime);
  }

  static int _compareMembersNewestFirst(
    CabAssignmentMemberModel left,
    CabAssignmentMemberModel right,
  ) {
    final leftTime =
        left.updatedAt ??
        left.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final rightTime =
        right.updatedAt ??
        right.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return rightTime.compareTo(leftTime);
  }
}
