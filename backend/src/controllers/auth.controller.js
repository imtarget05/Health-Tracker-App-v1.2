// src/controllers/auth.controller.js
import { auth, db } from "../lib/firebase.js";
import { generateToken } from "../lib/utils.js";

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
  const userDoc = await db.collection("users").doc(uid).get();
  return userDoc.exists ? userDoc.data() : null;
};

// Helper: verify email/password qua REST API của Firebase Auth
const verifyEmailPasswordWithFirebase = async (email, password) => {
  const apiKey = process.env.FIREBASE_API_KEY;
  if (!apiKey) {
    throw new Error("FIREBASE_API_KEY is not configured");
  }

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
    // data.error?.message có các mã như INVALID_PASSWORD, EMAIL_NOT_FOUND, ...
    const err = new Error(data.error?.message || "Failed to sign in");
    err.firebaseCode = data.error?.message;
    throw err;
  }

  // data.localId = uid, data.idToken = Firebase ID token
  return data;
};

// ============= SIGNUP =============
export const signup = async (req, res) => {
  const { fullName, email, password } = req.body;

  try {
    if (!fullName || !email || !password) {
      return res.status(400).json({ message: "All fields are required" });
    }

    if (password.length < 6) {
      return res
        .status(400)
        .json({ message: "Password must be at least 6 characters" });
    }

    // Tạo user trong Firebase Auth
    const userRecord = await auth.createUser({
      email,
      password,
      displayName: fullName,
      emailVerified: false,
    });

    // Tạo profile trong Firestore
    const userProfile = {
      uid: userRecord.uid,
      email,
      fullName,
      profilePic: "",
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    await db.collection("users").doc(userRecord.uid).set(userProfile);

    // Generate JWT token (set cookie)
    const token = generateToken(userRecord.uid, res);

    return res.status(201).json(buildUserResponse(userProfile, token));
  } catch (error) {
    console.log("Error in signup controller:", error);

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
    console.log("Error in email/password login:", error);

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

    const decodedToken = await auth.verifyIdToken(idToken);
    const uid = decodedToken.uid;

    const userProfile = await getUserProfileByUid(uid);
    if (!userProfile) {
      return res.status(404).json({ message: "User not found" });
    }

    const token = generateToken(uid, res);

    return res.status(200).json(buildUserResponse(userProfile, token));
  } catch (error) {
    console.log("Error in login with token:", error);

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

    const apiKey = process.env.FIREBASE_API_KEY;
    if (!apiKey) {
      return res.status(500).json({ message: "FIREBASE_API_KEY not configured" });
    }

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
