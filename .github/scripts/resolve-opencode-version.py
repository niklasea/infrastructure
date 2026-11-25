#!/usr/bin/env python3

import json
import re
import sys
import urllib.parse
import urllib.request

REGISTRY = "https://ghcr.io"
REPOSITORY = "anomalyco/opencode"
TAG_PATTERN = re.compile(r"^2\.(\d+)\.(\d+)$")


def get_json(url: str, token: str) -> tuple[dict, dict]:
    request = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response), dict(response.headers)


def main() -> int:
    token_url = f"{REGISTRY}/token?scope=repository:{REPOSITORY}:pull"
    with urllib.request.urlopen(token_url, timeout=30) as response:
        token = json.load(response)["token"]

    tags: list[str] = []
    url = f"{REGISTRY}/v2/{REPOSITORY}/tags/list?n=1000"
    while url:
        data, headers = get_json(url, token)
        tags.extend(data.get("tags") or [])
        link = headers.get("Link") or headers.get("link")
        match = re.search(r"<([^>]+)>;\s*rel=\"next\"", link or "")
        url = urllib.parse.urljoin(REGISTRY, match.group(1)) if match else ""

    versions = []
    for tag in tags:
        match = TAG_PATTERN.fullmatch(tag)
        if match:
            versions.append((int(match.group(1)), int(match.group(2))))

    if not versions:
        print("no OpenCode V2 tags found", file=sys.stderr)
        return 1

    minor = max(minor for minor, _ in versions)
    patch = max(patch for candidate, patch in versions if candidate == minor)
    print(f"2.{minor}.{patch}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
