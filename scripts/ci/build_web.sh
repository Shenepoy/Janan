#!/usr/bin/env bash
# Shared Flutter client web build, matching Hisab's worker and Wasm pipeline.
set -euo pipefail
task_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
task_flutter="${FLUTTER_BIN:-flutter}"
if [[ "$task_flutter" == */* ]]; then task_flutter="$(realpath "$task_flutter")"; fi
task_dart="$(dirname "$(command -v "$task_flutter")")/dart"
cd "$task_root"
"$task_flutter" pub get --enforce-lockfile
"$task_dart" run powersync:setup_web --no-worker
"$task_dart" compile js -O4 --no-source-maps tool/powersync_worker.dart -o web/powersync_db.worker.js
for asset in sqlite3.wasm powersync_db.worker.js; do
  test -s "web/$asset"
done
"$task_flutter" build web --wasm --no-wasm-dry-run --no-web-resources-cdn "$@"
python3 scripts/ci/stage_offline_web.py "$@"
