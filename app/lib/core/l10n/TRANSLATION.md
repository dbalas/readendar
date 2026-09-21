# Readendar translation guide and glossary

The product ships **Spanish UI today**, worldwide. `es` is the source locale and
the only ARB catalog for now. Additional locales are welcome when they are added
with the same key parity, tests, and native-widget coverage as Spanish.

## Where strings live

- **App (Flutter):** `lib/core/l10n/arb/app_es.arb` is the template (source of
  truth for keys, placeholders, and `@`-metadata). Run `flutter gen-l10n`.
- **Native widgets:** `Strings`/`types` tables in `ReadendarWidgetProvider.kt`
  and `ReadendarWidget.swift` (Spanish).

Store listing copy is not in this repository.

## Rules

1. **Never translate the brand** `Readendar`, product names (Goodreads, Kindle,
   Amazon, Google, Apple), ISBNs, URLs, or email addresses.
2. **Preserve every placeholder** exactly: `{count}`, `{name}`, `{days}`, …
   never rename or translate the identifier.
3. **Preserve ICU plural/select structure.** Plurals use the `one`/`other`
   categories (plus an explicit `=0` where present). Keep the branches; translate
   only the human text inside each `{…}`.
4. **Tone:** informal second person (tú), consistent with a friendly consumer
   app. Match the register of the existing Spanish copy.
5. **Keep parity:** the Spanish template must contain every key.
   `test/core/l10n/app_locales_test.dart` + `locale_smoke_test.dart` enforce this.
6. **Never use the em dash in user-visible copy.** Not in ARBs or native widget
   strings. Prefer a period, comma, colon, or parentheses. (Hyphen `-` and en
   dash `–` in ranges are fine when needed.)
