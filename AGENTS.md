# Readendar agent guide

Stable repo-wide contract for coding agents. Keep short. Details live in scoped
guides. `CLAUDE.md` → this file.

## Load context (token discipline)

Load **only** what the task needs. Do not inventory the repo or preload READMEs,
generated files, l10n catalogs, or native trees.

1. This file.
2. Scoped guide for every area you edit: [app](app/AGENTS.md) ·
   [.github](.github/AGENTS.md). Design asset rules are under **Design assets**
   below.
3. Prefer nearest implementation + its tests over prose.

```bash
rg --files <area> | rg '<feature|file>'
rg -n '<symbol|route|key>' <area>
```

## Core contract

- English with the user.
- Never use the em dash character in product copy, UI strings, commits, PR
  text, chat replies, or new docs. Use a comma, period, colon, or parentheses.
- Inspect before edit. Preserve unrelated dirty-worktree changes.
- Code, tests, schemas, checked-in config beat narrative docs. Fix stale guides
  when a task exposes them.
- Stay in requested scope. No destructive data/infra/deploy/git/external actions
  without clear authorization.
- **Red → green → refactor.** Behavior change = test first (or with the change).
  Cover the changed surface fully: happy path, failure path, and auth/edge cases
  the code can hit. No untested behavior ships.
- User-initiated ops: localized success + error feedback; never swallow failures
  or claim success before durable completion. Tests must cover both branches.
- Never weaken validation, secrets, or ownership scoping for convenience.
- One rule, one owner. No shims / duplicated business rules unless a live
  contract requires them.
- Generated outputs only via canonical command: never hand-edit `l10n/gen/`.
- Keep this root guide under ~800 words. Detail → nearest scoped guide.

## Surfaces (truth)

| Surface | Truth |
|---|---|
| `app/` | `lib/**`, `android/**`, `ios/**` |
| `design/` | `colors_and_type.css`, fonts, SVGs |
| `.github/workflows/` | workflow YAML |

Deps point inward:

- App: core has no features; `di/` composes; UI under `features/`.

Tokens: [design/colors_and_type.css](design/colors_and_type.css). Versions:
lockfiles / `pubspec.yaml`. Do not snapshot versions here.

This repository does not contain a hosted API, admin desk, marketing site, or
store-signing tree. Do not add features that need them.

## Design assets (`design/**`)

- `colors_and_type.css` is the semantic visual source of truth for Flutter.
  Update `app/lib/core/theme/` when a token contract changes.
- Fonts and SVGs under `design/` are sources; store rasters and platform icon
  PNGs under `app/` are outputs. Do not hand-edit every derivative when a single
  source SVG changes without updating the matching outputs deliberately.
- Preserve SVG view boxes, transparency, text-to-path/font assumptions, and brand
  contrast. Do not introduce a second token or asset with the same meaning.
- Icon, logo, and artwork changes need visual check at intended dimensions.
  Mobile UI tied to tokens still needs light/dark and Android/iOS adaptive chrome
  checks per [app/AGENTS.md](app/AGENTS.md).

## Change workflow

Before edit: `git status --short` → owning layer → closest impl + test pattern.

While editing:

- Thin widgets; rules in owning helper.
- Localize new/changed copy in Spanish (`app_es.arb`) today. The UI ships
  Spanish only for now; more locales are welcome when product adds them.
  Catalog search uses Open Library, Empathy/Casa del Libro, and the BNE;
  other sources are open for contribution. Light/dark + Android/iOS
  capability parity for mobile.
  Flutter UI is **adaptive** (Material Android, Cupertino/glass iOS) via unique
  `Rd*` seams that branch inside `app/lib/core/widgets/`. See
  [app/AGENTS.md](app/AGENTS.md); do not unify chrome across platforms.
- Semantic design tokens only; no one-off colors or duplicated platform behavior.

### Verify

Default to the narrowest meaningful verification: tests nearest to touched
files and lint/analyze limited to those files. Do not run a surface-wide suite
unless the user explicitly requests it.

| Change | Default focused verification | Full suite (explicit request only) |
|---|---|---|
| Flutter | `flutter test <path>` in `app/` | `flutter test`, `flutter analyze` in `app/` |
| Workflow | unit/static | note unverified external steps |
| Docs only | paths/links/commands | no product suite unless behavior changed |

If a check cannot run, state exactly what was skipped and why.

## Done when

All applicable:

- [ ] Changed behavior has full test coverage (success, failure, relevant edges)
- [ ] User actions: success + error feedback implemented **and** tested
- [ ] Strings localized for **all current languages** on the touched surface
- [ ] Flutter light/dark + Android/iOS capability parity; adaptive chrome
      preserved (Material vs Cupertino via core `Rd*` seams, not feature forks)
- [ ] Widget-path updates when book/event/progress/quote display changes
- [ ] Generated artifacts via canonical command only
- [ ] Handoff: validation run + real gaps
