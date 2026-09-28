; hafuch-safa: core text logic.
; Pure functions only (no windows, keyboard or clipboard access), so every
; rule here is covered by tests\unit-tests.ahk.
;
; Directions are plain strings:
;   "en-he"  text was typed on the English layout but meant to be Hebrew
;   "he-en"  text was typed on the Hebrew layout but meant to be English

#Requires AutoHotkey v2.0

HS_Opposite(dir) => (dir == "en-he") ? "he-en" : "en-he"

HS_TargetLang(dir) => (dir == "en-he") ? "he" : "en"

; ---------------------------------------------------------------------------
; Conversion tables
; ---------------------------------------------------------------------------

; Builds a table from [englishChar, hebrewChar] pairs that sit on the same
; physical key. When a character appears twice, the first pair wins, so list
; unshifted keys before shifted ones. Pairs that are identical in both layouts
; (digits, most symbols) are dropped: unmapped characters stay as they are.
HS_TableFromPairs(pairs) {
    enToHe := Map(), heToEn := Map()
    for pair in pairs {
        en := pair[1], he := pair[2]
        if (en == "" || he == "" || en == he)
            continue
        if !enToHe.Has(en)
            enToHe[en] := he
        if !heToEn.Has(he)
            heToEn[he] := en
    }
    return {enToHe: enToHe, heToEn: heToEn}
}

; Same, from parallel strings: enLayers[i] and heLayers[i] list the
; characters of one keyboard layer key by key, in the same order.
HS_TableFromLayers(enLayers, heLayers) {
    pairs := []
    for i, enRow in enLayers {
        enChars := StrSplit(enRow), heChars := StrSplit(heLayers[i])
        if (enChars.Length != heChars.Length)
            throw ValueError("Layer " i ": " enChars.Length " English keys but " heChars.Length " Hebrew keys")
        for j, ch in enChars
            pairs.Push([ch, heChars[j]])
    }
    return HS_TableFromPairs(pairs)
}

; ---------------------------------------------------------------------------
; Character classes
; ---------------------------------------------------------------------------

HS_IsLatinLetter(ch) {
    o := Ord(ch)
    return (o >= 0x41 && o <= 0x5A) || (o >= 0x61 && o <= 0x7A)
}

HS_IsHebrewLetter(ch) {
    o := Ord(ch)
    return o >= 0x05D0 && o <= 0x05EA
}

HS_IsSpace(ch) => (ch == " " || ch == "`t" || ch == "`n" || ch == "`r" || ch == Chr(0xA0))

HS_CountLetters(text) {
    latin := 0, hebrew := 0
    Loop Parse, text {
        if HS_IsLatinLetter(A_LoopField)
            latin++
        else if HS_IsHebrewLetter(A_LoopField)
            hebrew++
    }
    return {latin: latin, hebrew: hebrew}
}

; ---------------------------------------------------------------------------
; Direction and conversion
; ---------------------------------------------------------------------------

; Majority of letters decides. Digits, spaces and symbols do not vote.
; On a tie (including text with no letters at all) tieDir is returned; the
; caller passes the direction implied by the keyboard layout that is active.
HS_DetectDirection(text, tieDir := "en-he") {
    c := HS_CountLetters(text)
    if (c.latin > c.hebrew)
        return "en-he"
    if (c.hebrew > c.latin)
        return "he-en"
    return tieDir
}

; Converts one character. An uppercase English letter converts like its
; lowercase key, because Hebrew has no letter case (Shift on the Hebrew
; layout types uppercase English, so "AKUO" typed with Caps Lock by mistake
; still becomes the Hebrew word).
HS_ConvertChar(ch, dir, table) {
    if (dir == "en-he") {
        if table.enToHe.Has(ch)
            return table.enToHe[ch]
        o := Ord(ch)
        if (o >= 0x41 && o <= 0x5A) {
            lower := Chr(o + 32)
            if table.enToHe.Has(lower)
                return table.enToHe[lower]
        }
        return ch
    }
    return table.heToEn.Has(ch) ? table.heToEn[ch] : ch
}

HS_Convert(text, dir, table) {
    out := ""
    Loop Parse, text
        out .= HS_ConvertChar(A_LoopField, dir, table)
    return out
}

; Converts text whose characters may be the result of an earlier flip.
; shadow has the same length as text and holds, for each character, what it
; was before that flip (or the character itself if it was typed as is).
; A character that came from the opposite flip is restored exactly, so
; flipping "Hello" and flipping it back gives "Hello" and not "hello".
HS_ConvertWithShadow(text, shadow, dir, table) {
    if (StrLen(shadow) != StrLen(text))
        return HS_Convert(text, dir, table)
    back := HS_Opposite(dir)
    out := ""
    Loop Parse, text {
        ch := A_LoopField
        was := SubStr(shadow, A_Index, 1)
        if (was !== ch && HS_ConvertChar(was, back, table) == ch)
            out .= was
        else
            out .= HS_ConvertChar(ch, dir, table)
    }
    return out
}

; ---------------------------------------------------------------------------
; Words before the caret
; ---------------------------------------------------------------------------

; 1-based index where the last word of text starts; whitespace after the
; word belongs to the span. Words are split on whitespace only, because
; , . ; / ' [ ] are Hebrew letters or punctuation on the other layout.
; Returns 0 when text holds no word.
HS_LastWordStart(text) {
    i := StrLen(text)
    while (i >= 1 && HS_IsSpace(SubStr(text, i, 1)))
        i--
    if (i < 1)
        return 0
    while (i >= 1 && !HS_IsSpace(SubStr(text, i, 1)))
        i--
    return i + 1
}

; Start of the span flipped by a first press without a selection: the last
; word, extended backwards over words that have no letters (numbers, emoji),
; so "akuo 123" flips "akuo" too. Returns 0 when there is nothing to flip.
HS_FlipSpanStart(text) {
    start := HS_LastWordStart(text)
    if (start = 0)
        return 0
    probe := start
    loop {
        c := HS_CountLetters(SubStr(text, probe))
        if (c.latin + c.hebrew > 0)
            return probe
        prev := HS_LastWordStart(SubStr(text, 1, probe - 1))
        if (prev = 0)
            return start
        probe := prev
    }
}

; Backspace presses needed to delete text: a CR LF pair and a surrogate pair
; (emoji) each disappear with a single press.
HS_BackspaceCount(text) {
    n := 0
    Loop Parse, StrReplace(text, "`r`n", "`n") {
        o := Ord(A_LoopField)
        if !(o >= 0xDC00 && o <= 0xDFFF)
            n++
    }
    return n
}

; Length of the common prefix of two strings (case-sensitive).
HS_CommonPrefixLength(a, b) {
    n := Min(StrLen(a), StrLen(b)), i := 0
    while (i < n && SubStr(a, i + 1, 1) == SubStr(b, i + 1, 1))
        i++
    return i
}

; ---------------------------------------------------------------------------
; Settings
; ---------------------------------------------------------------------------

; Parses "Ctrl+Alt+L" or AutoHotkey syntax ("^!l"). Letters and digits are
; turned into virtual key codes so the hotkey works on every layout.
; Returns {spec, key, mods, display}; throws ValueError on bad input.
HS_ParseHotkey(text) {
    text := Trim(text)
    if (text = "")
        throw ValueError("empty hotkey")
    mods := [], key := ""
    if RegExMatch(text, "i)^\s*(ctrl|control|alt|shift|win|lwin|rwin)\s*\+") {
        parts := StrSplit(text, "+", " `t")
        key := parts.Pop()
        for p in parts {
            switch p, false {
                case "ctrl", "control": mods.Push("Ctrl")
                case "alt": mods.Push("Alt")
                case "shift": mods.Push("Shift")
                case "win", "lwin": mods.Push("LWin")
                case "rwin": mods.Push("RWin")
                default: throw ValueError("unknown modifier: " p)
            }
        }
    } else {
        i := 1
        while (i < StrLen(text) && InStr("^!+#", SubStr(text, i, 1))) {
            switch SubStr(text, i, 1) {
                case "^": mods.Push("Ctrl")
                case "!": mods.Push("Alt")
                case "+": mods.Push("Shift")
                case "#": mods.Push("LWin")
            }
            i++
        }
        key := SubStr(text, i)
    }
    key := Trim(key)
    if (key = "")
        throw ValueError("missing key in hotkey: " text)
    if !mods.Length
        throw ValueError("the hotkey needs at least one modifier (Ctrl, Alt, Shift or Win)")
    display := ""
    symbols := ""
    seen := Map()
    for m in mods {
        if seen.Has(m)
            continue
        seen[m] := true
        display .= (m = "LWin" || m = "RWin" ? "Win" : m) "+"
        symbols .= m = "Ctrl" ? "^" : m = "Alt" ? "!" : m = "Shift" ? "+" : m = "LWin" ? "#" : ">#"
    }
    if RegExMatch(key, "^[A-Za-z0-9]$") {
        display .= StrUpper(key)
        key := Format("vk{:02X}", Ord(StrUpper(key)))
    } else {
        display .= key
    }
    return {spec: symbols key, key: key, mods: mods, display: display}
}

HS_DefaultSettingsText() {
    return "
    (
    Hotkey=Ctrl+Alt+L
    HebrewLayout=auto
    SwitchLayout=1
    ExpandWindowMs=2000
    InsertMethod=type
    TerminalInsertMethod=type
    PasteRestoreDelayMs=300
    ShowTips=1
    DebugLog=0
    ExcludeApps=
    TerminalApps=WindowsTerminal.exe,OpenConsole.exe,conhost.exe,cmd.exe,powershell.exe,pwsh.exe,wsl.exe,bash.exe,mintty.exe,putty.exe,kitty.exe,alacritty.exe,wezterm-gui.exe,ConEmu.exe,ConEmu64.exe,Tabby.exe,Hyper.exe,WindowsTerminalPreview.exe
    LineCopyApps=Code.exe,Code - Insiders.exe,Cursor.exe,Windsurf.exe,devenv.exe,sublime_text.exe,idea64.exe,pycharm64.exe,webstorm64.exe,phpstorm64.exe,rider64.exe,clion64.exe,goland64.exe,rubymine64.exe,datagrip64.exe,studio64.exe
    )"
}

; Parses the simple "Key=Value" config format. Lines starting with ; and
; [section] lines are ignored. Keys are case-insensitive.
HS_ParseConfigText(text) {
    cfg := Map()
    cfg.CaseSense := "Off"
    for line in StrSplit(text, "`n", "`r") {
        line := Trim(line, " `t" Chr(0xFEFF))
        if (line = "" || SubStr(line, 1, 1) = ";" || SubStr(line, 1, 1) = "[")
            continue
        eq := InStr(line, "=")
        if !eq
            continue
        key := Trim(SubStr(line, 1, eq - 1))
        if (key != "")
            cfg[key] := Trim(SubStr(line, eq + 1))
    }
    return cfg
}

HS_SplitList(value) {
    list := []
    for item in StrSplit(value, ",", " `t")
        if (item != "")
            list.Push(StrLower(item))
    return list
}

; Merges user values over the defaults and validates them.
; Returns {settings, errors}; invalid values fall back to the default.
HS_BuildSettings(userMap) {
    raw := HS_ParseConfigText(HS_DefaultSettingsText())
    for k, v in userMap
        raw[k] := v
    defaults := HS_ParseConfigText(HS_DefaultSettingsText())
    errors := []
    s := {}

    try {
        s.hotkey := HS_ParseHotkey(raw["Hotkey"])
    } catch as e {
        errors.Push("Hotkey: " e.Message)
        s.hotkey := HS_ParseHotkey(defaults["Hotkey"])
    }

    s.layout := StrLower(raw["HebrewLayout"])
    if !(s.layout = "auto" || s.layout = "standard" || s.layout = "mac") {
        errors.Push("HebrewLayout: expected auto, standard or mac")
        s.layout := defaults["HebrewLayout"]
    }

    s.switchLayout := HS_ReadBool(raw, defaults, "SwitchLayout", errors)
    s.showTips := HS_ReadBool(raw, defaults, "ShowTips", errors)
    s.debugLog := HS_ReadBool(raw, defaults, "DebugLog", errors)
    s.expandMs := HS_ReadInt(raw, defaults, "ExpandWindowMs", 200, 10000, errors)
    s.pasteRestoreMs := HS_ReadInt(raw, defaults, "PasteRestoreDelayMs", 50, 5000, errors)
    s.insert := HS_ReadChoice(raw, defaults, "InsertMethod", ["paste", "type"], errors)
    s.termInsert := HS_ReadChoice(raw, defaults, "TerminalInsertMethod", ["paste", "type"], errors)
    s.excludeApps := HS_SplitList(raw["ExcludeApps"])
    s.terminalApps := HS_SplitList(raw["TerminalApps"])
    s.lineCopyApps := HS_SplitList(raw["LineCopyApps"])
    return {settings: s, errors: errors}
}

HS_ReadBool(raw, defaults, key, errors) {
    v := StrLower(Trim(raw[key]))
    if (v = "1" || v = "true" || v = "yes" || v = "on")
        return true
    if (v = "0" || v = "false" || v = "no" || v = "off")
        return false
    errors.Push(key ": expected 1 or 0")
    return defaults[key] = "1"
}

HS_ReadInt(raw, defaults, key, lo, hi, errors) {
    v := Trim(raw[key])
    if (IsInteger(v) && v + 0 >= lo && v + 0 <= hi)
        return v + 0
    errors.Push(key ": expected a number between " lo " and " hi)
    return defaults[key] + 0
}

HS_ReadChoice(raw, defaults, key, choices, errors) {
    v := StrLower(Trim(raw[key]))
    for c in choices
        if (v = c)
            return c
    errors.Push(key ": expected one of " HS_Join(choices, ", "))
    return defaults[key]
}

HS_Join(list, sep) {
    out := ""
    for i, item in list
        out .= (i > 1 ? sep : "") item
    return out
}
