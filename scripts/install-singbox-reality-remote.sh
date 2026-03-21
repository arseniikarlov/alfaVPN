#!/usr/bin/env bash
set -euo pipefail

PUBLIC_PORT="${PUBLIC_PORT:-2053}"
SING_BOX_VERSION="${SING_BOX_VERSION:-1.12.20}"
REALITY_SERVER_NAME="${REALITY_SERVER_NAME:-www.cloudflare.com}"
REALITY_HANDSHAKE_SERVER="${REALITY_HANDSHAKE_SERVER:-$REALITY_SERVER_NAME}"
REALITY_HANDSHAKE_PORT="${REALITY_HANDSHAKE_PORT:-443}"
REALITY_SHORT_ID="${REALITY_SHORT_ID:-e5671ea03f2eccca}"
VLESS_UUIDS="${VLESS_UUIDS:?VLESS_UUIDS is required}"
REALITY_PRIVATE_KEY="${REALITY_PRIVATE_KEY:-}"
REALITY_PUBLIC_KEY="${REALITY_PUBLIC_KEY:-}"

BIN_PATH="/usr/local/bin/sing-box"
CONFIG_DIR="/etc/sing-box"
CONFIG_PATH="${CONFIG_DIR}/config.json"
STATE_DIR="/var/lib/sing-box"
PRIVATE_KEY_PATH="${CONFIG_DIR}/reality-private.key"
PUBLIC_KEY_PATH="${CONFIG_DIR}/reality-public.key"
SERVICE_PATH="/etc/systemd/system/sing-box-reality.service"

log() {
  printf '%s\n' "$*"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

need_cmd curl
need_cmd tar
need_cmd python3
need_cmd install
need_cmd systemctl
need_cmd useradd
need_cmd groupadd

ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
case "$ARCH" in
  amd64|x86_64)
    RELEASE_ARCH="linux-amd64"
    ;;
  *)
    echo "unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

install -d -m 755 "$CONFIG_DIR" "$STATE_DIR"

if ! getent group sing-box >/dev/null 2>&1; then
  groupadd --system sing-box
fi

if ! id -u sing-box >/dev/null 2>&1; then
  useradd --system --gid sing-box --home-dir "$STATE_DIR" --shell /usr/sbin/nologin sing-box
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

CURRENT_VERSION=""
if [ -x "$BIN_PATH" ]; then
  CURRENT_VERSION="$("$BIN_PATH" version 2>/dev/null | awk 'NR==1{print $3}')"
fi

if [ "$CURRENT_VERSION" != "$SING_BOX_VERSION" ]; then
  ARCHIVE="sing-box-${SING_BOX_VERSION}-${RELEASE_ARCH}.tar.gz"
  URL="https://github.com/SagerNet/sing-box/releases/download/v${SING_BOX_VERSION}/${ARCHIVE}"
  log "downloading sing-box ${SING_BOX_VERSION}"
  curl -fsSL "$URL" -o "${TMP_DIR}/${ARCHIVE}"
  tar -xzf "${TMP_DIR}/${ARCHIVE}" -C "$TMP_DIR"
  install -m 755 "${TMP_DIR}/sing-box-${SING_BOX_VERSION}-${RELEASE_ARCH}/sing-box" "$BIN_PATH"
fi

if [ -n "$REALITY_PRIVATE_KEY" ] || [ -n "$REALITY_PUBLIC_KEY" ]; then
  if [ -z "$REALITY_PRIVATE_KEY" ] || [ -z "$REALITY_PUBLIC_KEY" ]; then
    echo "REALITY_PRIVATE_KEY and REALITY_PUBLIC_KEY must be provided together" >&2
    exit 1
  fi
else
  if [ -f "$PRIVATE_KEY_PATH" ] && [ -f "$PUBLIC_KEY_PATH" ]; then
    REALITY_PRIVATE_KEY="$(cat "$PRIVATE_KEY_PATH")"
    REALITY_PUBLIC_KEY="$(cat "$PUBLIC_KEY_PATH")"
  else
    KEYPAIR_OUTPUT="$("$BIN_PATH" generate reality-keypair)"
    REALITY_PRIVATE_KEY="$(printf '%s\n' "$KEYPAIR_OUTPUT" | awk -F': ' '/^PrivateKey:/{print $2}')"
    REALITY_PUBLIC_KEY="$(printf '%s\n' "$KEYPAIR_OUTPUT" | awk -F': ' '/^PublicKey:/{print $2}')"
  fi
fi

printf '%s\n' "$REALITY_PRIVATE_KEY" > "$PRIVATE_KEY_PATH"
printf '%s\n' "$REALITY_PUBLIC_KEY" > "$PUBLIC_KEY_PATH"
chmod 600 "$PRIVATE_KEY_PATH"
chmod 644 "$PUBLIC_KEY_PATH"

USERS_JSON="$(
  VLESS_UUIDS="$VLESS_UUIDS" python3 - <<'PY'
import json
import os

uuids = [x.strip() for x in os.environ["VLESS_UUIDS"].split(",") if x.strip()]
print(json.dumps([{"uuid": uuid} for uuid in uuids], ensure_ascii=True))
PY
)"

PUBLIC_PORT="$PUBLIC_PORT" \
REALITY_SERVER_NAME="$REALITY_SERVER_NAME" \
REALITY_HANDSHAKE_SERVER="$REALITY_HANDSHAKE_SERVER" \
REALITY_HANDSHAKE_PORT="$REALITY_HANDSHAKE_PORT" \
REALITY_SHORT_ID="$REALITY_SHORT_ID" \
REALITY_PRIVATE_KEY="$REALITY_PRIVATE_KEY" \
USERS_JSON="$USERS_JSON" \
python3 - <<'PY' > "$CONFIG_PATH"
import json
import os

config = {
    "log": {"level": "warn"},
    "inbounds": [
        {
            "type": "vless",
            "listen": "::",
            "listen_port": int(os.environ["PUBLIC_PORT"]),
            "tls": {
                "enabled": True,
                "server_name": os.environ["REALITY_SERVER_NAME"],
                "reality": {
                    "enabled": True,
                    "handshake": {
                        "server": os.environ["REALITY_HANDSHAKE_SERVER"],
                        "server_port": int(os.environ["REALITY_HANDSHAKE_PORT"]),
                    },
                    "private_key": os.environ["REALITY_PRIVATE_KEY"],
                    "short_id": [os.environ["REALITY_SHORT_ID"]],
                },
            },
            "users": json.loads(os.environ["USERS_JSON"]),
        }
    ],
    "outbounds": [{"type": "direct"}],
}

print(json.dumps(config, indent=2))
PY

chown -R root:root "$CONFIG_DIR"
chown -R sing-box:sing-box "$STATE_DIR"

"$BIN_PATH" check -c "$CONFIG_PATH"

cat > "$SERVICE_PATH" <<SERVICE
[Unit]
Description=sing-box Reality VLESS service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target network-online.target
Wants=network-online.target

[Service]
User=sing-box
Group=sing-box
StateDirectory=sing-box
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
ExecStart=${BIN_PATH} -D ${STATE_DIR} -C ${CONFIG_DIR} run
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
SERVICE

if command -v ufw >/dev/null 2>&1; then
  if ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw allow "${PUBLIC_PORT}/tcp" >/dev/null 2>&1 || true
  fi
fi

systemctl daemon-reload
systemctl enable --now sing-box-reality.service
systemctl restart sing-box-reality.service
sleep 2
systemctl --no-pager --full status sing-box-reality.service
ss -ltn | grep -q ":${PUBLIC_PORT} "

log ""
log "Reality public key:"
cat "$PUBLIC_KEY_PATH"
log ""
log "Reality short id:"
printf '%s\n' "$REALITY_SHORT_ID"
