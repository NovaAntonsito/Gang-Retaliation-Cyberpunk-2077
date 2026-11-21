module GangRetaliation

// Encargo nativo del journal para la zona de busqueda del Bounty Board (1 ranura).
// build_archive.py agrega quests/street_stories/gr_bounty_1 (StreetStory sin districtID, como el mod Drug Dealer) con un
// objetivo y DOS mappins:
//   mappin: estatico sin referencia. La posicion y el circulo los pone esta clase en una entrada del .mappins cocinado
//           de Night City (gameCookedMappinData con el hash de la ruta del mappin y un gamemappinsOutlineMappinVolume).
//   marker: de entidad. Referencia el nodo $/gangretaliation/gig/marker_1 (sector propio del archive, patron Drug Dealer)
//           y sigue a esa entidad, que este script teletransporta al centro de la zona.
// Modo (GRGigZone.Mode): 0 = solo cocinado, 1 = solo marcador (por defecto: UN solo pin "!"), 2 = ambos (dibuja dos "!" apilados, solo para comparar).
// Modos 3 y 4 son EXPERIMENTOS para que el juego trate el mappin como AREA (IsQuestAreaMappin) y dibuje el poligono:
//   3 = mappin 'area_a': estatico con referencia al nodo de area VANILLA #ma_wat_nid_03_tr_area (el del psicopata de Northside).
//   4 = mappin 'area_b': estatico con referencia al nodo marcador propio (una entidad, no un area).
// Los dos reciben su propia entrada cocinada (misma posicion y circulo). Ver DevGigMode / DevGigInfo (area=).
// El flujo real lo maneja GRBounties.TickGig (Rewards.reds); DevGigOn/Move/Off/Info/Mode/Accept sirven para probarlo.
public class GRGigZone extends ScriptableService {
    private let m_resource: ref<gameMappinResource>;
    private let m_loads: Int32;
    private let m_hash: Uint32;
    private let m_hashA: Uint32;
    private let m_hashB: Uint32;
    private let m_lateInject: Bool;
    private let m_mode: Int32;

    public static func Get() -> ref<GRGigZone> {
        return GameInstance.GetScriptableServiceContainer().GetService(n"GangRetaliation.GRGigZone") as GRGigZone;
    }

    public static func QuestPath() -> String {
        return "quests/street_stories/gr_bounty_1";
    }

    public static func PhasePath() -> String {
        return GRGigZone.QuestPath() + "/phase";
    }

    public static func ObjectivePath() -> String {
        return GRGigZone.PhasePath() + "/objective_1";
    }

    public static func MappinPath() -> String {
        return GRGigZone.ObjectivePath() + "/mappin";
    }

    public static func MarkerPath() -> String {
        return GRGigZone.ObjectivePath() + "/marker";
    }

    public static func AreaAPath() -> String {
        return GRGigZone.ObjectivePath() + "/area_a";
    }

    public static func AreaBPath() -> String {
        return GRGigZone.ObjectivePath() + "/area_b";
    }

    // Tiene que coincidir con GIG_MARKER_REF de build_archive.py.
    public static func MarkerNodeRef() -> String {
        return "$/gangretaliation/gig/marker_1";
    }

    // Murmur3_32("quests/street_stories/gr_bounty_1/phase/objective_1/mappin", seed 0x5EEDBA5E), calculado en Python.
    // Si JournalManager.GetEntryHash da otro valor, CheckHash corrige la entrada inyectada y lo avisa.
    public static func DefaultHash() -> Uint32 {
        return 2721694661u;
    }

    // Murmur3_32 de las rutas .../objective_1/area_a y .../area_b (mismo calculo que DefaultHash). CheckHash los corrige si difieren.
    public static func DefaultHashA() -> Uint32 {
        return 642038776u;
    }

    public static func DefaultHashB() -> Uint32 {
        return 2374099258u;
    }

    // Modo por defecto del encargo: 1 = solo el marcador de entidad (patron Drug Dealer): un solo "!" que sigue a la entidad y da el pin y el GPS.
    // El mappin cocinado queda disponible con DevGigMode(0) / (2) para comparar. Antes era 2 (los dos mappins activos = dos "!" apilados).
    public static func DefaultMode() -> Int32 {
        return 1;
    }

    public static func Radius() -> Float {
        return 150.0;
    }

    public static func Height() -> Float {
        return 20.0;
    }

    public static func Points() -> Int32 {
        return 24;
    }

    public static func MappinsPath() -> ResRef {
        return r"base\\worlds\\03_night_city\\_compiled\\default\\03_night_city.mappins";
    }

    // Segundos de juego entre el SMS de "aceptado" y la aparicion del encargo.
    public static func Delay() -> Float {
        return 10.0;
    }

    private cb func OnLoad() {
        this.m_hash = GRGigZone.DefaultHash();
        this.m_hashA = GRGigZone.DefaultHashA();
        this.m_hashB = GRGigZone.DefaultHashB();
        this.m_mode = GRGigZone.DefaultMode();
        GameInstance.GetCallbackSystem()
            .RegisterCallback(n"Resource/Load", this, n"OnMappinsLoad")
            .AddTarget(ResourceTarget.Path(r"base\\worlds\\03_night_city\\_compiled\\default\\03_night_city.mappins"));
    }

    private cb func OnMappinsLoad(event: ref<ResourceEvent>) {
        let resource: ref<gameMappinResource> = event.GetResource() as gameMappinResource;
        if !IsDefined(resource) {
            GRLog("Cooked zona: el recurso cargado no es gameMappinResource");
            return;
        }
        this.m_resource = resource;
        this.m_loads += 1;
        this.m_lateInject = false;
        let index: Int32 = this.Inject(resource);
        GRLog("Cooked zona: hash " + ToString(this.m_hash) + " inyectada (entrada " + IntToString(index) + " de "
            + IntToString(ArraySize(resource.cookedData)) + ", carga " + IntToString(this.m_loads) + ")");
    }

    // Agrega las entradas (si no estaban) con el circulo y una posicion valida (el origen) hasta que se las mueva.
    // Devuelve el indice de la entrada principal; area_a / area_b son las de los modos experimentales 3 y 4.
    private func Inject(resource: ref<gameMappinResource>) -> Int32 {
        GRGigZone.InjectOne(resource, this.m_hashA);
        GRGigZone.InjectOne(resource, this.m_hashB);
        return GRGigZone.InjectOne(resource, this.m_hash);
    }

    private static func InjectOne(resource: ref<gameMappinResource>, hash: Uint32) -> Int32 {
        let index: Int32 = GRGigZone.IndexIn(resource, hash);
        if index >= 0 {
            return index;
        }
        let data: gameCookedMappinData;
        let origin: Vector3;
        origin.X = 0.0;
        origin.Y = 0.0;
        origin.Z = 0.0;
        data.journalPathHash = hash;
        data.position = origin;
        data.volume = GRGigZone.MakeCircle(GRGigZone.Radius(), GRGigZone.Height(), GRGigZone.Points());
        ArrayPush(resource.cookedData, data);
        return ArraySize(resource.cookedData) - 1;
    }

    public static func MakeCircle(radius: Float, height: Float, points: Int32) -> ref<gamemappinsOutlineMappinVolume> {
        let volume: ref<gamemappinsOutlineMappinVolume> = new gamemappinsOutlineMappinVolume();
        volume.height = height;
        let step: Float = 6.2831853 / Cast<Float>(points);
        let i: Int32 = 0;
        while i < points {
            let angle: Float = step * Cast<Float>(i);
            let point: Vector2;
            point.X = CosF(angle) * radius;
            point.Y = SinF(angle) * radius;
            ArrayPush(volume.outlinePoints, point);
            i += 1;
        }
        return volume;
    }

    public static func IndexIn(resource: ref<gameMappinResource>, hash: Uint32) -> Int32 {
        if !IsDefined(resource) {
            return -1;
        }
        let i: Int32 = 0;
        let found: Int32 = -1;
        let count: Int32 = ArraySize(resource.cookedData);
        while i < count && found < 0 {
            if resource.cookedData[i].journalPathHash == hash {
                found = i;
            }
            i += 1;
        }
        return found;
    }

    // Si el callback no corrio (recurso ya cargado antes, ruta mal), intenta tomar el recurso del cache e inyectar tarde.
    public func EnsureResource() -> String {
        if IsDefined(this.m_resource) {
            return "";
        }
        let token: ref<ResourceToken> = GameInstance.GetResourceDepot().LoadResource(GRGigZone.MappinsPath());
        if !IsDefined(token) || !token.IsLoaded() {
            return "recurso .mappins NO capturado (callback no corrio y el cache no lo tiene cargado)";
        }
        let resource: ref<gameMappinResource> = token.GetResource() as gameMappinResource;
        if !IsDefined(resource) {
            return "recurso .mappins NO capturado (el cache devolvio otro tipo)";
        }
        this.m_resource = resource;
        this.m_lateInject = true;
        let index: Int32 = this.Inject(resource);
        GRLog("Cooked zona: hash " + ToString(this.m_hash) + " inyectada TARDE desde el cache (entrada " + IntToString(index) + ")");
        return "inyectada tarde desde el cache";
    }

    // Compara el hash usado con el del journal; si difiere, corrige la entrada inyectada.
    public func CheckHash(journal: ref<JournalManager>) -> String {
        let entry: wref<JournalEntry> = journal.GetEntryByString(GRGigZone.MappinPath(), "gameJournalQuestMapPin");
        if !IsDefined(entry) {
            return "mappin NO esta en el journal (archive sin la ranura?)";
        }
        let real: Uint32 = Cast<Uint32>(journal.GetEntryHash(entry));
        let result: String = "hash ok " + ToString(real);
        if real != this.m_hash {
            let old: Uint32 = this.m_hash;
            this.m_hash = real;
            this.Rehash(old, real);
            GRLog("Cooked zona: hash corregido " + ToString(old) + " -> " + ToString(real));
            result = "hash CORREGIDO " + ToString(old) + " -> " + ToString(real);
        }
        let areaA: wref<JournalEntry> = journal.GetEntryByString(GRGigZone.AreaAPath(), "gameJournalQuestMapPin");
        if IsDefined(areaA) {
            let realA: Uint32 = Cast<Uint32>(journal.GetEntryHash(areaA));
            if realA != this.m_hashA {
                let oldA: Uint32 = this.m_hashA;
                this.m_hashA = realA;
                this.Rehash(oldA, realA);
                GRLog("Cooked zona: hash area_a corregido " + ToString(oldA) + " -> " + ToString(realA));
                result += ", area_a CORREGIDO";
            }
        } else {
            result += ", area_a NO esta en el journal";
        }
        let areaB: wref<JournalEntry> = journal.GetEntryByString(GRGigZone.AreaBPath(), "gameJournalQuestMapPin");
        if IsDefined(areaB) {
            let realB: Uint32 = Cast<Uint32>(journal.GetEntryHash(areaB));
            if realB != this.m_hashB {
                let oldB: Uint32 = this.m_hashB;
                this.m_hashB = realB;
                this.Rehash(oldB, realB);
                GRLog("Cooked zona: hash area_b corregido " + ToString(oldB) + " -> " + ToString(realB));
                result += ", area_b CORREGIDO";
            }
        } else {
            result += ", area_b NO esta en el journal";
        }
        return result;
    }

    private func Rehash(old: Uint32, real: Uint32) {
        let index: Int32 = GRGigZone.IndexIn(this.m_resource, old);
        if index >= 0 {
            let data: gameCookedMappinData = this.m_resource.cookedData[index];
            data.journalPathHash = real;
            this.m_resource.cookedData[index] = data;
        }
    }

    public func IsInjected() -> Bool {
        return GRGigZone.IndexIn(this.m_resource, this.m_hash) >= 0;
    }

    public func GetCookedPosition(out pos: Vector3) -> Bool {
        let index: Int32 = GRGigZone.IndexIn(this.m_resource, this.m_hash);
        if index < 0 {
            return false;
        }
        pos = this.m_resource.cookedData[index].position;
        return true;
    }

    // Mueve la entrada cocinada (y las de area_a / area_b). radius > 0 tambien reemplaza el contorno por un circulo de ese radio.
    public func SetCookedPosition(pos: Vector3, radius: Float) -> Bool {
        let index: Int32 = GRGigZone.IndexIn(this.m_resource, this.m_hash);
        if index < 0 {
            return false;
        }
        this.MoveEntry(this.m_hash, pos, radius);
        this.MoveEntry(this.m_hashA, pos, radius);
        this.MoveEntry(this.m_hashB, pos, radius);
        return true;
    }

    private func MoveEntry(hash: Uint32, pos: Vector3, radius: Float) {
        let index: Int32 = GRGigZone.IndexIn(this.m_resource, hash);
        if index < 0 {
            return;
        }
        let data: gameCookedMappinData = this.m_resource.cookedData[index];
        data.position = pos;
        if radius > 1.0 {
            data.volume = GRGigZone.MakeCircle(radius, GRGigZone.Height(), GRGigZone.Points());
        }
        this.m_resource.cookedData[index] = data;
    }

    public func GetHash() -> Uint32 {
        return this.m_hash;
    }

    public func GetLoads() -> Int32 {
        return this.m_loads;
    }

    public func WasLateInject() -> Bool {
        return this.m_lateInject;
    }

    public func GetMode() -> Int32 {
        return this.m_mode;
    }

    public func SetMode(mode: Int32) {
        this.m_mode = Clamp(mode, 0, 4);
    }

    public static func ModeName(mode: Int32) -> String {
        if mode == 0 {
            return "0 solo cocinado";
        }
        if mode == 1 {
            return "1 solo marcador (por defecto)";
        }
        if mode == 3 {
            return "3 area A (referencia al nodo de area vanilla del psicopata)";
        }
        if mode == 4 {
            return "4 area B (referencia al marcador propio)";
        }
        return "2 cocinado + marcador (dos pines)";
    }

    // La Z de la zona puede venir en 0 o rota (NaN / enorme): en ese caso se usa la de V (fallback).
    public static func SafeZ(z: Float, fallback: Float) -> Float {
        if z != z || z == 0.0 || AbsF(z) > 20000.0 {
            return fallback;
        }
        return z;
    }

    // ---- Marcador de mundo (entidad persistente del sector del archive) ----

    public static func MarkerEntity(gi: GameInstance) -> ref<GameObject> {
        let nodeRef: NodeRef = CreateNodeRef(GRGigZone.MarkerNodeRef());
        let id: EntityID = ToEntityID(nodeRef);
        return GameInstance.FindEntityByID(gi, id) as GameObject;
    }

    public static func PlaceMarker(gi: GameInstance, pos: Vector4) -> String {
        let marker: ref<GameObject> = GRGigZone.MarkerEntity(gi);
        if !IsDefined(marker) {
            return "marcador NO encontrado (el sector del archive no cargo: .xl sin 'streaming' o archive viejo?)";
        }
        GameInstance.GetTeleportationFacility(gi).Teleport(marker, pos, new EulerAngles());
        return "marcador movido a " + GRGigZone.Vec4(pos);
    }

    public static func MarkerInfo(gi: GameInstance) -> String {
        let marker: ref<GameObject> = GRGigZone.MarkerEntity(gi);
        if !IsDefined(marker) {
            return "marcador NO encontrado";
        }
        return "marcador en " + GRGigZone.Vec4(marker.GetWorldPosition());
    }

    // ---- Journal ----

    public static func Present(journal: ref<JournalManager>) -> Bool {
        return IsDefined(journal.GetEntryByString(GRGigZone.ObjectivePath(), "gameJournalQuestObjective"));
    }

    public static func IsQuestActive(journal: ref<JournalManager>) -> Bool {
        let entry: wref<JournalEntry> = journal.GetEntryByString(GRGigZone.QuestPath(), "gameJournalQuest");
        if !IsDefined(entry) {
            return false;
        }
        return Equals(journal.GetEntryState(entry), gameJournalEntryState.Active);
    }

    // Reinicia o enciende los mappins del objetivo. cooked / marker eligen cuales (al apagar se apagan siempre los dos).
    public static func SetMappins(journal: ref<JournalManager>, state: gameJournalEntryState, cooked: Bool, marker: Bool) -> String {
        let dont: JournalNotifyOption = JournalNotifyOption.DoNotNotify;
        let c: Bool = false;
        let m: Bool = false;
        if cooked {
            c = journal.ChangeEntryState(GRGigZone.MappinPath(), "gameJournalQuestMapPin", state, dont);
        }
        if marker {
            m = journal.ChangeEntryState(GRGigZone.MarkerPath(), "gameJournalQuestMapPin", state, dont);
        }
        return "mappins cocinado=" + (cooked ? GRGigZone.Flag(c) : "-") + " marcador=" + (marker ? GRGigZone.Flag(m) : "-");
    }

    // Mappins experimentales de area (modos 3 y 4): a = referencia al nodo vanilla, b = referencia al marcador propio.
    public static func SetAreas(journal: ref<JournalManager>, state: gameJournalEntryState, a: Bool, b: Bool) -> String {
        let dont: JournalNotifyOption = JournalNotifyOption.DoNotNotify;
        let ra: Bool = false;
        let rb: Bool = false;
        if a {
            ra = journal.ChangeEntryState(GRGigZone.AreaAPath(), "gameJournalQuestMapPin", state, dont);
        }
        if b {
            rb = journal.ChangeEntryState(GRGigZone.AreaBPath(), "gameJournalQuestMapPin", state, dont);
        }
        return "area_a=" + (a ? GRGigZone.Flag(ra) : "-") + " area_b=" + (b ? GRGigZone.Flag(rb) : "-");
    }

    // Quest + descripcion + fase + objetivo (como Drug Dealer: quest y objetivo avisan, el resto no).
    public static func ActivateQuest(journal: ref<JournalManager>, loud: Bool) -> String {
        let active: gameJournalEntryState = gameJournalEntryState.Active;
        let dont: JournalNotifyOption = JournalNotifyOption.DoNotNotify;
        let notify: JournalNotifyOption = JournalNotifyOption.DoNotNotify;
        if loud {
            notify = JournalNotifyOption.Notify;
        }
        let q: Bool = journal.ChangeEntryState(GRGigZone.QuestPath(), "gameJournalQuest", active, notify);
        let d: Bool = journal.ChangeEntryState(GRGigZone.QuestPath() + "/description", "gameJournalQuestDescription", active, dont);
        let p: Bool = journal.ChangeEntryState(GRGigZone.PhasePath(), "gameJournalQuestPhase", active, dont);
        let o: Bool = journal.ChangeEntryState(GRGigZone.ObjectivePath(), "gameJournalQuestObjective", active, notify);
        return "q/d/p/o=" + GRGigZone.Flag(q) + GRGigZone.Flag(d) + GRGigZone.Flag(p) + GRGigZone.Flag(o);
    }

    public static func TrackObjective(journal: ref<JournalManager>) -> String {
        let objective: wref<JournalEntry> = journal.GetEntryByString(GRGigZone.ObjectivePath(), "gameJournalQuestObjective");
        if !IsDefined(objective) {
            return "sin objetivo para seguir";
        }
        journal.TrackEntry(objective);
        return journal.IsEntryTracked(objective) ? "seguido" : "TrackEntry no lo marco";
    }

    // Activacion completa del encargo (se llama despues de colocar la posicion).
    public func ActivateAll(journal: ref<JournalManager>, loud: Bool) -> String {
        let quest: String = GRGigZone.ActivateQuest(journal, loud);
        let cooked: Bool = this.m_mode == 0 || this.m_mode == 2;
        let marker: Bool = this.m_mode == 1 || this.m_mode == 2;
        let pins: String = GRGigZone.SetMappins(journal, gameJournalEntryState.Active, cooked, marker);
        let areas: String = GRGigZone.SetAreas(journal, gameJournalEntryState.Active, this.m_mode == 3, this.m_mode == 4);
        return quest + ", " + pins + ", " + areas;
    }

    public static func Deactivate(journal: ref<JournalManager>) -> String {
        let objective: wref<JournalEntry> = journal.GetEntryByString(GRGigZone.ObjectivePath(), "gameJournalQuestObjective");
        let untracked: String = "no estaba seguido";
        if IsDefined(objective) && journal.IsEntryTracked(objective) {
            journal.UntrackEntry();
            untracked = "untrack";
        }
        let off: gameJournalEntryState = gameJournalEntryState.Inactive;
        let dont: JournalNotifyOption = JournalNotifyOption.DoNotNotify;
        let pins: String = GRGigZone.SetMappins(journal, off, true, true) + ", " + GRGigZone.SetAreas(journal, off, true, true);
        let o: Bool = journal.ChangeEntryState(GRGigZone.ObjectivePath(), "gameJournalQuestObjective", off, dont);
        let p: Bool = journal.ChangeEntryState(GRGigZone.PhasePath(), "gameJournalQuestPhase", off, dont);
        let d: Bool = journal.ChangeEntryState(GRGigZone.QuestPath() + "/description", "gameJournalQuestDescription", off, dont);
        let q: Bool = journal.ChangeEntryState(GRGigZone.QuestPath(), "gameJournalQuest", off, dont);
        return "Inactive q/d/p/o=" + GRGigZone.Flag(q) + GRGigZone.Flag(d) + GRGigZone.Flag(p) + GRGigZone.Flag(o) + ", " + pins + ", " + untracked;
    }

    // Posiciona la entrada cocinada y el marcador y deja los mappins apagados, listos para activarse.
    public func Place(gi: GameInstance, journal: ref<JournalManager>, x: Float, y: Float, z: Float, radius: Float) -> String {
        let late: String = this.EnsureResource();
        let hash: String = this.CheckHash(journal);
        let pos3: Vector3;
        pos3.X = x;
        pos3.Y = y;
        pos3.Z = z;
        let moved: Bool = this.SetCookedPosition(pos3, radius);
        let marker: String = GRGigZone.PlaceMarker(gi, new Vector4(x, y, z, 1.0));
        let reset: String = GRGigZone.SetMappins(journal, gameJournalEntryState.Inactive, true, true) + ", " + GRGigZone.SetAreas(journal, gameJournalEntryState.Inactive, true, true);
        return hash + (StrLen(late) > 0 ? " (" + late + ")" : "") + ", posicion " + GRGigZone.Vec(pos3) + " radio " + IntToString(Cast<Int32>(radius))
            + " (cocinada " + (moved ? "ok" : "NO, entrada no inyectada") + "), " + marker + ", " + reset;
    }

    public static func Flag(ok: Bool) -> String {
        return ok ? "1" : "0";
    }

    public static func StateOf(journal: ref<JournalManager>, path: String, className: String) -> String {
        let entry: wref<JournalEntry> = journal.GetEntryByString(path, className);
        if !IsDefined(entry) {
            return "falta";
        }
        return EnumValueToString("gameJournalEntryState", Cast<Int64>(EnumInt(journal.GetEntryState(entry))));
    }

    public static func Vec(pos: Vector3) -> String {
        return FloatToStringPrec(pos.X, 1) + "," + FloatToStringPrec(pos.Y, 1) + "," + FloatToStringPrec(pos.Z, 1);
    }

    public static func Vec4(pos: Vector4) -> String {
        return FloatToStringPrec(pos.X, 1) + "," + FloatToStringPrec(pos.Y, 1) + "," + FloatToStringPrec(pos.Z, 1);
    }

    // Mappin vivo del objetivo (lo crea el MappinSystem al activar el mappin del journal).
    public static func ObjectiveMappin(gi: GameInstance) -> wref<IMappin> {
        let journal: ref<JournalManager> = GameInstance.GetJournalManager(gi);
        let phase: wref<JournalEntry> = journal.GetEntryByString(GRGigZone.PhasePath(), "gameJournalQuestPhase");
        let objective: wref<JournalEntry> = journal.GetEntryByString(GRGigZone.ObjectivePath(), "gameJournalQuestObjective");
        if !IsDefined(phase) || !IsDefined(objective) {
            return null;
        }
        return GameInstance.GetMappinSystem(gi).GetMappinFromObjective(phase, objective);
    }

    // Que ve el MappinSystem: mappin del objetivo, posiciones por objetivo, mappins de quest vivos y el que sigue V.
    public static func MappinReport(gi: GameInstance, journal: ref<JournalManager>) -> String {
        let system: ref<MappinSystem> = GameInstance.GetMappinSystem(gi);
        let result: String = "";
        let live: wref<IMappin> = GRGigZone.ObjectiveMappin(gi);
        if IsDefined(live) {
            result += "mappin del objetivo VIVO en " + GRGigZone.Vec4(live.GetWorldPosition()) + " area=" + GRGigZone.Flag(live.IsQuestAreaMappin())
                + " activo=" + GRGigZone.Flag(live.IsActive()) + " visible=" + GRGigZone.Flag(live.IsVisible()) + " seguido=" + GRGigZone.Flag(live.IsPlayerTracked());
        } else {
            result += "GetMappinFromObjective: sin mappin vivo";
        }
        let objective: wref<JournalEntry> = journal.GetEntryByString(GRGigZone.ObjectivePath(), "gameJournalQuestObjective");
        let positions: array<Vector3>;
        if IsDefined(objective) && system.GetQuestMappinPositionsByObjective(Cast<Uint32>(journal.GetEntryHash(objective)), positions) && ArraySize(positions) > 0 {
            result += ", GetQuestMappinPositionsByObjective " + IntToString(ArraySize(positions)) + " pos (primera " + GRGigZone.Vec(positions[0]) + ")";
        } else {
            result += ", GetQuestMappinPositionsByObjective sin datos";
        }
        let list: array<ref<IMappin>>;
        system.GetMappins(gamemappinsMappinTargetType.Map, list);
        let total: Int32 = ArraySize(list);
        let quests: Int32 = 0;
        let tracked: String = "";
        let i: Int32 = 0;
        while i < total {
            let mappin: ref<IMappin> = list[i];
            if IsDefined(mappin) && mappin.IsQuestMappin() {
                quests += 1;
                if mappin.IsPlayerTracked() {
                    tracked += (StrLen(tracked) > 0 ? "; " : "") + GRGigZone.Vec4(mappin.GetWorldPosition()) + " (" + EnumValueToString("gamedataMappinVariant", Cast<Int64>(EnumInt(mappin.GetVariant()))) + " area=" + GRGigZone.Flag(mappin.IsQuestAreaMappin()) + ")";
                }
            }
            i += 1;
        }
        result += ", mappins en el mapa " + IntToString(total) + " (de quest " + IntToString(quests) + ")" + (StrLen(tracked) > 0 ? ", de quest seguido en " + tracked : ", ninguno de quest seguido");
        return result;
    }

    // Pines vivos a <= 6 m (en planta) del centro del encargo, en el mundo 3D y en el mapa: cuantos son, de que clase (quest / circulo GR / pin de zona GR / otro) y su estado.
    // trim = true: si hay mas de un mappin de quest ACTIVO ahi (el encargo tiene que dibujar UN solo "!"), deja el de entidad (el marcador) y apaga los demas con SetMappinActive(false).
    // No toca los pines propios (circulo del minimapa, pin de respaldo). Los apagados se reactivan solos al rearmar el encargo (Place los deja Inactive y ActivateAll los vuelve a encender).
    public static func PinReport(gi: GameInstance, center: Vector4, trim: Bool) -> String {
        let system: ref<MappinSystem> = GameInstance.GetMappinSystem(gi);
        if !IsDefined(system) {
            return "sin MappinSystem";
        }
        let result: String = "";
        let t: Int32 = 0;
        while t < 2 {
            let kind: gamemappinsMappinTargetType = t == 0 ? gamemappinsMappinTargetType.World : gamemappinsMappinTargetType.Map;
            let list: array<ref<IMappin>>;
            system.GetMappins(kind, list);
            let keep: Int32 = -1;
            let keepEntity: Bool = false;
            let i: Int32 = 0;
            while i < ArraySize(list) {
                let m: ref<IMappin> = list[i];
                if IsDefined(m) && m.IsQuestMappin() && m.IsActive() && Vector4.Distance2D(m.GetWorldPosition(), center) <= 6.0 {
                    let isEntity: Bool = m.IsQuestEntityMappin();
                    if keep < 0 || (isEntity && !keepEntity) {
                        keep = i;
                        keepEntity = isEntity;
                    }
                }
                i += 1;
            }
            let lines: String = "";
            let near: Int32 = 0;
            let quests: Int32 = 0;
            let turnedOff: Int32 = 0;
            i = 0;
            while i < ArraySize(list) {
                let mappin: ref<IMappin> = list[i];
                if IsDefined(mappin) && Vector4.Distance2D(mappin.GetWorldPosition(), center) <= 6.0 {
                    near += 1;
                    let tag: String = "otro";
                    if mappin.IsQuestMappin() {
                        tag = "quest";
                        if mappin.IsActive() {
                            quests += 1;
                        }
                    } else if IsDefined(mappin.GetScriptData() as GRZoneCircleData) {
                        tag = "circulo GR";
                    } else if IsDefined(GRBountyZoneMappinData.Of(mappin)) {
                        tag = "pin de zona GR";
                    }
                    let off: String = "";
                    if trim && i != keep && mappin.IsQuestMappin() && mappin.IsActive() && keep >= 0 {
                        system.SetMappinActive(mappin.GetNewMappinID(), false);
                        turnedOff += 1;
                        off = " APAGADO";
                    }
                    let where: Vector4 = mappin.GetWorldPosition();
                    lines += " {" + tag + " " + EnumValueToString("gamedataMappinVariant", Cast<Int64>(EnumInt(mappin.GetVariant()))) + " entidad=" + GRGigZone.Flag(mappin.IsQuestEntityMappin())
                        + " area=" + GRGigZone.Flag(mappin.IsQuestAreaMappin()) + " activo=" + GRGigZone.Flag(mappin.IsActive()) + " visible=" + GRGigZone.Flag(mappin.IsVisible())
                        + " seguido=" + GRGigZone.Flag(mappin.IsPlayerTracked()) + " Z=" + FloatToStringPrec(where.Z, 1) + off + "}";
                }
                i += 1;
            }
            result += (t == 0 ? "pines mundo 3D" : " | pines mapa") + ": " + IntToString(near) + " cerca del centro (" + IntToString(quests) + " de quest activos"
                + (turnedOff > 0 ? ", " + IntToString(turnedOff) + " apagados" : "") + ")" + lines;
            t += 1;
        }
        return result;
    }

    // ---- Nombre del Nemesis en los textos ({0}) ----

    public static func IsGigObjective(gi: GameInstance, entry: wref<JournalEntry>) -> Bool {
        if !IsDefined(entry) {
            return false;
        }
        let journal: ref<JournalManager> = GameInstance.GetJournalManager(gi);
        if !IsDefined(journal) {
            return false;
        }
        let mine: wref<JournalEntry> = journal.GetEntryByString(GRGigZone.ObjectivePath(), "gameJournalQuestObjective");
        if !IsDefined(mine) {
            return false;
        }
        return journal.GetEntryHash(entry) == journal.GetEntryHash(mine);
    }

    public static func IsGigQuest(gi: GameInstance, entry: wref<JournalEntry>) -> Bool {
        if !IsDefined(entry) {
            return false;
        }
        let journal: ref<JournalManager> = GameInstance.GetJournalManager(gi);
        if !IsDefined(journal) {
            return false;
        }
        let mine: wref<JournalEntry> = journal.GetEntryByString(GRGigZone.QuestPath(), "gameJournalQuest");
        if !IsDefined(mine) {
            return false;
        }
        return journal.GetEntryHash(entry) == journal.GetEntryHash(mine);
    }

    // Reemplaza {0} por el nombre del Nemesis del contrato (se deriva del contrato cada vez: al cargar partida no hay nada que reconstruir).
    public static func Fill(gi: GameInstance, text: String) -> String {
        let bounties: ref<GRBounties> = GRBounties.Get(gi);
        let name: String = IsDefined(bounties) ? bounties.GigName() : "?";
        let localized: String = GetLocalizedText(text);
        if !StrContains(localized, "{0}") {
            return text;
        }
        return StrReplaceAll(localized, "{0}", name);
    }
}

// Pasos con demora de DevGigOn (activar y seguir) y de la opcion A de DevGigMove (reactivar el mappin cocinado).
public class GRGigZoneStep extends DelayCallback {
    public let gi: GameInstance;
    public let step: Int32;

    public func Call() {
        let journal: ref<JournalManager> = GameInstance.GetJournalManager(this.gi);
        let zone: ref<GRGigZone> = GRGigZone.Get();
        if !IsDefined(journal) || !IsDefined(zone) {
            return;
        }
        if this.step == 1 {
            GRLog("Cooked zona: DevGigOn activar -> " + zone.ActivateAll(journal, true));
        } else if this.step == 2 {
            let tracked: String = GRGigZone.TrackObjective(journal);
            GRLog("Cooked zona: DevGigOn seguir -> " + tracked + " | " + GRGigZone.MarkerInfo(this.gi) + " | " + GRGigZone.MappinReport(this.gi, journal));
        } else {
            let ok: String = GRGigZone.SetMappins(journal, gameJournalEntryState.Active, true, false);
            let objective: wref<JournalEntry> = journal.GetEntryByString(GRGigZone.ObjectivePath(), "gameJournalQuestObjective");
            if IsDefined(objective) && !journal.IsEntryTracked(objective) {
                journal.TrackEntry(objective);
            }
            let mappin: wref<IMappin> = GRGigZone.ObjectiveMappin(this.gi);
            let where: String = IsDefined(mappin) ? GRGigZone.Vec4(mappin.GetWorldPosition()) : "sin mappin vivo";
            GRLog("Cooked zona: DevGigMove A -> " + ok + ", mappin vivo en " + where);
        }
    }
}

// ---- Wrappers de UI: reemplazan {0} por el nombre del Nemesis (patron del mod Drug Dealer) ----

// Tracker del HUD (objetivo en pantalla).
@wrapMethod(QuestTrackerObjectiveLogicController)
public final func SetData(const objectiveTitle: script_ref<String>, isTracked: Bool, isOptional: Bool, currentCounter: Int32, totalCounter: Int32, objectiveEntry: wref<JournalQuestObjective>, isQuestType: Bool) {
    wrappedMethod(objectiveTitle, isTracked, isOptional, currentCounter, totalCounter, objectiveEntry, isQuestType);
    let gi: GameInstance = GetGameInstance();
    if GRGigZone.IsGigObjective(gi, objectiveEntry) {
        inkTextRef.SetText(this.m_objectiveTitle, GRGigZone.Fill(gi, inkTextRef.GetText(this.m_objectiveTitle)));
    }
}

// Detalle de la quest en el diario (objetivos).
@wrapMethod(QuestDetailsObjectiveController)
public final func Setup(objective: wref<JournalQuestObjective>, journalManager: wref<JournalManager>, currentCounter: Int32, totalCounter: Int32, opt isTracked: Bool) {
    wrappedMethod(objective, journalManager, currentCounter, totalCounter, isTracked);
    let gi: GameInstance = GetGameInstance();
    if GRGigZone.IsGigObjective(gi, objective) {
        inkTextRef.SetText(this.m_objectiveName, GRGigZone.Fill(gi, inkTextRef.GetText(this.m_objectiveName)));
    }
}

// Detalle de la quest en el diario (descripcion).
@wrapMethod(QuestDetailsPanelController)
private final func PopulateObjectives() -> Void {
    wrappedMethod();
    let gi: GameInstance = GetGameInstance();
    if GRGigZone.IsGigQuest(gi, this.m_currentQuestData) {
        inkTextRef.SetText(this.m_questDescription, GRGigZone.Fill(gi, inkTextRef.GetText(this.m_questDescription)));
    }
}

// Lista de quests del diario (la linea de abajo del titulo es el primer objetivo).
@wrapMethod(SimpleQuestListItemController)
protected cb func OnDataChanged(value: Variant) -> Bool {
    let result: Bool = wrappedMethod(value);
    if !IsDefined(this.m_data) || Equals(this.m_data.m_questType, QuestListItemType.Finished) {
        return result;
    }
    let gi: GameInstance = GetGameInstance();
    if GRGigZone.IsGigObjective(gi, this.m_data.GetFirstObjective()) {
        inkTextRef.SetText(this.m_description, GRGigZone.Fill(gi, inkTextRef.GetText(this.m_description)));
    }
    return result;
}

// Mapa: objetivo seguido.
@wrapMethod(WorldMapMenuGameController)
private final func UpdateTrackedQuest() -> Void {
    wrappedMethod();
    if !IsDefined(this.m_trackedObjective) {
        return;
    }
    let gi: GameInstance = GetGameInstance();
    if GRGigZone.IsGigObjective(gi, this.m_trackedObjective) {
        inkTextRef.SetText(this.m_objectiveName, GRGigZone.Fill(gi, inkTextRef.GetText(this.m_objectiveName)));
    }
}

// Mapa: globo al pasar el cursor sobre el mappin.
@wrapMethod(WorldMapTooltipController)
public func SetData(const data: script_ref<WorldMapTooltipData>, menu: ref<WorldMapMenuGameController>) {
    wrappedMethod(data, menu);
    let pin: ref<JournalQuestMapPin> = Deref(data).journalEntry as JournalQuestMapPin;
    if !IsDefined(pin) {
        return;
    }
    let gi: GameInstance = GetGameInstance();
    let journal: ref<JournalManager> = GameInstance.GetJournalManager(gi);
    if !IsDefined(journal) {
        return;
    }
    let parent: wref<JournalEntry> = journal.GetParentEntry(pin);
    if GRGigZone.IsGigObjective(gi, parent) {
        inkTextRef.SetText(this.m_descText, GRGigZone.Fill(gi, inkTextRef.GetText(this.m_descText)));
    }
}
