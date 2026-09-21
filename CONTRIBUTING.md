# Contributing

Thanks for helping. Read [README.md](README.md) for product scope, languages, and
catalog sources. Contributor docs and code comments are English.

Please read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). By opening a pull request
you agree to the [Apache License 2.0](LICENSE). The [Readendar name, logo, and
Rendi mascot](TRADEMARK.md) are not licensed.

Public source trees are `app/` and `design/` only. Keep new work local-first:
the library lives on the device.

## Run the app

Flutter 3.44.6+ (`app/pubspec.yaml`).

```bash
cd app
flutter pub get
flutter gen-l10n                   # after changing app_es.arb; commit gen/
flutter run
```

The app boots a local guest library with no extra config.

## Tests

Changed behavior needs tests: happy path, failure, and relevant edges. Mirror
`app/lib/...` under `app/test/...`.

```bash
cd app && flutter test test/path/to/focused_test.dart
cd app && flutter test
```

Do not hand-edit `app/lib/core/l10n/gen/`. Update
`app/lib/core/l10n/arb/app_es.arb`, run `flutter gen-l10n`, commit the generated
files. Never use an em dash in user-visible copy.

## UI and design

Flutter chrome is adaptive (Material on Android, Cupertino/glass on iOS). Features
use `Rd*` widgets in `app/lib/core/widgets/`. Design tokens live in
`design/colors_and_type.css` and `app/lib/core/theme/`. See [app/AGENTS.md](app/AGENTS.md)
and [AGENTS.md](AGENTS.md).

## Pull requests

- Keep the diff on the requested surface (`app/` or `design/`).
- Include tests for new behavior.
- Localize new copy in Spanish (and in every shipped locale once more exist).
- Say how you verified (tests, platform).
