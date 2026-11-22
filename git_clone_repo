cat > ~/Downloads/git_clone_repo.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# ABOUT THE TOKEN
# ----------------------------------------------------------------------------
# The 401 Bad credentials error also means the token you pasted either was
# empty (because of the paste-in-shell issue) or is invalid/expired. If it
# still fails after running as a script, generate a fresh token:
#
#   1. Go to https://github.com/settings/tokens
#   2. Generate new token (classic) -> check the "repo" scope -> generate -> copy it.
#   3. Paste it into the script prompt.
#
# That token needs access to BOTH igiteam/openofpcwc-projectigi (read) and the
# ability to create repos under igiteam. If igiteam is an ORGANIZATION (not
# your personal account), the POST /user/repos call will NOT work -- you would
# need to create the repo manually in the org, or switch the endpoint to
# /orgs/igiteam/repos and ensure your token has org repo-creation rights.
# ============================================================================

# ====== CONFIG ======
OLD_OWNER="igiteam"
OLD_REPO="openofpcwc-projectigi"
NEW_OWNER="igiteam"
NEW_REPO="openofpcwc-hidden-and-dangerous"
# ====================

# Prompt for visibility (public is default -- just press Enter)
printf "Repo visibility? [public/private] (default: public): "
read -r VISIBILITY
VISIBILITY="${VISIBILITY:-public}"

case "${VISIBILITY}" in
  public)  PRIVATE_FLAG="false" ;;
  private) PRIVATE_FLAG="true"  ;;
  *)
    echo "Invalid choice '${VISIBILITY}'. Use 'public' or 'private'." >&2
    exit 1
    ;;
esac
echo "    -> ${VISIBILITY}"

# Prompt for token (hidden input)
printf "Paste your GitHub Personal Access Token (repo scope): "
read -r -s GH_TOKEN
echo

if [[ -z "${GH_TOKEN}" ]]; then
  echo "No token provided. Aborting." >&2
  exit 1
fi

AUTH_OLD="https://x-access-token:${GH_TOKEN}@github.com/${OLD_OWNER}/${OLD_REPO}.git"
AUTH_NEW="https://x-access-token:${GH_TOKEN}@github.com/${NEW_OWNER}/${NEW_REPO}.git"

WORKDIR="$(mktemp -d)"
BARE_DIR="${WORKDIR}/${OLD_REPO}.git"

cleanup() {
  if [[ -d "${BARE_DIR}" ]]; then
    git -C "${BARE_DIR}" remote set-url --push origin "https://github.com/${NEW_OWNER}/${NEW_REPO}.git" >/dev/null 2>&1 || true
  fi
  rm -rf "${WORKDIR}"
}
trap cleanup EXIT

echo "==> Verifying token..."
HTTP_CODE=$(curl -s -o /tmp/gh_whoami.json -w "%{http_code}" \
  -H "Authorization: Bearer ${GH_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/user)

if [[ "${HTTP_CODE}" != "200" ]]; then
  echo "Token check failed (HTTP ${HTTP_CODE}):" >&2
  cat /tmp/gh_whoami.json >&2
  echo >&2
  exit 1
fi
echo "    Token OK (user: $(grep -o '"login": *"[^"]*"' /tmp/gh_whoami.json | head -1 | cut -d'"' -f4))"
rm -f /tmp/gh_whoami.json

echo "==> Creating new ${VISIBILITY} repo ${NEW_OWNER}/${NEW_REPO} on GitHub..."
HTTP_CODE=$(curl -s -o /tmp/gh_create_resp.json -w "%{http_code}" \
  -X POST \
  -H "Authorization: Bearer ${GH_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/user/repos \
  -d "{\"name\":\"${NEW_REPO}\",\"private\":${PRIVATE_FLAG}}")

if [[ "${HTTP_CODE}" == "201" ]]; then
  echo "    Created."
elif [[ "${HTTP_CODE}" == "422" ]]; then
  echo "    Repo already exists (or name conflict). Continuing with mirror push."
  echo "    NOTE: visibility will NOT be changed on an existing repo."
else
  echo "    Unexpected API response (HTTP ${HTTP_CODE}):" >&2
  cat /tmp/gh_create_resp.json >&2
  echo >&2
  exit 1
fi
rm -f /tmp/gh_create_resp.json

echo "==> Bare-cloning source repo..."
git clone --bare "${AUTH_OLD}" "${BARE_DIR}"

echo "==> Mirror-pushing to ${NEW_OWNER}/${NEW_REPO}..."
git -C "${BARE_DIR}" push --mirror "${AUTH_NEW}"

echo
echo "Done. New repo: https://github.com/${NEW_OWNER}/${NEW_REPO}"
EOF
chmod +x ~/Downloads/git_clone_repo.sh && ~/Downloads/git_clone_repo.sh
