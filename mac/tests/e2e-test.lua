-- End-to-end test of the installed hafuch-safa module, run inside
-- Hammerspoon by mac/tests/run-tests.sh.
--
-- It opens a document of its own in TextEdit (mac/tests/output/e2e-doc.txt),
-- types real key events into it, presses the real hotkey and checks for each
-- case: the text, the input source and that the clipboard came back intact.
--
-- Safety: every key is sent only while that document is the frontmost
-- window. If anything else comes to the front the run stops at once. Each
-- case has a 30 second limit. At the end the document is emptied and closed
-- (TextEdit is quit only if the test started it), and the input source and
-- clipboard are put back.
--
-- dofile() returns start(outPath, options); results are appended to outPath
-- as TAP lines, ending with "# done".

local here = debug.getinfo(1, "S").source:match("^@(.*/)")
local docPath = here .. "output/e2e-doc.txt"

local TEXTEDIT = "com.apple.TextEdit"
local SOURCES = { en = "com.apple.keylayout.ABC", he = "com.apple.keylayout.Hebrew" }

-- Physical keys (US positions) for the characters the cases type.
local KEYS = {
    a = 0, s = 1, d = 2, f = 3, h = 4, g = 5, z = 6, x = 7, c = 8, v = 9, b = 11, q = 12, w = 13,
    e = 14, r = 15, y = 16, t = 17, ["1"] = 18, ["2"] = 19, ["3"] = 20, ["4"] = 21, ["6"] = 22,
    ["5"] = 23, ["9"] = 25, ["7"] = 26, ["8"] = 28, ["0"] = 29, o = 31, u = 32, i = 34, p = 35,
    l = 37, j = 38, ["'"] = 39, k = 40, [";"] = 41, [","] = 43, ["/"] = 44, n = 45, m = 46,
    ["."] = 47, [" "] = 49,
}

return function(outPath, options)
    options = options or {}
    local rounds = options.rounds or 1
    local only = options.only
    local log = io.open(outPath, "w")
    local count, failed = 0, 0
    local function out(line)
        log:write(line, "\n")
        log:flush()
    end

    local function nowMs() return hs.timer.absoluteTime() / 1e6 end
    local function sleep(ms)
        local t = nowMs() + ms
        repeat coroutine.applicationYield(0.005) until nowMs() >= t
    end

    local abort -- set to a reason when the run must stop
    local caseDeadline = math.huge
    local doc -- our TextEdit window

    local function ourDocInFront()
        local w = hs.window.focusedWindow()
        if not w or not doc or w:id() ~= doc:id() then return false end
        local app = w:application()
        return app and app:bundleID() == TEXTEDIT
    end

    local function guard()
        if abort then error(abort, 0) end
        if nowMs() > caseDeadline then
            error("case took more than 30 seconds", 0)
        end
        if not ourDocInFront() then
            abort = "focus moved away from the test document, stopping"
            error(abort, 0)
        end
    end

    local function key(mods, code)
        guard()
        hs.eventtap.event.newKeyEvent(mods, code, true):post()
        hs.eventtap.event.newKeyEvent(mods, code, false):post()
        sleep(12)
    end

    -- Types characters as physical key presses; the active input source
    -- decides what appears, exactly as on a real keyboard.
    local function typeKeys(s)
        for ch in s:gmatch(".") do
            local lower = ch:lower()
            local code = KEYS[lower]
            if not code then error("no key for " .. ch, 0) end
            key((ch ~= lower) and { "shift" } or {}, code)
        end
    end

    local function hafuch()
        return hafuchSafa
    end

    local function waitIdle()
        sleep(60)
        local deadline = nowMs() + 10000
        while true do
            local s = hafuch().status()
            if not s.busy and s.queued == 0 then break end
            if nowMs() > deadline then error("the tool stayed busy for 10 seconds", 0) end
            sleep(20)
        end
        sleep(250) -- let TextEdit handle the last posted events
    end

    -- Holds Ctrl and Option, taps L, lets go: like a person pressing it.
    local function pressHotkey(times, gapMs)
        times = times or 1
        for i = 1, times do
            guard()
            hs.eventtap.event.newKeyEvent(hs.keycodes.map.ctrl, true):post()
            hs.eventtap.event.newKeyEvent(hs.keycodes.map.alt, true):post()
            hs.eventtap.event.newKeyEvent({ "ctrl", "alt" }, 37, true):post()
            hs.eventtap.event.newKeyEvent({ "ctrl", "alt" }, 37, false):post()
            hs.eventtap.event.newKeyEvent(hs.keycodes.map.alt, false):post()
            hs.eventtap.event.newKeyEvent(hs.keycodes.map.ctrl, false):post()
            if i < times then sleep(gapMs or 300) end
        end
        waitIdle()
    end

    local function docText()
        local app = hs.application.get(TEXTEDIT)
        local el = hs.axuielement.applicationElement(app):attributeValue("AXFocusedUIElement")
        return el and el:attributeValue("AXValue") or nil
    end

    local function setSource(lang)
        hs.keycodes.currentSourceID(SOURCES[lang])
        sleep(150)
    end

    local function currentLang()
        return hs.keycodes.currentSourceID():lower():find("hebrew", 1, true) and "he" or "en"
    end

    local clipSerial = 0
    local function setSentinel()
        clipSerial = clipSerial + 1
        local data = {
            ["public.utf8-plain-text"] = "hafuch-safa e2e sentinel " .. clipSerial,
            ["com.github.adiramsalem101.hafuch-safa.test"] = "custom data " .. clipSerial,
        }
        hs.pasteboard.writeAllData(data)
        return data
    end

    local function clipboardIntact(want)
        local got = hs.pasteboard.readAllData() or {}
        for k, v in pairs(want) do
            if got[k] ~= v then return false end
        end
        return true
    end

    local function clearDoc()
        key({ "cmd" }, 0)  -- select all
        key({}, 51)        -- delete
        sleep(150)
        if docText() ~= "" then error("could not empty the test document", 0) end
    end

    local function check(name, got, want)
        if got == want then return nil end
        return ("%s: got [%s] want [%s]"):format(name, tostring(got), tostring(want))
    end

    -- Each case returns a list of problems (empty when it passed).
    local cases = {
        { "English layout word becomes Hebrew, input source switches", function()
            setSource("en"); typeKeys("akuo"); pressHotkey()
            return { check("text", docText(), "שלום"), check("source", currentLang(), "he") }
        end },
        { "Hebrew layout word becomes English, input source switches", function()
            setSource("he"); typeKeys("hello")
            local typed = docText()
            pressHotkey()
            return { check("typed", typed, "יקךךם"), check("text", docText(), "hello"), check("source", currentLang(), "en") }
        end },
        { "three quick presses flip three words", function()
            setSource("en"); typeKeys("akuo nv bang"); pressHotkey(3, 300)
            return { check("text", docText(), "שלום מה נשמע") }
        end },
        { "punctuation is part of the word (tr. is ארץ)", function()
            setSource("en"); typeKeys("tr."); pressHotkey()
            return { check("text", docText(), "ארץ") }
        end },
        { "a trailing number pulls in the word before it", function()
            setSource("en"); typeKeys("akuo 123"); pressHotkey()
            return { check("text", docText(), "שלום 123") }
        end },
        { "after 2 seconds a press restores the word exactly, capitals included", function()
            setSource("en"); typeKeys("Hello"); pressHotkey()
            local first = docText()
            sleep(2300)
            pressHotkey()
            return { check("first", first, "יקךךם"), check("text", docText(), "Hello"), check("source", currentLang(), "en") }
        end },
        -- macOS may capitalize the first word by itself (Capitalize words
        -- automatically), so the unselected part is compared with what was
        -- typed, not with a fixed string.
        { "a selection flips and nothing else", function()
            setSource("en"); typeKeys("akuo nv")
            local typed = docText()
            key({ "shift" }, 123); key({ "shift" }, 123)
            pressHotkey()
            return { check("typed", typed:lower(), "akuo nv"), check("text", docText(), typed:sub(1, -3) .. "מה"),
                check("source", currentLang(), "he") }
        end },
        { "a quick second press flips the selection back", function()
            setSource("en"); typeKeys("akuo nv")
            local typed = docText()
            key({ "shift" }, 123); key({ "shift" }, 123)
            pressHotkey(2, 300)
            return { check("typed", typed:lower(), "akuo nv"), check("text", docText(), typed) }
        end },
        { "without typing memory (arrow keys) the word before the caret is selected", function()
            setSource("en"); typeKeys("akuo")
            key({}, 123); key({}, 124)
            pressHotkey()
            return { check("text", docText(), "שלום") }
        end },
        { "the Hebrew comma key becomes an apostrophe (don't)", function()
            setSource("he"); typeKeys("don't")
            local typed = docText()
            pressHotkey()
            return { check("typed", typed, "גםמ,א"), check("text", docText(), "don't") }
        end },
        { "typing goes on in the new language", function()
            setSource("en"); typeKeys("akuo"); pressHotkey(); typeKeys(" nv")
            return { check("text", docText(), "שלום מה") }
        end },
        { "Hebrew sentence in the Hebrew layout, two presses", function()
            setSource("he"); typeKeys("hello world"); pressHotkey(2, 300)
            return { check("text", docText(), "hello world") }
        end },
    }

    local function runCase(index, case)
        local want = setSentinel()
        caseDeadline = nowMs() + 30000
        local ok, problems = pcall(function()
            clearDoc()
            return case[2]()
        end)
        caseDeadline = math.huge
        local list = {}
        if not ok then
            list[1] = tostring(problems)
        else
            for _, p in ipairs(problems) do
                if p then list[#list + 1] = p end
            end
        end
        if not clipboardIntact(want) then list[#list + 1] = "clipboard was not restored" end
        count = count + 1
        local name = case[1] .. (options.label and (" [" .. options.label .. "]") or "")
        if #list == 0 then
            out(("ok %d - %s"):format(count, name))
        else
            failed = failed + 1
            out(("not ok %d - %s"):format(count, name))
            for _, p in ipairs(list) do out("  # " .. p) end
        end
    end

    local function main()
        if not hs.accessibilityState(false) then
            out("Bail out! Hammerspoon has no Accessibility permission")
            return
        end
        if not hafuchSafa or not hafuchSafa.status then
            out("Bail out! hafuch-safa is not loaded in Hammerspoon")
            return
        end
        local enabled = hs.keycodes.layouts(true)
        local have = {}
        for _, id in ipairs(enabled) do have[id] = true end
        if not have[SOURCES.en] or not have[SOURCES.he] then
            out("Bail out! the test needs the ABC and Hebrew input sources")
            return
        end

        local savedClip = hs.pasteboard.readAllData() or {}
        local savedSource = hs.keycodes.currentSourceID()
        local savedInsert = hafuchSafa.status().insert
        if options.insert then hafuchSafa.setOption("insert", options.insert) end
        local textEditWasRunning = hs.application.get(TEXTEDIT) ~= nil

        local f = io.open(docPath, "w")
        f:write("")
        f:close()
        hs.task.new("/usr/bin/open", nil, { "-e", docPath }):start()
        local deadline = nowMs() + 15000
        while nowMs() < deadline do
            local app = hs.application.get(TEXTEDIT)
            if app then
                for _, w in ipairs(app:allWindows()) do
                    if (w:title() or ""):find("e2e-doc", 1, true) then doc = w end
                end
            end
            if doc then break end
            sleep(100)
        end
        if not doc then
            out("Bail out! the test document did not open in TextEdit")
        else
            doc:focus()
            sleep(500)
            out(("# insert method: %s, rounds: %d"):format(hafuchSafa.status().insert, rounds))
            for _ = 1, rounds do
                for i, case in ipairs(cases) do
                    if abort then break end
                    if not only or only[i] then runCase(i, case) end
                end
                if abort then break end
            end
            if abort then out("Bail out! " .. abort) end

            -- Leave the document as it was (empty) and close it.
            if ourDocInFront() then pcall(clearDoc) end
            pcall(function() doc:close() end)
            sleep(500)
            local app = hs.application.get(TEXTEDIT)
            if app and not textEditWasRunning and #app:allWindows() == 0 then app:kill() end
        end

        hafuchSafa.setOption("insert", savedInsert)
        hs.keycodes.currentSourceID(savedSource)
        if next(savedClip) then hs.pasteboard.writeAllData(savedClip) else hs.pasteboard.clearContents() end
        out(("1..%d"):format(count))
        out(("# passed %d/%d"):format(count - failed, count))
    end

    coroutine.wrap(function()
        local ok, err = xpcall(main, debug.traceback)
        if not ok then out("Bail out! " .. tostring(err):gsub("\n", " | ")) end
        out("# done")
        log:close()
    end)()
    return "started"
end
