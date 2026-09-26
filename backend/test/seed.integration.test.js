import { firebasePromise, getDb } from "../src/lib/firebase.js";
import { execFileSync } from "node:child_process";

// Requires: Firestore emulator running + seed script executed beforehand.
// Run manually: USE_FIREBASE_EMULATOR=true node backend/scripts/seed.js
//
// The suite is SKIPPED - visibly, as "skipped" - when the Firestore emulator is
// not reachable. It used to `return` early instead, which Jest reported as a
// PASS: a test that asserts nothing inflates the pass count and hides the fact
// that the seeded Firestore path is never exercised on a plain `npm test`.
//
// The reachability probe runs at COLLECTION time on purpose: that is the only
// point where Jest can decide to skip a suite. That requires a synchronous
// answer, so the probe is a short-lived child process. Inside the suite the
// emulator is still required - if it goes away between collection and
// execution, the assertions fail loudly rather than passing quietly.

const [emulatorHost, emulatorPort] = (process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8081").split(":");
const port = Number.parseInt(emulatorPort || "8081", 10);

const REACHABILITY_PROBE = [
    "const net = require('node:net');",
    "const socket = net.connect(" + port + ", " + JSON.stringify(emulatorHost) + ");",
    "const timer = setTimeout(() => { socket.destroy(); process.exit(1); }, 2000);",
    "socket.on('connect', () => { clearTimeout(timer); socket.destroy(); process.exit(0); });",
    "socket.on('error', () => { clearTimeout(timer); process.exit(1); });",
].join("\n");

function isEmulatorReachableSync() {
    try {
        execFileSync(process.execPath, ["-e", REACHABILITY_PROBE], { stdio: "ignore", timeout: 10000 });
        return true;
    } catch {
        return false;
    }
}

const describeIfEmulator = isEmulatorReachableSync() ? describe : describe.skip;

describeIfEmulator("Seed data integration", () => {
    test("seed user exists in Firestore emulator", async () => {
        await firebasePromise;
        const db = getDb();

        const doc = await db.collection("users").doc("seed-test-user-1").get();
        expect(doc.exists).toBe(true);

        const data = doc.data();
        expect(data.uid).toBe("seed-test-user-1");
        expect(data.email).toBe("seed@example.com");
    }, 30000);
});
