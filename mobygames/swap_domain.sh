#!/usr/bin/env bash
# swap_domain.sh
#
# Usage:
#   ./swap_domain.sh input.json              # rewrite in place
#   ./swap_domain.sh input.json output.json  # write to a new file
#
# Replaces every occurrence of meyt.netlify.app with macosxjs.com.
# Override via env vars: OLD_DOMAIN=... NEW_DOMAIN=... ./swap_domain.sh ...

set -euo pipefail

OLD_DOMAIN="${OLD_DOMAIN:-meyt.netlify.app}"
NEW_DOMAIN="${NEW_DOMAIN:-macosxjs.com}"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <input.json> [output.json]" >&2
  exit 1
fi

IN="$1"
OUT="${2:-$1}"

if [ ! -f "$IN" ]; then
  echo "error: $IN not found" >&2
  exit 1
fi

# Sanity check: valid JSON?
if command -v jq >/dev/null 2>&1; then
  jq empty "$IN" || { echo "error: $IN is not valid JSON" >&2; exit 1; }
fi

# Count occurrences before/after for a summary.
BEFORE=$(grep -o "$OLD_DOMAIN" "$IN" | wc -l | tr -d ' ')

# Escape dots for sed regex.
ESCAPED_OLD=$(printf '%s' "$OLD_DOMAIN" | sed 's/\./\\./g')

if [ "$IN" = "$OUT" ]; then
  # In-place: write to a temp file first so we don't truncate on error.
  TMP="$(mktemp)"
  sed "s/$ESCAPED_OLD/$NEW_DOMAIN/g" "$IN" > "$TMP"
  mv "$TMP" "$OUT"
else
  sed "s/$ESCAPED_OLD/$NEW_DOMAIN/g" "$IN" > "$OUT"
fi

AFTER=$(grep -o "$OLD_DOMAIN" "$OUT" | wc -l | tr -d ' ')

echo "Replaced $BEFORE occurrence(s) of '$OLD_DOMAIN' with '$NEW_DOMAIN'"
echo "Remaining '$OLD_DOMAIN' in $OUT: $AFTER"
echo "Done -> $OUT"
