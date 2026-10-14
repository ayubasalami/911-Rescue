# Firebase

| Flavor  | Firebase project      | App ID suffix |
|---------|-----------------------|---------------|
| dev     | `rescue-staging`      | `.dev`        |
| staging | `rescue-staging`      | `.staging`    |
| prod    | `rescue-me-app-a3b51` | (none)        |

`bootstrap.dart` initializes Firebase with the flavor's
`lib/firebase_options_<flavor>.dart`. Native configs live in
`android/app/src/<flavor>/google-services.json` and
`ios/config/<flavor>/GoogleService-Info.plist`; an iOS build phase
(`flutterfire bundle-service-file`) copies the right plist in, so
`flutterfire_cli` must be installed on any machine that builds iOS:
`dart pub global activate flutterfire_cli`.

## Analytics

Event names live in `lib/src/core/analytics_events.dart`. Parameters never
carry coordinates, addresses, place names or search text.

### DebugView

Events from debug builds appear in Firebase console → Analytics → DebugView
within seconds, and are kept out of the normal reports.

- **iOS:** automatic on every debug build — `AppDelegate.swift` turns debug
  mode on under `#if DEBUG` (`flutter run` drops Xcode's `-FIRDebugEnabled`
  launch argument, so it can't be used). `#if DEBUG` relies on
  `SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG` in `ios/Flutter/Debug.xcconfig`.
- **Android:** run once per device/emulator session, then force-stop and
  relaunch the app (the flag is read at process start, and resets when the
  device restarts):

  ```
  adb shell setprop debug.firebase.analytics.app com.bwanalytics.rescue911.staging
  ```

  Use `.dev` or no suffix for the other flavors — only one package at a
  time. Turn it off with `adb shell setprop debug.firebase.analytics.app .none.`
  Without it, Android debug-build events go to the normal reports.

## Crashlytics

`bootstrap.dart` sends Flutter framework errors and uncaught async errors to
Crashlytics; `ApiClient` reports unparseable responses as non-fatals.
Collection is on in every build. To test, call
`ref.read(crashReportingServiceProvider).forceCrash()` from a temporary
button; reports upload on the app's next launch and can take a few minutes
to fill in. On iOS, a crash while Xcode or `flutter run`'s debugger is
attached is caught by the debugger and never reported — stop `flutter run`,
reopen the app from the home screen, crash it, and open it once more.
