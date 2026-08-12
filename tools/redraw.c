/* redraw - forces a full repaint of the Korg editor's windows.
 *
 * The editor leaves bands unpainted: it draws up to a point and what is left
 * shows as blank, and which ones get lost depends on the bank loaded.
 * Minimizing and restoring fixes it, because that invalidates the whole client
 * area and the program draws it again in full. Here the same thing is done
 * with RedrawWindow, without moving the window.
 *
 * WHY IT POLLS INSTEAD OF USING EVENTS: SetWinEventHook was tried, which is the
 * correct way on Windows to find out from another process. Under Wine the hook
 * installs without error but **not a single event arrives**, not even when
 * minimizing and restoring the window on purpose. Wine does not emit them.
 * Polling costs two calls every 400 ms, which is unnoticeable.
 *
 * What is watched is the window title and the number of windows of the process:
 * they change when a bank is loaded, when the program is switched and when a
 * dialog is opened, which is exactly when the drawing falls short.
 *
 *   redraw.exe              one pass and exit
 *   redraw.exe -w           watch and repaint whenever something changes
 *   redraw.exe -w -e 5000   plus a safety pass every 5 s
 *   redraw.exe -k           minimize and restore (the manual remedy)
 *   redraw.exe -t "text"    another window-title text (def. SoundEditor)
 *
 * Build (macOS: brew install mingw-w64):
 *   i686-w64-mingw32-gcc -O2 -o redraw.exe redraw.c -lgdi32 -luser32
 */

#define _WIN32_WINNT 0x0501
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char *wanted = "SoundEditor";
static DWORD editor_pid = 0;
static int   painted = 0;

static BOOL CALLBACK find_main(HWND h, LPARAM lp)
{
    char t[256];
    (void)lp;
    if (!IsWindowVisible(h)) return TRUE;
    if (!GetWindowTextA(h, t, sizeof(t))) return TRUE;
    if (strstr(t, wanted)) {
        GetWindowThreadProcessId(h, &editor_pid);
        return FALSE;
    }
    return TRUE;
}

/* repaints every visible window of the process: the main one and its dialogs
 * (Program Parameters, Drum Kit Parameters...), which suffer the same thing */
static BOOL CALLBACK repaint(HWND h, LPARAM lp)
{
    DWORD p = 0;
    (void)lp;
    if (!IsWindowVisible(h) || IsIconic(h)) return TRUE;
    GetWindowThreadProcessId(h, &p);
    if (p != editor_pid) return TRUE;
    RedrawWindow(h, NULL, NULL,
                 RDW_INVALIDATE | RDW_ERASE | RDW_ALLCHILDREN | RDW_UPDATENOW);
    painted++;
    return TRUE;
}

static int pass(void)
{
    painted = 0;
    EnumWindows(repaint, 0);
    return painted;
}

/* Fingerprint of the visible state: how many windows the process has and how
 * the first one is titled. editor_pid is zeroed before searching, so that when
 * the editor closes the watcher notices and exits instead of spinning on --
 * exactly the kind of zombie process to be avoided here. */
static void fingerprint(char *out, int n)
{
    HWND h;
    char t[256] = "";
    int windows = 0;

    editor_pid = 0;
    EnumWindows(find_main, 0);
    if (!editor_pid) { snprintf(out, n, "0|"); return; }

    for (h = GetTopWindow(NULL); h; h = GetNextWindow(h, GW_HWNDNEXT)) {
        DWORD p = 0;
        if (!IsWindowVisible(h)) continue;
        GetWindowThreadProcessId(h, &p);
        if (p == editor_pid) {
            windows++;
            if (!t[0]) GetWindowTextA(h, t, sizeof(t));
        }
    }
    snprintf(out, n, "%d|%s", windows, t);
}

int main(int argc, char **argv)
{
    int watch = 0, safety = 0, shake = 0, verbose = 0;

    for (int i = 1; i < argc; i++) {
        if      (!strcmp(argv[i], "-w")) watch = 1;
        else if (!strcmp(argv[i], "-k")) shake = 1;
        else if (!strcmp(argv[i], "-v")) verbose = 1;
        else if (!strcmp(argv[i], "-e") && i + 1 < argc) safety = atoi(argv[++i]);
        else if (!strcmp(argv[i], "-t") && i + 1 < argc) wanted = argv[++i];
        else if (!strcmp(argv[i], "-h")) {
            printf("usage: redraw.exe [-w] [-e ms] [-k] [-v] [-t text]\n"
                   "  -w        watch and repaint whenever something changes\n"
                   "  -e <ms>   plus a safety pass every so often\n"
                   "  -k        minimize and restore (the manual remedy)\n"
                   "  -v        report what it is doing\n"
                   "  -t <txt>  window-title text to look for (def. SoundEditor)\n");
            return 0;
        }
    }

    EnumWindows(find_main, 0);
    if (!editor_pid) {
        printf("No window found with \"%s\" in the title.\n", wanted);
        return 1;
    }

    if (shake) {
        for (HWND h = GetTopWindow(NULL); h; h = GetNextWindow(h, GW_HWNDNEXT)) {
            DWORD p = 0;
            GetWindowThreadProcessId(h, &p);
            if (p == editor_pid && IsWindowVisible(h)) {
                ShowWindow(h, SW_MINIMIZE);
                Sleep(250);
                ShowWindow(h, SW_RESTORE);
                printf("Shook window %p.\n", (void *)h);
                return 0;
            }
        }
        return 1;
    }

    if (!watch) {
        printf("Repainted %d windows.\n", pass());
        return 0;
    }

    char prev[320] = "", now[320] = "";
    DWORD last = GetTickCount();

    fingerprint(prev, sizeof(prev));
    pass();
    printf("Watching the editor (process %lu). Ctrl-C to stop.\n", editor_pid);
    fflush(stdout);

    for (;;) {
        Sleep(400);
        fingerprint(now, sizeof(now));
        if (!editor_pid) break;              /* the editor has been closed */

        if (strcmp(now, prev) != 0) {
            strcpy(prev, now);
            Sleep(120);                      /* let it finish its own drawing */
            int n = pass();
            if (verbose) { printf("  change -> repainted %d\n", n); fflush(stdout); }
            last = GetTickCount();
        } else if (safety > 0 && (GetTickCount() - last) >= (DWORD)safety) {
            pass();
            last = GetTickCount();
        }
    }
    return 0;
}
