-- Pure logic for the History feed (no game calls, so it can be unit-tested offline):
--   * parse a history.log line (old "NEWS" lines and the language-neutral v2 lines)
--   * turn a shown message into a LANGUAGE-NEUTRAL record: the main mod's message key plus typed
--     arguments (nemesis, gang, rank, trait, plain text), by matching it against the main mod's own
--     message templates (the localized ones are fetched at runtime; English fallbacks are built in)
--   * render a record back to text in whatever language is active
--   * tag a record with the gangs and nemeses it involves (using the live roster)
--
-- Nemesis TITLES ("the Usurper" / "el Usurpador") live only inside the main mod's own data, so they cannot be
-- translated here: a title is shown as it was recorded. Everything else in a sentence follows the game language.

local Tagger = {}

-- gang display label (what the main mod prints) -> gang key
Tagger.LABEL_TO_KEY = {
    ["Maelstrom"] = "Maelstrom",
    ["Tyger Claws"] = "TygerClaws",
    ["Valentinos"] = "Valentinos",
    ["6th Street"] = "SixthStreet",
    ["Animals"] = "Animals",
    ["Voodoo Boys"] = "VoodooBoys",
    ["Wraiths"] = "Wraiths",
    ["Scavs"] = "Scavengers",
    ["Barghest"] = "Barghest",
}

-- main mod message key, event kind, English template (fallback when the localized one isn't available),
-- argument types in order: N nemesis, G gang, R rank, P plain text, T one trait, L list of traits
Tagger.KEYS = {
    { "GR-MsgNemesisDead",       "DEATH",     "%s is dead... for now.",                                   "N" },
    { "GR-MsgNemesisConfirmed",  "DEATH",     "%s is dead. For good this time.",                          "N" },
    { "GR-MsgNemesisDeadOther",  "DEATH",     "%s is dead. Nobody knows who did it.",                     "N" },
    { "GR-MsgNemesisDeadPolice", "DEATH",     "Rumor: the NCPD took down %s.",                            "N" },
    { "GR-MsgNemesisDeadGang",   "DEATH",     "Rumor: %s was taken down by the %s.",                      "NG" },
    { "GR-MsgBossDown",          "VACUUM",    "The %s lost their boss. Someone will want the throne...",  "G" },
    { "GR-MsgAmbush",            "AMBUSH",    "Ambush! %s found you.",                                    "N" },
    { "GR-MsgGig",               "BACKUP",    "%s heard you were coming and brought backup!",             "N" },
    { "GR-MsgSquadTWR",          "BACKUP",    "%s is leading the vengeance squad!",                       "N" },
    { "GR-MsgSquadDD",           "BACKUP",    "%s came with the crew hitting your business!",             "N" },
    { "GR-MsgEscaped",           "ESCAPED",   "%s got away wounded. They will remember you.",             "N" },
    { "GR-MsgEscapedDismembered","ESCAPED",   "%s got away missing a limb. They will remember you.",      "N" },
    { "GR-MsgAgainEscaped",      "ESCAPED",   "%s escaped you again. They are getting stronger.",         "N" },
    { "GR-MsgAgainEscapedDismembered", "ESCAPED", "%s escaped you again. They are injured but getting stronger.", "N" },
    { "GR-MsgFled",              "ESCAPED",   "%s ran away. They will come back for you.",                "N" },
    { "GR-MsgFledDismembered",   "ESCAPED",   "%s ran away injured. They will come back for you.",        "N" },
    { "GR-MsgKnockedOut",        "ESCAPED",   "%s upgraded their chrome, vowing revenge.",                "N" },
    { "GR-MsgKnockedOutDismembered", "ESCAPED", "%s awoke with new chrome. They won't forget this.",      "N" },
    { "GR-MsgPromoted",          "PROMOTED",  "%s rose to %s of the %s.",                                 "NRG" },
    { "GR-MsgRecruited",         "NEWFACE",   "New face in the %s: %s, %s.",                              "GNR" },
    { "GR-MsgFeudKill",          "FEUD",      "Rumor: %s killed %s and is now %s of the %s.",             "NNRG" },
    { "GR-MsgFeudDemote",        "FEUD",      "Rumor: %s overthrew %s and is now %s of the %s.",          "NNRG" },
    { "GR-MsgFeudFail",          "FEUD",      "Rumor: %s put %s in their place.",                         "NN" },
    { "GR-MsgFeudFailDead",      "FEUD",      "Rumor: %s challenged %s and paid with their life.",        "NN" },
    { "GR-MsgReturned",          "RETURNED",  "%s is back from the dead, rebuilt with chrome. They are coming for you.", "N" },
    { "GR-MsgReturnedKnockedOut", "RETURNED", "%s was recovered and has been upgraded with chrome. Watch your back.", "N" },
    { "GR-MsgReleased",          "RELEASED",  "%s is back on the street.",                                "N" },
    { "GR-MsgPoliceArrest",      "ARREST",    "Rumor: the NCPD arrested %s. They will be out in a few days.", "N" },
    { "GR-MsgPoliceEscape",      "RAID",      "Rumor: %s shot their way out of an NCPD raid.",            "N" },
    { "GR-MsgRaid",              "RAID",      "The NCPD is raiding %s nearby!",                           "N" },
    { "GR-MsgTraitStrong",       "TRAIT",     "Strength found - %s: %s",                                  "NT" },
    { "GR-MsgTraitWeak",         "TRAIT",     "Weakness found - %s: %s",                                  "NT" },
    { "GR-MsgScan",              "TRAIT",     "%s - Strengths: %s. Weaknesses: %s.",                      "NLL" },
    { "GR-MsgWarStart",          "WAR",       "Rumor: the %s are attacking the %s in %s.",                "GGP" },
    { "GR-MsgSkirmish",          "WAR",       "The %s and the %s are shooting it out nearby!",            "GG" },
    { "GR-MsgWarWon",            "TERRITORY", "The %s took %s from the %s.",                              "GPG" },
    { "GR-MsgWarHeld",           "TERRITORY", "The %s held %s against the %s.",                           "GPG" },
    -- added for Gang Retaliation 1.4.0
    { "GR-MsgRaidBarghest",      "RAID",      "Barghest is raiding %s nearby!",                           "N" },
    { "GR-MsgBarghestEscape",    "RAID",      "Rumor: %s shot their way out of a Barghest raid.",         "N" },
    { "GR-MsgStrongholdCleared", "STRONGHOLD", "The %s stronghold has fallen.",                           "G" },
    { "GR-MsgBossWeapon",        "WEAPON",    "You took %s.",                                             "P" },
    -- added for Gang Retaliation 1.4.5 (these two use {gang} / {pct} placeholders, in that order)
    { "GR-IntelGained",          "INTEL",     "{gang} intel: {pct} %",                                    "GP" },
    { "GR-IntelLocated",         "INTEL",     "{gang} stronghold located",                                "G" },
}

Tagger.KEY_INFO = {}
for _, entry in ipairs(Tagger.KEYS) do
    Tagger.KEY_INFO[entry[1]] = { kind = entry[2], template = entry[3], types = entry[4] }
end

-- rank codes -> the main mod's localization key and the English word (fallback)
Tagger.RANK_KEYS = { R3 = "GR-RankBoss", R3F = "GR-RankBossF", R2 = "GR-RankLieutenant", R1 = "GR-RankSoldier" }
Tagger.RANK_EN = { R3 = "Boss", R3F = "Boss", R2 = "Lieutenant", R1 = "Soldier" }
Tagger.RANK_ORDER = { "R3", "R3F", "R2", "R1" }

-- trait key -> English text (fallback); the main mod's localization key is "GR-Trait-<key>"
Tagger.TRAITS = {
    { "fireproof", "Fire resistant" }, { "fear_fire", "Weak to fire" },
    { "insulated", "Shock resistant" }, { "weak_shock", "Weak to electricity" },
    { "toxproof", "Toxin resistant" }, { "weak_tox", "Weak to toxins" },
    { "brawler", "Seasoned brawler (resists melee)" }, { "weak_melee", "Weak to melee" },
    { "blastproof", "Blast resistant" }, { "weak_blast", "Weak to explosives" },
    { "firewall", "Firewall (resists quickhacks)" }, { "weak_hack", "Weak to quickhacks" },
    { "hardhead", "Hard head (resists headshots)" }, { "glass_jaw", "Glass jaw (weak to headshots)" },
    { "tough", "Thick skin (takes less damage)" }, { "deadly", "Deadly (hits V harder)" },
}

-- ---------------------------------------------------------------- helpers
local MAGIC = "[%^%$%(%)%%%.%[%]%*%+%-%?]"

local function escapePattern(s)
    return (s:gsub(MAGIC, "%%%0"))
end

local function splitPlain(s, sep)
    local out, pos = {}, 1
    while true do
        local a, b = s:find(sep, pos, true)
        if not a then
            out[#out + 1] = s:sub(pos)
            break
        end
        out[#out + 1] = s:sub(pos, a - 1)
        pos = b + 1
    end
    return out
end

local function clean(s)
    return (tostring(s or ""):gsub("[%^~;]", " "))
end

local function validText(value, key)
    return type(value) == "string" and value ~= "" and value ~= key
end

local function safeGet(getText, key)
    if not getText then return nil end
    local ok, value = pcall(getText, key)
    if ok and validText(value, key) then return value end
    return nil
end

-- the 1.4.5 messages use {gang} / {pct} instead of %s: treat each as one %s slot, in order of appearance
local function normalizeTemplate(template)
    return (template:gsub("{gang}", "%%s"):gsub("{pct}", "%%s"))
end

-- "Rumor: %s put %s in their place."  ->  "^Rumor: (.+) put (.+) in their place%.$"
function Tagger.templateToPattern(template)
    template = normalizeTemplate(template)
    local parts, pos = {}, 1
    while true do
        local a, b = template:find("%s", pos, true)
        if not a then
            parts[#parts + 1] = escapePattern(template:sub(pos))
            break
        end
        parts[#parts + 1] = escapePattern(template:sub(pos, a - 1))
        parts[#parts + 1] = "(.+)"
        pos = b + 1
    end
    return "^" .. table.concat(parts) .. "$"
end

-- getText(key) -> localized template or nil. Both the localized and the English template are matched.
function Tagger.buildMatchers(getText)
    local matchers = {}
    for _, entry in ipairs(Tagger.KEYS) do
        local key, kind, fallback, types = entry[1], entry[2], entry[3], entry[4]
        local templates = { fallback }
        local localized = safeGet(getText, key)
        if localized and localized ~= fallback then
            templates[#templates + 1] = localized
        end
        for _, template in ipairs(templates) do
            matchers[#matchers + 1] = { key = key, kind = kind, types = types, pattern = Tagger.templateToPattern(template) }
        end
    end
    return matchers
end

function Tagger.classify(text, matchers)
    for _, m in ipairs(matchers) do
        if text:match(m.pattern) then
            return m.kind
        end
    end
    return "NEWS"
end

-- words of the current language (plus English) -> rank codes / trait keys, so old and new text both parse
function Tagger.buildLexicon(getText)
    local lex = { rank = {}, traits = {} }
    for _, code in ipairs(Tagger.RANK_ORDER) do
        local word = safeGet(getText, Tagger.RANK_KEYS[code])
        if word and not lex.rank[word] then lex.rank[word] = code end
    end
    for _, code in ipairs(Tagger.RANK_ORDER) do
        local word = Tagger.RANK_EN[code]
        if not lex.rank[word] then lex.rank[word] = code end
    end
    for _, t in ipairs(Tagger.TRAITS) do
        local localized = safeGet(getText, "GR-Trait-" .. t[1])
        if localized and not lex.traits[localized] then lex.traits[localized] = t[1] end
        if not lex.traits[t[2]] then lex.traits[t[2]] = t[1] end
    end
    return lex
end

-- ---------------------------------------------------------------- parsing a shown message
-- `Name "Title"`, `Name "Title" (Gang)` or just `Name`
local function parseNemesis(s)
    local name, title, rest = s:match('^(.-) "(.-)"(.*)$')
    if not name then
        if s:find('"', 1, true) or s == "" then return nil end
        return { t = "N", name = s, title = "", gang = "" }
    end
    local gang = ""
    if rest ~= "" then
        gang = rest:match("^ %((.+)%)$")
        if not gang then return nil end
    end
    return { t = "N", name = name, title = title, gang = gang }
end

local function parseTrait(text, lex)
    local key = lex.traits[text]
    if key then return { k = key } end
    return { r = text }
end

-- returns { key=, kind=, args={...} } or nil when the text matches none of the main mod's messages
function Tagger.parseMessage(text, matchers, lex)
    for _, m in ipairs(matchers) do
        local caps = { text:match(m.pattern) }
        if #caps == #m.types and #caps > 0 then
            local args, ok = {}, true
            for i = 1, #m.types do
                local t, v = m.types:sub(i, i), caps[i]
                if t == "N" then
                    local n = parseNemesis(v)
                    if not n then ok = false break end
                    args[i] = n
                elseif t == "R" then
                    local code = lex.rank[v]
                    if code then args[i] = { t = "R", code = code } else args[i] = { t = "P", text = v } end
                elseif t == "G" then
                    args[i] = { t = "G", label = v }
                elseif t == "T" then
                    args[i] = { t = "T", item = parseTrait(v, lex) }
                elseif t == "L" then
                    local items = {}
                    for _, part in ipairs(splitPlain(v, ", ")) do items[#items + 1] = parseTrait(part, lex) end
                    args[i] = { t = "L", items = items }
                else
                    args[i] = { t = "P", text = v }
                end
            end
            if ok then
                return { key = m.key, kind = m.kind, args = args }
            end
        end
    end
    return nil
end

-- ---------------------------------------------------------------- storage format
local function encodeItem(item)
    if item.k then return "k:" .. clean(item.k) end
    return "r:" .. clean(item.r)
end

local function decodeItem(s)
    local tag, rest = s:match("^(%a):(.*)$")
    if tag == "k" then return { k = rest } end
    return { r = rest or s }
end

function Tagger.encode(args)
    local tokens = {}
    for _, a in ipairs(args) do
        if a.t == "N" then
            tokens[#tokens + 1] = "N~" .. clean(a.name) .. "~" .. clean(a.title) .. "~" .. clean(a.gang)
        elseif a.t == "R" then
            tokens[#tokens + 1] = "R~" .. clean(a.code)
        elseif a.t == "G" then
            tokens[#tokens + 1] = "G~" .. clean(a.label)
        elseif a.t == "T" then
            tokens[#tokens + 1] = "T~" .. encodeItem(a.item)
        elseif a.t == "L" then
            local parts = {}
            for _, item in ipairs(a.items) do parts[#parts + 1] = encodeItem(item) end
            tokens[#tokens + 1] = "L~" .. table.concat(parts, ";")
        else
            tokens[#tokens + 1] = "P~" .. clean(a.text)
        end
    end
    return table.concat(tokens, "^")
end

function Tagger.decode(str)
    local args = {}
    if not str or str == "" then return args end
    for _, token in ipairs(splitPlain(str, "^")) do
        local f = splitPlain(token, "~")
        local t = f[1]
        if t == "N" then
            args[#args + 1] = { t = "N", name = f[2] or "", title = f[3] or "", gang = f[4] or "" }
        elseif t == "R" then
            args[#args + 1] = { t = "R", code = f[2] or "R1" }
        elseif t == "G" then
            args[#args + 1] = { t = "G", label = f[2] or "" }
        elseif t == "T" then
            args[#args + 1] = { t = "T", item = decodeItem(f[2] or "") }
        elseif t == "L" then
            local items = {}
            for _, part in ipairs(splitPlain(f[2] or "", ";")) do
                if part ~= "" then items[#items + 1] = decodeItem(part) end
            end
            args[#args + 1] = { t = "L", items = items }
        else
            args[#args + 1] = { t = "P", text = f[2] or "" }
        end
    end
    return args
end

-- "2026-11-09 20:06:11 | campaign 333771167 | day   40.8 | NEWS           | message"            (old / unmatched)
-- "2026-11-09 20:06:11 | campaign 333771167 | day   40.8 | GR-MsgPromoted | N~..^R~R2^G~... | message"   (v2)
function Tagger.parseLine(line)
    local ts, campaign, day, kind, rest = line:match("^(.-) | campaign (%d+) | day%s+([%d%.%-]+) | (%S+)%s*| (.*)$")
    if not ts then
        return nil
    end
    local parsed = { ts = ts, campaign = tonumber(campaign), day = tonumber(day) or 0, kind = kind, text = rest }
    if Tagger.KEY_INFO[kind] then
        local encoded, text = rest:match("^(.-) | (.*)$")
        if encoded then
            parsed.key = kind
            parsed.args = Tagger.decode(encoded)
            parsed.text = text
        end
    end
    return parsed
end

function Tagger.formatLine(ts, campaign, day, key, args, text)
    if key and args then
        return string.format("%s | campaign %s | day %6.1f | %-24s | %s | %s", ts, tostring(campaign), day, key, Tagger.encode(args), text)
    end
    return string.format("%s | campaign %s | day %6.1f | %-14s | %s", ts, tostring(campaign), day, "NEWS", text)
end

-- ---------------------------------------------------------------- rendering in the active language
local function itemText(item, getText)
    if item.k then
        return safeGet(getText, "GR-Trait-" .. item.k) or (function()
            for _, t in ipairs(Tagger.TRAITS) do if t[1] == item.k then return t[2] end end
            return item.k
        end)()
    end
    return item.r or ""
end

local function argText(a, getText)
    if a.t == "N" then
        local out = a.name
        if a.title ~= "" then out = out .. ' "' .. a.title .. '"' end
        if a.gang ~= "" then out = out .. " (" .. a.gang .. ")" end
        return out
    elseif a.t == "R" then
        return safeGet(getText, Tagger.RANK_KEYS[a.code] or "") or Tagger.RANK_EN[a.code] or a.code
    elseif a.t == "G" then
        return a.label
    elseif a.t == "T" then
        return itemText(a.item, getText)
    elseif a.t == "L" then
        local parts = {}
        for _, item in ipairs(a.items) do parts[#parts + 1] = itemText(item, getText) end
        return table.concat(parts, ", ")
    end
    return a.text or ""
end

-- the sentence for a record in the language getText serves (English when it serves nothing)
function Tagger.render(key, args, getText)
    local info = Tagger.KEY_INFO[key]
    if not info then return nil end
    local template = normalizeTemplate(safeGet(getText, key) or info.template)
    local index = 0
    return (template:gsub("%%s", function()
        index = index + 1
        local a = args[index]
        if not a then return "%s" end
        return argText(a, getText)
    end))
end

-- ---------------------------------------------------------------- tagging
-- true when `needle` occurs in `text` as a whole word (and, when `after` is given, directly followed by it)
local function containsWhole(text, needle, after)
    local target = needle .. (after or "")
    local init = 1
    while true do
        local a, b = text:find(target, init, true)
        if not a then
            return false
        end
        local before = a > 1 and text:byte(a - 1) or nil
        local okBefore = before == nil or not ((before >= 48 and before <= 57) or (before >= 65 and before <= 90)
            or (before >= 97 and before <= 122) or before >= 128)
        local okAfter = true
        if not after then
            local nxt = b < #text and text:byte(b + 1) or nil
            okAfter = nxt == nil or not ((nxt >= 48 and nxt <= 57) or (nxt >= 65 and nxt <= 90)
                or (nxt >= 97 and nxt <= 122) or nxt >= 128)
        end
        if okBefore and okAfter then
            return true
        end
        init = a + 1
    end
end

local function labelMap(roster)
    local map = {}
    for label, key in pairs(Tagger.LABEL_TO_KEY) do map[label] = key end
    for _, e in ipairs(roster) do
        if e.gang and e.gang ~= "" and e.gangKey and e.gangKey ~= "" then map[e.gang] = e.gangKey end
    end
    return map
end

local function packTags(gangs, names)
    return "|" .. table.concat(gangs, "|") .. "|", "|" .. table.concat(names, "|") .. "|"
end

-- roster: list of { name=, gangKey=, gang= (display label) }.
-- Returns gangs "|Key1|Key2|" and names "|Name1|Name2|" (delimited so redscript's StrContains is exact).
-- For RAW text a nemesis is found by `Name "` (messages always print `Name "Title"`), so a handle that also
-- appears as a title word (e.g. "Scrap") can't be mistaken for the nemesis.
function Tagger.tag(text, roster)
    local names, nameSeen = {}, {}
    local gangs, gangSeen = {}, {}
    local labels = labelMap(roster)
    for _, e in ipairs(roster) do
        local name = e.name
        if name and name ~= "" and not nameSeen[name] and containsWhole(text, name, ' "') then
            nameSeen[name] = true
            names[#names + 1] = name
            if e.gangKey and e.gangKey ~= "" and not gangSeen[e.gangKey] then
                gangSeen[e.gangKey] = true
                gangs[#gangs + 1] = e.gangKey
            end
        end
    end
    local sorted = {}
    for label in pairs(labels) do sorted[#sorted + 1] = label end
    table.sort(sorted)
    for _, label in ipairs(sorted) do
        local key = labels[label]
        if not gangSeen[key] and containsWhole(text, label) then
            gangSeen[key] = true
            gangs[#gangs + 1] = key
        end
    end
    return packTags(gangs, names)
end

-- the same tags, straight from a record's typed arguments (no text scanning)
function Tagger.tagArgs(args, roster)
    local names, nameSeen = {}, {}
    local gangs, gangSeen = {}, {}
    local labels = labelMap(roster)
    local gangOfName = {}
    for _, e in ipairs(roster) do
        if e.name and e.gangKey then gangOfName[e.name] = e.gangKey end
    end
    local function addGang(key)
        if key and key ~= "" and not gangSeen[key] then
            gangSeen[key] = true
            gangs[#gangs + 1] = key
        end
    end
    for _, a in ipairs(args) do
        if a.t == "N" then
            if a.name ~= "" and not nameSeen[a.name] then
                nameSeen[a.name] = true
                names[#names + 1] = a.name
            end
            addGang(gangOfName[a.name])
            if a.gang ~= "" then addGang(labels[a.gang]) end
        elseif a.t == "G" then
            addGang(labels[a.label])
        end
    end
    return packTags(gangs, names)
end

-- Tags for one recorded event. Most events name their nemeses and gangs as typed arguments, but a boss
-- weapon ("You took <Boss "Title">'s <Weapon>.") carries the boss only inside the weapon's name, so that
-- one is tagged by scanning its text.
function Tagger.tagEvent(key, args, text, roster)
    local info = key and Tagger.KEY_INFO[key]
    if info and info.kind == "WEAPON" then
        return Tagger.tag(text, roster)
    end
    return Tagger.tagArgs(args, roster)
end

-- a cheap fingerprint of the roster so we only re-tag when it changed
function Tagger.rosterSignature(roster)
    local parts = { tostring(#roster) }
    for _, e in ipairs(roster) do
        parts[#parts + 1] = (e.name or "") .. "~" .. (e.gangKey or "")
    end
    return table.concat(parts, ";")
end

return Tagger
