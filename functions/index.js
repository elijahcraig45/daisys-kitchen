const { onRequest } = require('firebase-functions/v2/https');

const fetch = (...args) => import('node-fetch').then(({ default: fetchFn }) => fetchFn(...args));

exports.recipeAutofillProxy = onRequest(
  {
    cors: true,
    region: 'us-central1',
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (req, res) => {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    const rawUrl = req.query.url || req.body?.url;
    if (!rawUrl || typeof rawUrl !== 'string') {
      res.status(400).json({ error: 'Missing "url" query parameter.' });
      return;
    }

    let target;
    try {
      target = new URL(rawUrl);
    } catch (_) {
      res.status(400).json({ error: 'Invalid url parameter.' });
      return;
    }

    if (target.protocol !== 'http:' && target.protocol !== 'https:') {
      res.status(400).json({ error: 'Only http/https URLs are allowed.' });
      return;
    }

    try {
      const upstream = await fetch(target.toString(), {
        headers: {
          'user-agent': 'recipe-autofill-proxy/1.0',
          accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
        redirect: 'follow',
      });

      const body = await upstream.text();
      res.set('Cache-Control', 'public, max-age=900');
      res.status(upstream.status).send(body);
    } catch (error) {
      console.error('Autofill proxy error', error);
      res.status(502).json({ error: 'Failed to fetch the requested URL.' });
    }
  },
);
