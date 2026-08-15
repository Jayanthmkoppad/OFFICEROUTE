const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');
const { expect } = require('chai');
const PROJECT_ID = 'officeroute-security-certification';
const TODAY = new Date().toISOString().slice(0, 10);
const DAY = new Date(`${TODAY}T00:00:00.000Z`);
const PAST = new Date(DAY.getTime() - 86400000);
const FUTURE = new Date(DAY.getTime() + 86400000);
const PAST_KEY = PAST.toISOString().slice(0, 10);
const FUTURE_KEY = FUTURE.toISOString().slice(0, 10);
let env;

const shift = (driverId, vehicleId, status = 'active') => ({
  driverId, vehicleId, shiftDate: TODAY, shiftStart: new Date(), shiftEnd: status === 'completed' ? new Date() : null,
  shiftStatus: status, startLocation: '', endLocation: '', totalDistance: 0, totalTrips: 0,
  totalEmployees: 0, remarks: '', startOdometer: 1000, batteryPercentage: 90, vehicleCondition: 'Good',
  officeName: 'Configured Office', officeAddress: 'Configured Campus',
  officeLatitude: 15.37, officeLongitude: 75.13,
});
const invitation = (userId, x = {}) => ({
  assignmentId: '', dateKey: TODAY, userId, role: 'employee', branch: 'Hubballi', serviceCentre: 'Central',
  operationalDay: DAY, driverId: 'driver_1', vehicleId: 'veh_1', shiftId: `${TODAY}_driver_1`,
  status: 'invited', invitationStatus: 'invited', declineReason: '', invitedAt: new Date(), respondedAt: null,
  officeName: 'Configured Office', officeAddress: 'Configured Campus', officeLatitude: 15.37,
  officeLongitude: 75.13, pickupName: 'Main Gate',
  pickupAddress: 'Employee Main Gate', pickupLatitude: 15.36, pickupLongitude: 75.12, pickupValid: true,
  createdAt: new Date(), updatedAt: new Date(), ...x,
});
const assignment = (driverId, vehicleId, employeeIds, x = {}) => ({
  dateKey: TODAY, assignmentDate: new Date(), driverId, vehicleId, employeeIds,
  officeName: 'Configured Office', officeAddress: 'Configured Campus', officeLatitude: 15.37,
  officeLongitude: 75.13, branch: 'Hubballi', serviceCentre: 'Central', status: 'started',
  assignedBy: driverId, assignedAt: new Date(), updatedAt: new Date(), remarks: '', ...x,
});
const trip = (driverId, vehicleId, assignmentId, employeeIds, x = {}) => ({
  driverId, vehicleId, assignmentId, dateKey: TODAY, status: 'active',
  activeLocationSessionId: `session_${driverId}`, startedAt: new Date(), officeName: 'Configured Office',
  officeAddress: 'Configured Campus', officeLatitude: 15.37, officeLongitude: 75.13,
  branch: 'Hubballi', serviceCentre: 'Central', employeeIds, createdAt: new Date(), updatedAt: new Date(), ...x,
});
const rider = (tripId, assignmentId, employeeId, status = 'ready') => ({
  tripId, assignmentId, employeeId, status, pickupOrder: 1, pickupName: 'Main Gate',
  pickupAddress: 'Employee Main Gate', pickupLatitude: 15.36, pickupLongitude: 75.12,
  createdAt: new Date(), updatedAt: new Date(),
});
const progress = (employeeId, status = 'ready') => ({
  employeeId, passengerDisplayName: 'Employee', employeeCode: 'E-1', roleLabel: 'Employee',
  pickupSequence: 1, status, remark: status, attendanceActive: false, transportActive: true,
  distanceToPickupMeters: null, estimatedReadyMinutes: null, locationFreshness: 'unknown', updatedAt: new Date(),
});
const notice = (employeeId, type, x = {}) => ({
  id: `${type}_${employeeId}`, userId: employeeId, recipientUserId: employeeId,
  title: 'Transport update', body: 'Transport status changed', type, source: 'trip_event',
  tripId: `trip_${TODAY}_driver_cancel`, assignmentId: `plan_${TODAY}_driver_cancel`,
  driverId: 'driver_cancel', isRead: false, createdAt: new Date(), readAt: null, ...x,
});

async function seed() {
  await env.withSecurityRulesDisabled(async c => {
    const db = c.firestore(); const b = db.batch();
    const users = {
      emp_new:['employee','Hubballi','Central','active'], emp_other:['employee','Hubballi','Central','active'],
      emp_ready:['employee','Hubballi','Central','active'], emp_cancel:['employee','Hubballi','Central','active'],
      emp_rider2:['employee','Hubballi','Central','active'], driver_1:['driver','Hubballi','Central','active'],
      driver_2:['driver','Dharwad','North','active'], driver_off:['driver','Hubballi','Central','active'],
      driver_cancel:['driver','Hubballi','Central','active'], driver_new:['driver','Hubballi','Central','active'],
      admin_1:['admin','','','active'], manager_1:['manager','','','active'],
      inactive_admin:['admin','','','inactive'], unrelated_1:['sales','','','active'],
    };
    for (const [id,v] of Object.entries(users)) b.set(db.collection('users').doc(id), {role:v[0],branch:v[1],serviceCentre:v[2],status:v[3]});
    for (const [id,n] of [['veh_1','1001'],['veh_2','1002'],['veh_cancel','1003'],['veh_new','1004']]) b.set(db.collection('cab_vehicles').doc(id), {status:'active',vehicleNumber:n});
    b.set(db.collection('cab_driver_shifts').doc(`${TODAY}_driver_1`), shift('driver_1','veh_1'));
    b.set(db.collection('cab_driver_shifts').doc(`${TODAY}_driver_2`), shift('driver_2','veh_2'));
    b.set(db.collection('cab_driver_shifts').doc(`${TODAY}_driver_cancel`), shift('driver_cancel','veh_cancel'));
    b.set(db.collection('cab_assignment_members').doc(`${TODAY}_emp_new`), invitation('emp_new'));
    b.set(db.collection('cab_assignment_members').doc(`${TODAY}_emp_ready`), invitation('emp_ready',{status:'accepted',invitationStatus:'accepted',respondedAt:new Date()}));
    b.set(db.collection('cab_assignment_members').doc(`${TODAY}_emp_other`), invitation('emp_other',{status:'accepted',invitationStatus:'accepted',respondedAt:new Date()}));
    const aid=`plan_${TODAY}_driver_cancel`, tid=`trip_${TODAY}_driver_cancel`;
    b.set(db.collection('cab_assignments').doc(aid), assignment('driver_cancel','veh_cancel',['emp_cancel','emp_rider2']));
    b.set(db.collection('cab_trips').doc(tid), trip('driver_cancel','veh_cancel',aid,['emp_cancel','emp_rider2']));
    b.set(db.collection('cab_assignment_members').doc(`${TODAY}_emp_cancel`),invitation('emp_cancel',{assignmentId:aid,driverId:'driver_cancel',vehicleId:'veh_cancel',shiftId:`${TODAY}_driver_cancel`,status:'claimed',invitationStatus:'trip_active',respondedAt:new Date()}));
    b.set(db.collection('cab_assignment_members').doc(`${TODAY}_emp_rider2`),invitation('emp_rider2',{assignmentId:aid,driverId:'driver_cancel',vehicleId:'veh_cancel',shiftId:`${TODAY}_driver_cancel`,status:'picked_up',invitationStatus:'trip_active',respondedAt:new Date()}));
    b.set(db.collection('cab_trips').doc(tid).collection('riders').doc('emp_cancel'),rider(tid,aid,'emp_cancel'));
    b.set(db.collection('cab_trips').doc(tid).collection('riders').doc('emp_rider2'),rider(tid,aid,'emp_rider2','picked_up'));
    b.set(db.collection('cab_trips').doc(tid).collection('passenger_progress').doc('emp_cancel'),progress('emp_cancel'));
    b.set(db.collection('cab_trips').doc(tid).collection('passenger_progress').doc('emp_rider2'),progress('emp_rider2','picked_up'));
    b.set(db.collection('live_locations').doc('driver_cancel'),{userId:'driver_cancel',sessionId:'session_driver_cancel',assignmentId:aid,trackingReason:'driver_active_trip',status:'active',latitude:15.36,longitude:75.12,recordedAt:new Date()});
    b.set(db.collection('live_locations').doc('emp_cancel'),{userId:'emp_cancel',sessionId:'session_emp_cancel',assignmentId:aid,trackingReason:'cab_pickup_ready',status:'active',latitude:15.35,longitude:75.11,recordedAt:new Date()});
    b.set(db.collection('shared_map_presence').doc('driver_cancel'),{userId:'driver_cancel',displayName:'Driver',role:'driver',latitude:15.36,longitude:75.12,status:'active',updatedAt:new Date()});
    b.set(db.collection('location_sessions').doc('session_driver_cancel'),{id:'session_driver_cancel',userId:'driver_cancel',trackingReason:'driver_active_trip',status:'active',startedAt:new Date(),pausedAt:null,resumedAt:null,stoppedAt:null,lastLatitude:15.36,lastLongitude:75.12,lastUpdatedAt:new Date(),stopReason:'',metadata:{assignmentId:aid}});
    await b.commit();
  });
}
function claimBatch(db,{driverId='driver_1',vehicleId='veh_1',employeeId='emp_ready',member={},assign={},assignmentId}={}){
  const aid=assignmentId||`plan_${TODAY}_${driverId}`; const b=db.batch();
  b.set(db.collection('cab_assignments').doc(aid),assignment(driverId,vehicleId,[employeeId],assign));
  b.update(db.collection('cab_assignment_members').doc(`${TODAY}_${employeeId}`),{assignmentId:aid,status:'claimed',invitationStatus:'trip_active',updatedAt:new Date(),...member}); return b;
}
async function seedTripLink(){await env.withSecurityRulesDisabled(async c=>{const db=c.firestore(),aid=`plan_${TODAY}_driver_1`;await db.collection('cab_assignments').doc(aid).set(assignment('driver_1','veh_1',['emp_ready']));await db.collection('cab_assignment_members').doc(`${TODAY}_emp_ready`).set(invitation('emp_ready',{assignmentId:aid,status:'claimed',invitationStatus:'trip_active',respondedAt:new Date()}));});}
function cancelBatch(db,{actor='driver_cancel',reason='Safety issue',explanation=''}={}){const aid=`plan_${TODAY}_driver_cancel`,tid=`trip_${TODAY}_driver_cancel`,b=db.batch();b.update(db.collection('cab_trips').doc(tid),{status:'cancelled',cancellationReason:reason,cancellationExplanation:explanation,cancelledBy:actor,cancelledAt:new Date(),updatedAt:new Date()});b.update(db.collection('cab_assignments').doc(aid),{status:'cancelled',cancellationReason:reason,cancellationExplanation:explanation,cancelledBy:actor,cancelledAt:new Date(),updatedAt:new Date()});b.update(db.collection('cab_assignment_members').doc(`${TODAY}_emp_cancel`),{status:'cancelled',invitationStatus:'trip_active',updatedAt:new Date()});b.update(db.collection('cab_trips').doc(tid).collection('riders').doc('emp_cancel'),{status:'cancelled',tripCancellationReason:reason,tripCancelledAt:new Date(),updatedAt:new Date()});b.update(db.collection('cab_trips').doc(tid).collection('passenger_progress').doc('emp_cancel'),{status:'cancelled',remark:'trip_cancelled',transportActive:false,updatedAt:new Date()});for(const e of ['emp_cancel','emp_rider2'])b.set(db.collection('notifications').doc(`${tid}_${e}_cancelled`),notice(e,'cab_trip_cancelled',{cancellationReason:reason}));b.set(db.collection('cab_trips').doc(tid).collection('events').doc('cancelled'),{tripId:tid,assignmentId:aid,actorUserId:actor,eventType:'trip_cancelled',message:reason,createdAt:new Date(),metadata:{reason}});return b;}

describe('OfficeRoute Firestore Complete Security Certification Matrix',function(){
  this.timeout(30000);
  before(async()=>{env=await initializeTestEnvironment({projectId:PROJECT_ID,firestore:{rules:fs.readFileSync(path.join(__dirname,'../../firestore.rules'),'utf8'),host:'127.0.0.1',port:8085}});});
  after(async()=>{if(env)await env.cleanup();}); beforeEach(async()=>{await env.clearFirestore();await seed();});  describe('Employee request boundaries',()=>{
    it('allows Employee to read their own pending invitation',async()=>{const db=env.authenticatedContext('emp_new').firestore();await assertSucceeds(db.collection('cab_assignment_members').doc(`${TODAY}_emp_new`).get());});
    it('ATTACK: denies another Employee creation',async()=>{const db=env.authenticatedContext('emp_new').firestore();await assertFails(db.collection('cab_assignment_members').doc(`${TODAY}_emp_other`).set(invitation('emp_other')));});
    it('ATTACK: denies another Employee read',async()=>assertFails(env.authenticatedContext('emp_new').firestore().collection('cab_assignment_members').doc(`${TODAY}_emp_other`).get()));
    for(const [label,key,day] of [['past',PAST_KEY,PAST],['future',FUTURE_KEY,FUTURE]])it(`ATTACK: denies ${label} operational date`,async()=>{const db=env.authenticatedContext('emp_new').firestore();await assertFails(db.collection('cab_assignment_members').doc(`${key}_emp_new`).set(invitation('emp_new',{dateKey:key,operationalDay:day})));});
    for(const [label,x] of [
      ['unknown field',{escalated:true}],['driverId',{driverId:'driver_1'}],['vehicleId',{vehicleId:'veh_1'}],
      ['assignmentId',{assignmentId:'plan_x'}],['tripId',{tripId:'trip_x'}],['invalid pickup latitude',{pickupLatitude:91}],
      ['invalid pickup longitude',{pickupLongitude:181}],['missing pickup',{pickupAddress:''}],
      ['unauthorized branch',{branch:'Dharwad',serviceCentre:'North'}],['invalid initial status',{status:'accepted',invitationStatus:'accepted',respondedAt:new Date()}],
    ])it(`ATTACK: denies Employee create with ${label}`,async()=>{const db=env.authenticatedContext('emp_new').firestore();await assertFails(db.collection('cab_assignment_members').doc(`${TODAY}_emp_new`).set(invitation('emp_new',x)));});
    it('allows Employee to accept a pending invitation',async()=>{const db=env.authenticatedContext('emp_new').firestore();await assertSucceeds(db.collection('cab_assignment_members').doc(`${TODAY}_emp_new`).update({status:'accepted',invitationStatus:'accepted',declineReason:'',respondedAt:new Date(),updatedAt:new Date()}));});
    it('allows Employee to decline a pending invitation',async()=>{const db=env.authenticatedContext('emp_new').firestore();await assertSucceeds(db.collection('cab_assignment_members').doc(`${TODAY}_emp_new`).update({status:'declined',invitationStatus:'declined',declineReason:'Unavailable',respondedAt:new Date(),updatedAt:new Date()}));});
    for(const [label,e,x] of [
      ['cancellation after claim','emp_cancel',{status:'cancelled',updatedAt:new Date()}],
      ['picked_up transition','emp_ready',{status:'picked_up',updatedAt:new Date()}],
      ['completed transition','emp_ready',{status:'completed',updatedAt:new Date()}],
      ['pickup mutation after claim','emp_cancel',{pickupAddress:'Changed',updatedAt:new Date()}],
      ['identity mutation','emp_ready',{userId:'emp_other',updatedAt:new Date()}],
      ['branch mutation','emp_ready',{branch:'Dharwad',updatedAt:new Date()}],
      ['unknown update field','emp_ready',{admin:true,updatedAt:new Date()}],
    ])it(`ATTACK: denies Employee ${label}`,async()=>assertFails(env.authenticatedContext(e).firestore().collection('cab_assignment_members').doc(`${TODAY}_${e}`).update(x)));
  });

  describe('Driver open-request boundaries',()=>{
    const query=(db,x={})=>db.collection('cab_assignment_members').where('driverId','==',x.driverId||'driver_1').where('invitationStatus','==',x.invitationStatus||'accepted').get();
    it('allows active Driver eligible query',async()=>{const result=await assertSucceeds(query(env.authenticatedContext('driver_1').firestore()));expect(result.docs.map(d=>d.id)).to.include(`${TODAY}_emp_ready`);});
    it('ATTACK: denies off-duty Driver query',async()=>assertFails(query(env.authenticatedContext('driver_off').firestore())));
    it('ATTACK: denies wrong-day invitation read',async()=>{await env.withSecurityRulesDisabled(c=>c.firestore().collection('cab_assignment_members').doc(`${PAST_KEY}_past`).set(invitation('past',{dateKey:PAST_KEY,operationalDay:PAST,driverId:'driver_2',shiftId:`${TODAY}_driver_2`})));await assertFails(env.authenticatedContext('driver_1').firestore().collection('cab_assignment_members').doc(`${PAST_KEY}_past`).get());});
    it('ATTACK: denies wrong-branch invitation read',async()=>{await env.withSecurityRulesDisabled(c=>c.firestore().collection('cab_assignment_members').doc(`${TODAY}_wrong_branch`).set(invitation('wrong_branch',{driverId:'driver_2',vehicleId:'veh_2',shiftId:`${TODAY}_driver_2`,branch:'Dharwad',serviceCentre:'North'})));await assertFails(env.authenticatedContext('driver_1').firestore().collection('cab_assignment_members').doc(`${TODAY}_wrong_branch`).get());});
    it('ATTACK: denies unrelated Driver reading invalid pickup invitation',async()=>{await env.withSecurityRulesDisabled(c=>c.firestore().collection('cab_assignment_members').doc(`${TODAY}_bad`).set(invitation('bad',{pickupLatitude:999})));await assertFails(env.authenticatedContext('driver_2').firestore().collection('cab_assignment_members').doc(`${TODAY}_bad`).get());});
    for(const status of ['claimed','cancelled','completed'])it(`ATTACK: denies unowned ${status} request`,async()=>{await env.withSecurityRulesDisabled(c=>c.firestore().collection('cab_assignment_members').doc(`${TODAY}_${status}`).set(invitation(status,{status,driverId:'driver_2',vehicleId:'veh_2',shiftId:`${TODAY}_driver_2`})));await assertFails(env.authenticatedContext('driver_1').firestore().collection('cab_assignment_members').doc(`${TODAY}_${status}`).get());});
    it('ATTACK: denies broad unconstrained request list',async()=>assertFails(env.authenticatedContext('driver_1').firestore().collection('cab_assignment_members').get()));
    it('ATTACK: denies unrelated role query',async()=>assertFails(query(env.authenticatedContext('unrelated_1').firestore())));
  });

  describe('Driver claim boundaries',()=>{
    it('allows active Driver valid claim',async()=>assertSucceeds(claimBatch(env.authenticatedContext('driver_1').firestore()).commit()));
    it('ATTACK: denies off-duty claim',async()=>assertFails(claimBatch(env.authenticatedContext('driver_off').firestore(),{driverId:'driver_off',vehicleId:'veh_1'}).commit()));
    it('ATTACK: denies second Driver claim',async()=>assertFails(claimBatch(env.authenticatedContext('driver_2').firestore(),{driverId:'driver_2',vehicleId:'veh_2',employeeId:'emp_cancel'}).commit()));
    for(const [label,x] of [
      ['Employee UID',{userId:'emp_other'}],['pickup label',{pickupName:'Changed'}],['pickup address',{pickupAddress:'Changed'}],
      ['pickup latitude',{pickupLatitude:10}],['pickup longitude',{pickupLongitude:10}],['branch',{branch:'Dharwad'}],
      ['date',{dateKey:PAST_KEY}],['unknown field',{isAdmin:true}],['trip linkage',{tripId:'trip_bad'}],
    ])it(`ATTACK: denies claim changing ${label}`,async()=>assertFails(claimBatch(env.authenticatedContext('driver_1').firestore(),{member:x}).commit()));
    it('ATTACK: denies invalid assignment linkage',async()=>assertFails(claimBatch(env.authenticatedContext('driver_1').firestore(),{assignmentId:'plan_invalid'}).commit()));
    it('ATTACK: denies shift vehicle mismatch',async()=>assertFails(claimBatch(env.authenticatedContext('driver_1').firestore(),{vehicleId:'veh_2'}).commit()));
  });

  describe('Assignment boundaries',()=>{
    it('allows active Driver assignment',async()=>assertSucceeds(claimBatch(env.authenticatedContext('driver_1').firestore()).commit()));
    it('ATTACK: denies off-duty Driver assignment',async()=>assertFails(claimBatch(env.authenticatedContext('driver_off').firestore(),{driverId:'driver_off',vehicleId:'veh_1'}).commit()));
    it('ATTACK: denies empty employee list',async()=>assertFails(claimBatch(env.authenticatedContext('driver_1').firestore(),{assign:{employeeIds:[]}}).commit()));
    it('ATTACK: denies invalid or unclaimed member',async()=>{const db=env.authenticatedContext('driver_1').firestore();await assertFails(db.collection('cab_assignments').doc(`plan_${TODAY}_driver_1`).set(assignment('driver_1','veh_1',['missing'])));});
    it('ATTACK: denies wrong vehicle',async()=>assertFails(claimBatch(env.authenticatedContext('driver_1').firestore(),{vehicleId:'veh_2'}).commit()));
    it('ATTACK: denies wrong Driver identity',async()=>assertFails(claimBatch(env.authenticatedContext('driver_1').firestore(),{assign:{driverId:'driver_2',assignedBy:'driver_2'}}).commit()));
    it('ATTACK: denies unknown assignment field',async()=>assertFails(claimBatch(env.authenticatedContext('driver_1').firestore(),{assign:{secret:true}}).commit()));
    it('ATTACK: denies another Driver assignment mutation',async()=>assertFails(env.authenticatedContext('driver_1').firestore().collection('cab_assignments').doc(`plan_${TODAY}_driver_cancel`).update({status:'cancelled'})));
  });  describe('Trip boundaries',()=>{
    it('allows valid trip create',async()=>{await seedTripLink();const db=env.authenticatedContext('driver_1').firestore();await assertSucceeds(db.collection('cab_trips').doc(`trip_${TODAY}_driver_1`).set(trip('driver_1','veh_1',`plan_${TODAY}_driver_1`,['emp_ready'])));});
    for(const [label,x] of [['invalid assignment ownership',{assignmentId:`plan_${TODAY}_driver_cancel`}],['wrong vehicle',{vehicleId:'veh_2'}]])it(`ATTACK: denies trip create with ${label}`,async()=>{await seedTripLink();const db=env.authenticatedContext('driver_1').firestore();await assertFails(db.collection('cab_trips').doc(`trip_${TODAY}_driver_1`).set({...trip('driver_1','veh_1',`plan_${TODAY}_driver_1`,['emp_ready']),...x}));});
    for(const [label,x] of [
      ['employeeIds',{employeeIds:['emp_other']}],['Driver ID',{driverId:'driver_1'}],['assignmentId',{assignmentId:'plan_other'}],
      ['date',{dateKey:PAST_KEY}],['branch',{branch:'Dharwad'}],['unknown field',{arbitrary:true}],
    ])it(`ATTACK: denies trip ${label} mutation`,async()=>assertFails(env.authenticatedContext('driver_cancel').firestore().collection('cab_trips').doc(`trip_${TODAY}_driver_cancel`).update(x)));
    it('allows valid active to office-arrived transition',async()=>assertSucceeds(env.authenticatedContext('driver_cancel').firestore().collection('cab_trips').doc(`trip_${TODAY}_driver_cancel`).update({status:'office_arrived',officeArrivedAt:new Date(),updatedAt:new Date()})));
    it('ATTACK: denies invalid state jump',async()=>assertFails(env.authenticatedContext('driver_cancel').firestore().collection('cab_trips').doc(`trip_${TODAY}_driver_cancel`).update({status:'created',updatedAt:new Date()})));
    for(const [from,to] of [['completed','active'],['cancelled','active'],['completed','cancelled']])it(`ATTACK: denies terminal ${from} to ${to}`,async()=>{await env.withSecurityRulesDisabled(c=>c.firestore().collection('cab_trips').doc(`trip_${TODAY}_driver_cancel`).update({status:from}));await assertFails(env.authenticatedContext('driver_cancel').firestore().collection('cab_trips').doc(`trip_${TODAY}_driver_cancel`).update({status:to,updatedAt:new Date()}));});
    it('allows valid atomic cancellation',async()=>assertSucceeds(cancelBatch(env.authenticatedContext('driver_cancel').firestore()).commit()));
    it('ATTACK: denies unauthorized cancellation',async()=>assertFails(cancelBatch(env.authenticatedContext('driver_1').firestore(),{actor:'driver_1'}).commit()));
    it('ATTACK: denies cancellation without reason',async()=>assertFails(cancelBatch(env.authenticatedContext('driver_cancel').firestore(),{reason:''}).commit()));
    it('ATTACK: denies Other without explanation',async()=>assertFails(cancelBatch(env.authenticatedContext('driver_cancel').firestore(),{reason:'Other'}).commit()));
  });

  describe('Rider boundaries',()=>{
    const ref=(db,e='emp_cancel')=>db.collection('cab_trips').doc(`trip_${TODAY}_driver_cancel`).collection('riders').doc(e);
    it('allows valid rider create',async()=>{await env.withSecurityRulesDisabled(c=>ref(c.firestore(),'emp_rider2').delete());await assertSucceeds(ref(env.authenticatedContext('driver_cancel').firestore(),'emp_rider2').set(rider(`trip_${TODAY}_driver_cancel`,`plan_${TODAY}_driver_cancel`,'emp_rider2')));});
    it('allows Employee own rider read',async()=>assertSucceeds(ref(env.authenticatedContext('emp_cancel').firestore()).get()));
    it('ATTACK: denies another rider read',async()=>assertFails(ref(env.authenticatedContext('emp_rider2').firestore()).get()));
    it('ATTACK: denies unrelated Driver rider read',async()=>assertFails(ref(env.authenticatedContext('driver_1').firestore()).get()));
    it('ATTACK: denies unrelated Driver rider write',async()=>assertFails(ref(env.authenticatedContext('driver_1').firestore()).update({status:'waiting',updatedAt:new Date()})));
    it('ATTACK: denies rider identity mutation',async()=>assertFails(ref(env.authenticatedContext('driver_cancel').firestore()).update({employeeId:'emp_other'})));
    it('ATTACK: denies invalid rider transition',async()=>assertFails(ref(env.authenticatedContext('driver_cancel').firestore()).update({status:'dropped',updatedAt:new Date()})));
    it('allows arrival transition',async()=>assertSucceeds(ref(env.authenticatedContext('driver_cancel').firestore()).update({status:'waiting',reachedPickupAt:new Date(),updatedAt:new Date()})));
    it('allows waiting transition to picked-up',async()=>{await env.withSecurityRulesDisabled(c=>ref(c.firestore()).update({status:'waiting'}));await assertSucceeds(ref(env.authenticatedContext('driver_cancel').firestore()).update({status:'picked_up',pickedUpAt:new Date(),updatedAt:new Date()}));});
    it('allows picked-up transition to dropped',async()=>assertSucceeds(ref(env.authenticatedContext('driver_cancel').firestore(),'emp_rider2').update({status:'dropped',droppedAt:new Date(),updatedAt:new Date()})));
    it('ATTACK: denies immutable timestamp overwrite',async()=>assertFails(ref(env.authenticatedContext('driver_cancel').firestore()).update({createdAt:new Date(0)})));
    it('ATTACK: denies terminal rider reactivation',async()=>{await env.withSecurityRulesDisabled(c=>ref(c.firestore()).update({status:'dropped'}));await assertFails(ref(env.authenticatedContext('driver_cancel').firestore()).update({status:'waiting',updatedAt:new Date()}));});
  });

  describe('Passenger-progress boundaries',()=>{
    const ref=(db)=>db.collection('cab_trips').doc(`trip_${TODAY}_driver_cancel`).collection('passenger_progress').doc('emp_cancel');
    it('allows Employee own progress read',async()=>assertSucceeds(ref(env.authenticatedContext('emp_cancel').firestore()).get()));
    it('ATTACK: denies another Employee progress read',async()=>assertFails(ref(env.authenticatedContext('emp_rider2').firestore()).get()));
    it('allows owning Driver progress update',async()=>assertSucceeds(ref(env.authenticatedContext('driver_cancel').firestore()).update({status:'waiting',remark:'waiting',updatedAt:new Date()})));
    it('ATTACK: denies unrelated Driver progress update',async()=>assertFails(ref(env.authenticatedContext('driver_1').firestore()).update({status:'waiting',updatedAt:new Date()})));
    for(const [label,x] of [['unknown field',{secret:true}],['private coordinates',{latitude:15,longitude:75}],['identity mutation',{employeeId:'emp_other'}]])it(`ATTACK: denies progress ${label}`,async()=>assertFails(ref(env.authenticatedContext('driver_cancel').firestore()).update(x)));
    it('ATTACK: denies invalid progress transition',async()=>assertFails(ref(env.authenticatedContext('driver_cancel').firestore()).update({status:'completed',updatedAt:new Date()})));
  });

  describe('Notification boundaries',()=>{
    const create=(actor,e,type,x={})=>env.authenticatedContext(actor).firestore().collection('notifications').doc(`${type}_${e}`).set(notice(e,type,x));
    it('allows trip-start notification for own rider',async()=>assertSucceeds(create('driver_cancel','emp_cancel','cab_trip_started')));
    it('ATTACK: denies arbitrary recipient',async()=>assertFails(create('driver_cancel','emp_other','cab_trip_started')));
    it("ATTACK: denies another Driver's trip",async()=>assertFails(create('driver_1','emp_cancel','cab_trip_started')));
    it('ATTACK: denies unsupported Driver type',async()=>assertFails(create('driver_cancel','emp_cancel','unsupported')));
    it('ATTACK: denies unknown notification field',async()=>assertFails(create('driver_cancel','emp_cancel','cab_trip_started',{admin:true})));
    it('ATTACK: denies Start Duty Employee notification',async()=>{const db=env.authenticatedContext('driver_1').firestore();await assertFails(db.collection('notifications').doc('duty').set({userId:'emp_ready',title:'Duty',body:'Started',type:'cab_trip_started',source:'duty',driverId:'driver_1',isRead:false,createdAt:new Date()}));});
    for(const type of ['cab_arriving','cab_picked_up'])it(`allows ${type} notification`,async()=>assertSucceeds(create('driver_cancel','emp_cancel',type)));
    it('allows completion notification',async()=>{await env.withSecurityRulesDisabled(c=>c.firestore().collection('cab_trips').doc(`trip_${TODAY}_driver_cancel`).update({status:'completed'}));await assertSucceeds(create('driver_cancel','emp_cancel','cab_trip_completed'));});
    it('allows cancellation notification',async()=>{await env.withSecurityRulesDisabled(c=>c.firestore().collection('cab_trips').doc(`trip_${TODAY}_driver_cancel`).update({status:'cancelled'}));await assertSucceeds(create('driver_cancel','emp_cancel','cab_trip_cancelled',{cancellationReason:'Safety issue'}));});
    it('ATTACK: denies cancellation notification for non-rider',async()=>{await env.withSecurityRulesDisabled(c=>c.firestore().collection('cab_trips').doc(`trip_${TODAY}_driver_cancel`).update({status:'cancelled'}));await assertFails(create('driver_cancel','emp_other','cab_trip_cancelled',{cancellationReason:'Safety issue'}));});
  });  describe('Location and presence boundaries',()=>{
    it('allows assigned Employee Driver location read',async()=>assertSucceeds(env.authenticatedContext('emp_cancel').firestore().collection('live_locations').doc('driver_cancel').get()));
    it('ATTACK: denies unassigned Employee location read',async()=>assertFails(env.authenticatedContext('emp_ready').firestore().collection('live_locations').doc('driver_cancel').get()));
    it('ATTACK: denies unrelated Employee location read',async()=>assertFails(env.authenticatedContext('emp_other').firestore().collection('live_locations').doc('driver_cancel').get()));
    it('ATTACK: denies unrelated Driver Employee location read',async()=>assertFails(env.authenticatedContext('driver_1').firestore().collection('live_locations').doc('emp_cancel').get()));
    it('ATTACK: denies global shared presence read',async()=>assertFails(env.authenticatedContext('emp_cancel').firestore().collection('shared_map_presence').get()));
    it('allows Admin shared presence read',async()=>assertSucceeds(env.authenticatedContext('admin_1').firestore().collection('shared_map_presence').get()));
    it('allows Manager shared presence read',async()=>assertSucceeds(env.authenticatedContext('manager_1').firestore().collection('shared_map_presence').get()));
    it('allows End Duty offline presence update',async()=>assertSucceeds(env.authenticatedContext('driver_cancel').firestore().collection('shared_map_presence').doc('driver_cancel').update({status:'offline',updatedAt:new Date()})));
    it('ATTACK: completed trip no longer exposes location',async()=>{await env.withSecurityRulesDisabled(c=>c.firestore().collection('cab_trips').doc(`trip_${TODAY}_driver_cancel`).update({status:'completed'}));await assertFails(env.authenticatedContext('emp_cancel').firestore().collection('live_locations').doc('driver_cancel').get());});
  });

  describe('Shift boundaries',()=>{
    it('allows own valid shift',async()=>assertSucceeds(env.authenticatedContext('driver_new').firestore().collection('cab_driver_shifts').doc(`${TODAY}_driver_new`).set(shift('driver_new','veh_new'))));
    it('ATTACK: denies another Driver shift',async()=>assertFails(env.authenticatedContext('driver_1').firestore().collection('cab_driver_shifts').doc(`${TODAY}_driver_new`).set(shift('driver_new','veh_new'))));
    it('ATTACK: denies unknown shift field',async()=>assertFails(env.authenticatedContext('driver_new').firestore().collection('cab_driver_shifts').doc(`${TODAY}_driver_new`).set({...shift('driver_new','veh_new'),secret:true})));
    for(const [label,x] of [['Driver ID',{driverId:'driver_2'}],['date',{shiftDate:PAST_KEY}],['vehicle',{vehicleId:'veh_2'}]])it(`ATTACK: denies shift ${label} mutation`,async()=>assertFails(env.authenticatedContext('driver_1').firestore().collection('cab_driver_shifts').doc(`${TODAY}_driver_1`).update(x)));
    it('allows valid End Duty',async()=>assertSucceeds(env.authenticatedContext('driver_1').firestore().collection('cab_driver_shifts').doc(`${TODAY}_driver_1`).update({shiftStatus:'completed',shiftEnd:new Date(),totalDistance:5})));
    it('ATTACK: denies End Duty with active trip',async()=>assertFails(env.authenticatedContext('driver_cancel').firestore().collection('cab_driver_shifts').doc(`${TODAY}_driver_cancel`).update({shiftStatus:'completed',shiftEnd:new Date()})));
    for(const [label,x] of [['end timestamp rewrite',{shiftEnd:new Date(0)}],['reactivation',{shiftStatus:'active',shiftEnd:null}]])it(`ATTACK: denies completed shift ${label}`,async()=>{await env.withSecurityRulesDisabled(c=>c.firestore().collection('cab_driver_shifts').doc(`${TODAY}_driver_1`).set(shift('driver_1','veh_1','completed')));await assertFails(env.authenticatedContext('driver_1').firestore().collection('cab_driver_shifts').doc(`${TODAY}_driver_1`).update(x));});
  });

  describe('Location-session boundaries',()=>{
    const session={id:'session_driver_1_new',userId:'driver_1',trackingReason:'field_duty',status:'active',startedAt:new Date(),pausedAt:null,resumedAt:null,stoppedAt:null,lastLatitude:null,lastLongitude:null,lastUpdatedAt:new Date(),stopReason:'',metadata:{}};
    it('allows owner valid session create',async()=>assertSucceeds(env.authenticatedContext('driver_1').firestore().collection('location_sessions').doc('session_driver_1_new').set(session)));
    it('ATTACK: denies unrelated session read',async()=>assertFails(env.authenticatedContext('driver_1').firestore().collection('location_sessions').doc('session_driver_cancel').get()));
    it('allows active to stopped transition',async()=>assertSucceeds(env.authenticatedContext('driver_cancel').firestore().collection('location_sessions').doc('session_driver_cancel').update({status:'stopped',stoppedAt:new Date(),stopReason:'duty_ended'})));
    it('ATTACK: denies stopped to active',async()=>{await env.withSecurityRulesDisabled(c=>c.firestore().collection('location_sessions').doc('session_driver_cancel').update({status:'stopped',stoppedAt:new Date()}));await assertFails(env.authenticatedContext('driver_cancel').firestore().collection('location_sessions').doc('session_driver_cancel').update({status:'active',stoppedAt:null}));});
    it('ATTACK: denies session owner mutation',async()=>assertFails(env.authenticatedContext('driver_cancel').firestore().collection('location_sessions').doc('session_driver_cancel').update({userId:'driver_1'})));
    it('ATTACK: denies startedAt mutation',async()=>assertFails(env.authenticatedContext('driver_cancel').firestore().collection('location_sessions').doc('session_driver_cancel').update({startedAt:new Date(0)})));
    it('ATTACK: denies stoppedAt rewrite',async()=>{await env.withSecurityRulesDisabled(c=>c.firestore().collection('location_sessions').doc('session_driver_cancel').update({status:'stopped',stoppedAt:new Date()}));await assertFails(env.authenticatedContext('driver_cancel').firestore().collection('location_sessions').doc('session_driver_cancel').update({stoppedAt:new Date(0)}));});
  });

  describe('Admin and Manager boundaries',()=>{
    it('allows Admin transport read',async()=>assertSucceeds(env.authenticatedContext('admin_1').firestore().collection('cab_trips').doc(`trip_${TODAY}_driver_cancel`).get()));
    it('allows Admin transport operation',async()=>assertSucceeds(env.authenticatedContext('admin_1').firestore().collection('cab_trips').doc(`trip_${TODAY}_driver_cancel`).update({remarks:'Admin review'})));
    it('allows Manager transport read',async()=>assertSucceeds(env.authenticatedContext('manager_1').firestore().collection('cab_assignments').doc(`plan_${TODAY}_driver_cancel`).get()));
    it('allows Manager transport operation',async()=>assertSucceeds(env.authenticatedContext('manager_1').firestore().collection('cab_assignments').doc(`plan_${TODAY}_driver_cancel`).update({remarks:'Manager review'})));
    it('ATTACK: denies unrelated role',async()=>assertFails(env.authenticatedContext('unrelated_1').firestore().collection('cab_trips').doc(`trip_${TODAY}_driver_cancel`).get()));
    it('ATTACK: denies inactive privileged user',async()=>assertFails(env.authenticatedContext('inactive_admin').firestore().collection('cab_trips').doc(`trip_${TODAY}_driver_cancel`).get()));
  });

  describe('Real-world integration scenarios',()=>{
    it('INTEGRATION A: invitation, acceptance, claim, assignment',async()=>{const e=env.authenticatedContext('emp_new').firestore();await assertSucceeds(e.collection('cab_assignment_members').doc(`${TODAY}_emp_new`).update({status:'accepted',invitationStatus:'accepted',declineReason:'',respondedAt:new Date(),updatedAt:new Date()}));const d=env.authenticatedContext('driver_1').firestore();await assertSucceeds(claimBatch(d,{employeeId:'emp_new'}).commit());const a=await assertSucceeds(e.collection('cab_assignments').doc(`plan_${TODAY}_driver_1`).get());expect(a.data().employeeIds).to.include('emp_new');});
    it('INTEGRATION B: arrival, waiting, pickup synchronize',async()=>{const db=env.authenticatedContext('driver_cancel').firestore(),tid=`trip_${TODAY}_driver_cancel`;let b=db.batch();b.update(db.collection('cab_assignment_members').doc(`${TODAY}_emp_cancel`),{status:'waiting',updatedAt:new Date()});b.update(db.collection('cab_trips').doc(tid).collection('riders').doc('emp_cancel'),{status:'waiting',reachedPickupAt:new Date(),updatedAt:new Date()});b.update(db.collection('cab_trips').doc(tid).collection('passenger_progress').doc('emp_cancel'),{status:'waiting',remark:'waiting',updatedAt:new Date()});await assertSucceeds(b.commit());b=db.batch();b.update(db.collection('cab_assignment_members').doc(`${TODAY}_emp_cancel`),{status:'picked_up',updatedAt:new Date()});b.update(db.collection('cab_trips').doc(tid).collection('riders').doc('emp_cancel'),{status:'picked_up',pickedUpAt:new Date(),updatedAt:new Date()});b.update(db.collection('cab_trips').doc(tid).collection('passenger_progress').doc('emp_cancel'),{status:'picked_up',remark:'picked_up',updatedAt:new Date()});await assertSucceeds(b.commit());const m=await assertSucceeds(env.authenticatedContext('emp_cancel').firestore().collection('cab_assignment_members').doc(`${TODAY}_emp_cancel`).get());expect(m.data().status).to.equal('picked_up');});
    it('INTEGRATION C: completion hides location and keeps history',async()=>{await env.withSecurityRulesDisabled(async c=>{const db=c.firestore(),tid=`trip_${TODAY}_driver_cancel`;await db.collection('cab_assignment_members').doc(`${TODAY}_emp_cancel`).update({status:'picked_up'});await db.collection('cab_trips').doc(tid).collection('riders').doc('emp_cancel').update({status:'picked_up'});await db.collection('cab_trips').doc(tid).collection('passenger_progress').doc('emp_cancel').update({status:'picked_up'});});const db=env.authenticatedContext('driver_cancel').firestore(),tid=`trip_${TODAY}_driver_cancel`,aid=`plan_${TODAY}_driver_cancel`,b=db.batch();b.update(db.collection('cab_trips').doc(tid),{status:'completed',completedAt:new Date(),updatedAt:new Date()});b.update(db.collection('cab_assignments').doc(aid),{status:'completed',updatedAt:new Date()});b.update(db.collection('cab_assignment_members').doc(`${TODAY}_emp_cancel`),{status:'completed',updatedAt:new Date()});b.update(db.collection('cab_trips').doc(tid).collection('riders').doc('emp_cancel'),{status:'dropped',droppedAt:new Date(),updatedAt:new Date()});b.update(db.collection('cab_trips').doc(tid).collection('passenger_progress').doc('emp_cancel'),{status:'completed',transportActive:false,updatedAt:new Date()});await assertSucceeds(b.commit());const e=env.authenticatedContext('emp_cancel').firestore();await assertFails(e.collection('live_locations').doc('driver_cancel').get());expect((await assertSucceeds(e.collection('cab_trips').doc(tid).get())).data().status).to.equal('completed');});
    it('INTEGRATION D: two Drivers cannot claim one Employee',async()=>{await assertSucceeds(claimBatch(env.authenticatedContext('driver_1').firestore()).commit());await assertFails(claimBatch(env.authenticatedContext('driver_2').firestore(),{driverId:'driver_2',vehicleId:'veh_2'}).commit());const s=await assertSucceeds(env.authenticatedContext('driver_1').firestore().collection('cab_assignment_members').doc(`${TODAY}_emp_ready`).get());expect(s.data().driverId).to.equal('driver_1');});
    it('INTEGRATION E: cancellation is terminal and preserves picked-up fact',async()=>{const db=env.authenticatedContext('driver_cancel').firestore(),tid=`trip_${TODAY}_driver_cancel`;await assertSucceeds(cancelBatch(db).commit());await assertFails(db.collection('cab_trips').doc(tid).update({status:'active',updatedAt:new Date()}));expect((await assertSucceeds(db.collection('cab_trips').doc(tid).get())).data().status).to.equal('cancelled');expect((await assertSucceeds(db.collection('cab_trips').doc(tid).collection('riders').doc('emp_rider2').get())).data().status).to.equal('picked_up');expect((await assertSucceeds(env.authenticatedContext('emp_cancel').firestore().collection('notifications').doc(`${tid}_emp_cancel_cancelled`).get())).data().type).to.equal('cab_trip_cancelled');});
  });
});