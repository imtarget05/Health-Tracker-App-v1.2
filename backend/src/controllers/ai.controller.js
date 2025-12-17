// src/controllers/ai.controller.js
import { gemini, GEMINI_CHAT_MODEL } from "../config/gemini.js";
import { firebasePromise, getDb } from "../lib/firebase.js";

// Build system prompt dựa trên user + healthProfile
const buildSystemPrompt = (user, healthProfile) => {
  const base =
    "Bạn là một chuyên gia dinh dưỡng & huấn luyện viên sức khỏe, " +
    "tư vấn bằng tiếng Việt, giải thích ngắn gọn, dễ hiểu, không phán xét.\n\n" +
    "Ngữ cảnh: ứng dụng Healthy Tracker giúp người dùng theo dõi calories, nước uống, " +
    "cân nặng và thói quen tập luyện.\n";

  let profileText = "";
  if (healthProfile) {
    profileText =
      "\nThông tin sức khỏe của user:\n" +
      `- Tuổi: ${healthProfile.age ?? "?"}\n` +
      `- Giới tính: ${healthProfile.gender ?? "?"}\n` +
      `- Chiều cao: ${healthProfile.heightCm ?? "?"} cm\n` +
      `- Cân nặng: ${healthProfile.weightKg ?? "?"} kg\n` +
      `- Mức độ vận động: ${healthProfile.activityLevel ?? "?"}\n` +
      `- Mục tiêu: ${healthProfile.goal ?? "?"}\n` +
      `- Target calories/ngày: ${healthProfile.targetCaloriesPerDay ?? "?"}\n` +
      `- Target nước/ngày (ml): ${healthProfile.targetWaterMlPerDay ?? "?"}\n`;
  }

  return (
    base +
    profileText +
    "\nQuy tắc trả lời:\n" +
    "- Luôn trả lời bằng tiếng Việt thân thiện.\n" +
    "- Gợi ý cụ thể (ví dụ: ví dụ bữa ăn, khẩu phần, bài tập), không chỉ nói lý thuyết.\n" +
    "- Nếu user hỏi ngoài chủ đề sức khỏe/dinh dưỡng/thể dục, trả lời ngắn gọn rồi kéo về chủ đề chính.\n"
  );
};

export const chatWithAiCoach = async (req, res) => {
  try {
    const { message, history } = req.body;

    if (!message || typeof message !== "string") {
      return res.status(400).json({ message: "Field 'message' is required" });
    }

    const user = req.user || null;
    let healthProfile = null;
    let recentMeals = [];
    let recentWaterLogs = [];

    // Nếu có user → lấy profile và recent logs để cá nhân hóa
    if (user?.uid || user?.userId) {
      const userId = user.uid || user.userId;
      await firebasePromise;
      const db = getDb();

      // healthProfiles (optional)
      const snap = await db
        .collection("healthProfiles")
        .where("userId", "==", userId)
        .limit(1)
        .get();
      if (!snap.empty) {
        healthProfile = snap.docs[0].data();
      }

      // recent meals: last 24 hours from 'meals' collection (assumes field userId and createdAt)
      const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
      try {
        const mealsSnap = await db
          .collection('meals')
          .where('userId', '==', userId)
          .where('createdAt', '>=', since)
          .orderBy('createdAt', 'desc')
          .limit(10)
          .get();
        recentMeals = mealsSnap.docs.map(d => d.data());
      } catch (e) {
        console.warn('[chatWithAiCoach] failed to load recent meals', e?.message || e);
      }

      // recent water logs: last 24 hours from 'waterLogs' or 'water' collection
      try {
        const waterSnap = await db
          .collection('water')
          .where('userId', '==', userId)
          .where('createdAt', '>=', since)
          .orderBy('createdAt', 'desc')
          .limit(50)
          .get();
        recentWaterLogs = waterSnap.docs.map(d => d.data());
      } catch (e) {
        console.warn('[chatWithAiCoach] failed to load water logs', e?.message || e);
      }
    }

    // Build system prompt including recent logs
    let systemPrompt = buildSystemPrompt(user, healthProfile);
    if (recentMeals && recentMeals.length > 0) {
      systemPrompt += '\n\nGần đây user đã ăn (24h):\n';
      for (const m of recentMeals) {
        const t = m.createdAt || m.timestamp || m.date || '';
        systemPrompt += `- ${m.name ?? m.foodName ?? 'meal'} (${m.calories ?? m.totalCalories ?? '??'} cal) at ${t}\n`;
      }
    }
    if (recentWaterLogs && recentWaterLogs.length > 0) {
      const total = recentWaterLogs.reduce((s, r) => s + (Number(r.amountMl || r.amount || 0)), 0);
      systemPrompt += `\nGần đây user đã uống tổng khoảng ${total} ml trong 24h:\n`;
    }

    // Xây contents cho Gemini
    const contents = [];

    // Cho system prompt vào đầu như 1 message user đặc biệt
    contents.push({
      role: "user",
      parts: [{ text: systemPrompt }],
    });

    // Nếu FE gửi history: [{ role: "user"|"assistant", content: "..." }, ...]
    if (Array.isArray(history)) {
      for (const turn of history) {
        if (!turn || !turn.role || !turn.content) continue;
        contents.push({
          role: turn.role === "assistant" ? "model" : "user",
          parts: [{ text: turn.content }],
        });
      }
    }

    // Tin nhắn hiện tại
    contents.push({
      role: "user",
      parts: [{ text: message }],
    });

    const response = await gemini.models.generateContent({
      model: GEMINI_CHAT_MODEL,
      contents,
    });

    const replyText = response.text || "";

    // Persist chat turn to `aiChats` collection for history/audit
    try {
      await firebasePromise;
      const db = getDb();
      await db.collection('aiChats').add({
        userId: user?.uid || user?.userId || null,
        message,
        reply: replyText,
        createdAt: new Date().toISOString(),
        model: GEMINI_CHAT_MODEL,
      });
    } catch (e) {
      console.warn('[chatWithAiCoach] failed to persist chat turn', e?.message || e);
    }

    return res.status(200).json({
      reply: replyText,
      model: GEMINI_CHAT_MODEL,
    });
  } catch (error) {
    console.error("Error in chatWithAiCoach:", error);
    return res.status(500).json({ message: "AI chat error" });
  }
};
