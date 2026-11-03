# Athenova APK Index

Static download page for the Food, Stock and ISTQB Android apps. The page reads
public GitHub Releases from this repository and displays the two most recent
published versions per application, with separate Release and Debug APKs.

## Publishing an app build

After building the Debug and Release APKs, publish both together:

```sh
./scripts/publish-apks.sh <food|stock|istqb> <app-version> <debug.apk> <release.apk>
```

For example:

```sh
./scripts/publish-apks.sh food 1.0.0 \
  /path/to/app-debug.apk /path/to/app-release.apk
```

The script creates a uniquely tagged GitHub Release and uploads assets named
`<app>-debug.apk` and `<app>-release.apk`. The page sorts releases by publication
date, so a newly published build becomes **Atual** and the previous current
build automatically becomes **Anterior**. The first published build has no
previous release; the page indicates that until a second build is published.

The displayed version is passed from the app's `versionName`. The unique release
tag also includes its publication timestamp, so builds can be kept distinct even
when an app reuses a version name.

## Local preview

Open `index.html` in a browser. It reads the public Releases API, so releases
must exist for download cards to appear. No API token is required in the page.

## Hosting

GitHub Pages serves the root of the `main` branch. The page is plain HTML/CSS/JS
and does not need a build step.
