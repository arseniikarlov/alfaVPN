# VLESS Reality Infra

Separate infrastructure project for deploying `sing-box` with `VLESS + Reality` on a remote Linux server.

The default shape is:
- one `sing-box` systemd service
- one `VLESS` inbound over `Reality`
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

## Default Transport

- Protocol: `VLESS`
- Security: `Reality`
- Transport: `TCP`
- SNI: `www.cloudflare.com`

## Local Commands

Deploy:

```bash
make deploy
```

Print a URI from environment variables:

```bash
PUBLIC_HOST=1.2.3.4 \
PUBLIC_PORT=2053 \
REALITY_PUBLIC_KEY=PUBLIC_KEY \
REALITY_SHORT_ID=e5671ea03f2eccca \
REALITY_SERVER_NAME=www.cloudflare.com \
VLESS_UUIDS=11111111-1111-1111-1111-111111111111 \
make uri
```

## Remote Files

- config: `/etc/sing-box/config.json`
- private key: `/etc/sing-box/reality-private.key`
- public key: `/etc/sing-box/reality-public.key`
- service: `/etc/systemd/system/sing-box-reality.service`
- binary: `/usr/local/bin/sing-box`

