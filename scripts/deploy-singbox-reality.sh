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
REALITY_443_ENABLED="${REALITY_443_ENABLED:-0}"
REALITY_443_BIND="${REALITY_443_BIND:-127.0.0.1}"
REALITY_443_PORT="${REALITY_443_PORT:-12053}"
REALITY_443_SERVER_NAME="${REALITY_443_SERVER_NAME:-www.mozilla.org}"
REALITY_443_HANDSHAKE_SERVER="${REALITY_443_HANDSHAKE_SERVER:-$REALITY_443_SERVER_NAME}"
REALITY_443_HANDSHAKE_PORT="${REALITY_443_HANDSHAKE_PORT:-443}"
REALITY_443_PUBLIC_PORT="${REALITY_443_PUBLIC_PORT:-443}"
REALITY_443_COMPAT_ENABLED="${REALITY_443_COMPAT_ENABLED:-0}"
REALITY_443_COMPAT_BIND="${REALITY_443_COMPAT_BIND:-127.0.0.1}"
REALITY_443_COMPAT_PORT="${REALITY_443_COMPAT_PORT:-12054}"
REALITY_443_COMPAT_SERVER_NAME="${REALITY_443_COMPAT_SERVER_NAME:-www.cloudflare.com}"
REALITY_443_COMPAT_HANDSHAKE_SERVER="${REALITY_443_COMPAT_HANDSHAKE_SERVER:-$REALITY_443_COMPAT_SERVER_NAME}"
REALITY_443_COMPAT_HANDSHAKE_PORT="${REALITY_443_COMPAT_HANDSHAKE_PORT:-443}"
REALITY_GRPC_ENABLED="${REALITY_GRPC_ENABLED:-0}"
REALITY_GRPC_BIND="${REALITY_GRPC_BIND:-::}"
REALITY_GRPC_PORT="${REALITY_GRPC_PORT:-22053}"
REALITY_GRPC_PUBLIC_PORT="${REALITY_GRPC_PUBLIC_PORT:-$REALITY_GRPC_PORT}"
REALITY_GRPC_SERVER_NAME="${REALITY_GRPC_SERVER_NAME:-httpredir.debian.org}"
REALITY_GRPC_HANDSHAKE_SERVER="${REALITY_GRPC_HANDSHAKE_SERVER:-$REALITY_GRPC_SERVER_NAME}"
REALITY_GRPC_HANDSHAKE_PORT="${REALITY_GRPC_HANDSHAKE_PORT:-443}"
REALITY_GRPC_SHORT_ID="${REALITY_GRPC_SHORT_ID-}"
REALITY_GRPC_SERVICE_NAME="${REALITY_GRPC_SERVICE_NAME:-ftp.debian.org}"
REALITY_GRPC_MODE="${REALITY_GRPC_MODE:-gun}"
REALITY_GRPC_UUIDS="${REALITY_GRPC_UUIDS:-}"
VLESS_UUIDS="${VLESS_UUIDS:?VLESS_UUIDS is required}"
VLESS_COMPAT_UUIDS="${VLESS_COMPAT_UUIDS:-}"
VLESS_FLOW="${VLESS_FLOW-xtls-rprx-vision}"
REALITY_PRIVATE_KEY="${REALITY_PRIVATE_KEY:-}"
REALITY_PUBLIC_KEY="${REALITY_PUBLIC_KEY:-}"

if [ -z "$HOST" ]; then
  echo "HOST is required" >&2
  exit 1
fi

REMOTE_INSTALL="/tmp/install-singbox-reality-remote.sh"
REMOTE_ENV="/tmp/singbox-reality.env"
REMOTE_LOG="/tmp/install-singbox-reality.log"
LOCAL_ENV_FILE="$(mktemp)"
SSH_OPTS=(
  -o BatchMode=yes
  -o ConnectTimeout=8
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/Users/alfa/.ssh/known_hosts_mtproxy
)

cleanup() {
  rm -f "$LOCAL_ENV_FILE"
}
trap cleanup EXIT

shell_quote() {
  printf '%q' "$1"
}

write_local_env_file() {
  {
    printf 'PUBLIC_PORT=%q\n' "$PUBLIC_PORT"
    printf 'SING_BOX_VERSION=%q\n' "$SING_BOX_VERSION"
    printf 'REALITY_SERVER_NAME=%q\n' "$REALITY_SERVER_NAME"
    printf 'REALITY_HANDSHAKE_SERVER=%q\n' "$REALITY_HANDSHAKE_SERVER"
    printf 'REALITY_HANDSHAKE_PORT=%q\n' "$REALITY_HANDSHAKE_PORT"
    printf 'REALITY_SHORT_ID=%q\n' "$REALITY_SHORT_ID"
    printf 'REALITY_443_ENABLED=%q\n' "$REALITY_443_ENABLED"
    printf 'REALITY_443_BIND=%q\n' "$REALITY_443_BIND"
    printf 'REALITY_443_PORT=%q\n' "$REALITY_443_PORT"
    printf 'REALITY_443_SERVER_NAME=%q\n' "$REALITY_443_SERVER_NAME"
    printf 'REALITY_443_HANDSHAKE_SERVER=%q\n' "$REALITY_443_HANDSHAKE_SERVER"
    printf 'REALITY_443_HANDSHAKE_PORT=%q\n' "$REALITY_443_HANDSHAKE_PORT"
    printf 'REALITY_443_COMPAT_ENABLED=%q\n' "$REALITY_443_COMPAT_ENABLED"
    printf 'REALITY_443_COMPAT_BIND=%q\n' "$REALITY_443_COMPAT_BIND"
    printf 'REALITY_443_COMPAT_PORT=%q\n' "$REALITY_443_COMPAT_PORT"
    printf 'REALITY_443_COMPAT_SERVER_NAME=%q\n' "$REALITY_443_COMPAT_SERVER_NAME"
    printf 'REALITY_443_COMPAT_HANDSHAKE_SERVER=%q\n' "$REALITY_443_COMPAT_HANDSHAKE_SERVER"
    printf 'REALITY_443_COMPAT_HANDSHAKE_PORT=%q\n' "$REALITY_443_COMPAT_HANDSHAKE_PORT"
    printf 'REALITY_GRPC_ENABLED=%q\n' "$REALITY_GRPC_ENABLED"
    printf 'REALITY_GRPC_BIND=%q\n' "$REALITY_GRPC_BIND"
    printf 'REALITY_GRPC_PORT=%q\n' "$REALITY_GRPC_PORT"
    printf 'REALITY_GRPC_SERVER_NAME=%q\n' "$REALITY_GRPC_SERVER_NAME"
    printf 'REALITY_GRPC_HANDSHAKE_SERVER=%q\n' "$REALITY_GRPC_HANDSHAKE_SERVER"
    printf 'REALITY_GRPC_HANDSHAKE_PORT=%q\n' "$REALITY_GRPC_HANDSHAKE_PORT"
    printf 'REALITY_GRPC_SHORT_ID=%q\n' "$REALITY_GRPC_SHORT_ID"
    printf 'REALITY_GRPC_SERVICE_NAME=%q\n' "$REALITY_GRPC_SERVICE_NAME"
    printf 'REALITY_GRPC_UUIDS=%q\n' "$REALITY_GRPC_UUIDS"
    printf 'VLESS_UUIDS=%q\n' "$VLESS_UUIDS"
    printf 'VLESS_COMPAT_UUIDS=%q\n' "$VLESS_COMPAT_UUIDS"
    printf 'VLESS_FLOW=%q\n' "$VLESS_FLOW"
    printf 'REALITY_PRIVATE_KEY=%q\n' "$REALITY_PRIVATE_KEY"
    printf 'REALITY_PUBLIC_KEY=%q\n' "$REALITY_PUBLIC_KEY"
  } > "$LOCAL_ENV_FILE"
}

start_remote_install() {
  local remote_install_q remote_env_q remote_log_q remote_wrapper

  remote_install_q="$(shell_quote "$REMOTE_INSTALL")"
  remote_env_q="$(shell_quote "$REMOTE_ENV")"
  remote_log_q="$(shell_quote "$REMOTE_LOG")"
  remote_wrapper="set -a; . ${REMOTE_ENV}; set +a; bash ${REMOTE_INSTALL}; rc=\$?; echo __EXIT__:\$rc; exit \$rc"

  write_local_env_file
  scp "${SSH_OPTS[@]}" "${SCRIPT_DIR}/install-singbox-reality-remote.sh" "${HOST}:${REMOTE_INSTALL}"
  scp "${SSH_OPTS[@]}" "$LOCAL_ENV_FILE" "${HOST}:${REMOTE_ENV}"
  ssh "${SSH_OPTS[@]}" "$HOST" \
    "chmod 600 ${remote_env_q} && chmod 755 ${remote_install_q} && : > ${remote_log_q} && setsid -f bash -c $(shell_quote "$remote_wrapper") > ${remote_log_q} 2>&1 < /dev/null && exit 0" \
    || echo "remote launch connection dropped; polling install log anyway" >&2
}

wait_for_remote_install() {
  local exit_line exit_code remote_log_q

  remote_log_q="$(shell_quote "$REMOTE_LOG")"
  for _ in {1..90}; do
    exit_line="$(ssh "${SSH_OPTS[@]}" "$HOST" "grep -E '^__EXIT__:' ${remote_log_q} | tail -n 1" 2>/dev/null || true)"
    if [ -n "$exit_line" ]; then
      exit_code="${exit_line#__EXIT__:}"
      if [ "$exit_code" = "0" ]; then
        ssh "${SSH_OPTS[@]}" "$HOST" "rm -f $(shell_quote "$REMOTE_ENV")" >/dev/null 2>&1 || true
        return 0
      fi

      ssh "${SSH_OPTS[@]}" "$HOST" "tail -n 120 ${remote_log_q}" >&2 || true
      return "$exit_code"
    fi

    sleep 2
  done

  echo "remote install did not finish in time; last log lines:" >&2
  ssh "${SSH_OPTS[@]}" "$HOST" "tail -n 120 ${remote_log_q}" >&2 || true
  return 1
}

run_remote_validation() {
  local validation_env
  validation_env="$(
    printf 'env'
    printf ' PUBLIC_PORT=%s' "$(shell_quote "$PUBLIC_PORT")"
    printf ' REALITY_443_ENABLED=%s' "$(shell_quote "$REALITY_443_ENABLED")"
    printf ' REALITY_443_PORT=%s' "$(shell_quote "$REALITY_443_PORT")"
    printf ' REALITY_443_PUBLIC_PORT=%s' "$(shell_quote "$REALITY_443_PUBLIC_PORT")"
    printf ' REALITY_443_COMPAT_ENABLED=%s' "$(shell_quote "$REALITY_443_COMPAT_ENABLED")"
    printf ' REALITY_443_COMPAT_PORT=%s' "$(shell_quote "$REALITY_443_COMPAT_PORT")"
    printf ' REALITY_GRPC_ENABLED=%s' "$(shell_quote "$REALITY_GRPC_ENABLED")"
    printf ' REALITY_GRPC_PORT=%s' "$(shell_quote "$REALITY_GRPC_PORT")"
  )"

  ssh "${SSH_OPTS[@]}" "$HOST" "${validation_env} bash -s" <<'REMOTE'
set -euo pipefail

check_service() {
  local service="$1"
  systemctl is-active --quiet "$service"
  printf 'ok service %s\n' "$service"
}

check_listen() {
  local port="$1"
  ss -H -ltn "sport = :${port}" | grep -q .
  printf 'ok listen :%s\n' "$port"
}

check_service sing-box-reality
check_listen "$PUBLIC_PORT"

if [ "$REALITY_443_ENABLED" = "1" ]; then
  check_listen "$REALITY_443_PORT"

  if command -v haproxy >/dev/null 2>&1; then
    haproxy -c -f /etc/haproxy/haproxy.cfg >/dev/null
    printf 'ok haproxy config\n'
    systemctl is-active --quiet haproxy
    printf 'ok service haproxy\n'
    check_listen "$REALITY_443_PUBLIC_PORT"
  else
    echo "haproxy is required for REALITY_443_ENABLED=1" >&2
    exit 1
  fi
fi

if [ "$REALITY_443_COMPAT_ENABLED" = "1" ]; then
  check_listen "$REALITY_443_COMPAT_PORT"
  grep -q "$REALITY_443_COMPAT_PORT" /etc/haproxy/haproxy.cfg
  printf 'ok haproxy route :%s\n' "$REALITY_443_COMPAT_PORT"
fi

if [ "$REALITY_GRPC_ENABLED" = "1" ]; then
  check_listen "$REALITY_GRPC_PORT"
fi
REMOTE
}

start_remote_install
wait_for_remote_install

echo
echo "Remote validation:"
run_remote_validation

REALITY_PUBLIC_KEY_REMOTE="$(ssh "${SSH_OPTS[@]}" "$HOST" "cat /etc/sing-box/reality-public.key")"

echo
echo "Client URIs:"
PUBLIC_HOST="$PUBLIC_HOST" \
PUBLIC_PORT="$PUBLIC_PORT" \
REALITY_PUBLIC_KEY="$REALITY_PUBLIC_KEY_REMOTE" \
  REALITY_SHORT_ID="$REALITY_SHORT_ID" \
  REALITY_SERVER_NAME="$REALITY_SERVER_NAME" \
  VLESS_UUIDS="$VLESS_UUIDS" \
  FLOW="$VLESS_FLOW" \
  LABEL_PREFIX="vless-$(printf '%s' "$PUBLIC_HOST" | tr '.' '-')" \
  "${SCRIPT_DIR}/render-vless-uri.sh"

if [ "${REALITY_443_ENABLED}" = "1" ]; then
  echo
  echo "Client URIs via 443 edge:"
  PUBLIC_HOST="$PUBLIC_HOST" \
  PUBLIC_PORT="$REALITY_443_PUBLIC_PORT" \
  REALITY_PUBLIC_KEY="$REALITY_PUBLIC_KEY_REMOTE" \
  REALITY_SHORT_ID="$REALITY_SHORT_ID" \
  REALITY_SERVER_NAME="$REALITY_443_SERVER_NAME" \
  VLESS_UUIDS="$VLESS_UUIDS" \
  FLOW="$VLESS_FLOW" \
  LABEL_PREFIX="vless-443-$(printf '%s' "$PUBLIC_HOST" | tr '.' '-')" \
    "${SCRIPT_DIR}/render-vless-uri.sh"
fi

if [ -n "${VLESS_COMPAT_UUIDS}" ]; then
  echo
  echo "Client URIs without Vision flow for older V2Ray-compatible clients:"
  PUBLIC_HOST="$PUBLIC_HOST" \
  PUBLIC_PORT="$REALITY_443_PUBLIC_PORT" \
  REALITY_PUBLIC_KEY="$REALITY_PUBLIC_KEY_REMOTE" \
  REALITY_SHORT_ID="$REALITY_SHORT_ID" \
  REALITY_SERVER_NAME="$REALITY_443_SERVER_NAME" \
  VLESS_UUIDS="$VLESS_COMPAT_UUIDS" \
  FLOW="" \
  LABEL_PREFIX="vless-443-compat-$(printf '%s' "$PUBLIC_HOST" | tr '.' '-')" \
    "${SCRIPT_DIR}/render-vless-uri.sh"
fi

if [ "${REALITY_GRPC_ENABLED}" = "1" ]; then
  echo
  echo "Client URIs via gRPC Reality:"
  PUBLIC_HOST="$PUBLIC_HOST" \
  PUBLIC_PORT="$REALITY_GRPC_PUBLIC_PORT" \
  REALITY_PUBLIC_KEY="$REALITY_PUBLIC_KEY_REMOTE" \
  REALITY_SHORT_ID="$REALITY_GRPC_SHORT_ID" \
  REALITY_SERVER_NAME="$REALITY_GRPC_SERVER_NAME" \
  VLESS_UUIDS="$REALITY_GRPC_UUIDS" \
  FLOW="" \
  FINGERPRINT="firefox" \
  TRANSPORT_TYPE="grpc" \
  GRPC_SERVICE_NAME="$REALITY_GRPC_SERVICE_NAME" \
  GRPC_MODE="$REALITY_GRPC_MODE" \
  LABEL_PREFIX="grpc-vpn-$(printf '%s' "$PUBLIC_HOST" | tr '.' '-')" \
    "${SCRIPT_DIR}/render-vless-uri.sh"
fi

if [ "${REALITY_443_COMPAT_ENABLED}" = "1" ]; then
  echo
  echo "Client URIs via 443 Cloudflare compatibility edge:"
  PUBLIC_HOST="$PUBLIC_HOST" \
  PUBLIC_PORT="$REALITY_443_PUBLIC_PORT" \
  REALITY_PUBLIC_KEY="$REALITY_PUBLIC_KEY_REMOTE" \
  REALITY_SHORT_ID="$REALITY_SHORT_ID" \
  REALITY_SERVER_NAME="$REALITY_443_COMPAT_SERVER_NAME" \
  VLESS_UUIDS="$VLESS_UUIDS" \
  LABEL_PREFIX="vless-443-cf-$(printf '%s' "$PUBLIC_HOST" | tr '.' '-')" \
    "${SCRIPT_DIR}/render-vless-uri.sh"
fi
