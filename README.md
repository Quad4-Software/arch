# Quad4 Arch

Unofficial [pacman](https://wiki.archlinux.org/title/Pacman) repository for Quad4 software. Hosted at [arch.quad4.io](https://arch.quad4.io).

## Install

Append this to `/etc/pacman.conf` after the official `[core]` and `[extra]` blocks, or copy [conf/pacman-quad4.conf](conf/pacman-quad4.conf):

```ini
[quad4]
SigLevel = Optional TrustAll
Server = https://arch.quad4.io/$arch
Server = https://github.com/Quad4-Software/arch/releases/download/pkg-$arch
```

Then:

```bash
sudo pacman -Syu
sudo pacman -S reticulum-go-bin meshchatx-bin renbrowser-bin rns lxmf nomadnet
```

The first Server is [arch.quad4.io](https://arch.quad4.io). The second is a rolling GitHub Release named `pkg-$arch`.

Packages are unsigned until a key is placed at `keys/quad4.gpg`. Keep `SigLevel = Optional TrustAll` until then. After packages and the database are signed, switch to `SigLevel = Required` and import the public key.

## Packages

| Package | Description |
| --- | --- |
| `reticulum-go-bin` | Reticulum-Go, prebuilt GitHub release (`x86_64`, `aarch64`, `armv7h`) |
| `reticulum-go-git` | Reticulum-Go built from `master` |
| `meshchatx-bin` | MeshChatX AppImage (`x86_64`, `aarch64`) |
| `meshchatx-git` | MeshChatX built from `master` |
| `renbrowser-bin` | Ren Browser for Reticulum (`x86_64`, `aarch64`) |
| `renbrowser-git` | Ren Browser built from `master` |
| `gorrcd-bin` | Go RRC hub daemon (prebuilt) |
| `gorrcd-git` | Go RRC hub daemon from `master` |
| `golxmd-bin` | Go LXMF daemon (prebuilt) |
| `golxmd-git` | Go LXMF daemon from `master` |
| `rns` | Python Reticulum Network Stack (PyPI, external) |
| `lxmf` | Python LXMF (PyPI, external) |
| `nomadnet` | Nomad Network client (PyPI, external) |
| `lxmfy` | LXMF bot framework (PyPI) |
| `rns-page-node` | RNS page/file node (PyPI) |
| `pip-rns` | Install Python packages from Reticulum remotes (PyPI) |

`*-bin` and `*-git` for the same app conflict and both provide the unversioned name (`reticulum-go`, `meshchatx`, …). Old bare names (`reticulum-go`, `meshchatx`, …) are replaced by the matching `*-bin` package on upgrade. Python packages stay unversioned (no `-bin`/`-git`). `rns`, `lxmf`, and `nomadnet` are third-party Markqvist packages mirrored for convenience.

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
sh scripts/install-verify-tools.sh
sh scripts/bump-binary.sh reticulum-go-bin v1.1.1
sh scripts/bump-binary.sh meshchatx-bin v4.8.5
```

Binary bumps fail closed unless release assets verify:

- `reticulum-go-bin`: cosign blob attestation (`.cosign.bundle`) against the pinned key in `keys/upstream/reticulum-go.cosign.pub`
- `meshchatx-bin`: SLSA provenance (`meshchatx-linux-v*.intoto.jsonl`) via `slsa-verifier` for `github.com/Quad4-Software/MeshChatX` and the release tag

Tool versions and sha256 pins live in `conf/ci-pins.env`. Arch image bumps cross-check the Docker Hub tag digest before rewriting the pin.

Or let CI do it. The Auto bump workflow runs daily, on `workflow_dispatch`, and on `repository_dispatch` type `quad4-bump`. It updates binary package TAGs and the Arch image pin in `conf/ci-pins.env`, opens a PR on `chore/auto-bump`, and enables auto-merge when CI is green.

Set repository secret `AUTO_BUMP_TOKEN` (classic PAT or fine-grained token with Contents and Pull requests write) so the PR is not opened with `GITHUB_TOKEN` (otherwise `pull_request` workflows do not run). Also enable Allow auto-merge in repo settings.

Check for bumps locally:

```bash
sh scripts/auto-bump.sh
```

Scaffold a new package:

```bash
sh scripts/new-pkg.sh other-tool --kind binary --github Quad4-Software/other-tool --tag v0.1.0
sh scripts/new-pkg.sh other-tool --kind git --github Quad4-Software/other-tool
```

That creates `pkg/other-tool-bin` and `pkg/other-tool-git`. Edit `package()` in the new PKGBUILD, then add matrix rows in `.github/workflows/ci.yml` and `publish.yml`.

From another Quad4 repository (needs `actions: write` on this repo):

```bash
# Rebuild current package versions
gh api repos/Quad4-Software/arch/dispatches -f event_type=quad4-rebuild

# Check for newer upstream releases and open a bump PR
gh api repos/Quad4-Software/arch/dispatches -f event_type=quad4-bump
```

## License

PKGBUILDs, scripts, and CI are [0BSD](LICENSE).

Packaged software keeps its own license, recorded in each PKGBUILD `license=` field:

- Reticulum-Go: Apache-2.0
- MeshChatX: 0BSD, with upstream MIT
