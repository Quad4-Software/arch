#!/bin/sh
# Update a python/PyPI PKGBUILD to the latest (or given) version.
#
# Usage:
#   bump-pypi.sh NAME [VERSION]
# Example:
#   bump-pypi.sh rns
#   bump-pypi.sh rns 1.5.2

set -eu

ROOT="$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/lib.sh"
load_repo_conf

NAME="${1:-}"
REQ_VER="${2:-}"
[ -n "$NAME" ] || die "usage: bump-pypi.sh NAME [VERSION]"

load_pkg_conf "$NAME"
[ "$KIND" = "python" ] || die "$NAME is not a python package"
need_cmd curl
need_cmd python3

PYPI_NAME="${PYPI_NAME:-$NAME}"
meta="$(mktemp)"
curl -fsSL --retry 3 --retry-delay 2 "https://pypi.org/pypi/${PYPI_NAME}/json" >"$meta"

parsed="$(python3 - "$meta" "${REQ_VER}" <<'PY'
import json
import sys

path, want = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as f:
	data = json.load(f)
ver = want or data["info"]["version"]
if ver not in data["releases"]:
	raise SystemExit(f"version {ver} not on PyPI")
sdist = None
for u in data["releases"][ver]:
	if u.get("packagetype") == "sdist":
		sdist = u
		break
if not sdist:
	raise SystemExit(f"no sdist for {ver}")
print(ver)
print(sdist["url"])
print(sdist["digests"]["sha256"])
print(sdist["filename"])
PY
)"
rm -f "$meta"

VER="$(printf '%s\n' "$parsed" | sed -n '1p')"
SDIST_URL="$(printf '%s\n' "$parsed" | sed -n '2p')"
SHA="$(printf '%s\n' "$parsed" | sed -n '3p')"
SDIST_FILE="$(printf '%s\n' "$parsed" | sed -n '4p')"
# sdist dir is usually name-ver with underscores normalized oddly
# Prefer filename without .tar.gz / .zip
case "$SDIST_FILE" in
*.tar.gz) SDIST_DIR="${SDIST_FILE%.tar.gz}" ;;
*.zip) SDIST_DIR="${SDIST_FILE%.zip}" ;;
*) SDIST_DIR="${NAME}-${VER}" ;;
esac

DIR="$ROOT/pkg/$NAME"
sums_block="# AUTO-SUMS-BEGIN
sha256sums=('${SHA}')
# AUTO-SUMS-END"

awk -v ver="$VER" -v url="$SDIST_URL" -v block="$sums_block" -v sdir="$SDIST_DIR" '
	BEGIN { in_sums=0 }
	/^pkgver=/ { print "pkgver=" ver; next }
	/^source=/ {
		print "source=(\"" url "\")"
		next
	}
	/cd "\$srcdir\// {
		print "\tcd \"$srcdir/" sdir "\""
		next
	}
	/^# AUTO-SUMS-BEGIN$/ { print block; in_sums=1; next }
	/^# AUTO-SUMS-END$/ { in_sums=0; next }
	{ if (!in_sums) print }
' "$DIR/PKGBUILD" >"$DIR/PKGBUILD.next"
mv "$DIR/PKGBUILD.next" "$DIR/PKGBUILD"

tmpconf="$(mktemp)"
sed "s/^VERSION=.*/VERSION=${VER}/" "$DIR/pkg.conf" >"$tmpconf"
mv "$tmpconf" "$DIR/pkg.conf"

if [ -x "$ROOT/scripts/gen-srcinfo.sh" ]; then
	sh "$ROOT/scripts/gen-srcinfo.sh" "$NAME" || true
fi

log "Updated $NAME to $VER"
