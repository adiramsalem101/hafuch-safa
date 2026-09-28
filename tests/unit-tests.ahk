; Unit tests for the pure conversion logic (lib\core.ahk, lib\layouts.ahk).
; Output is TAP on stdout; the exit code is the number of failed checks.
; Run: tests\run-tests.ps1   (or AutoHotkey64.exe /ErrorStdOut tests\unit-tests.ahk)

#Requires AutoHotkey v2.0
#SingleInstance Off
#NoTrayIcon
#Include %A_ScriptDir%\..\lib\core.ahk
#Include %A_ScriptDir%\..\lib\layouts.ahk

global T_Count := 0, T_Failed := 0
OnError(T_OnError)

std := HS_StaticTable("standard")
mac := HS_StaticTable("mac")

; --- English layout text that was meant to be Hebrew -----------------------
Eq("en-he: single word", HS_Convert("akuo", "en-he", std), "שלום")
Eq("en-he: sentence", HS_Convert("akuo nv bang", "en-he", std), "שלום מה נשמע")
Eq("en-he: Caps Lock text still becomes Hebrew", HS_Convert("AKUO", "en-he", std), "שלום")
Eq("en-he: capital first letter", HS_Convert("Akuo", "en-he", std), "שלום")
Eq("en-he: apostrophe key is the Hebrew comma, ? stays", HS_Convert("akuo' nv bang?", "en-he", std), "שלום, מה נשמע?")
Eq("en-he: period key is final tsadi", HS_Convert("tr.", "en-he", std), "ארץ")
Eq("en-he: comma key is tav", HS_Convert("t,", "en-he", std), "את")
Eq("en-he: semicolon key is final pe", HS_Convert("tk;", "en-he", std), "אלף")
Eq("en-he: slash key is the Hebrew period", HS_Convert("akuo/", "en-he", std), "שלום.")
Eq("en-he: digits and spaces stay", HS_Convert("akuo 123", "en-he", std), "שלום 123")
Eq("en-he: parentheses mirror like the Hebrew layout", HS_Convert("(akuo)", "en-he", std), ")שלום(")
Eq("en-he: brackets mirror", HS_Convert("[x]", "en-he", std), "]ס[")
Eq("en-he: backtick key types a semicolon", HS_Convert("``", "en-he", std), ";")
Eq("en-he: Hebrew letters already present stay", HS_Convert("akuo שלום", "en-he", std), "שלום שלום")
Eq("en-he: emoji survives", HS_Convert("akuo 🙂", "en-he", std), "שלום 🙂")
Eq("en-he: empty text", HS_Convert("", "en-he", std), "")
Eq("en-he: correct English flips too (no dictionary)", HS_Convert("hello", "en-he", std), "יקךךם")
Eq("en-he: symbols shared by both layouts stay", HS_Convert("a-b=c!@#", "en-he", std), "ש-נ=ב!@#")

; --- Hebrew layout text that was meant to be English -----------------------
Eq("he-en: single word", HS_Convert("יקךךם", "he-en", std), "hello")
Eq("he-en: two words", HS_Convert("יקךךם 'םרךג", "he-en", std), "hello world")
Eq("he-en: Hebrew comma is the apostrophe key", HS_Convert("גםמ,א", "he-en", std), "don't")
Eq("he-en: Hebrew period is the slash key", HS_Convert("שלום.", "he-en", std), "akuo/")
Eq("he-en: Hebrew slash is the q key", HS_Convert("/וןא", "he-en", std), "quit")
Eq("he-en: Hebrew semicolon is the backtick key", HS_Convert(";", "he-en", std), "``")
Eq("he-en: Shift on the Hebrew layout typed capitals, they stay", HS_Convert("Hקךךם", "he-en", std), "Hello")
Eq("he-en: mirrored parentheses come back", HS_Convert(")שלום(", "he-en", std), "(akuo)")
Eq("he-en: numbers and symbols stay", HS_Convert("123 !@#", "he-en", std), "123 !@#")
Eq("he-en: correct Hebrew flips too (no dictionary)", HS_Convert("ארץ", "he-en", std), "tr.")
Eq("he-en: newline and tab stay", HS_Convert("יק`r`nךך`tם", "he-en", std), "he`r`nll`to")

; --- round trips ------------------------------------------------------------
for sample in ["akuo nv bang, tk/", "don't stop (now)", "a;b'c,d.e/f``g[h]", "x.y,z;w'q/"]
    Eq("round trip: " sample, HS_Convert(HS_Convert(sample, "en-he", std), "he-en", std), sample)

; --- direction detection -----------------------------------------------------
Eq("direction: Latin majority", HS_DetectDirection("akuo"), "en-he")
Eq("direction: Hebrew majority", HS_DetectDirection("יקךךם"), "he-en")
Eq("direction: majority wins in mixed text", HS_DetectDirection("ab שלום"), "he-en")
Eq("direction: tie uses the fallback", HS_DetectDirection("ab של", "he-en"), "he-en")
Eq("direction: no letters uses the fallback", HS_DetectDirection("123 ,./", "he-en"), "he-en")
Eq("direction: empty text uses the default", HS_DetectDirection(""), "en-he")
Eq("direction: punctuation does not vote", HS_DetectDirection("a,,,,,,", "he-en"), "en-he")

; --- exact restore through the shadow ----------------------------------------
Eq("shadow: flipping back restores capitals", HS_ConvertWithShadow("יקךךם", "Hello", "he-en", std), "Hello")
Eq("shadow: typed text converts normally", HS_ConvertWithShadow("יקךךם", "יקךךם", "he-en", std), "hello")
Eq("shadow: unrelated shadow is ignored", HS_ConvertWithShadow("abc", "xyz", "en-he", std), "שנב")
Eq("shadow: length mismatch falls back to plain conversion", HS_ConvertWithShadow("abc", "x", "en-he", std), "שנב")

; --- words before the caret ----------------------------------------------------
Eq("last word: plain", HS_LastWordStart("akuo nv bang"), 9)
Eq("last word: trailing space belongs to the span", HS_LastWordStart("akuo nv "), 6)
Eq("last word: punctuation stays inside the word", HS_LastWordStart("akuo, tr."), 7)
Eq("last word: only spaces", HS_LastWordStart("   "), 0)
Eq("last word: empty", HS_LastWordStart(""), 0)
Eq("flip span: a trailing number pulls in the word before it", HS_FlipSpanStart("akuo 123"), 1)
Eq("flip span: normal word", HS_FlipSpanStart("xx akuo"), 4)
Eq("flip span: symbols only", HS_FlipSpanStart("/"), 1)
Eq("flip span: nothing", HS_FlipSpanStart("  "), 0)

Eq("backspaces: plain", HS_BackspaceCount("akuo "), 5)
Eq("backspaces: CR LF counts once", HS_BackspaceCount("a`r`nb"), 3)
Eq("backspaces: emoji counts once", HS_BackspaceCount("a🙂"), 2)
Eq("common prefix", HS_CommonPrefixLength("123akuo", "123שלום"), 3)
Eq("common prefix: none", HS_CommonPrefixLength("akuo", "שלום"), 0)

; --- hotkey and settings -------------------------------------------------------
h := HS_ParseHotkey("Ctrl+Alt+L")
Eq("hotkey: friendly syntax", h.spec, "^!vk4C")
Eq("hotkey: display text", h.display, "Ctrl+Alt+L")
Eq("hotkey: key as virtual key code", h.key, "vk4C")
Eq("hotkey: AutoHotkey syntax", HS_ParseHotkey("^!l").spec, "^!vk4C")
Eq("hotkey: function key", HS_ParseHotkey("Ctrl+Shift+F9").spec, "^+F9")
Eq("hotkey: Win modifier", HS_ParseHotkey("Win+Alt+H").display, "Win+Alt+H")
Throws("hotkey: a key without modifier is refused", () => HS_ParseHotkey("L"))
Throws("hotkey: unknown modifier is refused", () => HS_ParseHotkey("Ctrl+Hyper+L"))

r := HS_BuildSettings(Map())
Eq("settings: defaults have no errors", r.errors.Length, 0)
Eq("settings: default hotkey", r.settings.hotkey.display, "Ctrl+Alt+L")
Eq("settings: default expand window", r.settings.expandMs, 2000)
Eq("settings: default insert method", r.settings.insert, "paste")
Eq("settings: terminals type instead of paste", r.settings.termInsert, "type")

r := HS_BuildSettings(HS_ParseConfigText("; comment`n[General]`n Hotkey = Ctrl+Shift+K `nExpandWindowMs=1500`nHebrewLayout=MAC`n"))
Eq("settings: parsed hotkey", r.settings.hotkey.spec, "^+vk4B")
Eq("settings: parsed number", r.settings.expandMs, 1500)
Eq("settings: layout name is case-insensitive", r.settings.layout, "mac")
Eq("settings: valid file has no errors", r.errors.Length, 0)

r := HS_BuildSettings(HS_ParseConfigText("ExpandWindowMs=abc`nInsertMethod=magic`nSwitchLayout=maybe"))
Eq("settings: three bad values reported", r.errors.Length, 3)
Eq("settings: bad number falls back", r.settings.expandMs, 2000)
Eq("settings: bad choice falls back", r.settings.insert, "paste")
Eq("settings: bad switch falls back", r.settings.switchLayout, true)

; --- tables --------------------------------------------------------------------
Eq("mac table: letters", HS_Convert("akuo nv bang", "en-he", mac), "שלום מה נשמע")
Eq("mac table: backtick is not mapped", HS_Convert("``", "en-he", mac), "``")
Throws("tables: layers of different length are refused", () => HS_TableFromLayers(["ab"], ["x"]))
letters := 0
for he, en in std.heToEn
    if HS_IsHebrewLetter(he)
        letters++
Eq("standard table covers all 27 Hebrew letters", letters, 27)

FileAppend("1.." T_Count "`n# passed " (T_Count - T_Failed) "/" T_Count "`n", "*", "UTF-8-RAW")
ExitApp(T_Failed)

; ---------------------------------------------------------------------------

Eq(name, actual, expected) {
    global T_Count, T_Failed
    T_Count++
    if (Type(actual) = Type(expected) && actual == expected) {
        T_Out("ok " T_Count " - " name)
        return
    }
    T_Failed++
    T_Out("not ok " T_Count " - " name)
    T_Out("  #  got:  [" T_Show(actual) "]")
    T_Out("  #  want: [" T_Show(expected) "]")
}

Throws(name, fn) {
    global T_Count, T_Failed
    T_Count++
    try {
        fn()
    } catch {
        T_Out("ok " T_Count " - " name)
        return
    }
    T_Failed++
    T_Out("not ok " T_Count " - " name " (nothing was thrown)")
}

T_Show(v) {
    if IsObject(v)
        return Type(v)
    codes := ""
    Loop Parse, String(v)
        codes .= Format(" {:04X}", Ord(A_LoopField))
    return v "] codes:[" Trim(codes)
}

T_Out(line) => FileAppend(line "`n", "*", "UTF-8-RAW")

T_OnError(e, mode) {
    T_Out("Bail out! " Type(e) ": " e.Message " (line " e.Line ")")
    ExitApp(100)
}
