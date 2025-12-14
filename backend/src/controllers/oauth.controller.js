// src/controllers/oauth.controller.js
import { firebasePromise, getAuth, getDb } from "../lib/firebase.js";
import { generateToken } from "../lib/utils.js";
import { OAuth2Client } from "google-auth-library";
import { GOOGLE_CLIENT_ID, FACEBOOK_APP_ID, FACEBOOK_APP_SECRET } from "../config/env.js";

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
    console.log('getOrCreateUserByEmail: found existing firestore user for email=', email, 'uid=', user.uid || '<no-uid-field>');
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

        try {
            await db.collection("users").doc(userRecord.uid).set(userProfile);
            console.log('getOrCreateUserByEmail: created firestore user doc uid=', userRecord.uid);
        } catch (setErr) {
            console.error('getOrCreateUserByEmail: failed to write firestore user doc for uid=', userRecord.uid, setErr?.message || setErr);
            // Re-throw so caller can handle/log
            throw setErr;
        }

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
            try {
                await db.collection('users').doc(existing.uid).set(userProfile);
                console.log('getOrCreateUserByEmail: created firestore user doc for existing auth user uid=', existing.uid);
            } catch (setErr) {
                console.error('getOrCreateUserByEmail: failed to write firestore user doc for existing uid=', existing.uid, setErr?.message || setErr);
                throw setErr;
            }
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

        // Mask token for logs: keep first 8 and last 8 chars only
        const maskToken = (t) => {
            if (!t || t.length <= 32) return t ? `${t.slice(0, 8)}...${t.slice(-8)}` : t;
            return `${t.slice(0, 8)}...${t.slice(-8)}`;
        };

        console.log('facebookAuth: received accessToken=', maskToken(accessToken));
        try {
            const prefix = accessToken && accessToken.length >= 3 ? accessToken.slice(0, 3) : accessToken || '';
            console.log('facebookAuth: token_prefix=', prefix, 'len=', accessToken ? accessToken.length : 0);
            console.log('facebookAuth: token_looks_like_EAA=', typeof accessToken === 'string' && accessToken.startsWith('EAA'));
        } catch (e) {
            console.log('facebookAuth: token diagnostics failed', e?.message || e);
        }
        try {
            console.log('facebookAuth: token_check startsWithEAA=', typeof accessToken === 'string' && accessToken.startsWith('EAA'), 'length=', accessToken ? accessToken.length : 0);
        } catch (tkErr) {
            console.log('facebookAuth: token_check error', tkErr?.message || tkErr);
        }

        // If the token looks like a JWT (starts with eyJ) it's likely an id_token from
        // another provider (or mis-used). In production reject such tokens outright.
        const looksLikeJwt = typeof accessToken === 'string' && accessToken.startsWith('eyJ');

        if (looksLikeJwt) {
            console.log('facebookAuth: received token that looks like a JWT/id_token');
            if (process.env.NODE_ENV === 'production') {
                // In production, never accept JWTs here.
                return res.status(400).json({ message: 'Server requires a Facebook user access token (not an id_token)' });
            }

            // In non-production, keep the old behavior but make it explicit and guarded.
            try {
                const parts = accessToken.split('.');
                if (parts.length >= 2) {
                    const payloadB64 = parts[1];
                    const padded = payloadB64.padEnd(payloadB64.length + (4 - (payloadB64.length % 4)) % 4, '=');
                    const buf = Buffer.from(padded.replace(/-/g, '+').replace(/_/g, '/'), 'base64');
                    const decoded = JSON.parse(buf.toString('utf8'));
                    console.log('facebookAuth: decoded_jwt_payload_keys=', Object.keys(decoded));

                    // In development accept JWT payload if it contains an email or sub
                    const maybeEmail = decoded.email || decoded.preferred_username || decoded.upn || null;
                    const maybeName = decoded.name || decoded.given_name || decoded.family_name || null;
                    const maybeSub = decoded.sub || decoded.user_id || decoded.uid || null;

                    if (!maybeEmail && !maybeSub) {
                        console.log('facebookAuth: jwt payload missing email/sub, rejecting');
                        return res.status(400).json({ message: 'JWT id_token missing email/sub' });
                    }

                    const email = maybeEmail || `${maybeSub}@facebook.invalid`;
                    const name = maybeName || '';
                    const providerId = maybeSub;

                    const user = await getOrCreateUserByEmail({
                        email,
                        name,
                        picture: '',
                        provider: 'facebook',
                        providerId,
                    });

                    const token = generateToken(user.uid, res);
                    return res.status(200).json(buildOAuthResponse(user, token));
                }
            } catch (err) {
                console.log('facebookAuth: failed to decode jwt payload', err?.message || err);
                return res.status(400).json({ message: 'Invalid JWT id_token' });
            }
        }

        // If we have app credentials, call debug_token to inspect token validity and app_id
        if (FACEBOOK_APP_ID && FACEBOOK_APP_SECRET) {
            try {
                const appAccess = `${FACEBOOK_APP_ID}|${FACEBOOK_APP_SECRET}`;
                const debugResp = await fetch(
                    `https://graph.facebook.com/debug_token?input_token=${accessToken}&access_token=${appAccess}`
                );
                const debugJson = await debugResp.json();

                if (!debugResp.ok) {
                    console.log('facebookAuth: debug_token returned non-OK:', debugJson);
                    return res.status(401).json({ message: 'Invalid Facebook access token (debug_token failed)' });
                }

                const d = debugJson.data || debugJson;
                console.log('facebookAuth: debug_token: is_valid=', d.is_valid, 'app_id=', d.app_id, 'type=', d.type, 'expires_at=', d.expires_at);

                // Ensure token is valid
                if (!d.is_valid) {
                    return res.status(401).json({ message: 'Facebook access token is not valid' });
                }

                // Ensure the token is for this app
                if (d.app_id && String(d.app_id) !== String(FACEBOOK_APP_ID)) {
                    console.log('facebookAuth: debug_token app_id mismatch, expected=', FACEBOOK_APP_ID, 'got=', d.app_id);
                    return res.status(401).json({ message: 'Facebook access token was not issued for this app' });
                }

                // Optionally ensure token type is USER
                if (d.type && d.type.toLowerCase() !== 'user') {
                    console.log('facebookAuth: debug_token type not user:', d.type);
                    // We don't strictly fail for other types here, but log for diagnostics
                }
            } catch (dbgErr) {
                console.log('facebookAuth: debug_token request failed:', dbgErr?.message || dbgErr);
                return res.status(500).json({ message: 'Failed to validate Facebook token' });
            }
        } else {
            console.log('facebookAuth: FACEBOOK_APP_ID/SECRET not set in env; skipping debug_token call');
            // In production we should have these values; if missing, reject in prod
            if (process.env.NODE_ENV === 'production') {
                return res.status(500).json({ message: 'Server misconfigured: FACEBOOK_APP_ID/SECRET missing' });
            }
        }

        console.log('facebookAuth: calling graph.me for token.');
        const facebookResponse = await fetch(
            `https://graph.facebook.com/v18.0/me?fields=id,name,email,picture&access_token=${accessToken}`
        );

        const facebookData = await facebookResponse.json();

        console.log('facebookAuth: facebookData keys=', Object.keys(facebookData));
        try {
            console.log('facebookAuth: facebookData sample=', {
                id: facebookData.id,
                email: facebookData.email,
                name: facebookData.name,
                picture: facebookData.picture && facebookData.picture.data && facebookData.picture.data.url ? '<has-picture>' : '<no-picture>'
            });
        } catch (_) {}

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

        let user;
        try {
            user = await getOrCreateUserByEmail({
            email,
            name,
            picture: profilePicUrl,
            provider: "facebook",
            providerId: facebookId,
            });
            console.log('facebookAuth: getOrCreateUserByEmail returned user uid=', user && user.uid ? user.uid : '<no-uid>');
        } catch (userErr) {
            console.error('facebookAuth: error creating/getting user by email=', email, userErr?.message || userErr);
            return res.status(500).json({ message: 'Failed to create or fetch user profile' });
        }

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

// Development helper: debug token endpoint
export const facebookDebug = async (req, res) => {
    try {
        const { input_token } = req.body;

        if (!input_token) {
            return res.status(400).json({ message: 'input_token is required in body' });
        }

        if (!FACEBOOK_APP_ID || !FACEBOOK_APP_SECRET) {
            return res.status(500).json({ message: 'FACEBOOK_APP_ID/APP_SECRET not configured on server' });
        }

        try {
            console.log('facebookDebug: input_token looksLikeEAA=', typeof input_token === 'string' && input_token.startsWith('EAA'), 'length=', input_token ? input_token.length : 0);
        } catch (e) {
            console.log('facebookDebug: token check error', e?.message || e);
        }

        const appAccess = `${FACEBOOK_APP_ID}|${FACEBOOK_APP_SECRET}`;
        const debugResp = await fetch(
            `https://graph.facebook.com/debug_token?input_token=${input_token}&access_token=${appAccess}`
        );

        const debugJson = await debugResp.json();

        // Return the debug info but avoid leaking app secret; it's safe to return debugJson
        return res.status(debugResp.ok ? 200 : 400).json({ debug: debugJson });
    } catch (err) {
        console.log('facebookDebug: error', err);
        return res.status(500).json({ message: 'Internal server error' });
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

// Dev-only helper: create or get a user profile directly to validate Firestore writes.
export const createTestUser = async (req, res) => {
    try {
        const { email, name } = req.body;
        if (!email) return res.status(400).json({ message: 'email is required' });

        const user = await getOrCreateUserByEmail({
            email,
            name: name || email.split('@')[0],
            picture: '',
            provider: 'test',
            providerId: `test-${Date.now()}`,
        });

        return res.status(200).json({ ok: true, user });
    } catch (err) {
        console.error('createTestUser: error', err?.message || err);
        return res.status(500).json({ message: 'Failed to create test user', error: err?.message || String(err) });
    }
};
