// src/services/aiClient.js
// Helper to call AI service with timeout, retries and robust JSON parsing
import { setTimeout as wait } from 'timers/promises';

const defaultOptions = {
    // Increased default timeout and retries to support longer model inference
    timeout: 30000, // ms (30s)
    retries: 3,
    backoffMs: 500,
};

async function postPredict(url, fileBuffer, opts = {}) {
    const { timeout, retries, backoffMs } = { ...defaultOptions, ...opts };

    let lastErr = null;
    for (let attempt = 0; attempt <= retries; attempt++) {
        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), timeout);

        try {
            const headers = { 'Content-Type': 'application/octet-stream' };
            if (opts.aiApiKey) headers['x-api-key'] = opts.aiApiKey;

            const res = await fetch(url, {
                method: 'POST',
                headers,
                body: fileBuffer,
                signal: controller.signal,
            });
            clearTimeout(timer);

            // read text first to allow better error messages and robust parsing
            const text = await res.text();

            if (!res.ok) {
                const err = new Error(`AI service responded ${res.status}`);
                err.status = res.status;
                err.raw = text;
                throw err;
            }

            try {
                const json = JSON.parse(text || '{}');
                return json;
            } catch (e) {
                const err = new Error('Failed to parse JSON from AI service');
                err.raw = text;
                throw err;
            }
        } catch (err) {
            clearTimeout(timer);
            lastErr = err;

            // If aborted due to timeout, normalize message
            if (err.name === 'AbortError') {
                lastErr = new Error('AI request aborted due to timeout');
            }

            // For last attempt, rethrow; otherwise backoff and retry
            if (attempt === retries) break;
            const backoff = backoffMs * Math.pow(2, attempt);
            await wait(backoff);
        }
    }

    // All attempts failed
    throw lastErr;
}

// GET helper for analyze-from-url style endpoints
async function getAnalyzeFromUrl(url, opts = {}) {
    const { timeout, retries, backoffMs } = { ...defaultOptions, ...opts };

    let lastErr = null;
    for (let attempt = 0; attempt <= retries; attempt++) {
        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), timeout);

        try {
            const headers = { 'Accept': 'application/json' };
            if (opts.aiApiKey) headers['x-api-key'] = opts.aiApiKey;

            const res = await fetch(url, {
                method: 'GET',
                headers,
                signal: controller.signal,
            });
            clearTimeout(timer);

            const text = await res.text();

            if (!res.ok) {
                const err = new Error(`AI service responded ${res.status}`);
                err.status = res.status;
                err.raw = text;
                throw err;
            }

            try {
                const json = JSON.parse(text || '{}');
                return json;
            } catch (e) {
                const err = new Error('Failed to parse JSON from AI service');
                err.raw = text;
                throw err;
            }
        } catch (err) {
            clearTimeout(timer);
            lastErr = err;
            if (err.name === 'AbortError') {
                lastErr = new Error('AI request aborted due to timeout');
            }

            if (attempt === retries) break;
            const backoff = backoffMs * Math.pow(2, attempt);
            await wait(backoff);
        }
    }

    throw lastErr;
}

// expose the new helper alongside postPredict
export default {
    postPredict,
    getAnalyzeFromUrl,
};
