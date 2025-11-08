// Firebase Admin SDK initialization
import admin from 'firebase-admin';
import dotenv from 'dotenv';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
    try {
        // Option 1: Use service account JSON file (as string in env)
        if (process.env.FIREBASE_SERVICE_ACCOUNT_KEY) {
            const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_KEY);
            admin.initializeApp({
                credential: admin.credential.cert(serviceAccount),
            });
            console.log('✅ Firebase Admin initialized with SERVICE_ACCOUNT_KEY');
        }
        // Option 2: Use service account file path
        else if (process.env.FIREBASE_SERVICE_ACCOUNT_PATH) {
            const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH.startsWith('/')
                ? process.env.FIREBASE_SERVICE_ACCOUNT_PATH
                : join(__dirname, '..', '..', process.env.FIREBASE_SERVICE_ACCOUNT_PATH);
            const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf8'));
            admin.initializeApp({
                credential: admin.credential.cert(serviceAccount),
            });
            console.log('✅ Firebase Admin initialized with SERVICE_ACCOUNT_PATH');
        }
        // Option 3: Use project ID (for Google Cloud environments)
        else if (process.env.FIREBASE_PROJECT_ID) {
            admin.initializeApp({
                projectId: process.env.FIREBASE_PROJECT_ID,
            });
            console.log('✅ Firebase Admin initialized with PROJECT_ID');
        } else {
            console.error('❌ Firebase configuration not found!');
            console.error('Please set one of the following in your .env file:');
            console.error('  - FIREBASE_SERVICE_ACCOUNT_KEY (JSON string)');
            console.error('  - FIREBASE_SERVICE_ACCOUNT_PATH (file path)');
            console.error('  - FIREBASE_PROJECT_ID (project ID)');
            console.error('\n⚠️  Server will start but Firebase features will not work.');
            console.error('📖 See .env.example for configuration guide.');
        }
    } catch (error) {
        console.error('❌ Error initializing Firebase Admin:', error.message);
        console.error('⚠️  Server will start but Firebase features will not work.');
        // Don't throw error - allow server to start without Firebase
    }
}

export const adminAuth = admin.apps.length > 0 ? admin.auth() : null;
export const db = admin.apps.length > 0 ? admin.firestore() : null;
export default admin.apps.length > 0 ? admin : null;

