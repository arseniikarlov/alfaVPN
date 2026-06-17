# VLESS Reality Infra

Separate infrastructure project for deploying `sing-box` with `VLESS + Reality + Vision` on a remote Linux server.

The default shape is:
- one `sing-box` systemd service
- one `VLESS` inbound over `Reality` with `xtls-rprx-vision`
- optional hidden `Reality` inbound on localhost for a front proxy on `443`
- pinned `sing-box` version from the official GitHub release
- a deploy script that installs or updates the service over SSH

## Quick Start

```bash
cp .env.example .env
```

Fill in:
- `HOST`
- `PUBLIC_HOST`
- `PUBLIC_PORT`
- `VLESS_UUIDS`

Optional if you route `443` through a front proxy like `haproxy`:
- `REALITY_443_ENABLED=1`
- `REALITY_443_PORT=12053`
- `REALITY_443_SERVER_NAME=www.mozilla.org`
- `REALITY_443_HANDSHAKE_SERVER=www.mozilla.org`
- `REALITY_443_PUBLIC_PORT=443`
- `REALITY_443_COMPAT_ENABLED=0`
- `REALITY_443_COMPAT_PORT=12054`
- `REALITY_443_COMPAT_SERVER_NAME=www.cloudflare.com`
- `REALITY_443_COMPAT_HANDSHAKE_SERVER=www.cloudflare.com`

Optional gRPC Reality inbound:
- `REALITY_GRPC_ENABLED=1`
- `REALITY_GRPC_PORT=22053`
- `REALITY_GRPC_SERVER_NAME=httpredir.debian.org`
- `REALITY_GRPC_HANDSHAKE_SERVER=httpredir.debian.org`
- `REALITY_GRPC_SHORT_ID=`
- `REALITY_GRPC_SERVICE_NAME=ftp.debian.org`
- `REALITY_GRPC_MODE=gun`
- `REALITY_GRPC_UUIDS=a0fc23ec-04d1-4bac-8579-791b0142a88d`

Then deploy:

```bash
make deploy
```

The deploy script will:
- install or update `sing-box`
- generate a fresh `Reality` keypair if none exists
- write `/etc/sing-box/config.json`
- start `sing-box-reality.service`
- print the active `public key`
- print ready-to-use `vless://` URIs
- print an extra `vless://` URI for `443` when `REALITY_443_ENABLED=1`
- print an extra `vless://` URI for gRPC when `REALITY_GRPC_ENABLED=1`
- print a compatibility `443` URI for old `www.cloudflare.com` SNI clients when `REALITY_443_COMPAT_ENABLED=1`; keep this off when `www.cloudflare.com` is reserved for Telegram MTProxy Fake-TLS

## Default Transport

- Protocol: `VLESS`
- Security: `Reality`
- Transport: `TCP`
- Flow: `xtls-rprx-vision`
- SNI: `www.cloudflare.com`

## Local Commands

Deploy:

```bash
make deploy
```

Print a URI from environment variables:

```bash
make uri \
  PUBLIC_HOST=1.2.3.4 \
  PUBLIC_PORT=2053 \
  REALITY_PUBLIC_KEY=PUBLIC_KEY \
  REALITY_SHORT_ID=e5671ea03f2eccca \
  REALITY_SERVER_NAME=www.cloudflare.com \
  VLESS_UUIDS=11111111-1111-1111-1111-111111111111
```

Print a URI for a `443` edge that forwards to a hidden localhost inbound:

```bash
make uri \
  PUBLIC_HOST=1.2.3.4 \
  PUBLIC_PORT=443 \
  REALITY_PUBLIC_KEY=PUBLIC_KEY \
  REALITY_SHORT_ID=e5671ea03f2eccca \
  REALITY_SERVER_NAME=www.mozilla.org \
  VLESS_UUIDS=11111111-1111-1111-1111-111111111111 \
  LABEL_PREFIX=vless-443-1-2-3-4
```

Print a compatibility URI for clients that still use `www.cloudflare.com` on `443`:

```bash
make uri \
  PUBLIC_HOST=1.2.3.4 \
  PUBLIC_PORT=443 \
  REALITY_PUBLIC_KEY=PUBLIC_KEY \
  REALITY_SHORT_ID=e5671ea03f2eccca \
  REALITY_SERVER_NAME=www.cloudflare.com \
  VLESS_UUIDS=11111111-1111-1111-1111-111111111111 \
  LABEL_PREFIX=vless-443-cf-1-2-3-4
```

## Remote Files

- config: `/etc/sing-box/config.json`
- private key: `/etc/sing-box/reality-private.key`
- public key: `/etc/sing-box/reality-public.key`
- service: `/etc/systemd/system/sing-box-reality.service`
- binary: `/usr/local/bin/sing-box`
