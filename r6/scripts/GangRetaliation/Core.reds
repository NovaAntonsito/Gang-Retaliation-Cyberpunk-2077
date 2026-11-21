module GangRetaliation

import Codeware.Localization.*

public func GRLog(msg: String) {
    FTLog("[GangRetaliation] " + msg);
}

// On-screen category checkboxes (Mod Settings) let the user mute a noisy category without turning the
// whole on-screen panel off - e.g. keep Detection/Flee visible during combat testing while muting
// Campaign (the broadest one, since nearly all of Lua funnels through a single debugLog() call).
public func GRDebugOnScreenCategoryEnabled(settings: ref<GRSettings>, category: String) -> Bool {
    if Equals(category, "Detection") {
        return settings.debugOnScreenDetection;
    }
    if Equals(category, "Spawner") {
        return settings.debugOnScreenSpawner;
    }
    if Equals(category, "Campaign") {
        return settings.debugOnScreenCampaign;
    }
    if Equals(category, "Stronghold") {
        return settings.debugOnScreenStronghold;
    }
    return true;
}

// Screen-only sibling to GRDebugLog, for messages that must keep writing to gamelog.log unconditionally
// (not gated on settings.debugLog) but should still be optionally mirrored on screen - e.g. GRStronghold's
// "Guarida (...)"/"Guaridas auto: ..." lines, which are permanent-ish event records today, not purely
// debug-gated chatter, so folding them into GRDebugLog would have made them stop reaching the file
// whenever debugLog is off. Call the existing GRLog(msg) separately alongside this for the file write.
public func GRPushDebugLine(gi: GameInstance, msg: String, category: String) {
    let settings: ref<GRSettings> = GRSettings.Get(gi);
    if !IsDefined(settings) || !settings.debugOnScreen || !GRDebugOnScreenCategoryEnabled(settings, category) {
        return;
    }
    let hud: ref<GRHud> = GRHud.Get(gi);
    if IsDefined(hud) {
        hud.PushDebugLine(msg);
    }
}

// Universal "pure debug line" sink - the two gates (write to gamelog.log, push to the on-screen debug
// panel) stay independent, same as GRDetection.Debug() already did standalone. Shared here so any class
// (not just GRDetection) and Lua (via GRSystem.PushDebugLine, see Core.reds's GRSystem below) can reach
// the on-screen panel without duplicating the settings/GRHud lookup at every call site. Scoped to
// messages that were already debug-gated (settings.debugLog) - the unconditional, always-written
// GRLog(...) calls elsewhere (deaths, decapitations, etc.) are permanent event records, not diagnostic
// chatter, and are left as plain GRLog() calls rather than being folded in here.
public func GRDebugLog(gi: GameInstance, msg: String, category: String) {
    let settings: ref<GRSettings> = GRSettings.Get(gi);
    if !IsDefined(settings) {
        return;
    }
    if settings.debugLog {
        GRLog(msg);
    }
    if settings.debugOnScreen && GRDebugOnScreenCategoryEnabled(settings, category) {
        let hud: ref<GRHud> = GRHud.Get(gi);
        if IsDefined(hud) {
            hud.PushDebugLine(msg);
        }
    }
}

public class GRSystem extends ScriptableSystem {
    private persistent let m_campaignId: Int32;

    private let m_sessionToken: Int32;

    private let m_restoredSeen: Bool;

    public static func Get(gi: GameInstance) -> ref<GRSystem> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRSystem") as GRSystem;
    }

    private func OnAttach() {
        this.m_sessionToken = RandRange(1, 999999999);
        GRLog("Sistema cargado");
    }

    public func GetSessionToken() -> Int32 {
        return this.m_sessionToken;
    }

    // Screen-only (no file write) - Lua's debugLog() already does its own print() to the CET
    // console/gamelog.log when settings.debugLog is on, so routing it through GRDebugLog (which also
    // writes via GRLog/FTLog) would duplicate every line in the file. This lets Lua reach just the
    // on-screen panel, called via getSystem("GangRetaliation.GRSystem"):PushDebugLine(msg) from init.lua.
    public func PushDebugLine(msg: String) {
        let settings: ref<GRSettings> = GRSettings.Get(this.GetGameInstance());
        if !IsDefined(settings) || !settings.debugOnScreen || !settings.debugOnScreenCampaign {
            return;
        }
        let hud: ref<GRHud> = GRHud.Get(this.GetGameInstance());
        if IsDefined(hud) {
            hud.PushDebugLine(msg);
        }
    }

    private func OnRestored(saveVersion: Int32, gameVersion: Int32) {
        this.m_restoredSeen = true;
        let saved: Int32 = this.m_campaignId;
        let fact: Int32 = this.ReadCampaignFact();
        let source: String = "persistente";
        if saved == 0 {
            this.GenerateCampaignId("OnRestored, la partida no traia id");
            source = fact > 0 ? "fact" : "nueva";
        } else {
            if fact != saved {
                source = fact > 0 ? "persistente, el fact decia otro" : "persistente, sin fact todavia";
            }
        }
        this.WriteCampaignFact();
        let rewardsText: String = "?";
        let rewards: ref<GRRewards> = GRRewards.Get(this.GetGameInstance());
        if IsDefined(rewards) {
            rewardsText = IntToString(rewards.GetRegisteredCount());
        }
        GRLog("Partida restaurada: campana " + IntToString(saved) + " fact " + IntToString(fact) + " rewards=" + rewardsText
            + " -> usa " + IntToString(this.m_campaignId) + " (" + source + ")");
    }

    private func OnPlayerAttach(request: ref<PlayerAttachRequest>) {
        if !this.IsInGame() {
            return;
        }
        if this.m_campaignId == 0 {
            if !this.WasRestored() {
                this.GenerateCampaignId("OnPlayerAttach, partida nueva");
            } else {
                if !this.m_restoredSeen {
                    this.GenerateCampaignId("OnPlayerAttach, partida cargada sin OnRestored");
                }
            }
        }
        this.WriteCampaignFact();
    }

    private func ReadCampaignFact() -> Int32 {
        let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
        if !IsDefined(quests) {
            return 0;
        }
        return quests.GetFact(n"gr_campaign_id");
    }

    private func WriteCampaignFact() {
        if this.m_campaignId == 0 {
            return;
        }
        let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
        if IsDefined(quests) && quests.GetFact(n"gr_campaign_id") != this.m_campaignId {
            quests.SetFact(n"gr_campaign_id", this.m_campaignId);
        }
    }

    public func IsInGame() -> Bool {
        let requests: wref<inkISystemRequestsHandler> = GameInstance.GetSystemRequestsHandler();
        return IsDefined(requests) && !requests.IsPreGame();
    }

    private func GenerateCampaignId(source: String) {
        if this.m_campaignId != 0 {
            return;
        }
        let fact: Int32 = this.ReadCampaignFact();
        if fact > 0 {
            this.m_campaignId = fact;
            GRLog("Campana recuperada del fact: " + IntToString(fact) + " (" + source + ")");
        } else {
            this.m_campaignId = RandRange(100000, 999999999);
            GRLog("Nueva campana: " + IntToString(this.m_campaignId) + " (" + source + ")");
            this.WriteCampaignFact();
        }
    }

    public func GetCampaignId() -> Int32 {
        return this.m_campaignId;
    }

    public func GetText(key: String) -> String {
        return LocalizationSystem.GetInstance(this.GetGameInstance()).GetText(key);
    }
}
