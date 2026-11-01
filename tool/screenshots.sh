#!/bin/sh
# Captures the device screen every two seconds into $1 until stopped.
out="$1"; mkdir -p "$out"; n=0
while :; do
  n=$((n + 1))
  adb exec-out screencap -p > "$out/$(printf %03d $n).png" 2>/dev/null
  sleep 2
done
