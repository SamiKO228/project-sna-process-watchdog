#!/bin/bash

# FILE PATHS (ENSURE THESE ARE CORRECT BEFORE RUNNING)
CONFIG_FILE="/etc/watchdog/watchdog.conf"
LOG_FILE="/var/log/watchdog.log"
ALERT_LOG="/var/log/watchdog_alerts.log"

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Email alert simulation function
send_alert() {
    local message="ALERT: $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$ALERT_LOG"
    # Real mail command can be added here if Postfix is configured
}

# Check and restart function
check_processes() {
    # Read config, ignoring comments and empty lines
    grep -v '^#' "$CONFIG_FILE" | grep -v '^$' | while IFS='|' read -r name cpu_limit ram_limit delay; do
        
        # Trim whitespace from variables
        name=$(echo "$name" | xargs)
        cpu_limit=$(echo "$cpu_limit" | xargs)
        ram_limit=$(echo "$ram_limit" | xargs)
        delay=$(echo "$delay" | xargs)

        # 1. Find process PID
        pid=$(pgrep -x "$name")

        if [ -z "$pid" ]; then
            log_message "Process '$name' is NOT running. Attempting to start..."
            # IMPORTANT: Assumes the start command is the same as the process name
            $name & 
            send_alert "Process $name was dead and restarted."
        else
            # 2. Get current CPU and RAM (in MB) usage
            # Using ps: %cpu - percentage, rss - memory in KB
            stats=$(ps -p "$pid" -o %cpu,rss --no-headers)
            current_cpu=$(echo "$stats" | awk '{print $1}' | cut -d. -f1) # Round to integer
            current_ram_kb=$(echo "$stats" | awk '{print $2}')
            current_ram_mb=$((current_ram_kb / 1024))

            # 3. Check for Resource Exhaustion
            if [ "$current_cpu" -gt "$cpu_limit" ] || [ "$current_ram_mb" -gt "$ram_limit" ]; then
                log_message "Resource Limit Exceeded for '$name'! CPU: $current_cpu%/$cpu_limit%, RAM: ${current_ram_mb}MB/${ram_limit}MB"
                
                send_alert "Killing $name (PID: $pid) due to resource exhaustion."
                kill -9 "$pid"
                
                sleep "$delay"
                $name &
                log_message "Process '$name' restarted after delay."
            fi
        fi
    done
}

# MAIN LOOP
log_message "Watchdog service started."
while true; do
    check_processes
    sleep 5 # System check frequency
done
