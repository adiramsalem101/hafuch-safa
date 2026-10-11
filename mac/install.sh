#!/bin/bash
# hafuch-safa (הפוך שפה) for macOS: installs the tool in one command.
#
#   1. Installs Hammerspoon if it is missing: the official release from
#      GitHub (a pinned version, checked by SHA256 and code signature) into
#      ~/Applications. No Homebrew, no sudo, no admin password.
#   2. Copies the module to ~/.hammerspoon/hafuch-safa (keeps an existing
#      config.ini).
#   3. Adds one loading line at the end of ~/.hammerspoon/init.lua, only if
#      it is not there yet. Nothing else in init.lua is touched.
#   4. Turns on "Launch at login" for Hammerspoon (on the first start).
#   5. Starts or reloads Hammerspoon. If the Accessibility permission is
#      missing, opens its settings and waits until it is turned on.
#
# Run: bash mac/install.sh   (or the one line in README.md)

set -euo pipefail

HS_TEAM_ID="VQCYSNZB89"   # code signing team of the official Hammerspoon builds
# Pinned and tested release; the SHA256 is the digest GitHub lists for the asset.
HS_VERSION="1.1.1"
HS_SHA256="11bb1c90faf5427f37c7bd4fe7eab9774ae43e1d5cb020c5b3088dac32849efa"
HS_URL="https://github.com/Hammerspoon/hammerspoon/releases/download/$HS_VERSION/Hammerspoon-$HS_VERSION.zip"
HS_MIN_MACOS=13           # LSMinimumSystemVersion of Hammerspoon 1.1.1
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

# Downloads the pinned official release into a folder (default
# ~/Applications) and checks its SHA256 and code signature before using it.
# Not through Homebrew: a cask is quarantined, and macOS then holds the first
# start behind a "downloaded from the Internet" dialog that the installer
# cannot see.
download_hammerspoon() {
    local target="${1:-$HOME/Applications}" tmp sum sig
    tmp="$(mktemp -d)"
    say "Downloading Hammerspoon $HS_VERSION from GitHub..."
    curl -fsSL -o "$tmp/hs.zip" "$HS_URL" \
        || { rm -rf "$tmp"; fail "could not download $HS_URL (check the internet connection and run the line again)"; }
    sum="$(shasum -a 256 "$tmp/hs.zip" | awk '{print $1}')"
    [ "$sum" = "$HS_SHA256" ] || { rm -rf "$tmp"; fail "the Hammerspoon download does not match its SHA256"; }
    ditto -x -k "$tmp/hs.zip" "$tmp/x" || { rm -rf "$tmp"; fail "could not unpack Hammerspoon"; }
    [ -d "$tmp/x/Hammerspoon.app" ] || { rm -rf "$tmp"; fail "the download has no Hammerspoon.app"; }
    codesign --verify --deep --strict "$tmp/x/Hammerspoon.app" 2>/dev/null \
        || { rm -rf "$tmp"; fail "the Hammerspoon download failed the signature check"; }
    # Read all of codesign's output first: piped into grep -q, codesign got
    # SIGPIPE after the matching line and pipefail failed the check.
    sig="$(codesign -dv "$tmp/x/Hammerspoon.app" 2>&1 || true)"
    [[ "$sig" == *"TeamIdentifier=$HS_TEAM_ID"* ]] \
        || { rm -rf "$tmp"; fail "the Hammerspoon download is not signed by the Hammerspoon team"; }
    mkdir -p "$target"
    rm -rf "$target/Hammerspoon.app"
    mv "$tmp/x/Hammerspoon.app" "$target/"
    rm -rf "$tmp"
}

# Prints 1 when a modifier remap makes the Control key send Command (System
# Settings > Keyboard > Modifier Keys, or hidutil), otherwise 0. People who
# come from Windows often swap the two; Ctrl+Option+L then reaches macOS as
# Cmd+Option+L and the hotkey never fires.
ctrl_sends_cmd() {
    { hidutil property --get UserKeyMapping 2>/dev/null || true
      defaults -currentHost read -g 2>/dev/null || true; } \
    | awk '/\{/ { s = ""; d = "" }
           /HIDKeyboardModifierMappingSrc/ { s = $0; gsub(/[^0-9]/, "", s) }
           /HIDKeyboardModifierMappingDst/ { d = $0; gsub(/[^0-9]/, "", d) }
           /\}/ { if (s == "30064771296" && (d == "30064771299" || d == "30064771303")) f = 1 }
           END { print f ? 1 : 0 }'
}

# Prints how many Hebrew keyboard input sources are turned on.
hebrew_sources() {
    defaults read com.apple.HIToolbox AppleEnabledInputSources 2>/dev/null \
        | grep -c '"KeyboardLayout Name" = "\{0,1\}Hebrew' || true
}

# Test hook: HAFUCH_SAFA_DOWNLOAD_ONLY=<folder> downloads and verifies
# Hammerspoon into that folder and stops.
if [ -n "${HAFUCH_SAFA_DOWNLOAD_ONLY:-}" ]; then
    download_hammerspoon "$HAFUCH_SAFA_DOWNLOAD_ONLY"
    printf '%s\n' "$HAFUCH_SAFA_DOWNLOAD_ONLY/Hammerspoon.app"
    exit 0
fi

# --- 1. Hammerspoon ---------------------------------------------------------
HS_APP="$(find_hammerspoon)"
HS_INSTALLED_BY="existing"
if [ -z "$HS_APP" ]; then
    MACOS="$(sw_vers -productVersion 2>/dev/null || true)"
    case "${MACOS%%.*}" in
        ''|*[!0-9]*) ;;
        *) if [ "${MACOS%%.*}" -lt "$HS_MIN_MACOS" ]; then
               printf '%s\n' "הכלי צריך macOS $HS_MIN_MACOS ומעלה, ובמק הזה מותקן macOS $MACOS." >&2
               fail "Hammerspoon $HS_VERSION needs macOS $HS_MIN_MACOS or later; this Mac has macOS $MACOS"
           fi ;;
    esac
    say "Hammerspoon is not installed, installing it..."
    download_hammerspoon
    HS_INSTALLED_BY="download"
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
SWAPPED=0
if [ -f "$DEST/config.ini" ]; then
    say "Keeping the existing settings: $DEST/config.ini"
elif [ "$(ctrl_sends_cmd)" = 1 ]; then
    # Control and Command are swapped: bind what the Control key really sends.
    SWAPPED=1
    sed 's/^Hotkey=Ctrl+Option+L/Hotkey=Cmd+Option+L/' "$SRC/config.ini" > "$DEST/config.ini"
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

# A first start of a new download can take a while.
say "Starting Hammerspoon..."
for _ in $(seq 1 600); do
    [ -f "$DEST/state.txt" ] && break
    sleep 0.1
done
if [ ! -f "$DEST/state.txt" ]; then
    say ""
    say "Hammerspoon did not start within a minute, or hafuch-safa did not report back."
    say "If macOS shows a dialog about Hammerspoon, answer it and run the line again."
    say "Otherwise open the Hammerspoon console (its menu bar icon > Console) to see why."
    say "אם macOS מציג חלון על Hammerspoon, אשרו אותו והריצו את השורה שוב."
    exit 1
fi

# --- 6. Accessibility permission --------------------------------------------
GRANTED=0
grep -q '^accessibility=1' "$DEST/state.txt" && GRANTED=1
if [ "$GRANTED" = 0 ]; then
    say ""
    say "One more step: allow Hammerspoon to control the keyboard."
    say "In System Settings > Privacy & Security > Accessibility, turn on the switch next to Hammerspoon."
    say "If macOS asks about Hammerspoon first, click Open System Settings. Hammerspoon's own window can be closed."
    say "בהגדרות המערכת > פרטיות ואבטחה > נגישות, הפעילו את המתג ליד Hammerspoon."
    open "$AX_PANE" || true
    say ""
    say "Waiting for the switch (up to 5 minutes)... / ממתין להפעלת המתג..."
    for _ in $(seq 1 300); do
        grep -q '^accessibility=1' "$DEST/state.txt" 2>/dev/null && { GRANTED=1; break; }
        sleep 1
    done
fi

HOTKEY="$(sed -n 's/^hotkey=//p' "$DEST/state.txt")"
say ""
say "הפוך שפה הותקן. קיצור: ${HOTKEY:-Ctrl+Option+L}"
say "hafuch-safa is installed. Hotkey: ${HOTKEY:-Ctrl+Option+L}"
if [ "$SWAPPED" = 1 ]; then
    say ""
    say "Control and Command are swapped on this Mac, so the hotkey is Cmd+Option+L:"
    say "on the keyboard you press Control+Option+L, as on Windows."
    say "במק הזה Control ו-Command מוחלפים, ולכן לוחצים על המקשים Control+Option+L, כמו ב-Windows."
fi
if [ "$(hebrew_sources)" = 0 ]; then
    say ""
    say "No Hebrew input source is turned on. Add one: System Settings > Keyboard >"
    say "Text Input > Edit > + > Hebrew. Without it there is nothing to switch to."
    say "לא מוגדר מקור קלט עברי. מוסיפים בהגדרות המערכת > מקלדת > קלט טקסט > עריכה > + > עברית."
fi
say ""
say "Settings: $DEST/config.ini"
say "Uninstall: bash $DEST/uninstall.sh"
if [ "$GRANTED" = 1 ]; then
    say "Accessibility permission: granted. Ready to use."
    say "מוכן. הקלידו akuo ולחצו על הקיצור."
else
    say "The permission is not on yet. Once you turn on the switch, hafuch-safa starts by itself;"
    say "there is no need to run this again. / אחרי הפעלת המתג הכלי עולה לבד, אין צורך להריץ שוב."
fi
