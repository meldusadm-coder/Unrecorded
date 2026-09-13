#!/usr/bin/env python3
"""Require the real public release assets, including policy content, before Play upload."""
from urllib.request import Request, urlopen


def main():
    for path, markers in {
        "/": ("Unrecorded",),
        "/privacy.html": ("Privacy Policy", "Meldlife Ltd", "privacy@unrecorded.app"),
        "/privacy": ("Privacy Policy", "Meldlife Ltd", "privacy@unrecorded.app"),
        "/app-ads.txt": ("google.com, pub-5555183606520770",),
    }.items():
        url = "https://unrecorded.app" + path
        request = Request(url, headers={"User-Agent": "Unrecorded-release-check/1.0"})
        with urlopen(request, timeout=30) as response:
            content = response.read().decode("utf-8")
            if response.status != 200 or not all(marker in content for marker in markers):
                raise RuntimeError(f"Public asset is missing or invalid: {url}")
        print(f"Public asset verified: {url}")


if __name__ == "__main__":
    main()
