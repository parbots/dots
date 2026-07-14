#!/usr/bin/env bash
set -euo pipefail

DOTS_DIR="${DOTS_DIR:-$HOME/dev/dots}"
SYNC_SCRIPT="$DOTS_DIR/scripts/sync.sh"
DEFAULT_INTERVAL=1800

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

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
    <string>$DOTS_STATE_DIR/launchd-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$DOTS_STATE_DIR/launchd-stderr.log</string>
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
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
SERVICE
}

generate_timer() {
    local interval="${1:-$DEFAULT_INTERVAL}"
    cat <<TIMER
[Unit]
Description=dots sync timer

[Timer]
OnBootSec=5min
OnUnitActiveSec=${interval}s
Unit=$SERVICE_NAME.service

[Install]
WantedBy=timers.target
TIMER
}

# parse_interval <arg> — accept seconds, Nm, or Nh; print seconds.
# Rejects non-numeric input and anything under 60 seconds.
parse_interval() {
    local arg=$1 seconds
    if [[ "$arg" =~ ^([0-9]+)h$ ]]; then
        seconds=$(( 10#${BASH_REMATCH[1]} * 3600 ))
    elif [[ "$arg" =~ ^([0-9]+)m$ ]]; then
        seconds=$(( 10#${BASH_REMATCH[1]} * 60 ))
    elif [[ "$arg" =~ ^[0-9]+$ ]]; then
        seconds=$(( 10#$arg ))
    else
        error "Invalid interval '$arg'. Use seconds, Nm, or Nh (e.g. 900, 15m, 1h)."
        return 1
    fi
    if (( seconds < 60 )); then
        error "Interval must be at least 60 seconds (got ${seconds}s)."
        return 1
    fi
    echo "$seconds"
}

cmd_enable() {
    local interval="${1:-$DEFAULT_INTERVAL}"
    if [[ "$OS" == "Darwin" ]]; then
        mkdir -p "$(dirname "$PLIST_PATH")"
        mkdir -p "$DOTS_STATE_DIR"
        generate_plist "$interval" > "$PLIST_PATH"
        launchctl unload "$PLIST_PATH" 2>/dev/null || true
        launchctl load "$PLIST_PATH"
        success "Scheduled sync enabled (launchd, every ${interval}s)."
    elif [[ "$OS" == "Linux" ]]; then
        mkdir -p "$SYSTEMD_DIR"
        mkdir -p "$DOTS_STATE_DIR"
        generate_service > "$SYSTEMD_DIR/$SERVICE_NAME.service"
        generate_timer "$interval" > "$SYSTEMD_DIR/$SERVICE_NAME.timer"
        systemctl --user daemon-reload
        systemctl --user enable --now "$SERVICE_NAME.timer"
        success "Scheduled sync enabled (systemd, every ${interval}s)."
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
            local baked
            # '|| true': sed exits 2 if the file is missing, and under pipefail
            # that would kill the script before the BROKEN branch can report it.
            baked=$(sed -n 's|.*<string>\(.*sync\.sh\)</string>.*|\1|p' "$PLIST_PATH" 2>/dev/null | head -1 || true)
            if [[ -z "$baked" || ! -f "$baked" ]]; then
                error "Scheduled sync: BROKEN — script path in $PLIST_PATH is missing (${baked:-unparseable})"
            else
                success "Scheduled sync: ACTIVE (launchd)"
                launchctl list "$PLIST_LABEL" 2>/dev/null | head -5
            fi
        else
            warn "Scheduled sync: INACTIVE"
        fi
    elif [[ "$OS" == "Linux" ]]; then
        if systemctl --user is-active "$SERVICE_NAME.timer" &>/dev/null; then
            local baked
            # '|| true': see the Darwin branch — a missing unit file must reach
            # the BROKEN report, not kill the script via pipefail.
            baked=$(sed -n 's/^ExecStart=//p' "$SYSTEMD_DIR/$SERVICE_NAME.service" 2>/dev/null | head -1 || true)
            if [[ -z "$baked" || ! -f "$baked" ]]; then
                error "Scheduled sync: BROKEN — script path in $SYSTEMD_DIR/$SERVICE_NAME.service is missing (${baked:-unparseable})"
            else
                success "Scheduled sync: ACTIVE (systemd)"
                systemctl --user status "$SERVICE_NAME.timer" --no-pager
            fi
        else
            warn "Scheduled sync: INACTIVE"
        fi
    else
        warn "Scheduled sync: unsupported OS"
    fi

    local LOG_FILE="$DOTS_SYNC_LOG"
    if [[ -f "$LOG_FILE" ]]; then
        info "Last sync:"
        tail -1 "$LOG_FILE"
    fi
}

case "${1:-}" in
    enable)
        INTERVAL="$DEFAULT_INTERVAL"
        if [[ -n "${2:-}" ]]; then
            INTERVAL="$(parse_interval "$2")" || exit 1
        fi
        cmd_enable "$INTERVAL"
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
        echo "                     interval: seconds, Nm for minutes, or Nh for hours (e.g., 15m, 1h)"
        echo "  disable            Disable scheduled sync"
        echo "  status             Show scheduler status and last sync"
        exit 1
        ;;
esac
