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
    // Donde empezo a huir: la correa de 30 m de un NPC del mundo se mide desde aca, no desde V.
    public let fleeOrigin: Vector4;
    // Segundos seguidos (ticks de 1 s) que V no lo ve.
    public let unseen: Float;
    // V le pego mientras estaba escondido (estar en m_hiding = escondido: neutral y quieto).
    public let discovered: Bool;
    // Huye con la reaccion nativa del juego (modo H): no se le mandan ordenes de movimiento, la cortarian.
    public let nativeFlee: Bool;
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

    // NPCs del mundo escondidos tras huir (ver UpdateHiding).
    private let m_hiding: array<ref<GRCandidate>>;
    // Quienes huyeron en esta sesion. No se borra con ResetFight: si el combate termina mientras
    // corre y despues vuelve a pelear, sigue contando como huido.
    private let m_fledIds: array<EntityID>;

    public func GRProfState() -> String {
        return "candidates=" + IntToString(ArraySize(this.m_candidates)) + " combatants=" + IntToString(ArraySize(this.m_combatants))
            + " fleeing=" + IntToString(ArraySize(this.m_fleeing)) + " hiding=" + IntToString(ArraySize(this.m_hiding));
    }

    public static func Get(gi: GameInstance) -> ref<GRDetection> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRDetection") as GRDetection;
    }

    private func OnAttach() {
        // G (terror + correr): el que mejor anduvo en la prueba del usuario (2026-11-05).
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
        if IsDefined(record) && IsDefined(record.Rarity()) {
            let rarity: gamedataNPCRarity = record.Rarity().Type();
            if Equals(rarity, gamedataNPCRarity.Boss) || Equals(rarity, gamedataNPCRarity.MaxTac) {
                return false;
            }
        }
        return NotEquals(GRDetection.GetGang(npc), "");
    }

    // Jackie (Valentino) y otros acompañantes: un golpe de V por error no los vuelve candidatos.
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
        // m_combatants solo tiene a los que pegaron o recibieron golpes: si V ve a otros enemigos
        // (llegando, detras de una cobertura), no es el ultimo. No gasta la huida: se reintenta.
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
        let health: Float = this.GetHealthPercent(last);
        if health > 0.0 && health <= GRIntegrations.GetFleePercent(settings.fleeHealthPercent) {
            this.m_someoneFled = true;
            this.m_pendingFlee = last.GetEntityID();
            this.m_hasPendingFlee = true;
            // Huye a los 0.1 s, fuera de este evento. Antes esperaba al tick de 1 s de CET y V
            // a veces lo remataba antes de que corriera. El tick queda de respaldo.
            GRDetectionCall.SendDelayed(this.GetGameInstance(), GRDetectionCall.RunFlee(), last.GetEntityID(), 0.1);
        }
    }

    // Hostiles vivos que V tiene registrados, sin contar a "last" (lo mismo que usa el panel del HUD).
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
            // Solo los que de verdad pelean cerca. Antes contaba cualquier hostil registrado (uno lejos o
            // quieto) y la huida esperaba para siempre ("quedan 1 amenazas mas" durante todo el combate).
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

    // V ve al NPC: ninguna pared entre los ojos de V y el pecho del NPC.
    private func PlayerSees(npc: ref<ScriptedPuppet>) -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());
        if !IsDefined(player) || !IsDefined(spawner) {
            return false;
        }
        return spawner.HasLineOfSight(player, npc.GetWorldPosition());
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
        this.MakeFleeMode(npc, -1);
    }

    // forcedMode: -1 = normal (modo elegido para los spawns propios, 0 para los del mundo). El boton de
    // debug fuerza el modo elegido en el panel para cualquier NPC (experimento: que sistema del juego
    // hace huir de verdad a un pandillero).
    private func MakeFleeMode(npc: ref<ScriptedPuppet>, forcedMode: Int32) {
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
        // NPCs del mundo (pueden ser de una mision): sin estado de miedo, que hace que el juego los
        // descargue. Solo corren y se esconden.
        let ownSpawn: Bool = this.IsOwnSpawn(npc.GetEntityID());
        // Los del mundo, sin estado de miedo (modos B/C/E): hace que el juego los descargue.
        let mode: Int32 = forcedMode >= 0 ? forcedMode : this.m_fleeMode;
        if forcedMode < 0 && !ownSpawn && (mode == 1 || mode == 2 || mode == 4) {
            mode = 6;
        }
        if IsDefined(puppet) && IsDefined(player) && IsDefined(puppet.GetAttitudeAgent()) && IsDefined(puppet.GetAIControllerComponent()) {
            this.ApplyFleeMode(puppet, player, mode);
            // Modo H: si la reaccion nativa arranco, corre a la vista y no hay flash ni desaparicion.
            // Si el juego no la acepto (sin componente de reacciones), sigue con el flash de siempre.
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
            // Flash: V queda ciega un momento y en ese rato el que huye desaparece (Vanish). Antes corria y
            // la IA del juego lo teletransportaba o lo devolvia a pelear a la vista de V.
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
        this.Debug("Huye el ultimo en pie (modo " + IntToString(mode) + "): " + candidate.gang + " vida " + FloatToString(candidate.health) + "%");
    }

    // Modos de huida. 0-2 son los de siempre; 3-6 son experimentos con sistemas del juego (2026-11-05):
    // con "neutral + correr" la IA de combate lo devolvia a pelear apenas V le pegaba o lo seguia viendo.
    //   0 A: neutral + correr         1 B: estado de miedo          2 C: A + B
    //   3 D: borrar amenazas (como el hackeo Memory Wipe: ClearThreats + estado alerta) + A
    //   4 E: borrar amenazas + B + A
    //   5 F: retirada nativa (stat CanRetreat, sigue hostil; la usa la policia ante MaxTac)
    //   6 G: estimulo de terror directo (como huyen los civiles) + A
    //   7 H: reaccion nativa Flee forzada (GRForceFlee, como They Will Remember) + neutral, sin orden de
    //        correr (la orden cortaria la reaccion) y sin flash (2026-11-10)
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

    // Vuelve a pelear (escolta trabada o escondido descubierto). Sigue marcado como huido.
    // Se llama desde el tick, nunca desde un evento de golpe o muerte.
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

    // NPC del mundo al final de su correa: se queda neutral y quieto (no sale de la zona, por si es
    // de una mision). Si sigue vivo al terminar el combate, es Nemesis (fled). Sigue en m_hiding aun
    // despues de ascender: si V lo encuentra y le pega, vuelve a pelear (ver UpdateHiding).
    private func Hide(npc: ref<ScriptedPuppet>, candidate: ref<GRCandidate>) {
        candidate.fleeing = false;
        let puppet: ref<NPCPuppet> = npc as NPCPuppet;
        // Con la huida nativa no se lo frena: sigue corriendo y el juego lo descarga cuando queda lejos.
        if IsDefined(puppet) && !candidate.nativeFlee {
            GRMoveTo(puppet, npc.GetWorldPosition(), moveMovementType.Walk, 1.0);
        }
        ArrayPush(this.m_hiding, candidate);
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if IsDefined(player) && !player.IsInCombat() {
            // El combate ya termino mientras corria: no hay otro fin de combate que lo registre.
            this.Promote(candidate, "fled");
            this.Debug("Escondido con el combate terminado: " + candidate.gang);
            return;
        }
        // Que el fin de combate lo encuentre aunque la lista se haya reiniciado mientras corria
        // (UpsertCandidate lo crea con fled = HasFled, ya marcado en MakeFlee).
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
            // Ya ascendido (fin de combate): se lo sigue mientras V este cerca, para que un golpe de V
            // lo despierte. Antes se soltaba y quedaba neutral y quieto toda la sesion.
            let done: Bool = false;
            if !IsDefined(npc) {
                if !candidate.ddSpawn {
                    this.Promote(candidate, "fled");
                }
                done = true;
            } else {
                if GRDetection.IsNeutralized(npc) {
                    done = true;
                } else {
                    if candidate.discovered {
                        this.StopFlee(npc, candidate, "V encontro al escondido");
                        done = true;
                    } else {
                        if this.WasPromoted(candidate.entityID) && this.DistanceToPlayer(npc) > 100.0 {
                            done = true;
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

    // Huyendo o escondido ahora mismo. Lo usa ProvokeIdle para no devolverlo al combate.
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
                    let elapsed: Float = this.Now() - this.m_fleeStart[i];
                    if this.PlayerSees(npc) {
                        candidate.unseen = 0.0;
                    } else {
                        candidate.unseen += 1.0;
                    }
                    if this.IsOwnSpawn(candidate.entityID) {
                        // Escapa al perderse de vista (3 s sin verlo y a mas de 25 m) o al pasar 50 m.
                        // Antes bastaban 25 s aunque V lo tuviera a la vista a 10 m.
                        if (candidate.unseen >= 3.0 && distance > 25.0) || distance > 50.0 {
                            this.Promote(candidate, "fled");
                            done = true;
                        } else {
                            if elapsed > 60.0 {
                                this.StopFlee(npc, candidate, "no pudo perderse de vista en 60 s");
                                done = true;
                            }
                        }
                    } else {
                        // Un NPC del mundo puede ser necesario para una mision: si se aleja, el juego lo
                        // descarga y la mision queda sin terminar. Se esconde en cuanto V lo pierde de
                        // vista (2 s, a mas de 15 m de donde empezo), o a 50 m de ahi, o a los 25 s.
                        // Antes se escondia a 30 m aunque V lo estuviera mirando.
                        let run: Float = Vector4.Distance(npc.GetWorldPosition(), candidate.fleeOrigin);
                        if (candidate.unseen >= 2.0 && run > 15.0) || run > 50.0 || elapsed > 25.0 {
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

    // Fin de la huida con flash, mientras V esta ciega: escapo y es Nemesis (fled). Spawn propio: se borra.
    // Del mundo: no se puede borrar algo que no genero el mod, asi que se lo manda a unos 80 m, lejos de V
    // (ahi el juego lo descarga solo). Sigue en m_hiding: si V lo encuentra y le pega, vuelve a pelear.
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
                this.Promote(candidate, "fled");
            }
            return;
        }
        if GRDetection.IsNeutralized(npc) {
            return;
        }
        candidate.health = this.GetHealthPercent(npc);
        candidate.position = npc.GetWorldPosition();
        let gi: GameInstance = this.GetGameInstance();
        let spawner: ref<GRSpawner> = GRSpawner.Get(gi);
        if IsDefined(spawner) && spawner.IsOwnSpawn(id) {
            this.Promote(candidate, "fled");
            spawner.Vanish(id);
            this.Debug("Desaparece con flash (spawn propio): " + candidate.gang);
            return;
        }
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        if IsDefined(player) {
            let pos: Vector4 = GRAwayFrom(npc, player, 80.0);
            GameInstance.GetTeleportationFacility(gi).Teleport(npc, pos, Vector4.ToRotation(pos - player.GetWorldPosition()));
        }
        ArrayPush(this.m_hiding, candidate);
        this.Promote(candidate, "fled");
        this.Debug("Desaparece con flash (del mundo, a " + FloatToString(this.DistanceToPlayer(npc)) + " m): " + candidate.gang);
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
        if kind == GRDetectionCall.NPCDeath() || kind == GRDetectionCall.NPCDeathByV() {
            this.OnNPCDeath(id, kind == GRDetectionCall.NPCDeathByV());
            return;
        }
        if kind == GRDetectionCall.RunFlee() {
            this.RunPendingFlee();
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
        // V le pego al escondido (aunque ya sea Nemesis): el tick lo vuelve hostil (no se cambia la IA desde aca).
        let hiding: ref<GRCandidate> = this.FindHiding(npc.GetEntityID());
        if IsDefined(hiding) {
            hiding.discovered = true;
        }
        if !this.IsEnabled() || !GRDetection.IsEligible(npc) || GRDetection.IsPlayerAlly(npc) || this.WasPromoted(npc.GetEntityID())
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

    private func OnNPCDeath(id: EntityID, byPlayer: Bool) {
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());
        if IsDefined(spawner) {
            // El evento de muerte nombra a V aunque no haya un golpe suyo registrado (auto que explota).
            let nemesisId: Int32 = spawner.GetNemesisId(id);
            if byPlayer && nemesisId > 0 {
                spawner.RecordHitBy(nemesisId, "v");
            }
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
        // Si no, un escondido muerto cuyo cuerpo se descarga antes del tick se ascendia como "fled".
        let h: Int32 = ArraySize(this.m_hiding) - 1;
        while h >= 0 {
            if this.m_hiding[h].entityID == id {
                ArrayErase(this.m_hiding, h);
            }
            h -= 1;
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
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());

        // Sin copia local: todo corre en el hilo principal y nada borra de m_candidates durante el recorrido.
        let i: Int32 = 0;
        while i < ArraySize(this.m_candidates) {
            let candidate: ref<GRCandidate> = this.m_candidates[i];
            let npc: ref<ScriptedPuppet>;
            if IsDefined(candidate) {
                npc = GameInstance.FindEntityByID(this.GetGameInstance(), candidate.entityID) as ScriptedPuppet;
            }
            // Si otro mod lo borró, no hay pruebas de que haya escapado.
            if IsDefined(npc) && !GRDetection.IsNeutralized(npc) && !GRDetection.IsPlayerAlly(npc) {
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
                // Un sobrante (emboscada cortada por tiempo en plena pelea) deja de pelear porque el mod lo
                // pone neutral y lo manda a irse: eso no es escapar herido. Si huyo de verdad, si cuenta.
                let pacified: Bool = IsDefined(spawner) && spawner.IsLeftover(candidate.entityID) && !candidate.fled;
                if !pacified && !candidate.fleeing && candidate.health > 0.0 && (candidate.health <= threshold || candidate.fled) {
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
        this.MakeFleeMode(target, this.m_fleeMode);
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

    // Los avisos esperan si V esta en una escena de mision (tier 3-5: cinematicas, recuerdos de Johnny),
    // en una danza cerebral o en un menu. Tier 1-2 (calle, departamento) si se muestran.
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

    // Por defecto al registro lateral (sin sonido ni vibracion); el aviso grande del centro es opcional.
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
    public static func RunFlee() -> Int32 { return 4; }
    public static func Vanish() -> Int32 { return 5; }
    public static func Unblind() -> Int32 { return 6; }
    public static func NPCDeathByV() -> Int32 { return 7; }

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

// Ceguera de la huida: el glitch del hackeo de ceguera de los netrunners enemigos (Reboot Optics contra V).
// Si ese registro no existe en esta version del juego, la ceguera de las luces cegadoras.
public func GRBlindEffect() -> TweakDBID {
    let glitch: TweakDBID = t"AIQuickHackStatusEffect.HackBlind";
    if IsDefined(TweakDBInterface.GetStatusEffectRecord(glitch)) {
        return glitch;
    }
    return t"BaseStatusEffect.Blind";
}

// Huida nativa (modo H): le pide al arbol de IA la reaccion Flee, la misma con la que corren los civiles,
// con prioridad por encima del combate. Mandar solo el estimulo de terror (modo G) no alcanza: el preset
// de un pandillero lo descarta y la reaccion nunca se pide. Es la rama directa de TriggerBehaviorReaction
// del juego, sin pasar por el estimulo (They Will Remember envuelve ese camino y se queda con los Terror
// que vienen de V). Devuelve false si no se pudo pedir.
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
    // Tirado en el piso o en un vehiculo: queda pendiente y el juego la dispara al salir de ese estado.
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

// Corta la huida nativa (el que no pudo perderse de vista vuelve a pelear): saca las animaciones de
// panico y le avisa a la tarea de reaccion que termine.
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

// Unico armado de AIMoveToCommand del mod (huida, escondite, sobrantes que se van).
public func GRMoveTo(puppet: ref<NPCPuppet>, pos: Vector4, type: moveMovementType, distance: Float) {
    if !IsDefined(puppet) || !IsDefined(puppet.GetAIControllerComponent()) {
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

// Punto del navmesh (a pie) a unos 'distance' metros del NPC, en la direccion contraria a V. Prueba
// desvios de hasta 60 grados y distancias mas cortas: el punto en linea recta solia caer dentro de un
// edificio y el NPC no encontraba camino. Sin punto valido, el de linea recta como antes.
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
    return from + away * distance;
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
    // Hilo del motor: solo se lee quien provoco la muerte; el dato viaja en la llamada agendada.
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
