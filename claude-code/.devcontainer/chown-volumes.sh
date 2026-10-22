#!/bin/bash
# Give node the template's named-volume mount points, a safety net in case Docker
# didn't seed a new volume's ownership. Baked root-owned into the sandbox image
# at /usr/local/sbin/chown-volumes and run through sudo instead of a blanket
# `sudo chown`, which would let the agent chown anything (#208).
#
# Mount points only, no -R: a new volume's root is the only root-owned part. -h
# and -execdir stop a symlink swapped in by the agent redirecting chown.

set -euo pipefail

find /workspace -maxdepth 4 -name node_modules -type d -execdir chown -h node {} +
chown -h node /home/node/.claude /commandhistory /home/node/.config/gh /home/node/.config/cloudflare
