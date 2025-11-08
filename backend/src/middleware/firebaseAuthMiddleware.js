// Firebase Authentication Middleware
import admin, { adminAuth, db } from '../lib/firebase.js';

export const verifyFirebaseToken = async (req, res, next) => {
    try {
        // Check if Firebase Admin is initialized
        if (!adminAuth || !db) {
            return res.status(503).json({
                success: false,
                message: 'Firebase Admin not configured. Please check your .env file.'
            });
        }

        // Extract token from Authorization header
        const authHeader = req.headers.authorization;

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                success: false,
                message: 'No token provided or invalid format'
            });
        }

        const idToken = authHeader.substring(7);

        try {
            // Verify Firebase ID token
            const decodedToken = await adminAuth.verifyIdToken(idToken);

            // Get user data from Firestore
            const userDoc = await db.collection('users').doc(decodedToken.uid).get();

            if (!userDoc.exists) {
                // Create user document if it doesn't exist
                await db.collection('users').doc(decodedToken.uid).set({
                    uid: decodedToken.uid,
                    email: decodedToken.email || '',
                    displayName: decodedToken.name || '',
                    photoURL: decodedToken.picture || '',
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });

                req.user = {
                    uid: decodedToken.uid,
                    email: decodedToken.email,
                    displayName: decodedToken.name,
                    photoURL: decodedToken.picture,
                };
            } else {
                req.user = {
                    uid: userDoc.data().uid,
                    ...userDoc.data(),
                };
            }

            req.firebaseUser = decodedToken;
            next();
        } catch (error) {
            console.error('Token verification error:', error.message);
            return res.status(401).json({
                success: false,
                message: 'Invalid or expired token'
            });
        }
    } catch (error) {
        console.error('Auth middleware error:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Internal server error'
        });
    }
};

