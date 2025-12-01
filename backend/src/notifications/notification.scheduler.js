import cron from "node-cron";
import { db } from "../lib/firebase.js";
import {
    sendDailySummaryNotification,
    sendStreakReminderIfNeeded,
} from "./notification.logic.js";
import { sendPushToUser } from "./notification.service.js";
import { NotificationType } from "./notification.templates.js";

// Helper lấy profile & target
const getUserTargets = async (userId) => {
    const snap = await db
        .collection("healthProfiles")
        .where("userId", "==", userId)
        .limit(1)
        .get();

    if (snap.empty) {
        return { targetCalories: null, targetWater: null };
    }

    const profile = snap.docs[0].data();
    return {
        targetCalories: profile.targetCaloriesPerDay || null,
        targetWater: profile.targetWaterMlPerDay || null,
    };
};

// Helper lấy daily totals (calo + nước)
const getDailyTotals = async (userId, dateStr) => {
    // meals
    const mealSnap = await db
        .collection("meals")
        .where("userId", "==", userId)
        .where("date", "==", dateStr)
        .get();

    let totalCalories = 0;
    mealSnap.forEach((doc) => {
        const data = doc.data();
        totalCalories += data.totalCalories || 0;
    });

    // water
    const waterSnap = await db
        .collection("waterLogs")
        .where("userId", "==", userId)
        .where("date", "==", dateStr)
        .get();

    let totalWater = 0;
    waterSnap.forEach((doc) => {
        const data = doc.data();
        totalWater += data.amountMl || 0;
    });

    return { totalCalories, totalWater };
};

// Helper: lấy tất cả userId có healthProfiles (để gửi summary)
const getAllActiveUserIds = async () => {
    const snap = await db.collection("healthProfiles").get();
    const ids = new Set();
    snap.forEach((doc) => {
        const data = doc.data();
        if (data.userId) ids.add(data.userId);
    });
    return Array.from(ids);
};

// Helper: lấy user inactive > X ngày
const getInactiveUserIds = async (days) => {
    const now = new Date();
    const cutoff = new Date(now);
    cutoff.setDate(now.getDate() - days);

    const snap = await db
        .collection("users") // collection profile user
        .where("lastLoginAt", "<", cutoff.toISOString())
        .get();

    const ids = [];
    snap.forEach((doc) => {
        const data = doc.data();
        if (data.uid) ids.push(data.uid);
    });

    return ids;
};

export const startNotificationSchedulers = () => {
    // ---- Daily Summary: 21:00 mỗi ngày ----
    cron.schedule("0 21 * * *", async () => {
        const now = new Date();
        const dateStr = now.toISOString().slice(0, 10);

        console.log("[Cron] Running Daily Summary at 21:00 for", dateStr);

        const userIds = await getAllActiveUserIds();
        for (const userId of userIds) {
            try {
                const { targetCalories, targetWater } = await getUserTargets(userId);
                const { totalCalories, totalWater } = await getDailyTotals(
                    userId,
                    dateStr
                );

                await sendDailySummaryNotification({
                    userId,
                    date: dateStr,
                    totalCalories,
                    targetCalories,
                    totalWater,
                    targetWater,
                });
            } catch (e) {
                console.error("[Cron] DailySummary error for user", userId, e);
            }
        }
    });

    // ---- Streak Reminder: 20:00 mỗi ngày ----
    cron.schedule("0 20 * * *", async () => {
        const now = new Date();
        const dateStr = now.toISOString().slice(0, 10);
        console.log("[Cron] Running Streak Reminder at 20:00 for", dateStr);

        const userIds = await getAllActiveUserIds();
        for (const userId of userIds) {
            try {
                await sendStreakReminderIfNeeded({ userId, currentDate: now });
            } catch (e) {
                console.error("[Cron] StreakReminder error for user", userId, e);
            }
        }
    });

    // ---- Re-engagement: 10:00 mỗi ngày, nếu > 3 ngày không login ----
    cron.schedule("0 10 * * *", async () => {
        console.log("[Cron] Running Re-engagement at 10:00");

        const inactiveUserIds = await getInactiveUserIds(3);
        for (const userId of inactiveUserIds) {
            try {
                await sendPushToUser({
                    userId,
                    type: NotificationType.RE_ENGAGEMENT,
                    variables: {
                        inactive_days: 3,
                    },
                });
            } catch (e) {
                console.error("[Cron] Re-engagement error for user", userId, e);
            }
        }
    });

    console.log("✅ Notification schedulers started");
};
