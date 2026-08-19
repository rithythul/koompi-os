#!/usr/bin/env python3
import socket
import sys
import time

def main():
    sock_path, key, tries, interval_s = sys.argv[1:5]
    tries = int(tries)
    interval_s = float(interval_s)

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
        print("could not connect to QEMU monitor socket", file=sys.stderr)
        return 1

    s.settimeout(2)
    try:
        s.recv(4096)
    except socket.timeout:
        pass

    for _ in range(tries):
        time.sleep(interval_s)
        s.sendall(("sendkey %s\n" % key).encode())
        try:
            s.recv(4096)
        except socket.timeout:
            pass
    s.close()
    return 0

if __name__ == "__main__":
    sys.exit(main())
