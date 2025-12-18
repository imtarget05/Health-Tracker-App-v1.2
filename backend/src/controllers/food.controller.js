import fs from "fs/promises";
import fetch from 'node-fetch';
import { firebasePromise, getDb } from "../lib/firebase.js";
import { AI_SERVICE_URL } from "../config/env.js";
import aiClient from "../services/aiClient.js";
import { handleAiProcessingSuccess, handleAiProcessingFailure } from '../notifications/notification.logic.js';

const MEAL_TYPES = ["breakfast", "lunch", "dinner", "snack"];

export const scanFood = async (req, res) => {
  let localPath;
  try {
    await firebasePromise;
    const db = getDb();
    const user = req.user || null;
    const userId = user?.uid || user?.userId || null;
    const { mealType } = req.body;

    // mealType không bắt buộc, nhưng nếu có thì validate
    let normalizedMealType = null;
    if (mealType && MEAL_TYPES.includes(mealType)) {
      normalizedMealType = mealType;
    }

    // 1. Kiểm tra file
    if (!req.file) {
      return res
        .status(400)
        .json({ message: "File is required (field name: file)" });
    }

    localPath = req.file.path;

    // 2. Gọi AI service (BE ← AI) với timeout/retry và parsing an toàn
    const fileBuffer = await fs.readFile(localPath);

    let aiData;
    try {
      aiData = await aiClient.postPredict(`${AI_SERVICE_URL}/predict`, fileBuffer, { timeout: 12000, retries: 2, aiApiKey: process.env.AI_API_KEY });
    } catch (err) {
      console.error('AI service error:', err?.message || err, err?.raw ? `rawLen=${String(err.raw).slice(0, 200)}` : '');
      return res.status(502).json({ message: 'AI service error', detail: err?.message || 'unknown' });
    }

    // validate shape
    if (!aiData || typeof aiData !== 'object' || !Array.isArray(aiData.detections)) {
      console.error('AI returned unexpected shape', aiData);
      return res.status(502).json({ message: 'AI service returned invalid response' });
    }
    // dạng:
    // {
    //   success: true,
    //   detections: [ { food, confidence, portion_g, nutrition:{...} } ],
    //   total_nutrition: {...},
    //   items_count: 1,
    //   image_dimensions: {...}
    // }

    if (!aiData.success || !Array.isArray(aiData.detections) || aiData.detections.length === 0) {
      return res.status(400).json({
        message: "No food detected in image",
      });
    }

    // Chọn detection chính (ở đây chọn detection đầu tiên
    // hoặc em có thể chọn detection có calories lớn nhất)
    const mainDetection = aiData.detections[0];

    const label = mainDetection.food;
    const confidence = mainDetection.confidence;
    const portionG = mainDetection.portion_g;
    const nutrition = mainDetection.nutrition || {};

    // 3. Tra bảng FoodItem (bảng chuẩn dinh dưỡng)
    let foodItem = null;
    let foodItemId = null;

    const foodSnap = await db
      .collection("foodItems")
      .where("name", "==", label)
      .limit(1)
      .get();

    if (!foodSnap.empty) {
      const doc = foodSnap.docs[0];
      foodItemId = doc.id;
      foodItem = doc.data();
    }

    // 4. Build response theo spec

    let suggestedServing;
    let calories;

    if (foodItem) {
      // nếu đã có trong bảng chuẩn
      suggestedServing = foodItem.servingSize || "1 serving";
      calories =
        foodItem.caloriesPerServing ??
        nutrition.calories ??
        null;
    } else {
      // chưa có trong bảng chuẩn -> fallback dùng AI
      suggestedServing =
        typeof portionG === "number"
          ? `${Math.round(portionG)}g`
          : "1 serving";

      calories = nutrition.calories ?? null;
    }

    // 5. Trả JSON về cho Flutter (Mobile ↔ BE)
    return res.status(200).json({
      label,                       // vd: "bread"
      confidence,                  // 0.92
      suggested_serving: suggestedServing, // "1 slice (30g)" hoặc "349g"
      calories,                    // 80 hoặc từ AI
      food_item_id: foodItemId,    // id trong collection foodItems (nếu có)
      meal_type: normalizedMealType,
      // bonus info cho FE nếu cần
      ai_meta: {
        items_count: aiData.items_count,
        total_nutrition: aiData.total_nutrition,
        image_dimensions: aiData.image_dimensions,
      },
    });
  } catch (error) {
    console.error("Error in scanFood:", error);
    return res.status(500).json({ message: "Internal server error" });
  } finally {
    // Xoá file tạm
    if (localPath) {
      try {
        await fs.unlink(localPath);
      } catch (e) {
        console.warn("Cannot remove temp file:", localPath, e.message);
      }
    }
  }
};

// POST /foods/scan-url
// Body: JSON { imageUrl: string, mealType?: string }
export const scanFoodFromUrl = async (req, res) => {
  try {
    await firebasePromise;
    const db = getDb();
    const user = req.user || null;
    const userId = user?.uid || user?.userId || null;
    const { imageUrl, mealType } = req.body;

    if (!imageUrl || typeof imageUrl !== 'string') {
      return res.status(400).json({ message: 'imageUrl is required' });
    }

    // Try AI analyze-from-url endpoint first (fast when AI can fetch URL directly)
    let aiData;
    try {
      const url = `${AI_SERVICE_URL}/analyze-from-url?image_url=${encodeURIComponent(imageUrl)}`;
      aiData = await aiClient.getAnalyzeFromUrl(url, { timeout: 15000, retries: 2, aiApiKey: process.env.AI_API_KEY });
    } catch (err) {
      console.warn('analyze-from-url failed, attempting server-side fetch+predict fallback:', err?.message || err);

      // Fallback: try to download image server-side and POST raw bytes to AI /predict
      try {
        const fetchResp = await fetch(imageUrl);
        if (!fetchResp.ok) {
          const msg = `Failed to download image (${fetchResp.status})`;
          console.error(msg);
          if (userId) { try { await handleAiProcessingFailure({ userId }); } catch (e) { console.warn('notify failure', e?.message || e); } }
          return res.status(502).json({ message: 'AI service error', detail: msg });
        }

        const arrayBuffer = await fetchResp.arrayBuffer();
        const buffer = Buffer.from(arrayBuffer);

        try {
          aiData = await aiClient.postPredict(`${AI_SERVICE_URL}/predict`, buffer, { timeout: 20000, retries: 2 });
        } catch (err2) {
          console.error('AI service error (predict fallback):', err2?.message || err2, err2?.raw ? `rawLen=${String(err2.raw).slice(0, 200)}` : '');
          if (userId) { try { await handleAiProcessingFailure({ userId }); } catch (e) { console.warn('notify failure', e?.message || e); } }
          return res.status(502).json({ message: 'AI service error', detail: err2?.message || 'unknown' });
        }
      } catch (fetchErr) {
        console.error('Failed to fetch image server-side:', fetchErr?.message || fetchErr);
        if (userId) { try { await handleAiProcessingFailure({ userId }); } catch (e) { console.warn('notify failure', e?.message || e); } }
        return res.status(502).json({ message: 'AI service error', detail: fetchErr?.message || 'failed to fetch image' });
      }
    }

    if (!aiData || typeof aiData !== 'object' || !Array.isArray(aiData.detections)) {
      console.error('AI returned unexpected shape', aiData);
      if (userId) { try { await handleAiProcessingFailure({ userId }); } catch (e) { console.warn('notify failure', e?.message || e); } }
      return res.status(502).json({ message: 'AI service returned invalid response' });
    }

    if (!aiData.success || aiData.detections.length === 0) {
      if (userId) { try { await handleAiProcessingFailure({ userId }); } catch (e) { console.warn('notify failure', e?.message || e); } }
      return res.status(400).json({ message: 'No food detected in image' });
    }

    const detections = aiData.detections || [];
    const totalNutrition = aiData.total_nutrition || null;
    const itemsCount = aiData.items_count ?? detections.length;
    const imageDimensions = aiData.image_dimensions || null;

    // choose main detection (highest calories)
    let mainDetection = null;
    if (detections.length > 0) {
      mainDetection = detections.reduce((max, cur) => {
        const curCal = cur?.nutrition?.calories ?? 0;
        const maxCal = max?.nutrition?.calories ?? 0;
        return curCal > maxCal ? cur : max;
      });
    }

    const now = new Date().toISOString();

    const logData = {
      userId,
      // We do not persist the remote image URL into cloud storage here. The frontend is expected
      // to download and save the image locally and associate it with the returned document id.
      imagePath: null,
      imageUrl: null,
      detections,
      totalNutrition,
      itemsCount,
      imageDimensions,
      mainFood: mainDetection
        ? {
          food: mainDetection.food,
          portion_g: mainDetection.portion_g,
          nutrition: mainDetection.nutrition,
          confidence: mainDetection.confidence,
        }
        : null,
      createdAt: now,
    };

    const docRef = await db.collection('foodDetections').add(logData);

    // notify success
    if (userId && mainDetection) {
      const deepLinkUrl = `healthytracker://detection/${docRef.id}`;
      try {
        await handleAiProcessingSuccess({
          userId,
          mealType: mealType || 'bữa ăn',
          foodName: mainDetection.food,
          calories: mainDetection.nutrition?.calories ?? 0,
          deepLinkUrl,
        });
      } catch (e) { console.warn('notify failure', e?.message || e); }
    }

    // Suggest a filename the frontend can use to persist the image locally.
    const extMatch = (imageUrl || '').match(/\.([a-zA-Z0-9]+)(?:\?|$)/);
    const ext = extMatch ? `.${extMatch[1]}` : '.jpg';
    const suggestedLocalFilename = `${docRef.id}${ext}`;

    return res.status(200).json({
      id: docRef.id,
      suggestedLocalFilename,
      itemsCount,
      detections,
      totalNutrition,
      mainFood: logData.mainFood,
      createdAt: now,
    });
  } catch (error) {
    console.error('Error in scanFoodFromUrl:', error);
    return res.status(500).json({ message: 'Internal server error' });
  }
};
