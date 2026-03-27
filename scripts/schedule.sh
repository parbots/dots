#!/usr/bin/env bash
set -euo pipefail

DOTS_DIR="${DOTS_DIR:-$HOME/dev/dots}"
SYNC_SCRIPT="$DOTS_DIR/scripts/sync.sh"
DEFAULT_INTERVAL=1800

NC='\033[0m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'

info() { echo -e "${BLUE}$1${NC}"; }
success() { echo -e "${GREEN}$1${NC}"; }
error() { echo -e "${RED}$1${NC}" >&2; }
warn() { echo -e "${YELLOW}$1${NC}"; }

OS="$(uname -s)"

PLIST_LABEL="com.dots.sync"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"

generate_plist() {
    local interval="${1:-$DEFAULT_INTERVAL}"
    cat <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SYNC_SCRIPT</string>
    </array>
    <key>StartInterval</key>
    <integer>$interval</integer>
    <key>StandardOutPath</key>
    <string>$HOME/.local/state/dots/launchd-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/.local/state/dots/launchd-stderr.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    </dict>
</dict>
</plist>
PLIST
}

SYSTEMD_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="dots-sync"

generate_service() {
    cat <<SERVICE
[Unit]
Description=dots sync

[Service]
Type=oneshot
ExecStart=$SYNC_SCRIPT
Environment=PATH=/usr/local/bin:/usr/bin:/bin
SERVICE
}

generate_timer() {
    local interval="${1:-$DEFAULT_INTERVAL}"
    local minutes=$(( interval / 60 ))
    cat <<TIMER
[Unit]
Description=dots sync timer

[Timer]
OnBootSec=5min
OnUnitActiveSec=${minutes}min
Unit=$SERVICE_NAME.service

[Install]
WantedBy=timers.target
TIMER
}

cmd_enable() {
    local interval="${1:-$DEFAULT_INTERVAL}"
    if [[ "$OS" == "Darwin" ]]; then
        mkdir -p "$(dirname "$PLIST_PATH")"
        mkdir -p "$HOME/.local/state/dots"
        generate_plist "$interval" > "$PLIST_PATH"
        launchctl unload "$PLIST_PATH" 2>/dev/null || true
        launchctl load "$PLIST_PATH"
        success "Scheduled sync enabled (launchd, every $((interval / 60))m)."
    elif [[ "$OS" == "Linux" ]]; then
        mkdir -p "$SYSTEMD_DIR"
        mkdir -p "$HOME/.local/state/dots"
        generate_service > "$SYSTEMD_DIR/$SERVICE_NAME.service"
        generate_timer "$interval" > "$SYSTEMD_DIR/$SERVICE_NAME.timer"
        systemctl --user daemon-reload
        systemctl --user enable --now "$SERVICE_NAME.timer"
        success "Scheduled sync enabled (systemd, every $((interval / 60))m)."
    else
        error "Unsupported OS: $OS"
        exit 1
    fi
}

cmd_disable() {
    if [[ "$OS" == "Darwin" ]]; then
        if [[ -f "$PLIST_PATH" ]]; then
            launchctl unload "$PLIST_PATH" 2>/dev/null || true
            rm -f "$PLIST_PATH"
            success "Scheduled sync disabled (launchd)."
        else
            warn "Scheduled sync is not enabled."
        fi
    elif [[ "$OS" == "Linux" ]]; then
        if systemctl --user is-enabled "$SERVICE_NAME.timer" &>/dev/null; then
            systemctl --user disable --now "$SERVICE_NAME.timer"
            rm -f "$SYSTEMD_DIR/$SERVICE_NAME.service" "$SYSTEMD_DIR/$SERVICE_NAME.timer"
            systemctl --user daemon-reload
            success "Scheduled sync disabled (systemd)."
        else
            warn "Scheduled sync is not enabled."
        fi
    else
        error "Unsupported OS: $OS"
        exit 1
    fi
}

cmd_status() {
    if [[ "$OS" == "Darwin" ]]; then
        if launchctl list "$PLIST_LABEL" &>/dev/null; then
            success "Scheduled sync: ACTIVE (launchd)"
            launchctl list "$PLIST_LABEL" 2>/dev/null | head -5
        else
            warn "Scheduled sync: INACTIVE"
        fi
    elif [[ "$OS" == "Linux" ]]; then
        if systemctl --user is-active "$SERVICE_NAME.timer" &>/dev/null; then
            success "Scheduled sync: ACTIVE (systemd)"
            systemctl --user status "$SERVICE_NAME.timer" --no-pager
        else
            warn "Scheduled sync: INACTIVE"
        fi
    else
        warn "Scheduled sync: unsupported OS"
    fi

    local LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/dots/sync.log"
    if [[ -f "$LOG_FILE" ]]; then
        info "Last sync:"
        tail -1 "$LOG_FILE"
    fi
}

case "${1:-}" in
    enable)
        if [[ -n "${2:-}" ]]; then
            ARG="$2"
            if [[ "$ARG" == *m ]]; then
                INTERVAL=$(( ${ARG%m} * 60 ))
            else
                INTERVAL="$ARG"
            fi
            cmd_enable "$INTERVAL"
        else
            cmd_enable
        fi
        ;;
    disable)
        cmd_disable
        ;;
    status)
        cmd_status
        ;;
    *)
        echo "Usage: schedule.sh {enable [interval]|disable|status}"
        echo ""
        echo "  enable [interval]  Enable scheduled sync (default: 30m)"
        echo "                     interval: seconds, or Nm for minutes (e.g., 15m)"
        echo "  disable            Disable scheduled sync"
        echo "  status             Show scheduler status and last sync"
        exit 1
        ;;
esac
