# 🧩 Layer 2 — HaramBlur (content blurring on the page)

Pi-hole is a **network** filter: it blocks bad *domains* and forces SafeSearch for
every device, but it cannot look *inside* a page it allows. **HaramBlur** is the
second layer that covers that gap — a free, open-source browser extension that uses
**on-device AI** to automatically **blur inappropriate images and videos on the page
itself**, in real time.

> HaramBlur is a **separate project**, not part of this kit and not affiliated with it.
> Source & credit: **<https://github.com/alganzory/HaramBlur>** (license: **AGPL-3.0**).
> It uses face detection (the *Human* library) + NSFW detection (*nsfwjs*).

## Why use it *with* Pi-hole

| | Pi-hole (Layer 1) | HaramBlur (Layer 2) |
|---|---|---|
| Works at | The **network** (DNS), on the Pi | The **browser**, on each device |
| Blocks / hides | Bad **domains** + forces SafeSearch/YouTube | Bad **images & video** on allowed pages |
| Covers | Every device on the Wi-Fi, no per-device app | Only browsers where it's installed |
| Blind spot it has | Can't see *inside* an allowed page | Only the browser (not apps/other devices) |

Neither is perfect alone. Together they cover far more: the network gate stops most
bad sites; the on-page filter blurs what slips through on the sites that remain.

## Install (per browser, per device)

Install it in **each family member's browser**:

- **Chrome / Edge / Brave (Chromium):**
  <https://chrome.google.com/webstore/detail/haramblur/pbcoegikffnadpahojjhgdladmmddeji>
- **Firefox (desktop & Android):**
  <https://addons.mozilla.org/addon/haramblur/>

After installing, open the extension's pop-up and set:
- **Detection type** — images/video, faces, NSFW.
- **Blur strength** and **strictness** — start moderate; raise for younger kids.
- **Hover-to-unblur** — consider turning this **off** on children's devices.
- **On/off toggle** — leave it on.

## Good to know (honest notes)

- **Per-device, per-browser.** Unlike Pi-hole, it isn't network-wide — you install it
  on each device/browser, and it only protects the browser (not native apps or games).
- **Runs on the device.** All processing is in the browser (private — nothing uploaded),
  but the AI uses CPU/GPU, so it can slow older phones/laptops. Lower the strictness or
  pause it on weak devices.
- **Not foolproof.** AI detection misses things and occasionally over-blurs. It's a strong
  aid, not a guarantee — keep it paired with Pi-hole, device parental controls, and
  conversations.
- **Managed devices:** for family/managed devices you can force-install the extension via
  your browser's enterprise policy (advanced; see the browser's extension-management docs).

## Locking it down (optional)

To stop a child from simply removing the extension:
- Use the device's **parental controls / supervised account** (Google Family Link, Apple
  Screen Time, Microsoft Family) to manage which extensions can be added/removed.
- On managed Chromium, an admin policy can **force-install** and prevent removal.

These are device-level controls outside this kit, but they're what make Layer 2 stick.
