#!/usr/bin/env python3
"""Select the latest APK releases for one app from GitHub's releases API JSON."""

import json
import sys
from pathlib import Path


def asset_for(release: dict, name: str) -> dict | None:
    return next(
        (asset for asset in release.get("assets", []) if asset.get("name") == name),
        None,
    )


def latest_releases(pages: list[list[dict]], app: str) -> list[dict]:
    releases = [release for page in pages for release in page]
    selected = []
    for channel in ("release", "debug"):
        asset_name = f"{app}-{channel}.apk"
        prefix = f"{app}-{channel}-v"
        candidates = [
            release
            for release in releases
            if not release.get("draft")
            and not release.get("prerelease")
            and release.get("tag_name", "").startswith(prefix)
            and asset_for(release, asset_name)
        ]
        candidates.sort(
            key=lambda release: asset_for(release, asset_name).get("created_at", ""),
            reverse=True,
        )
        if candidates:
            selected.append(candidates[0])
    return selected


def main() -> None:
    if len(sys.argv) != 4:
        raise SystemExit("usage: update-release-manifest.py <app> <api-pages.json> <output.json>")
    app, source, destination = sys.argv[1:]
    pages = json.loads(Path(source).read_text(encoding="utf-8"))
    output = latest_releases(pages, app)
    if not output:
        raise SystemExit(f"no published APK releases found for {app}")
    Path(destination).write_text(
        json.dumps(output, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
