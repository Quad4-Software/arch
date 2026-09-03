#!/bin/sh
# Upload per-arch repo trees to rolling GitHub Releases named repo-\$arch.
# Recreates each release because published releases may be immutable.
# Deletes the git tag too so the same rolling tag name can be reused.

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
TARGET="${GITHUB_SHA:-${GITHUB_REF_NAME:-master}}"

remove_rolling_tag() {
	tag="$1"
	if gh release view "$tag" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
		log "removing release $tag for republish"
		gh release delete "$tag" --repo "$GITHUB_REPOSITORY" --yes --cleanup-tag
	fi
	# Immutable releases can leave a tag that blocks recreate even after delete.
	if gh api "repos/${GITHUB_REPOSITORY}/git/ref/tags/${tag}" >/dev/null 2>&1; then
		log "removing leftover tag $tag"
		gh api --method DELETE "repos/${GITHUB_REPOSITORY}/git/refs/tags/${tag}" >/dev/null
	fi
}

upload_arch() {
	arch="$1"
	dir="$ROOT/repo/$arch"
	[ -d "$dir" ] || die "missing repo/$arch"
	tag="${PREFIX}-${arch}"
	notes="$(mktemp)"
	printf '%s\n' "Pacman database and packages for ${arch}." >"$notes"
	printf '%s\n' "Server = https://github.com/${GITHUB_REPOSITORY}/releases/download/${tag}" >>"$notes"

	assets="$(find "$dir" -maxdepth 1 -type f ! -name '*.old' | LC_ALL=C sort)"
	[ -n "$assets" ] || die "no assets under repo/$arch"

	remove_rolling_tag "$tag"

	log "creating release $tag"
	# Draft first so assets can upload before immutability locks the release.
	# shellcheck disable=SC2086
	gh release create "$tag" $assets \
		--repo "$GITHUB_REPOSITORY" \
		--target "$TARGET" \
		--title "$tag" \
		--notes-file "$notes" \
		--latest=false \
		--draft
	gh release edit "$tag" --repo "$GITHUB_REPOSITORY" --draft=false
	rm -f "$notes"
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
