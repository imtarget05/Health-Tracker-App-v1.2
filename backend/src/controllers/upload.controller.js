import { bucket, firebasePromise } from "../lib/firebase.js";
import fs from "fs";

export const uploadFileController = async (req, res) => {
    try {
        await firebasePromise;

        if (!req.file) {
            return res.status(400).json({ message: "No file uploaded" });
        }

        const tempPath = req.file.path;
        const destination = `uploads/${req.file.filename}`;

        await bucket.upload(tempPath, {
            destination,
            metadata: { contentType: req.file.mimetype },
        });

        // Link ảnh public
        const fileUrl = `https://storage.googleapis.com/${bucket.name}/${destination}`;

        // Xóa file tạm
        fs.unlink(tempPath, (err) => {
            if (err) console.log("Temp file deletion error:", err);
        });

        return res.json({ fileUrl });
    } catch (err) {
        console.error("Upload error:", err);
        res.status(500).json({ message: "Upload failed" });
    }
};
