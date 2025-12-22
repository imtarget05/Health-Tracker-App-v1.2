// src/routes/ai.route.js
import express from "express";
import { chatWithAiCoach, getAiChatHistory, saveAiChatSummary, deleteAiChatSummary } from "../controllers/ai.controller.js";
import { analyzeImage } from "../controllers/aiImage.controller.js";
import { uploadImageAndAnalyze } from "../controllers/aiUpload.controller.js";
import upload from "../middleware/upload.middleware.js";
import { protectRoute } from "../middleware/auth.middleware.js";

const router = express.Router();

// Nếu muốn chat phải login mới được (có profile) → dùng protectRoute
router.post("/chat", protectRoute, chatWithAiCoach);
router.get('/history', protectRoute, getAiChatHistory);
router.post('/summary', protectRoute, saveAiChatSummary);
router.delete('/summary/:chatId', protectRoute, deleteAiChatSummary);
router.post('/analyze-image', protectRoute, analyzeImage);
// multipart upload -> cloud storage -> ai
router.post('/upload-image', protectRoute, upload.single('image'), uploadImageAndAnalyze);

// Nếu muốn thử không cần login, có thể thêm:
// Note: public /chat-public was used for dev testing but has been removed to
// avoid accidental exposure. Use authenticated POST /ai/chat instead.

export default router;
