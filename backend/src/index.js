// src/index.js
import express from "express";
import dotenv from "dotenv";
import cookieParser from "cookie-parser";
import authRoutes from "./routes/auth.route.js";
import uploadRoutes from "./routes/upload.route.js";
// 🔴 XÓA: import { connectDB } from "./lib/db.js";

dotenv.config();
const app = express();

const PORT = process.env.PORT || 5001;

app.use(express.json());
app.use(cookieParser());

// Routes
app.use("/auth", authRoutes);
app.use("/upload", uploadRoutes);
// Health check route
app.get("/api/health", (req, res) => {
    res.json({
        status: "OK",
        message: "Server is running",
        timestamp: new Date().toISOString(),
        database: "Firebase Firestore", // ✅ ĐỔI THÀNH FIRESTORE
        firebase: "Initialized"
    });
});

// Simple test route - chỉ hiển thị endpoints
app.get("/api/test", (req, res) => {
    res.json({
        message: "Chat App API Endpoints",
        endpoints: [
            { method: "GET", path: "/api/health", description: "Server status" },
            { method: "POST", path: "/api/auth/signup", description: "Create user" },
            { method: "POST", path: "/api/auth/login", description: "Login user" },
            { method: "GET", path: "/api/auth/check", description: "Check auth" },
            { method: "POST", path: "/api/auth/facebook", description: "Facebook OAuth" },
            { method: "POST", path: "/api/auth/google", description: "Google OAuth" },
            { method: "PUT", path: "/api/auth/update-profile", description: "Update profile" },
            { method: "POST", path: "/api/auth/logout", description: "Logout" }
        ]
    });
});

// Start server
app.listen(PORT, () => {
    console.log("Server is running on port:" + PORT);
    console.log("Using Firebase Firestore for database"); // ✅ THÔNG BÁO FIRESTORE
});