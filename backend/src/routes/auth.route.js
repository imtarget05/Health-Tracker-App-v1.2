// src/routes/auth.route.js
import express from "express";
import {
    signup,
    loginWithToken,
    logout,
    updateProfile,
    checkAuth,
    forgotPassword,
    resetPassword,
    // loginWithEmailPassword // 👉 CÓ THỂ BỎ nếu không dùng
} from "../controllers/auth.controller.js";
import { facebookAuth, googleAuth } from "../controllers/oauth.controller.js";
import { protectRoute } from "../middleware/auth.middleware.js";

const router = express.Router();

// ===== Core Auth theo spec =====
router.post("/register", signup);          // POST /auth/register
router.post("/login", loginWithToken);     // POST /auth/login (client gửi idToken)
router.get("/me", protectRoute, checkAuth);// GET /auth/me

// ===== Extra (nếu muốn giữ tương thích cũ) =====
// router.post("/login-email", loginWithEmailPassword);
router.post("/logout", logout);
router.put("/update-profile", protectRoute, updateProfile);
router.post("/forgot-password", forgotPassword);
router.post("/reset-password", resetPassword);

// ===== OAuth =====
router.post("/facebook", facebookAuth);
router.post("/google", googleAuth);

router.get("/facebook/test", (req, res) => {
    res.json({
        message: "Facebook OAuth endpoint is working",
        note: "Use POST method with accessToken in body",
    });
});

router.get("/google/test", (req, res) => {
    res.json({
        message: "Google OAuth endpoint is ready",
        note: "Use POST method with Google ID token"
    });
});

export default router;
