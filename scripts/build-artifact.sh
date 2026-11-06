#!/usr/bin/env bash
# Builds dist/jbrowse5-<version>.tar.gz (+ .sha256) from build-manifest.json alone.
# The tarball is bit-reproducible for a given commit: sorted names, mtimes pinned
# to the commit time, numeric owner 0, normalized modes, gzip -n.
set -euo pipefail

usage() {
  echo "usage: $0 <version>   (e.g. 1.2.3 or 0.0.0-dev; no leading v)" >&2
  exit 2
}

[ $# -eq 1 ] || usage
version="$1"
[[ "$version" =~ ^[0-9][0-9A-Za-z.+-]*$ ]] || usage

for tool in curl jq unzip sha256sum tar gzip git; do
  command -v "$tool" > /dev/null || { echo "error: $tool not found on PATH" >&2; exit 1; }
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$repo_root/build-manifest.json"
downloads="$repo_root/build/downloads"
stage="$repo_root/build/stage"
out="$repo_root/dist"
app="$stage/jbrowse5"
tarball="jbrowse5-${version}.tar.gz"

commit="$(git -C "$repo_root" rev-parse HEAD)"
commit_epoch="$(git -C "$repo_root" log -1 --format=%ct HEAD)"
commit_time="$(git -C "$repo_root" log -1 --format=%cI HEAD)"
if [ -n "$(git -C "$repo_root" status --porcelain -- . ':!build' ':!dist')" ]; then
  tree_state=dirty
  echo "warning: working tree is dirty; build-info.txt will say so" >&2
else
  tree_state=clean
fi

# Downloads into a .part file and only keeps it once the sha256 matches.
fetch_verified() {
  local url="$1" sha256="$2" dest="$3"
  if [ -f "$dest" ] && echo "$sha256  $dest" | sha256sum -c --status; then
    return
  fi
  curl -fsSL --retry 3 -o "$dest.part" "$url"
  local actual
  actual="$(sha256sum "$dest.part" | cut -d' ' -f1)"
  if [ "$actual" != "$sha256" ]; then
    rm -f "$dest.part"
    echo "error: sha256 mismatch for $url" >&2
    echo "  expected $sha256" >&2
    echo "  actual   $actual" >&2
    exit 1
  fi
  mv "$dest.part" "$dest"
}

jq -e '
  (.jbrowse | (.tag and .url and .sha256))
  and (.plugins | type == "array")
  and all(.plugins[]; .name and .url and .sha256 and .file
          and (.file | test("^[A-Za-z0-9][A-Za-z0-9._-]*$")))
  and ([.plugins[].name] | length == (unique | length))
  and ([.plugins[].file] | length == (unique | length))
' "$manifest" > /dev/null || {
  echo "error: $manifest is malformed (jbrowse {tag,url,sha256}; plugins [{name,url,sha256,file}], unique names and plain file names)" >&2
  exit 1
}

rm -rf "$stage"
mkdir -p "$downloads" "$app/plugins" "$out"

jb_tag="$(jq -r .jbrowse.tag "$manifest")"
jb_url="$(jq -r .jbrowse.url "$manifest")"
jb_sha="$(jq -r .jbrowse.sha256 "$manifest")"
jb_zip="$downloads/jbrowse-web-${jb_tag}.zip"
fetch_verified "$jb_url" "$jb_sha" "$jb_zip"
unzip -q "$jb_zip" -d "$app"
rm -rf "$app/test_data"
[ -f "$app/index.html" ] || { echo "error: $jb_url has no index.html at its root" >&2; exit 1; }

plugin_lines=()
while IFS=$'\t' read -r name url sha256 file; do
  fetch_verified "$url" "$sha256" "$downloads/$file"
  cp "$downloads/$file" "$app/plugins/$file"
  plugin_lines+=("plugin: $name $url sha256=$sha256")
done < <(jq -r '.plugins[] | [.name, .url, .sha256, .file] | @tsv' "$manifest")

jq '{plugins: [.plugins[] | {name, url: ("plugins/" + .file)}]}' "$manifest" > "$app/config.json"

{
  echo "artifact: jbrowse5-${version}"
  echo "jbrowse: $jb_tag $jb_url sha256=$jb_sha"
  for line in ${plugin_lines[@]+"${plugin_lines[@]}"}; do echo "$line"; done
  echo "jbrowse2_commit: $commit"
  echo "jbrowse2_commit_time: $commit_time"
  echo "jbrowse2_tree: $tree_state"
} > "$app/build-info.txt"

tar --sort=name --format=gnu \
    --mtime="@$commit_epoch" \
    --owner=0 --group=0 --numeric-owner \
    --mode='u+rwX,go+rX,go-w' \
    -C "$stage" -cf - jbrowse5 \
  | gzip -n -9 > "$out/$tarball"
(cd "$out" && sha256sum "$tarball" > "$tarball.sha256")

cat "$out/$tarball.sha256"
