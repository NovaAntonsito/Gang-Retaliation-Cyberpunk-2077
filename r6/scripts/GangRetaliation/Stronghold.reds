module GangRetaliation

// Guaridas fijas, una por banda (sitios probados en el juego). Lua pasa quienes viven en cada una
// (Nemesis vivos de la banda, Jefe primero) y los guardias. Ocupada = tiene al menos un Nemesis vivo:
// solo esas salen en el mapa y solo esas se generan. Una sola activa a la vez (GRSpawner tiene un solo
// grupo de guarida): al acercarse V (<120 m) a la ocupada mas cercana aparecen en sus puestos; si V se
// aleja (>250 m) sin combate, desaparecen.
// Las muertes de Nemesis van por el camino normal de GRSpawner (MarkDead -> processDeaths en Lua).
public class GRStronghold extends ScriptableSystem {
    // Sitios (arrays paralelos, un indice por guarida).
    private let m_siteGangs: array<String>;
    private let m_sitePos: array<Vector4>;
    private let m_siteMembers: array<Int32>;
    private let m_siteGuards: array<String>;
    private let m_siteMappins: array<NewMappinID>;
    private let m_siteHasMappin: array<Bool>;

    // Miembros de todas las guaridas (arrays paralelos; m_memberSites = indice del sitio donde viven).
    private let m_memberSites: array<Int32>;
    private let m_ids: array<Int32>;
    private let m_records: array<String>;
    private let m_appearances: array<String>;
    private let m_speakers: array<String>;

    private let m_active: Bool;
    private let m_activeSite: Int32;
    private let m_cleared: Bool;

    // Para Lua, con la banda: "spawned:Animals", "cleared:Animals", "left:Animals".
    private let m_events: array<String>;

    public static func Get(gi: GameInstance) -> ref<GRStronghold> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRStronghold") as GRStronghold;
    }

    private func OnDetach() {
        let i: Int32 = 0;
        while i < ArraySize(this.m_siteGangs) {
            this.RemoveSiteMappin(i);
            i += 1;
        }
    }

    // Coordenadas de data/site_candidates.json (todas con 20 puestos validos, salvo TygerClaws con 17).
    private func EnsureSites() {
        if ArraySize(this.m_siteGangs) > 0 {
            return;
        }
        this.AddSite("Animals", -2405.2426757813, -2084.2224121094, 9.0001068115234);
        // Dogtown solo existe con Phantom Liberty.
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
    }

    private func AddSite(gang: String, x: Float, y: Float, z: Float) {
        let none: NewMappinID;
        ArrayPush(this.m_siteGangs, gang);
        ArrayPush(this.m_sitePos, new Vector4(x, y, z, 1.0));
        ArrayPush(this.m_siteMembers, 0);
        ArrayPush(this.m_siteGuards, "");
        ArrayPush(this.m_siteMappins, none);
        ArrayPush(this.m_siteHasMappin, false);
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
        }
    }

    // En el mapa solo las ocupadas: se quita al quedar sin Nemesis y vuelve sola cuando la banda tiene otra vez.
    private func RefreshMappins() {
        let i: Int32 = 0;
        while i < ArraySize(this.m_siteGangs) {
            let occupied: Bool = this.m_siteMembers[i] > 0;
            if occupied && !this.m_siteHasMappin[i] {
                let data: MappinData;
                data.mappinType = t"Mappins.DefaultStaticMappin";
                data.variant = gamedataMappinVariant.OutpostVariant;
                data.active = true;
                this.m_siteMappins[i] = GameInstance.GetMappinSystem(this.GetGameInstance()).RegisterMappin(data, this.m_sitePos[i]);
                this.m_siteHasMappin[i] = true;
                GRLog("Guarida (" + this.m_siteGangs[i] + "): ocupada, en el mapa");
            } else if !occupied && this.m_siteHasMappin[i] {
                this.RemoveSiteMappin(i);
                GRLog("Guarida (" + this.m_siteGangs[i] + "): vacia, fuera del mapa");
            }
            i += 1;
        }
    }

    // --- Datos desde Lua (ClearMembers una vez, luego AddMember/SetGuards por banda) ---

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

    // Lua los pasa en orden (Jefe primero). Bandas sin guarida (o Barghest sin Phantom Liberty): se ignoran.
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

    // records: TweakDBIDs de los guardias separados por coma.
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

    // --- Lectura (debug en vivo: REDnode solo deja llamar Get/Is/Has) ---

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

    public func IsActive() -> Bool {
        return this.m_active;
    }

    public func GetActiveGang() -> String {
        if !this.m_active {
            return "";
        }
        return this.GetSiteGang(this.m_activeSite);
    }

    // Indice de la guarida mas cercana a V (ocupada o no); -1 sin jugador.
    public func GetNearestSite() -> Int32 {
        return this.FindNearest(false);
    }

    public func GetNearestGang() -> String {
        return this.GetSiteGang(this.FindNearest(false));
    }

    public func GetNearestDistance() -> Float {
        return this.GetSiteDistance(this.FindNearest(false));
    }

    // Distancia de V a esa guarida (en planta); -1 si no hay jugador o el indice no existe.
    public func GetSiteDistance(site: Int32) -> Float {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !this.IsValidSite(site) || !IsDefined(player) {
            return -1.0;
        }
        let pos: Vector4 = player.GetWorldPosition();
        return Vector4.Distance2D(pos, this.m_sitePos[site]);
    }

    // Dev: una linea para el panel de CET.
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

    // --- Dev ---

    // Dev: los recoge y vuelven a aparecer en el proximo tick si V sigue a <120 m.
    public func Respawn() {
        if this.m_active {
            GRSpawner.Get(this.GetGameInstance()).DespawnAll();
            this.m_active = false;
        }
    }

    // Dev: lleva a V a la guarida de esa banda. false si la banda no tiene (Barghest sin Phantom Liberty).
    public func DevTeleport(gang: String) -> Bool {
        let site: Int32 = this.FindSite(gang);
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if site < 0 || !IsDefined(player) {
            return false;
        }
        let pos: Vector4 = this.m_sitePos[site];
        pos.Z += 0.5;
        GameInstance.GetTeleportationFacility(this.GetGameInstance()).Teleport(player, pos, Vector4.ToRotation(player.GetWorldForward()));
        return true;
    }

    // Dev: cuantos de los 20 puestos de una guarida llena entran en ese punto (sin generar a nadie).
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

    // --- Tick (1 s, desde Lua, hilo principal) ---

    public func Tick() {
        this.EnsureSites();
        this.RefreshMappins();
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) {
            return;
        }
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());

        if this.m_active {
            if !spawner.IsStrongholdActive() {
                this.m_active = false;
                return;
            }
            let gang: String = this.m_siteGangs[this.m_activeSite];
            if !this.m_cleared && spawner.CountStanding() == 0 {
                this.m_cleared = true;
                ArrayPush(this.m_events, "cleared:" + gang);
                GRLog("Guarida (" + gang + "): tomada");
            }
            if this.GetSiteDistance(this.m_activeSite) > 250.0 && !player.IsInCombat() {
                spawner.DespawnAll();
                this.m_active = false;
                ArrayPush(this.m_events, "left:" + gang);
                GRLog("Guarida (" + gang + "): V se fue, se recogen");
            }
            return;
        }

        // Ninguna activa: la ocupada mas cercana, si V esta a menos de 120 m.
        let site: Int32 = this.FindNearest(true);
        if site < 0 || this.GetSiteDistance(site) > 120.0 {
            return;
        }
        let blocker: String = spawner.GetAmbushBlocker();
        if StrLen(blocker) > 0 {
            return;
        }
        this.Populate(spawner, site);
    }

    private func Populate(spawner: ref<GRSpawner>, site: Int32) {
        let gang: String = this.m_siteGangs[site];
        let center: Vector4 = this.m_sitePos[site];
        spawner.BeginStronghold();
        let placed: Int32 = 0;
        let failed: Int32 = 0;
        // Jefe en el centro, el resto a 4-6 m; guardias en dos anillos: 8 a 8-12 m, el resto a 14-20 m.
        let slot: Int32 = 0;
        let i: Int32 = 0;
        while i < ArraySize(this.m_ids) {
            if this.m_memberSites[i] == site {
                let radius: Float = slot == 0 ? 0.0 : RandRangeF(4.0, 6.0);
                let pos: Vector4 = this.FindPost(spawner, center, Cast<Float>(slot) * 2.1, radius);
                if !Vector4.IsZero(pos) && spawner.SpawnPosted(this.m_ids[i], this.m_records[i], this.m_appearances[i], pos, center, this.m_speakers[i]) {
                    placed += 1;
                } else {
                    failed += 1;
                }
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
            let angle: Float = 2.0 * Pi() * Cast<Float>(ringSlot) / Cast<Float>(Max(ring, 1)) + (outer ? 0.4 : 0.0) + RandRangeF(-0.2, 0.2);
            let pos: Vector4 = this.FindPost(spawner, center, angle, outer ? RandRangeF(14.0, 20.0) : RandRangeF(8.0, 12.0));
            if !Vector4.IsZero(pos) && spawner.SpawnPosted(0, guards[i], "", pos, center, "") {
                placed += 1;
            } else {
                failed += 1;
            }
            i += 1;
        }
        if placed == 0 {
            spawner.DespawnAll();
            GRLog("Guarida (" + gang + "): sin puestos validos en el navmesh");
            return;
        }
        this.m_active = true;
        this.m_activeSite = site;
        this.m_cleared = false;
        ArrayPush(this.m_events, "spawned:" + gang);
        GRLog("Guarida (" + gang + "): " + IntToString(placed) + " en sus puestos, " + IntToString(failed) + " sin sitio");
    }

    // Si el puesto no sirve, prueba mas cerca y girando un poco.
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
