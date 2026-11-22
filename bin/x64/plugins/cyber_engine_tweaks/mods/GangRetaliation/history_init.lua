-- Gang Retaliation History
-- Companion mod for Gang Retaliation. It does NOT modify that mod:
--   1. It observes GRDetection:Notify(text) (the method the main mod uses to show each message) and
--      appends every message to data/history.log as a LANGUAGE-NEUTRAL record (the main mod's message key
--      plus typed arguments, with the text as shown kept alongside for reading).
--   2. It feeds those events, rendered in the language the game is using now, tagged with the gangs/nemeses
--      they involve and classified by kind, to the "Nemesis History" screen (a redscript system,
--      GRChronData), found under Journal in the hub menu.

local Tagger = require("modules/tagger")

local VERSION = "1.2.0"
local LOG_PATH = "data/history.log"
local MAX_BYTES = 1024 * 1024 -- rotate to history.log.old once per session if larger
local MAX_EVENTS = 600        -- per campaign, newest kept
local TARGET_CLASS = "GangRetaliation.GRDetection"
local TARGET_METHOD = "Notify"

local state = {
    events = {},          -- { day=, text=, key=, args= } for the loaded campaign, oldest first
    loadedCampaign = 0,
    rosterSig = nil,
    dirty = false,
    timer = 0,
    matchers = nil,
    lex = nil,
    getText = nil,
    lang = nil,
    converted = false,
}

local function getSystem(name)
    local ok, sys = pcall(function()
        return Game.GetScriptableSystemsContainer():Get(name)
    end)
    if ok then return sys end
    return nil
end

local function rotateIfNeeded()
    local file = io.open(LOG_PATH, "r")
    if not file then return end
    local size = file:seek("end")
    file:close()
    if size and size > MAX_BYTES then
        os.remove(LOG_PATH .. ".old")
        os.rename(LOG_PATH, LOG_PATH .. ".old")
    end
end

local function gameDay()
    local ok, day = pcall(function()
        local spawner = getSystem("GangRetaliation.GRSpawner")
        return spawner and spawner:GetGameDay() or 0
    end)
    return ok and tonumber(day) or 0
end

-- Same value the main mod uses: GRSystem:GetCampaignId() (stored in the save file, 0 until a game is loaded)
local function campaignId()
    local ok, id = pcall(function()
        local sys = getSystem("GangRetaliation.GRSystem")
        return sys and sys:GetCampaignId() or 0
    end)
    return ok and tonumber(id) or 0
end

local function writeLine(key, args, text)
    pcall(function()
        local file = io.open(LOG_PATH, "a")
        if not file then return end
        file:write(Tagger.formatLine(os.date("%Y-%m-%d %H:%M:%S"), campaignId(), gameDay(), key, args, text), "\n")
        file:close()
    end)
end

-- ---------------------------------------------------------------- text, matchers and language
-- (re)builds the message matchers and the word lexicon for the language in use; true when the language changed
local function ensureMatchers()
    local grSystem = getSystem("GangRetaliation.GRSystem")
    local lang = "en"
    local getText = nil
    if grSystem then
        local ok, value = pcall(function() return grSystem:GetText("GR-Lang") end)
        if ok and type(value) == "string" and value ~= "" and value ~= "GR-Lang" then lang = value end
        getText = function(key) return grSystem:GetText(key) end
    end
    if state.matchers == nil or state.lang ~= lang or (getText and not state.getText) then
        local changed = state.lang ~= nil and state.lang ~= lang
        state.getText = getText
        state.matchers = Tagger.buildMatchers(getText)
        state.lex = Tagger.buildLexicon(getText)
        state.lang = lang
        return changed
    end
    return false
end

-- ---------------------------------------------------------------- old log -> language-neutral log
-- Old lines ("... | NEWS | message") are rewritten as v2 lines when the message matches one of the main mod's
-- messages. The original file is kept once as data/history.log.v1.bak. Safe swap: the log is renamed aside first
-- and restored if anything goes wrong.
local function convertLog()
    local file = io.open(LOG_PATH, "r")
    if not file then return end
    local lines, changed = {}, 0
    for line in file:lines() do
        local out = line
        local parsed = Tagger.parseLine(line)
        if parsed and not parsed.args and parsed.kind == "NEWS" then
            local rec = Tagger.parseMessage(parsed.text, state.matchers, state.lex)
            if rec then
                out = Tagger.formatLine(parsed.ts, parsed.campaign, parsed.day, rec.key, rec.args, parsed.text)
                changed = changed + 1
            end
        end
        lines[#lines + 1] = out
    end
    file:close()
    if changed == 0 then return end

    local existing = io.open(LOG_PATH .. ".v1.bak", "r")
    if existing then
        existing:close()
    else
        local src = io.open(LOG_PATH, "rb")
        if not src then return end
        local data = src:read("*a")
        src:close()
        local backup = io.open(LOG_PATH .. ".v1.bak", "wb")
        if not backup then return end
        backup:write(data)
        backup:close()
    end

    local tmpPath = LOG_PATH .. ".new"
    local tmp = io.open(tmpPath, "w")
    if not tmp then return end
    tmp:write(table.concat(lines, "\n"), "\n")
    tmp:close()
    os.remove(LOG_PATH .. ".prev")
    if not os.rename(LOG_PATH, LOG_PATH .. ".prev") then
        -- renaming isn't possible here (seen in the game's sandbox): the original is already safe in
        -- history.log.v1.bak, so rewrite the log in place instead
        os.remove(tmpPath)
        local inPlace = io.open(LOG_PATH, "w")
        if not inPlace then return end
        inPlace:write(table.concat(lines, "\n"), "\n")
        inPlace:close()
        print(string.format("[GangRetaliationHistory] history.log converted to the language-neutral format (%d lines); original kept as history.log.v1.bak", changed))
        return
    end
    if not os.rename(tmpPath, LOG_PATH) then
        os.rename(LOG_PATH .. ".prev", LOG_PATH)
        return
    end
    os.remove(LOG_PATH .. ".prev")
    print(string.format("[GangRetaliationHistory] history.log converted to the language-neutral format (%d lines); original kept as history.log.v1.bak", changed))
end

-- ---------------------------------------------------------------- feed for the History screen
local function readRoster()
    local roster = {}
    local ok = pcall(function()
        local data = getSystem("GangRetaliation.GRMenuData")
        if not data then return end
        local entries = data:GetEntries()
        for _, e in ipairs(entries) do
            roster[#roster + 1] = { name = e.name, gangKey = e.gangKey, gang = e.gang }
        end
    end)
    if not ok then return {} end
    return roster
end

local function loadEvents(campaign)
    state.events = {}
    local file = io.open(LOG_PATH, "r")
    if file then
        for line in file:lines() do
            local parsed = Tagger.parseLine(line)
            if parsed and parsed.campaign == campaign then
                if parsed.args then
                    state.events[#state.events + 1] = { day = parsed.day, text = parsed.text, key = parsed.key, args = parsed.args }
                elseif parsed.kind == "NEWS" then
                    local rec = Tagger.parseMessage(parsed.text, state.matchers, state.lex)
                    state.events[#state.events + 1] = { day = parsed.day, text = parsed.text, key = rec and rec.key, args = rec and rec.args }
                end
            end
        end
        file:close()
    end
    while #state.events > MAX_EVENTS do table.remove(state.events, 1) end
    state.loadedCampaign = campaign
end

local function push(roster)
    local hist = getSystem("GangRetaliationHistory.GRChronData")
    if not hist then return false end
    ensureMatchers()
    hist:Clear()
    for _, ev in ipairs(state.events) do
        local text, kind, gangs, names = ev.text, "NEWS", nil, nil
        if ev.key and ev.args then
            text = Tagger.render(ev.key, ev.args, state.getText) or ev.text
            kind = Tagger.KEY_INFO[ev.key].kind
            gangs, names = Tagger.tagEvent(ev.key, ev.args, text, roster)
        else
            gangs, names = Tagger.tag(ev.text, roster)
        end
        hist:Add(math.floor(ev.day), kind, text, gangs, names)
    end
    return true
end

local function refresh()
    local campaign = campaignId()
    if campaign == 0 then return end
    if ensureMatchers() then state.dirty = true end   -- language changed: re-render everything
    if not state.converted then
        state.converted = true
        local ok, err = pcall(convertLog)
        if not ok then print("[GangRetaliationHistory] log conversion error: " .. tostring(err)) end
        state.loadedCampaign = 0
    end
    if campaign ~= state.loadedCampaign then
        loadEvents(campaign)
        state.rosterSig = nil
        state.dirty = true
    end
    local roster = readRoster()
    local sig = Tagger.rosterSignature(roster)
    if sig ~= state.rosterSig then
        state.rosterSig = sig
        state.dirty = true
    end
    if state.dirty then
        local ok, pushed = pcall(push, roster)
        if ok and pushed then
            state.dirty = false
            print(string.format("[GangRetaliationHistory] History screen fed: %d events, %d roster entries (campaign %s)",
                #state.events, #roster, tostring(campaign)))
        end
    end
end

local function onMessage(text)
    text = tostring(text)
    ensureMatchers()
    local rec = Tagger.parseMessage(text, state.matchers, state.lex)
    if rec then
        writeLine(rec.key, rec.args, text)
    else
        writeLine(nil, nil, text)
    end
    local campaign = campaignId()
    if campaign ~= 0 and campaign == state.loadedCampaign then
        state.events[#state.events + 1] = { day = gameDay(), text = text, key = rec and rec.key, args = rec and rec.args }
        if #state.events > MAX_EVENTS then table.remove(state.events, 1) end
        state.dirty = true
    end
end

registerForEvent("onInit", function()
    pcall(rotateIfNeeded)
    local ok, err = pcall(function()
        Observe(TARGET_CLASS, TARGET_METHOD, function(_, text)
            if text and text ~= "" then onMessage(text) end
        end)
    end)
    if ok then
        print("[GangRetaliationHistory] v" .. VERSION .. " hooked " .. TARGET_CLASS .. ":" .. TARGET_METHOD .. " -> " .. LOG_PATH)
    else
        print("[GangRetaliationHistory] could NOT hook " .. TARGET_CLASS .. ":" .. TARGET_METHOD .. " (" .. tostring(err) .. "). Logging is inactive; the main mod may have changed.")
    end
end)

-- once a second: pick up the campaign, the roster and any new events, and push them to the screen
registerForEvent("onUpdate", function(delta)
    state.timer = state.timer + delta
    if state.timer < 1.0 then return end
    state.timer = 0
    local ok, err = pcall(refresh)
    if not ok and tostring(err) ~= state.lastError then
        state.lastError = tostring(err)      -- print each distinct error once, not every second
        print("[GangRetaliationHistory] feed error: " .. state.lastError)
    end
end)
