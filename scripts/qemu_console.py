#!/usr/bin/env python3
import socket
import sys
import time

def main():
    sock_path, payload_path, log_path, timeout_s, connect_delay_s = sys.argv[1:6]
    timeout_s = float(timeout_s)
    connect_delay_s = float(connect_delay_s)

    deadline = time.monotonic() + 60
    s = None
    while time.monotonic() < deadline:
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(sock_path)
            break
        except OSError:
            s = None
            time.sleep(1)
    if s is None:
        print("could not connect to QEMU console socket", file=sys.stderr)
        return 1

    time.sleep(connect_delay_s)
    with open(payload_path, "rb") as f:
        payload = f.read()
    chunk_size = 200
    for i in range(0, len(payload), chunk_size):
        s.sendall(payload[i:i + chunk_size])
        time.sleep(0.1)

    s.settimeout(5)
    end = time.monotonic() + timeout_s
    with open(log_path, "ab") as log:
        while time.monotonic() < end:
            try:
                chunk = s.recv(4096)
            except socket.timeout:
                continue
            if not chunk:
                return 0
            log.write(chunk)
            log.flush()
    return 1

if __name__ == "__main__":
    sys.exit(main())
