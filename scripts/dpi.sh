#!/bin/sh
# Changes the scaling of the "X5D Editor" bottle.
#   ./dpi.sh 100   original size, no text is clipped
#   ./dpi.sh 125   / 150 / 175 / 200
# Close the editor before running it, and open it again afterwards.
#
# This enlarges the font, not the image: dialogs scale well because Windows
# measures them in units relative to the font, but the main window, which the
# program draws by hand in pixels, does not.
# A non-numeric argument used to make the arithmetic below yield 0 and write
# LogPixels = 0 into the registry, leaving the bottle with unusable fonts.
case "$1" in
    ''|*[!0-9]*) echo "usage: $0 <100|125|150|175|200>"; exit 1 ;;
esac
PCT=$1
[ "$PCT" -lt 50 ] || [ "$PCT" -gt 400 ] && { echo "The percentage must be between 50 and 400."; exit 1; }
DPI=$(( 96 * PCT / 100 ))
HEX=$(printf '%x' $DPI)
CX="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver"
for K in 'HKCU\Control Panel\Desktop' 'HKCU\Software\Wine\Fonts'; do
    "$CX/bin/wine" --bottle "X5D Editor" --wl-app reg add "$K" \
        /v LogPixels /t REG_DWORD /d $DPI /f >/dev/null 2>&1
done
# the wineserver keeps the registry in memory and rewrites it on exit, so it
# has to be stopped and the flush waited for
# Only THIS bottle's wineserver: killing them all takes down any other
# CrossOver application that happens to be open, without warning.
sleep 2
for w in $(pgrep -x wineserver 2>/dev/null); do
    lsof -p "$w" 2>/dev/null | grep -qF "Bottles/X5D Editor/" && kill "$w" 2>/dev/null
done
sleep 3
echo "Scaled to $PCT%  (LogPixels = $DPI, 0x$HEX). Restart the editor."
