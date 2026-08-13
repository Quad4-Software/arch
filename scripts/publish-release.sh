#!/bin/sh
# Upload per-arch repo trees to rolling GitHub Releases named repo-\$arch.

set -eu

ROOT="$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/lib.sh"
load_repo_conf

need_cmd gh
GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
: "${GH_TOKEN:?GH_TOKEN or GITHUB_TOKEN is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
export GH_TOKEN

PREFIX="${RELEASE_PREFIX:-repo}"

upload_arch() {
	arch="$1"
	dir="$ROOT/repo/$arch"
	[ -d "$dir" ] || die "missing repo/$arch"
	tag="${PREFIX}-${arch}"
	notes="$(mktemp)"
	printf '%s\n' "Pacman database and packages for ${arch}." >"$notes"
	printf '%s\n' "Server = https://github.com/${GITHUB_REPOSITORY}/releases/download/${tag}" >>"$notes"
	if gh release view "$tag" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
		log "updating release $tag"
	else
		log "creating release $tag"
		gh release create "$tag" \
			--repo "$GITHUB_REPOSITORY" \
			--title "$tag" \
			--notes-file "$notes" \
			--latest=false
	fi
	rm -f "$notes"
	# shellcheck disable=SC2046
	gh release upload "$tag" --repo "$GITHUB_REPOSITORY" --clobber $(find "$dir" -maxdepth 1 -type f ! -name '*.old' | LC_ALL=C sort)
}

if [ $# -gt 0 ]; then
	arches="$*"
else
	arches=""
	for d in "$ROOT"/repo/*; do
		[ -d "$d" ] || continue
		arches="$arches $(basename "$d")"
	done
fi
[ -n "$arches" ] || die "repo/ has no architecture directories"

for arch in $arches; do
	upload_arch "$arch"
done
