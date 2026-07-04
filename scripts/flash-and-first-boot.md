# Step 0 - Flash the SD card and first boot

You only need to do this **once per Pi**. It takes ~15 minutes, mostly waiting.

## What you need
- A Raspberry Pi (any Pi 3, 4, 5, or Zero 2 W works - a Pi 4 is ideal)
- A microSD card (8 GB or larger) + a way to plug it into your computer
- The Pi's power supply and a network connection (Ethernet cable is easiest;
  Wi-Fi also works)

## 1. Install "Raspberry Pi Imager" on your computer
Download it (free, official) from **https://www.raspberrypi.com/software/** and
install it like any normal app (Windows, macOS, or Linux).

## 2. Flash Raspberry Pi OS Lite (64-bit)
1. Put the microSD card in your computer.
2. Open **Raspberry Pi Imager**.
3. **CHOOSE DEVICE** -> pick your Pi model.
4. **CHOOSE OS** -> *Raspberry Pi OS (other)* -> **Raspberry Pi OS Lite (64-bit)**.
   ("Lite" has no desktop - perfect for an always-on box. It's smaller and faster.)
5. **CHOOSE STORAGE** -> pick your microSD card. *(Double-check - this erases it.)*
6. Click **NEXT**, then **EDIT SETTINGS** when it offers to customise. This part
   is important - it lets the Pi run with no screen or keyboard ("headless"):
   - **Set hostname:** `pihole`  (so you can reach it at `pihole.local`)
   - **Set username and password:** e.g. username `pi` and a password you'll remember.
   - **Configure wireless LAN** *(only if you're using Wi-Fi)*: your Wi-Fi name,
     password, and country.
   - **Set locale / timezone.**
   - Go to the **SERVICES** tab -> tick **Enable SSH** -> **Use password authentication**.
7. **SAVE**, then **YES** to apply the settings, then **YES** to erase and write.
8. Wait for it to finish and verify, then remove the card.

## 3. First boot
1. Put the microSD card into the Pi.
2. Plug in the network cable (or rely on the Wi-Fi you configured) and then power.
3. Wait ~90 seconds for it to boot.

## 4. Connect to the Pi from your computer
Open a terminal (on Windows use **PowerShell** or **Windows Terminal**) and type:

```
ssh pi@pihole.local
```

*(Replace `pi` with the username you set. If `pihole.local` doesn't work, find
the Pi's IP address in your router's device list and use `ssh pi@THE.IP.ADDRESS`.)*

Type `yes` the first time it asks about the fingerprint, then enter your password.
You're now "inside" the Pi.

## 5. Get the install kit onto the Pi

**Easiest - download it on the Pi** (public repo, no private access needed):

```
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/Tamer-Gamal/pihole-family-shield.git
cd pihole-family-shield/scripts
cp setup.conf.example setup.conf
nano setup.conf        # set your admin password, then Ctrl+O, Enter, Ctrl+X
sudo ./bootstrap.sh
```

*(Prefer offline? Copy the `pi-hole` folder from your computer instead -
`scp -r ./pi-hole pi@pihole.local:~/` or a USB stick - then `cd ~/pi-hole/scripts`
and run the same `cp` / `nano` / `bootstrap.sh` steps.)*

That's it - the script does the rest, including the **family protection** layer
(SafeSearch, YouTube Restricted Mode, adult/gambling blocking) which is on by
default. When it finishes it prints your admin page address and reminds you of the
one remaining step (point your router at the Pi), which the **interactive guide**
walks through with pictures.
