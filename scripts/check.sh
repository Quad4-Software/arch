#!/bin/sh
# Validate PKGBUILDs, pkg.conf files, and shell scripts.

set -eu

ROOT="$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/lib.sh"
load_repo_conf

need_cmd grep
need_cmd sed

FAILED=0

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	FAILED=1
}

check_pkg() {
	name="$1"
	dir="$ROOT/pkg/$name"
	load_pkg_conf "$name"
	[ -f "$dir/PKGBUILD" ] || fail "$name: missing PKGBUILD"
	grep -q "^pkgname=${name}$" "$dir/PKGBUILD" || fail "$name: PKGBUILD pkgname mismatch"
	grep -q '^pkgver=' "$dir/PKGBUILD" || fail "$name: PKGBUILD missing pkgver"
	grep -q '^pkgrel=' "$dir/PKGBUILD" || fail "$name: PKGBUILD missing pkgrel"
	grep -q "install=${name}.install" "$dir/PKGBUILD" || fail "$name: PKGBUILD missing install="
	[ -f "$dir/${name}.install" ] || fail "$name: missing ${name}.install"
	case "$KIND" in
	binary)
		[ -n "${TAG:-}" ] || fail "$name: binary pkg.conf missing TAG"
		[ -n "${VERIFY:-}" ] || fail "$name: binary pkg.conf missing VERIFY"
		case "${VERIFY}" in
		cosign)
			[ -n "${COSIGN_PUB:-}" ] || fail "$name: VERIFY=cosign needs COSIGN_PUB"
			[ -f "$ROOT/$COSIGN_PUB" ] || fail "$name: missing $COSIGN_PUB"
			;;
		slsa)
			[ -n "${SLSA_PROVENANCE:-}" ] || fail "$name: VERIFY=slsa needs SLSA_PROVENANCE"
			[ -n "${SLSA_SOURCE_URI:-}" ] || fail "$name: VERIFY=slsa needs SLSA_SOURCE_URI"
			;;
		sha256sums)
			[ -n "${SHA256SUMS:-}" ] || fail "$name: VERIFY=sha256sums needs SHA256SUMS"
			;;
		none) ;;
		*)
			fail "$name: unknown VERIFY=${VERIFY}"
			;;
		esac
		grep -q '# AUTO-SUMS-BEGIN' "$dir/PKGBUILD" || fail "$name: missing AUTO-SUMS markers"
		if [ -n "${CONFLICTS:-}" ]; then
			grep -q "conflicts=('${CONFLICTS}')" "$dir/PKGBUILD" || fail "$name: conflicts mismatch"
		fi
		;;
	git)
		[ -n "${BRANCH:-}" ] || fail "$name: git pkg.conf missing BRANCH"
		grep -q "sha256sums=('SKIP')" "$dir/PKGBUILD" || fail "$name: git PKGBUILD must SKIP checksums"
		grep -q '^pkgver()' "$dir/PKGBUILD" || fail "$name: git PKGBUILD missing pkgver()"
		;;
	python)
		[ -n "${PYPI_NAME:-}" ] || fail "$name: python pkg.conf missing PYPI_NAME"
		[ -n "${VERSION:-}" ] || fail "$name: python pkg.conf missing VERSION"
		grep -q '# AUTO-SUMS-BEGIN' "$dir/PKGBUILD" || fail "$name: missing AUTO-SUMS markers"
		grep -q "arch=('any')" "$dir/PKGBUILD" || fail "$name: python PKGBUILD must be arch=any"
		;;
	*)
		fail "$name: unknown KIND=$KIND"
		;;
	esac
}

log "==> packages"
count=0
for pkg in $(list_packages); do
	log "  $pkg"
	check_pkg "$pkg"
	count=$((count + 1))
done
[ "$count" -gt 0 ] || fail "no packages under pkg/"

log "==> repo.conf"
[ -n "${REPO_NAME:-}" ] || fail "REPO_NAME empty"
[ -n "${PAGES_URL:-}" ] || fail "PAGES_URL empty"

log "==> pacman snippet"
[ -f "$ROOT/conf/pacman-quad4.conf" ] || fail "missing conf/pacman-quad4.conf"
grep -q "^\\[${REPO_NAME}\\]" "$ROOT/conf/pacman-quad4.conf" || fail "pacman snippet missing [$REPO_NAME]"

log "==> trust pins"
[ -n "${COSIGN_VERSION:-}" ] || fail "ci-pins.env missing COSIGN_VERSION"
[ -n "${COSIGN_SHA256:-}" ] || fail "ci-pins.env missing COSIGN_SHA256"
[ -n "${SLSA_VERIFIER_VERSION:-}" ] || fail "ci-pins.env missing SLSA_VERIFIER_VERSION"
[ -n "${SLSA_VERIFIER_SHA256:-}" ] || fail "ci-pins.env missing SLSA_VERIFIER_SHA256"
[ -f "$ROOT/keys/upstream/reticulum-go.cosign.pub" ] || fail "missing keys/upstream/reticulum-go.cosign.pub"
[ -f "$ROOT/keys/upstream/meshchatx.cosign.pub" ] || fail "missing keys/upstream/meshchatx.cosign.pub"

if command -v shellcheck >/dev/null 2>&1; then
	log "==> shellcheck"
	# shellcheck disable=SC2046
	shellcheck -x "$ROOT"/scripts/*.sh "$ROOT"/pkg/*/*.install || fail "shellcheck reported issues"
else
	log "==> shellcheck skipped (not installed)"
fi

if [ "$FAILED" -ne 0 ]; then
	die "checks failed"
fi
log "OK"
