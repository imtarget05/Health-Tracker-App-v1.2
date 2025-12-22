import { firebasePromise, getApp, getDb } from '../lib/firebase.js';
import aiClient from '../services/aiClient.js';
import fs from 'fs';
import path from 'path';
import { DateTime } from 'luxon';

// POST /ai/upload-image (multipart) field name 'image'
export const uploadImageAndAnalyze = async (req, res) => {
    try {
        const user = req.user;
        if (!user) return res.status(401).json({ message: 'Not authenticated' });
        if (!req.file) return res.status(400).json({ message: 'No file uploaded' });

        await firebasePromise;
        const admin = getApp();
        const db = getDb();

        const bucket = admin.storage().bucket();
        const tmpPath = req.file.path;
        const destName = `uploads/${user.uid}/${Date.now()}_${req.file.filename}`;

        // Upload file from tmp to bucket
        await bucket.upload(tmpPath, { destination: destName, metadata: { contentType: req.file.mimetype } });

        // Remove tmp file
        try { fs.unlinkSync(tmpPath); } catch (e) { /* ignore */ }

        const file = bucket.file(destName);
        // create aiImages doc status pending
        const nowIso = new Date().toISOString();
        const aiImageRef = db.collection('aiImages').doc();
        await aiImageRef.set({ userId: user.uid, storagePath: `gs://${bucket.name}/${destName}`, status: 'pending', createdAt: nowIso });

        // generate signed url valid short time for AI service
        const [signedUrl] = await file.getSignedUrl({ action: 'read', expires: DateTime.utc().plus({ minutes: 10 }).toJSDate() });

        // call AI
        let analysis;
        try {
            analysis = await aiClient.getAnalyzeFromUrl(signedUrl);
        } catch (e) {
            console.error('AI analysis failed', e && (e.message || e));
            // mark aiImage as failed
            await aiImageRef.update({ status: 'failed', error: String(e && (e.message || e)), updatedAt: new Date().toISOString() });
            return res.status(502).json({ message: 'AI analysis failed' });
        }

        const detections = analysis.detections || [];
        const detectionRef = db.collection('foodDetections').doc();
        const detDoc = { userId: user.uid, aiImageId: aiImageRef.id, detections, createdAt: nowIso, updatedAt: nowIso };
        await detectionRef.set(detDoc);

        // update aiImage status
        await aiImageRef.update({ status: 'analyzed', detections, updatedAt: new Date().toISOString() });

        return res.status(200).json({ aiImageId: aiImageRef.id, detectionId: detectionRef.id, detections });
    } catch (e) {
        console.error('uploadImageAndAnalyze error', e && (e.message || e));
        return res.status(500).json({ message: 'Internal server error' });
    }
};
