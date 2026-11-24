# PicoSwitch (Macro build)

Raspberry Pi Pico firmware (RP2350, or RP2040 for the Pico 1): Switch gamepad + USB keyboard macro that types the CIV7 chat-XSS payload once, ~10 s after boot (`MACRO_START_DELAY_MS` in `include/MacroEngine.h`).
LED is lit while the macro runs.
On Pico W and Pico 2 W, the CYW43 wireless chip is initialized to control the onboard LED; the default macro still uses USB, not Bluetooth.

## Payload pipeline

```
<payload.js>                      any JS for the chat XSS (loader bootstrap etc.)
  -> python tools/make_payload.py <payload.js>     stages it verbatim (CRLF-normalized)
  -> ../core.js
  -> node compress.js              terser -> deflateRaw -> base-25 chunked lines (<=254 chars)
  -> payload.txt
  -> cmake --build <build>         payload_to_macro.py -> include/macro_script.h -> firmware
```

The chat eval context is synchronous: the payload must not use top-level await (`node --check core.js` must pass).
If yours needs it, wrap it in its own `(async function(){ ...
})();` before staging.

The shipped `../core.js`/`payload.txt` carry the **Remote JS Loader** bootstrap (exploit core + TCP loader on :9026): ~87 typed lines, ~20 min.
After it runs, send the persistent installer from the PC with `../installer-creator/`.

## Build

All boards build from this one tree via `CMakePresets.json` — `pico2`, `pico2_w`, `pico1`, and `pico1_w` (the SDK calls the latter board `pico_w`) — each into its own build directory. Pico 1 and Pico W use RP2040; Pico 2 and Pico 2 W use RP2350.

Needs the pico-sdk (set `PICO_SDK_PATH`; 2.3.1), ARM toolchain, Ninja, Node + terser, and a modern host gcc.

```
cd PicoSwitch
npm install                                        # terser for compress.js
node compress.js                                   # reads ../core.js -> payload.txt (<=254-char lines)
python tools/make_payload.py <payload.js>         # optional: stage a custom payload into ../core.js
export PICO_SDK_PATH=<sdk>
cmake --preset pico2 && cmake --build --preset pico2
cmake --preset pico2_w && cmake --build --preset pico2_w
cmake --preset pico1 && cmake --build --preset pico1
cmake --preset pico1_w && cmake --build --preset pico1_w
```

Default builds type US-layout keystrokes. For JP consoles build the JIS variant (the layout is compiled into the macro - one UF2 per console region): `cmake -B build-pico2-jis -G Ninja -DPICO_BOARD=pico2 -DCIV7_TARGET_NAME=civ7-pico2-jis -DCIV7_KEYBOARD_LAYOUT=jis && cmake --build build-pico2-jis`. For Pico W use `-DPICO_BOARD=pico_w -DCIV7_TARGET_NAME=civ7-pico1_w-jis -B build-pico1_w-jis` instead.

On Ubuntu 24.04 the full toolchain installs with `sudo apt install -y git build-essential cmake ninja-build gcc-arm-none-eabi libnewlib-arm-none-eabi libstdc++-arm-none-eabi-newlib python3 nodejs npm`.
Or build all eight variants at once (payload + pico1/pico1_w/pico2/pico2_w x us/jis) with `./build_all.sh`.
On Windows, prefix the cmake commands with a modern mingw FIRST on PATH (`PATH=<modern-mingw>/bin:$PATH cmake ...`) — CMake may otherwise pick an ancient host gcc that cannot build pioasm.

UF2 generation does not use picotool (its `uf2 convert` segfaults on some hosts): the build packs the UF2 straight from the .bin with `pack_uf2.py`, byte-identical to picotool's output on both platforms (rp2040 data blocks; rp2350-arm-s data blocks plus the RP2350-E10 abs block with its RP2-ignore-block extension tag). To pack one manually:

```
<toolchain>/arm-none-eabi-objcopy -Obinary build-pico2/src/civ7-pico2.elf build-pico2/src/civ7-pico2.bin
python tools/pack_uf2.py build-pico2/src/civ7-pico2.bin civ7-pico2.uf2 [rp2040|rp2350]
```

## Macro shape

Preamble: gamepad A x5.
Per payload line: Esc, wait 750 ms, A, wait 550 ms, type line, Enter x2, then A between batches.
Timings are hardware-tested constants at the top of `tools/payload_to_macro.py` - do not lower without re-testing.
