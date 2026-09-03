# Quad4 Arch

Unofficial [pacman](https://wiki.archlinux.org/title/Pacman) repository for Quad4 software. Hosted at [arch.quad4.io](https://arch.quad4.io).

## Install

Append this to `/etc/pacman.conf` after the official `[core]` and `[extra]` blocks, or copy [conf/pacman-quad4.conf](conf/pacman-quad4.conf):

```ini
[quad4]
SigLevel = Optional TrustAll
Server = https://arch.quad4.io/$arch
Server = https://github.com/Quad4-Software/arch/releases/download/repo-$arch
```

Then:

```bash
sudo pacman -Syu
sudo pacman -S reticulum-go meshchatx
```

The first Server is [arch.quad4.io](https://arch.quad4.io). The second is a rolling GitHub Release named `repo-$arch`.

Packages are unsigned until a key is placed at `keys/quad4.gpg`. Keep `SigLevel = Optional TrustAll` until then. After packages and the database are signed, switch to `SigLevel = Required` and import the public key.

## Packages

| Package | Description |
| --- | --- |
| `reticulum-go` | Reticulum-Go, prebuilt GitHub release (`x86_64`, `aarch64`, `armv7h`) |
| `reticulum-go-git` | Reticulum-Go built from `master` |
| `meshchatx` | MeshChatX AppImage (`x86_64`, `aarch64`) |
| `meshchatx-git` | MeshChatX built from `master` |

`reticulum-go` conflicts with `reticulum-go-git`. `meshchatx` conflicts with `meshchatx-git`.

## Development

On Arch, `makepkg` and `repo-add` run on the host. Elsewhere, scripts use the pinned `archlinux:base-devel` image from `conf/ci-pins.env`.

```bash
make check
make build
make repo
make pages
```

Bump a binary package after an upstream release:

```bash
sh scripts/bump-binary.sh reticulum-go v1.1.1
sh scripts/bump-binary.sh meshchatx v4.8.5
```

Scaffold a new package:

```bash
sh scripts/new-pkg.sh other-tool --kind binary --github Quad4-Software/other-tool --tag v0.1.0
sh scripts/new-pkg.sh other-tool-git --kind git --github Quad4-Software/other-tool
```

Edit `package()` in the new PKGBUILD, then add matrix rows in `.github/workflows/ci.yml` and `publish.yml`.

Rebuild from another Quad4 repository (needs `actions: write` on this repo):

```bash
gh api repos/Quad4-Software/arch/dispatches -f event_type=quad4-rebuild
```

## License

PKGBUILDs, scripts, and CI are [0BSD](LICENSE).

Packaged software keeps its own license, recorded in each PKGBUILD `license=` field:

- Reticulum-Go: Apache-2.0
- MeshChatX: 0BSD, with upstream MIT
