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
