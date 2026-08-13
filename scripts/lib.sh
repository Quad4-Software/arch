# Shared helpers for Quad4 Arch repo tools. Source this file from other scripts.
# shellcheck shell=sh

if [ -n "${QUAD4_LIB_LOADED:-}" ]; then
	return 0
fi
QUAD4_LIB_LOADED=1

quad4_root() {
	CDPATH='' cd -- "$(dirname "$0")/.." && pwd
}

ROOT="${ROOT:-$(quad4_root)}"

log() {
	printf '%s\n' "$*"
}

die() {
	printf 'ERROR: %s\n' "$*" >&2
	exit 1
}

need_cmd() {
	command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

load_repo_conf() {
	# shellcheck disable=SC1091
	. "$ROOT/conf/repo.conf"
	# shellcheck disable=SC1091
	. "$ROOT/conf/ci-pins.env"
	: "${REPO_NAME:?repo.conf missing REPO_NAME}"
	: "${ARCHLINUX_IMAGE:?ci-pins.env missing ARCHLINUX_IMAGE}"
	: "${ARCHLINUX_DIGEST:?ci-pins.env missing ARCHLINUX_DIGEST}"
}

load_pkg_conf() {
	_pkg="$1"
	_conf="$ROOT/pkg/${_pkg}/pkg.conf"
	[ -f "$_conf" ] || die "missing pkg.conf for ${_pkg}"
	KIND=
	GITHUB=
	TAG=
	BRANCH=
	SOURCE_TARBALL=
	CONFLICTS=
	PROVIDES=
	ASSET_x86_64=
	ASSET_aarch64=
	ASSET_armv7h=
	ARCHES=
	# shellcheck disable=SC1090
	. "$_conf"
	: "${KIND:?${_pkg} pkg.conf missing KIND}"
	: "${GITHUB:?${_pkg} pkg.conf missing GITHUB}"
	export KIND GITHUB TAG BRANCH SOURCE_TARBALL CONFLICTS PROVIDES
	export ASSET_x86_64 ASSET_aarch64 ASSET_armv7h ARCHES
}

list_packages() {
	for _d in "$ROOT"/pkg/*/pkg.conf; do
		[ -f "$_d" ] || continue
		basename "$(dirname "$_d")"
	done | LC_ALL=C sort
}

pkg_arches_binary() {
	printf '%s\n' x86_64 aarch64 armv7h
}

docker_image() {
	printf '%s@%s' "$ARCHLINUX_IMAGE" "$ARCHLINUX_DIGEST"
}

have_native_makepkg() {
	command -v makepkg >/dev/null 2>&1 && command -v repo-add >/dev/null 2>&1
}
