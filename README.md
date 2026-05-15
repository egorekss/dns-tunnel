# DNS Tunnel

Native macOS client for **iodine** DNS-over-IP tunnel. A polished, Streisand-style app that lets you tunnel all your traffic through DNS queries — useful in restrictive networks (hotels, airports, captive portals, corporate DPI) where regular VPN is blocked but DNS still works.

![Status: alpha](https://img.shields.io/badge/status-alpha-orange) ![Platform: macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![License: MIT](https://img.shields.io/badge/license-MIT-green)

## Features

- **Native SwiftUI app** — no Electron, no Java, ~1.6 MB
- **Multiple server profiles** — switch between your servers
- **One-click connect/disconnect** — big green/red button
- **Smart VPN conflict resolution** — auto-detects and disconnects active Streisand / IKEv2 / OpenVPN / WireGuard / sing-box / v2ray / Outline / Tunnelblick before establishing the tunnel
- **Lives in menu bar AND Dock** — toggle Dock visibility in settings
- **Localized** — English and Russian, auto-selects from system language
- **Universal binary** — runs natively on Apple Silicon (arm64) and Intel (x86_64)
- **No analytics, no telemetry** — your config never leaves your Mac
- **Universal client** — works with any iodine server, configure your own from the UI

## Screenshots

> _Add screenshots after building_

## How it works

```
[Your Mac] ─── DNS query (encoded data) ───┐
   │                                        │
   │                                        ▼
   │                              [Local resolver / 8.8.8.8]
   │                                        │
   │                                        ▼
   │                              [Root → .ru → reg.ru]
   │                                        │
   │                                        ▼
   │                          [your VPS, port 53/UDP, iodined]
   │                                        │
   ◀─── DNS reply (TXT/NULL with payload) ──┘
```

When you connect, the app:

1. Detects any active VPN (so it doesn't conflict)
2. Stops them automatically (optional, configurable)
3. Pins a route to the iodine server through your real gateway (so the tunnel doesn't eat itself)
4. Starts `iodined` client in the background
5. Switches default route to the tunnel `utun` interface
6. Sets DNS to public resolvers (so DNS queries don't loop through the tunnel)

On disconnect, everything is restored to the original state.

## Installation

### Prerequisites

- macOS 13 (Ventura) or later
- [Homebrew](https://brew.sh) for installing the iodine binary
- A configured iodine server (see [Server setup](docs/server-setup.md))

### Quick install (binary, recommended)

> Once we publish releases — until then, build from source.

```bash
brew install iodine
# Download DNS-Tunnel.app from Releases page
# Drag to /Applications
# Run install-helper.sh once (it will prompt for sudo password)
```

### Build from source

Requires Xcode Command Line Tools (no full Xcode IDE needed):

```bash
xcode-select --install   # if not already installed
git clone https://github.com/egorekss/dns-tunnel.git
cd dns-tunnel
brew install iodine
./Scripts/build.sh                   # builds universal binary (arm64 + x86_64)
./Scripts/install-helper.sh          # one-time, requires sudo password
cp -R Build/DNS\ Tunnel.app /Applications/
open /Applications/DNS\ Tunnel.app
```

By default the build is universal (works on Apple Silicon + Intel). To build native-only and skip the lipo step:

```bash
BUILD_ARCH=arm64 ./Scripts/build.sh   # or x86_64
```

The app opens with an empty server list — fill in the parameters of your iodine server in the **Servers** tab.

### Localization

The app auto-selects English or Russian based on system language. To force a specific language:

```bash
defaults write com.dnstunnel.app AppleLanguages -array "en"   # English
defaults write com.dnstunnel.app AppleLanguages -array "ru"   # Russian
defaults delete com.dnstunnel.app AppleLanguages              # back to system default
```

To add a new language: copy `Resources/en.lproj/Localizable.strings` to `Resources/<lang>.lproj/Localizable.strings`, translate the values, add `<lang>` to `CFBundleLocalizations` in `Info.plist`, rebuild.

## Server setup

You need an Ubuntu/Debian VPS, a domain you control, and ~10 minutes. Full guide:
**[docs/server-setup.md](docs/server-setup.md)**

## Configuration

After first launch, click the **Servers** tab → **+ Add** and fill in:

| Field | Description | Example |
|---|---|---|
| Name | Any label for the server | `Home VPS` |
| Tunnel domain | Subdomain delegated via NS to your VPS | `t.example.com` |
| Password | The password set in `iodined -P` | `your-secret-password` |
| Server IP | Public IPv4 of the VPS (used for pin route) | `1.2.3.4` |

## Architecture

```
DNSTunnelApp/
├── Sources/
│   ├── Models.swift           # ServerConfig, ServerStore, AppSettings (UserDefaults)
│   ├── HelperRunner.swift     # Launches privileged helper via osascript
│   ├── VPNDetector.swift      # Detects/stops conflicting VPNs
│   ├── TunnelManager.swift    # State machine, ObservableObject
│   ├── MenuBarController.swift# NSStatusItem
│   ├── main.swift             # App entry, NSApplicationDelegate, window mgmt
│   └── Views/                 # SwiftUI: Status, Servers, Settings, About
├── Resources/
│   ├── Info.plist
│   └── proxy-tunnel.sh        # Privileged helper (route, NAT, DNS, iodine lifecycle)
├── Scripts/
│   ├── build.sh               # swiftc + bundle assembly
│   ├── install-helper.sh      # Installs proxy-tunnel.sh to /usr/local/bin (sudo)
│   └── make-icon.sh           # Generates AppIcon.icns programmatically
└── docs/
    └── server-setup.md        # iodine on Ubuntu, NS delegation, systemd
```

### Why a privileged helper?

iodine needs root to create `utun` interfaces and modify routing tables. Instead of running the whole app as root (terrible), we install a small bash helper at `/usr/local/bin/proxy-tunnel.sh` that's owned by root and has a strict CLI: `connect`, `disconnect`, `status`, `kill-vpns`. The app calls it via `osascript "do shell script ... with administrator privileges"`, which prompts the user for password through the standard macOS authorization dialog.

This is the same model used by Tunnelblick, Mullvad, and most other Mac VPN clients pre-`SMAppService`.

## Limitations / known issues

- **iodine is detectable by DPI.** It uses base32-encoded DNS labels which look nothing like normal DNS traffic. Modern DPI in restrictive countries flags it. iodine helps in *captive portal* / *open DNS* scenarios, **not** in heavy-DPI environments.
- **Speed is low.** Realistic 50–680 Kbps on UDP, lower on TCP/TXT-only. This is a "get something working when nothing else does" tool, not a daily driver.
- **iOS not supported** — Apple's NetworkExtension restrictions and the lack of an iodine port mean DNS tunneling on iPhone is essentially impossible without a paid Apple Developer account and a custom-built app.
- **App is not notarized.** Right-click → Open on first launch to bypass Gatekeeper warning.

## Donate

If this saved you in a hotel or airport, a coffee is appreciated:

**USDT (TRC20 / TRON):**
```
THMomvCtsbthM4hoZSW4AyvSbyn5wc6WUt
```

(There's also a QR code in the **About** tab of the app.)

## License

MIT — see [LICENSE](LICENSE).

## Credits

- [iodine](https://code.kryo.se/iodine/) by Erik Ekman & Bjorn Andersson — the actual tunneling protocol & client/server
- This app is just a UI wrapper around it
