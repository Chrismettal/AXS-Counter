# AXS-Counter <!-- omit in toc -->

[![License: CC BY-SA 4.0](https://img.shields.io/badge/license-CC%20BY--SA%204.0-blue?style=flat-square)](https://creativecommons.org/licenses/by-sa/4.0/)
[![Shop: Elecrow](https://img.shields.io/badge/shop-Elecrow-blue?style=flat-square)](https://www.elecrow.com/store/Binary-6)
[![Donations: Coffee](https://img.shields.io/badge/donations-Coffee-brown?style=flat-square)](https://github.com/Chrismettal#donations)

ConnectIQ data field for **Garmin Edge devices** that counts **SRAM Force AXS bonus-button** presses over `ANT+`.

Used like these clicker counters to count arbitrary numbers during cycling. (How many peoples did I pass? How many turns did I have in the group ride?)

**If you like my work please consider [supporting me](https://github.com/Chrismettal#donations)!**

## Table of contents <!-- omit in toc -->

- [Concept](#concept)
- [How it works](#how-it-works)
- [Recording to the activity](#recording-to-the-activity)
- [Settings](#settings)
  - [How to open the settings](#how-to-open-the-settings)
- [Build](#build)
- [AI Usage](#ai-usage)
- [Donations](#donations)
- [License](#license)

## Concept

A big number on a data page that changes when you press the SRAM bonus buttons. A dot in the corner shows the ANT+ link: **green** while the shifter is broadcasting, **red** when no frames are arriving (SRAM asleep, out of range, or channel lost).

Each of the three actions — **Increment**, **Decrement** and **Reset** — can be bound to any of the bonus-button combinations (ANT+ Function Set 1–8 × short/long press), or left unassigned. Defaults: Increment = **FS 3 · short press** (both buttons), Decrement and Reset unassigned. No persistence — the counter resets to 0 when the field is restarted.

## How it works

The bonus buttons are exposed by SRAM as ANT+ *function sets* on the **Shifting profile (device type 0x22)**. The shifter broadcasts a **data page 2** frame about once per second while it is awake:

```
[2, counter, newest, e2, e3, e4, e5, 0]
```

- byte 0 = `2` (button page)
- byte 1 = event counter, increments on every press
- bytes 2..6 = last 5 events, most recent first
- event byte = `functionSet | (longPress ? 0x20 : 0)` — `1` = left, `2` = right, `3` = both; `33`/`34`/`35` = long presses

The app taps the Edge's **native ANT+ Shifting channel** (`AntPlus.Shifting` + `ShiftingListener.onMessage`) — no raw channel, no device number, no background scan. A new press is detected by the event counter changing; the newest event is then byte 2.

Requirements:

- The Edge is already paired to the SRAM on its built-in shifting channel.
- The SRAM is awake and the bonus buttons are mapped to ANT+ Function Sets in the SRAM AXS app (SRAM currently exposes FS 1–3; the settings allow binding any FS 1–8).

## Recording to the activity

While an activity is recording, the counter is written into the activity's `.fit` file as [developer data](https://developer.garmin.com/connect-iq/core-topics/activity-recording/) (`Toybox.FitContributor`):

- **Per-second timeline** (record messages) → appears as a chart on the activity details page in Garmin Connect.
- **Final value** (session message) → appears in the activity summary.

The field must be on a visible data page during the ride for the timeline to be sampled.

> **Note:** the data is written to the `.fit` file regardless of how the app was installed, but **Garmin Connect only renders developer data for apps installed from the Connect IQ App Store** (a beta install qualifies). Sideloaded builds record the data, but Connect has no display metadata for it — inspect the `.fit` directly (e.g. [fitfileviewer.com](https://www.fitfileviewer.com/)) to verify. The same restriction applies to the phone settings dialog.

## Settings

Each of the three actions can be bound to one button combination, or left *Unassigned*:

| Setting | Action |
|---|---|
| **Increment** | counter +1 (default: FS 3 · short press) |
| **Decrement** | counter −1 (default: Unassigned) |
| **Reset** | counter → 0 (default: Unassigned) |

Each option is one of 16 combinations: Function Set 1–8 × short/long press. Changes take effect immediately while the field is running (no restart needed). If two actions are bound to the same combination, the priority is Increment > Decrement > Reset.

### How to open the settings

On the Edge, the settings are **on-device** (data fields cannot push other UI, but the framework offers this one view). Open them from the data page:

1. On a data page that shows the **Counter** field, **swipe up** to open the page menu.
2. Select **ConnectIQ Fields** → **AXS-Counter**.
3. The root menu lists *Increment*, *Decrement* and *Reset*, each showing its current binding. Select one to open its 17-option submenu (Unassigned + FS 1–8 × short/long). Pick an option and it is saved and applied immediately; **Back** returns to the root menu.

The same prompt also appears when you first **add** the field to a data page ("Configure this field?").

> **Note on the phone dialog:** the `properties.xml` settings (the same three values) are also defined so that, if the app is installed from the **Connect IQ App Store** (e.g. as a beta app), the standard **Garmin Connect** phone settings dialog appears. Sideloaded `.prg` files do *not* get the phone settings button — the on-device menu above is the path that works with sideloading.

## Build

```
monkeyc -f src/project.jungle -d edge1050 -y ~/.Garmin/ConnectIQ/developer_key.der -o _gitignored/Builds/AXS-Counter.prg -w
```

Sideload the resulting `.prg` to the Edge (MTP → `Garmin/Apps`), then put the **Counter** field on a data page.

## AI Usage

This codebase was mostly meatproxied through `Qwen3.8-27B:Q4_K_XL` at `100k` context running on a `7900XTX` locally.

## Donations

**If you like my work please consider [supporting me](https://github.com/Chrismettal#donations)!**

## License

 <a rel="CClicense" href="http://creativecommons.org/licenses/by-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-sa/4.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/">Creative Commons Attribution-ShareAlike 4.0 International License</a>.
