#!/usr/bin/env bash
# Compares this config with upstream Doom master (doomemacs/core plus its
# doomemacs/modules submodule), independent of the local ~/.config/emacs
# checkout. The clone is only read with grep/awk/diff; nothing in it runs.
#
# Usage: upstream-check.sh <scratch-dir>
set -euo pipefail

scratch=${1:?usage: upstream-check.sh <scratch-dir>}
skill_dir=$(cd "$(dirname "$0")" && pwd)
doomdir=${DOOMDIR:-$HOME/.config/doom}
local_doom=${EMACSDIR:-$HOME/.config/emacs}
upstream=$scratch/doom-upstream

if [ -d "$upstream/.git" ]; then
  git -C "$upstream" fetch -q --depth 1 origin master
  git -C "$upstream" reset -q --hard FETCH_HEAD
else
  git clone -q --depth 1 https://github.com/doomemacs/core "$upstream"
fi
git -C "$upstream" submodule update -q --init --depth 1

upstream_modules=$upstream/sources/doom+/modules
[ -d "$upstream_modules" ] || upstream_modules=$upstream/modules

echo "UPSTREAM $(git -C "$upstream" log -1 --format='%h %cs')  LOCAL $(git -C "$local_doom" log -1 --format='%h %cs')"

echo "## Modules and flags (init.el vs upstream modules)"
awk -f "$skill_dir/doom-modules.awk" "$doomdir/init.el" |
while read -r category module flags; do
  case $module in :*) continue ;; esac   # :os (:if ...) conditionals
  dir=$upstream_modules/$category/$module
  if [ ! -d "$dir" ]; then
    echo "MISSING-MODULE :$category $module"
    continue
  fi
  for flag in $flags; do
    grep -rqF -- "$flag" "$dir" || echo "UNKNOWN-FLAG :$category $module $flag"
  done
done

echo "## Obsolete symbols used in config.org"
find "$upstream/lisp" "$upstream/modules" "$upstream_modules" -name '*.el' -print0 |
  xargs -0 awk -f "$skill_dir/doom-obsolete.awk" > "$scratch/doom-obsolete.tsv"
cut -f1 "$scratch/doom-obsolete.tsv" | sort -u |
while read -r symbol; do
  where=$(grep -m1 -F "$symbol"$'\t' "$scratch/doom-obsolete.tsv" | cut -f2- | sed "s|$upstream/||")
  grep -nP "(?<![\w!+*/<>=:-])\Q$symbol\E(?![\w!+*/<>=:-])" "$doomdir/config.org" |
    sed "s|^|OBSOLETE $symbol config.org:|; s|\$|   [$where]|" || true
done

echo "## Template changes (local checkout -> upstream)"
for template in init.example.el config.example.el packages.example.el; do
  diff -u "$local_doom/static/$template" "$upstream/static/$template" \
    --label "local/$template" --label "upstream/$template" || true
done
