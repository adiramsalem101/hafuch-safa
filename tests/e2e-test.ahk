; End-to-end test against the RUNNING hafuch-safa instance.
;
; Opens its own small editor window (a standard Edit control, like classic
; Notepad, and a RichEdit control, like WordPad), types into it with real
; keystrokes, presses the hotkey and checks three things after every case:
; the text, the keyboard layout of the window and the clipboard content.
;
; Keystrokes are sent only while the test window is the active window; if it
; loses focus the run stops at once. The user's clipboard and keyboard layout
; are saved first and put back at the end.
;
; Usage: AutoHotkey64.exe /ErrorStdOut e2e-test.ahk [path\to\config.ini]
; Output is TAP; the exit code is the number of failed cases.

#Requires AutoHotkey v2.0
#SingleInstance Off
#NoTrayIcon
#Include %A_ScriptDir%\..\lib\core.ahk
#Include %A_ScriptDir%\..\lib\system.ahk

SendMode "Event"
SetKeyDelay 10, 10
SendLevel 1            ; hafuch-safa ignores its own keystrokes (level 0) but must see these
DetectHiddenWindows true

global T := {count: 0, failed: 0}
global G := "", Ed := "", Re := "", UserClip := "", UserHkl := 0, HotkeySend := ""
SetTimer(() => Bail("the whole run took longer than 58 s"), -58000)
OnError(E2E_OnError)

cfgPath := A_Args.Length ? A_Args[1] : A_ScriptDir "\..\config.ini"
user := FileExist(cfgPath) ? HS_ParseConfigText(FileRead(cfgPath, "UTF-8")) : Map()
hk := HS_BuildSettings(user).settings.hotkey
HotkeySend := SubStr(hk.spec, 1, StrLen(hk.spec) - StrLen(hk.key)) "{" hk.key "}"
Out("# hotkey: " hk.display)

if !WinExist("hafuch-safa.ahk ahk_class AutoHotkey")
    Bail("hafuch-safa is not running (run install.ps1 or start hafuch-safa.ahk)")
if !(HS_FindHkl("he") && HS_FindHkl("en"))
    Bail("an English and a Hebrew keyboard layout must both be installed")

; Real keystrokes are used, so wait until nobody is using the keyboard or mouse.
idleStart := A_TickCount
while (A_TimeIdle < 1500) {
    if (A_TickCount - idleStart > 15000)
        Bail("the keyboard or mouse is in use; run the test again when the computer is idle")
    Sleep 100
}

UserClip := ClipboardAll()
UserHkl := HS_WindowHkl(HS_FocusHwnd(DllCall("GetForegroundWindow", "Ptr")))

G := Gui("+AlwaysOnTop", "hafuch-safa e2e test")
G.SetFont("s12", "Segoe UI")
G.Add("Text",, "Edit control (Notepad-like)")
Ed := G.Add("Edit", "w640 h70 Multi")
G.Add("Text",, "RichEdit control (WordPad-like)")
DllCall("LoadLibrary", "Str", "Msftedit.dll", "Ptr")
Re := G.Add("Custom", "ClassRICHEDIT50W w640 h70 +0x1004 +Border")
G.Show()
WinActivate("ahk_id " G.Hwnd)
if !WinWaitActive("ahk_id " G.Hwnd,, 5)
    Bail("could not activate the test window")

; name, control, layout before typing, typed text, expected text after each press, layout after
RunCase("en-he: one word", Ed, "en", "akuo", ["שלום"], "he", {customClip: true})
RunCase("he-en: one word typed on the Hebrew layout", Ed, "he", "יקךךם", ["hello"], "en")
RunCase("en-he: each press adds one word", Ed, "en", "akuo nv bang", ["akuo nv נשמע", "akuo מה נשמע", "שלום מה נשמע"], "he")
RunCase("en-he: punctuation keys", Ed, "en", "akuo' nv bang?", ["akuo' nv נשמע?", "akuo' מה נשמע?", "שלום, מה נשמע?"], "he")
RunCase("he-en: apostrophe and capitals", Ed, "he", "Iגםמ,א", ["Idon't"], "en")
RunCase("en-he: trailing space kept", Ed, "en", "akuo ", ["שלום "], "he")
RunCase("en-he: number after the word", Ed, "en", "akuo 123", ["שלום 123"], "he")
RunCase("selection: only the selection flips", Ed, "en", "hello world", ["יקךךם 'םרךג"], "he", {select: "+{Home}"})
RunCase("again after the time window: exact restore", Ed, "en", "Hello", ["יקךךם", "Hello"], "en", {gapMs: 2300})
RunCase("no typing known: word before the caret", Ed, "en", "", ["שלום"], "he", {preset: "akuo"})
RunCase("richedit: each press adds one word", Re, "en", "akuo nv bang", ["akuo nv נשמע", "akuo מה נשמע", "שלום מה נשמע"], "he")
RunCase("richedit: he-en", Re, "he", "יקךךם 'םרךג", ["יקךךם world", "hello world"], "en")
Finish()

; ---------------------------------------------------------------------------

RunCase(name, ctrl, startLang, typed, steps, wantLang, opts := {}) {
    t0 := A_TickCount
    ok := true, detail := ""
    try {
        custom := opts.HasOwnProp("customClip")
        sentinel := "hafuch-safa-sentinel-" A_TickCount
        PrepareClipboard(sentinel, custom)
        Guard()
        ctrl.Focus()
        ControlSetText(opts.HasOwnProp("preset") ? opts.preset : "", ctrl)
        if !SetLang(startLang)
            throw Error("could not set the starting layout to " startLang)
        ; A navigation key also makes the tool forget everything typed before.
        Keys(opts.HasOwnProp("preset") ? "^{End}" : "{End}")
        if (typed != "") {
            Guard()
            SendText typed
        }
        if opts.HasOwnProp("select")
            Keys(opts.select)
        Sleep 150
        for i, want in steps {
            if (i > 1)
                Sleep(opts.HasOwnProp("gapMs") ? opts.gapMs : 150)
            Keys(HotkeySend)
            if !WaitText(ctrl, want, 5000)
                throw Error("after press " i ": text is [" ControlGetText(ctrl) "], want [" want "]")
        }
        Sleep 400   ; the clipboard restore and the layout switch end right after the text
        lang := HS_LangOfHkl(HS_WindowHkl(ctrl.Hwnd))
        if (lang != wantLang)
            throw Error("keyboard layout is [" lang "], want [" wantLang "]")
        if !ClipboardIs(sentinel, custom)
            throw Error("clipboard not restored, it holds [" SubStr(A_Clipboard, 1, 40) "]")
        if (A_TickCount - t0 > 30000)
            throw Error("took longer than 30 s")
    } catch as e {
        ok := false, detail := e.Message
    }
    Report(ok, name " (" Round((A_TickCount - t0) / 1000, 1) " s)", detail)
}

Guard() {
    if WinActive("ahk_id " G.Hwnd)
        return
    fg := DllCall("GetForegroundWindow", "Ptr"), who := "none"
    if fg
        try who := WinGetProcessName("ahk_id " fg) " / " WinGetClass("ahk_id " fg)
    Bail("the test window lost focus to [" who "]; stopped so no keys go to another window")
}

Keys(keys) {
    Guard()
    Send keys
}

WaitText(ctrl, want, ms) {
    t0 := A_TickCount
    while (A_TickCount - t0 < ms) {
        if (ControlGetText(ctrl) == want)
            return true
        Sleep 25
    }
    return false
}

SetLang(lang) {
    hkl := HS_FindHkl(lang)
    focus := HS_FocusHwnd(G.Hwnd)
    Loop 3 {
        DllCall("PostMessageW", "Ptr", focus, "UInt", 0x50, "Ptr", 0, "Ptr", hkl)
        Loop 25 {
            Sleep 20
            if (HS_LangOfHkl(HS_WindowHkl(G.Hwnd)) = lang)
                return true
        }
    }
    return false
}

TestFormat() => DllCall("RegisterClipboardFormatW", "Str", "hafuch-safa-test-bytes", "UInt")

; Text sentinel, optionally with a custom binary format next to it, to prove
; the whole clipboard (not only its text) comes back.
PrepareClipboard(sentinel, custom) {
    if !HS_Clip.Open()
        throw Error("could not open the clipboard")
    DllCall("EmptyClipboard")
    DllCall("SetClipboardData", "UInt", 13, "Ptr", HS_Clip.GlobalText(sentinel))
    if custom {
        h := DllCall("GlobalAlloc", "UInt", 0x42, "UPtr", 16, "Ptr")
        p := DllCall("GlobalLock", "Ptr", h, "Ptr")
        Loop 16
            NumPut("UChar", 0x10 + A_Index, p, A_Index - 1)
        DllCall("GlobalUnlock", "Ptr", h)
        DllCall("SetClipboardData", "UInt", TestFormat(), "Ptr", h)
    }
    for f in HS_Clip.PrivacyFormats()
        DllCall("SetClipboardData", "UInt", f[1], "Ptr", HS_Clip.GlobalDword(f[2]))
    DllCall("CloseClipboard")
}

ClipboardIs(sentinel, custom) {
    if (A_Clipboard !== sentinel)
        return false
    if !custom
        return true
    good := false
    if HS_Clip.Open() {
        h := DllCall("GetClipboardData", "UInt", TestFormat(), "Ptr")
        if h {
            p := DllCall("GlobalLock", "Ptr", h, "Ptr")
            good := true
            Loop 16
                good := good && NumGet(p, A_Index - 1, "UChar") = 0x10 + A_Index
            DllCall("GlobalUnlock", "Ptr", h)
        }
        DllCall("CloseClipboard")
    }
    return good
}

Report(ok, name, detail) {
    T.count++
    if ok {
        Out("ok " T.count " - " name)
        return
    }
    T.failed++
    Out("not ok " T.count " - " name)
    Out("  # " detail)
}

Out(line) => FileAppend(line "`n", "*", "UTF-8-RAW")

Cleanup() {
    static done := false
    if done
        return
    done := true
    try {
        if (UserHkl && IsObject(G)) {
            DllCall("PostMessageW", "Ptr", HS_FocusHwnd(G.Hwnd), "UInt", 0x50, "Ptr", 0, "Ptr", UserHkl)
            Sleep 200
        }
    }
    try G.Destroy()
    try HS_Clip.Restore(UserClip)
}

Finish() {
    Out("1.." T.count)
    Out("# passed " (T.count - T.failed) "/" T.count)
    Cleanup()
    ExitApp(T.failed)
}

Bail(msg) {
    Out("Bail out! " msg)
    Cleanup()
    ExitApp(99)
}

E2E_OnError(e, mode) {
    Bail("script error: " e.Message " (line " e.Line ")")
    return 1
}
