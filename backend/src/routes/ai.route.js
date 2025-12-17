// src/routes/ai.route.js
import express from "express";
import { chatWithAiCoach } from "../controllers/ai.controller.js";
import { protectRoute } from "../middleware/auth.middleware.js";

const router = express.Router();

// Nếu muốn chat phải login mới được (có profile) → dùng protectRoute
router.post("/chat", protectRoute, chatWithAiCoach);

// Nếu muốn thử không cần login, có thể thêm:
// Note: public /chat-public was used for dev testing but has been removed to
// avoid accidental exposure. Use authenticated POST /ai/chat instead.

export default router;
