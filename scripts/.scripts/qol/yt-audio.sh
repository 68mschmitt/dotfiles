#!/bin/bash

yt-dlp -f bestaudio ytsearch:$1 -o - 2>/dev/null | ffplay -nodisp -autoexit -i - &>/dev/null
