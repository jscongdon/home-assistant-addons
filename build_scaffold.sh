#!/usr/bin/env bash
set -euo pipefail

# Simple Home Assistant add-on scaffold creator.
# Usage: ./build_scaffold.sh <addon-slug>

# Updated: allow 0 or 1 args. If 1 arg provided, treat as initial slug suggestion.
if [ "${#}" -gt 1 ]; then
  cat <<EOF
Usage: ${0##*/} [addon-slug]

Examples:
  ${0##*/}                 # interactive prompts
  ${0##*/} my-addon        # use 'my-addon' as initial slug suggestion
EOF
  exit 1
fi

INITIAL_SLUG="${1:-}"

# Prompt for Add-on name (default from initial slug or current dir)
if [ -n "${INITIAL_SLUG}" ]; then
  DEFAULT_NAME="$(echo "${INITIAL_SLUG}" | sed 's/-/ /g')"
else
  DEFAULT_NAME="$(basename "$(pwd)")"
fi
read -r -p "Add-on name [${DEFAULT_NAME}]: " ADDON_NAME
ADDON_NAME="${ADDON_NAME:-$DEFAULT_NAME}"

# Suggest a slug derived from the add-on name
_suggest_slug() {
  local s="$1"
  # try transliteration if iconv exists
  if command -v iconv >/dev/null 2>&1; then
    s="$(printf '%s' "$s" | iconv -t ascii//TRANSLIT 2>/dev/null || printf '%s' "$s")"
  fi
  s="$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]')"
  s="$(printf '%s' "$s" | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-+|-+$//g')"
  printf '%s' "$s"
}

SUGGESTED_SLUG="$(_suggest_slug "$ADDON_NAME")"
DEFAULT_SLUG="${INITIAL_SLUG:-$SUGGESTED_SLUG}"

# Prompt for slug with validation loop
while :; do
  read -r -p "Add-on slug [${DEFAULT_SLUG}]: " SLUG_INPUT
  SLUG_INPUT="${SLUG_INPUT:-$DEFAULT_SLUG}"
  # validate: non-empty and only lowercase alnum, hyphen, underscore
  if [ -z "$SLUG_INPUT" ]; then
    echo "Slug cannot be empty. Please enter a slug."
    continue
  fi
  if printf '%s' "$SLUG_INPUT" | grep -Eq '^[a-z0-9]+([_-][a-z0-9]+)*$'; then
    SLUG="$SLUG_INPUT"
    break
  else
    echo "Invalid slug. Use lowercase letters, numbers, hyphens or underscores (e.g. my-addon)."
  fi
done

ROOT_DIR="$(pwd)"
ADDON_DIR="${ROOT_DIR}/${SLUG}"

if [ -e "${ADDON_DIR}" ]; then
  echo "Error: target '${ADDON_DIR}' already exists." >&2
  exit 2
fi

mkdir -p "${ADDON_DIR}"

# Create a minimal config.json with chosen name & slug
cat > "${ADDON_DIR}/config.json" <<JSON
{
  "name": "$(printf '%s' "$ADDON_NAME")",
  "version": "0.1.0",
  "slug": "$(printf '%s' "$SLUG")",
  "description": "Minimal Home Assistant add-on scaffold.",
  "arch": ["armv7", "armhf", "aarch64", "amd64", "i386"],
  "startup": "services",
  "boot": "auto",
  "options": {},
  "schema": {}
}
JSON

# Create a simple Dockerfile
cat > "${ADDON_DIR}/Dockerfile" <<'DOCKER'
ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest
FROM ${BUILD_FROM}

# Use bash as the default shell for the add-on
ENV LANG C.UTF-8

# Copy files
COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
DOCKER

# Minimal run script
cat > "${ADDON_DIR}/run.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

# Minimal run placeholder for the add-on
echo "Running add-on..."
sleep 1
# Replace with your add-on startup commands
tail -f /dev/null
SH

chmod +x "${ADDON_DIR}/run.sh"

# README
cat > "${ADDON_DIR}/README.md" <<MD
# Add-on: ${ADDON_NAME}

This is a minimal scaffold for a Home Assistant add-on.

Replace fields in config.json, implement run.sh, and adjust the Dockerfile as needed.
MD


echo "Scaffold created at: ${ADDON_DIR}"
echo "Next steps:"
echo "  - Edit ${ADDON_DIR}/config.json and ${ADDON_DIR}/run.sh"
echo "  - Build and test your add-on according to Home Assistant add-on development docs"

