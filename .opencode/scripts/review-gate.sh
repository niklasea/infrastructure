#!/usr/bin/env bash
#
# Deterministic review gate. Runs available linters and validators, records
# pass/fail/skip per tool, and never applies infrastructure changes.
#
# Usage: review-gate.sh
# Env:
#   REVIEW_OUT_DIR   output directory (defaults to /tmp/opencode/review-<sha>)
#   REVIEW_GATE_FULL set to 1 to also run dotnet build/test and cargo checks

set -uo pipefail

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "not inside a git repository" >&2
  exit 2
}
cd "$repo_root"

short=$(git rev-parse --short=12 HEAD 2>/dev/null || echo "nogit")
out="${REVIEW_OUT_DIR:-/tmp/opencode/review-$short}"
mkdir -p "$out"
log="$out/gate.log"
: >"$log"

pass=0
fail=0
skip=0

record() {
  status=$1
  name=$2
  detail=$3
  printf '%-28s %-6s %s\n' "$name" "$status" "$detail" | tee -a "$log"
  case "$status" in
    pass) pass=$((pass + 1)) ;;
    fail) fail=$((fail + 1)) ;;
    skip) skip=$((skip + 1)) ;;
  esac
}

have() {
  command -v "$1" >/dev/null 2>&1
}

run_cmd() {
  if have timeout; then
    timeout 180 "$@"
  else
    "$@"
  fi
}

run() {
  name=$1
  shift
  [ $# -gt 0 ] || {
    record skip "$name" "no command"
    return
  }
  tool=$1
  if ! have "$tool"; then
    record skip "$name" "missing $tool"
    return
  fi
  if run_cmd "$@" >>"$log" 2>&1; then
    record pass "$name" "$*"
  else
    rc=$?
    record fail "$name" "exit $rc: $*"
  fi
}

record header "gate" "repository: $repo_root"
record header "gate" "output: $out"

# Whitespace and conflict markers.
if git diff --check >>"$log" 2>&1; then
  record pass "git-diff-check" "no whitespace errors"
else
  record fail "git-diff-check" "whitespace errors or conflict markers"
fi

# Terraform.
if [ -d terraform ]; then
  run terraform-fmt terraform fmt -check -recursive terraform
  if [ -d terraform/.terraform ]; then
    run terraform-validate terraform -chdir=terraform validate -no-color
  else
    record skip terraform-validate "terraform/.terraform missing; run terraform init -backend=false"
  fi
  run tflint tflint --chdir=terraform
  run checkov checkov -d terraform --compact
else
  record skip terraform "no terraform/ directory"
fi

# Ansible.
if [ -d ansible ]; then
  if [ -f .github/linters/.ansible-lint.yml ]; then
    run ansible-lint ansible-lint -c .github/linters/.ansible-lint.yml ansible
  else
    run ansible-lint ansible-lint ansible
  fi
  if [ -f ansible/yamllint.conf ]; then
    run yamllint yamllint -c ansible/yamllint.conf ansible
  else
    run yamllint yamllint ansible
  fi
  if [ -f ansible/main.yml ]; then
    run ansible-syntax ansible-playbook --syntax-check ansible/main.yml
  fi
else
  record skip ansible "no ansible/ directory"
fi

# GitHub Actions.
if [ -d .github/workflows ]; then
  run zizmor zizmor .github/workflows
  run actionlint actionlint
else
  record skip actions "no .github/workflows directory"
fi

# Dockerfiles.
dockerfiles=()
while IFS= read -r dockerfile; do
  dockerfiles+=("$dockerfile")
done < <(
  find . -type f \( -iname 'dockerfile' -o -iname 'dockerfile.*' \) \
    -not -path './.git/*' -print 2>/dev/null
)
if [ "${#dockerfiles[@]}" -gt 0 ]; then
  if have hadolint; then
    if run_cmd hadolint "${dockerfiles[@]}" >>"$log" 2>&1; then
      record pass hadolint "${#dockerfiles[@]} Dockerfile(s)"
    else
      rc=$?
      record fail hadolint "exit $rc: ${#dockerfiles[@]} Dockerfile(s)"
    fi
  else
    record skip hadolint "missing hadolint"
  fi
else
  record skip hadolint "no Dockerfiles"
fi

# Secret scanning is optional.
if have gitleaks; then
  run gitleaks gitleaks detect --no-git --source . --redact
else
  record skip gitleaks "missing gitleaks"
fi

# Language build/test checks are opt-in because they can be slow.
if [ "${REVIEW_GATE_FULL:-0}" = "1" ]; then
  if find . -type f \( -name '*.sln' -o -name '*.csproj' \) \
    -not -path './.git/*' -print -quit 2>/dev/null | grep -q .; then
    run dotnet-build dotnet build --nologo
    run dotnet-test dotnet test --nologo
  else
    record skip dotnet "no .sln or .csproj"
  fi

  if [ -f Cargo.toml ]; then
    run cargo-fmt cargo fmt --check
    run cargo-clippy cargo clippy --all-targets -- -D warnings
    run cargo-test cargo test
  else
    record skip rust "no Cargo.toml"
  fi
else
  record skip dotnet "REVIEW_GATE_FULL not set"
  record skip rust "REVIEW_GATE_FULL not set"
fi

printf '\nSummary: %d pass, %d fail, %d skip\n' "$pass" "$fail" "$skip" | tee -a "$log"
printf 'Log: %s\n' "$log"

if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
