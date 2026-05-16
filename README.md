# SNA Process Watchdog

A lightweight process monitoring tool for System and Network Administration
practice. It watches critical processes, logs failures, simulates alerts, and
tries to recover failed or overloaded processes automatically.

## Features

- Monitors processes by exact process name with `pgrep -x`.
- Monitors a specific process through a PID file and `/proc/<pid>`.
- Restarts failed processes with an explicit command from the config.
- Checks CPU and RAM limits.
- Stops overloaded processes gracefully with `SIGTERM`, then uses `SIGKILL`
  only if the process does not exit in time.
- Handles `SIGTERM` and `SIGINT` so systemd or a terminal can stop the loop
  cleanly.
- Writes operational logs and alert-simulation logs.
- Can run as a systemd service or as a standalone script.

## Project Structure

```text
.
|-- watchdog.sh       # Main monitoring and recovery logic
|-- watchdog.conf     # Process list, restart commands, and limits
|-- watchdog.service  # Optional systemd unit
|-- install.sh        # Installation helper
|-- tests/
|   `-- memory_leak.py # Demo process for RAM-limit recovery
`-- README.md
```

## Configuration

The installed config path is:

```bash
/etc/watchdog/watchdog.conf
```

Config format:

```text
mode | target | start_command | max_cpu_percent | max_ram_mb | restart_delay_sec
```

Examples:

```text
name | nginx | systemctl start nginx | 80 | 256 | 5
pidfile | /run/myapp.pid | /opt/myapp/start.sh | 70 | 512 | 5
```

`name` mode uses `pgrep -x target`. This is good for processes with a clear
unique name, such as `nginx` or `mysqld`.

`pidfile` mode reads a PID from a file and checks `/proc/<pid>`. This is better
for generic runtimes like `python`, `node`, or `java`, because many unrelated
programs may share the same process name.

## Installation

```bash
sudo chmod +x install.sh
sudo ./install.sh
```

If WSL prints `sudo: unable to execute ./install.sh: No such file or directory`
even though the file exists, convert Windows line endings first:

```bash
sed -i 's/\r$//' install.sh watchdog.sh watchdog.conf watchdog.service tests/memory_leak.py
chmod +x install.sh watchdog.sh
sudo ./install.sh
```

After installation:

```bash
sudo systemctl status watchdog.service
sudo tail -f /var/log/watchdog.log
sudo tail -f /var/log/watchdog_alerts.log
```

## Standalone Run

For local testing without installing the service:

```bash
chmod +x watchdog.sh
LOG_FILE=./watchdog.log ALERT_LOG=./watchdog_alerts.log ./watchdog.sh ./watchdog.conf
```

## Failure and Recovery Demo

1. Add this line to `watchdog.conf`:

```text
pidfile | /tmp/watchdog-memory-leak.pid | PID_FILE=/tmp/watchdog-memory-leak.pid python3 tests/memory_leak.py | 90 | 64 | 3
```

2. Start the watchdog from the repository root:

```bash
LOG_FILE=./watchdog.log ALERT_LOG=./watchdog_alerts.log ./watchdog.sh ./watchdog.conf
```

3. The watchdog starts `tests/memory_leak.py`. The demo process writes its PID
   to `/tmp/watchdog-memory-leak.pid`, allocates memory, exceeds the RAM limit,
   receives `SIGTERM`, and then gets started again after the configured delay.

4. Watch the recovery in logs:

```bash
tail -f ./watchdog.log
tail -f ./watchdog_alerts.log
```

Example watchdog log output:

```text
2026-05-16 17:16:38 - Watchdog service started. Config: ./watchdog.conf
2026-05-16 17:16:38 - Target 'pidfile:/tmp/watchdog-memory-leak.pid' is not running.
2026-05-16 17:16:41 - Start command launched for 'pidfile:/tmp/watchdog-memory-leak.pid' (launcher PID: 5854).
[PID: 5854] Starting memory leak simulation...
[PID: 5854] Allocated ~70 MB of RAM...
2026-05-16 17:16:47 - Resource limit exceeded for 'pidfile:/tmp/watchdog-memory-leak.pid'. CPU: 1%/90%, RAM: 80MB/64MB
2026-05-16 17:16:47 - Sending SIGTERM to 'pidfile:/tmp/watchdog-memory-leak.pid' PIDs: 5854
[PID: 5854] Received signal 15, exiting...
2026-05-16 17:16:48 - Process 'pidfile:/tmp/watchdog-memory-leak.pid' stopped gracefully.
2026-05-16 17:16:48 - Starting 'pidfile:/tmp/watchdog-memory-leak.pid' after 3s delay: PID_FILE=/tmp/watchdog-memory-leak.pid python3 tests/memory_leak.py
2026-05-16 17:16:51 - Start command launched for 'pidfile:/tmp/watchdog-memory-leak.pid' (launcher PID: 5961).
```

Example alert log output:

```text
2026-05-16 17:16:38 - ALERT: pidfile:/tmp/watchdog-memory-leak.pid is down. Restart command will be executed.
2026-05-16 17:16:47 - ALERT: pidfile:/tmp/watchdog-memory-leak.pid exceeded resource limits. Restarting.
```

## Manual Crash Test

When the demo process is running, kill it manually:

```bash
kill -9 "$(cat /tmp/watchdog-memory-leak.pid)"
```

The watchdog should detect that `/proc/<pid>` disappeared and execute the
configured start command again.

## Final Cleanup

After the demo:

```bash
pkill -f 'tests/memory_leak.py'
rm -f /tmp/watchdog-memory-leak.pid
```
