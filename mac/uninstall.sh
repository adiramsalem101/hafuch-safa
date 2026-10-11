#!/bin/bash
# hafuch-safa (הפוך שפה) for macOS: removes everything install.sh added.
#
#   * The loading line in ~/.hammerspoon/init.lua (only that line).
#   * The folder ~/.hammerspoon/hafuch-safa.
#   * init.lua itself, if the installer created it and it is now empty.
#   * "Launch at login" for Hammerspoon, if the installer turned it on and
#     no other Hammerspoon config is left.
#   * Hammerspoon itself, if the installer installed it and no other
#     Hammerspoon config is left.
#
# Options:
#   --keep-config        keep ~/.hammerspoon/hafuch-safa/config.ini
#   --keep-hammerspoon   never remove Hammerspoon or change its settings
#
# Run: bash ~/.hammerspoon/hafuch-safa/uninstall.sh

set -euo pipefail

main() {
    local keep_config=0 keep_hs=0 arg
    for arg in "$@"; do
        case "$arg" in
            --keep-config) keep_config=1 ;;
            --keep-hammerspoon) keep_hs=1 ;;
            *) printf 'unknown option: %s\n' "$arg" >&2; exit 2 ;;
        esac
    done

    local cfgdir="$HOME/.hammerspoon"
    local dest="$cfgdir/hafuch-safa"
    local init="$cfgdir/init.lua"
    local state="$dest/install-state"
    local hs_by="existing" hs_app="" init_created=0
    if [ -f "$state" ]; then
        hs_by="$(sed -n 's/^hammerspoon=//p' "$state")"
        hs_app="$(sed -n 's/^hammerspoon_app=//p' "$state")"
        init_created="$(sed -n 's/^init_created=//p' "$state")"
    fi
    [ -n "$hs_app" ] && [ -d "$hs_app" ] || hs_app="$(find_hammerspoon)"

    # Is there Hammerspoon config besides our line? Blank lines and Lua
    # comments do not count.
    local other_config=0
    if [ -f "$init" ] && grep -vF 'hafuch-safa/init.lua' "$init" \
        | grep -vE '^[[:space:]]*(--.*)?$' | grep -q .; then
        other_config=1
    fi

    # 1. Turn off "Launch at login" if we turned it on and nothing else uses
    #    Hammerspoon. Only Hammerspoon can change its own login item, so the
    #    module is replaced by a two-line script and Hammerspoon runs it once.
    if [ "$keep_hs" = 0 ] && [ "$other_config" = 0 ] && [ -f "$dest/autolaunch-enabled" ] \
        && [ -n "$hs_app" ] && grep -qF 'hafuch-safa/init.lua' "$init" 2>/dev/null; then
        printf '%s\n' "Turning off Launch at login for Hammerspoon..."
        rm -f "$dest/goodbye-done"
        cat > "$dest/init.lua" <<'EOF'
-- hafuch-safa uninstall: undo "Launch at login", then do nothing.
hs.autoLaunch(false)
local f = io.open(hs.configdir .. "/hafuch-safa/goodbye-done", "w")
if f then f:write("1\n") f:close() end
EOF
        restart_hammerspoon "$hs_app"
        local i
        for i in $(seq 1 100); do [ -f "$dest/goodbye-done" ] && break; sleep 0.1; done
        [ -f "$dest/goodbye-done" ] || printf '%s\n' "Could not reach Hammerspoon; turn off Launch at login in its preferences."
    fi

    # 2. The loading line, and nothing else.
    if [ -f "$init" ] && grep -qF 'hafuch-safa/init.lua' "$init"; then
        local tmp="$cfgdir/.init.lua.hafuch-safa-tmp"
        grep -vF 'hafuch-safa/init.lua' "$init" > "$tmp" || true
        cat "$tmp" > "$init"
        rm -f "$tmp"
        printf '%s\n' "Removed the hafuch-safa line from $init"
    fi
    if [ "$init_created" = 1 ] && [ -f "$init" ] && ! grep -q '[^[:space:]]' "$init"; then
        rm -f "$init"
        printf '%s\n' "Removed $init (the installer created it and it is empty now)"
    fi

    # 3. The module folder.
    if [ -d "$dest" ]; then
        if [ "$keep_config" = 1 ] && [ -f "$dest/config.ini" ]; then
            find "$dest" -mindepth 1 ! -name config.ini -exec rm -rf {} +
            printf '%s\n' "Kept $dest/config.ini"
        else
            rm -rf "$dest"
        fi
        printf '%s\n' "Removed hafuch-safa from $cfgdir"
    fi

    # 4. Hammerspoon: reload it if other config uses it; otherwise quit it,
    #    and remove it if the installer installed it.
    if [ "$other_config" = 1 ] || [ "$keep_hs" = 1 ]; then
        if pgrep -xq Hammerspoon && [ -n "$hs_app" ]; then
            restart_hammerspoon "$hs_app"
            printf '%s\n' "Reloaded Hammerspoon (your other Hammerspoon config stays)."
        fi
    else
        if pgrep -xq Hammerspoon; then
            pkill -x Hammerspoon || true
            printf '%s\n' "Quit Hammerspoon (it has nothing left to run)."
        fi
        case "$hs_by" in
            brew)
                if command -v brew >/dev/null 2>&1; then
                    brew uninstall --cask hammerspoon && printf '%s\n' "Removed Hammerspoon (Homebrew)."
                fi
                ;;
            download)
                if [ -n "$hs_app" ] && [ -d "$hs_app" ]; then
                    rm -rf "$hs_app"
                    printf '%s\n' "Removed $hs_app"
                fi
                ;;
            *)
                [ -n "$hs_app" ] && printf '%s\n' "Hammerspoon was installed before hafuch-safa, so it stays: $hs_app"
                ;;
        esac
    fi

    printf '\n%s\n' "הפוך שפה הוסר. hafuch-safa was uninstalled."
    printf '%s\n' "The Accessibility entry for Hammerspoon stays in System Settings; remove it there if you like."
}

find_hammerspoon() {
    local p
    for p in "/Applications/Hammerspoon.app" "$HOME/Applications/Hammerspoon.app"; do
        [ -d "$p" ] && { printf '%s\n' "$p"; return; }
    done
    return 0
}

# Reloads the Hammerspoon config: through the hs tool if the config loads
# hs.ipc, otherwise by quitting and starting Hammerspoon.
restart_hammerspoon() {
    local app="$1" cli="$1/Contents/Frameworks/hs/hs" i
    if pgrep -xq Hammerspoon; then
        if [ -x "$cli" ] && perl -e 'alarm 5; exec @ARGV' "$cli" -c '_hafuchSafaReload = hs.timer.doAfter(0.3, hs.reload) return true' < /dev/null >/dev/null 2>&1; then
            sleep 1
            return
        fi
        pkill -x Hammerspoon || true
        for i in $(seq 1 50); do pgrep -xq Hammerspoon || break; sleep 0.1; done
    fi
    open -a "$app"
}

# The whole file is read before anything runs, so deleting the installed
# copy of this script while it runs is safe.
main "$@"
