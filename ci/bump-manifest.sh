#!/usr/bin/env bash
# Repin this repo's extra-data to whatever the bentoo overlay's ebuild points
# at (see ci/resolve-overlay-pin.sh for why the overlay is the source of truth).
#
# extra-data pins an exact sha256 and byte size, so both .debs must actually be
# downloaded and hashed -- there is no metadata endpoint that hands those over.
# The manifest and the metainfo release are rewritten in place; committing is
# left to the caller.
#
# Prints "unchanged" and exits 0 when the manifest already carries that pin.
#
# Env:
#   DISTFILES  optional read-only cache probed before downloading
#              (expects Portage's claude-desktop-bin-<PV>-<arch>.deb names)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
MANIFEST="$ROOT/io.github.lucascouts.ClaudeDesktopFlatpak.yml"
METAINFO="$ROOT/io.github.lucascouts.ClaudeDesktopFlatpak.metainfo.xml"

log() { printf '>> %s\n' "$*" >&2; }
die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

[[ -f "$MANIFEST" ]] || die "manifest not found: $MANIFEST"

pin="$("$HERE/resolve-overlay-pin.sh")"
version="$(sed -n 's/^version=//p' <<<"$pin")"
build_id="$(sed -n 's/^build_id=//p' <<<"$pin")"
url_x64="$(sed -n 's/^deb_url_x64=//p' <<<"$pin")"
url_arm64="$(sed -n 's/^deb_url_arm64=//p' <<<"$pin")"
[[ -n "$version" && -n "$build_id" ]] || die "could not resolve the overlay pin"
log "overlay pins $version (build $build_id)"

if grep -q "/x64/${version}/Claude-${build_id}.deb" "$MANIFEST"; then
	echo "unchanged"
	exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# arch-suffix in Portage's naming, arch-segment in Anthropic's URLs
obtain() { # <url> <portage-arch> <dest>
	local url="$1" parch="$2" dest="$3" cached="${DISTFILES:-}/claude-desktop-bin-${version}-${2}.deb"
	if [[ -n "${DISTFILES:-}" && -f "$cached" ]]; then
		log "reusing cached $(basename "$cached")"
		printf '%s' "$cached"
		return
	fi
	log "downloading ${parch} .deb"
	curl -fL --retry 3 --retry-delay 5 -o "$dest" "$url" >&2
	printf '%s' "$dest"
}

deb_x64="$(obtain "$url_x64" x86_64 "$tmp/x64.deb")"
deb_arm64="$(obtain "$url_arm64" aarch64 "$tmp/arm64.deb")"

sha_x64="$(sha256sum "$deb_x64" | cut -d' ' -f1)"
size_x64="$(stat -c %s "$deb_x64")"
sha_arm64="$(sha256sum "$deb_arm64" | cut -d' ' -f1)"
size_arm64="$(stat -c %s "$deb_arm64")"
log "x64   sha=$sha_x64 size=$size_x64"
log "arm64 sha=$sha_arm64 size=$size_arm64"

python3 - "$MANIFEST" "$version" "$build_id" \
	"$sha_x64" "$size_x64" "$sha_arm64" "$size_arm64" <<'PYEOF'
import re
import sys

path, pv, bid, sha_x64, size_x64, sha_arm64, size_arm64 = sys.argv[1:8]
by_arch = {"x64": (sha_x64, size_x64), "arm64": (sha_arm64, size_arm64)}

# Both extra-data blocks look alike, so the rewrite is scoped by the
# only-arches line that opens each one.
arch, out = None, []
for line in open(path):
    s = line.strip()
    if s == "only-arches: [x86_64]":
        arch = "x64"
    elif s == "only-arches: [aarch64]":
        arch = "arm64"
    if arch and s.startswith("url:") and "downloads.claude.ai" in s:
        line = re.sub(r"url:.*",
                      f"url: https://downloads.claude.ai/releases/linux/{arch}/{pv}/Claude-{bid}.deb",
                      line)
    elif arch and s.startswith("sha256:"):
        line = re.sub(r"sha256:.*", f"sha256: {by_arch[arch][0]}", line)
    elif arch and s.startswith("size:"):
        line = re.sub(r"size:.*", f"size: {by_arch[arch][1]}", line)
    out.append(line)
open(path, "w").writelines(out)
PYEOF

if [[ -f "$METAINFO" ]]; then
	sed -i -E "s#<release version=\"[^\"]*\" date=\"[^\"]*\"/>#<release version=\"${version}\" date=\"$(date -u +%F)\"/>#" \
		"$METAINFO"
fi

# A silently mangled manifest is worse than no bump at all: assert both the new
# pin and that the file still parses as YAML before handing back "changed".
grep -q "/x64/${version}/Claude-${build_id}.deb" "$MANIFEST" || die "manifest rewrite did not take"
grep -q "/arm64/${version}/Claude-${build_id}.deb" "$MANIFEST" || die "arm64 rewrite did not take"
python3 -c 'import sys, yaml; yaml.safe_load(open(sys.argv[1]))' "$MANIFEST" ||
	die "manifest is no longer valid YAML"

echo "changed $version"
