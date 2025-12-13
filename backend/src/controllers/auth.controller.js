// src/controllers/auth.controller.js
import { firebasePromise, getAuth, getDb } from "../lib/firebase.js";
import fs from "fs";
import fetch from "node-fetch";
import { generateToken } from "../lib/utils.js";
import { FIREBASE_API_KEY } from "../config/env.js";
// Helper: build response user object
const buildUserResponse = (userProfile, token) => ({
  uid: userProfile.uid,
  fullName: userProfile.fullName,
  email: userProfile.email,
  profilePic: userProfile.profilePic || "",
  token,
});

// Helper: lấy user profile từ Firestore
const getUserProfileByUid = async (uid) => {
  await firebasePromise;
  const db = getDb();
  const userDoc = await db.collection("users").doc(uid).get();
  return userDoc.exists ? userDoc.data() : null;
};

// Helper: verify email/password qua REST API của Firebase Auth
const verifyEmailPasswordWithFirebase = async (email, password) => {
  // 🔐 Dùng FIREBASE_API_KEY đã validate sẵn
  const apiKey = FIREBASE_API_KEY;

  const url = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`;

  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      email,
      password,
      returnSecureToken: true,
    }),
  });

  const data = await response.json();

  if (!response.ok) {
    const err = new Error(data.error?.message || "Failed to sign in");
    err.firebaseCode = data.error?.message;
    throw err;
  }

  // data.localId = uid, data.idToken = Firebase ID token
  return data;
};

// ============= SIGNUP =============
export const signup = async (req, res) => {
  let { fullName, email, password } = req.body;

  try {
    console.log('[signup] payload:', { fullName, email: email && email.replace(/(.{3}).+(@.+)/, '$1***$2') });
    if (!email || !password) {
      return res.status(400).json({ message: "Email and password are required" });
    }

    // Nếu không có fullName từ FE, tự tạo 1 tên từ email (ví dụ: first part trước @)
    if (!fullName || String(fullName).trim() === '') {
      try {
        fullName = String(email).split('@')[0].replace(/[\._\d]+/g, ' ').trim();
        if (!fullName) fullName = 'User';
      } catch (e) {
        fullName = 'User';
      }
    }

    if (password.length < 6) {
      return res
        .status(400)
        .json({ message: "Password must be at least 6 characters" });
    }

    // Tạo user trong Firebase Auth
    await firebasePromise;
    const auth = getAuth();
    const db = getDb();

    let userRecord;
    try {
      console.log('[signup] creating auth user for email=', email);
      userRecord = await auth.createUser({
        email,
        password,
        displayName: fullName,
        emailVerified: false,
      });
      console.log('[signup] auth.createUser succeeded', { uid: userRecord.uid });
    } catch (e) {
      const adminCode = e?.code || e?.errorInfo?.code || e?.firebaseCode || e?.message;
      console.error('[signup] Firebase Auth createUser failed:', { adminCode, message: e?.message || e });
      // Map common admin errors to friendly responses
      if (adminCode && (adminCode === 'auth/email-already-exists' || adminCode === 'auth/email_exists')) {
        return res.status(400).json({ message: 'Email already exists' });
      }
      if (adminCode && adminCode === 'auth/invalid-email') {
        return res.status(400).json({ message: 'Invalid email format' });
      }
      // fallback
      return res.status(500).json({ message: 'Failed to create user' });
    }

    // Tạo profile trong Firestore
    const userProfile = {
      uid: userRecord.uid,
      email,
      fullName,
      profilePic: "",
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    try {
      console.log('[signup] writing user profile to Firestore', { uid: userRecord.uid });
      await db.collection("users").doc(userRecord.uid).set(userProfile);
      console.log('[signup] Firestore write succeeded', { uid: userRecord.uid });
    } catch (e) {
      console.error('[signup] Firestore write failed:', e?.message || e);
      // Attempt to cleanup created auth user to avoid orphaned accounts
      try {
        await auth.deleteUser(userRecord.uid);
        console.log('[signup] Rolled back created auth user due to Firestore failure', { uid: userRecord.uid });
      } catch (delErr) {
        console.error('[signup] Failed to rollback auth user:', delErr?.message || delErr);
      }
      return res.status(500).json({ message: 'Failed to create user profile' });
    }

    // Generate JWT token (set cookie)
    let token;
    try {
      token = generateToken(userRecord.uid, res);
    } catch (e) {
      console.error('[signup] Token generation failed:', e?.message || e);
      // Attempt to cleanup created auth user since token issuance failed
      try {
        await auth.deleteUser(userRecord.uid);
        console.log('[signup] Rolled back created auth user due to token failure', { uid: userRecord.uid });
      } catch (delErr) {
        console.error('[signup] Failed to rollback auth user after token failure:', delErr?.message || delErr);
      }
      return res.status(500).json({ message: 'Failed to issue token' });
    }

  console.log('[signup] success', { uid: userRecord.uid });
  return res.status(200).json(buildUserResponse(userProfile, token));
  } catch (error) {
    console.error("Error in signup controller:", error && (error.stack || error));
    console.debug('[signup] caught error details:', {
      name: error?.name,
      message: error?.message,
      code: error?.code || error?.firebaseCode,
    });
    try {
      fs.appendFileSync(
        '/tmp/backend-signup-errors.log',
        `\n---- ${new Date().toISOString()} ----\n${error && (error.stack || JSON.stringify(error))}\n`
      );
    } catch (e) {
      console.error('Failed to write signup error file', e);
    }

    switch (error.code) {
      case "auth/email-already-exists":
        return res.status(400).json({ message: "Email already exists" });
      case "auth/weak-password":
        return res.status(400).json({ message: "Password is too weak" });
      case "auth/invalid-email":
        return res.status(400).json({ message: "Invalid email format" });
      default:
        return res.status(500).json({ message: "Internal Server Error" });
    }
  }
};

// ============= LOGIN BẰNG EMAIL/PASSWORD (SERVER-SIDE) =============
// Nếu bạn muốn login hoàn toàn qua API backend mà không dùng Firebase Client SDK trên FE
export const loginWithEmailPassword = async (req, res) => {
  const { email, password } = req.body;

  try {
    if (!email || !password) {
      return res.status(400).json({ message: "Email and password are required" });
    }

    // Dùng REST API của Firebase Auth để verify email/password
    const data = await verifyEmailPasswordWithFirebase(email, password);
    const uid = data.localId;

    // Lấy user profile từ Firestore
    const userProfile = await getUserProfileByUid(uid);
    if (!userProfile) {
      return res.status(404).json({ message: "User profile not found" });
    }

    // Generate JWT token cho hệ thống
    const token = generateToken(uid, res);

    return res.status(200).json(buildUserResponse(userProfile, token));
  } catch (error) {
    console.error("Error in email/password login:", error && (error.stack || error));
    try {
      fs.appendFileSync('/tmp/backend-auth-errors.log', `\n---- ${new Date().toISOString()} LOGIN-EMAIL ERROR ----\n${error && (error.stack || JSON.stringify(error))}\n`);
    } catch (e) {
      console.error('Failed to write auth error file', e);
    }

    if (error.firebaseCode) {
      switch (error.firebaseCode) {
        case "EMAIL_NOT_FOUND":
          return res.status(404).json({ message: "User not found" });
        case "INVALID_PASSWORD":
          return res.status(401).json({ message: "Invalid password" });
        case "INVALID_EMAIL":
          return res.status(400).json({ message: "Invalid email format" });
        default:
          return res.status(401).json({ message: "Invalid email or password" });
      }
    }

    return res.status(500).json({ message: "Internal server error" });
  }
};

// ============= LOGIN BẰNG FIREBASE ID TOKEN (CLIENT SDK) =============
export const loginWithToken = async (req, res) => {
  try {
    const { idToken } = req.body;

    if (!idToken) {
      return res.status(400).json({ message: "ID token is required" });
    }

    await firebasePromise;
    const auth = getAuth();
    console.log('[loginWithToken] received idToken length=', typeof idToken === 'string' ? idToken.length : 0);
    let decodedToken;
    try {
      decodedToken = await auth.verifyIdToken(idToken);
      console.log('[loginWithToken] verifyIdToken succeeded', { uid: decodedToken.uid });
    } catch (vdErr) {
      console.error('[loginWithToken] verifyIdToken failed:', vdErr?.message || vdErr);
      throw vdErr;
    }
    const uid = decodedToken.uid;

    const userProfile = await getUserProfileByUid(uid);
    if (!userProfile) {
      return res.status(404).json({ message: "User not found" });
    }

    const token = generateToken(uid, res);

    return res.status(200).json(buildUserResponse(userProfile, token));
  } catch (error) {
    console.error("Error in login with token:", error && (error.stack || error));
    try {
      fs.appendFileSync('/tmp/backend-auth-errors.log', `\n---- ${new Date().toISOString()} LOGIN-TOKEN ERROR ----\n${error && (error.stack || JSON.stringify(error))}\n`);
    } catch (e) {
      console.error('Failed to write auth error file', e);
    }

    switch (error.code) {
      case "auth/id-token-expired":
        return res.status(401).json({ message: "Token expired" });
      case "auth/invalid-id-token":
        return res.status(401).json({ message: "Invalid token" });
      default:
        return res.status(401).json({ message: "Invalid token" });
    }
  }
};

// ============= UPDATE PROFILE =============
export const updateProfile = async (req, res) => {
  try {
    const { profilePic, fullName } = req.body;
    const userId = req.user.uid;

    const updateData = {
      updatedAt: new Date().toISOString(),
    };

    // Upload hoặc update avatar
    if (profilePic) {
      updateData.profilePic = profilePic;
    }

    // Update fullname
    await firebasePromise;
    const auth = getAuth();
    const db = getDb();

    if (fullName) {
      updateData.fullName = fullName;
      await auth.updateUser(userId, { displayName: fullName });
    }

    await db.collection("users").doc(userId).update(updateData);

    const updatedUser = await getUserProfileByUid(userId);

    return res.status(200).json({
      uid: updatedUser.uid,
      fullName: updatedUser.fullName,
      email: updatedUser.email,
      profilePic: updatedUser.profilePic || "",
    });
  } catch (error) {
    console.log("Error in update profile controller:", error);
    return res.status(500).json({ message: "Internal Server Error" });
  }
};

// ============= CHECK AUTH (GET /auth/me) =============
export const checkAuth = async (req, res) => {
  try {
    const user = req.user; // đã được set ở protectRoute
    if (!user) {
      return res.status(401).json({ message: "Not authorized" });
    }

    return res.status(200).json(user);
  } catch (error) {
    console.log("Error in check auth:", error);
    return res.status(500).json({ message: "Internal Server Error" });
  }
};

// ============= LOGOUT =============
export const logout = (req, res) => {
  try {
    res.clearCookie("jwt", {
      httpOnly: true,
      sameSite: "strict",
      secure: process.env.NODE_ENV !== "development",
    });

    return res.status(200).json({ message: "Logged out successfully" });
  } catch (error) {
    console.log("Error in logout controller:", error);
    return res.status(500).json({ message: "Internal Server Error" });
  }
};

// ============= FORGOT PASSWORD =============
export const forgotPassword = async (req, res) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ message: "Email is required" });
    }

    await firebasePromise;
    const auth = getAuth();
    const resetLink = await auth.generatePasswordResetLink(email);

    // TODO: gửi email thật sự bằng service (SendGrid, Nodemailer, ...)
    console.log("Password reset link:", resetLink);

    return res.status(200).json({
      message: "Password reset link sent to email",
      resetLink: process.env.NODE_ENV === "development" ? resetLink : undefined,
    });
  } catch (error) {
    console.log("Error in forgot password:", error);

    if (error.code === "auth/user-not-found") {
      return res.status(404).json({ message: "User not found" });
    }

    return res.status(500).json({ message: "Internal server error" });
  }
};

// ============= RESET PASSWORD (REST API) =============
export const resetPassword = async (req, res) => {
  try {
    const { oobCode, newPassword } = req.body;

    if (!oobCode || !newPassword) {
      return res
        .status(400)
        .json({ message: "Reset code and new password are required" });
    }

    // 🔐 Dùng FIREBASE_API_KEY từ config
    const apiKey = FIREBASE_API_KEY;

    const url = `https://identitytoolkit.googleapis.com/v1/accounts:resetPassword?key=${apiKey}`;

    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ oobCode, newPassword }),
    });

    const data = await response.json();

    if (!response.ok) {
      console.log("Reset password error:", data);
      return res.status(400).json({
        message: data.error?.message || "Invalid or expired reset code",
      });
    }

    return res.status(200).json({ message: "Password reset successfully" });
  } catch (error) {
    console.log("Error in reset password:", error);
    return res.status(500).json({ message: "Internal server error" });
  }
};
