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
WYCODE_VERSION=v0.1.4 WYCODE_INSTALL_DIR="$HOME/bin" bash install.sh
```

```powershell
$env:WYCODE_VERSION = 'v0.1.4'
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

Run assessments only against systems you own or are authorized to test. `wycode` opens the native interactive TUI. `wycode scan <target>` runs headlessly; `--dry-run` prints the scan plan without running commands or contacting the model. Headless exit codes are `0` for a clean assessment, `2` for findings above medium severity, and `1` for an infrastructure failure or truncated assessment.

## Bash execution

Assessment commands run directly through Bash in the selected project directory with your account's permissions and environment. File tools read and write real host files. Bash must be on PATH; on Windows, install Git Bash and add its `bin` directory to PATH. Security tools, Python packages, browsers, and proxies use the host's existing setup and are not provisioned automatically.

Each shell call starts a fresh Bash process. Changes to shell variables or the working directory do not persist between calls. Native assessments retain their permission prompts. Cancellation stops owned command processes and leaves assessment files and reports intact. The default TUI uses a private server for its lifetime.

The old leading `--nodocker` flag is accepted for compatibility; Bash is now the default on supported hosts. WYCODE does not install, start, stop, or manage Docker engines or containers.

## Assessment reports

When an assessment ends, WYCODE saves `report.md` and `report.json` and shows the report in chat or headless output. Reports include findings, the assessment summary, documented coverage, unresolved work, and next options. Unverified candidates remain separate from findings. Failed or unfinished child tasks produce an incomplete report instead of a successful assessment.

Completed assessments are not rerun after a server restart. Legacy Docker assessments require a new `/start <target>` assessment before commands can run through Bash.

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
