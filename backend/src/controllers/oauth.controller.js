// src/controllers/oauth.controller.js
import { firebasePromise, getAuth, getDb } from "../lib/firebase.js";
import { generateToken } from "../lib/utils.js";
import { OAuth2Client } from "google-auth-library";
import { GOOGLE_CLIENT_ID } from "../config/env.js";

const googleClient = new OAuth2Client(GOOGLE_CLIENT_ID);
// Helper: tạo hoặc lấy user theo email
const getOrCreateUserByEmail = async ({
    email,
    name,
    picture,
    provider,
    providerId,
}) => {
    await firebasePromise;
    const db = getDb();
    const auth = getAuth();

    // Tìm trong Firestore trước
    const usersSnapshot = await db
        .collection("users")
        .where("email", "==", email)
        .limit(1)
        .get();

    if (!usersSnapshot.empty) {
        const user = usersSnapshot.docs[0].data();
        return user;
    }

    // Nếu chưa có, thử tạo user trong Firebase Auth.
    // Nhưng nếu email đã tồn tại trong Firebase Auth (ví dụ đăng nhập bằng Google
    // khi người dùng đã đăng ký bằng email), thì lấy user hiện có và đảm bảo
    // hồ sơ Firestore tồn tại. Điều này cho phép luồng Google sign-in chấp nhận
    // email trùng lặp mà không báo lỗi "Email already exists".
    try {
        const userRecord = await auth.createUser({
            email,
            displayName: name,
            emailVerified: true,
            photoURL: picture || undefined,
        });

        const userProfile = {
            uid: userRecord.uid,
            email,
            fullName: name,
            profilePic: picture || "",
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
            // Lưu thêm provider info cho rõ ràng
            provider,
            providerId,
        };

        await db.collection("users").doc(userRecord.uid).set(userProfile);

        return userProfile;
    } catch (err) {
        // Nếu lỗi là email đã tồn tại trong Firebase Auth, lấy user đó thay vì
        // trả về lỗi. Những lỗi khác thì ném tiếp.
        if (err && (err.code === 'auth/email-already-exists' || (err.message && err.message.includes('email-already-exists')))) {
            console.log('getOrCreateUserByEmail: email exists in Auth, fetching existing user by email=', email);
            // Lấy thông tin user từ Firebase Auth
            const existing = await auth.getUserByEmail(email);

            // Kiểm tra xem có document Firestore cho uid này chưa
            const userDoc = await db.collection('users').doc(existing.uid).get();
            if (userDoc.exists) {
                return userDoc.data();
            }

            // Nếu chưa có profile trong Firestore, tạo profile từ userRecord
            const createdAt = existing.metadata && existing.metadata.creationTime ? new Date(existing.metadata.creationTime).toISOString() : new Date().toISOString();
            const userProfile = {
                uid: existing.uid,
                email: existing.email,
                fullName: existing.displayName || name || '',
                profilePic: existing.photoURL || picture || '',
                createdAt,
                updatedAt: new Date().toISOString(),
                provider,
                providerId,
            };

            await db.collection('users').doc(existing.uid).set(userProfile);
            return userProfile;
        }

        throw err;
    }
};

// Helper: build response
const buildOAuthResponse = (user, token) => ({
    uid: user.uid,
    fullName: user.fullName,
    email: user.email,
    profilePic: user.profilePic || "",
    token,
});

// ============= FACEBOOK AUTH =============
export const facebookAuth = async (req, res) => {
    try {
        const { accessToken } = req.body;

        if (!accessToken) {
            return res.status(400).json({ message: "Access token is required" });
        }

        const facebookResponse = await fetch(
            `https://graph.facebook.com/v18.0/me?fields=id,name,email,picture&access_token=${accessToken}`
        );

        const facebookData = await facebookResponse.json();

        if (!facebookResponse.ok) {
            console.log("Facebook token error:", facebookData);
            return res.status(401).json({ message: "Invalid Facebook token" });
        }

        const { id: facebookId, name, email, picture } = facebookData;

        if (!email) {
            // Có trường hợp Facebook không trả email (privacy setting)
            return res.status(400).json({
                message: "Facebook account does not have a public email",
            });
        }

        const profilePicUrl = picture?.data?.url || "";

        const user = await getOrCreateUserByEmail({
            email,
            name,
            picture: profilePicUrl,
            provider: "facebook",
            providerId: facebookId,
        });

        const token = generateToken(user.uid, res);

        return res.status(200).json(buildOAuthResponse(user, token));
    } catch (error) {
        console.log("Error in Facebook auth:", error);

        if (error.code === "auth/email-already-exists") {
            return res.status(400).json({ message: "Email already exists" });
        }

        return res.status(500).json({ message: "Internal server error" });
    }
};

// ============= GOOGLE AUTH =============
export const googleAuth = async (req, res) => {
    try {
        const { idToken } = req.body;

        if (!idToken) {
            return res.status(400).json({ message: "Google ID token is required" });
        }

        console.log('googleAuth: received idToken length=', idToken ? idToken.length : 0);

        // Support a single GOOGLE_CLIENT_ID or multiple comma-separated client IDs
        // (useful when accepting tokens from iOS and web clients).
        const rawAud = process.env.GOOGLE_CLIENT_ID || '';
        const allowedAudiences = rawAud.split(',').map(a => a.trim()).filter(Boolean);
        console.log('googleAuth: allowedAudiences=', allowedAudiences);

        const ticket = await googleClient.verifyIdToken({
            idToken,
            audience: allowedAudiences.length > 0 ? allowedAudiences : undefined,
        });

        const googleUser = ticket.getPayload();

        console.log('googleAuth: verifyIdToken payload=', googleUser);

        if (!googleUser) {
            return res.status(401).json({ message: "Invalid Google token" });
        }

        const { sub: googleId, name, email, picture } = googleUser;

        if (!email) {
            return res.status(400).json({
                message: "Google account does not have an email",
            });
        }

        const user = await getOrCreateUserByEmail({
            email,
            name,
            picture,
            provider: "google",
            providerId: googleId,
        });

        const token = generateToken(user.uid, res);

        return res.status(200).json(buildOAuthResponse(user, token));
    } catch (error) {
        console.error("Error in Google auth:", error?.stack || error);

        if (error.code === "auth/email-already-exists") {
            return res.status(400).json({ message: "Email already exists" });
        }

        // In development return the real error to help debugging
        if (process.env.NODE_ENV !== 'production') {
            return res.status(500).json({ message: error.message || 'Internal server error', stack: error.stack });
        }

        return res.status(500).json({ message: "Internal server error" });
    }
};
