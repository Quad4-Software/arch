#!/bin/sh
# Runs inside the pinned Arch Linux container to refresh repo databases.

set -eu

REPO_NAME="${REPO_NAME:?}"
CARCH="${CARCH:?}"
GPGKEY="${GPGKEY:-}"

pacman -Syu --noconfirm --needed pacman gnupg
if ! id -u builder >/dev/null 2>&1; then
	useradd -m -u 10000 builder
fi
chown -R builder:builder /repo

sign_flags=""
if [ -n "$GPGKEY" ]; then
	if [ -n "${PACKAGER_GPG_PRIVATE_KEY:-}" ]; then
		mkdir -p /home/builder/.gnupg
		chmod 700 /home/builder/.gnupg
		printf '%s\n' "$PACKAGER_GPG_PRIVATE_KEY" >/tmp/quad4-private.asc
		chmod 600 /tmp/quad4-private.asc
		GNUPGHOME=/home/builder/.gnupg gpg --batch --import /tmp/quad4-private.asc
		chown -R builder:builder /home/builder/.gnupg
		rm -f /tmp/quad4-private.asc
		sign_flags="-s -k $GPGKEY"
	else
		echo "GPGKEY set but PACKAGER_GPG_PRIVATE_KEY not set; signing disabled" >&2
	fi
fi

# shellcheck disable=SC2086
su -s /bin/sh builder -c "cd /repo && export GPGKEY='$GPGKEY' && repo-add -R $sign_flags ${REPO_NAME}.db.tar.gz /repo/*.pkg.tar.zst"
# GitHub Releases cannot host symlinks. Duplicate db files as regular files.
rm -f "/repo/${REPO_NAME}.db" "/repo/${REPO_NAME}.files"
cp -f "/repo/${REPO_NAME}.db.tar.gz" "/repo/${REPO_NAME}.db"
cp -f "/repo/${REPO_NAME}.files.tar.gz" "/repo/${REPO_NAME}.files"
if [ -n "$sign_flags" ]; then
	[ -e "/repo/${REPO_NAME}.db.sig" ] || cp -f "/repo/${REPO_NAME}.db.tar.gz.sig" "/repo/${REPO_NAME}.db.sig"
	[ -e "/repo/${REPO_NAME}.files.sig" ] || cp -f "/repo/${REPO_NAME}.files.tar.gz.sig" "/repo/${REPO_NAME}.files.sig"
fi
rm -f /repo/*.old /repo/*.old.sig
