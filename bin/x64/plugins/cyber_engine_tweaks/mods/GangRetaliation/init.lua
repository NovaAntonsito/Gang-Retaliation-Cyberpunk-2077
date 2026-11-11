local Store = require("modules/store")
local Names = require("modules/names")
local Ambush = require("modules/ambush")
local Traits = require("modules/traits")
local Hierarchy = require("modules/hierarchy")
local War = require("modules/war")
local Escorts = require("modules/escorts")
local Vehicles = require("modules/vehicles")

local GR = {
    dev = true, -- GR_DEV_FLAG
    overlayOpen = false,
    campaignId = 0,
    sessionToken = 0,
    saveTimer = 0,
    lastAction = "",

    messages = {},
    messageTimer = 0,

    pendingAmbush = nil,

    gigRolled = {},

    encounterId = nil,

    dayOffset = 0,
}

local function getSystem(name)
    local container = Game.GetScriptableSystemsContainer()
    if not container then return nil end
    return container:Get(name)
end

local function text(key, fallback)
    local sys = getSystem("GangRetaliation.GRSystem")
    if sys then
        local value = sys:GetText(key)
        if value and value ~= "" and value ~= key then return value end
    end
    return fallback or key
end

local function lang()
    return text("GR-Lang", "en")
end

local function getSettings()
    return getSystem("GangRetaliation.GRSettings")
end

local function getDetection()
    return getSystem("GangRetaliation.GRDetection")
end

local function debugLog(msg)
    local settings = getSettings()
    if settings and settings.debugLog then
        print("[GangRetaliation] " .. msg)
    end
end

local function notify(msg)
    table.insert(GR.messages, msg)
    print("[GangRetaliation] " .. msg)
end

local function flushMessages(delta)
    GR.messageTimer = GR.messageTimer - delta
    if GR.messageTimer > 0 or #GR.messages == 0 then return end
    local det = getDetection()
    if not det then return end
    if not det:CanNotify() then
        GR.messageTimer = 1.0
        return
    end
    det:Notify(table.remove(GR.messages, 1))
    GR.messageTimer = 3.5
end

local function traitName(key)
    return text("GR-Trait-" .. key, key)
end

local function rankLabel(rank, gender)
    if rank == 3 and gender == "Female" then return text("GR-RankBossF", "Boss") end
    if rank == 3 then return text("GR-RankBoss", "Boss") end
    if rank == 2 then return text("GR-RankLieutenant", "Lieutenant") end
    return text("GR-RankSoldier", "Soldier")
end

local function getSpawner()
    return getSystem("GangRetaliation.GRSpawner")
end

local function findNemesis(id)
    for _, n in ipairs(Store.campaign(GR.campaignId).nemeses) do
        if n.id == id then return n end
    end
    return nil
end

local function labelOf(n)
    return Names.display(n, lang()) .. " (" .. Names.gangLabel(n.gang) .. ")"
end

local function fullName(n)
    if (n.rank or 1) <= 1 then return Names.display(n, lang()) end
    return rankLabel(n.rank, n.gender) .. " " .. Names.display(n, lang())
end

local function gameDay()
    local spawner = getSystem("GangRetaliation.GRSpawner")
    return (spawner and spawner:GetGameDay() or 0) + GR.dayOffset
end

local function pushTraits(n)
    if Traits.ensure(n) then Store.dirty = true end
    local sys = getSystem("GangRetaliation.GRTraits")
    if sys then sys:SetTraits(n.id, Traits.csv(n)) end
end

local function updateNemesis(evt)
    local n = findNemesis(evt.nemesisId)
    if not n then return end
    n.encounters = (n.encounters or 1) + 1
    n.health = evt.health
    n.pos = { x = evt.posX, y = evt.posY, z = evt.posZ }

    n.escapes = (n.escapes or 0) + 1
    n.escapedDay = gameDay()
    Hierarchy.addRenown(n, 2)
    Traits.ensure(n)
    Traits.grow(n)
    notify(string.format(text("GR-MsgAgainEscaped", "%s escaped you again. They are getting stronger."), labelOf(n)))
    Store.dirty = true
    Store.save()
end

local function createNemesis(evt)
    if evt.nemesisId and evt.nemesisId > 0 then
        updateNemesis(evt)
        return
    end

    local gang = evt.gang
    local settings = getSettings()
    local maxPerGang = settings and settings.maxPerGang or 8

    if Store.countAlive(GR.campaignId, gang) >= maxPerGang then
        debugLog(string.format(text("GR-MsgGangFull", "%s already has its maximum of Nemeses."), Names.gangLabel(gang)))
        return
    end

    local taken = {}
    for _, other in ipairs(Store.campaign(GR.campaignId).nemeses) do
        if other.gang == gang and other.name then taken[other.name] = true end
    end
    local name, titleEn, titleEs = Names.generate(gang, evt.gender, evt.origin, taken)
    local nemesis = Store.addNemesis(GR.campaignId, {
        name = name,
        titleEn = titleEn,
        titleEs = titleEs,
        gang = gang,
        rank = 1,
        origin = evt.origin,
        status = "alive",
        encounters = 1,
        recordID = evt.recordID,
        appearance = evt.appearance,
        gender = evt.gender,
        health = evt.health,
        pos = { x = evt.posX, y = evt.posY, z = evt.posZ },
        created = os.time(),
        escapedDay = gameDay(),
        traits = {},
    })
    Traits.ensure(nemesis)
    Store.save()

    local label = Names.display(nemesis, lang()) .. " (" .. Names.gangLabel(gang) .. ")"
    if evt.origin == "fled" then
        notify(string.format(text("GR-MsgFled", "%s ran away. They will come back for you."), label))
    else
        notify(string.format(text("GR-MsgEscaped", "%s got away wounded. They will remember you."), label))
    end
end

local function processPending()
    local det = getDetection()
    if not det then return end
    local count = det:GetPendingCount()
    if count == 0 then return end

    for i = 0, count - 1 do
        local evt = det:GetPending(i)
        if evt then
            local ok, err = pcall(createNemesis, evt)
            if not ok then print("[GangRetaliation] Error creando Nemesis: " .. tostring(err)) end
        end
    end
    det:ClearPending()
end

local function processDeaths()
    local spawner = getSpawner()
    if not spawner then return end
    local count = spawner:GetDeathCount()
    if count == 0 then return end

    for i = 0, count - 1 do
        local n = findNemesis(spawner:GetDeath(i))
        if n and n.status ~= "dead" then
            local kind = spawner:GetDeathKind(i)
            local cause = spawner:GetDeathCause(i)
            n.status = "dead"
            n.diedAt = os.time()
            n.deathDay = gameDay()
            n.diedByGang = nil
            if string.sub(cause, 1, 5) == "gang:" then
                n.diedBy, n.diedByGang = "gang", string.sub(cause, 6)
            else
                n.diedBy = cause
            end
            Store.dirty = true

            local settings = getSettings()
            local returns = Hierarchy.resolveDeath(n, kind, {
                day = gameDay(), random = math.random,
                settings = { returnChancePercent = settings and settings.returnChancePercent or 40 },
            })
            debugLog(string.format("%s muere (%s, %s): %s", labelOf(n), kind, cause, returns and ("vuelve el dia " .. string.format("%.1f", n.returnDay)) or "no vuelve"))
            if n.diedBy == "police" then
                notify(string.format(text("GR-MsgNemesisDeadPolice", "Rumor: the NCPD took down %s."), labelOf(n)))
            elseif n.diedBy == "gang" then
                notify(string.format(text("GR-MsgNemesisDeadGang", "Rumor: %s was taken down by the %s."), labelOf(n), Names.gangLabel(n.diedByGang)))
            elseif n.diedBy == "other" then
                notify(string.format(text("GR-MsgNemesisDeadOther", "%s is dead. Nobody knows who did it."), labelOf(n)))
            elseif kind == "confirmed" then
                notify(string.format(text("GR-MsgNemesisConfirmed", "%s is dead. For good this time."), labelOf(n)))
            else
                notify(string.format(text("GR-MsgNemesisDead", "%s is dead... for now."), labelOf(n)))
            end
            Hierarchy.onDeath(Store.ensureCampaign(GR.campaignId), n, gameDay())
            if (n.rank or 1) == Hierarchy.BOSS then
                notify(string.format(text("GR-MsgBossDown", "The %s lost their boss. Someone will want the throne..."), Names.gangLabel(n.gang)))
            end
        end
    end
    spawner:ClearDeaths()
    Store.save()
end

local function launchAmbush(n, forceVehicle)
    local settings = getSettings()
    local spawner = getSpawner()
    if not settings or not spawner then return "no systems" end

    local speaker = fullName(n)
    local line = text(Ambush.lineKey(n), "...")
    local escorts = Ambush.escorts(n, settings.ambushMaxEscorts)
    pushTraits(n)
    -- A veces llegan en un vehiculo de la banda; si no hay sitio para el coche, a pie.
    local useVehicle = forceVehicle or math.random(100) <= Vehicles.chancePercent
    local vehicle = useVehicle and Vehicles.pick(n.gang) or nil
    local started = vehicle and spawner:StartVehicleAmbush(n.id, n.recordID, n.appearance or "", escorts, line, speaker, vehicle)
    if started then
        print(string.format("[GangRetaliation] Transporte #%d (%s): vehiculo %s", n.id, n.gang, vehicle))
    else
        if not spawner:StartAmbush(n.id, n.recordID, n.appearance or "", escorts, line, speaker) then
            print(string.format("[GangRetaliation] Transporte #%d (%s): ninguno, no se pudo generar (bloqueo: %s)",
                n.id, n.gang, tostring(spawner:GetAmbushBlocker())))
            return "spawn failed"
        end
        print(string.format("[GangRetaliation] Transporte #%d (%s): a pie (%s)", n.id, n.gang,
            vehicle and ("fallo el vehiculo " .. vehicle) or "tirada de vehiculo fallida"))
    end

    n.ambushes = (n.ambushes or 0) + 1
    GR.encounterId = n.id
    Store.dirty = true
    notify(string.format(text("GR-MsgAmbush", "Ambush! %s found you."), labelOf(n)))
    return "ambush #" .. n.id
end

local function tryAmbush(force, warnSeconds, forceVehicle)
    local settings = getSettings()
    local spawner = getSpawner()
    if not settings or not spawner then return "no systems" end
    if not settings.enabled or (not force and not settings.ambushEnabled) then return "disabled" end
    if GR.pendingAmbush then return "sms sent, waiting" end

    local campaign = Store.campaign(GR.campaignId)
    if not force then
        local waited = os.time() - (campaign.lastAmbush or 0)
        if waited < settings.ambushCooldownMinutes * 60 then return "cooldown" end
        -- Rencor de They Will Remember y rango de Drug Dealer: x1.0 a x2.0.
        local heat = spawner:GetHeatFactor()
        if math.random(100) > settings.ambushChancePercent * heat then return "roll failed" end
        local safe, distance = Ambush.nearHome(campaign)
        if safe then return string.format("near home (%.0f m)", distance) end
    end

    local blocker = spawner:GetAmbushBlocker()
    if blocker ~= "" then return "blocked: " .. blocker end

    local warSys = getSystem("GangRetaliation.GRWar")
    local districtGangs = (warSys and War.districtGangs(campaign, warSys:GetCurrentDistrict()))
        or Ambush.parseGangs(spawner:GetDistrictGangs())
    -- Los que acaban de escapar esperan (Ambush.escapeRestDays); una emboscada forzada no espera.
    local today = gameDay()
    local n, resting = Ambush.pick(campaign.nemeses, districtGangs, not force, not force and today or nil)
    for _, r in ipairs(resting) do
        debugLog(string.format("Emboscada: %s descartado, escapo hace %.2f dias (espera %s)", labelOf(r), today - r.escapedDay, tostring(Ambush.escapeRestDays)))
    end
    if not n then return #resting > 0 and "all resting after escape" or "no living Nemesis" end

    Store.ensureCampaign(GR.campaignId).lastAmbush = os.time()
    Store.dirty = true

    local delay = warnSeconds or settings.ambushSmsSeconds or 0
    local phone = getSystem("GangRetaliation.GRPhone")
    if delay <= 0 or not phone or not phone:SendThreat(Names.display(n, lang()), text(Ambush.smsKey(n), "...")) then
        return launchAmbush(n, forceVehicle)
    end
    local now = spawner:GetTime()

    GR.pendingAmbush = { id = n.id, due = now + delay, giveUp = now + delay + 1800, vehicle = forceVehicle }
    return "sms #" .. n.id .. ", ambush in " .. delay .. " s"
end

local function updatePendingAmbush()
    local pending = GR.pendingAmbush
    local spawner = getSpawner()
    if not pending or not spawner then return end

    local now = spawner:GetTime()
    if now < pending.due then return end

    local n = findNemesis(pending.id)
    if not n or n.status == "dead" then
        GR.pendingAmbush = nil
        return
    end
    local blocker = spawner:GetAmbushBlocker()

    local result = blocker == "" and launchAmbush(n, pending.vehicle) or ("blocked: " .. blocker)
    if result ~= "spawn failed" and blocker == "" then
        GR.pendingAmbush = nil
        debugLog("Emboscada anunciada: " .. result)
    elseif now > pending.giveUp then
        GR.pendingAmbush = nil
        debugLog("Emboscada anunciada cancelada: " .. blocker)
    else
        -- V bajo techo o sin sitio: reintentar cada 5 s hasta que salga a la calle.
        pending.due = now + 5
    end
end

-- Noches dormidas en una cama propia (GRHomes): 2 noches en el mismo sitio lo vuelven casa, sin aviso.
local function updateHomes()
    local homes = getSystem("GangRetaliation.GRHomes")
    if not homes or GR.campaignId == 0 then return end
    local count = homes:GetSleepCount()
    if count == 0 then return end
    local campaign = Store.ensureCampaign(GR.campaignId)
    for i = 0, count - 1 do
        local x, y = homes:GetSleepX(i), homes:GetSleepY(i)
        if Ambush.recordSleep(campaign, x, y, homes:GetSleepDay(i)) then
            debugLog(string.format("Nueva casa en %.1f, %.1f", x, y))
        end
    end
    homes:ClearSleeps()
    Store.dirty = true
end

local function drawHomes()
    if GR.campaignId == 0 then return end
    local campaign = Store.campaign(GR.campaignId)
    local player = Game.GetPlayer()
    ImGui.Separator()
    ImGui.Text(string.format("%s: %d", text("GR-UiHomes", "Safe homes (no ambushes nearby)"), #Ambush.allHomes(campaign)))
    if player then
        local _, distance = Ambush.homeFactor(player:GetWorldPosition(), campaign)
        ImGui.TextDisabled(string.format("%.0f m", distance))
    end
    if player and #(campaign.homes or {}) > 0 and ImGui.Button(text("GR-UiRemoveHome", "Remove nearest home")) then
        local removed = Ambush.removeNearestHome(Store.ensureCampaign(GR.campaignId), player:GetWorldPosition())
        if removed then
            Store.dirty = true
            debugLog(string.format("Casa quitada (a %.0f m)", removed))
        end
    end
end

local function tryGig(force)
    local settings = getSettings()
    local spawner = getSpawner()
    local det = getDetection()
    if not settings or not spawner or not det then return "no systems" end
    if not settings.enabled or (not force and not settings.gigEnabled) then return nil end

    local gigId = spawner:GetActiveGigId()
    if gigId == "" and not force then return nil end
    local blocker = spawner:GetReinforcementBlocker()
    if blocker ~= "" then return force and ("blocked: " .. blocker) or nil end

    local campaign = Store.campaign(GR.campaignId)
    for gang in pairs(Ambush.parseGangs(det:GetFightGangs())) do
        local key = gigId .. "/" .. gang
        if force or not GR.gigRolled[key] then
            GR.gigRolled[key] = true
            local n = Ambush.pickFromGang(campaign.nemeses, gang)
            local roll = math.random(100)
            if n and (force or roll <= settings.gigChancePercent) then
                local speaker = fullName(n)
                local line = text(Ambush.gigLineKey(n), "...")
                local escorts = Ambush.escorts(n, math.min(1, settings.ambushMaxEscorts))
                pushTraits(n)
                if not spawner:StartReinforcement(n.id, n.recordID, n.appearance or "", escorts, line, speaker) then
                    return "spawn failed"
                end
                n.gigs = (n.gigs or 0) + 1
                GR.encounterId = n.id
                Store.dirty = true
                notify(string.format(text("GR-MsgGig", "%s heard you were coming and brought backup!"), labelOf(n)))
                return "gig reinforcement #" .. n.id
            end
            debugLog(string.format("Gig %s / %s: %s", gigId, gang, n and ("tirada " .. roll .. " fallida") or "sin Nemesis vivo"))
        end
    end
    return force and "no Nemesis for this fight" or nil
end

-- Integraciones: un escuadron de venganza de They Will Remember o una mision de Drug Dealer contra una
-- banda con Nemesis vivo. Se tira una vez por escuadron (misma probabilidad que los gigs), cuando V ya
-- pelea; si el escuadron desaparece, se olvida y el proximo vuelve a tirar.
local function tryExternalSquad()
    local settings = getSettings()
    local spawner = getSpawner()
    if not settings or not spawner or not settings.enabled or not settings.gigEnabled then return nil end

    local squad = spawner:GetExternalSquad()
    if squad == "" then
        GR.externalRolled = {}
        return nil
    end
    GR.externalRolled = GR.externalRolled or {}
    if GR.externalRolled[squad] then return nil end
    if spawner:GetReinforcementBlocker() ~= "" then return nil end
    GR.externalRolled[squad] = true

    local source, gang = string.match(squad, "^(%a+)|(.+)$")
    local n = gang and Ambush.pickFromGang(Store.campaign(GR.campaignId).nemeses, gang)
    local roll = math.random(100)
    if not n or roll > settings.gigChancePercent then
        return string.format("%s: %s", squad, n and ("tirada " .. roll .. " fallida") or "sin Nemesis vivo")
    end

    local line = text(Ambush.gigLineKey(n), "...")
    local escorts = Ambush.escorts(n, math.min(1, settings.ambushMaxEscorts))
    pushTraits(n)
    if not spawner:StartReinforcement(n.id, n.recordID, n.appearance or "", escorts, line, fullName(n)) then
        return squad .. ": spawn failed"
    end
    n.gigs = (n.gigs or 0) + 1
    GR.encounterId = n.id
    Store.dirty = true
    if source == "TWR" then
        notify(string.format(text("GR-MsgSquadTWR", "%s is leading the vengeance squad!"), labelOf(n)))
    else
        notify(string.format(text("GR-MsgSquadDD", "%s came with the crew hitting your business!"), labelOf(n)))
    end
    return squad .. ": Nemesis #" .. n.id
end

local function processAppearances()
    local spawner = getSpawner()
    if not spawner or spawner:GetAppearanceReportCount() == 0 then return end
    for i = 0, spawner:GetAppearanceReportCount() - 1 do
        local id, appearance = string.match(spawner:GetAppearanceReport(i) or "", "^(%d+):(.+)$")
        local n = id and findNemesis(tonumber(id))
        if n and (not n.appearance or n.appearance == "" or n.appearance == "random") and appearance ~= "None" then
            n.appearance = appearance
            Store.dirty = true
        end
    end
    spawner:ClearAppearanceReports()
end

local function checkEncounter()
    local spawner = getSpawner()
    if not GR.encounterId or not spawner or spawner:IsAmbushActive() then return end
    -- Al terminar la emboscada todavia puede estar yendose (sobrante): V aun puede matarlo.
    -- Sobrevive recien cuando se borra fuera de la vista. processDeaths corre antes que esto.
    if spawner:IsNemesisSpawned(GR.encounterId) then return end
    local n = findNemesis(GR.encounterId)
    GR.encounterId = nil
    if n and n.status ~= "dead" then
        Hierarchy.addRenown(n, 1)
        n.survived = (n.survived or 0) + 1
        Store.dirty = true
        debugLog(Names.display(n, lang()) .. " sobrevive al encuentro: renombre " .. n.renown)
    end
end

local function hierarchyEvent(kind, a, b)
    local gang = Names.gangLabel(a.gang)
    local nameA = Names.display(a, lang())
    local nameB = b and Names.display(b, lang()) or ""
    local rankA = rankLabel(a.rank, a.gender)
    if kind == "promoted" then
        notify(string.format(text("GR-MsgPromoted", "%s rose to %s of the %s."), nameA, rankA, gang))
    elseif kind == "returned" then
        notify(string.format(text("GR-MsgReturned", "%s is back from the dead, rebuilt with chrome. They are coming for you."), nameA .. " (" .. gang .. ")"))
        local phone = getSystem("GangRetaliation.GRPhone")
        if phone then
            phone:SendReturn(nameA, text("GR-SmsReturn-" .. math.random(3), "..."))
        end
    elseif kind == "recruited" then
        notify(string.format(text("GR-MsgRecruited", "New face in the %s: %s, %s."), gang, nameA, rankA))
    elseif kind == "feudKill" then
        notify(string.format(text("GR-MsgFeudKill", "Rumor: %s killed %s and is now %s of the %s."), nameA, nameB, rankA, gang))
    elseif kind == "feudDemote" then
        notify(string.format(text("GR-MsgFeudDemote", "Rumor: %s overthrew %s and is now %s of the %s."), nameA, nameB, rankA, gang))
    elseif kind == "feudFail" then
        notify(string.format(text("GR-MsgFeudFail", "Rumor: %s put %s in their place."), nameA, nameB))
    elseif kind == "policeKill" then
        notify(string.format(text("GR-MsgNemesisDeadPolice", "Rumor: the NCPD took down %s."), nameA .. " (" .. gang .. ")"))
    elseif kind == "policeArrest" then
        notify(string.format(text("GR-MsgPoliceArrest", "Rumor: the NCPD arrested %s. They will be out in a few days."), nameA .. " (" .. gang .. ")"))
    elseif kind == "policeEscape" then
        notify(string.format(text("GR-MsgPoliceEscape", "Rumor: %s shot their way out of an NCPD raid."), nameA .. " (" .. gang .. ")"))
    elseif kind == "released" then
        notify(string.format(text("GR-MsgReleased", "%s is back on the street."), nameA .. " (" .. gang .. ")"))
    elseif kind == "feudFailDead" then
        notify(string.format(text("GR-MsgFeudFailDead", "Rumor: %s challenged %s and paid with their life."), nameB, nameA))
    end
    Store.dirty = true
end

local function districtLabel(campaign, key)
    local d = campaign.war and campaign.war.districts[key]
    return d and d.label or key
end

local function warLine(kind, a, d, place)
    if kind == "warStart" then
        return string.format(text("GR-MsgWarStart", "Rumor: the %s are attacking the %s in %s."), Names.gangLabel(a), Names.gangLabel(d), place)
    elseif kind == "warWon" then
        return string.format(text("GR-MsgWarWon", "The %s took %s from the %s."), Names.gangLabel(a), place, Names.gangLabel(d))
    end
    return string.format(text("GR-MsgWarHeld", "The %s held %s against the %s."), Names.gangLabel(a), place, Names.gangLabel(d))
end

local function warEvent(kind, a, d, key)
    notify(warLine(kind, a, d, districtLabel(Store.campaign(GR.campaignId), key)))
    Store.dirty = true
end

local function warContext(campaign, settings)
    return {
        day = gameDay(),
        random = math.random,
        settings = { warChancePercent = settings.warChancePercent },
        gangs = Hierarchy.knownGangs(campaign),
        event = warEvent,
    }
end

local function updateWar(campaign, settings)
    local warSys = getSystem("GangRetaliation.GRWar")
    if not warSys then return end
    if GR.warInit ~= GR.campaignId then
        local list = warSys:GetAllDistricts()
        War.init(campaign, list, function(gang) return Names.gangLabels[gang] ~= nil end)
        GR.warInit = GR.campaignId
        print(string.format('[GangRetaliation] Territorio: %d distritos del juego, %d con bandas del mod',
            select(2, string.gsub(list, '[^;]+', '')), #((campaign.war or {}).order or {})))
        Store.dirty = true
    end
    War.update(campaign, warContext(campaign, settings))
end

local function groupRecords(gang, count)
    local list = Escorts[gang]
    if not list or #list == 0 then return nil end
    local ids = {}
    for i = 1, count do ids[i] = list[math.random(#list)] end
    return table.concat(ids, ",")
end

local function trySkirmish(force)
    local settings = getSettings()
    local warSys = getSystem("GangRetaliation.GRWar")
    if not settings or not warSys or not settings.enabled then return "no systems" end
    if not force and (settings.skirmishChancePercent or 0) <= 0 then return "disabled" end
    local blocker = warSys:GetBlocker()
    if blocker ~= "" then return "blocked: " .. blocker end
    local campaign = Store.campaign(GR.campaignId)
    local key = warSys:GetCurrentDistrict()
    local war = War.activeWarAt(campaign, key)
    local a, d = war and war.a, war and war.d
    if not war then
        if not force then return "no war here" end

        local gangs = Hierarchy.knownGangs(campaign)
        a, d = gangs[1], gangs[2]
        local district = campaign.war and campaign.war.districts[key]
        if district then
            local sorted = {}
            for gang in pairs(district.inf) do table.insert(sorted, gang) end
            table.sort(sorted, function(x, y) return district.inf[x] > district.inf[y] end)
            if sorted[2] then a, d = sorted[1], sorted[2] end
        end
    elseif not force then
        if os.time() - (GR.lastSkirmish or 0) < 300 then return "cooldown" end
        if math.random(100) > settings.skirmishChancePercent then return "roll failed" end
    end
    local ra, rd = groupRecords(a, 3), groupRecords(d, 3)
    if not ra or not rd then return "no records for " .. tostring(a) .. "/" .. tostring(d) end
    if not warSys:Start(ra, rd) then return "spawn failed: " .. tostring(warSys:GetLastError()) end
    GR.lastSkirmish = os.time()
    notify(string.format(text("GR-MsgSkirmish", "The %s and the %s are shooting it out nearby!"), Names.gangLabel(a), Names.gangLabel(d)))
    return "skirmish " .. a .. " vs " .. d
end

local function tryRaid(force)
    local settings = getSettings()
    local spawner = getSpawner()
    if not settings or not spawner or not settings.enabled then return "no systems" end
    if not force then
        if (settings.raidChancePercent or 0) <= 0 then return "disabled" end
        if os.time() - (GR.lastRaid or 0) < 900 then return "cooldown" end
        if math.random(100) > settings.raidChancePercent then return "roll failed" end
        local safe, distance = Ambush.nearHome(Store.campaign(GR.campaignId))
        if safe then return string.format("near home (%.0f m)", distance) end
    end
    local blocker = spawner:GetAmbushBlocker()
    if blocker ~= "" then return "blocked: " .. blocker end

    local campaign = Store.campaign(GR.campaignId)
    local warSys = getSystem("GangRetaliation.GRWar")
    local districtGangs = (warSys and War.districtGangs(campaign, warSys:GetCurrentDistrict()))
        or Ambush.parseGangs(spawner:GetDistrictGangs())
    local n = Ambush.pick(campaign.nemeses, districtGangs, false)
    if not n then return "no living Nemesis" end

    pushTraits(n)
    if not spawner:StartRaid(n.id, n.recordID, n.appearance or "", Ambush.escorts(n, settings.ambushMaxEscorts), fullName(n), Ambush.police(n)) then
        return "spawn failed"
    end
    GR.lastRaid = os.time()
    GR.raidId = n.id
    notify(string.format(text("GR-MsgRaid", "The NCPD is raiding %s nearby!"), labelOf(n)))
    return "raid #" .. n.id
end

local raidBounty = { 1000, 2500, 5000 }

local function checkRaid()
    local spawner = getSpawner()
    if not GR.raidId or not spawner or spawner:IsRaidActive() then return end
    local n = findNemesis(GR.raidId)
    GR.raidId = nil
    local outcome = spawner:TakeRaidOutcome()
    if outcome == "helpedPolice" or outcome == "helpedPoliceHurtCops" then
        local bounty = raidBounty[(n and n.rank) or 1] or raidBounty[1]
        local deducted = outcome == "helpedPoliceHurtCops"
        local amount = deducted and math.floor(bounty / 2) or bounty
        if spawner:GiveMoney(amount) then
            local msg
            if deducted then
                msg = string.format(text("GR-SmsRaidBountyCut", "Thanks for the assist, citizen. %d eurodollars were deducted for our wounded officers' medical bills. %d eurodollars have been wired to your account."), bounty - amount, amount)
            else
                msg = string.format(text("GR-SmsRaidBounty", "Thanks for the assist, citizen. %d eurodollars have been wired to your account."), amount)
            end
            local phone = getSystem("GangRetaliation.GRPhone")
            if not phone or not phone:SendBounty(deducted, msg) then notify(msg) end
            debugLog("Redada: recompensa NCPD " .. amount .. (deducted and " (con descuento)" or ""))
        end
    end
    if n and n.status ~= "dead" then
        Hierarchy.addRenown(n, 2)
        Store.dirty = true
        notify(string.format(text("GR-MsgPoliceEscape", "Rumor: %s shot their way out of an NCPD raid."), labelOf(n)))
    end
end

-- Guarida (prototipo, una por campana): Lua solo pasa quien vive ahi; aparecer/desaparecer va en GRStronghold.
-- Viven ahi todos los Nemesis vivos de la banda (Jefe primero). Entre 10 y 20 en total: cada Teniente
-- vivo suma 3 guardias, asi que matarlos antes debilita la guarida del Jefe.
local STRONGHOLD_MAX = 20
local function pushStronghold()
    local sys = getSystem("GangRetaliation.GRStronghold")
    if not sys then return end
    local site = Store.campaign(GR.campaignId).stronghold
    local key = site and string.format("%d:%s:%.1f:%.1f", GR.campaignId, site.gang, site.x, site.y) or ""
    if key ~= GR.siteKey then
        GR.siteKey = key
        if site then sys:SetSite(site.gang, site.x, site.y, site.z) else sys:ClearSite() end
    end
    if not site then return end

    local members = {}
    for _, n in ipairs(Store.campaign(GR.campaignId).nemeses) do
        if n.gang == site.gang and n.status ~= "dead" and not n.jailedUntil and n.recordID then
            table.insert(members, n)
        end
    end
    table.sort(members, function(a, b)
        if (a.rank or 1) ~= (b.rank or 1) then return (a.rank or 1) > (b.rank or 1) end
        return (a.renown or 0) > (b.renown or 0)
    end)
    sys:ClearMembers()
    local lieutenants, boss = 0, false
    for i, n in ipairs(members) do
        if i > STRONGHOLD_MAX then break end
        pushTraits(n)
        sys:AddMember(n.id, n.recordID, n.appearance or "", fullName(n))
        if n.rank == Hierarchy.LIEUTENANT then lieutenants = lieutenants + 1 end
        if n.rank == Hierarchy.BOSS then boss = true end
    end
    local guards = math.min(8 + 3 * lieutenants + (boss and 2 or 0), STRONGHOLD_MAX - math.min(#members, STRONGHOLD_MAX))
    sys:SetGuards(guards > 0 and groupRecords(site.gang, guards) or "")
end

local function strongholdEvents()
    local sys = getSystem("GangRetaliation.GRStronghold")
    if not sys then return end
    local site = Store.campaign(GR.campaignId).stronghold
    local gang = site and Names.gangLabel(site.gang) or "?"
    local ev = sys:TakeEvent()
    while ev ~= "" do
        -- Llegar a la guarida no se avisa (discreto): V la descubre al ver a los guardias.
        if ev == "cleared" then
            notify(string.format(text("GR-MsgStrongholdCleared", "The %s stronghold has fallen."), gang))
        end
        ev = sys:TakeEvent()
    end
end

-- Dev: barrio de V y bandas de ese barrio para el panel de sitios (como mucho una consulta por segundo).
local function siteContext(campaign)
    local now = os.clock()
    if GR.siteCtx and now - GR.siteCtx.t < 1 then return GR.siteCtx end
    local warSys = getSystem("GangRetaliation.GRWar")
    local spawner = getSpawner()
    local district = warSys and warSys:GetCurrentDistrict() or ""
    local set = (warSys and War.districtGangs(campaign, district))
        or Ambush.parseGangs(spawner and spawner:GetDistrictGangs() or "")
    local list = {}
    for gang in pairs(set) do table.insert(list, gang) end
    table.sort(list)
    GR.siteCtx = { t = now, district = district, label = districtLabel(campaign, district), gangs = list }
    return GR.siteCtx
end

local function updateHierarchy(feudChance, policeChance)
    local settings = getSettings()
    local spawner = getSpawner()
    if not settings or not spawner or not settings.enabled then return end

    local ctx = {
        day = gameDay(),
        settings = {
            vacancyDays = settings.vacancyDays,
            feudChancePercent = feudChance or settings.feudChancePercent,
            policeChancePercent = policeChance or settings.policeChancePercent,
            maxPerGang = settings.maxPerGang,
            returnChancePercent = settings.returnChancePercent,
        },
        random = math.random,
        isSpawned = function(id) return spawner:IsNemesisSpawned(id) end,
        addNemesis = function(data) return Store.addNemesis(GR.campaignId, data) end,
        event = hierarchyEvent,
    }
    local campaign = Store.ensureCampaign(GR.campaignId)
    if Hierarchy.seed(campaign, ctx) then
        debugLog("Campana nueva: cupulas de las bandas creadas (" .. #campaign.nemeses .. " Nemesis)")
        Store.save()
    end
    Hierarchy.update(campaign, ctx)
    updateWar(campaign, settings)
end

local function menuTraits(n)
    local lines = {}
    for _, t in ipairs(n.traits or {}) do
        if t.revealed then
            local full = traitName(t.key)
            local sign = Traits.isWeakness(t.key) and "-" or "+"
            table.insert(lines, sign .. "|" .. text("GR-TraitShort-" .. t.key, full) .. "|" .. full)
        else
            table.insert(lines, "?|???|" .. text("GR-MenuScanHint", "??? - scan them to find out"))
        end
    end
    return table.concat(lines, "\n")
end

local function renownHint(n)
    local rank = n.rank or 1
    if rank >= Hierarchy.BOSS then
        return text("GR-MenuRenownTop", "At the top. They only fall if you kill them or someone overthrows them.")
    end
    local need = Hierarchy.fastRenown[rank + 1] - (n.renown or 0)
    local nextRank = rankLabel(rank + 1, n.gender)
    if need <= 0 then
        return string.format(text("GR-MenuRenownReady", "Ready to become %s as soon as a spot opens."), nextRank)
    end
    return string.format(text("GR-MenuRenownNeed", "%d more for a fast promotion to %s."), need, nextRank)
end

local function vacancyNote(campaign, gang, rank)
    local state = campaign.hierarchy and campaign.hierarchy[gang]
    local since = state and state.vacant and state.vacant[tostring(rank)]
    local settings = getSettings()
    if not since or not settings then return "" end
    local left = settings.vacancyDays - (gameDay() - since)
    if left <= 0 then return text("GR-MenuVacantSoon", "Being filled soon") end
    return string.format(text("GR-MenuVacantIn", "Filled in %.1f days"), left)
end

local function pushTerritory(sys, campaign)
    local w = campaign.war
    if not w or not w.order then return end
    local today = gameDay()
    for _, key in ipairs(w.order) do
        local district = w.districts[key]
        local gangs = {}
        for gang in pairs(district.inf) do table.insert(gangs, gang) end
        table.sort(gangs, function(x, y) return district.inf[x] > district.inf[y] end)
        local parts = {}
        for _, gang in ipairs(gangs) do
            table.insert(parts, gang .. "|" .. Names.gangLabel(gang) .. "|" .. tostring(district.inf[gang]))
        end
        local war = War.activeWarAt(campaign, key)
        local warText = ""
        if war then
            warText = table.concat({ war.a, war.d, War.strength(campaign, war.a, today), War.strength(campaign, war.d, today),
                math.floor(today) - war.start + 1, war.finish - war.start + 1 }, "|")
        end
        sys:AddDistrict(key, district.label or key, district.region or "", War.owner(district), table.concat(parts, ","), warText)
    end
    local ranking = {}
    for _, gang in ipairs(Hierarchy.knownGangs(campaign)) do
        table.insert(ranking, { gang = gang, value = War.strength(campaign, gang, today) })
    end
    table.sort(ranking, function(x, y) return x.value > y.value end)
    for _, r in ipairs(ranking) do
        local losses = War.recentLosses(campaign, r.gang, today)
        local note = ""
        if losses > 0 then
            note = string.format(text("GR-MenuWeakNote", "-%d: V killed %d Nemeses"), losses * War.weakPenalty, losses)
        end
        sys:AddGangStrength(r.gang, Names.gangLabel(r.gang), r.value, note)
    end
    for _, m in ipairs(w.rumors or {}) do
        sys:AddRumor(string.format(text("GR-MenuDay", "DAY %d"), m.day), warLine(m.kind, m.a, m.d, districtLabel(campaign, m.district)))
    end
end

local function pushMenu()
    local sys = getSystem("GangRetaliation.GRMenuData")
    if not sys then return end
    sys:Clear()

    local campaign = Store.campaign(GR.campaignId)
    local list = {}
    for _, n in ipairs(campaign.nemeses) do
        if n.gang then table.insert(list, n) end
    end
    table.sort(list, function(a, b)
        if a.gang ~= b.gang then return Names.gangLabel(a.gang) < Names.gangLabel(b.gang) end
        return (a.renown or 0) > (b.renown or 0)
    end)

    local l = lang()
    for _, n in ipairs(list) do
        local cause = ""
        if n.status == "dead" then
            if n.diedBy == "feud" then
                cause = text("GR-MenuDiedFeud", "Killed by their own gang")
            elseif n.diedBy == "police" then
                cause = text("GR-MenuDiedPolice", "Killed by the NCPD")
            elseif n.diedBy == "gang" then
                cause = string.format(text("GR-MenuDiedGang", "Killed by the %s"), Names.gangLabel(n.diedByGang))
            elseif n.diedBy == "other" then
                cause = text("GR-MenuDiedOther", "Died in unclear circumstances")
            else
                cause = text("GR-MenuDiedV", "Killed by V")
            end
        end
        local title = (l == "es") and n.titleEs or n.titleEn

        local escapes = (n.escapes or 0) + ((n.origin == "escaped" or n.origin == "fled") and 1 or 0)
        -- Maximo 8 argumentos por llamada a redscript: con mas, el juego crashea al cargar.
        sys:Add(n.gang, Names.gangLabel(n.gang), n.rank or 1, n.status == "dead", n.name or "?", title or "",
            Ambush.hasMetV(n), n.renown or 0)
        sys:AddDetail(menuTraits(n), renownHint(n), text("GR-Origin-" .. (n.origin or "escaped"), n.origin or ""), cause)
        sys:AddStats(n.encounters or 1, escapes, n.ambushes or 0, n.gigs or 0)
    end
    for _, gang in ipairs(Hierarchy.knownGangs(campaign)) do
        sys:SetVacancy(gang, vacancyNote(campaign, gang, 3), vacancyNote(campaign, gang, 2))
    end
    pushTerritory(sys, campaign)
end

local function processReveals()
    local sys = getSystem("GangRetaliation.GRTraits")
    if not sys then return end
    local count = sys:GetRevealCount()
    if count == 0 then return end

    for i = 0, count - 1 do
        local id, what = string.match(sys:GetReveal(i) or "", "^(%d+):(.+)$")
        local n = id and findNemesis(tonumber(id))
        if n then
            if what == "scan" then
                if Traits.revealAll(n) then
                    local none = text("GR-UiNone", "none")
                    local strong = Traits.list(n, traitName, false, true)
                    local weak = Traits.list(n, traitName, true, true)
                    notify(string.format(text("GR-MsgScan", "%s - Strengths: %s. Weaknesses: %s."), Names.display(n, lang()), strong ~= "" and strong or none, weak ~= "" and weak or none))
                end
            elseif Traits.reveal(n, what) then
                local key = Traits.isWeakness(what) and "GR-MsgTraitWeak" or "GR-MsgTraitStrong"
                local fallback = Traits.isWeakness(what) and "Weakness found - %s: %s" or "Strength found - %s: %s"
                notify(string.format(text(key, fallback), Names.display(n, lang()), traitName(what)))
            end
            Store.dirty = true
        end
    end
    sys:ClearReveals()
end

local function refreshCampaign()
    if not Game.GetPlayer() then
        GR.campaignId = 0
        return
    end
    local sys = getSystem("GangRetaliation.GRSystem")
    if not sys then return end

    if not sys:IsInGame() then
        GR.campaignId = 0
        return
    end

    local id = sys:GetCampaignId()
    if id == 0 then
        sys:EnsureCampaignId()
        id = sys:GetCampaignId()
    end
    local token = sys:GetSessionToken()
    if id ~= 0 and (id ~= GR.campaignId or token ~= GR.sessionToken) then
        GR.campaignId = id
        GR.sessionToken = token
        GR.pendingAmbush = nil
        GR.gigRolled = {}
        GR.encounterId = nil
        debugLog("Campana activa: " .. tostring(id))

        -- En la pantalla de carga el juego aun no esta listo: no tocar nada hasta que pase.
        GR.warmup = 15

        GR.hierarchyNow = true
    end
end

registerForEvent("onInit", function()
    math.randomseed(os.time())
    Store.load()

    print("[GangRetaliation] CET cargado")
end)

registerForEvent("onShutdown", function()
    if Store.dirty then Store.save() end
end)

-- Dev: medidor por seccion. os.clock tiene ~1 ms de resolucion en Windows: sirve para promedios de
-- muchas llamadas y para ver picos, no para una llamada sola. Las llamadas a redscript cuentan dentro.
GR.prof = { cur = {}, last = {}, window = 0, counts = "", state = "" }
local function profAdd(sections, name, ms)
    local s = sections[name]
    if not s then
        s = { calls = 0, total = 0, max = 0 }
        sections[name] = s
    end
    s.calls, s.total, s.max = s.calls + 1, s.total + ms, math.max(s.max, ms)
end

local function prof(name, fn, ...)
    if not GR.dev then return fn(...) end
    local t0 = os.clock()
    local a, b = fn(...)
    local ms = (os.clock() - t0) * 1000
    profAdd(GR.prof.cur, name, ms)
    if GR.bench and GR.bench.measuring then profAdd(GR.bench.sections, name, ms) end
    return a, b
end

local function update(delta)
    -- Cada llamada a redscript cuesta: todo el sondeo va en un tick de 1 s, no en cada frame.
    GR.fleeTimer = (GR.fleeTimer or 0) + delta
    local tick = GR.fleeTimer >= 1
    if tick then
        GR.fleeTimer = 0
        prof("refreshCampaign", refreshCampaign)
    end
    if GR.campaignId == 0 then return end
    if (GR.warmup or 0) > 0 then
        GR.warmup = GR.warmup - delta
        return
    end
    if GR.hierarchyNow then
        GR.hierarchyNow = false
        local ok, err = prof("updateHierarchy", pcall, updateHierarchy)
        if not ok then print("[GangRetaliation] Error en jerarquia: " .. tostring(err)) end
    end

    if tick then
        prof("processPending", processPending)
        prof("processDeaths", processDeaths)
        prof("checkEncounter", checkEncounter)
        prof("checkRaid", checkRaid)
        prof("processAppearances", processAppearances)
        prof("processReveals", processReveals)

        local det = getDetection()
        if det then prof("Detection:UpdateFleeing", function() det:UpdateFleeing() end) end
        local speech = getSystem("GangRetaliation.GRSpeech")
        if speech then prof("Speech:Tick", function() speech:Tick() end) end
        local spawner = getSpawner()
        if spawner then prof("Spawner:Tick", function() spawner:Tick() end) end
        local warSys = getSystem("GangRetaliation.GRWar")
        if warSys then prof("War:Tick", function() warSys:Tick() end) end
        if Store.version ~= GR.strongholdVersion or GR.campaignId ~= GR.strongholdCampaign then
            GR.strongholdVersion = Store.version
            GR.strongholdCampaign = GR.campaignId
            local okS, errS = prof("pushStronghold", pcall, pushStronghold)
            if not okS then print("[GangRetaliation] Error en guarida: " .. tostring(errS)) end
        end
        local stronghold = getSystem("GangRetaliation.GRStronghold")
        if stronghold then prof("Stronghold:Tick", function() stronghold:Tick() end) end
        prof("strongholdEvents", pcall, strongholdEvents)
        prof("updatePendingAmbush", pcall, updatePendingAmbush)
        prof("updateHomes", pcall, updateHomes)
        -- El menu solo se reconstruye si cambiaron los datos (o la campana). Cada 30 s igual,
        -- por los textos que dependen del dia de juego o del idioma.
        GR.menuTimer = (GR.menuTimer or 0) + 1
        if Store.version ~= GR.menuVersion or GR.campaignId ~= GR.menuCampaign or GR.menuTimer >= 30 then
            GR.menuTimer = 0
            GR.menuVersion = Store.version
            GR.menuCampaign = GR.campaignId
            local okM, errM = prof("pushMenu", pcall, pushMenu)
            if not okM then print("[GangRetaliation] Error en datos del menu: " .. tostring(errM)) end
        end
        local ok, result = prof("tryGig", pcall, tryGig, false)
        if result then debugLog("Gig: " .. tostring(result)) end
        local okE, resultE = prof("tryExternalSquad", pcall, tryExternalSquad)
        if resultE then debugLog("Escuadron externo: " .. tostring(resultE)) end
    end

    GR.ambushTimer = (GR.ambushTimer or 0) + delta
    -- Solo en el frame del tick, justo despues de refreshCampaign (por si cambio la partida).
    if tick and GR.ambushTimer >= 60 then
        GR.ambushTimer = 0
        local ok, result = prof("tryAmbush", pcall, tryAmbush, false)
        debugLog("Emboscada: " .. tostring(result))
        local okH, errH = prof("updateHierarchy", pcall, updateHierarchy)
        if not okH then print("[GangRetaliation] Error en jerarquia: " .. tostring(errH)) end
        local okS, resultS = prof("trySkirmish", pcall, trySkirmish, false)
        debugLog("Escaramuza: " .. tostring(resultS))
        local okR, resultR = prof("tryRaid", pcall, tryRaid, false)
        debugLog("Redada: " .. tostring(resultR))
    end

    flushMessages(delta)

    if Store.dirty then
        GR.saveTimer = GR.saveTimer + delta
        if GR.saveTimer >= 5 then
            GR.saveTimer = 0
            prof("Store.save (JSON)", Store.save)
        end
    end
end

-- Dev: cuanto tarda onUpdate (promedio y pico por segundo), para medir el rendimiento.
GR.perf = { sum = 0, frames = 0, peak = 0, time = 0, avgMs = 0, peakMs = 0 }
-- Dev: vuelo con noclip para recorrer la ciudad buscando sitios. V se teletransporta cada frame hacia donde
-- mira la camara (atraviesa paredes y no cae) y es invulnerable hasta 10 s despues de apagarlo.
GR.fly = { on = false, f = 0, b = 0, l = 0, r = 0, up = 0, down = 0, fast = false, godUntil = 0 }

local function setFlyGod(on)
    local player = Game.GetPlayer()
    if not player then return end
    local god = Game.GetGodModeSystem()
    if on then
        god:AddGodMode(player:GetEntityID(), gameGodModeType.Invulnerable, CName.new("GRFly"))
    else
        god:RemoveGodMode(player:GetEntityID(), gameGodModeType.Invulnerable, CName.new("GRFly"))
    end
end

local function toggleFly()
    local fly = GR.fly
    local player = Game.GetPlayer()
    if not player then return end
    fly.on = not fly.on
    if fly.on then
        fly.hold = player:GetWorldPosition()
        fly.godUntil = 0
        setFlyGod(true)
    else
        fly.godUntil = os.clock() + 10
    end
end

local function updateFly(delta)
    local fly = GR.fly
    if not fly.on then
        if fly.godUntil > 0 and os.clock() > fly.godUntil then
            fly.godUntil = 0
            setFlyGod(false)
        end
        return
    end
    local player = Game.GetPlayer()
    if not player or not fly.hold then return end
    local cam = Game.GetCameraSystem()
    local fwd, right = cam:GetActiveCameraForward(), cam:GetActiveCameraRight()
    local step = (fly.fast and 60 or 15) * math.min(delta, 0.1)
    local ahead, side, lift = fly.f - fly.b, fly.r - fly.l, fly.up - fly.down
    local h = fly.hold
    fly.hold = ToVector4{
        x = h.x + (fwd.x * ahead + right.x * side) * step,
        y = h.y + (fwd.y * ahead + right.y * side) * step,
        z = h.z + (fwd.z * ahead + lift) * step,
        w = 1,
    }
    Game.GetTeleportationFacility():Teleport(player, fly.hold, ToEulerAngles{ roll = 0, pitch = 0, yaw = player:GetWorldYaw() })
end

if GR.dev then
    local function held(key)
        return function(down) GR.fly[key] = down and 1 or 0 end
    end
    registerInput("gr_fly_forward", "Fly: forward", held("f"))
    registerInput("gr_fly_back", "Fly: back", held("b"))
    registerInput("gr_fly_left", "Fly: left", held("l"))
    registerInput("gr_fly_right", "Fly: right", held("r"))
    registerInput("gr_fly_up", "Fly: up", held("up"))
    registerInput("gr_fly_down", "Fly: down", held("down"))
    registerInput("gr_fly_fast", "Fly: fast (hold)", function(down) GR.fly.fast = down end)
    registerHotkey("gr_fly_toggle", "Fly: on/off", function() pcall(toggleFly) end)
end

-- Dev: FPS del juego (con el delta de cada frame) y benchmark que apaga partes del mod para comparar.
GR.fps = { frames = 0, time = 0, worst = 0, value = 0, worstMs = 0 }
local BENCH_PHASES = {
    { name = "all on" },
    { name = "Lua off", luaOff = true },
    { name = "redscript hooks off", hooksOff = true },
    { name = "all off", luaOff = true, hooksOff = true },
    { name = "all on (again)" },
}
local BENCH_SETTLE, BENCH_MEASURE = 3, 10

local function profiler()
    return getSystem("GangRetaliation.GRProfiler")
end

local function sortedSections(sections, seconds)
    local list = {}
    for name, s in pairs(sections) do
        table.insert(list, { name = name, calls = s.calls, totalMs = s.total, maxMs = s.max, msPerSecond = s.total / seconds })
    end
    table.sort(list, function(a, b) return a.totalMs > b.totalMs end)
    return list
end

local function percentile(values, p)
    if #values == 0 then return 0 end
    table.sort(values)
    return values[math.max(1, math.ceil(#values * p))]
end

local function benchFinish(aborted)
    local b = GR.bench
    GR.bench = nil
    local pr = profiler()
    if pr then pr:SetHooksOff(false) end
    if aborted then
        GR.benchStatus = "Benchmark cancelled"
        return
    end
    local run = { date = os.date("%Y-%m-%d %H:%M:%S"), campaign = GR.campaignId, nemeses = #Store.campaign(GR.campaignId).nemeses, phases = b.results }
    print("[GangRetaliation] PERF ===== benchmark " .. run.date .. " (" .. run.nemeses .. " nemeses) =====")
    for _, r in ipairs(b.results) do
        print(string.format("[GangRetaliation] PERF %-22s %6.1f fps  avg %.2f ms  p99 %.2f ms  worst %.2f ms  lua %.3f ms/s", r.name, r.fps, r.avgFrameMs, r.p99FrameMs, r.worstFrameMs, r.luaMsPerSecond))
    end
    local path = "data/perf_results.json"
    local runs = {}
    local f = io.open(path, "r")
    if f then
        local ok, decoded = pcall(json.decode, f:read("*a"))
        f:close()
        if ok and type(decoded) == "table" then runs = decoded end
    end
    table.insert(runs, run)
    f = io.open(path, "w")
    if f then
        f:write(json.encode(runs))
        f:close()
    end
    GR.benchLast = b.results
    GR.benchStatus = "Benchmark done (" .. run.date .. "), saved to data/perf_results.json"
end

local function benchStep(delta)
    local b = GR.bench
    -- Con la ventana de CET abierta los FPS no valen: se espera a que se cierre y la fase arranca de nuevo.
    if GR.overlayOpen then
        b.t, b.measuring = 0, false
        GR.benchStatus = "Benchmark: close the CET overlay to start. Stand still, do not move the camera."
        return
    end
    local phase = BENCH_PHASES[b.phase]
    if b.t == 0 then
        local pr = profiler()
        if pr then pr:SetHooksOff(phase.hooksOff == true) end
    end
    b.t = b.t + delta
    if not b.measuring and b.t >= BENCH_SETTLE then
        b.measuring, b.frames, b.time, b.deltas, b.sections = true, 0, 0, {}, {}
        local pr = profiler()
        if pr then pr:TakeCounts() end
    end
    if b.measuring then
        b.frames, b.time = b.frames + 1, b.time + delta
        table.insert(b.deltas, delta * 1000)
    end
    GR.benchStatus = string.format("Benchmark: phase %d/%d (%s) %.0f s", b.phase, #BENCH_PHASES, phase.name, b.t)
    if b.t >= BENCH_SETTLE + BENCH_MEASURE then
        local pr = profiler()
        local sections = sortedSections(b.sections, b.time)
        local luaMs = 0
        for _, s in ipairs(sections) do luaMs = luaMs + s.msPerSecond end
        local worst = 0
        for _, d in ipairs(b.deltas) do worst = math.max(worst, d) end
        table.insert(b.results, {
            name = phase.name,
            fps = b.frames / b.time,
            avgFrameMs = b.time * 1000 / b.frames,
            p99FrameMs = percentile(b.deltas, 0.99),
            worstFrameMs = worst,
            luaMsPerSecond = luaMs,
            luaSections = sections,
            hookCalls = pr and pr:TakeCounts() or "",
            state = pr and pr:GetState() or "",
        })
        b.phase, b.t, b.measuring = b.phase + 1, 0, false
        if b.phase > #BENCH_PHASES then benchFinish(false) end
    end
end

registerForEvent("onUpdate", function(delta)
    if GR.dev then
        local okF, errF = pcall(updateFly, delta)
        if not okF then
            GR.fly.on = false
            print("[GangRetaliation] Error en fly: " .. tostring(errF))
        end
    end
    if not GR.dev then return update(delta) end

    local fps = GR.fps
    fps.frames, fps.time, fps.worst = fps.frames + 1, fps.time + delta, math.max(fps.worst, delta)
    if fps.time >= 1 then
        fps.value, fps.worstMs = fps.frames / fps.time, fps.worst * 1000
        fps.frames, fps.time, fps.worst = 0, 0, 0
    end

    local skipLua = false
    if GR.bench then
        benchStep(delta)
        local b = GR.bench
        skipLua = b ~= nil and BENCH_PHASES[b.phase].luaOff == true and not GR.overlayOpen
    end

    if not skipLua then
        local start = os.clock()
        update(delta)
        local p, ms = GR.perf, (os.clock() - start) * 1000
        p.sum, p.frames, p.peak, p.time = p.sum + ms, p.frames + 1, math.max(p.peak, ms), p.time + delta
        if p.time >= 1 then
            p.avgMs, p.peakMs = p.sum / p.frames, p.peak
            p.sum, p.frames, p.peak, p.time = 0, 0, 0, 0
        end
    end

    -- Ventana de 10 s para el panel (el benchmark usa sus propios contadores).
    local pf = GR.prof
    pf.window = pf.window + delta
    if pf.window >= 10 then
        pf.last = sortedSections(pf.cur, pf.window)
        pf.cur, pf.window = {}, 0
        local pr = profiler()
        if pr and not GR.bench then
            pf.counts, pf.state = pr:TakeCounts(), pr:GetState()
        end
    end
end)

registerForEvent("onOverlayOpen", function() GR.overlayOpen = true end)
registerForEvent("onOverlayClose", function() GR.overlayOpen = false end)

local function drawReleaseWindow()
    if ImGui.Begin("Gang Retaliation") then
        if GR.campaignId == 0 then
            ImGui.Text(text("GR-UiWaiting", "Waiting for a loaded save..."))
        else
            local alive, dead = 0, 0
            for _, n in ipairs(Store.campaign(GR.campaignId).nemeses) do
                if n.status == "dead" then dead = dead + 1 else alive = alive + 1 end
            end
            ImGui.Text(text("GR-UiCampaign", "Campaign") .. ": " .. tostring(GR.campaignId))
            ImGui.Text(string.format("%s: %d (+%d %s)", text("GR-UiNemeses", "Nemeses"), alive, dead, text("GR-UiDead", "dead")))
            ImGui.TextDisabled(string.format("game day %.2f", gameDay()))
            drawHomes()
        end
    end
    ImGui.End()
end

registerForEvent("onDraw", function()
    if not GR.overlayOpen then return end
    if not GR.dev then
        drawReleaseWindow()
        return
    end

    if ImGui.Begin("Gang Retaliation (dev)") then
        if GR.campaignId == 0 then
            ImGui.Text(text("GR-UiWaiting", "Waiting for a loaded save..."))
        else
            local campaign = Store.campaign(GR.campaignId)
            local l = lang()
            ImGui.Text(text("GR-UiCampaign", "Campaign") .. ": " .. tostring(GR.campaignId))
            ImGui.Text(text("GR-UiNemeses", "Nemeses") .. ": " .. tostring(#campaign.nemeses))
            ImGui.TextDisabled(string.format("onUpdate: %.3f ms/frame avg, %.3f ms peak (last second)", GR.perf.avgMs, GR.perf.peakMs))
            ImGui.TextDisabled(string.format("FPS %.0f, worst frame %.1f ms (overlay open lowers it)", GR.fps.value, GR.fps.worstMs))
            if ImGui.CollapsingHeader("Performance") then
                if GR.bench then
                    if ImGui.Button("Cancel benchmark") then benchFinish(true) end
                elseif ImGui.Button("Run benchmark (~65 s)") then
                    GR.bench = { phase = 1, t = 0, measuring = false, results = {} }
                end
                ImGui.TextWrapped(GR.benchStatus or "Stand still in a busy street, close the overlay and do not touch the mouse.")
                for _, r in ipairs(GR.benchLast or {}) do
                    ImGui.Text(string.format("%-22s %5.1f fps  p99 %5.1f ms  worst %5.1f ms  lua %.2f ms/s", r.name, r.fps, r.p99FrameMs, r.worstFrameMs, r.luaMsPerSecond))
                end
                ImGui.Separator()
                ImGui.TextDisabled("Lua sections, last 10 s (ms/s, max ms, calls):")
                for i, s in ipairs(GR.prof.last) do
                    if i > 10 then break end
                    ImGui.TextDisabled(string.format("  %-26s %7.3f  %6.1f  %d", s.name, s.msPerSecond, s.maxMs, s.calls))
                end
                ImGui.TextDisabled("Hooks, last 10 s: " .. GR.prof.counts)
                ImGui.TextWrapped("Alive: " .. GR.prof.state)
            end

            local det = getDetection()
            if det then
                ImGui.Text(text("GR-UiCandidates", "Wounded gangers in this fight") .. ": " .. tostring(det:GetCandidateCount()))
            end
            local sp = getSpawner()
            if sp then
                ImGui.TextDisabled(string.format("%s [%s]  ambush: %s", sp:GetDistrictName(), sp:GetDistrictGangs(), sp:IsAmbushActive() and "ACTIVE" or (sp:GetAmbushBlocker() ~= "" and sp:GetAmbushBlocker() or "ready")))
                local homeFactor, homeDistance = Ambush.homeFactor(Game.GetPlayer():GetWorldPosition(), Store.campaign(GR.campaignId))
                ImGui.TextDisabled(string.format("home: %.0f m  (ambush chance x%.2f)", homeDistance, homeFactor))
                drawHomes()
                ImGui.TextDisabled(sp:GetTrackedObjectiveInfo())
                if GR.pendingAmbush then
                    ImGui.TextDisabled(string.format("SMS #%d: ambush in %.0f s", GR.pendingAmbush.id, GR.pendingAmbush.due - sp:GetTime()))
                end
                local gigId = sp:GetActiveGigId()
                ImGui.TextDisabled(string.format("gig: %s  fight: [%s]", gigId ~= "" and (sp:GetActiveGigTitle() .. " (" .. gigId .. ")") or "-", det and det:GetFightGangs() or ""))
            end

            local settings = getSettings()
            if settings then
                ImGui.Separator()
                ImGui.Text(string.format("enabled=%s  maxPerGang=%d  debugLog=%s", tostring(settings.enabled), settings.maxPerGang, tostring(settings.debugLog)))
                ImGui.Text(string.format("escapeHealth=%d%%  fleeHealth=%d%%", settings.escapeHealthPercent, settings.fleeHealthPercent))
            end

            ImGui.Separator()
            if #campaign.nemeses == 0 then
                ImGui.Text(text("GR-UiNoData", "No Nemeses yet."))
            end
            local spawner = getSpawner()
            for _, n in ipairs(campaign.nemeses) do
                local dead = n.status == "dead"
                ImGui.Text(string.format("#%d %s%s", n.id or 0, Names.display(n, l), dead and (" [" .. text("GR-UiDead", "dead") .. "]") or ""))
                ImGui.Text(string.format("    %s - %s - %s - %.0f%% - x%d - ren %d", Names.gangLabel(n.gang), rankLabel(n.rank, n.gender), n.origin or "?", n.health or 0, n.encounters or 1, n.renown or 0))
                if n.recordID then
                    if n.traits and #n.traits > 0 then
                        local parts = {}
                        for _, t in ipairs(n.traits) do
                            table.insert(parts, (Traits.isWeakness(t.key) and "-" or "+") .. traitName(t.key) .. (t.revealed and "" or " (?)"))
                        end
                        ImGui.TextWrapped("    " .. table.concat(parts, ", "))
                    end
                    ImGui.TextDisabled("    " .. tostring(n.recordID) .. " / " .. tostring(n.appearance))
                    if spawner and not dead and n.id then
                        ImGui.SameLine()
                        if ImGui.SmallButton(text("GR-UiSpawn", "Spawn") .. "##" .. tostring(n.id)) then
                            pushTraits(n)
                            local ok = spawner:SpawnNearPlayer(n.id, n.recordID, n.appearance or "", 8.0, fullName(n))
                            GR.lastAction = ok and ("Spawn #" .. n.id) or "Spawn: no disponible / not available"
                        end
                        ImGui.SameLine()
                        if ImGui.SmallButton(text("GR-UiMarkDead", "Mark dead") .. "##dead" .. tostring(n.id)) then
                            n.status = "dead"
                            n.diedAt = os.time()
                            Store.save()
                        end
                        ImGui.SameLine()

                        if ImGui.SmallButton("Debug: dies, returns##ret" .. tostring(n.id)) then
                            n.status = "dead"
                            n.diedAt = os.time()
                            n.confirmed = nil
                            n.returnDay = gameDay()
                            Hierarchy.onDeath(Store.ensureCampaign(GR.campaignId), n, gameDay())
                            Store.save()
                            GR.lastAction = "#" .. n.id .. " volvera con +1 game day"
                        end
                    end
                end
            end

            ImGui.Separator()
            if ImGui.Button(text("GR-UiPromoteTarget", "Debug: make target a Nemesis")) then
                local det2 = getDetection()
                if det2 then
                    GR.lastAction = det2:DebugPromoteLookAt() and "OK" or "No valido / not valid"
                end
            end
            ImGui.SameLine()
            if ImGui.Button(text("GR-UiFleeTarget", "Debug: make target flee")) then
                local det3 = getDetection()
                if det3 then
                    GR.lastAction = det3:DebugFleeLookAt() and "Flee OK" or "No valido / not valid"
                end
            end
            local det4 = getDetection()
            if det4 then
                local mode = det4:GetFleeMode()
                ImGui.Text("Flee mode:")
                -- D-G: experimentos con sistemas del juego (ver ApplyFleeMode en Detection.reds).
                local modes = { { 0, "A: run" }, { 1, "B: fear" }, { 2, "C: both" }, { 3, "D: wipe+run" },
                    { 4, "E: wipe+fear+run" }, { 5, "F: retreat" }, { 6, "G: terror+run" }, { 7, "H: native flee" } }
                for i, opt in ipairs(modes) do
                    if i ~= 5 then ImGui.SameLine() end
                    if ImGui.RadioButton(opt[2], mode == opt[1]) then det4:SetFleeMode(opt[1]) end
                end
            end
            if ImGui.Button(text("GR-UiForceAmbush", "Debug: ambush now")) then
                local ok, result = pcall(tryAmbush, true)
                GR.lastAction = tostring(result)
                print("[GangRetaliation] Debug: " .. GR.lastAction)
            end
            ImGui.SameLine()
            if ImGui.Button(text("GR-UiSmsAmbush", "Debug: SMS + ambush in 15 s")) then
                local ok, result = pcall(tryAmbush, true, 15)
                GR.lastAction = tostring(result)
                print("[GangRetaliation] Debug: " .. GR.lastAction)
            end
            if ImGui.Button("Debug: vehicle ambush now") then
                local ok, result = pcall(tryAmbush, true, 0, true)
                GR.lastAction = tostring(result)
                print("[GangRetaliation] Debug: " .. GR.lastAction)
            end
            local hud = getSystem("GangRetaliation.GRHud")
            if hud then
                if ImGui.Button(hud:IsGodMode() and "Debug: god mode ON (click = off)" or "Debug: god mode OFF (click = on)") then
                    GR.lastAction = hud:ToggleGodMode() and "God mode ON" or "God mode OFF"
                end
                ImGui.TextDisabled(hud:GetGodModeInfo())
                ImGui.TextDisabled(hud:GetDebugInfo())
            end
            if ImGui.Button("Debug: gig reinforcement now") then
                local ok, result = pcall(tryGig, true)
                GR.lastAction = tostring(result)
                print("[GangRetaliation] Debug: " .. GR.lastAction)
            end
            ImGui.SameLine()
            if ImGui.Button("Hide lines") then
                local speech = getSystem("GangRetaliation.GRSpeech")
                if speech then speech:HideAll() end
            end
            ImGui.SameLine()
            if ImGui.Button(text("GR-UiDespawnAll", "Despawn all")) then
                local sp = getSpawner()
                if sp then sp:DespawnAll() end
            end
            ImGui.TextDisabled(string.format("game day %.2f (+%d debug)", gameDay(), GR.dayOffset))
            if ImGui.Button("Debug: +1 game day") then
                GR.dayOffset = GR.dayOffset + 1
                local ok, err = pcall(updateHierarchy)
                GR.lastAction = ok and "+1 day" or tostring(err)
            end
            ImGui.SameLine()
            if ImGui.Button("Debug: force feud") then
                for _, state in pairs(Store.ensureCampaign(GR.campaignId).hierarchy or {}) do state.lastFeudDay = nil end
                local ok, err = pcall(updateHierarchy, 100)
                GR.lastAction = ok and "feud" or tostring(err)
            end
            ImGui.SameLine()
            if ImGui.Button("Debug: force NCPD clash") then
                for _, state in pairs(Store.ensureCampaign(GR.campaignId).hierarchy or {}) do state.lastPoliceDay = nil end
                local ok, err = pcall(updateHierarchy, nil, 100)
                GR.lastAction = ok and "NCPD clash" or tostring(err)
            end
            if ImGui.Button("Debug: NCPD raid now") then
                local ok, res = pcall(tryRaid, true)
                GR.lastAction = tostring(res)
            end
            ImGui.SameLine()
            if ImGui.Button("Debug: start war") then
                local settings = getSettings()
                local campaign = Store.ensureCampaign(GR.campaignId)
                local ok, res = pcall(function()
                    updateWar(campaign, settings)
                    return War.forceWar(campaign, warContext(campaign, settings))
                end)
                GR.lastAction = ok and (res and "war started" or "no war possible") or tostring(res)
            end
            ImGui.SameLine()
            if ImGui.Button("Debug: skirmish now") then
                local ok, res = pcall(trySkirmish, true)
                GR.lastAction = tostring(res)
            end
            ImGui.Separator()
            local campaign = Store.ensureCampaign(GR.campaignId)
            local gangs = Hierarchy.knownGangs(campaign)
            table.sort(gangs)
            local ctx = siteContext(campaign)
            -- Al cambiar de barrio se elige sola la primera banda del barrio (se puede cambiar a mano).
            if ctx.district ~= GR.siteDistrict then
                GR.siteDistrict = ctx.district
                for i, gang in ipairs(gangs) do
                    if gang == ctx.gangs[1] then GR.siteGang = i end
                end
            end
            ImGui.Text(string.format("District: %s | Gangs here: %s", ctx.label ~= "" and ctx.label or "?",
                #ctx.gangs > 0 and table.concat(ctx.gangs, ", ") or "none"))
            if #gangs > 0 then
                GR.siteGang = math.min(GR.siteGang or 1, #gangs)
                GR.siteGang = ImGui.Combo("##sitegang", GR.siteGang - 1, gangs, #gangs) + 1
                ImGui.SameLine()
                if ImGui.Button("Stronghold: set here") then
                    local pos = Game.GetPlayer():GetWorldPosition()
                    campaign.stronghold = { gang = gangs[GR.siteGang], x = pos.x, y = pos.y, z = pos.z }
                    Store.dirty = true
                    GR.lastAction = string.format("guarida %s en %.1f, %.1f, %.1f", gangs[GR.siteGang], pos.x, pos.y, pos.z)
                end
            end
            -- Sitios candidatos para las guaridas fijas: se recorren a mano y despues se pasan al codigo.
            local inDistrict = false
            for _, gang in ipairs(ctx.gangs) do
                if gang == gangs[GR.siteGang or 1] then inDistrict = true end
            end
            if #gangs > 0 and ImGui.Button(string.format("Save site: %s @ %s%s##savesite", gangs[GR.siteGang or 1] or "?",
                ctx.label ~= "" and ctx.label or "?", inDistrict and "" or " (NOT their district)")) then
                local ok, res = pcall(function()
                    local pos = Game.GetPlayer():GetWorldPosition()
                    local sys = getSystem("GangRetaliation.GRStronghold")
                    local warSys = getSystem("GangRetaliation.GRWar")
                    local site = { gang = gangs[GR.siteGang], x = pos.x, y = pos.y, z = pos.z,
                        district = warSys and warSys:GetCurrentDistrict() or "", districtGangs = ctx.gangs,
                        posts = sys and sys:TestSite(pos.x, pos.y, pos.z) or -1 }
                    local list = Store.loadSites()
                    table.insert(list, site)
                    Store.saveSites(list)
                    return string.format("sitio #%d %s (%s): %d/20 puestos", #list, site.gang, site.district, site.posts)
                end)
                GR.lastAction = tostring(res)
            end
            ImGui.SameLine()
            if ImGui.Button("Test spot") then
                local pos = Game.GetPlayer():GetWorldPosition()
                local sys = getSystem("GangRetaliation.GRStronghold")
                GR.lastAction = sys and string.format("aqui entran %d/20 puestos", sys:TestSite(pos.x, pos.y, pos.z)) or "no system"
            end
            ImGui.SameLine()
            if ImGui.Button("Remove last candidate") then
                local list = Store.loadSites()
                local removed = table.remove(list)
                Store.saveSites(list)
                GR.lastAction = removed and string.format("borrado %s (%s), quedan %d", removed.gang, removed.district, #list) or "no hay sitios"
            end
            if campaign.stronghold then
                local sys = getSystem("GangRetaliation.GRStronghold")
                local inside = sys and sys:GetMemberCount() or 0
                ImGui.Text(string.format("Stronghold %s: %.0f m, %d inside%s%s", campaign.stronghold.gang,
                    sys and sys:GetDistance() or -1, inside, inside == 0 and " (nobody alive: won't spawn)" or "",
                    (sys and sys:IsActive()) and " (active)" or ""))
                if ImGui.Button("Stronghold: teleport there") then
                    local site = campaign.stronghold
                    local player = Game.GetPlayer()
                    Game.GetTeleportationFacility():Teleport(player, ToVector4{ x = site.x, y = site.y, z = site.z + 0.5, w = 1 },
                        ToEulerAngles{ roll = 0, pitch = 0, yaw = player:GetWorldYaw() })
                end
                ImGui.SameLine()
                if ImGui.Button("Stronghold: respawn") and sys then sys:Respawn() end
                ImGui.SameLine()
                if ImGui.Button("Remove stronghold") then
                    campaign.stronghold = nil
                    Store.dirty = true
                end
            end
            if ImGui.Button(GR.fly.on and "Fly: ON (click to land)" or "Fly (noclip)") then pcall(toggleFly) end
            ImGui.SameLine()
            ImGui.TextDisabled("keys: CET > Bindings > Gang Retaliation (Fly: ...)")
            ImGui.Separator()
            -- Drug Dealer (la logica esta en GRSpawner.DebugDD / GRIntegrations)
            local ddSpawner = getSpawner()
            if ddSpawner then
                if not GR.ddInfoAt or os.clock() - GR.ddInfoAt > 1 then
                    GR.ddInfo = ddSpawner:GetDDDebugInfo()
                    GR.ddInfoAt = os.clock()
                end
                ImGui.Text(GR.ddInfo)
                local ddButtons = { "DD: capture random zone", "DD: contest this zone", "DD: terror +25", "DD: surrender all zones" }
                for i, label in ipairs(ddButtons) do
                    if i > 1 then ImGui.SameLine() end
                    if ImGui.Button(label) then GR.lastAction = ddSpawner:DebugDD(i - 1) end
                end
                if ImGui.Button("TWR: fake vengeance SMS") then GR.lastAction = ddSpawner:DebugTWR(0) end
                ImGui.SameLine()
                if ImGui.Button("TWR: fake payment refused") then GR.lastAction = ddSpawner:DebugTWR(1) end
            end
            if ImGui.Button("Save now") then Store.save() end
            ImGui.SameLine()
            if ImGui.Button("Clear campaign") then Store.clearCampaign(GR.campaignId) end
            if GR.lastAction ~= "" then ImGui.TextDisabled(GR.lastAction) end
        end
    end
    ImGui.End()
end)

return GR
