// src/config/gemini.js
import { GoogleGenAI } from "@google/genai";
import { AI_CHAT_API_KEY } from "./env.js"; // 👈 import từ env.js

if (!AI_CHAT_API_KEY) {
    throw new Error("AI_CHAT_API_KEY is not set");
}

export const gemini = new GoogleGenAI({ apiKey: AI_CHAT_API_KEY });

// Model chat chính
export const GEMINI_CHAT_MODEL = "gemini-2.5-flash"; // hoặc gemini-1.5-flash nếu muốn
