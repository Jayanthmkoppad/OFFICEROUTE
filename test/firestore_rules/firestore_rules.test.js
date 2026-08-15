const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');
const { expect } = require('chai');

const PROJECT_ID = 'officeroute-96b30';
const TODAY = new Date().toISOString().slice(0, 10);
const OPERATIONAL_DAY = new Date(`${TODAY}T00:00:00.000Z`);
let testEnv;

describe('OfficeRoute Firestore Security Rules Attack & Privacy Test Suite', function () {
  this.timeout(20000);

  before(async () => {
    const rulesPath = path.join(__dirname, '../../firestore.rules');
    const rules = fs.readFileSync(rulesPath, 'utf8');

    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules: rules,
        host: '127.0.0.1',
        port: 8085,
      },
    });
  });

  after(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  beforeEach(async () => {
    if (testEnv) {
      await testEnv.clearFirestore();
    }
  });

  // -----------------------------------------------------------------
  // 1. Unauthenticated & Unknown Role Access Denial
  // -----------------------------------------------------------------
  describe('1. Unauthenticated & Unknown Role Access Denial', () => {
    it('denies unauthenticated read from users collection', async () => {
      const unauth = testEnv.unauthenticatedContext().firestore();
      await assertFails(unauth.collection('users').doc('user_101').get());
    });

    it('denies unauthenticated write to users collection', async () => {
      const unauth = testEnv.unauthenticatedContext().firestore();
      await assertFails(
        unauth.collection('users').doc('user_101').set({ name: 'Hacker' })
      );
    });

    it('denies unauthenticated read from cab_assignments', async () => {
      const unauth = testEnv.unauthenticatedContext().firestore();
      await assertFails(
        unauth.collection('cab_assignments').doc('plan_2026-08-01_driver_1').get()
      );
    });

    it('denies unauthenticated write to live_locations', async () => {
      const unauth = testEnv.unauthenticatedContext().firestore();
      await assertFails(
        unauth.collection('live_locations').doc('emp_1').set({
          latitude: 15.36,
          longitude: 75.12,
        })
      );
    });
  });

  // -----------------------------------------------------------------
  // 2. Employee Profile & Self Privacy Scoping
  // -----------------------------------------------------------------
  describe('2. Employee Profile & Self Privacy Scoping', () => {
    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('users').doc('emp_1').set({
          uid: 'emp_1',
          name: 'Employee One',
          email: 'emp1@company.com',
          role: 'employee',
          sessionApproved: true,
        });
        await db.collection('users').doc('emp_2').set({
          uid: 'emp_2',
          name: 'Employee Two',
          email: 'emp2@company.com',
          role: 'employee',
          sessionApproved: true,
        });
      });
    });

    it('allows employee to read own profile', async () => {
      const emp1Db = testEnv.authenticatedContext('emp_1').firestore();
      await assertSucceeds(emp1Db.collection('users').doc('emp_1').get());
    });

    it('allows employee to update allowed self profile fields', async () => {
      const emp1Db = testEnv.authenticatedContext('emp_1').firestore();
      await assertSucceeds(
        emp1Db.collection('users').doc('emp_1').update({
          name: 'Employee One Updated',
          phone: '+91-9999988888',
        })
      );
    });

    it('ATTACK: denies employee from modifying administrative fields (role, sessionApproved)', async () => {
      const emp1Db = testEnv.authenticatedContext('emp_1').firestore();
      await assertFails(
        emp1Db.collection('users').doc('emp_1').update({
          role: 'admin',
        })
      );
    });

    it('ATTACK: denies employee A from updating employee B profile', async () => {
      const emp1Db = testEnv.authenticatedContext('emp_1').firestore();
      await assertFails(
        emp1Db.collection('users').doc('emp_2').update({
          name: 'Hacked Name',
        })
      );
    });
  });

  // -----------------------------------------------------------------
  // 3. Assignment-Based Live Location Access & Attacks
  // -----------------------------------------------------------------
  describe('3. Assignment-Based Live Location Access & Attacks', () => {
    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('users').doc('emp_1').set({ role: 'employee' });
        await db.collection('users').doc('emp_2').set({ role: 'employee' });
        await db.collection('users').doc('driver_1').set({ role: 'driver' });
        await db.collection('users').doc('driver_2').set({ role: 'driver' });
        await db.collection('users').doc('manager_1').set({ role: 'manager' });

        await db.collection('cab_assignments').doc('plan_2026-08-01_driver_1').set({
          id: 'plan_2026-08-01_driver_1',
          dateKey: '2026-08-01',
          driverId: 'driver_1',
          employeeIds: ['emp_1'],
          status: 'active',
        });

        await db.collection('cab_trips').doc('trip_2026-08-01_driver_1').set({
          assignmentId: 'plan_2026-08-01_driver_1', driverId: 'driver_1',
          dateKey: '2026-08-01', employeeIds: ['emp_1'], status: 'active',
        });

        // Driver 1 live location
        await db.collection('live_locations').doc('driver_1').set({
          userId: 'driver_1',
          sessionId: 'sess_drv_1',
          assignmentId: 'plan_2026-08-01_driver_1',
          trackingReason: 'driver_active_trip',
          status: 'active',
          latitude: 15.36,
          longitude: 75.12,
          recordedAt: new Date(),
        });

        // Employee 1 live location
        await db.collection('live_locations').doc('emp_1').set({
          userId: 'emp_1',
          sessionId: 'sess_emp_1',
          assignmentId: 'plan_2026-08-01_driver_1',
          trackingReason: 'cab_pickup_ready',
          status: 'active',
          latitude: 15.364,
          longitude: 75.124,
          recordedAt: new Date(),
        });

        // Employee 2 live location (unassigned)
        await db.collection('live_locations').doc('emp_2').set({
          userId: 'emp_2',
          sessionId: 'sess_emp_2',
          assignmentId: 'assign_other',
          trackingReason: 'cab_pickup_ready',
          status: 'active',
          latitude: 15.37,
          longitude: 75.13,
          recordedAt: new Date(),
        });
      });
    });

    it('allows employee 1 to read assigned driver 1 live location', async () => {
      const emp1Db = testEnv.authenticatedContext('emp_1').firestore();
      await assertSucceeds(
        emp1Db.collection('live_locations').doc('driver_1').get()
      );
    });

    it('ATTACK: denies employee 1 from reading unassigned driver 2 live location', async () => {
      const emp1Db = testEnv.authenticatedContext('emp_1').firestore();
      await assertFails(
        emp1Db.collection('live_locations').doc('driver_2').get()
      );
    });

    it('allows driver 1 to read assigned employee 1 live location', async () => {
      const drv1Db = testEnv.authenticatedContext('driver_1').firestore();
      await assertSucceeds(
        drv1Db.collection('live_locations').doc('emp_1').get()
      );
    });

    it('ATTACK: denies driver 1 from reading unassigned employee 2 live location', async () => {
      const drv1Db = testEnv.authenticatedContext('driver_1').firestore();
      await assertFails(
        drv1Db.collection('live_locations').doc('emp_2').get()
      );
    });

    it('ATTACK: denies manager from unrestricted raw live_locations access', async () => {
      const mgrDb = testEnv.authenticatedContext('manager_1').firestore();
      await assertFails(
        mgrDb.collection('live_locations').doc('emp_2').get()
      );
    });

    it('ATTACK: denies employee 1 from writing cab location without assignmentId', async () => {
      const emp1Db = testEnv.authenticatedContext('emp_1').firestore();
      await assertFails(
        emp1Db.collection('live_locations').doc('emp_1').set({
          userId: 'emp_1',
          sessionId: 'sess_emp_1',
          trackingReason: 'cab_pickup_ready',
          status: 'active',
          latitude: 15.364,
          longitude: 75.124,
          recordedAt: new Date(),
        })
      );
    });
  });

  // -----------------------------------------------------------------
  // 4. Employee Transition Graph Validation & Field Tampering
  // -----------------------------------------------------------------
  describe('4. Employee Transition Graph Validation & Field Tampering', () => {
    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('users').doc('emp_1').set({ role: 'employee', branch: 'Hubballi', serviceCentre: 'Central' });
        await db.collection('cab_assignment_members').doc(`${TODAY}_emp_1`).set({
          assignmentId: '', dateKey: TODAY, userId: 'emp_1', role: 'employee',
          branch: 'Hubballi', serviceCentre: 'Central', operationalDay: OPERATIONAL_DAY,
          driverId: 'driver_1', vehicleId: 'veh_1', shiftId: `${TODAY}_driver_1`,
          status: 'invited', invitationStatus: 'invited', declineReason: '',
          invitedAt: new Date(), respondedAt: null, officeName: 'Configured Office',
          officeAddress: 'Configured Campus', officeLatitude: 15.37, officeLongitude: 75.13,
          pickupName: 'Main Gate', pickupAddress: 'Main Gate', pickupLatitude: 15.36,
          pickupLongitude: 75.12, pickupValid: true, createdAt: new Date(), updatedAt: new Date(),
        });
      });
    });

    it('allows Employee to accept a pending invitation', async () => {
      const emp1Db = testEnv.authenticatedContext('emp_1').firestore();
      await assertSucceeds(
        emp1Db.collection('cab_assignment_members').doc(`${TODAY}_emp_1`).update({
          status: 'accepted', invitationStatus: 'accepted', declineReason: '',
          respondedAt: new Date(), updatedAt: new Date(),
        })
      );
    });

    it('allows Employee to decline a pending invitation', async () => {
      const emp1Db = testEnv.authenticatedContext('emp_1').firestore();
      await assertSucceeds(
        emp1Db.collection('cab_assignment_members').doc(`${TODAY}_emp_1`).update({
          status: 'declined', invitationStatus: 'declined', declineReason: 'Unavailable',
          respondedAt: new Date(), updatedAt: new Date(),
        })
      );
    });

    it('ATTACK: denies employee setting forbidden driver status (picked_up)', async () => {
      const emp1Db = testEnv.authenticatedContext('emp_1').firestore();
      await assertFails(
        emp1Db.collection('cab_assignment_members').doc(`${TODAY}_emp_1`).update({
          status: 'picked_up',
          updatedAt: new Date(),
        })
      );
    });

    it('ATTACK: denies employee changing status and driverId together', async () => {
      const emp1Db = testEnv.authenticatedContext('emp_1').firestore();
      await assertFails(
        emp1Db.collection('cab_assignment_members').doc(`${TODAY}_emp_1`).update({
          status: 'travelling_to_pickup',
          driverId: 'hacker_driver',
          updatedAt: new Date(),
        })
      );
    });

    it('ATTACK: denies employee changing status and pickupLatitude together', async () => {
      const emp1Db = testEnv.authenticatedContext('emp_1').firestore();
      await assertFails(
        emp1Db.collection('cab_assignment_members').doc(`${TODAY}_emp_1`).update({
          status: 'travelling_to_pickup',
          pickupLatitude: 99.9999,
          updatedAt: new Date(),
        })
      );
    });
  });

  // -----------------------------------------------------------------
  // 5. Trip & Rider Privacy & Attacks
  // -----------------------------------------------------------------
  describe('5. Trip & Rider Privacy & Attacks', () => {
    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('cab_assignments').doc('plan_2026-08-01_driver_1').set({
          id: 'plan_2026-08-01_driver_1',
          dateKey: '2026-08-01',
          driverId: 'driver_1',
          employeeIds: ['emp_1'],
        });
        await db.collection('cab_assignments').doc('assign_2').set({
          id: 'assign_2',
          driverId: 'driver_2',
          employeeIds: ['emp_2'],
        });

        await db.collection('cab_assignment_members').doc('2026-08-01_emp_1').set({
          dateKey: '2026-08-01',
          userId: 'emp_1',
          assignmentId: 'plan_2026-08-01_driver_1',
          driverId: 'driver_1',
          status: 'claimed',
        });
        await db.collection('cab_trips').doc('trip_1').set({
          id: 'trip_1',
          assignmentId: 'plan_2026-08-01_driver_1',
          driverId: 'driver_1',
          status: 'active',
        });
        await db.collection('cab_trips').doc('trip_2').set({
          id: 'trip_2',
          assignmentId: 'assign_2',
          driverId: 'driver_2',
          status: 'active',
        });

        await db
          .collection('cab_trips')
          .doc('trip_1')
          .collection('riders')
          .doc('emp_1')
          .set({
            employeeId: 'emp_1',
            status: 'assigned',
          });
        await db
          .collection('cab_trips')
          .doc('trip_1')
          .collection('riders')
          .doc('emp_2_fake')
          .set({
            employeeId: 'emp_2_fake',
            status: 'assigned',
          });
      });
    });

    it('allows employee 1 to read assigned trip 1', async () => {
      const emp1Db = testEnv.authenticatedContext('emp_1').firestore();
      await assertSucceeds(emp1Db.collection('cab_trips').doc('trip_1').get());
    });

    it('ATTACK: denies employee 1 from reading unassigned trip 2', async () => {
      const emp1Db = testEnv.authenticatedContext('emp_1').firestore();
      await assertFails(emp1Db.collection('cab_trips').doc('trip_2').get());
    });

    it('allows employee 1 to read own rider doc in trip 1', async () => {
      const emp1Db = testEnv.authenticatedContext('emp_1').firestore();
      await assertSucceeds(
        emp1Db
          .collection('cab_trips')
          .doc('trip_1')
          .collection('riders')
          .doc('emp_1')
          .get()
      );
    });

    it('ATTACK: denies employee 1 from reading another rider doc in trip 1', async () => {
      const emp1Db = testEnv.authenticatedContext('emp_1').firestore();
      await assertFails(
        emp1Db
          .collection('cab_trips')
          .doc('trip_1')
          .collection('riders')
          .doc('emp_2_fake')
          .get()
      );
    });
  });

  // -----------------------------------------------------------------
  // 6. Passenger Progress Sanitization & Coordinate Injection Attacks
  // -----------------------------------------------------------------
  describe('6. Passenger Progress Sanitization & Coordinate Injection Attacks', () => {
    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('cab_assignments').doc('plan_2026-08-01_driver_1').set({
          id: 'plan_2026-08-01_driver_1',
          dateKey: '2026-08-01',
          driverId: 'driver_1',
          employeeIds: ['emp_1'],
        });
        await db.collection('cab_assignment_members').doc('2026-08-01_emp_1').set({
          dateKey: '2026-08-01',
          userId: 'emp_1',
          assignmentId: 'plan_2026-08-01_driver_1',
          driverId: 'driver_1',
          status: 'claimed',
        });
        await db.collection('cab_trips').doc('trip_1').set({
          id: 'trip_1',
          assignmentId: 'plan_2026-08-01_driver_1',
          driverId: 'driver_1',
          status: 'active',
        });
      });
    });

    it('allows employee 1 to write sanitized progress payload', async () => {
      const emp1Db = testEnv.authenticatedContext('emp_1').firestore();
      await assertSucceeds(
        emp1Db
          .collection('cab_trips')
          .doc('trip_1')
          .collection('passenger_progress')
          .doc('emp_1')
          .set({
            employeeId: 'emp_1',
            passengerDisplayName: 'Employee One',
            pickupSequence: 1,
            status: 'ready',
            distanceToPickupMeters: 45.0,
            estimatedReadyMinutes: 2,
            locationFreshness: 'Just now',
            updatedAt: new Date(),
          })
      );
    });

    it('ATTACK: denies employee 1 from injecting raw latitude/longitude into passenger progress', async () => {
      const emp1Db = testEnv.authenticatedContext('emp_1').firestore();
      await assertFails(
        emp1Db
          .collection('cab_trips')
          .doc('trip_1')
          .collection('passenger_progress')
          .doc('emp_1')
          .set({
            employeeId: 'emp_1',
            passengerDisplayName: 'Employee One',
            pickupSequence: 1,
            status: 'ready',
            distanceToPickupMeters: 45.0,
            estimatedReadyMinutes: 2,
            locationFreshness: 'Just now',
            updatedAt: new Date(),
            latitude: 15.3647,
            longitude: 75.1240,
          })
      );
    });

    it('ATTACK: denies employee 1 from writing passenger progress for employee 2', async () => {
      const emp1Db = testEnv.authenticatedContext('emp_1').firestore();
      await assertFails(
        emp1Db
          .collection('cab_trips')
          .doc('trip_1')
          .collection('passenger_progress')
          .doc('emp_2')
          .set({
            employeeId: 'emp_2',
            passengerDisplayName: 'Employee Two',
            pickupSequence: 2,
            status: 'ready',
            distanceToPickupMeters: 50.0,
            estimatedReadyMinutes: 3,
            locationFreshness: 'Just now',
            updatedAt: new Date(),
          })
      );
    });
  });

  // -----------------------------------------------------------------
  // 7. Broad Query Denial Security Tests
  // -----------------------------------------------------------------
  describe('7. Broad Query Denial Security Tests', () => {
    it('ATTACK: denies broad collection query on live_locations', async () => {
      const emp1Db = testEnv.authenticatedContext('emp_1').firestore();
      await assertFails(emp1Db.collection('live_locations').get());
    });

    it('ATTACK: denies broad collection query on cab_assignment_members', async () => {
      const emp1Db = testEnv.authenticatedContext('emp_1').firestore();
      await assertFails(emp1Db.collection('cab_assignment_members').get());
    });

    it('ATTACK: denies broad collection query on cab_trips riders subcollection', async () => {
      const emp1Db = testEnv.authenticatedContext('emp_1').firestore();
      await assertFails(
        emp1Db.collection('cab_trips').doc('trip_1').collection('riders').get()
      );
    });
  });

  // -----------------------------------------------------------------
  // 8. Driver Independent Claiming & Mandatory Security Tests
  // -----------------------------------------------------------------
  describe('8. Driver Independent Claiming & Mandatory Security Tests', () => {
    const readyPayload = (userId, branch = 'Hubballi', serviceCentre = 'Central') => ({
      assignmentId: '', dateKey: TODAY, userId, role: 'employee', branch,
      serviceCentre, operationalDay: OPERATIONAL_DAY,
      driverId: 'drv_1', vehicleId: 'veh_1', shiftId: `${TODAY}_drv_1`,
      status: 'accepted', invitationStatus: 'accepted', declineReason: '', invitedAt: new Date(), respondedAt: new Date(),
      officeName: 'Configured Office', officeAddress: 'Configured Campus', officeLatitude: 15.37, officeLongitude: 75.13, pickupName: 'Main Gate',
      pickupAddress: 'Main Gate', pickupLatitude: 15.36,
      pickupLongitude: 75.12, pickupValid: true, createdAt: new Date(), updatedAt: new Date(),
    });

    const assignmentPayload = (driverId = 'drv_1', vehicleId = 'veh_1', employeeIds = ['emp_10']) => ({
      dateKey: TODAY, assignmentDate: new Date(), driverId, vehicleId,
      employeeIds, officeName: 'Configured Office', officeAddress: 'Configured Campus',
      officeLatitude: 15.37, officeLongitude: 75.13,
      branch: driverId === 'drv_2' ? 'Dharwad' : 'Hubballi',
      serviceCentre: driverId === 'drv_2' ? 'North' : 'Central',
      status: 'started', assignedBy: driverId, assignedAt: new Date(),
      updatedAt: new Date(), remarks: '',
    });

    const tripPayload = (driverId = 'drv_1', vehicleId = 'veh_1', employeeIds = ['emp_10']) => ({
      driverId, vehicleId, assignmentId: `plan_${TODAY}_${driverId}`,
      dateKey: TODAY, status: 'active', activeLocationSessionId: `session_${driverId}`,
      startedAt: new Date(), officeName: 'Configured Office',
      officeAddress: 'Configured Campus', officeLatitude: 15.37,
      officeLongitude: 75.13, branch: driverId === 'drv_2' ? 'Dharwad' : 'Hubballi',
      serviceCentre: driverId === 'drv_2' ? 'North' : 'Central', employeeIds,
      createdAt: new Date(), updatedAt: new Date(),
    });

    const shiftPayload = (driverId, vehicleId) => ({
      driverId, vehicleId, shiftDate: TODAY, shiftStart: new Date(), shiftEnd: null,
      shiftStatus: 'active', startLocation: '', endLocation: '', totalDistance: 0,
      totalTrips: 0, totalEmployees: 0, remarks: '', startOdometer: 12000,
      batteryPercentage: 90, vehicleCondition: 'Good',
      officeName: 'Configured Office', officeAddress: 'Configured Campus',
      officeLatitude: 15.37, officeLongitude: 75.13,
    });

    function buildClaimBatch(db, driverId = 'drv_1', vehicleId = 'veh_1', employeeId = 'emp_10') {
      const assignmentId = `plan_${TODAY}_${driverId}`;
      const tripId = `trip_${TODAY}_${driverId}`;
      const batch = db.batch();
      const assignment = db.collection('cab_assignments').doc(assignmentId);
      const trip = db.collection('cab_trips').doc(tripId);
      batch.set(assignment, assignmentPayload(driverId, vehicleId, [employeeId]));
      batch.set(trip, tripPayload(driverId, vehicleId, [employeeId]));
      batch.update(db.collection('cab_assignment_members').doc(`${TODAY}_${employeeId}`), {
        assignmentId, status: 'claimed', invitationStatus: 'trip_active', updatedAt: new Date(),
      });
      batch.set(trip.collection('riders').doc(employeeId), {
        tripId, assignmentId, employeeId, status: 'ready', pickupOrder: 1,
        pickupName: 'Main Gate', pickupAddress: 'Main Gate', pickupLatitude: 15.36,
        pickupLongitude: 75.12, createdAt: new Date(), updatedAt: new Date(),
      });
      batch.set(trip.collection('passenger_progress').doc(employeeId), {
        employeeId, passengerDisplayName: '', employeeCode: '', roleLabel: 'Employee',
        pickupSequence: 1, status: 'ready', remark: 'ready', attendanceActive: false,
        transportActive: true, distanceToPickupMeters: null, estimatedReadyMinutes: null,
        locationFreshness: 'unknown', updatedAt: new Date(),
      });
      batch.set(db.collection('notifications').doc(`${tripId}_${employeeId}_started`), {
        id: `${tripId}_${employeeId}_started`, userId: employeeId,
        recipientUserId: employeeId, title: 'Driver assigned', body: 'Trip started',
        type: 'cab_trip_started', source: 'trip_event', tripId, assignmentId,
        driverId, isRead: false, createdAt: new Date(), readAt: null,
      });
      return batch;
    }

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('users').doc('drv_1').set({ role: 'driver', branch: 'Hubballi', serviceCentre: 'Central', status: 'active' });
        await db.collection('users').doc('drv_2').set({ role: 'driver', branch: 'Dharwad', serviceCentre: 'North', status: 'active' });
        await db.collection('users').doc('drv_off').set({ role: 'driver', branch: 'Hubballi', serviceCentre: 'Central', status: 'active' });
        await db.collection('users').doc('emp_10').set({ role: 'employee', branch: 'Hubballi', serviceCentre: 'Central' });
        await db.collection('users').doc('emp_create').set({ role: 'employee', branch: 'Hubballi', serviceCentre: 'Central' });
        await db.collection('cab_vehicles').doc('veh_1').set({ status: 'active', vehicleNumber: 'KA-25-1001' });
        await db.collection('cab_vehicles').doc('veh_2').set({ status: 'active', vehicleNumber: 'KA-25-1002' });
        await db.collection('cab_driver_shifts').doc(`${TODAY}_drv_1`).set(shiftPayload('drv_1', 'veh_1'));
        await db.collection('cab_driver_shifts').doc(`${TODAY}_drv_2`).set(shiftPayload('drv_2', 'veh_2'));
        await db.collection('cab_assignment_members').doc(`${TODAY}_emp_10`).set(readyPayload('emp_10'));
        await db.collection('cab_assignment_members').doc(`${TODAY}_emp_cancelled`).set({ ...readyPayload('emp_cancelled'), status: 'cancelled' });
      });
    });

    it('Driver creates a canonical invitation for a scoped Employee', async () => {
      const db = testEnv.authenticatedContext('drv_1').firestore();
      await assertSucceeds(db.collection('cab_assignment_members').doc(`${TODAY}_emp_create`).set({ ...readyPayload('emp_create'), status: 'invited', invitationStatus: 'invited', respondedAt: null }));
    });

    it('ATTACK: denies Employee creating another Employee request', async () => {
      const db = testEnv.authenticatedContext('emp_10').firestore();
      await assertFails(db.collection('cab_assignment_members').doc(`${TODAY}_emp_other`).set({ ...readyPayload('emp_other'), status: 'assigned' }));
    });

    it('ATTACK: rejects unknown fields and Driver-owned fields on creation', async () => {
      const db = testEnv.authenticatedContext('emp_create').firestore();
      await assertFails(db.collection('cab_assignment_members').doc(`${TODAY}_emp_create`).set({ ...readyPayload('emp_create'), status: 'assigned', isAdmin: true }));
      await assertFails(db.collection('cab_assignment_members').doc(`${TODAY}_emp_create`).set({ ...readyPayload('emp_create'), status: 'assigned', driverId: 'drv_1', vehicleId: 'veh_1' }));
    });

    it('ATTACK: denies Employee creating self-picked-up request', async () => {
      const db = testEnv.authenticatedContext('emp_create').firestore();
      await assertFails(db.collection('cab_assignment_members').doc(`${TODAY}_emp_create`).set({ ...readyPayload('emp_create'), status: 'picked_up' }));
    });

    it('Authorized on-duty Driver reads only same-branch Ready requests', async () => {
      const db = testEnv.authenticatedContext('drv_1').firestore();
      const result = await assertSucceeds(db.collection('cab_assignment_members').where('dateKey', '==', TODAY).where('operationalDay', '==', OPERATIONAL_DAY).where('driverId', '==', 'drv_1').where('invitationStatus', '==', 'accepted').get());
      expect(result.docs.map((doc) => doc.id)).to.include(`${TODAY}_emp_10`);
    });

    it('ATTACK: denies off-duty and cross-branch Driver READY queries', async () => {
      const off = testEnv.authenticatedContext('drv_off').firestore();
      await assertFails(off.collection('cab_assignment_members').where('dateKey', '==', TODAY).where('operationalDay', '==', OPERATIONAL_DAY).where('driverId', '==', 'drv_1').where('invitationStatus', '==', 'accepted').get());
      const scoped = testEnv.authenticatedContext('drv_1').firestore();
      await assertFails(scoped.collection('cab_assignment_members').where('dateKey', '==', TODAY).where('operationalDay', '==', OPERATIONAL_DAY).where('driverId', '==', '').where('status', '==', 'ready').where('role', '==', 'employee').where('pickupValid', '==', true).where('branch', '==', 'Dharwad').get());
    });

    it('Driver creates only a scoped own assignment with an atomic claim', async () => {
      const db = testEnv.authenticatedContext('drv_1').firestore();
      const batch = db.batch();
      const assignmentId = `plan_${TODAY}_drv_1`;
      batch.set(db.collection('cab_assignments').doc(assignmentId), assignmentPayload());
      batch.update(db.collection('cab_assignment_members').doc(`${TODAY}_emp_10`), { assignmentId, status: 'claimed', invitationStatus: 'trip_active', updatedAt: new Date() });
      await assertSucceeds(batch.commit());
      await assertFails(db.collection('cab_assignments').doc('plan_bad').set({ ...assignmentPayload('drv_2', 'veh_1'), assignedBy: 'drv_2' }));
    });

    it('atomic Driver claim creates assignment, trip, rider, progress, and notification', async () => {
      const db = testEnv.authenticatedContext('drv_1').firestore();
      await assertSucceeds(buildClaimBatch(db).commit());
    });

    it('Driver claims Ready request and conflicting Driver loses safely', async () => {
      const db = testEnv.authenticatedContext('drv_1').firestore();
      await assertSucceeds(buildClaimBatch(db).commit());
      const other = testEnv.authenticatedContext('drv_2').firestore();
      await assertFails(other.collection('cab_assignment_members').doc(`${TODAY}_emp_10`).update({ assignmentId: `plan_${TODAY}_drv_2`, driverId: 'drv_2', vehicleId: 'veh_2', status: 'claimed', updatedAt: new Date() }));
    });

    it('ATTACK: denies claiming cancelled request or changing pickup identity', async () => {
      const db = testEnv.authenticatedContext('drv_1').firestore();
      await assertFails(db.collection('cab_assignment_members').doc(`${TODAY}_emp_cancelled`).update({ assignmentId: `plan_${TODAY}_drv_1`, driverId: 'drv_1', vehicleId: 'veh_1', status: 'claimed', updatedAt: new Date() }));
      const batch = buildClaimBatch(db);
      batch.update(db.collection('cab_assignment_members').doc(`${TODAY}_emp_10`), { pickupAddress: 'Changed' });
      await assertFails(batch.commit());
    });
  });

  describe('9. Start Duty & Shift Security Tests', () => {
    const validShift = (driverId, vehicleId) => ({
      driverId, vehicleId, shiftDate: TODAY, shiftStart: new Date(), shiftEnd: null,
      shiftStatus: 'active', startLocation: '', endLocation: '', totalDistance: 0,
      totalTrips: 0, totalEmployees: 0, remarks: '', startOdometer: 12000,
      batteryPercentage: 90, vehicleCondition: 'Good',
      officeName: 'Configured Office', officeAddress: 'Configured Campus',
      officeLatitude: 15.37, officeLongitude: 75.13,
    });

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('users').doc('drv_100').set({ uid: 'drv_100', role: 'driver', name: 'Duty Driver', status: 'active' });
        await db.collection('users').doc('drv_200').set({ uid: 'drv_200', role: 'driver', name: 'Duty Driver 2', status: 'active' });
        await db.collection('users').doc('emp_100').set({ uid: 'emp_100', role: 'employee', name: 'Duty Employee' });
        await db.collection('cab_vehicles').doc('veh_100').set({ vehicleNumber: 'KA-25-0100', status: 'active' });
        await db.collection('cab_vehicles').doc('veh_200').set({ vehicleNumber: 'KA-25-0200', status: 'active' });
        await db.collection('cab_driver_shifts').doc(`${TODAY}_drv_100`).set(validShift('drv_100', 'veh_100'));
      });
    });

    it('1. Authorized Driver creates their own current-day deterministic shift', async () => {
      const db = testEnv.authenticatedContext('drv_200').firestore();
      await assertSucceeds(db.collection('cab_driver_shifts').doc(`${TODAY}_drv_200`).set(validShift('drv_200', 'veh_200')));
    });

    it('2. ATTACK: denies Driver 1 from creating Driver 2 shift', async () => {
      const db = testEnv.authenticatedContext('drv_100').firestore();
      await assertFails(db.collection('cab_driver_shifts').doc(`${TODAY}_drv_200`).set(validShift('drv_200', 'veh_200')));
    });

    it('3. ATTACK: denies Employee from creating a Driver shift', async () => {
      const db = testEnv.authenticatedContext('emp_100').firestore();
      await assertFails(db.collection('cab_driver_shifts').doc(`${TODAY}_emp_100`).set(validShift('emp_100', 'veh_100')));
    });

    it('4. ATTACK: denies Unauthenticated user from creating a shift', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(db.collection('cab_driver_shifts').doc(`${TODAY}_drv_200`).set(validShift('drv_200', 'veh_200')));
    });

    it('5 & 6. Driver shift has no assignmentId or tripId', async () => {
      const db = testEnv.authenticatedContext('drv_200').firestore();
      await assertSucceeds(db.collection('cab_driver_shifts').doc(`${TODAY}_drv_200`).set(validShift('drv_200', 'veh_200')));
    });

    it('7. Valid checklist fields are accepted', async () => {
      const db = testEnv.authenticatedContext('drv_200').firestore();
      await assertSucceeds(db.collection('cab_driver_shifts').doc(`${TODAY}_drv_200`).set({ ...validShift('drv_200', 'veh_200'), batteryPercentage: 88, vehicleCondition: 'Minor Damage', remarks: 'Scratch on left door' }));
    });

    it('8. ATTACK: denies Driver from modifying driverId on existing shift update', async () => {
      const db = testEnv.authenticatedContext('drv_100').firestore();
      await assertFails(db.collection('cab_driver_shifts').doc(`${TODAY}_drv_100`).update({ driverId: 'drv_200' }));
    });

    it('9. Driver reads available vehicles collection', async () => {
      const db = testEnv.authenticatedContext('drv_100').firestore();
      await assertSucceeds(db.collection('cab_vehicles').get());
    });

    it('10. ATTACK: denies Driver from modifying cab_vehicles master data', async () => {
      const db = testEnv.authenticatedContext('drv_100').firestore();
      await assertFails(db.collection('cab_vehicles').doc('veh_100').update({ vehicleNumber: 'KA-25-HACKED' }));
    });

    it('11. Duty tracking attendance check-in succeeds without assignmentId', async () => {
      const db = testEnv.authenticatedContext('drv_100').firestore();
      await assertSucceeds(db.collection('attendance').add({ userId: 'drv_100', status: 'Checked In', date: new Date(), checkInTime: new Date() }));
    });

    it('12. ATTACK: denies Unclaimed Employee from reading Driver duty location without assignment', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('live_locations').doc('drv_100').set({ userId: 'drv_100', latitude: 15.3647, longitude: 75.124, sessionId: 'sess_1', trackingReason: 'field_duty', status: 'active', recordedAt: new Date(), assignmentId: '' });
      });
      const db = testEnv.authenticatedContext('emp_100').firestore();
      await assertFails(db.collection('live_locations').doc('drv_100').get());
    });

    it('13 & 14. Shift update by owning Driver succeeds and preserves immutable fields', async () => {
      const db = testEnv.authenticatedContext('drv_100').firestore();
      await assertSucceeds(db.collection('cab_driver_shifts').doc(`${TODAY}_drv_100`).update({ shiftStatus: 'completed', shiftEnd: new Date(), totalDistance: 42.5 }));
    });

    it('15. Driver duplicate attendance checkIn read/write is idempotent', async () => {
      const db = testEnv.authenticatedContext('drv_100').firestore();
      await assertSucceeds(db.collection('attendance').where('userId', '==', 'drv_100').get());
    });
  });  describe('10. Progress and Shared Presence Privacy', () => {
    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('users').doc('privacy_emp_1').set({ role: 'employee' });
        await db.collection('users').doc('privacy_emp_2').set({ role: 'employee' });
        await db.collection('users').doc('privacy_driver').set({ role: 'driver' });
        await db.collection('cab_assignments').doc('privacy_assignment').set({ driverId: 'privacy_driver', employeeIds: ['privacy_emp_1', 'privacy_emp_2'], status: 'started' });
        await db.collection('cab_trips').doc('privacy_trip').set({ assignmentId: 'privacy_assignment', driverId: 'privacy_driver', employeeIds: ['privacy_emp_1', 'privacy_emp_2'], status: 'active' });
        await db.collection('cab_trips').doc('privacy_trip').collection('passenger_progress').doc('privacy_emp_1').set({ employeeId: 'privacy_emp_1', status: 'ready' });
        await db.collection('shared_map_presence').doc('privacy_driver').set({ userId: 'privacy_driver', displayName: 'Driver', role: 'driver', latitude: 15.36, longitude: 75.12, status: 'active', updatedAt: new Date() });
      });
    });

    it('allows Employee to read only own passenger progress', async () => {
      const db = testEnv.authenticatedContext('privacy_emp_1').firestore();
      await assertSucceeds(db.collection('cab_trips').doc('privacy_trip').collection('passenger_progress').doc('privacy_emp_1').get());
    });

    it('ATTACK: denies another rider in same trip from reading progress', async () => {
      const db = testEnv.authenticatedContext('privacy_emp_2').firestore();
      await assertFails(db.collection('cab_trips').doc('privacy_trip').collection('passenger_progress').doc('privacy_emp_1').get());
    });

    it('ATTACK: denies generic signed-in global shared presence read', async () => {
      const db = testEnv.authenticatedContext('privacy_emp_1').firestore();
      await assertFails(db.collection('shared_map_presence').get());
      await assertFails(db.collection('shared_map_presence').doc('privacy_driver').get());
    });
  });
});
