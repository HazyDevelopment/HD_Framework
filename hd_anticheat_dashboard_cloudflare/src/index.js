import { Hono } from 'hono';
import authRoutes from './routes/auth.js';
import configRoutes from './routes/config.js';
import webhookRoutes from './routes/webhook.js';
import bansRoutes from './routes/bans.js';
import uploadsRoutes from './routes/uploads.js';
import adminRoutes from './routes/admin.js';
import meRoutes from './routes/me.js';

const app = new Hono();

app.route('/api/auth', authRoutes);
app.route('/api', configRoutes);
app.route('/api', webhookRoutes);
app.route('/api', bansRoutes);
app.route('/api', meRoutes);
app.route('/api/uploads', uploadsRoutes);
app.route('/api/admin', adminRoutes);

// Serves ban-evidence screenshots out of R2 — this is this build's
// replacement for the Node version's `express.static('/uploads', ...)`
// serving a local disk folder; there's no local disk here at all.
app.get('/uploads/*', async (c) => {
    const key = c.req.path.replace(/^\/uploads\//, '');
    const obj = await c.env.SCREENSHOTS.get(key);
    if (!obj) return c.notFound();
    return new Response(obj.body, {
        headers: {
            'Content-Type': obj.httpMetadata?.contentType || 'image/jpeg',
            'Cache-Control': 'public, max-age=31536000, immutable',
        },
    });
});

// Everything else (/, /dashboard.html, /css/*, /js/*, /favicon.*) falls
// through to the static frontend in public/, served via the ASSETS
// binding (see wrangler.toml's [assets] block, run_worker_first = true
// is what guarantees every request reaches this file before falling
// back to a static file).
app.get('*', (c) => c.env.ASSETS.fetch(c.req.raw));

export default app;
