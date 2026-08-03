// ═══════════════════════════════════════════════════════════════════
//  HD INVENTORY | ICONS
//  Hand-drawn line-art SVG icons, one per item in HD_Framework's
//  shared/items.lua — real vector graphics (not a monogram fallback,
//  not a placeholder), styled consistently: 24x24 viewBox, stroke
//  only, currentColor (so CSS controls the actual colour — see
//  .item-tile { color: #fff } in style.css). Add a new item to
//  shared/items.lua and its icon here; anything missing falls back to
//  ICON_DEFAULT rather than breaking the grid.
// ═══════════════════════════════════════════════════════════════════

(function () {
    'use strict';

    const S = 'viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"';

    const ICONS = {
        id_card: `<svg ${S}><rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="8" cy="10.5" r="1.8"/><path d="M5 16c.5-2 2-3 3-3s2.5 1 3 3"/><path d="M14 9h5M14 13h5"/></svg>`,
        driver_license: `<svg ${S}><rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="8" cy="12" r="2.6"/><path d="M14 9h5M14 12h5M14 15h3"/></svg>`,
        radio: `<svg ${S}><line x1="15" y1="2" x2="15" y2="6"/><rect x="7" y="6" width="10" height="16" rx="2"/><line x1="9" y1="10" x2="15" y2="10"/><line x1="9" y1="13" x2="15" y2="13"/><circle cx="12" cy="17" r="1.4"/></svg>`,
        handcuffs: `<svg ${S}><circle cx="7" cy="12" r="4"/><circle cx="17" cy="12" r="4"/><line x1="11" y1="12" x2="13" y2="12"/></svg>`,
        armorplate: `<svg ${S}><path d="M12 3l7 3v6c0 4.5-3 7.5-7 9-4-1.5-7-4.5-7-9V6l7-3z"/></svg>`,
        bandage: `<svg ${S}><rect x="2" y="9" width="20" height="6" rx="3"/><line x1="9" y1="9" x2="9" y2="15"/><line x1="15" y1="9" x2="15" y2="15"/></svg>`,
        painkillers: `<svg ${S}><rect x="3" y="9" width="18" height="6" rx="3"/><line x1="12" y1="9" x2="12" y2="15"/></svg>`,
        medkit: `<svg ${S}><rect x="3" y="7" width="18" height="13" rx="2"/><path d="M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2"/><line x1="12" y1="11" x2="12" y2="16"/><line x1="9.5" y1="13.5" x2="14.5" y2="13.5"/></svg>`,
        splint: `<svg ${S}><rect x="4" y="10" width="16" height="4" rx="1"/><line x1="7" y1="8" x2="7" y2="16"/><line x1="17" y1="8" x2="17" y2="16"/></svg>`,
        defibrillator: `<svg ${S}><path d="M12 20s-7-4.5-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.5-7 10-7 10z"/><polyline points="8,12 10,12 11,9 13,15 14,12 16,12"/></svg>`,
        oxygen_mask: `<svg ${S}><path d="M6 10a6 6 0 0 1 12 0v3a3 3 0 0 1-3 3H9a3 3 0 0 1-3-3v-3z"/><path d="M4 9c-1 0-1 2 0 2M20 9c1 0 1 2 0 2"/></svg>`,
        morphine: `<svg ${S}><line x1="3" y1="21" x2="9" y2="15"/><rect x="8.5" y="8.5" width="10" height="5" rx="1" transform="rotate(45 13.5 11)"/><line x1="15" y1="4" x2="19" y2="8"/><line x1="17" y1="2" x2="21" y2="6"/></svg>`,
        stretcher: `<svg ${S}><rect x="3" y="8" width="18" height="6" rx="1"/><line x1="3" y1="14" x2="3" y2="19"/><line x1="21" y1="14" x2="21" y2="19"/><line x1="6" y1="8" x2="6" y2="6"/><line x1="18" y1="8" x2="18" y2="6"/></svg>`,
        surgical_kit: `<svg ${S}><line x1="4" y1="20" x2="13" y2="11"/><path d="M13 11l3-3 4 4-3 3z"/></svg>`,
        repairkit: `<svg ${S}><path d="M14.7 6.3a4 4 0 0 0-5.4 5.4L4 17l3 3 5.3-5.3a4 4 0 0 0 5.4-5.4l-2.8 2.8-2-2z"/></svg>`,
        jump_cables: `<svg ${S}><path d="M3 6c3 0 3 3 6 3s3-3 6-3 3 3 6 3"/><path d="M3 15c3 0 3 3 6 3s3-3 6-3 3 3 6 3"/></svg>`,
        tow_hook: `<svg ${S}><path d="M9 3v9a5 5 0 0 0 10 0"/><circle cx="9" cy="3" r="1.6" fill="currentColor" stroke="none"/></svg>`,
        phone: `<svg ${S}><rect x="7" y="2" width="10" height="20" rx="2"/><line x1="10.5" y1="18.5" x2="13.5" y2="18.5"/></svg>`,
        water_bottle: `<svg ${S}><path d="M10 2h4v3l2 2v13a2 2 0 0 1-2 2h-4a2 2 0 0 1-2-2V7l2-2z"/><line x1="8" y1="12" x2="16" y2="12"/></svg>`,
        sandwich: `<svg ${S}><path d="M3 18l9-13 9 13z"/><line x1="6.5" y1="13" x2="17.5" y2="13"/></svg>`,
    };

    const ICON_DEFAULT = `<svg ${S}><path d="M3 8l9-5 9 5-9 5-9-5z"/><path d="M3 8v8l9 5 9-5V8"/><line x1="12" y1="13" x2="12" y2="21"/></svg>`;

    window.HD_ICONS = {
        get(name) { return ICONS[name] || ICON_DEFAULT; },
    };
})();
