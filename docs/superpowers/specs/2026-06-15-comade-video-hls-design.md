# CoMade Capability Video — HLS Adaptive Hosting

**Date:** 2026-06-15
**URL:** https://video.comade.com.au
**Host:** OVH Sydney Coolify (`coolify-ovh-syd`, `139.99.210.148`)

## Goal

Host the CoMade capability video at an unlisted-public URL with adaptive
bitrate streaming, so viewers automatically get the best quality their
connection can sustain (4K down to 720p) with seamless mid-stream switching.

## Source assets

- `C:\Users\EmilBadenhorst\Downloads\CMD-ORG-DOC-133 Rev 0 Capability Video 18226 4k.mp4` (121 MB) — master source for transcode
- `C:\Users\EmilBadenhorst\Downloads\CMD-ORG-DOC-133 Rev 0 Capability Video 18226 1080.mp4` (38 MB) — not needed once 4K master is transcoded
- `C:\Users\EmilBadenhorst\Downloads\comade.png` (292×89 RGBA) — corner wordmark/logo

## Architecture

A minimal **nginx static-file container** on Coolify serves over HTTPS:

1. **Player page** (`index.html`) — minimal, full-bleed `<video>`, black
   background, small CoMade logo in a corner, powered by **hls.js**.
   hls.js measures throughput and auto-switches renditions. Safari/iOS play
   the HLS stream natively (no hls.js needed there).
2. **HLS master playlist** (`master.m3u8`) + 3 per-rendition playlists.
3. **Video segments** (fMP4 `.m4s`, ~4s each).

No JavaScript bandwidth detection — ABR is handled by the HLS player.

### Decision: why HLS over two-file + JS speed detection

`navigator.connection` is non-standard and absent on Safari/iOS; JS speed
guessing is unreliable and cannot adapt mid-playback. HLS ABR is the
industry-standard approach (YouTube/Netflix), works on every browser, and
switches quality live as the network changes.

## Component 1 — Transcoding (HLS ladder)

Run **ffmpeg once on the OVH box** (8 vCPU) against the 4K master. Single
source → 3-rung ladder for consistency:

| Rung  | Resolution | ~Bitrate  |
|-------|-----------|-----------|
| 4K    | 2160p     | ~16 Mbps  |
| 1080p | 1080p     | ~6 Mbps   |
| 720p  | 720p      | ~3 Mbps   |

(480p deliberately excluded — too low quality for a sales asset.)

Output written to the persistent media volume:
`master.m3u8`, `v0.m3u8`/`v1.m3u8`/`v2.m3u8`, fMP4 init + `.m4s` segments.

## Component 2 — Hosting / deploy

- **nginx:alpine** Docker app in Coolify, deployed from a small git repo
  (project root `c:\Code\comade-video`) containing `Dockerfile`,
  `nginx.conf`, `index.html`, and `comade.png`. Image stays tiny.
- **Heavy media lives in a Coolify persistent volume** mounted at
  `/srv/media`, populated by the on-box ffmpeg run. Media is **never**
  committed to git.
- nginx config:
  - `/` → player page
  - `/hls/` → media volume
  - correct MIME types (`application/vnd.apple.mpegurl` for `.m3u8`,
    `video/iso.segment` / `video/mp4` for segments)
  - `Accept-Ranges: bytes`; long cache TTL on segments, short/no-cache on
    `.m3u8` playlists
  - no directory listing (`autoindex off`)

## Component 3 — DNS & TLS

- **A record** `video.comade.com.au` → `139.99.210.148`, **DNS-only
  (grey cloud)**. Not proxied — CF free plan discourages proxying video
  bytes; OVH origin has ample bandwidth. Cloudflare zone
  `comade.com.au` = `824efd34af10908e11162645cdd258bc`.
- **TLS** via Coolify's built-in Traefik → Let's Encrypt for the subdomain.

## Component 4 — Access

Unlisted public. Anyone with the link can play it. No directory listing,
no file index, not linked from anywhere.

## Verification

1. ffmpeg output: `master.m3u8` references all 3 rungs; each rendition
   playlist resolves and segments exist.
2. `curl -I https://video.comade.com.au` → `200`, valid Let's Encrypt cert.
3. Browser: video plays; throttling DevTools network to "Slow 3G/Fast 3G"
   drops the stream to a lower rung automatically, then climbs back when
   throttle is removed.
4. Safari/iOS: native HLS playback works.

## Out of scope (YAGNI)

- Analytics / view tracking
- Multiple videos / a video library
- Auth / gating
- Subtitles / captions (can add later if needed)
