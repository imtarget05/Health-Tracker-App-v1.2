import { getDb, firebasePromise } from "./firebase.js";

/**
 * getUserTargets: returns standardized target fields for a user.
 * Output: { targetCalories: number|null, targetWaterMlPerDay: number|null }
 */
export const getUserTargets = async (userId) => {
    await firebasePromise;
    const db = getDb();

    const snap = await db
        .collection("healthProfiles")
        .where("userId", "==", userId)
        .limit(1)
        .get();

    if (snap.empty) return { targetCalories: null, targetWaterMlPerDay: null };

    const profile = snap.docs[0].data();

    return {
        targetCalories: profile.targetCaloriesPerDay || null,
        targetWaterMlPerDay: profile.targetWaterMlPerDay || null,
    };
};

export default {
    getUserTargets,
};
