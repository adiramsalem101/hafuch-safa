-- hafuch-safa: core text logic for macOS (port of lib/core.ahk).
-- Pure functions only (no windows, keyboard or clipboard access), so every
-- rule here is covered by mac/tests/unit-tests.lua. Plain Lua 5.4 plus the
-- standard utf8 library: it runs inside Hammerspoon and in any lua5.4.
--
-- Text is UTF-8. Every position and length below counts characters (code
-- points), not bytes.
--
-- Directions are plain strings:
--   "en-he"  text was typed on the English layout but meant to be Hebrew
--   "he-en"  text was typed on the Hebrew layout but meant to be English

local M = {}

function M.opposite(dir) return dir == "en-he" and "he-en" or "en-he" end

function M.targetLang(dir) return dir == "en-he" and "he" or "en" end

-- ---------------------------------------------------------------------------
-- UTF-8 helpers
-- ---------------------------------------------------------------------------

-- Splits text into an array of characters. Invalid UTF-8 bytes are kept as
-- single-byte characters instead of raising an error.
function M.chars(text)
    local out = {}
    local i, n = 1, #text
    while i <= n do
        local nextPos = utf8.offset(text, 2, i)
        local ok = pcall(utf8.codepoint, text, i)
        if not ok or not nextPos then nextPos = i + 1 end
        out[#out + 1] = text:sub(i, nextPos - 1)
        i = nextPos
    end
    return out
end

function M.len(text) return #M.chars(text) end

-- Characters i..j (1-based, inclusive). Negative indexes count from the end,
-- like string.sub.
function M.sub(text, i, j)
    local c = M.chars(text)
    local n = #c
    j = j or n
    if i < 0 then i = n + i + 1 end
    if j < 0 then j = n + j + 1 end
    if i < 1 then i = 1 end
    if j > n then j = n end
    if i > j then return "" end
    return table.concat(c, "", i, j)
end

local function cp(ch)
    local ok, v = pcall(utf8.codepoint, ch, 1)
    return ok and v or -1
end
M.codepoint = cp

-- ---------------------------------------------------------------------------
-- Conversion tables
-- ---------------------------------------------------------------------------

-- Builds a table from {englishChar, hebrewChar} pairs that sit on the same
-- physical key. When a character appears twice, the first pair wins, so list
-- unshifted keys before shifted ones. Pairs that are identical in both
-- layouts (digits, most symbols) are dropped: unmapped characters stay as
-- they are. Outputs longer than one character (a letter with a vowel point)
-- cannot be mapped character by character and are skipped.
--
-- A Hebrew letter on the shifted layer maps back to the lowercase key: from
-- Hebrew to English the result is lowercase, as on Windows.
function M.tableFromPairs(pairs)
    local enToHe, heToEn = {}, {}
    for _, pair in ipairs(pairs) do
        local en, he = pair[1], pair[2]
        if en ~= "" and he ~= "" and en ~= he and M.len(en) == 1 and M.len(he) == 1 then
            if enToHe[en] == nil then enToHe[en] = he end
            if heToEn[he] == nil then
                if M.isHebrewLetter(he) and en:match("^%u$") then
                    heToEn[he] = en:lower()
                else
                    heToEn[he] = en
                end
            end
        end
    end
    return { enToHe = enToHe, heToEn = heToEn }
end

-- Same, from parallel layers: enLayers[i] and heLayers[i] list what each key
-- of one keyboard layer types, key by key in the same order, separated by
-- spaces. "∅" marks a key that types nothing on that layer.
function M.tableFromLayers(enLayers, heLayers)
    local pairs = {}
    for i, enRow in ipairs(enLayers) do
        local enKeys, heKeys = {}, {}
        for k in enRow:gmatch("%S+") do enKeys[#enKeys + 1] = k end
        for k in heLayers[i]:gmatch("%S+") do heKeys[#heKeys + 1] = k end
        if #enKeys ~= #heKeys then
            error(("layer %d: %d English keys but %d Hebrew keys"):format(i, #enKeys, #heKeys))
        end
        for j, en in ipairs(enKeys) do
            local he = heKeys[j]
            if en ~= "∅" and he ~= "∅" then pairs[#pairs + 1] = { en, he } end
        end
    end
    return M.tableFromPairs(pairs)
end

-- ---------------------------------------------------------------------------
-- Character classes
-- ---------------------------------------------------------------------------

function M.isLatinLetter(ch)
    local o = cp(ch)
    return (o >= 0x41 and o <= 0x5A) or (o >= 0x61 and o <= 0x7A)
end

function M.isHebrewLetter(ch)
    local o = cp(ch)
    return o >= 0x05D0 and o <= 0x05EA
end

function M.isSpace(ch)
    return ch == " " or ch == "\t" or ch == "\n" or ch == "\r" or ch == "\u{A0}"
end

function M.countLetters(text)
    local latin, hebrew = 0, 0
    for _, ch in ipairs(M.chars(text)) do
        if M.isLatinLetter(ch) then
            latin = latin + 1
        elseif M.isHebrewLetter(ch) then
            hebrew = hebrew + 1
        end
    end
    return { latin = latin, hebrew = hebrew }
end

-- ---------------------------------------------------------------------------
-- Direction and conversion
-- ---------------------------------------------------------------------------

-- Majority of letters decides. Digits, spaces and symbols do not vote.
-- On a tie (including text with no letters at all) tieDir is returned; the
-- caller passes the direction implied by the input source that is active.
function M.detectDirection(text, tieDir)
    tieDir = tieDir or "en-he"
    local c = M.countLetters(text)
    if c.latin > c.hebrew then return "en-he" end
    if c.hebrew > c.latin then return "he-en" end
    return tieDir
end

-- Converts one character. An uppercase English letter without a mapping of
-- its own converts like its lowercase key, because Hebrew has no letter case
-- ("AKUO" typed with Caps Lock by mistake still becomes the Hebrew word).
function M.convertChar(ch, dir, tbl)
    if dir == "en-he" then
        local he = tbl.enToHe[ch]
        if he then return he end
        if ch:match("^%u$") then
            he = tbl.enToHe[ch:lower()]
            if he then return he end
        end
        return ch
    end
    return tbl.heToEn[ch] or ch
end

function M.convert(text, dir, tbl)
    local out = {}
    for i, ch in ipairs(M.chars(text)) do out[i] = M.convertChar(ch, dir, tbl) end
    return table.concat(out)
end

-- Converts text whose characters may be the result of an earlier flip.
-- shadow has the same length as text and holds, for each character, what it
-- was before that flip (or the character itself if it was typed as is).
-- A character that came from the opposite flip is restored exactly, so
-- flipping "Hello" and flipping it back gives "Hello" and not "hello".
function M.convertWithShadow(text, shadow, dir, tbl)
    local t, s = M.chars(text), M.chars(shadow)
    if #t ~= #s then return M.convert(text, dir, tbl) end
    local back = M.opposite(dir)
    local out = {}
    for i, ch in ipairs(t) do
        local was = s[i]
        if was ~= ch and M.convertChar(was, back, tbl) == ch then
            out[i] = was
        else
            out[i] = M.convertChar(ch, dir, tbl)
        end
    end
    return table.concat(out)
end

-- ---------------------------------------------------------------------------
-- Words before the caret
-- ---------------------------------------------------------------------------

-- 1-based index where the last word of text starts; whitespace after the
-- word belongs to the span. Words are split on whitespace only, because
-- , . ; / ' [ ] are Hebrew letters or punctuation on the other layout.
-- Returns 0 when text holds no word.
function M.lastWordStart(text)
    local c = M.chars(text)
    local i = #c
    while i >= 1 and M.isSpace(c[i]) do i = i - 1 end
    if i < 1 then return 0 end
    while i >= 1 and not M.isSpace(c[i]) do i = i - 1 end
    return i + 1
end

-- Start of the span flipped by a first press without a selection: the last
-- word, extended backwards over words that have no letters (numbers, emoji),
-- so "akuo 123" flips "akuo" too. Returns 0 when there is nothing to flip.
function M.flipSpanStart(text)
    local start = M.lastWordStart(text)
    if start == 0 then return 0 end
    local probe = start
    while true do
        local c = M.countLetters(M.sub(text, probe))
        if c.latin + c.hebrew > 0 then return probe end
        local prev = M.lastWordStart(M.sub(text, 1, probe - 1))
        if prev == 0 then return start end
        probe = prev
    end
end

-- Characters that Backspace removes together with the character before
-- them: combining marks (Hebrew points, accents), variation selectors and
-- emoji modifiers. A character after a zero width joiner also joins.
local function joinsPrevious(o)
    return (o >= 0x0300 and o <= 0x036F) or (o >= 0x0591 and o <= 0x05C7)
        or (o >= 0xFE00 and o <= 0xFE0F) or o == 0x200D
        or (o >= 0x1F3FB and o <= 0x1F3FF)
end

-- Splits text into what the user sees as single characters: a letter with
-- its vowel points, an emoji with its modifiers, a CR LF pair.
function M.clusters(text)
    local out, prev = {}, nil
    for _, ch in ipairs(M.chars(text)) do
        local o = cp(ch)
        local n = #out
        if n > 0 and (joinsPrevious(o) or prev == 0x200D or (ch == "\n" and out[n] == "\r")) then
            out[n] = out[n] .. ch
        else
            out[n + 1] = ch
        end
        prev = o
    end
    return out
end

-- Backspace presses needed to delete text: one per visible character, so a
-- CR LF pair, an emoji and a letter with a vowel point each take one press.
function M.backspaceCount(text)
    return #M.clusters(text)
end

-- Length of the common prefix of two strings (case-sensitive), in characters.
function M.commonPrefixLength(a, b)
    local ca, cb = M.chars(a), M.chars(b)
    local i = 0
    while i < #ca and i < #cb and ca[i + 1] == cb[i + 1] do i = i + 1 end
    return i
end

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------

-- macOS virtual key codes of the ANSI keyboard (physical positions, so the
-- hotkey works with every input source).
M.keyCodes = {
    a = 0, s = 1, d = 2, f = 3, h = 4, g = 5, z = 6, x = 7, c = 8, v = 9, b = 11,
    q = 12, w = 13, e = 14, r = 15, y = 16, t = 17, ["1"] = 18, ["2"] = 19,
    ["3"] = 20, ["4"] = 21, ["6"] = 22, ["5"] = 23, ["="] = 24, ["9"] = 25,
    ["7"] = 26, ["-"] = 27, ["8"] = 28, ["0"] = 29, ["]"] = 30, o = 31, u = 32,
    ["["] = 33, i = 34, p = 35, l = 37, j = 38, ["'"] = 39, k = 40, [";"] = 41,
    ["\\"] = 42, [","] = 43, ["/"] = 44, n = 45, m = 46, ["."] = 47, ["`"] = 50,
    space = 49, f1 = 122, f2 = 120, f3 = 99, f4 = 118, f5 = 96, f6 = 97, f7 = 98,
    f8 = 100, f9 = 101, f10 = 109, f11 = 103, f12 = 111, f13 = 105, f14 = 107,
    f15 = 113, f16 = 106, f17 = 64, f18 = 79, f19 = 80, f20 = 90,
}

local modifierNames = {
    ctrl = "ctrl", control = "ctrl", ["⌃"] = "ctrl",
    alt = "alt", option = "alt", opt = "alt", ["⌥"] = "alt",
    shift = "shift", ["⇧"] = "shift",
    cmd = "cmd", command = "cmd", win = "cmd", ["⌘"] = "cmd",
}
local modifierOrder = { "ctrl", "alt", "shift", "cmd" }
local modifierDisplay = { ctrl = "Ctrl", alt = "Option", shift = "Shift", cmd = "Cmd" }

local function trim(s) return (s:gsub("^\u{FEFF}", ""):gsub("^%s+", ""):gsub("%s+$", "")) end
M.trim = trim

-- Parses "Ctrl+Option+L", "Ctrl+Alt+L" (Windows spelling) or AutoHotkey
-- syntax ("^!l": ^ Ctrl, ! Option, + Shift, # Cmd). Letters, digits and
-- F-keys become key codes. Returns {mods, key, keyCode, display}; raises an
-- error with a readable message on bad input.
function M.parseHotkey(text)
    text = trim(text or "")
    if text == "" then error("empty hotkey", 0) end
    local found, key = {}, nil
    local first = text:match("^([^+%s]+)%s*%+")
    if first and modifierNames[first:lower()] then
        local parts = {}
        for p in (text .. "+"):gmatch("([^+]*)%+") do parts[#parts + 1] = trim(p) end
        key = table.remove(parts)
        for _, p in ipairs(parts) do
            local m = modifierNames[p:lower()]
            if not m then error("unknown modifier: " .. p, 0) end
            found[m] = true
        end
    else
        local i = 1
        local symbols = { ["^"] = "ctrl", ["!"] = "alt", ["+"] = "shift", ["#"] = "cmd" }
        while i < #text and symbols[text:sub(i, i)] do
            found[symbols[text:sub(i, i)]] = true
            i = i + 1
        end
        key = text:sub(i)
    end
    key = trim(key or "")
    if key == "" then error("missing key in hotkey: " .. text, 0) end
    local mods, display = {}, ""
    for _, m in ipairs(modifierOrder) do
        if found[m] then
            mods[#mods + 1] = m
            display = display .. modifierDisplay[m] .. "+"
        end
    end
    if #mods == 0 then error("the hotkey needs at least one modifier (Ctrl, Option, Shift or Cmd)", 0) end
    local lower = key:lower()
    local code = M.keyCodes[lower]
    if not code then error("unknown key: " .. key, 0) end
    if #key == 1 then
        display = display .. key:upper()
    else
        display = display .. lower:sub(1, 1):upper() .. lower:sub(2)
    end
    return { mods = mods, key = lower, keyCode = code, display = display }
end

function M.defaultSettingsText()
    return table.concat({
        "Hotkey=Ctrl+Option+L",
        "HebrewLayout=auto",
        "SwitchLayout=1",
        "ExpandWindowMs=2000",
        "InsertMethod=type",
        "TerminalInsertMethod=type",
        "PasteRestoreDelayMs=300",
        "ShowTips=1",
        "ShowMenuBarIcon=1",
        "DebugLog=0",
        "ExcludeApps=",
        "TerminalApps=com.apple.Terminal,com.googlecode.iterm2,dev.warp.Warp-Stable,com.mitchellh.ghostty,"
            .. "net.kovidgoyal.kitty,org.alacritty,io.alacritty,com.github.wez.wezterm,co.zeit.hyper,org.tabby",
        "LineCopyApps=com.microsoft.VSCode,com.microsoft.VSCodeInsiders,com.todesktop.230313mzl4w4u92,"
            .. "com.exafunction.windsurf,com.vscodium,com.jetbrains.*,com.google.android.studio,"
            .. "com.sublimetext.4,com.sublimetext.3,dev.zed.Zed",
    }, "\n")
end

-- Parses the simple "Key=Value" config format. Lines starting with ; or #
-- and [section] lines are ignored. Keys are case-insensitive (stored lower).
function M.parseConfigText(text)
    local cfg = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        line = trim(line:gsub("\r$", ""))
        local c = line:sub(1, 1)
        if line ~= "" and c ~= ";" and c ~= "#" and c ~= "[" then
            local eq = line:find("=", 1, true)
            if eq then
                local key = trim(line:sub(1, eq - 1))
                if key ~= "" then cfg[key:lower()] = trim(line:sub(eq + 1)) end
            end
        end
    end
    return cfg
end

function M.splitList(value)
    local list = {}
    for item in (value or ""):gmatch("[^,]+") do
        item = trim(item)
        if item ~= "" then list[#list + 1] = item:lower() end
    end
    return list
end

-- True when any of the names (bundle ID, app name) is in the list. An item
-- ending with * matches by prefix ("com.jetbrains.*").
function M.inList(list, ...)
    for _, name in ipairs({ ... }) do
        if name and name ~= "" then
            name = name:lower()
            for _, item in ipairs(list) do
                if item:sub(-1) == "*" then
                    if name:sub(1, #item - 1) == item:sub(1, -2) then return true end
                elseif name == item then
                    return true
                end
            end
        end
    end
    return false
end

local layoutNames = { auto = "auto", mac = "mac", hebrew = "mac", pc = "pc", standard = "pc",
    ["hebrew-pc"] = "pc", qwerty = "qwerty", ["hebrew-qwerty"] = "qwerty" }

local function readBool(raw, defaults, key, errors)
    local v = (raw[key] or ""):lower()
    if v == "1" or v == "true" or v == "yes" or v == "on" then return true end
    if v == "0" or v == "false" or v == "no" or v == "off" then return false end
    errors[#errors + 1] = key .. ": expected 1 or 0"
    return defaults[key] == "1"
end

local function readInt(raw, defaults, key, lo, hi, errors)
    local v = raw[key] or ""
    local n = v:match("^%d+$") and tonumber(v)
    if n and n >= lo and n <= hi then return n end
    errors[#errors + 1] = ("%s: expected a number between %d and %d"):format(key, lo, hi)
    return tonumber(defaults[key])
end

local function readChoice(raw, defaults, key, choices, errors)
    local v = (raw[key] or ""):lower()
    for _, c in ipairs(choices) do
        if v == c then return c end
    end
    errors[#errors + 1] = key .. ": expected one of " .. table.concat(choices, ", ")
    return defaults[key]
end

-- Merges user values over the defaults and validates them.
-- Returns settings, errors; invalid values fall back to the default.
-- Error messages use the key names as written in config.ini.
function M.buildSettings(userMap)
    local defaults = M.parseConfigText(M.defaultSettingsText())
    local raw = M.parseConfigText(M.defaultSettingsText())
    for k, v in pairs(userMap or {}) do raw[k:lower()] = v end
    local errors, s = {}, {}
    local function err(msg) errors[#errors + 1] = msg end

    local ok, h = pcall(M.parseHotkey, raw.hotkey)
    if ok then
        s.hotkey = h
    else
        err("Hotkey: " .. tostring(h))
        s.hotkey = M.parseHotkey(defaults.hotkey)
    end

    s.layout = layoutNames[(raw.hebrewlayout or ""):lower()]
    if not s.layout then
        err("HebrewLayout: expected auto, mac, pc or qwerty")
        s.layout = defaults.hebrewlayout
    end

    local e = {}
    s.switchLayout = readBool(raw, defaults, "switchlayout", e)
    s.showTips = readBool(raw, defaults, "showtips", e)
    s.showMenuBarIcon = readBool(raw, defaults, "showmenubaricon", e)
    s.debugLog = readBool(raw, defaults, "debuglog", e)
    s.expandMs = readInt(raw, defaults, "expandwindowms", 200, 10000, e)
    s.pasteRestoreMs = readInt(raw, defaults, "pasterestoredelayms", 50, 5000, e)
    s.insert = readChoice(raw, defaults, "insertmethod", { "paste", "type" }, e)
    s.termInsert = readChoice(raw, defaults, "terminalinsertmethod", { "paste", "type" }, e)
    local proper = {
        switchlayout = "SwitchLayout", showtips = "ShowTips", showmenubaricon = "ShowMenuBarIcon",
        debuglog = "DebugLog", expandwindowms = "ExpandWindowMs", pasterestoredelayms = "PasteRestoreDelayMs",
        insertmethod = "InsertMethod", terminalinsertmethod = "TerminalInsertMethod",
    }
    for _, msg in ipairs(e) do
        local key, rest = msg:match("^(%w+)(:.*)$")
        err((proper[key] or key) .. rest)
    end
    s.excludeApps = M.splitList(raw.excludeapps)
    s.terminalApps = M.splitList(raw.terminalapps)
    s.lineCopyApps = M.splitList(raw.linecopyapps)
    return s, errors
end

-- ---------------------------------------------------------------------------
-- Key maps (English key -> what the same key types on the Hebrew layout)
-- ---------------------------------------------------------------------------

-- The 47 keys of the ANSI keyboard, plain and with Shift, in this order:
--   ` 1 2 3 4 5 6 7 8 9 0 - =  q w e r t y u i o p [ ] \  a s d f g h j k l ; '  z x c v b n m , . /
-- The Hebrew layers were read from the layouts that ship with macOS 15 with
-- mac/tests/layout-dump.swift (UCKeyTranslate, read only). "∅" is a key that
-- types nothing; outputs of two characters (a letter with a vowel point)
-- are listed but skipped when the table is built.
local EN_PLAIN = "` 1 2 3 4 5 6 7 8 9 0 - = q w e r t y u i o p [ ] \\ a s d f g h j k l ; ' z x c v b n m , . /"
local EN_SHIFT = "~ ! @ # $ % ^ & * ( ) _ + Q W E R T Y U I O P { } | A S D F G H J K L : \" Z X C V B N M < > ?"

M.layers = {
    -- macOS "Hebrew" (com.apple.keylayout.Hebrew). Shift on a letter key types
    -- nothing or a vowelled letter, never an English capital.
    mac = {
        "; 1 2 3 4 5 6 7 8 9 0 - = / ׳ ק ר א ט ו ן ם פ ] [ ֿ ש ד ג כ ע י ח ל ך ף , ז ס ב ה נ מ צ ת ץ .",
        "~ ! @ # $ % ^ ₪ * ) ( _ + ∅ ∅ ∅ ∅ ∅ ∅ וֹ ∅ ∅ ∅ } { | שׁ ∅ „ ∅ ∅ ∅ ∅ לֹ ∅ : ״ ∅ ∅ לֹ ∅ ∅ ∅ ∅ > < ?",
    },
    -- macOS "Hebrew-PC" (com.apple.keylayout.Hebrew-PC), the Windows layout.
    -- Shift on a letter key types the English capital.
    pc = {
        "\\ 1 2 3 4 5 6 7 8 9 0 - = / ' ק ר א ט ו ן ם פ ] [ \\ ש ד ג כ ע י ח ל ך ף , ז ס ב ה נ מ צ ת ץ .",
        "| ! @ # $ % ^ & * ) ( _ + Q W E R T Y U I O P } { | A S D F G H J K L : \" Z X C V B N M > < ?",
    },
    -- macOS "Hebrew-QWERTY" (com.apple.keylayout.Hebrew-QWERTY), phonetic.
    qwerty = {
        "ּ 1 2 3 4 5 6 7 8 9 0 – = ק ש ע ר ת ט ו י ו פ ’ ײַ ֿ א ס ד פ ג ה ח כ ל ; ׳ ז כ צ ו ב נ מ , . /",
        "ּ ! “ # $ % ” ₪ * ) ( — + ∅ שׁ ֵ ∅ ט ת וּ ײַ וֹ ף } { - ָ ש „ ף ∅ ח ∅ ך לֹ : ’ ∅ ך ץ ב ּ ן ם > < ?",
    },
}

-- Input source IDs of each table, in order of preference.
M.sourceIDs = {
    mac = "com.apple.keylayout.Hebrew",
    pc = "com.apple.keylayout.Hebrew-PC",
    qwerty = "com.apple.keylayout.Hebrew-QWERTY",
}

local tableCache = {}

-- Returns the conversion table "mac", "pc" or "qwerty".
function M.staticTable(name)
    local layers = M.layers[name]
    if not layers then error("unknown layout table: " .. tostring(name), 0) end
    if not tableCache[name] then
        local t = M.tableFromLayers({ EN_PLAIN, EN_SHIFT }, layers)
        -- Text that was typed on the other Hebrew layouts (or on Windows) has
        -- an ASCII apostrophe or a Hebrew geresh where this layout has the
        -- other one; both come from the w key. Extra pairs never override a
        -- key of the layout itself.
        for _, extra in ipairs({ { "w", "'" }, { "w", "׳" } }) do
            if t.heToEn[extra[2]] == nil and name ~= "qwerty" then t.heToEn[extra[2]] = extra[1] end
        end
        tableCache[name] = t
    end
    return tableCache[name]
end

-- Picks the table for an input source ID ("com.apple.keylayout.Hebrew-PC").
function M.tableNameForSource(sourceID)
    for name, id in pairs(M.sourceIDs) do
        if sourceID == id then return name end
    end
    return nil
end

return M
