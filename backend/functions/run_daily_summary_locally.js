// Convenience script to run daily summary logic for testing.
// Usage: node run_daily_summary_locally.js <userId> [date]

const admin = require('firebase-admin');
const { DateTime } = require('luxon');

admin.initializeApp();
const db = admin.firestore();

async function getDailyTotals(userId, dateStr) {
    const mealsSnap = await db.collection('meals')
        .where('userId', '==', userId)
        .where('date', '==', dateStr)
        .get();
    let totalCalories = 0, totalProtein = 0;
    mealsSnap.forEach(d => { const dt = d.data(); totalCalories += Number(dt.totalCalories || 0); totalProtein += Number(dt.totalProtein || 0); });
    return { totalCalories, totalProtein };
}

async function run(userId, dateStr) {
    const profileDoc = await db.collection('profiles').doc(userId).get();
    const profile = profileDoc.exists ? profileDoc.data() : null;
    const totals = await getDailyTotals(userId, dateStr);
    console.log('Profile:', profile);
    console.log('Totals:', totals);

    const payload = {
        date: dateStr,
        totalCalories: totals.totalCalories,
        totalProtein: totals.totalProtein,
        mealCount: 1,
        targetCalories: profile && profile.dailyCalorieTarget || null,
        status: 'test',
        createdAt: new Date().toISOString(),
    };

    await db.collection('profiles').doc(userId).collection('dailySummaries').doc(dateStr).set(payload, { merge: true });
    console.log('Wrote summary for', userId, dateStr);
}

(async function () {
    const args = process.argv.slice(2);
    const userId = args[0];
    const dateStr = args[1] || DateTime.utc().toISODate();
    if (!userId) { console.error('Usage: node run_daily_summary_locally.js <userId> [YYYY-MM-DD]'); process.exit(1); }
    await run(userId, dateStr);
    process.exit(0);
})();
