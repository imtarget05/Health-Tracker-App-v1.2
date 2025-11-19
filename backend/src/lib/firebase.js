// src/lib/firebase.js
import { config } from 'dotenv';
config();

let auth, db, storage, app;

const initializeFirebase = async () => {
    try {
        const firebaseAdmin = await import('firebase-admin');
        const admin = firebaseAdmin.default;

        if (admin.apps.length > 0) {
            app = admin.apps[0];
            auth = admin.auth();
            db = admin.firestore();
            storage = admin.storage();
            return { auth, db, storage, app };
        }

        const serviceAccount = {
            type: process.env.FIREBASE_TYPE,
            project_id: process.env.FIREBASE_PROJECT_ID,
            private_key_id: process.env.FIREBASE_PRIVATE_KEY_ID,

            // 🚨 QUAN TRỌNG: REPLACE \n -> newline thật
            private_key: process.env.FIREBASE_PRIVATE_KEY
                ?.replace(/\\n/g, '\n'),

            client_email: process.env.FIREBASE_CLIENT_EMAIL,
            client_id: process.env.FIREBASE_CLIENT_ID,
            auth_uri: process.env.FIREBASE_AUTH_URI,
            token_uri: process.env.FIREBASE_TOKEN_URI,
            auth_provider_x509_cert_url: process.env.FIREBASE_AUTH_PROVIDER_CERT_URL,
            client_x509_cert_url: process.env.FIREBASE_CLIENT_CERT_URL,
            universe_domain: process.env.FIREBASE_UNIVERSE_DOMAIN
        };

        app = admin.initializeApp({
            credential: admin.credential.cert(serviceAccount),
            databaseURL: `https://${process.env.FIREBASE_PROJECT_ID}.firebaseio.com`,
            storageBucket: process.env.FIREBASE_STORAGE_BUCKET
        });

        auth = admin.auth();
        db = admin.firestore();
        storage = admin.storage();

        console.log('Firebase Admin initialized successfully');
        return { auth, db, storage, app };
    } catch (error) {
        console.error('Error initializing Firebase:', error);
        throw error;
    }
};

const firebasePromise = initializeFirebase();

export { auth, db, storage, app, firebasePromise };
export default app;
