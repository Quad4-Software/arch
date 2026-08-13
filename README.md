# Quad4 Arch repository

Arch pacman repository for Quad4 software.

Users add a `[quad4]` section to `/etc/pacman.conf` and install with `pacman -S`. Maintainers add packages under `pkg/`, CI builds them with `makepkg`, and `repo-add` writes `quad4.db.tar.gz` plus `quad4.files.tar.gz`.

## Add the repo (Arch / CachyOS)

Copy [conf/pacman-quad4.conf](conf/pacman-quad4.conf) into `/etc/pacman.conf` after the official `[core]` and `[extra]` blocks, then:

```bash
sudo pacman -Syu
sudo pacman -S reticulum-go meshchatx
```

`reticulum-go` is the prebuilt GitHub release binary. `reticulum-go-git` builds current `master` and conflicts with `reticulum-go`.

`meshchatx` wraps the GitHub release AppImage for `x86_64` and `aarch64`. `meshchatx-git` builds current `master` with Electron and conflicts with `meshchatx`.

Primary Server is `https://arch.quad4.io/$arch`. Fallback Server is a rolling GitHub Release named `repo-$arch`.

The repo is unsigned until a packaging key is added under `keys/quad4.gpg`. `SigLevel = Optional TrustAll` is required until then. After you sign packages and the database, switch that line to `SigLevel = Required` and import the public key.

Point DNS for `arch.quad4.io` at GitHub Pages:

```
arch.quad4.io  CNAME  quad4-software.github.io
```

This workflow publishes the site with GitHub Actions. Enable Pages once: repository Settings, Pages, source GitHub Actions. The first successful Publish run sets the custom domain and deploys `public/` (including `CNAME`). The `github-pages` environment is created on that first deploy.

## Layout

```
conf/           repo name, pinned Arch container digest, pacman snippet
pkg/            one directory per package (PKGBUILD, pkg.conf, .install)
scripts/        check, bump, makepkg, repo-add, Pages, GitHub Release
.github/        pinned Actions (full commit SHA)
```

`pkg/*/pkg.conf` is the catalog. `KIND=binary` wraps GitHub release assets. `KIND=git` clones and builds.

## Maintainer commands

On Arch, `makepkg` and `repo-add` run on the host. Anywhere else, scripts use the pinned `archlinux:base-devel` image from `conf/ci-pins.env`.

```bash
make check
make build
make repo
make pages
```

Bump a binary package when upstream tags a release:

```bash
sh scripts/bump-binary.sh reticulum-go v1.0.2
sh scripts/bump-binary.sh meshchatx v4.8.2
```

Add another Quad4 project:

```bash
sh scripts/new-pkg.sh other-tool --kind binary --github Quad4-Software/other-tool --tag v0.1.0
sh scripts/new-pkg.sh other-tool-git --kind git --github Quad4-Software/other-tool
```

Then edit the new `PKGBUILD` `package()` as needed and add a matrix row in `.github/workflows/ci.yml` and `publish.yml`.

Rebuild from another Quad4 repo after a release (classic PAT or GitHub App with `actions: write` on this repository):

```bash
gh api repos/Quad4-Software/arch/dispatches -f event_type=quad4-rebuild
```

## License

This repository (PKGBUILDs, scripts, and CI) is licensed under [0BSD](LICENSE).

Packaged software keeps its own license. `reticulum-go` and `reticulum-go-git` install Reticulum-Go, which is Apache-2.0. `meshchatx` and `meshchatx-git` install MeshChatX (0BSD with upstream MIT). That is what the PKGBUILD `license=` field records.
