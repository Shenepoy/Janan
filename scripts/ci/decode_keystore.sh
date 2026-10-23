#!/usr/bin/env bash
# Write android/key.properties from GitHub Actions secrets.
#
# Reads KEYSTORE_BASE64, KEYSTORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD.
# This fork does not have derdilla's Play / F-Droid key. Use your own.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

if [[ -z "${KEYSTORE_BASE64:-}" ]]; then
  echo "KEYSTORE_BASE64 is not set" >&2
  echo "This fork does not own the official signing key. Add your own secrets. See docs/ci.md." >&2
  exit 1
fi

: "${KEYSTORE_PASSWORD:?KEYSTORE_PASSWORD required}"
: "${KEY_ALIAS:?KEY_ALIAS required}"
KEY_PASSWORD="${KEY_PASSWORD:-$KEYSTORE_PASSWORD}"

keystore_path="$ROOT_DIR/android/release-keystore.jks"
echo "$KEYSTORE_BASE64" | base64 --decode > "$keystore_path"

export KEYSTORE_PASSWORD KEY_ALIAS KEY_PASSWORD
python3 "$ROOT_DIR/scripts/ci/write_signing_properties.py" \
  "$keystore_path" "$ROOT_DIR/android/key.properties"

echo "Wrote android/key.properties"
