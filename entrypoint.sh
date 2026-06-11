#!/usr/bin/env bash
set -euo pipefail

CARLA_HOME="${CARLA_HOME:-${HOME:-/tmp/pcla-carla-home}}"
export HOME="${CARLA_HOME}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-${CARLA_HOME}/.cache}"
mkdir -p "${HOME}/carlaCache" "${XDG_CACHE_HOME}"

exec /opt/conda/envs/PCLA/bin/python -m pcla_wrapper.server
