# CoMade Capability Video — HLS Adaptive Hosting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Host the CoMade 4K capability video at https://video.comade.com.au with HLS adaptive-bitrate streaming (4K / 1080p / 720p auto-switching) on the OVH Sydney Coolify box.

**Architecture:** A tiny `nginx:alpine` container (built from a small public GitHub repo) serves a minimal hls.js player plus the HLS playlists/segments. The heavy media is transcoded once on the OVH box by ffmpeg and lives in a host bind-mount volume — never in git. DNS-only Cloudflare A record points the subdomain straight at the OVH origin; Coolify's Traefik issues the Let's Encrypt cert.

**Tech Stack:** nginx, hls.js, ffmpeg (libx264, fMP4 HLS), Docker, Coolify, Cloudflare DNS.

**Key facts (verified):**
- OVH box: `ubuntu@139.99.210.148`, Coolify dashboard `https://coolify-syd.rezolveit.com.au` (CF Access gated; `/api/` bypass exists).
- Cloudflare zone `comade.com.au` = `824efd34af10908e11162645cdd258bc`. CF API token + account ID in `c:\Code\M365Manage\.env`.
- Source 4K master: `C:\Users\EmilBadenhorst\Downloads\CMD-ORG-DOC-133 Rev 0 Capability Video 18226 4k.mp4`.
- Logo: `C:\Users\EmilBadenhorst\Downloads\comade.png` (292×89 RGBA).
- Project root: `c:\Code\comade-video` (git already initialised; spec committed).

**Host paths on OVH box:**
- Media bind-mount source: `/data/comade-video/hls` → container `/srv/media`.
- Uploaded master: `/data/comade-video/src/master4k.mp4`.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `Dockerfile` | Build `nginx:alpine` image with player + config baked in |
| `nginx.conf` | Server config: player at `/`, media at `/hls/`, MIME + range headers, no autoindex |
| `index.html` | Minimal hls.js player page, CoMade logo overlay |
| `hls.min.js` | Vendored hls.js (no runtime third-party CDN) |
| `comade.png` | Logo (copied from Downloads) |
| `transcode.sh` | ffmpeg HLS-ladder script, run once on the OVH box |
| `.gitignore` | Exclude media/transcode output |
| `.dockerignore` | Keep build context tiny |

---

## Task 1: Scaffold the static site

**Files:**
- Create: `c:\Code\comade-video\.gitignore`
- Create: `c:\Code\comade-video\.dockerignore`
- Create: `c:\Code\comade-video\nginx.conf`
- Create: `c:\Code\comade-video\index.html`
- Create: `c:\Code\comade-video\Dockerfile`
- Create: `c:\Code\comade-video\comade.png` (copied)
- Create: `c:\Code\comade-video\hls.min.js` (downloaded)

- [ ] **Step 1: Write `.gitignore`**

```
hls/
*.mp4
*.m4s
*.ts
node_modules/
```

- [ ] **Step 2: Write `.dockerignore`**

```
docs/
hls/
*.mp4
*.m4s
.git/
transcode.sh
```

- [ ] **Step 3: Write `nginx.conf`**

```nginx
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;
    autoindex off;

    types {
        text/html                       html;
        image/png                       png;
        application/javascript          js;
        application/vnd.apple.mpegurl   m3u8;
        video/mp4                       m4s mp4;
    }

    # HLS media from the host bind-mount volume
    location /hls/ {
        alias /srv/media/;
        add_header Accept-Ranges bytes;
        add_header Cache-Control "public, max-age=3600";
    }

    location / {
        try_files $uri $uri/ =404;
    }
}
```

- [ ] **Step 4: Write `index.html`**

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>CoMade — Capability Video</title>
<style>
  html,body{margin:0;height:100%;background:#000;overflow:hidden}
  #wrap{position:fixed;inset:0;display:flex;align-items:center;justify-content:center}
  video{width:100%;height:100%;object-fit:contain;background:#000}
  #logo{position:fixed;top:18px;left:18px;width:130px;opacity:.9;pointer-events:none;z-index:2}
  #msg{color:#fff;font-family:system-ui,sans-serif}
</style>
</head>
<body>
<div id="wrap">
  <video id="v" controls playsinline></video>
</div>
<img id="logo" src="/comade.png" alt="CoMade">
<script src="/hls.min.js"></script>
<script>
  var v = document.getElementById('v');
  var src = '/hls/master.m3u8';
  if (v.canPlayType('application/vnd.apple.mpegurl')) {
    v.src = src;                              // Safari / iOS native HLS
  } else if (window.Hls && Hls.isSupported()) {
    var hls = new Hls({ startLevel: -1 });    // -1 = auto-select by bandwidth
    hls.loadSource(src);
    hls.attachMedia(v);
  } else {
    document.getElementById('wrap').innerHTML =
      '<p id="msg">Your browser cannot play this video.</p>';
  }
</script>
</body>
</html>
```

- [ ] **Step 5: Write `Dockerfile`**

```dockerfile
FROM nginx:alpine
RUN rm -f /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html hls.min.js comade.png /usr/share/nginx/html/
```

- [ ] **Step 6: Copy the logo and download vendored hls.js**

Run (PowerShell):
```powershell
Copy-Item "C:\Users\EmilBadenhorst\Downloads\comade.png" "c:\Code\comade-video\comade.png"
Invoke-WebRequest "https://cdn.jsdelivr.net/npm/hls.js@1/dist/hls.min.js" -OutFile "c:\Code\comade-video\hls.min.js"
```

- [ ] **Step 7: Verify files exist and hls.min.js is non-trivial**

Run (PowerShell):
```powershell
Get-ChildItem c:\Code\comade-video\*.png,c:\Code\comade-video\hls.min.js | Select-Object Name,Length
```
Expected: `comade.png` ~5.7 KB, `hls.min.js` > 300 KB.

- [ ] **Step 8: Commit**

```bash
cd /c/Code/comade-video
git add .gitignore .dockerignore nginx.conf index.html Dockerfile comade.png hls.min.js
git commit -m "feat: scaffold nginx HLS player site"
```

---

## Task 2: Write the transcode script

**Files:**
- Create: `c:\Code\comade-video\transcode.sh`

- [ ] **Step 1: Write `transcode.sh`**

Keyframes are forced every 4 s via `force_key_frames` so the GOP aligns with `-hls_time 4` regardless of source fps. fMP4 segments, VOD playlist, 3-rung ladder, audio duplicated to each rendition.

```bash
#!/usr/bin/env bash
set -euo pipefail
SRC="${1:?usage: transcode.sh <src.mp4> [outdir]}"
OUT="${2:-/data/comade-video/hls}"
mkdir -p "$OUT"

ffmpeg -y -i "$SRC" \
  -filter_complex "[0:v]split=3[v0][v1][v2]; \
     [v0]scale=3840:2160[v0o]; \
     [v1]scale=1920:1080[v1o]; \
     [v2]scale=1280:720[v2o]" \
  -map "[v0o]" -map "[v1o]" -map "[v2o]" \
  -map a:0 -map a:0 -map a:0 \
  -c:v libx264 -preset medium -profile:v high -pix_fmt yuv420p \
  -force_key_frames "expr:gte(t,n_forced*4)" \
  -c:a aac -b:a 128k -ar 48000 \
  -b:v:0 16000k -maxrate:0 17600k -bufsize:0 24000k \
  -b:v:1 6000k  -maxrate:1 6600k  -bufsize:1 9000k \
  -b:v:2 3000k  -maxrate:2 3300k  -bufsize:2 4500k \
  -hls_time 4 -hls_playlist_type vod \
  -hls_segment_type fmp4 -hls_flags independent_segments \
  -master_pl_name master.m3u8 \
  -var_stream_map "v:0,a:0,name:2160p v:1,a:1,name:1080p v:2,a:2,name:720p" \
  "$OUT/v%v.m3u8"

echo "Done. Wrote ladder to $OUT"
ls -1 "$OUT"
```

- [ ] **Step 2: Commit**

```bash
cd /c/Code/comade-video
git add transcode.sh
git commit -m "feat: add ffmpeg HLS-ladder transcode script"
```

---

## Task 3: Publish the repo to GitHub

The repo holds only the player, config, logo, and Dockerfile — nothing sensitive — so a **public** repo lets Coolify deploy without a deploy key.

- [ ] **Step 1: Create the public repo and push**

Run (from `c:\Code\comade-video`):
```bash
gh repo create rezolve-it/comade-video --public --source=. --remote=origin --push
```

- [ ] **Step 2: Verify it pushed**

Run:
```bash
gh repo view rezolve-it/comade-video --json url,visibility -q '.url + " (" + .visibility + ")"'
```
Expected: a github.com URL marked `PUBLIC`. Confirm media files are **absent** from the repo (gitignored):
```bash
gh api repos/rezolve-it/comade-video/contents -q '.[].name'
```
Expected: no `.mp4`/`.m4s`/`hls` entries.

---

## Task 4: Create the DNS record

- [ ] **Step 1: Create the A record (DNS-only)**

Run (Bash, from `c:\Code\M365Manage` so `.env` is present):
```bash
cd /c/Code/M365Manage
TOKEN=$(grep "^CLOUDFLARE_API_TOKEN=" .env | cut -d= -f2- | tr -d '"'"'"'\r')
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/824efd34af10908e11162645cdd258bc/dns_records" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  --data '{"type":"A","name":"video.comade.com.au","content":"139.99.210.148","ttl":1,"proxied":false}' \
  | python -c "import sys,json;d=json.load(sys.stdin);print('success:',d['success']); print(d.get('errors'))"
```
Expected: `success: True`.

- [ ] **Step 2: Verify resolution**

Run (PowerShell):
```powershell
Resolve-DnsName video.comade.com.au -Type A
```
Expected: resolves to `139.99.210.148` (may take a minute to propagate).

---

## Task 5: Transcode the video on the OVH box

All commands run over SSH as `ubuntu@139.99.210.148`.

- [ ] **Step 1: Ensure ffmpeg is installed**

```bash
ssh ubuntu@139.99.210.148 'ffmpeg -version >/dev/null 2>&1 || sudo apt-get update && sudo apt-get install -y ffmpeg; ffmpeg -version | head -1'
```
Expected: prints an ffmpeg version line.

- [ ] **Step 2: Create host directories**

```bash
ssh ubuntu@139.99.210.148 'sudo mkdir -p /data/comade-video/hls /data/comade-video/src && sudo chown -R ubuntu:ubuntu /data/comade-video'
```

- [ ] **Step 3: Upload the 4K master**

Run (PowerShell — `scp` ships with Windows OpenSSH):
```powershell
scp "C:\Users\EmilBadenhorst\Downloads\CMD-ORG-DOC-133 Rev 0 Capability Video 18226 4k.mp4" ubuntu@139.99.210.148:/data/comade-video/src/master4k.mp4
```

- [ ] **Step 4: Copy the transcode script up and run it**

```bash
scp /c/Code/comade-video/transcode.sh ubuntu@139.99.210.148:/data/comade-video/transcode.sh
ssh ubuntu@139.99.210.148 'bash /data/comade-video/transcode.sh /data/comade-video/src/master4k.mp4 /data/comade-video/hls'
```
Expected: ends with `Done.` and a directory listing including `master.m3u8`, `v0.m3u8`, `v1.m3u8`, `v2.m3u8`, init segments, and `.m4s` segment files.

- [ ] **Step 5: Verify the master playlist lists all 3 rungs**

```bash
ssh ubuntu@139.99.210.148 'cat /data/comade-video/hls/master.m3u8'
```
Expected: three `#EXT-X-STREAM-INF` entries with `RESOLUTION=3840x2160`, `1920x1080`, `1280x720`.

---

## Task 6: Deploy the nginx app on Coolify

**Sub-skill:** Use the `coolify-deploy` skill for the Coolify mechanics. Target the **OVH Sydney** instance (`https://coolify-syd.rezolveit.com.au`), not the R640. The API is reachable via the `/api/` CF Access bypass; generate an API token in that Coolify UI (Settings → API Tokens) if one isn't already in `.env`. If API access is awkward, the Coolify web UI (behind CF Access for `@rezolveit.com.au`) is an acceptable fallback — the click-path below maps to the same settings.

Create a Coolify application with these settings:

- [ ] **Step 1: New application — Dockerfile build from public repo**
  - Source: Public Repository → `https://github.com/rezolve-it/comade-video`, branch `main`.
  - Build Pack: **Dockerfile** (root `Dockerfile`).
  - Server: the OVH Sydney server; default network.

- [ ] **Step 2: Add the persistent storage bind mount**
  - Type: bind mount.
  - Host path: `/data/comade-video/hls`
  - Container path: `/srv/media`
  - (This maps the transcoded ladder into nginx's `/hls/` alias.)

- [ ] **Step 3: Set the domain**
  - Domain: `https://video.comade.com.au`
  - Port: `80` (nginx listens on 80; Traefik terminates TLS).
  - Ensure Let's Encrypt / automatic TLS is enabled for the domain.

- [ ] **Step 4: Deploy**
  - Trigger deploy. Wait for the build + container to go healthy in Coolify.

- [ ] **Step 5: Verify the container is up and TLS issued**

```bash
curl -sI https://video.comade.com.au | head -5
```
Expected: `HTTP/2 200`, served by nginx, valid cert (no `curl -k` needed). If you see a cert error, wait for Traefik's ACME challenge to complete (can take 1-2 min) and retry.

---

## Task 7: End-to-end verification

- [ ] **Step 1: Player page loads**

```bash
curl -s https://video.comade.com.au | grep -o '<title>[^<]*</title>'
```
Expected: `<title>CoMade — Capability Video</title>`.

- [ ] **Step 2: Master playlist is reachable with correct MIME**

```bash
curl -sI https://video.comade.com.au/hls/master.m3u8 | grep -i -E 'HTTP/|content-type|accept-ranges'
```
Expected: `200`, `content-type: application/vnd.apple.mpegurl`, `accept-ranges: bytes`.

- [ ] **Step 3: A segment is byte-range serveable**

```bash
curl -sI -H "Range: bytes=0-1023" https://video.comade.com.au/hls/v2_000.m4s | grep -i -E 'HTTP/|content-range'
```
(Adjust the segment filename to one listed in Task 5 Step 4.)
Expected: `206 Partial Content` with a `content-range` header.

- [ ] **Step 4: Browser adaptive-bitrate check (manual)**

Open https://video.comade.com.au in Chrome. Press play — it should start and auto-pick a rung. Open DevTools → Network → set throttling to "Fast 3G": within a few segments the stream should step down to 720p (smaller `.m4s` requests). Remove throttling: it should climb back toward 4K. Confirm the CoMade logo shows top-left and there is no directory listing at `/hls/`.

- [ ] **Step 5: iOS/Safari native check (manual, if a device is handy)**

Open the URL in Safari (desktop or iOS). Expected: plays via native HLS (no hls.js path).

---

## Self-Review (completed)

- **Spec coverage:** HLS ladder (Task 5) ✓; nginx static host + volume (Tasks 1, 6) ✓; player + logo (Task 1) ✓; DNS grey-cloud A record (Task 4) ✓; Traefik LE TLS (Task 6) ✓; unlisted/no-index (`autoindex off` + `noindex` meta) ✓; verification incl. ABR + Safari (Task 7) ✓. 480p excluded per decision ✓.
- **Placeholders:** none — all code/commands are concrete. The only intentionally manual steps are the browser/Safari checks (Task 7) and the Coolify UI fallback, both unavoidable.
- **Type/name consistency:** `/srv/media` ↔ `/data/comade-video/hls` mapping consistent across nginx.conf, transcode default OUT, and the Coolify bind mount; `master.m3u8` name consistent between ffmpeg `-master_pl_name`, player `src`, and verification.
- **Open dependency:** Task 6 assumes the `rezolve-it` GitHub org and a Coolify GitHub/public-repo source on OVH-syd. If the org name differs, adjust the repo path in Tasks 3 and 6 consistently.
