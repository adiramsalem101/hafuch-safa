; hafuch-safa: everything that talks to Windows (keyboard layouts, clipboard,
; windows). Kept apart from core.ahk so the pure logic stays testable.

#Requires AutoHotkey v2.0

; ---------------------------------------------------------------------------
; Keyboard layouts
; ---------------------------------------------------------------------------

; Handles (HKL) of the keyboard layouts the user installed, in their order.
HS_InstalledHkls() {
    n := DllCall("GetKeyboardLayoutList", "Int", 0, "Ptr", 0, "Int")
    if (n <= 0)
        return []
    buf := Buffer(n * A_PtrSize, 0)
    n := DllCall("GetKeyboardLayoutList", "Int", n, "Ptr", buf, "Int")
    list := []
    Loop n
        list.Push(NumGet(buf, (A_Index - 1) * A_PtrSize, "Ptr"))
    return list
}

; "he", "en" or "" for a layout handle (the low word is the language id).
HS_LangOfHkl(hkl) {
    lid := hkl & 0xFFFF
    if (lid = 0x040D)
        return "he"
    if ((lid & 0x3FF) = 0x09)
        return "en"
    return ""
}

HS_FindHkl(lang) {
    for hkl in HS_InstalledHkls()
        if (HS_LangOfHkl(hkl) = lang)
            return hkl
    return 0
}

; The control that has keyboard focus inside a top-level window (the edit box
; of a browser, the message field of a chat app); the window itself if unknown.
HS_FocusHwnd(hwnd) {
    tid := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
    size := 8 + A_PtrSize * 6 + 16
    gti := Buffer(size, 0)
    NumPut("UInt", size, gti, 0)
    if (tid && DllCall("GetGUIThreadInfo", "UInt", tid, "Ptr", gti)) {
        focus := NumGet(gti, 8 + A_PtrSize, "Ptr")
        if focus
            return focus
    }
    return hwnd
}

HS_WindowHkl(hwnd) {
    tid := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
    return DllCall("GetKeyboardLayout", "UInt", tid, "Ptr")
}

; Language of the layout active in a window: "he", "en" or "".
HS_CurrentLang(hwnd) => HS_LangOfHkl(HS_WindowHkl(HS_FocusHwnd(hwnd)))

; Asks the focused window to switch to the first installed layout of lang.
; Only switches between layouts the user already installed; never adds one.
HS_SwitchLayout(hwnd, lang) {
    hkl := HS_FindHkl(lang)
    if !hkl
        return false
    focus := HS_FocusHwnd(hwnd)
    if (HS_LangOfHkl(HS_WindowHkl(focus)) = lang)
        return true
    for target in (focus != hwnd ? [focus, hwnd] : [hwnd]) {
        DllCall("PostMessageW", "Ptr", target, "UInt", 0x50, "Ptr", 0, "Ptr", hkl)   ; WM_INPUTLANGCHANGEREQUEST
        Loop 15 {
            Sleep 20
            if (HS_LangOfHkl(HS_WindowHkl(focus)) = lang)
                return true
        }
    }
    return false
}

; Registry id (KLID) of a layout handle, for example "0002040D".
HS_LayoutKlid(hkl) {
    hi := (hkl >> 16) & 0xFFFF
    if ((hi & 0xF000) != 0xF000)
        return Format("{:08X}", hi)
    layoutId := hi & 0x0FFF
    Loop Reg, "HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layouts", "K" {
        id := RegRead(A_LoopRegKey "\" A_LoopRegName, "Layout Id", "")
        if (id != "" && Integer("0x" id) = layoutId)
            return StrUpper(A_LoopRegName)
    }
    return ""
}

; Display name of a layout handle, for example "Hebrew (Standard)".
HS_LayoutName(hkl) {
    klid := HS_LayoutKlid(hkl)
    if (klid = "")
        return ""
    return RegRead("HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\" klid, "Layout Text", klid)
}

; Character a key types on a layout, read without touching the keyboard state.
HS_KeyChar(hkl, sc, shift := false, altGr := false) {
    vk := DllCall("MapVirtualKeyExW", "UInt", sc, "UInt", 1, "Ptr", hkl, "UInt")   ; MAPVK_VSC_TO_VK
    if !vk
        return ""
    state := Buffer(256, 0)
    if shift
        NumPut("UChar", 0x80, state, 0x10)
    if altGr {
        NumPut("UChar", 0x80, state, 0x11)
        NumPut("UChar", 0x80, state, 0x12)
    }
    out := Buffer(16, 0)
    ; Flag 4: do not change the keyboard state (Windows 10 1607 and later).
    n := DllCall("ToUnicodeEx", "UInt", vk, "UInt", sc, "Ptr", state, "Ptr", out, "Int", 8, "UInt", 4, "Ptr", hkl, "Int")
    return (n = 1) ? StrGet(out, 1, "UTF-16") : ""
}

; Scan codes of the typing keys, row by row (US order).
HS_TypingScanCodes() {
    codes := [0x29]
    Loop 12
        codes.Push(0x01 + A_Index)   ; 1 .. =
    Loop 12
        codes.Push(0x0F + A_Index)   ; q .. ]
    codes.Push(0x2B)                 ; \
    Loop 11
        codes.Push(0x1D + A_Index)   ; a .. '
    Loop 10
        codes.Push(0x2B + A_Index)   ; z .. /
    codes.Push(0x56)                 ; extra key on ISO keyboards
    return codes
}

; Conversion table read from the installed English and Hebrew layouts, so any
; variant (Hebrew, Hebrew (Standard), Hebrew (Standard, 2018), Dvorak...) maps
; exactly. Returns {table, enHkl, heHkl} or 0 when one of them is missing.
HS_SystemTable() {
    enHkl := HS_FindHkl("en"), heHkl := HS_FindHkl("he")
    if !(enHkl && heHkl)
        return 0
    pairs := []
    for shift in [false, true]
        for sc in HS_TypingScanCodes() {
            en := HS_KeyChar(enHkl, sc, shift)
            if (shift && HS_IsLatinLetter(en))
                continue   ; capitals follow the letter-case rule in core.ahk
            pairs.Push([en, HS_KeyChar(heHkl, sc, shift)])
        }
    return {table: HS_TableFromPairs(pairs), enHkl: enHkl, heHkl: heHkl}
}

; ---------------------------------------------------------------------------
; Windows
; ---------------------------------------------------------------------------

HS_ProcessName(hwnd) {
    try return WinGetProcessName("ahk_id " hwnd)
    return ""
}

HS_ClassName(hwnd) {
    try return WinGetClass("ahk_id " hwnd)
    return ""
}

HS_WinPid(hwnd) {
    try return WinGetPID("ahk_id " hwnd)
    return 0
}

HS_InList(item, list) {
    item := StrLower(item)
    for x in list
        if (x = item)
            return true
    return false
}

; ---------------------------------------------------------------------------
; Clipboard
; ---------------------------------------------------------------------------

class HS_Clip {
    static offered := ""       ; text waiting to be pasted
    static pending := false
    static renderTick := 0     ; when an application asked for the text
    static renderPid := 0      ; which process asked (0 = unknown)
    static ready := false

    static Init() {
        if this.ready
            return
        OnMessage(0x0305, ObjBindMethod(this, "OnRenderFormat"))       ; WM_RENDERFORMAT
        OnMessage(0x0306, ObjBindMethod(this, "OnRenderAllFormats"))   ; WM_RENDERALLFORMATS
        this.ready := true
    }

    ; Registered formats that ask Windows clipboard history, cloud clipboard
    ; and clipboard managers to ignore the content. [format id, DWORD value]
    static PrivacyFormats() {
        static formats := ""
        if !formats
            formats := [
                [DllCall("RegisterClipboardFormatW", "Str", "ExcludeClipboardContentFromMonitorProcessing", "UInt"), 1],
                [DllCall("RegisterClipboardFormatW", "Str", "CanIncludeInClipboardHistory", "UInt"), 0],
                [DllCall("RegisterClipboardFormatW", "Str", "CanUploadToCloudClipboard", "UInt"), 0],
                [DllCall("RegisterClipboardFormatW", "Str", "Clipboard Viewer Ignore", "UInt"), 0]
            ]
        return formats
    }

    static Snapshot() {
        try return ClipboardAll()
        return ""
    }

    static Open() {
        Loop 25 {
            if DllCall("OpenClipboard", "Ptr", A_ScriptHwnd)
                return true
            Sleep 20
        }
        return false
    }

    static GlobalText(text) {
        h := DllCall("GlobalAlloc", "UInt", 0x42, "UPtr", (StrLen(text) + 1) * 2, "Ptr")
        if h {
            StrPut(text, DllCall("GlobalLock", "Ptr", h, "Ptr"), "UTF-16")
            DllCall("GlobalUnlock", "Ptr", h)
        }
        return h
    }

    static GlobalDword(value) {
        h := DllCall("GlobalAlloc", "UInt", 0x42, "UPtr", 4, "Ptr")
        if h {
            NumPut("UInt", value, DllCall("GlobalLock", "Ptr", h, "Ptr"))
            DllCall("GlobalUnlock", "Ptr", h)
        }
        return h
    }

    ; Puts text on the clipboard with delayed rendering: Windows asks this
    ; script for the text only when an application reads it, which tells us
    ; exactly when the paste happened, so the user's clipboard can be put
    ; back right away instead of after a guessed delay.
    static Offer(text) {
        this.Init()
        if !this.Open()
            return false
        DllCall("EmptyClipboard")
        this.offered := text
        this.pending := true
        this.renderTick := 0
        this.renderPid := 0
        DllCall("SetClipboardData", "UInt", 13, "Ptr", 0)   ; CF_UNICODETEXT, rendered on request
        for f in this.PrivacyFormats()
            DllCall("SetClipboardData", "UInt", f[1], "Ptr", this.GlobalDword(f[2]))
        DllCall("CloseClipboard")
        return true
    }

    static OnRenderFormat(wParam, lParam, msg, hwnd) {
        if (wParam != 13 || !this.pending)
            return
        ; The reading application holds the clipboard open; just hand over the data.
        DllCall("SetClipboardData", "UInt", 13, "Ptr", this.GlobalText(this.offered))
        pid := 0
        if (opener := DllCall("GetOpenClipboardWindow", "Ptr"))
            DllCall("GetWindowThreadProcessId", "Ptr", opener, "UInt*", &pid)
        this.renderPid := pid
        this.renderTick := A_TickCount
        return 0
    }

    static OnRenderAllFormats(wParam, lParam, msg, hwnd) {
        if !this.pending
            return
        if DllCall("OpenClipboard", "Ptr", A_ScriptHwnd) {
            if (DllCall("GetClipboardOwner", "Ptr") = A_ScriptHwnd)
                DllCall("SetClipboardData", "UInt", 13, "Ptr", this.GlobalText(this.offered))
            DllCall("CloseClipboard")
        }
        return 0
    }

    ; After Ctrl+V: waits until the target application reads the offered text.
    ;   "pasted"  the target (or an unknown reader) read it
    ;   "unsure"  another program read it first, so the paste moment is
    ;             unknown; waited fallbackMs instead
    ;   "none"    nobody read it within timeoutMs (the app ignored Ctrl+V)
    static WaitForPaste(sinceTick, targetPid, timeoutMs, fallbackMs) {
        deadline := A_TickCount + timeoutMs
        while (A_TickCount < deadline) {
            if this.renderTick {
                if (this.renderTick >= sinceTick && (!this.renderPid || this.renderPid = targetPid))
                    return "pasted"
                Sleep fallbackMs
                return "unsure"
            }
            Sleep 10
        }
        return "none"
    }

    ; Splits a ClipboardAll() snapshot into its entries; 0 if it looks wrong.
    ; Layout per entry: UInt format, UInt size, data; a UInt 0 ends the list.
    static Entries(saved) {
        entries := [], off := 0, total := saved.Size
        while (off + 4 <= total) {
            fmt := NumGet(saved, off, "UInt")
            if (fmt = 0)
                return (off + 4 = total) ? entries : 0
            if (off + 8 > total)
                return 0
            size := NumGet(saved, off + 4, "UInt")
            if (off + 8 + size > total)
                return 0
            entries.Push({format: fmt, offset: off, size: size})
            off += 8 + size
        }
        return 0
    }

    ; Puts a snapshot back. The privacy formats are added to it so that the
    ; restore does not show up a second time in clipboard history.
    static Restore(saved) {
        this.pending := false
        this.offered := ""
        if !IsObject(saved)
            return
        entries := saved.Size ? this.Entries(saved) : []
        try {
            if (entries = 0) {
                A_Clipboard := saved
            } else if !entries.Length {
                A_Clipboard := ""
            } else {
                extra := this.PrivacyFormats()
                body := saved.Size - 4
                buf := Buffer(body + extra.Length * 12 + 4, 0)
                DllCall("RtlMoveMemory", "Ptr", buf, "Ptr", saved.Ptr, "UPtr", body)
                off := body
                for f in extra {
                    NumPut("UInt", f[1], "UInt", 4, "UInt", f[2], buf, off)
                    off += 12
                }
                NumPut("UInt", 0, buf, off)
                A_Clipboard := ClipboardAll(buf)
            }
        }
    }

    ; Plain text put on the clipboard right away (not delayed), marked private.
    static SetPrivateText(text) {
        if !this.Open()
            return false
        DllCall("EmptyClipboard")
        DllCall("SetClipboardData", "UInt", 13, "Ptr", this.GlobalText(text))
        for f in this.PrivacyFormats()
            DllCall("SetClipboardData", "UInt", f[1], "Ptr", this.GlobalDword(f[2]))
        DllCall("CloseClipboard")
        return true
    }
}
