import { onCall } from 'firebase-functions/v2/https';
import { accountRef, approvedUid, newCode } from './shared';

export const getInviteCode = onCall(async (req) => {
  const uid = approvedUid(req);
  const acc = (await accountRef(uid).get()).data() ?? {};
  if (acc.inviteCode) return { code: acc.inviteCode, invited: acc.invitedCount ?? 0, earned: acc.inviteCredits ?? 0 };
  const code = await newCode('inviteCodes', { uid });
  await accountRef(uid).set({ inviteCode: code }, { merge: true });
  return { code, invited: 0, earned: 0 };
});
