// src/routes/notification.route.js
import express from "express";
import { protectRoute } from "../middleware/auth.middleware.js";
import { sendPushToUser } from "../notifications/notification.service.js";
import { NotificationType } from "../notifications/notification.templates.js";

const router = express.Router();

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
