#!/bin/sh
# usage: threads.sh <pid>  - per-thread name, state, wait channel, cpu ticks
p=$1
top -b -n1 | head -12
echo "== $(cat /proc/$p/cmdline | tr '\0' ' ' | cut -c1-80)"
for t in /proc/$p/task/*; do
  echo "$(cat $t/comm) $(cat $t/wchan) $(awk '{print $3, $14+$15}' $t/stat)"
done | sort -k4 -n -r | head -25
