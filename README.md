# Korg X5D sound editor on Apple Silicon

How to run **Korg's original 1995 sound editor** — a 16-bit Windows 3.x binary —
on a modern Apple Silicon Mac, with **working bidirectional CoreMIDI**, plus
tools for the `.X5` bank file format.

`SE05.EXE`, the editor shipped with the Korg X5D / X5 / 05R/W, is an **NE
executable**: a real 16-bit Windows 3.x program, not the Win95 32-bit one its
date might suggest. Getting it to talk to a synthesizer from an M-series Mac
takes four separate things to line up, and every one of them fails silently when
it is missing.

> **No Korg software is included here.** `SE05.EXE`, `GMREFW.EXE`, the multis and
> the sound banks are Korg's and are not distributed in this repository. Neither
> are the Microsoft DLLs mentioned below — those come from your own copies. What
> is here is documentation, the reverse-engineered file format, and the code
> written to make it work.

---

## Why the obvious routes fail

- **Wine** has no usable 16-bit support on ARM. Its own Win16 modules exist, but
  they cannot run on Apple Silicon.
- **Parallels does not help either.** Windows 11 on ARM does not ship NTVDM, so
  there is no 16-bit subsystem inside the VM to run the program in.
- **OTVDM / winevdm works**, because it does not emulate: it reimplements the
  Win16 subsystem as a **32-bit application**, which runs under **Rosetta 2**.
  Native window, system mouse, direct CoreMIDI. There is no need to emulate a
  whole PC.

Full recipe: [`docs/otvdm-crossover.md`](docs/otvdm-crossover.md).

## The four required pieces

All four are necessary. Three are runtime libraries; the fourth is the one
nobody documents.

1. **`msvbvm60.dll`** — the VB6 runtime, extracted from the CAB inside
   `vbrun60sp6.exe` **without running it**, using the `cabextract` that ships
   with CrossOver.
2. **`MFC40.DLL`** — from `BASE4.CAB` of a Windows 98 CD.
3. **The 15 32-bit `api-ms-win-crt-*.dll`** — these are *not* in the modern VC++
   redistributable, which assumes Windows 10 provides them. They have to come
   from **VC++ 2015 RTM x86**: extract the bundle with `cabextract` and rename
   the resulting `api_ms_..._.dll` files (underscores) to hyphens.
4. **The key one — force Wine's built-in 16-bit modules to `native`.** Wine
   ships around 50 of its own 16-bit modules (`krnl386.exe16`, `mmsystem.dll16`,
   `user.exe16`…) that are loaded **with priority over OTVDM's** and cannot work
   on ARM. Every one of them must be set to `native` in
   `HKCU\Software\Wine\DllOverrides`, **with all three name variants**:
   `mmsystem.dll16`, `mmsystem.dll` and `mmsystem`.

   With `krnl386` alone the editor starts, but it **sees no MIDI ports at all**.
   The override that fixes the MIDI is **`mmsystem`**.

[`scripts/win16-native.sh`](scripts/win16-native.sh) applies step 4: it
enumerates the `*16` modules of the installed CrossOver and writes the three
variants of each with `reg add` (`-n` for a dry run first).

## SysEx: the separate fix you also need

Bank dumps do not work out of the box, and the failure is invisible.

**Wine silently discards every SysEx message longer than 498 bytes on macOS and
returns `MMSYSERR_NOERROR`.** The application believes it has sent the dump. A
bank is 15,549 bytes, so nothing ever arrives. The bug is in
`dlls/winecoreaudio.drv/coremidi.c` (`midi_send` builds the CoreMIDI packet list
in a fixed 512-byte buffer with a single `MIDIPacketListAdd` call) and it has
been unfixed since 2015. There is a second, independent ceiling underneath it:
CoreMIDI truncates any SysEx handed to `MIDISend` in one call at 12,001 bytes,
also without error — which is why the message has to be **split**, not merely
given a bigger buffer.

The fix — a `winmm` proxy DLL that chunks long messages before they reach Wine,
plus the measurements behind the diagnosis — lives in its own repository,
because it is useful to anyone running any MIDI editor under Wine or CrossOver
on macOS:

**→ https://github.com/yoshimodular/wine-coreaudio-sysex-fix**

Without it, everything else here works except transmitting banks.

## Time-wasting traps

- **The `wineserver` keeps the registry in memory** and rewrites it on exit,
  stomping on any change made from outside. Stop it and wait for the flush
  between writes.
- **`regedit /S` does not import `.reg` files reliably** here. Use `reg add`.
- **`cxmenu` entries of `--type raw` run in the macOS shell**, not in Wine, so a
  `C:\...` command does nothing. Point them at a native script, or copy an
  `.app` of your own.
- **Do not install Windows fonts in the bottle.** Copying the 46 originals from
  Windows 98 to fix clipped text **makes it worse**: the editor computes the
  height of its panels from the text metrics, and with different fonts some
  blocks are drawn half-finished. Leaving only four still left it broken. The
  bottle's `Fonts` folder must be empty.
- The `winmm` override goes as **`native,builtin`**, never plain `native`:
  without the fallback, any process that cannot find the native DLL is left with
  no `winmm` at all.
- **Updating CrossOver overwrites the patched DLL**, so the proxy has to be
  reinstalled afterwards.

## Known issues

| | |
|---|---|
| Startup, editing, exit | fine |
| MIDI ports, reception | fine |
| Bank dumps | fine, **with the `winmm` proxy** (separate repo, above) |
| Some clipped text strings | **unresolved.** Specific strings in tight places stay clipped. Ruled out: the scaling and the fonts (installing the original Windows fonts makes it worse). The cause is not known. |
| Bands left undrawn | solved with `redraw.exe` |
| Scaling | the font scales, the hand-drawn main window does not — see below |

**Scaling** is raised with `LogPixels` (96 = 100%, 192 = 200%) in
`HKCU\Control Panel\Desktop` and `HKCU\Software\Wine\Fonts`;
[`scripts/dpi.sh`](scripts/dpi.sh) does it. That enlarges the *font*, not the
image. Dialogs scale well because Windows measures them in units relative to the
font; the main window, which the program draws by hand in pixels, does not.
Neither Wine nor OTVDM can scale up the already-drawn image, which is the only
thing that would preserve the layout.

---

## The `.X5` bank format

The most reusable thing here: the bank file layout and Korg's SysEx packing,
worked out by measuring the files, because it is documented nowhere.

**→ [`docs/x5-bank-format.md`](docs/x5-bank-format.md)** — offsets, the 7→8
packing with its LSB-first bit order, the function numbers, and how it was
verified.

In short: a `.X5` / `.05R` file is always **30,891 bytes** and holds the data
**raw, exactly as it travels over SysEx**, only unpacked — an 862-byte editor
header, 100 programs of 136 bytes, 100 combinations of 164 bytes, and 29 bytes
of global data. Each program and combination starts with a 10-character ASCII
name, which makes the alignment checkable at a glance.

## Two findings that apply to any old Windows app under CrossOver

**→ [`docs/wine-macos-notes.md`](docs/wine-macos-notes.md)**

- **Incomplete repaints.** Panels come out cut off halfway down; minimizing and
  restoring fixes them, which is what proves it is a repaint problem and not a
  layout one. `redraw.exe` forces the same invalidation from outside. It polls
  because **`SetWinEventHook` installs fine under Wine and delivers no events at
  all** — verified by triggering them deliberately.
- **Leftover processes.** Wine leaves nine processes alive after the application
  exits, spinning at 1.5% CPU each, forever. `wineserver -k`, `wineboot -k` and
  `cxreboot` do not touch them. They can be identified per bottle with `lsof`
  and killed.

---

## Tools

Everything here is standalone: Python 3 with no dependencies, and one C file.

### `tools/x5syx` — bank → SysEx

```sh
# list the 100 programs and 100 combinations of a bank
python3 tools/x5syx M1.X5 --list

# whole bank to a single .syx (programs 0x4C + combinations 0x4D)
python3 tools/x5syx M1.X5 -o M1.syx
# -> M1.syx  34298 bytes  [prog 0x4C 15549B, combi 0x4D 18749B]  channel 1

# a synth on global MIDI channel 3, one file per block
python3 tools/x5syx M1.X5 -c 3 --split

# programs only
python3 tools/x5syx M1.X5 --only prog
```

The global data block (`0x55`) is **omitted by default** because it would
overwrite the synth's tuning and MIDI settings; `--global` includes it.

### `tools/mltsyx` — `.MLT` multi → SysEx

```sh
# one file
python3 tools/mltsyx MULTI00.MLT -o out/

# a whole directory, dropping the global block and retargeting the channel
python3 tools/mltsyx Multi/ -o out/ --no-global -c 3
```

### `tools/redraw.c` — force a full repaint

```sh
brew install mingw-w64
i686-w64-mingw32-gcc -O2 -o redraw.exe tools/redraw.c -lgdi32 -luser32
```

Copy `redraw.exe` into the bottle's `drive_c` and run it inside Wine:

```
redraw.exe              one pass and exit
redraw.exe -w           watch and repaint whenever something changes
redraw.exe -w -e 5000   plus a safety pass every 5 s
redraw.exe -k           minimize and restore (the manual remedy)
redraw.exe -t "text"    another window-title text (default: SoundEditor)
```

It exits by itself when the editor closes, so it never becomes one of the
leftover processes described above.

### `scripts/`

| Script | What it does |
|---|---|
| [`win16-native.sh`](scripts/win16-native.sh) | writes the `native` overrides for all of Wine's 16-bit modules, three name variants each (`-n` = dry run) |
| [`dpi.sh`](scripts/dpi.sh) | changes the bottle's scaling: `./dpi.sh 150` |
| [`wine-cleanup.sh`](scripts/wine-cleanup.sh) | kills the processes Wine leaves behind, only those of one bottle, identified with `lsof` |
| [`launch-editor.sh`](scripts/launch-editor.sh) | starts the editor through OTVDM, launches the repaint watcher, and sweeps the bottle on exit |

The scripts assume CrossOver in `/Applications` and a bottle named
`X5D Editor`; both are one edit away at the top of each file.

## Repository layout

```
docs/
  otvdm-crossover.md    the full recipe: the four pieces, the traps, scaling
  x5-bank-format.md     the .X5 format and Korg's SysEx packing
  wine-macos-notes.md   repainting and leftover processes under CrossOver
  es/                   the Spanish originals of the three documents
tools/
  x5syx                 .X5 / .05R bank -> SysEx
  mltsyx                .MLT multi -> SysEx
  redraw.c              forces a full repaint from outside the process
scripts/                overrides, scaling, cleanup, launcher
```

The documentation was written in Spanish first; the originals are kept in
[`docs/es/`](docs/es/) since translations drift.

## License

[MIT](LICENSE), © 2026 Antonio Escobar — **covering the code and documentation
in this repository only**. The Korg editor software is not included here and is
not distributed by this project.
