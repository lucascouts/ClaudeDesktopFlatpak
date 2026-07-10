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

## Build locally

```bash
flatpak install --user flathub org.flatpak.Builder
flatpak run org.flatpak.Builder --force-clean --user --install --install-deps-from=flathub \
    builddir io.github.lucascouts.ClaudeDesktopFlatpak.yml
flatpak run io.github.lucascouts.ClaudeDesktopFlatpak
```

## Lint (Flathub requirements)

```bash
flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest io.github.lucascouts.ClaudeDesktopFlatpak.yml
flatpak run --command=flatpak-builder-lint org.flatpak.Builder repo repo
```

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

## Updates

New releases are picked up automatically:
[flatpak-external-data-checker](https://github.com/flathub-infra/flatpak-external-data-checker)
polls `https://claude.ai/api/desktop/linux/{x64,arm64}/deb/latest`
(see `x-checker-data` in the manifest) and opens update PRs.

## License

Packaging files (manifest/scripts) are MIT. Claude Desktop itself is
proprietary software by Anthropic PBC, subject to
[Anthropic's Consumer Terms](https://www.anthropic.com/legal/consumer-terms).
