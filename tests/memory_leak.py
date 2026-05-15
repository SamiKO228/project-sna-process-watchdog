#!/usr/bin/env python3

import time
import os

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
    chunk_string = 'A' * (1024 * 1024 * chunk_size_mb)

    try:
        while True:
            # Append the 10MB string to the list
            leaked_memory.append(chunk_string)
            
            total_allocated = len(leaked_memory) * chunk_size_mb
            print(f"[PID: {os.getpid()}] Allocated ~{total_allocated} MB of RAM...")
            
            # Sleep for 1 second to allow Watchdog to poll the metrics
            time.sleep(1)
            
    except MemoryError:
        print(f"[PID: {os.getpid()}] System out of memory! (Watchdog failed to catch this in time)")

if __name__ == "__main__":
    simulate_memory_leak()
