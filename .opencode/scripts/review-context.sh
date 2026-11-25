#!/usr/bin/env bash
#
# Collect review context for the code-review skill.
# Usage: review-context.sh [git-diff-range]
#
# Writes to /tmp/opencode/review-<sha>/ by default. Override with REVIEW_OUT_DIR.

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "not inside a git repository" >&2
  exit 1
}
cd "$repo_root"

range="${1:-}"
if [ -z "$range" ]; then
  if git rev-parse --verify -q origin/main >/dev/null 2>&1; then
    # Diff from the merge base to the working tree, so branch commits,
    # staged changes, and unstaged changes are all included.
    range="$(git merge-base origin/main HEAD)"
  else
    range="HEAD"
  fi
fi

short=$(git rev-parse --short=12 HEAD 2>/dev/null || echo "nogit")
out="${REVIEW_OUT_DIR:-/tmp/opencode/review-$short}"
mkdir -p "$out"

git diff --no-ext-diff --unified=80 "$range" >"$out/diff.patch" 2>"$out/diff.err" || true
git diff --name-status "$range" >"$out/changed-files.txt" 2>/dev/null || true
git diff --stat "$range" >"$out/diff.stat" 2>/dev/null || true
git status --porcelain=v1 >"$out/status.txt" 2>/dev/null || true
if [ "${REVIEW_INCLUDE_PACK:-0}" = "1" ]; then
  git ls-files --others --exclude-standard >"$out/untracked.txt" 2>/dev/null || true
else
  git ls-files --others --exclude-standard 2>/dev/null \
    | grep -v -E '^(\.opencode/|REVIEW\.md$|node_modules/|target/|bin/|obj/|\.terraform/|__pycache__/)' \
    >"$out/untracked.txt" || true
fi
git log --oneline -20 >"$out/recent-commits.txt" 2>/dev/null || true

: >"$out/untracked.patch"
if [ -s "$out/untracked.txt" ]; then
  while IFS= read -r file; do
    [ -f "$file" ] || continue
    git diff --no-index --unified=40 -- /dev/null "$file" >>"$out/untracked.patch" 2>/dev/null || true
  done <"$out/untracked.txt"
fi

python3 - "$repo_root" "$range" "$out" <<'PY'
import datetime
import json
import os
import subprocess
import sys

repo_root, range_arg, out = sys.argv[1:4]


def lines(name):
    path = os.path.join(out, name)
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            return [line.rstrip("\n") for line in handle if line.strip()]
    except FileNotFoundError:
        return []


def git(*args):
    try:
        return subprocess.check_output(
            ["git", *args], cwd=repo_root, text=True, stderr=subprocess.DEVNULL
        ).strip()
    except Exception:
        return None


changed = lines("changed-files.txt")
changed_paths = []
for entry in changed:
    parts = entry.split("\t")
    if len(parts) >= 2:
        changed_paths.append(parts[-1])

meta = {
    "repo_root": repo_root,
    "range": range_arg,
    "head": git("rev-parse", "HEAD"),
    "base": git("merge-base", "origin/main", "HEAD"),
    "created_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "out_dir": out,
    "diff": os.path.join(out, "diff.patch"),
    "untracked_patch": os.path.join(out, "untracked.patch"),
    "changed_files": changed,
    "changed_paths": changed_paths,
    "untracked_files": lines("untracked.txt"),
    "status": lines("status.txt"),
    "recent_commits": lines("recent-commits.txt"),
}

with open(os.path.join(out, "context.json"), "w", encoding="utf-8") as handle:
    json.dump(meta, handle, indent=2)
    handle.write("\n")

print(json.dumps(meta, indent=2))
PY
