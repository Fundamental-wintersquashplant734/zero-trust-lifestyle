# Definitely Working

Anti-AFK script that keeps your computer active and shows you as "online" in chat applications. Simulates mouse activity to prevent screen lock and away status.

## Overview

Prevents idle detection by simulating mouse movements and optionally clicks or keypresses. Runs until stopped (or until an optional duration expires). Supports subtle small movements from the current position or large random movements across the screen. Uses randomized delays between each action to avoid obvious patterns.

## Features

- Subtle mouse jiggler (small movements from current position)
- Optional large random mouse movements
- Optional random left-clicks
- Optional Shift key simulation
- Configurable delay range between actions
- Optional timed duration

## Installation

```bash
chmod +x scripts/definitely-working.sh
```

## Dependencies

Required:
- `xdotool` - Mouse/keyboard simulation (Linux/X11)

```bash
sudo apt install xdotool
```

## Quick Start

```bash
# Run indefinitely with subtle movements (default)
./scripts/definitely-working.sh

# Run for 1 hour (3600 seconds)
./scripts/definitely-working.sh 3600

# Run in the background
./scripts/definitely-working.sh &

# Kill it later
pkill -f definitely-working
```

## Usage

```
Usage: definitely-working.sh [OPTIONS] [DURATION]
```

If `DURATION` (in seconds) is provided, the script stops automatically after that time. If omitted, it runs indefinitely until interrupted with Ctrl+C.

## Options

| Flag | Description |
|------|-------------|
| `--subtle` | Small movements from current position (default) |
| `--obvious` | Large random movements across the full screen |
| `--with-clicks` | Occasionally left-click (5% chance per action - use carefully!) |
| `--with-keyboard` | Occasionally press Shift key (5% chance per action) |
| `--delay MIN MAX` | Set delay range in seconds between actions (default: 5-120) |
| `-h, --help` | Show help |

## Examples

```bash
# Run indefinitely with subtle movements
./scripts/definitely-working.sh

# Run for 2 hours with obvious movements
./scripts/definitely-working.sh --obvious 7200

# Run for 30 minutes during a meeting with keyboard activity
./scripts/definitely-working.sh --with-keyboard 1800

# Run with a faster interval (every 10-30 seconds)
./scripts/definitely-working.sh --delay 10 30

# Run for exactly 1 hour, subtle, with clicks (careful!)
./scripts/definitely-working.sh --subtle --with-clicks 3600
```

## Activity Modes

### Subtle (default)

```bash
./scripts/definitely-working.sh --subtle
```

Moves the mouse a small random amount (up to ±25 pixels) from its **current position**. Stays within screen bounds. Effectively invisible to an observer and won't disrupt active work.

### Obvious

```bash
./scripts/definitely-working.sh --obvious
```

Moves the mouse to a fully random position anywhere on the screen. More noticeable. Useful when subtle movements aren't enough to prevent idle detection.

### With Clicks

```bash
./scripts/definitely-working.sh --with-clicks
```

Adds a 5% chance of a left-click on each activity cycle. **Use with caution** - clicks can interact with whatever is under the cursor.

### With Keyboard

```bash
./scripts/definitely-working.sh --with-keyboard
```

Adds a 5% chance of pressing the Shift key on each activity cycle. Shift is a safe key that doesn't produce visible text output.

## Delay Configuration

The script waits a random number of seconds between each action. The range is configurable:

```bash
# Default: random delay between 5 and 120 seconds
./scripts/definitely-working.sh

# Faster: every 10-30 seconds
./scripts/definitely-working.sh --delay 10 30

# Slower: every 2-5 minutes
./scripts/definitely-working.sh --delay 120 300
```

## Use Cases

- Prevent screen lock during long downloads or builds
- Stay "active" during video or audio-only playback
- Prevent away status during hands-free monitoring
- Keep remote desktop connections alive
- Maintain VPN session during passive tasks

## Tips

- Use `--subtle` for less noticeable activity (default)
- Don't use `--with-clicks` on windows where accidental clicks matter
- Run in background: `./scripts/definitely-working.sh &`
- Kill background instance: `pkill -f definitely-working`
- Combine with a duration to auto-stop: `./scripts/definitely-working.sh 3600`

## Warnings

### Ethical Use

Only use for legitimate purposes:
- Actually working but not at keyboard
- Passive monitoring tasks
- Long-running processes
- Technical constraints

**Do NOT use to:**
- Fake attendance
- Deceive employer
- Circumvent monitoring for fraud

### Detection Risks

- Advanced monitoring may detect regular patterns
- Use `--delay` with a wide range for less predictability
- Be honest if asked about your activity

### Company Policies

- Check company policy first
- May violate monitoring policies
- Use at your own risk

## Troubleshooting

### Not Preventing Screen Lock

- Verify `xdotool` is installed and working: `xdotool getmouselocation`
- Check that X display is accessible (`DISPLAY` env var set)
- Try `--obvious` mode for more aggressive movement

### Mouse Not Moving

- Confirm the script is running: `pgrep -f definitely-working`
- Try running in foreground to see log output
- Check for `xdotool` errors

### Movements Visible to Others

- Use `--subtle` (default) for minimal movement
- Reduce `MOVEMENT_RANGE` in the script (default: 50px)
- Increase the delay range to reduce frequency

## Related Scripts

- `slack-auto-responder.sh` - Auto-respond to messages
- `meeting-excuse-generator.sh` - Decline meetings
- `focus-mode-nuclear.sh` - Prevent distractions
