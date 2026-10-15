# wycode

Native terminal security assessment agent, based on [opencode](https://github.com/anomalyco/opencode). Run the interactive TUI or a headless assessment from one executable. This repository distributes installers and release binaries.

## Install

Linux and macOS:

```sh
curl https://raw.githubusercontent.com/capibaras001/wycode/main/install.sh | bash
```

Windows, in PowerShell:

```powershell
irm https://raw.githubusercontent.com/capibaras001/wycode/main/install.ps1 | iex
```

The installers select your platform, download the latest release, verify its SHA256 against the release's `SHA256SUMS`, and install to `~/.local/bin` (`%USERPROFILE%\.local\bin` on Windows). They print PATH instructions when needed. Installation of the executable does not require sudo. Git Bash/MSYS users should use the PowerShell command above.

To inspect the installer first, download it from this repository and run it locally. To select a version or install location:

```sh
curl -fsSL https://raw.githubusercontent.com/capibaras001/wycode/main/install.sh -o install.sh
WYCODE_VERSION=v0.1.3 WYCODE_INSTALL_DIR="$HOME/bin" bash install.sh
```

```powershell
$env:WYCODE_VERSION = 'v0.1.3'
$env:WYCODE_INSTALL_DIR = "$env:USERPROFILE\bin"
irm https://raw.githubusercontent.com/capibaras001/wycode/main/install.ps1 | iex
```

Rerun the installer to upgrade. On Windows, close all wycode TUI sessions first; after validating the download, the installer stops the existing wycode background service before replacing its executable. If stopping the service fails, the installed executable is preserved; run `wycode service stop` and retry. Remove the installed executable and its adjacent `wycode-docs` directory to uninstall. License notices and this README are installed in `wycode-docs`.

## Use

Release binaries include a gateway credential for the built-in wy-gcp models, so you can start directly:

```sh
wycode
```

Optionally override the bundled credential with your own gateway key:

```sh
export WYCODE_API_KEY='your-key'
wycode
```

```powershell
$env:WYCODE_API_KEY = 'your-key'
wycode
```

The interactive TUI also supports native provider login and model selection. WY-CODE uses `aisdk:@ai-sdk/anthropic` against `https://gcp.wy-code.tech/v1`; headless scans use the same SDK and the built-in gateway model catalog.

```sh
wycode --version
wycode scan https://your-authorized-target.example --dry-run
wycode scan https://your-authorized-target.example --model kimi-k3 --effort high
```

Run assessments only against systems you own or are authorized to test. `wycode` opens the native interactive TUI. `wycode scan <target>` runs headlessly; `--dry-run` prints the scan plan without starting Docker or running an assessment. Headless exit codes are `0` for a clean assessment, `2` for findings above medium severity, and `1` for an infrastructure failure or truncated assessment.

## Docker lifecycle

Assessments normally run tools in a Docker sandbox. wycode detects an existing Docker engine, installs or starts a supported local engine when needed, and pulls the sandbox image. The startup screen shows installation, disk checks, download progress, engine startup, and image preparation. Initial setup can require administrator privileges, a platform installer, or a Windows WSL restart; follow the displayed prompts. Existing running engines stay running. An engine started by wycode is stopped when its final assessment lease closes. Closing an assessment cleans up its owned sandbox resources.

Installer downloads check free space and can fall back to `/tmp`. Before pulling a missing sandbox image, wycode estimates download and extraction space on the Docker daemon's filesystem. If primary storage is insufficient and the daemon's `/tmp` has room, wycode starts an owned temporary Docker engine with its data in `/tmp/wycode-engine-*`. It removes that engine and its data on normal exit or handled cancellation. A forced process kill can leave those resources behind. The fallback needs privileged containers and enough primary space for its small helper and engine images. `/tmp` on the same filesystem cannot add capacity; Docker Desktop and remote contexts use the daemon host's `/tmp`.

If Docker setup fails, the interactive chat still opens and shows a concise warning. Docker mode requires a reachable Linux Docker engine. Check `docker info` and your service's logs; on restricted hosts that cannot run Docker, configure a reachable engine with `DOCKER_HOST` or use Kali host mode below. An installed Docker CLI alone does not provide a running engine.

## Kali host mode

On Kali Linux, run assessment tools directly on the host:

```sh
wycode --nodocker
wycode scan https://your-authorized-target.example --nodocker
```

wycode checks `/etc/os-release` for Kali before enabling this mode. Shell commands run in the selected project directory with your account's permissions, and file tools access the host filesystem. Docker installation and image downloads are skipped. Native assessments retain their permission prompts; cancellation stops owned shell processes and leaves host files intact. The TUI uses a private server for this invocation so the selected execution mode stays consistent. Existing assessments retain their original execution mode and fail clearly if opened under a conflicting mode.

## Streaming and cache

The first text or reasoning fragment is forwarded immediately; subsequent fragments remain batched. The TUI shows Thinking when the provider starts reasoning, even before reasoning text arrives. Provider processing time still determines when answer text becomes available.

Client reads have a 10-second TTL and are invalidated by relevant live events. SSE connections can resume from `Last-Event-ID` using a 60-second in-memory event cache, bounded to 4,096 events and 8 MiB. Successful reconnects replay missing events in order before normal hydration resumes. Expired or evicted cursors, or a server restart, trigger a fresh state load. This cache is local to the server process and is not durable assessment history.

## Release platforms

| OS           | Architecture        | Archive                          |
| ------------ | ------------------- | -------------------------------- |
| Linux, glibc | x86-64              | `wycode-linux-amd64.tar.gz`      |
| Linux, glibc | ARM64               | `wycode-linux-arm64.tar.gz`      |
| Linux, musl  | x86-64              | `wycode-linux-amd64-musl.tar.gz` |
| Linux, musl  | ARM64               | `wycode-linux-arm64-musl.tar.gz` |
| macOS        | Intel x86-64        | `wycode-darwin-amd64.tar.gz`     |
| macOS        | Apple Silicon ARM64 | `wycode-darwin-arm64.tar.gz`     |
| Windows      | x86-64              | `wycode-windows-amd64.zip`       |
| Windows      | ARM64               | `wycode-windows-arm64.zip`       |

Linux musl builds require `libstdc++`. On Alpine, install the shell/download prerequisites and C++ runtime with `apk add --no-cache bash curl libstdc++` before running the installer.

Each archive contains `wycode` or `wycode.exe`, `LICENSE`, `APACHE-2.0`, `NOTICE`, and `README.md` at its root. Binaries include the runtime; a separate Bun installation and source checkout are unnecessary. Other architectures, 32-bit systems, and other operating systems are unsupported.

Releases are cross-compiled. Installer fixtures exercise platform selection, downloads, checksums, and failed-install preservation in temporary directories. Cross-compilation and fixture checks do not establish native end-to-end assessment support on every target; Windows/macOS signing and notarization are not provided.

## License and attribution

wycode includes opencode and its terminal interface under the [MIT License](LICENSE), copyright (c) 2025 opencode. The wycode assessment package is licensed under [Apache-2.0](APACHE-2.0). Its skill packs were ported from [strix](https://github.com/usestrix/strix), copyright 2025 usestrix; see [NOTICE](NOTICE). Upstream and third-party components retain their respective licenses.
