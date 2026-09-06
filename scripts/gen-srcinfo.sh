#!/bin/sh
# Write .SRCINFO from PKGBUILD using makepkg --printsrcinfo.

set -eu

ROOT="$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/lib.sh"
load_repo_conf

NAME="${1:-}"
[ -n "$NAME" ] || die "usage: gen-srcinfo.sh NAME"
[ -f "$ROOT/pkg/$NAME/PKGBUILD" ] || die "missing PKGBUILD for $NAME"

FORCE_DOCKER="${FORCE_DOCKER:-0}"

if [ "$FORCE_DOCKER" != "1" ] && command -v makepkg >/dev/null 2>&1; then
	(
		cd "$ROOT/pkg/$NAME"
		makepkg --printsrcinfo >.SRCINFO
		chmod 644 .SRCINFO
	)
	log "wrote pkg/$NAME/.SRCINFO"
	exit 0
fi

need_cmd docker
img="$(docker_image)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
docker run --rm \
	-v "$ROOT/pkg/$NAME:/pkg" \
	"$img" \
	/bin/sh -c "
pacman -Syu --noconfirm --needed pacman >/dev/null
useradd -m -u 10000 builder
mkdir -p /tmp/work && cp -a /pkg /tmp/work/pkg
chown -R builder:builder /tmp/work/pkg
su -s /bin/sh builder -c 'cd /tmp/work/pkg && makepkg --printsrcinfo' > /tmp/work/pkg/.SRCINFO
cp -a /tmp/work/pkg/.SRCINFO /pkg/.SRCINFO
chmod 644 /pkg/.SRCINFO
"
log "wrote pkg/$NAME/.SRCINFO"
