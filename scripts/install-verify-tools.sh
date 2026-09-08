#!/bin/sh
# Install pinned cosign and slsa-verifier into DEST (default: .tools).
#
# Usage: install-verify-tools.sh [DEST]

set -eu

ROOT="$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/lib.sh"
load_repo_conf

need_cmd curl
need_cmd sha256sum

DEST="${1:-$ROOT/.tools}"
mkdir -p "$DEST"

download_pin() {
	name="$1"
	url="$2"
	want_sum="$3"
	out="$DEST/$name"
	if [ -x "$out" ]; then
		got="$(sha256sum "$out" | awk '{print $1}')"
		if [ "$got" = "$want_sum" ]; then
			log "have $name ($want_sum)"
			return 0
		fi
		log "replacing $name (checksum mismatch)"
	fi
	tmp="$(mktemp)"
	log "GET $url"
	curl -fsSL --retry 3 --retry-delay 2 -o "$tmp" "$url"
	got="$(sha256sum "$tmp" | awk '{print $1}')"
	[ "$got" = "$want_sum" ] || die "$name sha256 mismatch: got $got want $want_sum"
	mv "$tmp" "$out"
	chmod 755 "$out"
	log "installed $name"
}

build_slsa_verifier() {
	out="$DEST/slsa-verifier"
	repo="${SLSA_VERIFIER_BUILD_REPO:-https://github.com/kipz/slsa-verifier.git}"
	commit="${SLSA_VERIFIER_COMMIT:?}"
	ver="${SLSA_VERIFIER_VERSION:?}"

	if [ -x "$out" ]; then
		if "$out" version | grep -q "GitVersion:.*$ver" && \
		   "$out" version | grep -q "GitCommit:.*$commit"; then
			log "have slsa-verifier $ver ($commit)"
			return 0
		fi
		log "rebuilding slsa-verifier"
	fi

	need_cmd git
	need_cmd go

	tmpdir="$(mktemp -d)"
	trap 'rm -rf "$tmpdir"' EXIT

	log "clone slsa-verifier $commit"
	(
		cd "$tmpdir"
		git init -q slsa-verifier
		cd slsa-verifier
		git remote add origin "$repo"
		git fetch -q --depth 1 origin "$commit"
		git checkout -q "$commit"
	)

	log "apply builder-repo patch"
	git -C "$tmpdir/slsa-verifier" apply "$ROOT/scripts/patches/slsa-verifier-builder-repo.patch"

	build_date="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
	ldflags="-X sigs.k8s.io/release-utils/version.gitVersion=$ver \
		-X sigs.k8s.io/release-utils/version.gitCommit=$commit \
		-X sigs.k8s.io/release-utils/version.gitTreeState=clean \
		-X sigs.k8s.io/release-utils/version.buildDate=$build_date"

	(
		cd "$tmpdir/slsa-verifier"
		go build -buildvcs=false -ldflags "$ldflags" -o "$out" ./cli/slsa-verifier
	)
	chmod 755 "$out"

	if ! "$out" version | grep -q "GitVersion:.*$ver"; then
		die "slsa-verifier version mismatch"
	fi
	if ! "$out" version | grep -q "GitCommit:.*$commit"; then
		die "slsa-verifier commit mismatch"
	fi
	log "built slsa-verifier $ver ($commit)"
}

: "${COSIGN_VERSION:?}"
: "${COSIGN_SHA256:?}"
: "${SLSA_VERIFIER_VERSION:?}"

download_pin cosign \
	"https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-amd64" \
	"$COSIGN_SHA256"

if [ "${SLSA_VERIFIER_BUILD:-}" = "1" ]; then
	: "${SLSA_VERIFIER_COMMIT:?}"
	build_slsa_verifier
else
	: "${SLSA_VERIFIER_SHA256:?}"
	download_pin slsa-verifier \
		"https://github.com/slsa-framework/slsa-verifier/releases/download/${SLSA_VERIFIER_VERSION}/slsa-verifier-linux-amd64" \
		"$SLSA_VERIFIER_SHA256"
fi

printf '%s\n' "$DEST"
