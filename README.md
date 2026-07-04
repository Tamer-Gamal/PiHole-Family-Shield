# 🛡️ Pi-hole Kit — a family-safe home network

> **Built on [Pi-hole®](https://pi-hole.net)** — the free, open-source network blocker
> ([source on GitHub](https://github.com/pi-hole/pi-hole)). This kit **installs** Pi-hole from
> its official installer and adds a family-filtering layer, setup scripts & a guide on top.
> It is an independent project, **not affiliated with or endorsed by** the Pi-hole team.

A complete, repeatable kit for turning a Raspberry Pi into a **family-safe Pi-hole**:
a little box that keeps kids safer and blocks ads for **every device on your home
network** — phones, TVs, laptops, consoles — with no app to install on each device.

Family protection is the **main purpose** and is **on by default**:

- 🔍 **Forces SafeSearch** on Google, Bing & DuckDuckGo (no adult results/images)
- ▶️ **Forces YouTube Restricted Mode**
- 🚫 **Blocks adult / pornographic sites** network-wide
- 🎰 **Blocks gambling** and known **scam / phishing / malware** domains
- 📵 **Blocks ads & trackers** (faster, cleaner browsing as a bonus)

> ⚠️ **No DNS filter is perfect.** It blocks known bad *domains* and forces safe search,
> but can't see inside an allowed site, can't catch brand-new adult sites instantly, and
> can be bypassed with a VPN unless hardened. Use it **with** device parental controls
> (Screen Time / Family Link) and conversations — a strong first layer, not a guarantee.

Built to be **cloned**: edit one config file, run one script, and you have an
identical, family-safe Pi-hole. Make one for yourself, then make more for friends.

> This is a standalone Homelab-Hive project. It has **nothing to do with the Rei
> VM** or any Rei service — it runs entirely on its own Raspberry Pi hardware.

---

## 📖 Start here (non-technical)

Open the **interactive guidebook** — it walks you through everything with
diagrams, checklists, and copy-paste commands:

```
pi-hole/guide/index.html      ← double-click to open in your browser
```

Order of the journey:
1. **What Pi-hole is** and how it protects you (guidebook, section 1–2)
2. **Flash the SD card** → [`scripts/flash-and-first-boot.md`](scripts/flash-and-first-boot.md)
3. **Run the installer** → `sudo ./bootstrap.sh`
4. **Point your router at the Pi** (guidebook, section 5)
5. **Verify + enjoy** (guidebook, section 6)

---

## 🧰 What's in this folder

```
pi-hole/
├── README.md                     ← you are here
├── guide/
│   └── index.html                ← the interactive, illustrated guidebook
├── scripts/
│   ├── flash-and-first-boot.md   ← Step 0: prepare the SD card + connect
│   ├── setup.conf.example        ← copy to setup.conf and edit (the ONLY file you change)
│   ├── bootstrap.sh              ← the one-shot installer (idempotent)
│   ├── family-filter.sh          ← SafeSearch + YouTube-restricted + adult/gambling blocking
│   ├── install-unbound.sh        ← optional: private recursive DNS
│   ├── add-blocklists.sh         ← adds the curated ad/malware blocklists
│   ├── backup.sh                 ← save your config (Teleporter) to reuse on other Pis
│   └── update.sh                 ← keep OS + Pi-hole + lists up to date
├── config/
│   ├── blocklists.txt            ← curated ad + malware/phishing lists
│   ├── blocklists-family.txt     ← adult / NSFW lists (family mode)
│   └── unbound-pihole.conf       ← Unbound resolver config
└── companions/
    └── haramblur.md              ← Layer 2: on-page image/video blurring (browser add-on)
```

---

## ⚡ Quick start (for people comfortable in a terminal)

The kit is **self-contained** — it does **not** need access to any private repo. Get the
`pi-hole/` folder onto a freshly-flashed Raspberry Pi OS Lite (connected to your network),
then run the installer.

```bash
# On your computer, in the folder that contains pi-hole/ :
scp -r ./pi-hole pi@pihole.local:~/

# Then on the Pi:
cd ~/pi-hole/scripts
cp setup.conf.example setup.conf
nano setup.conf              # set your admin password (family mode is on by default)
sudo ./bootstrap.sh
```

Then set your **router's DNS server** to the Pi's IP address and reboot your
devices. Done.

> Other ways to move the folder: a USB stick, a cloud link, or `git clone` if you keep
> the kit in a repo the target can read. See **Sharing with friends** below.

---

## 🧬 Sharing with friends / making more Pi-holes

**Getting the kit to a friend** (it contains no secrets, so it travels freely):
- **Public repo (easiest)** — the kit is mirrored to a public repo so anyone can install it
  with one command: <https://github.com/Tamer-Gamal/pihole-family-shield>
  ```bash
  git clone https://github.com/Tamer-Gamal/pihole-family-shield.git
  cd pihole-family-shield/scripts && cp setup.conf.example setup.conf && nano setup.conf && sudo ./bootstrap.sh
  ```
- **USB stick / cloud link** — hand them the `pi-hole/` folder; they copy it onto their Pi.
- **`scp`** — if you set their Pi up, `scp -r ./pi-hole pi@pihole.local:~/` from your computer.

> This `pi-hole/` folder inside the private homelab repo is the **source**; the public repo above
> is a mirror of it. When you change the kit here, re-push the same files to the public repo.

**Reproducing the Pi-hole itself**, two ways:

1. **Fresh + same config** — flash a new SD card, copy your edited `setup.conf`,
   run `sudo ./bootstrap.sh`. Identical, family-safe result every time.
2. **Clone an existing one** — on your working Pi run `sudo ./backup.sh` to get a
   Teleporter archive, then on the new Pi (after `bootstrap.sh`) restore it from
   the admin page: **Settings → Teleporter → Restore**. This copies your exact
   allowlists/blocklists/custom settings.

## 👨‍👩‍👧 Family protection (on by default)

Set in `setup.conf`; applied by `family-filter.sh` (run automatically by `bootstrap.sh`):

| Setting | Default | What it does |
|---|---|---|
| `FAMILY_MODE` | `true` | SafeSearch (Google/Bing/DuckDuckGo) + YouTube Restricted Mode + adult-site blocking |
| `FAMILY_BLOCK_GAMBLING` | `true` | Also blocks gambling / betting sites |
| `YOUTUBE_MODE` | `strict` | `strict` (young kids) or `moderate` |
| `BLOCK_DNS_BYPASS` | `false` | Blocks VPN / DoH / proxy escape tricks — powerful, but can block a legit VPN you use |
| `FAMILY_GOOGLE_CCTLD` | *(empty)* | Force SafeSearch on your country's Google too, e.g. `google.com.sa` |

**Honest limits (important):** DNS filtering blocks known bad *domains* and forces safe
search. It **cannot** filter content *inside* a site you allow, **cannot** catch a
brand-new adult site until the lists update, and a determined child can bypass it with a
VPN unless you enable `BLOCK_DNS_BYPASS` **and** force all devices' DNS to the Pi in your
router. Use this **with** device parental controls and conversations — not instead of them.

### 🧩 Layer 2 — HaramBlur (blurs what Pi-hole can't see inside)

Pair this network filter with **[HaramBlur](https://github.com/alganzory/HaramBlur)** — a
free, open-source browser extension (AGPL-3.0) that uses **on-device AI** to blur
inappropriate **images & videos on the page itself**, covering Pi-hole's blind spot inside
allowed sites. It's a **separate project** (not part of this kit); install it per browser:
- Chrome/Edge/Brave: <https://chrome.google.com/webstore/detail/haramblur/pbcoegikffnadpahojjhgdladmmddeji>
- Firefox (desktop & Android): <https://addons.mozilla.org/addon/haramblur/>

Full setup, settings, caveats & lock-down tips: **[`companions/haramblur.md`](companions/haramblur.md)**.

---

## 🔒 Design choices (and why)

| Choice | Why |
|---|---|
| **Native install** (not Docker) | A network appliance wants a fixed identity and to survive reboots with no extra runtime. The official installer is the most battle-tested, easiest-to-reproduce path for a first-time Pi owner. |
| **DHCP reservation over static IP** | Pi-hole must always live at the same address. Reserving it in the *router* is easier and more robust than per-Pi static config. `bootstrap.sh` can still set a static IP if you insist (advanced). |
| **Cloudflare upstream by default, Unbound optional** | Works instantly for everyone; privacy purists flip one switch (`INSTALL_UNBOUND="true"`) to stop trusting any upstream company. |
| **Curated, low-false-positive blocklists** | Over-blocking makes "the internet look broken" for non-tech users. The defaults (OISD + focused malware/phishing) block aggressively without breaking normal sites. |
| **Pi-hole v6 with v5 fallbacks** | Targets the current release; commands that changed (e.g. the admin password) fall back automatically so the kit keeps working on older images. |

---

## 🩺 Maintenance

- **Monthly:** `sudo ./update.sh` (OS + Pi-hole + lists).
- **Before big changes / to clone:** `sudo ./backup.sh`.
- **A site looks broken?** It's almost never Pi-hole breaking the *page* — but if
  a login or download is blocked, open the admin page → **Query Log**, find the
  red (blocked) domain, and click **Allow**. The guidebook's troubleshooting
  section shows this step by step.

## 🙏 Credits & source

This kit is a **wrapper + guide**, not a fork. The actual software it installs:

- **Pi-hole®** — free, open-source, by the Pi-hole team: <https://pi-hole.net> ·
  source <https://github.com/pi-hole/pi-hole>. `bootstrap.sh` installs it from the
  **official installer** (`https://install.pi-hole.net`) so you always get the current,
  maintained release — we deliberately do **not** vendor Pi-hole's source here.
- **Unbound** — recursive DNS resolver (NLnet Labs), installed from the OS package repo.
- **Blocklists** — maintained by their authors: OISD, HaGeZi, Steven Black, and others.
- **HaramBlur** (optional Layer 2, install per browser) — on-device-AI image/video blurring
  browser extension by *alganzory*: <https://github.com/alganzory/HaramBlur> (AGPL-3.0). A
  separate project, not bundled with, modified by, or affiliated with this kit.

This project is independent and **not affiliated with or endorsed by** the Pi-hole team
or the HaramBlur project.

## ⚠️ Verification note

These scripts are written to be idempotent and are `bash -n` clean, but they
install and configure software **on a Raspberry Pi**, which is separate hardware.
They have **not** been executed end-to-end here — validate on your first Pi and
report anything that needs a tweak.
