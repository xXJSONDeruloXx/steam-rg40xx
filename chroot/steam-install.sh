#!/bin/bash
# Inside the chroot, as the steam user: installs Valve's native arm64 client from its CDN manifest.
set -eu
channel=${1:-steamdeck_publicbeta}
cdn=https://client-update.steamstatic.com
root=$HOME/.local/share/Steam
manifest=steam_client_${channel}_linuxarm64
work=$root/package/dl
mkdir -p "$work"
curl -fsSL "$cdn/$manifest" -o "$work/manifest"
version=$(awk -F'"' '$2 == "version" { print $4; exit }' "$work/manifest")
awk -F'"' '
  /^\t"/ && NF >= 3 && $4 == "" { block = $2 }
  $2 == "file" { file[block] = $4 }
  $2 == "sha2" { sha[block] = $4 }
  END { for (b in file) if (b ~ /_all$/ || b ~ /_linuxarm64_linuxarm64$/) print b, file[b], sha[b] }
' "$work/manifest" | sort > "$work/parts"
while read -r block file sum; do
  [ -f "$work/$file.done" ] && continue
  echo "== $block"
  curl -fsSL --retry 5 -C - -o "$work/$file" "$cdn/$file" || curl -fsSL --retry 5 -o "$work/$file" "$cdn/$file"
  echo "$sum  $work/$file" | sha256sum -c --quiet
  unzip -qo "$work/$file" -d "$root"
  rm -f "$work/$file"
  : > "$work/$file.done"
done < "$work/parts"
find "$root" -depth -name '*\\*' | while read -r odd; do
  fixed=${odd//\\//}
  mkdir -p "$(dirname "$fixed")"
  if [ -d "$odd" ]; then cp -a "$odd/." "$fixed/" && rm -rf "$odd"; else mv -f "$odd" "$fixed"; fi
done
chmod -R a+x "$root/steamrtarm64" "$root/linuxarm64" 2>/dev/null || true
cp -f "$work/manifest" "$root/package/$manifest.manifest"
echo "$channel" > "$root/package/beta"
ln -sfn "$root/steamrtarm64" "$root/steamrtarm32"
mkdir -p "$HOME/.steam"
ln -sfn "$root" "$HOME/.steam/root"
ln -sfn "$root" "$HOME/.steam/steam"
ln -sfn "$root/steamrtarm64" "$HOME/.steam/bin64"
ln -sfn "$root/linuxarm64" "$HOME/.steam/sdkarm64"
ln -sfn "$root/steamrtarm64" "$HOME/.steam/binarm64"
echo "installed $version"
