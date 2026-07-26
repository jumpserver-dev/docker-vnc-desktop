#!/usr/bin/env python3
"""Exercise TigerVNC's legacy Latin-1 and extended UTF-8 clipboard paths."""

from __future__ import annotations

import base64
import os
import socket
import struct
import subprocess
import sys
import time
import tkinter
import zlib


RFB_VERSION = b"RFB 003.008\n"
SECURITY_NONE = 1
MSG_SET_ENCODINGS = 2
MSG_SERVER_CUT_TEXT = 3
MSG_CLIENT_CUT_TEXT = 6
ENCODING_EXTENDED_CLIPBOARD = 0xC0A1E5CE

CLIPBOARD_UTF8 = 1 << 0
CLIPBOARD_CAPS = 1 << 24
CLIPBOARD_REQUEST = 1 << 25
CLIPBOARD_PEEK = 1 << 26
CLIPBOARD_NOTIFY = 1 << 27
CLIPBOARD_PROVIDE = 1 << 28

CLIPBOARD_CAPABILITIES = (
    CLIPBOARD_UTF8
    | CLIPBOARD_REQUEST
    | CLIPBOARD_PEEK
    | CLIPBOARD_NOTIFY
    | CLIPBOARD_PROVIDE
)

UTF8_SAMPLE = "中文剪贴板 — café — 日本語 — 🙂 — e\u0301\n第二行"
LEGACY_UTF8_SAMPLE = "传统剪贴板 UTF-8 直传 — 中文 — 日本語 — 🙂"
LATIN1_BYTES = b"caf\xe9 - \xa3"
LATIN1_TEXT = "café - £"


def read_exact(sock: socket.socket, length: int) -> bytes:
    chunks: list[bytes] = []
    remaining = length
    while remaining:
        chunk = sock.recv(remaining)
        if not chunk:
            raise ConnectionError(f"connection closed with {remaining} bytes remaining")
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


def connect_with_retry(port: int, timeout: float = 10.0) -> socket.socket:
    deadline = time.monotonic() + timeout
    while True:
        try:
            sock = socket.create_connection(("127.0.0.1", port), timeout=1.0)
            sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            sock.settimeout(5.0)
            return sock
        except OSError:
            if time.monotonic() >= deadline:
                raise
            time.sleep(0.1)


class RFBClipboardClient:
    def __init__(self, port: int, extended_clipboard: bool = True) -> None:
        self.sock = connect_with_retry(port)
        self._handshake()
        if extended_clipboard:
            self._enable_extended_clipboard()

    def close(self) -> None:
        self.sock.close()

    def _handshake(self) -> None:
        version = read_exact(self.sock, 12)
        if version != RFB_VERSION:
            raise AssertionError(f"unexpected RFB version: {version!r}")
        self.sock.sendall(RFB_VERSION)

        security_count = read_exact(self.sock, 1)[0]
        if security_count == 0:
            reason_length = struct.unpack("!I", read_exact(self.sock, 4))[0]
            reason = read_exact(self.sock, reason_length).decode("utf-8", "replace")
            raise AssertionError(f"server rejected connection: {reason}")
        security_types = read_exact(self.sock, security_count)
        if SECURITY_NONE not in security_types:
            raise AssertionError(f"None security unavailable: {security_types!r}")
        self.sock.sendall(bytes([SECURITY_NONE]))

        security_result = struct.unpack("!I", read_exact(self.sock, 4))[0]
        if security_result != 0:
            raise AssertionError(f"RFB security failed with status {security_result}")

        self.sock.sendall(b"\x01")
        server_init = read_exact(self.sock, 24)
        name_length = struct.unpack("!I", server_init[20:24])[0]
        read_exact(self.sock, name_length)

    def _enable_extended_clipboard(self) -> None:
        encodings = [
            ENCODING_EXTENDED_CLIPBOARD,
            0,
        ]
        self.sock.sendall(
            struct.pack("!BBH", MSG_SET_ENCODINGS, 0, len(encodings))
            + b"".join(struct.pack("!I", encoding) for encoding in encodings)
        )

        flags, payload = self.wait_for_action(CLIPBOARD_CAPS)
        required = CLIPBOARD_CAPABILITIES | CLIPBOARD_CAPS
        if flags & required != required:
            raise AssertionError(f"incomplete server clipboard capabilities: 0x{flags:08x}")
        if len(payload) != 4:
            raise AssertionError(f"unexpected clipboard capabilities payload: {payload!r}")

        self.send_extended(
            CLIPBOARD_CAPS,
            CLIPBOARD_CAPABILITIES,
            struct.pack("!I", 0),
        )

    def send_extended(self, action: int, formats: int, body: bytes = b"") -> None:
        payload = struct.pack("!I", action | formats) + body
        negative_length = (-len(payload)) & 0xFFFFFFFF
        self.sock.sendall(
            bytes([MSG_CLIENT_CUT_TEXT])
            + b"\x00\x00\x00"
            + struct.pack("!I", negative_length)
            + payload
        )

    def provide_utf8(self, data: bytes) -> None:
        encoded = struct.pack("!I", len(data)) + data
        self.send_extended(
            CLIPBOARD_PROVIDE,
            CLIPBOARD_UTF8,
            zlib.compress(encoded),
        )

    def announce_utf8(self) -> None:
        self.send_extended(CLIPBOARD_NOTIFY, CLIPBOARD_UTF8)

    def send_legacy_cut_text(self, data: bytes) -> None:
        self.sock.sendall(
            bytes([MSG_CLIENT_CUT_TEXT])
            + b"\x00\x00\x00"
            + struct.pack("!I", len(data))
            + data
        )

    def read_legacy_cut_text(self) -> bytes:
        message_type = read_exact(self.sock, 1)[0]
        if message_type != MSG_SERVER_CUT_TEXT:
            raise AssertionError(f"unexpected server message type: {message_type}")
        read_exact(self.sock, 3)
        wire_length = struct.unpack("!I", read_exact(self.sock, 4))[0]
        if wire_length & 0x80000000:
            raise AssertionError("unexpected extended clipboard message")
        return read_exact(self.sock, wire_length)

    def read_extended(self) -> tuple[int, bytes]:
        message_type = read_exact(self.sock, 1)[0]
        if message_type != MSG_SERVER_CUT_TEXT:
            raise AssertionError(f"unexpected server message type: {message_type}")
        read_exact(self.sock, 3)
        wire_length = struct.unpack("!I", read_exact(self.sock, 4))[0]
        if not wire_length & 0x80000000:
            data = read_exact(self.sock, wire_length)
            raise AssertionError(f"unexpected legacy clipboard message: {data!r}")
        payload_length = (-struct.unpack("!i", struct.pack("!I", wire_length))[0])
        payload = read_exact(self.sock, payload_length)
        if len(payload) < 4:
            raise AssertionError(f"short extended clipboard message: {payload!r}")
        return struct.unpack("!I", payload[:4])[0], payload[4:]

    def wait_for_action(self, action: int, timeout: float = 5.0) -> tuple[int, bytes]:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            self.sock.settimeout(max(0.1, deadline - time.monotonic()))
            flags, payload = self.read_extended()
            if flags & action:
                return flags, payload
        raise TimeoutError(f"timed out waiting for clipboard action 0x{action:08x}")

    def request_utf8(self) -> str:
        self.send_extended(CLIPBOARD_REQUEST, CLIPBOARD_UTF8)
        flags, compressed = self.wait_for_action(CLIPBOARD_PROVIDE)
        if not flags & CLIPBOARD_UTF8:
            raise AssertionError(f"server did not provide UTF-8: 0x{flags:08x}")
        decompressor = zlib.decompressobj()
        decoded = decompressor.decompress(compressed)
        if len(decoded) < 4:
            raise AssertionError(f"short clipboard data: {decoded!r}")
        length = struct.unpack("!I", decoded[:4])[0]
        data = decoded[4 : 4 + length]
        if len(data) != length:
            raise AssertionError(f"truncated clipboard data: expected {length}, got {len(data)}")
        if data.endswith(b"\x00"):
            data = data[:-1]
        return data.decode("utf-8").replace("\r\n", "\n")


def read_x11_clipboard(expected: str, timeout: float = 5.0) -> str:
    deadline = time.monotonic() + timeout
    last_error: Exception | None = None
    while time.monotonic() < deadline:
        root = tkinter.Tk()
        root.withdraw()
        try:
            value = root.clipboard_get(type="UTF8_STRING")
            if value == expected:
                return value
        except tkinter.TclError as exc:
            last_error = exc
        finally:
            root.destroy()
        time.sleep(0.05)
    raise AssertionError(
        f"X11 clipboard did not become {expected!r}; last error was {last_error!r}"
    )


def own_x11_clipboard(encoded_text: str) -> None:
    text = base64.b64decode(encoded_text).decode("utf-8")
    root = tkinter.Tk()
    root.withdraw()
    root.clipboard_clear()
    root.clipboard_append(text)
    root.update()
    print("ready", flush=True)
    while True:
        root.update()
        time.sleep(0.01)


def start_x11_reader(expected: str) -> subprocess.Popen[str]:
    encoded = base64.b64encode(expected.encode("utf-8")).decode("ascii")
    return subprocess.Popen(
        [sys.executable, __file__, "--read", encoded],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def wait_for_x11_reader(reader: subprocess.Popen[str], timeout: float = 5.0) -> None:
    stdout, stderr = reader.communicate(timeout=timeout)
    if reader.returncode != 0 or stdout.strip() != "ready":
        raise AssertionError(
            f"X11 clipboard reader failed: status={reader.returncode}, "
            f"stdout={stdout!r}, stderr={stderr!r}"
        )


def receive_remote_utf8(
    client: RFBClipboardClient, wire_data: bytes, expected: str
) -> None:
    client.announce_utf8()
    reader = start_x11_reader(expected)
    try:
        flags, _ = client.wait_for_action(CLIPBOARD_REQUEST)
        if not flags & CLIPBOARD_UTF8:
            raise AssertionError(f"server requested wrong clipboard format: 0x{flags:08x}")
        client.provide_utf8(wire_data)
        wait_for_x11_reader(reader)
    finally:
        if reader.poll() is None:
            reader.terminate()
            reader.wait(timeout=5)


def run_tests() -> None:
    client = RFBClipboardClient(port=int(os.environ.get("RFB_TEST_PORT", "5999")))
    try:
        # Extended clipboard data is UTF-8 and must survive byte-for-byte.
        receive_remote_utf8(
            client,
            UTF8_SAMPLE.encode("utf-8") + b"\x00",
            UTF8_SAMPLE,
        )

        # Invalid extended UTF-8 must be rejected, and the connection must
        # remain healthy enough for the next valid transfer.
        client.announce_utf8()
        invalid_reader = start_x11_reader("invalid data must not be exposed")
        try:
            client.wait_for_action(CLIPBOARD_REQUEST)
            client.provide_utf8(b"\xf0(\x8c(\x00")
            time.sleep(0.5)
            if invalid_reader.poll() is not None:
                stdout, stderr = invalid_reader.communicate()
                raise AssertionError(
                    "invalid UTF-8 unexpectedly completed an X11 selection: "
                    f"stdout={stdout!r}, stderr={stderr!r}"
                )
        finally:
            if invalid_reader.poll() is None:
                invalid_reader.terminate()
                invalid_reader.wait(timeout=5)

        recovery_sample = UTF8_SAMPLE + " — recovery ✓"
        receive_remote_utf8(
            client,
            recovery_sample.encode("utf-8") + b"\x00",
            recovery_sample,
        )

        # Some web clients put UTF-8 directly in the legacy ClientCutText
        # message. Preserve it instead of decoding each byte as Latin-1.
        client.send_legacy_cut_text(LEGACY_UTF8_SAMPLE.encode("utf-8"))
        read_x11_clipboard(LEGACY_UTF8_SAMPLE)

        # Legacy RFB CutText is Latin-1, even if the desktop locale is UTF-8.
        # Invalid UTF-8 falls back to the protocol-standard Latin-1 decoding.
        client.send_legacy_cut_text(LATIN1_BYTES)
        read_x11_clipboard(LATIN1_TEXT)

        # Verify the opposite direction: X11 UTF8_STRING -> extended RFB UTF-8.
        encoded = base64.b64encode(UTF8_SAMPLE.encode("utf-8")).decode("ascii")
        owner = subprocess.Popen(
            [sys.executable, __file__, "--own", encoded],
            stdout=subprocess.PIPE,
            text=True,
        )
        try:
            assert owner.stdout is not None
            if owner.stdout.readline().strip() != "ready":
                raise AssertionError("clipboard owner did not start")
            while True:
                flags, _ = client.wait_for_action(CLIPBOARD_NOTIFY)
                if flags & CLIPBOARD_UTF8:
                    break
            received = client.request_utf8()
            if received != UTF8_SAMPLE:
                raise AssertionError(
                    f"server-to-client clipboard mismatch: {received!r}"
                )
        finally:
            owner.terminate()
            owner.wait(timeout=5)

        # Preserve desktop UTF-8 when sending to clients that only implement
        # legacy ServerCutText, matching the deployment's historical behavior.
        legacy_client = RFBClipboardClient(
            port=int(os.environ.get("RFB_TEST_PORT", "5999")),
            extended_clipboard=False,
        )
        encoded = base64.b64encode(LEGACY_UTF8_SAMPLE.encode("utf-8")).decode("ascii")
        legacy_owner = subprocess.Popen(
            [sys.executable, __file__, "--own", encoded],
            stdout=subprocess.PIPE,
            text=True,
        )
        try:
            assert legacy_owner.stdout is not None
            if legacy_owner.stdout.readline().strip() != "ready":
                raise AssertionError("legacy clipboard owner did not start")
            wire_data = legacy_client.read_legacy_cut_text()
            if wire_data != LEGACY_UTF8_SAMPLE.encode("utf-8"):
                raise AssertionError(
                    f"legacy server clipboard was not raw UTF-8: {wire_data!r}"
                )
        finally:
            legacy_owner.terminate()
            legacy_owner.wait(timeout=5)
            legacy_client.close()
    finally:
        client.close()

    print("TigerVNC clipboard encoding checks passed")


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--own":
        own_x11_clipboard(sys.argv[2])
    elif len(sys.argv) == 3 and sys.argv[1] == "--read":
        expected_text = base64.b64decode(sys.argv[2]).decode("utf-8")
        read_x11_clipboard(expected_text, timeout=10)
        print("ready", flush=True)
    elif len(sys.argv) == 1:
        run_tests()
    else:
        raise SystemExit(f"usage: {sys.argv[0]} [--own|--read BASE64_TEXT]")
