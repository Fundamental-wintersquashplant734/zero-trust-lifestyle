# Coffee Shop Lockdown

Automatic security lockdown for public WiFi environments. Monitors your network connection and enforces security measures when you're on an untrusted network.

## Overview

Detects when you connect to an unknown or public WiFi network and automatically enforces security measures: terminates sensitive applications, forces VPN connection, blocks HTTP traffic, clears the clipboard, and locks password managers. Deactivates automatically when you return to a trusted network.

## Features

- Automatic public WiFi detection
- Mandatory VPN enforcement
- HTTP traffic blocking via iptables
- Sensitive application termination
- Clipboard clearing
- Password manager locking (KeePassXC, 1Password, Bitwarden)
- GNOME keyring locking
- Desktop warning notifications
- Trusted network management

## Installation

```bash
chmod +x scripts/coffee-shop-lockdown.sh
```

## Dependencies

Required:
- `jq` - JSON processing

Optional:
- VPN client (NordVPN, OpenVPN, or WireGuard)
- `iptables` - HTTP traffic blocking (requires root)
- `xclip` or `wl-copy` - Clipboard clearing
- `zenity` - Desktop warning dialog (Linux)

## Quick Start

```bash
# Start network monitoring daemon
./scripts/coffee-shop-lockdown.sh monitor &

# Check current status
./scripts/coffee-shop-lockdown.sh status

# Trust current network
./scripts/coffee-shop-lockdown.sh trust
```

## Commands

### monitor

```bash
./scripts/coffee-shop-lockdown.sh monitor
```

Starts the network monitoring daemon. Checks the current WiFi network every 10 seconds. When a network change is detected:
- If the network is in the trusted list, deactivates any active lockdown
- If the network appears to be public, activates lockdown immediately
- If the network is unknown, prompts whether to trust it

Run in the background with `&` or configure as a systemd service.

### status

```bash
./scripts/coffee-shop-lockdown.sh status
```

Shows whether lockdown is currently active, the current network, and whether it is trusted.

### trust

```bash
./scripts/coffee-shop-lockdown.sh trust
```

Adds the currently connected network to the trusted list. Future connections to this network will not trigger lockdown.

### untrust

```bash
./scripts/coffee-shop-lockdown.sh untrust
```

Removes the currently connected network from the trusted list.

### list-trusted

```bash
./scripts/coffee-shop-lockdown.sh list-trusted
```

Displays all networks in the trusted list.

### test

```bash
./scripts/coffee-shop-lockdown.sh test
```

Runs the full lockdown sequence against the current network. Use with `DRY_RUN=1` to preview what would happen without applying changes:

```bash
DRY_RUN=1 ./scripts/coffee-shop-lockdown.sh test
```

## Options

These flags can be combined with any command to modify lockdown behavior:

| Flag | Description |
|------|-------------|
| `--no-vpn` | Don't enforce VPN on untrusted networks |
| `--no-kill-apps` | Don't terminate applications |
| `--no-http-block` | Don't block HTTP traffic |

## Lockdown Actions

When an untrusted network is detected, the following actions run in order:

1. **Kill sensitive apps** - Terminates Chrome, Firefox, Slack, Discord, Telegram, Signal, Thunderbird, Evolution, Teams, Zoom (and any custom apps in `$DATA_DIR/blocked_apps.txt`)
2. **Enable VPN** - Tries NordVPN, then OpenVPN, then WireGuard
3. **Block HTTP** - Adds iptables rule to reject port 80 traffic (requires root)
4. **Clear clipboard** - Wipes clipboard contents
5. **Lock password managers** - Locks KeePassXC, 1Password, Bitwarden, and GNOME keyring
6. **Show warning** - Displays terminal banner and desktop notification

## Configuration

Security behavior can be tuned via environment variables:

```bash
# Toggle individual lockdown actions
KILL_APPS=1
ENABLE_VPN=1
BLOCK_HTTP=1
CLEAR_CLIPBOARD=1
LOCK_KEYRING=1
SHOW_WARNING=1

# VPN configuration (for OpenVPN)
OPENVPN_CONFIG=~/.config/openvpn/client.ovpn

# WireGuard interface name
WG_INTERFACE=wg0

# Network check interval (seconds)
CHECK_INTERVAL=10
```

### Custom Blocked Apps

Add additional apps to terminate on lockdown:

```
$DATA_DIR/blocked_apps.txt
```

One process name per line. Lines starting with `#` are ignored.

## Trusted Networks

The trusted network list is stored at `$DATA_DIR/trusted_networks.txt`. Networks are identified by SSID and BSSID together, so a spoofed SSID with a different BSSID will not match.

```bash
# Trust current network
./scripts/coffee-shop-lockdown.sh trust

# See all trusted networks
./scripts/coffee-shop-lockdown.sh list-trusted

# Untrust current network
./scripts/coffee-shop-lockdown.sh untrust
```

## Auto-Start on Boot

### systemd

```bash
sudo systemctl enable coffee-shop-lockdown
```

### Autostart (desktop environments)

Create `~/.config/autostart/coffee-shop-lockdown.desktop` pointing to the monitor command.

## Example Session

```bash
$ ./scripts/coffee-shop-lockdown.sh monitor &

[INFO] Starting network monitoring daemon (interval: 10s)
[INFO] Network changed to: Starbucks WiFi
[WARN] PUBLIC NETWORK DETECTED: Starbucks WiFi
[WARN] Activating security lockdown for: Starbucks WiFi
[WARN] Killing sensitive applications...
[WARN] Killed apps: slack chrome
[INFO] Ensuring VPN is active...
[OK] VPN activated
[OK] HTTP traffic blocked
[OK] Clipboard cleared
[OK] Password managers locked

╔══════════════════════════════════════════════════════════════╗
║                    🚨 SECURITY LOCKDOWN 🚨                   ║
║         YOU ARE ON AN UNTRUSTED NETWORK                      ║
║         Network: Starbucks WiFi                              ║
║  DO NOT perform sensitive operations!                        ║
╚══════════════════════════════════════════════════════════════╝

$ ./scripts/coffee-shop-lockdown.sh status

🔒 LOCKDOWN ACTIVE
Current network: Starbucks WiFi|AA:BB:CC:DD:EE:FF
⚠ Untrusted network
```

## Troubleshooting

### VPN won't connect

- Check VPN credentials and configuration file paths
- Verify internet connectivity before VPN
- Check if the firewall is blocking VPN ports

### HTTP block requires root

The iptables rule requires root. Either run with `sudo` or use `--no-http-block` and rely on the VPN for traffic protection.

### Apps not being killed

- Check that the process name exactly matches the executable name
- Add custom app names to `$DATA_DIR/blocked_apps.txt`

### Trusted network keeps triggering lockdown

- The BSSID is included in network identification. If your router's MAC address changed, you'll need to re-trust the network.

## Data Location

```
$DATA_DIR/trusted_networks.txt    # Trusted network list
$DATA_DIR/.lockdown_state         # Current lockdown state
$DATA_DIR/blocked_apps.txt        # Custom apps to kill (optional)
$DATA_DIR/.iptables_backup        # Firewall backup (restored on deactivation)
```

## Related Scripts

- `opsec-paranoia-check.sh` - Overall OPSEC validation
- `git-secret-scanner.sh` - Prevent credential leaks
- `browser-history-cleanser.sh` - Clean sensitive data
