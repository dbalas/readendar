# Flutter app agent guide

Applies to `app/**`, including Android/iOS native code. Read the root
[AGENTS.md](../AGENTS.md) first, then the nearest test next to the code you
change. There is no `docs/agents/` tree in this repository.

## Architecture and state

- `lib/core/` is reusable and has no feature knowledge. It owns shared models,
  networking, failures, storage, localization, theme, utilities, and design-system
  widgets.
- `lib/data/` owns SQLite repositories and catalog HTTP. Until 15 October 2026
  the Dio client is only for leftover cloud export/auth (`GET /v1/me/export`
  and login). Do not add product features that need the hosted API.
- `lib/di/providers.dart` is the composition seam. Per-ID/family providers are
  `.autoDispose` unless a documented lifecycle requirement proves otherwise.
  UI must handle `AsyncValue` loading / error / data like sibling screens;
  invalidate/refresh the same providers as comparable flows.
- `lib/features/<name>/` owns feature UI and feature-specific domain/helpers.
  Keep reusable primitives in core, but do not prematurely generalize one-off UI.
- Lift repository failures through the existing `Failure` / `FailureException`
  path so screens localize one consistent error model.

Stateful objects such as `TextEditingController`, focus nodes, animation
controllers, and subscriptions must be created outside `build()` and disposed.
Bottom sheets that own controllers should be stateful.

## UI contract

- **Design-system first** (app equivalent of shadcn): reuse
  `lib/core/widgets/` before adding feature-local controls. Confirmation prompts
  use `confirm_dialog.dart` (`showConfirmDialog` /
  `showConfirmChoiceDialog` / `showTypeToConfirmDialog`). **Always pass a
  header `icon:`** (and usually `confirmIcon:`) so every confirm modal matches
  the rest of the app — never ship a bare title-only confirm. Transient feedback
  uses `toast.dart` (`showRdToast` / `showRdFailureToast`) — never hand-roll
  `SnackBar`. Data-entry dialogs may be bespoke.
- **Adaptive chrome (permanent contract — keep and extend):** iOS ≠ Android is
  intentional product design, not a temporary experiment. Android keeps Material;
  iOS/macOS use Cupertino / glass / soft-fill. Same information architecture,
  actions, and copy; different control chrome, radii, nav, sheets, search, and
  form fields. Never “fix” one platform to look like the other. Never regress
  to a single shared look for convenience.
- **One unique adaptive component, branch inside:** features call a single
  `Rd*` / `showRd*` API. Platform bifurcation lives only inside that core
  widget (or `core/utils/platform_chrome.dart` via `usesCupertinoChrome`) —
  never `if (Platform.isIOS)` / raw `Cupertino*` / Material chrome forks in
  `features/`, and never parallel `*_ios.dart` / `*_android.dart` screen trees.
  New chrome → add or extend one adaptive seam in `lib/core/widgets/`, then
  reuse it.   Prefer existing seams: `RdRootNavBar` (floating glass pill on Apple;
  translucent glass + full-item stadium destinations on Android),
  `RdSectionTabs` (unified pill track on every platform — intentional
  exception to adaptive chrome), `RdCreateAction`, `RdButton` (solid pill CTAs —
  not glass),   `RdOverflowMenu` / `showRdMenu`, `RdContextMenu` (long-press),
  `RdListItemActions` (swipe list actions),
  `RdReorderableRow` (delayed long-press reorder, no grip handle),
  `RdSegmentedControl`,   `RdTextField` / `RdTextFormField` / `RdFormSelectField`
  (soft-fill form chrome on Apple — never raw `TextField` / `TextFormField` /
  `DropdownButtonFormField` / `showDatePicker` at feature sites),
  `RdDropdownField` (sheet picker via `showRdMenu` on every platform — never
  Material `DropdownButtonFormField` overlay), `OptionSelector`,
  `RdCheckbox` / `RdCheckboxListTile`,
  `RdSlider`, `RdRefresh`, `RdProgress`, `showRdDatePicker` /
  `showRdTimePicker`, `showRdNavSheet`, `RdSearchField` (branded soft pill on
  Apple),   `RdSwitchListTile`, `SettingsGroup`, `RdSliverLargeTitle` /
  `RdLargeTitleScaffold` (optional collapsing large titles — root tabs keep
  compact `AppBar` titles so they stay aligned with Calendar/Home), plus
  glass primitives `RdGlassPanel` / `showRdModalSheet`.
  Glass is for floating overlays only (nav, menus, sheets, pickers) — never
  frost cards / form fields / mundane buttons. Use `rdFloatingNavContentInset`
  for root-tab scroll padding under the floating pill (both platforms), and
  `RdCreateAction.fab(aboveFloatingNav: true)` (or the same inset on a
  positioned FAB) so create FABs sit **above** the pill — not under it.
  `showRdModalSheet`
  applies keyboard viewInsets — do not double-wrap. Never stock
  `CupertinoTabBar` / `CupertinoSearchTextField` / `CupertinoActionSheet` / raw
  `showModalBottomSheet` at feature call sites. New bottom sheets should use
  `showRdModalSheet`; choice menus use `showRdMenu`. Empty states prefer
  worked `illustration:` scenes (`EmptyArtBackdrop` / `EmptyArtCard`) over bare
  icons; CTAs use `RdButton` so Apple pills vs Material buttons stay correct.
  Widget tests that touch chrome should cover both platforms (override
  `ThemeData.platform`) where behavior diverges — see
  `test/core/widgets/rd_adaptive_chrome_test.dart` and
  `test/core/theme/ios_adaptive_chrome_test.dart`.
- **Search fields:** always use `RdSearchField` from
  `lib/core/widgets/search_field.dart` for free-text lookup / filter UIs
  (library, catalog search, pickers, filters sheet, etc.).
  Do not invent per-screen `TextField` + `InputDecoration` search bars.
- **Form fields:** always use `RdTextField` / `RdTextFormField` for typed
  entry and `RdFormSelectField` / `RdDropdownField` / `OptionSelector` for
  selects so Apple soft-fill chrome stays consistent across a form.
- No hard-coded user-visible text. Use `AppL10n.of(context)` and add/update the
  key in `app/lib/core/l10n/arb/app_es.arb`. Spanish is the only locale today;
  additional locales are welcome when product adds them.
  Follow `lib/core/l10n/TRANSLATION.md`. Never use the em dash (`—`) in
  user-visible copy (period/comma/colon instead). Never hand-edit
  `lib/core/l10n/gen/` — run `flutter gen-l10n`.
- Format dates/numbers using the full locale through `core/utils/`; sort visible
  text with locale-aware collation, not raw `compareTo`.
- Calendar/planner: follow existing date-only vs instant helpers. Do not mix
  local “today” with UTC timestamps casually; mirror nearby plan/event code.
- `design/colors_and_type.css` is the visual source; Flutter primitives live in
  `lib/core/theme/`. Use `context.colors.<semanticRole>` for theme-dependent
  colors. `ReadendarTokens` is for spacing, radii, type, and intentional
  brightness-independent brand constants.
- Typography has shared semantic owners: navigation/control titles remain the
  DM Sans `title*` roles; literary/content titles use the Newsreader
  `displaySmall` / `headlineLarge` / `headlineSmall` roles, with
  `EditorialTitle` owning prominent content-entry titles and their interrupted
  accent rule; grouped content labels use `SectionHeader`, including the same
  rule; long-form editorial copy uses `ReadendarTextStyles.editorialBody`. Do
  not create per-screen font families, weights, tracking, or near-duplicate
  title styles.
- Never introduce raw `Color(0x...)` in feature widgets or use neutral palette
  constants as surfaces/text. Do not add per-screen brightness branches when a
  semantic color role should own the behavior.
- Use the existing status/event color seams (`core/widgets/book_status_ui.dart`,
  `EventType.colorOf`/`colorFor`) instead of rebuilding mappings at call sites.
- Use `CachedNetworkImageProvider` for repeatedly rendered remote covers.

Every UI change must be checked in light and dark themes. Tests should cover
semantic behavior; visually inspect both themes when layout/color changed.

### Premium theme contract

- Premium themes are complete visual identities, not recolors. Each new one must
  have a unique semantic light/dark palette, app-canvas treatment, restrained
  motion language, celebration treatment, and a
  cinematic book-detail atmosphere. Do not approve a theme whose dominant hue,
  material, or motion concept can be mistaken for an existing theme.
- `lib/core/theme/theme_manifest.dart` is the single source. Add the ID/effect,
  localized label in every base ARB, painter treatment, cross-surface artwork,
  and focused tests together; run `dart run tool/generate_native_themes.dart`
  and `flutter gen-l10n` instead of editing generated/native catalogs directly.
- Premium previews reuse `ThemePreviewCard` with the standard 132px height and
  spacing. The collection already communicates entitlement, so cards must not
  add a premium star/sparkle badge. Selection check/progress remains overlaid at
  the top-right and must retain correct clipping and rounded borders.
- Atmosphere stays subtle and content-first: no pronounced card shadows or
  elevations, no constant visual noise, no obscured text, and no expensive work
  in foreground rebuilds. Isolate animated painters with `RepaintBoundary`,
  honor reduced-motion/TickerMode, and test animation containment.
- Premium additions must preserve local-only theme persistence and Original
  fallback for missing/retired IDs. Cover-derived color remains explicit opt-in
  and computed locally. Themes are ungated.

## Android and iOS parity

Flutter work targets both platforms unless the product explicitly says otherwise.
**Parity means capability + flow, not identical chrome** — see UI contract above
(iOS Cupertino/glass vs Android Material is intentional). When an OS capability
is involved, inspect and update both `android/**` and `ios/**` as applicable:

- permissions and privacy descriptions (iOS `permission_handler` macros in
  `ios/Podfile`: `PERMISSION_CAMERA`, `PERMISSION_MICROPHONE`,
  `PERMISSION_SPEECH_RECOGNIZER`, matching Info.plist usage strings);
- intent filters, URL schemes, and associated domains;
- notification, storage, picker, auth, sharing, and lifecycle behavior;
- build files, deployment targets, entitlements, and native dependencies;
- native widget renderers/configuration.

Guard platform-specific APIs and provide an equivalent implementation or an
explicit safe fallback. Widget tests do not prove native compilation; run the
relevant Android/iOS build when locally available and name any unverified platform
in the handoff.

## Data-changing flows

- Every user-initiated async operation must implement localized success and error
  feedback, plus a loading/disabled state when repeat submission is possible.
  Confirm success only after the durable operation succeeds; make failures visible
  and actionable instead of swallowing them in logs or best-effort callbacks. Test
  both the success and failure feedback branches.
- Mutations must invalidate/refresh the same providers and local notification
  state as comparable existing flows.
- Any new path that changes reading books, progress, events, or quote-widget data
  must preserve the synchronization contract in `features/widget/widget_sync.dart`.
- Handle partial network failures explicitly. Multi-step create flows must use
  existing idempotency/rollback behavior and must not leave the UI claiming a
  failed operation succeeded.
- Keep Dart enums and DTO models aligned in the same change. This repository
  does not contain a hosted API or OpenAPI spec.

## Tests and commands

Full coverage of the changed surface: happy path, failure path, and edges the
new code can hit. No untested behavior in the diff. Mirror the source path under
`test/`. Prefer unit tests for pure generators/models, widget tests for visible
states/interactions, and integration tests only for flows that require
platform/app boundaries.

From `app/`:

```bash
flutter test test/<focused_test>.dart
flutter test test/features/<feature>/
flutter analyze
flutter gen-l10n
```

Use `flutter gen-l10n` only when localization inputs changed; generated files under
`lib/core/l10n/gen/` are outputs, not editing targets. Broad gates: `flutter test`
and `flutter analyze` from `app/`.

