// Builds and sends the ban embed a buyer configured a Discord webhook
// for. Kept server-side (never done from the FXServer/Lua side) so the
// webhook URL itself only ever has to live in this database — a buyer
// rotating it is one dashboard save, not a redeploy of their game
// server.

const KIND_LABELS = {
    speedHack: 'Speed Hack',
    teleportHack: 'Teleport Hack',
    invincibility: 'Invincibility',
    injection: 'Injection / Mod Menu',
    manual: 'Manual Ban',
};

function buildEmbeds(ban, webhookCfg, screenshotUrls) {
    const fields = [];
    if (ban.reason) fields.push({ name: 'Reason', value: ban.reason.slice(0, 1024) });

    if (webhookCfg.include_cfx && (ban.cfx_name || ban.cfx_id)) {
        fields.push({
            name: 'Cfx.re Account',
            value: [ban.cfx_name, ban.cfx_id ? `ID: ${ban.cfx_id}` : null].filter(Boolean).join('\n') || 'Unknown',
            inline: true,
        });
    }
    if (webhookCfg.include_steam) {
        fields.push({ name: 'Steam ID', value: ban.steam_id || 'Steam not running', inline: true });
    }
    if (webhookCfg.include_discord) {
        fields.push({
            name: 'Discord',
            value: ban.discord_name ? `${ban.discord_name} (${ban.discord_id})` : (ban.discord_id ? `ID: ${ban.discord_id}` : 'Discord not running'),
            inline: true,
        });
    }

    // Shared across every embed in this message on purpose (not a real
    // page) — Discord visually groups embeds into one gallery only when
    // their `url` fields match, which is the only lever the embed API
    // gives you for a multi-image post.
    const groupAnchor = `https://hd-anticheat.invalid/bans/${ban.id || Date.now()}`;

    const main = {
        title: `Player Banned — ${KIND_LABELS[ban.kind] || ban.kind || 'Unknown'}`,
        url: groupAnchor,
        description: `**${ban.player_name || 'Unknown player'}**`,
        color: webhookCfg.embed_color,
        fields,
        timestamp: new Date().toISOString(),
        footer: { text: 'HD AntiCheat' },
    };

    const embeds = [main];
    const shots = webhookCfg.include_screenshots ? (screenshotUrls || []) : [];
    // Discord embeds only support one `image` each — stacking N
    // image-only embeds under the same message is the standard trick
    // for a multi-frame gallery in one post instead of N separate posts.
    for (const url of shots.slice(0, 4)) {
        embeds.push({ url: groupAnchor, image: { url } });
    }

    return embeds;
}

async function postBanToDiscord(ban, webhookCfg, screenshotUrls) {
    if (!webhookCfg || !webhookCfg.discord_webhook_url) return { skipped: true };

    const embeds = buildEmbeds(ban, webhookCfg, screenshotUrls);
    const res = await fetch(webhookCfg.discord_webhook_url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ embeds }),
    });
    if (!res.ok) {
        const text = await res.text().catch(() => '');
        throw new Error(`Discord webhook returned ${res.status}: ${text.slice(0, 300)}`);
    }
    return { skipped: false };
}

module.exports = { postBanToDiscord };
