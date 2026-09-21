# GitHub workflow agent guide

Applies to `.github/**`. Read the root guide first and inspect the exact live
workflow before changing CI.

## Contracts

- `workflows/ci.yml` runs on pushes to `main` and on pull requests. It runs
  `flutter pub get --enforce-lockfile` and `flutter test` in `app/`. Nothing else.
- There is no GitHub workflow that publishes store binaries, the marketing
  site, or a hosted API. Do not add deploy, Fastlane, or image-publish
  workflows here.
- Keep permissions least-privilege, secrets referenced through GitHub contexts,
  third-party actions intentionally pinned, and untrusted PR input out of
  privileged shells.

## Change and verification practice

- Reproduce a failure from current run logs before editing.
- Keep the Flutter version in `ci.yml` aligned with `app/pubspec.yaml`.
- After workflow edits, run `cd app && flutter test` locally when you can.
