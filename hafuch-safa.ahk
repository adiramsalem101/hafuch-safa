; hafuch-safa (הפוך שפה)
; Flips text typed in the wrong keyboard layout between Hebrew and English,
; then switches the Windows keyboard layout so you can keep typing.
;
;   * Selected text: the selection is flipped.
;   * No selection: the last typed word is flipped; pressing again within
;     ExpandWindowMs extends the flip one word back each time.
;   * The direction comes from the majority of letters.
;
; Settings: config.ini next to this file. License: MIT.

#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_ScriptDir%\lib\core.ahk
#Include %A_ScriptDir%\lib\layouts.ahk
#Include %A_ScriptDir%\lib\system.ahk

global HS_VERSION := "1.0.0"
global HS_HOMEPAGE := "https://github.com/adiramsalem101/hafuch-safa"
global HS_ConfigPath := A_ScriptDir "\config.ini"
global HS_Cfg := ""                 ; validated settings (see HS_BuildSettings)
global HS_Table := ""               ; conversion table in use
global HS_TableSource := ""
global HS_HotkeyVK := 0
; What was typed right before the caret in the focused window, as far as we
; know. shadow holds what each character was before the last flip.
global HS_Buf := {text: "", shadow: "", hwnd: 0, version: 0}
; The last flip, for pressing again (extend or toggle back).
global HS_Chain := {hwnd: 0, version: -1, tick: 0, len: 0, dir: "", kind: ""}
global HS_KeyUp := true             ; false while the hotkey key is held (auto-repeat)
global HS_SkipChar := ""            ; character the hotkey itself may type (AltGr layouts)
global HS_Hook := ""
global HS_WarnedMissing := false

HS_Main()

; Any click may move the caret: forget what was typed.
~*LButton::HS_ResetBuffer()
~*RButton::HS_ResetBuffer()
~*MButton::HS_ResetBuffer()
~*XButton1::HS_ResetBuffer()
~*XButton2::HS_ResetBuffer()

HS_Main() {
    global HS_Cfg, HS_HotkeyVK
    user := Map()
    try {
        if FileExist(HS_ConfigPath)
            user := HS_ParseConfigText(FileRead(HS_ConfigPath, "UTF-8"))
    } catch as e {
        HS_Warn("לא ניתן לקרוא את קובץ ההגדרות, ממשיכים עם ברירות המחדל.`n`n" HS_ConfigPath "`n" e.Message)
    }
    built := HS_BuildSettings(user)
    HS_Cfg := built.settings
    if built.errors.Length
        HS_Warn("בקובץ ההגדרות יש ערכים לא תקינים, ובמקומם נעשה שימוש בברירת המחדל:`n`n" HS_Join(built.errors, "`n"))
    HS_HotkeyVK := GetKeyVK(HS_Cfg.hotkey.key)
    HS_LoadTable()
    HS_SetupTray()
    HS_StartWatcher()
    HS_RegisterHotkey()
}

HS_LoadTable() {
    global HS_Table, HS_TableSource
    if (HS_Cfg.layout = "auto") {
        if (sys := HS_SystemTable()) {
            HS_Table := sys.table
            HS_TableSource := "auto (installed layouts)"
            return
        }
        HS_Table := HS_StaticTable("standard")
        HS_TableSource := "standard (English or Hebrew layout not installed)"
        return
    }
    HS_Table := HS_StaticTable(HS_Cfg.layout)
    HS_TableSource := HS_Cfg.layout
}

HS_RegisterHotkey() {
    h := HS_Cfg.hotkey
    try {
        if HS_Cfg.excludeApps.Length {
            HotIf HS_HotkeyAllowed
            Hotkey h.spec, HS_OnHotkey, "On B"
            HotIf
        } else {
            Hotkey h.spec, HS_OnHotkey, "On B"
        }
        Hotkey "~*" h.key " up", HS_OnHotkeyUp, "On"
    } catch as e {
        HS_Warn("לא ניתן להגדיר את הקיצור " h.display "`n" e.Message)
        ExitApp 1
    }
}

HS_HotkeyAllowed(*) => !HS_InList(HS_ProcessName(WinExist("A")), HS_Cfg.excludeApps)

HS_OnHotkeyUp(*) {
    global HS_KeyUp := true
}

; ---------------------------------------------------------------------------
; Typing watcher: remembers the characters typed before the caret
; ---------------------------------------------------------------------------

HS_StartWatcher() {
    global HS_Hook
    ; V: keys still reach the application. I1: ignore keys sent by this script.
    ; L0: no internal buffer, only the callbacks below.
    HS_Hook := InputHook("V I1 L0")
    HS_Hook.KeyOpt("{All}", "N")
    HS_Hook.OnChar := HS_OnChar
    HS_Hook.OnKeyDown := HS_OnKeyDown
    HS_Hook.Start()
}

HS_OnKeyDown(ih, vk, sc) {
    global HS_SkipChar
    switch vk {
        case 0x10, 0x11, 0x12, 0x14, 0x5B, 0x5C, 0x90, 0x91, 0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5:
            return   ; modifier and lock keys on their own change nothing
    }
    if (vk = HS_HotkeyVK && HS_HotkeyModsDown()) {
        HS_SkipChar := HS_HotkeyChar(sc)
        return
    }
    ctrl := GetKeyState("Ctrl"), alt := GetKeyState("Alt")
    if (GetKeyState("LWin") || GetKeyState("RWin") || ctrl != alt) {
        HS_ResetBuffer()   ; a shortcut: paste, undo, word delete, window switch...
        return
    }
    switch vk {
        case 0x08:
            HS_BufferBackspace()
        case 0x09, 0x0D, 0x1B, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x2D:
            HS_ResetBuffer()   ; Tab, Enter, Esc, page and arrow keys, Home, End, Insert
    }
}

HS_OnChar(ih, ch) {
    global HS_SkipChar
    if (HS_SkipChar != "") {
        skip := HS_SkipChar
        HS_SkipChar := ""
        if (ch == skip)
            return
    }
    ch := RegExReplace(ch, "[\x00-\x1F\x7F]")
    if (ch = "")
        return
    hwnd := DllCall("GetForegroundWindow", "Ptr")
    if (hwnd != HS_Buf.hwnd)
        HS_ResetBuffer(hwnd)
    HS_Buf.text .= ch
    HS_Buf.shadow .= ch
    HS_Buf.version++
    if (StrLen(HS_Buf.text) > 500) {
        HS_Buf.text := SubStr(HS_Buf.text, -300)
        HS_Buf.shadow := SubStr(HS_Buf.shadow, -300)
    }
}

HS_ResetBuffer(hwnd := 0) {
    HS_Buf.text := "", HS_Buf.shadow := "", HS_Buf.hwnd := hwnd
    HS_Buf.version++
}

HS_BufferBackspace() {
    if (HS_Buf.text != "") {
        cut := (Ord(SubStr(HS_Buf.text, -1)) >= 0xDC00 && Ord(SubStr(HS_Buf.text, -1)) <= 0xDFFF) ? 2 : 1
        HS_Buf.text := SubStr(HS_Buf.text, 1, -cut)
        HS_Buf.shadow := SubStr(HS_Buf.shadow, 1, -cut)
    }
    HS_Buf.version++
}

HS_HotkeyModsDown() {
    for m in HS_Cfg.hotkey.mods
        if !GetKeyState(m)
            return false
    return true
}

; On layouts with AltGr (Hebrew (Standard) types ” on Ctrl+Alt+L) the hotkey
; can produce a character; it must not end up in the typing buffer.
HS_HotkeyChar(sc) {
    mods := HS_Cfg.hotkey.mods
    ctrl := false, alt := false, shift := false
    for m in mods {
        ctrl := ctrl || m = "Ctrl"
        alt := alt || m = "Alt"
        shift := shift || m = "Shift"
    }
    if !(ctrl && alt)
        return ""
    return HS_KeyChar(HS_WindowHkl(HS_FocusHwnd(DllCall("GetForegroundWindow", "Ptr"))), sc, shift, true)
}

; ---------------------------------------------------------------------------
; The hotkey
; ---------------------------------------------------------------------------

HS_OnHotkey(*) {
    global HS_KeyUp
    pressTick := A_TickCount
    if (!HS_KeyUp && GetKeyState(HS_Cfg.hotkey.key, "P"))
        return   ; auto-repeat while the key is held down
    HS_KeyUp := false
    ; Let go of Ctrl/Alt first, so Backspace and Ctrl+V reach the app clean.
    for m in HS_Cfg.hotkey.mods
        KeyWait m, "L T1"
    hwnd := DllCall("GetForegroundWindow", "Ptr")
    if !hwnd
        return
    HS_Log("press: app=" HS_ProcessName(hwnd) " buffer=" StrLen(HS_Buf.text) " chars, same window=" (HS_Buf.hwnd = hwnd) " chain=" HS_Chain.kind "/" (HS_Chain.version = HS_Buf.version) "/" (pressTick - HS_Chain.tick) "ms")
    try {
        HS_Flip(hwnd, pressTick)
    } catch as e {
        HS_Log("error: " e.Message " line " e.Line)
        HS_Tip("הפוך שפה: " e.Message)
    }
}

HS_Flip(hwnd, pressTick) {
    isTerm := HS_IsTerminal(hwnd)
    bufValid := (HS_Buf.hwnd = hwnd && HS_Buf.text != "")
    if (bufValid && HS_Chain.hwnd = hwnd && HS_Chain.version = HS_Buf.version
            && pressTick - HS_Chain.tick <= HS_Cfg.expandMs) {
        if (HS_Chain.kind = "word")
            return HS_ExpandChain(hwnd, isTerm)
        ; Pressed again right after flipping a selection: flip it back.
        return HS_FlipTail(hwnd, isTerm, HS_Chain.len, HS_Opposite(HS_Chain.dir), "toggle")
    }
    if bufValid {
        start := HS_FlipSpanStart(HS_Buf.text)
        if (start > 0) {
            span := SubStr(HS_Buf.text, start)
            dir := HS_DetectDirection(span, HS_TieDirection(hwnd))
            return HS_FlipTail(hwnd, isTerm, StrLen(span), dir, "word")
        }
    }
    if isTerm
        return HS_Tip("הקלד מילה ואז לחץ " HS_Cfg.hotkey.display)
    if HS_IsShellWindow(hwnd)
        return HS_Tip("אין כאן טקסט להפיכה")
    HS_FlipSelection(hwnd)
}

; Flips the last n characters of the buffer, which sit right before the caret.
HS_FlipTail(hwnd, isTerm, n, dir, kind) {
    global HS_Chain
    text := HS_Buf.text, shadow := HS_Buf.shadow
    keep := StrLen(text) - n
    tail := SubStr(text, keep + 1)
    flipped := HS_ConvertWithShadow(tail, SubStr(shadow, keep + 1), dir, HS_Table)
    HS_Log("flip " kind ": " n " chars " dir (isTerm ? " (terminal)" : ""))
    ; Switch first: the new text is then typed as real keys of the target layout.
    HS_SwitchTo(hwnd, dir)
    if (flipped == tail)
        return
    if !HS_ReplaceBeforeCaret(hwnd, isTerm, tail, flipped)
        return
    HS_Buf.text := SubStr(text, 1, keep) flipped
    HS_Buf.shadow := SubStr(shadow, 1, keep) tail
    HS_Buf.version++
    HS_Chain := {hwnd: hwnd, version: HS_Buf.version, tick: A_TickCount, len: n, dir: dir, kind: kind}
}

; Pressed again within the time window: flip one more word to the left.
HS_ExpandChain(hwnd, isTerm) {
    global HS_Chain
    text := HS_Buf.text, shadow := HS_Buf.shadow
    n := HS_Chain.len
    keep := StrLen(text) - n
    prefix := SubStr(text, 1, keep)
    start := HS_LastWordStart(prefix)
    if (start = 0) {
        HS_Chain.tick := A_TickCount
        return HS_Tip("אין עוד מילים מוכרות לפני. סמן את הטקסט ולחץ שוב")
    }
    added := SubStr(prefix, start)
    span := SubStr(text, keep + 1)
    HS_Log("extend: +" StrLen(added) " chars " HS_Chain.dir)
    flippedAdded := HS_ConvertWithShadow(added, SubStr(shadow, start, StrLen(added)), HS_Chain.dir, HS_Table)
    HS_SwitchTo(hwnd, HS_Chain.dir)
    if !HS_ReplaceBeforeCaret(hwnd, isTerm, added span, flippedAdded span)
        return
    HS_Buf.text := SubStr(text, 1, start - 1) flippedAdded span
    HS_Buf.shadow := SubStr(shadow, 1, start - 1) added SubStr(shadow, keep + 1)
    HS_Buf.version++
    HS_Chain := {hwnd: hwnd, version: HS_Buf.version, tick: A_TickCount, len: n + StrLen(added), dir: HS_Chain.dir, kind: "word"}
}

; Nothing typed is known here: flip the selection, or select the word before
; the caret (Ctrl+Shift+Left) and flip that.
HS_FlipSelection(hwnd) {
    global HS_Chain
    saved := HS_Clip.Snapshot()
    if !IsObject(saved)
        return HS_Tip("הלוח תפוס כרגע, נסה שוב")
    lineCopy := HS_InList(HS_ProcessName(hwnd), HS_Cfg.lineCopyApps)
    copyKeys := lineCopy ? "^{Insert}" : "^{vk43}"
    kind := "selection"
    text := HS_CopySelection(hwnd, copyKeys, 500)
    if (text != "" && lineCopy && RegExMatch(text, "\R$"))
        text := ""   ; code editors copy the whole line when nothing is selected
    if (text = "") {
        kind := "word"
        text := HS_SelectPreviousWord(hwnd, copyKeys)
    }
    if (text = "") {
        HS_Clip.Restore(saved)
        return HS_Tip("לא נמצא טקסט להפיכה. סמן טקסט ולחץ שוב")
    }
    dir := HS_DetectDirection(text, HS_TieDirection(hwnd))
    flipped := HS_Convert(text, dir, HS_Table)
    HS_Log("flip " kind " (read with the clipboard): " StrLen(text) " chars " dir)
    HS_SwitchTo(hwnd, dir)
    if (flipped == text) {
        HS_Clip.Restore(saved)
        return
    }
    if (HS_Cfg.insert = "paste") {
        ok := HS_PasteText(hwnd, flipped)
        HS_Clip.Restore(saved)
    } else {
        HS_Clip.Restore(saved)
        ok := HS_TypeText(hwnd, flipped)   ; typing replaces the selection
    }
    if !ok
        return
    HS_Buf.text := flipped, HS_Buf.shadow := text, HS_Buf.hwnd := hwnd
    HS_Buf.version++
    HS_Chain := {hwnd: hwnd, version: HS_Buf.version, tick: A_TickCount, len: StrLen(flipped), dir: dir, kind: kind}
}

HS_CopySelection(hwnd, copyKeys, timeoutMs) {
    try A_Clipboard := ""
    catch
        return ""
    if !WinActive("ahk_id " hwnd)
        return ""
    Send copyKeys
    if !ClipWait(timeoutMs / 1000)
        return ""
    if DllCall("IsClipboardFormatAvailable", "UInt", 15)   ; files were copied, not text
        return ""
    return A_Clipboard
}

HS_SelectPreviousWord(hwnd, copyKeys) {
    if !WinActive("ahk_id " hwnd)
        return ""
    Send "^+{Left}"
    text := HS_CopySelection(hwnd, copyKeys, 400)
    if (text = "") {
        ; Some editors move visually inside right-to-left text, where the
        ; previous word is on the right.
        if !WinActive("ahk_id " hwnd)
            return ""
        Send "^+{Right}"
        return HS_CopySelection(hwnd, copyKeys, 400)
    }
    Loop 2 {
        ; The selection may hold punctuation only: take one more word.
        c := HS_CountLetters(text)
        if (c.latin + c.hebrew > 0 || !WinActive("ahk_id " hwnd))
            break
        Send "^+{Left}"
        more := HS_CopySelection(hwnd, copyKeys, 400)
        if (more = "" || more == text)
            break
        text := more
    }
    return text
}

; ---------------------------------------------------------------------------
; Writing the result
; ---------------------------------------------------------------------------

HS_ReplaceBeforeCaret(hwnd, isTerm, oldText, newText) {
    if !WinActive("ahk_id " hwnd) {
        HS_Log("replace: window no longer active, nothing sent")
        return false
    }
    same := HS_CommonPrefixLength(oldText, newText)
    count := HS_BackspaceCount(SubStr(oldText, same + 1))
    HS_Log("replace: backspaces=" count " insert=" (StrLen(newText) - same) " chars")
    if (count > 0)
        Send "{Backspace " count "}"
    return HS_Insert(hwnd, isTerm, SubStr(newText, same + 1))
}

; Default: type the text as keystrokes. A paste can silently fail when another
; program reads the clipboard at the same moment (see ASSUMPTIONS.md), and
; that would leave the old word deleted with nothing in its place.
HS_Insert(hwnd, isTerm, text) {
    if (text = "")
        return true
    if ((isTerm ? HS_Cfg.termInsert : HS_Cfg.insert) = "paste") {
        saved := HS_Clip.Snapshot()
        if IsObject(saved) {
            ok := HS_PasteText(hwnd, text)
            HS_Clip.Restore(saved)
            return ok
        }
    }
    return HS_TypeText(hwnd, text)
}

HS_TypeText(hwnd, text) {
    if !WinActive("ahk_id " hwnd) {
        HS_Log("type: window no longer active, " StrLen(text) " chars not typed")
        return false
    }
    HS_Log("type: " StrLen(text) " chars")
    SendText text
    return true
}

; InsertMethod=paste: puts the text on the clipboard (kept out of clipboard
; history), presses Ctrl+V and gives the application PasteRestoreDelayMs to
; read it. The caller puts the user's clipboard back afterwards.
HS_PasteText(hwnd, text) {
    if !WinActive("ahk_id " hwnd) {
        HS_Log("paste: window no longer active")
        return false
    }
    if !HS_Clip.SetPrivateText(text) {
        HS_Log("paste: clipboard busy, typing instead")
        return HS_TypeText(hwnd, text)
    }
    HS_Log("paste: " StrLen(text) " chars")
    Send "^{vk56}"
    Sleep HS_Cfg.pasteRestoreMs
    return true
}

HS_SwitchTo(hwnd, dir) {
    global HS_WarnedMissing
    if !HS_Cfg.switchLayout
        return
    lang := HS_TargetLang(dir)
    if HS_FindHkl(lang)
        HS_Log("layout: switch to " lang " -> " (HS_SwitchLayout(hwnd, lang) ? "ok" : "failed"))
    else if !HS_WarnedMissing {
        HS_WarnedMissing := true
        HS_Tip(lang = "he" ? "פריסת מקלדת עברית לא מותקנת, אין לאן לעבור" : "פריסת מקלדת אנגלית לא מותקנת, אין לאן לעבור")
    }
}

; Direction for text without a letter majority: it was typed on the layout
; that is active now, so flip away from it.
HS_TieDirection(hwnd) => (HS_CurrentLang(hwnd) = "he") ? "he-en" : "en-he"

HS_IsTerminal(hwnd) {
    cls := HS_ClassName(hwnd)
    if (cls = "ConsoleWindowClass" || cls = "CASCADIA_HOSTING_WINDOW_CLASS" || cls = "mintty" || cls = "PuTTY" || cls = "VirtualConsoleClass")
        return true
    return HS_InList(HS_ProcessName(hwnd), HS_Cfg.terminalApps)
}

HS_IsShellWindow(hwnd) {
    cls := HS_ClassName(hwnd)
    return (cls = "CabinetWClass" || cls = "ExploreWClass" || cls = "Progman" || cls = "WorkerW" || cls = "Shell_TrayWnd")
}

; ---------------------------------------------------------------------------
; Tray menu and messages
; ---------------------------------------------------------------------------

HS_SetupTray() {
    A_IconTip := "הפוך שפה (" HS_Cfg.hotkey.display ")"
    icon := A_ScriptDir "\assets\hafuch-safa.ico"
    if FileExist(icon)
        TraySetIcon(icon)
    m := A_TrayMenu
    m.Delete()
    title := "הפוך שפה " HS_VERSION
    m.Add(title, HS_ShowAbout)
    m.Add()
    m.Add("השהה", HS_TogglePause)
    m.Add("פתח את קובץ ההגדרות", (*) => Run('notepad.exe "' HS_ConfigPath '"'))
    m.Add("טען מחדש", (*) => Reload())
    m.Add()
    m.Add("יציאה", (*) => ExitApp())
    m.Default := title
}

HS_TogglePause(itemName, *) {
    static paused := false
    paused := !paused
    Suspend(paused ? 1 : 0)
    if paused
        HS_Hook.Stop()
    else
        HS_Hook.Start()
    HS_ResetBuffer()
    A_TrayMenu.ToggleCheck(itemName)
    A_IconTip := "הפוך שפה (" HS_Cfg.hotkey.display ")" (paused ? " מושהה" : "")
}

HS_ShowAbout(*) {
    MsgBox("הפוך שפה " HS_VERSION "`n`n"
        . "קיצור: " HS_Cfg.hotkey.display "`n"
        . "טבלת מיפוי: " HS_TableSource "`n"
        . "קובץ הגדרות: " HS_ConfigPath "`n`n"
        . HS_HOMEPAGE, "הפוך שפה", 0x180040)
}

HS_Tip(msg) {
    if !HS_Cfg.showTips
        return
    ToolTip(msg)
    SetTimer(() => ToolTip(), -2500)
}

HS_Warn(msg) => MsgBox(msg, "הפוך שפה", 0x180030)

; DebugLog=1 in config.ini: one line per step in %TEMP%\hafuch-safa-debug.log.
; Only lengths and results are written, never the text itself.
HS_Log(msg) {
    if !(IsObject(HS_Cfg) && HS_Cfg.debugLog)
        return
    try FileAppend(FormatTime(, "HH:mm:ss") "." Format("{:03}", A_MSec) " " msg "`n", A_Temp "\hafuch-safa-debug.log", "UTF-8")
}
