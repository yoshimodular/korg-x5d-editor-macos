# Notes on Wine under macOS: repainting and leftover processes

Two things that are not specific to this editor and will probably affect any
old application under CrossOver.

*(Spanish original: [`es/notas-macos-wine.md`](es/notas-macos-wine.md).)*

---

## Bands left undrawn

When loading a bank or switching program, some boxes come out cut off halfway
down, with blank space below. **Which ones get lost varies** depending on what
is loaded.

**Ruled out, with evidence:**

- **Not the scaling.** It happens the same at 100% and at 200%.
- **Not the fonts.** It happens with the `Fonts` folder empty.
- **Not tight-fitting containers.** If it were, the same ones would always
  fail; they change from bank to bank.
- **Not OTVDM's `PeekMessageSleep`.**

**It is an incomplete repaint.** The fact that proves it: **minimizing and
restoring the window fixes it**. The program knows how to draw it; the first
paint stops short. On restore, Windows invalidates the whole client area and it
gets redrawn in full.

### The fix

`redraw.exe` calls `RedrawWindow` with
`RDW_INVALIDATE | RDW_ERASE | RDW_ALLCHILDREN | RDW_UPDATENOW` on every visible
window of the process — the main one and its dialogs, which suffer the same
thing.

### Why it polls instead of using events

**`SetWinEventHook`** was tried, which is the correct way on Windows to find out
from another process without polling. Under Wine the hook **installs without
error and not a single event arrives**. Verified by triggering the events
deliberately: minimizing and restoring the window from outside, the shake works
and the watcher receives nothing. **Wine does not emit them.**

Polling costs two calls every 400 ms — the window title and how many windows the
process has — which change when a bank is loaded, a program is switched or a
dialog is opened. It is unnoticeable.

Source and build instructions: [`../tools/redraw.c`](../tools/redraw.c).

---

## Wine's processes do not exit on their own

When the application is closed, **nine processes** stay alive: `explorer.exe`
(the bottle's shell) and with it `services.exe`, `plugplay.exe`, `rpcss.exe`,
`svchost.exe` and two `winedevice.exe`, **spinning at 1.5% CPU each**,
indefinitely and with no timeout. With several sessions accumulated you end up
with four complete sets.

That is Wine's design: it leaves the bottle warm so the next start is fast. But
it never shuts it down.

**None of the obvious routes work:**

- `wineserver -k` returns an error — CrossOver does not locate its server
  through the standard `WINEPREFIX`.
- `wineboot -k` does not touch them.
- `cxreboot` only simulates a Windows restart.
- CrossOver has no command to shut a bottle down.

On top of that, if the `wineserver` is killed brutally (for example to force the
registry to be flushed to disk), its services are left **orphaned**: there is no
longer anyone that can tell them to exit, and from then on not even a later
`wineserver -k` reaches them.

### The fix

Kill them, but only those of the bottle in question. Which bottle each process
belongs to is identified with **`lsof`**:

```sh
for p in $(ps ax | grep "[.]exe" | awk '{print $1}'); do
    lsof -p "$p" 2>/dev/null | grep -q "Bottles/$BOTTLE" && kill -9 "$p"
done
```

That is what [`../scripts/wine-cleanup.sh`](../scripts/wine-cleanup.sh) does,
and the launcher invokes it on exit. Measured: 2 processes before opening → 11
with the editor open → **2** five seconds after closing it.
