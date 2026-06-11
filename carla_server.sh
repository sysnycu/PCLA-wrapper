#!/usr/bin/env bash
set -euo pipefail

CARLA_ROOT="${CARLA_ROOT:-/opt/carla}"
CARLA_EXECUTABLE="${CARLA_EXECUTABLE:-${CARLA_ROOT}/CarlaUE4.sh}"
CARLA_HOME="${CARLA_HOME:-${HOME:-/tmp/pcla-carla-home}}"

export HOME="${CARLA_HOME}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-${CARLA_HOME}/.cache}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-${CARLA_HOME}/runtime}"

mkdir -p "${HOME}/carlaCache" "${XDG_CACHE_HOME}" "${XDG_RUNTIME_DIR}"
chmod 0777 "${HOME}" "${HOME}/carlaCache" "${XDG_CACHE_HOME}" "${XDG_RUNTIME_DIR}"

if [[ -n "${DISPLAY:-}" && -z "${XAUTHORITY:-}" ]]; then
    for authority in /home/carla/.Xauthority /root/.Xauthority; do
        if [[ -r "${authority}" ]]; then
            export XAUTHORITY="${authority}"
            break
        fi
    done
fi

if [[ ! -x "${CARLA_EXECUTABLE}" ]]; then
    echo "CARLA executable is not available: ${CARLA_EXECUTABLE}" >&2
    exit 127
fi

args=(
    -RenderOffScreen
    -nosound
    "-carla-port=${CARLA_PORT:-2000}"
    "-carla-rpc-timeout=${CARLA_TIMEOUT:-120}"
    "-carla-tm-port=${CARLA_TM_PORT:-8000}"
)

# NullRHI disables the rendering pipeline used by CARLA camera sensors and can
# only be used by sensorless agents. CARLA 0.9.16 crashes when NullRHI and
# quality-level are supplied together, so quality is set only for rendered mode.
if [[ "${CARLA_NULLRHI:-0}" == "1" ]]; then
    args+=(-nullrhi)
else
    args+=("-quality-level=${CARLA_QUALITY_LEVEL:-Low}")
fi

# CarlaUE4 resolves some runtime files relative to its launch directory.
cd "${CARLA_ROOT}"

if [[ "$(id -u)" == "0" ]]; then
    run_uid="${CARLA_RUN_UID:-$(id -u carla)}"
    run_gid="${CARLA_RUN_GID:-$(id -g carla)}"
    exec setpriv \
        "--reuid=${run_uid}" \
        "--regid=${run_gid}" \
        --clear-groups \
        "${CARLA_EXECUTABLE}" "${args[@]}"
fi

exec "${CARLA_EXECUTABLE}" "${args[@]}"
