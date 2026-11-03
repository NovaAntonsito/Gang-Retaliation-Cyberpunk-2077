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
    // Ya huyo en esta pelea (aunque StopFlee lo haya hecho volver): si sobrevive, escapo.
    public let fled: Bool;
    // Generado por Drug Dealer: si desaparece, lo borro DD (Purge), no escapo.
    public let ddSpawn: Bool;
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
}

public class GRDetection extends ScriptableSystem {
    private let m_candidates: array<ref<GRCandidate>>;
    private let m_pending: array<ref<GRNemesisEvent>>;

    private let m_promoted: array<EntityID>;

    // IDs y no referencias: un NPC a medio descargar deja una referencia rota; el ID se busca cada vez.
    private let m_combatants: array<EntityID>;

    private let m_someoneFled: Bool;

    private let m_fleeing: array<ref<GRCandidate>>;
    private let m_fleeStart: array<Float>;

    private let m_fleeMode: Int32;

    private let m_pendingFlee: EntityID;
    private let m_hasPendingFlee: Bool;

    public static func Get(gi: GameInstance) -> ref<GRDetection> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRDetection") as GRDetection;
    }

    private func OnAttach() {
        this.m_fleeMode = 2;
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
        if IsDefined(record) && IsDefined(record.Rarity()) {
            let rarity: gamedataNPCRarity = record.Rarity().Type();
            if Equals(rarity, gamedataNPCRarity.Boss) || Equals(rarity, gamedataNPCRarity.MaxTac) {
                return false;
            }
        }
        return NotEquals(GRDetection.GetGang(npc), "");
    }

    public static func IsNeutralized(npc: ref<ScriptedPuppet>) -> Bool {
        return !IsDefined(npc) || npc.IsDead() || ScriptedPuppet.IsDefeated(npc) || ScriptedPuppet.IsUnconscious(npc);
    }

    private func GetHealthPercent(npc: ref<ScriptedPuppet>) -> Float {
        return GameInstance.GetStatPoolsSystem(this.GetGameInstance()).GetStatPoolValue(Cast<StatsObjectID>(npc.GetEntityID()), gamedataStatPoolType.Health, true);
    }

    private func IsEnabled() -> Bool {
        let settings: ref<GRSettings> = GRSettings.Get(this.GetGameInstance());
        return !IsDefined(settings) || settings.enabled;
    }

    private func Debug(msg: String) {
        let settings: ref<GRSettings> = GRSettings.Get(this.GetGameInstance());
        if IsDefined(settings) && settings.debugLog {
            GRLog(msg);
        }
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
        return candidate;
    }

    private func UpsertCandidate(npc: ref<ScriptedPuppet>) -> ref<GRCandidate> {
        let index: Int32 = this.FindCandidate(npc.GetEntityID());
        if index >= 0 {
            let candidate: ref<GRCandidate> = this.m_candidates[index];
            candidate.health = this.GetHealthPercent(npc);
            candidate.position = npc.GetWorldPosition();
            return candidate;
        }
        let created: ref<GRCandidate> = this.MakeCandidate(npc);
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
        let health: Float = this.GetHealthPercent(last);
        if health > 0.0 && health <= Cast<Float>(settings.fleeHealthPercent) {
            this.m_someoneFled = true;
            this.m_pendingFlee = last.GetEntityID();
            this.m_hasPendingFlee = true;
        }
    }

    // "" = este pandillero puede huir si queda ultimo en pie. Lo usan la huida y la linea de huida del HUD.
    public func GetFleeBlocker(npc: ref<ScriptedPuppet>) -> String {
        let gi: GameInstance = this.GetGameInstance();
        let settings: ref<GRSettings> = GRSettings.Get(gi);
        if !IsDefined(settings) || !settings.enabled || !settings.lastManFlees {
            return "disabled";
        }
        if !GRDetection.IsEligible(npc) || GRDetection.IsNeutralized(npc) {
            return "not eligible";
        }
        let spawner: ref<GRSpawner> = GRSpawner.Get(gi);
        if IsDefined(spawner) && spawner.IsRaidActive() {
            return "raid";
        }
        if VehicleComponent.IsMountedToVehicle(gi, npc) || VehicleComponent.IsMountedToVehicle(gi, GetPlayer(gi)) {
            return "vehicle";
        }
        // Los generados por el mod (escoltas de emboscada) nunca son de una mision: la mision seguida no los frena.
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
        this.MakeFlee(npc);
    }

    private func Now() -> Float {
        return EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
    }

    private func MakeFlee(npc: ref<ScriptedPuppet>) {
        if !IsDefined(npc) || !npc.IsAttached() || VehicleComponent.IsMountedToVehicle(this.GetGameInstance(), npc) {
            return;
        }
        this.m_someoneFled = true;
        let candidate: ref<GRCandidate> = this.UpsertCandidate(npc);
        candidate.fleeing = true;
        candidate.fled = true;
        ArrayPush(this.m_fleeing, candidate);
        ArrayPush(this.m_fleeStart, this.Now());

        let puppet: ref<NPCPuppet> = npc as NPCPuppet;
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        // NPCs del mundo (pueden ser de una mision): sin estado de miedo, que hace que el juego los
        // descargue. Solo corren y se esconden.
        let ownSpawn: Bool = this.IsOwnSpawn(npc.GetEntityID());
        let mode: Int32 = ownSpawn ? this.m_fleeMode : 0;
        if IsDefined(puppet) && IsDefined(player) && IsDefined(puppet.GetAttitudeAgent()) && IsDefined(puppet.GetAIControllerComponent()) {
            if mode == 0 || mode == 2 {
                puppet.GetAttitudeAgent().SetAttitudeTowards(player.GetAttitudeAgent(), EAIAttitude.AIA_Neutral);
                let offset: Vector4 = npc.GetWorldPosition() - player.GetWorldPosition();
                if Vector4.Length(offset) < 0.5 {
                    offset = player.GetWorldForward();
                }
                let away: Vector4 = Vector4.Normalize(offset);
                let wp: WorldPosition;
                WorldPosition.SetVector4(wp, npc.GetWorldPosition() + away * 60.0);
                let target: AIPositionSpec;
                AIPositionSpec.SetWorldPosition(target, wp);
                let move: ref<AIMoveToCommand> = new AIMoveToCommand();
                move.movementTarget = target;
                move.movementType = moveMovementType.Sprint;
                move.ignoreNavigation = false;
                move.finishWhenDestinationReached = true;
                move.desiredDistanceFromTarget = 2.0;
                puppet.GetAIControllerComponent().SendCommand(move);
            }
            if mode == 1 || mode == 2 {
                NPCPuppet.ChangeHighLevelState(puppet, gamedataNPCHighLevelState.Fear);
            }
        }

        GameObject.PlayVoiceOver(npc, n"fear_run", n"Scripts:GangRetaliation");
        this.SayFleeLine(npc, candidate.gang);
        this.Debug("Huye el ultimo en pie (modo " + IntToString(mode) + "): " + candidate.gang + " vida " + FloatToString(candidate.health) + "%");
    }

    private func IsOwnSpawn(id: EntityID) -> Bool {
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());
        return IsDefined(spawner) && spawner.IsOwnSpawn(id);
    }

    // Se llama desde el tick, nunca desde un evento de golpe o muerte.
    private func StopFlee(npc: ref<ScriptedPuppet>, candidate: ref<GRCandidate>) {
        candidate.fleeing = false;
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) || !IsDefined(npc.GetAttitudeAgent()) || !IsDefined(player.GetAttitudeAgent()) {
            return;
        }
        npc.GetAttitudeAgent().SetAttitudeTowards(player.GetAttitudeAgent(), EAIAttitude.AIA_Hostile);
        StimBroadcasterComponent.SendStimDirectly(player, gamedataStimType.CombatHit, npc);
        this.Debug("Huida cortada: un NPC del mundo no sale de la zona (" + candidate.gang + ")");
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
                    this.Promote(candidate, "fled");
                }
                done = true;
            } else {
                if GRDetection.IsNeutralized(npc) {
                    done = true;
                } else {
                    candidate.health = this.GetHealthPercent(npc);
                    candidate.position = npc.GetWorldPosition();
                    let distance: Float = IsDefined(player) ? Vector4.Distance(npc.GetWorldPosition(), player.GetWorldPosition()) : 0.0;
                    let timeout: Bool = this.Now() - this.m_fleeStart[i] > 25.0;
                    if this.IsOwnSpawn(candidate.entityID) {
                        if distance > 45.0 || timeout {
                            this.Promote(candidate, "fled");
                            done = true;
                        }
                    } else {
                        // Un NPC del mundo puede ser necesario para una mision: si se aleja, el juego lo
                        // descarga y la mision queda sin terminar. Vuelve a pelear; si sobrevive al
                        // combate, el fin de combate lo registra como escapado.
                        if distance > 30.0 || timeout {
                            this.StopFlee(npc, candidate);
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
    }

    public func GetFleeMode() -> Int32 {
        return this.m_fleeMode;
    }

    public func SetFleeMode(mode: Int32) {
        this.m_fleeMode = mode;
    }

    // Entrada unica de los eventos del motor. Siempre llega desde GRDetectionCall, en el hilo principal.
    public func HandleCall(kind: Int32, id: EntityID) {
        if kind == GRDetectionCall.CombatEnded() {
            this.OnPlayerCombatEnded();
            return;
        }
        if kind == GRDetectionCall.NPCDeath() {
            this.OnNPCDeath(id);
            return;
        }
        let npc: ref<ScriptedPuppet> = this.FindPuppet(id);
        if !IsDefined(npc) {
            return;
        }
        if kind == GRDetectionCall.PlayerHitNPC() {
            this.OnPlayerHitNPC(npc);
        } else {
            if kind == GRDetectionCall.NPCHitPlayer() {
                this.OnNPCHitPlayer(npc);
            }
        }
    }

    private func OnPlayerHitNPC(npc: ref<ScriptedPuppet>) {
        if !this.IsEnabled() || !GRDetection.IsEligible(npc) || this.WasPromoted(npc.GetEntityID())
            || GRIntegrations.IsDDAlly(npc.GetEntityID()) {
            return;
        }
        this.AddCombatant(npc.GetEntityID());
        this.UpsertCandidate(npc);
        this.CheckLastStanding();
    }

    private func OnNPCHitPlayer(npc: ref<ScriptedPuppet>) {
        if this.IsEnabled() && GRDetection.IsEligible(npc) && !GRIntegrations.IsDDAlly(npc.GetEntityID()) {
            this.AddCombatant(npc.GetEntityID());
        }
    }

    private func OnNPCDeath(id: EntityID) {
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());
        if IsDefined(spawner) {
            spawner.MarkDead(id);
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
        // El muerto sigue en m_combatants: cuenta para el tamano de la pelea y IsNeutralized lo descarta.
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
        let debugLog: Bool = IsDefined(settings) && settings.debugLog;

        // Sin copia local: todo corre en el hilo principal y nada borra de m_candidates durante el recorrido.
        let i: Int32 = 0;
        while i < ArraySize(this.m_candidates) {
            let candidate: ref<GRCandidate> = this.m_candidates[i];
            let npc: ref<ScriptedPuppet>;
            if IsDefined(candidate) {
                npc = GameInstance.FindEntityByID(this.GetGameInstance(), candidate.entityID) as ScriptedPuppet;
            }
            // Si otro mod lo borró, no hay pruebas de que haya escapado.
            if IsDefined(npc) && !GRDetection.IsNeutralized(npc) {
                candidate.health = this.GetHealthPercent(npc);
                candidate.position = npc.GetWorldPosition();

                if debugLog {
                    let msg: String = "Fin de combate: ";
                    msg += candidate.gang;
                    msg += " vida ";
                    msg += FloatToString(candidate.health);
                    msg += "%";
                    if candidate.fleeing {
                        msg += " (huyendo)";
                    }
                    GRLog(msg);
                }

                // Un NPC del mundo que huyo vuelve a pelear al alejarse (StopFlee); si sobrevive al combate,
                // escapo aunque tenga mas vida que el umbral de huida herida.
                if !candidate.fleeing && candidate.health > 0.0 && (candidate.health <= threshold || candidate.fled) {
                    this.Promote(candidate, candidate.fled ? "fled" : "escaped");
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
        this.MakeFlee(target);
        return true;
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

    public func Notify(text: String) {
        let msg: SimpleScreenMessage;
        msg.isShown = true;
        msg.duration = 6.0;
        msg.message = text;
        let defs = GetAllBlackboardDefs();
        GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(defs.UI_Notifications).SetVariant(defs.UI_Notifications.WarningMessage, ToVariant(msg), true);
    }
}

// Golpes, muertes y cambios de combate llegan desde hilos de trabajo del motor, a veces varios a la vez
// (una escopeta contra un grupo). Si tocaran las listas de GRDetection desde ahi, dos hilos las modifican
// juntos y el juego crashea. Los hooks solo agendan esta llamada; GRDetection la procesa en el hilo principal.
public class GRDetectionCall extends DelayCallback {
    public let gi: GameInstance;
    public let kind: Int32;
    public let entityID: EntityID;

    public static func PlayerHitNPC() -> Int32 { return 0; }
    public static func NPCHitPlayer() -> Int32 { return 1; }
    public static func NPCDeath() -> Int32 { return 2; }
    public static func CombatEnded() -> Int32 { return 3; }

    public static func Send(gi: GameInstance, kind: Int32, id: EntityID) {
        let call: ref<GRDetectionCall> = new GRDetectionCall();
        call.gi = gi;
        call.kind = kind;
        call.entityID = id;
        GameInstance.GetDelaySystem(gi).DelayCallback(call, 0.0, false);
    }

    public func Call() -> Void {
        let det: ref<GRDetection> = GRDetection.Get(this.gi);
        if IsDefined(det) {
            det.HandleCall(this.kind, this.entityID);
        }
    }
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

@wrapMethod(NPCPuppet)
protected cb func OnDeath(evt: ref<gameDeathEvent>) -> Bool {
    GRDetectionCall.Send(this.GetGame(), GRDetectionCall.NPCDeath(), this.GetEntityID());
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
