#!/usr/bin/env python3
import hid
import time
import os
from datetime import datetime

VENDOR_ID = 0x3434
OUTPUT_FILE = "/tmp/keychron_battery.txt"

def main():
    print(f"Starting Keychron Passive Listener. Writing to {OUTPUT_FILE}")
    
    # Write initial state
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(OUTPUT_FILE, "w") as f:
        f.write(f"?\nLast updated: {now}\n")

    while True:
        handles = []
        try:
            # Open all Keychron interfaces
            for dev in hid.enumerate(VENDOR_ID):
                try:
                    h = hid.Device(path=dev['path'])
                    h.nonblocking = True
                    handles.append(h)
                except Exception:
                    pass
            
            if not handles:
                now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                with open(OUTPUT_FILE, "w") as f:
                    f.write(f"Disconnected\nLast updated: {now}\n")
                time.sleep(10)
                continue

            # Listen quietly forever
            while True:
                for h in handles:
                    data = h.read(64)
                    if data and data[0] == 0x54 and len(data) >= 6:
                        battery = data[5]
                        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                        with open(OUTPUT_FILE, "w") as f:
                            f.write(f"{battery}%\nLast updated: {now}\n")
                        print(f"Captured Push Update: {battery}%")
                time.sleep(10) # Low CPU usage polling loop
                
        except OSError:
            # Mouse went to sleep or unplugged, close handles and restart loop
            for h in handles:
                h.close()
            time.sleep(5)
            
        except KeyboardInterrupt:
            for h in handles:
                h.close()
            print("\nExiting.")
            break

if __name__ == "__main__":
    main()