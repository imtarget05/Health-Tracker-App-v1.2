import admin from 'firebase-admin';
import { db } from '../lib/firebase.js';
import { sendPushToUser } from '../notifications/notification.service.js';
import { NotificationType } from '../notifications/notification.templates.js';

/**
 * Utility: parse createdAt which may be Firestore Timestamp or ISO string
 */
function toDate(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') return value.toDate();
  const d = new Date(value);
  return isNaN(d.getTime()) ? null : d;
}

/**
 * computeStreakDays(userId): returns integer days since last workout or null if no history
 */
export async function computeStreakDays(userId) {
  if (!userId) return null;
  try {
    const q = await db.collection('workouts')
      .where('userId', '==', userId)
      .orderBy('createdAt', 'desc')
      .limit(1)
      .get();

    if (q.empty) return null;
    const lastVal = q.docs[0].data().createdAt;
    const lastDate = toDate(lastVal);
    if (!lastDate) return null;
    const diffDays = Math.floor((Date.now() - lastDate.getTime()) / (1000 * 60 * 60 * 24));
    return diffDays;
  } catch (e) {
    console.error('computeStreakDays error', e);
    return null;
  }
}

/**
 * recentlySentReminder checks notifications collection for recent same-type messages
 */
export async function recentlySentReminder(userId, types = [], windowHours = 48) {
  if (!userId || !Array.isArray(types) || types.length === 0) return false;
  try {
    const cutoff = new Date(Date.now() - windowHours * 60 * 60 * 1000).toISOString();
    // Try sentAt then createdAt fields
    const snap = await db.collection('notifications')
      .where('userId', '==', userId)
      .where('type', 'in', types)
      .where('createdAt', '>=', cutoff)
      .limit(1)
      .get()
      .catch(() => ({ empty: true }));
    return !snap.empty;
  } catch (e) {
    console.warn('recentlySentReminder failed', e);
    return false;
  }
}

/**
 * sendStreakReminderIfNeeded(userId)
 */
export async function sendStreakReminderIfNeeded(userId) {
  if (!userId) return;
  try {
    const missedDays = await computeStreakDays(userId);
    if (missedDays === null) return; // skip users with no history

    const lightType = NotificationType.STREAK_LIGHT || 'streak_light';
    const strongType = NotificationType.STREAK_STRONG || 'streak_strong';
    const typesToCheck = [lightType, strongType];

    const already = await recentlySentReminder(userId, typesToCheck, 48);
    if (already) return;

    let title, body, nType;
    if (missedDays >= 5) {
      title = '💪 Chúng ta cùng cố gắng nào!';
      body = `Bạn đã bỏ ${missedDays} ngày. Bắt đầu lại với 15-20 phút hôm nay nhé.`;
      nType = strongType;
    } else if (missedDays >= 2) {
      title = '🧭 Nhắc nhẹ: quay lại luyện tập';
      body = `Bạn đã bỏ ${missedDays} ngày. Hôm nay thử 15-20 phút nhé — bạn làm được!`;
      nType = lightType;
    } else {
      return;
    }

    await sendPushToUser({
      userId,
      type: nType,
      variables: {},
      data: { action: 'streak.reminder', missedDays }
    });
  } catch (e) {
    console.error('sendStreakReminderIfNeeded err', e);
  }
}

/**
 * runWorkoutReminderPass - check profiles for workout.preferredTime and send reminders
 */
export async function runWorkoutReminderPass() {
  try {
    const now = new Date();
    const nowHHMM = now.toTimeString().slice(0, 5); // "HH:MM"
    // paginate through profiles in small batches (limit simple for dev)
    const snap = await db.collection('profiles').limit(500).get();
    for (const doc of snap.docs) {
      const userId = doc.id;
      const profile = doc.data() || {};
      const w = profile.workout;
      if (!w || !w.enabled) continue;
      const preferred = w.preferredTime;
      if (!preferred) continue;
      if (preferred !== nowHHMM) continue;

      // skip if user already logged workout today
      const start = new Date(); start.setHours(0, 0, 0, 0);
      const end = new Date(start); end.setDate(end.getDate() + 1);
      const q = await db.collection('workouts')
        .where('userId', '==', userId)
        .where('createdAt', '>=', start.toISOString())
        .where('createdAt', '<', end.toISOString())
        .limit(1)
        .get();
      if (!q.empty) continue;

      // send personalized streak/reminder
      await sendStreakReminderIfNeeded(userId);
    }
  } catch (e) {
    console.error('runWorkoutReminderPass err', e);
  }
}

/**
 * getDailyTotals and runDailySummaryPass
 */
async function getDailyTotals(userId, date = new Date()) {
  const start = new Date(date); start.setHours(0, 0, 0, 0);
  const end = new Date(start); end.setDate(end.getDate() + 1);
  const totals = { mealsKcal: 0, waterMl: 0, workoutsCalories: 0, workoutsMinutes: 0 };

  try {
    const mealsQ = await db.collection('meals')
      .where('userId', '==', userId)
      .where('createdAt', '>=', start.toISOString())
      .where('createdAt', '<', end.toISOString())
      .get();
    mealsQ.forEach(d => { const m = d.data(); totals.mealsKcal += (m.kcal || 0); });
  } catch (e) { /* ignore */ }

  try {
    const waterQ = await db.collection('water')
      .where('userId', '==', userId)
      .where('createdAt', '>=', start.toISOString())
      .where('createdAt', '<', end.toISOString())
      .get();
    waterQ.forEach(d => { const w = d.data(); totals.waterMl += (w.amountMl || 0); });
  } catch (e) { /* ignore */ }

  try {
    const wQ = await db.collection('workouts')
      .where('userId', '==', userId)
      .where('createdAt', '>=', start.toISOString())
      .where('createdAt', '<', end.toISOString())
      .get();
    wQ.forEach(d => { const w = d.data(); totals.workoutsCalories += (w.caloriesBurned || 0); totals.workoutsMinutes += (w.duration || 0); });
  } catch (e) { /* ignore */ }

  return totals;
}

let _workoutInterval = null;
let _dailyInterval = null;
let _dailyLastRun = null;

export async function runDailySummaryPass() {
  try {
    const now = new Date();
    const hhmm = now.toTimeString().slice(0, 5);
    if (hhmm !== '21:00') return;
    const today = now.toISOString().slice(0, 10);
    if (_dailyLastRun === today) return;
    _dailyLastRun = today;

    const usersSnap = await db.collection('users').get();
    for (const u of usersSnap.docs) {
      const userId = u.id;
      const totals = await getDailyTotals(userId, new Date());
      const body = `Ăn: ${totals.mealsKcal} kcal\nTập: -${totals.workoutsCalories} kcal\nNet: ${totals.mealsKcal - totals.workoutsCalories} kcal\nNước: ${(Math.round(totals.waterMl / 100) / 10)} L`;
      await sendPushToUser({
        userId,
        type: NotificationType.DAILY_SUMMARY,
        variables: {
          total_calories: totals.mealsKcal,
          target_calories: undefined,
          total_water: Math.round(totals.waterMl),
          target_water: undefined,
          summary_note: ''
        },
        data: { totals }
      }).catch(e => console.error('daily summary send err', e));
    }
  } catch (e) {
    console.error('runDailySummaryPass err', e);
  }
}

export function startWorkoutReminderScheduler(intervalMs = 60 * 1000) {
  if (_workoutInterval) return;
  runWorkoutReminderPass().catch(() => { });
  _workoutInterval = setInterval(() => runWorkoutReminderPass().catch(() => { }), intervalMs);
}

export function startDailySummaryScheduler(intervalMs = 60 * 1000) {
  if (_dailyInterval) return;
  runDailySummaryPass().catch(() => { });
  _dailyInterval = setInterval(() => runDailySummaryPass().catch(() => { }), intervalMs);
}

/**
 * createWorkout route handler
 */
export async function createWorkout(req, res) {
  try {
    const userId = req.user && req.user.uid;
    if (!userId) return res.status(401).json({ message: 'Unauthorized' });
    const { type = 'cardio', duration = 0, caloriesBurned = 0 } = req.body;
    const now = new Date().toISOString();
    const payload = { userId, type, duration: Number(duration), caloriesBurned: Number(caloriesBurned), createdAt: now };

    const ref = await db.collection('workouts').add(payload);

    // send completion notification (non-blocking)
    sendPushToUser({
      userId,
      type: NotificationType.WORKOUT_COMPLETE,
      variables: {
        duration: payload.duration,
        type: payload.type,
        calories: payload.caloriesBurned
      },
      data: { workoutId: ref.id }
    }).catch(() => { });

    return res.status(201).json({ id: ref.id, ...payload });
  } catch (e) {
    console.error('createWorkout err', e);
    return res.status(500).json({ message: 'Internal Server Error' });
  }
}

// after app ready / firebase init
