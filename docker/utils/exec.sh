#!/usr/bin/env bash
set -eo pipefail

container="$1"

docker container exec -it "$container" /bin/bash
