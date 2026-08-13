# Host tools. Package builds use makepkg inside Arch (native or pinned Docker).

.PHONY: all check build repo pages help
.PHONY: build-reticulum-go build-reticulum-go-git
.PHONY: build-meshchatx build-meshchatx-git

all: check build repo

help:
	@echo "Targets:"
	@echo "  check                 Validate PKGBUILDs, pkg.conf, and shell scripts"
	@echo "  build                 makepkg every package (Docker if not on Arch)"
	@echo "  build-reticulum-go    Binary packages for x86_64 aarch64 armv7h"
	@echo "  build-reticulum-go-git Git packages for host architecture"
	@echo "  build-meshchatx       AppImage packages for x86_64 aarch64"
	@echo "  build-meshchatx-git   Git package for host architecture"
	@echo "  repo                  repo-add databases under repo/\$arch"
	@echo "  pages                 Assemble GitHub Pages tree in public/"
	@echo "Variables: FORCE_DOCKER=1 PACKAGER='Quad4.io <ivan@quad4.io>'"

check:
	sh scripts/check.sh

build:
	sh scripts/makepkg.sh

build-reticulum-go:
	sh scripts/makepkg.sh reticulum-go

build-reticulum-go-git:
	sh scripts/makepkg.sh reticulum-go-git

build-meshchatx:
	sh scripts/makepkg.sh meshchatx

build-meshchatx-git:
	sh scripts/makepkg.sh meshchatx-git

repo:
	sh scripts/repo-add.sh

pages: repo
	sh scripts/assemble-pages.sh
