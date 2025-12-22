// src/routes/upload.route.js
import express from "express";
import upload from "../middleware/upload.middleware.js";
import { uploadFileController, uploadAvatarController } from "../controllers/upload.controller.js";
import { protectRoute } from "../middleware/auth.middleware.js";

const router = express.Router();

// URL: /upload
router.post("/", protectRoute, upload.single("file"), uploadFileController);

// Dedicated avatar upload: POST /upload/avatar
router.post("/avatar", protectRoute, upload.single("file"), uploadAvatarController);

export default router;
