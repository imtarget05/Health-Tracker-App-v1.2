import assert from "assert";
import { firebasePromise, getDb } from "../src/lib/firebase.js";

const run = async () => {
    // This test expects the Firestore emulator to be running and the seed script to have run.
    await firebasePromise;
    const db = getDb();

    const doc = await db.collection('users').doc('seed-test-user-1').get();
    assert.ok(doc.exists, 'seed user should exist in Firestore');

    const data = doc.data();
    assert.strictEqual(data.uid, 'seed-test-user-1');
    assert.strictEqual(data.email, 'seed@example.com');

    console.log('seed.integration test passed');
};

run().catch((e) => { console.error(e); process.exit(1); });
