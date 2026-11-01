// Shared by the emulator suites. Everything runs against the demo-nikah project.
import { getApps, initializeApp as adminApp } from 'firebase-admin/app';
import { getAuth as adminAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { initializeApp } from 'firebase/app';
import { connectAuthEmulator, getAuth, signInWithCustomToken } from 'firebase/auth';
import { connectFunctionsEmulator, getFunctions, httpsCallable } from 'firebase/functions';

export const projectId = 'demo-nikah';
export const bucketName = 'demo-nikah.appspot.com';
let n = 0;

export function admin() {
  process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
  process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
  process.env.FIREBASE_STORAGE_EMULATOR_HOST = '127.0.0.1:9199';
  if (getApps().length === 0) adminApp({ projectId, storageBucket: bucketName });
  return { db: getFirestore(), bucket: getStorage().bucket(), auth: adminAuth() };
}

/** Signs in as [uid] and returns a function that calls callables as them. */
export async function user(uid: string, claims: object, phoneNumber?: string) {
  const a = adminAuth();
  await a.createUser({ uid }).catch(() => undefined);
  if (phoneNumber) await a.updateUser(uid, { phoneNumber });
  await a.setCustomUserClaims(uid, claims);
  const app = initializeApp({ apiKey: 'x', projectId, appId: 'x' }, `h${uid}${n++}`);
  const auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  await signInWithCustomToken(auth, await a.createCustomToken(uid));
  const fns = getFunctions(app, 'asia-south1');
  connectFunctionsEmulator(fns, '127.0.0.1', 5001);
  return (name: string, data: unknown = {}) => httpsCallable(fns, name)(data).then((r) => r.data as any);
}

export const code = (p: Promise<unknown>) => p.then(() => 'ok', (e) => e.code as string);

export const validDraft = (extra: object = {}) => ({
  fullName: 'Sara Khan', gender: 'female', maritalStatus: 'Never married', marriageReadiness: 'Ready now',
  homeCity: 'Delhi', height: `5'4"`, almaMaters: ['AMU'], qualification: 'MBA', qualificationGraduate: true,
  profession: 'Doctor', dateOfBirth: Date.UTC(1998, 0, 1), photos: ['p'], intentConfirmed: true, dataConsent: true,
  ...extra,
});

export const profile = (id: string, gender: string, extra: object = {}) => ({
  id, name: id, gender, live: true, dateOfBirth: Date.UTC(1998, 0, 1), caste: 'Syed', maritalStatus: 'Never married',
  university: 'AMU', education: 'MBA', profession: 'Doctor', location: 'Delhi', approvedAt: Timestamp.now(), ...extra,
});
