// Firebase-based Auth Controllers
import admin, { adminAuth, db } from '../lib/firebase.js';
import { sendOTPEmail, generateOTP } from '../utils/emailService.js';

// Helper to check Firebase initialization
const checkFirebase = (res) => {
  if (!adminAuth || !db) {
    res.status(503).json({
      success: false,
      message: 'Firebase Admin not configured. Please check your .env file.'
    });
    return false;
  }
  return true;
};

// ✅ Verify Firebase token và trả về user data
export const verifyToken = async (req, res) => {
  if (!checkFirebase(res)) return;

  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'No token provided'
      });
    }

    const idToken = authHeader.substring(7);
    const decodedToken = await adminAuth.verifyIdToken(idToken);

    // Get user from Firestore
    const userDoc = await db.collection('users').doc(decodedToken.uid).get();

    if (!userDoc.exists) {
      // Create user document automatically
      await db.collection('users').doc(decodedToken.uid).set({
        uid: decodedToken.uid,
        email: decodedToken.email || '',
        displayName: decodedToken.name || '',
        photoURL: decodedToken.picture || '',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return res.json({
        success: true,
        user: {
          uid: decodedToken.uid,
          email: decodedToken.email,
          displayName: decodedToken.name,
          photoURL: decodedToken.picture,
        }
      });
    }

    res.json({
      success: true,
      user: {
        uid: userDoc.data().uid,
        ...userDoc.data(),
      }
    });
  } catch (error) {
    console.error('Verify token error:', error.message);
    res.status(401).json({
      success: false,
      message: 'Invalid token'
    });
  }
};

// ✅ Get user profile
export const getUserProfile = async (req, res) => {
  if (!checkFirebase(res)) return;

  try {
    const uid = req.firebaseUser.uid;
    const userDoc = await db.collection('users').doc(uid).get();

    if (!userDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    res.json({
      success: true,
      user: {
        uid: userDoc.data().uid,
        ...userDoc.data(),
      }
    });
  } catch (error) {
    console.error('Get user profile error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

// ✅ Update user profile
export const updateProfile = async (req, res) => {
  if (!checkFirebase(res)) return;

  try {
    const uid = req.firebaseUser.uid;
    const { displayName, photoURL, profilePic } = req.body;

    const updateData = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (displayName) updateData.displayName = displayName;
    if (photoURL) updateData.photoURL = photoURL;
    if (profilePic) updateData.profilePic = profilePic;

    await db.collection('users').doc(uid).update(updateData);

    const updatedUser = await db.collection('users').doc(uid).get();

    res.json({
      success: true,
      user: {
        uid: updatedUser.data().uid,
        ...updatedUser.data(),
      }
    });
  } catch (error) {
    console.error('Update profile error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};

// ✅ Gửi OTP cho login (lưu vào Firestore)
export const sendLoginOTP = async (req, res) => {
  if (!checkFirebase(res)) return;

  try {
    const { email } = req.body;

    // Check if user exists in Firebase Auth
    let userRecord;
    try {
      userRecord = await adminAuth.getUserByEmail(email);
    } catch (error) {
      return res.status(404).json({
        success: false,
        message: 'Email không tồn tại'
      });
    }

    const otp = generateOTP();
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 phút

    // Lưu OTP vào Firestore
    await db.collection('otps').add({
      email,
      otp,
      type: 'login',
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Gửi email OTP
    await sendOTPEmail(email, otp, 'login');

    res.json({
      success: true,
      message: 'Mã OTP đã được gửi đến email của bạn'
    });
  } catch (error) {
    console.error('Send login OTP error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Lỗi hệ thống'
    });
  }
};

// ✅ Xác thực OTP login
export const verifyLoginOTP = async (req, res) => {
  if (!checkFirebase(res)) return;

  try {
    const { email, otp } = req.body;

    const now = admin.firestore.Timestamp.now();
    const otpsSnapshot = await db.collection('otps')
      .where('email', '==', email)
      .where('otp', '==', otp)
      .where('type', '==', 'login')
      .where('expiresAt', '>', now)
      .limit(1)
      .get();

    if (otpsSnapshot.empty) {
      return res.status(400).json({
        success: false,
        message: 'Mã OTP không hợp lệ hoặc đã hết hạn'
      });
    }

    // Xóa OTP đã sử dụng
    const otpDoc = otpsSnapshot.docs[0];
    await otpDoc.ref.delete();

    // Get user from Firebase Auth
    const userRecord = await adminAuth.getUserByEmail(email);

    // Get user data from Firestore
    const userDoc = await db.collection('users').doc(userRecord.uid).get();

    if (!userDoc.exists) {
      // Create user document if not exists
      await db.collection('users').doc(userRecord.uid).set({
        uid: userRecord.uid,
        email: userRecord.email || '',
        displayName: userRecord.displayName || '',
        photoURL: userRecord.photoURL || '',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    res.json({
      success: true,
      message: 'Đăng nhập thành công',
      user: {
        uid: userRecord.uid,
        email: userRecord.email,
        displayName: userRecord.displayName,
        photoURL: userRecord.photoURL,
      }
    });
  } catch (error) {
    console.error('Verify login OTP error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Lỗi hệ thống'
    });
  }
};

// ✅ Quên mật khẩu
export const forgotPassword = async (req, res) => {
  if (!checkFirebase(res)) return;

  try {
    const { email } = req.body;

    try {
      await adminAuth.getUserByEmail(email);
    } catch (error) {
      return res.status(404).json({
        success: false,
        message: 'Email không tồn tại'
      });
    }

    const otp = generateOTP();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 phút

    await db.collection('otps').add({
      email,
      otp,
      type: 'reset_password',
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await sendOTPEmail(email, otp, 'reset_password');

    res.json({
      success: true,
      message: 'Mã OTP reset mật khẩu đã được gửi'
    });
  } catch (error) {
    console.error('Forgot password error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Lỗi hệ thống'
    });
  }
};

// ✅ Reset password với OTP (tạo link reset password)
export const resetPassword = async (req, res) => {
  if (!checkFirebase(res)) return;

  try {
    const { email, otp } = req.body;

    const now = admin.firestore.Timestamp.now();
    const otpsSnapshot = await db.collection('otps')
      .where('email', '==', email)
      .where('otp', '==', otp)
      .where('type', '==', 'reset_password')
      .where('expiresAt', '>', now)
      .limit(1)
      .get();

    if (otpsSnapshot.empty) {
      return res.status(400).json({
        success: false,
        message: 'Mã OTP không hợp lệ'
      });
    }

    // Xóa OTP đã sử dụng
    const otpDoc = otpsSnapshot.docs[0];
    await otpDoc.ref.delete();

    // Generate password reset link
    const userRecord = await adminAuth.getUserByEmail(email);
    const resetLink = await adminAuth.generatePasswordResetLink(email);

    res.json({
      success: true,
      message: 'Đặt lại mật khẩu thành công',
      resetLink: resetLink // Frontend sẽ redirect user đến link này
    });
  } catch (error) {
    console.error('Reset password error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Lỗi hệ thống'
    });
  }
};

// ✅ Logout (client-side only, Firebase handles this)
export const logout = (req, res) => {
  res.json({
    success: true,
    message: 'Logged out successfully'
  });
};

// ✅ Check auth status
export const checkAuth = async (req, res) => {
  if (!checkFirebase(res)) return;

  try {
    const uid = req.firebaseUser.uid;
    const userDoc = await db.collection('users').doc(uid).get();

    if (!userDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    res.json({
      success: true,
      user: {
        uid: userDoc.data().uid,
        ...userDoc.data(),
      }
    });
  } catch (error) {
    console.error('Check auth error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
};
