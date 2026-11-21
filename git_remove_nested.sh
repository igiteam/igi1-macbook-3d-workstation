#!/bin/bash

# Remove nested Git repositories while preserving all project files.
# Keeps the main repository, .gitignore files and Git LFS files intact.
# Does NOT automatically commit or push.

set -u

echo "=== Nested Git Repository Cleanup ==="

# Find main repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: This is not inside a Git repository."
    exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT" || exit 1

echo "Main repository: $REPO_ROOT"

found_nested=0
fixed_count=0

# Find nested .git directories and .git files.
# Prune each .git entry so we never scan Git's internal data.
while IFS= read -r -d '' gitmeta; do

    # Never remove the main repository's Git metadata.
    if [ "$gitmeta" = "./.git" ]; then
        continue
    fi

    dirpath="${gitmeta%/.git}"

    found_nested=$((found_nested + 1))

    echo ""
    echo "Found nested repository: $dirpath"

    # Count existing files before cleanup.
    file_count=$(find "$dirpath" -type f ! -path "*/.git/*" | wc -l | tr -d ' ')
    echo "  Files found: $file_count"

    # Remove nested repository references from the main Git index.
    # This is particularly important for submodules (gitlinks).
    git rm --cached -r -f --ignore-unmatch -- "$dirpath" >/dev/null 2>&1 || true

    # Remove ONLY the nested Git metadata.
    rm -rf "$gitmeta"

    if [ -e "$gitmeta" ]; then
        echo "  ERROR: Could not remove $gitmeta"
        continue
    fi

    # Add the directory as ordinary project files.
    if git add -A -- "$dirpath"; then
        fixed_count=$((fixed_count + 1))
        echo "  ✓ Converted into a regular project directory."
    else
        echo "  ERROR: Could not stage $dirpath"
    fi

done < <(find . -name ".git" -prune -print0)

echo ""
echo "=== Cleanup Summary ==="
echo "Nested repositories found: $found_nested"
echo "Successfully processed: $fixed_count"

echo ""
echo "=== Remaining Git Metadata ==="
find . -name ".git" -prune -print

echo ""
echo "=== Git Status ==="
git status

echo ""
echo "=== Next Steps ==="

if [ "$found_nested" -gt 0 ]; then
    echo "Nested repository cleanup finished."
    echo ""
    echo "Review staged changes with:"
    echo "  git diff --cached --stat"
    echo "  git diff --cached"
    echo ""
    echo "When everything looks correct, commit with:"
    echo "  git commit -m \"Remove nested Git repositories\""
    echo ""
    echo "Then push with:"
    echo "  git push"
else
    echo "No nested Git repositories found."
fi

echo ""
echo "Done!"
