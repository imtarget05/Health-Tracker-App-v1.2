#!/usr/bin/env node
// Usage: node migrate_meals_to_profiles.js [--limit N]
import { firebasePromise, getDb } from '../src/lib/firebase.js';

const args = process.argv.slice(2);
let limit = 500;
for (let i = 0; i < args.length; i++) if (args[i] === '--limit' && args[i + 1]) limit = Number(args[i + 1]);

const run = async () => {
    await firebasePromise;
    const db = getDb();
    console.log('Starting migration... limit=', limit);

    const snap = await db.collection('meals').limit(limit).get();
    if (snap.empty) { console.log('No meals found'); return; }

    let count = 0;
    for (const doc of snap.docs) {
        const data = doc.data();
        if (!data.userId) { console.warn('Skipping meal without userId', doc.id); continue; }

        const targetRef = db.collection('profiles').doc(data.userId).collection('meals').doc(doc.id);
        const exists = await targetRef.get();
        if (exists.exists) { console.log('Already migrated', doc.id); continue; }

        // copy document (preserve id)
        await targetRef.set(data);
        count++;
        console.log('Migrated', doc.id, 'to profiles/', data.userId, '/meals');
    }

    console.log('Migration finished. migrated=', count);
};

run().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
