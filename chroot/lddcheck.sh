#!/bin/bash
r=/home/steam/.local/share/Steam
export LD_LIBRARY_PATH=$r/steamrtarm64:$r/steamrtarm64/panorama:$r/steamrtarm64/libs
cd $r/steamrtarm64
for b in steam steamwebhelper *.so; do
  m=$(ldd "$b" 2>&1 | grep "not found" | awk '{print $1}' | tr '\n' ' ')
  [ -n "$m" ] && echo "$b: $m"
done
echo done
