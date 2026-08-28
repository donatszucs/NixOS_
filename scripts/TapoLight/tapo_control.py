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

async def get_device():
    if not EMAIL or not PASSWORD or not IP:
        raise Exception("Missing credentials")
    client = ApiClient(EMAIL, PASSWORD)
    return await client.l530(IP)

async def main():
    if len(sys.argv) < 2: return
    
    cmd = sys.argv[1]

    if cmd == "on":
        try:
            device = await get_device()
            await device.on()
        except Exception:
            pass
    elif cmd == "off":
        try:
            device = await get_device()
            await device.off()
        except Exception:
            pass
    elif cmd == "set":
        # Safeguard: Ensure sys.argv[2] exists and is not empty
        if len(sys.argv) > 2 and sys.argv[2].strip():
            try:
                val = int(sys.argv[2])
                device = await get_device()
                await device.set_brightness(val)
            except Exception:
                pass # Ignore bad input or connection error
    elif cmd == "brightness":
        try:
            device = await get_device()
            info = await device.get_device_info()
            print(f"{info.brightness}")
        except Exception:
            print("OFF") # Fallback if device is unreachable
    elif cmd == "color":
        if len(sys.argv) > 3:
            try:
                h = int(sys.argv[2])
                s = int(sys.argv[3])
                device = await get_device()
                await device.set_hue_saturation(h, s)
            except Exception:
                pass
    elif cmd == "white":
        try:
            device = await get_device()
            await device.set_color_temperature(4000)
        except Exception:
            pass
    elif cmd == "get_color":
        try:
            device = await get_device()
            info = await device.get_device_info()
            print(f"{info.hue},{info.saturation}")
        except Exception:
            print("30,0")
    elif cmd == "state":
        try:
            device = await get_device()
            info = await device.get_device_info()
            h = 0 if info.color_temp > 0 else info.hue
            s = 0 if info.color_temp > 0 else info.saturation
            print(f"{'ON' if info.device_on else 'OFF'},{info.brightness},{h},{s}")
        except Exception:
            print("OFF,0,30,0") # Fallback if device is unreachable
    elif cmd == "status":
        try:
            device = await get_device()
            info = await device.get_device_info()
            print(f"{'ON' if info.device_on else 'OFF'}")
        except Exception:
            print("OFF") # Fallback if device is unreachable

if __name__ == "__main__":
    asyncio.run(main())