# Security policy

## Supported versions

Report vulnerabilities against the current `main` branch and the latest store
builds.

## Report a vulnerability

Email [hello@readendar.com](mailto:hello@readendar.com) with:

- a description of the issue
- steps to reproduce, or a proof of concept
- affected surface (Flutter app)

Do not open a public GitHub issue for security reports.

You should hear back within 7 days. Please give us a reasonable window to
fix and ship before any public disclosure.

## Scope notes

The product is local-first. New installs do not talk to a Readendar API.
Until 15 October 2026 12:00 UTC, leftover JWTs can still call a hosted export
endpoint that is not part of this repository. After that date the export
window closes.
