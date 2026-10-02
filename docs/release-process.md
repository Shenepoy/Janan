# Release process

## Versioning

App versions are calendar versions: `YY.0M.MICRO+BUILD`

| Part | Meaning | Example |
|------|---------|---------|
| `YY` | Two-digit year | `26` |
| `0M` | Zero-padded month | `08` |
| `MICRO` | Release index in that month, starting at `0` | `0`, `1`, `10` |
| `BUILD` | Android `versionCode` / iOS `CFBundleVersion`. Always increments. Used for in-app upgrades (`last_version`). | `58` |

Examples:

- First August 2026 release: `26.08.0+58`
- Second that month: `26.08.1+59`
- First September release: `26.09.0+60`

The name lives in `pubspec.yaml`. Flutter keeps the leading zero on the month. Tag GitHub releases as `v26.08.0`.

`tools/release_tool` computes the next `YY.0M.MICRO` from the current UTC month and increments `BUILD`.

## App release checklist

How this tree ships APKs: [docs/ci.md](ci.md).

Treat a direct request to cut, publish, or push a release as authorization to complete this
checklist through the GitHub Release.

1. Choose the next `YY.0M.MICRO+BUILD` version. Use `tools/release_tool` and the current UTC
   month; keep `BUILD` increasing. Set `version:` in `pubspec.yaml`. The matching tag omits the
   build suffix, for example `26.10.0+73` maps to `v26.10.0`.
2. Run every step in GitHub Actions CI (`.github/workflows/ci.yml`) against the versioned changes.
   Resolve failures and rerun until code generation, translation validation, analysis, tests,
   goldens, and the debug APK build pass.
3. Commit the release changes and push the commit to `main`. Wait for the `CI` run on that exact
   commit to pass.
4. Confirm the matching `vYY.0M.MICRO` tag does not already exist. Create an annotated tag at the
   CI-green commit and push that tag to `origin`.
5. Wait for the tag-triggered `Release` workflow. Confirm it passes and the GitHub Release contains
   the ABI APKs (`armeabi-v7a`, `arm64-v8a`, `x86_64`), universal APK, and symbols archive before
   reporting the release as published.

Never move or overwrite an existing release tag. If a tagged release needs a code fix, use a new
micro version and build number.

Obtainium follows that GitHub Release.

Do not upload this APK to Play or F-Droid. Those listings are not ours.
