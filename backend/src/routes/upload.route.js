// src/routes/upload.route.js
import express from "express";
import upload from "../middleware/upload.middleware.js";
import { uploadFileController } from "../controllers/upload.controller.js";
import { protectRoute } from "../middleware/auth.middleware.js";

const router = express.Router();

// URL: /upload
router.post("/", protectRoute, upload.single("file"), uploadFileController);

export default router;
