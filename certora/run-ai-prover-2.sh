#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$ROOT_DIR/certora/.certora-tools"
VENV_DIR="$TOOLS_DIR/venv"
TOOLS_BIN="$VENV_DIR/bin"
TOOLS_PYTHON="$TOOLS_BIN/python"
TOOLS_UV="$TOOLS_BIN/uv"
TOOLS_CERTORA_RUN="$TOOLS_BIN/certoraRun"
TOOLS_SOLC_SELECT="$TOOLS_BIN/solc-select"
SOLC_BIN_DIR="$TOOLS_DIR/solc-bin"
SOLC_CACHE_DIR="$TOOLS_DIR/solc-cache"
PYPI_COOLDOWN="1 week"
PYPI_COOLDOWN_DAYS="7"

cd "$ROOT_DIR"
export PATH="$SOLC_BIN_DIR:$PATH"

CONFIG_FILES=('certora/confs/autospec_Answer_Function.conf')
REQUIRED_SOLC_VERSIONS=('0.8.34')

log() {
  printf '\n[ai-prover] %s\n' "$*"
}

die() {
  printf '\n[ai-prover] ERROR: %s\n' "$*" >&2
  printf '[ai-prover] See certora/README-2.md#manual-fallback for manual setup steps.\n' >&2
  exit 1
}

ensure_local_directory() {
  local directory="$1"
  if [ -L "$directory" ]; then
    die "Refusing to use symlinked tool directory: $directory"
  fi
  if [ -e "$directory" ] && [ ! -d "$directory" ]; then
    die "Expected a directory but found something else: $directory"
  fi
  mkdir -p "$directory"
}

ensure_python_tooling() {
  command -v python3 >/dev/null 2>&1 || die "python3 is required to prepare local Certora tooling."
  ensure_local_directory "$TOOLS_DIR"
  log "Refreshing local Python virtual environment at $VENV_DIR"
  rm -rf "$VENV_DIR" || die "Could not remove stale local virtual environment at $VENV_DIR."
  python3 -m venv "$VENV_DIR" || die "Could not create Python virtual environment. On Debian/Ubuntu, install python3-venv and rerun."
  install_uv_after_cooldown
}

select_pypi_version_after_cooldown() {
  local package_name="$1"
  "$TOOLS_PYTHON" - "$package_name" "$PYPI_COOLDOWN_DAYS" <<'PY'
import json
import sys
import urllib.request
from datetime import datetime, timedelta, timezone

package_name = sys.argv[1]
cooldown_days = int(sys.argv[2])
cutoff = datetime.now(timezone.utc) - timedelta(days=cooldown_days)

with urllib.request.urlopen(f"https://pypi.org/pypi/{package_name}/json", timeout=30) as response:
    metadata = json.load(response)

candidates = []
for version, files in metadata.get("releases", {}).items():
    stable_marker = version.replace(".", "").replace("post", "")
    if not stable_marker.isdigit():
        continue

    upload_times = []
    for file_info in files:
        if file_info.get("yanked"):
            continue
        upload_time = file_info.get("upload_time_iso_8601")
        if not upload_time:
            continue
        uploaded_at = datetime.fromisoformat(upload_time.replace("Z", "+00:00"))
        if uploaded_at <= cutoff:
            upload_times.append(uploaded_at)

    if upload_times:
        candidates.append((max(upload_times), version))

if not candidates:
    raise SystemExit(f"No {package_name} release is older than the configured cooldown")

candidates.sort()
print(candidates[-1][1])
PY
}

install_uv_after_cooldown() {
  local uv_version
  uv_version="$(select_pypi_version_after_cooldown uv)" || die "Could not resolve a uv release older than $PYPI_COOLDOWN."
  log "Installing uv $uv_version into the repo-local virtual environment"
  "$TOOLS_PYTHON" -m pip install --disable-pip-version-check --upgrade --no-deps "uv==$uv_version"
  [ -x "$TOOLS_UV" ] || die "Repo-local uv was not installed at $TOOLS_UV."
}

install_python_tools() {
  ensure_python_tooling
  log "Installing Certora Python tools with a $PYPI_COOLDOWN PyPI cooldown"
  "$TOOLS_UV" pip install \
    --python "$TOOLS_PYTHON" \
    --upgrade \
    --reinstall \
    --exclude-newer "$PYPI_COOLDOWN" \
    certora-cli solc-select
  [ -x "$TOOLS_CERTORA_RUN" ] || die "Repo-local certoraRun was not installed at $TOOLS_CERTORA_RUN."
  [ -x "$TOOLS_SOLC_SELECT" ] || die "Repo-local solc-select was not installed at $TOOLS_SOLC_SELECT."
}

check_java() {
  command -v java >/dev/null 2>&1 || die "Java 21+ is required. Install it and rerun this script."
  local major
  major="$(java -version 2>&1 | awk -F'[".]' '/version/ {print $2; exit}')"
  if [ -n "$major" ] && [ "$major" -lt 21 ]; then
    die "Java 21+ is required, but java -version reports major version $major."
  fi
}

prepare_solc() {
  local version="$1"
  local artifact="$HOME/.solc-select/artifacts/solc-$version/solc-$version"
  local shorthand="${version#0.}"

  log "Preparing solc $version"
  if ! "$TOOLS_SOLC_SELECT" install "$version"; then
    log "solc-select install failed; downloading solc $version directly"
    artifact="$SOLC_CACHE_DIR/solc-$version"
    download_solc_direct "$version" "$artifact"
  fi
  ensure_local_directory "$SOLC_BIN_DIR"

  artifact="$(find_solc_artifact "$version" "$artifact")"
  if [ ! -x "$artifact" ] || ! solc_binary_matches_version "$artifact" "$version"; then
    log "Could not find an executable solc $version from solc-select; downloading directly"
    artifact="$SOLC_CACHE_DIR/solc-$version"
    download_solc_direct "$version" "$artifact"
  fi

  if ! solc_binary_matches_version "$artifact" "$version"; then
    die "Could not prepare executable solc $version. Candidate was: $artifact"
  fi

  ln -sf "$artifact" "$SOLC_BIN_DIR/solc-$version"
  ln -sf "$artifact" "$SOLC_BIN_DIR/solc$shorthand"
}

find_solc_artifact() {
  local version="$1"
  local preferred="$2"
  local found=""

  if [ -x "$preferred" ]; then
    printf '%s\n' "$preferred"
    return
  fi

  if [ -d "$HOME/.solc-select/artifacts" ]; then
    found="$(find "$HOME/.solc-select/artifacts" -type f \( -name "solc-$version" -o -name "solc-v$version" -o -name "solc" \) -perm -111 2>/dev/null | head -n 1 || true)"
  fi

  printf '%s\n' "$found"
}

solc_binary_matches_version() {
  local binary="$1"
  local version="$2"
  local escaped_version
  local output

  [ -x "$binary" ] || return 1
  escaped_version="$(printf '%s\n' "$version" | sed 's/[][(){}.^$*+?|\\]/\\&/g')"
  output="$("$binary" --version 2>&1 || true)"
  printf '%s\n' "$output" | grep -Eq "(^|[^0-9])$escaped_version([^0-9]|$)"
}

download_solc_direct() {
  local version="$1"
  local artifact="$2"
  local os_name
  local url

  command -v curl >/dev/null 2>&1 || die "curl is required for direct solc download fallback."
  ensure_local_directory "$SOLC_CACHE_DIR"
  os_name="$(uname -s)"
  case "$os_name" in
    Darwin)
      url="https://github.com/argotorg/solidity/releases/download/v$version/solc-macos"
      ;;
    Linux)
      url="https://github.com/argotorg/solidity/releases/download/v$version/solc-static-linux"
      ;;
    *)
      die "Unsupported OS for direct solc download: $os_name"
      ;;
  esac

  mkdir -p "$(dirname "$artifact")"
  curl -fL --retry 3 -o "$artifact" "$url"
  chmod +x "$artifact"
}

main() {
  if [ "${#CONFIG_FILES[@]}" -eq 0 ]; then
    die "No generated Certora config files were included in this PR."
  fi

  check_java
  install_python_tools

  if [ -z "${CERTORAKEY:-${CERTORA_KEY:-}}" ]; then
    die "Set CERTORAKEY before running, e.g. export CERTORAKEY=<your-certora-api-key>."
  fi

  for version in "${REQUIRED_SOLC_VERSIONS[@]}"; do
    prepare_solc "$version"
  done

  for config in "${CONFIG_FILES[@]}"; do
    [ -f "$config" ] || die "Missing config file: $config"
    log "Running certoraRun $config"
    "$TOOLS_CERTORA_RUN" "$config"
  done
}

main "$@"
