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
- [Settings](#settings)
- [Build](#build)
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

## Settings

Open the app's settings in the **Garmin Connect** app (phone) → *AXS-Counter*. Three actions can each be bound to one button combination, or left *Unassigned*:

| Setting | Action |
|---|---|
| **Increment** | counter +1 (default: FS 3 · short press) |
| **Decrement** | counter −1 (default: Unassigned) |
| **Reset** | counter → 0 (default: Unassigned) |

Each option is one of 16 combinations: Function Set 1–8 × short/long press. Changes take effect immediately while the field is running (no restart needed). If two actions are bound to the same combination, the priority is Increment > Decrement > Reset.

## Build

```
monkeyc -f src/project.jungle -d edge1050 -y ~/.Garmin/ConnectIQ/developer_key.der -o _gitignored/Builds/AXS-Counter.prg -w
```

Sideload the resulting `.prg` to the Edge (MTP → `Garmin/Apps`), then put the **Counter** field on a data page.

## Donations

**If you like my work please consider [supporting me](https://github.com/Chrismettal#donations)!**

## License

 <a rel="CClicense" href="http://creativecommons.org/licenses/by-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-sa/4.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/">Creative Commons Attribution-ShareAlike 4.0 International License</a>.
