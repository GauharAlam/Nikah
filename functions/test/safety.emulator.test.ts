// Reports reach people who can act on them, and cannot be used as a weapon.
import { before, test } from 'node:test';
import assert from 'node:assert/strict';
import { admin, code, profile, user } from './helpers';

let db: FirebaseFirestore.Firestore;
let auth: ReturnType<typeof admin>['auth'];

async function target(uid: string) {
  await db.doc(`profiles/${uid}`).set(profile(uid, 'female'));
  await db.doc(`accounts/${uid}`).set({ stage: 'approved' });
  return user(uid, { approved: true });
}

before(() => { ({ db, auth } = admin()); });

test('SEC-09: an unapproved account cannot report anyone', async () => {
  await target('s1');
  for (const id of ['s1a', 's1b', 's1c']) {
    const fresh = await user(id, {});
    assert.equal(await code(fresh('reportProfile', { target: 's1', reason: 'Fake profile' })), 'functions/permission-denied');
  }
  assert.equal((await db.doc('profiles/s1').get()).data()?.live, true);
});

test('SEC-09: a member cannot report themselves', async () => {
  const m = await target('s2');
  assert.equal(await code(m('reportProfile', { target: 's2', reason: 'Fake profile' })), 'functions/invalid-argument');
});

test('SEC-09: repeating a report does not reopen a closed one', async () => {
  await target('s3');
  const m = await user('s3r', { approved: true });
  await m('reportProfile', { target: 's3', reason: 'Fake profile' });
  const rev = await user('srev', { reviewer: true });
  await rev('resolveReport', { id: 's3r_s3', decision: 'dismiss' });
  await m('reportProfile', { target: 's3', reason: 'Fake profile' });
  assert.equal((await db.doc('reports/s3r_s3').get()).data()?.status, 'dismissed');
});

test('reports carry a structured reason and optional details', async () => {
  await target('s4');
  const m = await user('s4r', { approved: true });
  assert.equal(await code(m('reportProfile', { target: 's4', reason: 'Because' })), 'functions/invalid-argument');
  await m('reportProfile', { target: 's4', reason: 'Asked for money', details: 'Asked for a loan', context: 'conversation' });
  const r = (await db.doc('reports/s4r_s4').get()).data();
  assert.equal(r?.reason, 'Asked for money');
  assert.equal(r?.details, 'Asked for a loan');
  assert.equal(r?.context, 'conversation');
});

test('reviewers see reports without the reporter, and members cannot', async () => {
  await target('s5');
  const m = await user('s5r', { approved: true });
  await m('reportProfile', { target: 's5', reason: 'Fake profile' });
  assert.equal(await code(m('listReports')), 'functions/permission-denied');
  const rev = await user('srev', { reviewer: true });
  const { reports } = await rev('listReports');
  const found = reports.find((r: any) => r.target === 's5');
  assert.ok(found);
  assert.equal(found.reporter, undefined);
});

test('a hold takes a member off the app, and a reviewer can release it with a record', async () => {
  const t = await target('s6');
  await db.doc('profiles/s6m').set(profile('s6m', 'male'));
  await db.doc('matches/s6_s6m').set({ users: ['s6', 's6m'], status: 'active' });
  for (const id of ['s6a', 's6b', 's6c']) {
    await (await user(id, { approved: true }))('reportProfile', { target: 's6', reason: 'Fake profile' });
  }
  assert.equal((await db.doc('profiles/s6').get()).data()?.held, true);
  assert.equal((await db.doc('accounts/s6').get()).data()?.held, true);
  assert.equal((await auth.getUser('s6')).customClaims?.approved, false);
  assert.ok(t);

  const rev = await user('srev', { reviewer: true });
  await rev('releaseHold', { uid: 's6' });
  const p = (await db.doc('profiles/s6').get()).data();
  assert.equal(p?.live, true);
  assert.equal(p?.held, undefined);
  assert.equal((await auth.getUser('s6')).customClaims?.approved, true);
  const log = await db.collection('auditLogs').where('target', '==', 's6').get();
  assert.ok(log.docs.some((d) => d.data().action === 'hold_released'));
});

test('a reviewer cannot resolve a report about themselves or release their own hold', async () => {
  await target('s7');
  const m = await user('s7r', { approved: true });
  await m('reportProfile', { target: 's7', reason: 'Fake profile' });
  const self = await user('s7', { reviewer: true });
  assert.equal(await code(self('resolveReport', { id: 's7r_s7', decision: 'dismiss' })), 'functions/permission-denied');
  assert.equal(await code(self('releaseHold', { uid: 's7' })), 'functions/permission-denied');
});

test('every report decision is audited', async () => {
  await target('s8');
  const m = await user('s8r', { approved: true });
  await m('reportProfile', { target: 's8', reason: 'Fake profile' });
  const rev = await user('srev', { reviewer: true });
  await rev('resolveReport', { id: 's8r_s8', decision: 'uphold', note: 'Confirmed' });
  assert.equal((await db.doc('reports/s8r_s8').get()).data()?.status, 'upheld');
  const log = await db.collection('auditLogs').where('target', '==', 's8').get();
  assert.ok(log.docs.some((d) => d.data().action === 'report_uphold'));
});

test('SEC-16: reporting and exporting have limits', async () => {
  const m = await user('s9', { approved: true });
  for (let i = 0; i < 10; i++) {
    await db.doc(`profiles/s9t${i}`).set(profile(`s9t${i}`, 'female'));
    await m('reportProfile', { target: `s9t${i}`, reason: 'Fake profile' });
  }
  await db.doc('profiles/s9x').set(profile('s9x', 'female'));
  assert.equal(await code(m('reportProfile', { target: 's9x', reason: 'Fake profile' })), 'functions/resource-exhausted');
  for (let i = 0; i < 3; i++) await m('exportMyData');
  assert.equal(await code(m('exportMyData')), 'functions/resource-exhausted');
});

test('a burst of messages raises a flag for reviewers, not a public action', async () => {
  await db.doc('config/app').set({ limits: { suspiciousMessagesPerDay: 2 } });
  await db.doc('matches/s10_s10b').set({ users: ['s10', 's10b'], status: 'active', unread: {} });
  for (const id of ['1', '2', '3']) {
    await db.doc(`matches/s10_s10b/messages/${id}`).set({ sender: 's10', text: 'x', sentAt: new Date() });
  }
  for (let i = 0; i < 50 && !(await db.doc('reports/system_s10').get()).exists; i++) {
    await new Promise((r) => setTimeout(r, 100));
  }
  const flag = (await db.doc('reports/system_s10').get()).data();
  assert.equal(flag?.reason, 'High message volume');
  await db.doc('config/app').delete();
});
