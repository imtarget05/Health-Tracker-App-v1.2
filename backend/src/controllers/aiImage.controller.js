import aiClient from '../services/aiClient.js';
import { firebasePromise, getDb } from '../lib/firebase.js';

// POST /ai/analyze-image
// Body: { imageUrl: string }  OR multipart file (not implemented here)
export const analyzeImage = async (req, res) => {
    try {
        const user = req.user;
        if (!user) return res.status(401).json({ message: 'Not authenticated' });

        const userId = user.uid || user.userId;
        const { imageUrl } = req.body;
        if (!imageUrl) return res.status(400).json({ message: 'imageUrl is required' });

        await firebasePromise;
        const db = getDb();

        // Call AI analyzer (GET style)
        let analysis = null;
        try {
            analysis = await aiClient.getAnalyzeFromUrl(imageUrl, {});
        } catch (e) {
            console.error('AI analyze failed', e && (e.message || e));
            return res.status(502).json({ message: 'AI service failed', detail: e && e.message });
        }

        // Normalize expected shape: { detections: [ { food, calories, protein, portion_g, confidence, nutrition } ] }
        const detections = analysis.detections || [];

        const now = new Date().toISOString();
        const aiImageRef = db.collection('aiImages').doc();
        const detectionRef = db.collection('foodDetections').doc();

        const aiImageDoc = {
            userId,
            storagePath: imageUrl,
            status: 'analyzed',
            detections,
            raw: analysis,
            createdAt: now,
        };

        const detectionDoc = {
            userId,
            aiImageId: aiImageRef.id,
            detections,
            createdAt: now,
            updatedAt: now,
        };

        await aiImageRef.set(aiImageDoc);
        await detectionRef.set(detectionDoc);

        return res.status(200).json({
            aiImageId: aiImageRef.id,
            detectionId: detectionRef.id,
            detections,
        });
    } catch (e) {
        console.error('analyzeImage error', e && (e.message || e));
        return res.status(500).json({ message: 'Internal server error' });
    }
};
