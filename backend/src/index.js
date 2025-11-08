import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import cookieParser from 'cookie-parser';
import admin from 'firebase-admin';
import { createRequire } from 'module';

const require = createRequire(import.meta.url);
// ✅ Load JSON kiểu CommonJS
const serviceAccount = require('../service-account.json');

const app = express();

// middlewares...
app.use(express.json());
app.use(cookieParser());
const ALLOWED_ORIGINS = ['http://localhost:10182', 'http://127.0.0.1:10182', 'http://healthy-tracker:8001'];
app.use(cors({
  origin: (origin, cb) => {
    if (!origin || ALLOWED_ORIGINS.includes(origin)) return cb(null, true);
    return cb(new Error(`CORS: Origin ${origin} not allowed`), false);
  },
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// ✅ Firebase Admin init bằng serviceAccount đã load
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

// routes...
app.get('/api/health', (req, res) => res.json({ ok: true, ts: Date.now() }));

app.post('/api/auth/verify-token', async (req, res) => {
  try {
    const auth = req.headers.authorization || '';
    if (!auth.startsWith('Bearer ')) {
      return res.status(401).json({ ok: false, error: 'Missing bearer token' });
    }
    const idToken = auth.slice(7);
    const decoded = await admin.auth().verifyIdToken(idToken);
    return res.json({
      ok: true,
      uid: decoded.uid,
      email: decoded.email,
      email_verified: decoded.email_verified,
      iss: decoded.iss,
      aud: decoded.aud,
    });
  } catch (e) {
    console.error('verify-token error:', e);
    return res.status(401).json({ ok: false, error: 'Invalid token' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`API listening on http://localhost:${PORT}`));
