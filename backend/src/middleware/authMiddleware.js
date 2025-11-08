import jwt from "jsonwebtoken";
import User from "../models/user.js";

export const protectRoute = async (req, res, next) => {
    try {
        // ✅ Hỗ trợ cả cookie và Authorization header
        let token = req.cookies.jwt;

        if (!token && req.headers.authorization) {
            // Extract token from "Bearer <token>"
            const authHeader = req.headers.authorization;
            if (authHeader.startsWith('Bearer ')) {
                token = authHeader.substring(7);
            }
        }

        if (!token) {
            return res.status(401).json({
                success: false,
                message: "Not authorized, no token provided"
            });
        }

        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        if (!decoded || !decoded.id) {
            return res.status(401).json({
                success: false,
                message: "Not authorized, token failed"
            });
        }

        const user = await User.findById(decoded.id).select("-password");
        if (!user) {
            return res.status(401).json({
                success: false,
                message: "User not found"
            });
        }

        req.user = user;
        next();
    } catch (error) {
        console.log("Error in auth middleware", error.message);
        return res.status(401).json({
            success: false,
            message: "Not authorized, token invalid"
        });
    }
}