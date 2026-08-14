const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const crypto = require('node:crypto');
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

// Unambiguous characters only: no O/0, I/1/L, so a code read aloud or off a screen
// cannot be mistyped into someone else's household.
const INVITE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const INVITE_LENGTH = 6;
const INVITE_TTL_DAYS = 14;
const MAX_HOUSEHOLD_MEMBERS = 12;

const MAX_PROXY_BYTES = 2 * 1024 * 1024;
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;

/* Re-hosted recipe images. The extension comes from the served content-type rather than
   the URL, because a recipe photo is routinely served from a path with no extension at
   all — and a URL's extension is a claim, not a fact. */
const IMAGE_TYPES = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/gif': 'gif',
};

/* A bucket created today is <project>.firebasestorage.app; older projects got
   <project>.appspot.com, and FIREBASE_CONFIG.storageBucket can disagree with both when the
   bucket was provisioned after the project. Overridable, and checked for existence at call
   time so a mismatch is a legible error instead of a silent failure. */
const IMAGE_BUCKET =
  process.env.RECIPE_IMAGE_BUCKET || 'recipe-f644f.firebasestorage.app';
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
async function readCappedBuffer(response, limit, tooLarge) {
  let total = 0;
  const chunks = [];
  for await (const chunk of response.body) {
    total += chunk.length;
    if (total > limit) {
      throw new HttpsError('resource-exhausted', tooLarge);
    }
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
}

async function readCapped(response, limit) {
  const buffer = await readCappedBuffer(response, limit, 'That page is too large to import.');
  return buffer.toString('utf8');
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
      // Nothing reads a redirect's body, and this function is invoked repeatedly.
      upstream.body?.resume();
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


/* ---------------------------------------------------------------------------
 * Households
 *
 * Joining is a function rather than a rule for two reasons: a rule permissive enough
 * to let a non-member append themselves to memberUids is permissive enough to let them
 * append themselves to ANY household, and verifying an invite code inside rules means
 * trusting a code the writer supplied. Here the code is looked up server-side and both
 * writes happen together.
 * ------------------------------------------------------------------------- */

function requireDurableAccount(request) {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError('unauthenticated', 'Sign in first.');
  }
  if (auth.token.firebase?.sign_in_provider === 'anonymous') {
    throw new HttpsError(
      'permission-denied',
      'Households need a Google account, so members can be identified.',
    );
  }
  return auth;
}

function newInviteCode() {
  let code = '';
  for (let i = 0; i < INVITE_LENGTH; i += 1) {
    code += INVITE_ALPHABET[Math.floor(Math.random() * INVITE_ALPHABET.length)];
  }
  return code;
}

/** Creates an invite for the caller's household, replacing any code they had. */
exports.createHouseholdInvite = onCall(COMMON, async (request) => {
  const auth = requireDurableAccount(request);
  const db = getFirestore();

  const user = await db.collection('users').doc(auth.uid).get();
  const householdId = user.data()?.householdId;
  if (!householdId) {
    throw new HttpsError('failed-precondition', 'Create a household first.');
  }

  const household = await db.collection('households').doc(householdId).get();
  if (!household.exists || !(household.data().memberUids || []).includes(auth.uid)) {
    throw new HttpsError('permission-denied', 'You are not in that household.');
  }

  // One live code per household: an old one left valid is a way in that nobody
  // remembers handing out.
  const existing = await db.collection('householdInvites')
    .where('householdId', '==', householdId).get();
  await Promise.all(existing.docs.map((d) => d.ref.delete()));

  const code = newInviteCode();
  const expiresAt = new Date(Date.now() + INVITE_TTL_DAYS * 24 * 60 * 60 * 1000);
  await db.collection('householdInvites').doc(code).set({
    householdId,
    createdBy: auth.uid,
    createdAt: FieldValue.serverTimestamp(),
    expiresAt,
  });

  return { code, expiresAt: expiresAt.toISOString() };
});

exports.joinHousehold = onCall(COMMON, async (request) => {
  const auth = requireDurableAccount(request);
  const raw = request.data?.code;
  if (typeof raw !== 'string' || raw.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'Enter an invite code.');
  }
  const code = raw.trim().toUpperCase();

  const db = getFirestore();
  const userRef = db.collection('users').doc(auth.uid);

  const current = await userRef.get();
  if (current.data()?.householdId) {
    // Refused rather than silently moved: belonging to two households is not a state
    // this data model has, and losing access to the first one should be deliberate.
    throw new HttpsError(
      'failed-precondition',
      'You are already in a household. Leave it before joining another.',
    );
  }

  const inviteRef = db.collection('householdInvites').doc(code);

  // A transaction because two people redeeming the last seat at once would otherwise
  // both succeed.
  const householdName = await db.runTransaction(async (tx) => {
    const invite = await tx.get(inviteRef);
    if (!invite.exists) {
      throw new HttpsError('not-found', 'That code is not valid.');
    }
    const { householdId, expiresAt } = invite.data();
    if (expiresAt?.toDate && expiresAt.toDate() < new Date()) {
      throw new HttpsError('deadline-exceeded', 'That code has expired.');
    }

    const householdRef = db.collection('households').doc(householdId);
    const household = await tx.get(householdRef);
    if (!household.exists) {
      throw new HttpsError('not-found', 'That household no longer exists.');
    }
    const members = household.data().memberUids || [];
    if (members.includes(auth.uid)) {
      return household.data().name;
    }
    if (members.length >= MAX_HOUSEHOLD_MEMBERS) {
      throw new HttpsError('resource-exhausted', 'That household is full.');
    }

    tx.update(householdRef, { memberUids: FieldValue.arrayUnion(auth.uid) });
    tx.set(userRef, { householdId }, { merge: true });
    return household.data().name;
  });

  return { householdId: (await userRef.get()).data().householdId, name: householdName };
});

exports.leaveHousehold = onCall(COMMON, async (request) => {
  const auth = requireDurableAccount(request);
  const db = getFirestore();
  const userRef = db.collection('users').doc(auth.uid);

  const user = await userRef.get();
  const householdId = user.data()?.householdId;
  if (!householdId) {
    throw new HttpsError('failed-precondition', 'You are not in a household.');
  }

  await db.runTransaction(async (tx) => {
    const householdRef = db.collection('households').doc(householdId);
    const household = await tx.get(householdRef);
    if (household.exists) {
      tx.update(householdRef, { memberUids: FieldValue.arrayRemove(auth.uid) });
    }
    tx.set(userRef, { householdId: null }, { merge: true });
  });

  // Recipes shared to the household are deliberately left alone. They still belong to
  // whoever wrote them, and silently republishing or deleting someone's recipe because a
  // housemate left would be worse than leaving it where it is.
  return { left: householdId };
});

/** Creates a household with the caller as its only member, and puts them in it. */
exports.createHousehold = onCall(COMMON, async (request) => {
  const auth = requireDurableAccount(request);
  const name = (request.data?.name || '').toString().trim() || 'Our Kitchen';
  if (name.length > 100) {
    throw new HttpsError('invalid-argument', 'That name is too long.');
  }

  const db = getFirestore();
  const userRef = db.collection('users').doc(auth.uid);
  const user = await userRef.get();
  if (user.data()?.householdId) {
    throw new HttpsError('failed-precondition', 'You are already in a household.');
  }

  const householdRef = db.collection('households').doc();
  await db.runTransaction(async (tx) => {
    tx.set(householdRef, {
      name,
      createdBy: auth.uid,
      createdAt: FieldValue.serverTimestamp(),
      memberUids: [auth.uid],
    });
    tx.set(userRef, { householdId: householdRef.id }, { merge: true });
  });

  return { householdId: householdRef.id, name };
});

/* ---------------------------------------------------------------------------
 * Re-hosting recipe images
 * ------------------------------------------------------------------------- */

/**
 * Copies a recipe's image into this project's Storage bucket and records the copy as
 * `cachedImageUrl`.
 *
 * Takes a recipeId and nothing else. The URL it fetches is read out of the recipe
 * document server-side, so this cannot be pointed at an arbitrary address — the mistake
 * recipeAutofillProxy used to make, and the reason that one is now a callable too.
 *
 * `imageUrl` is deliberately left alone. A client holding a recipe loaded before the copy
 * existed would otherwise save its stale external URL back over the new one; instead the
 * app prefers cachedImageUrl and falls back, and firestore.rules refuses client writes to
 * the cached field, exactly as it does for isAdmin and aiEnabled.
 *
 * Access to the copy is by unguessable download token rather than by path: storage.rules
 * denies reads outright, and the token in the URL is what authorises. So a private
 * recipe's photo is no more reachable than the URL it is named in — capability, not
 * secrecy by obscure path.
 */
exports.cacheRecipeImage = onCall({ ...COMMON, timeoutSeconds: 60 }, async (request) => {
  const auth = requireDurableAccount(request);
  const db = getFirestore();

  const recipeId = request.data?.recipeId;
  if (!recipeId || typeof recipeId !== 'string' || recipeId.length > 200) {
    throw new HttpsError('invalid-argument', 'A recipeId is required.');
  }

  const ref = db.collection('recipes').doc(recipeId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'That recipe does not exist.');
  }
  const recipe = snap.data();

  if (recipe.createdBy !== auth.uid) {
    const caller = await db.collection('users').doc(auth.uid).get();
    if (caller.data()?.isAdmin !== true) {
      throw new HttpsError('permission-denied', 'That is not your recipe.');
    }
  }

  // Idempotent: a second call is a no-op rather than a second copy on the bill.
  if (typeof recipe.cachedImageUrl === 'string' && recipe.cachedImageUrl) {
    return { cached: false, url: recipe.cachedImageUrl };
  }

  const source = recipe.imageUrl;
  if (!source || typeof source !== 'string' || !/^https?:\/\//i.test(source)) {
    throw new HttpsError(
      'failed-precondition',
      'That recipe has no external image to copy.',
    );
  }

  let target;
  try {
    target = new URL(source);
  } catch (_) {
    throw new HttpsError('failed-precondition', 'That image URL is not valid.');
  }

  let body;
  let contentType;
  for (let hop = 0; hop <= MAX_REDIRECTS; hop += 1) {
    await assertPublicUrl(target);

    const upstream = await fetch(target.toString(), {
      headers: {
        'user-agent': 'daisys-kitchen-image-cache/1.0',
        accept: 'image/avif,image/webp,image/jpeg,image/png,*/*;q=0.8',
      },
      redirect: 'manual',
      size: 0,
    });

    if ([301, 302, 303, 307, 308].includes(upstream.status)) {
      upstream.body?.resume();
      const location = upstream.headers.get('location');
      if (!location) {
        throw new HttpsError('unavailable', 'That image redirected without a target.');
      }
      target = new URL(location, target);
      continue;
    }

    if (!upstream.ok) {
      throw new HttpsError('unavailable', `That image returned ${upstream.status}.`);
    }

    contentType = (upstream.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
    if (!IMAGE_TYPES[contentType]) {
      upstream.body?.resume();
      throw new HttpsError(
        'failed-precondition',
        `That URL served ${contentType || 'no content type'}, not an image.`,
      );
    }
    body = await readCappedBuffer(upstream, MAX_IMAGE_BYTES, 'That image is too large.');
    break;
  }

  if (!body) {
    throw new HttpsError('unavailable', 'That image redirected too many times.');
  }

  const bucket = getStorage().bucket(IMAGE_BUCKET);
  const [exists] = await bucket.exists();
  if (!exists) {
    // Named, because the usual cause is a bucket whose real name is not the one guessed
    // from the project id, and that is otherwise a very quiet failure.
    throw new HttpsError(
      'failed-precondition',
      `Storage bucket ${IMAGE_BUCKET} does not exist. Create it, or set RECIPE_IMAGE_BUCKET.`,
    );
  }

  const token = crypto.randomUUID();
  const path = `recipeImages/${recipeId}/original.${IMAGE_TYPES[contentType]}`;
  await bucket.file(path).save(body, {
    resumable: false,
    metadata: {
      contentType,
      // The bytes never change under a given path, and a recipe card is read far more
      // often than it is written.
      cacheControl: 'public, max-age=31536000, immutable',
      metadata: { firebaseStorageDownloadTokens: token },
    },
  });

  const url =
    `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
    `${encodeURIComponent(path)}?alt=media&token=${token}`;

  await ref.update({
    cachedImageUrl: url,
    imageCachedAt: FieldValue.serverTimestamp(),
    // Kept so the copy can always be traced back to where it came from.
    imageSourceUrl: source,
  });

  return { cached: true, url, bytes: body.length, contentType };
});
