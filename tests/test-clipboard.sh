#!/usr/bin/env bash

set -Eeuo pipefail

IMAGE=${1:-docker-vnc-desktop:tigervnc-1.16.2}
TEST_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

docker run --rm \
    --entrypoint /bin/bash \
    --volume "${TEST_DIR}:/tests:ro" \
    "${IMAGE}" \
    -c '
set -Eeuo pipefail

LOG_FILE=/tmp/tigervnc-clipboard-test.log
VNC_PID=

cleanup() {
    status=$?
    trap - EXIT
    if [ -n "${VNC_PID}" ]; then
        kill "${VNC_PID}" 2>/dev/null || true
        wait "${VNC_PID}" 2>/dev/null || true
    fi
    if [ "${status}" -ne 0 ]; then
        sed -n "1,240p" "${LOG_FILE}" >&2
    fi
    exit "${status}"
}
trap cleanup EXIT

version_output=$(/usr/bin/Xtigervnc -version 2>&1)
case "${version_output}" in
    *"TigerVNC 1.16.2"*) ;;
    *)
        echo "Expected TigerVNC 1.16.2, got: ${version_output}" >&2
        exit 1
        ;;
esac

test "$(locale charmap)" = "UTF-8"

/usr/bin/Xtigervnc :99 \
    -geometry 800x600 \
    -depth 24 \
    -rfbport 5999 \
    -localhost=1 \
    -Log "*:stderr:100" \
    -SecurityTypes=None \
    -AcceptCutText=1 \
    -SendCutText=1 \
    -AcceptLegacyClipboardUTF8=1 \
    -SendLegacyClipboardUTF8=1 \
    -ac >"${LOG_FILE}" 2>&1 &
VNC_PID=$!

DISPLAY=:99 python3 /tests/clipboard_roundtrip.py
grep -Fq "Invalid UTF-8 sequence in clipboard - ignoring" "${LOG_FILE}"
'
