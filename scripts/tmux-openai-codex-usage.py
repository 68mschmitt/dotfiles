#!/usr/bin/env python3
"""Read subscription limits without copying or rotating Codex's OAuth tokens."""

import json
import subprocess
import sys
import threading


class RpcError(Exception):
    pass


def read_usage(codex, timeout):
    process = subprocess.Popen(
        [codex, "app-server", "--listen", "stdio://"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    timer = threading.Timer(timeout, process.kill)
    timer.start()

    def send(message):
        process.stdin.write(json.dumps(message) + "\n")
        process.stdin.flush()

    def request(request_id, method, params=None):
        message = {"id": request_id, "method": method}
        if params is not None:
            message["params"] = params
        send(message)
        for line in process.stdout:
            response = json.loads(line)
            if response.get("id") != request_id:
                continue
            if "error" in response:
                raise RpcError(response["error"].get("message", ""))
            return response["result"]
        raise OSError("Codex exited or timed out")

    try:
        request(1, "initialize", {
            "clientInfo": {"name": "tmux_usage", "title": "Tmux Usage", "version": "1.0.0"},
        })
        send({"method": "initialized", "params": {}})
        result = request(2, "account/rateLimits/read")
        return result["rateLimits"]
    finally:
        timer.cancel()
        if process.poll() is None:
            process.terminate()
        try:
            process.wait(timeout=1)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        process.stdin.close()
        process.stdout.close()


def main():
    try:
        usage = read_usage(sys.argv[1], float(sys.argv[2]))
        print(json.dumps(usage))
        return 0
    except RpcError as error:
        message = str(error).lower()
        if "429" in message or "too many requests" in message:
            return 3
        if any(text in message for text in (
            "401", "403", "authentication required", "sign in", "login", "refresh token",
        )):
            return 2
        return 1
    except (OSError, ValueError, KeyError, TypeError):
        return 1


if __name__ == "__main__":
    sys.exit(main())
