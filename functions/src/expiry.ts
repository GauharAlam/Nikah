import type { DocumentReference, Firestore } from 'firebase-admin/firestore';

/**
 * Expires proposals one transaction at a time, so an answer that arrived after
 * the scheduler's query is never overwritten. Returns the ids that moved.
 */
export async function expiredProposalIds(db: Firestore, refs: DocumentReference[]): Promise<string[]> {
  const moved = await Promise.all(refs.map((ref) => db.runTransaction(async (tx) => {
    if ((await tx.get(ref)).data()?.status !== 'pending') return null;
    tx.update(ref, { status: 'expired' });
    return ref.id;
  })));
  return moved.filter((id): id is string => id !== null);
}
