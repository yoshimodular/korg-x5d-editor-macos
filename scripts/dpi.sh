#!/bin/sh
# Changes the scaling of the "X5D Editor" bottle.
#   ./dpi.sh 100   original size, no text is clipped
#   ./dpi.sh 125   / 150 / 175 / 200
# Close the editor before running it, and open it again afterwards.
#
# This enlarges the font, not the image: dialogs scale well because Windows
# measures them in units relative to the font, but the main window, which the
# program draws by hand in pixels, does not.
[ -z "$1" ] && { echo "usage: $0 <100|125|150|175|200>"; exit 1; }
PCT=$1
DPI=$(( 96 * PCT / 100 ))
HEX=$(printf '%x' $DPI)
CX="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver"
for K in 'HKCU\Control Panel\Desktop' 'HKCU\Software\Wine\Fonts'; do
    "$CX/bin/wine" --bottle "X5D Editor" --wl-app reg add "$K" \
        /v LogPixels /t REG_DWORD /d $DPI /f >/dev/null 2>&1
done
# the wineserver keeps the registry in memory and rewrites it on exit, so it
# has to be stopped and the flush waited for
sleep 2; pkill -f wineserver 2>/dev/null; sleep 3
echo "Scaled to $PCT%  (LogPixels = $DPI, 0x$HEX). Restart the editor."
