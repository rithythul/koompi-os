#!/usr/bin/env python3
import socket
import sys
import time

def main():
    sock_path, payload_path, log_path, timeout_s, quiet_s, landmark = sys.argv[1:7]
    timeout_s = float(timeout_s)
    quiet_s = float(quiet_s)
    landmark_bytes = landmark.encode()

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

    with open(payload_path, "rb") as f:
        payload = f.read()

    s.settimeout(1)
    end = time.monotonic() + timeout_s
    sent = False
    seen_landmark = False
    last_data_at = None
    tail = b""
    with open(log_path, "ab") as log:
        while time.monotonic() < end:
            try:
                chunk = s.recv(4096)
            except socket.timeout:
                chunk = None
            if chunk is not None:
                if not chunk:
                    return 0 if sent else 1
                last_data_at = time.monotonic()
                log.write(chunk)
                log.flush()
                if not seen_landmark:
                    tail = (tail + chunk)[-4096:]
                    if landmark_bytes in tail:
                        seen_landmark = True

            if (
                not sent
                and seen_landmark
                and last_data_at is not None
                and (time.monotonic() - last_data_at) >= quiet_s
            ):
                chunk_size = 200
                for i in range(0, len(payload), chunk_size):
                    s.sendall(payload[i:i + chunk_size])
                    time.sleep(0.1)
                sent = True
    return 1 if not sent else 1

if __name__ == "__main__":
    sys.exit(main())
