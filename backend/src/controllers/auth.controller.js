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

    // Ensure a user profile exists in Firestore. If missing, upsert a minimal profile
    // using information available from Firebase Auth (admin SDK).
    const db = getDb();
    let userProfile = await getUserProfileByUid(uid);

    try {
      // Fetch user record from Firebase Auth admin to obtain displayName/email/photoURL
      let userRecord = null;
      try {
        userRecord = await auth.getUser(uid);
      } catch (e) {
        // If getUser fails, continue and rely on decodedToken / existing profile
        console.warn('[loginWithToken] auth.getUser failed, proceeding with available data', e?.message || e);
      }

      const email = userRecord?.email || decodedToken.email || (userProfile && userProfile.email) || null;
      const fullName = userRecord?.displayName || (userProfile && userProfile.fullName) || null;
      const profilePic = userRecord?.photoURL || (userProfile && userProfile.profilePic) || "";

      const now = new Date().toISOString();

      if (!userProfile) {
        // Create minimal profile
        const minimal = {
          uid,
          email: email || '',
          fullName: fullName || '',
          profilePic: profilePic || '',
          createdAt: now,
          updatedAt: now,
        };
        try {
          await db.collection('users').doc(uid).set(minimal);
          userProfile = minimal;
          console.log('[loginWithToken] created minimal user profile for uid=', uid);
        } catch (e) {
          console.error('[loginWithToken] Failed to create user profile in Firestore:', e?.message || e);
          // Continue: we can still issue token but log the failure
        }
      } else {
        // Update updatedAt and sync any missing fields
        const updateData = { updatedAt: now };
        if (!userProfile.fullName && fullName) updateData.fullName = fullName;
        if (!userProfile.email && email) updateData.email = email;
        if (!userProfile.profilePic && profilePic) updateData.profilePic = profilePic;
        try {
          await db.collection('users').doc(uid).set(updateData, { merge: true });
          userProfile = await getUserProfileByUid(uid);
          console.log('[loginWithToken] updated user profile for uid=', uid);
        } catch (e) {
          console.error('[loginWithToken] Failed to update user profile in Firestore:', e?.message || e);
        }
      }
    } catch (e) {
      console.error('[loginWithToken] unexpected error during profile upsert:', e?.message || e);
    }

    const token = generateToken(uid, res);

    return res.status(200).json(buildUserResponse(userProfile || { uid, email: '', fullName: '', profilePic: '' }, token));
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
    // Accept a wider set of profile fields from the client
    const {
      profilePic,
      fullName,
      username,
      weightKg,
      heightCm,
      goal,
      phone,
      age,
      gender,
      idealWeightKg,
      deadline,
      trainingIntensity,
      dietPlan,
      dailyWaterMl,
      drinkingTimes,
      deadlineCompleted,
    } = req.body || {};

    const userId = req.user.uid;

    const now = new Date().toISOString();
    const updateData = {
      updatedAt: now,
    };

    // copy allowed fields if provided
    if (typeof profilePic === 'string' && profilePic.trim() !== '') updateData.profilePic = profilePic;
    if (typeof fullName === 'string' && fullName.trim() !== '') updateData.fullName = fullName;
    if (typeof username === 'string') updateData.username = username;
    if (weightKg !== undefined) updateData.weightKg = weightKg;
    if (heightCm !== undefined) updateData.heightCm = heightCm;
    if (typeof goal === 'string') updateData.goal = goal;
    if (typeof phone === 'string') updateData.phone = phone;
    if (age !== undefined) updateData.age = age;
    if (typeof gender === 'string') updateData.gender = gender;
    if (idealWeightKg !== undefined) updateData.idealWeightKg = idealWeightKg;
    if (typeof deadline === 'string') updateData.deadline = deadline;
    if (typeof trainingIntensity === 'string') updateData.trainingIntensity = trainingIntensity;
    if (typeof dietPlan === 'string') updateData.dietPlan = dietPlan;
    if (dailyWaterMl !== undefined) updateData.dailyWaterMl = dailyWaterMl;
    if (Array.isArray(drinkingTimes)) updateData.drinkingTimes = drinkingTimes;
    if (deadlineCompleted !== undefined) updateData.deadlineCompleted = deadlineCompleted;

    await firebasePromise;
    const auth = getAuth();
    const db = getDb();

    // Sync displayName and photoURL in Firebase Auth when provided
    try {
      const authUpdate = {};
      if (fullName) authUpdate.displayName = fullName;
      if (profilePic) authUpdate.photoURL = profilePic;
      if (Object.keys(authUpdate).length > 0) {
        await auth.updateUser(userId, authUpdate);
      }
    } catch (e) {
      console.warn('[updateProfile] failed to update Firebase Auth user:', e?.message || e);
      // continue; Firestore update is still the source of truth for profile document
    }

    // Mirror a subset of fields into nested `profile` map for frontend compatibility
    const mirrorKeys = [
      'profilePic',
      'fullName',
      'username',
      'weightKg',
      'heightCm',
      'email',
      'age',
      'gender',
      'dailyWaterMl',
      'drinkingTimes',
      'deadlineCompleted',
    ];

    const profileMap = {};
    for (const k of mirrorKeys) {
      if (Object.prototype.hasOwnProperty.call(updateData, k)) {
        profileMap[k] = updateData[k];
      }
    }

    const finalPayload = { ...updateData };
    if (Object.keys(profileMap).length > 0) {
      finalPayload.profile = profileMap;
    }

    // Persist into Firestore using merge to avoid clobbering other fields
    await db.collection('users').doc(userId).set(finalPayload, { merge: true });

    const updatedUser = await getUserProfileByUid(userId);

    return res.status(200).json({
      uid: updatedUser.uid,
      fullName: updatedUser.fullName,
      email: updatedUser.email,
      profilePic: updatedUser.profilePic || '',
    });
  } catch (error) {
    console.log('Error in update profile controller:', error);
    return res.status(500).json({ message: 'Internal Server Error' });
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
