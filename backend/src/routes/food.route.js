import express from "express";
import upload from "../middleware/upload.middleware.js";
import { protectRoute } from "../middleware/auth.middleware.js";
import { scanFood } from "../controllers/food.controller.js";
import { scanFoodFromUrl } from "../controllers/food.controller.js";

const router = express.Router();

// POST /foods/scan
// Body: multipart/form-data
//   - file: ảnh món ăn
//   - mealType (optional): breakfast/lunch/dinner/snack
router.post(
    "/scan",
    protectRoute,            // yêu cầu user đã đăng nhập (có JWT)
    upload.single("file"),
    scanFood
);

// POST /foods/scan-url
// Body: JSON { imageUrl: string, mealType?: string }
router.post(
    "/scan-url",
    protectRoute,
    express.json(),
    scanFoodFromUrl
);

export default router;
