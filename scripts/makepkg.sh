#!/bin/sh
# Build one or more packages with makepkg.
# Native Arch uses host makepkg. Otherwise a pinned Arch Linux container.
#
# Usage:
#   makepkg.sh                     build every package for host arch
#   makepkg.sh reticulum-go        one package
#   makepkg.sh reticulum-go-bin aarch64
# Env:
#   FORCE_DOCKER=1   always use the pinned container
#   PACKAGER         packager string for .PKGINFO

set -eu

ROOT="$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/lib.sh"
load_repo_conf

PKG_FILTER="${1:-}"
ARCH_FILTER="${2:-}"
FORCE_DOCKER="${FORCE_DOCKER:-0}"
PACKAGER="${PACKAGER:-${REPO_PACKAGER:-$REPO_MAINTAINER}}"
GPGKEY="${GPGKEY:-${REPO_GPGKEY:-}}"
SIGN_MAKEPKG="${SIGN_MAKEPKG:-0}"

host_arch="$(uname -m)"
case "$host_arch" in
x86_64|aarch64|armv7l|armv7h) ;;
*) host_arch=x86_64 ;;
esac
if [ "$host_arch" = "armv7l" ]; then
	host_arch=armv7h
fi

use_docker() {
	if [ "$FORCE_DOCKER" = "1" ]; then
		return 0
	fi
	if have_native_makepkg; then
		return 1
	fi
	return 0
}

gpg_secret_in_keyring() {
	[ -n "${GPGKEY:-}" ] || return 1
	gpg --list-secret-keys --with-colons "$GPGKEY" >/dev/null 2>&1
}

maybe_sign_makepkg() {
	if [ -z "${GPGKEY:-}" ]; then
		SIGN_MAKEPKG=0
		return
	fi
	if use_docker; then
		if [ -n "${PACKAGER_GPG_PRIVATE_KEY:-}" ]; then
			SIGN_MAKEPKG=1
		fi
		return
	fi
	if gpg_secret_in_keyring; then
		SIGN_MAKEPKG=1
	else
		log "    GPG key $GPGKEY not in local keyring; package signing disabled"
		SIGN_MAKEPKG=0
	fi
}

build_one() {
	name="$1"
	arch="$2"
	load_pkg_conf "$name"
	outdir="$ROOT/out/$arch"
	mkdir -p "$outdir"
	log "==> makepkg $name ($arch) kind=$KIND"
	maybe_sign_makepkg

	if use_docker; then
		need_cmd docker
		img="$(docker_image)"
		log "    image $img"
		if [ "$SIGN_MAKEPKG" = "1" ]; then
			docker run --rm \
				-e "PKG_NAME=$name" \
				-e "CARCH=$arch" \
				-e "KIND=$KIND" \
				-e "PACKAGER=$PACKAGER" \
				-e "GPGKEY=$GPGKEY" \
				-e "PACKAGER_GPG_PRIVATE_KEY" \
				-v "$ROOT:/src:ro" \
				-v "$outdir:/out" \
				"$img" \
				/bin/sh /src/scripts/makepkg-inner.sh
		else
			docker run --rm \
				-e "PKG_NAME=$name" \
				-e "CARCH=$arch" \
				-e "KIND=$KIND" \
				-e "PACKAGER=$PACKAGER" \
				-v "$ROOT:/src:ro" \
				-v "$outdir:/out" \
				"$img" \
				/bin/sh /src/scripts/makepkg-inner.sh
		fi
	else
		need_cmd makepkg
		(
			cd "$ROOT/pkg/$name"
			export CARCH="$arch"
			export PACKAGER
			export GPGKEY
			export PKGDEST="$outdir"
			sign_flag=""
			[ "$SIGN_MAKEPKG" = "1" ] && sign_flag="--sign"
			# Python runtime depends may be Quad4 packages not yet installed.
			# shellcheck disable=SC2086
			if [ "$KIND" = "python" ]; then
				makepkg -df --noconfirm --skippgpcheck --cleanbuild $sign_flag
			else
				makepkg -f --noconfirm --skippgpcheck --cleanbuild $sign_flag
			fi
		)
	fi
}

if [ -n "$PKG_FILTER" ]; then
	pkgs="$PKG_FILTER"
else
	pkgs="$(list_packages)"
fi

for name in $pkgs; do
	load_pkg_conf "$name"
	if [ -n "$ARCH_FILTER" ]; then
		arches="$ARCH_FILTER"
	elif [ -n "${ARCHES:-}" ]; then
		arches="$ARCHES"
	elif [ "$KIND" = "binary" ]; then
		arches="x86_64 aarch64 armv7h"
	elif [ "$KIND" = "python" ]; then
		arches="x86_64"
	else
		arches="$host_arch"
	fi
	for arch in $arches; do
		build_one "$name" "$arch"
	done
done

log "packages in $ROOT/out/"
find "$ROOT/out" -type f -name '*.pkg.tar.*' | LC_ALL=C sort
