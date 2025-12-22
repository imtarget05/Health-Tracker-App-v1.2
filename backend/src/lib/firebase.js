import { config } from "dotenv";
config();

let auth;
let db;
let storage;
let bucket;
let app;

const initializeFirebase = async () => {
    try {
        const firebaseAdmin = await import("firebase-admin");
        const admin = firebaseAdmin.default;

        // 🔄 Tránh khởi tạo trùng (Firebase Admin không cho phép)
        if (admin.apps.length > 0) {
            app = admin.apps[0];
            auth = admin.auth();
            db = admin.firestore();
            storage = admin.storage();
            bucket = storage.bucket(process.env.FIREBASE_STORAGE_BUCKET);

            return { auth, db, storage, bucket, app };
        }

        const isEmulator = !!process.env.FIRESTORE_EMULATOR_HOST || process.env.USE_FIREBASE_EMULATOR === "1";
        if (isEmulator) {
            // When using the emulator, avoid requiring a real service account.
            // Ensure firebase-admin has an explicit project ID so it does not
            // try to query the GCE metadata server (which fails on dev machines).
            const projectId = process.env.FIREBASE_PROJECT_ID || process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
            if (projectId) {
                process.env.GCLOUD_PROJECT = projectId;
            }
            app = admin.initializeApp({ projectId });
            auth = admin.auth();
            db = admin.firestore();
            storage = admin.storage ? admin.storage() : undefined;
            bucket = storage && process.env.FIREBASE_STORAGE_BUCKET ? storage.bucket(process.env.FIREBASE_STORAGE_BUCKET) : undefined;

            console.log(" Firebase Admin initialized in EMULATOR mode");

            return { auth, db, storage, bucket, app };
        }

        // 🔐 Service account (fix key \n)
        // Do not log private key material. Keep only light initialization logs.
        if (!process.env.FIREBASE_PRIVATE_KEY) {
            console.warn('Firebase private key not provided in environment; ensure service account is available for production.');
        }

        // � Service account object (support escaped \n in .env)
        const serviceAccount = {
            type: process.env.FIREBASE_TYPE,
            project_id: process.env.FIREBASE_PROJECT_ID,
            private_key_id: process.env.FIREBASE_PRIVATE_KEY_ID,
            private_key: process.env.FIREBASE_PRIVATE_KEY ? process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n") : undefined,
            client_email: process.env.FIREBASE_CLIENT_EMAIL,
            client_id: process.env.FIREBASE_CLIENT_ID,
            auth_uri: process.env.FIREBASE_AUTH_URI,
            token_uri: process.env.FIREBASE_TOKEN_URI,
            auth_provider_x509_cert_url: process.env.FIREBASE_AUTH_PROVIDER_CERT_URL,
            client_x509_cert_url: process.env.FIREBASE_CLIENT_CERT_URL,
            universe_domain: process.env.FIREBASE_UNIVERSE_DOMAIN,
        };

        // �🚀 Initialize Firebase Admin SDK
        app = admin.initializeApp({
            credential: admin.credential.cert(serviceAccount),
            storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
        });

        auth = admin.auth();
        db = admin.firestore();
        storage = admin.storage();
        bucket = storage.bucket(process.env.FIREBASE_STORAGE_BUCKET);

        console.log(" Firebase Admin initialized successfully");

        return { auth, db, storage, bucket, app };
    } catch (error) {
        console.error(" Error initializing Firebase:", error);
        throw error;
    }
};

const firebasePromise = initializeFirebase();

// --- Safe getters ---------------------------------------------------------
// Use these to avoid accidentally using uninitialized bindings.
export const getAuth = () => {
    if (!auth) throw new Error("Firebase not initialized yet. Await firebasePromise first.");
    return auth;
};

export const getDb = () => {
    if (!db) throw new Error("Firebase not initialized yet. Await firebasePromise first.");
    return db;
};

export const getStorage = () => {
    if (!storage) throw new Error("Firebase not initialized yet. Await firebasePromise first.");
    return storage;
};

export const getBucket = () => {
    if (!bucket) throw new Error("Firebase not initialized yet. Await firebasePromise first.");
    return bucket;
};

export const getApp = () => {
    if (!app) throw new Error("Firebase not initialized yet. Await firebasePromise first.");
    return app;
};

// Backwards-compatible named exports (these will be populated after init)
export { auth, db, storage, bucket, app, firebasePromise };
export default app;
