#!/bin/sh
# Copy built packages into repo/\$arch and run repo-add.
#
# Usage: repo-add.sh [arch ...]

set -eu

ROOT="$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/lib.sh"
load_repo_conf

FORCE_DOCKER="${FORCE_DOCKER:-0}"

sync_arch() {
	arch="$1"
	src="$ROOT/out/$arch"
	dst="$ROOT/repo/$arch"
	mkdir -p "$dst"
	[ -d "$src" ] || die "no packages in out/$arch (run makepkg.sh first)"
	found=0
	for f in "$src"/*.pkg.tar.zst; do
		[ -f "$f" ] || continue
		found=1
		cp -a "$f" "$dst/"
		if [ -f "${f}.sig" ]; then
			cp -a "${f}.sig" "$dst/"
		fi
	done
	[ "$found" -eq 1 ] || die "no .pkg.tar.zst files in out/$arch"

	log "==> repo-add $REPO_NAME ($arch)"
	if [ "$FORCE_DOCKER" = "1" ] || ! have_native_makepkg; then
		need_cmd docker
		img="$(docker_image)"
		docker run --rm \
			-e REPO_NAME="$REPO_NAME" \
			-e CARCH="$arch" \
			-v "$ROOT:/src:ro" \
			-v "$dst:/repo" \
			"$img" \
			/bin/sh /src/scripts/repo-add-inner.sh
	else
		need_cmd repo-add
		(
			cd "$dst"
			repo-add -R "${REPO_NAME}.db.tar.gz" ./*.pkg.tar.zst
			rm -f "${REPO_NAME}.db" "${REPO_NAME}.files"
			cp -f "${REPO_NAME}.db.tar.gz" "${REPO_NAME}.db"
			cp -f "${REPO_NAME}.files.tar.gz" "${REPO_NAME}.files"
			rm -f ./*.old
		)
	fi
}

if [ $# -gt 0 ]; then
	arches="$*"
else
	arches=""
	for d in "$ROOT"/out/*; do
		[ -d "$d" ] || continue
		arches="$arches $(basename "$d")"
	done
	[ -n "$arches" ] || die "out/ is empty"
fi

for arch in $arches; do
	sync_arch "$arch"
done

log "repo tree:"
find "$ROOT/repo" -type f | LC_ALL=C sort
