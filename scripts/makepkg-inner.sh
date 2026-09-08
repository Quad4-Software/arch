#!/bin/sh
# Runs inside the pinned Arch Linux container. Not invoked on the host.

set -eu

PKG_NAME="${PKG_NAME:?}"
CARCH="${CARCH:?}"
KIND="${KIND:?}"
PACKAGER="${PACKAGER:-Quad4.io <ivan@quad4.io>}"
GPGKEY="${GPGKEY:-}"

pacman -Syu --noconfirm --needed base-devel git sudo gnupg
MAKEPKG_FLAGS='-sf --noconfirm --skippgpcheck --cleanbuild'
case "$KIND" in
git)
	pacman -S --noconfirm --needed git go
	;;
python)
	# Runtime depends may be other Quad4 packages not in official repos.
	# Install build backends here and skip pacman dep resolution.
	pacman -S --noconfirm --needed \
		python python-build python-installer python-wheel python-setuptools \
		python-hatchling python-poetry-core
	MAKEPKG_FLAGS='-df --noconfirm --skippgpcheck --cleanbuild'
	;;
esac

if ! id -u builder >/dev/null 2>&1; then
	useradd -m -u 10000 builder
fi
printf '%s\n' 'builder ALL=(ALL) NOPASSWD: /usr/bin/pacman' >/etc/sudoers.d/builder
chmod 440 /etc/sudoers.d/builder
mkdir -p /home/builder/src /out
rm -rf /home/builder/pkg
cp -a "/src/pkg/${PKG_NAME}" /home/builder/pkg
chown -R builder:builder /home/builder /out

if [ -n "$GPGKEY" ]; then
	MAKEPKG_FLAGS="${MAKEPKG_FLAGS} --sign"
fi

cat >/home/builder/run.sh <<INNER
set -eu
cd /home/builder/pkg
export PKGDEST=/out
export SRCDEST=/home/builder/src
export GPGKEY="$GPGKEY"
if [ -n "\${PACKAGER_GPG_PRIVATE_KEY:-}" ]; then
	mkdir -p \$HOME/.gnupg
	chmod 700 \$HOME/.gnupg
	printf '%s\\n' "\$PACKAGER_GPG_PRIVATE_KEY" >/tmp/quad4-private.asc
	chmod 600 /tmp/quad4-private.asc
	gpg --batch --import /tmp/quad4-private.asc
	rm -f /tmp/quad4-private.asc
fi
# shellcheck disable=SC2086
makepkg ${MAKEPKG_FLAGS}
INNER
chown builder:builder /home/builder/run.sh
chmod 755 /home/builder/run.sh

env PACKAGER="$PACKAGER" CARCH="$CARCH" GPGKEY="$GPGKEY" PACKAGER_GPG_PRIVATE_KEY="${PACKAGER_GPG_PRIVATE_KEY:-}" su -s /bin/sh builder -c /home/builder/run.sh
