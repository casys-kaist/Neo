#!/usr/bin/env bash
set -eo pipefail

container="$1"
detach_key="ctrl-e"

docker container attach "$container" --detach-keys "$detach_key"
