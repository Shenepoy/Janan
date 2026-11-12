#!/usr/bin/env bash
# Build signed, obfuscated APKs for every Flutter ABI plus one universal APK.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

DIST_DIR="${DIST_DIR:-dist}"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
SYMBOLS_DIR="${SYMBOLS_DIR:-build/app/outputs/symbols}"
if [[ "$DIST_DIR" != /* ]]; then
  DIST_DIR="$ROOT_DIR/$DIST_DIR"
fi
if [[ "$SYMBOLS_DIR" != /* ]]; then
  SYMBOLS_DIR="$ROOT_DIR/$SYMBOLS_DIR"
fi
JANAN_FLAVOR="${JANAN_FLAVOR:-foss}"
ARTIFACT_PREFIX="${ARTIFACT_PREFIX:-janan-${JANAN_FLAVOR}}"
build_args=("--target=${JANAN_TARGET:-lib/main.dart}")
if [[ -n "${JANAN_DART_DEFINE_FILE:-}" ]]; then
  build_args+=("--dart-define-from-file=$JANAN_DART_DEFINE_FILE")
fi
APK_DIR="$ROOT_DIR/build/app/outputs/flutter-apk"
MAPPING_FILE="$ROOT_DIR/build/app/outputs/mapping/${JANAN_FLAVOR}Release/mapping.txt"
TARGET_PLATFORMS="android-arm,android-arm64,android-x64"

if ! command -v zip >/dev/null 2>&1; then
  echo "zip is required to package the Dart symbols and R8 mapping" >&2
  exit 1
fi

# Do not let a stale output look like a successful build.
mkdir -p "$DIST_DIR"
find "$DIST_DIR" -mindepth 1 -maxdepth 1 -type f -delete
mkdir -p "$SYMBOLS_DIR"
# A fresh path prevents Flutter's incremental cache from skipping symbol output
# after a previous archive was produced or files were cleaned.
symbols_work="$(mktemp -d "$SYMBOLS_DIR/run.XXXXXX")"
mkdir -p "$symbols_work/split" "$symbols_work/universal"

"$FLUTTER_BIN" build apk --release --flavor "$JANAN_FLAVOR" \
  --split-per-abi \
  --obfuscate \
  --split-debug-info="$symbols_work/split" \
  --target-platform "$TARGET_PLATFORMS" "${build_args[@]}"

eval "$(bash ./scripts/ci/app_version.sh)"
for abi in armeabi-v7a arm64-v8a x86_64; do
  input="$APK_DIR/app-${abi}-${JANAN_FLAVOR}-release.apk"
  output="$DIST_DIR/${ARTIFACT_PREFIX}-${name}-${abi}.apk"
  if [[ ! -s "$input" ]]; then
    echo "Missing split APK: $input" >&2
    exit 1
  fi
  cp "$input" "$output"
done

"$FLUTTER_BIN" build apk --release --flavor "$JANAN_FLAVOR" \
  --obfuscate \
  --split-debug-info="$symbols_work/universal" \
  --target-platform "$TARGET_PLATFORMS" "${build_args[@]}"

universal="$APK_DIR/app-${JANAN_FLAVOR}-release.apk"
if [[ ! -s "$universal" ]]; then
  echo "Missing universal APK: $universal" >&2
  exit 1
fi
cp "$universal" "$DIST_DIR/${ARTIFACT_PREFIX}-${name}-universal.apk"

if [[ ! -s "$MAPPING_FILE" ]]; then
  echo "R8 mapping file was not generated: $MAPPING_FILE" >&2
  exit 1
fi

for variant in split universal; do
  for arch in android-arm android-arm64 android-x64; do
    symbol="$symbols_work/$variant/app.$arch.symbols"
    test -s "$symbol" || { echo "Missing Dart symbols: $symbol" >&2; exit 1; }
  done
done

symbols_archive="$DIST_DIR/${ARTIFACT_PREFIX}-${name}-symbols.zip"
rm -f "$symbols_archive"
archive_root="$(mktemp -d)"
trap 'rm -rf "$archive_root"' EXIT
mkdir -p "$archive_root/symbols" "$archive_root/r8"
cp -R "$symbols_work"/. "$archive_root/symbols/"
cp "$MAPPING_FILE" "$archive_root/r8/mapping.txt"
(
  cd "$archive_root"
  zip -q -r "$symbols_archive" symbols r8
)
trap - EXIT
rm -rf "$archive_root"

echo "Release artifacts:"
ls -lh "$DIST_DIR"
