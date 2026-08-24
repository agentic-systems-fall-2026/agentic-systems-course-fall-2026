#!/usr/bin/env python3
"""
hang-server.py - a tiny, dependency-free endpoint for BC3 reliability testing.

Simulate the "bad day" your agent has to survive: an endpoint that hangs,
resets, stalls, or hands back junk. Point your agent's BASE url at it and
prove that your timeouts, retries, and JSON validation actually fire.

Modes
  hang     (default) accept the connection and never reply -> client read timeout
  reset    accept, then force a TCP reset (connection dropped mid-request)
  slow     reply, but only after --delay seconds (exercises your timeout)
  garbage  reply immediately with non-JSON junk (exercises fence-strip + fallback)

Usage
  python3 hang-server.py                       # hang on port 9099
  python3 hang-server.py --mode reset
  python3 hang-server.py --mode slow --delay 30
  python3 hang-server.py --mode garbage
  python3 hang-server.py --port 9099

Then, in another terminal, aim your agent at it, e.g.:
  BASE=http://127.0.0.1:9099 python3 fixed_agent.py

Binds to 127.0.0.1 only, so it is never exposed off-box. Stop it with Ctrl-C.
This is a testing aid, not part of the graded agent - keep your fix in
fixed_agent.py.
"""
import argparse
import socket
import struct
import threading
import time


def send_http(conn, status, ctype, body):
    reason = {200: "OK", 500: "Internal Server Error"}.get(status, "OK")
    head = (
        f"HTTP/1.1 {status} {reason}\r\n"
        f"Content-Type: {ctype}\r\n"
        f"Content-Length: {len(body)}\r\n"
        f"Connection: close\r\n\r\n"
    ).encode()
    conn.sendall(head + body)


def handle(conn, mode, delay):
    try:
        # Best-effort drain of the request so clients that write first don't stall.
        try:
            conn.setblocking(False)
            conn.recv(65535)
        except Exception:
            pass
        conn.setblocking(True)

        if mode == "hang":
            # Never respond. Hold the socket open until the client gives up.
            while True:
                time.sleep(3600)
        elif mode == "reset":
            # SO_LINGER with timeout 0 makes close() send a TCP RST, so the
            # client sees a connection reset rather than a graceful shutdown.
            conn.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER,
                            struct.pack("ii", 1, 0))
            conn.close()
            return
        elif mode == "slow":
            time.sleep(delay)
            send_http(conn, 200, "application/json",
                      b'{"verdict":"approved","risk":"low","note":"slow reply"}')
        elif mode == "garbage":
            send_http(conn, 200, "text/plain",
                      b'```json\n{ this is (not) valid JSON at all >>> \n``` trailing junk')
    except Exception:
        pass
    finally:
        try:
            conn.close()
        except Exception:
            pass


def main():
    ap = argparse.ArgumentParser(
        description="Local endpoint that misbehaves on purpose, for BC3 reliability tests.")
    ap.add_argument("--mode", choices=["hang", "reset", "slow", "garbage"],
                    default="hang", help="how the endpoint misbehaves (default: hang)")
    ap.add_argument("--port", type=int, default=9099, help="port to listen on (default: 9099)")
    ap.add_argument("--delay", type=float, default=30.0,
                    help="seconds to stall before replying, for --mode slow (default: 30)")
    ap.add_argument("--host", default="127.0.0.1",
                    help="bind address (default: 127.0.0.1, localhost only)")
    args = ap.parse_args()

    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((args.host, args.port))
    srv.listen(50)

    detail = f" (delay {args.delay:g}s)" if args.mode == "slow" else ""
    print(f"hang-server: mode={args.mode}{detail}  listening on http://{args.host}:{args.port}")
    print(f"point your agent at it, e.g.  BASE=http://{args.host}:{args.port} python3 fixed_agent.py")
    print("Ctrl-C to stop.")
    try:
        while True:
            conn, _ = srv.accept()
            threading.Thread(target=handle, args=(conn, args.mode, args.delay),
                             daemon=True).start()
    except KeyboardInterrupt:
        print("\nhang-server: stopped.")
    finally:
        srv.close()


if __name__ == "__main__":
    main()
