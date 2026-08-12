# The 16-bit Korg editor under CrossOver, with MIDI

`SE05.EXE` is a **Windows 3.x (16-bit) NE executable**, not a Win95 one as its
date might suggest. That rules Wine out directly — it has no usable 16-bit
support on ARM — and also Parallels on Apple Silicon, because Windows 11 ARM
does not ship NTVDM.

**It does work** with **OTVDM/winevdm**, which reimplements the Win16 subsystem
as a **32-bit** application and therefore runs under Rosetta 2. Native window,
system mouse and direct CoreMIDI. There is no need to emulate a whole PC.

*(Spanish original: [`es/otvdm-crossover.md`](es/otvdm-crossover.md).)*

## The four pieces

All four are necessary:

1. **`msvbvm60.dll`** (the VB6 runtime) — extracted from the CAB inside
   `vbrun60sp6.exe` **without running it**, using the `cabextract` that ships
   with CrossOver.
2. **`MFC40.DLL`** — from `BASE4.CAB` of a Windows 98 CD.
3. **The 15 32-bit `api-ms-win-crt-*.dll`** — these do not come with the modern
   VC++ redistributable, which assumes Windows 10 provides them. They have to be
   taken from **VC++ 2015 RTM x86**, extracting the bundle with `cabextract` and
   renaming the `api_ms_..._.dll` files (underscores) to hyphens.
4. **The key one:** Wine ships **its own 16-bit modules** (`krnl386.exe16`,
   `mmsystem.dll16`, `user.exe16`… — about 50 of them) which are loaded **with
   priority over OTVDM's** and cannot work on ARM. All of them must be forced to
   `native` in `HKCU\Software\Wine\DllOverrides`, with the three name variants
   (`mmsystem.dll16`, `mmsystem.dll`, `mmsystem`).

With `krnl386` alone the program starts but **sees no MIDI ports at all**. The
one that fixes that is `mmsystem`.

> None of those DLLs are Microsoft-redistributable in this context, so none of
> them are included in this repository. They come from your own copies.

The overrides can be applied with
[`../scripts/win16-native.sh`](../scripts/win16-native.sh), which enumerates the
`*.16` modules of the installed CrossOver and writes the three variants of each
with `reg add`.

## Traps that cost time

- **The `wineserver` keeps the registry in memory** and rewrites it on exit,
  stomping on changes made from outside. It has to be stopped, and the flush
  waited for, between writes.
- **`regedit /S` does not import `.reg` files reliably** here. Use `reg add`.
- **`cxmenu` entries of `--type raw` run in the macOS shell**, not in Wine, so a
  `C:\...` command does not work: you have to point at a native script or copy
  an `.app` of your own.

## Scaling

It is raised with `LogPixels` (96 = 100%, 192 = 200%) in
`HKCU\Control Panel\Desktop` and `HKCU\Software\Wine\Fonts`. The
[`../scripts/dpi.sh`](../scripts/dpi.sh) script does it.

That enlarges the font, not the image. Dialogs scale well because Windows
measures them in units relative to the font; the main window, which the program
draws by hand in pixels, does not. Neither Wine nor OTVDM knows how to scale up
the already-drawn image, which is the only thing that would preserve the layout.

## Do not install Windows fonts

Copying the 46 original Windows 98 fonts to fix clipped text was tried and it
**makes things worse**: the editor computes the height of its panels from the
text metrics, and with a different font some blocks are drawn half-finished.
Leaving only four fonts still left it broken. **The bottle's `Fonts` folder must
be empty.**

## What fails and what does not

| | |
|---|---|
| Startup, editing, exit | fine |
| MIDI ports, reception | fine |
| Bank dumps | fine, **with the winmm proxy** (see the main README) |
| Some clipped text | stays like that; specific strings in tight places |
| Bands left undrawn | solved with `redraw.exe` |
