#!/usr/bin/env bash
# Simple helper to run Firebase emulator, seed, run tests, and then stop.
# Requires firebase-tools installed locally (npx firebase-tools) or globally.
set -euo pipefail
cd "$(dirname "$0")/.."

# Start emulator in background
npx firebase emulators:start --only firestore --project=demo-project &
EMULATOR_PID=$!
# Wait for emulator to boot
sleep 3

# Set env to point to emulator
export FIRESTORE_EMULATOR_HOST=localhost:8080
export USE_FIREBASE_EMULATOR=1

# Run seed against emulator
npm run seed:emulator

# Run tests
npm test

# Stop emulator
kill $EMULATOR_PID || true
wait $EMULATOR_PID 2>/dev/null || true

echo "Emulator run complete"
