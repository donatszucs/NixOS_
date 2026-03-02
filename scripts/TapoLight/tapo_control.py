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
    if len(sys.argv) < 2: return
    
    client = ApiClient(EMAIL, PASSWORD)
    device = await client.l530(IP)
    cmd = sys.argv[1]

    if cmd == "on": await device.on()
    elif cmd == "off": await device.off()
    elif cmd == "set":
        # Safeguard: Ensure sys.argv[2] exists and is not empty
        if len(sys.argv) > 2 and sys.argv[2].strip():
            try:
                val = int(sys.argv[2])
                await device.set_brightness(val)
            except ValueError:
                pass # Ignore bad input
    elif cmd == "brightness":
        try:
            info = await device.get_device_info()
            print(f"{info.brightness}")
        except Exception:
            print("OFF") # Fallback if device is unreachable
    elif cmd == "status":
        try:
            info = await device.get_device_info()
            print(f"{'ON' if info.device_on else 'OFF'}")
        except Exception:
            print("anyad") # Fallback if device is unreachable

if __name__ == "__main__":
    asyncio.run(main())