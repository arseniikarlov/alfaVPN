#!/usr/bin/env bash
set -euo pipefail

PUBLIC_HOST="${PUBLIC_HOST:?PUBLIC_HOST is required}"
PUBLIC_PORT="${PUBLIC_PORT:?PUBLIC_PORT is required}"
REALITY_PUBLIC_KEY="${REALITY_PUBLIC_KEY:?REALITY_PUBLIC_KEY is required}"
REALITY_SHORT_ID="${REALITY_SHORT_ID?REALITY_SHORT_ID is required}"
REALITY_SERVER_NAME="${REALITY_SERVER_NAME:?REALITY_SERVER_NAME is required}"
VLESS_UUIDS="${VLESS_UUIDS:?VLESS_UUIDS is required}"
LABEL_PREFIX="${LABEL_PREFIX:-vless-reality}"
FINGERPRINT="${FINGERPRINT:-chrome}"
FLOW="${FLOW-xtls-rprx-vision}"
TRANSPORT_TYPE="${TRANSPORT_TYPE:-tcp}"
GRPC_SERVICE_NAME="${GRPC_SERVICE_NAME:-}"
GRPC_MODE="${GRPC_MODE:-gun}"

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
flow = os.environ.get("FLOW", "xtls-rprx-vision")
transport_type = os.environ.get("TRANSPORT_TYPE", "tcp")
grpc_service_name = os.environ.get("GRPC_SERVICE_NAME", "")
grpc_mode = os.environ.get("GRPC_MODE", "gun")

for idx, uuid in enumerate(uuids, start=1):
    label = urllib.parse.quote(f"{label_prefix}-{idx}")
    query_params = {
        "encryption": "none",
        "security": "reality",
        "sni": sni,
        "fp": fingerprint,
        "pbk": public_key,
        "sid": short_id,
        "type": transport_type,
    }
    if transport_type == "grpc":
        query_params["serviceName"] = grpc_service_name
        query_params["mode"] = grpc_mode
    else:
        query_params["headerType"] = "none"
    if flow:
        query_params["flow"] = flow

    query = urllib.parse.urlencode(query_params)
    print(f"vless://{uuid}@{host}:{port}?{query}#{label}")
PY
