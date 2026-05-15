#!/bin/bash

# --- PATH VARIABLES (Can be adjusted for your system) ---
# Project source directory (auto-detects script location)
REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Installation destinations
BIN_DEST="/usr/local/bin"
CONF_DEST="/etc/watchdog"
SERVICE_DEST="/etc/systemd/system"
LOG_DEST="/var/log"

# File names
SCRIPT_NAME="watchdog.sh"
CONF_NAME="watchdog.conf"
SERVICE_NAME="watchdog.service"

# --- CHECKS ---
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root (use sudo)"
   exit 1
fi

# Check if source files exist before copying
for file in "$SCRIPT_NAME" "$CONF_NAME" "$SERVICE_NAME"; do
    if [ ! -f "$REPO_DIR/$file" ]; then
        echo "Error: Source file $REPO_DIR/$file not found!"
        exit 1
    fi
done

echo "Starting installation of Process Watchdog..."

# 1. Create directory structure and logs
mkdir -p "$CONF_DEST"
touch "$LOG_DEST/watchdog.log"
touch "$LOG_DEST/watchdog_alerts.log"

# 2. Copy files
echo "Copying files from $REPO_DIR..."
cp "$REPO_DIR/$SCRIPT_NAME" "$BIN_DEST/"
cp "$REPO_DIR/$CONF_NAME" "$CONF_DEST/"
cp "$REPO_DIR/$SERVICE_NAME" "$SERVICE_DEST/"

# 3. Set permissions
chmod +x "$BIN_DEST/$SCRIPT_NAME"

# 4. Register in Systemd
echo "Registering systemd service..."
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

echo "------------------------------------------------"
echo "Installation Complete!"
echo "Configuration: $CONF_DEST/$CONF_NAME"
echo "Log file:      $LOG_DEST/watchdog.log"
echo "Service Status: systemctl status $SERVICE_NAME"
