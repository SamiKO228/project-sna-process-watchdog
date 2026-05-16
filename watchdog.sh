#!/usr/bin/env bash

CONFIG_FILE="${1:-${CONFIG_FILE:-/etc/watchdog/watchdog.conf}}"
LOG_FILE="${LOG_FILE:-/var/log/watchdog.log}"
ALERT_LOG="${ALERT_LOG:-/var/log/watchdog_alerts.log}"
CHECK_INTERVAL="${CHECK_INTERVAL:-5}"
STOP_TIMEOUT="${STOP_TIMEOUT:-5}"

running=true

ensure_log_files() {
    mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$ALERT_LOG")" 2>/dev/null || true
    touch "$LOG_FILE" "$ALERT_LOG" 2>/dev/null || true
}

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

log_message() {
    printf '%s - %s\n' "$(timestamp)" "$1" >> "$LOG_FILE"
}

send_alert() {
    printf '%s - ALERT: %s\n' "$(timestamp)" "$1" >> "$ALERT_LOG"
}

trim() {
    local value="$*"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

is_number() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

is_pid_alive() {
    local pid="$1"
    [[ "$pid" =~ ^[0-9]+$ ]] && [[ -d "/proc/$pid" ]]
}

sleep_interruptible() {
    local seconds="$1"
    local elapsed=0

    while [[ "$running" == true && "$elapsed" -lt "$seconds" ]]; do
        sleep 1 &
        wait $! 2>/dev/null || true
        elapsed=$((elapsed + 1))
    done
}

handle_shutdown() {
    running=false
    log_message "Shutdown signal received. Stopping watchdog loop."
}

get_pids() {
    local mode="$1"
    local target="$2"
    local pid

    case "$mode" in
        name)
            pgrep -x "$target" 2>/dev/null || true
            ;;
        pidfile)
            [[ -r "$target" ]] || return 0
            pid="$(tr -d '[:space:]' < "$target" 2>/dev/null)"
            if is_pid_alive "$pid"; then
                printf '%s\n' "$pid"
            fi
            ;;
    esac
}

get_usage() {
    local cpu_total=0
    local ram_total=0
    local pid
    local stats
    local cpu
    local ram_kb

    for pid in "$@"; do
        stats="$(ps -p "$pid" -o %cpu=,rss= 2>/dev/null)" || continue
        [[ -n "$stats" ]] || continue

        cpu="$(awk '{printf "%d", $1}' <<< "$stats")"
        ram_kb="$(awk '{printf "%d", $2}' <<< "$stats")"

        cpu_total=$((cpu_total + cpu))
        ram_total=$((ram_total + ram_kb / 1024))
    done

    printf '%s %s\n' "$cpu_total" "$ram_total"
}

stop_pids() {
    local label="$1"
    shift
    local pids=("$@")
    local alive=()
    local pid
    local waited=0

    [[ "${#pids[@]}" -gt 0 ]] || return 0

    log_message "Sending SIGTERM to '$label' PIDs: ${pids[*]}"
    kill -TERM "${pids[@]}" 2>/dev/null || true

    while [[ "$waited" -lt "$STOP_TIMEOUT" ]]; do
        alive=()
        for pid in "${pids[@]}"; do
            if is_pid_alive "$pid"; then
                alive+=("$pid")
            fi
        done

        if [[ "${#alive[@]}" -eq 0 ]]; then
            log_message "Process '$label' stopped gracefully."
            return 0
        fi

        sleep_interruptible 1
        [[ "$running" == true ]] || return 0
        waited=$((waited + 1))
    done

    alive=()
    for pid in "${pids[@]}"; do
        if is_pid_alive "$pid"; then
            alive+=("$pid")
        fi
    done

    if [[ "${#alive[@]}" -gt 0 ]]; then
        log_message "SIGTERM timeout for '$label'. Sending SIGKILL to PIDs: ${alive[*]}"
        send_alert "Forced kill for $label after SIGTERM timeout."
        kill -KILL "${alive[@]}" 2>/dev/null || true
    fi
}

start_process() {
    local label="$1"
    local delay="$2"
    local start_command="$3"

    log_message "Starting '$label' after ${delay}s delay: $start_command"
    sleep_interruptible "$delay"

    if [[ "$running" != true ]]; then
        return 0
    fi

    bash -c "$start_command" >> "$LOG_FILE" 2>&1 &
    log_message "Start command launched for '$label' (launcher PID: $!)."
}

monitor_entry() {
    local mode="$1"
    local target="$2"
    local start_command="$3"
    local cpu_limit="$4"
    local ram_limit="$5"
    local delay="$6"
    local label="${mode}:${target}"
    local pids=()
    local current_cpu
    local current_ram

    mapfile -t pids < <(get_pids "$mode" "$target")

    if [[ "${#pids[@]}" -eq 0 ]]; then
        log_message "Target '$label' is not running."
        send_alert "$label is down. Restart command will be executed."
        start_process "$label" "$delay" "$start_command"
        return 0
    fi

    read -r current_cpu current_ram < <(get_usage "${pids[@]}")

    if [[ "$current_cpu" -gt "$cpu_limit" || "$current_ram" -gt "$ram_limit" ]]; then
        log_message "Resource limit exceeded for '$label'. CPU: ${current_cpu}%/${cpu_limit}%, RAM: ${current_ram}MB/${ram_limit}MB"
        send_alert "$label exceeded resource limits. Restarting."
        stop_pids "$label" "${pids[@]}"
        start_process "$label" "$delay" "$start_command"
    fi
}

handle_config_line() {
    local line_number="$1"
    local raw_line="$2"
    local trimmed
    local mode
    local target
    local start_command
    local cpu_limit
    local ram_limit
    local delay
    local extra

    trimmed="$(trim "$raw_line")"
    [[ -z "$trimmed" || "$trimmed" == \#* ]] && return 0

    IFS='|' read -r mode target start_command cpu_limit ram_limit delay extra <<< "$raw_line"

    mode="$(trim "$mode")"
    target="$(trim "$target")"
    start_command="$(trim "$start_command")"
    cpu_limit="$(trim "$cpu_limit")"
    ram_limit="$(trim "$ram_limit")"
    delay="$(trim "$delay")"
    extra="$(trim "${extra:-}")"

    if [[ -n "$extra" ]]; then
        log_message "Invalid config line $line_number: expected 6 pipe-separated fields."
        return 1
    fi

    if [[ "$mode" != "name" && "$mode" != "pidfile" ]]; then
        log_message "Invalid config line $line_number: mode must be 'name' or 'pidfile'."
        return 1
    fi

    if [[ -z "$target" || -z "$start_command" ]]; then
        log_message "Invalid config line $line_number: target and start command are required."
        return 1
    fi

    if ! is_number "$cpu_limit" || ! is_number "$ram_limit" || ! is_number "$delay"; then
        log_message "Invalid config line $line_number: CPU, RAM, and delay must be non-negative integers."
        return 1
    fi

    monitor_entry "$mode" "$target" "$start_command" "$cpu_limit" "$ram_limit" "$delay"
}

check_processes() {
    local line_number=0
    local raw_line

    if [[ ! -r "$CONFIG_FILE" ]]; then
        log_message "Configuration file is not readable: $CONFIG_FILE"
        send_alert "Configuration file is not readable: $CONFIG_FILE"
        return 1
    fi

    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        line_number=$((line_number + 1))
        handle_config_line "$line_number" "$raw_line"
        [[ "$running" == true ]] || break
    done < "$CONFIG_FILE"
}

trap handle_shutdown INT TERM

ensure_log_files
log_message "Watchdog service started. Config: $CONFIG_FILE"

while [[ "$running" == true ]]; do
    check_processes
    sleep_interruptible "$CHECK_INTERVAL"
done

log_message "Watchdog service stopped."
