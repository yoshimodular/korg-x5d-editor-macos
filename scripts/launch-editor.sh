#!/bin/sh
# Korg's original editor (SE05.EXE, 16-bit) through OTVDM in the patched bottle.
#
# The "X5D Editor" bottle carries: msvbvm60, MFC40, the api-ms-win-crt-* set,
# and the overrides that force Wine's own 16-bit modules to native -- which is
# what stops Wine from loading its own 16-bit stubs (incompatible with Apple
# Silicon) instead of OTVDM's. It also carries the winmm proxy that splits long
# sysex messages; see the README.
CX="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin"
PREFIX="$HOME/Library/Application Support/CrossOver/Bottles/X5D Editor"

# if a previous session was left hanging, clear it before starting
pkill -f "winedbg --auto" 2>/dev/null

# The editor leaves bands unpainted when a bank is loaded or the program is
# changed: it draws up to a point and the rest stays blank. Minimizing and
# restoring fixes it, because that invalidates the whole client area.
# redraw.exe does the same from outside whenever it detects something changed.
# It exits by itself when the editor is closed.
( sleep 8
  "$CX/cxstart" --bottle "X5D Editor" --workdir "C:\\" -- "C:\\redraw.exe" -w \
      >/dev/null 2>&1 ) &

"$CX/cxstart" --bottle "X5D Editor" --workdir "C:\\OTVDM" -- \
     "C:\\OTVDM\\otvdmw.exe" "C:\\OTVDM\\KORG\\SE05.EXE"

# On exit, Wine leaves the bottle "warm": explorer.exe stays alive as the shell
# and with it services, plugplay, rpcss, svchost and two winedevice.exe,
# spinning at 1.5% CPU each, indefinitely and with no timeout. Neither
# `wineserver -k` nor `cxreboot` closes them. Here we wait for the editor to
# finish and then sweep the bottle.
sleep 3
while pgrep -f "otvdmw.exe" >/dev/null 2>&1; do sleep 2; done

# do not sweep if SoundTower is still open; it shares the bottle
if ! pgrep -f "X5DEdPro.exe" >/dev/null 2>&1; then
    [ -x /Applications/KORG/x5d/wine-cleanup.sh ] && \
        /Applications/KORG/x5d/wine-cleanup.sh "X5D Editor" >/dev/null 2>&1
fi
