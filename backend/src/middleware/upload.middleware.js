// src/middleware/upload-middleware.js
import multer from "multer";
import path from "path";
import fs from "fs";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// thư mục tạm ngay cạnh file middleware (hoặc bạn đổi theo ý)
const uploadTempDir = path.join(__dirname, "tmp");
if (!fs.existsSync(uploadTempDir)) {
    fs.mkdirSync(uploadTempDir, { recursive: true });
}

const storage = multer.diskStorage({
    destination(req, file, cb) {
        cb(null, uploadTempDir);
    },
    filename(req, file, cb) {
        const ext = path.extname(file.originalname);
        const uniqueName =
            Date.now() + "-" + Math.round(Math.random() * 1e9) + ext;
        cb(null, uniqueName);
    },
});

const upload = multer({
    storage,
    limits: { fileSize: 5 * 1024 * 1024 },
    fileFilter(req, file, cb) {
        // Accept common image mimetypes and any mimetype that starts with image/
        const allowedExt = ['.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif'];

        // If mimetype exists and clearly indicates image/* accept it
        if (file.mimetype && typeof file.mimetype === 'string' && file.mimetype.startsWith('image/')) {
            return cb(null, true);
        }

        // Some clients (gallery/older devices/emulators) may omit or set an odd mimetype.
        // Fall back to checking the filename extension when available.
        const orig = file.originalname || '';
        const ext = path.extname(orig).toLowerCase();
        if (ext && allowedExt.includes(ext)) {
            return cb(null, true);
        }

        // As a last resort accept common image-like stream when filename has no ext but fieldname suggests file
        // (avoid blindly accepting all uploads). Log details to help debugging client uploads.
        console.warn('upload.middleware: rejected file', { mimetype: file.mimetype, originalname: file.originalname, fieldname: file.fieldname });

        const err = new Error('Only image files are allowed (jpg, png, webp, heic)');
        err.status = 400;
        return cb(err);
    },
});


export default upload;
