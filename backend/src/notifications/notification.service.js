import { NotificationTemplates, NotificationType } from "./notification.templates.js";
import { firebasePromise, getDb, getApp } from "../lib/firebase.js";
import { DateTime } from 'luxon';

// admin will be retrieved after firebase init
let admin;

// Quiet hours: 23:00 - 06:00
const DEFAULT_QUIET_HOURS = {
    startHour: 23,
    endHour: 6,
};

// send retry/backoff settings
const DEFAULT_SEND_OPTIONS = {
    maxRetries: 2,
    baseDelayMs: 250, // backoff base
    batchDelayMs: 200, // small pause between batches
    batchSize: 500, // safe multicast batch size
};

// Helper: thay {{placeholder}} bằng dữ liệu
export const renderTemplate = (template, variables = {}) => {
    if (!template) return { title: "", body: "" };

    const replace = (text) =>
        text.replace(/{{(.*?)}}/g, (_, key) => {
            const trimmedKey = key.trim();
            const value = variables[trimmedKey];
            return value !== undefined && value !== null ? String(value) : "";
        });

    return {
        title: replace(template.title || ""),
        body: replace(template.body || ""),
    };
};

export const isInQuietHours = (date = new Date(), quiet = DEFAULT_QUIET_HOURS, timezone = null) => {
    let dt;
    if (timezone) {
        try {
            dt = DateTime.fromJSDate(date).setZone(timezone);
        } catch (e) {
            dt = DateTime.fromJSDate(date);
        }
    } else {
        dt = DateTime.fromJSDate(date);
    }
    const hour = dt.hour;
    const { startHour, endHour } = quiet;
    // Quiet: [startHour, 24) U [0, endHour)
    if (startHour < endHour) {
        return hour >= startHour && hour < endHour;
    }
    return hour >= startHour || hour < endHour;
};

// Lấy tất cả FCM token của user
const getUserDeviceTokens = async (userId) => {
    await firebasePromise;
    const db = getDb();

    const snap = await db
        .collection("deviceTokens")
        .where("userId", "==", userId)
        .where("isActive", "==", true)
        .get();

    const tokens = [];
    // return objects with token and docId so we can update failure metadata later
    snap.forEach((doc) => {
        const data = doc.data();
        if (data.token) tokens.push({ token: data.token, id: doc.id, meta: data });
    });

    return tokens;
};

// Fetch user profile (to read per-user quiet hours or timezone) if needed
const getUserProfile = async (userId) => {
    try {
        await firebasePromise;
        const db = getDb();
        const doc = await db.collection('profiles').doc(userId).get();
        if (!doc.exists) return null;
        return doc.data();
    } catch (e) {
        console.warn('[Notification] getUserProfile failed', e && (e.message || e));
        return null;
    }
};

// Gửi push tới một user
export const sendPushToUser = async ({
    userId,
    type,
    variables = {},
    data = {},
    respectQuietHours = true,
    // optional per-call send options override DEFAULT_SEND_OPTIONS
    sendOptions = {},
    // optional quietHours object to override global default (e.g. from user profile)
    quietHours = null,
}) => {
    const now = new Date();
    // if quietHours not provided, try to read from profile
    let quiet = quietHours || DEFAULT_QUIET_HOURS;
    if (!quietHours) {
        try {
            const profile = await getUserProfile(userId);
            if (profile && profile.quietHours) {
                quiet = profile.quietHours;
            }
        } catch (e) {
            // ignore and use default
        }
    }
    if (respectQuietHours && isInQuietHours(now, quiet)) {
        console.log(
            `[Notification] Skip due to quiet hours for user ${userId}, type=${type}`
        );
        // still write DB note about quiet hours
        try {
            const db = getDb();
            await db.collection('notifications').add({
                userId,
                type,
                title: '',
                body: '',
                data,
                sentAt: now.toISOString(),
                read: false,
                note: 'skipped_quiet_hours',
            });
        } catch (e) {
            console.warn('[Notification] Cannot write quiet-hours log to DB', e.message || e);
        }
        return;
    }

    // Normalize incoming type strings so callers can pass either
    // - enum key names (e.g. 'DAILY_SUMMARY')
    // - enum values (e.g. 'daily_summary')
    // - or other case variants
    const requestedType = type;
    let normalizedType = requestedType;
    if (typeof requestedType === 'string') {
        // exact match to templates
        if (NotificationTemplates[requestedType]) {
            normalizedType = requestedType;
        } else if (NotificationTemplates[requestedType.toLowerCase()]) {
            normalizedType = requestedType.toLowerCase();
        } else if (NotificationType && NotificationType[requestedType]) {
            // caller passed the enum key name, map to its value
            normalizedType = NotificationType[requestedType];
        }
    }

    const template = NotificationTemplates[normalizedType];
    if (!template) {
        console.warn(`[Notification] Missing template for type=${requestedType} (normalized=${normalizedType})`);
        // Continue: use empty title/body and still write a DB record so dev flows can observe notifications
    }

    const { title, body } = template ? renderTemplate(template, variables) : { title: '', body: '' };
    const tokenEntries = await getUserDeviceTokens(userId);
    const tokens = tokenEntries.map(t => t.token);

    // Always write a DB record even if no tokens. Normalize stored document and limit sizes.
    const db = getDb();
    const sanitizeDataForDb = (obj) => {
        if (!obj || typeof obj !== 'object') return {};
        const out = {};
        const keys = Object.keys(obj).slice(0, 20); // limit keys
        for (const k of keys) {
            try {
                let v = obj[k];
                if (v === null || v === undefined) continue;
                if (typeof v === 'object') v = JSON.stringify(v).slice(0, 1024);
                else v = String(v).slice(0, 1024);
                out[k] = v;
            } catch (e) {
                out[k] = String(obj[k]).slice(0, 256);
            }
        }
        return out;
    };

    if (!tokens.length) {
        console.log(`[Notification] No active tokens for user ${userId}`);
        try {
            await db.collection('notifications').add({
                userId,
                type: normalizedType || type,
                title,
                body,
                data: sanitizeDataForDb(data),
                status: 'no_device_tokens',
                createdAt: now.toISOString(),
                sentAt: now.toISOString(),
                read: false,
                note: 'no_device_tokens',
            });
        } catch (e) {
            console.warn('[Notification] Cannot write notification log to DB', e.message || e);
        }
        return;
    }

    const payload = {
        notification: {
            title,
            body,
        },
        data: {
            type,
            ...Object.entries(data).reduce((acc, [k, v]) => {
                acc[k] = String(v);
                return acc;
            }, {}),
        },
    };

    // ensure admin SDK initialized
    try {
        await firebasePromise;
        admin = getApp() || (await import('firebase-admin')).default;
    } catch (e) {
        console.error('[Notification] Firebase not initialized, cannot send push', e);
        return;
    }

    const messaging = admin.messaging();

    // merge send options
    const opts = { ...DEFAULT_SEND_OPTIONS, ...(sendOptions || {}) };
    const batches = [];
    for (let i = 0; i < tokens.length; i += opts.batchSize) {
        batches.push(tokens.slice(i, i + opts.batchSize));
    }

    let overallResult = { successCount: 0, failureCount: 0, failures: [] };

    for (let i = 0; i < batches.length; i++) {
        const batchTokens = batches[i];
        let attempt = 0;
        let sent = false;
        let lastErr = null;

        while (attempt <= opts.maxRetries && !sent) {
            try {
                const resp = await messaging.sendEachForMulticast({ tokens: batchTokens, ...payload });
                overallResult.successCount += resp.successCount || 0;
                overallResult.failureCount += resp.failureCount || 0;
                if (resp.failureCount && Array.isArray(resp.responses)) {
                    resp.responses.forEach((r, idx) => {
                        if (!r.success) overallResult.failures.push({ token: batchTokens[idx], error: r.error && r.error.message });
                    });
                }
                sent = true;
                console.log(`[Notification] Batch ${i + 1}/${batches.length} sent for user=${userId}, success=${resp.successCount}, failed=${resp.failureCount}`);
            } catch (e) {
                lastErr = e;
                attempt += 1;
                const delay = opts.baseDelayMs * Math.pow(2, attempt - 1);
                console.warn(`[Notification] send batch failed attempt=${attempt}/${opts.maxRetries} user=${userId} err=${e && (e.message || e)} — retrying in ${delay}ms`);
                await new Promise((r) => setTimeout(r, delay));
            }
        }

        if (!sent) {
            console.error(`[Notification] Failed to send batch ${i + 1} for user=${userId} after ${opts.maxRetries} retries`, lastErr && (lastErr.message || lastErr));
        }

        // small delay between batches to reduce spikes
        if (i < batches.length - 1 && opts.batchDelayMs > 0) {
            await new Promise((r) => setTimeout(r, opts.batchDelayMs));
        }
    }

    // Always write log to DB for observability
    try {
        const status = (overallResult && overallResult.failureCount === 0) ? 'sent' : (overallResult && overallResult.successCount > 0 ? 'partial_sent' : 'failed');
        await db.collection('notifications').add({
            userId,
            type: normalizedType || type,
            title,
            body,
            data: sanitizeDataForDb(data),
            status,
            createdAt: now.toISOString(),
            sentAt: now.toISOString(),
            read: false,
            push_result: {
                successCount: overallResult.successCount || 0,
                failureCount: overallResult.failureCount || 0,
                failures: overallResult.failures ? overallResult.failures.slice(0, 20) : [],
            },
        });
    } catch (e) {
        console.warn('[Notification] Cannot write notification log to DB', e.message || e);
    }
    // Update per-token failure metadata in deviceTokens collection
    try {
        // map token -> failures
        const failureMap = new Map();
        if (overallResult.failures && overallResult.failures.length) {
            for (const f of overallResult.failures) {
                failureMap.set(f.token, (failureMap.get(f.token) || 0) + 1);
            }
        }

        const BATCH = 500;
        let writeBatch = db.batch();
        let ops = 0;
        const FAILURE_THRESHOLD = 3; // consecutive failures to mark inactive

        // For tokens that were part of this send, update their metadata
        for (const entry of tokenEntries) {
            const token = entry.token;
            const docRef = db.collection('deviceTokens').doc(entry.id);
            const failedCount = failureMap.get(token) || 0;

            // Determine updates: if any failures for this token, increment failureCount and set lastFailureAt
            if (failedCount > 0) {
                const newCount = ((entry.meta && entry.meta.failureCount) || 0) + failedCount;
                const updates = {
                    failureCount: newCount,
                    lastFailureAt: new Date().toISOString(),
                };
                if (newCount >= FAILURE_THRESHOLD) {
                    updates.isActive = false;
                    updates.note = 'auto_deactivated_failure_threshold';
                }
                writeBatch.update(docRef, updates);
            } else {
                // success for this token: reset failureCount and lastFailureAt
                const updates = {
                    failureCount: 0,
                    lastSuccessAt: new Date().toISOString(),
                    isActive: true,
                };
                writeBatch.update(docRef, updates);
            }

            ops += 1;
            if (ops >= BATCH) {
                await writeBatch.commit();
                writeBatch = db.batch();
                ops = 0;
            }
        }

        if (ops > 0) await writeBatch.commit();
    } catch (e) {
        console.warn('[Notification] Failed to update device token metadata', e && (e.message || e));
    }
};
