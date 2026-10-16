#!/usr/bin/env bash
set -euo pipefail

bash_supported() {
  local executable
  executable=$(command -v "$1" 2>/dev/null) || return 1
  LC_ALL=C "$executable" --version 2>/dev/null | awk '
    /^GNU bash, version [0-9]+[.][0-9]+/ {
      split($4, version, ".")
      supported = version[1] + 0 > 5 || (version[1] + 0 == 5 && version[2] + 0 >= 2)
      exit
    }
    END { exit !supported }
  '
}

find_bash() {
  local directory prefix brew
  local directories=()
  selected_bash=
  if [ -n "${WYCODE_BASH:-}" ]; then
    if bash_supported "$WYCODE_BASH"; then selected_bash=$WYCODE_BASH; return 0; fi
    return 1
  fi
  IFS=: read -r -a directories <<< "$PATH"
  for directory in "${directories[@]}"; do
    if bash_supported "${directory:-.}/bash"; then selected_bash=${directory:-.}/bash; return 0; fi
  done
  brew=$(command -v brew 2>/dev/null || true)
  prefix=
  if [ -n "$brew" ]; then prefix=$("$brew" --prefix bash 2>/dev/null || true); fi
  for directory in "${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/bin}" "${prefix:+$prefix/bin}" /opt/homebrew/bin /usr/local/bin; do
    if [ -n "$directory" ] && bash_supported "$directory/bash"; then selected_bash=$directory/bash; return 0; fi
  done
  return 1
}

run_privileged() {
  if [ "$(id -u)" = 0 ]; then "$@"; return $?; fi
  if command -v sudo >/dev/null 2>&1; then
    if sudo -n true 2>/dev/null; then sudo -n "$@"; return $?; fi
    if ( : </dev/tty ) 2>/dev/null; then sudo "$@" </dev/tty; return $?; fi
  fi
  printf '%s\n' 'Installing Bash requires root or sudo authorization. Install Bash with your package manager, then rerun this installer.' >&2
  return 1
}

ensure_bash() {
  local manager candidate
  if find_bash; then return 0; fi
  printf '%s\n' 'Preparing GNU Bash 5.2 or newer...'
  if [ "$platform" = darwin ]; then
    manager=$(command -v brew 2>/dev/null || true)
    if [ -z "$manager" ]; then
      printf '%s\n' 'Bash 5.2+ requires Homebrew on macOS. Install Homebrew or make brew available on PATH, then rerun this installer.' >&2
      return 1
    fi
    if "$manager" list --versions bash >/dev/null 2>&1; then
      "$manager" upgrade bash || { printf '%s\n' 'Homebrew could not upgrade Bash.' >&2; return 1; }
    else
      "$manager" install bash || { printf '%s\n' 'Homebrew could not install Bash.' >&2; return 1; }
    fi
  else
    manager=
    for candidate in apt-get dnf apk pacman zypper; do
      if command -v "$candidate" >/dev/null 2>&1; then manager=$candidate; break; fi
    done
    case "$manager" in
      apt-get)
        run_privileged apt-get update && run_privileged apt-get install -y bash || { printf '%s\n' 'Could not install or upgrade Bash with apt-get.' >&2; return 1; } ;;
      dnf)
        run_privileged dnf install -y bash || { printf '%s\n' 'Could not install or upgrade Bash with dnf.' >&2; return 1; } ;;
      apk)
        run_privileged apk add --no-cache --upgrade bash || { printf '%s\n' 'Could not install or upgrade Bash with apk.' >&2; return 1; } ;;
      pacman)
        run_privileged pacman -S --needed --noconfirm bash || { printf '%s\n' 'Could not install or upgrade Bash with pacman. Refresh your system packages and retry.' >&2; return 1; } ;;
      zypper)
        run_privileged zypper --non-interactive install bash || { printf '%s\n' 'Could not install or upgrade Bash with zypper.' >&2; return 1; } ;;
      *)
        printf '%s\n' 'Bash 5.2+ is required. No supported package manager was found (apt-get, dnf, apk, pacman, zypper). Install Bash and rerun this installer.' >&2
        return 1 ;;
    esac
  fi
  if ! find_bash; then
    printf '%s\n' 'GNU Bash 5.2+ is still unavailable after package installation. Check your repository version and WYCODE_BASH override. The existing WYCODE installation was preserved.' >&2
    return 1
  fi
  printf 'Bash ready: %s\n' "$selected_bash"
}

main() {
  case "$(uname -s)" in
    Linux) platform=linux ;;
    Darwin) platform=darwin ;;
    MINGW*|MSYS*|CYGWIN*)
      printf '%s\n' 'On Windows, run this in PowerShell:' 'irm https://raw.githubusercontent.com/capibaras001/wycode/main/install.ps1 | iex' >&2
      exit 1 ;;
    *) printf '%s\n' 'wycode supports Linux, macOS, and Windows (PowerShell installer).' >&2; exit 1 ;;
  esac
  case "$(uname -m)" in
    x86_64|x86-64|amd64|x64) arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) printf 'Unsupported architecture: %s\n' "$(uname -m)" >&2; exit 1 ;;
  esac
  libc=
  if [ "$platform" = linux ]; then
    if ! getconf GNU_LIBC_VERSION >/dev/null 2>&1; then
      if (ldd --version 2>&1 || true) | grep -qi musl; then libc=-musl; fi
    fi
  fi
  for tool in curl tar awk mktemp; do
    command -v "$tool" >/dev/null 2>&1 || { printf 'Required command missing: %s\n' "$tool" >&2; exit 1; }
  done
  if command -v sha256sum >/dev/null 2>&1; then
    checksum_command=(sha256sum)
  elif command -v shasum >/dev/null 2>&1; then
    checksum_command=(shasum -a 256)
  else
    printf '%s\n' 'SHA256 verification requires sha256sum or shasum.' >&2
    exit 1
  fi

  version=${WYCODE_VERSION:-latest}
  case "$version" in
    latest) release=latest/download ;;
    *)
      if [[ ! "$version" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+([-+][A-Za-z0-9.-]+)?$ ]]; then
        printf 'Invalid WYCODE_VERSION: %s\n' "$version" >&2; exit 1
      fi
      release=download/v${version#v} ;;
  esac
  base=${WYCODE_RELEASE_BASE_URL:-https://github.com/capibaras001/wycode/releases}
  asset=wycode-$platform-$arch$libc.tar.gz
  install_dir=${WYCODE_INSTALL_DIR:-$HOME/.local/bin}
  temporary=$(mktemp -d "${TMPDIR:-/tmp}/wycode-install.XXXXXX")
  staged=
  trap 'rm -rf "$temporary"; if [ -n "$staged" ]; then rm -f "$staged"; fi' EXIT
  printf 'Downloading %s (%s)...\n' "$asset" "$version"
  curl -fsSL --retry 3 "${base%/}/$release/$asset" -o "$temporary/$asset"
  curl -fsSL --retry 3 "${base%/}/$release/SHA256SUMS" -o "$temporary/SHA256SUMS"
  expected=$(awk -v asset="$asset" '$2 == asset || $2 == "*" asset { print $1 }' "$temporary/SHA256SUMS")
  actual=$("${checksum_command[@]}" "$temporary/$asset" | awk '{print $1}')
  if [[ ! "$expected" =~ ^[a-fA-F0-9]{64}$ ]] || [ "$(printf '%s' "$expected" | tr 'A-F' 'a-f')" != "$actual" ]; then
    printf 'SHA256 verification failed for %s; existing installation was preserved.\n' "$asset" >&2
    exit 1
  fi

  contents=$(tar -tzf "$temporary/$asset")
  while IFS= read -r entry; do
    case "${entry#./}" in
      wycode|LICENSE|APACHE-2.0|NOTICE|README.md) ;;
      *) printf '%s\n' 'Unexpected archive contents; existing installation was preserved.' >&2; exit 1 ;;
    esac
  done <<< "$contents"
  if ! tar -tvzf "$temporary/$asset" | awk 'substr($0, 1, 1) != "-" { exit 1 }'; then
    printf '%s\n' 'Archive entries must be regular files; existing installation was preserved.' >&2
    exit 1
  fi
  mkdir "$temporary/extract"
  tar -xzf "$temporary/$asset" -C "$temporary/extract"
  for entry in wycode LICENSE APACHE-2.0 NOTICE README.md; do
    if [ ! -f "$temporary/extract/$entry" ] || [ -L "$temporary/extract/$entry" ]; then
      printf 'Archive is missing a regular %s file.\n' "$entry" >&2
      exit 1
    fi
  done
  ensure_bash || exit 1
  mkdir -p "$install_dir"
  mkdir -p "$install_dir/wycode-docs"
  for entry in LICENSE APACHE-2.0 NOTICE README.md; do
    cp "$temporary/extract/$entry" "$install_dir/wycode-docs/$entry"
  done
  staged=$(mktemp "$install_dir/.wycode.XXXXXX")
  cp "$temporary/extract/wycode" "$staged"
  chmod 755 "$staged"
  mv -f "$staged" "$install_dir/wycode"
  staged=
  printf 'Installed wycode to %s/wycode\n' "$install_dir"
  case ":$PATH:" in
    *":$install_dir:"*) printf '%s\n' 'Run: wycode --version' ;;
    *)
      printf '%s\n' 'Add this directory to PATH in your shell profile, then open a new terminal:'
      printf '  export PATH=%q:"$PATH"\n' "$install_dir"
      printf 'Or run now: %q --version\n' "$install_dir/wycode" ;;
  esac
}

main "$@"
