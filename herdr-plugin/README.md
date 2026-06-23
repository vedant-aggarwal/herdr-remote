# herdi-push — herdr plugin

Push agent status events from any herdr instance to a central herdi relay for monitoring.

## Install

```bash
herdr plugin install dcolinmorgan/herdr-push
```

Or link locally:
```bash
git clone https://github.com/dcolinmorgan/herdi
herdr plugin link herdi/herdr-plugin
```

## Configure

Set the relay target (your Mac's IP running herdi-relay):

```bash
# In your shell profile (~/.bashrc, ~/.zshrc):
export HERDI_RELAY_HOST="ws://100.120.17.59:8375"
```

For Tailscale users, use your Mac's Tailscale IP. Find it with `tailscale ip -4`.

## How it works

1. Every time an agent status changes (idle → working → blocked), herdr fires `pane.agent_status_changed`
2. This plugin pushes the event to your herdi relay over WebSocket
3. The relay broadcasts it to all connected clients (iOS app, Mac menu bar, TUI, Telegram bot)
4. Falls back to UDP localhost:8376 if WebSocket isn't available

## No polling needed

Unlike SSH-based monitoring, this is event-driven — status updates appear instantly on all your devices. The remote machine pushes to you; no inbound SSH required.
