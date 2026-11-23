-- Nemesis History data, fed by direct calls placed next to each notify() in init.lua (real variables
-- already in scope there - gang keys, names, the exact args passed to that notify's string.format), not
-- by re-parsing rendered text. Replaces the old companion mod's log-reading + regex-matching pipeline
-- (modules/tagger.lua, now deleted) entirely: there is nothing left to reconstruct, so there is nothing
-- left to get it wrong.
--
-- What actually gets stored is the message KEY plus its substitution ARGS, not a rendered sentence -
-- Menu.reds's RenderHistoryText() looks up the key's template in whatever language is active and
-- substitutes the args fresh every time a history row is built (render at display time), so a language
-- switch mid-save changes how old entries read too, instead of freezing them in whatever language was
-- active when the event happened.
--
-- Persistence: one file PER CAMPAIGN (data/history_<campaignId>.log, see logPath()), not one shared file -
-- so clearing a campaign's history (the Clear Log setting) only ever touches that campaign's own file, never
-- any other save's. Each file is plain text, one line per event, fields separated by a literal tab
-- (day \t kind \t key \t gangs \t names \t args). Tabs, not " | ", because gangs/names are themselves
-- "|Key1|Key2|" pipe-delimited lists (the way GRChronData.Add expects) - with " | " as the top-level
-- separator too, a 2+-element list like "|NameA|NameB|" collides with the field boundary and breaks
-- re-parsing on the next load. Tabs never appear in a gang key, nemesis name, message key, or arg value, so
-- there's no ambiguity. GRChronData itself (a ScriptableSystem) does not persist across sessions on its
-- own, hence this file.
--
-- One-time legacy migration: if no per-campaign file has ever been written (data/.legacy_migrated doesn't
-- exist), migrateOldLog() looks for the old standalone GangRetaliationHistory companion mod's history.log
-- and replays its events in, split out into their own per-campaign files (the old log mixed every campaign
-- together in one file too, tagged with "campaign %d+" per line). That old format already tags each line
-- with the message key and a roster of gang/name tokens (Tagger.encode's "G~label", "N~name~title~gang",
-- etc., joined by "^"), so migrated entries still filter correctly by member/gang - only the event TEXT is
-- a frozen, already-rendered sentence (the old format's last column), not key+args, since the exact
-- string.format args used at the time aren't recoverable from that log. Substitute() leaves a template
-- with no "%s"/"%d" tokens untouched, so a frozen sentence just displays as-is regardless of the active
-- language - the same thing an un-migrated raw sentence has always done.
local Names = require("modules/names")

local History = {}

local LOG_DIR = "data/"
local MIGRATION_MARKER = "data/.legacy_migrated"
local MAX_BYTES = 1024 * 1024   -- rotate a campaign's file to .old once per session if larger
local MAX_EVENTS = 600          -- per campaign file, newest kept

local function logPath(campaign)
    return LOG_DIR .. "history_" .. tostring(math.floor(campaign)) .. ".log"
end

-- main mod message key -> event kind (short code shown/colored in the History tabs)
History.KIND = {
    ["GR-MsgNemesisDead"] = "DEATH",
    ["GR-MsgNemesisConfirmed"] = "DEATH",
    ["GR-MsgNemesisDeadOther"] = "DEATH",
    ["GR-MsgNemesisDeadPolice"] = "DEATH",
    ["GR-MsgNemesisDeadGang"] = "DEATH",
    ["GR-MsgBossDown"] = "VACUUM",
    ["GR-MsgAmbush"] = "AMBUSH",
    ["GR-MsgGig"] = "BACKUP",
    ["GR-MsgSquadTWR"] = "BACKUP",
    ["GR-MsgSquadDD"] = "BACKUP",
    ["GR-MsgEscaped"] = "ESCAPED",
    ["GR-MsgEscapedDismembered"] = "ESCAPED",
    ["GR-MsgAgainEscaped"] = "ESCAPED",
    ["GR-MsgAgainEscapedDismembered"] = "ESCAPED",
    ["GR-MsgFled"] = "ESCAPED",
    ["GR-MsgFledDismembered"] = "ESCAPED",
    ["GR-MsgAgainFled"] = "ESCAPED",
    ["GR-MsgAgainFledDismembered"] = "ESCAPED",
    ["GR-MsgKnockedOut"] = "ESCAPED",
    ["GR-MsgKnockedOutDismembered"] = "ESCAPED",
    ["GR-MsgAgainKnockedOut"] = "ESCAPED",
    ["GR-MsgAgainKnockedOutDismembered"] = "ESCAPED",
    ["GR-MsgPromoted"] = "PROMOTED",
    ["GR-MsgRecruited"] = "NEWFACE",
    ["GR-MsgFeudKill"] = "FEUD",
    ["GR-MsgFeudDemote"] = "FEUD",
    ["GR-MsgFeudFail"] = "FEUD",
    ["GR-MsgFeudFailDead"] = "FEUD",
    ["GR-MsgReturned"] = "RETURNED",
    ["GR-MsgReturnedKnockedOut"] = "RETURNED",
    ["GR-MsgReleased"] = "RELEASED",
    ["GR-MsgPoliceArrest"] = "ARREST",
    ["GR-MsgPoliceEscape"] = "RAID",
    ["GR-MsgRaid"] = "RAID",
    ["GR-MsgRaidBarghest"] = "RAID",
    ["GR-MsgBarghestEscape"] = "RAID",
    ["GR-MsgWarStart"] = "WAR",
    ["GR-MsgSkirmish"] = "WAR",
    ["GR-MsgWarWon"] = "TERRITORY",
    ["GR-MsgWarHeld"] = "TERRITORY",
    ["GR-MsgStrongholdCleared"] = "STRONGHOLD",
    ["GR-MsgBossWeapon"] = "WEAPON",
    ["GR-IntelGained"] = "INTEL",
    ["GR-IntelLocated"] = "INTEL",
    ["GR-MsgTraitStrong"] = "TRAIT",
    ["GR-MsgTraitWeak"] = "TRAIT",
    ["GR-MsgScan"] = "TRAIT",
}

local state = {
    getSystem = nil,   -- injected: function(name) -> system or nil
    campaignId = nil,  -- injected: function() -> number, the live current campaign id (GR.campaignId)
    loadedCampaign = -1,
    gameDay = nil,     -- injected: function() -> number
    log = nil,         -- injected: function(msg) - init.lua's own debug_onscreen.log writer, always
                        -- flushed, not gated on any setting (see init.lua's appendDebugLogLine) - used here
                        -- so migration's outcome is visible without needing the CET console, which doesn't
                        -- persist print() anywhere on this install.
}

local function dlog(msg)
    if state.log then
        pcall(state.log, "[History] " .. msg)
    end
end

local function pack(list)
    if #list == 0 then return "||" end
    return "|" .. table.concat(list, "|") .. "|"
end

-- args, plain pipe-joined (no framing pipes - these are positional substitution values, not a
-- membership list StrContains needs to match exactly, so there's nothing to frame).
local function packArgs(list)
    local parts = {}
    for i, v in ipairs(list or {}) do
        parts[i] = tostring(v)
    end
    return table.concat(parts, "|")
end

-- "key|arg1|arg2|..." (or just "key" with no trailing pipe when there are no args) - this exact string
-- is what lands in GRChronData's text slot and what Menu.reds's RenderHistoryText() splits back apart.
local function encodeKeyArgs(key, argsStr)
    if argsStr == "" then return key end
    return key .. "|" .. argsStr
end

local function hist()
    if not state.getSystem then return nil end
    return state.getSystem("GangRetaliation.GRChronData")
end

local function rotateIfNeeded(campaign)
    local path = logPath(campaign)
    local file = io.open(path, "r")
    if not file then return end
    local size = file:seek("end")
    file:close()
    if size and size > MAX_BYTES then
        os.remove(path .. ".old")
        os.rename(path, path .. ".old")
    end
end

-- "123\tPROMOTED\tGR-MsgPromoted\t|Maelstrom|\t|Rico Alvarez|\tRico Alvarez|Captain|Maelstrom"
-- (last field is the pipe-joined args, not a rendered sentence - see the module header. Tab-separated,
-- not " | ", so a multi-element gangs/names pack like "|A|B|" can't be confused with a field boundary.)
-- kind is its own column, not re-derived from key at load time, because a migrated legacy entry's "key"
-- slot holds a frozen sentence instead of a real History.KIND key - re-deriving would always miss and
-- silently reclassify every migrated event as plain "NEWS" on the very next reload. No campaign column -
-- the file itself (see logPath()) is already scoped to one campaign.
local function formatLine(day, kind, key, gangs, names, argsStr)
    return string.format("%d\t%s\t%s\t%s\t%s\t%s", math.floor(day), kind, (key:gsub("[\n\t]", " ")), gangs, names, (argsStr:gsub("[\n\t]", " ")))
end

local function parseLine(line)
    local dayS, kind, key, gangs, names, argsStr = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$")
    if not dayS then return nil end
    local day = tonumber(dayS)
    if not day then return nil end
    return { day = day, kind = kind, key = key, gangs = gangs, names = names, argsStr = argsStr }
end

local function appendLine(campaign, day, kind, key, gangs, names, argsStr)
    pcall(function()
        local file = io.open(logPath(campaign), "a")
        if not file then return end
        file:write(formatLine(day, kind, key, gangs, names, argsStr), "\n")
        file:close()
    end)
end

-- ---------------------------------------------------------------- one-time legacy data migration
-- Confirmed in-game 2026-11-22: CET's Lua sandbox rejects io.open paths that climb out of this mod's own
-- folder via "../" (every other relative path this mod already uses, all inside its own folder, works
-- fine - it's specifically the ".." that's blocked). So the old standalone mod's data/history.log has to
-- be copied INTO this mod's own folder first (as data/legacy_history.log, a plain file-system copy done
-- from outside the game - the sandbox only restricts this mod's own Lua code, not that) - tried first. The
-- "../" paths are kept as a second attempt in case a different CET build/config ever allows it, but are
-- not expected to succeed on this install.
local OLD_LOG_PATHS = {
    "data/legacy_history.log",
    "../GangRetaliationHistory/data/history.log",
    "../GangRetaliationHistory.disabled/data/history.log",
}

local function splitPlain(s, sep)
    local out = {}
    local start = 1
    while true do
        local i = s:find(sep, start, true)
        if not i then
            out[#out + 1] = s:sub(start)
            break
        end
        out[#out + 1] = s:sub(start, i - 1)
        start = i + #sep
    end
    return out
end

local function trim(s)
    return (s or ""):match("^%s*(.-)%s*$")
end

-- Old roster tokens (Tagger.encode, the now-deleted companion mod's own format): tokens joined by "^",
-- each "TAG~field~field~...". Only "G~label" (a bare gang DISPLAY LABEL, not its internal key) and
-- "N~name~title~gang" (a nemesis, whose own gang field may be blank if the gang was already tagged
-- separately) carry anything this mod's member/gang filtering needs - R~/T~/L~/P~ tokens (rank codes,
-- traits, districts) are ignored here.
--
-- Confirmed from the real log (2026-11-22): roster gang fields are display labels ("6th Street",
-- "Tyger Claws", "Voodoo Boys", "Scavs"), not the internal keys ("SixthStreet", "TygerClaws",
-- "VoodooBoys", "Scavengers") GangColor()/entry.gangKey filtering actually matches against - those 4
-- gangs' migrated events silently matched nothing (blank Gang History, missing member history) until
-- this was caught. toGangKey() maps back via names.lua's own Names.gangLabels (the single source of
-- truth for key<->label, so this can't drift out of sync the way a separate hardcoded table would) -
-- gangs whose label already equals their key (Maelstrom, Valentinos, Animals, Wraiths, Barghest) just
-- pass through unchanged. Also trims stray trailing spaces some old roster tokens have (e.g. "G~Scavs ").
local LABEL_TO_KEY = {}
for key, label in pairs(Names.gangLabels) do
    LABEL_TO_KEY[label] = key
end

local function toGangKey(label)
    label = trim(label)
    if label == "" then return "" end
    return LABEL_TO_KEY[label] or label
end

local function parseOldRoster(roster)
    local gangs, names = {}, {}
    for _, token in ipairs(splitPlain(roster or "", "^")) do
        local f = splitPlain(token, "~")
        if f[1] == "G" then
            local key = toGangKey(f[2])
            if key ~= "" then gangs[#gangs + 1] = key end
        elseif f[1] == "N" then
            local name = trim(f[2])
            if name ~= "" then names[#names + 1] = name end
            local key = toGangKey(f[4])
            if key ~= "" then gangs[#gangs + 1] = key end
        end
    end
    return gangs, names
end

-- Narrow fallback, only used when a line had NO roster at all - 29 of the user's real 863 lines, all
-- "NEWS" (the old Tagger's "couldn't classify this one" kind), where the rendered sentence still plainly
-- names a nemesis/gang even though nothing structured was ever tagged for it. Not a revival of the old
-- Tagger's general text-matching approach (there is no plan to extend this to real message keys) - purely
-- a one-time migration aid for this specific handful of legacy lines, since every NEW event going forward
-- already gets real structured args from History.record's call sites and never needs this at all.
-- Two known shapes in the real data: "Name \"Title\" (Gang) ran away/came to again/ran from you again..."
-- (name+title+gang) and "Intel on Rank Name \"Title\" - strength/weakness: ..." (name+title only - these
-- never mention a gang in the text at all).
local function extractFromSentence(sentence)
    local name, _, gangLabel = sentence:match('^(.-) "(.-)" %((.-)%)')
    if name then
        local gangs = {}
        local key = toGangKey(gangLabel)
        if key ~= "" then gangs[1] = key end
        return gangs, { trim(name) }
    end
    name = sentence:match('^Intel on %a+ (.-) "(.-)"%s*%-')
    if name then
        return {}, { trim(name) }
    end
    return {}, {}
end

-- "2026-11-08 11:19:00 | campaign 333771167 | day   36.5 | GR-MsgRecruited          | G~Wraiths^N~Cactus~the Usurper~^R~R2 | New face in the Wraiths: Cactus "the Usurper", Lieutenant."
-- (key+roster+sentence) or, when the old Tagger couldn't classify a message, just key+sentence with no
-- roster at all ("... | NEWS            | some already-rendered line"). Try the richer pattern first.
-- Captures the old log's own "campaign %d+" field too, so each migrated event lands in the right
-- per-campaign file (the old log mixed every campaign into one file; this one splits them back out).
local function parseOldLine(line)
    local campaignS = line:match("campaign (%d+)")
    local campaign = tonumber(campaignS) or 0
    local day, key, roster, sentence, gangs, names
    day, key, roster, sentence = line:match("| day%s+([%-%d%.]+) | (%S+)%s*| (.-) | (.*)$")
    if day then
        gangs, names = parseOldRoster(roster)
    else
        day, key, sentence = line:match("| day%s+([%-%d%.]+) | (%S+)%s*| (.*)$")
        gangs, names = {}, {}
    end
    if not day then return nil end
    if #gangs == 0 and #names == 0 then
        gangs, names = extractFromSentence(sentence)
    end
    return { day = tonumber(day) or 0, campaign = campaign, key = key, gangs = gangs, names = names, sentence = sentence }
end

local function openFirst(paths)
    for _, path in ipairs(paths) do
        local file = io.open(path, "r")
        if file then return file, path end
    end
    return nil, nil
end

-- Runs once ever: data/.legacy_migrated's mere existence (written at the end of this function regardless
-- of outcome) is the "already attempted" marker, so a later Clear Log on one campaign's file can never
-- cause the old data to come flooding back in. If the old mod's log can't be found (not installed, already
-- removed, or CET blocked the "../"/same-folder-copy traversal), this is a no-op, same as if there were
-- nothing to migrate - every branch below logs through dlog() so the outcome is visible in
-- data/debug_onscreen.log without needing the CET console.
local function migrateOldLog()
    if io.open(MIGRATION_MARKER, "r") then return end
    local old, foundPath = openFirst(OLD_LOG_PATHS)
    if not old then
        dlog("migration: old log not found at any known path - nothing to migrate (or CET blocked the traversal)")
    else
        dlog("migration: found old log at \"" .. foundPath .. "\", migrating...")
        local migrated, campaigns = 0, {}
        for line in old:lines() do
            local ev = parseOldLine(line)
            if ev then
                -- Frozen sentence, no args: stored as the "key" slot with an empty argsStr, same as any
                -- template with no "%s"/"%d" tokens - Substitute() returns it unchanged (see module
                -- header). kind is looked up from the REAL old key now, while it's still in scope, and
                -- persisted explicitly (see formatLine) so it survives every future reload too.
                local kind = History.KIND[ev.key] or "NEWS"
                appendLine(ev.campaign, ev.day, kind, ev.sentence, pack(ev.gangs), pack(ev.names), "")
                migrated = migrated + 1
                campaigns[ev.campaign] = true
            end
        end
        old:close()
        local campaignCount = 0
        for _ in pairs(campaigns) do campaignCount = campaignCount + 1 end
        dlog("migration: done, " .. migrated .. " legacy events migrated across " .. campaignCount .. " campaign(s)")
    end
    pcall(function()
        local marker = io.open(MIGRATION_MARKER, "w")
        if marker then
            marker:write(os.date("%Y-%m-%d %H:%M:%S"), "\n")
            marker:close()
        end
    end)
end

-- Reads this campaign's own file and replays it into GRChronData.
local function loadFromLog(campaign)
    local h = hist()
    if not h then return end
    h:Clear()
    local file = io.open(logPath(campaign), "r")
    if not file then return end
    local lines = {}
    for line in file:lines() do
        local parsed = parseLine(line)
        if parsed then lines[#lines + 1] = parsed end
    end
    file:close()
    while #lines > MAX_EVENTS do table.remove(lines, 1) end
    for _, ev in ipairs(lines) do
        h:Add(ev.day, ev.kind, encodeKeyArgs(ev.key, ev.argsStr), ev.gangs, ev.names)
    end
end

-- Call once from init.lua's onInit, passing the two small accessors it already has plus its own
-- always-flushed debug_onscreen.log writer (appendDebugLogLine) so migration's outcome is observable.
function History.init(getSystem, gameDay, log)
    state.getSystem = getSystem
    state.gameDay = gameDay
    state.log = log
    local ok, err = pcall(migrateOldLog)
    if not ok then
        dlog("migration: crashed - " .. tostring(err))
    end
end

-- Call once per tick (init.lua's own update(delta)) with the current campaign id - reloads this campaign's
-- file into GRChronData only when the campaign actually changes (new game/save loaded), not every tick.
function History.onCampaignTick(campaignId)
    if campaignId == 0 or campaignId == state.loadedCampaign then return end
    state.loadedCampaign = campaignId
    pcall(function() rotateIfNeeded(campaignId) end)
    pcall(function() loadFromLog(campaignId) end)
end

-- gangKeys/names: plain Lua arrays of real gang-key / nemesis-name strings already in scope at the
-- notify() call site this sits next to. args: the exact substitution values that were passed to that
-- site's string.format() call, in order - NOT the already-formatted sentence. Stored as key+args so the
-- sentence can be rendered fresh in whatever language is active whenever the history panel is opened.
function History.record(key, gangKeys, names, args)
    if not state.gameDay then return end
    local campaign = state.loadedCampaign
    if not campaign or campaign == 0 or campaign == -1 then return end
    local day = state.gameDay()
    local gangs, names_s = pack(gangKeys or {}), pack(names or {})
    local argsStr = packArgs(args)
    local kind = History.KIND[key] or "NEWS"
    appendLine(campaign, day, kind, key, gangs, names_s, argsStr)
    local h = hist()
    if h then
        h:Add(math.floor(day), kind, encodeKeyArgs(key, argsStr), gangs, names_s)
    end
end

-- For the upcoming "Clear Log" mod setting: deletes ONLY the current campaign's own file (never any other
-- save's) and clears the live in-memory GRChronData so the GANGS menu reflects it immediately, without
-- needing a relaunch. Caller is responsible for its own "are you sure, this cannot be undone" confirmation.
function History.ClearCurrentCampaign()
    local campaign = state.loadedCampaign
    if not campaign or campaign == 0 or campaign == -1 then return false end
    os.remove(logPath(campaign))
    local h = hist()
    if h then h:Clear() end
    dlog("cleared history for campaign " .. tostring(campaign))
    return true
end

return History
