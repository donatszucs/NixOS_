import asyncio
import os
import sys
from tapo import ApiClient
from dotenv import load_dotenv

script_dir = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(script_dir, ".env"))

IP = os.getenv("TAPO_IP")
EMAIL = os.getenv("TAPO_EMAIL")
PASSWORD = os.getenv("TAPO_PASSWORD")

async def main():
    client = ApiClient(EMAIL, PASSWORD)
    device = await client.l530(IP)
    
    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        if cmd == "toggle":
            info = await device.get_device_info()
            if info.device_on: await device.off()
            else: await device.on()
        elif cmd == "brightness" and len(sys.argv) > 2:
            info = await device.get_device_info()
            current = info.brightness
            adjustment = int(sys.argv[2])
            new_brightness = max(1, min(100, current + adjustment))
            await device.set_brightness(new_brightness)

    # Fetch final state
    info = await device.get_device_info()
    
    if not info.device_on:
        # " Off" (with a leading space) makes it 4 characters
        print(" Off 󱩎")
    else:
        brightness = info.brightness
        # "{:>3}%" ensures the number is right-aligned in a 3-space block
        # e.g., "  5%", " 50%", "100%"
        print(f"{brightness:>3}% 󱩒")

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except Exception:
        print("󰛑")