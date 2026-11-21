module GangRetaliation

public class GRStronghold extends ScriptableSystem {
    private let m_siteGangs: array<String>;
    private let m_sitePos: array<Vector4>;
    private let m_siteFixed: array<Vector4>;
    private let m_siteChoiceLog: array<String>;

    private persistent let m_chosen: array<Int32>;
    private persistent let m_chosenX: array<Float>;
    private persistent let m_chosenY: array<Float>;
    private persistent let m_chosenZ: array<Float>;
    private let m_gangList: array<String>;

    private let m_candLoaded: Bool;
    private let m_candCount: Int32;
    private let m_candGangs: array<String>;
    private let m_candIds: array<String>;
    private let m_candVariants: array<Int32>;
    private let m_candHashes: array<Uint32>;
    private let m_candJournalHashes: array<Uint32>;
    private let m_candJournalDone: Bool;
    private let m_journalFound: Int32;
    private let m_journalSame: Int32;
    private let m_journalExample: String;
    private let m_candPos: array<Vector4>;
    private let m_candKnown: array<Bool>;
    private let m_candBad: array<Bool>;
    private let m_candFound: Int32;
    // Puntos de caza descartados por estar bajo tierra/cubiertos (solo esta sesion; se vuelven a descubrir con el rayo).
    private let m_coverPos: array<Vector4>;

    private let m_questPos: array<Vector4>;
    private let m_safePos: array<Vector4>;
    private let m_ticks: Int32;
    private let m_scanTick: Int32;
    private let m_scanDone: Bool;
    private let m_scanTries: Int32;
    private let m_scanLogged: Bool;
    private let m_scanTotal: Int32;
    private let m_scanVariant: Int32;
    private let m_scanPoi: Int32;
    private let m_scanStatic: Int32;
    private let m_scanJournal: Int32;
    private let m_scanUnmatched: Int32;
    private let m_scanSecure: Int32;
    private let m_scanExample: String;
    private let m_choiceWait: Int32;

    private let m_visitSite: Int32;
    private let m_visitPosts: Bool;
    private let m_visitNear: Bool;
    private let m_visitTries: Int32;
    private let m_siteMembers: array<Int32>;
    private let m_siteGuards: array<String>;
    private let m_siteMappins: array<NewMappinID>;
    private let m_siteHasMappin: array<Bool>;
    private let m_siteMarks: array<ref<GRStrongholdMappinData>>;

    private let m_memberSites: array<Int32>;
    private let m_ids: array<Int32>;
    private let m_records: array<String>;
    private let m_appearances: array<String>;
    private let m_speakers: array<String>;

    private let m_active: Bool;
    private let m_activeSite: Int32;
    private let m_activePos: Vector4;
    private let m_cleared: Bool;

    private let m_pending: array<ref<GRPendingPost>>;
    private let m_populating: Bool;
    private let m_announced: Bool;
    private let m_fillTicks: Int32;
    private let m_placed: Int32;
    private let m_failed: Int32;
    private let m_fillStats: array<Int32>;

    private let m_events: array<String>;

    // Caza del Bounty Board: m_hunt = Nemesis del contrato cuando el grupo activo es una caza (0 = guarida).
    private let m_hunt: Int32;
    private let m_huntWait: Int32;
    private let m_huntLog: String;
    // Origen del spawn: Nemesis que aparecieron en su guarida en esta activacion (contratos de Jefe "en su guarida").
    private let m_origins: array<Int32>;

    private persistent let m_mapFilterSeeded: Bool;
    private let m_mapCustom: Bool;
    private let m_mapFilterOn: Bool;

    public static func Get(gi: GameInstance) -> ref<GRStronghold> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRStronghold") as GRStronghold;
    }

    // These "Guarida (...)"/"Guaridas auto: ..." messages always write to gamelog.log regardless of the
    // debugLog setting (they're placement/scanning records, not purely debug-gated chatter) - this adds
    // an independent, optional on-screen mirror (debugOnScreen + debugOnScreenStronghold) without
    // changing that unconditional file-write behavior.
    private func Log(msg: String) {
        GRLog(msg);
        GRPushDebugLine(this.GetGameInstance(), msg, "Stronghold");
    }

    public static func MapFilter() -> gamedataWorldMapFilter {
        return gamedataWorldMapFilter.RelicDeviceFilter;
    }

    public func IsMapFilterSeeded() -> Bool { return this.m_mapFilterSeeded; }
    public func IsMapCustom() -> Bool { return this.m_mapCustom; }
    public func IsMapFilterOn() -> Bool { return this.m_mapFilterOn; }

    public func MarkMapFilterSeeded() {
        this.m_mapFilterSeeded = true;
        this.Log("Mapa: filtro GUARIDAS prendido por primera vez en esta partida");
    }

    public func SetMapFilter(custom: Bool, on: Bool) {
        let changed: Bool = (custom && !this.m_mapCustom) || (!custom && this.m_mapCustom)
            || (on && !this.m_mapFilterOn) || (!on && this.m_mapFilterOn);
        this.m_mapCustom = custom;
        this.m_mapFilterOn = on;
        if changed {
            let customText: String = custom ? "si" : "no";
            let onText: String = on ? "marcada" : "sin marcar";
            this.Log("Mapa: filtro rapido PERSONALIZADA = " + customText + ", casilla GUARIDAS = " + onText);
        }
    }

    public static func SpawnDistance() -> Float { return 70.0; }
    public static func ForcedDistance() -> Float { return 45.0; }
    public static func SightWait() -> Int32 { return 8; }
    public static func GroundWait() -> Int32 { return 10; }
    public static func SpotWait() -> Int32 { return 5; }
    public static func CheckDistance() -> Float { return 150.0; }
    public static func MinPosts() -> Int32 { return 14; }

    private func OnDetach() {
        let i: Int32 = 0;
        while i < ArraySize(this.m_siteGangs) {
            this.RemoveSiteMappin(i);
            i += 1;
        }
    }

    private func EnsureSites() {
        if ArraySize(this.m_siteGangs) > 0 {
            return;
        }
        this.AddSite("Animals", -2405.2426757813, -2084.2224121094, 9.0001068115234);
        if IsEP1() {
            this.AddSite("Barghest", -1825.90527, -2639.56909, 40.3169174);
        }
        this.AddSite("Maelstrom", -1183.3427734375, 1302.7615966797, 18.575248718262);
        this.AddSite("Scavengers", -860.226562, 2793.70581, 38.5733261);
        this.AddSite("SixthStreet", 63.618316650391, -1828.0014648438, -10.104141235352);
        this.AddSite("TygerClaws", -361.50540161133, 557.77117919922, 31.197227478027);
        this.AddSite("Valentinos", -823.60107421875, -388.01766967773, 8.1999969482422);
        this.AddSite("VoodooBoys", -1964.0188, -1952.28345, 18.1248322);
        this.AddSite("Wraiths", 4025.73438, 6.36502838, 118.74411);
        this.ApplyChoices();
    }

    private func AddSite(gang: String, x: Float, y: Float, z: Float) {
        let none: NewMappinID;
        ArrayPush(this.m_siteGangs, gang);
        ArrayPush(this.m_sitePos, new Vector4(x, y, z, 1.0));
        ArrayPush(this.m_siteFixed, new Vector4(x, y, z, 1.0));
        ArrayPush(this.m_siteChoiceLog, "");
        ArrayPush(this.m_siteMembers, 0);
        ArrayPush(this.m_siteGuards, "");
        ArrayPush(this.m_siteMappins, none);
        ArrayPush(this.m_siteHasMappin, false);
        ArrayPush(this.m_siteMarks, null);
    }

    private func FindSite(gang: String) -> Int32 {
        this.EnsureSites();
        let i: Int32 = 0;
        while i < ArraySize(this.m_siteGangs) {
            if Equals(this.m_siteGangs[i], gang) {
                return i;
            }
            i += 1;
        }
        return -1;
    }

    private func IsValidSite(site: Int32) -> Bool {
        this.EnsureSites();
        return site >= 0 && site < ArraySize(this.m_siteGangs);
    }

    private func RemoveSiteMappin(site: Int32) {
        if this.m_siteHasMappin[site] {
            GameInstance.GetMappinSystem(this.GetGameInstance()).UnregisterMappin(this.m_siteMappins[site]);
            this.m_siteHasMappin[site] = false;
            this.m_siteMarks[site] = null;
        }
    }

    private func RefreshMappins() {
        let intel: ref<GRIntelSystem> = GRIntelSystem.Get(this.GetGameInstance());
        let settings: ref<GRSettings> = GRSettings.Get(this.GetGameInstance());
        let debugAll: Bool = IsDefined(settings) && settings.debugLog;
        let i: Int32 = 0;
        while i < ArraySize(this.m_siteGangs) {
            let located: Bool = !IsDefined(intel) || intel.IsLocated(this.m_siteGangs[i]);
            let occupied: Bool = this.m_siteMembers[i] > 0 && (located || debugAll);
            if occupied && !this.m_siteHasMappin[i] {
                let data: MappinData;
                let mark: ref<GRStrongholdMappinData> = new GRStrongholdMappinData();
                mark.gang = this.m_siteGangs[i];
                this.m_siteMarks[i] = mark;
                data.mappinType = t"Mappins.GRStrongholdMappinDefinition";
                data.variant = gamedataMappinVariant.CPO_PingDoorVariant;
                data.active = true;
                data.scriptData = mark;
                this.m_siteMappins[i] = GameInstance.GetMappinSystem(this.GetGameInstance()).RegisterMappin(data, this.m_sitePos[i]);
                this.m_siteHasMappin[i] = true;
                if located {
                    this.Log("Guarida (" + this.m_siteGangs[i] + "): ocupada y localizada, en el mapa");
                } else {
                    this.Log("Guarida (" + this.m_siteGangs[i] + "): visible por debug (intel " + IntToString(intel.GetIntel(this.m_siteGangs[i])) + "%)");
                }
            } else if !occupied && this.m_siteHasMappin[i] {
                this.RemoveSiteMappin(i);
                this.Log("Guarida (" + this.m_siteGangs[i] + "): vacia o sin localizar, fuera del mapa");
            }
            i += 1;
        }
    }

    private func MarkLocated(gang: String, reason: String) {
        let intel: ref<GRIntelSystem> = GRIntelSystem.Get(this.GetGameInstance());
        if IsDefined(intel) {
            intel.MarkLocated(gang, reason);
        }
    }


    public func ClearMembers() {
        this.EnsureSites();
        ArrayClear(this.m_memberSites);
        ArrayClear(this.m_ids);
        ArrayClear(this.m_records);
        ArrayClear(this.m_appearances);
        ArrayClear(this.m_speakers);
        let i: Int32 = 0;
        while i < ArraySize(this.m_siteGangs) {
            this.m_siteMembers[i] = 0;
            this.m_siteGuards[i] = "";
            i += 1;
        }
    }

    public func AddMember(gang: String, nemesisId: Int32, recordID: String, appearance: String, speaker: String) {
        let site: Int32 = this.FindSite(gang);
        if site < 0 || this.m_siteMembers[site] >= 20 {
            return;
        }
        ArrayPush(this.m_memberSites, site);
        ArrayPush(this.m_ids, nemesisId);
        ArrayPush(this.m_records, recordID);
        ArrayPush(this.m_appearances, appearance);
        ArrayPush(this.m_speakers, speaker);
        this.m_siteMembers[site] = this.m_siteMembers[site] + 1;
    }

    public func SetGuards(gang: String, records: String) {
        let site: Int32 = this.FindSite(gang);
        if site >= 0 {
            this.m_siteGuards[site] = records;
        }
    }

    public func TakeEvent() -> String {
        if ArraySize(this.m_events) == 0 {
            return "";
        }
        let first: String = this.m_events[0];
        ArrayErase(this.m_events, 0);
        return first;
    }


    public func HasSite(gang: String) -> Bool {
        return this.FindSite(gang) >= 0;
    }

    public func GetSiteCount() -> Int32 {
        this.EnsureSites();
        return ArraySize(this.m_siteGangs);
    }

    public func GetSiteGang(site: Int32) -> String {
        if !this.IsValidSite(site) {
            return "";
        }
        return this.m_siteGangs[site];
    }

    public func GetSiteMemberCount(site: Int32) -> Int32 {
        if !this.IsValidSite(site) {
            return 0;
        }
        return this.m_siteMembers[site];
    }

    public func GetSitePosition(site: Int32) -> Vector4 {
        if !this.IsValidSite(site) {
            return Vector4.EmptyVector();
        }
        return this.m_sitePos[site];
    }

    public func IsSiteOccupied(site: Int32) -> Bool {
        return this.GetSiteMemberCount(site) > 0;
    }

    public func GetGangSitePosition(gang: String) -> Vector4 {
        let site: Int32 = this.FindSite(gang);
        if site < 0 {
            return Vector4.EmptyVector();
        }
        return this.m_sitePos[site];
    }

    public func IsLairMember(nemesisId: Int32) -> Bool {
        return nemesisId > 0 && ArrayContains(this.m_ids, nemesisId);
    }

    public func SpawnedInLair(nemesisId: Int32) -> Bool {
        return nemesisId > 0 && ArrayContains(this.m_origins, nemesisId);
    }

    public func GetHuntId() -> Int32 {
        return this.m_active ? this.m_hunt : 0;
    }

    // Punto real para la zona de caza de un contrato: un POI de la banda (outpost/gangwatch) que no sea la guarida actual,
    // sin mision ni zona segura cerca. Si no hay, el sitio fijo de la banda si la guarida se mudo. Vacio = sin punto.
    // Cada candidato (y el sitio fijo) se valida contra la SUPERFICIE: si hay una superficie a mas de 6 m por encima del POI esta bajo tierra/cubierto y se descarta.
    // Sin datos de colision (POI lejano, sin streamear) NO se descarta; validated = true solo si el rayo dio datos con V a <= 150 m (si no, GRBounties lo revalida a < 200 m).
    // Devuelve la posicion del POI (Z original); surfaceZ = superficie mas alta medida (0 si no hay datos); useZ = Z a usar para pin y spawn (la del suelo si validated).
    public func PickHuntSpot(gang: String, nemesisId: Int32, out validated: Bool, out surfaceZ: Float, out useZ: Float) -> Vector4 {
        validated = false;
        surfaceZ = 0.0;
        useZ = 0.0;
        let site: Int32 = this.FindSite(gang);
        this.ScanMappins();
        let lair: Vector4 = site >= 0 ? this.m_sitePos[site] : Vector4.EmptyVector();
        let good: array<Int32>;
        let loose: array<Int32>;
        let i: Int32 = 0;
        while i < this.m_candCount {
            if Equals(this.m_candGangs[i], gang) && this.m_candKnown[i] && !this.m_candBad[i] && !this.IsCovered(this.m_candPos[i]) {
                let pos: Vector4 = this.m_candPos[i];
                if site < 0 || Vector4.Distance2D(pos, lair) > 150.0 {
                    if !this.IsNearOtherSite(-1, pos, 150.0) && !this.IsNearMappin(true, pos, 150.0) && !this.IsNearMappin(false, pos, 60.0) {
                        ArrayPush(good, i);
                    } else {
                        ArrayPush(loose, i);
                    }
                }
            }
            i += 1;
        }
        let goodCount: Int32 = ArraySize(good);
        let looseCount: Int32 = ArraySize(loose);
        let label: String = "";
        let cand: Int32 = -1;
        let covered: Int32 = 0;
        let verdict: Int32 = 0;
        while cand < 0 && ArraySize(good) > 0 {
            let pick: Int32 = Min(RandRange(0, ArraySize(good)), ArraySize(good) - 1);
            let idx: Int32 = good[pick];
            ArrayErase(good, pick);
            verdict = this.SurfaceVerdict(nemesisId, this.m_candPos[idx], this.m_candIds[idx], validated, surfaceZ, useZ);
            if verdict == 2 {
                covered += 1;
            } else {
                cand = idx;
            }
        }
        while cand < 0 && ArraySize(loose) > 0 {
            let pick2: Int32 = Min(RandRange(0, ArraySize(loose)), ArraySize(loose) - 1);
            let idx2: Int32 = loose[pick2];
            ArrayErase(loose, pick2);
            verdict = this.SurfaceVerdict(nemesisId, this.m_candPos[idx2], this.m_candIds[idx2], validated, surfaceZ, useZ);
            if verdict == 2 {
                covered += 1;
            } else {
                cand = idx2;
                label = " (cerca de una mision o zona segura: no habia otro)";
            }
        }
        if cand >= 0 {
            GRLog("Caza #" + IntToString(nemesisId) + " (" + gang + "): punto en " + this.m_candIds[cand] + label + " | " + IntToString(goodCount) + " validos, "
                + IntToString(looseCount) + " de reserva, " + IntToString(covered) + " descartados (bajo tierra/cubierto)");
            this.LogSurface(nemesisId, this.m_candPos[cand], verdict, validated, surfaceZ, useZ);
            return this.m_candPos[cand];
        }
        if site >= 0 && Vector4.Distance2D(this.m_siteFixed[site], lair) > 150.0 && !this.IsCovered(this.m_siteFixed[site]) {
            verdict = this.SurfaceVerdict(nemesisId, this.m_siteFixed[site], "sitio fijo", validated, surfaceZ, useZ);
            if verdict != 2 {
                GRLog("Caza #" + IntToString(nemesisId) + " (" + gang + "): sin POI de la banda con posicion, punto en su sitio fijo (la guarida se mudo) | "
                    + IntToString(covered) + " POI descartados (bajo tierra/cubierto)");
                this.LogSurface(nemesisId, this.m_siteFixed[site], verdict, validated, surfaceZ, useZ);
                return this.m_siteFixed[site];
            }
        }
        validated = false;
        return Vector4.EmptyVector();
    }

    private func IsCovered(pos: Vector4) -> Bool {
        for covered in this.m_coverPos {
            if Vector4.Distance2D(covered, pos) < 2.0 {
                return true;
            }
        }
        return false;
    }

    // Evalua un punto contra la superficie. Si esta cubierto lo anota (no se vuelve a elegir) y deja el log. Devuelve 0 sin datos, 1 en superficie, 2 cubierto.
    // validated/surfaceZ/useZ quedan para el ultimo punto evaluado.
    private func SurfaceVerdict(nemesisId: Int32, pos: Vector4, label: String, out validated: Bool, out surfaceZ: Float, out useZ: Float) -> Int32 {
        let top: Float = 0.0;
        let floorZ: Float = pos.Z;
        validated = false;
        surfaceZ = 0.0;
        useZ = pos.Z;
        let verdict: Int32 = GRSurfaceCheck(this.GetGameInstance(), pos, top, floorZ);
        if verdict == 0 {
            return 0;
        }
        surfaceZ = top;
        if verdict == 2 {
            this.MarkCovered(pos);
            GRLog("Caza #" + IntToString(nemesisId) + ": POI " + label + " cubierto (superficie Z=" + FloatToStringPrec(top, 1) + ", POI Z=" + FloatToStringPrec(pos.Z, 1) + "), descartado");
            return 2;
        }
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if IsDefined(player) && Vector4.Distance2D(player.GetWorldPosition(), pos) <= 150.0 {
            validated = true;
            useZ = floorZ;
        }
        return 1;
    }

    private func LogSurface(nemesisId: Int32, pos: Vector4, verdict: Int32, validated: Bool, surfaceZ: Float, useZ: Float) {
        if validated {
            GRLog("Caza #" + IntToString(nemesisId) + ": punto validado en superficie (Z=" + FloatToStringPrec(useZ, 1) + ", superficie mas alta " + FloatToStringPrec(surfaceZ, 1)
                + ", POI Z=" + FloatToStringPrec(pos.Z, 1) + ")");
        } else if verdict == 1 {
            GRLog("Caza #" + IntToString(nemesisId) + ": punto sin validar (hay colision pero V esta a mas de 150 m), se revalida a < 200 m");
        } else {
            GRLog("Caza #" + IntToString(nemesisId) + ": punto sin validar (sin colision cargada en el POI), se revalida cuando V este a < 200 m");
        }
    }

    // Lo usa GRBounties al revalidar de cerca: anota el punto como cubierto para que PickHuntSpot no lo vuelva a elegir.
    public func MarkCovered(pos: Vector4) {
        if !this.IsCovered(pos) {
            ArrayPush(this.m_coverPos, pos);
        }
    }

    // Id del POI candidato en esa posicion (para los logs), o "sitio fijo".
    public func CandidateLabel(pos: Vector4) -> String {
        this.EnsureCandidates();
        let i: Int32 = 0;
        while i < this.m_candCount {
            if this.m_candKnown[i] && Vector4.Distance2D(this.m_candPos[i], pos) < 2.0 {
                return this.m_candIds[i];
            }
            i += 1;
        }
        return "(sitio fijo)";
    }

    public func IsActive() -> Bool {
        return this.m_active;
    }

    public func GetActiveGang() -> String {
        if !this.m_active {
            return "";
        }
        return this.GetSiteGang(this.m_activeSite);
    }

    public func GetNearestSite() -> Int32 {
        return this.FindNearest(false);
    }

    public func GetNearestGang() -> String {
        return this.GetSiteGang(this.FindNearest(false));
    }

    public func GetNearestDistance() -> Float {
        return this.GetSiteDistance(this.FindNearest(false));
    }

    public func GetSiteDistance(site: Int32) -> Float {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !this.IsValidSite(site) || !IsDefined(player) {
            return -1.0;
        }
        let pos: Vector4 = player.GetWorldPosition();
        return Vector4.Distance2D(pos, this.m_sitePos[site]);
    }

    public func GetNearestInfo() -> String {
        let site: Int32 = this.FindNearest(false);
        if site < 0 {
            return "Stronghold: no sites";
        }
        let inside: Int32 = this.m_siteMembers[site];
        let info: String = "Nearest stronghold: " + this.m_siteGangs[site] + ", " + IntToString(Cast<Int32>(this.GetSiteDistance(site)))
            + " m, " + IntToString(inside) + " inside";
        if inside == 0 {
            info += " (nobody alive: off the map, won't spawn)";
        }
        if this.m_active {
            if this.m_activeSite == site {
                info += " (active)";
            } else {
                info += " | active: " + this.m_siteGangs[this.m_activeSite];
            }
        }
        return info;
    }

    private func FindNearest(occupiedOnly: Bool) -> Int32 {
        this.EnsureSites();
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) {
            return -1;
        }
        let pos: Vector4 = player.GetWorldPosition();
        let best: Int32 = -1;
        let bestDistance: Float = 0.0;
        let i: Int32 = 0;
        while i < ArraySize(this.m_siteGangs) {
            if !occupiedOnly || this.m_siteMembers[i] > 0 {
                let distance: Float = Vector4.Distance2D(pos, this.m_sitePos[i]);
                if best < 0 || distance < bestDistance {
                    best = i;
                    bestDistance = distance;
                }
            }
            i += 1;
        }
        return best;
    }


    public func Respawn() {
        if this.m_active {
            GRSpawner.Get(this.GetGameInstance()).DespawnAll();
            this.m_active = false;
            this.StopPopulating();
        }
    }

    public func DevTeleport(gang: String) -> Bool {
        let site: Int32 = this.FindSite(gang);
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if site < 0 || !IsDefined(player) {
            return false;
        }
        let pos: Vector4 = this.m_sitePos[site];
        pos.Z += 0.5;
        // Solo con suelo comprobado en el destino (si la zona no esta cargada, V caeria bajo el mapa): si no hay, no se mueve a V.
        let groundZ: Float = 0.0;
        let here: Vector4 = player.GetWorldPosition();
        if !GRGroundBetween(this.GetGameInstance(), pos.X, pos.Y, pos.Z + 4.0, pos.Z - 40.0, groundZ) {
            GRLog("Guarida: DevTeleport a " + gang + " cancelado: sin suelo cargado en " + IntToString(Cast<Int32>(pos.X)) + "," + IntToString(Cast<Int32>(pos.Y)) + " (a "
                + IntToString(Cast<Int32>(Vector4.Distance2D(here, pos))) + " m de V), V no se movio");
            return false;
        }
        pos.Z = groundZ + 0.5;
        GameInstance.GetTeleportationFacility(this.GetGameInstance()).Teleport(player, pos, Vector4.ToRotation(player.GetWorldForward()));
        return true;
    }

    public func TestSite(x: Float, y: Float, z: Float) -> Int32 {
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());
        let center: Vector4 = new Vector4(x, y, z, 1.0);
        let ok: Int32 = 0;
        let i: Int32 = 0;
        while i < 20 {
            let radius: Float = 0.0;
            let angle: Float = 0.0;
            if i >= 1 && i < 5 {
                radius = 5.0;
                angle = Cast<Float>(i) * 2.1;
            } else if i >= 5 && i < 13 {
                radius = 10.0;
                angle = 2.0 * Pi() * Cast<Float>(i - 5) / 8.0;
            } else if i >= 13 {
                radius = 17.0;
                angle = 2.0 * Pi() * Cast<Float>(i - 13) / 7.0 + 0.4;
            }
            if !Vector4.IsZero(this.FindPost(spawner, center, angle, radius)) {
                ok += 1;
            }
            i += 1;
        }
        return ok;
    }


    private func GangSlot(gang: String) -> Int32 {
        if ArraySize(this.m_gangList) == 0 {
            let gangs: array<String> = GRIntelSystem.Gangs();
            this.m_gangList = gangs;
        }
        let i: Int32 = 0;
        while i < ArraySize(this.m_gangList) {
            if Equals(this.m_gangList[i], gang) {
                return i;
            }
            i += 1;
        }
        return -1;
    }

    private func EnsureChoices() {
        this.GangSlot("");
        let count: Int32 = ArraySize(this.m_gangList);
        while ArraySize(this.m_chosen) < count {
            ArrayPush(this.m_chosen, 0);
        }
        while ArraySize(this.m_chosenX) < count {
            ArrayPush(this.m_chosenX, 0.0);
        }
        while ArraySize(this.m_chosenY) < count {
            ArrayPush(this.m_chosenY, 0.0);
        }
        while ArraySize(this.m_chosenZ) < count {
            ArrayPush(this.m_chosenZ, 0.0);
        }
    }

    private func EnsureCandidates() {
        if this.m_candLoaded {
            return;
        }
        this.m_candLoaded = true;
        let gangs: array<String> = GRStrongholdCandidates.Gangs();
        let ids: array<String> = GRStrongholdCandidates.Ids();
        let variants: array<Int32> = GRStrongholdCandidates.Variants();
        let hashes: array<Uint32> = GRStrongholdCandidates.JournalHashes();
        this.m_candGangs = gangs;
        this.m_candIds = ids;
        this.m_candVariants = variants;
        this.m_candHashes = hashes;
        this.m_candCount = Min(Min(ArraySize(gangs), ArraySize(ids)), Min(ArraySize(variants), ArraySize(hashes)));
        let i: Int32 = 0;
        while i < this.m_candCount {
            ArrayPush(this.m_candPos, Vector4.EmptyVector());
            ArrayPush(this.m_candKnown, false);
            ArrayPush(this.m_candBad, false);
            i += 1;
        }
    }

    private func EnsureJournalHashes() {
        if this.m_candJournalDone {
            return;
        }
        let journal: ref<JournalManager> = GameInstance.GetJournalManager(this.GetGameInstance());
        if !IsDefined(journal) {
            return;
        }
        this.m_candJournalDone = true;
        let paths: array<String> = GRStrongholdCandidates.Paths();
        let i: Int32 = 0;
        while i < this.m_candCount {
            let hash: Uint32 = 0u;
            if i < ArraySize(paths) {
                let entry: wref<JournalEntry> = journal.GetEntryByString(paths[i], "gameJournalPointOfInterestMappin");
                if IsDefined(entry) {
                    hash = Cast<Uint32>(journal.GetEntryHash(entry));
                    this.m_journalFound += 1;
                    if hash == this.m_candHashes[i] {
                        this.m_journalSame += 1;
                    } else if StrLen(this.m_journalExample) == 0 {
                        this.m_journalExample = this.m_candIds[i] + ": estatico " + ToString(this.m_candHashes[i]) + ", journal " + ToString(hash);
                    }
                }
            }
            ArrayPush(this.m_candJournalHashes, hash);
            i += 1;
        }
    }

    private func FindCandidate(hash: Uint32, out byJournal: Bool) -> Int32 {
        byJournal = false;
        let i: Int32 = 0;
        while i < this.m_candCount {
            if this.m_candHashes[i] == hash {
                return i;
            }
            i += 1;
        }
        i = 0;
        while i < ArraySize(this.m_candJournalHashes) {
            if this.m_candJournalHashes[i] == hash && hash != 0u {
                byJournal = true;
                return i;
            }
            i += 1;
        }
        return -1;
    }

    private func IsSafeVariant(variant: gamedataMappinVariant) -> Bool {
        return Equals(variant, gamedataMappinVariant.ApartmentVariant)
            || Equals(variant, gamedataMappinVariant.Zzz05_ApartmentToPurchaseVariant)
            || Equals(variant, gamedataMappinVariant.FixerVariant)
            || Equals(variant, gamedataMappinVariant.DropboxVariant)
            || Equals(variant, gamedataMappinVariant.ServicePointBarVariant)
            || Equals(variant, gamedataMappinVariant.ServicePointClothesVariant)
            || Equals(variant, gamedataMappinVariant.ServicePointDropPointVariant)
            || Equals(variant, gamedataMappinVariant.ServicePointFoodVariant)
            || Equals(variant, gamedataMappinVariant.ServicePointGunsVariant)
            || Equals(variant, gamedataMappinVariant.ServicePointJunkVariant)
            || Equals(variant, gamedataMappinVariant.ServicePointMedsVariant)
            || Equals(variant, gamedataMappinVariant.ServicePointMeleeTrainerVariant)
            || Equals(variant, gamedataMappinVariant.ServicePointNetTrainerVariant)
            || Equals(variant, gamedataMappinVariant.ServicePointProstituteVariant)
            || Equals(variant, gamedataMappinVariant.ServicePointRipperdocVariant)
            || Equals(variant, gamedataMappinVariant.ServicePointTechVariant)
            || Equals(variant, gamedataMappinVariant.Zzz14_ServicePointBlackMarketVariant)
            || Equals(variant, gamedataMappinVariant.Zzz21_ServicePointGlamdocVariant);
    }

    private func ScanMappins() {
        this.EnsureCandidates();
        if this.m_scanDone && this.m_ticks - this.m_scanTick < 5 {
            return;
        }
        let system: ref<MappinSystem> = GameInstance.GetMappinSystem(this.GetGameInstance());
        if !IsDefined(system) {
            return;
        }
        this.m_scanDone = true;
        this.m_scanTick = this.m_ticks;
        this.EnsureJournalHashes();
        let all: array<ref<IMappin>>;
        system.GetMappins(gamemappinsMappinTargetType.Map, all);
        ArrayClear(this.m_questPos);
        ArrayClear(this.m_safePos);
        this.m_scanTotal = ArraySize(all);
        this.m_scanVariant = 0;
        this.m_scanPoi = 0;
        this.m_scanStatic = 0;
        this.m_scanJournal = 0;
        this.m_scanUnmatched = 0;
        this.m_scanSecure = 0;
        let i: Int32 = 0;
        while i < ArraySize(all) {
            let mappin: ref<IMappin> = all[i];
            if IsDefined(mappin) {
                let variant: gamedataMappinVariant = mappin.GetVariant();
                if mappin.IsQuestMappin() || mappin.IsQuestAreaMappin() {
                    ArrayPush(this.m_questPos, mappin.GetWorldPosition());
                } else if this.IsSafeVariant(variant) {
                    ArrayPush(this.m_safePos, mappin.GetWorldPosition());
                } else if Equals(variant, gamedataMappinVariant.OutpostVariant) || Equals(variant, gamedataMappinVariant.GangWatchVariant) {
                    this.m_scanVariant += 1;
                    let poi: ref<PointOfInterestMappin> = mappin as PointOfInterestMappin;
                    if IsDefined(poi) {
                        this.m_scanPoi += 1;
                        let hash: Uint32 = poi.GetJournalPathHash();
                        let byJournal: Bool = false;
                        let cand: Int32 = this.FindCandidate(hash, byJournal);
                        if cand >= 0 {
                            let pos: Vector4 = poi.GetWorldPosition();
                            pos.W = 1.0;
                            this.m_candPos[cand] = pos;
                            this.m_candKnown[cand] = true;
                            if byJournal {
                                this.m_scanJournal += 1;
                            } else {
                                this.m_scanStatic += 1;
                            }
                            if poi.IsInsideSecurityAreaTrigger() {
                                this.m_scanSecure += 1;
                            }
                        } else {
                            this.m_scanUnmatched += 1;
                            if StrLen(this.m_scanExample) == 0 {
                                this.m_scanExample = ToString(hash);
                            }
                        }
                    }
                }
            }
            i += 1;
        }
        this.m_candFound = 0;
        i = 0;
        while i < this.m_candCount {
            if this.m_candKnown[i] {
                this.m_candFound += 1;
            }
            i += 1;
        }
    }

    private func LogScan() {
        this.Log("Guaridas auto: escaneo de mappins (Map): " + IntToString(this.m_scanTotal) + " mappins, " + IntToString(this.m_scanVariant)
            + " outpost/gangwatch (" + IntToString(this.m_scanPoi) + " son POI) | candidatos con posicion " + IntToString(this.m_candFound) + "/"
            + IntToString(this.m_candCount) + " (por hash estatico " + IntToString(this.m_scanStatic) + ", por plan B journal "
            + IntToString(this.m_scanJournal) + ") | POI sin candidato " + IntToString(this.m_scanUnmatched)
            + (StrLen(this.m_scanExample) > 0 ? " (ej. hash " + this.m_scanExample + ")" : "") + " | candidatos dentro de area de seguridad "
            + IntToString(this.m_scanSecure) + " | mappins de mision " + IntToString(ArraySize(this.m_questPos)) + ", de zona segura "
            + IntToString(ArraySize(this.m_safePos)));
        this.Log("Guaridas auto: hash estatico vs journal: " + IntToString(this.m_journalSame) + " iguales de " + IntToString(this.m_journalFound)
            + " paths que el journal conoce (de " + IntToString(this.m_candCount) + " candidatos)"
            + (StrLen(this.m_journalExample) > 0 ? " | distinto, ej. " + this.m_journalExample : ""));
        let line: String = "";
        let g: Int32 = 0;
        while g < ArraySize(this.m_gangList) {
            let total: Int32 = 0;
            let known: Int32 = 0;
            let i: Int32 = 0;
            while i < this.m_candCount {
                if Equals(this.m_candGangs[i], this.m_gangList[g]) {
                    total += 1;
                    if this.m_candKnown[i] {
                        known += 1;
                    }
                }
                i += 1;
            }
            if StrLen(line) > 0 {
                line += ", ";
            }
            line += this.m_gangList[g] + " " + IntToString(known) + "/" + IntToString(total);
            g += 1;
        }
        this.Log("Guaridas auto: candidatos con posicion por banda: " + line);
        if this.m_scanPoi == 0 {
            let system: ref<MappinSystem> = GameInstance.GetMappinSystem(this.GetGameInstance());
            let world: array<ref<IMappin>>;
            let minimap: array<ref<IMappin>>;
            system.GetMappins(gamemappinsMappinTargetType.World, world);
            system.GetMappins(gamemappinsMappinTargetType.Minimap, minimap);
            this.Log("Guaridas auto: ningun POI outpost/gangwatch en GetMappins(Map) (" + IntToString(this.m_scanVariant)
                + " mappins de esas variantes en total): los POI sin descubrir no aparecen o no son PointOfInterestMappin. Otras listas: World "
                + IntToString(ArraySize(world)) + ", Minimap " + IntToString(ArraySize(minimap)) + " mappins. Todas las bandas siguen en el sitio fijo");
        }
    }

    private func GetChosen(site: Int32) -> Int32 {
        let slot: Int32 = this.GangSlot(this.m_siteGangs[site]);
        if slot < 0 || slot >= ArraySize(this.m_chosen) {
            return 0;
        }
        return this.m_chosen[slot];
    }

    private func SiteLabel(site: Int32) -> String {
        let chosen: Int32 = this.GetChosen(site);
        if chosen <= 0 || chosen > this.m_candCount {
            return "sitio fijo";
        }
        return this.m_candIds[chosen - 1];
    }

    private func ApplyChoices() {
        this.EnsureCandidates();
        this.EnsureChoices();
        let i: Int32 = 0;
        while i < ArraySize(this.m_siteGangs) {
            let slot: Int32 = this.GangSlot(this.m_siteGangs[i]);
            if slot >= 0 && this.m_chosen[slot] > 0 {
                let cand: Int32 = this.m_chosen[slot] - 1;
                let x: Float = this.m_chosenX[slot];
                let y: Float = this.m_chosenY[slot];
                if cand < this.m_candCount && Equals(this.m_candGangs[cand], this.m_siteGangs[i]) && (AbsF(x) > 0.01 || AbsF(y) > 0.01) {
                    this.m_sitePos[i] = new Vector4(x, y, this.m_chosenZ[slot], 1.0);
                    this.Log("Guarida (" + this.m_siteGangs[i] + "): en " + this.m_candIds[cand] + " (eleccion guardada en la partida)");
                } else {
                    this.m_chosen[slot] = 0;
                    this.Log("Guarida (" + this.m_siteGangs[i] + "): eleccion guardada invalida (candidato " + IntToString(cand) + "), vuelve al sitio fijo");
                }
            }
            i += 1;
        }
    }

    private func IsNearMappin(mission: Bool, pos: Vector4, radius: Float) -> Bool {
        let count: Int32 = mission ? ArraySize(this.m_questPos) : ArraySize(this.m_safePos);
        let i: Int32 = 0;
        while i < count {
            let other: Vector4 = mission ? this.m_questPos[i] : this.m_safePos[i];
            if Vector4.Distance2D(pos, other) < radius {
                return true;
            }
            i += 1;
        }
        return false;
    }

    private func IsNearOtherSite(site: Int32, pos: Vector4, radius: Float) -> Bool {
        let i: Int32 = 0;
        while i < ArraySize(this.m_sitePos) {
            if i != site && Vector4.Distance2D(pos, this.m_sitePos[i]) < radius {
                return true;
            }
            i += 1;
        }
        return false;
    }

    private func ChooseCandidate(site: Int32, exclude: Int32, avoid: Vector4, useAvoid: Bool, out discarded: String) -> Int32 {
        let gang: String = this.m_siteGangs[site];
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let hasPlayer: Bool = IsDefined(player);
        let playerPos: Vector4;
        if hasPlayer {
            playerPos = player.GetWorldPosition();
        }
        let outposts: array<Int32>;
        let watches: array<Int32>;
        let nMission: Int32 = 0;
        let nSafe: Int32 = 0;
        let nOther: Int32 = 0;
        let nPlayer: Int32 = 0;
        let nNoPos: Int32 = 0;
        let nBad: Int32 = 0;
        let i: Int32 = 0;
        while i < this.m_candCount {
            if i != exclude && Equals(this.m_candGangs[i], gang) {
                let pos: Vector4 = this.m_candPos[i];
                if !this.m_candKnown[i] {
                    nNoPos += 1;
                } else if this.m_candBad[i] {
                    nBad += 1;
                } else if hasPlayer && Vector4.Distance2D(pos, playerPos) < 200.0 {
                    nPlayer += 1;
                } else if this.IsNearOtherSite(site, pos, 400.0) || (useAvoid && Vector4.Distance2D(pos, avoid) < 400.0) {
                    nOther += 1;
                } else if this.IsNearMappin(false, pos, 60.0) {
                    nSafe += 1;
                } else if this.IsNearMappin(true, pos, 150.0) {
                    nMission += 1;
                } else if this.m_candVariants[i] == 0 {
                    ArrayPush(outposts, i);
                } else {
                    ArrayPush(watches, i);
                }
            }
            i += 1;
        }
        discarded = "descartados: mision " + IntToString(nMission) + ", zona segura " + IntToString(nSafe) + ", cerca de otra "
            + IntToString(nOther) + ", cerca de V " + IntToString(nPlayer) + " | sin posicion " + IntToString(nNoPos) + ", sin puestos "
            + IntToString(nBad) + " | validos: " + IntToString(ArraySize(outposts)) + " outpost, " + IntToString(ArraySize(watches)) + " gangwatch";
        let count: Int32 = ArraySize(outposts);
        if count > 0 {
            return outposts[Min(RandRange(0, count), count - 1)];
        }
        count = ArraySize(watches);
        if count > 0 {
            return watches[Min(RandRange(0, count), count - 1)];
        }
        return -1;
    }

    private func MoveSite(site: Int32, cand: Int32) {
        this.EnsureChoices();
        let slot: Int32 = this.GangSlot(this.m_siteGangs[site]);
        if slot < 0 {
            return;
        }
        if cand >= 0 {
            let pos: Vector4 = this.m_candPos[cand];
            this.m_chosen[slot] = cand + 1;
            this.m_chosenX[slot] = pos.X;
            this.m_chosenY[slot] = pos.Y;
            this.m_chosenZ[slot] = pos.Z;
            this.m_sitePos[site] = pos;
        } else {
            this.m_chosen[slot] = 0;
            this.m_chosenX[slot] = 0.0;
            this.m_chosenY[slot] = 0.0;
            this.m_chosenZ[slot] = 0.0;
            this.m_sitePos[site] = this.m_siteFixed[site];
        }
        this.m_siteChoiceLog[site] = "";
        this.RemoveSiteMappin(site);
        if this.m_visitSite == site + 1 {
            this.m_visitSite = 0;
        }
    }

    private func LogChosen(site: Int32, cand: Int32, discarded: String) {
        this.Log("Guarida (" + this.m_siteGangs[site] + "): elegida " + this.m_candIds[cand] + " (" + (this.m_candVariants[cand] == 0 ? "outpost" : "gangwatch")
            + ") a " + IntToString(Cast<Int32>(this.GetSiteDistance(site))) + " m de V | " + discarded);
    }

    private func Relocate(site: Int32, reason: String) -> Bool {
        let gang: String = this.m_siteGangs[site];
        let current: Int32 = this.GetChosen(site) - 1;
        let oldPos: Vector4 = this.m_sitePos[site];
        let oldLabel: String = this.SiteLabel(site);
        this.ScanMappins();
        let discarded: String;
        let cand: Int32 = this.ChooseCandidate(site, current, oldPos, true, discarded);
        if cand < 0 && current < 0 {
            this.Log("Guarida (" + gang + "): no se muda (" + reason + "), sin candidato valido: sigue en el sitio fijo | " + discarded);
            return false;
        }
        this.MoveSite(site, cand);
        if cand >= 0 {
            this.LogChosen(site, cand, discarded);
        } else {
            this.Log("Guarida (" + gang + "): sin candidato valido, vuelve al sitio fijo | " + discarded);
        }
        this.Log("Guarida (" + gang + "): se muda de " + oldLabel + " a " + this.SiteLabel(site) + " (" + reason + ")");
        return true;
    }

    private func TickCandidates() {
        this.m_ticks += 1;
        if !this.m_scanLogged {
            if this.m_ticks < 3 || (this.m_ticks - 3) % 5 != 0 {
                return;
            }
            this.ScanMappins();
            this.m_scanTries += 1;
            if this.m_candFound > 0 || this.m_scanTries >= 6 {
                this.m_scanLogged = true;
                this.LogScan();
            }
            return;
        }
        if this.m_choiceWait > 0 {
            this.m_choiceWait -= 1;
            return;
        }
        this.AutoChoose();
    }

    private func AutoChoose() {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) {
            return;
        }
        let intel: ref<GRIntelSystem> = GRIntelSystem.Get(this.GetGameInstance());
        if !IsDefined(intel) {
            return;
        }
        let none: Vector4;
        let pending: Bool = false;
        let scanned: Bool = false;
        let i: Int32 = 0;
        while i < ArraySize(this.m_siteGangs) {
            let gang: String = this.m_siteGangs[i];
            if this.GetChosen(i) == 0 && !intel.IsLocated(gang) && this.HasCandidates(gang) {
                let busy: Bool = (this.m_active && this.m_activeSite == i) || this.GetSiteDistance(i) < 250.0;
                if busy {
                    pending = true;
                } else {
                    if !scanned {
                        this.ScanMappins();
                        scanned = true;
                    }
                    let discarded: String;
                    let cand: Int32 = this.ChooseCandidate(i, -1, none, false, discarded);
                    if cand >= 0 {
                        this.MoveSite(i, cand);
                        this.LogChosen(i, cand, discarded);
                    } else {
                        pending = true;
                        if NotEquals(this.m_siteChoiceLog[i], discarded) {
                            this.m_siteChoiceLog[i] = discarded;
                            this.Log("Guarida (" + gang + "): sin candidato valido, sigue en el sitio fijo (reintenta cada 60 s) | " + discarded);
                        }
                    }
                }
            }
            i += 1;
        }
        if pending {
            this.m_choiceWait = 60;
        }
    }

    private func HasCandidates(gang: String) -> Bool {
        let i: Int32 = 0;
        while i < this.m_candCount {
            if Equals(this.m_candGangs[i], gang) {
                return true;
            }
            i += 1;
        }
        return false;
    }

    private func CountPoliceNear(pos: Vector4, radius: Float) -> Int32 {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) {
            return 0;
        }
        let query: TargetSearchQuery;
        query.testedSet = TargetingSet.Complete;
        query.searchFilter = TSF_NPC();
        query.maxDistance = Vector4.Distance(player.GetWorldPosition(), pos) + radius;
        query.filterObjectByDistance = true;
        query.includeSecondaryTargets = false;
        query.ignoreInstigator = true;
        let parts: array<TS_TargetPartInfo>;
        GameInstance.GetTargetingSystem(this.GetGameInstance()).GetTargetParts(player, query, parts);
        let seen: array<EntityID>;
        let i: Int32 = 0;
        while i < ArraySize(parts) {
            let component: wref<TargetingComponent> = TS_TargetPartInfo.GetComponent(parts[i]);
            if IsDefined(component) {
                let npc: ref<ScriptedPuppet> = component.GetEntity() as ScriptedPuppet;
                if IsDefined(npc) && !GRDetection.IsNeutralized(npc) && Vector4.Distance2D(npc.GetWorldPosition(), pos) < radius
                    && !ArrayContains(seen, npc.GetEntityID()) {
                    let record: wref<Character_Record> = npc.GetRecord();
                    if IsDefined(record) && IsDefined(record.Affiliation()) && Equals(record.Affiliation().Type(), gamedataAffiliation.NCPD) {
                        ArrayPush(seen, npc.GetEntityID());
                    }
                }
            }
            i += 1;
        }
        return ArraySize(seen);
    }

    private func Revalidate(spawner: ref<GRSpawner>, site: Int32, near: Bool) -> Int32 {
        let gang: String = this.m_siteGangs[site];
        let pos: Vector4 = this.m_sitePos[site];
        let where: String = near ? "de cerca" : "de lejos";
        let reason: String = "";
        let badPosts: Bool = false;
        if !near {
            this.ScanMappins();
            if spawner.IsQuestObjectiveNearby() {
                reason = "objetivo de mision seguido a menos de 150 m de V";
            } else if this.IsNearMappin(true, pos, 150.0) {
                reason = "mappin de mision a menos de 150 m";
            }
        }
        let postsText: String = "ya validados";
        if StrLen(reason) == 0 && !this.m_visitPosts {
            let nav: ref<NavigationSystem> = GameInstance.GetNavigationSystem(this.GetGameInstance());
            let streamed: Bool = nav.IsNavmeshStreamedInLocation(pos, 2.0);
            let posts: Int32 = this.TestSite(pos.X, pos.Y, pos.Z);
            postsText = IntToString(posts) + "/20 (navmesh " + (streamed ? "cargado" : "sin cargar") + ")";
            if posts >= GRStronghold.MinPosts() {
                this.m_visitPosts = true;
            } else if near {
                this.m_visitTries += 1;
                if this.m_visitTries < GRStronghold.SpotWait() {
                    return 1;
                }
                let snapped: Vector4 = nav.GetNearestNavmeshPointBelowOnlyHumanNavmesh(pos + new Vector4(0.0, 0.0, 2.0, 0.0), 3.0, 6);
                let retry: Int32 = 0;
                if !Vector4.IsZero(snapped) && Vector4.Distance(snapped, pos) > 0.5 {
                    retry = this.TestSite(snapped.X, snapped.Y, snapped.Z);
                }
                if retry >= GRStronghold.MinPosts() {
                    snapped.W = 1.0;
                    this.Log("Guarida (" + gang + "): centro de " + this.SiteLabel(site) + " ajustado al navmesh (" + IntToString(posts) + " -> "
                        + IntToString(retry) + " puestos; Z " + FloatToStringPrec(pos.Z, 2) + " -> " + FloatToStringPrec(snapped.Z, 2) + ", "
                        + FloatToStringPrec(Vector4.Distance2D(snapped, pos), 1) + " m en planta)");
                    this.SetSitePosition(site, snapped);
                    pos = snapped;
                    postsText = IntToString(retry) + "/20 (centro ajustado)";
                    this.m_visitPosts = true;
                } else {
                    reason = "solo " + IntToString(posts) + " de 20 puestos (navmesh " + (streamed ? "cargado" : "sin cargar") + ")";
                    badPosts = true;
                }
            } else {
                postsText += ", se repite de cerca";
            }
        }
        if StrLen(reason) == 0 {
            let police: Int32 = this.CountPoliceNear(pos, 50.0);
            if police > 0 {
                reason = IntToString(police) + " NCPD a menos de 50 m";
            }
        }
        if StrLen(reason) == 0 {
            this.Log("Guarida (" + gang + "): revalidada " + where + " (" + this.SiteLabel(site) + ", V a "
                + IntToString(Cast<Int32>(this.GetSiteDistance(site))) + " m): sin mision, sin NCPD, puestos " + postsText);
            return 0;
        }
        let intel: ref<GRIntelSystem> = GRIntelSystem.Get(this.GetGameInstance());
        if !IsDefined(intel) || intel.IsLocated(gang) {
            this.Log("Guarida (" + gang + "): falla la revalidacion " + where + " (" + reason + ") pero ya esta localizada: no se muda");
            return 0;
        }
        let current: Int32 = this.GetChosen(site) - 1;
        if badPosts && current >= 0 && current < this.m_candCount {
            this.m_candBad[current] = true;
        }
        this.Log("Guarida (" + gang + "): falla la revalidacion " + where + " de " + this.SiteLabel(site) + " (" + reason + "), se muda en silencio");
        if this.Relocate(site, "revalidacion") {
            return 2;
        }
        return 0;
    }

    private func SetSitePosition(site: Int32, pos: Vector4) {
        this.m_sitePos[site] = pos;
        let slot: Int32 = this.GangSlot(this.m_siteGangs[site]);
        if slot >= 0 && slot < ArraySize(this.m_chosen) && this.m_chosen[slot] > 0 {
            this.m_chosenX[slot] = pos.X;
            this.m_chosenY[slot] = pos.Y;
            this.m_chosenZ[slot] = pos.Z;
        }
        this.RemoveSiteMappin(site);
    }

    public func DevMove(gang: String) -> String {
        let site: Int32 = this.FindSite(gang);
        if site < 0 {
            return "No stronghold for " + gang;
        }
        let from: String = this.SiteLabel(site);
        if !this.Relocate(site, "dev") {
            return gang + ": no valid candidate, stays at " + from + " (see log)";
        }
        let intel: ref<GRIntelSystem> = GRIntelSystem.Get(this.GetGameInstance());
        if IsDefined(intel) {
            intel.ResetIntel(gang, "mudanza dev");
        }
        return gang + ": " + from + " -> " + this.SiteLabel(site) + ", " + IntToString(Cast<Int32>(this.GetSiteDistance(site))) + " m from V";
    }

    public func GetSiteInfo(gang: String) -> String {
        let site: Int32 = this.FindSite(gang);
        if site < 0 {
            return "No stronghold for " + gang;
        }
        let pos: Vector4 = this.m_sitePos[site];
        return gang + ": " + this.SiteLabel(site) + " @ " + FloatToStringPrec(pos.X, 1) + ", " + FloatToStringPrec(pos.Y, 1) + ", "
            + FloatToStringPrec(pos.Z, 1) + " | " + IntToString(Cast<Int32>(this.GetSiteDistance(site))) + " m from V, "
            + IntToString(this.m_siteMembers[site]) + " inside | candidates with position " + IntToString(this.m_candFound) + "/"
            + IntToString(this.m_candCount);
    }


    public func Tick() {
        this.EnsureSites();
        this.TickCandidates();
        this.RefreshMappins();
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) {
            return;
        }
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());

        if this.m_active {
            if !spawner.IsStrongholdActive() {
                this.m_active = false;
                this.StopPopulating();
                return;
            }
            let gang: String = this.m_siteGangs[this.m_activeSite];
            if this.m_populating {
                this.FillPosts(spawner, player);
                if !this.m_active {
                    return;
                }
            }
            if this.m_hunt > 0 {
                if !this.m_populating && !this.m_cleared && spawner.CountStanding() == 0 {
                    this.m_cleared = true;
                    GRLog(this.ActiveLabel() + ": no queda nadie en pie");
                }
                if Vector4.Distance2D(player.GetWorldPosition(), this.m_activePos) > 250.0 && !player.IsInCombat() {
                    GRLog(this.ActiveLabel() + ": V se fue (>250 m, fuera de combate), se recogen; vuelven si V regresa con el contrato abierto");
                    spawner.DespawnAll();
                    this.m_active = false;
                    this.StopPopulating();
                }
                return;
            }
            if !this.m_populating && !this.m_cleared && spawner.CountStanding() == 0 {
                this.m_cleared = true;
                ArrayPush(this.m_events, "cleared:" + gang);
                this.Log("Guarida (" + gang + "): tomada");
                if this.Relocate(this.m_activeSite, "tomada") {
                    let intel: ref<GRIntelSystem> = GRIntelSystem.Get(this.GetGameInstance());
                    if IsDefined(intel) {
                        intel.ResetIntel(gang, "guarida tomada, la banda se muda");
                    }
                } else {
                    this.MarkLocated(gang, "guarida tomada");
                }
            }
            if Vector4.Distance2D(player.GetWorldPosition(), this.m_activePos) > 250.0 && !player.IsInCombat() {
                spawner.DespawnAll();
                this.m_active = false;
                this.StopPopulating();
                ArrayPush(this.m_events, "left:" + gang);
                this.Log("Guarida (" + gang + "): V se fue, se recogen");
            }
            return;
        }

        if this.TryHunt(spawner, player) {
            return;
        }

        let site: Int32 = this.FindNearest(true);
        if site < 0 {
            this.m_visitSite = 0;
            return;
        }
        let distance: Float = this.GetSiteDistance(site);
        if this.m_visitSite != site + 1 {
            this.m_visitSite = 0;
            if distance > GRStronghold.CheckDistance() {
                return;
            }
            this.m_visitSite = site + 1;
            this.m_visitPosts = false;
            this.m_visitNear = false;
            this.m_visitTries = 0;
            if this.Revalidate(spawner, site, false) == 2 {
                return;
            }
        } else if distance > 200.0 {
            this.m_visitSite = 0;
            return;
        }
        if distance > GRStronghold.SpawnDistance() {
            return;
        }
        let blocker: String = spawner.GetAmbushBlocker();
        if StrLen(blocker) > 0 {
            return;
        }
        if !this.m_visitNear {
            if this.Revalidate(spawner, site, true) != 0 {
                return;
            }
            this.m_visitNear = true;
        }
        this.BeginPopulate(spawner, player, site);
    }

    private func StopPopulating() {
        ArrayClear(this.m_pending);
        this.m_populating = false;
        this.m_hunt = 0;
        ArrayClear(this.m_origins);
    }

    private func ActiveLabel() -> String {
        let gang: String = this.GetSiteGang(this.m_activeSite);
        if this.m_hunt > 0 {
            return "Caza #" + IntToString(this.m_hunt) + " (" + gang + ")";
        }
        return "Guarida (" + gang + ")";
    }

    // Zona de caza del Bounty Board: si V esta a menos de 90 m del punto real de un contrato aceptado,
    // aparecen el Nemesis y 2-3 escoltas ahi (mismo relleno de puestos que la guarida, sin Lua).
    private func TryHunt(spawner: ref<GRSpawner>, player: ref<PlayerPuppet>) -> Bool {
        if this.m_huntWait > 0 {
            this.m_huntWait -= 1;
            return false;
        }
        let bounties: ref<GRBounties> = GRBounties.Get(this.GetGameInstance());
        if !IsDefined(bounties) {
            return false;
        }
        let nemesisId: Int32 = 0;
        let spot: Vector4;
        // Antes de poder aparecer: los puntos de caza sin validar a < 200 m de V se revalidan contra la superficie (si estan cubiertos, la zona se muda).
        bounties.CheckHuntSurface(player.GetWorldPosition());
        if !bounties.NearestHunt(player.GetWorldPosition(), GRBounties.HuntSpawnDistance(), nemesisId, spot) {
            this.m_huntLog = "";
            return false;
        }
        let blocker: String = spawner.GetAmbushBlocker();
        if StrLen(blocker) == 0 && spawner.IsNemesisSpawned(nemesisId) {
            blocker = "el Nemesis ya esta en el mundo";
        }
        let member: Int32 = ArrayFindFirst(this.m_ids, nemesisId);
        if StrLen(blocker) == 0 && member < 0 {
            blocker = "no esta entre los miembros vivos de su banda (sin record)";
        }
        if StrLen(blocker) > 0 {
            let key: String = IntToString(nemesisId) + ":" + blocker;
            if NotEquals(this.m_huntLog, key) {
                this.m_huntLog = key;
                GRLog("Caza #" + IntToString(nemesisId) + ": V a " + IntToString(Cast<Int32>(Vector4.Distance2D(player.GetWorldPosition(), spot))) + " m del punto, espera ("
                    + blocker + ")");
            }
            return false;
        }
        this.m_huntLog = "";
        return this.BeginHunt(spawner, player, member, nemesisId, spot);
    }

    private func HuntCenter(spawner: ref<GRSpawner>, spot: Vector4) -> Vector4 {
        let nav: ref<NavigationSystem> = GameInstance.GetNavigationSystem(this.GetGameInstance());
        let radii: array<Float> = [0.0, 6.0, 12.0, 20.0, 30.0];
        for radius in radii {
            let k: Int32 = 0;
            let steps: Int32 = radius > 0.0 ? 6 : 1;
            while k < steps {
                let angle: Float = 2.0 * Pi() * Cast<Float>(k) / Cast<Float>(steps);
                let raw: Vector4 = spot + new Vector4(CosF(angle) * radius, SinF(angle) * radius, 2.0, 0.0);
                let pos: Vector4 = nav.GetNearestNavmeshPointBelowOnlyHumanNavmesh(raw, 3.0, 6);
                if !Vector4.IsZero(pos) && AbsF(pos.Z - spot.Z) < 6.0 && spawner.IsClearSpot(pos) {
                    pos.W = 1.0;
                    return pos;
                }
                k += 1;
            }
        }
        return Vector4.EmptyVector();
    }

    private func BeginHunt(spawner: ref<GRSpawner>, player: ref<PlayerPuppet>, member: Int32, nemesisId: Int32, spot: Vector4) -> Bool {
        let site: Int32 = this.m_memberSites[member];
        let gang: String = this.m_siteGangs[site];
        let center: Vector4 = this.HuntCenter(spawner, spot);
        if Vector4.IsZero(center) {
            this.m_huntWait = 10;
            GRLog("Caza #" + IntToString(nemesisId) + " (" + gang + "): sin navmesh libre a menos de 30 m del punto (" + FloatToStringPrec(spot.X, 1) + ", "
                + FloatToStringPrec(spot.Y, 1) + ", " + FloatToStringPrec(spot.Z, 1) + "), reintenta en 10 s");
            return false;
        }
        ArrayClear(this.m_pending);
        let leader: ref<GRPendingPost> = new GRPendingPost();
        leader.nemesisId = nemesisId;
        leader.record = this.m_records[member];
        leader.appearance = this.m_appearances[member];
        leader.speaker = this.m_speakers[member];
        leader.angle = 0.0;
        leader.radius = 0.0;
        ArrayPush(this.m_pending, leader);
        let guards: array<String>;
        let records: String = this.m_siteGuards[site];
        if StrLen(records) > 0 {
            guards = StrSplit(records, ",");
        }
        let escorts: Int32 = Min(RandRange(2, 4), ArraySize(guards));
        let start: Int32 = ArraySize(guards) > 0 ? RandRange(0, ArraySize(guards)) : 0;
        let k: Int32 = 0;
        while k < escorts {
            let escort: ref<GRPendingPost> = new GRPendingPost();
            escort.record = guards[(start + k) % ArraySize(guards)];
            escort.angle = 2.0 * Pi() * Cast<Float>(k) / Cast<Float>(Max(escorts, 1)) + RandRangeF(-0.3, 0.3);
            escort.radius = RandRangeF(3.0, 6.0);
            ArrayPush(this.m_pending, escort);
            k += 1;
        }
        spawner.BeginStronghold();
        this.m_active = true;
        this.m_activeSite = site;
        this.m_activePos = center;
        this.m_hunt = nemesisId;
        ArrayClear(this.m_origins);
        this.m_cleared = false;
        this.m_populating = true;
        this.m_announced = false;
        this.m_fillTicks = 0;
        this.m_placed = 0;
        this.m_failed = 0;
        this.m_fillStats = [0, 0, 0, 0, 0];
        GRLog(this.ActiveLabel() + ": V a " + IntToString(Cast<Int32>(Vector4.Distance2D(player.GetWorldPosition(), center))) + " m del punto de caza, Nemesis + "
            + IntToString(escorts) + " escoltas (centro ajustado " + FloatToStringPrec(Vector4.Distance2D(center, spot), 1) + " m)");
        this.FillPosts(spawner, player);
        return true;
    }

    private func BeginPopulate(spawner: ref<GRSpawner>, player: ref<PlayerPuppet>, site: Int32) {
        let gang: String = this.m_siteGangs[site];
        ArrayClear(this.m_pending);
        ArrayClear(this.m_origins);
        this.m_hunt = 0;
        let slot: Int32 = 0;
        let i: Int32 = 0;
        while i < ArraySize(this.m_ids) {
            if this.m_memberSites[i] == site {
                let member: ref<GRPendingPost> = new GRPendingPost();
                member.nemesisId = this.m_ids[i];
                member.record = this.m_records[i];
                member.appearance = this.m_appearances[i];
                member.speaker = this.m_speakers[i];
                member.angle = Cast<Float>(slot) * 2.1;
                member.radius = slot == 0 ? 0.0 : RandRangeF(4.0, 6.0);
                ArrayPush(this.m_pending, member);
                slot += 1;
            }
            i += 1;
        }
        let guards: array<String>;
        let records: String = this.m_siteGuards[site];
        if StrLen(records) > 0 {
            guards = StrSplit(records, ",");
        }
        let count: Int32 = ArraySize(guards);
        let inner: Int32 = Min(count, 8);
        i = 0;
        while i < count {
            let outer: Bool = i >= inner;
            let ring: Int32 = outer ? count - inner : inner;
            let ringSlot: Int32 = outer ? i - inner : i;
            let guard: ref<GRPendingPost> = new GRPendingPost();
            guard.record = guards[i];
            guard.angle = 2.0 * Pi() * Cast<Float>(ringSlot) / Cast<Float>(Max(ring, 1)) + (outer ? 0.4 : 0.0) + RandRangeF(-0.2, 0.2);
            guard.radius = outer ? RandRangeF(14.0, 20.0) : RandRangeF(8.0, 12.0);
            ArrayPush(this.m_pending, guard);
            i += 1;
        }
        if ArraySize(this.m_pending) == 0 {
            return;
        }
        spawner.BeginStronghold();
        this.m_active = true;
        this.m_activeSite = site;
        this.m_activePos = this.m_sitePos[site];
        this.m_cleared = false;
        this.m_populating = true;
        this.m_announced = false;
        this.m_fillTicks = 0;
        this.m_placed = 0;
        this.m_failed = 0;
        this.m_fillStats = [0, 0, 0, 0, 0];
        this.Log("Guarida (" + gang + "): V a " + IntToString(Cast<Int32>(this.GetSiteDistance(site))) + " m, "
            + IntToString(ArraySize(this.m_pending)) + " puestos por ocupar");
        this.FillPosts(spawner, player);
    }

    private func FillPosts(spawner: ref<GRSpawner>, player: ref<PlayerPuppet>) {
        let gang: String = this.m_siteGangs[this.m_activeSite];
        let center: Vector4 = this.m_activePos;
        let playerPos: Vector4 = player.GetWorldPosition();
        this.m_fillTicks += 1;
        let spawnedNow: Int32 = 0;
        let waitSpot: Int32 = 0;
        let waitGround: Int32 = 0;
        let waitSight: Int32 = 0;
        let i: Int32 = 0;
        while i < ArraySize(this.m_pending) {
            let post: ref<GRPendingPost> = this.m_pending[i];
            let done: Bool = false;
            post.waited += 1;
            if !post.hasPos {
                let found: Vector4 = this.FindPost(spawner, center, post.angle, post.radius);
                if !Vector4.IsZero(found) {
                    post.pos = found;
                    post.hasPos = true;
                    post.waited = 1;
                } else if post.waited >= GRStronghold.SpotWait() {
                    this.m_failed += 1;
                    done = true;
                } else {
                    waitSpot += 1;
                }
            }
            if post.hasPos {
                let groundZ: Float = 0.0;
                let ground: Bool = spawner.GroundBelow(post.pos, groundZ);
                let seen: Bool = spawner.IsPostSeen(player, post.pos);
                let groundOk: Bool = ground || post.waited > GRStronghold.GroundWait();
                let sightOk: Bool = !seen || Vector4.Distance(playerPos, post.pos) < GRStronghold.ForcedDistance() || post.waited > GRStronghold.SightWait();
                if !groundOk {
                    post.waitedGround = true;
                    waitGround += 1;
                } else if !sightOk {
                    post.waitedSight = true;
                    waitSight += 1;
                } else {
                    let spawnPos: Vector4 = post.pos;
                    let drop: Float = ground ? post.pos.Z - groundZ : 0.0;
                    let snap: Bool = ground && drop > -0.4 && AbsF(drop) > 0.05;
                    if snap {
                        spawnPos.Z = groundZ;
                    }
                    if spawner.SpawnPosted(post.nemesisId, post.record, post.appearance, spawnPos, center, post.speaker) {
                        this.m_placed += 1;
                        spawnedNow += 1;
                        if post.nemesisId > 0 && this.m_hunt == 0 && !ArrayContains(this.m_origins, post.nemesisId) {
                            ArrayPush(this.m_origins, post.nemesisId);
                        }
                        if snap {
                            this.m_fillStats[4] += 1;
                            if AbsF(drop) > 0.3 {
                                GRLog(this.ActiveLabel() + ": puesto con el navmesh a " + FloatToStringPrec(drop, 2) + " m del suelo real (Z "
                                    + FloatToStringPrec(post.pos.Z, 2) + " -> " + FloatToStringPrec(groundZ, 2) + "): aparece en el suelo");
                            }
                        }
                        if post.waitedGround {
                            this.m_fillStats[0] += 1;
                            if !ground {
                                this.m_fillStats[1] += 1;
                            }
                        }
                        if post.waitedSight {
                            this.m_fillStats[2] += 1;
                            if seen {
                                this.m_fillStats[3] += 1;
                            }
                        }
                        done = true;
                    } else if post.waited > GRStronghold.GroundWait() {
                        this.m_failed += 1;
                        done = true;
                    }
                }
            }
            if done {
                ArrayErase(this.m_pending, i);
            } else {
                i += 1;
            }
        }
        if this.m_placed > 0 && !this.m_announced {
            this.m_announced = true;
            if this.m_hunt == 0 {
                ArrayPush(this.m_events, "spawned:" + gang);
                this.MarkLocated(gang, "V llego a la guarida");
            }
        }
        if this.m_fillTicks == 1 {
            GRLog(this.ActiveLabel() + ": primer intento, " + IntToString(spawnedNow) + " aparecen, " + IntToString(waitGround)
                + " esperan suelo, " + IntToString(waitSight) + " esperan a que V no mire, " + IntToString(waitSpot) + " sin sitio todavia");
        }
        if ArraySize(this.m_pending) > 0 {
            return;
        }
        this.m_populating = false;
        if this.m_placed == 0 {
            GRLog(this.ActiveLabel() + ": sin puestos validos en el navmesh");
            if this.m_hunt > 0 {
                this.m_huntWait = 30;
            }
            spawner.DespawnAll();
            this.m_active = false;
            this.StopPopulating();
            return;
        }
        GRLog(this.ActiveLabel() + ": " + IntToString(this.m_placed) + " en sus puestos, " + IntToString(this.m_failed) + " sin sitio, en "
            + IntToString(this.m_fillTicks) + " s | esperaron suelo " + IntToString(this.m_fillStats[0]) + " (" + IntToString(this.m_fillStats[1])
            + " aparecieron sin suelo) | esperaron a que V no mire " + IntToString(this.m_fillStats[2]) + " (" + IntToString(this.m_fillStats[3])
            + " aparecieron a la vista) | bajados al suelo " + IntToString(this.m_fillStats[4]));
    }

    private func FindPost(spawner: ref<GRSpawner>, center: Vector4, angle: Float, radius: Float) -> Vector4 {
        let tries: array<Float> = [1.0, 0.7, 0.4];
        for scale in tries {
            let pos: Vector4 = spawner.PostSpot(center, angle + (1.0 - scale), radius * scale);
            if !Vector4.IsZero(pos) {
                return pos;
            }
        }
        return Vector4.EmptyVector();
    }
}

public class GRPendingPost {
    public let nemesisId: Int32;
    public let record: String;
    public let appearance: String;
    public let speaker: String;
    public let angle: Float;
    public let radius: Float;
    public let pos: Vector4;
    public let hasPos: Bool;
    public let waited: Int32;
    public let waitedGround: Bool;
    public let waitedSight: Bool;
}

public class GRStrongholdMappinData extends MappinScriptData {
    public let gang: String;
    private let m_loggedMap: Bool;
    private let m_loggedMinimap: Bool;
    private let m_loggedWorld: Bool;
    private let m_loggedTooltip: Bool;
    private let m_loggedFilter: Int32;

    public static func IconPart() -> CName {
        return n"devil_horns";
    }

    public func LogFilter(shown: Bool) -> Void {
        let state: Int32 = shown ? 1 : 2;
        if this.m_loggedFilter == state {
            return;
        }
        this.m_loggedFilter = state;
        let what: String = shown ? "visible" : "oculta";
        GRLog("Guarida (" + this.gang + "): " + what + " en el mapa por la casilla GUARIDAS");
    }

    public static func ViewMap() -> Int32 { return 0; }
    public static func ViewMinimap() -> Int32 { return 1; }
    public static func ViewWorld() -> Int32 { return 2; }
    public static func ViewTooltip() -> Int32 { return 3; }

    public static func Of(mappin: wref<IMappin>) -> wref<GRStrongholdMappinData> {
        if !IsDefined(mappin) {
            return null;
        }
        return mappin.GetScriptData() as GRStrongholdMappinData;
    }

    public func LogOnce(view: Int32) -> Void {
        let what: String;
        if view == GRStrongholdMappinData.ViewMap() {
            if this.m_loggedMap {
                return;
            }
            this.m_loggedMap = true;
            what = "icono devil_horns en el mapa grande";
        } else if view == GRStrongholdMappinData.ViewMinimap() {
            if this.m_loggedMinimap {
                return;
            }
            this.m_loggedMinimap = true;
            what = "icono devil_horns en el minimapa";
        } else if view == GRStrongholdMappinData.ViewWorld() {
            if this.m_loggedWorld {
                return;
            }
            this.m_loggedWorld = true;
            what = "icono devil_horns en el marcador del mundo";
        } else {
            if this.m_loggedTooltip {
                return;
            }
            this.m_loggedTooltip = true;
            what = "titulo propio en el tooltip del mapa";
        }
        GRLog("Guarida (" + this.gang + "): " + what);
    }
}

public func GRApplyMappinIcon(mappin: wref<IMappin>, icon: inkImageRef, view: Int32) -> Void {
    if !IsDefined(mappin) {
        return;
    }
    let data: wref<MappinScriptData> = mappin.GetScriptData();
    if !IsDefined(data) {
        return;
    }
    let stronghold: wref<GRStrongholdMappinData> = data as GRStrongholdMappinData;
    if IsDefined(stronghold) {
        inkImageRef.SetTexturePart(icon, GRStrongholdMappinData.IconPart());
        stronghold.LogOnce(view);
        return;
    }
    let zone: wref<GRBountyZoneMappinData> = data as GRBountyZoneMappinData;
    if IsDefined(zone) {
        inkImageRef.SetTexturePart(icon, zone.IconPart());
        zone.LogOnce(view);
        return;
    }
    // Diagnostico: el mappin del circulo del minimapa cayo en un controlador POI/mapa (en vez de MinimapDeviceMappinController).
    let circle: wref<GRZoneCircleData> = data as GRZoneCircleData;
    if IsDefined(circle) {
        circle.poiHit += 1;
        if circle.poiHit == 1 {
            GRLog("Zona #" + IntToString(circle.nemesisId) + ": ERROR el mappin del circulo cayo en un controlador POI/mapa (vista " + IntToString(view) + "), no en MinimapDeviceMappinController");
        }
    }
}

// Circulo del minimapa: MinimapDeviceMappinController dibuja el circulo (SetEffectAreaRadius) en Update. Aca solo se loguea cuando se crea/actualiza
// el controlador para el mappin del circulo de la zona (una vez), y se cuentan las actualizaciones (DevZoneInfo).
@wrapMethod(MinimapDeviceMappinController)
protected func Update() -> Void {
    wrappedMethod();
    let mappin: wref<IMappin> = this.GetMappin();
    if !IsDefined(mappin) {
        return;
    }
    let circle: wref<GRZoneCircleData> = mappin.GetScriptData() as GRZoneCircleData;
    if IsDefined(circle) {
        circle.updates += 1;
        if circle.updates == 1 {
            GRLog("Zona #" + IntToString(circle.nemesisId) + ": MinimapDeviceMappinController creado para el circulo (m_range=" + IntToString(Cast<Int32>(circle.m_range))
                + " m, showOnMiniMap=" + GRGigZone.Flag(circle.m_showOnMiniMap) + ", currentTarget=" + GRGigZone.Flag(circle.m_isCurrentTarget) + ")");
        }
        this.GRApplyCircleColor(circle);
    }
}

// Color del circulo segun GRZoneCircleData.colorMode (ver GRBounties.ZoneColorModeName). El tintColor del widget effectArea esta ENLAZADO al estilo
// "Mappin.AreaColor" (blanco): se re-enlaza a MainColors.ActiveYellow dentro de la zona (BindProperty, como hace el juego) y ademas se fija el valor con
// SetTintColor. Se reaplica en cada Update mientras V esta adentro; al salir se vuelve al binding y tinte originales.
@addMethod(MinimapDeviceMappinController)
private func GRApplyCircleColor(circle: wref<GRZoneCircleData>) -> Void {
    let mode: Int32 = circle.colorMode;
    let widget: wref<inkWidget> = inkWidgetRef.Get(this.effectAreaWidget);
    let root: wref<inkWidget> = this.GetRootWidget();
    if !circle.hasBase {
        circle.baseTint = inkWidgetRef.GetTintColor(this.effectAreaWidget);
        circle.hasBase = true;
        GRLog("Zona #" + IntToString(circle.nemesisId) + ": tinte base del circulo r" + FloatToStringPrec(circle.baseTint.Red, 2) + " g" + FloatToStringPrec(circle.baseTint.Green, 2)
            + " b" + FloatToStringPrec(circle.baseTint.Blue, 2) + " a" + FloatToStringPrec(circle.baseTint.Alpha, 2) + " (widget " + (IsDefined(widget) ? "ok" : "NULO") + ")");
    }
    let want: Bool = circle.inside && mode > 0 && mode != 4;
    // Limpieza: salio de la zona, o DevZoneColorMode cambio el modo (se deshace lo del modo anterior).
    if (circle.tinted || circle.rootTinted) && (!want || circle.colorDirty) {
        if IsDefined(widget) {
            widget.BindProperty(n"tintColor", GRBounties.ZoneCircleBaseStyle());
        }
        inkWidgetRef.SetTintColor(this.effectAreaWidget, circle.baseTint);
        if circle.rootTinted && IsDefined(root) {
            root.SetTintColor(new HDRColor(1.0, 1.0, 1.0, 1.0));
        }
        circle.tinted = false;
        circle.rootTinted = false;
        GRLog("Zona #" + IntToString(circle.nemesisId) + ": color del circulo restaurado");
    }
    circle.colorDirty = false;
    if !want {
        return;
    }
    let first: Bool = !circle.tinted;
    if GRZoneCircleData.UsesBind(mode) && IsDefined(widget) {
        widget.BindProperty(n"tintColor", GRBounties.ZoneCircleInsideStyle());
    }
    if GRZoneCircleData.UsesTint(mode) {
        inkWidgetRef.SetTintColor(this.effectAreaWidget, GRBounties.ZoneCircleInsideColor());
    }
    if mode == 6 && IsDefined(root) {
        root.SetTintColor(GRBounties.ZoneCircleInsideColor());
        circle.rootTinted = true;
    }
    circle.tinted = true;
    if first {
        GRLog("Zona #" + IntToString(circle.nemesisId) + ": color del circulo aplicado (modo " + GRBounties.ZoneColorModeName(mode) + ")");
    }
}

// El mappin del circulo usa la definicion del juego (showInWorld=true), asi que el mundo 3D le crea un icono ("i 58M"). Se oculta la raiz
// del widget del mundo al final de cada OnUpdate (el minimapa usa MinimapDeviceMappinController, no se toca).
@wrapMethod(GameplayMappinController)
protected cb func OnUpdate() -> Bool {
    let result: Bool = wrappedMethod();
    let mappin: wref<IMappin> = this.GetMappin();
    if IsDefined(mappin) && IsDefined(mappin.GetScriptData() as GRZoneCircleData) {
        this.SetRootVisible(false);
    }
    return result;
}

public func GRBountyZoneTooltip(zone: wref<GRBountyZoneMappinData>, gi: GameInstance, out title: String, out desc: String) -> Bool {
    if !IsDefined(zone) {
        return false;
    }
    let core: ref<GRSystem> = GRSystem.Get(gi);
    if !IsDefined(core) {
        return false;
    }
    title = StrReplaceAll(core.GetText("GR-BountyZoneTitle"), "{name}", zone.name);
    desc = StrReplaceAll(core.GetText(zone.boss ? "GR-BountyZoneLairDesc" : "GR-BountyZoneDesc"), "{name}", zone.name);
    zone.LogOnce(GRStrongholdMappinData.ViewTooltip());
    return true;
}

@wrapMethod(BaseWorldMapMappinController)
protected func UpdateIcon() -> Void {
    wrappedMethod();
    GRApplyMappinIcon(this.GetMappin(), this.iconWidget, GRStrongholdMappinData.ViewMap());
}

@wrapMethod(MinimapPOIMappinController)
protected final func UpdateIcon() -> Void {
    wrappedMethod();
    GRApplyMappinIcon(this.GetMappin(), this.iconWidget, GRStrongholdMappinData.ViewMinimap());
    // Zona de caza: en el minimapa va solo el circulo (MinimapDeviceMappinController); el pin central y el anillo se ocultan aca y quedan en el mapa grande.
    if GRBounties.HideZonePinsOnMinimap() && IsDefined(GRBountyZoneMappinData.Of(this.GetMappin())) {
        this.SetForceHide(true);
    }
}

// Update llama a UpdateVisibility despues de UpdateIcon; se vuelve a ocultar al final por si lo reseteara.
@wrapMethod(MinimapPOIMappinController)
protected func Update() -> Void {
    wrappedMethod();
    if GRBounties.HideZonePinsOnMinimap() && IsDefined(GRBountyZoneMappinData.Of(this.GetMappin())) {
        this.SetForceHide(true);
    }
}

@wrapMethod(QuestMappinController)
protected func UpdateIcon() -> Void {
    wrappedMethod();
    GRApplyMappinIcon(this.GetMappin(), this.iconWidget, GRStrongholdMappinData.ViewWorld());
    let mappin: wref<IMappin> = this.GetMappin();
    if !IsDefined(mappin) || !Equals(mappin.GetVariant(), gamedataMappinVariant.HuntForPsychoVariant) {
        return;
    }
    let spawner: ref<GRSpawner> = GRSpawner.Get(GetGameInstance());
    if !IsDefined(spawner) {
        return;
    }
    let rank: Int32 = spawner.GetNemesisRank(mappin.GetEntityID());
    if rank > 0 {
        inkWidgetRef.SetTintColor(this.iconWidget, GRHud.RankMappinColor(rank));
    }
}

@wrapMethod(WorldMappinsContainerController)
public func CreateMappinUIProfile(mappin: wref<IMappin>, mappinVariant: gamedataMappinVariant, customData: ref<MappinControllerCustomData>) -> MappinUIProfile {
    if Equals(mappinVariant, gamedataMappinVariant.CPO_PingDoorVariant) {
        if IsDefined(GRStrongholdMappinData.Of(mappin)) {
            return wrappedMethod(mappin, gamedataMappinVariant.OutpostVariant, customData);
        }
    }
    return wrappedMethod(mappin, mappinVariant, customData);
}

@addField(WorldMapTooltipController)
private let m_grBanner: wref<inkCompoundWidget>;

@wrapMethod(WorldMapTooltipController)
protected cb func OnInitialize() -> Bool {
    let result: Bool = wrappedMethod();
    let root: ref<inkCompoundWidget> = this.GetRootCompoundWidget();
    if !IsDefined(root) {
        return result;
    }
    let content: ref<inkCompoundWidget> = root.GetWidgetByPathName(n"tooltip/tooltipFlex/mainLayout/content/mainContent") as inkCompoundWidget;
    if !IsDefined(content) {
        return result;
    }
    let banner: ref<inkCanvas> = new inkCanvas();
    banner.SetName(n"grStrongholdBanner");
    banner.SetSize(680.0, 288.0);
    banner.SetAnchor(inkEAnchor.BottomRight);
    banner.SetAnchorPoint(1.0, 1.0);
    banner.SetMargin(inkMargin(0.0, 0.0, 32.0, 16.0));
    banner.SetAffectsLayoutWhenHidden(false);
    banner.SetVisible(false);
    let image: ref<inkImage> = new inkImage();
    image.SetName(n"image");
    image.SetSize(680.0, 288.0);
    image.Reparent(banner);
    banner.Reparent(content);
    this.m_grBanner = banner;
    return result;
}

@wrapMethod(WorldMapTooltipController)
protected final func Reset() -> Void {
    wrappedMethod();
    if IsDefined(this.m_grBanner) {
        this.m_grBanner.SetVisible(false);
    }
}

@wrapMethod(WorldMapTooltipController)
public func SetData(const data: script_ref<WorldMapTooltipData>, menu: ref<WorldMapMenuGameController>) -> Void {
    wrappedMethod(data, menu);
    if IsDefined(this.m_grBanner) {
        this.m_grBanner.SetVisible(false);
    }
    if !IsDefined(menu) {
        return;
    }
    let mark: wref<GRStrongholdMappinData> = GRStrongholdMappinData.Of(Deref(data).mappin);
    let player: wref<GameObject> = menu.GetPlayer();
    if !IsDefined(player) {
        return;
    }
    let zoneTitle: String;
    let zoneDesc: String;
    if GRBountyZoneTooltip(GRBountyZoneMappinData.Of(Deref(data).mappin), player.GetGame(), zoneTitle, zoneDesc) {
        inkTextRef.SetText(this.m_titleText, zoneTitle);
        inkTextRef.SetText(this.m_descText, zoneDesc);
        return;
    }
    if !IsDefined(mark) {
        return;
    }
    let core: ref<GRSystem> = GRSystem.Get(player.GetGame());
    if !IsDefined(core) {
        return;
    }
    let title: String = StrReplace(core.GetText("GR-StrongholdMapTitle"), "{gang}", GRIntelSystem.GangLabel(mark.gang));
    inkTextRef.SetText(this.m_titleText, title);
    inkTextRef.SetText(this.m_descText, core.GetText("GR-StrongholdMapDesc"));
    let settings: ref<GRSettings> = GRSettings.Get(player.GetGame());
    let showBanner: Bool = !IsDefined(settings) || settings.strongholdBanner;
    if showBanner && IsDefined(this.m_grBanner) {
        let banner: ref<inkImage> = this.m_grBanner.GetWidgetByPathName(n"image") as inkImage;
        if IsDefined(banner) {
            banner.SetAtlasResource(r"gangretaliation\\gui\\stronghold_banners.inkatlas");
            banner.SetTexturePart(StringToName(StrLower(mark.gang)));
            this.m_grBanner.SetVisible(true);
        }
    }
    mark.LogOnce(GRStrongholdMappinData.ViewTooltip());
}

@wrapMethod(WorldMapPoliceTooltipController)
public func SetData(const data: script_ref<WorldMapTooltipData>, menu: ref<WorldMapMenuGameController>) -> Void {
    wrappedMethod(data, menu);
    if !IsDefined(menu) {
        return;
    }
    let mark: wref<GRStrongholdMappinData> = GRStrongholdMappinData.Of(Deref(data).mappin);
    let player: wref<GameObject> = menu.GetPlayer();
    if !IsDefined(player) {
        return;
    }
    let zoneTitle: String;
    let zoneDesc: String;
    if GRBountyZoneTooltip(GRBountyZoneMappinData.Of(Deref(data).mappin), player.GetGame(), zoneTitle, zoneDesc) {
        inkTextRef.SetText(this.m_titleText, zoneTitle);
        return;
    }
    if !IsDefined(mark) {
        return;
    }
    let core: ref<GRSystem> = GRSystem.Get(player.GetGame());
    if !IsDefined(core) {
        return;
    }
    let title: String = StrReplace(core.GetText("GR-StrongholdMapTitle"), "{gang}", GRIntelSystem.GangLabel(mark.gang));
    inkTextRef.SetText(this.m_titleText, title);
    mark.LogOnce(GRStrongholdMappinData.ViewTooltip());
}


@wrapMethod(WorldMapMenuGameController)
protected cb func OnInitialize() -> Bool {
    let result: Bool = wrappedMethod();
    let system: ref<GRStronghold> = GRStronghold.Get(GetGameInstance());
    if IsDefined(system) {
        let filter: gamedataWorldMapFilter = GRStronghold.MapFilter();
        if !system.IsMapFilterSeeded() && !this.IsFastTravelEnabled() {
            this.SetCustomFilter(filter);
            system.MarkMapFilterSeeded();
        }
        system.SetMapFilter(Equals(this.GetQuickFilter(), gamedataWorldMapFilter.CustomFilter), this.HasCustomFilter(filter));
    }
    return result;
}

public class GRIntelSystem extends ScriptableSystem {
    private persistent let m_values: array<Int32>;

    private let m_coinIds: array<EntityID>;
    private let m_coinFlee: array<Bool>;

    private let m_fightSeen: array<EntityID>;
    private let m_fightChosen: EntityID;
    private let m_hasChosen: Bool;
    private let m_chosenUsed: Bool;

    private let m_active: Bool;
    private let m_gang: String;
    private let m_rank: Int32;
    private let m_start: Float;

    private let m_suppressShardPickup: EntityID;

    private let m_shardIds: array<EntityID>;
    private let m_shardRanks: array<Int32>;
    private let m_shardNemesis: array<Int32>;

    public static func Get(gi: GameInstance) -> ref<GRIntelSystem> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRIntelSystem") as GRIntelSystem;
    }

    public static func Gangs() -> array<String> {
        return ["Maelstrom", "TygerClaws", "Valentinos", "SixthStreet", "Animals", "VoodooBoys", "Wraiths", "Scavengers", "Barghest"];
    }

    public static func Duration() -> Float {
        return 3.0;
    }

    public static func AmountFor(rank: Int32) -> Int32 {
        if rank >= 3 {
            return 50;
        }
        if rank == 2 {
            return 25;
        }
        if rank == 1 {
            return 10;
        }
        return 5;
    }

    public static func RankName(rank: Int32) -> String {
        if rank >= 3 {
            return "Jefe";
        }
        if rank == 2 {
            return "Teniente";
        }
        if rank == 1 {
            return "Soldado";
        }
        return "comun";
    }

    public static func GangLabel(gang: String) -> String {
        if Equals(gang, "TygerClaws") {
            return "Tyger Claws";
        }
        if Equals(gang, "SixthStreet") {
            return "6th Street";
        }
        if Equals(gang, "VoodooBoys") {
            return "Voodoo Boys";
        }
        if Equals(gang, "Scavengers") {
            return "Scavs";
        }
        return gang;
    }

    public static func ShardRecordFor(gang: String) -> TweakDBID {
        if Equals(gang, "Maelstrom") {
            return t"Items.GRIntelShard_Maelstrom";
        }
        if Equals(gang, "TygerClaws") {
            return t"Items.GRIntelShard_TygerClaws";
        }
        if Equals(gang, "Valentinos") {
            return t"Items.GRIntelShard_Valentinos";
        }
        if Equals(gang, "SixthStreet") {
            return t"Items.GRIntelShard_SixthStreet";
        }
        if Equals(gang, "Animals") {
            return t"Items.GRIntelShard_Animals";
        }
        if Equals(gang, "VoodooBoys") {
            return t"Items.GRIntelShard_VoodooBoys";
        }
        if Equals(gang, "Wraiths") {
            return t"Items.GRIntelShard_Wraiths";
        }
        if Equals(gang, "Scavengers") {
            return t"Items.GRIntelShard_Scavengers";
        }
        if Equals(gang, "Barghest") {
            return t"Items.GRIntelShard_Barghest";
        }
        return TDBID.None();
    }

    public static func IsShardRecord(id: TweakDBID) -> Bool {
        let gangs: array<String> = GRIntelSystem.Gangs();
        for gang in gangs {
            if Equals(id, GRIntelSystem.ShardRecordFor(gang)) {
                return true;
            }
        }
        return false;
    }

    private func GangIndex(gang: String) -> Int32 {
        let gangs: array<String> = GRIntelSystem.Gangs();
        let i: Int32 = 0;
        while i < ArraySize(gangs) {
            if Equals(gangs[i], gang) {
                return i;
            }
            i += 1;
        }
        return -1;
    }

    public func GetIntel(gang: String) -> Int32 {
        let index: Int32 = this.GangIndex(gang);
        if index < 0 || index >= ArraySize(this.m_values) {
            return 0;
        }
        return this.m_values[index];
    }

    public func IsLocated(gang: String) -> Bool {
        return this.GetIntel(gang) >= 100;
    }

    private func EnsureValues() {
        let gangs: array<String> = GRIntelSystem.Gangs();
        let count: Int32 = ArraySize(gangs);
        while ArraySize(this.m_values) < count {
            ArrayPush(this.m_values, 0);
        }
    }

    public func AddIntel(gang: String, amount: Int32, reason: String) -> Int32 {
        let index: Int32 = this.GangIndex(gang);
        if index < 0 || amount <= 0 {
            return 0;
        }
        this.EnsureValues();
        if index >= ArraySize(this.m_values) {
            GRLog("Intel: ERROR, " + gang + " sin lugar en la lista (" + IntToString(ArraySize(this.m_values)) + " valores)");
            return 0;
        }
        let before: Int32 = this.m_values[index];
        let after: Int32 = Min(100, before + amount);
        this.m_values[index] = after;
        GRLog("Intel: " + gang + " +" + IntToString(after - before) + "% = " + IntToString(after) + "% (" + reason + ")");
        this.Notify(this.Format(this.Text("GR-IntelGained"), gang, after));
        if before < 100 && after >= 100 {
            GRLog("Intel: guarida de " + gang + " localizada");
            this.Notify(this.Format(this.Text("GR-IntelLocated"), gang, after));
        }
        return after;
    }

    public func MarkLocated(gang: String, reason: String) {
        let index: Int32 = this.GangIndex(gang);
        if index < 0 || this.IsLocated(gang) {
            return;
        }
        this.EnsureValues();
        this.m_values[index] = 100;
        GRLog("Intel: guarida de " + gang + " localizada (" + reason + ")");
    }

    public func ResetIntel(gang: String, reason: String) {
        let index: Int32 = this.GangIndex(gang);
        if index < 0 {
            return;
        }
        this.EnsureValues();
        if index >= ArraySize(this.m_values) {
            return;
        }
        let before: Int32 = this.m_values[index];
        this.m_values[index] = 0;
        GRLog("Intel: " + gang + " " + IntToString(before) + "% -> 0% (" + reason + ")");
    }


    public func OnFightReset() {
        ArrayClear(this.m_coinIds);
        ArrayClear(this.m_coinFlee);
        ArrayClear(this.m_fightSeen);
        this.m_hasChosen = false;
        this.m_chosenUsed = false;
    }

    public func NoteCombatant(npc: ref<ScriptedPuppet>) {
        if !IsDefined(npc) || this.m_chosenUsed || StrLen(GRDetection.GetGang(npc)) == 0 || this.NemesisRank(npc) > 0 {
            return;
        }
        let id: EntityID = npc.GetEntityID();
        for seen in this.m_fightSeen {
            if seen == id {
                return;
            }
        }
        ArrayPush(this.m_fightSeen, id);
        if RandRange(0, ArraySize(this.m_fightSeen)) == 0 {
            this.m_fightChosen = id;
            this.m_hasChosen = true;
        }
    }

    public func TryKnockOut(npc: ref<ScriptedPuppet>, health: Float, threshold: Float) -> Bool {
        if !IsDefined(npc) || npc.IsDead() || GRDetection.IsNeutralized(npc) || health <= 0.0 || health > threshold {
            return false;
        }
        let gang: String = GRDetection.GetGang(npc);
        let rank: Int32 = this.NemesisRank(npc);
        if StrLen(gang) == 0 || this.GangIndex(gang) < 0 {
            return false;
        }
        if rank == 0 {
            if !this.m_hasChosen || this.m_chosenUsed || this.m_fightChosen != npc.GetEntityID() {
                return false;
            }
            this.m_chosenUsed = true;
        } else {
            if this.FleeCoin(npc) {
                return false;
            }
        }
        StatusEffectHelper.ApplyStatusEffect(npc, t"BaseStatusEffect.Unconscious");
        GRLog("Intel: " + gang + " inconsciente (" + GRIntelSystem.RankName(rank) + ", vida " + IntToString(RoundF(health))
            + "% <= " + IntToString(RoundF(threshold)) + "%) " + TDBID.ToStringDEBUG(npc.GetRecordID()));
        this.QueueShard(npc.GetEntityID(), this.NemesisIdOf(npc.GetEntityID()), rank,
            rank > 0 ? GRIntelCall.GiveShardNemesis() : GRIntelCall.GiveShard());
        return true;
    }

    public func OnNemesisDown(id: EntityID, nemesisId: Int32, rank: Int32) {
        if rank <= 0 || nemesisId <= 0 {
            return;
        }
        this.QueueShard(id, nemesisId, rank, GRIntelCall.GiveShardNemesis());
    }

    private func QueueShard(id: EntityID, nemesisId: Int32, rank: Int32, kind: Int32) {
        if this.ShardIndex(id) >= 0 {
            return;
        }
        ArrayPush(this.m_shardIds, id);
        ArrayPush(this.m_shardRanks, rank);
        ArrayPush(this.m_shardNemesis, nemesisId);
        GRIntelCall.Send(this.GetGameInstance(), kind, id, 0.5);
    }

    private func ShardIndex(id: EntityID) -> Int32 {
        let i: Int32 = 0;
        while i < ArraySize(this.m_shardIds) {
            if this.m_shardIds[i] == id {
                return i;
            }
            i += 1;
        }
        return -1;
    }

    private func ForgetShard(id: EntityID) {
        let i: Int32 = this.ShardIndex(id);
        if i >= 0 {
            ArrayErase(this.m_shardIds, i);
            ArrayErase(this.m_shardRanks, i);
            ArrayErase(this.m_shardNemesis, i);
        }
    }

    private func NemesisIdOf(id: EntityID) -> Int32 {
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());
        return IsDefined(spawner) ? spawner.GetNemesisId(id) : 0;
    }

    private func ShardRank(npc: ref<ScriptedPuppet>) -> Int32 {
        let i: Int32 = this.ShardIndex(npc.GetEntityID());
        if i >= 0 {
            return this.m_shardRanks[i];
        }
        return this.NemesisRank(npc);
    }


    public func OnGiveShardDelayed(id: EntityID, allowDead: Bool) {
        let npc: ref<ScriptedPuppet> = GameInstance.FindEntityByID(this.GetGameInstance(), id) as ScriptedPuppet;
        if !IsDefined(npc) {
            this.ForgetShard(id);
            return;
        }
        if npc.IsDead() && !allowDead {
            this.ForgetShard(id);
            return;
        }
        let gang: String = GRDetection.GetGang(npc);
        if StrLen(gang) == 0 {
            this.ForgetShard(id);
            return;
        }
        let i: Int32 = this.ShardIndex(id);
        let rank: Int32 = i >= 0 ? this.m_shardRanks[i] : this.NemesisRank(npc);
        let nemesisId: Int32 = i >= 0 ? this.m_shardNemesis[i] : 0;
        this.GiveIntelShard(npc, gang, rank, nemesisId);
    }

    private func GiveIntelShard(npc: ref<ScriptedPuppet>, gang: String, rank: Int32, nemesisId: Int32) {
        let recordID: TweakDBID = GRIntelSystem.ShardRecordFor(gang);
        if !TDBID.IsValid(recordID) {
            return;
        }
        let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGameInstance());
        let id: ItemID = ItemID.FromTDBID(recordID);
        let state: String = npc.IsDead() ? "muerto" : "noqueado";
        if ts.GetItemQuantity(npc, id) > 0 {
            GRLog("Intel: shard ya presente en " + (nemesisId > 0 ? "Nemesis #" + IntToString(nemesisId) : gang)
                + " (" + GRIntelSystem.RankName(rank) + ", " + state + "), no se da otro");
            return;
        }
        let given: Bool = ts.GiveItem(npc, id, 1);
        npc.EvaluateLootQualityEvent();
        if !given {
            this.ForgetShard(npc.GetEntityID());
        }
        let who: String = nemesisId > 0 ? "Nemesis #" + IntToString(nemesisId) : gang;
        GRLog("Intel: shard " + (given ? "dado" : "FALLO al dar") + " a " + who + " (" + GRIntelSystem.RankName(rank) + ", " + state + ") "
            + TDBID.ToStringDEBUG(npc.GetRecordID()));
    }

    private func DestroyIntelShard(npc: ref<ScriptedPuppet>, gang: String) {
        let recordID: TweakDBID = GRIntelSystem.ShardRecordFor(gang);
        if !TDBID.IsValid(recordID) {
            return;
        }
        let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGameInstance());
        let id: ItemID = ItemID.FromTDBID(recordID);
        let qty: Int32 = ts.GetItemQuantity(npc, id);
        if qty > 0 {
            this.m_suppressShardPickup = npc.GetEntityID();
            ts.RemoveItem(npc, id, qty);
            let none: EntityID;
            this.m_suppressShardPickup = none;
            GRLog("Intel: shard (prueba) destruido, el NPC murio antes de que lo saquearan ("
                + TDBID.ToStringDEBUG(npc.GetRecordID()) + ")");
        }
    }

    public func OnShardLooted(npc: ref<ScriptedPuppet>) {
        if !IsDefined(npc) || Equals(npc.GetEntityID(), this.m_suppressShardPickup) {
            return;
        }
        let gang: String = GRDetection.GetGang(npc);
        let tracked: Bool = this.ShardIndex(npc.GetEntityID()) >= 0;
        let rank: Int32 = this.ShardRank(npc);
        this.ForgetShard(npc.GetEntityID());
        GRLog("Intel: shard saqueado, rango usado " + GRIntelSystem.RankName(rank) + (tracked ? " (recordado al darlo)" : " (sin registro, rango actual)"));
        if StrLen(gang) == 0 {
            GRLog("Intel: shard (prueba) recogido pero sin banda valida, ignorado ("
                + TDBID.ToStringDEBUG(npc.GetRecordID()) + ")");
            return;
        }
        if this.m_active {
            GRLog("Intel: shard (prueba) recogido con otra barra ya activa, sumado al instante sin animacion, "
                + gang + " (" + GRIntelSystem.RankName(rank) + ")");
            this.AddIntel(gang, GRIntelSystem.AmountFor(rank), "shard (prueba, sin animacion): " + GRIntelSystem.RankName(rank));
            this.RevealTraitFromShard(gang);
            return;
        }
        GRLog("Intel: shard (prueba) recogido, " + gang + " (" + GRIntelSystem.RankName(rank) + "), arrancando barra cosmetica");
        this.StartShardBar(gang, rank);
    }

    public func OnNPCDeath(id: EntityID) {
        let i: Int32 = this.ShardIndex(id);
        if i >= 0 && this.m_shardRanks[i] > 0 {
            return;
        }
        this.ForgetShard(id);
        let npc: ref<ScriptedPuppet> = GameInstance.FindEntityByID(this.GetGameInstance(), id) as ScriptedPuppet;
        if !IsDefined(npc) {
            return;
        }
        let gang: String = GRDetection.GetGang(npc);
        if StrLen(gang) == 0 {
            return;
        }
        this.DestroyIntelShard(npc, gang);
    }

    private func FleeCoin(npc: ref<ScriptedPuppet>) -> Bool {
        let id: EntityID = npc.GetEntityID();
        let i: Int32 = 0;
        while i < ArraySize(this.m_coinIds) {
            if this.m_coinIds[i] == id {
                return this.m_coinFlee[i];
            }
            i += 1;
        }
        let flee: Bool = RandRange(0, 2) == 0;
        ArrayPush(this.m_coinIds, id);
        ArrayPush(this.m_coinFlee, flee);
        let name: String = "";
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());
        if IsDefined(spawner) {
            name = spawner.GetNemesisLabel(id);
        }
        if StrLen(name) == 0 {
            name = TDBID.ToStringDEBUG(npc.GetRecordID());
        }
        GRLog("Intel: " + name + " moneda -> " + (flee ? "huye" : "inconsciente"));
        return flee;
    }

    private func NemesisRank(npc: ref<ScriptedPuppet>) -> Int32 {
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());
        if !IsDefined(spawner) || spawner.GetNemesisId(npc.GetEntityID()) <= 0 {
            return 0;
        }
        return Max(1, spawner.GetNemesisRank(npc.GetEntityID()));
    }


    private func Now() -> Float {
        return EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
    }

    private func StartShardBar(gang: String, rank: Int32) {
        this.m_active = true;
        this.m_gang = gang;
        this.m_rank = rank;
        this.m_start = this.Now();
        let bar: ref<IBlackboard> = this.ProgressBar();
        let defs = GetAllBlackboardDefs();
        bar.SetString(defs.UI_HUDProgressBar.Header, this.Text("GR-IntelExtracting"), true);
        bar.SetString(defs.UI_HUDProgressBar.BottomText, this.Format(this.Text("GR-IntelBottom"), gang, this.GetIntel(gang)), true);
        bar.SetString(defs.UI_HUDProgressBar.CompletedText, this.Text("GR-IntelDone"), true);
        bar.SetString(defs.UI_HUDProgressBar.FailedText, this.Text("GR-IntelFailed"), true);
        bar.SetFloat(defs.UI_HUDProgressBar.Progress, 0.0, true);
        bar.SetBool(defs.UI_HUDProgressBar.Active, true, true);
        GRIntelCall.Send(this.GetGameInstance(), GRIntelCall.Tick(), new EntityID(), 0.1);
    }

    public func OnTick() {
        if !this.m_active {
            return;
        }
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) || player.IsDead() {
            this.Stop(false, "V muerto o sin jugador");
            return;
        }
        let progress: Float = (this.Now() - this.m_start) / GRIntelSystem.Duration();
        this.ProgressBar().SetFloat(GetAllBlackboardDefs().UI_HUDProgressBar.Progress, MinF(1.0, progress), true);
        if progress >= 1.0 {
            let gang: String = this.m_gang;
            let rank: Int32 = this.m_rank;
            this.Stop(true, "");
            this.AddIntel(gang, GRIntelSystem.AmountFor(rank), "shard (prueba): " + GRIntelSystem.RankName(rank));
            this.RevealTraitFromShard(gang);
            return;
        }
        GRIntelCall.Send(this.GetGameInstance(), GRIntelCall.Tick(), new EntityID(), 0.1);
    }

    private func RevealTraitFromShard(gang: String) {
        let traits: ref<GRTraits> = GRTraits.Get(this.GetGameInstance());
        if IsDefined(traits) {
            traits.RevealFromIntel(gang);
        }
    }

    private func Stop(done: Bool, reason: String) {
        this.m_active = false;
        let bar: ref<IBlackboard> = this.ProgressBar();
        if done {
            bar.SetFloat(GetAllBlackboardDefs().UI_HUDProgressBar.Progress, 1.0, true);
        }
        bar.SetBool(GetAllBlackboardDefs().UI_HUDProgressBar.Active, false, true);
        if !done {
            GRLog("Intel: extraccion cancelada, " + reason);
        }
    }

    private func ProgressBar() -> ref<IBlackboard> {
        return GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().UI_HUDProgressBar);
    }

    private func Text(key: String) -> String {
        let core: ref<GRSystem> = GRSystem.Get(this.GetGameInstance());
        return IsDefined(core) ? core.GetText(key) : key;
    }

    private func Format(text: String, gang: String, value: Int32) -> String {
        return StrReplace(StrReplace(text, "{gang}", GRIntelSystem.GangLabel(gang)), "{pct}", IntToString(value));
    }

    private func Notify(text: String) {
        let det: ref<GRDetection> = GRDetection.Get(this.GetGameInstance());
        if IsDefined(det) {
            det.Notify(text);
        }
    }
}

public class GRIntelCall extends DelayCallback {
    public let gi: GameInstance;
    public let kind: Int32;
    public let entityID: EntityID;

    public static func Tick() -> Int32 { return 1; }
    public static func GiveShard() -> Int32 { return 3; }
    public static func GiveShardNemesis() -> Int32 { return 4; }

    public static func Send(gi: GameInstance, kind: Int32, id: EntityID, delay: Float) {
        let call: ref<GRIntelCall> = new GRIntelCall();
        call.gi = gi;
        call.kind = kind;
        call.entityID = id;
        GameInstance.GetDelaySystem(gi).DelayCallback(call, delay, false);
    }

    public func Call() -> Void {
        let intel: ref<GRIntelSystem> = GRIntelSystem.Get(this.gi);
        if !IsDefined(intel) {
            return;
        }
        if this.kind == GRIntelCall.GiveShard() || this.kind == GRIntelCall.GiveShardNemesis() {
            intel.OnGiveShardDelayed(this.entityID, this.kind == GRIntelCall.GiveShardNemesis());
            return;
        }
        intel.OnTick();
    }
}

@wrapMethod(ScriptedPuppet)
protected cb func OnItemRemovedEvent(evt: ref<ItemBeingRemovedEvent>) -> Bool {
    let result: Bool = wrappedMethod(evt);
    if IsDefined(evt) && GRIntelSystem.IsShardRecord(ItemID.GetTDBID(evt.itemID)) {
        let intelSystem: ref<GRIntelSystem> = GRIntelSystem.Get(this.GetGame());
        if IsDefined(intelSystem) {
            intelSystem.OnShardLooted(this);
        }
    }
    return result;
}

@wrapMethod(PlayerPuppet)
protected cb func OnItemAddedToInventory(evt: ref<ItemAddedEvent>) -> Bool {
    let result: Bool = wrappedMethod(evt);
    if IsDefined(evt) && GRIntelSystem.IsShardRecord(ItemID.GetTDBID(evt.itemID)) {
        GameInstance.GetTransactionSystem(this.GetGame()).RemoveItem(this, evt.itemID, evt.currentQuantity);
    }
    return result;
}
