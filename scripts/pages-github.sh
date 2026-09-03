#!/bin/sh
# Enable GitHub Pages from Actions, or attach the custom domain after deploy.
#
# Usage:
#   pages-github.sh enable
#   pages-github.sh domain

set -eu

ROOT="$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/lib.sh"
load_repo_conf

: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${GH_TOKEN:?GH_TOKEN or GITHUB_TOKEN is required}"
export GH_TOKEN

cname="${PAGES_URL#http://}"
cname="${cname#https://}"
cname="${cname%%/*}"
[ -n "$cname" ] || die "PAGES_URL has no host"

cmd="${1:-}"
case "$cmd" in
enable)
	if gh api "repos/${GITHUB_REPOSITORY}/pages" >/dev/null 2>&1; then
		log "GitHub Pages already enabled"
	else
		log "Enabling GitHub Pages (Actions)"
		gh api --method POST "repos/${GITHUB_REPOSITORY}/pages" \
			-f build_type=workflow
	fi
	;;
domain)
	# GITHUB_TOKEN often cannot PUT Pages settings (403). Skip when already set.
	current="$(gh api "repos/${GITHUB_REPOSITORY}/pages" --jq '.cname // empty' 2>/dev/null || true)"
	if [ "$current" = "$cname" ]; then
		log "Pages custom domain already ${cname}"
	else
		log "Setting Pages custom domain ${cname}"
		if ! gh api --method PUT "repos/${GITHUB_REPOSITORY}/pages" \
			-f build_type=workflow \
			-f cname="${cname}"; then
			die "cannot set Pages custom domain to ${cname} (needs repo admin). Set it in Settings > Pages"
		fi
	fi
	gh api --method PUT "repos/${GITHUB_REPOSITORY}/pages" \
		-F https_enforced=true >/dev/null 2>&1 || true
	;;
*)
	die "usage: pages-github.sh enable|domain"
	;;
esac
