#!/bin/sh
# Detect newer upstream releases and Arch image pins, apply bumps in-tree.
# Binary bumps verify cosign/SLSA attestations via bump-binary.sh.
#
# Usage: auto-bump.sh
# Writes GitHub Actions outputs when GITHUB_OUTPUT is set:
#   changed=true|false
#   summary=<human summary>

set -eu

ROOT="$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/lib.sh"
load_repo_conf

need_cmd curl
need_cmd gh
need_cmd python3

CHANGED=0
SUMMARY=""

append_summary() {
	if [ -n "$SUMMARY" ]; then
		SUMMARY="${SUMMARY}; $1"
	else
		SUMMARY="$1"
	fi
}

write_outputs() {
	changed="$1"
	summary="$2"
	if [ -z "${GITHUB_OUTPUT:-}" ]; then
		return 0
	fi
	{
		printf 'changed=%s\n' "$changed"
		printf 'summary<<EOF\n'
		printf '%s\n' "$summary"
		printf 'EOF\n'
	} >>"$GITHUB_OUTPUT"
}

bump_binary_packages() {
	for name in $(list_packages); do
		load_pkg_conf "$name"
		[ "$KIND" = "binary" ] || continue
		[ -n "${TAG:-}" ] || die "$name: binary pkg.conf missing TAG"
		[ -n "${VERIFY:-}" ] || die "$name: binary pkg.conf missing VERIFY"

		latest="$(gh api "repos/${GITHUB}/releases/latest" --jq '.tag_name')"
		[ -n "$latest" ] || die "$name: empty latest release tag from ${GITHUB}"

		if [ "$latest" = "$TAG" ]; then
			log "$name: already at $TAG"
			continue
		fi

		log "$name: $TAG -> $latest"
		sh "$ROOT/scripts/bump-binary.sh" "$name" "$latest"
		CHANGED=1
		append_summary "${name} ${TAG} -> ${latest}"
	done
}

verify_arch_digest() {
	tag="$1"
	want="$2"
	detail="$(mktemp)"
	curl -fsSL --retry 3 --retry-delay 2 \
		"https://hub.docker.com/v2/repositories/library/archlinux/tags/${tag}" \
		>"$detail"
	got="$(python3 - "$detail" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
	data = json.load(f)
digest = data.get("digest") or ""
if not digest.startswith("sha256:"):
	raise SystemExit("tag detail missing sha256 digest")
print(digest)
PY
	)"
	rm -f "$detail"
	[ "$got" = "$want" ] || die "Arch image digest mismatch for ${tag}: list=$want detail=$got"
	log "arch image digest verified for $tag"
}

write_ci_pins() {
	new_tag="$1"
	new_digest="$2"
	cat >"$ROOT/conf/ci-pins.env" <<EOF
# Pinned CI images. Bump tag and digest together.
# Official Arch Linux docker image: https://hub.docker.com/_/archlinux
#
#   archlinux:${new_tag}
#   digest ${new_digest}

ARCHLINUX_IMAGE=docker.io/library/archlinux:${new_tag}
ARCHLINUX_DIGEST=${new_digest}

# Release verification tools (linux-amd64). Bump version and sha256 together.
COSIGN_VERSION=${COSIGN_VERSION}
COSIGN_SHA256=${COSIGN_SHA256}
SLSA_VERIFIER_VERSION=${SLSA_VERIFIER_VERSION}
SLSA_VERIFIER_SHA256=${SLSA_VERIFIER_SHA256}
EOF
}

bump_arch_image() {
	hub_json="$(mktemp)"
	curl -fsSL --retry 3 --retry-delay 2 \
		"https://hub.docker.com/v2/repositories/library/archlinux/tags?page_size=50&ordering=last_updated&name=base-devel-" \
		>"$hub_json"

	parsed="$(python3 - "$hub_json" <<'PY'
import json
import re
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
	data = json.load(f)

pat = re.compile(r"^base-devel-\d{8}\.\d+\.\d+$")
for row in data.get("results", []):
	name = row.get("name") or ""
	digest = row.get("digest") or ""
	if pat.match(name) and digest.startswith("sha256:"):
		print(f"{name} {digest}")
		raise SystemExit(0)
raise SystemExit("no dated base-devel tag found on Docker Hub")
PY
	)"
	rm -f "$hub_json"

	new_tag="${parsed%% *}"
	new_digest="${parsed#* }"
	if [ -z "$new_tag" ] || [ -z "$new_digest" ]; then
		die "failed to parse Arch image pin"
	fi

	verify_arch_digest "$new_tag" "$new_digest"

	current_ref="${ARCHLINUX_IMAGE##*:}"
	if [ "$current_ref" = "$new_tag" ] && [ "$ARCHLINUX_DIGEST" = "$new_digest" ]; then
		log "arch image: already at $new_tag"
		return 0
	fi

	log "arch image: $current_ref -> $new_tag"
	write_ci_pins "$new_tag" "$new_digest"
	CHANGED=1
	append_summary "archlinux ${current_ref} -> ${new_tag}"
}

log "==> binary packages"
bump_binary_packages

log "==> archlinux image"
bump_arch_image

if [ "$CHANGED" -eq 0 ]; then
	log "no bumps needed"
	write_outputs false "no bumps needed"
	exit 0
fi

log "bumped: $SUMMARY"
write_outputs true "$SUMMARY"
