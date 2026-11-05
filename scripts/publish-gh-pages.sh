#!/usr/bin/env bash
# Publish the profile site to GitHub Pages from the operator's machine.
# Replaces .github/workflows/deploy-pages.yml (owner decision 2026-11-05: no
# GitHub Actions and no runners). Same build as the workflow:
# scripts/build-site.sh _site with pandoc (the workflow used Ubuntu's apt
# pandoc, 3.1.3 on ubuntu-24.04; it was not pinned), and only the pushed main
# is published.
#
# The built _site (with .nojekyll; no custom domain, so no CNAME) is committed
# on top of the existing gh-pages branch (or as an orphan branch the first
# time) and pushed without force, with the operator's own git credentials.
#
# One-time owner step: GitHub > Settings > Pages > Build and deployment >
# Source "Deploy from a branch", branch gh-pages, folder / (root).
#
# Usage: scripts/publish-gh-pages.sh [--no-push]
#   --no-push  build and create the gh-pages commit locally, but do not push.
set -euo pipefail

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '==> %s\n' "$*"; }

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
push=1
while [[ $# -gt 0 ]]; do
  case $1 in
    --no-push) push=0; shift ;;
    -h|--help) sed -n '2,17p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

# Guard: the workflow deployed only a push to main, from a fresh checkout.
git -C "$REPO" fetch --quiet origin main || die "git fetch origin main failed"
dirty=$(git -C "$REPO" status --porcelain --untracked-files=normal)
if [[ -n $dirty ]]; then
  printf '%s\n' "$dirty" >&2
  die "working tree is not clean; commit, stash or remove the files above first"
fi
sha=$(git -C "$REPO" rev-parse HEAD)
[[ $sha == "$(git -C "$REPO" rev-parse refs/remotes/origin/main)" ]] || die "HEAD $sha is not origin/main; publish only the pushed main"
command -v pandoc >/dev/null 2>&1 || die "pandoc not found (apt-get install pandoc / brew install pandoc)"

# Build in a clean detached worktree, like actions/checkout.
tmp=$(mktemp -d "${TMPDIR:-/tmp}/ksamintpro-pages.XXXXXX")
src=$tmp/src
cleanup() {
  git -C "$REPO" worktree remove --force "$src" 2>/dev/null || true
  rm -rf "$tmp"
  git -C "$REPO" worktree prune 2>/dev/null || true
}
trap cleanup EXIT
git -C "$REPO" worktree add --quiet --detach "$src" "$sha"
log "building $sha with $(pandoc --version | head -1)"
out=$tmp/_site
bash "$src/scripts/build-site.sh" "$out"
[[ -f $out/.nojekyll ]] || die "_site is missing .nojekyll"

# Commit _site on top of origin/gh-pages (or as an orphan) and push without force.
gitdir=$(git -C "$REPO" rev-parse --absolute-git-dir)
parent=""
status=0
git -C "$REPO" ls-remote --exit-code --heads origin gh-pages >/dev/null || status=$?
if [[ $status -eq 0 ]]; then
  git -C "$REPO" fetch --quiet origin "+refs/heads/gh-pages:refs/remotes/origin/gh-pages"
  parent=$(git -C "$REPO" rev-parse refs/remotes/origin/gh-pages)
  log "gh-pages exists at $parent; committing on top of it"
elif [[ $status -eq 2 ]]; then
  log "gh-pages does not exist yet; creating it as an orphan branch"
else
  die "could not list origin/gh-pages (git ls-remote exit $status)"
fi
index=$tmp/gh-pages.index
GIT_DIR=$gitdir GIT_WORK_TREE=$out GIT_INDEX_FILE=$index git -C "$out" add --all --force -- .
tree=$(GIT_DIR=$gitdir GIT_INDEX_FILE=$index git write-tree)
if [[ -n $parent && $tree == "$(git -C "$REPO" rev-parse "$parent^{tree}")" ]]; then
  log "gh-pages already has this exact tree; nothing to publish"
  exit 0
fi
if [[ -n $parent ]]; then
  commit=$(git -C "$REPO" commit-tree "$tree" -p "$parent" -m "Publish $sha from main")
else
  commit=$(git -C "$REPO" commit-tree "$tree" -m "Publish $sha from main")
fi
if [[ $push == 1 ]]; then
  git -C "$REPO" push origin "$commit:refs/heads/gh-pages"
  log "pushed $commit to origin/gh-pages"
else
  log "dry run: built gh-pages commit $commit (tree $tree, $(git -C "$REPO" ls-tree -r "$tree" | wc -l | tr -d ' ') files); not pushed"
fi
