# AI Prover rules for Answer

These Certora Prover artifacts were generated for `SmokeTest/src/Answer.sol`.

## Source inputs

- Design: `SmokeTest/design.md`
- Threat model: None

## Generated files

- `certora/specs/autospec_Answer_Function.spec`
- `certora/specs/summaries/Answer_base_summaries.spec`
- `certora/specs/summaries/Answer_call_resolution-2.spec`
- `certora/confs/autospec_Answer_Function.conf`
- `certora/mocks/DummyERC20Impl.sol`

## Run the rules

How to run Certora Prover:

1. Export your Certora Prover API key:

```bash
export CERTORAKEY=<your-certora-api-key>
```

2. From the repository root, run the generated helper script:

```bash
bash certora/run-ai-prover-2.sh
```

The script checks your local toolchain, installs or updates Python CLI tools into a repo-local `certora/.certora-tools` virtual environment with a one-week PyPI cooldown, prepares the required Solidity compiler binaries, and then runs:

```bash
certoraRun certora/confs/autospec_Answer_Function.conf
```

Note: `certoraRun` uploads the repository to Certora's cloud for verification.

## Manual fallback

If `bash certora/run-ai-prover-2.sh` fails, run these steps from the repository root.

1. Make sure the required base tools are present:

```bash
python3 --version
java -version
```

2. Install the Certora Python tools locally:

```bash
rm -rf certora/.certora-tools/venv
python3 -m venv certora/.certora-tools/venv
UV_VERSION="$(
certora/.certora-tools/venv/bin/python - uv 7 <<'PY'
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
candidates.sort()
print(candidates[-1][1])
PY
)"
certora/.certora-tools/venv/bin/python -m pip install --disable-pip-version-check --upgrade --no-deps "uv==$UV_VERSION"
certora/.certora-tools/venv/bin/uv pip install --python certora/.certora-tools/venv/bin/python --upgrade --reinstall --exclude-newer "1 week" certora-cli solc-select
certora/.certora-tools/venv/bin/certoraRun --version
```

3. Prepare the Solidity compiler binaries expected by the generated config:

```bash
certora/.certora-tools/venv/bin/solc-select install 0.8.34
mkdir -p certora/.certora-tools/solc-bin
SOLC_BIN="$HOME/.solc-select/artifacts/solc-0.8.34/solc-0.8.34"
"$SOLC_BIN" --version | grep -F '0.8.34'
ln -sf "$SOLC_BIN" "certora/.certora-tools/solc-bin/solc-0.8.34"
ln -sf "$SOLC_BIN" "certora/.certora-tools/solc-bin/solc8.34"
export PATH="$PWD/certora/.certora-tools/solc-bin:$PATH"
```

If `solc-select install` fails or does not create the expected binary, download the compiler directly:

```bash
mkdir -p certora/.certora-tools/solc-cache certora/.certora-tools/solc-bin
curl -fL --retry 3 -o "certora/.certora-tools/solc-cache/solc-0.8.34" "https://github.com/argotorg/solidity/releases/download/v0.8.34/solc-macos"
chmod +x "certora/.certora-tools/solc-cache/solc-0.8.34"
"certora/.certora-tools/solc-cache/solc-0.8.34" --version | grep -F '0.8.34'
ln -sf "../solc-cache/solc-0.8.34" "certora/.certora-tools/solc-bin/solc-0.8.34"
ln -sf "../solc-cache/solc-0.8.34" "certora/.certora-tools/solc-bin/solc8.34"
export PATH="$PWD/certora/.certora-tools/solc-bin:$PATH"
```

4. Export your Certora API key and run the generated config:

```bash
export CERTORAKEY=<your-certora-api-key>
certora/.certora-tools/venv/bin/certoraRun certora/confs/autospec_Answer_Function.conf
```
