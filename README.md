# Athenova APK Index

Static download page for the Food, Stock and ISTQB Android apps. The page reads
public GitHub Releases from this repository and displays the two most recent
published versions per application, with separate Release and Debug APKs.

## Automatic publication on APK generation

Food, Stock and ISTQB Gradle builds load the shared
`gradle/auto-publish-apk.gradle` hook. Completing `packageDebug` or
`packageRelease` publishes that APK to its matching app/channel release. A
content hash check skips publication when the generated APK is unchanged.
Gradle logs the local APK path and whether it was published successfully or was
already available with identical content.

The project expects this repository at `~/proj/APK`. If it is checked out
elsewhere, set `APK_INDEX_REPO` to its path before invoking Gradle.

The publisher creates a uniquely tagged GitHub Release and uploads one APK as
`<app>-<channel>.apk`. For a manual publication:

```sh
./scripts/publish-apks.sh <food|stock|istqb> <debug|release> <app-version> <apk>
```

For example:

```sh
./scripts/publish-apks.sh food debug 1.0 /path/to/app-debug.apk
```

The page sorts each app/channel independently by publication date, so a new
Debug APK advances only the Debug channel: its current becomes anterior, while
Release is unchanged. The first published build in a channel has no previous
release; the page indicates that until a second build is published.

The displayed version is passed from the app's `versionName`. The unique release
tag also includes its publication timestamp, so builds can be kept distinct even
when an app reuses a version name.

## Local preview

Open `index.html` in a browser. It reads the public Releases API, so releases
must exist for download cards to appear. No API token is required in the page.

## Hosting

GitHub Pages serves the root of the `main` branch. The page is plain HTML/CSS/JS
and does not need a build step.
