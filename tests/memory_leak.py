#!/usr/bin/env python3

import atexit
import time
import os
import signal
import sys


PID_FILE = os.environ.get("PID_FILE")


def write_pid_file():
    if not PID_FILE:
        return

    with open(PID_FILE, "w", encoding="utf-8") as pid_file:
        pid_file.write(f"{os.getpid()}\n")


def remove_pid_file():
    if PID_FILE and os.path.exists(PID_FILE):
        os.remove(PID_FILE)


def handle_shutdown(signum, frame):
    print(f"[PID: {os.getpid()}] Received signal {signum}, exiting...")
    sys.exit(0)


def simulate_memory_leak():
    """
    Simulates a memory leak by continuously appending large chunks of data
    to a list until the process is killed by the Watchdog.
    """
    print(f"[PID: {os.getpid()}] Starting memory leak simulation...")
    
    # List to hold the leaked data in memory
    leaked_memory = []
    
    # Size of each chunk to allocate (10 Megabytes)
    chunk_size_mb = 10
    try:
        while True:
            # Allocate a fresh chunk on every loop iteration.
            leaked_memory.append(bytearray(1024 * 1024 * chunk_size_mb))
            
            total_allocated = len(leaked_memory) * chunk_size_mb
            print(f"[PID: {os.getpid()}] Allocated ~{total_allocated} MB of RAM...", flush=True)
            
            # Sleep for 1 second to allow Watchdog to poll the metrics
            time.sleep(1)
            
    except MemoryError:
        print(f"[PID: {os.getpid()}] System out of memory! (Watchdog failed to catch this in time)")

if __name__ == "__main__":
    write_pid_file()
    atexit.register(remove_pid_file)
    signal.signal(signal.SIGTERM, handle_shutdown)
    signal.signal(signal.SIGINT, handle_shutdown)
    simulate_memory_leak()
