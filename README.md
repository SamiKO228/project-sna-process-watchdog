# SNA Process Watchdog

A lightweight, automated process monitoring tool designed for **System and Network Administration (SNA)**. This tool ensures system reliability by monitoring critical processes and automatically recovering them in case of crashes or resource exhaustion.

## Features

- **Automated Monitoring:** Tracks processes by name using `pgrep`.
- **Resource Guard:** Detects "Resource Exhaustion" (CPU/RAM spikes) and restarts offending processes.
- **Configurable Delays:** Customizable restart intervals to prevent "flapping".
- **Logging & Alerts:** Detailed logs and a simulation of email alerts for every incident.
- **Systemd Integration:** Runs as a background service with auto-restart capabilities.

## Project Structure

```text
.
├── watchdog.sh       # Main logic (Monitoring & Recovery)
├── watchdog.conf     # Configuration file (Limits & Process list)
├── watchdog.service  # Systemd unit file
├── install.sh        # Automated installation script
├── docs/             # Project documentation and reports
└── poc_tests/        # Proof of Concept scripts (stress tests)
```

## Installation

To install the watchdog on your Ubuntu system, clone the repository and run the installation script with root privileges:

```bash
git clone [https://github.com/your-username/sna-process-watchdog.git](https://github.com/your-username/sna-process-watchdog.git)
cd sna-process-watchdog
sudo chmod +x install.sh
sudo ./install.sh
```

## Configuration

You can manage monitored processes in `/etc/watchdog/watchdog.conf`. 
The format is: `process_name | max_cpu_% | max_ram_MB | restart_delay_sec`

Example:
```text
nginx | 20 | 256 | 5
python_app | 50 | 128 | 10
```

## Usage & Monitoring

**Check Service Status:**
```bash
systemctl status watchdog.service
```

**View Real-time Logs:**
```bash
tail -f /var/log/watchdog.log
```

**View Critical Alerts:**
```bash
cat /var/log/watchdog_alerts.log
```

## License
University Project (Educational Use Only)
