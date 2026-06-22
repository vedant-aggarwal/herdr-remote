#!/usr/bin/env python3
"""
Herdi Push — herdr plugin that pushes agent status to a remote herdi relay.

Install:
    herdr plugin install dcolinmorgan/herdi/herdr-plugin

Configure (set relay target):
    export HERDI_RELAY_HOST="ws://your-mac-ip:8375"
    # Or for LAN/Tailscale:
    export HERDI_RELAY_HOST="ws://100.120.17.59:8375"

The plugin pushes a JSON event over WebSocket on every agent status change.
Falls back to UDP localhost:8376 if WebSocket fails.
"""
import json, os, socket, subprocess, sys

event_raw = os.environ.get("HERDR_PLUGIN_EVENT_JSON", "{}")
# Config: relay host (WebSocket URL or just host:port for UDP)
RELAY_HOST = os.environ.get("HERDI_RELAY_HOST", "")
RELAY_UDP = os.environ.get("HERDI_RELAY_UDP", "127.0.0.1:8376")

try:
    event = json.loads(event_raw)
    data = event.get("data", {})
    hostname = socket.gethostname().split(".")[0]

    payload = json.dumps({
        "type": "agent_event",
        "pane_id": data.get("pane_id", ""),
        "status": (data.get("agent_status") or "").lower(),
        "agent": (data.get("agent") or data.get("display_agent") or "").lower(),
        "project": os.path.basename(data.get("cwd", "")),
        "cwd": data.get("cwd", ""),
        "host": hostname,
    })

    sent = False

    # Try WebSocket push (non-blocking, best-effort)
    if RELAY_HOST.startswith("ws"):
        try:
            # Use a quick subprocess to avoid needing websockets installed
            script = f'''
import asyncio, sys
try:
    import websockets
    async def push():
        async with websockets.connect("{RELAY_HOST}", open_timeout=3, close_timeout=1) as ws:
            await ws.send(sys.argv[1])
    asyncio.run(push())
except Exception:
    sys.exit(1)
'''
            result = subprocess.run(
                [sys.executable, "-c", script, payload],
                capture_output=True, timeout=5
            )
            sent = result.returncode == 0
        except Exception:
            pass

    # Fallback: UDP push (works for local relay or if configured)
    if not sent:
        try:
            host, port = RELAY_UDP.rsplit(":", 1)
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sock.sendto(payload.encode(), (host, int(port)))
            sock.close()
        except Exception:
            pass

except Exception:
    pass
