const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { DateTime } = require('luxon');

admin.initializeApp();
const db = admin.firestore();

// Helper: sum meals for userId & dateStr (YYYY-MM-DD)
async function getDailyTotals(userId, dateStr) {
    const mealsSnap = await db.collection('meals')
        .where('userId', '==', userId)
        .where('date', '==', dateStr)
        .get();

    let totalCalories = 0, totalProtein = 0;
    mealsSnap.forEach(d => {
        const data = d.data();
        totalCalories += Number(data.calories || data.totalCalories || 0);
        totalProtein += Number(data.protein || 0);
    });

    const waterSnap = await db.collection('waterLogs')
        .where('userId', '==', userId)
        .where('date', '==', dateStr)
        .get();
    let totalWater = 0;
    waterSnap.forEach(d => { totalWater += Number(d.data().amountMl || 0); });

    return { totalCalories, totalProtein, totalWater };
}

// Get list of active users: read collection healthProfiles (existing app convention)
async function getAllUserIds() {
    const snap = await db.collection('healthProfiles').get();
    const ids = [];
    snap.forEach(d => {
        const data = d.data();
        if (data.userId) ids.push(data.userId);
    });
    return ids;
}

// Determine status vs target
function computeStatus(totalCalories, targetCalories, mealCount) {
    if (!mealCount || mealCount === 0) return 'missing';
    if (!targetCalories) return 'unknown';
    const diff = totalCalories - targetCalories;
    if (diff > 100) return 'exceed';
    if (diff < -200) return 'warning';
    return 'good';
}

exports.scheduledDailySummary = functions.pubsub.schedule('0 21 * * *').timeZone('UTC').onRun(async (context) => {
    console.log('[CF] scheduledDailySummary starting');
    const now = DateTime.utc();

    const userIds = await getAllUserIds();
    const CHUNK = 30;
    for (let i = 0; i < userIds.length; i += CHUNK) {
        const chunk = userIds.slice(i, i + CHUNK);
        await Promise.all(chunk.map(async (uid) => {
            try {
                // read profile to get timezone and targets
                const profDoc = await db.collection('profiles').doc(uid).get();
                const profile = profDoc.exists ? profDoc.data() : null;
                const tz = profile && profile.timezone ? profile.timezone : 'UTC';
                const localNow = now.setZone(tz);
                const dateStr = localNow.toISODate(); // YYYY-MM-DD in user's timezone

                const totals = await getDailyTotals(uid, dateStr);

                // count meals
                const mealsSnap = await db.collection('meals')
                    .where('userId', '==', uid)
                    .where('date', '==', dateStr)
                    .get();
                const mealCount = mealsSnap.size;

                const targetCalories = profile && profile.dailyCalorieTarget ? Number(profile.dailyCalorieTarget) : null;

                const status = computeStatus(totals.totalCalories, targetCalories, mealCount);

                const summaryRef = db.collection('profiles').doc(uid).collection('dailySummaries').doc(dateStr);
                const payload = {
                    date: dateStr,
                    totalCalories: totals.totalCalories,
                    totalProtein: totals.totalProtein,
                    totalWater: totals.totalWater,
                    mealCount,
                    targetCalories: targetCalories || null,
                    status,
                    createdAt: new Date().toISOString(),
                };
                await summaryRef.set(payload, { merge: true });

                // Also write top-level copy for indexing/analytics
                await db.collection('dailySummaries').add({ userId: uid, ...payload });

                // Send notification via FCM - write notification doc and send
                const title = status === 'good' ? '✅ Hôm nay bạn ăn rất cân đối' : (status === 'exceed' ? '⚠️ Bạn vượt mục tiêu calo' : (status === 'missing' ? '❗ Chưa ghi nhận bữa hôm nay' : 'Báo cáo ngày'));
                const body = status === 'good' ? `Tổng ${totals.totalCalories} kcal — rất tốt!` : (status === 'exceed' ? `Bạn vượt ${totals.totalCalories - (targetCalories || 0)} kcal so với mục tiêu` : (status === 'missing' ? 'Bạn chưa ghi nhận đủ bữa hôm nay' : `Tổng ${totals.totalCalories} kcal`));

                // write notifications collection for QA
                await db.collection('notifications').add({
                    userId: uid,
                    type: 'DAILY_SUMMARY',
                    title,
                    body,
                    data: { date: dateStr },
                    status: 'pending',
                    createdAt: new Date().toISOString(),
                });

                // send FCM via admin SDK using deviceTokens docs
                const tokenSnap = await db.collection('deviceTokens').where('userId', '==', uid).where('isActive', '==', true).get();
                const tokens = [];
                tokenSnap.forEach(d => { const dd = d.data(); if (dd.token) tokens.push(dd.token); });
                if (tokens.length) {
                    const message = {
                        notification: { title, body },
                        data: { type: 'DAILY_SUMMARY', date: dateStr }
                    };
                    // use sendMulticast in batches of 500
                    for (let j = 0; j < tokens.length; j += 500) {
                        const batch = tokens.slice(j, j + 500);
                        try {
                            const resp = await admin.messaging().sendMulticast({ tokens: batch, ...message });
                            console.log('[CF] Sent FCM for', uid, 'success=', resp.successCount, 'failed=', resp.failureCount);
                        } catch (e) {
                            console.error('[CF] FCM send error for', uid, e && e.message);
                        }
                    }
                }
            } catch (e) {
                console.error('[CF] user processing failed', e && e.message);
            }
        }));
    }

    console.log('[CF] scheduledDailySummary finished');
    return null;
});
