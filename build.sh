#!/bin/sh

# Author: haibara <haibara@bebasid.com>
# =====================================
#
# The copyright holder <haibara> grant the freedom
# to copy, modify, convey, adapt, and/or redistribute this work 
# under the terms of the Massachusetts Institute of Technology License.

echo -e "==== BUILD DEFAULT UNBOUND DOCKER IMAGE ===="
docker build -t ghcr.io/bebasid/unbound-default:latest  -f Dockerfile-default .

echo -e "==== BUILD DEFAULT FAMILY DOCKER IMAGE ===="
docker build -t ghcr.io/bebasid/unbound-family:latest  -f Dockerfile-family .

