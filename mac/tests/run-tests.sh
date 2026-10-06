#!/bin/bash
# Runs the macOS tests.
#
#   bash mac/tests/run-tests.sh            unit tests only
#   bash mac/tests/run-tests.sh --e2e      unit tests, then the end-to-end test
#   bash mac/tests/run-tests.sh --e2e-only [--rounds N] [--insert type|paste]
#
# The unit tests run with a standalone Lua 5.4 if there is one, otherwise
# inside Hammerspoon (the same Lua the tool runs in). The end-to-end test
# always runs inside Hammerspoon against the installed tool, and needs the
# Accessibility permission. During it (about 30 seconds per round) do not
# touch the keyboard or the mouse: it types into a TextEdit document of its
# own and stops by itself if another window comes to the front.
#
# To talk to Hammerspoon the runner puts a file named test-mode in the
# installed module (which then loads hs.ipc) and reloads it; at the end the
# file is removed and Hammerspoon is reloaded again.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.hammerspoon/hafuch-safa"
OUT="$HERE/output"
mkdir -p "$OUT"

unit=1 e2e=0 rounds=1 insert=""
while [ $# -gt 0 ]; do
    case "$1" in
        --e2e) e2e=1 ;;
        --e2e-only) e2e=1; unit=0 ;;
        --rounds) rounds="$2"; shift ;;
        --insert) insert="$2"; shift ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

with_timeout() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' "$s" "$@"; }

HS_APP=""
for p in /Applications/Hammerspoon.app "$HOME/Applications/Hammerspoon.app"; do
    [ -d "$p" ] && HS_APP="$p" && break
done
HS_CLI="$HS_APP/Contents/Frameworks/hs/hs"
ipc_on=0

hs_cli() { with_timeout 20 "$HS_CLI" -t 10 -q -c "$1" < /dev/null; }

restart_hammerspoon() {
    pkill -x Hammerspoon || true
    for _ in $(seq 1 50); do pgrep -xq Hammerspoon || break; sleep 0.1; done
    open -g -a "$HS_APP"
}

ipc_start() {
    [ "$ipc_on" = 1 ] && return 0
    [ -n "$HS_APP" ] || { echo "Hammerspoon is not installed"; return 1; }
    [ -f "$DEST/init.lua" ] || { echo "hafuch-safa is not installed (run mac/install.sh first)"; return 1; }
    : > "$DEST/test-mode"
    ipc_on=1
    restart_hammerspoon
    for _ in $(seq 1 100); do
        if pgrep -xq Hammerspoon && [ "$(with_timeout 3 "$HS_CLI" -t 2 -q -c 'return "pong"' < /dev/null 2>/dev/null)" = "pong" ]; then
            return 0
        fi
        sleep 0.2
    done
    echo "could not reach Hammerspoon through hs.ipc"
    return 1
}

ipc_stop() {
    [ "$ipc_on" = 1 ] || return 0
    rm -f "$DEST/test-mode"
    restart_hammerspoon
    ipc_on=0
}
trap ipc_stop EXIT

status=0

if [ "$unit" = 1 ]; then
    echo "== unit tests (mac/tests/unit-tests.lua)"
    LUA=""
    for c in lua5.4 lua54 lua; do
        if command -v "$c" >/dev/null 2>&1 && "$c" -v 2>&1 | grep -q 'Lua 5\.4'; then LUA="$c"; break; fi
    done
    if [ -n "$LUA" ]; then
        with_timeout 60 "$LUA" "$HERE/unit-tests.lua" | tee "$OUT/unit-tests.txt"
        [ "${PIPESTATUS[0]}" = 0 ] || status=1
    else
        echo "# no standalone Lua 5.4, running inside Hammerspoon"
        ipc_start || exit 1
        hs_cli "local failed, lines = dofile('$HERE/unit-tests.lua')(); return table.concat(lines, '\n')" \
            | tee "$OUT/unit-tests.txt"
        grep -q '^not ok\|^Bail out' "$OUT/unit-tests.txt" && status=1
        grep -q '^# passed' "$OUT/unit-tests.txt" || status=1
    fi
fi

if [ "$e2e" = 1 ]; then
    echo "== end-to-end test in TextEdit (do not touch the keyboard or mouse)"
    ipc_start || exit 1
    result="$OUT/e2e-results.txt"
    rm -f "$result"
    opts="{rounds = $rounds"
    [ -n "$insert" ] && opts="$opts, insert = '$insert', label = '$insert'"
    opts="$opts}"
    hs_cli "return dofile('$HERE/e2e-test.lua')('$result', $opts)" >/dev/null
    # 30 seconds per case at most; a round normally takes about 30 seconds.
    limit=$(( 60 * rounds ))
    shown=0
    for _ in $(seq 1 $(( limit * 5 ))); do
        if [ -f "$result" ]; then
            total=$(wc -l < "$result")
            if [ "$total" -gt "$shown" ]; then
                tail -n +"$(( shown + 1 ))" "$result" | head -n "$(( total - shown ))"
                shown=$total
            fi
            grep -q '^# done' "$result" && break
        fi
        sleep 0.2
    done
    if ! grep -q '^# done' "$result" 2>/dev/null; then
        echo "Bail out! the end-to-end test did not finish within $limit seconds"
        status=1
    fi
    grep -q '^not ok\|^Bail out' "$result" && status=1
fi

exit $status
