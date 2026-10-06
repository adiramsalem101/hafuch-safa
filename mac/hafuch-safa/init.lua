-- hafuch-safa (הפוך שפה) for macOS, a Hammerspoon module.
-- Flips text typed in the wrong keyboard layout between Hebrew and English,
-- then switches the input source so you can keep typing.
--
--   * Selected text: the selection is flipped.
--   * No selection: the last typed word is flipped; pressing again within
--     ExpandWindowMs extends the flip one word back each time.
--   * The direction comes from the majority of letters.
--
-- Loaded by one line at the end of ~/.hammerspoon/init.lua (see install.sh).
-- Settings: config.ini next to this file. License: MIT.

local M = {}
M.version = "1.0.0"
M.homepage = "https://github.com/adiramsalem101/hafuch-safa"

local dir = debug.getinfo(1, "S").source:match("^@(.*/)")
local core = dofile(dir .. "core.lua")
M.core = core
M.dir = dir
M.configPath = dir .. "config.ini"

local eventtap = hs.eventtap
local evtypes = eventtap.event.types
-- Every event this module posts carries this value, so the typing watcher
-- can tell them from what the user types.
local MARK = 0x48534146 -- "HSAF"
local USERDATA = eventtap.event.properties.eventSourceUserData
local TRANSIENT = "org.nspasteboard.TransientType"

local cfg, cfgErrors = core.buildSettings({})
local tbl = core.staticTable("mac")
local tableSource = "mac"

-- What was typed right before the caret in the frontmost app, as far as we
-- know. shadow holds what each character was before the last flip.
local buf = { text = "", shadow = "", n = 0, pid = nil, version = 0 }
-- The last flip, for pressing again (extend or toggle back).
local chain = { pid = nil, version = -1, tick = 0, len = 0, dir = "", kind = "" }
local busy = false
local queue = {}          -- press times of hotkey presses that came in while busy
local paused = false
local warnedMissing = false
local lastSource = {}     -- last input source seen per language
local watcher, appWatcher, hotkey, menu, watchdog, axTimer

local function nowMs() return hs.timer.absoluteTime() / 1e6 end

-- DebugLog=1: one line per step in debug.log next to this file.
-- Only lengths and results are written, never the text itself.
local function log(msg)
    if not cfg.debugLog then return end
    local f = io.open(dir .. "debug.log", "a")
    if f then
        f:write(os.date("%H:%M:%S"), (".%03d "):format(math.floor(nowMs()) % 1000), msg, "\n")
        f:close()
    end
end

local function tip(msg)
    if cfg.showTips then hs.alert.show(msg, 2.5) end
end

local function writeState(extra)
    local f = io.open(dir .. "state.txt", "w")
    if not f then return end
    f:write("version=", M.version, "\n")
    f:write("loaded=1\n")
    f:write("accessibility=", hs.accessibilityState(false) and "1" or "0", "\n")
    f:write("hotkey=", cfg.hotkey.display, "\n")
    f:write("table=", tableSource, "\n")
    if extra then f:write(extra, "\n") end
    f:close()
end

-- Waits inside the flip coroutine without blocking Hammerspoon, so the
-- typing watcher and the target app keep running.
local function sleep(ms)
    local untilT = nowMs() + ms
    repeat coroutine.applicationYield(0.005) until nowMs() >= untilT
end

local function frontPid()
    local app = hs.application.frontmostApplication()
    return app and app:pid()
end

-- ---------------------------------------------------------------------------
-- Posting keys
-- ---------------------------------------------------------------------------

local function post(e)
    e:setProperty(USERDATA, MARK)
    e:post()
end

local function pressKey(mods, code)
    post(eventtap.event.newKeyEvent(mods, code, true))
    post(eventtap.event.newKeyEvent(mods, code, false))
end

-- Types one visible character as a Unicode key event: it does not depend on
-- the input source, so Hebrew arrives as Hebrew on any layout.
local function typeCluster(s)
    local down = eventtap.event.newKeyEvent({}, 0, true)
    down:setUnicodeString(s)
    post(down)
    local up = eventtap.event.newKeyEvent({}, 0, false)
    up:setUnicodeString(s)
    post(up)
end

-- ---------------------------------------------------------------------------
-- Input sources
-- ---------------------------------------------------------------------------

local function isHebrewSource(id) return id ~= nil and id:lower():find("hebrew", 1, true) ~= nil end

local function enabledSources()
    local ok, list = pcall(hs.keycodes.layouts, true)
    return ok and list or {}
end

local function isEnabled(id, list)
    for _, x in ipairs(list) do
        if x == id then return true end
    end
    return false
end

-- The conversion table: from HebrewLayout, or (auto) from the Hebrew input
-- source in use.
local function loadTable()
    local name = cfg.layout
    if name == "auto" then
        local cur = hs.keycodes.currentSourceID()
        name = core.tableNameForSource(cur) or core.tableNameForSource(lastSource.he or "")
        if not name then
            local list = enabledSources()
            for _, n in ipairs({ "mac", "pc", "qwerty" }) do
                if isEnabled(core.sourceIDs[n], list) then
                    name = n
                    break
                end
            end
        end
        name = name or "mac"
        tableSource = "auto (" .. name .. ")"
    else
        tableSource = name
    end
    tbl = core.staticTable(name)
    return name
end

local function findSource(lang, tableName)
    local list = enabledSources()
    local candidates
    if lang == "he" then
        candidates = { core.sourceIDs[tableName], lastSource.he, core.sourceIDs.mac, core.sourceIDs.pc, core.sourceIDs.qwerty }
    else
        candidates = { lastSource.en, "com.apple.keylayout.ABC", "com.apple.keylayout.US" }
    end
    for _, id in ipairs(candidates) do
        if id and isEnabled(id, list) then return id end
    end
    for _, id in ipairs(list) do
        if isHebrewSource(id) == (lang == "he") then return id end
    end
    return nil
end

local function currentLang()
    return isHebrewSource(hs.keycodes.currentSourceID()) and "he" or "en"
end

-- Direction for text without a letter majority: it was typed on the input
-- source that is active now, so flip away from it.
local function tieDirection() return currentLang() == "he" and "he-en" or "en-he" end

local function switchTo(direction, tableName)
    if not cfg.switchLayout then return end
    local lang = core.targetLang(direction)
    local cur = hs.keycodes.currentSourceID()
    lastSource[isHebrewSource(cur) and "he" or "en"] = cur
    if (isHebrewSource(cur) and "he" or "en") == lang then return end
    local id = findSource(lang, tableName)
    if id then
        local ok = hs.keycodes.currentSourceID(id)
        log("input source: switch to " .. lang .. " -> " .. (ok and "ok" or "failed"))
    elseif not warnedMissing then
        warnedMissing = true
        tip(lang == "he" and "מקור קלט עברי לא מותקן, אין לאן לעבור" or "מקור קלט אנגלי לא מותקן, אין לאן לעבור")
    end
end

-- ---------------------------------------------------------------------------
-- Typing watcher: remembers the characters typed before the caret
-- ---------------------------------------------------------------------------

local function resetBuffer(pid)
    buf.text, buf.shadow, buf.n, buf.pid = "", "", 0, pid
    buf.version = buf.version + 1
end

local function backspaceBuffer()
    if buf.n > 0 then
        local cl = core.clusters(buf.text)
        local last = cl[#cl]
        local k = core.len(last)
        buf.text = buf.text:sub(1, #buf.text - #last)
        buf.shadow = core.sub(buf.shadow, 1, buf.n - k)
        buf.n = buf.n - k
    end
    buf.version = buf.version + 1
end

local function modsMatch(flags, mods)
    local want = {}
    for _, m in ipairs(mods) do want[m] = true end
    for _, m in ipairs({ "ctrl", "alt", "shift", "cmd" }) do
        if (flags[m] and true or false) ~= (want[m] or false) then return false end
    end
    return true
end

-- Tab, Return, Enter, Esc, arrows, Home, End, Page Up, Page Down, Help:
-- the caret moves or the text is sent, so forget what was typed.
local RESET_KEYS = { [48] = true, [36] = true, [76] = true, [53] = true, [123] = true, [124] = true,
    [125] = true, [126] = true, [115] = true, [119] = true, [116] = true, [121] = true, [114] = true }

local function onEvent(e)
    if e:getProperty(USERDATA) == MARK then return false end
    if e:getType() ~= evtypes.keyDown then
        resetBuffer() -- any click may move the caret
        return false
    end
    local code, flags = e:getKeyCode(), e:getFlags()
    if code == cfg.hotkey.keyCode and modsMatch(flags, cfg.hotkey.mods) then return false end
    if busy then
        resetBuffer() -- the user typed while a flip was running
        return false
    end
    if flags.cmd or flags.ctrl then
        resetBuffer() -- a shortcut: paste, undo, word delete, window switch...
        return false
    end
    if code == 51 then -- Backspace; Option+Backspace deletes a whole word
        if flags.alt then resetBuffer() else backspaceBuffer() end
        return false
    end
    if RESET_KEYS[code] then
        resetBuffer()
        return false
    end
    local ch = e:getCharacters() or ""
    ch = ch:gsub("[%z\1-\31\127]", "")
    if ch == "" or code == 117 then return false end -- dead key, Forward Delete
    local o = core.codepoint(ch)
    if o >= 0xF700 and o <= 0xF8FF then return false end -- function keys
    local pid = frontPid()
    if pid ~= buf.pid then resetBuffer(pid) end
    buf.text = buf.text .. ch
    buf.shadow = buf.shadow .. ch
    buf.n = buf.n + core.len(ch)
    buf.version = buf.version + 1
    if buf.n > 500 then
        buf.text, buf.shadow = core.sub(buf.text, -300), core.sub(buf.shadow, -300)
        buf.n = 300
    end
    return false
end

local function startWatcher()
    if watcher then watcher:stop() end
    watcher = eventtap.new({ evtypes.keyDown, evtypes.leftMouseDown, evtypes.rightMouseDown, evtypes.otherMouseDown },
        function(e)
            local ok, err = pcall(onEvent, e)
            if not ok then log("watcher error: " .. tostring(err)) end
            return false
        end)
    watcher:start()
end

-- ---------------------------------------------------------------------------
-- Clipboard
-- ---------------------------------------------------------------------------

local function clipSnapshot()
    return { data = hs.pasteboard.readAllData() or {}, count = hs.pasteboard.changeCount() }
end

-- Puts the saved clipboard back, marked transient so clipboard managers do
-- not record it a second time. Nothing happens if nobody touched it.
local function clipRestore(saved)
    if hs.pasteboard.changeCount() == saved.count then return end
    if next(saved.data) == nil then
        hs.pasteboard.clearContents()
        return
    end
    local data = {}
    for k, v in pairs(saved.data) do data[k] = v end
    data[TRANSIENT] = ""
    if not hs.pasteboard.writeAllData(data) then log("clipboard: restore failed") end
end

-- Presses Cmd+C and waits for the app to put the selection on the clipboard.
-- Returns the text, or nil when nothing (or files) was copied.
local function copySelection(ctx, timeoutMs)
    if frontPid() ~= ctx.pid then return nil end
    local before = hs.pasteboard.changeCount()
    pressKey({ "cmd" }, 8)
    local deadline = nowMs() + timeoutMs
    while hs.pasteboard.changeCount() == before do
        if nowMs() > deadline then return nil end
        sleep(10)
    end
    local types
    repeat
        types = hs.pasteboard.contentTypes() or {}
        if #types > 0 then break end
        sleep(10)
    until nowMs() > deadline
    for _, t in ipairs(types) do
        if t == "public.file-url" then return nil end -- Finder copied files
    end
    local text = hs.pasteboard.readString()
    if text == nil or text == "" then return nil end
    return text
end

-- InsertMethod=paste: puts the text on the clipboard (marked transient),
-- presses Cmd+V and gives the app PasteRestoreDelayMs to read it. The caller
-- puts the user's clipboard back afterwards.
local function pasteText(ctx, text)
    if frontPid() ~= ctx.pid then return false end
    if not hs.pasteboard.writeAllData({ ["public.utf8-plain-text"] = text, [TRANSIENT] = "" }) then
        log("paste: clipboard busy")
        return false
    end
    log("paste: " .. core.len(text) .. " chars")
    pressKey({ "cmd" }, 9)
    sleep(cfg.pasteRestoreMs)
    return true
end

-- ---------------------------------------------------------------------------
-- Writing the result
-- ---------------------------------------------------------------------------

local function typeText(ctx, text)
    if frontPid() ~= ctx.pid then
        log("type: app no longer in front, nothing typed")
        return false
    end
    log("type: " .. core.len(text) .. " chars")
    for _, cl in ipairs(core.clusters(text)) do
        if cl == "\t" then pressKey({}, 48) else typeCluster(cl) end
    end
    return true
end

-- Text with line breaks is always pasted: typing Return would send the
-- message in chat apps.
local function insert(ctx, text)
    if text == "" then return true end
    local method = ctx.isTerm and cfg.termInsert or cfg.insert
    if method == "paste" or text:find("[\r\n]") then
        local saved = clipSnapshot()
        local ok = pasteText(ctx, text)
        clipRestore(saved)
        if ok then return true end
    end
    return typeText(ctx, text)
end

local function replaceBeforeCaret(ctx, oldText, newText)
    if frontPid() ~= ctx.pid then
        log("replace: app no longer in front, nothing sent")
        return false
    end
    local same = core.commonPrefixLength(oldText, newText)
    local count = core.backspaceCount(core.sub(oldText, same + 1))
    log(("replace: backspaces=%d insert=%d chars"):format(count, core.len(newText) - same))
    for _ = 1, count do pressKey({}, 51) end
    return insert(ctx, core.sub(newText, same + 1))
end

-- ---------------------------------------------------------------------------
-- Flipping
-- ---------------------------------------------------------------------------

-- Flips the last n characters of the buffer, which sit right before the caret.
local function flipTail(ctx, n, direction, kind)
    local text, shadow = buf.text, buf.shadow
    local keep = buf.n - n
    local tail = core.sub(text, keep + 1)
    local flipped = core.convertWithShadow(tail, core.sub(shadow, keep + 1), direction, tbl)
    log(("flip %s: %d chars %s%s"):format(kind, n, direction, ctx.isTerm and " (terminal)" or ""))
    switchTo(direction, ctx.tableName)
    if flipped == tail then return end
    if not replaceBeforeCaret(ctx, tail, flipped) then return end
    buf.text = core.sub(text, 1, keep) .. flipped
    buf.shadow = core.sub(shadow, 1, keep) .. tail
    buf.n = keep + core.len(flipped)
    buf.version = buf.version + 1
    chain = { pid = ctx.pid, version = buf.version, tick = nowMs(), len = n, dir = direction, kind = kind }
end

-- Pressed again within the time window: flip one more word to the left.
local function expandChain(ctx)
    local text, shadow = buf.text, buf.shadow
    local n = chain.len
    local keep = buf.n - n
    local prefix = core.sub(text, 1, keep)
    local start = core.lastWordStart(prefix)
    if start == 0 then
        chain.tick = nowMs()
        return tip("אין עוד מילים מוכרות לפני. סמן את הטקסט ולחץ שוב")
    end
    local added = core.sub(prefix, start)
    local addedLen = core.len(added)
    local span = core.sub(text, keep + 1)
    log(("extend: +%d chars %s"):format(addedLen, chain.dir))
    local flippedAdded = core.convertWithShadow(added, core.sub(shadow, start, start + addedLen - 1), chain.dir, tbl)
    switchTo(chain.dir, ctx.tableName)
    if not replaceBeforeCaret(ctx, added .. span, flippedAdded .. span) then return end
    buf.text = core.sub(text, 1, start - 1) .. flippedAdded .. span
    buf.shadow = core.sub(shadow, 1, start - 1) .. added .. core.sub(shadow, keep + 1)
    buf.n = core.len(buf.text)
    buf.version = buf.version + 1
    chain = { pid = ctx.pid, version = buf.version, tick = nowMs(), len = n + addedLen, dir = chain.dir, kind = "word" }
end

-- The focused text element, through the accessibility API. Used only for
-- hints (is there a selection, is this a text field); nil when the app does
-- not expose it.
local function focusedElement(ctx)
    local ok, el = pcall(function()
        local appEl = hs.axuielement.applicationElement(ctx.app)
        appEl:setTimeout(0.2)
        return appEl:attributeValue("AXFocusedUIElement")
    end)
    return ok and el or nil
end

local function selectionLength(ctx)
    local el = focusedElement(ctx)
    if not el then return nil end
    local ok, range = pcall(el.attributeValue, el, "AXSelectedTextRange")
    if ok and type(range) == "table" and range.length then return range.length end
    return nil
end

-- Finder and the desktop: Cmd+C copies files, so only a text field counts.
local function hasTextFocus(ctx)
    if ctx.bundle ~= "com.apple.finder" then return true end
    local el = focusedElement(ctx)
    local role = el and el:attributeValue("AXRole")
    return role == "AXTextField" or role == "AXTextArea" or role == "AXComboBox"
end

local function selectPreviousWord(ctx)
    local function extend(code)
        if frontPid() ~= ctx.pid then return nil end
        pressKey({ "alt", "shift" }, code)
        sleep(30)
        return copySelection(ctx, 400)
    end
    local text = extend(123) -- Option+Shift+Left
    if not text then
        -- In right-to-left text Cocoa moves visually, and the previous word
        -- is on the right.
        return extend(124)
    end
    for _ = 1, 2 do
        -- The selection may hold punctuation only: take one more word.
        local c = core.countLetters(text)
        if c.latin + c.hebrew > 0 then break end
        local more = extend(123)
        if not more or more == text then break end
        text = more
    end
    return text
end

-- Nothing typed is known here: flip the selection, or select the word before
-- the caret (Option+Shift+Left) and flip that.
local function flipSelection(ctx)
    local saved = clipSnapshot()
    local lineCopy = core.inList(cfg.lineCopyApps, ctx.bundle, ctx.name)
    local kind = "selection"
    local text
    if selectionLength(ctx) ~= 0 then
        text = copySelection(ctx, 500)
        if text and lineCopy and text:match("[\r\n]$") then text = nil end -- code editors copy the line
    end
    if not text then
        kind = "word"
        text = selectPreviousWord(ctx)
    end
    if not text then
        clipRestore(saved)
        return tip("לא נמצא טקסט להפיכה. סמן טקסט ולחץ שוב")
    end
    local direction = core.detectDirection(text, tieDirection())
    local flipped = core.convert(text, direction, tbl)
    log(("flip %s (read with the clipboard): %d chars %s"):format(kind, core.len(text), direction))
    switchTo(direction, ctx.tableName)
    clipRestore(saved)
    if flipped == text then return end
    if not insert(ctx, flipped) then return end -- typing replaces the selection
    buf.text, buf.shadow, buf.n, buf.pid = flipped, text, core.len(flipped), ctx.pid
    buf.version = buf.version + 1
    chain = { pid = ctx.pid, version = buf.version, tick = nowMs(), len = buf.n, dir = direction, kind = kind }
end

local function waitForModifiers(mods, timeoutMs)
    local deadline = nowMs() + timeoutMs
    while nowMs() < deadline do
        local held = eventtap.checkKeyboardModifiers()
        local any = held.ctrl or held.alt or held.cmd
        for _, m in ipairs(mods) do any = any or held[m] end
        if not any then return true end
        sleep(10)
    end
    return false
end

local function flip(pressTick)
    -- Let go of the hotkey's modifiers first, so Backspace and the new text
    -- reach the app clean.
    waitForModifiers(cfg.hotkey.mods, 1000)
    local app = hs.application.frontmostApplication()
    if not app then return end
    local ctx = { app = app, pid = app:pid(), bundle = app:bundleID() or "", name = app:name() or "" }
    ctx.isTerm = core.inList(cfg.terminalApps, ctx.bundle, ctx.name)
    ctx.tableName = loadTable()
    local bufValid = buf.pid == ctx.pid and buf.text ~= ""
    log(("press: app=%s buffer=%d chars same app=%s chain=%s/%s/%dms"):format(ctx.bundle, buf.n,
        tostring(buf.pid == ctx.pid), chain.kind, tostring(chain.version == buf.version), math.floor(pressTick - chain.tick)))
    if bufValid and chain.pid == ctx.pid and chain.version == buf.version and pressTick - chain.tick <= cfg.expandMs then
        if chain.kind == "word" then return expandChain(ctx) end
        -- Pressed again right after flipping a selection: flip it back.
        return flipTail(ctx, chain.len, core.opposite(chain.dir), "toggle")
    end
    if bufValid then
        local start = core.flipSpanStart(buf.text)
        if start > 0 then
            local span = core.sub(buf.text, start)
            return flipTail(ctx, core.len(span), core.detectDirection(span, tieDirection()), "word")
        end
    end
    if ctx.isTerm then return tip("הקלד מילה ואז לחץ " .. cfg.hotkey.display) end
    if not hasTextFocus(ctx) then return tip("אין כאן טקסט להפיכה") end
    return flipSelection(ctx)
end

local function runFlip(pressTick)
    busy = true
    coroutine.wrap(function()
        local ok, err = xpcall(flip, debug.traceback, pressTick)
        if not ok then
            log("error: " .. tostring(err))
            tip("הפוך שפה: " .. tostring(err):match("^[^\n]*"))
        end
        busy = false
        if #queue > 0 then
            local nextTick = table.remove(queue, 1)
            hs.timer.doAfter(0, function() runFlip(nextTick) end)
        end
    end)()
end

local function onHotkey()
    if paused then return end
    local app = hs.application.frontmostApplication()
    if app and core.inList(cfg.excludeApps, app:bundleID(), app:name()) then
        -- Excluded app: let the key combination through to the app itself.
        hotkey:disable()
        eventtap.keyStroke(cfg.hotkey.mods, cfg.hotkey.keyCode, 0)
        hs.timer.doAfter(0.1, function() if hotkey and not paused then hotkey:enable() end end)
        return
    end
    if busy then
        if #queue < 10 then queue[#queue + 1] = nowMs() end
        return
    end
    runFlip(nowMs())
end

-- ---------------------------------------------------------------------------
-- Settings, menu bar and start/stop
-- ---------------------------------------------------------------------------

local function readConfig()
    local user = {}
    local f = io.open(M.configPath, "r")
    if f then
        user = core.parseConfigText(f:read("a") or "")
        f:close()
    end
    cfg, cfgErrors = core.buildSettings(user)
    if #cfgErrors > 0 then
        hs.alert.show("הפוך שפה: בקובץ ההגדרות יש ערכים לא תקינים, ובמקומם נעשה שימוש בברירת המחדל:\n"
            .. table.concat(cfgErrors, "\n"), 8)
    end
end

local function menuTitle() return paused and "אA ⏸" or "אA" end

local function showAbout()
    hs.focus()
    hs.dialog.blockAlert("הפוך שפה " .. M.version,
        "קיצור: " .. cfg.hotkey.display .. "\n"
        .. "טבלת מיפוי: " .. tableSource .. "\n"
        .. "קובץ הגדרות: " .. M.configPath .. "\n"
        .. "הרשאת נגישות: " .. (hs.accessibilityState(false) and "יש" or "חסרה") .. "\n\n"
        .. M.homepage, "אישור")
end

local function togglePause()
    paused = not paused
    if paused then
        if hotkey then hotkey:disable() end
        if watcher then watcher:stop() end
    else
        if hotkey then hotkey:enable() end
        startWatcher()
    end
    resetBuffer()
    if menu then menu:setTitle(menuTitle()) end
end

local function setupMenu()
    if menu then menu:delete() end
    menu = nil
    if not cfg.showMenuBarIcon then return end
    menu = hs.menubar.new(true, "hafuch-safa")
    if not menu then return end
    menu:setTitle(menuTitle())
    menu:setTooltip("הפוך שפה (" .. cfg.hotkey.display .. ")")
    menu:setMenu(function()
        return {
            { title = "הפוך שפה " .. M.version, fn = showAbout },
            { title = "-" },
            { title = "השהה", checked = paused, fn = togglePause },
            { title = "פתח את קובץ ההגדרות", fn = function() hs.task.new("/usr/bin/open", nil, { "-t", M.configPath }):start() end },
            { title = "טען מחדש", fn = function() M.restart() end },
        }
    end)
end

-- Accessibility permission: without it macOS gives Hammerspoon no key
-- events and lets it post none. Check every 2 seconds until it is granted,
-- then start the watcher again (a tap created before that stays deaf).
local function watchAccessibility()
    if axTimer then axTimer:stop() end
    if hs.accessibilityState(false) then return end
    hs.alert.show("הפוך שפה צריך הרשאת נגישות:\nהגדרות המערכת > פרטיות ואבטחה > נגישות > Hammerspoon", 8)
    axTimer = hs.timer.doEvery(2, function()
        if hs.accessibilityState(false) then
            axTimer:stop()
            axTimer = nil
            startWatcher()
            writeState()
            hs.alert.show("הפוך שפה מוכן. קיצור: " .. cfg.hotkey.display, 4)
        end
    end)
end

local function firstRun()
    local marker = dir .. "first-run"
    local f = io.open(marker, "r")
    if not f then return end
    f:close()
    os.remove(marker)
    if not hs.autoLaunch() then
        hs.autoLaunch(true)
        local g = io.open(dir .. "autolaunch-enabled", "w")
        if g then g:write("1\n") g:close() end
    end
    if hs.accessibilityState(false) then
        hs.alert.show("הפוך שפה הותקן. קיצור: " .. cfg.hotkey.display, 5)
    end
end

function M.start()
    readConfig()
    paused = false
    queue = {}
    resetBuffer()
    loadTable()
    if hs.hotkey.systemAssigned(cfg.hotkey.mods, cfg.hotkey.keyCode) then
        hs.alert.show("הפוך שפה: הקיצור " .. cfg.hotkey.display .. " תפוס במערכת. אפשר לבחור אחר בקובץ ההגדרות", 6)
    end
    hotkey = hs.hotkey.new(cfg.hotkey.mods, cfg.hotkey.keyCode, onHotkey)
    if not hotkey or not hotkey:enable() then
        hs.alert.show("הפוך שפה: לא ניתן להגדיר את הקיצור " .. cfg.hotkey.display, 6)
    end
    startWatcher()
    appWatcher = hs.application.watcher.new(function(_, event)
        if event == hs.application.watcher.activated then resetBuffer() end
    end)
    appWatcher:start()
    -- macOS turns off an event tap that it considers slow; turn it back on.
    watchdog = hs.timer.doEvery(5, function()
        if not paused and watcher and not watcher:isEnabled() then
            log("watcher was disabled, restarting")
            startWatcher()
        end
    end)
    setupMenu()
    firstRun()
    watchAccessibility()
    writeState()
    return M
end

function M.stop()
    if hotkey then hotkey:delete() end
    if watcher then watcher:stop() end
    if appWatcher then appWatcher:stop() end
    if watchdog then watchdog:stop() end
    if axTimer then axTimer:stop() end
    if menu then menu:delete() end
    hotkey, watcher, appWatcher, watchdog, axTimer, menu = nil, nil, nil, nil, nil, nil
end

function M.restart()
    M.stop()
    return M.start()
end

-- For the end-to-end test.
function M.status()
    return { busy = busy, queued = #queue, paused = paused, bufferLength = buf.n, chainKind = chain.kind,
        insert = cfg.insert, table = tableSource }
end

function M.setOption(key, value)
    cfg[key] = value
end

-- Test mode (mac/tests/run-tests.sh creates the file test-mode next to this
-- one): the hs command line tool may run the tests inside Hammerspoon.
do
    local f = io.open(dir .. "test-mode", "r")
    if f then
        f:close()
        require("hs.ipc")
    end
end

return M.start()
