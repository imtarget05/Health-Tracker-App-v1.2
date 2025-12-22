import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

// This script is intended to run against the local emulator.
// Make sure FIRESTORE_EMULATOR_HOST and GOOGLE_APPLICATION_CREDENTIALS are set appropriately.

async function seedOldToken(db) {
    const oldDate = new Date();
    oldDate.setDate(oldDate.getDate() - 365); // 1 year old

    const doc = await db.collection('deviceTokens').add({
        userId: 'test-user-cleanup',
        token: 'stale-token-123',
        isActive: false,
        failureCount: 5,
        lastFailureAt: oldDate.toISOString(),
        createdAt: oldDate.toISOString(),
    });
    console.log('Seeded stale token id=', doc.id);
    return doc.id;
}

async function run() {
    // Initialize admin using emulator
    initializeApp({ projectId: process.env.FIREBASE_PROJECT || 'demo-project' });
    const db = getFirestore();

    const seededId = await seedOldToken(db);

    // invoke cleanup (inline, using Admin SDK) - remove inactive tokens with lastFailureAt older than 30 days
    console.log('Invoking inline cleanup for tokens older than 30 days');
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - 30);
    const cutoffIso = cutoff.toISOString();

    const snap = await db.collection('deviceTokens')
        .where('isActive', '==', false)
        .where('lastFailureAt', '<', cutoffIso)
        .get();

    let removed = 0;
    if (!snap.empty) {
        const batchSize = 500;
        let batch = db.batch();
        let ops = 0;
        for (const d of snap.docs) {
            batch.delete(d.ref);
            ops += 1;
            removed += 1;
            if (ops >= batchSize) {
                await batch.commit();
                batch = db.batch();
                ops = 0;
            }
        }
        if (ops > 0) await batch.commit();
    }
    console.log('Cleanup result: removed=', removed);

    // verify
    const doc = await db.collection('deviceTokens').where('token', '==', 'stale-token-123').get();
    if (doc.empty) {
        console.log('Verification passed: token removed');
        process.exit(0);
    } else {
        console.error('Verification failed: token still exists');
        process.exit(2);
    }
}

run().catch((e) => {
    console.error('Error running test', e && (e.message || e));
    process.exit(1);
});
