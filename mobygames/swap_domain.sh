cat > swap_domain.sh <<'EOF' && chmod +x swap_domain.sh && ./swap_domain.sh pc_games_with_covers.json
#!/usr/bin/env bash
set -euo pipefail

OLD_DOMAIN="${OLD_DOMAIN:-meyt.netlify.app}"
NEW_DOMAIN="${NEW_DOMAIN:-meyt.macosxjs.com}"

[ $# -ge 1 ] || { echo "Usage: $0 <input.json> [output.json]" >&2; exit 1; }

IN="$1"
OUT="${2:-$1}"
[ -f "$IN" ] || { echo "error: $IN not found" >&2; exit 1; }

command -v jq >/dev/null 2>&1 && { jq empty "$IN" || { echo "error: invalid JSON" >&2; exit 1; }; }

BEFORE=$(grep -o "$OLD_DOMAIN" "$IN" | wc -l | tr -d ' ')
ESCAPED_OLD=$(printf '%s' "$OLD_DOMAIN" | sed 's/\./\\./g')

if [ "$IN" = "$OUT" ]; then
  TMP="$(mktemp)"
  sed "s/$ESCAPED_OLD/$NEW_DOMAIN/g" "$IN" > "$TMP"
  mv "$TMP" "$OUT"
else
  sed "s/$ESCAPED_OLD/$NEW_DOMAIN/g" "$IN" > "$OUT"
fi

AFTER=$(grep -o "$OLD_DOMAIN" "$OUT" | wc -l | tr -d ' ')
echo "Replaced $BEFORE occurrence(s) of '$OLD_DOMAIN' -> '$NEW_DOMAIN'"
echo "Remaining: $AFTER  |  Done -> $OUT"
EOF
