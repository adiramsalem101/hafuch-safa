-- Unit tests for the pure conversion logic (mac/hafuch-safa/core.lua).
-- The first 83 checks are tests/unit-tests.ahk of the Windows version, case by
-- case; the rest cover what only exists on the Mac.
-- Output is TAP. Run: mac/tests/run-tests.sh
--   (or any Lua 5.4: lua mac/tests/unit-tests.lua)
-- Inside Hammerspoon, dofile() returns a function: run() -> failed, lines.

local here = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
local core = dofile(here .. "../hafuch-safa/core.lua")

local function run()
    local lines, count, failed = {}, 0, 0
    local function out(line) lines[#lines + 1] = line end

    local function show(v)
        if type(v) ~= "string" then return tostring(v) end
        local codes = {}
        for _, ch in ipairs(core.chars(v)) do codes[#codes + 1] = ("%04X"):format(core.codepoint(ch)) end
        return v .. "] codes:[" .. table.concat(codes, " ")
    end

    local function eq(name, actual, expected)
        count = count + 1
        if type(actual) == type(expected) and actual == expected then
            out(("ok %d - %s"):format(count, name))
            return
        end
        failed = failed + 1
        out(("not ok %d - %s"):format(count, name))
        out("  #  got:  [" .. show(actual) .. "]")
        out("  #  want: [" .. show(expected) .. "]")
    end

    local function throws(name, fn)
        count = count + 1
        if not pcall(fn) then
            out(("ok %d - %s"):format(count, name))
            return
        end
        failed = failed + 1
        out(("not ok %d - %s (nothing was thrown)"):format(count, name))
    end

    local conv = core.convert
    -- The table of the macOS "Hebrew" input source, the one installed by
    -- default. It agrees with the Windows table on every case below.
    local std = core.staticTable("mac")
    local pc = core.staticTable("pc")
    local qwerty = core.staticTable("qwerty")

    -- --- English layout text that was meant to be Hebrew --------------------
    eq("en-he: single word", conv("akuo", "en-he", std), "שלום")
    eq("en-he: sentence", conv("akuo nv bang", "en-he", std), "שלום מה נשמע")
    eq("en-he: Caps Lock text still becomes Hebrew", conv("AKUO", "en-he", std), "שלום")
    eq("en-he: capital first letter", conv("Akuo", "en-he", std), "שלום")
    eq("en-he: apostrophe key is the Hebrew comma, ? stays", conv("akuo' nv bang?", "en-he", std), "שלום, מה נשמע?")
    eq("en-he: period key is final tsadi", conv("tr.", "en-he", std), "ארץ")
    eq("en-he: comma key is tav", conv("t,", "en-he", std), "את")
    eq("en-he: semicolon key is final pe", conv("tk;", "en-he", std), "אלף")
    eq("en-he: slash key is the Hebrew period", conv("akuo/", "en-he", std), "שלום.")
    eq("en-he: digits and spaces stay", conv("akuo 123", "en-he", std), "שלום 123")
    eq("en-he: parentheses mirror like the Hebrew layout", conv("(akuo)", "en-he", std), ")שלום(")
    eq("en-he: brackets mirror", conv("[x]", "en-he", std), "]ס[")
    eq("en-he: backtick key types a semicolon", conv("`", "en-he", std), ";")
    eq("en-he: Hebrew letters already present stay", conv("akuo שלום", "en-he", std), "שלום שלום")
    eq("en-he: emoji survives", conv("akuo 🙂", "en-he", std), "שלום 🙂")
    eq("en-he: empty text", conv("", "en-he", std), "")
    eq("en-he: correct English flips too (no dictionary)", conv("hello", "en-he", std), "יקךךם")
    eq("en-he: symbols shared by both layouts stay", conv("a-b=c!@#", "en-he", std), "ש-נ=ב!@#")

    -- --- Hebrew layout text that was meant to be English ---------------------
    eq("he-en: single word", conv("יקךךם", "he-en", std), "hello")
    eq("he-en: two words", conv("יקךךם 'םרךג", "he-en", std), "hello world")
    eq("he-en: Hebrew comma is the apostrophe key", conv("גםמ,א", "he-en", std), "don't")
    eq("he-en: Hebrew period is the slash key", conv("שלום.", "he-en", std), "akuo/")
    eq("he-en: Hebrew slash is the q key", conv("/וןא", "he-en", std), "quit")
    eq("he-en: Hebrew semicolon is the backtick key", conv(";", "he-en", std), "`")
    eq("he-en: Shift on the Hebrew layout typed capitals, they stay", conv("Hקךךם", "he-en", std), "Hello")
    eq("he-en: mirrored parentheses come back", conv(")שלום(", "he-en", std), "(akuo)")
    eq("he-en: numbers and symbols stay", conv("123 !@#", "he-en", std), "123 !@#")
    eq("he-en: correct Hebrew flips too (no dictionary)", conv("ארץ", "he-en", std), "tr.")
    eq("he-en: newline and tab stay", conv("יק\r\nךך\tם", "he-en", std), "he\r\nll\to")

    -- --- round trips ------------------------------------------------------------
    for _, sample in ipairs({ "akuo nv bang, tk/", "don't stop (now)", "a;b'c,d.e/f`g[h]", "x.y,z;w'q/" }) do
        eq("round trip: " .. sample, conv(conv(sample, "en-he", std), "he-en", std), sample)
    end

    -- --- direction detection ------------------------------------------------------
    local detect = core.detectDirection
    eq("direction: Latin majority", detect("akuo"), "en-he")
    eq("direction: Hebrew majority", detect("יקךךם"), "he-en")
    eq("direction: majority wins in mixed text", detect("ab שלום"), "he-en")
    eq("direction: tie uses the fallback", detect("ab של", "he-en"), "he-en")
    eq("direction: no letters uses the fallback", detect("123 ,./", "he-en"), "he-en")
    eq("direction: empty text uses the default", detect(""), "en-he")
    eq("direction: punctuation does not vote", detect("a,,,,,,", "he-en"), "en-he")

    -- --- exact restore through the shadow -----------------------------------------
    local shadow = core.convertWithShadow
    eq("shadow: flipping back restores capitals", shadow("יקךךם", "Hello", "he-en", std), "Hello")
    eq("shadow: typed text converts normally", shadow("יקךךם", "יקךךם", "he-en", std), "hello")
    eq("shadow: unrelated shadow is ignored", shadow("abc", "xyz", "en-he", std), "שנב")
    eq("shadow: length mismatch falls back to plain conversion", shadow("abc", "x", "en-he", std), "שנב")

    -- --- words before the caret ----------------------------------------------------
    eq("last word: plain", core.lastWordStart("akuo nv bang"), 9)
    eq("last word: trailing space belongs to the span", core.lastWordStart("akuo nv "), 6)
    eq("last word: punctuation stays inside the word", core.lastWordStart("akuo, tr."), 7)
    eq("last word: only spaces", core.lastWordStart("   "), 0)
    eq("last word: empty", core.lastWordStart(""), 0)
    eq("flip span: a trailing number pulls in the word before it", core.flipSpanStart("akuo 123"), 1)
    eq("flip span: normal word", core.flipSpanStart("xx akuo"), 4)
    eq("flip span: symbols only", core.flipSpanStart("/"), 1)
    eq("flip span: nothing", core.flipSpanStart("  "), 0)

    eq("backspaces: plain", core.backspaceCount("akuo "), 5)
    eq("backspaces: CR LF counts once", core.backspaceCount("a\r\nb"), 3)
    eq("backspaces: emoji counts once", core.backspaceCount("a🙂"), 2)
    eq("common prefix", core.commonPrefixLength("123akuo", "123שלום"), 3)
    eq("common prefix: none", core.commonPrefixLength("akuo", "שלום"), 0)

    -- --- hotkey and settings -------------------------------------------------------
    local function spec(h) return table.concat(h.mods, "+") .. " " .. h.keyCode end
    local h = core.parseHotkey("Ctrl+Alt+L")
    eq("hotkey: friendly syntax", spec(h), "ctrl+alt 37")
    eq("hotkey: display text", h.display, "Ctrl+Option+L")
    eq("hotkey: key as virtual key code", h.keyCode, 37)
    eq("hotkey: AutoHotkey syntax", spec(core.parseHotkey("^!l")), "ctrl+alt 37")
    eq("hotkey: function key", spec(core.parseHotkey("Ctrl+Shift+F9")), "ctrl+shift 101")
    eq("hotkey: Win modifier", core.parseHotkey("Win+Alt+H").display, "Option+Cmd+H")
    throws("hotkey: a key without modifier is refused", function() core.parseHotkey("L") end)
    throws("hotkey: unknown modifier is refused", function() core.parseHotkey("Ctrl+Hyper+L") end)

    local s, errors = core.buildSettings({})
    eq("settings: defaults have no errors", #errors, 0)
    eq("settings: default hotkey", s.hotkey.display, "Ctrl+Option+L")
    eq("settings: default expand window", s.expandMs, 2000)
    eq("settings: default insert method types the text", s.insert, "type")
    eq("settings: terminals type instead of paste", s.termInsert, "type")

    s, errors = core.buildSettings(core.parseConfigText("; comment\n[General]\n Hotkey = Ctrl+Shift+K \nExpandWindowMs=1500\nHebrewLayout=MAC\n"))
    eq("settings: parsed hotkey", spec(s.hotkey), "ctrl+shift 40")
    eq("settings: parsed number", s.expandMs, 1500)
    eq("settings: layout name is case-insensitive", s.layout, "mac")
    eq("settings: valid file has no errors", #errors, 0)

    s, errors = core.buildSettings(core.parseConfigText("ExpandWindowMs=abc\nInsertMethod=magic\nSwitchLayout=maybe"))
    eq("settings: three bad values reported", #errors, 3)
    eq("settings: bad number falls back", s.expandMs, 2000)
    eq("settings: bad choice falls back", s.insert, "type")
    eq("settings: bad switch falls back", s.switchLayout, true)

    -- --- tables --------------------------------------------------------------------
    eq("pc table: letters", conv("akuo nv bang", "en-he", pc), "שלום מה נשמע")
    eq("pc table: backtick types a backslash", conv("`", "en-he", pc), "\\")
    throws("tables: layers of different length are refused", function() core.tableFromLayers({ "a b" }, { "x" }) end)
    local letters = 0
    for he in pairs(std.heToEn) do
        if core.isHebrewLetter(he) then letters = letters + 1 end
    end
    eq("standard table covers all 27 Hebrew letters", letters, 27)

    -- ============ macOS only ======================================================
    eq("mac: the w key types a geresh on the Mac Hebrew layout", conv("w", "en-he", std), "׳")
    eq("mac: geresh flips back to w", conv("׳םרךג", "he-en", std), "world")
    eq("mac: Shift+7 types the shekel sign", conv("&", "en-he", std), "₪")
    eq("mac: a letter with a vowel point is left alone", conv("שׁ", "he-en", std), "a" .. "\u{05C1}")
    eq("pc table: the w key types an apostrophe", conv("w", "en-he", pc), "'")
    eq("pc table: Shift typed capitals, they stay", conv("Hקךךם", "he-en", pc), "Hello")
    eq("pc table: geresh typed on the Mac layout still flips", conv("׳", "he-en", pc), "w")
    eq("qwerty table: phonetic letters", conv("wloM", "en-he", qwerty), "שלום")
    eq("qwerty table: Hebrew comes back lowercase", conv("שלום", "he-en", qwerty), "wlum")
    eq("qwerty table: Shift+T has its own letter", conv("tT", "en-he", qwerty), "תט")
    eq("qwerty table: covers all 27 Hebrew letters", (function()
        local n = 0
        for he in pairs(qwerty.heToEn) do
            if core.isHebrewLetter(he) then n = n + 1 end
        end
        return n
    end)(), 27)
    eq("source ID picks the table", core.tableNameForSource("com.apple.keylayout.Hebrew-PC"), "pc")
    eq("source ID: an English layout has no table", core.tableNameForSource("com.apple.keylayout.ABC"), nil)
    eq("app list: wildcard matches by prefix", core.inList({ "com.jetbrains.*" }, "com.jetbrains.intellij"), true)
    eq("app list: names are case-insensitive", core.inList(core.splitList("TextEdit, Notes"), "com.apple.TextEdit", "textedit"), true)
    eq("app list: no match", core.inList(core.splitList("com.apple.Terminal"), "com.apple.TextEdit"), false)
    eq("backspaces: a letter with a vowel point counts once", core.backspaceCount("שׁ"), 1)
    eq("backspaces: emoji with a skin tone counts once", core.backspaceCount("👍🏽"), 1)
    eq("characters: Hebrew counts per letter", core.len("שלום 🙂"), 6)
    eq("characters: substring by character", core.sub("akuo שלום", 6), "שלום")
    eq("hotkey: Mac spelling", spec(core.parseHotkey("Control+Option+L")), "ctrl+alt 37")
    eq("hotkey: Cmd modifier", spec(core.parseHotkey("Cmd+Shift+Space")), "shift+cmd 49")
    throws("hotkey: unknown key is refused", function() core.parseHotkey("Ctrl+Option+Banana") end)
    s, errors = core.buildSettings(core.parseConfigText("HebrewLayout=standard\nShowMenuBarIcon=0\nhotkey=ctrl+option+k"))
    eq("settings: standard is the PC layout", s.layout, "pc")
    eq("settings: menu bar icon can be hidden", s.showMenuBarIcon, false)
    eq("settings: key names are case-insensitive", s.hotkey.display, "Ctrl+Option+K")
    s, errors = core.buildSettings(core.parseConfigText("HebrewLayout=klingon\nHotkey=L"))
    local keys = {}
    for _, e in ipairs(errors) do keys[#keys + 1] = e:match("^(%w+):") end
    eq("settings: bad layout and hotkey reported by name", table.concat(keys, ","), "Hotkey,HebrewLayout")
    eq("settings: bad layout falls back to auto", s.layout, "auto")

    out(("1..%d"):format(count))
    out(("# passed %d/%d"):format(count - failed, count))
    return failed, lines
end

if arg and arg[0] and arg[0]:match("unit%-tests%.lua$") then
    local failed, lines = run()
    print(table.concat(lines, "\n"))
    os.exit(failed == 0 and 0 or 1)
end

return run
