; hafuch-safa: built-in key maps (English key -> Hebrew character on the same key).
;
; "standard" was read with ToUnicodeEx from Windows "Hebrew (Standard)"
; (KBDHEBL3.DLL, 0002040D). Windows' older "Hebrew" layout (KBDHEB.DLL) types
; the same characters on the unshifted and shifted layers, which are the only
; layers used for flipping. Note the swapped pairs on the Hebrew layout:
; [ ] { } ( ) < > are mirrored, and ` types ;
;
; "mac" is the macOS "Hebrew" layout as given in the project brief (letters
; and the punctuation keys around them only).
;
; HebrewLayout=auto (the default) does not use these tables when both an
; English and a Hebrew layout are installed: it reads the installed layouts
; directly (see HS_SystemTable in system.ahk) and falls back to "standard".

#Requires AutoHotkey v2.0

HS_StaticTable(name) {
    q := Chr(34)   ; the " character
    switch name, false {
        case "standard":
            return HS_TableFromLayers(
                ["``1234567890-=qwertyuiop[]\asdfghjkl;'zxcvbnm,./", "~!@#$%^&*()_+{}|:" q "<>?"],
                [";1234567890-=/'קראטוןםפ][\שדגכעיחלךף,זסבהנמצתץ.", "~!@#$%^&*)(_+}{|:" q "><?"])
        case "mac":
            return HS_TableFromLayers(
                ["qwertyuiopasdfghjkl;'zxcvbnm,./"],
                ["/'קראטוןםפשדגכעיחלךף,זסבהנמצתץ."])
    }
    throw ValueError("unknown layout table: " name)
}
