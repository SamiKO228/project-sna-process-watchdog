#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

echo "Installing Process Watchdog..."

# 1. Create needed folders
mkdir -p /etc/watchdog
touch /var/log/watchdog.log
touch /var/log/watchdog_alerts.log

# 2. Copy the files (considering you're in root)
cp watchdog.sh /usr/local/bin/
cp watchdog.conf /etc/watchdog/
cp watchdog.service /etc/systemd/system/

# 3. Set the rights
chmod +x /usr/local/bin/watchdog.sh

# 4. Restart the systemd daemon and start the service
systemctl daemon-reload
systemctl enable watchdog.service
systemctl restart watchdog.service

echo "Watchdog installed and started! Check status: systemctl status watchdog"
