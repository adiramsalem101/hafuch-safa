#!/bin/bash
# hafuch-safa (הפוך שפה) for macOS: installs the tool in one command.
#
#   1. Installs Hammerspoon if it is missing (Homebrew, or the official
#      GitHub release into ~/Applications). No sudo, no admin password.
#   2. Copies the module to ~/.hammerspoon/hafuch-safa (keeps an existing
#      config.ini).
#   3. Adds one loading line at the end of ~/.hammerspoon/init.lua, only if
#      it is not there yet. Nothing else in init.lua is touched.
#   4. Turns on "Launch at login" for Hammerspoon (on the first start).
#   5. Starts or reloads Hammerspoon and opens the Accessibility settings
#      if the permission is still missing.
#
# Run: bash mac/install.sh   (or the one line in README.md)

set -euo pipefail

HS_TEAM_ID="VQCYSNZB89"   # code signing team of the official Hammerspoon builds
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HS_CONFIG_DIR="$HOME/.hammerspoon"
DEST="$HS_CONFIG_DIR/hafuch-safa"
INIT="$HS_CONFIG_DIR/init.lua"
LOAD_LINE='do local ok, m = pcall(dofile, hs.configdir .. "/hafuch-safa/init.lua"); if ok then hafuchSafa = m else print("hafuch-safa: " .. tostring(m)) end end -- hafuch-safa'
AX_PANE="x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

say() { printf '%s\n' "$*"; }
fail() { printf 'hafuch-safa: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "this installer is for macOS"
for f in hafuch-safa/init.lua hafuch-safa/core.lua config.ini uninstall.sh; do
    [ -f "$SRC/$f" ] || fail "missing $f next to install.sh"
done

# Finds Hammerspoon.app; prints its path or nothing.
find_hammerspoon() {
    local p
    for p in "/Applications/Hammerspoon.app" "$HOME/Applications/Hammerspoon.app"; do
        [ -d "$p" ] && { printf '%s\n' "$p"; return; }
    done
    p="$(mdfind "kMDItemCFBundleIdentifier == 'org.hammerspoon.Hammerspoon'" 2>/dev/null | head -n 1 || true)"
    [ -n "$p" ] && [ -d "$p" ] && printf '%s\n' "$p"
    return 0
}

# Downloads the latest official release into a folder (default
# ~/Applications) and checks its code signature before using it.
download_hammerspoon() {
    local target="${1:-$HOME/Applications}" tmp url
    tmp="$(mktemp -d)"
    url="$(curl -fsSL https://api.github.com/repos/Hammerspoon/hammerspoon/releases/latest \
        | grep -o '"browser_download_url": *"[^"]*Hammerspoon-[0-9.]*\.zip"' | head -n 1 | sed 's/.*"\(https[^"]*\)"/\1/')"
    [ -n "$url" ] || { rm -rf "$tmp"; fail "could not find the Hammerspoon download on GitHub"; }
    say "Downloading $url"
    curl -fsSL -o "$tmp/hs.zip" "$url" || { rm -rf "$tmp"; fail "download failed"; }
    ditto -x -k "$tmp/hs.zip" "$tmp/x" || { rm -rf "$tmp"; fail "could not unpack Hammerspoon"; }
    [ -d "$tmp/x/Hammerspoon.app" ] || { rm -rf "$tmp"; fail "the download has no Hammerspoon.app"; }
    codesign --verify --deep --strict "$tmp/x/Hammerspoon.app" 2>/dev/null \
        || { rm -rf "$tmp"; fail "the Hammerspoon download failed the signature check"; }
    codesign -dv "$tmp/x/Hammerspoon.app" 2>&1 | grep -q "TeamIdentifier=$HS_TEAM_ID" \
        || { rm -rf "$tmp"; fail "the Hammerspoon download is not signed by the Hammerspoon team"; }
    mkdir -p "$target"
    rm -rf "$target/Hammerspoon.app"
    mv "$tmp/x/Hammerspoon.app" "$target/"
    rm -rf "$tmp"
    printf '%s\n' "$target/Hammerspoon.app"
}

# Test hook: HAFUCH_SAFA_DOWNLOAD_ONLY=<folder> downloads and verifies
# Hammerspoon into that folder and stops.
if [ -n "${HAFUCH_SAFA_DOWNLOAD_ONLY:-}" ]; then
    download_hammerspoon "$HAFUCH_SAFA_DOWNLOAD_ONLY"
    exit 0
fi

# --- 1. Hammerspoon ---------------------------------------------------------
HS_APP="$(find_hammerspoon)"
HS_INSTALLED_BY="existing"
if [ -z "$HS_APP" ]; then
    say "Hammerspoon is not installed, installing it..."
    if command -v brew >/dev/null 2>&1 && brew install --cask hammerspoon; then
        HS_INSTALLED_BY="brew"
    else
        say "Homebrew is not available, using the official release from GitHub."
        download_hammerspoon >/dev/null
        HS_INSTALLED_BY="download"
    fi
    HS_APP="$(find_hammerspoon)"
    [ -n "$HS_APP" ] || fail "Hammerspoon was installed but cannot be found"
fi
say "Hammerspoon: $HS_APP"

# --- 2. The module ----------------------------------------------------------
mkdir -p "$DEST"
STATE="$DEST/install-state"
PREV_HS_BY="" PREV_INIT_CREATED=""
if [ -f "$STATE" ]; then
    PREV_HS_BY="$(sed -n 's/^hammerspoon=//p' "$STATE")"
    PREV_INIT_CREATED="$(sed -n 's/^init_created=//p' "$STATE")"
fi
# A reinstall keeps what the first install recorded.
[ "$HS_INSTALLED_BY" = "existing" ] && [ -n "$PREV_HS_BY" ] && HS_INSTALLED_BY="$PREV_HS_BY"

cp "$SRC/hafuch-safa/init.lua" "$SRC/hafuch-safa/core.lua" "$DEST/"
cp "$SRC/uninstall.sh" "$DEST/uninstall.sh"
chmod +x "$DEST/uninstall.sh"
if [ -f "$DEST/config.ini" ]; then
    say "Keeping the existing settings: $DEST/config.ini"
else
    cp "$SRC/config.ini" "$DEST/config.ini"
fi
: > "$DEST/first-run"

# --- 3. The loading line in init.lua ----------------------------------------
INIT_CREATED="${PREV_INIT_CREATED:-0}"
if [ ! -f "$INIT" ]; then
    : > "$INIT"
    INIT_CREATED=1
fi
if grep -qF 'hafuch-safa/init.lua' "$INIT"; then
    say "init.lua already loads hafuch-safa"
else
    # Add a line break first if the file does not end with one.
    if [ -s "$INIT" ] && [ "$(tail -c 1 "$INIT" | od -An -c | tr -d ' ')" != '\n' ]; then
        printf '\n' >> "$INIT"
    fi
    printf '%s\n' "$LOAD_LINE" >> "$INIT"
    say "Added one line to the end of $INIT"
fi

cat > "$STATE" <<EOF
hammerspoon=$HS_INSTALLED_BY
hammerspoon_app=$HS_APP
init_created=$INIT_CREATED
EOF

# --- 4 and 5. Start or reload Hammerspoon -----------------------------------
rm -f "$DEST/state.txt"
HS_CLI="$HS_APP/Contents/Frameworks/hs/hs"
if pgrep -xq Hammerspoon; then
    # The hs command line tool works only if the existing config loads
    # hs.ipc. Otherwise quit Hammerspoon and start it again.
    if [ -x "$HS_CLI" ]; then
        perl -e 'alarm 5; exec @ARGV' "$HS_CLI" -c '_hafuchSafaReload = hs.timer.doAfter(0.3, hs.reload) return true' < /dev/null >/dev/null 2>&1 || true
    fi
    for _ in $(seq 1 30); do [ -f "$DEST/state.txt" ] && break; sleep 0.1; done
    if [ ! -f "$DEST/state.txt" ]; then
        pkill -x Hammerspoon || true
        for _ in $(seq 1 50); do pgrep -xq Hammerspoon || break; sleep 0.1; done
        open -a "$HS_APP"
    fi
else
    open -a "$HS_APP"
fi

for _ in $(seq 1 150); do
    [ -f "$DEST/state.txt" ] && break
    sleep 0.1
done
if [ ! -f "$DEST/state.txt" ]; then
    say ""
    say "Hammerspoon started, but hafuch-safa did not report back yet."
    say "Open the Hammerspoon console (menu bar icon > Console) to see why."
    exit 1
fi

HOTKEY="$(sed -n 's/^hotkey=//p' "$DEST/state.txt")"
say ""
say "הפוך שפה הותקן. קיצור: ${HOTKEY:-Ctrl+Option+L}"
say "hafuch-safa is installed. Hotkey: ${HOTKEY:-Ctrl+Option+L}"
say "Settings: $DEST/config.ini"
say "Uninstall: bash $DEST/uninstall.sh"

if grep -q '^accessibility=1' "$DEST/state.txt"; then
    say "Accessibility permission: granted. Ready to use."
else
    say ""
    say "One more step: allow Hammerspoon to control the keyboard."
    say "In the window that opens (Privacy & Security > Accessibility), turn on Hammerspoon."
    say "בחלון שנפתח (פרטיות ואבטחה > נגישות) הפעילו את המתג ליד Hammerspoon."
    open "$AX_PANE" || true
fi
