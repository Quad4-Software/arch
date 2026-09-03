#!/bin/sh
# Verify a downloaded release blob using package VERIFY settings.
#
# Usage:
#   verify-asset.sh --mode cosign --blob PATH --bundle PATH --key PATH
#   verify-asset.sh --mode slsa --blob PATH --provenance PATH --source-uri URI --source-tag TAG
#
# Env:
#   COSIGN / SLSA_VERIFIER  paths to binaries (or on PATH)
#   QUAD4_TOOLS             directory from install-verify-tools.sh

set -eu

ROOT="$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/lib.sh"

MODE=""
BLOB=""
BUNDLE=""
KEY=""
PROVENANCE=""
SOURCE_URI=""
SOURCE_TAG=""

usage() {
	die "usage: verify-asset.sh --mode cosign|slsa ..."
}

while [ $# -gt 0 ]; do
	case "$1" in
	--mode)
		MODE="${2:-}"
		shift 2
		;;
	--blob)
		BLOB="${2:-}"
		shift 2
		;;
	--bundle)
		BUNDLE="${2:-}"
		shift 2
		;;
	--key)
		KEY="${2:-}"
		shift 2
		;;
	--provenance)
		PROVENANCE="${2:-}"
		shift 2
		;;
	--source-uri)
		SOURCE_URI="${2:-}"
		shift 2
		;;
	--source-tag)
		SOURCE_TAG="${2:-}"
		shift 2
		;;
	-h | --help)
		usage
		;;
	*)
		die "unknown argument: $1"
		;;
	esac
done

[ -n "$MODE" ] || usage
[ -n "$BLOB" ] || usage
[ -f "$BLOB" ] || die "blob not found: $BLOB"

resolve_tool() {
	name="$1"
	case "$name" in
	cosign)
		if [ -n "${COSIGN:-}" ] && [ -x "$COSIGN" ]; then
			printf '%s\n' "$COSIGN"
			return 0
		fi
		;;
	slsa-verifier)
		if [ -n "${SLSA_VERIFIER:-}" ] && [ -x "$SLSA_VERIFIER" ]; then
			printf '%s\n' "$SLSA_VERIFIER"
			return 0
		fi
		;;
	esac
	if [ -n "${QUAD4_TOOLS:-}" ] && [ -x "${QUAD4_TOOLS}/${name}" ]; then
		printf '%s\n' "${QUAD4_TOOLS}/${name}"
		return 0
	fi
	if [ -x "$ROOT/.tools/${name}" ]; then
		printf '%s\n' "$ROOT/.tools/${name}"
		return 0
	fi
	if command -v "$name" >/dev/null 2>&1; then
		command -v "$name"
		return 0
	fi
	die "missing $name (run scripts/install-verify-tools.sh)"
}

case "$MODE" in
cosign)
	[ -n "$BUNDLE" ] || die "cosign mode needs --bundle"
	[ -n "$KEY" ] || die "cosign mode needs --key"
	[ -f "$BUNDLE" ] || die "bundle not found: $BUNDLE"
	[ -f "$KEY" ] || die "key not found: $KEY"
	cosign_bin="$(resolve_tool cosign)"
	log "cosign verify-blob-attestation $(basename "$BLOB")"
	"$cosign_bin" verify-blob-attestation \
		--insecure-ignore-tlog \
		--key "$KEY" \
		--bundle "$BUNDLE" \
		--type slsaprovenance1 \
		"$BLOB"
	;;
slsa)
	[ -n "$PROVENANCE" ] || die "slsa mode needs --provenance"
	[ -n "$SOURCE_URI" ] || die "slsa mode needs --source-uri"
	[ -n "$SOURCE_TAG" ] || die "slsa mode needs --source-tag"
	[ -f "$PROVENANCE" ] || die "provenance not found: $PROVENANCE"
	slsa_bin="$(resolve_tool slsa-verifier)"
	log "slsa-verifier verify-artifact $(basename "$BLOB")"
	"$slsa_bin" verify-artifact "$BLOB" \
		--provenance-path "$PROVENANCE" \
		--source-uri "$SOURCE_URI" \
		--source-tag "$SOURCE_TAG"
	;;
*)
	die "unknown verify mode: $MODE"
	;;
esac
