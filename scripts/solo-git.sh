#!/usr/bin/env bash
set -euo pipefail

BRANCH_PREFIX="${BRANCH_PREFIX:-codex}"
IOS_INFO_PLIST="apps/ios/HealthPassport/Config/Info.plist"
IOS_PROJECT_FILE="apps/ios/HealthPassport/HealthPassport.xcodeproj/project.pbxproj"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/solo-git.sh status
  ./scripts/solo-git.sh start <task-name>
  ./scripts/solo-git.sh verify
  ./scripts/solo-git.sh finish
  ./scripts/solo-git.sh protect-local-xcode
  ./scripts/solo-git.sh unprotect-local-xcode

Environment:
  BRANCH_PREFIX=codex  Override the feature branch prefix.
USAGE
}

current_branch() {
  git branch --show-current
}

remote_exists() {
  git remote get-url origin >/dev/null 2>&1
}

require_clean_tree() {
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Working tree has uncommitted changes. Commit, stash, or intentionally protect local-only files first." >&2
    git status --short
    exit 1
  fi
}

normalize_task_name() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//'
}

pull_main_if_remote_exists() {
  if remote_exists; then
    git pull --ff-only origin main
  else
    echo "No origin remote configured; skipping pull."
  fi
}

push_main_if_remote_exists() {
  if remote_exists; then
    git push origin main
  else
    echo "No origin remote configured; skipping push."
  fi
}

verify() {
  local node_bin
  node_bin="$(resolve_node_bin)"
  "$node_bin" --test --experimental-transform-types packages/core/test/*.test.ts services/api/test/*.test.ts
  swift run --package-path apps/ios/HealthPassport HealthPassportKitSmokeTests
  swift build --package-path apps/ios/HealthPassport
}

resolve_node_bin() {
  local bundled_node="$HOME/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node"

  if [[ -n "${NODE_BIN:-}" ]]; then
    echo "$NODE_BIN"
  elif command -v node >/dev/null 2>&1; then
    command -v node
  elif [[ -x "$bundled_node" ]]; then
    echo "$bundled_node"
  else
    echo "Node.js was not found. Set NODE_BIN=/path/to/node and rerun verify." >&2
    exit 1
  fi
}

case "${1:-}" in
  status)
    echo "Branch: $(current_branch)"
    git status --short --branch
    if remote_exists; then
      echo "Origin: $(git remote get-url origin)"
    else
      echo "Origin: not configured"
    fi
    ;;
  start)
    task_name="${2:-}"
    if [[ -z "$task_name" ]]; then
      usage
      exit 1
    fi
    if [[ "$(current_branch)" != "main" ]]; then
      echo "Start new feature branches from main." >&2
      exit 1
    fi
    branch_name="$BRANCH_PREFIX/$(normalize_task_name "$task_name")"
    require_clean_tree
    pull_main_if_remote_exists
    git switch -c "$branch_name"
    ;;
  verify)
    verify
    ;;
  finish)
    branch="$(current_branch)"
    if [[ -z "$branch" || "$branch" == "main" ]]; then
      echo "Run finish from a feature branch, not main." >&2
      exit 1
    fi
    require_clean_tree
    verify
    git switch main
    pull_main_if_remote_exists
    git merge --ff-only "$branch"
    push_main_if_remote_exists
    ;;
  protect-local-xcode)
    git update-index --skip-worktree "$IOS_INFO_PLIST" "$IOS_PROJECT_FILE"
    echo "Protected local Xcode files from normal status."
    ;;
  unprotect-local-xcode)
    git update-index --no-skip-worktree "$IOS_INFO_PLIST" "$IOS_PROJECT_FILE"
    echo "Unprotected local Xcode files; inspect diffs before staging."
    ;;
  ""|-h|--help|help)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
