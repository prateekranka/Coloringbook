#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="${WORKFLOW:-testflight.yml}"
BRANCH="$(git -C "${ROOT_DIR}" branch --show-current)"
VARIANT_NAME="${VARIANT_NAME:-Gouache TestFlight build}"
RELEASE_NOTES="${RELEASE_NOTES:-}"
WATCH="${WATCH:-1}"
PUSH="${PUSH:-1}"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--no-push] [--no-watch] [--variant-name NAME] [--release-notes TEXT]

Triggers the TestFlight GitHub Actions workflow for the current branch.

Environment overrides:
  VARIANT_NAME      Human-readable build name. Default: ${VARIANT_NAME}
  RELEASE_NOTES    TestFlight release notes. Required unless passed as an arg.
  PUSH             Set to 0 to skip git push.
  WATCH            Set to 0 to skip gh run watch.
  WORKFLOW         Workflow file. Default: ${WORKFLOW}
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-push)
      PUSH=0
      shift
      ;;
    --no-watch)
      WATCH=0
      shift
      ;;
    --variant-name)
      VARIANT_NAME="${2:?Missing value for --variant-name}"
      shift 2
      ;;
    --release-notes)
      RELEASE_NOTES="${2:?Missing value for --release-notes}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "${BRANCH}" ]]; then
  echo "No current git branch found." >&2
  exit 1
fi

if [[ -z "${RELEASE_NOTES}" ]]; then
  RELEASE_NOTES="$(git -C "${ROOT_DIR}" log -1 --pretty=%B)"
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "GitHub CLI is not authenticated. Run: gh auth login -h github.com" >&2
  exit 1
fi

if (( PUSH )); then
  git -C "${ROOT_DIR}" push origin "${BRANCH}"
fi

gh workflow run "${WORKFLOW}" \
  --ref "${BRANCH}" \
  -f "variant_name=${VARIANT_NAME}" \
  -f "release_notes=${RELEASE_NOTES}"

echo "Triggered ${WORKFLOW} on ${BRANCH}."

if (( WATCH )); then
  sleep 5
  gh run watch --workflow "${WORKFLOW}" --exit-status
fi
