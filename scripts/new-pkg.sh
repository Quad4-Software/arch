#!/bin/sh
# Scaffold a new package under pkg/.
#
# Usage:
#   new-pkg.sh NAME --kind binary --github OWNER/REPO --tag vX.Y.Z
#   new-pkg.sh NAME --kind git --github OWNER/REPO [--branch master]

set -eu

ROOT="$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/lib.sh"
load_repo_conf

NAME=""
KIND=""
GITHUB=""
TAG=""
BRANCH="master"

usage() {
	cat <<'EOF'
Usage:
  new-pkg.sh NAME --kind binary --github OWNER/REPO --tag vX.Y.Z
  new-pkg.sh NAME --kind git --github OWNER/REPO [--branch master]
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
	--kind)
		KIND="$2"
		shift 2
		;;
	--github)
		GITHUB="$2"
		shift 2
		;;
	--tag)
		TAG="$2"
		shift 2
		;;
	--branch)
		BRANCH="$2"
		shift 2
		;;
	-h|--help)
		usage
		exit 0
		;;
	--*)
		die "unknown option: $1"
		;;
	*)
		if [ -z "$NAME" ]; then
			NAME="$1"
			shift
		else
			die "unexpected argument: $1"
		fi
		;;
	esac
done

[ -n "$NAME" ] || die "missing NAME"
[ -n "$KIND" ] || die "missing --kind"
[ -n "$GITHUB" ] || die "missing --github"
case "$KIND" in
binary|git) ;;
*) die "--kind must be binary or git" ;;
esac
echo "$NAME" | grep -Eq '^[a-z0-9][a-z0-9+._-]*$' || die "invalid package name: $NAME"
[ ! -e "$ROOT/pkg/$NAME" ] || die "pkg/$NAME already exists"

if [ "$KIND" = "binary" ]; then
	[ -n "$TAG" ] || die "binary packages require --tag"
fi

mkdir -p "$ROOT/pkg/$NAME"
case "$KIND" in
binary)
	cat >"$ROOT/pkg/$NAME/pkg.conf" <<EOF
KIND=binary
GITHUB=$GITHUB
TAG=$TAG
ASSET_x86_64=${NAME}-linux-amd64
ASSET_aarch64=${NAME}-linux-arm64
ASSET_armv7h=${NAME}-linux-arm
SOURCE_TARBALL=1
CONFLICTS=${NAME}-git
PROVIDES=$NAME
EOF
	sed -e "s/@NAME@/${NAME}/g" -e "s/@GITHUB@/${GITHUB}/g" \
		"$ROOT/scripts/templates/PKGBUILD.binary" >"$ROOT/pkg/$NAME/PKGBUILD"
	sed -e "s/@NAME@/${NAME}/g" \
		"$ROOT/scripts/templates/install.binary" >"$ROOT/pkg/$NAME/${NAME}.install"
	log "Created pkg/$NAME (binary). Edit ASSET_* in pkg.conf then run: scripts/bump-binary.sh $NAME $TAG"
	;;
git)
	cat >"$ROOT/pkg/$NAME/pkg.conf" <<EOF
KIND=git
GITHUB=$GITHUB
BRANCH=$BRANCH
CONFLICTS=$NAME
PROVIDES=$NAME
EOF
	sed -e "s/@NAME@/${NAME}/g" -e "s/@GITHUB@/${GITHUB}/g" -e "s/@BRANCH@/${BRANCH}/g" \
		"$ROOT/scripts/templates/PKGBUILD.git" >"$ROOT/pkg/$NAME/PKGBUILD"
	sed -e "s/@NAME@/${NAME}/g" \
		"$ROOT/scripts/templates/install.git" >"$ROOT/pkg/$NAME/${NAME}.install"
	log "Created pkg/$NAME (git). Adjust PKGBUILD build() for that project."
	;;
esac
