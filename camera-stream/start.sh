#!/usr/bin/env bash
set -euo pipefail

DEVICE="${CAMERA_DEVICE:-/dev/video0}"
PORT="${STREAM_PORT:-8081}"
FPS="${STREAM_FPS:-10}"
QUALITY="${STREAM_QUALITY:-7}"

if [[ ! -e "$DEVICE" ]]; then
  echo "Camera device not found: $DEVICE" >&2
  exit 1
fi

exec ffmpeg \
  -hide_banner \
  -loglevel error \
  -f v4l2 \
  -i "$DEVICE" \
  -vf "fps=$FPS" \
  -f mjpeg \
  -q:v "$QUALITY" \
  -listen 1 \
  "http://0.0.0.0:${PORT}/stream.mjpg"
