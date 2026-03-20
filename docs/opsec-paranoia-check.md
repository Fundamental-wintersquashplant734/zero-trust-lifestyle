# OPSEC Paranoia Check

Comprehensive operational security validation for security researchers. Ensures VPN, DNS, webcam, microphone, and all security measures are properly configured.

## Overview

Runs a full OPSEC audit and optionally monitors continuously in the background. Checks VPN status, DNS configuration, webcam/microphone access, clipboard content, file metadata, Tor usage, running processes, and network connections. Alerts immediately if any security measure fails.

## Features

- VPN status and kill switch verification
- DNS leak detection
- Webcam and microphone monitoring
- Clipboard content scanning
- File metadata checks
- Tor browser validation
- Suspicious process detection
- Network connection monitoring
- Automated alerts on failures
- Continuous background monitoring via daemon mode

## Installation

```bash
chmod +x scripts/opsec-paranoia-check.sh
```

## Dependencies

Required:
- `ip` or `ifconfig` - Network interfaces
- `jq` - JSON processing

Optional:
- `iptables` - Firewall rules (Linux)
- `lsof` - Webcam detection (Linux)
- `lsusb` - USB webcam detection (Linux)
- `pactl` - Microphone detection (Linux)
- `exiftool` - File metadata checks
- `torsocks` - Tor connectivity test

## Quick Start

```bash
# Run all checks once
./scripts/opsec-paranoia-check.sh

# Quick check (VPN + DNS only)
./scripts/opsec-paranoia-check.sh --quick

# Run as background daemon
./scripts/opsec-paranoia-check.sh --daemon &
```

## Usage

### Run All Checks

```bash
./scripts/opsec-paranoia-check.sh
```

Runs comprehensive OPSEC validation across all categories and prints a summary.

### Quick Check

```bash
./scripts/opsec-paranoia-check.sh --quick
```

Runs only the critical checks: VPN and DNS. Skips webcam, microphone, clipboard, metadata, processes, and network checks. Ideal for crontab.

### Daemon Mode

```bash
./scripts/opsec-paranoia-check.sh --daemon &
```

Runs checks continuously in a loop, sleeping for `OPSEC_CHECK_INTERVAL` seconds (default: 15 minutes) between runs. Sends an alert if any check fails.

### Verbose Output

```bash
./scripts/opsec-paranoia-check.sh --verbose
```

Enables debug-level logging for detailed output during each check.

## Options

| Flag | Short | Description |
|------|-------|-------------|
| `--daemon` | `-d` | Run as background monitoring daemon |
| `--quick` | `-q` | Quick check (VPN + DNS only) |
| `--verbose` | `-v` | Verbose output |
| `--help` | `-h` | Show help |

## Checks Performed

### 1. VPN Status

Validates:
- VPN connection is active
- VPN interface exists (tun0, tap0, wg0, utun)
- Kill switch is configured via iptables

**Alerts if:**
- VPN is down
- Kill switch not configured

### 2. DNS Configuration

Validates:
- DNS servers are in the allowed list (`ALLOWED_DNS`)
- No DNS leak via external test

**Alerts if:**
- Untrusted DNS server detected
- DNS leak detected

### 3. Webcam Monitoring

Validates:
- No process is actively accessing `/dev/video*`

**Warns if:**
- Webcam is actively in use

### 4. Microphone Monitoring

Validates:
- No PulseAudio/PipeWire source is in RUNNING state

**Warns if:**
- Microphone is actively in use

### 5. Clipboard Content

Validates:
- Clipboard does not contain API keys, private keys, passwords, email addresses, or credit card numbers

**Warns if:**
- Sensitive data patterns detected in clipboard

### 6. File Metadata

Validates:
- Images modified in the last 24 hours have no GPS EXIF data
- PDFs modified in the last 24 hours have no Author metadata

**Alerts if:**
- GPS or author metadata found in recent files

### 7. Tor Status

Validates:
- Tor daemon (`tor`) is running
- Tor connectivity works via torsocks

**Info only** - Does not fail the overall check if Tor is not running

### 8. Process Monitoring

Validates:
- No known interception tools running (keyloggers, wireshark, tcpdump, ettercap, burpsuite, mitmproxy)

**Warns if:**
- Any of the above processes detected (make sure they are yours)

### 9. Network Connections

Validates:
- No suspicious ports listening (4444 Metasploit, 5555 ADB, 6666 IRC/malware, 31337 Back Orifice)
- Public IP has not changed from the last recorded VPN IP

**Alerts if:**
- Suspicious port detected
- Public IP unexpectedly changed

## Configuration

Edit check intervals and thresholds in the script or via environment variables:

```bash
# Check interval for daemon mode (seconds)
OPSEC_CHECK_INTERVAL=900  # 15 minutes default

# Send alert on failure
ALERT_ON_FAILURE=1

# Individual check toggles (set to 0 to disable)
CHECK_VPN=1
CHECK_DNS=1
CHECK_WEBCAM=1
CHECK_MICROPHONE=1
CHECK_CLIPBOARD=1
CHECK_METADATA=1
CHECK_TOR=1
CHECK_PROCESSES=1
CHECK_NETWORK=1
```

### Allowed DNS Servers

Edit in the script:
```bash
ALLOWED_DNS=("127.0.0.1" "10.0.0.1")
```

Add your VPN's DNS server to this list.

## Example Output

```
╔════════════════════════════════════════╗
║       OPSEC PARANOIA CHECK            ║
╚════════════════════════════════════════╝

[INFO] Checking VPN status...
[OK] VPN is active
[INFO] Checking VPN kill switch...
[WARN] No kill switch detected - traffic may leak if VPN drops

[INFO] Checking DNS configuration...
[WARN] Untrusted DNS server detected: 8.8.8.8
[ERROR] DNS leak potential detected!

[INFO] Checking webcam status...
[OK] No webcam activity detected

[INFO] Checking clipboard for sensitive data...
[WARN] Sensitive data in clipboard:
  📧 Email address in clipboard

═══════════════════════════════════════
SUMMARY:
  Total checks: 9
  Passed: 6
  Failed: 3

Failed checks: VPN DNS Clipboard
```

## Recommended Setup

```bash
# Add to crontab for periodic quick checks
*/15 * * * * /path/to/opsec-paranoia-check.sh --quick

# Start daemon at login
/path/to/opsec-paranoia-check.sh --daemon &
```

## Best Practices

1. **Run on startup**
   - Validates OPSEC before you start work
   - Catches configuration drift

2. **Enable daemon mode**
   - Continuous validation
   - Immediate alerts

3. **Customize allowed DNS**
   - Add your VPN's DNS servers
   - Remove public DNS if not needed

4. **Check before sensitive work**
   - Run manual check before each session
   - Use `--quick` for fast validation

## Common Issues

### VPN Not Detected

- Verify VPN is actually connected
- Check the VPN interface name (tun0, wg0, etc.)
- Update `REQUIRED_VPNS` in the script

### DNS False Positives

- Add your VPN DNS to `ALLOWED_DNS`
- Some VPNs use public DNS intentionally

### Webcam Alerts During Calls

- Normal during video calls
- Check which process is accessing the camera

### Clipboard Warnings

- Clear clipboard regularly
- Use a password manager instead of copy/paste

## Data Location

```
$DATA_DIR/.vpn_ip    # Saved public IP for change detection
```

## Security Considerations

This script helps validate OPSEC but:
- Not a complete security solution
- Manual verification still needed
- Can't detect all threats
- Assumes you trust the check results

## Related Scripts

- `coffee-shop-lockdown.sh` - Public WiFi security
- `git-secret-scanner.sh` - Prevent secret leaks
- `browser-history-cleanser.sh` - Clean browsing data
