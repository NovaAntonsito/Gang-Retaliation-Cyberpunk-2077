module GangRetaliation

// Guarida de una banda (prototipo, una sola): Lua pasa el sitio, quienes viven ahi (Jefe primero) y los
// guardias. Al acercarse V (<120 m) aparecen en sus puestos; si V se aleja (>250 m) sin combate, desaparecen.
// Las muertes de Nemesis van por el camino normal de GRSpawner (MarkDead -> processDeaths en Lua).
public class GRStronghold extends ScriptableSystem {
    private let m_hasSite: Bool;
    private let m_gang: String;
    private let m_site: Vector4;

    private let m_ids: array<Int32>;
    private let m_records: array<String>;
    private let m_appearances: array<String>;
    private let m_speakers: array<String>;
    private let m_guards: array<String>;

    private let m_active: Bool;
    private let m_cleared: Bool;
    private let m_mappin: NewMappinID;
    private let m_hasMappin: Bool;

    // Para Lua: "spawned", "cleared", "left".
    private let m_events: array<String>;

    public static func Get(gi: GameInstance) -> ref<GRStronghold> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRStronghold") as GRStronghold;
    }

    private func OnDetach() {
        this.RemoveSiteMappin();
    }

    public func SetSite(gang: String, x: Float, y: Float, z: Float) {
        this.m_gang = gang;
        this.m_site = new Vector4(x, y, z, 1.0);
        this.m_hasSite = true;
        this.RemoveSiteMappin();
        let data: MappinData;
        data.mappinType = t"Mappins.DefaultStaticMappin";
        data.variant = gamedataMappinVariant.OutpostVariant;
        data.active = true;
        this.m_mappin = GameInstance.GetMappinSystem(this.GetGameInstance()).RegisterMappin(data, this.m_site);
        this.m_hasMappin = true;
    }

    public func ClearSite() {
        if this.m_active {
            GRSpawner.Get(this.GetGameInstance()).DespawnAll();
            this.m_active = false;
        }
        this.m_hasSite = false;
        this.RemoveSiteMappin();
    }

    private func RemoveSiteMappin() {
        if this.m_hasMappin {
            GameInstance.GetMappinSystem(this.GetGameInstance()).UnregisterMappin(this.m_mappin);
            this.m_hasMappin = false;
        }
    }

    public func HasSite() -> Bool {
        return this.m_hasSite;
    }

    public func GetGang() -> String {
        return this.m_gang;
    }

    public func GetMemberCount() -> Int32 {
        return ArraySize(this.m_ids);
    }

    public func IsActive() -> Bool {
        return this.m_active;
    }

    // Dev: los recoge y vuelven a aparecer en el proximo tick si V sigue a <120 m.
    public func Respawn() {
        if this.m_active {
            GRSpawner.Get(this.GetGameInstance()).DespawnAll();
            this.m_active = false;
        }
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

    public func ClearMembers() {
        ArrayClear(this.m_ids);
        ArrayClear(this.m_records);
        ArrayClear(this.m_appearances);
        ArrayClear(this.m_speakers);
        ArrayClear(this.m_guards);
    }

    public func AddMember(nemesisId: Int32, recordID: String, appearance: String, speaker: String) {
        ArrayPush(this.m_ids, nemesisId);
        ArrayPush(this.m_records, recordID);
        ArrayPush(this.m_appearances, appearance);
        ArrayPush(this.m_speakers, speaker);
    }

    public func SetGuards(records: String) {
        ArrayClear(this.m_guards);
        if StrLen(records) > 0 {
            this.m_guards = StrSplit(records, ",");
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

    public func GetDistance() -> Float {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !this.m_hasSite || !IsDefined(player) {
            return -1.0;
        }
        let pos: Vector4 = player.GetWorldPosition();
        return Vector4.Distance2D(pos, this.m_site);
    }

    public func Tick() {
        if !this.m_hasSite {
            return;
        }
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) {
            return;
        }
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());
        let distance: Float = this.GetDistance();

        if this.m_active {
            if !spawner.IsStrongholdActive() {
                this.m_active = false;
                return;
            }
            if !this.m_cleared && spawner.CountStanding() == 0 {
                this.m_cleared = true;
                ArrayPush(this.m_events, "cleared");
                GRLog("Guarida (" + this.m_gang + "): tomada");
            }
            if distance > 250.0 && !player.IsInCombat() {
                spawner.DespawnAll();
                this.m_active = false;
                ArrayPush(this.m_events, "left");
                GRLog("Guarida (" + this.m_gang + "): V se fue, se recogen");
            }
            return;
        }

        if distance > 120.0 || ArraySize(this.m_ids) == 0 {
            return;
        }
        let blocker: String = spawner.GetAmbushBlocker();
        if StrLen(blocker) > 0 {
            return;
        }
        this.Populate(spawner);
    }

    private func Populate(spawner: ref<GRSpawner>) {
        spawner.BeginStronghold();
        let placed: Int32 = 0;
        let failed: Int32 = 0;
        // Jefe en el centro, el resto a 4-6 m; guardias en dos anillos: 8 a 8-12 m, el resto a 14-20 m.
        let i: Int32 = 0;
        while i < ArraySize(this.m_ids) {
            let radius: Float = i == 0 ? 0.0 : RandRangeF(4.0, 6.0);
            let pos: Vector4 = this.FindPost(spawner, this.m_site, Cast<Float>(i) * 2.1, radius);
            if !Vector4.IsZero(pos) && spawner.SpawnPosted(this.m_ids[i], this.m_records[i], this.m_appearances[i], pos, this.m_site, this.m_speakers[i]) {
                placed += 1;
            } else {
                failed += 1;
            }
            i += 1;
        }
        let count: Int32 = ArraySize(this.m_guards);
        let inner: Int32 = Min(count, 8);
        i = 0;
        while i < count {
            let outer: Bool = i >= inner;
            let ring: Int32 = outer ? count - inner : inner;
            let slot: Int32 = outer ? i - inner : i;
            let angle: Float = 2.0 * Pi() * Cast<Float>(slot) / Cast<Float>(Max(ring, 1)) + (outer ? 0.4 : 0.0) + RandRangeF(-0.2, 0.2);
            let pos: Vector4 = this.FindPost(spawner, this.m_site, angle, outer ? RandRangeF(14.0, 20.0) : RandRangeF(8.0, 12.0));
            if !Vector4.IsZero(pos) && spawner.SpawnPosted(0, this.m_guards[i], "", pos, this.m_site, "") {
                placed += 1;
            } else {
                failed += 1;
            }
            i += 1;
        }
        if placed == 0 {
            spawner.DespawnAll();
            GRLog("Guarida (" + this.m_gang + "): sin puestos validos en el navmesh");
            return;
        }
        this.m_active = true;
        this.m_cleared = false;
        ArrayPush(this.m_events, "spawned");
        GRLog("Guarida (" + this.m_gang + "): " + IntToString(placed) + " en sus puestos, " + IntToString(failed) + " sin sitio");
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
