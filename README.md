# herdi

Mobile interface for [herdr](https://herdr.dev) AI coding agents. Monitor agent status, approve requests, and send responses from your phone.

## Architecture

```
┌─────────────┐     WebSocket      ┌───────────────┐     CLI      ┌───────┐
│  iOS App    │◄──────────────────►│ herdi-relay  │◄────────────►│ herdr │
│  (SwiftUI)  │     :8375          │  (Python)     │              │       │
└─────────────┘                    └───────────────┘              └───────┘
                                         ▲
                                         │ UDP :8376
                                   ┌─────┴─────┐
                                   │herdr plugin│
                                   └───────────┘
```

- **relay/** — Python daemon that polls herdr, accepts plugin events, and serves a WebSocket
- **herdi-ios/** — SwiftUI app that connects via Bonjour or manual IP

## Setup

### Relay (on your Mac)

```bash
cd relay
pip install -r requirements.txt
python3 herdi_relay.py

# Or install as herdr plugin for instant event push:
herdr plugin link .
```

### iOS App

Open `herdi-ios/` in Xcode or build with Swift Package Manager. Requires iOS 17+.

The app auto-discovers the relay via Bonjour (`_herdi._tcp`), or you can enter the IP manually in Settings.

## Features (MVP)

- Agent kanban board (Blocked → Working → Idle)
- Tap blocked agents to see approval prompt + option buttons
- Send responses back to the agent with one tap
- Auto-reconnect on network changes
- Bonjour service discovery

## LaunchAgent

To keep the relay running:

```bash
cp relay/com.herdi.relay.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.herdi.relay.plist
```
