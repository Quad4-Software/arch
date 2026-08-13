#!/bin/sh
# Assemble the GitHub Pages tree.

set -eu

ROOT="$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/lib.sh"
load_repo_conf

PUB="$ROOT/public"
rm -rf "$PUB"
mkdir -p "$PUB"

if [ -d "$ROOT/repo" ]; then
	cp -a "$ROOT/repo/." "$PUB/"
fi
cp "$ROOT/conf/pacman-quad4.conf" "$PUB/pacman-quad4.conf"
if [ -f "$ROOT/keys/quad4.gpg" ]; then
	cp "$ROOT/keys/quad4.gpg" "$PUB/quad4.gpg"
fi
touch "$PUB/.nojekyll"
if [ -f "$ROOT/CNAME" ]; then
	cp "$ROOT/CNAME" "$PUB/CNAME"
else
	cname="${PAGES_URL#http://}"
	cname="${cname#https://}"
	cname="${cname%%/*}"
	[ -n "$cname" ] || die "PAGES_URL has no host"
	printf '%s\n' "$cname" >"$PUB/CNAME"
fi

[ -f "$ROOT/site/index.html" ] || die "missing site/index.html"

files_inc="$(mktemp)"
trap 'rm -f "$files_inc"' EXIT
find "$PUB" \( -name '*.pkg.tar.zst' -o -name '*.db' -o -name '*.db.tar.gz' -o -name '*.files' -o -name '*.files.tar.gz' \) \
	| sed "s|^$PUB/||" | LC_ALL=C sort | {
	current=""
	while IFS= read -r rel; do
		[ -n "$rel" ] || continue
		arch="${rel%%/*}"
		base="${rel#*/}"
		if [ "$arch" != "$current" ]; then
			[ -n "$current" ] && printf '</ul>\n'
			printf '<h3>%s</h3>\n<ul>\n' "$arch"
			current="$arch"
		fi
		printf '<li><a href="%s">%s</a></li>\n' "$rel" "$base"
	done
	if [ -n "$current" ]; then
		printf '</ul>\n'
	else
		printf '<p class="muted">No packages published yet.</p>\n'
	fi
} >"$files_inc"

awk -v files="$files_inc" '
	/<!--PACKAGE_FILES-->/ {
		while ((getline line < files) > 0) print line
		close(files)
		next
	}
	{ print }
' "$ROOT/site/index.html" >"$PUB/index.html"

log "pages tree at $PUB"
find "$PUB" -type f | LC_ALL=C sort
