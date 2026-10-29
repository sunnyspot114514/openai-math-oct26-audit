#!/bin/bash
D=/home/mathaudit/aud
while true; do
  A=$(df --output=avail -BG / | tail -1 | tr -dc 0-9)
  if [ "$A" -lt 11 ]; then echo "$(date -Is) DISK FLOOR avail=${A}G -> killing mathaudit" >> /tmp/aud_watch.log; pkill -u mathaudit; fi
  grep -q LSDONE $D/all.log 2>/dev/null && exit 0
  sleep 20
done
