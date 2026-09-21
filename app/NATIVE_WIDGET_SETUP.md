# Home-screen widgets

Native widget targets already live in this tree:

- iOS: `ios/ReadendarWidget/`
- Android: `ReadendarWidgetProvider.kt` plus the layout/xml resources

The app is local-first. Dart writes a JSON snapshot into the App Group /
`home_widget` store. Native timelines render that cache. Taps enqueue
`wdg_pending_ops` so the next app open applies them to SQLite. Do not add
features that need a hosted widget API.

## Shared keys (`widget_bridge.dart`)

| key | meaning |
|-----|---------|
| `wdg_cached_summary` | events/progress snapshot from the local library |
| `wdg_quotes_cache` | quotes snapshot |
| `wdg_pending_ops` | taps queued while the app was closed |
| `wdg_locale` / `wdg_theme` / `wdg_scheme` | chrome |
| `wdg_access` / `wdg_refresh` / `wdg_base_url` | unused leftovers; empty on new installs |

App Group: `group.com.readendar.readendar`.

## iOS

1. Keep the `ReadendarWidget` target, App Group on Runner + extension, and
   `ENABLE_DEBUG_DYLIB = NO` on the widget target.
2. Release uses `Runner.entitlements` (App Group, Sign in with Apple,
   Associated Domains for leftover magic links). Debug/Profile use
   `Runner.siwa-debug.entitlements`.
3. Keep the `Resign Widget Simulator Entitlements` build phase
   (`ios/resign_widget_simulator_entitlements.sh`) so App Group sync works
   on simulator.
4. Associated Domains (`applinks:api.readendar.com`,
   `applinks:readendar.com`) stay until the export window closes.

Forks must change `DEVELOPMENT_TEAM` in the Xcode project and the App Group
id.

## Android

The `<receiver>` entries and Glance/RemoteViews layouts are already in
`AndroidManifest.xml` and `res/`. Gradle sync is enough. Forks must change
`applicationId` and signing.

## Covers

Native widgets still prefer cached chips when a remote cover URL is not
reachable. Local sidecar covers are copied into the snapshot when the app
syncs.
