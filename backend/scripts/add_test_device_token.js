#!/usr/bin/env node
import { firebasePromise, getDb } from '../src/lib/firebase.js';

const [, , userIdArg, tokenArg] = process.argv;

if (!userIdArg || !tokenArg) {
  console.log('Usage: node scripts/add_test_device_token.js <userId> <deviceToken>');
  process.exit(1);
}

const run = async () => {
  try {
    await firebasePromise;
    const db = getDb();

    const doc = {
      userId: userIdArg,
      token: tokenArg,
      isActive: true,
      createdAt: new Date().toISOString(),
    };

    const ref = await db.collection('deviceTokens').add(doc);
    console.log('Added device token with id:', ref.id);
    process.exit(0);
  } catch (e) {
    console.error('Failed to add device token:', e && (e.message || e));
    process.exit(1);
  }
};

run();
