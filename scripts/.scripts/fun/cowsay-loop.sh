#!/bin/bash

cowsay_message="Hello from cowsay!"
for cowfile in $(cowsay -l | tail -n +2); do
  echo "=== $cowfile ==="
  cowsay -f "$cowfile" "$cowsay_message" | lolcat
  echo ""
done

