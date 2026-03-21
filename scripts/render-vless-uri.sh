#!/usr/bin/env bash
set -euo pipefail

PUBLIC_HOST="${PUBLIC_HOST:?PUBLIC_HOST is required}"
PUBLIC_PORT="${PUBLIC_PORT:?PUBLIC_PORT is required}"
REALITY_PUBLIC_KEY="${REALITY_PUBLIC_KEY:?REALITY_PUBLIC_KEY is required}"
REALITY_SHORT_ID="${REALITY_SHORT_ID:?REALITY_SHORT_ID is required}"
REALITY_SERVER_NAME="${REALITY_SERVER_NAME:?REALITY_SERVER_NAME is required}"
VLESS_UUIDS="${VLESS_UUIDS:?VLESS_UUIDS is required}"
LABEL_PREFIX="${LABEL_PREFIX:-vless-reality}"
FINGERPRINT="${FINGERPRINT:-chrome}"

python3 - <<'PY'
import os
import urllib.parse

host = os.environ["PUBLIC_HOST"]
port = os.environ["PUBLIC_PORT"]
public_key = os.environ["REALITY_PUBLIC_KEY"]
short_id = os.environ["REALITY_SHORT_ID"]
sni = os.environ["REALITY_SERVER_NAME"]
uuids = [x.strip() for x in os.environ["VLESS_UUIDS"].split(",") if x.strip()]
label_prefix = os.environ.get("LABEL_PREFIX", "vless-reality")
fingerprint = os.environ.get("FINGERPRINT", "chrome")

for idx, uuid in enumerate(uuids, start=1):
    label = urllib.parse.quote(f"{label_prefix}-{idx}")
    query = urllib.parse.urlencode(
        {
            "encryption": "none",
            "security": "reality",
            "sni": sni,
            "fp": fingerprint,
            "pbk": public_key,
            "sid": short_id,
            "type": "tcp",
            "headerType": "none",
        }
    )
    print(f"vless://{uuid}@{host}:{port}?{query}#{label}")
PY

