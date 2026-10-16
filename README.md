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

The installers select your platform, download the latest release, verify its SHA256 against the release's `SHA256SUMS`, and install to `~/.local/bin` (`%USERPROFILE%\.local\bin` on Windows). They prepare GNU Bash 5.2 or newer before replacing an existing installation, using an existing Homebrew on macOS, apt-get/dnf/apk/pacman/zypper on Linux, or WinGet's Git.Git package on Windows. Updating Git Bash through WinGet also updates Git for Windows. Installing dependencies may require administrator authorization; the executable itself installs to your user directory. The installers do not install Homebrew/WinGet or change your login shell. Git Bash/MSYS users should use the PowerShell command above.

If a manager is missing, authorization fails, or its repository cannot provide Bash 5.2+, installation stops with instructions and preserves the existing WYCODE executable and documents. Dependencies already installed are retained. Repositories with older Bash require an administrator-provided supported Bash; WYCODE does not upgrade the whole operating system.

To inspect the installer first, download it from this repository and run it locally. To select a version or install location:

```sh
curl -fsSL https://raw.githubusercontent.com/capibaras001/wycode/main/install.sh -o install.sh
WYCODE_VERSION=v0.1.6 WYCODE_INSTALL_DIR="$HOME/bin" bash install.sh
```

```powershell
$env:WYCODE_VERSION = 'v0.1.6'
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
wycode scan https://your-authorized-target.example --goal "Validate account isolation with recorded positive and negative controls"
```

Run assessments only against systems you own or are authorized to test. `wycode` opens the native interactive TUI. `wycode scan <target>` runs headlessly; `--dry-run` prints the scan plan without running commands or contacting the model. Headless exit codes are `0` for a clean assessment, `2` for findings above medium severity, and `1` for an infrastructure failure or truncated assessment.

In the TUI, `/start <target>` chooses the assessment scope. `/goal <objective>` adds a persistent objective to the running assessment, or starts one in the current project directory. `/goal` shows recorded status. The main agent defines success criteria as required plan tasks and continues toward them; each criterion needs a completed result and evidence. Children contribute to the same plan. Missing access, cancelled work and execution limits produce incomplete results with specific next actions.

The main agent can choose a WY-CODE child model with `create_agent.model`: `glm-5.3`, `kimi-k3` (Kimi K3), `kimi-for-coding`, or `glm-5.3-flash`. The choice is saved with native child Sessions; omission inherits the parent model. Routing guidance suggests complex validation, broad-context synthesis, source/test work, and bounded triage respectively; these are defaults rather than benchmark guarantees.

`tool_catalog` lists/searches the current advertised tools and returns their input schemas. Agents use dedicated tools and MCP discovery for matching tasks, and Bash for installed processes, builds and scanners. Discovery does not grant permissions or execute the selected tool.

## Bash execution

Assessment commands run directly through GNU Bash 5.2 or newer in the selected project directory with your account's permissions and environment. File tools read and write real host files. WYCODE checks the Bash executable before native/headless assessments and again when recovering them after a restart. It searches PATH and standard Homebrew/Git Bash locations, skipping unsupported versions. An assessment uses the selected absolute executable path for its lifetime. Security tools, Python packages, browsers, and proxies use the host's existing setup and are not provisioned automatically.

Set `WYCODE_BASH` to an absolute executable path for a custom installation, for example `WYCODE_BASH=/opt/homebrew/bin/bash wycode` or `$env:WYCODE_BASH = 'C:\Program Files\Git\bin\bash.exe'` in PowerShell. This override is authoritative: an invalid or old executable fails instead of silently choosing another one. If package installation does not update the overridden path, correct or unset the override and rerun the installer.

WYCODE never installs dependencies during an assessment. If Bash is unavailable or too old, it reports the detected version/path and asks you to rerun the installer. You can still open the TUI, read reports or `/goal` status, log in, and use help/version or dry-run without a supported Bash. Ordinary native chat and OpenCode shell selection outside assessments retain their existing behavior.

Each shell call starts a fresh Bash process. Changes to shell variables or the working directory do not persist between calls. Native assessments retain their permission prompts. Cancellation stops owned command processes and leaves assessment files and reports intact. The default TUI uses a private server for its lifetime.

The old leading `--nodocker` flag is accepted for compatibility; Bash is now the default on supported hosts. WYCODE does not install, start, stop, or manage Docker engines or containers.

## Assessment reports

When an assessment ends, WYCODE saves `report.md` and `report.json` and shows the report in chat or headless output. Reports include findings, the assessment summary, documented coverage, unresolved work, and next options. Unverified candidates remain separate from findings. Failed or unfinished child tasks produce an incomplete report instead of a successful assessment.

For multi-step assessments, `scan_plan` tracks the target, hypothesis, validation criterion, priority, owner, dependencies, and result for each task. Ready work waits for its prerequisites. Reopening a prerequisite reopens dependent completions for review. Required unfinished work, including cancelled work, prevents a complete report. An explicit partial closure records its reason and keeps the report incomplete; optional checks remain visible as next options.

`finding_chain` connects existing finding notes into candidate paths and creates optional verification tasks for their links. Each verified link requires source evidence plus a recorded expected result, observed result, and link evidence. Changing or deleting source notes invalidates stale proof and reopens verification. Exact duplicate findings consolidate with source provenance; similar findings with distinct evidence remain separate. Chains are reported separately and never automatically raise finding severities.

Roots and children share this bookkeeping. Native recovery restores task IDs, source revisions, chain proofs, and the order of their updates without repeating host commands or network requests. Planning tools preserve the existing assessment scope and permissions.

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

Releases are cross-compiled. Installer fixtures exercise platform selection, downloads, checksums, dependency provisioning, and failed-install preservation in temporary directories. PowerShell installer fixtures can also run on macOS with an isolated PowerShell runtime; that does not establish native Windows execution. Cross-compilation and fixture checks do not establish native end-to-end assessment support on every target; Windows/macOS signing and notarization are not provided.

## License and attribution

wycode includes opencode and its terminal interface under the [MIT License](LICENSE), copyright (c) 2025 opencode. The wycode assessment package is licensed under [Apache-2.0](APACHE-2.0). Its skill packs were ported from [strix](https://github.com/usestrix/strix), copyright 2025 usestrix; see [NOTICE](NOTICE). Upstream and third-party components retain their respective licenses.

## Development changes

The [usability source changeset](changes/usability/README.md) contains the scoped source patch, baseline hashes, and validation results for explicit chat/project/target entry, progress restoration, evidence validation, and report controls. It is a development change package; the existing release binaries remain v0.1.6.
