SHELL := /bin/bash

ifneq ("$(wildcard .env)","")
include .env
export
endif

HOST ?=

.PHONY: deploy uri

deploy:
	./scripts/deploy-singbox-reality.sh $(HOST)

uri:
	./scripts/render-vless-uri.sh

