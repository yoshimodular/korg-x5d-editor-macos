#!/bin/sh
# Forces Wine's own 16-bit modules to `native` so OTVDM's are the ones that get
# loaded.
#
#   ./win16-native.sh -n                 -> dry run, only prints what it would do
#   ./win16-native.sh                    -> applies it to the "X5D Editor" bottle
#   ./win16-native.sh "Other bottle"     -> another bottle
#
# Why: Wine ships around 50 of its own 16-bit modules (krnl386.exe16,
# mmsystem.dll16, user.exe16...) which are loaded with priority over OTVDM's and
# cannot work on ARM. Every one of them has to be forced to `native` in
# HKCU\Software\Wine\DllOverrides, and with the three name variants
# (mmsystem.dll16, mmsystem.dll, mmsystem) -- one alone is not enough.
#
# With krnl386 alone the editor starts but sees NO MIDI ports. The override that
# fixes that is mmsystem.
#
# Note: `regedit /S` does not import .reg files reliably here, hence `reg add`.
# And the wineserver keeps the registry in memory and rewrites it on exit, so
# close everything in the bottle before running this.

DRY=0
[ "$1" = "-n" ] && { DRY=1; shift; }
BOTTLE="${1:-X5D Editor}"

CX="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver"
LIB="$CX/lib/wine/i386-windows"
KEY='HKCU\Software\Wine\DllOverrides'

[ -d "$LIB" ] || { echo "CrossOver not found at $CX"; exit 1; }

n=0
for f in "$LIB"/*16; do
    b=$(basename "$f")            # e.g. mmsystem.dll16
    withext=${b%16}               # e.g. mmsystem.dll
    bare=${withext%.*}            # e.g. mmsystem
    for name in "$b" "$withext" "$bare"; do
        if [ "$DRY" = 1 ]; then
            echo "reg add $KEY /v $name /t REG_SZ /d native /f"
        else
            "$CX/bin/wine" --bottle "$BOTTLE" --wl-app reg add "$KEY" \
                /v "$name" /t REG_SZ /d native /f >/dev/null 2>&1
        fi
        n=$((n + 1))
    done
done

if [ "$DRY" = 1 ]; then
    echo "-- dry run: $n entries"
    exit 0
fi

# Stop the wineserver and wait for it to flush the registry to disk -- only
# this bottle's. `pkill -f wineserver` takes down every other CrossOver
# application that happens to be open, unsaved work and all.
sleep 2
for w in $(pgrep -x wineserver 2>/dev/null); do
    lsof -p "$w" 2>/dev/null | grep -qF "Bottles/$BOTTLE/" && kill "$w" 2>/dev/null
done
sleep 3
echo "$n overrides written to \"$BOTTLE\"."
