#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ -f "${PROJECT_DIR}/.env" ]; then
  # shellcheck disable=SC1091
  source "${PROJECT_DIR}/.env"
fi

HOST="${1:-${HOST:-}}"
PUBLIC_HOST="${PUBLIC_HOST:?PUBLIC_HOST is required}"
PUBLIC_PORT="${PUBLIC_PORT:-2053}"
SING_BOX_VERSION="${SING_BOX_VERSION:-1.12.20}"
REALITY_SERVER_NAME="${REALITY_SERVER_NAME:-www.cloudflare.com}"
REALITY_HANDSHAKE_SERVER="${REALITY_HANDSHAKE_SERVER:-$REALITY_SERVER_NAME}"
REALITY_HANDSHAKE_PORT="${REALITY_HANDSHAKE_PORT:-443}"
REALITY_SHORT_ID="${REALITY_SHORT_ID:-e5671ea03f2eccca}"
VLESS_UUIDS="${VLESS_UUIDS:?VLESS_UUIDS is required}"
REALITY_PRIVATE_KEY="${REALITY_PRIVATE_KEY:-}"
REALITY_PUBLIC_KEY="${REALITY_PUBLIC_KEY:-}"

if [ -z "$HOST" ]; then
  echo "HOST is required" >&2
  exit 1
fi

REMOTE_INSTALL="/tmp/install-singbox-reality-remote.sh"
SSH_OPTS=(
  -o BatchMode=yes
  -o ConnectTimeout=8
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/Users/alfa/.ssh/known_hosts_mtproxy
)

scp "${SSH_OPTS[@]}" "${SCRIPT_DIR}/install-singbox-reality-remote.sh" "${HOST}:${REMOTE_INSTALL}"

ssh "${SSH_OPTS[@]}" "$HOST" \
  "chmod 755 ${REMOTE_INSTALL} && \
   PUBLIC_PORT='${PUBLIC_PORT}' \
   SING_BOX_VERSION='${SING_BOX_VERSION}' \
   REALITY_SERVER_NAME='${REALITY_SERVER_NAME}' \
   REALITY_HANDSHAKE_SERVER='${REALITY_HANDSHAKE_SERVER}' \
   REALITY_HANDSHAKE_PORT='${REALITY_HANDSHAKE_PORT}' \
   REALITY_SHORT_ID='${REALITY_SHORT_ID}' \
   VLESS_UUIDS='${VLESS_UUIDS}' \
   REALITY_PRIVATE_KEY='${REALITY_PRIVATE_KEY}' \
   REALITY_PUBLIC_KEY='${REALITY_PUBLIC_KEY}' \
   bash ${REMOTE_INSTALL}"

REALITY_PUBLIC_KEY_REMOTE="$(ssh "${SSH_OPTS[@]}" "$HOST" "cat /etc/sing-box/reality-public.key")"

echo
echo "Client URIs:"
PUBLIC_HOST="$PUBLIC_HOST" \
PUBLIC_PORT="$PUBLIC_PORT" \
REALITY_PUBLIC_KEY="$REALITY_PUBLIC_KEY_REMOTE" \
REALITY_SHORT_ID="$REALITY_SHORT_ID" \
REALITY_SERVER_NAME="$REALITY_SERVER_NAME" \
VLESS_UUIDS="$VLESS_UUIDS" \
LABEL_PREFIX="vless-$(printf '%s' "$PUBLIC_HOST" | tr '.' '-')" \
  "${SCRIPT_DIR}/render-vless-uri.sh"
