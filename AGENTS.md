# AGENTS.md

Project instructions for AI agents working in this repository.

## Build

- One `.prg` per target device. Output directory: `build/` (gitignored).
- Supported device ids: `edge540`, `edge550`, `edge840`, `edge850`, `edge1040`, `edge1050`, `edge1060`.
- SDK 9.3.0 lives in `~/.Garmin/ConnectIQ/Sdks/`; the compiler is `~/.Garmin/ConnectIQ/Sdks/bin/monkeyc`.
- Signing key: `~/.Garmin/ConnectIQ/developer_key.der`.
- Build command (Linux, from repo root):

      monkeyc -f src/project.jungle -d <device> -y ~/.Garmin/ConnectIQ/developer_key.der -o build/AXS-Counter-<device>.prg -w

- `monkeyc` always needs `-f src/project.jungle` and `-y <key>`.
- **`edge1060` device profile:** not shipped in SDK 9.3.0's device set (device profiles come from Garmin's cloud via the SDK Manager login). The profile at `~/.Garmin/ConnectIQ/Devices/edge1060/` is a clone of `edge1050` (same device family: 480×800, API 6.0) with the device id renamed in `compiler.json` and the `.bin`/`.api.debug.xml` files renamed. The compiler accepts it. If the official profile ever becomes available via the SDK Manager, replace the clone.

## Release

Releases are manual (no CI). One `.prg` per device, attached to a GitHub release.

1. Build every target into `build/`, naming the output `AXS-Counter-<device>.prg`:

       for d in edge540 edge550 edge840 edge850 edge1040 edge1050 edge1060; do
         monkeyc -f src/project.jungle -d $d \
           -y ~/.Garmin/ConnectIQ/developer_key.der \
           -o build/AXS-Counter-$d.prg
       done

2. Create the release with `gh` (installed on the dev machine) and attach all `.prg` files:

       gh release create vX.Y.Z \
         build/AXS-Counter-edge540.prg \
         build/AXS-Counter-edge550.prg \
         build/AXS-Counter-edge840.prg \
         build/AXS-Counter-edge850.prg \
         build/AXS-Counter-edge1040.prg \
         build/AXS-Counter-edge1050.prg \
         build/AXS-Counter-edge1060.prg \
         --title "vX.Y.Z" --notes "..."

3. If the supported device list changes, update the Sideloading table in `README.md`, the Build section, and the manifest products.

## Conventions

- Work directly on `master`; commit small, focused changes.
