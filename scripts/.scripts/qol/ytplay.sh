#!/bin/bash

# ytplay.sh — Play a YouTube video in mpv as a background process
# Usage: ./ytplay.sh "https://www.youtube.com/watch?v=..."

URL="$1"

if [[ -z "$URL" ]]; then
  echo "Usage: $0 <youtube-url>"
  exit 1
fi

# Launch mpv in the background with good format selection and silent output
nohup mpv --really-quiet \
          --ytdl-format="bestaudio[ext=m4a]+bestvideo[ext=mp4]/best" \
          "$URL" >/dev/null 2>&1 &
