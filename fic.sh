#!/bin/bash
# Fix remaining rapsberry-* filenames inside raspberry-pi5-ssd/

set -e

cd "/Users/gabrielmay/Documents/igiteam/igi1-macbook-3d-workstation"

echo "🔍 Files still containing 'rapsberry' in name:"
find . -iname '*rapsberry*' -not -path './.git/*'

echo ""
echo "Renaming..."

# Rename each file, deepest first
find . -depth -iname '*rapsberry*' -not -path './.git/*' 2>/dev/null | while IFS= read -r p; do
    newpath="$(echo "$p" | sed -E 's/rapsberry/raspberry/gi')"
    if [ "$p" != "$newpath" ]; then
        if git mv "$p" "$newpath" 2>/dev/null; then
            echo "  ✅ $p → $newpath"
        elif mv "$p" "$newpath" 2>/dev/null; then
            echo "  ✅ (mv) $p → $newpath"
        else
            echo "  ❌ FAILED: $p"
        fi
    fi
done

echo ""
echo "🔍 Remaining 'rapsberry' files (should be empty):"
find . -iname '*rapsberry*' -not -path './.git/*' || echo "  (none)"

echo ""
echo "✅ Done. Now run:"
echo "   git status"
echo "   git add -A"
echo "   git commit -m 'Fix rapsberry → raspberry typo'"
echo "   git push"