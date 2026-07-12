# Customizing this fork

This is your fork. `origin` is yours; `upstream` is dcolinmorgan's. Pull his fixes with
`git fetch upstream && git merge upstream/main`.

## Run it

```powershell
.\relay\start.ps1
```

Then open **https://alter-101-1.tail50de13.ts.net:8443** on any device with Tailscale on.

The relay binds `127.0.0.1` only — `tailscale serve` is the single way in, so nothing is
exposed to your LAN or the internet. Anyone who can reach that URL can type arbitrary
commands into a shell on this PC. That's the whole point of the tool, and it's why it
lives on the tailnet and nowhere else.

## The edit loop

`start.ps1` sets `HERDR_DEV=1`, so the relay watches `web/` and pushes `{"type":"reload"}`
over the WebSocket when a file changes.

**Edit `web/index.html` → save → every connected client refreshes itself.** No build step,
no bundler, no deploy. The relay reads the file from disk on every request.

`web/index.html` is one file: ~130 lines of CSS, some markup, ~200 lines of vanilla JS.
That's the entire frontend.

## Adding a feature

The backend is a message-type switch in `handle_client` (`relay/herdr_relay.py`), and
`run_herdr()` can call **any** herdr CLI command — `workspace`, `tab`, `pane split`,
`agent`, `worktree`, `wait`, `notification`. So a feature is one `elif` plus some HTML.

### Worked example: launch an agent in any directory from your phone

**1. Backend** — add to the switch in `handle_client`:

```python
elif msg_type == "spawn":
    out = run_herdr("workspace", "create", "--cwd", msg["cwd"], "--no-focus")
    pane = json.loads(out)["result"]["root_pane"]["pane_id"]
    run_herdr("pane", "run", pane, msg.get("agent", "claude"))
    await ws.send(json.dumps({"type": "spawned", "pane_id": pane}))
```

**2. Frontend** — add to `web/index.html`:

```html
<div class="setting-group">
  <label>Launch agent in directory</label>
  <input id="spawnCwd" placeholder="C:\Users\VEDANT\my-project" />
  <button onclick="spawn()">Launch</button>
</div>
```

```js
function spawn() {
  const cwd = document.getElementById('spawnCwd').value.trim();
  if (!cwd || !ws) return;
  ws.send(JSON.stringify({ type: 'spawn', cwd, agent: 'claude' }));
}
```

Save. Your phone reloads. The button is there.

Handle the `spawned` reply in `handleMessage()` if you want to jump straight into the new
pane's terminal view.

## Windows fixes carried in this fork

Upstream targets macOS/Linux. These are the changes that make it run here — worth knowing
if you ever merge upstream and something breaks:

- **`run_herdr()` decodes UTF-8 explicitly.** `subprocess(text=True)` uses the locale codec,
  which is cp1252 on Windows and raises on the box-drawing glyphs `pane read` emits. The
  exception was being swallowed by a bare `except`, so panes silently read back **empty**.
- **`raw_pane_read()` falls back to `--source visible`.** `--source recent` is *scrollback*;
  a pane that hasn't scrolled yet reads back empty, so fresh panes appeared blank.
- **Signal handling falls back to `signal.signal()`.** Windows' asyncio loop has no
  `add_signal_handler` — upstream crashes on startup.
- **`HERDR` resolves via `shutil.which`** instead of a hardcoded `/opt/homebrew` path.
- **Binds `127.0.0.1`**, not `0.0.0.0`.
- **`relay/start.ps1`** replaces `start.sh` (bash + `lsof` + `cloudflared`).

## Knobs

| Env var | Default | Meaning |
|---|---|---|
| `HERDR_DEV` | unset | `1` = watch `web/` and hot-reload clients |
| `HERDR_WEB_DIR` | `../web` | which directory to serve |
| `HERDR_RELAY_HOST` | `127.0.0.1` | bind address |
| `HERDR_RELAY_PORT` | `8375` | relay port |
| `HERDR_RELAY_TOKEN` | unset | shared secret; clients append `?token=` |
| `HERDR_REMOTES` | unset | comma-separated SSH targets to also poll |

`HERDR_REMOTES` is how you'd add your VPS (`srv1743044`) later — the relay would poll herdr
there over SSH and its agents would show up alongside the local ones.
