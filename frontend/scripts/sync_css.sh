#!/bin/sh
set -eu

src_root=${1:-src}
out_root=${2:-dist}

find "$src_root" -type f -name '*.css' -print | while IFS= read -r css_file; do
  relative_path=${css_file#"$src_root/"}
  target="$out_root/$relative_path"
  mkdir -p "$(dirname "$target")"
  if [ ! -f "$target" ] || ! cmp -s "$css_file" "$target"; then
    cp "$css_file" "$target"
  fi
done
