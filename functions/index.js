const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const dns = require('node:dns').promises;
const net = require('node:net');

const fetch = (...args) => import('node-fetch').then(({ default: fetchFn }) => fetchFn(...args));

initializeApp();

// Never in Remote Config. Remote Config is delivered to every client, so a key
// kept there is readable by anyone who loads the site — which is how the previous
// key ended up public. Set with:
//   firebase functions:secrets:set GEMINI_API_KEY
const geminiApiKey = defineSecret('GEMINI_API_KEY');

const GEMINI_BASE = 'https://generativelanguage.googleapis.com/v1beta';
const DEFAULT_MODEL = 'gemini-2.5-flash';

// Seeds users/{uid}.aiEnabled on first authorised call. The Firestore flag is the
// source of truth so access can be granted or revoked without a deploy.
const AI_SEED_EMAILS = ['elijahcraig45@gmail.com', 'teemoore00@gmail.com'];

const MAX_PROXY_BYTES = 2 * 1024 * 1024;
const MAX_REDIRECTS = 5;
const COMMON = { region: 'us-central1', timeoutSeconds: 30, memory: '256MiB' };

/**
 * Both AI entry points are gated here rather than in the client.
 *
 * A client-side allowlist is not a control: the check runs on the caller's machine,
 * and until this function existed the API key was in the client anyway. So the key
 * lives in Secret Manager and never leaves the server, and permission is decided
 * from Firestore under the caller's verified uid.
 */
async function assertAiAllowed(request) {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError('unauthenticated', 'Sign in to use this feature.');
  }

  const db = getFirestore();
  const ref = db.collection('users').doc(auth.uid);
  const snap = await ref.get();

  if (snap.exists && snap.data().aiEnabled === true) return;

  // Not yet flagged. Seed from the allowlist so the first call by a named account
  // works without a manual Firestore edit; everyone else is refused.
  const email = (auth.token.email || '').toLowerCase();
  const verified = auth.token.email_verified === true;
  if (verified && AI_SEED_EMAILS.includes(email)) {
    await ref.set({ aiEnabled: true }, { merge: true });
    return;
  }

  throw new HttpsError(
    'permission-denied',
    'AI features are limited to specific accounts on this instance.',
  );
}

/** True for anything that should never be reachable from a server-side fetch. */
function isBlockedAddress(address) {
  if (net.isIPv4(address)) {
    const [a, b] = address.split('.').map(Number);
    if (a === 127 || a === 0 || a === 10) return true;
    if (a === 169 && b === 254) return true;          // link-local, incl. metadata
    if (a === 172 && b >= 16 && b <= 31) return true;
    if (a === 192 && b === 168) return true;
    if (a === 100 && b >= 64 && b <= 127) return true; // carrier NAT
    if (a >= 224) return true;                         // multicast and above
    return false;
  }
  const lower = address.toLowerCase();
  if (lower === '::1' || lower === '::') return true;
  if (lower.startsWith('fe80') || lower.startsWith('fc') || lower.startsWith('fd')) return true;
  // IPv4-mapped IPv6 (::ffff:127.0.0.1) would otherwise slip past the checks above.
  const mapped = lower.match(/^::ffff:(\d+\.\d+\.\d+\.\d+)$/);
  if (mapped) return isBlockedAddress(mapped[1]);
  return false;
}

/**
 * Resolves the host and refuses anything internal.
 *
 * This is checked on every redirect hop, not just the first, because otherwise a
 * public URL that 302s to 169.254.169.254 walks straight through. The wall
 * calendar's browser_service._assert_public() solves the same problem the same way.
 */
async function assertPublicUrl(target) {
  if (target.protocol !== 'http:' && target.protocol !== 'https:') {
    throw new HttpsError('invalid-argument', 'Only http and https URLs are allowed.');
  }
  const host = target.hostname.replace(/^\[|\]$/g, '');
  if (host.endsWith('.internal') || host.endsWith('.local') || host === 'metadata') {
    throw new HttpsError('invalid-argument', 'That host is not allowed.');
  }
  if (net.isIP(host)) {
    if (isBlockedAddress(host)) {
      throw new HttpsError('invalid-argument', 'That address is not allowed.');
    }
    return;
  }
  let records;
  try {
    records = await dns.lookup(host, { all: true });
  } catch (_) {
    throw new HttpsError('invalid-argument', 'That host could not be resolved.');
  }
  // Every resolved address must be public: one internal answer is enough to abuse.
  if (records.some((record) => isBlockedAddress(record.address))) {
    throw new HttpsError('invalid-argument', 'That address is not allowed.');
  }
}

/** Reads at most `limit` bytes, so a huge or endless response can't exhaust memory. */
async function readCapped(response, limit) {
  let total = 0;
  const chunks = [];
  for await (const chunk of response.body) {
    total += chunk.length;
    if (total > limit) {
      throw new HttpsError('resource-exhausted', 'That page is too large to import.');
    }
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString('utf8');
}

/**
 * Fetches a recipe page for the autofill parser.
 *
 * Was an unauthenticated onRequest with Access-Control-Allow-Origin: * that took any
 * URL, followed redirects and returned the body — an open proxy anyone on the internet
 * could point at anything, on this project's bill and from inside Google's network.
 * onCall gives a verified caller identity and handles CORS for the app's own origin.
 */
exports.recipeAutofillProxy = onCall(COMMON, async (request) => {
  await assertAiAllowed(request);

  const rawUrl = request.data?.url;
  if (!rawUrl || typeof rawUrl !== 'string') {
    throw new HttpsError('invalid-argument', 'A url is required.');
  }

  let target;
  try {
    target = new URL(rawUrl);
  } catch (_) {
    throw new HttpsError('invalid-argument', 'That is not a valid URL.');
  }

  for (let hop = 0; hop <= MAX_REDIRECTS; hop += 1) {
    await assertPublicUrl(target);

    const upstream = await fetch(target.toString(), {
      headers: {
        'user-agent': 'recipe-autofill-proxy/2.0',
        accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      },
      // Manual, so each hop is re-checked rather than trusted.
      redirect: 'manual',
      size: 0,
    });

    if ([301, 302, 303, 307, 308].includes(upstream.status)) {
      const location = upstream.headers.get('location');
      if (!location) {
        throw new HttpsError('unavailable', 'That page redirected without a target.');
      }
      target = new URL(location, target);
      continue;
    }

    if (!upstream.ok) {
      throw new HttpsError('unavailable', `That page returned ${upstream.status}.`);
    }
    return { status: upstream.status, body: await readCapped(upstream, MAX_PROXY_BYTES) };
  }

  throw new HttpsError('unavailable', 'That page redirected too many times.');
});

/**
 * The only path to Gemini. The key stays here; the client sends a prompt and gets
 * text back, so there is nothing in the browser worth stealing.
 */
exports.geminiProxy = onCall({ ...COMMON, secrets: [geminiApiKey], timeoutSeconds: 60 },
  async (request) => {
    await assertAiAllowed(request);

    const prompt = request.data?.prompt;
    if (typeof prompt !== 'string' || prompt.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'A prompt is required.');
    }
    if (prompt.length > 60000) {
      throw new HttpsError('invalid-argument', 'That prompt is too long.');
    }

    const model = typeof request.data?.model === 'string' && request.data.model.trim()
      ? request.data.model.trim()
      : DEFAULT_MODEL;

    const upstream = await fetch(
      `${GEMINI_BASE}/models/${encodeURIComponent(model)}:generateContent`,
      {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          // Header rather than ?key=, so the key cannot end up in a URL that gets
          // logged by something along the way.
          'x-goog-api-key': geminiApiKey.value(),
        },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: { temperature: 0.4, topK: 32, topP: 1, maxOutputTokens: 4096 },
        }),
      },
    );

    if (!upstream.ok) {
      // Deliberately not returning the upstream body: it can echo request details,
      // and a quota message is not the caller's business.
      console.error('Gemini upstream error', upstream.status);
      throw new HttpsError('unavailable', 'The AI service could not be reached.');
    }

    const data = await upstream.json();
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? null;
    return { text };
  });
