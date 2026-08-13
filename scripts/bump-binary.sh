#!/bin/sh
# Update a binary PKGBUILD to a GitHub release tag and refresh sha256sums.
#
# Usage: bump-binary.sh NAME TAG
# Example: bump-binary.sh reticulum-go v1.0.1

set -eu

ROOT="$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/lib.sh"
load_repo_conf

NAME="${1:-}"
TAG="${2:-}"
[ -n "$NAME" ] || die "usage: bump-binary.sh NAME TAG"
[ -n "$TAG" ] || die "usage: bump-binary.sh NAME TAG"

load_pkg_conf "$NAME"
[ "$KIND" = "binary" ] || die "$NAME is not a binary package"
need_cmd curl
need_cmd sha256sum
need_cmd sed

VER="${TAG#v}"
DIR="$ROOT/pkg/$NAME"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

sum_of() {
	sha256sum "$1" | awk '{print $1}'
}

download() {
	url="$1"
	out="$2"
	log "GET $url"
	curl -fsSL --retry 3 --retry-delay 2 -o "$out" "$url"
}

expand_ver() {
	printf '%s' "$1" | sed "s/@VER@/${VER}/g"
}

base="https://github.com/${GITHUB}/releases/download/${TAG}"
src_url="https://github.com/${GITHUB}/archive/refs/tags/${TAG}.tar.gz"

src_sum=""
if [ "${SOURCE_TARBALL:-}" = "1" ]; then
	download "$src_url" "$WORKDIR/src.tar.gz"
	src_sum="$(sum_of "$WORKDIR/src.tar.gz")"
fi

sum_x86=""
sum_arm64=""
sum_armv7=""
if [ -n "${ASSET_x86_64:-}" ]; then
	download "${base}/$(expand_ver "$ASSET_x86_64")" "$WORKDIR/amd64"
	sum_x86="$(sum_of "$WORKDIR/amd64")"
fi
if [ -n "${ASSET_aarch64:-}" ]; then
	download "${base}/$(expand_ver "$ASSET_aarch64")" "$WORKDIR/arm64"
	sum_arm64="$(sum_of "$WORKDIR/arm64")"
fi
if [ -n "${ASSET_armv7h:-}" ]; then
	download "${base}/$(expand_ver "$ASSET_armv7h")" "$WORKDIR/arm"
	sum_armv7="$(sum_of "$WORKDIR/arm")"
fi

sums_block="# AUTO-SUMS-BEGIN"
if [ -n "$src_sum" ]; then
	sums_block="${sums_block}
sha256sums=('${src_sum}')"
fi
if [ -n "$sum_x86" ]; then
	sums_block="${sums_block}
sha256sums_x86_64=('${sum_x86}')"
fi
if [ -n "$sum_arm64" ]; then
	sums_block="${sums_block}
sha256sums_aarch64=('${sum_arm64}')"
fi
if [ -n "$sum_armv7" ]; then
	sums_block="${sums_block}
sha256sums_armv7h=('${sum_armv7}')"
fi
sums_block="${sums_block}
# AUTO-SUMS-END"

awk -v ver="$VER" -v block="$sums_block" '
	BEGIN { in_sums=0 }
	/^pkgver=/ { print "pkgver=" ver; next }
	/^# AUTO-SUMS-BEGIN$/ { print block; in_sums=1; next }
	/^# AUTO-SUMS-END$/ { in_sums=0; next }
	{ if (!in_sums) print }
' "$DIR/PKGBUILD" >"$DIR/PKGBUILD.next"
mv "$DIR/PKGBUILD.next" "$DIR/PKGBUILD"

tmpconf="$(mktemp)"
sed "s/^TAG=.*/TAG=${TAG}/" "$DIR/pkg.conf" >"$tmpconf"
mv "$tmpconf" "$DIR/pkg.conf"

if [ -x "$ROOT/scripts/gen-srcinfo.sh" ]; then
	sh "$ROOT/scripts/gen-srcinfo.sh" "$NAME" || true
fi

log "Updated $NAME to $TAG ($VER)"
