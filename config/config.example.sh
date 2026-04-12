#!/bin/bash
#=============================================================================
# Configuration file for zero-trust-lifestyle
# Copy this to config.sh and fill in your values
#=============================================================================

#-----------------------------------------------------------------------------
# General Settings
#-----------------------------------------------------------------------------

# Enable verbose logging (0=off, 1=on)
VERBOSE=0

# REQUIRED: strong secret used to derive the encryption key for data/.secrets.enc.
# Generate with: openssl rand -base64 48
# Losing this value means losing access to everything in data/.secrets.enc.
# Never commit the real value.
ENCRYPTION_PASSWORD=""

#-----------------------------------------------------------------------------
# Notification Settings
#-----------------------------------------------------------------------------

# Email alerts
ALERT_EMAIL=""

# Webhook for alerts (Slack, Discord, etc.)
ALERT_WEBHOOK=""

# Telegram alerts
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

#-----------------------------------------------------------------------------
# Meeting Prep Assassin
#-----------------------------------------------------------------------------

# LinkedIn API credentials
LINKEDIN_API_KEY=""

# GitHub Personal Access Token
GITHUB_TOKEN=""

# Twitter/X API Bearer Token
TWITTER_BEARER_TOKEN=""

# Google Calendar credentials path
GOOGLE_CALENDAR_CREDS="$HOME/.config/google-calendar-creds.json"

#-----------------------------------------------------------------------------
# Passive-Aggressive Emailer
#-----------------------------------------------------------------------------

# Anger delay in minutes
ANGER_DELAY_MINUTES=60

# Maximum acceptable anger score (0-100)
MAX_ANGER_SCORE=75

#-----------------------------------------------------------------------------
# Wife Happy Score
#-----------------------------------------------------------------------------

# Partner's name
PARTNER_NAME="Partner"

#-----------------------------------------------------------------------------
# Slack Settings
#-----------------------------------------------------------------------------

# Slack Bot Token (get from https://api.slack.com/tokens)
SLACK_TOKEN=""

# Slack Webhook URL (get from https://api.slack.com/messaging/webhooks)
# Alternative to bot token - simpler for posting messages
SLACK_WEBHOOK=""

# Slack channel for standup posts
SLACK_CHANNEL="#standup"

# Your Slack User ID (find with: https://api.slack.com/methods/users.identity/test)
SLACK_USER_ID=""

# Your Slack User TOKEN (for user-based actions)
SLACK_USER_TOKEN=""

#-----------------------------------------------------------------------------
# Slack Auto-Responder
#-----------------------------------------------------------------------------

# Enable/disable auto-respond (0=disabled, 1=enabled)
AUTO_RESPOND_ENABLED=1

# Only respond during office hours (0=always, 1=office hours only)
OFFICE_HOURS_ONLY=0

# Detect message urgency and respond faster (0=off, 1=on)
DETECT_URGENCY=1

# Detect if you're active and skip auto-respond (0=off, 1=on)
DETECT_ACTIVITY=1

#-----------------------------------------------------------------------------
# OPSEC Paranoia Check
#-----------------------------------------------------------------------------

# Check interval in seconds (for daemon mode)
OPSEC_CHECK_INTERVAL=900  # 15 minutes

# Send alert on failure
ALERT_ON_FAILURE=1

# Allowed DNS servers (comma-separated)
ALLOWED_DNS=("127.0.0.1" "10.0.0.1" "192.168.1.1")

#-----------------------------------------------------------------------------
# Automated Sock Maintenance
#-----------------------------------------------------------------------------

# Use headless browser (0=show browser, 1=headless)
HEADLESS=1

# Use proxies (0=no, 1=yes)
USE_PROXY=1

# Chrome driver path
CHROME_DRIVER="chromedriver"

#-----------------------------------------------------------------------------
# Coffee Shop Lockdown
#-----------------------------------------------------------------------------

# Kill sensitive apps on untrusted network
KILL_APPS=1

# Enforce VPN on untrusted network
ENABLE_VPN=1

# Block HTTP traffic
BLOCK_HTTP=1

# Clear clipboard
CLEAR_CLIPBOARD=1

# Lock password managers
LOCK_KEYRING=1

# Show warning screen
SHOW_WARNING=1

# OpenVPN config path (if using OpenVPN)
OPENVPN_CONFIG="$HOME/.config/openvpn/client.ovpn"

# WireGuard interface name
WG_INTERFACE="wg0"

#-----------------------------------------------------------------------------
# API Rate Limits
#-----------------------------------------------------------------------------

# Prevent API abuse
RATE_LIMIT_ENABLED=1

#-----------------------------------------------------------------------------
# Standup Bot
#-----------------------------------------------------------------------------

# Git repositories to scan for commits (comma-separated)
GIT_REPOS=""

# GitHub repository (owner/repo format)
GITHUB_REPO=""

# JIRA settings (optional)
JIRA_URL=""
JIRA_TOKEN=""

# Corporate speak level (0=off, 1=on)
CORPORATE_SPEAK=1

#-----------------------------------------------------------------------------
# Security Settings
#-----------------------------------------------------------------------------

# Store passwords encrypted
USE_ENCRYPTION=1

# Audit log all actions
AUDIT_LOG=1
AUDIT_LOG_FILE="$HOME/.local/share/security-scripts/audit.log"

#-----------------------------------------------------------------------------
# Export all variables
#-----------------------------------------------------------------------------
export VERBOSE
export ENCRYPTION_PASSWORD
export ALERT_EMAIL ALERT_WEBHOOK
export TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID
export LINKEDIN_API_KEY GITHUB_TOKEN TWITTER_BEARER_TOKEN
export GOOGLE_CALENDAR_CREDS
export ANGER_DELAY_MINUTES MAX_ANGER_SCORE
export PARTNER_NAME
export SLACK_TOKEN SLACK_WEBHOOK SLACK_CHANNEL SLACK_USER_ID SLACK_USER_TOKEN
export AUTO_RESPOND_ENABLED OFFICE_HOURS_ONLY DETECT_URGENCY DETECT_ACTIVITY
export OPSEC_CHECK_INTERVAL ALERT_ON_FAILURE
export ALLOWED_DNS
export HEADLESS USE_PROXY CHROME_DRIVER
export KILL_APPS ENABLE_VPN BLOCK_HTTP CLEAR_CLIPBOARD LOCK_KEYRING SHOW_WARNING
export OPENVPN_CONFIG WG_INTERFACE
export RATE_LIMIT_ENABLED
export USE_ENCRYPTION AUDIT_LOG AUDIT_LOG_FILE
export GIT_REPOS GITHUB_REPO JIRA_URL JIRA_TOKEN CORPORATE_SPEAK
