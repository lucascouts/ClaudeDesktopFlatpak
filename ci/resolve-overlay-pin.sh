#!/usr/bin/env bash
# Resolve the Claude Desktop version and Anthropic build id currently pinned by
# the bentoo overlay's app-misc/claude-desktop-bin ebuild, and print them as
# key=value lines (ready to append to $GITHUB_OUTPUT).
#
# Why the overlay and not Anthropic's API: claude.ai/api sits behind Cloudflare
# and 403s GitHub-hosted runner IPs, so CI cannot probe it. The overlay's
# autoupdate runs from a residential IP where the API does answer, and records
# both values in the ebuild -- version in the filename, build id in BUILD_ID.
# Reading them back is a plain GitHub fetch, which always works from CI.
#
# Env:
#   OVERLAY_REPO  overlay slug   (default: obentoo/bentoo)
#   OVERLAY_REF   branch or tag  (default: master)
#   GH_TOKEN      optional; lifts the anonymous api.github.com rate limit
set -euo pipefail

OVERLAY_REPO="${OVERLAY_REPO:-obentoo/bentoo}"
OVERLAY_REF="${OVERLAY_REF:-master}"
PKGDIR="app-misc/claude-desktop-bin"

auth=()
if [[ -n "${GH_TOKEN:-}" ]]; then
	auth=(-H "Authorization: Bearer ${GH_TOKEN}")
fi

# Listing the package directory (rather than guessing the filename) is what
# survives a revbump: the file becomes ...-1.2.3-r1.ebuild while the .deb URL
# still carries 1.2.3.
listing="$(curl -fsSL --retry 3 ${auth[@]+"${auth[@]}"} \
	-H 'Accept: application/vnd.github+json' \
	"https://api.github.com/repos/${OVERLAY_REPO}/contents/${PKGDIR}?ref=${OVERLAY_REF}")"

ebuild="$(printf '%s' "$listing" |
	jq -r '.[].name | select(endswith(".ebuild"))' |
	sort -V | tail -1)"
[[ -n "$ebuild" ]] || {
	echo "no ebuild found in ${OVERLAY_REPO}:${PKGDIR}" >&2
	exit 1
}

version="${ebuild#claude-desktop-bin-}"
version="${version%.ebuild}"
version="${version%-r[0-9]*}" # -rN is a packaging counter, not an upstream version
[[ "$version" =~ ^[0-9][0-9.]*$ ]] || {
	echo "unexpected version parsed from '${ebuild}': ${version}" >&2
	exit 1
}

# The .deb has no stable name: every release is Claude-<sha40>.deb, and that
# hash lives in the ebuild's BUILD_ID. The arm64 endpoint serves the same hash.
body="$(curl -fsSL --retry 3 \
	"https://raw.githubusercontent.com/${OVERLAY_REPO}/${OVERLAY_REF}/${PKGDIR}/${ebuild}")"
build_id="$(printf '%s' "$body" |
	sed -n 's/^BUILD_ID="\([0-9a-f]\{40\}\)".*/\1/p' | head -1)"
[[ "$build_id" =~ ^[0-9a-f]{40}$ ]] || {
	echo "no BUILD_ID found in ${ebuild}" >&2
	exit 1
}

base="https://downloads.claude.ai/releases/linux"
printf 'version=%s\n' "$version"
printf 'build_id=%s\n' "$build_id"
printf 'deb_url_x64=%s/x64/%s/Claude-%s.deb\n' "$base" "$version" "$build_id"
printf 'deb_url_arm64=%s/arm64/%s/Claude-%s.deb\n' "$base" "$version" "$build_id"
