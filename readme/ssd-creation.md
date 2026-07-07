# SSD Creation For Raspberry Pi

This guide explains how to create a bootable SSD for the Raspberry Pi with SSH enabled and hostname set to rpiai.

## Prerequisites

- Raspberry Pi Imager installed on Windows
- USB to SSD adapter
- Target SSD connected to your computer
- Wi-Fi name and password available

## Steps

1. Open Raspberry Pi Imager.
2. Select your Raspberry Pi model.
3. Select OS:
   - Recommended: Raspberry Pi OS Lite (64-bit)
   - Alternative (if local desktop UI is needed): Raspberry Pi OS (64-bit)
4. Select the SSD as storage.
5. Open Advanced options in Imager:
   - Enable SSH
   - Set hostname to rpiai
   - Configure Wi-Fi SSID, password, and country
   - Set username and password
6. Click Write and wait until imaging is complete.
7. Safely eject the SSD.
8. Insert SSD into Raspberry Pi and power it on.

## Quick Validation

From Windows PowerShell:

```powershell
ping rpiai.local
```

From Git Bash:

```bash
/c/Windows/System32/ping.exe -n 2 rpiai.local
```

If rpiai.local does not resolve, use your router DHCP page to find the Pi IP and continue with that IP.
