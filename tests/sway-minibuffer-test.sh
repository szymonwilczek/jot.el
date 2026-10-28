#!/bin/bash
# Regression test: switching notes from an open note must prompt in a
# visible minibuffer.
#
# Runs a headless sway with an Emacs daemon on it, isolated in its own
# XDG_RUNTIME_DIR, so it never talks to the running compositor or daemon.
#
# First client frame goes to the sway scratchpad, which makes it the
# `default-minibuffer-frame', as when a scratchpad frame is made before
# the main one.  With a note open, C-c C-j (`jot-find-note') then reads
# in the minibuffer of the jot child frame, which must be the one of its
# parent frame and not that of the hidden scratchpad frame.
#
# Needs sway, swaymsg, python3 and Emacs built with PGTK.
# Usage: tests/sway-minibuffer-test.sh

set -u
root=$(cd "$(dirname "$0")/.." && pwd)

# short, as it holds the sockets of sway and the Emacs server
rt=$(mktemp -d "${JOT_TEST_TMPDIR:-/tmp}/jot.XXXXXX") || exit 2
chmod 700 "$rt"
export XDG_RUNTIME_DIR=$rt SWAYSOCK=$rt/sway.sock
unset WAYLAND_DISPLAY DISPLAY

cleanup() {
    emacsclient -e '(kill-emacs)' >/dev/null 2>&1
    [ -n "${sway_pid:-}" ] && kill "$sway_pid" 2>/dev/null
    wait 2>/dev/null
    rm -rf "$rt"
}
trap cleanup EXIT

E() { timeout 5 emacsclient -e "$1"; }

printf 'output HEADLESS-1 resolution 1920x1080\n' >"$rt/sway.conf"
WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman \
                      sway -c "$rt/sway.conf" >"$rt/sway.log" 2>&1 </dev/null &
sway_pid=$!
for _ in $(seq 50); do
    swaymsg -t get_version >/dev/null 2>&1 && break
    sleep 0.1
done
export WAYLAND_DISPLAY
WAYLAND_DISPLAY=$(cd "$rt" && ls wayland-[0-9] 2>/dev/null | head -1)
[ -n "$WAYLAND_DISPLAY" ] || { echo "sway did not start"; cat "$rt/sway.log"; exit 2; }

mkdir "$rt/notes"
emacs -Q --daemon -L "$root" \
      --eval "(progn (require 'jot) (setq jot-dir \"$rt/notes\") (jot-mode 1))" \
      >"$rt/emacs.log" 2>&1 </dev/null ||
    { echo "Emacs did not start"; cat "$rt/emacs.log"; exit 2; }

emacsclient -c -n -F '((name . "jot-test-scratchpad"))' >/dev/null
sleep 1
swaymsg '[title="jot-test-scratchpad"] move scratchpad' >/dev/null
emacsclient -c -n -F '((name . "jot-test-main"))' >/dev/null
sleep 1
swaymsg '[title="jot-test-main"] focus' >/dev/null

# open a note with C-c M-j, then switch notes from it with C-c C-j
E '(setq unread-command-events (listify-key-sequence (kbd "C-c M-j first RET")))' >/dev/null
sleep 1
E '(setq unread-command-events (listify-key-sequence (kbd "C-c C-j")))' >/dev/null
sleep 1

# the frame of the minibuffer being read, or of its root parent for a child
mini=$(E '(when (active-minibuffer-window)
            (frame-parameter (jot--root-parent-frame
                              (window-frame (active-minibuffer-window)))
                             (quote name)))')
E '(setq unread-command-events (listify-key-sequence (kbd "C-g")))' >/dev/null

visible=$(swaymsg -t get_tree | python3 -c '
import json, sys
name = json.loads(sys.argv[1]) if sys.argv[1].startswith("\"") else None
def walk(n):
    if n.get("name") == name:
        print(str(n.get("visible")).lower())
    for c in n.get("nodes", []) + n.get("floating_nodes", []):
        walk(c)
walk(json.load(sys.stdin))' "$mini")

if [ "$visible" = true ]; then
    echo "PASS: jot-find-note reads in visible frame $mini"
    exit 0
fi
echo "FAIL: jot-find-note reads in frame $mini, visible: ${visible:-unknown}"
exit 1
