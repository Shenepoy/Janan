# Contributing

This is **Janan** (`Zyzto/blood-pressure-monitor-fl`). Issues, pull requests, and releases belong on **this** repository.

When you contribute you agree that the work is under the same license as the project ([GPL-3.0](LICENSE.md)).

## Bugs and features

Use the app, note what is wrong or missing, and [open an issue](https://github.com/Zyzto/blood-pressure-monitor-fl/issues). Check for an existing issue on the same topic first. If you are unsure, open one anyway.

Issues that are hard to reproduce help most when they include steps that cause the problem.

## Texts and translations

Fix grammar and wording in the docs or in the app strings.

Translations live in [`assets/translations`](assets/translations). Edit the JSON and open a pull request.

Build notes and architecture live in [`docs/`](docs/). CI, signing, and Obtainium releases are in [docs/ci.md](docs/ci.md).

To build locally:

1. Install [Flutter](https://docs.flutter.dev/get-started/install) `3.50.0` (pinned in `pubspec.yaml`)
2. `git clone https://github.com/Zyzto/blood-pressure-monitor-fl.git`
3. `cd blood-pressure-monitor-fl`
4. `dart run build_runner build`

Then:

- Run: `flutter run`
- Android APK: `flutter build apk`
  - Release builds (`--release`) need a [signing key](https://docs.flutter.dev/deployment/android#sign-the-app)

Data formats and style notes are in [docs](docs/). Those files started as upstream docs.

Open a PR on this repo. Talking about the change in an issue first is helpful but not required.

Questions about the code: open a discussion or an issue here.

### iOS

Help testing or shipping iOS is welcome. Open an issue here if you can help.
