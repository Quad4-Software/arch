#!/bin/sh
# Assemble the GitHub Pages tree from repo/.

set -eu

ROOT="$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/lib.sh"
load_repo_conf

PUB="$ROOT/public"
rm -rf "$PUB"
mkdir -p "$PUB"

[ -d "$ROOT/repo" ] || die "repo/ missing (run repo-add.sh first)"

cp -a "$ROOT/repo/." "$PUB/"
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

index="$PUB/index.html"
{
	printf '%s\n' '<!DOCTYPE html>'
	printf '%s\n' '<html lang="en"><head><meta charset="utf-8"><title>Quad4 Arch repo</title></head><body>'
	printf '%s\n' "<h1>${REPO_NAME}</h1>"
	printf '%s\n' '<p>Custom pacman repository for Quad4 packages. Not AUR.</p>'
	printf '%s\n' '<p>Add <a href="pacman-quad4.conf">pacman-quad4.conf</a> to /etc/pacman.conf then pacman -Syu.</p>'
	printf '%s\n' '<ul>'
	find "$PUB" \( -name '*.pkg.tar.zst' -o -name '*.db' -o -name '*.db.tar.gz' -o -name '*.files' -o -name '*.files.tar.gz' \) \
		| sed "s|^$PUB/||" | LC_ALL=C sort | while IFS= read -r rel; do
		[ -n "$rel" ] || continue
		printf '<li><a href="%s">%s</a></li>\n' "$rel" "$rel"
	done
	printf '%s\n' '</ul></body></html>'
} >"$index"

log "pages tree at $PUB"
find "$PUB" -type f | LC_ALL=C sort
