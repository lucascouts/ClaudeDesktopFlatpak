# Claude Desktop — unofficial Flatpak

Unofficial Flatpak packaging of [Claude Desktop](https://claude.ai/download)
for Linux. Part of the
[Claude Desktop for Linux](https://github.com/lucascouts/claude-desktop-app)
packaging project (see there for the AppImage and Gentoo ebuild).

The app binary is **not redistributed**: at install time, Flatpak downloads the
official `.deb` directly from Anthropic's release server (`downloads.claude.ai`)
via the `extra-data` mechanism and unpacks it locally. This package is not
affiliated with or endorsed by Anthropic.

Supported: `x86_64` and `aarch64`.

## Not on Flathub

This package is **not published on Flathub** and installs from a locally built
repo instead (below). Flathub declined it: the app needs host command spawning
(`--talk-name=org.freedesktop.Flatpak`, for local MCP servers) and `--filesystem=home`
(for Claude Code), and Flathub does not grant those sandbox holes to a
closed-source, proprietary application. Removing them would pass review but
break local MCP servers and Claude Code, which are the point of the package.
For a distribution-agnostic option without the sandbox, use the
[AppImage](https://github.com/lucascouts/ClaudeDesktopAppImage) instead.

## Build and install

```bash
flatpak install --user flathub org.flatpak.Builder

# Build into a local repo (do not use --install: the extra-data unpack runs a
# nested bwrap that fails where unprivileged user namespaces are restricted).
flatpak run org.flatpak.Builder --force-clean --user --repo=repo \
    builddir io.github.lucascouts.ClaudeDesktopFlatpak.yml

# Install from that repo and run.
flatpak --user remote-add --no-gpg-verify --if-not-exists claude-local repo
flatpak --user install claude-local io.github.lucascouts.ClaudeDesktopFlatpak
flatpak run io.github.lucascouts.ClaudeDesktopFlatpak
```

To update, re-run the build with a newer `.deb` version in the manifest
(`x-checker-data` in the manifest tracks upstream, but without Flathub's
external-data-checker nothing bumps it automatically — edit the `extra-data`
`url`/`sha256`/`size` and rebuild).

## Lint

```bash
flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest io.github.lucascouts.ClaudeDesktopFlatpak.yml
```

The two `finish-args` findings (`--filesystem=home`, host `flatpak-spawn`) are
intentional; see *Not on Flathub* above.

## Local MCP servers

The app runs inside the Flatpak sandbox, so MCP server commands configured in
`~/.config/Claude/claude_desktop_config.json` execute inside the sandbox too.
To run them on the host instead, prefix commands with `flatpak-spawn --host`:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "flatpak-spawn",
      "args": ["--host", "npx", "-y", "@modelcontextprotocol/server-filesystem", "/home/you/allowed"]
    }
  }
}
```

Remote (HTTP/SSE) MCP servers work unchanged.

## Known limitations

- The VM-based code-execution sandbox (qemu/OVMF/virtiofsd) is unavailable
  inside Flatpak.
- The Electron/Chromium sandbox is provided by
  [zypak](https://github.com/refi64/zypak) (no setuid helper in Flatpak).

## License

Packaging files (manifest/scripts) are MIT. Claude Desktop itself is
proprietary software by Anthropic PBC, subject to
[Anthropic's Consumer Terms](https://www.anthropic.com/legal/consumer-terms).
