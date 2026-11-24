import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from update_release_manifest import latest_releases


class LatestReleasesTest(unittest.TestCase):
    def test_selects_latest_release_and_debug_assets_separately(self):
        releases = [
            self.release("food-release-v1.0-old", "2026-11-20T00:00:00Z", "food-release.apk"),
            self.release("food-debug-v1.0-new", "2026-11-24T00:00:00Z", "food-debug.apk"),
            self.release("food-release-v1.0-new", "2026-11-24T00:00:00Z", "food-release.apk"),
            self.release("stock-release-v1.0-new", "2026-11-25T00:00:00Z", "stock-release.apk"),
        ]

        result = latest_releases([releases], "food")

        self.assertEqual(
            ["food-release-v1.0-new", "food-debug-v1.0-new"],
            [release["tag_name"] for release in result],
        )

    def test_ignores_drafts_prereleases_and_releases_without_expected_asset(self):
        releases = [
            self.release("food-release-v1.0-draft", "2026-11-26T00:00:00Z", "food-release.apk", draft=True),
            self.release("food-release-v1.0-pre", "2026-11-25T00:00:00Z", "food-release.apk", prerelease=True),
            self.release("food-release-v1.0-no-asset", "2026-11-24T00:00:00Z", "other.apk"),
        ]

        self.assertEqual([], latest_releases([releases], "food"))

    @staticmethod
    def release(tag, created_at, asset_name, **overrides):
        release = {
            "tag_name": tag,
            "draft": False,
            "prerelease": False,
            "assets": [{"name": asset_name, "created_at": created_at}],
        }
        release.update(overrides)
        return release


if __name__ == "__main__":
    unittest.main()
