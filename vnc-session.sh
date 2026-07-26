#!/usr/bin/env bash

set -Eeuo pipefail

SCREEN_WIDTH=${JUMPSERVER_WIDTH:-1280}
SCREEN_HEIGHT=${JUMPSERVER_HEIGHT:-800}
GEOMETRY="${SCREEN_WIDTH}x${SCREEN_HEIGHT}"
DEPTH=${JUMPSERVER_DEPTH:-24}
DPI=${JUMPSERVER_DPI:-96}
DISPLAY_NUMBER=0
DISPLAY=":${DISPLAY_NUMBER}"
export DISPLAY

VNC_PID=
DESKTOP_PID=

cleanup() {
    local status=$?

    trap - EXIT INT TERM
    if [ -n "${DESKTOP_PID}" ]; then
        kill "${DESKTOP_PID}" 2>/dev/null || true
    fi
    if [ -n "${VNC_PID}" ]; then
        kill "${VNC_PID}" 2>/dev/null || true
    fi
    wait "${DESKTOP_PID}" 2>/dev/null || true
    wait "${VNC_PID}" 2>/dev/null || true
    exit "${status}"
}
trap cleanup EXIT INT TERM

touch "${HOME}/.Xauthority"
chmod 600 "${HOME}/.Xauthority"
COOKIE=$(mcookie)
xauth -f "${HOME}/.Xauthority" add "$(hostname)/unix:${DISPLAY_NUMBER}" . "${COOKIE}"
xauth -f "${HOME}/.Xauthority" add "${DISPLAY}" . "${COOKIE}"

/usr/bin/Xtigervnc "${DISPLAY}" \
    -geometry "${GEOMETRY}" \
    -depth "${DEPTH}" \
    -dpi "${DPI}" \
    -localhost=0 \
    -PasswordFile="${HOME}/.vnc/passwd" \
    -SecurityTypes=VncAuth \
    -AcceptCutText=1 \
    -SendCutText=1 \
    -AcceptLegacyClipboardUTF8=1 \
    -SendLegacyClipboardUTF8=1 \
    -auth "${HOME}/.Xauthority" \
    "$@" &
VNC_PID=$!

for _ in $(seq 1 100); do
    if [ -S "/tmp/.X11-unix/X${DISPLAY_NUMBER}" ]; then
        break
    fi
    if ! kill -0 "${VNC_PID}" 2>/dev/null; then
        wait "${VNC_PID}"
    fi
    sleep 0.1
done

if [ ! -S "/tmp/.X11-unix/X${DISPLAY_NUMBER}" ]; then
    echo "TigerVNC did not create display ${DISPLAY}" >&2
    exit 1
fi

"${HOME}/.vnc/xstartup" &
DESKTOP_PID=$!

wait -n "${VNC_PID}" "${DESKTOP_PID}"
