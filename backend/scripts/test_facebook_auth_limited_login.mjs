// Usage:
//   FB_TOKEN='<paste token>' node scripts/test_facebook_auth_limited_login.mjs
//   echo '<paste token>' | node scripts/test_facebook_auth_limited_login.mjs
//
// Prints status + response JSON. Does NOT print the token.

import crypto from 'node:crypto';

const BACKEND_BASE = process.env.BACKEND_BASE_URL || 'http://127.0.0.1:5001';
const REQUEST_ID = process.env.REQUEST_ID || `cli-${Date.now()}`;
const NONCE = process.env.NONCE || 'cli-nonce';

async function readStdin() {
    if (process.stdin.isTTY) return '';
    const chunks = [];
    for await (const c of process.stdin) chunks.push(c);
    return Buffer.concat(chunks).toString('utf8');
}

const stdin = (await readStdin()).trim();
const tokenRaw = (process.env.FB_TOKEN || stdin || '').trim();

if (!tokenRaw) {
    console.error('Missing token. Provide FB_TOKEN env var or pipe token to stdin.');
    process.exit(2);
}

const token = tokenRaw.replace(/^"|"$/g, '').replace(/[\r\n]/g, '').trim();
const tokenSha256 = crypto.createHash('sha256').update(token).digest('hex');

const resp = await fetch(`${BACKEND_BASE}/auth/facebook`, {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Request-Id': REQUEST_ID,
        'X-Client-Token-Sha256': tokenSha256,
    },
    body: JSON.stringify({ accessToken: token, nonce: NONCE }),
});

const text = await resp.text();
let json;
try {
    json = JSON.parse(text);
} catch {
    json = { raw: text };
}

console.log(JSON.stringify({
    requestId: REQUEST_ID,
    backendBaseUrl: BACKEND_BASE,
    status: resp.status,
    tokenSha256,
    body: json,
}, null, 2));
