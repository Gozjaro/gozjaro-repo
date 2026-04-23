#!/bin/sh
# Upload a built gozpak repository to GitHub Releases.
# Usage: ./scripts/repo-upload.sh [repo-dir] [tag]
#
# Requires: gh (GitHub CLI), authenticated
#
# The release URL becomes the GOZPAK_REPOS endpoint:
#   https://github.com/Gozjaro/gozjaro-repo/releases/download/<tag>/
set -e

REPO_DIR="${1:-./repo}"
TAG="${2:-stable}"
GH_REPO="Gozjaro/gozjaro-repo"

if ! command -v gh >/dev/null 2>&1; then
    echo "error: 'gh' (GitHub CLI) is required" >&2
    echo "  install: https://cli.github.com" >&2
    exit 1
fi

if [ ! -f "$REPO_DIR/repo.index" ]; then
    echo "error: $REPO_DIR/repo.index not found" >&2
    echo "  run 'gozpak repo-index $REPO_DIR' first" >&2
    exit 1
fi

echo "=> Uploading repo from $REPO_DIR to $GH_REPO release '$TAG'"

# Count files
n_files=$(find "$REPO_DIR" -maxdepth 1 -name '*.tar.*' | wc -l | tr -d ' ')
echo "   $n_files package tarballs + repo.index"

# Delete existing release if it exists (to replace assets)
if gh release view "$TAG" --repo "$GH_REPO" >/dev/null 2>&1; then
    echo "=> Deleting existing release '$TAG'..."
    gh release delete "$TAG" --repo "$GH_REPO" --yes
    # Also delete the git tag so we can recreate it at HEAD
    gh api "repos/$GH_REPO/git/refs/tags/$TAG" -X DELETE 2>/dev/null || true
fi

# Create the release
echo "=> Creating release '$TAG'..."
gh release create "$TAG" \
    --repo "$GH_REPO" \
    --title "Gozjaro Package Repository ($TAG)" \
    --notes "Binary package repository for Gozjaro Linux.

## Usage

\`\`\`sh
echo 'https://github.com/Gozjaro/gozjaro-repo/releases/download/$TAG' > /etc/gozpak/repos.conf
gozpak sync
gozpak get curl
\`\`\`

**Packages:** $n_files
**Updated:** $(date -u +%Y-%m-%d)" \
    --latest

# Upload repo.index first
echo "=> Uploading repo.index..."
gh release upload "$TAG" "$REPO_DIR/repo.index" \
    --repo "$GH_REPO" --clobber

# Upload all tarballs
uploaded=0
for tarball in "$REPO_DIR"/*.tar.*; do
    [ -f "$tarball" ] || continue
    name=$(basename "$tarball")
    uploaded=$((uploaded + 1))
    printf "   [%d/%d] %s\n" "$uploaded" "$n_files" "$name"
    gh release upload "$TAG" "$tarball" \
        --repo "$GH_REPO" --clobber
done

echo ""
echo "=> Done! $uploaded packages uploaded."
echo ""
echo "Repository URL:"
echo "  https://github.com/Gozjaro/gozjaro-repo/releases/download/$TAG"
echo ""
echo "Client config:"
echo "  echo 'https://github.com/Gozjaro/gozjaro-repo/releases/download/$TAG' > /etc/gozpak/repos.conf"
echo "  gozpak sync && gozpak get <package>"
