#!/bin/sh
# Runs inside the pinned Arch Linux container to refresh repo databases.

set -eu

REPO_NAME="${REPO_NAME:?}"
CARCH="${CARCH:?}"

pacman -Syu --noconfirm --needed pacman
if ! id -u builder >/dev/null 2>&1; then
	useradd -m -u 10000 builder
fi
chown -R builder:builder /repo
su -s /bin/sh builder -c "cd /repo && repo-add -R ${REPO_NAME}.db.tar.gz /repo/*.pkg.tar.zst"
# GitHub Releases cannot host symlinks. Duplicate db files as regular files.
rm -f "/repo/${REPO_NAME}.db" "/repo/${REPO_NAME}.files"
cp -f "/repo/${REPO_NAME}.db.tar.gz" "/repo/${REPO_NAME}.db"
cp -f "/repo/${REPO_NAME}.files.tar.gz" "/repo/${REPO_NAME}.files"
rm -f /repo/*.old
