// Usage: GOOGLE_APPLICATION_CREDENTIALS=<key outside the repo> npx ts-node scripts/grant-reviewer.ts <uid>
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

async function main(): Promise<void> {
  const uid = process.argv[2];
  if (!uid) throw new Error('Pass the reviewer uid.');
  initializeApp();
  const user = await getAuth().getUser(uid);
  await getAuth().setCustomUserClaims(uid, { ...(user.customClaims ?? {}), reviewer: true });
  console.log(`Reviewer access granted to ${uid}.`);
}
void main();
