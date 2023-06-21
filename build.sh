#!/bin/sh
echo -e "==== BUILD DEFAULT FAMILY DOCKER IMAGE ===="
docker build -t ghcr.io/bebasid/unbound-family:latest  -f Dockerfile .