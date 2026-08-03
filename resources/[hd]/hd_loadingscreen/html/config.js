// ═══════════════════════════════════════════════════════════════════
//  HD LOADINGSCREEN | CONFIG
//  Plain JS, not Lua — see fxmanifest.lua's comment for why a loading
//  screen can't have a Lua-backed config the way every other HD
//  resource does.
// ═══════════════════════════════════════════════════════════════════
window.HD_LOADSCREEN_CONFIG = {
    serverName: 'HAZY DEVELOPMENT',
    tagline: 'United Kingdom Roleplay',
    // Now a full promotional banner (wordmark/tagline/feature badges
    // already in the image itself), not a small square mark — see
    // style.css's #logo rule, sized as a hero graphic with
    // #serverName/#tagline hidden below it so the text isn't
    // duplicated. Use a real high-resolution source (the wider/higher-
    // res the better, it's displayed close to full width) — a small
    // source stretched up to hero size is what reads as blurry.
    logo: 'images/logo.png',

    // Any youtube.com/watch or youtu.be link works — paste the whole
    // URL, the video id is pulled out automatically below. Leave empty
    // ('') for no music. Browsers/CEF can be picky about autoplaying
    // audio — if it doesn't play, that's a client-side autoplay policy
    // thing, not a config error.
    youtubeUrl: 'https://www.youtube.com/watch?v=oFqVvjq6BGM&list=RDoFqVvjq6BGM&start_radio=1',
    musicVolume: 35, // 0-100

    // Background slideshow — add real screenshots here as
    // 'images/slide1.jpg', 'images/slide2.jpg', etc. (drop the actual
    // files into html/images/ and list them here) and they'll be used
    // instead of the built-in placeholder gradients automatically. Add
    // more entries the same way as you get more images.
    slideshowImages: [
        'images/slide1.png',
    ],
    slideshowIntervalMs: 3000,
};
