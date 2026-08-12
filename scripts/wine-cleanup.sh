#!/bin/sh
# Closes the processes Wine leaves alive after an application exits.
#
#   ./wine-cleanup.sh                 -> only the "X5D Editor" bottle
#   ./wine-cleanup.sh "SoundDiver"    -> another bottle
#   ./wine-cleanup.sh --all           -> every bottle
#
# Why this is needed: when the application is closed, Wine leaves the bottle
# "warm" so the next start is fast. explorer.exe (the shell), services.exe,
# plugplay.exe, rpcss.exe, svchost.exe and two winedevice.exe stay alive,
# spinning at 1.5% CPU each, indefinitely and with no timeout. CrossOver has no
# command to shut a bottle down (cxreboot only simulates a Windows restart) and
# `wineserver -k` does not find its server because CrossOver does not use the
# standard WINEPREFIX. So they have to be killed -- but only those of the given
# bottle, which is worked out with lsof.

BOTTLE="${1:-X5D Editor}"

if [ "$BOTTLE" = "--all" ] || [ "$BOTTLE" = "--todas" ]; then
    PATTERN="Bottles/"
else
    # The trailing slash matters: without it "X5D Editor" also matched
    # "X5D Editor 2" and killed the wrong bottle's processes.
    PATTERN="Bottles/$BOTTLE/"
fi

killed=0
for p in $(ps ax | grep "[.]exe" | awk '{print $1}'); do
    # which bottle does this process belong to (-F: a bottle name is a literal
    # path, not a regex; metacharacters in it would otherwise mis-match)
    if lsof -p "$p" 2>/dev/null | grep -qF "$PATTERN"; then
        kill -9 "$p" 2>/dev/null && killed=$((killed + 1))
    fi
done

# that bottle's wineserver, if it was left loose
for p in $(pgrep -x wineserver 2>/dev/null); do
    if lsof -p "$p" 2>/dev/null | grep -qF "$PATTERN"; then
        kill -9 "$p" 2>/dev/null && killed=$((killed + 1))
    fi
done

echo "Closed $killed processes. $(ps ax | grep -c '[.]exe') left in total."
