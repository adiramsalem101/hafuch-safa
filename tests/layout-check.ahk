; Compares the built-in "standard" key map (lib\layouts.ahk) with the English
; and Hebrew layouts installed on this computer, read through ToUnicodeEx.
; Nothing is changed: installed layouts are only read.
; Output is TAP; exit code 0 when they match (or when a layout is missing).

#Requires AutoHotkey v2.0
#SingleInstance Off
#NoTrayIcon
#Include %A_ScriptDir%\..\lib\core.ahk
#Include %A_ScriptDir%\..\lib\layouts.ahk
#Include %A_ScriptDir%\..\lib\system.ahk

Out(line) => FileAppend(line "`n", "*", "UTF-8-RAW")

sys := HS_SystemTable()
if !sys {
    Out("1..0 # SKIP an English and a Hebrew keyboard layout are not both installed")
    ExitApp 0
}
Out("# English: " HS_LayoutName(sys.enHkl) " (" HS_LayoutKlid(sys.enHkl) ")")
Out("# Hebrew:  " HS_LayoutName(sys.heHkl) " (" HS_LayoutKlid(sys.heHkl) ")")

std := HS_StaticTable("standard")
diffs := 0
for dirName, maps in Map("en-he", [sys.table.enToHe, std.enToHe], "he-en", [sys.table.heToEn, std.heToEn]) {
    installed := maps[1], builtIn := maps[2]
    for k, v in installed {
        if (!builtIn.Has(k) || builtIn[k] !== v) {
            diffs++
            Out("# " dirName ": installed [" k "] -> [" v "], built-in -> [" (builtIn.Has(k) ? builtIn[k] : "none") "]")
        }
    }
    for k, v in builtIn {
        if !installed.Has(k) {
            diffs++
            Out("# " dirName ": built-in maps [" k "] -> [" v "], the installed layout does not")
        }
    }
    Out("# " dirName ": " installed.Count " mapped characters")
}

Out("1..1")
Out((diffs ? "not ok" : "ok") " 1 - built-in table matches the installed layouts (" diffs " differences)")
ExitApp(diffs ? 1 : 0)
