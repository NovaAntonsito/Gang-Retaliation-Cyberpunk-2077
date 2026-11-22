module GangRetaliation

public class GRCandidate {
    public let entityID: EntityID;

    public let nemesisId: Int32;
    public let gang: String;
    public let recordID: TweakDBID;
    public let appearance: CName;
    public let gender: CName;
    public let health: Float;
    public let position: Vector4;
    public let fleeing: Bool;
    public let fled: Bool;
    public let ddSpawn: Bool;
    public let fleeOrigin: Vector4;
    public let unseen: Float;
    public let discovered: Bool;
    public let nativeFlee: Bool;
    public let limbsMissing: Bool;
    public let wasAware: Bool;
}

public class GRNemesisEvent {
    public let origin: String;
    public let nemesisId: Int32;
    public let gang: String;
    public let recordID: String;
    public let appearance: String;
    public let gender: String;
    public let health: Float;
    public let posX: Float;
    public let posY: Float;
    public let posZ: Float;
    public let limbsMissing: Bool;
    // Only meaningful for origin == "knockedout": true when this candidate is also a GRSpawner own-spawn
    // (ambush/raid/reinforcement). Own-spawns are independently tracked by GRSpawner.CheckNeutralized(),
    // which already records this same knockout as a death (kind="knockout") and lets Lua's processDeaths()
    // announce it ("is dead... for now" / "is dead. For good this time" if beheaded first) with the
    // canonical return-day logic - so Lua skips the knockout toast whenever this is true, to avoid a
    // redundant, contradictory second message for the same event. A wild (non-own-spawn) candidate has no
    // such pipeline watching it, so Lua instead records it immediately but holds the actual announcement
    // (and keeps it off the roster) for a real-time delay - see deferOrAnnounceKnockout in init.lua.
    public let ownSpawn: Bool;
}

public class GRDetection extends ScriptableSystem {
    private let m_candidates: array<ref<GRCandidate>>;
    private let m_pending: array<ref<GRNemesisEvent>>;

    private let m_promoted: array<EntityID>;

    private let m_combatants: array<EntityID>;

    private let m_someoneFled: Bool;

    private let m_fleeing: array<ref<GRCandidate>>;
    private let m_fleeStart: array<Float>;

    private let m_fleeMode: Int32;

    private let m_pendingFlee: EntityID;
    private let m_hasPendingFlee: Bool;

    private let m_hiding: array<ref<GRCandidate>>;
    private let m_fledIds: array<EntityID>;

    public func GRProfState() -> String {
        return "candidates=" + IntToString(ArraySize(this.m_candidates)) + " combatants=" + IntToString(ArraySize(this.m_combatants))
            + " fleeing=" + IntToString(ArraySize(this.m_fleeing)) + " hiding=" + IntToString(ArraySize(this.m_hiding));
    }

    public static func Get(gi: GameInstance) -> ref<GRDetection> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRDetection") as GRDetection;
    }

    private func OnAttach() {
        this.m_fleeMode = 7;
    }

    public static func GetGang(npc: ref<ScriptedPuppet>) -> String {
        let record: wref<Character_Record> = npc.GetRecord();
        if !IsDefined(record) || !IsDefined(record.Affiliation()) {
            return "";
        }
        switch record.Affiliation().Type() {
            case gamedataAffiliation.Maelstrom: return "Maelstrom";
            case gamedataAffiliation.TygerClaws: return "TygerClaws";
            case gamedataAffiliation.Valentinos: return "Valentinos";
            case gamedataAffiliation.SixthStreet: return "SixthStreet";
            case gamedataAffiliation.Animals: return "Animals";
            case gamedataAffiliation.VoodooBoys: return "VoodooBoys";
            case gamedataAffiliation.Wraiths: return "Wraiths";
            case gamedataAffiliation.Scavengers: return "Scavengers";
            case gamedataAffiliation.Barghest: return "Barghest";
            default: return "";
        }
    }

    public static func IsEligible(npc: ref<ScriptedPuppet>) -> Bool {
        if !IsDefined(npc) || npc.IsPlayer() || npc.IsCrowd() || npc.IsCharacterCivilian() {
            return false;
        }

        let record: wref<Character_Record> = npc.GetRecord();
        if GRDetection.IsMachineRecord(record) {
            return false;
        }
        if IsDefined(record) && IsDefined(record.Rarity()) {
            let rarity: gamedataNPCRarity = record.Rarity().Type();
            if Equals(rarity, gamedataNPCRarity.Boss) || Equals(rarity, gamedataNPCRarity.MaxTac) {
                return false;
            }
        }
        return NotEquals(GRDetection.GetGang(npc), "");
    }

    public static func IsMachineRecord(record: wref<Character_Record>) -> Bool {
        if !IsDefined(record) || !IsDefined(record.CharacterType()) {
            return false;
        }
        let kind: gamedataNPCType = record.CharacterType().Type();
        return Equals(kind, gamedataNPCType.Drone) || Equals(kind, gamedataNPCType.Mech)
            || Equals(kind, gamedataNPCType.Spiderbot) || Equals(kind, gamedataNPCType.Android)
            || Equals(kind, gamedataNPCType.Cerberus) || Equals(kind, gamedataNPCType.Chimera)
            || Equals(kind, gamedataNPCType.Device);
    }

    public static func IsMachine(npc: ref<ScriptedPuppet>) -> Bool {
        return IsDefined(npc) && GRDetection.IsMachineRecord(npc.GetRecord());
    }

    public static func IsMachineRecordID(recordID: String) -> Bool {
        return GRDetection.IsMachineRecord(TweakDBInterface.GetCharacterRecord(TDBID.Create(recordID)));
    }

    public static func IsPlayerAlly(npc: ref<ScriptedPuppet>) -> Bool {
        if !IsDefined(npc) {
            return false;
        }
        if npc.IsPlayerCompanion() {
            return true;
        }
        let player: ref<PlayerPuppet> = GetPlayer(npc.GetGame());
        return IsDefined(player) && Equals(GameObject.GetAttitudeBetween(npc, player), EAIAttitude.AIA_Friendly);
    }

    public static func IsNeutralized(npc: ref<ScriptedPuppet>) -> Bool {
        return !IsDefined(npc) || npc.IsDead() || ScriptedPuppet.IsDefeated(npc) || ScriptedPuppet.IsUnconscious(npc);
    }

    public static func IsAwareOfPlayer(npc: ref<ScriptedPuppet>, player: ref<PlayerPuppet>) -> Bool {
        if !IsDefined(npc) || !IsDefined(player) {
            return false;
        }
        let tracked: TrackedLocation;
        return TargetTrackingExtension.GetTrackedLocation(npc, player, tracked) && tracked.visible;
    }

    public static func HasMissingLimb(npc: ref<ScriptedPuppet>) -> Bool {
        if !IsDefined(npc) || !IsDefined(npc.GetDismembermentComponent()) {
            return false;
        }
        let limbs = npc.GetDismembermentComponent().GetDismemberedLimbCount();
        return limbs.fleshDismemberments + limbs.cyberDismemberments > 0u;
    }

    // Relentless Live Dismemberment (the user's dismemberment mod) tracks a downed leg via these two
    // status effects rather than the native per-component limb count, and has its own grounded/crawl/
    // seated handling - including its own timeout that eventually force-kills the NPC if left alone.
    public static func HasDismemberedLeg(npc: ref<ScriptedPuppet>) -> Bool {
        if !IsDefined(npc) {
            return false;
        }
        return StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.DismemberedLegLeft")
            || StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.DismemberedLegRight");
    }

    private func GetHealthPercent(npc: ref<ScriptedPuppet>) -> Float {
        return GameInstance.GetStatPoolsSystem(this.GetGameInstance()).GetStatPoolValue(Cast<StatsObjectID>(npc.GetEntityID()), gamedataStatPoolType.Health, true);
    }

    private func IsEnabled() -> Bool {
        let settings: ref<GRSettings> = GRSettings.Get(this.GetGameInstance());
        return !IsDefined(settings) || settings.enabled;
    }

    private func Debug(msg: String) {
        GRDebugLog(this.GetGameInstance(), msg, "Detection");
    }

    private func GetSpawnedNemesisId(id: EntityID) -> Int32 {
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());
        return IsDefined(spawner) ? spawner.GetNemesisId(id) : 0;
    }

    private func FindCandidate(id: EntityID) -> Int32 {
        let i: Int32 = 0;
        while i < ArraySize(this.m_candidates) {
            if this.m_candidates[i].entityID == id {
                return i;
            }
            i += 1;
        }
        return -1;
    }

    private func WasPromoted(id: EntityID) -> Bool {
        for promoted in this.m_promoted {
            if promoted == id {
                return true;
            }
        }
        return false;
    }

    private func IsPlayerDead() -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) || player.IsDead() {
            return true;
        }
        let health: Float = GameInstance.GetStatPoolsSystem(this.GetGameInstance()).GetStatPoolValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatPoolType.Health, true);
        return health <= 0.0;
    }

    private func MakeCandidate(npc: ref<ScriptedPuppet>) -> ref<GRCandidate> {
        let candidate: ref<GRCandidate> = new GRCandidate();
        candidate.entityID = npc.GetEntityID();
        candidate.gang = GRDetection.GetGang(npc);
        candidate.ddSpawn = GRIntegrations.IsDDSpawn(npc.GetEntityID());
        candidate.nemesisId = this.GetSpawnedNemesisId(npc.GetEntityID());
        candidate.recordID = npc.GetRecord().GetID();
        candidate.appearance = npc.GetCurrentAppearanceName();
        candidate.gender = npc.GetResolvedGenderName();
        candidate.health = this.GetHealthPercent(npc);
        candidate.position = npc.GetWorldPosition();
        candidate.limbsMissing = GRDetection.HasMissingLimb(npc);
        candidate.wasAware = GRDetection.IsAwareOfPlayer(npc, GetPlayer(this.GetGameInstance()));
        return candidate;
    }

    private func UpsertCandidate(npc: ref<ScriptedPuppet>) -> ref<GRCandidate> {
        let index: Int32 = this.FindCandidate(npc.GetEntityID());
        if index >= 0 {
            let candidate: ref<GRCandidate> = this.m_candidates[index];
            candidate.health = this.GetHealthPercent(npc);
            candidate.position = npc.GetWorldPosition();
            candidate.limbsMissing = GRDetection.HasMissingLimb(npc);
            candidate.wasAware = candidate.wasAware || GRDetection.IsAwareOfPlayer(npc, GetPlayer(this.GetGameInstance()));
            return candidate;
        }
        let created: ref<GRCandidate> = this.MakeCandidate(npc);
        created.fled = this.HasFled(created.entityID);
        ArrayPush(this.m_candidates, created);
        this.Debug("Candidato: " + created.gang + " " + TDBID.ToStringDEBUG(created.recordID));
        return created;
    }

    private func AddCombatant(id: EntityID) {
        for combatant in this.m_combatants {
            if combatant == id {
                return;
            }
        }
        ArrayPush(this.m_combatants, id);
    }

    private func FindPuppet(id: EntityID) -> ref<ScriptedPuppet> {
        return GameInstance.FindEntityByID(this.GetGameInstance(), id) as ScriptedPuppet;
    }

    private func ResetFight() {
        ArrayClear(this.m_candidates);
        ArrayClear(this.m_combatants);
        this.m_someoneFled = false;
        this.m_hasPendingFlee = false;
        let intel: ref<GRIntelSystem> = GRIntelSystem.Get(this.GetGameInstance());
        if IsDefined(intel) {
            intel.OnFightReset();
        }
    }

    private func CheckLastStanding() {
        let settings: ref<GRSettings> = GRSettings.Get(this.GetGameInstance());
        if this.m_someoneFled || !IsDefined(settings) || !settings.lastManFlees {
            return;
        }
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());
        if IsDefined(spawner) && spawner.IsRaidActive() {
            return;
        }

        if ArraySize(this.m_combatants) < 2 {
            return;
        }
        let last: ref<ScriptedPuppet>;
        let alive: Int32 = 0;
        for combatant in this.m_combatants {
            let npc: ref<ScriptedPuppet> = this.FindPuppet(combatant);
            if !GRDetection.IsNeutralized(npc) {
                alive += 1;
                last = npc;
            }
        }
        if alive != 1 {
            return;
        }
        let others: Int32 = this.CountOtherThreats(last);
        if others > 0 {
            this.Debug("Huida esperada: quedan " + IntToString(others) + " amenazas mas");
            return;
        }

        let blocker: String = this.GetFleeBlocker(last);
        if Equals(blocker, "vehicle") {
            this.Debug("Huida cancelada: hay un vehiculo de por medio");
            return;
        }
        if StrLen(blocker) > 0 {
            this.m_someoneFled = true;
            if IsDefined(spawner) {
                this.Debug("Huida cancelada: " + blocker + " (" + spawner.GetTrackedObjectiveInfo() + ")");
            } else {
                this.Debug("Huida cancelada: " + blocker);
            }
            return;
        }
        // A leg-dismembered NPC (Relentless Live Dismemberment's own grounded/crawl/seated state) is
        // still alive, but forcing them to stand and sprint away interrupts that mod's own handling -
        // it already has a timeout that resolves them (force-kills them) on its own if left alone, so
        // leave them to it instead of yanking them into our flee logic.
        if GRDetection.HasDismemberedLeg(last) {
            this.Debug("Huida cancelada: sin piernas, se deja en manos del mod de desmembramiento");
            return;
        }
        let health: Float = this.GetHealthPercent(last);
        if health > 0.0 && health <= GRIntegrations.GetFleePercent(settings.fleeHealthPercent) {
            this.m_someoneFled = true;
            this.m_pendingFlee = last.GetEntityID();
            this.m_hasPendingFlee = true;
            GRDetectionCall.SendDelayed(this.GetGameInstance(), GRDetectionCall.RunFlee(), last.GetEntityID(), 0.1);
        }
    }

    // "Equipped" here means a real drawn weapon - bare fists (and innate melee cyberware like Mantis
    // Blades/Strong Arms/Nanowires) also occupy the weapon slot, so brawler-type NPCs would otherwise
    // never count as disarmed even after losing a limb (see RPGManager.DropItemFromSlot's own exclusion
    // list for the same reason, in scriptedPuppet).
    private func HasWeaponEquipped(npc: ref<ScriptedPuppet>) -> Bool {
        // Boxer/brawler-type NPCs can carry their weapon (or remaining fist) in either hand, so both
        // slots need checking - a southpaw missing her right arm would otherwise read as disarmed
        // while still swinging a weapon equipped in her left hand.
        return this.HasWeaponInSlot(npc, t"AttachmentSlots.WeaponRight") || this.HasWeaponInSlot(npc, t"AttachmentSlots.WeaponLeft");
    }

    // "Equipped" here means a real drawn weapon - bare fists (and innate melee cyberware like Mantis
    // Blades/Strong Arms/Nanowires) also occupy the weapon slot, so brawler-type NPCs would otherwise
    // never count as disarmed even after losing a limb (see RPGManager.DropItemFromSlot's own exclusion
    // list for the same reason, in scriptedPuppet).
    private func HasWeaponInSlot(npc: ref<ScriptedPuppet>, slot: TweakDBID) -> Bool {
        let item: wref<ItemObject> = GameInstance.GetTransactionSystem(this.GetGameInstance()).GetItemInSlot(npc, slot);
        if !IsDefined(item) {
            this.Debug("Chequeo de arma (" + TDBID.ToStringDEBUG(slot) + "): nada en esa mano");
            return false;
        }
        let itemType: gamedataItemType = RPGManager.GetItemType(item.GetItemData().GetID());
        // 2026-11-22: a gang NPC self-healing mid-fight briefly equips a stim/injector in this same slot -
        // Con_Inhaler/Con_Injector (confirmed via the vanilla script dump) aren't weapons either, but
        // weren't excluded, so a one-armed NPC caught holding one read as "still armed" and never triggered
        // disarmed-flee, continuing the fight unarmed as if nothing had changed.
        let isFistsLike: Bool = Equals(itemType, gamedataItemType.Wea_Fists) || Equals(itemType, gamedataItemType.Cyb_StrongArms)
            || Equals(itemType, gamedataItemType.Cyb_MantisBlades) || Equals(itemType, gamedataItemType.Cyb_NanoWires)
            || Equals(itemType, gamedataItemType.Con_Inhaler) || Equals(itemType, gamedataItemType.Con_Injector);
        this.Debug("Chequeo de arma (" + TDBID.ToStringDEBUG(slot) + "): " + EnumValueToString("gamedataItemType", Cast<Int64>(EnumInt(itemType)))
            + (isFistsLike ? " (punos/cyberware, no cuenta como arma)" : " (arma real)"));
        return !isFistsLike;
    }

    // recordID is an archetype/template path, not a per-NPC identity - two different individuals sharing
    // the same character base (e.g. two "rare" variants of the same model) print identically and are
    // impossible to tell apart in the debug log. Tagging with EntityID.ToDebugString gives each a short,
    // stable per-instance suffix so they read as distinct even when the recordID is the same.
    private func Tag(id: EntityID, recordID: TweakDBID) -> String {
        return TDBID.ToStringDEBUG(recordID) + "#" + EntityID.ToDebugString(id);
    }

    // With a dismemberment mod installed, a hit can leave an NPC missing a limb; if they're also
    // unarmed (weapon shot/knocked out of hand), they should try to flee on their own regardless of
    // how many other combatants are still up - independent of the last-man-standing check above.
    private func CheckDisarmedFlee(npc: ref<ScriptedPuppet>) {
        let id: EntityID = npc.GetEntityID();
        if this.HasFled(id) || this.IsRunningAway(id) {
            this.Debug("Huida por desarme: omitida, ya huyo o esta huyendo (" + this.Tag(id, npc.GetRecordID()) + ")");
            return;
        }
        let health: Float = this.GetHealthPercent(npc);
        let missingLimb: Bool = GRDetection.HasMissingLimb(npc);
        let hasWeapon: Bool = this.HasWeaponEquipped(npc);
        this.Debug("Huida por desarme: " + this.Tag(id, npc.GetRecordID()) + " vida=" + FloatToString(health)
            + "% miembro perdido=" + (missingLimb ? "si" : "no") + " con arma=" + (hasWeapon ? "si" : "no"));
        if health <= 0.0 {
            return;
        }
        if !missingLimb || hasWeapon {
            // Dismemberment is asynchronous - DismembermentComponent.RequestDismemberment() only queues
            // a DismembermentEvent, processed by the component itself on a later tick, while this check
            // runs synchronously inside the same hit that caused it. A hit landed the same instant as the
            // one that severs a limb can easily be checked before the component has registered it, and
            // since this only runs again on the *next* hit, an NPC who never gets hit again afterward
            // (confirmed via gamelog trace: two separate NPCs lost a limb on what should have been the
            // disarming blow, and neither registered it even several seconds later) would otherwise never
            // get a second chance. Re-check once more shortly after, independent of what this pass saw.
            GRDetectionCall.SendDelayed(this.GetGameInstance(), GRDetectionCall.RunDisarmedFlee(), id, 0.3);
            return;
        }
        let blocker: String = this.GetFleeBlocker(npc, true);
        if StrLen(blocker) > 0 {
            this.Debug("Huida por desarme cancelada: " + blocker);
            return;
        }
        this.Debug("Huida por desarme: disparando huida retrasada (" + this.Tag(id, npc.GetRecordID()) + ")");
        GRDetectionCall.SendDelayed(this.GetGameInstance(), GRDetectionCall.RunDisarmedFlee(), id, 0.1);
    }

    private func RunDisarmedFlee(id: EntityID) {
        // Same noise concern as above: now scheduled from every qualifying-or-not hit, so these two
        // early-outs (npc already dead/invalid, or already fleeing by some other trigger) are also now
        // common, uninteresting outcomes most of the time - kept silent for the same reason.
        let npc: ref<ScriptedPuppet> = GameInstance.FindEntityByID(this.GetGameInstance(), id) as ScriptedPuppet;
        if !IsDefined(npc) || GRDetection.IsNeutralized(npc) || this.GetHealthPercent(npc) <= 0.0 {
            return;
        }
        if this.HasFled(id) || this.IsRunningAway(id) {
            return;
        }
        if !GRDetection.HasMissingLimb(npc) || this.HasWeaponEquipped(npc) {
            // No longer logged: since every hit that doesn't immediately qualify now schedules this same
            // recheck (see CheckDisarmedFlee's comment above), this branch is the overwhelmingly common,
            // uninteresting outcome - logging it here would flood the log/on-screen panel on every ordinary
            // hit instead of just the rare, meaningful cases.
            return;
        }
        let blocker: String = this.GetFleeBlocker(npc, true);
        if StrLen(blocker) > 0 {
            this.Debug("Huida por desarme (retrasada) cancelada: " + blocker);
            return;
        }
        // A missing leg also counts toward HasMissingLimb()'s generic flesh/cyber total, so a
        // leg-dismembered NPC who's also unarmed would otherwise qualify here too - same reasoning as
        // CheckLastStanding above, leave them to Relentless Live Dismemberment's own handling instead.
        if GRDetection.HasDismemberedLeg(npc) {
            this.Debug("Huida por desarme (retrasada) cancelada: sin piernas, se deja en manos del mod de desmembramiento");
            return;
        }
        this.Debug("Huida por desarme (retrasada): confirmada, huyendo (" + this.Tag(id, npc.GetRecordID()) + ")");
        this.MakeFlee(npc, "desarmado y mutilado");
    }

    private func CountOtherThreats(last: ref<ScriptedPuppet>) -> Int32 {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) || !IsDefined(player.GetTargetTrackerComponent()) {
            return 0;
        }
        let tracked: array<TrackedLocation> = player.GetTargetTrackerComponent().GetHostileThreats(true);
        let count: Int32 = 0;
        let names: String = "";
        for location in tracked {
            let npc: ref<ScriptedPuppet> = location.entity as ScriptedPuppet;
            if IsDefined(npc) && npc.GetEntityID() != last.GetEntityID() && !GRDetection.IsNeutralized(npc)
                && NPCPuppet.IsInCombat(npc)
                && Vector4.Distance(npc.GetWorldPosition(), player.GetWorldPosition()) < 40.0 {
                count += 1;
                names += " " + TDBID.ToStringDEBUG(npc.GetRecordID());
            }
        }
        if count > 0 {
            this.Debug("Amenazas que frenan la huida:" + names);
        }
        return count;
    }

    private func HasFled(id: EntityID) -> Bool {
        for fled in this.m_fledIds {
            if fled == id {
                return true;
            }
        }
        return false;
    }

    private func MarkFled(id: EntityID) {
        if this.HasFled(id) {
            return;
        }
        if ArraySize(this.m_fledIds) >= 64 {
            ArrayErase(this.m_fledIds, 0);
        }
        ArrayPush(this.m_fledIds, id);
    }

    private func PlayerSees(npc: ref<ScriptedPuppet>) -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());
        if !IsDefined(player) || !IsDefined(spawner) {
            return false;
        }
        return spawner.HasLineOfSight(player, npc.GetWorldPosition());
    }

    // ignoreRaid: 2026-11-22, user's call - a disarmed/dismembered NPC should still try to flee even
    // during a raid (the alternative was cowering uselessly in place, which looked broken even though the
    // raid-wide no-flee rule is intentional for the ordinary last-man-standing case). Only the two
    // disarmed-flee call sites below pass true; CheckLastStanding and the HUD's cosmetic "can flee"
    // indicator keep the raid block as-is.
    public func GetFleeBlocker(npc: ref<ScriptedPuppet>, opt ignoreRaid: Bool) -> String {
        let gi: GameInstance = this.GetGameInstance();
        let settings: ref<GRSettings> = GRSettings.Get(gi);
        if !IsDefined(settings) || !settings.enabled || !settings.lastManFlees {
            return "disabled";
        }
        if !GRDetection.IsEligible(npc) || GRDetection.IsNeutralized(npc) {
            return "not eligible";
        }
        let spawner: ref<GRSpawner> = GRSpawner.Get(gi);
        if !ignoreRaid && IsDefined(spawner) && spawner.IsRaidActive() {
            return "raid";
        }
        if VehicleComponent.IsMountedToVehicle(gi, npc) || VehicleComponent.IsMountedToVehicle(gi, GetPlayer(gi)) {
            return "vehicle";
        }
        let ownSpawn: Bool = IsDefined(spawner) && spawner.IsOwnSpawn(npc.GetEntityID());
        if IsDefined(spawner) && (spawner.IsInScene() || (!ownSpawn && spawner.IsStoryQuestNearby())) {
            return "scene or story quest nearby";
        }
        return "";
    }

    private func RunPendingFlee() {
        if !this.m_hasPendingFlee {
            return;
        }
        this.m_hasPendingFlee = false;
        let npc: ref<ScriptedPuppet> = GameInstance.FindEntityByID(this.GetGameInstance(), this.m_pendingFlee) as ScriptedPuppet;
        if !IsDefined(npc) || GRDetection.IsNeutralized(npc) || this.GetHealthPercent(npc) <= 0.0 {
            return;
        }
        this.MakeFlee(npc, "ultimo en pie");
    }

    private func Now() -> Float {
        return EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
    }

    private func MakeFlee(npc: ref<ScriptedPuppet>, reason: String) {
        this.MakeFleeMode(npc, -1, reason);
    }

    private func MakeFleeMode(npc: ref<ScriptedPuppet>, forcedMode: Int32, reason: String) {
        if !IsDefined(npc) || !npc.IsAttached() || VehicleComponent.IsMountedToVehicle(this.GetGameInstance(), npc) {
            return;
        }
        this.m_someoneFled = true;
        let candidate: ref<GRCandidate> = this.UpsertCandidate(npc);
        candidate.fleeing = true;
        candidate.fled = true;
        candidate.fleeOrigin = npc.GetWorldPosition();
        candidate.unseen = 0.0;
        candidate.discovered = false;
        candidate.nativeFlee = false;
        this.MarkFled(candidate.entityID);
        ArrayPush(this.m_fleeing, candidate);
        ArrayPush(this.m_fleeStart, this.Now());

        let puppet: ref<NPCPuppet> = npc as NPCPuppet;
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let ownSpawn: Bool = this.IsOwnSpawn(npc.GetEntityID());
        let mode: Int32 = forcedMode >= 0 ? forcedMode : this.m_fleeMode;
        if forcedMode < 0 && !ownSpawn && (mode == 1 || mode == 2 || mode == 4) {
            mode = 6;
        }
        if IsDefined(puppet) && IsDefined(player) && IsDefined(puppet.GetAttitudeAgent()) && IsDefined(puppet.GetAIControllerComponent()) {
            this.ApplyFleeMode(puppet, player, mode);
            if mode == 7 {
                let reactions: ref<ReactionManagerComponent> = puppet.GetStimReactionComponent();
                candidate.nativeFlee = IsDefined(reactions) && reactions.GRForceFlee(player);
                this.Debug("Huida nativa (modo H): " + (candidate.nativeFlee ? "reaccion Flee pedida" : "sin componente de reacciones, se usa el flash"));
            }
        }
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());
        if ownSpawn && IsDefined(spawner) {
            spawner.HideMarkers(npc.GetEntityID());
        }
        if !candidate.nativeFlee {
            if IsDefined(player) {
                let blind: TweakDBID = GRBlindEffect();
                StatusEffectHelper.ApplyStatusEffect(player, blind);
                GRDetectionCall.SendDelayed(this.GetGameInstance(), GRDetectionCall.Unblind(), player.GetEntityID(), 2.0);
                this.Debug("Flash: " + TDBID.ToStringDEBUG(blind));
            }
            GRDetectionCall.SendDelayed(this.GetGameInstance(), GRDetectionCall.Vanish(), npc.GetEntityID(), 0.6);
        }

        GameObject.PlayVoiceOver(npc, n"fear_run", n"Scripts:GangRetaliation");
        this.SayFleeLine(npc, candidate.gang);
        this.Debug("Huye (" + reason + ", modo " + IntToString(mode) + "): " + candidate.gang + " vida " + FloatToString(candidate.health) + "%");
    }

    private func ApplyFleeMode(puppet: ref<NPCPuppet>, player: ref<PlayerPuppet>, mode: Int32) {
        if mode == 7 {
            puppet.GetAttitudeAgent().SetAttitudeTowards(player.GetAttitudeAgent(), EAIAttitude.AIA_Neutral);
            return;
        }
        if mode == 3 || mode == 4 {
            let tracker: ref<TargetTrackerComponent> = puppet.GetTargetTrackerComponent();
            if IsDefined(tracker) {
                tracker.ClearThreats();
            }
            if mode == 3 {
                NPCPuppet.ChangeHighLevelState(puppet, gamedataNPCHighLevelState.Alerted);
            }
        }
        if mode == 5 {
            GameInstance.GetStatsSystem(this.GetGameInstance()).AddModifier(Cast<StatsObjectID>(puppet.GetEntityID()),
                RPGManager.CreateStatModifier(gamedataStatType.CanRetreat, gameStatModifierType.Additive, 1.0));
            return;
        }
        if mode == 6 {
            StimBroadcasterComponent.SendStimDirectly(player, gamedataStimType.Terror, puppet);
        }
        if mode != 1 {
            puppet.GetAttitudeAgent().SetAttitudeTowards(player.GetAttitudeAgent(), EAIAttitude.AIA_Neutral);
            GRMoveTo(puppet, GRAwayFrom(puppet, player, 60.0), moveMovementType.Sprint, 2.0);
        }
        if mode == 1 || mode == 2 || mode == 4 {
            NPCPuppet.ChangeHighLevelState(puppet, gamedataNPCHighLevelState.Fear);
        }
    }

    private func IsOwnSpawn(id: EntityID) -> Bool {
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());
        return IsDefined(spawner) && spawner.IsOwnSpawn(id);
    }

    private func StopFlee(npc: ref<ScriptedPuppet>, candidate: ref<GRCandidate>, reason: String) {
        candidate.fleeing = false;
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) || !IsDefined(npc.GetAttitudeAgent()) || !IsDefined(player.GetAttitudeAgent()) {
            return;
        }
        if candidate.nativeFlee {
            candidate.nativeFlee = false;
            let reactions: ref<ReactionManagerComponent> = npc.GetStimReactionComponent();
            if IsDefined(reactions) {
                reactions.GRStopFlee();
            }
        }
        npc.GetAttitudeAgent().SetAttitudeTowards(player.GetAttitudeAgent(), EAIAttitude.AIA_Hostile);
        StimBroadcasterComponent.SendStimDirectly(player, gamedataStimType.CombatHit, npc);
        this.Debug("Huida cortada: " + reason + " (" + candidate.gang + ")");
    }

    private func Hide(npc: ref<ScriptedPuppet>, candidate: ref<GRCandidate>) {
        candidate.fleeing = false;
        candidate.unseen = 0.0;
        let puppet: ref<NPCPuppet> = npc as NPCPuppet;
        if IsDefined(puppet) && !candidate.nativeFlee {
            GRMoveTo(puppet, npc.GetWorldPosition(), moveMovementType.Walk, 1.0);
        }
        ArrayPush(this.m_hiding, candidate);
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if IsDefined(player) && !player.IsInCombat() {
            this.PromoteFled(candidate);
            this.Debug("Escondido con el combate terminado: " + candidate.gang);
            return;
        }
        this.UpsertCandidate(npc);
        this.Debug("Se esconde: " + candidate.gang + " a " + FloatToString(this.DistanceToPlayer(npc)) + " m de V");
    }

    private func DistanceToPlayer(npc: ref<ScriptedPuppet>) -> Float {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        return IsDefined(player) ? Vector4.Distance(npc.GetWorldPosition(), player.GetWorldPosition()) : 0.0;
    }

    private func UpdateHiding() {
        let i: Int32 = ArraySize(this.m_hiding) - 1;
        while i >= 0 {
            let candidate: ref<GRCandidate> = this.m_hiding[i];
            let npc: ref<ScriptedPuppet> = this.FindPuppet(candidate.entityID);
            let done: Bool = false;
            if !IsDefined(npc) {
                if !candidate.ddSpawn {
                    this.PromoteFled(candidate);
                }
                done = true;
            } else {
                if GRDetection.IsNeutralized(npc) {
                    this.Debug("Escondido abandonado: neutralizado por otra via (" + candidate.gang + ")");
                    done = true;
                } else {
                    if candidate.discovered {
                        // 2026-11-22: StopFlee() unconditionally turns the NPC hostile again regardless of
                        // whether they can actually fight - reported in game as a disarmed, limb-missing
                        // NPC getting spotted while hiding, walking back into combat, and "couldn't do
                        // anything." If they're still disarmed and missing a limb, let them keep trying to
                        // hide/flee instead of forcing a pointless re-engagement.
                        if GRDetection.HasMissingLimb(npc) && !this.HasWeaponEquipped(npc) {
                            candidate.discovered = false;
                            this.Debug("Escondido encontrado pero desarmado y mutilado: sigue escondiendose en vez de volver al combate (" + candidate.gang + ")");
                        } else {
                            this.StopFlee(npc, candidate, "V encontro al escondido");
                            done = true;
                        }
                    } else {
                        if this.WasPromoted(candidate.entityID) && this.DistanceToPlayer(npc) > 100.0 {
                            done = true;
                        } else {
                            if this.PlayerSees(npc) {
                                candidate.unseen = 0.0;
                            } else {
                                candidate.unseen += 1.0;
                                if candidate.unseen >= 3.0 {
                                    if this.VanishHiding(npc, candidate) {
                                        done = true;
                                    } else {
                                        candidate.unseen = 0.0;
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if done {
                ArrayErase(this.m_hiding, i);
            }
            i -= 1;
        }
    }

    private func VanishHiding(npc: ref<ScriptedPuppet>, candidate: ref<GRCandidate>) -> Bool {
        let gi: GameInstance = this.GetGameInstance();
        let spawner: ref<GRSpawner> = GRSpawner.Get(gi);
        if IsDefined(spawner) && spawner.IsOwnSpawn(candidate.entityID) {
            this.PromoteFled(candidate);
            spawner.Vanish(candidate.entityID);
            this.Debug("Escondido desaparece tras perderse de vista 3 s (spawn propio): " + candidate.gang);
            return true;
        }
        let pos: Vector4 = GRHidingDespawnSpot();
        GameInstance.GetTeleportationFacility(gi).Teleport(npc, pos, Vector4.ToRotation(new Vector4(1.0, 0.0, 0.0, 0.0)));
        // Teleport() only moves the entity - it doesn't touch the AI controller, so a community/workspot
        // goal still active from before (e.g. "go back to your assigned spot") can walk the NPC right back
        // the next tick. Pin it at the new spot with an explicit move command, the same trick Hide() uses
        // to freeze non-native-flee NPCs in place, so nothing steers it away before it's cleaned up.
        let puppet: ref<NPCPuppet> = npc as NPCPuppet;
        if IsDefined(puppet) {
            GRMoveTo(puppet, pos, moveMovementType.Walk, 0.5);
        }
        // 2026-11-22: this used to stop here, leaving the NPC alive forever at the Badlands spot - the
        // reported bug ("doesn't disappear, comes back knocked out after a save load"). Checked the vanilla
        // script dump for a safer native despawn call scoped to a non-dynamically-spawned NPC first:
        // CommunitySystem (the real owner of a wild gang NPC's spawn slot) exposes no per-entity despawn
        // method to script at all, and the only two that exist anywhere (PreventionSpawnSystem.RequestDespawn,
        // CompanionSystem.DespawnSubcharacter) are both hard-scoped to NCPD units / unique companions, not
        // generic gang mooks. No safer alternative exists, so this now does what own-spawn already does
        // successfully (see GRSpawner.Vanish, same DeleteEntity call) - deferred a few seconds past the pin
        // so it's not deleted out from under its own still-finishing move command. Not yet confirmed in game.
        GRDetectionCall.SendDelayed(gi, GRDetectionCall.DespawnVanished(), candidate.entityID, 3.0);
        this.PromoteFled(candidate);
        this.Debug("Escondido desaparece tras perderse de vista 3 s: " + candidate.gang);
        return true;
    }

    public func IsRunningAway(id: EntityID) -> Bool {
        if IsDefined(this.FindHiding(id)) {
            return true;
        }
        for candidate in this.m_fleeing {
            if candidate.entityID == id {
                return true;
            }
        }
        return false;
    }

    private func FindHiding(id: EntityID) -> ref<GRCandidate> {
        for candidate in this.m_hiding {
            if candidate.entityID == id {
                return candidate;
            }
        }
        return null;
    }

    private func SayFleeLine(npc: ref<ScriptedPuppet>, gang: String) {
        let loc: ref<GRSystem> = GRSystem.Get(this.GetGameInstance());
        if !IsDefined(loc) {
            return;
        }
        let line: String = loc.GetText("GR-Flee-" + IntToString(RandRange(1, 9)));
        GRSpeech.Say(npc, loc.GetText("GR-Gang-" + gang), line, 5.0);
    }

    public func UpdateFleeing() {
        this.RunPendingFlee();
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let i: Int32 = ArraySize(this.m_fleeing) - 1;
        while i >= 0 {
            let candidate: ref<GRCandidate> = this.m_fleeing[i];
            let npc: ref<ScriptedPuppet> = GameInstance.FindEntityByID(this.GetGameInstance(), candidate.entityID) as ScriptedPuppet;
            let done: Bool = false;
            if !IsDefined(npc) {
                if candidate.ddSpawn {
                    this.Debug("Huida descartada: Drug Dealer borro a su NPC (" + candidate.gang + ")");
                } else {
                    this.PromoteFled(candidate);
                }
                done = true;
            } else {
                if GRDetection.IsNeutralized(npc) {
                    this.Debug("Huida abandonada: neutralizado por otra via, nunca llego a esconderse (" + candidate.gang + ")");
                    done = true;
                } else {
                    candidate.health = this.GetHealthPercent(npc);
                    candidate.position = npc.GetWorldPosition();
                    candidate.limbsMissing = GRDetection.HasMissingLimb(npc);
                    let distance: Float = IsDefined(player) ? Vector4.Distance(npc.GetWorldPosition(), player.GetWorldPosition()) : 0.0;
                    let elapsed: Float = this.Now() - this.m_fleeStart[i];
                    let run: Float = Vector4.Distance(npc.GetWorldPosition(), candidate.fleeOrigin);
                    let ownSpawn: Bool = this.IsOwnSpawn(candidate.entityID);
                    let sees: Bool = this.PlayerSees(npc);
                    if sees {
                        candidate.unseen = 0.0;
                    } else {
                        candidate.unseen += 1.0;
                    }
                    this.Debug("Huida en curso: " + candidate.gang + " (spawn propio=" + (ownSpawn ? "si" : "no") + ") visto=" + (sees ? "si" : "no")
                        + " sin ver=" + FloatToString(candidate.unseen) + "s distancia a V=" + FloatToString(distance)
                        + "m recorrido=" + FloatToString(run) + "m transcurrido=" + FloatToString(elapsed) + "s");
                    if ownSpawn {
                        if (candidate.unseen >= 3.0 && distance > 25.0) || distance > 50.0 {
                            this.PromoteFled(candidate);
                            done = true;
                        } else {
                            if elapsed > 60.0 {
                                this.StopFlee(npc, candidate, "no pudo perderse de vista en 60 s");
                                done = true;
                            }
                        }
                    } else {
                        if run > 50.0 || elapsed > 25.0 {
                            this.Hide(npc, candidate);
                            done = true;
                        }
                    }
                }
            }
            if done {
                ArrayErase(this.m_fleeing, i);
                ArrayErase(this.m_fleeStart, i);
            }
            i -= 1;
        }
        this.UpdateHiding();
    }

    private func VanishFleeing(id: EntityID) {
        let index: Int32 = -1;
        let i: Int32 = 0;
        while i < ArraySize(this.m_fleeing) && index < 0 {
            if this.m_fleeing[i].entityID == id {
                index = i;
            }
            i += 1;
        }
        if index < 0 {
            return;
        }
        let candidate: ref<GRCandidate> = this.m_fleeing[index];
        ArrayErase(this.m_fleeing, index);
        ArrayErase(this.m_fleeStart, index);
        candidate.fleeing = false;
        let npc: ref<ScriptedPuppet> = this.FindPuppet(id);
        if !IsDefined(npc) {
            if !candidate.ddSpawn {
                this.PromoteFled(candidate);
            }
            return;
        }
        if GRDetection.IsNeutralized(npc) {
            return;
        }
        candidate.health = this.GetHealthPercent(npc);
        candidate.position = npc.GetWorldPosition();
        candidate.limbsMissing = GRDetection.HasMissingLimb(npc);
        let gi: GameInstance = this.GetGameInstance();
        let spawner: ref<GRSpawner> = GRSpawner.Get(gi);
        if IsDefined(spawner) && spawner.IsOwnSpawn(id) {
            this.PromoteFled(candidate);
            spawner.Vanish(id);
            this.Debug("Desaparece con flash (spawn propio): " + candidate.gang);
            return;
        }
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        if IsDefined(player) {
            let pos: Vector4;
            if GRSafeTeleportSpot(npc, player, 80.0, pos) {
                GameInstance.GetTeleportationFacility(gi).Teleport(npc, pos, Vector4.ToRotation(pos - player.GetWorldPosition()));
                GRLog("Huida con flash: teletransporte validado a " + FloatToString(Vector4.Distance(pos, player.GetWorldPosition())) + " m de V");
            }
        }
        ArrayPush(this.m_hiding, candidate);
        this.PromoteFled(candidate);
        this.Debug("Desaparece con flash (del mundo, a " + FloatToString(this.DistanceToPlayer(npc)) + " m): " + candidate.gang);
    }

    public func GetFleeMode() -> Int32 {
        return this.m_fleeMode;
    }

    public func SetFleeMode(mode: Int32) {
        this.m_fleeMode = mode;
    }

    public func HandleCall(kind: Int32, id: EntityID) {
        if kind == GRDetectionCall.CombatEnded() {
            this.OnPlayerCombatEnded();
            return;
        }
        if kind == GRDetectionCall.NPCDeath() || kind == GRDetectionCall.NPCDeathByV() {
            this.OnNPCDeath(id, kind == GRDetectionCall.NPCDeathByV());
            return;
        }
        if kind == GRDetectionCall.RunFlee() {
            this.RunPendingFlee();
            return;
        }
        if kind == GRDetectionCall.RunDisarmedFlee() {
            this.RunDisarmedFlee(id);
            return;
        }
        if kind == GRDetectionCall.Vanish() {
            this.VanishFleeing(id);
            return;
        }
        if kind == GRDetectionCall.Unblind() {
            let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
            if IsDefined(player) {
                StatusEffectHelper.RemoveStatusEffect(player, GRBlindEffect());
            }
            return;
        }
        if kind == GRDetectionCall.DespawnVanished() {
            // Guard against a stale/already-gone id (e.g. the entity unloaded on its own in the meantime)
            // the same way GRSafeTeleportSpot's own callers already do elsewhere - DeleteEntity on a bad id
            // is untested territory, so don't hand it one if we can avoid it.
            if GameInstance.FindEntityByID(this.GetGameInstance(), id) != null {
                GameInstance.GetDynamicEntitySystem().DeleteEntity(id);
                this.Debug("Escondido (fuera del mundo) finalmente eliminado");
            } else {
                this.Debug("Escondido (fuera del mundo): ya no existia al llegar la eliminacion diferida, nada que borrar");
            }
            return;
        }
        let npc: ref<ScriptedPuppet> = this.FindPuppet(id);
        if !IsDefined(npc) {
            return;
        }
        if kind == GRDetectionCall.PlayerHitNPC() {
            this.OnPlayerHitNPC(npc, false);
        } else {
            if kind == GRDetectionCall.NPCHitPlayer() {
                this.OnNPCHitPlayer(npc);
            } else {
                if kind == GRDetectionCall.PlayerTakedownNPC() {
                    this.OnPlayerHitNPC(npc, true);
                }
            }
        }
    }

    private func OnPlayerHitNPC(npc: ref<ScriptedPuppet>, forceKnockout: Bool) {
        let hiding: ref<GRCandidate> = this.FindHiding(npc.GetEntityID());
        if IsDefined(hiding) {
            hiding.discovered = true;
        }
        if !this.IsEnabled() || !GRDetection.IsEligible(npc) || GRDetection.IsPlayerAlly(npc) || this.WasPromoted(npc.GetEntityID())
            || GRIntegrations.IsDDAlly(npc.GetEntityID()) {
            return;
        }
        this.AddCombatant(npc.GetEntityID());
        let intel: ref<GRIntelSystem> = GRIntelSystem.Get(this.GetGameInstance());
        if IsDefined(intel) {
            intel.NoteCombatant(npc);
            let settings: ref<GRSettings> = GRSettings.Get(this.GetGameInstance());
            let fleeBase: Int32 = IsDefined(settings) ? settings.fleeHealthPercent : 35;
            let threshold: Float = GRIntegrations.GetFleePercent(fleeBase);
            let health: Float = forceKnockout ? threshold : this.GetHealthPercent(npc);
            intel.TryKnockOut(npc, health, threshold);
        }
        this.UpsertCandidate(npc);
        this.CheckLastStanding();
        this.CheckDisarmedFlee(npc);
    }

    private func OnNPCHitPlayer(npc: ref<ScriptedPuppet>) {
        if this.IsEnabled() && GRDetection.IsEligible(npc) && !GRIntegrations.IsDDAlly(npc.GetEntityID()) {
            this.AddCombatant(npc.GetEntityID());
        }
    }

    private func OnNPCDeath(id: EntityID, byPlayer: Bool) {
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());
        if IsDefined(spawner) {
            let nemesisId: Int32 = spawner.GetNemesisId(id);
            if byPlayer && nemesisId > 0 {
                spawner.RecordHitBy(nemesisId, "v");
            }
            spawner.MarkDead(id);
        }
        let intel: ref<GRIntelSystem> = GRIntelSystem.Get(this.GetGameInstance());
        if IsDefined(intel) {
            intel.OnNPCDeath(id);
        }
        // 2026-11-19, user's call: a kill now has the same shot at the intel shard a knockout does, with
        // the same broad eligibility OnPlayerHitNPC uses for knockouts (any eligible gang NPC, not just an
        // already-promoted Nemesis) - `byPlayer` alone is only a direct-instigator check (see its wrap
        // above, OnDeath), the same narrow gap already documented for indirect knockouts, so it's OR'd
        // with GRSpawner's broader KilledByPlayer (vehicle rams, ForceKill, grapple) via WasKilledByPlayer.
        let deadNpc: ref<ScriptedPuppet> = GameInstance.FindEntityByID(this.GetGameInstance(), id) as ScriptedPuppet;
        if IsDefined(deadNpc) && IsDefined(intel) && this.IsEnabled() && GRDetection.IsEligible(deadNpc)
            && !GRDetection.IsPlayerAlly(deadNpc) && !GRIntegrations.IsDDAlly(id) {
            let killedByV: Bool = byPlayer || (IsDefined(spawner) && spawner.WasKilledByPlayer(deadNpc));
            if killedByV {
                intel.TryIntelOnDeath(deadNpc);
            }
        }
        let index: Int32 = this.FindCandidate(id);
        if index >= 0 {
            ArrayErase(this.m_candidates, index);
        }
        let f: Int32 = 0;
        while f < ArraySize(this.m_fleeing) {
            if this.m_fleeing[f].entityID == id {
                ArrayErase(this.m_fleeing, f);
                ArrayErase(this.m_fleeStart, f);
                f = ArraySize(this.m_fleeing);
            }
            f += 1;
        }
        let h: Int32 = ArraySize(this.m_hiding) - 1;
        while h >= 0 {
            if this.m_hiding[h].entityID == id {
                ArrayErase(this.m_hiding, h);
            }
            h -= 1;
        }
        if this.IsEnabled() {
            this.CheckLastStanding();
        }
    }

    private func OnPlayerCombatEnded() {
        if !this.IsEnabled() {
            this.ResetFight();
            return;
        }

        if this.IsPlayerDead() {
            this.Debug("Fin de combate por muerte de V: sin huidas");
            return;
        }
        let settings: ref<GRSettings> = GRSettings.Get(this.GetGameInstance());
        let threshold: Float = Cast<Float>(settings.escapeHealthPercent);
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());

        let i: Int32 = 0;
        while i < ArraySize(this.m_candidates) {
            let candidate: ref<GRCandidate> = this.m_candidates[i];
            let npc: ref<ScriptedPuppet>;
            if IsDefined(candidate) {
                npc = GameInstance.FindEntityByID(this.GetGameInstance(), candidate.entityID) as ScriptedPuppet;
            }
            if IsDefined(npc) && !npc.IsDead() && !GRDetection.IsPlayerAlly(npc) {
                candidate.health = this.GetHealthPercent(npc);
                candidate.position = npc.GetWorldPosition();
                candidate.limbsMissing = GRDetection.HasMissingLimb(npc);
                candidate.wasAware = candidate.wasAware || GRDetection.IsAwareOfPlayer(npc, GetPlayer(this.GetGameInstance()));
                let unconscious: Bool = ScriptedPuppet.IsDefeated(npc) || ScriptedPuppet.IsUnconscious(npc);

                let msg: String = "Fin de combate: ";
                msg += candidate.gang;
                msg += " vida ";
                msg += FloatToString(candidate.health);
                msg += "%";
                if candidate.fleeing {
                    msg += " (huyendo)";
                }
                if unconscious {
                    msg += " (inconsciente)";
                    if !candidate.wasAware {
                        msg += " (sigiloso, no vio a V)";
                    }
                }
                this.Debug(msg);

                let pacified: Bool = IsDefined(spawner) && spawner.IsLeftover(candidate.entityID) && !candidate.fled;
                if unconscious {
                    if !pacified && candidate.wasAware {
                        if RandRange(0, 100) < settings.knockoutChancePercent {
                            this.Promote(candidate, "knockedout");
                        } else {
                            this.Debug("Derribo: tirada fallida (" + IntToString(settings.knockoutChancePercent) + "%), no se registra: " + candidate.gang);
                        }
                    } else {
                        if !pacified && !candidate.wasAware {
                            this.Debug("Derribo sigiloso: no se registra (nunca vio a V, nemesisId=" + IntToString(candidate.nemesisId) + "): " + candidate.gang);
                        }
                    }
                } else if !pacified && !candidate.fleeing && candidate.health > 0.0 && (candidate.health <= threshold || candidate.fled) {
                    if candidate.fled {
                        this.PromoteFled(candidate);
                    } else {
                        this.Promote(candidate, candidate.limbsMissing ? "escapeddismembered" : "escaped");
                    }
                }
            }
            i += 1;
        }
        this.ResetFight();
    }

    private func GetLookAtNPC() -> ref<ScriptedPuppet> {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let target: ref<ScriptedPuppet> = GameInstance.GetTargetingSystem(this.GetGameInstance()).GetLookAtObject(player, false, false) as ScriptedPuppet;
        if !GRDetection.IsEligible(target) {
            GRLog("Debug: el objetivo no es un pandillero valido");
            return null;
        }
        return target;
    }

    public func DebugPromoteLookAt() -> Bool {
        let target: ref<ScriptedPuppet> = this.GetLookAtNPC();
        if !IsDefined(target) {
            return false;
        }
        this.Promote(this.MakeCandidate(target), "debug");
        return true;
    }

    public func DebugFleeLookAt() -> Bool {
        let target: ref<ScriptedPuppet> = this.GetLookAtNPC();
        if !IsDefined(target) {
            return false;
        }
        this.AddCombatant(target.GetEntityID());
        this.MakeFleeMode(target, this.m_fleeMode, "debug");
        return true;
    }

    private func PromoteFled(candidate: ref<GRCandidate>) {
        this.Promote(candidate, candidate.limbsMissing ? "fleddismembered" : "fled");
    }

    private func Promote(candidate: ref<GRCandidate>, origin: String) {
        if this.WasPromoted(candidate.entityID) {
            return;
        }
        ArrayPush(this.m_promoted, candidate.entityID);

        let evt: ref<GRNemesisEvent> = new GRNemesisEvent();
        evt.origin = origin;
        evt.nemesisId = candidate.nemesisId;
        evt.gang = candidate.gang;
        evt.recordID = TDBID.ToStringDEBUG(candidate.recordID);
        evt.appearance = NameToString(candidate.appearance);
        evt.gender = NameToString(candidate.gender);
        evt.health = candidate.health;
        evt.posX = candidate.position.X;
        evt.posY = candidate.position.Y;
        evt.posZ = candidate.position.Z;
        evt.limbsMissing = candidate.limbsMissing;
        if Equals(origin, "knockedout") {
            let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());
            if IsDefined(spawner) {
                evt.ownSpawn = spawner.IsOwnSpawn(candidate.entityID);
            }
        }
        ArrayPush(this.m_pending, evt);
        GRLog("Nuevo Nemesis (" + origin + "): " + evt.gang + " " + evt.recordID);
    }

    public func GetPendingCount() -> Int32 {
        return ArraySize(this.m_pending);
    }

    public func GetPending(index: Int32) -> ref<GRNemesisEvent> {
        return this.m_pending[index];
    }

    public func ClearPending() {
        ArrayClear(this.m_pending);
    }

    public func GetFightGangs() -> String {
        let result: String = "";
        for combatant in this.m_combatants {
            let npc: ref<ScriptedPuppet> = this.FindPuppet(combatant);
            if IsDefined(npc) {
                let gang: String = GRDetection.GetGang(npc);
                if StrLen(gang) > 0 && !StrContains(result, gang) {
                    result += (StrLen(result) > 0 ? "," : "") + gang;
                }
            }
        }
        return result;
    }

    public func GetCandidateCount() -> Int32 {
        return ArraySize(this.m_candidates);
    }

    public func CanNotify() -> Bool {
        let gi: GameInstance = this.GetGameInstance();
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        if !IsDefined(player) {
            return false;
        }
        let tier: Int32 = player.GetPlayerStateMachineBlackboard().GetInt(GetAllBlackboardDefs().PlayerStateMachine.HighLevel);
        if tier >= 3 && tier <= 5 {
            return false;
        }
        if GameInstance.GetBlackboardSystem(gi).Get(GetAllBlackboardDefs().UI_System).GetBool(GetAllBlackboardDefs().UI_System.IsInMenu) {
            return false;
        }
        let bd: ref<BraindanceSystem> = GameInstance.GetScriptableSystemsContainer(gi).Get(n"BraindanceSystem") as BraindanceSystem;
        if IsDefined(bd) && bd.GetIsInBraindance() {
            return false;
        }
        return true;
    }

    public func Notify(text: String) {
        let settings: ref<GRSettings> = GRSettings.Get(this.GetGameInstance());
        if !IsDefined(settings) || !settings.notifyCenter {
            GameInstance.GetActivityLogSystem(this.GetGameInstance()).AddLog(text);
            return;
        }
        let msg: SimpleScreenMessage;
        msg.isShown = true;
        msg.duration = 6.0;
        msg.message = text;
        let defs = GetAllBlackboardDefs();
        GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(defs.UI_Notifications).SetVariant(defs.UI_Notifications.WarningMessage, ToVariant(msg), true);
    }
}

public class GRDetectionCall extends DelayCallback {
    public let gi: GameInstance;
    public let kind: Int32;
    public let entityID: EntityID;

    public static func PlayerHitNPC() -> Int32 { return 0; }
    public static func NPCHitPlayer() -> Int32 { return 1; }
    public static func NPCDeath() -> Int32 { return 2; }
    public static func CombatEnded() -> Int32 { return 3; }
    public static func RunFlee() -> Int32 { return 4; }
    public static func Vanish() -> Int32 { return 5; }
    public static func Unblind() -> Int32 { return 6; }
    public static func NPCDeathByV() -> Int32 { return 7; }
    public static func PlayerTakedownNPC() -> Int32 { return 8; }
    public static func RunDisarmedFlee() -> Int32 { return 9; }
    public static func DespawnVanished() -> Int32 { return 10; }

    public static func Send(gi: GameInstance, kind: Int32, id: EntityID) {
        GRDetectionCall.SendDelayed(gi, kind, id, 0.0);
    }

    public static func SendDelayed(gi: GameInstance, kind: Int32, id: EntityID, delay: Float) {
        let call: ref<GRDetectionCall> = new GRDetectionCall();
        call.gi = gi;
        call.kind = kind;
        call.entityID = id;
        GameInstance.GetDelaySystem(gi).DelayCallback(call, delay, false);
    }

    public func Call() -> Void {
        let det: ref<GRDetection> = GRDetection.Get(this.gi);
        if IsDefined(det) {
            det.HandleCall(this.kind, this.entityID);
        }
    }
}

public func GRBlindEffect() -> TweakDBID {
    let glitch: TweakDBID = t"AIQuickHackStatusEffect.HackBlind";
    if IsDefined(TweakDBInterface.GetStatusEffectRecord(glitch)) {
        return glitch;
    }
    return t"BaseStatusEffect.Blind";
}

@addMethod(ReactionManagerComponent)
public func GRForceFlee(threat: ref<GameObject>) -> Bool {
    let owner: ref<GameObject> = this.GetOwner();
    if !IsDefined(owner) || !IsDefined(threat) {
        return false;
    }
    let game: GameInstance = owner.GetGame();
    this.DeactiveLookAt();
    GameInstance.GetDelaySystem(game).CancelDelay(this.m_resetReactionDataID);
    let reaction: ref<AIReactionData> = new AIReactionData();
    reaction.reactionBehaviorName = gamedataOutput.Flee;
    reaction.stimTarget = threat;
    reaction.stimSource = threat.GetWorldPosition();
    reaction.stimType = gamedataStimType.Terror;
    reaction.stimRecord = GameInstance.GetStimuliSystem(game).GetStimRecord(gamedataStimType.Terror);
    reaction.reactionPriority = 9;
    reaction.reactionBehaviorAIPriority = 7.0;
    reaction.skipInitialAnimation = true;
    if this.IsInPendingBehavior() {
        reaction.validTillTimeStamp = EngineTime.ToFloat(GameInstance.GetSimTime(game)) + 10.0;
        this.m_pendingReaction = reaction;
        this.m_desiredReaction = null;
        return true;
    }
    this.m_desiredReaction = reaction;
    let trigger: ref<StimuliEvent> = new StimuliEvent();
    trigger.SetStimType(gamedataStimType.Invalid);
    trigger.name = n"triggerReaction";
    owner.QueueEvent(trigger);
    NPCPuppet.ChangeHighLevelState(owner, gamedataNPCHighLevelState.Fear);
    AnimationControllerComponent.SetAnimWrapperWeightOnOwnerAndItems(owner, n"panic", 1.0);
    if !this.m_fearLocomotionWrapper {
        AnimationControllerComponent.SetAnimWrapperWeightOnOwnerAndItems(owner, this.GetRandomFearLocomotionAnimWrapper(3), 1.0);
        this.m_fearLocomotionWrapper = true;
    }
    return true;
}

@addMethod(ReactionManagerComponent)
public func GRStopFlee() -> Void {
    this.m_desiredReaction = null;
    this.m_pendingReaction = null;
    this.ResetAllFearAnimWrappers();
    let blackboard: ref<IBlackboard> = this.GetPuppetReactionBlackboard();
    if IsDefined(blackboard) {
        blackboard.SetBool(GetAllBlackboardDefs().PuppetReaction.exitReactionFlag, true);
    }
}

public func GRMoveTo(puppet: ref<NPCPuppet>, pos: Vector4, type: moveMovementType, distance: Float) {
    if !IsDefined(puppet) || !IsDefined(puppet.GetAIControllerComponent()) || Vector4.IsZero(pos) {
        return;
    }
    let wp: WorldPosition;
    WorldPosition.SetVector4(wp, pos);
    let target: AIPositionSpec;
    AIPositionSpec.SetWorldPosition(target, wp);
    let move: ref<AIMoveToCommand> = new AIMoveToCommand();
    move.movementTarget = target;
    move.movementType = type;
    move.ignoreNavigation = false;
    move.finishWhenDestinationReached = true;
    move.desiredDistanceFromTarget = distance;
    puppet.GetAIControllerComponent().SendCommand(move);
}

public func GRAwayFrom(npc: ref<GameObject>, player: ref<GameObject>, distance: Float) -> Vector4 {
    let offset: Vector4 = npc.GetWorldPosition() - player.GetWorldPosition();
    offset.Z = 0.0;
    if Vector4.Length(offset) < 0.5 {
        offset = player.GetWorldForward();
    }
    let away: Vector4 = Vector4.Normalize(offset);
    let from: Vector4 = npc.GetWorldPosition();
    let nav: ref<NavigationSystem> = GameInstance.GetNavigationSystem(npc.GetGame());
    let scales: array<Float> = [1.0, 0.7, 0.45];
    let angles: array<Float> = [0.0, 30.0, -30.0, 60.0, -60.0];
    if IsDefined(nav) {
        for scale in scales {
            for angle in angles {
                let dir: Vector4 = Vector4.RotateAxis(away, new Vector4(0.0, 0.0, 1.0, 0.0), angle / 180.0 * Pi());
                let raw: Vector4 = from + dir * (distance * scale);
                let pos: Vector4 = nav.GetNearestNavmeshPointBelowOnlyHumanNavmesh(raw + new Vector4(0.0, 0.0, 2.0, 0.0), 2.0, 6);
                if !Vector4.IsZero(pos) && AbsF(pos.Z - from.Z) < 6.0 {
                    return pos;
                }
            }
        }
    }
    GRLog("Alejarse de V: sin destino valido en el navmesh, no se mueve (a " + FloatToString(Vector4.Distance(from, player.GetWorldPosition())) + " m de V)");
    return Vector4.EmptyVector();
}

// Badlands plateau north of the Corpo Plaza border, well outside normal player reach (2D terrain/no real navmesh there).
// Fixed destination for disappearing a hiding, non-own-spawn NPC we can't safely delete outright - see NOTES.md.
public func GRHidingDespawnSpot() -> Vector4 {
    return new Vector4(4256.35, 1178.81, 146.85, 1.0);
}

public func GRSafeTeleportSpot(npc: ref<GameObject>, player: ref<PlayerPuppet>, distance: Float, out spot: Vector4) -> Bool {
    let gi: GameInstance = npc.GetGame();
    let nav: ref<NavigationSystem> = GameInstance.GetNavigationSystem(gi);
    let spawner: ref<GRSpawner> = GRSpawner.Get(gi);
    if !IsDefined(nav) || !IsDefined(spawner) {
        GRLog("Huida con flash: sin sistema de navegacion, no se teletransporta");
        return false;
    }
    let offset: Vector4 = npc.GetWorldPosition() - player.GetWorldPosition();
    offset.Z = 0.0;
    if Vector4.Length(offset) < 0.5 {
        offset = player.GetWorldForward();
    }
    let away: Vector4 = Vector4.Normalize(offset);
    let from: Vector4 = npc.GetWorldPosition();
    let scales: array<Float> = [1.0, 0.7, 0.45];
    let angles: array<Float> = [0.0, 30.0, -30.0, 60.0, -60.0];
    let fails: array<Int32> = [0, 0, 0, 0, 0];
    for scale in scales {
        for angle in angles {
            let dir: Vector4 = Vector4.RotateAxis(away, new Vector4(0.0, 0.0, 1.0, 0.0), angle / 180.0 * Pi());
            let raw: Vector4 = from + dir * (distance * scale);
            let pos: Vector4 = nav.GetNearestNavmeshPointBelowOnlyHumanNavmesh(raw + new Vector4(0.0, 0.0, 2.0, 0.0), 2.0, 6);
            if Vector4.IsZero(pos) {
                fails[0] += 1;
            } else {
                if AbsF(pos.Z - from.Z) > 3.0 {
                    fails[1] += 1;
                } else {
                    if !spawner.IsClearSpot(pos) {
                        fails[2] += 1;
                    } else {
                        if spawner.HasLineOfSight(player, pos) {
                            fails[3] += 1;
                        } else {
                            let walkable: Bool = false;
                            let path: ref<NavigationPath> = nav.CalculatePathOnlyHumanNavmesh(from, pos, NavGenAgentSize.Human, 1.0);
                            if IsDefined(path) && ArraySize(path.path) >= 2 {
                                let last: Vector4 = path.path[ArraySize(path.path) - 1];
                                walkable = Vector4.Distance(last, pos) < 3.0 && path.CalculateLength() < Vector4.Distance(from, pos) * 2.0 + 10.0;
                            }
                            if !walkable {
                                fails[4] += 1;
                            } else {
                                spot = pos;
                                return true;
                            }
                        }
                    }
                }
            }
        }
    }
    GRLog("Huida con flash: puntos descartados, sin destino seguro; no se teletransporta (sin navmesh=" + IntToString(fails[0])
        + ", otro piso=" + IntToString(fails[1]) + ", pared=" + IntToString(fails[2]) + ", a la vista=" + IntToString(fails[3])
        + ", sin camino=" + IntToString(fails[4]) + ")");
    return false;
}


@wrapMethod(HitReactionComponent)
public func EvaluateHit(newHitEvent: ref<gameHitEvent>) -> Void {
    wrappedMethod(newHitEvent);
    if !IsDefined(newHitEvent) || !IsDefined(newHitEvent.attackData) {
        return;
    }

    if IsDefined(newHitEvent.target as PlayerPuppet) {
        let attacker: ref<ScriptedPuppet> = newHitEvent.attackData.GetInstigator() as ScriptedPuppet;
        if IsDefined(attacker) && GRDetection.IsEligible(attacker) {
            GRDetectionCall.Send(attacker.GetGame(), GRDetectionCall.NPCHitPlayer(), attacker.GetEntityID());
        }
        return;
    }

    if IsDefined(newHitEvent.attackData.GetInstigator() as PlayerPuppet) {
        let npc: ref<ScriptedPuppet> = newHitEvent.target as ScriptedPuppet;
        if IsDefined(npc) && GRDetection.IsEligible(npc) {
            GRDetectionCall.Send(npc.GetGame(), GRDetectionCall.PlayerHitNPC(), npc.GetEntityID());
        }
    }
}

@wrapMethod(LocomotionTakedownEvents)
private final func DefeatTarget(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>, activator: wref<GameObject>, target: wref<GameObject>, effectName: CName, effectTag: CName) -> Void {
    wrappedMethod(stateContext, scriptInterface, activator, target, effectName, effectTag);
    let npc: ref<ScriptedPuppet> = target as ScriptedPuppet;
    if IsDefined(npc) && IsDefined(activator as PlayerPuppet) && GRDetection.IsEligible(npc) {
        let nonLethal: Bool = StrContains(NameToString(effectTag), "Unconscious");
        GRDetectionCall.Send(npc.GetGame(), nonLethal ? GRDetectionCall.PlayerTakedownNPC() : GRDetectionCall.PlayerHitNPC(), npc.GetEntityID());
    }
}

@wrapMethod(NPCPuppet)
protected cb func OnDeath(evt: ref<gameDeathEvent>) -> Bool {
    let byPlayer: Bool = IsDefined(evt) && IsDefined(evt.instigator) && evt.instigator.IsPlayer();
    GRDetectionCall.Send(this.GetGame(), byPlayer ? GRDetectionCall.NPCDeathByV() : GRDetectionCall.NPCDeath(), this.GetEntityID());
    return wrappedMethod(evt);
}

@wrapMethod(PlayerPuppet)
protected cb func OnCombatStateChanged(newState: Int32) -> Bool {
    let wasInCombat: Bool = this.IsInCombat();
    let result: Bool = wrappedMethod(newState);
    if wasInCombat && newState != 1 {
        GRDetectionCall.Send(this.GetGame(), GRDetectionCall.CombatEnded(), this.GetEntityID());
    }
    return result;
}
