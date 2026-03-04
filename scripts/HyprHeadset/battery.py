#!/usr/bin/env python3
"""
HyperX Cloud II Wireless (0x03f0:0x018b) battery checker.
Uses the same HID protocol as HeadsetControl (FF90/0303 interface).

Run via the wrapper: ./headset-battery
"""

import hid
import sys
import time

VENDOR_ID  = 0x03F0
PRODUCT_ID = 0x018B

USAGE_PAGE = 0xFF90
USAGE_ID   = 0x0303

WRITE_PACKET_SIZE = 19  # HID output report payload for this device (0x018b)
READ_PACKET_SIZE  = 19  # HID input  report payload (report ID 0x06)
READ_TIMEOUT_MS   = 1000

CMD_GET_BATTERY_LEVEL    = 0x02
CMD_GET_BATTERY_CHARGING = 0x03
BATTERY_LEVEL_INDEX      = 0x07
BATTERY_CHARGING_INDEX   = 0x04


def find_device_path() -> bytes | None:
    for dev in hid.enumerate(VENDOR_ID, PRODUCT_ID):
        if dev["usage_page"] == USAGE_PAGE and dev["usage"] == USAGE_ID:
            return dev["path"]
    return None


def send_command(h: hid.Device, command: int, value: int | None = None) -> list[int]:
    # Build 20-byte write: report ID 0x06 + 19 data bytes
    packet = bytearray(1 + WRITE_PACKET_SIZE)
    packet[0] = 0x06          # report ID
    packet[1] = 0xFF
    packet[2] = 0xBB
    packet[3] = command
    packet[4] = value if value is not None else 0x00
    h.write(bytes(packet))

    # Some devices may send asynchronous or out-of-order HID reports. Read repeatedly
    # until we receive a response whose command byte matches the command we sent,
    # or until the timeout expires.
    deadline = time.monotonic() + (READ_TIMEOUT_MS / 1000.0)
    last_hdr = None
    while time.monotonic() < deadline:
        response = h.read(READ_PACKET_SIZE + 1, int((deadline - time.monotonic()) * 1000))
        if not response:
            # try again until deadline
            continue
        if len(response) < 4:
            last_hdr = list(response[:len(response)])
            continue
        hdr = list(response[:4])
        last_hdr = hdr
        # Expected header: [report-id, 0xFF, 0xBB, command]
        if hdr[0] == 0x06 and hdr[1] == 0xFF and hdr[2] == 0xBB and hdr[3] == command:
            return list(response)
        # Otherwise ignore this packet (it may be a reply for a different command)
        # and keep waiting until we see the matching command or hit timeout.

    if last_hdr is None:
        raise RuntimeError("Short or empty response (no data read)")
    raise RuntimeError(f"Unexpected response header (no matching command before timeout): {last_hdr}")


def main():
    path = find_device_path()
    if path is None:
        print("Error: HyperX Cloud II Wireless (0x03f0:0x018b) not found.", file=sys.stderr)
        print("Make sure the USB dongle is plugged in and the headset is on.", file=sys.stderr)
        sys.exit(1)

    with hid.Device(path=path) as h:
        level_res    = send_command(h, CMD_GET_BATTERY_LEVEL)
        charging_res = send_command(h, CMD_GET_BATTERY_CHARGING)

    level    = level_res[BATTERY_LEVEL_INDEX]
    charging = charging_res[BATTERY_CHARGING_INDEX] == 1

    status = "Charging" if charging else "Discharging"
    print(f"Battery: {level}%  ({status})")


if __name__ == "__main__":
    main()
