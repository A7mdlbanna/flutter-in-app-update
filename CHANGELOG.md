## 0.0.1

* `InAppUpdateScope` widget and `InAppUpdateController`: mandatory updates by default (immediate flow on every open/resume, re-prompt on cancel, flexible fallback that installs itself), or optional flexible/immediate updates.
* `InAppUpdate.checkForUpdate`, `startUpdate`, `completeUpdate` and `installStateChanges`.
* Android: Google Play In-App Updates (Play Core `app-update` 2.1.0).
* iOS: App Store version check via the iTunes Lookup API, App Store page shown in-app with `SKStoreProductViewController`.
* Web and desktop report `unsupported`.
