// src/routes/notification.route.js
import express from "express";
import { protectRoute } from "../middleware/auth.middleware.js";
import { sendPushToUser } from "../notifications/notification.service.js";
import { NotificationType } from "../notifications/notification.templates.js";

const router = express.Router();

const isDevAllowed = async (req) => {
  // allow if env explicitly enables dev endpoints
  if (process.env.ALLOW_DEV_ENDPOINTS === '1' || process.env.ALLOW_DEV_ENDPOINTS === 'true') return true;
  const user = req && req.user;
  if (!user) return false;
  if (user.admin) return true;
  // fallback: check profiles collection for admin flag
  try {
    const db = (await import('../lib/firebase.js')).getDb();
    const doc = await db.collection('profiles').doc(user.uid || user.userId).get();
    if (!doc.exists) return false;
    const profile = doc.data() || {};
    return !!profile.admin;
  } catch (e) {
    console.warn('isDevAllowed profile check failed', e && (e.message || e));
    return false;
  }
};

/**
 * GET /notifications/test
 * - Dùng để test nhanh bằng browser
 * - Không gửi push, chỉ trả JSON confirm route OK
 */
router.get("/test", (req, res) => {
  res.json({
    message: "Notifications route OK",
    note: "Dùng POST /notifications/test (kèm JWT) để gửi push thật.",
  });
});

/**
 * POST /notifications/test
 * - Dùng Postman để gửi push notification test cho user hiện tại
 * - Cần header Authorization: Bearer <jwt>
 */
router.post("/test", protectRoute, async (req, res) => {
  try {
    const user = req.user;
    const userId = user.uid || user.userId;

    const { type, variables, data } = req.body;

    const notifType = type || NotificationType.WATER_REMINDER;

    await sendPushToUser({
      userId,
      type: notifType,
      variables: variables || {
        hours_since_last: 2,
        current_water: 500,
        target_water: 2000,
        suggested_ml: 250,
      },
      data: data || {},
      respectQuietHours: false, // test thì bỏ quiet hours
    });

    return res.status(200).json({
      message: "Test notification sent",
      type: notifType,
    });
  } catch (error) {
    console.error("Error in POST /notifications/test:", error);
    return res.status(500).json({ message: "Internal server error" });
  }
});

// ❗ Quan trọng: phải có default export
export default router;

// Dev-only: POST /notifications/emit
// - Protected route (requires JWT) to create a notification record directly for testing
router.post('/emit', protectRoute, async (req, res) => {
  try {
    if (!(await isDevAllowed(req))) return res.status(403).json({ message: 'Dev endpoints disabled' });

    const user = req.user;
    const userId = user.uid || user.userId;
    const { type, title, body, data } = req.body;

    // use sendPushToUser to ensure consistent write behavior (it will write even with no tokens)
    await sendPushToUser({
      userId,
      type: type || NotificationType.DAILY_SUMMARY,
      variables: {},
      data: data || {},
      respectQuietHours: false,
    });

    return res.status(200).json({ message: 'Emitted notification (test)' });
  } catch (err) {
    console.error('Error in /notifications/emit', err);
    return res.status(500).json({ message: 'Internal server error' });
  }
});

// GET /notifications/user/:userId?limit=20
// - allow if the calling user is the requested user, or admin/dev allowed
router.get('/user/:userId', protectRoute, async (req, res) => {
  try {
    const { userId } = req.params;
    const caller = req.user;

    // allow if caller is the same user
    const isOwner = caller && (caller.uid === userId || caller.userId === userId);
    if (!isOwner && !(await isDevAllowed(req))) return res.status(403).json({ message: 'Not authorized' });

    const limit = Math.min(100, parseInt(req.query.limit || '20', 10));
    const db = (await import('../lib/firebase.js')).getDb();

    // Optional server-side filter by type (accept enum key or value)
    let typeFilter = null;
    if (req.query.type) {
      const q = String(req.query.type);
      // If caller passed enum key like 'DAILY_SUMMARY', map to its value
      try {
        const templates = (await import('../notifications/notification.templates.js'));
        const NotificationType = templates.NotificationType || {};
        if (NotificationType[q]) typeFilter = NotificationType[q];
        else typeFilter = q.toLowerCase();
      } catch (e) {
        typeFilter = q.toLowerCase();
      }
    }

    // Avoid server-side orderBy to prevent missing index errors: fetch limited and sort locally
    let snap;
    if (typeFilter) {
      snap = await db.collection('notifications').where('userId', '==', userId).where('type', '==', typeFilter).limit(limit).get();
    } else {
      snap = await db.collection('notifications').where('userId', '==', userId).limit(limit).get();
    }
    const docs = [];
    // include document id so clients can reference the notification for updates
    snap.forEach(d => docs.push({ id: d.id, ...(d.data() || {}) }));
    docs.sort((a, b) => (b.sentAt || '').localeCompare(a.sentAt || ''));

    return res.status(200).json({ count: docs.length, notifications: docs });
  } catch (err) {
    console.error('Error in GET /notifications/user/:userId', err);
    return res.status(500).json({ message: 'Internal server error' });
  }
});


// PATCH /notifications/:nid/read
// body: { read: true|false } — optional; if omitted, toggles current read state
router.patch('/:nid/read', protectRoute, async (req, res) => {
  try {
    const { nid } = req.params;
    const db = (await import('../lib/firebase.js')).getDb();
    const docRef = db.collection('notifications').doc(nid);
    const doc = await docRef.get();
    if (!doc.exists) return res.status(404).json({ message: 'Notification not found' });

    const data = doc.data() || {};
    const user = req.user;
    const userId = user && (user.uid || user.userId);
    // Only the owner or an admin may modify read state
    if (!user || (!user.admin && data.userId !== userId)) {
      return res.status(403).json({ message: 'Not authorized' });
    }

    // req.body may be undefined for requests without a JSON body; guard access.
    const desired = (req.body && typeof req.body.read === 'boolean') ? req.body.read : !data.read;
    await docRef.update({ read: desired });
    return res.status(200).json({ id: nid, read: desired });
  } catch (err) {
    console.error('Error in PATCH /notifications/:nid/read', err);
    return res.status(500).json({ message: 'Internal server error' });
  }
});
