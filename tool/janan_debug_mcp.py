#!/usr/bin/env python3
"""MCP bridge to the Janan debug data server.

The app listens on 127.0.0.1:8765 only while Settings → Debug data server is on.
This process forwards that port from a device and speaks MCP over stdin.
"""

import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

PORT = 8765
HOST = "127.0.0.1"

TOOLS = [
    {
        "name": "debug_server_status",
        "description": "Check that the Janan debug data server is on and reachable.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "seed_reminder_rings",
        "description": (
            "Replace Test medicines with four doses: one overdue by 8 minutes, "
            "two due in 45 minutes (dotted ring), and one due in 3 hours. "
            "Turns medicine reminders and stacked rings on. The app must be open."
        ),
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "seed_sample_history",
        "description": (
            "Add two weeks of blood pressure readings, weigh-ins, and medicine "
            "logs. Medicine logs are on earlier days so today's open reminders "
            "stay open. The app must be open with the debug data server on."
        ),
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "clear_test_medicines",
        "description": "Remove medicines whose names start with 'Test ' and their schedules.",
        "inputSchema": {"type": "object", "properties": {}},
    },
]


def send(message):
    sys.stdout.write(json.dumps(message, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def adb_base():
    serial = os.environ.get("ANDROID_SERIAL", "").strip()
    command = ["adb"]
    if serial:
        command.extend(["-s", serial])
    return command


def forward_port():
    subprocess.run(
        adb_base() + ["forward", f"tcp:{PORT}", f"tcp:{PORT}"],
        check=False,
        capture_output=True,
        text=True,
    )


def request(path, body=None):
    forward_port()
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(
        f"http://{HOST}:{PORT}{path}",
        data=data,
        method="GET" if body is None else "POST",
    )
    if body is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=8) as response:
            return json.load(response)
    except urllib.error.URLError as error:
        return {
            "ok": False,
            "error": str(error.reason if hasattr(error, "reason") else error),
            "hint": (
                "Open the debug app and turn on Settings → Debug data server. "
                "The switch exists only in debug builds."
            ),
        }
    except Exception as error:
        return {"ok": False, "error": str(error)}


def tool_result(payload):
    return {
        "content": [{"type": "text", "text": json.dumps(payload, indent=2)}],
        "isError": not payload.get("ok", False),
    }


def call_tool(name):
    if name == "debug_server_status":
        return tool_result(request("/health"))
    if name == "seed_reminder_rings":
        return tool_result(request("/seed", {"scenario": "reminder_rings"}))
    if name == "seed_sample_history":
        return tool_result(request("/seed", {"scenario": "history"}))
    if name == "clear_test_medicines":
        return tool_result(request("/clear", {}))
    return tool_result({"ok": False, "error": f"Unknown tool {name}"})


def handle(message):
    method = message.get("method")
    message_id = message.get("id")
    if method == "initialize":
        send(
            {
                "jsonrpc": "2.0",
                "id": message_id,
                "result": {
                    "protocolVersion": message.get("params", {}).get(
                        "protocolVersion", "2024-11-05"
                    ),
                    "capabilities": {"tools": {}},
                    "serverInfo": {"name": "janan-debug", "version": "1.0.0"},
                },
            }
        )
        return
    if method == "tools/list":
        send({"jsonrpc": "2.0", "id": message_id, "result": {"tools": TOOLS}})
        return
    if method == "tools/call":
        name = message.get("params", {}).get("name", "")
        send({"jsonrpc": "2.0", "id": message_id, "result": call_tool(name)})
        return
    if method == "ping":
        send({"jsonrpc": "2.0", "id": message_id, "result": {}})
        return
    if message_id is not None:
        send(
            {
                "jsonrpc": "2.0",
                "id": message_id,
                "error": {"code": -32601, "message": f"Method not found: {method}"},
            }
        )


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line or line.lower().startswith("content-length"):
            continue
        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(message, dict):
            handle(message)


if __name__ == "__main__":
    main()
