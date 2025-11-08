// authRoutes.js
import express from 'express';
import {
  verifyToken,
  getUserProfile,
  updateProfile,
  checkAuth,
  sendLoginOTP,
  verifyLoginOTP,
  forgotPassword,
  resetPassword,
  logout
} from '../controllers/auth.controller.js';
import { verifyFirebaseToken } from '../middleware/firebaseAuthMiddleware.js';

const router = express.Router();

// Public routes
router.post('/verify-token', verifyToken);
router.post('/send-login-otp', sendLoginOTP);
router.post('/verify-login-otp', verifyLoginOTP);
router.post('/forgot-password', forgotPassword);
router.post('/reset-password', resetPassword);
router.post('/logout', logout);

// Protected routes (require Firebase token)
router.get('/check-auth', verifyFirebaseToken, checkAuth);
router.get('/profile', verifyFirebaseToken, getUserProfile);
router.put('/profile', verifyFirebaseToken, updateProfile);

export default router;