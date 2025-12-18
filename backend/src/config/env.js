import dotenv from "dotenv";

dotenv.config();

const REQUIRED_ENV_VARS = [
    "FIREBASE_API_KEY",
    "GOOGLE_CLIENT_ID",
    "FACEBOOK_APP_ID",
    "FACEBOOK_APP_SECRET",
    "JWT_SECRET",
    "AI_SERVICE_URL",
    "AI_CHAT_API_KEY",
    // AI_API_KEY is optional: if set, backend will forward x-api-key to the AI service.
];

const missing = REQUIRED_ENV_VARS.filter(
    (key) => !process.env[key] || process.env[key].trim() === ""
);

if (missing.length > 0) {
    console.error("Missing required environment variables:", missing.join(", "));
    throw new Error("Missing required environment variables. Check your .env file.");
}

export const FIREBASE_API_KEY = process.env.FIREBASE_API_KEY;
export const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID;
export const FACEBOOK_APP_ID = process.env.FACEBOOK_APP_ID;
export const FACEBOOK_APP_SECRET = process.env.FACEBOOK_APP_SECRET;
export const JWT_SECRET = process.env.JWT_SECRET;
export const NODE_ENV = process.env.NODE_ENV || "development";
export const AI_SERVICE_URL = process.env.AI_SERVICE_URL || "http://localhost:8000";
export const AI_CHAT_API_KEY = process.env.AI_CHAT_API_KEY;
export const AI_API_KEY = process.env.AI_API_KEY || "";
