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

: "${COSIGN_VERSION:?}"
: "${COSIGN_SHA256:?}"
: "${SLSA_VERIFIER_VERSION:?}"
: "${SLSA_VERIFIER_SHA256:?}"

download_pin cosign \
	"https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-amd64" \
	"$COSIGN_SHA256"
download_pin slsa-verifier \
	"https://github.com/slsa-framework/slsa-verifier/releases/download/${SLSA_VERIFIER_VERSION}/slsa-verifier-linux-amd64" \
	"$SLSA_VERIFIER_SHA256"

printf '%s\n' "$DEST"
