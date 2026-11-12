module GangRetaliation

import Codeware.Localization.*

public class GRSpawner extends ScriptableSystem {
    private let m_entityIDs: array<EntityID>;

    private let m_nemesisIDs: array<Int32>;

    private let m_lines: array<String>;

    private let m_speakers: array<String>;

    private let m_mappins: array<NewMappinID>;
    private let m_hasMappin: array<Bool>;

    private let m_sides: array<Int32>;
    private let m_spawnSide: Int32;
    private let m_raidMode: Bool;
    // Guarida: los NPCs esperan en su puesto (hostiles, pero sin saber donde esta V). GRStronghold decide el fin.
    private let m_strongholdMode: Bool;
    private let m_raidHitGang: Bool;
    private let m_raidHitPolice: Bool;
    private let m_raidOutcome: String;
    private let m_raidHeat: Int32;
    private let m_policeImmune: Bool;
    private let m_immuneRaidEnd: Float;
    private let m_raidPoliceOnV: Bool;
    // Los que hacen la redada (bando 1: NCPD, o Barghest en Dogtown). No se borra al terminar la redada:
    // siguen contando mientras se van como sobrantes (ver IsRaidForce). Se reinicia en la redada siguiente.
    private let m_raidForceIDs: array<EntityID>;

    private let m_deaths: array<Int32>;
    private let m_deathKinds: array<String>;

    private let m_finisherIds: array<Int32>;

    private let m_lastHitIds: array<Int32>;
    private let m_lastHitBy: array<String>;
    private let m_deathCauses: array<String>;

    private let m_appearanceReports: array<String>;

    private let m_ambushActive: Bool;
    private let m_ambushStart: Float;
    private let m_ambushSawCombat: Bool;
    private let m_ambushCalmSince: Float;

    // Reintentos de hostilidad (Nemesis que aparecen pasivos) y barra de jefe a vigilar.
    private let m_provokeAmbush: Float;
    private let m_provokeAt: Float;
    private let m_provokeCount: Int32;
    private let m_bossBar: wref<BossHealthBarGameController>;

    private let m_objectivePins: Int32;
    private let m_objectiveSource: String;
    private let m_objectiveDistance: Float;
    private let m_objectiveCheckedAt: Float;
    private let m_stuckChecked: Bool;

    private let m_spawnPositions: array<Vector4>;

    // Emboscada en vehiculo: 0 = a pie, 1 = esperando que carguen, 2 = montados, 3 = conduciendo, 4 = bajados.
    private let m_vehicleID: EntityID;
    private let m_vehicleState: Int32;
    private let m_vehicleStateTime: Float;

    private let m_spotFound: Bool;
    // Por que fallo la ultima busqueda de sitio (para el log): alcanzable, cielo abierto, despejado, a la vista.
    private let m_spotFails: array<Int32>;
    // Busqueda junto al trafico (log): autos cargados, fuera de rango, sin camino, sin hueco, a la vista.
    private let m_trafficFails: array<Int32>;

    // Lo que queda de una emboscada, redada o escaramuza ya terminada. Antes se borraba todo de golpe
    // delante de V (vivos, cadaveres y auto). Ahora los vivos se van y cada uno se borra cuando V no lo ve.
    private let m_leftIDs: array<EntityID>;
    private let m_leftNemesis: array<Int32>;
    private let m_leftSince: array<Float>;
    private let m_leftSent: array<Bool>;
    // Nombre completo del Nemesis (escaner y barra de jefe) mientras se va.
    private let m_leftNames: array<String>;

    // Ultimo Nemesis-maquina rechazado y cuando: la emboscada anunciada reintenta cada 5 s y llenaba el log.
    private let m_machineLoggedId: Int32;
    private let m_machineLoggedAt: Float;

    public static func Get(gi: GameInstance) -> ref<GRSpawner> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRSpawner") as GRSpawner;
    }

    private func OnAttach() {
        GameInstance.GetDynamicEntitySystem().RegisterListener(n"GangRetaliation", this, n"OnEntityEvent");
    }

    private func OnDetach() {
        GameInstance.GetDynamicEntitySystem().UnregisterListener(n"GangRetaliation", this, n"OnEntityEvent");
    }

    private func Now() -> Float {
        return EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
    }

    public func GetGameDay() -> Float {
        return GameInstance.GetTimeSystem(this.GetGameInstance()).GetGameTimeStamp() / 86400.0;
    }

    public func GetTime() -> Float {
        return this.Now();
    }

    private func IndexOf(id: EntityID) -> Int32 {
        let i: Int32 = 0;
        while i < ArraySize(this.m_entityIDs) {
            if this.m_entityIDs[i] == id {
                return i;
            }
            i += 1;
        }
        return -1;
    }

    public func GetNemesisId(id: EntityID) -> Int32 {
        let index: Int32 = this.IndexOf(id);
        if index >= 0 {
            return this.m_nemesisIDs[index];
        }
        // Un Nemesis que se esta yendo sigue teniendo sus rasgos y su causa de muerte.
        let left: Int32 = this.LeftoverIndex(id);
        return left >= 0 ? this.m_leftNemesis[left] : 0;
    }

    // Incluye a los sobrantes: uno que se esta yendo sigue en el mundo y no puede aparecer otra copia.
    public func IsNemesisSpawned(nemesisId: Int32) -> Bool {
        if nemesisId <= 0 {
            return false;
        }
        return ArrayContains(this.m_nemesisIDs, nemesisId) || ArrayContains(this.m_leftNemesis, nemesisId);
    }

    // Hay algo del mod en el mundo (emboscada activa o sobrantes). Lo usa GRTraits para registrar golpes.
    public func HasOwnSpawns() -> Bool {
        return ArraySize(this.m_entityIDs) > 0 || ArraySize(this.m_leftIDs) > 0;
    }

    public func GRProfState() -> String {
        return "spawned=" + IntToString(ArraySize(this.m_entityIDs)) + " leftovers=" + IntToString(ArraySize(this.m_leftIDs));
    }

    private func GetDirection(player: ref<PlayerPuppet>, angle: Float) -> Vector4 {
        return Vector4.RotateAxis(player.GetWorldForward(), Vector4(0.0, 0.0, 1.0, 0.0), angle / 180.0 * Pi());
    }

    private func GetGroundPosition(player: ref<PlayerPuppet>, angle: Float, distance: Float) -> Vector4 {
        let raw: Vector4 = player.GetWorldPosition() + this.GetDirection(player, angle) * distance;
        return GameInstance.GetNavigationSystem(this.GetGameInstance()).GetNearestNavmeshPointBelowOnlyHumanNavmesh(raw, 1.0, 5);
    }

    private func IsReachable(player: ref<PlayerPuppet>, pos: Vector4, distance: Float) -> Bool {
        let target: Vector4 = player.GetWorldPosition();
        // Poca diferencia de altura y camino corto: en edificios de varios pisos evita puntos de otro
        // piso o detras de paredes (habitaciones cerradas del megaedificio).
        if Vector4.IsZero(pos) || AbsF(pos.Z - target.Z) > 2.0 {
            return false;
        }
        let path: ref<NavigationPath> = GameInstance.GetNavigationSystem(this.GetGameInstance()).CalculatePathOnlyHumanNavmesh(pos, target, NavGenAgentSize.Human, 1.0);
        if !IsDefined(path) || ArraySize(path.path) < 2 {
            return false;
        }

        let last: Vector4 = path.path[ArraySize(path.path) - 1];
        return Vector4.Distance(last, target) < 3.0 && path.CalculateLength() < distance * 1.8 + 5.0;
    }

    // Punto metido en una pared: rayos cortos a la altura del pecho chocan en casi todas las direcciones.
    private func IsClearSpot(pos: Vector4) -> Bool {
        let spatial: ref<SpatialQueriesSystem> = GameInstance.GetSpatialQueriesSystem(this.GetGameInstance());
        let chest: Vector4 = pos + new Vector4(0.0, 0.0, 1.2, 0.0);
        let dirs: array<Vector4> = [new Vector4(0.6, 0.0, 0.0, 0.0), new Vector4(-0.6, 0.0, 0.0, 0.0), new Vector4(0.0, 0.6, 0.0, 0.0), new Vector4(0.0, -0.6, 0.0, 0.0)];
        let hits: Int32 = 0;
        for dir in dirs {
            let result: TraceResult;
            if spatial.SyncRaycastByCollisionGroup(chest, chest + dir, n"Static", result, true, false) {
                hits += 1;
            }
        }
        return hits < 3;
    }

    // Solo a cielo abierto: en un megaedificio o un interior el piso de arriba tapa el cielo. Si V esta bajo
    // techo no hay punto valido y la emboscada anunciada espera a que salga a la calle.
    private func IsOpenSky(pos: Vector4) -> Bool {
        let result: TraceResult;
        return !GameInstance.GetSpatialQueriesSystem(this.GetGameInstance()).SyncRaycastByCollisionGroup(pos + new Vector4(0.0, 0.0, 2.0, 0.0), pos + new Vector4(0.0, 0.0, 40.0, 0.0), n"Static", result, true, false);
    }

    // Los dos puntos se conectan a pie (los dos bandos de una redada pueden llegar a pelear).
    private func IsConnected(from: Vector4, to: Vector4) -> Bool {
        let path: ref<NavigationPath> = GameInstance.GetNavigationSystem(this.GetGameInstance()).CalculatePathOnlyHumanNavmesh(from, to, NavGenAgentSize.Human, 1.0);
        if !IsDefined(path) || ArraySize(path.path) < 2 {
            return false;
        }
        let last: Vector4 = path.path[ArraySize(path.path) - 1];
        return Vector4.Distance(last, to) < 3.0 && path.CalculateLength() < Vector4.Distance(from, to) * 2.0 + 10.0;
    }

    // V ve el punto: ninguna pared entre sus ojos y el pecho del NPC. Unica copia: la usan la huida
    // (GRDetection.PlayerSees), los sobrantes y la busqueda de sitio.
    public func HasLineOfSight(player: ref<PlayerPuppet>, pos: Vector4) -> Bool {
        let result: TraceResult;
        let eyes: Vector4 = player.GetWorldPosition() + new Vector4(0.0, 0.0, 1.7, 0.0);
        return !GameInstance.GetSpatialQueriesSystem(this.GetGameInstance()).SyncRaycastByCollisionGroup(eyes, pos + new Vector4(0.0, 0.0, 1.5, 0.0), n"Static", result, true, false);
    }

    // Oculto para V (regla de They Will Remember): fuera del cono de 70 grados delante de V y sin linea
    // de vista ni al pecho ni a la cabeza. Con solo la pared, V lo veia al girar o por un hueco.
    private func IsHiddenFromPlayer(player: ref<PlayerPuppet>, pos: Vector4) -> Bool {
        let toPos: Vector4 = pos - player.GetWorldPosition();
        toPos.Z = 0.0;
        if Vector4.GetAngleBetween(player.GetWorldForward(), toPos) < 70.0 {
            return false;
        }
        let result: TraceResult;
        let eyes: Vector4 = player.GetWorldPosition() + new Vector4(0.0, 0.0, 1.7, 0.0);
        let head: Vector4 = pos + new Vector4(0.0, 0.0, 1.8, 0.0);
        return !this.HasLineOfSight(player, pos)
            && GameInstance.GetSpatialQueriesSystem(this.GetGameInstance()).SyncRaycastByCollisionGroup(eyes, head, n"Static", result, true, false);
    }

    private func FindReachableSpot(player: ref<PlayerPuppet>, angle: Float, distance: Float) -> Vector4 {
        return this.FindSpot(player, angle, distance, 120.0, 0.45, false);
    }

    // Busca un punto a 'distance' en la direccion 'angle' (0 = delante de V), desviandose como mucho
    // maxOffset grados y acercandose como mucho hasta distance * minScale. hidden: fuera de la vista de V.
    private func FindSpot(player: ref<PlayerPuppet>, angle: Float, distance: Float, maxOffset: Float, minScale: Float, hidden: Bool) -> Vector4 {
        let offsets: array<Float> = [0.0, 15.0, -15.0, 30.0, -30.0, 45.0, -45.0, 60.0, -60.0, 80.0, -80.0, 120.0, -120.0];
        let scales: array<Float> = [1.0, 0.85, 0.7, 0.45];
        this.m_spotFails = [0, 0, 0, 0];
        for scale in scales {
            if scale >= minScale {
                for offset in offsets {
                    if AbsF(offset) <= maxOffset {
                        let pos: Vector4 = this.GetGroundPosition(player, angle + offset, distance * scale);
                        if !this.IsReachable(player, pos, distance * scale) {
                            this.m_spotFails[0] += 1;
                        } else {
                            if !this.IsOpenSky(pos) {
                                this.m_spotFails[1] += 1;
                            } else {
                                if !this.IsClearSpot(pos) {
                                    this.m_spotFails[2] += 1;
                                } else {
                                    if hidden && !this.IsHiddenFromPlayer(player, pos) {
                                        this.m_spotFails[3] += 1;
                                    } else {
                                        this.m_spotFound = true;
                                        return pos;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        this.m_spotFound = false;
        return player.GetWorldPosition();
    }

    // Emboscada en auto al estilo de They Will Remember: se genera pegado a un auto que ya esta en la calle
    // (siempre en calzada y con la orientacion del carril), que apunte hacia V y con camino a pie hasta V.
    // Distancias de TWR para V a pie: 90-120 m mas o menos delante, o 50-80 m al costado/detras.
    private func FindTrafficSpot(player: ref<PlayerPuppet>, out spawnPos: Vector4, out spawnOri: Quaternion) -> Bool {
        let traffic: ref<GRTraffic> = GRTraffic.Get(this.GetGameInstance());
        if !IsDefined(traffic) {
            return false;
        }
        let vehicles: array<ref<VehicleObject>> = traffic.GetVehicles();
        let playerPos: Vector4 = player.GetWorldPosition();
        let forward: Vector4 = player.GetWorldForward();
        let checkedPaths: Int32 = 0;
        let playerVehicleID: EntityID;
        let playerVehicle: wref<GameObject> = GetMountedVehicle(player);
        if IsDefined(playerVehicle) {
            playerVehicleID = playerVehicle.GetEntityID();
        }
        this.m_trafficFails = [ArraySize(vehicles), 0, 0, 0, 0];
        for vehicle in vehicles {
            let pos: Vector4 = vehicle.GetWorldPosition();
            let dist: Float = Vector4.Length(pos - playerPos);
            let fovAngle: Float = Vector4.GetAngleBetween(forward, pos - playerPos);
            let fovAngleEnemy: Float = Vector4.GetAngleBetween(vehicle.GetWorldForward(), Vector4.Normalize(playerPos - pos));
            let inBand: Bool = (dist > 90.0 && dist < 120.0 && fovAngle < 70.0 && fovAngleEnemy < 60.0)
                || (dist > 50.0 && dist < 80.0 && fovAngle > 70.0 && fovAngleEnemy < 60.0);
            // Fuera: el auto de V, autos en otro nivel (puentes, AV) y los nuestros.
            let own: Bool = vehicle.GetEntityID() == this.m_vehicleID || (EntityID.IsDefined(playerVehicleID) && vehicle.GetEntityID() == playerVehicleID);
            if !inBand || own || AbsF(pos.Z - playerPos.Z) > 6.0 {
                this.m_trafficFails[1] += 1;
            } else {
                // Cada camino cuesta: como mucho 8 por intento.
                if checkedPaths >= 8 {
                    return false;
                }
                checkedPaths += 1;
                let path: ref<NavigationPath> = GameInstance.GetNavigationSystem(this.GetGameInstance()).CalculatePathOnlyHumanNavmesh(pos, playerPos, NavGenAgentSize.Human, 5.0);
                let pathLength: Float = IsDefined(path) ? path.CalculateLength() : 0.0;
                if pathLength <= 0.0 || pathLength > 2.0 * dist {
                    this.m_trafficFails[2] += 1;
                } else {
                    if !this.HasSpaceForCar(vehicle, spawnPos) {
                        this.m_trafficFails[3] += 1;
                    } else {
                        // Cerca y a la vista de V se veria aparecer de la nada.
                        if dist < 80.0 && this.HasLineOfSight(player, spawnPos) {
                            this.m_trafficFails[4] += 1;
                        } else {
                            spawnOri = vehicle.GetWorldOrientation();
                            let ground: Vector4 = GameInstance.GetNavigationSystem(this.GetGameInstance()).GetNearestNavmeshPointBelowOnlyHumanNavmesh(spawnPos + new Vector4(0.0, 0.0, 1.0, 0.0), 0.5, 5);
                            if !Vector4.IsZero(ground) && Vector4.Distance(ground, spawnPos) <= 10.0 {
                                spawnPos = ground;
                            }
                            return true;
                        }
                    }
                }
            }
        }
        return false;
    }

    // Hueco de un auto (caja de 5 x 8 x 2 m) a 10 m delante o detras del auto del trafico, sin chocar
    // con paredes ni con otros vehiculos.
    private func HasSpaceForCar(vehicle: ref<VehicleObject>, out spawnPos: Vector4) -> Bool {
        let spatial: ref<SpatialQueriesSystem> = GameInstance.GetSpatialQueriesSystem(this.GetGameInstance());
        let box: Vector4 = new Vector4(2.5, 4.0, 1.0, 0.0);
        let forward: Vector4 = vehicle.GetWorldForward();
        forward.Z = 0.0;
        forward = Vector4.Normalize(forward);
        let origin: Vector4 = vehicle.GetWorldPosition();
        let angles: array<Float> = [0.0, Pi()];
        for angle in angles {
            let dir: Vector4 = Vector4.RotateAxis(forward, new Vector4(0.0, 0.0, 1.0, 0.0), angle);
            let query: Vector4 = origin + dir * 10.0;
            query.Z += box.Z + 0.2;
            let rotation: EulerAngles = Quaternion.ToEulerAngles(Quaternion.BuildFromDirectionVector(dir));
            let hitStatic: TraceResult;
            let hitVehicle: TraceResult;
            if !spatial.Overlap(box, query, rotation, n"Static", hitStatic) && !spatial.Overlap(box, query, rotation, n"Vehicle", hitVehicle) {
                spawnPos = query;
                return true;
            }
        }
        return false;
    }

    // Escolta junto al lider (el grupo llega junto), ajustada al navmesh; si no hay sitio, en el del lider.
    private func EscortSpot(leader: Vector4, index: Int32) -> Vector4 {
        let angle: Float = Cast<Float>(index) * 2.4 + RandRangeF(-0.4, 0.4);
        let radius: Float = RandRangeF(2.5, 5.0);
        let raw: Vector4 = leader + new Vector4(CosF(angle) * radius, SinF(angle) * radius, 1.0, 0.0);
        let pos: Vector4 = GameInstance.GetNavigationSystem(this.GetGameInstance()).GetNearestNavmeshPointBelowOnlyHumanNavmesh(raw, 1.0, 5);
        if Vector4.IsZero(pos) || AbsF(pos.Z - leader.Z) > 1.5 || !this.IsClearSpot(pos) {
            return leader;
        }
        return pos;
    }

    public func FindWarSpot(angle: Float, distance: Float) -> Vector4 {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) {
            return Vector4.EmptyVector();
        }
        let pos: Vector4 = this.FindReachableSpot(player, angle, distance);
        return this.m_spotFound ? pos : Vector4.EmptyVector();
    }

    private func GetFacingPlayer(player: ref<PlayerPuppet>, from: Vector4) -> Quaternion {
        return EulerAngles.ToQuat(Vector4.ToRotation(player.GetWorldPosition() - from));
    }

    private func SpawnAt(nemesisId: Int32, recordID: String, appearance: String, position: Vector4, orientation: Quaternion, line: String, speaker: String) -> Bool {
        let des: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
        if !IsDefined(des) || !des.IsReady() {
            return false;
        }
        let spec: ref<DynamicEntitySpec> = new DynamicEntitySpec();
        spec.recordID = TDBID.Create(recordID);
        spec.appearanceName = StrLen(appearance) > 0 ? StringToName(appearance) : n"random";
        spec.position = position;
        spec.orientation = orientation;
        spec.persistState = false;
        spec.persistSpawn = false;
        spec.alwaysSpawned = false;
        spec.spawnInView = true;
        spec.active = true;
        ArrayPush(spec.tags, n"GangRetaliation");

        let entityID: EntityID = des.CreateEntity(spec);
        ArrayPush(this.m_entityIDs, entityID);
        ArrayPush(this.m_spawnPositions, position);
        ArrayPush(this.m_nemesisIDs, nemesisId);
        ArrayPush(this.m_lines, line);
        ArrayPush(this.m_speakers, speaker);
        let noMappin: NewMappinID;
        ArrayPush(this.m_mappins, noMappin);
        ArrayPush(this.m_hasMappin, false);
        ArrayPush(this.m_sides, this.m_spawnSide);
        if this.m_spawnSide == 1 {
            ArrayPush(this.m_raidForceIDs, entityID);
        }
        return true;
    }

    public func GetNemesisName(id: EntityID) -> String {
        let index: Int32 = this.IndexOf(id);
        if index >= 0 {
            return this.m_nemesisIDs[index] > 0 ? this.m_speakers[index] : "";
        }
        let left: Int32 = this.LeftoverIndex(id);
        return left >= 0 && this.m_leftNemesis[left] > 0 ? this.m_leftNames[left] : "";
    }

    private func AddMappin(index: Int32, npc: ref<GameObject>) {
        let data: MappinData;
        data.mappinType = t"Mappins.DefaultStaticMappin";
        data.variant = gamedataMappinVariant.HuntForPsychoVariant;
        data.active = true;
        data.visibleThroughWalls = true;
        this.m_mappins[index] = GameInstance.GetMappinSystem(this.GetGameInstance()).RegisterMappinWithObject(data, npc, n"poi_mappin", new Vector3(0.0, 0.0, 2.2));
        this.m_hasMappin[index] = true;
    }

    private func RemoveMappin(index: Int32) {
        if this.m_hasMappin[index] {
            GameInstance.GetMappinSystem(this.GetGameInstance()).UnregisterMappin(this.m_mappins[index]);
            this.m_hasMappin[index] = false;
        }
    }

    public func MarkDead(id: EntityID) {
        let npc: ref<ScriptedPuppet> = GameInstance.FindEntityByID(this.GetGameInstance(), id) as ScriptedPuppet;
        let index: Int32 = this.IndexOf(id);
        if index >= 0 {
            this.RemoveMappin(index);
            if this.m_nemesisIDs[index] > 0 {
                this.RecordDeath(this.m_nemesisIDs[index], npc);
                this.m_nemesisIDs[index] = 0;
            }
            return;
        }
        let left: Int32 = this.LeftoverIndex(id);
        if left >= 0 && this.m_leftNemesis[left] > 0 {
            this.RecordDeath(this.m_leftNemesis[left], npc);
            this.m_leftNemesis[left] = 0;
        }
    }

    private func RecordDeath(nemesisId: Int32, npc: ref<ScriptedPuppet>) {
        let kind: String = this.DeathKind(nemesisId, npc);
        ArrayPush(this.m_deaths, nemesisId);
        let cause: String = this.TakeLastHit(nemesisId);
        if NotEquals(cause, "v") && this.KilledByPlayer(npc as NPCPuppet) {
            GRLog("Nemesis #" + IntToString(nemesisId) + ": muerte indirecta (" + cause + "), atribuida a V");
            cause = "v";
        }
        if Equals(kind, "confirmed") && NotEquals(cause, "v") {
            kind = "normal";
        }
        ArrayPush(this.m_deathKinds, kind);
        ArrayPush(this.m_deathCauses, cause);
        ArrayRemove(this.m_finisherIds, nemesisId);
        GRLog("Nemesis #" + IntToString(nemesisId) + " muerto (" + kind + ", " + cause + ")");
    }

    // V como responsable de una muerte o un derribo sin golpe suyo registrado. El juego mata a los pasajeros
    // de un auto que explota con el estado ForceKill (no hay golpe) y los derribos por agarre no pasan por
    // el sistema de dano. Se mira a quien anota el juego: GetMyKiller (instigador del evento de muerte o del
    // derribo letal) y quien aplico el estado que lo mato o lo dejo inconsciente. Un vehiculo destruido
    // cuenta para V si V lo dano. Siempre desde el hilo principal.
    private func KilledByPlayer(npc: ref<NPCPuppet>) -> Bool {
        if !IsDefined(npc) {
            return false;
        }
        // Derribo por agarre: sigue montado en V (ranura "grapple") mientras dura la animacion.
        if ScriptedPuppet.IsBeingGrappled(npc) {
            return true;
        }
        let sources: array<wref<GameObject>>;
        ArrayPush(sources, npc.GetMyKiller());
        ArrayPush(sources, GetMountedVehicle(npc));
        let effects: array<TweakDBID> = [t"BaseStatusEffect.ForceKill", t"BaseStatusEffect.Unconscious"];
        for effectID in effects {
            let effect: ref<StatusEffect> = StatusEffectHelper.GetStatusEffectByID(npc, effectID);
            if IsDefined(effect) {
                ArrayPush(sources, GameInstance.FindEntityByID(this.GetGameInstance(), effect.GetInstigatorEntityID()) as GameObject);
            }
        }
        for source in sources {
            let vehicle: ref<VehicleObject> = source as VehicleObject;
            if IsDefined(source) && (source.IsPlayer() || (IsDefined(vehicle) && vehicle.IsDestroyed() && vehicle.GRHitByPlayer())) {
                return true;
            }
        }
        return false;
    }

    private func DeathKind(nemesisId: Int32, npc: ref<ScriptedPuppet>) -> String {
        if IsDefined(npc) && !npc.IsDead() && (ScriptedPuppet.IsUnconscious(npc) || ScriptedPuppet.IsDefeated(npc)) {
            return "knockout";
        }
        if ArrayContains(this.m_finisherIds, nemesisId) {
            return "confirmed";
        }
        if IsDefined(npc) && IsDefined(npc.GetDismembermentComponent()) {
            let limbs = npc.GetDismembermentComponent().GetDismemberedLimbCount();
            if limbs.fleshDismemberments + limbs.cyberDismemberments > 0u {
                return "confirmed";
            }
        }
        return "normal";
    }

    public func RecordHitBy(nemesisId: Int32, source: String) {
        let i: Int32 = ArrayFindFirst(this.m_lastHitIds, nemesisId);
        if i >= 0 {
            this.m_lastHitBy[i] = source;
        } else {
            ArrayPush(this.m_lastHitIds, nemesisId);
            ArrayPush(this.m_lastHitBy, source);
        }
        if NotEquals(source, "v") {
            ArrayRemove(this.m_finisherIds, nemesisId);
        }
    }

    private func TakeLastHit(nemesisId: Int32) -> String {
        let i: Int32 = ArrayFindFirst(this.m_lastHitIds, nemesisId);
        if i < 0 {
            return "other";
        }
        let source: String = this.m_lastHitBy[i];
        ArrayErase(this.m_lastHitIds, i);
        ArrayErase(this.m_lastHitBy, i);
        return source;
    }

    public func RecordPlayerHit(nemesisId: Int32, finisher: Bool) {
        this.RecordHitBy(nemesisId, "v");
        if finisher {
            if !ArrayContains(this.m_finisherIds, nemesisId) {
                ArrayPush(this.m_finisherIds, nemesisId);
            }
        } else {
            ArrayRemove(this.m_finisherIds, nemesisId);
        }
    }

    private func CheckNeutralized() {
        let i: Int32 = ArraySize(this.m_entityIDs) - 1;
        while i >= 0 {
            if this.m_nemesisIDs[i] > 0 {
                let npc: ref<ScriptedPuppet> = GameInstance.FindEntityByID(this.GetGameInstance(), this.m_entityIDs[i]) as ScriptedPuppet;
                if IsDefined(npc) && (npc.IsDead() || ScriptedPuppet.IsDefeated(npc) || ScriptedPuppet.IsUnconscious(npc)) {
                    this.MarkDead(this.m_entityIDs[i]);
                }
            }
            i -= 1;
        }
    }

    private func CheckTaunts() {
        let taunts: ref<GRTaunts> = GRTaunts.Get(this.GetGameInstance());
        if !IsDefined(taunts) {
            return;
        }
        let i: Int32 = 0;
        while i < ArraySize(this.m_entityIDs) {
            if this.m_nemesisIDs[i] > 0 {
                let npc: ref<ScriptedPuppet> = GameInstance.FindEntityByID(this.GetGameInstance(), this.m_entityIDs[i]) as ScriptedPuppet;
                if IsDefined(npc) && !GRDetection.IsNeutralized(npc) {
                    taunts.CheckHealth(npc);
                }
            }
            i += 1;
        }
    }

    // Nemesis guardado con un record de drone/mech/robot (las versiones hasta 1.3.x los ascendian): no se
    // genera. Lo consultan todos los caminos que generan un Nemesis por su record. El aviso sale como mucho
    // una vez por minuto por Nemesis.
    private func IsMachineNemesis(nemesisId: Int32, recordID: String, what: String) -> Bool {
        if !GRDetection.IsMachineRecordID(recordID) {
            return false;
        }
        let now: Float = this.Now();
        if this.m_machineLoggedId != nemesisId || this.m_machineLoggedAt <= 0.0 || now - this.m_machineLoggedAt > 60.0 || now < this.m_machineLoggedAt {
            this.m_machineLoggedId = nemesisId;
            this.m_machineLoggedAt = now;
            GRLog(what + ": Nemesis #" + IntToString(nemesisId) + " no se genera, su record es una maquina (drone/mech/robot): " + recordID);
        }
        return true;
    }

    // Para CET: al cargar la campana saca a los Nemesis guardados cuyo record es una maquina.
    public func IsMachineRecordID(recordID: String) -> Bool {
        return GRDetection.IsMachineRecordID(recordID);
    }

    public func SpawnNearPlayer(nemesisId: Int32, recordID: String, appearance: String, distance: Float, name: String) -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) || this.IsNemesisSpawned(nemesisId) {
            return false;
        }
        if this.IsMachineNemesis(nemesisId, recordID, "Generar cerca") {
            return false;
        }
        let pos: Vector4 = this.FindReachableSpot(player, 0.0, distance);
        if !this.m_spotFound {
            return false;
        }
        let ok: Bool = this.SpawnAt(nemesisId, recordID, appearance, pos, this.GetFacingPlayer(player, pos), "", name);
        if ok {
            GRLog("Generando Nemesis #" + IntToString(nemesisId) + " (" + recordID + ")");
        }
        return ok;
    }

    public func GetAmbushBlocker() -> String {
        let blocker: String = this.GetSpawnBlocker();
        if StrLen(blocker) > 0 {
            return blocker;
        }
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if player.IsInCombat() {
            return "in combat";
        }
        if StatusEffectSystem.ObjectHasStatusEffectWithTag(player, n"NoCombat") {
            return "no-combat zone";
        }
        if this.IsInScene() {
            return "scene (no weapons)";
        }
        if this.IsPlayerSwimming() {
            return "underwater";
        }
        if this.IsQuestObjectiveNearby() {
            return "quest objective nearby";
        }
        if GRSpawner.IsTWRSquadActive() {
            return "They Will Remember squad";
        }
        if GRIntegrations.IsDDJobActive(this.GetGameInstance()) {
            return "Drug Dealer job";
        }
        return "";
    }

    // V nadando o buceando (cualquier estado de nado distinto del normal: superficie, buceo, saliendo del
    // agua). Lo mismo que lee PlayerPuppet.IsSwimming del juego. Reporte: emboscada en el buceo con Judy.
    public func IsPlayerSwimming() -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) {
            return false;
        }
        let swimming: Int32 = player.GetPlayerStateMachineBlackboard().GetInt(GetAllBlackboardDefs().PlayerStateMachine.Swimming);
        return swimming != EnumInt(gamePSMSwimming.Default);
    }

    // V a menos de 150 m (en horizontal) de algun punto del objetivo que esta siguiendo, sea del tipo de
    // mision que sea: ahi una emboscada cae en medio de la mision. Sin objetivo seguido o sin punto en el
    // mapa no bloquea. Usa la distancia cacheada de GetTrackedObjectiveDistance.
    public func IsQuestObjectiveNearby() -> Bool {
        let distance: Float = this.GetTrackedObjectiveDistance();
        return distance >= 0.0 && distance < 150.0;
    }

    // Para CET (Integrations.reds): escuadron de TWR/DD cerca ("TWR|Banda") y multiplicador de emboscadas.
    public func GetExternalSquad() -> String {
        return GRIntegrations.GetExternalSquad(this.GetGameInstance());
    }

    public func GetHeatFactor() -> Float {
        return GRIntegrations.GetHeatFactor(this.GetGameInstance(), this.GetDistrictGangs());
    }

    // Panel dev: debug de Drug Dealer. 0 capturar zona al azar, 1 disputar la actual, 2 +25 terror, 3 soltar zonas.
    public func DebugDD(action: Int32) -> String {
        switch action {
            case 0: return GRIntegrations.DebugCaptureRandomTurf();
            case 1: return GRIntegrations.DebugContestCurrentTurf();
            case 2: return GRIntegrations.DebugAddTerror();
            case 3: return GRIntegrations.DebugSurrenderAllTurfs();
            default: return "";
        }
    }

    // Panel dev: 0 = simular venganza de TWR, 1 = simular perdon pagado y rechazado.
    public func DebugTWR(action: Int32) -> String {
        let watch: ref<GRTWRWatch> = GRTWRWatch.Get(this.GetGameInstance());
        return IsDefined(watch) ? watch.Debug(action) : "TWR watch not ready";
    }

    public func GetDDDebugInfo() -> String {
        let settings: ref<GRSettings> = GRSettings.Get(this.GetGameInstance());
        return GRIntegrations.GetDDDebugInfo(IsDefined(settings) ? settings.fleeHealthPercent : 35);
    }

    // They Will Remember manda sus propias venganzas (tag TheyWillRemember.Squad): no sumar otra encima.
    public static func IsTWRSquadActive() -> Bool {
        let des: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
        if !IsDefined(des) {
            return false;
        }
        // Solo miembros vivos: TWR no borra los cadaveres mientras V este a menos de 80 m.
        let squad: array<ref<Entity>> = des.GetTagged(n"TheyWillRemember.Squad");
        for member in squad {
            let npc: ref<ScriptedPuppet> = member as ScriptedPuppet;
            if IsDefined(npc) && !GRDetection.IsNeutralized(npc) {
                return true;
            }
        }
        return false;
    }

    // Tier de escena 2-5: V camina sin armas (departamento, escenas de mision). En la calle es 1.
    public func IsInScene() -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) {
            return false;
        }
        let tier: Int32 = player.GetPlayerStateMachineBlackboard().GetInt(GetAllBlackboardDefs().PlayerStateMachine.HighLevel);
        return tier >= 2 && tier <= 5;
    }

    // Distancia horizontal de V al punto mas cercano del objetivo seguido (-1 = sin punto en el mapa).
    // Igual que el mapa del juego (worldMap.swift): solo si la entrada seguida es un objetivo, y con su hash.
    // GetQuestMappinPosition NO va aca: espera el hash de un mappin, no de un objetivo (sospecha del crash
    // del 31/10). Se recalcula como mucho una vez cada 2 s (el panel CET lo pide en cada frame y el bloqueo
    // de emboscadas en cada tick). m_objectivePins / m_objectiveSource quedan para el panel dev.
    public func GetTrackedObjectiveDistance() -> Float {
        let now: Float = this.Now();
        if this.m_objectiveCheckedAt > 0.0 && now >= this.m_objectiveCheckedAt && now - this.m_objectiveCheckedAt < 2.0 {
            return this.m_objectiveDistance;
        }
        this.m_objectiveCheckedAt = now;
        this.m_objectiveDistance = -1.0;
        this.m_objectivePins = 0;
        this.m_objectiveSource = "none";
        let gi: GameInstance = this.GetGameInstance();
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        let journal: ref<JournalManager> = GameInstance.GetJournalManager(gi);
        let mappins: ref<MappinSystem> = GameInstance.GetMappinSystem(gi);
        if !IsDefined(player) || !IsDefined(journal) || !IsDefined(mappins) {
            return -1.0;
        }
        let objective: ref<JournalQuestObjectiveBase> = journal.GetTrackedEntry() as JournalQuestObjectiveBase;
        if !IsDefined(objective) {
            this.m_objectiveSource = "not an objective";
            return -1.0;
        }
        let positions: array<Vector3>;
        mappins.GetQuestMappinPositionsByObjective(Cast<Uint32>(journal.GetEntryHash(objective)), positions);
        this.m_objectivePins = ArraySize(positions);
        if this.m_objectivePins == 0 {
            return -1.0;
        }
        this.m_objectiveSource = "objective";
        let playerPos: Vector4 = player.GetWorldPosition();
        let nearest: Float = -1.0;
        for pos in positions {
            let dx: Float = pos.X - playerPos.X;
            let dy: Float = pos.Y - playerPos.Y;
            let d: Float = SqrtF(dx * dx + dy * dy);
            if nearest < 0.0 || d < nearest {
                nearest = d;
            }
        }
        this.m_objectiveDistance = nearest;
        return nearest;
    }

    // Texto para el panel dev: tipo de mision seguida, distancia y de donde salio el punto.
    public func GetTrackedObjectiveInfo() -> String {
        let quest: wref<JournalQuest> = this.GetTrackedQuest();
        let questType: String = IsDefined(quest) ? EnumValueToString("gameJournalQuestType", Cast<Int64>(EnumInt(quest.GetType()))) : "-";
        let distance: Float = this.GetTrackedObjectiveDistance();
        let where: String = distance < 0.0 ? "no pin" : IntToString(Cast<Int32>(distance)) + " m";
        return "objective: " + questType + ", " + where + " (" + IntToString(this.m_objectivePins) + " pins, " + this.m_objectiveSource + ")";
    }

    // Mision de historia seguida y V cerca de su objetivo: ahi una huida puede dejar la mision sin terminar.
    // Lejos del objetivo, o sin punto en el mapa, no bloquea (casi todos siguen siempre alguna mision).
    public func IsStoryQuestNearby() -> Bool {
        if !this.IsStoryQuestTracked() {
            return false;
        }
        let distance: Float = this.GetTrackedObjectiveDistance();
        return distance >= 0.0 && distance < 150.0;
    }

    // Mision de historia seguida (no gigs).
    public func IsStoryQuestTracked() -> Bool {
        let quest: wref<JournalQuest> = this.GetTrackedQuest();
        if !IsDefined(quest) {
            return false;
        }
        let questType: gameJournalQuestType = quest.GetType();
        return Equals(questType, gameJournalQuestType.MainQuest) || Equals(questType, gameJournalQuestType.SideQuest)
            || Equals(questType, gameJournalQuestType.MinorQuest) || Equals(questType, gameJournalQuestType.StreetStory);
    }

    public func IsOwnSpawn(id: EntityID) -> Bool {
        return this.IndexOf(id) >= 0 || this.LeftoverIndex(id) >= 0;
    }

    private func GetSpawnBlocker() -> String {
        let gi: GameInstance = this.GetGameInstance();
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        if !IsDefined(player) || player.IsDead() {
            return "no player";
        }
        if this.m_ambushActive {
            return "ambush active";
        }
        if !GameInstance.GetDynamicEntitySystem().IsReady() {
            return "entity system not ready";
        }
        if VehicleComponent.IsMountedToVehicle(gi, player) {
            return "in vehicle";
        }
        return "";
    }

    public func GetReinforcementBlocker() -> String {
        let blocker: String = this.GetSpawnBlocker();
        if StrLen(blocker) > 0 {
            return blocker;
        }
        if !GetPlayer(this.GetGameInstance()).IsInCombat() {
            return "not in combat";
        }
        return "";
    }

    public func GetActiveGigId() -> String {
        let quest: wref<JournalQuest> = this.GetTrackedQuest();
        if !IsDefined(quest) || NotEquals(quest.GetType(), gameJournalQuestType.Contract) {
            return "";
        }
        return quest.GetId();
    }

    public func GetActiveGigTitle() -> String {
        let quest: wref<JournalQuest> = this.GetTrackedQuest();
        if !IsDefined(quest) {
            return "";
        }
        return quest.GetTitle(GameInstance.GetJournalManager(this.GetGameInstance()));
    }

    private func GetTrackedQuest() -> wref<JournalQuest> {
        let journal: ref<JournalManager> = GameInstance.GetJournalManager(this.GetGameInstance());
        let entry: wref<JournalEntry> = journal.GetTrackedEntry();
        let depth: Int32 = 0;
        while IsDefined(entry) && depth < 6 {
            let quest: wref<JournalQuest> = entry as JournalQuest;
            if IsDefined(quest) {
                return quest;
            }
            entry = journal.GetParentEntry(entry);
            depth += 1;
        }
        return null;
    }

    public func GetDistrictGangs() -> String {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) {
            return "";
        }
        let district: wref<District_Record> = player.GetPreventionSystem().GetCurrentDistrict().GetDistrictRecord();
        let result: String = "";

        while IsDefined(district) && StrLen(result) == 0 {
            if district.GetGangsCount() > 0 {
                let gangs: array<wref<Affiliation_Record>>;
                district.Gangs(gangs);
                for gang in gangs {
                    result += (StrLen(result) > 0 ? "," : "") + NameToString(gang.EnumName());
                }
            }
            district = district.ParentDistrict();
        }
        return result;
    }

    public func GetDistrictName() -> String {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) {
            return "";
        }
        let district: wref<District_Record> = player.GetPreventionSystem().GetCurrentDistrict().GetDistrictRecord();
        return IsDefined(district) ? district.EnumName() : "";
    }

    public func StartAmbush(nemesisId: Int32, recordID: String, appearance: String, escortRecords: String, line: String, speaker: String) -> Bool {
        let blocker: String = this.GetAmbushBlocker();
        if StrLen(blocker) > 0 || this.IsNemesisSpawned(nemesisId) {
            GRLog("A pie: no se intenta (bloqueo=" + blocker + ", ya generado=" + ToString(this.IsNemesisSpawned(nemesisId)) + ")");
            return false;
        }
        this.m_raidMode = false;
        if !this.SpawnGroup(nemesisId, recordID, appearance, escortRecords, line, speaker, 40.0) {
            return false;
        }
        this.m_ambushSawCombat = false;
        GRLog("Emboscada: Nemesis #" + IntToString(nemesisId));
        return true;
    }

    // Llegan en un vehiculo de la banda: aparece fuera de la vista a ~70 m detras de V, conducen hasta V y
    // se bajan a pelear. Los comandos de IA se mandan desde el tick (nunca desde eventos).
    public func StartVehicleAmbush(nemesisId: Int32, recordID: String, appearance: String, escortRecords: String, line: String, speaker: String, vehicleRecord: String) -> Bool {
        let blocker: String = this.GetAmbushBlocker();
        if StrLen(blocker) > 0 || this.IsNemesisSpawned(nemesisId) {
            GRLog("Vehiculo: no se intenta (bloqueo=" + blocker + ", ya generado=" + ToString(this.IsNemesisSpawned(nemesisId)) + ")");
            return false;
        }
        if this.IsMachineNemesis(nemesisId, recordID, "Vehiculo") {
            return false;
        }
        if !IsDefined(TweakDBInterface.GetVehicleRecord(TDBID.Create(vehicleRecord))) {
            GRLog("Vehiculo: record inexistente " + vehicleRecord);
            return false;
        }
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let pos: Vector4;
        let orientation: Quaternion;
        // Primero junto a un auto del trafico (en la calle, mirando como el carril).
        if this.FindTrafficSpot(player, pos, orientation) {
            GRLog("Vehiculo: junto a un auto del trafico a " + FloatToString(Vector4.Distance(pos, player.GetWorldPosition())) + " m");
        } else {
            GRLog("Vehiculo: sin auto del trafico util (cargados=" + IntToString(this.m_trafficFails[0])
                + ", fuera de rango=" + IntToString(this.m_trafficFails[1]) + ", sin camino=" + IntToString(this.m_trafficFails[2])
                + ", sin hueco=" + IntToString(this.m_trafficFails[3]) + ", a la vista=" + IntToString(this.m_trafficFails[4]) + ")");
            // Si no: detras de V; si no hay sitio, cualquier lado salvo delante, y mas cerca.
            pos = this.FindSpot(player, RandRangeF(165.0, 195.0), 70.0, 120.0, 0.45, true);
            if !this.m_spotFound {
                GRLog("Vehiculo: sin sitio alrededor de V (descartes: no alcanzable=" + IntToString(this.m_spotFails[0])
                    + ", bajo techo=" + IntToString(this.m_spotFails[1]) + ", ocupado=" + IntToString(this.m_spotFails[2])
                    + ", a la vista=" + IntToString(this.m_spotFails[3]) + ")");
                return false;
            }
            orientation = this.GetFacingPlayer(player, pos);
        }
        let des: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
        let spec: ref<DynamicEntitySpec> = new DynamicEntitySpec();
        spec.recordID = TDBID.Create(vehicleRecord);
        spec.position = pos;
        spec.orientation = orientation;
        spec.persistState = false;
        spec.persistSpawn = false;
        spec.alwaysSpawned = false;
        spec.spawnInView = true;
        spec.active = true;
        ArrayPush(spec.tags, n"GangRetaliation");
        this.m_vehicleID = des.CreateEntity(spec);
        if !EntityID.IsDefined(this.m_vehicleID) {
            GRLog("Vehiculo: CreateEntity fallo para " + vehicleRecord);
            return false;
        }

        this.m_raidMode = false;
        this.m_vehicleState = 1;
        this.m_vehicleStateTime = this.Now();
        this.SpawnAt(nemesisId, recordID, appearance, pos, spec.orientation, line, speaker);
        let escorts: array<String>;
        if StrLen(escortRecords) > 0 {
            escorts = StrSplit(escortRecords, ",");
        }
        // Como mucho 3 escoltas: el vehiculo tiene 4 asientos.
        let i: Int32 = 0;
        while i < ArraySize(escorts) && i < 3 {
            this.SpawnAt(0, escorts[i], "", this.EscortSpot(pos, i), spec.orientation, "", "");
            i += 1;
        }
        this.m_ambushActive = true;
        this.m_ambushStart = this.Now();
        this.m_ambushCalmSince = 0.0;
        this.m_ambushSawCombat = false;
        this.m_stuckChecked = true;
        GRLog("Emboscada en vehiculo: Nemesis #" + IntToString(nemesisId) + " (" + vehicleRecord + ")");
        return true;
    }

    private func SeatName(index: Int32) -> CName {
        switch index {
            case 0: return n"seat_front_left";
            case 1: return n"seat_front_right";
            case 2: return n"seat_back_left";
            default: return n"seat_back_right";
        }
    }

    private func MountData(index: Int32) -> ref<MountEventData> {
        let data: ref<MountEventData> = new MountEventData();
        data.slotName = this.SeatName(index);
        data.mountParentEntityId = this.m_vehicleID;
        data.isInstant = true;
        data.ignoreHLS = true;
        return data;
    }

    private func GetVehicle() -> ref<VehicleObject> {
        return GameInstance.FindEntityByID(this.GetGameInstance(), this.m_vehicleID) as VehicleObject;
    }

    private func TickVehicle(player: ref<PlayerPuppet>, now: Float) {
        let vehicle: ref<VehicleObject> = this.GetVehicle();
        let elapsed: Float = now - this.m_vehicleStateTime;
        if this.m_vehicleState == 1 {
            let ready: Bool = IsDefined(vehicle);
            let i: Int32 = 0;
            while i < ArraySize(this.m_entityIDs) {
                if !IsDefined(GameInstance.FindEntityByID(this.GetGameInstance(), this.m_entityIDs[i]) as ScriptedPuppet) {
                    ready = false;
                }
                i += 1;
            }
            if ready {
                let seat: Int32 = 0;
                while seat < ArraySize(this.m_entityIDs) {
                    let npc: ref<ScriptedPuppet> = GameInstance.FindEntityByID(this.GetGameInstance(), this.m_entityIDs[seat]) as ScriptedPuppet;
                    let mount: ref<AIMountCommand> = new AIMountCommand();
                    mount.mountData = this.MountData(seat);
                    npc.GetAIControllerComponent().SendCommand(mount);
                    seat += 1;
                }
                GRLog("Vehiculo: montando " + IntToString(ArraySize(this.m_entityIDs)) + " NPC");
                this.SetVehicleState(2, now);
            } else {
                if elapsed > 15.0 {
                    GRLog("Vehiculo: no cargo a tiempo, se bajan a pie");
                    this.StartVehicleFight(player, now);
                }
            }
        } else {
            if this.m_vehicleState == 2 && elapsed > 2.0 {
                if IsDefined(vehicle) {
                    let drive: ref<AIVehicleDriveToPointAutonomousCommand> = new AIVehicleDriveToPointAutonomousCommand();
                    drive.targetPosition = Vector4.Vector4To3(player.GetWorldPosition());
                    drive.minimumDistanceToTarget = 10.0;
                    // TWR usa 80/10 para sus refuerzos; con 14 llegaban tarde y V ya se habia ido.
                    drive.maxSpeed = 40.0;
                    drive.minSpeed = 10.0;
                    drive.clearTrafficOnPath = true;
                    drive.driveDownTheRoadIndefinitely = false;
                    drive.needDriver = true;
                    let evt: ref<AICommandEvent> = new AICommandEvent();
                    evt.command = drive;
                    vehicle.QueueEvent(evt);
                    // Si el auto se descarga y vuelve a cargar, retoma este comando (como TWR).
                    vehicle.GetAIComponent().SetInitCmd(drive);
                    GRLog("Vehiculo: conduciendo hacia V");
                }
                this.SetVehicleState(3, now);
            } else {
                if this.m_vehicleState == 3 {
                    let close: Bool = IsDefined(vehicle) && Vector4.Distance(vehicle.GetWorldPosition(), player.GetWorldPosition()) < 20.0;
                    if close || !IsDefined(vehicle) || elapsed > 35.0 || player.IsInCombat() {
                        GRLog("Vehiculo: se bajan (cerca=" + ToString(close) + ", " + FloatToString(elapsed) + " s)");
                        this.StartVehicleFight(player, now);
                    }
                }
            }
        }
    }

    private func SetVehicleState(state: Int32, now: Float) {
        this.m_vehicleState = state;
        this.m_vehicleStateTime = now;
    }

    // Se bajan y atacan; desde aqui sigue como una emboscada normal (con chequeo de atasco).
    private func StartVehicleFight(player: ref<PlayerPuppet>, now: Float) {
        let i: Int32 = 0;
        while i < ArraySize(this.m_entityIDs) {
            let npc: ref<ScriptedPuppet> = GameInstance.FindEntityByID(this.GetGameInstance(), this.m_entityIDs[i]) as ScriptedPuppet;
            if IsDefined(npc) {
                if this.m_vehicleState >= 2 {
                    let unmount: ref<AIUnmountCommand> = new AIUnmountCommand();
                    unmount.mountData = this.MountData(i);
                    unmount.mountData.isInstant = false;
                    npc.GetAIControllerComponent().SendCommand(unmount);
                }
                this.MakeHostile(i, npc, player);
                this.m_spawnPositions[i] = npc.GetWorldPosition();
            }
            i += 1;
        }
        this.SetVehicleState(4, now);
        this.m_ambushStart = now;
        this.m_stuckChecked = false;
    }

    private func MakeHostile(index: Int32, npc: ref<ScriptedPuppet>, player: ref<PlayerPuppet>) {
        if !IsDefined(npc.GetAttitudeAgent()) || !IsDefined(player.GetAttitudeAgent()) {
            return;
        }
        npc.GetAttitudeAgent().SetAttitudeTowards(player.GetAttitudeAgent(), EAIAttitude.AIA_Hostile);
        StimBroadcasterComponent.SendStimDirectly(player, gamedataStimType.CombatHit, npc);
        if StrLen(this.m_lines[index]) > 0 {
            GRSpeech.Say(npc, this.m_speakers[index], this.m_lines[index], 5.0);
        }
    }

    public func StartReinforcement(nemesisId: Int32, recordID: String, appearance: String, escortRecords: String, line: String, speaker: String) -> Bool {
        if StrLen(this.GetReinforcementBlocker()) > 0 || this.IsNemesisSpawned(nemesisId) {
            return false;
        }
        this.m_raidMode = false;
        if !this.SpawnGroup(nemesisId, recordID, appearance, escortRecords, line, speaker, 20.0) {
            return false;
        }
        this.m_ambushSawCombat = true;
        GRLog("Refuerzo en gig: Nemesis #" + IntToString(nemesisId));
        return true;
    }

    private func SpawnGroup(nemesisId: Int32, recordID: String, appearance: String, escortRecords: String, line: String, speaker: String, distance: Float) -> Bool {
        // Emboscada a pie y refuerzo en gig pasan los dos por aca.
        if this.IsMachineNemesis(nemesisId, recordID, "A pie") {
            return false;
        }
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());

        // Detras de V (arco de +-60 grados), sin acercarse a menos del 70% de la distancia: no aparecen
        // delante ni encima. Si no hay sitio, la emboscada anunciada espera y reintenta.
        let angle: Float = RandRangeF(165.0, 195.0);
        let pos: Vector4 = this.FindSpot(player, angle, distance, 45.0, 0.7, false);
        if !this.m_spotFound {
            GRLog("Sin punto alcanzable detras de V: no se genera");
            return false;
        }
        if !this.SpawnAt(nemesisId, recordID, appearance, pos, this.GetFacingPlayer(player, pos), line, speaker) {
            return false;
        }

        let escorts: array<String>;
        if StrLen(escortRecords) > 0 {
            escorts = StrSplit(escortRecords, ",");
        }
        let i: Int32 = 0;
        while i < ArraySize(escorts) {
            let escortPos: Vector4 = this.EscortSpot(pos, i);
            this.SpawnAt(0, escorts[i], "", escortPos, this.GetFacingPlayer(player, escortPos), "", "");
            i += 1;
        }

        this.m_ambushActive = true;
        this.m_ambushStart = this.Now();
        this.m_ambushCalmSince = 0.0;
        this.m_stuckChecked = false;
        GRLog(IntToString(ArraySize(escorts)) + " escoltas");
        return true;
    }

    // V en Dogtown: el distrito actual o alguno de arriba se llama "Dogtown..." (Dogtown, Dogtown_Akebono,
    // Dogtown_Brooklyn...). La misma fuente que GetDistrictName y GRWar.GetCurrentDistrict.
    public func IsInDogtown() -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) || !IsDefined(player.GetPreventionSystem()) {
            return false;
        }
        let current: wref<District> = player.GetPreventionSystem().GetCurrentDistrict();
        if !IsDefined(current) {
            return false;
        }
        let district: wref<District_Record> = current.GetDistrictRecord();
        let depth: Int32 = 0;
        while IsDefined(district) && depth < 6 {
            if StrBeginsWith(district.EnumName(), "Dogtown") {
                return true;
            }
            district = district.ParentDistrict();
            depth += 1;
        }
        return false;
    }

    // Quien hace las redadas donde esta V: en Dogtown no entra la NCPD, manda Barghest. Lo lee CET para
    // elegir a quien allanan y los textos.
    public func GetRaidForce() -> String {
        return this.IsInDogtown() ? "Barghest" : "NCPD";
    }

    // Uno de los que hacen la redada (o la hicieron y se estan yendo). Lo usa GRTraits.HitSource: son
    // amistosos con V, pero sus golpes no son de V.
    public func IsRaidForce(id: EntityID) -> Bool {
        let i: Int32 = 0;
        while i < ArraySize(this.m_raidForceIDs) {
            if this.m_raidForceIDs[i] == id {
                return true;
            }
            i += 1;
        }
        return false;
    }

    // Soldados de Barghest para una redada en Dogtown: tantos como policias pidio CET (2 + rango), al
    // azar entre los mismos 12 records que usan los escoltas de Barghest (modules/escorts.lua).
    private func BarghestRaiders(policeRecords: String) -> String {
        let pool: array<String> = [
            "Character.bou_kurtz_grunt1_ranged1_handgun_ma",
            "Character.bou_kurtz_grunt1_ranged1_handgun_wa",
            "Character.bou_kurtz_grunt1_ranged1_saratoga_ma",
            "Character.bou_kurtz_grunt1_ranged1_saratoga_wa",
            "Character.high_kurtz_grunt1_ranged1_handgun_ma",
            "Character.high_kurtz_grunt1_ranged1_handgun_wa",
            "Character.high_kurtz_grunt1_ranged1_saratoga_ma",
            "Character.high_kurtz_grunt1_ranged1_saratoga_wa",
            "Character.combat_zone_gate_kurtz_grunt1_ranged1_handgun_ma",
            "Character.combat_zone_gate_kurtz_grunt1_ranged1_handgun_wa",
            "Character.combat_zone_gate_kurtz_grunt1_ranged1_saratoga_ma",
            "Character.combat_zone_gate_kurtz_grunt1_ranged1_saratoga_wa"
        ];
        let count: Int32 = 3;
        if StrLen(policeRecords) > 0 {
            let asked: array<String> = StrSplit(policeRecords, ",");
            count = ArraySize(asked);
        }
        let result: String = "";
        let i: Int32 = 0;
        while i < count {
            let pick: Int32 = Min(RandRange(0, ArraySize(pool)), ArraySize(pool) - 1);
            result += (i > 0 ? "," : "") + pool[pick];
            i += 1;
        }
        return result;
    }

    private func IsBarghestRecord(recordID: String) -> Bool {
        let record: wref<Character_Record> = TweakDBInterface.GetCharacterRecord(TDBID.Create(recordID));
        return IsDefined(record) && IsDefined(record.Affiliation()) && Equals(record.Affiliation().Type(), gamedataAffiliation.Barghest);
    }

    // policeRecords lo manda CET (policias de la NCPD). En Dogtown se ignora y vienen soldados de Barghest:
    // mismo numero, mismo bando 1 (amistosos con V, hostiles al grupo del Nemesis).
    public func StartRaid(nemesisId: Int32, recordID: String, appearance: String, escortRecords: String, speaker: String, policeRecords: String) -> Bool {
        if StrLen(this.GetAmbushBlocker()) > 0 || this.IsNemesisSpawned(nemesisId) {
            return false;
        }
        let force: String = this.GetRaidForce();
        let label: String = "Redada " + force;
        if this.IsMachineNemesis(nemesisId, recordID, label) {
            return false;
        }
        let raiders: String = policeRecords;
        if Equals(force, "Barghest") {
            // Barghest no allana a los suyos (CET ya elige a un Nemesis de otra banda).
            if this.IsBarghestRecord(recordID) {
                GRLog(label + ": Nemesis #" + IntToString(nemesisId) + " es de Barghest, no se genera");
                return false;
            }
            raiders = this.BarghestRaiders(policeRecords);
        }
        // A ~55 m (minimo ~40) y fuera de la vista de V: se oye el tiroteo y V se acerca, no aparece de la nada.
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        // Detras y a los costados primero; delante nunca (el cono de vista lo descarta igual).
        let angles: array<Float> = [180.0, 135.0, -135.0, 100.0, -100.0];
        for angle in angles {
            let posA: Vector4 = this.FindSpot(player, angle - 10.0, 55.0, 15.0, 0.75, true);
            if !this.m_spotFound {
                posA = Vector4.EmptyVector();
            }
            let posB: Vector4 = this.FindSpot(player, angle + 10.0, 55.0, 15.0, 0.75, true);
            if !this.m_spotFound {
                posB = Vector4.EmptyVector();
            }
            if !Vector4.IsZero(posA) && !Vector4.IsZero(posB) && Vector4.Distance(posA, posB) > 6.0 && this.IsConnected(posA, posB) {
                this.m_raidMode = true;
                this.m_raidHitGang = false;
                this.m_raidHitPolice = false;
                this.m_raidOutcome = "";
                this.m_raidHeat = 0;
                this.m_policeImmune = true;
                this.m_immuneRaidEnd = 0.0;
                this.m_raidPoliceOnV = false;
                ArrayClear(this.m_raidForceIDs);
                this.m_spawnSide = 0;
                let facing: Quaternion = EulerAngles.ToQuat(Vector4.ToRotation(posB - posA));
                if !this.SpawnAt(nemesisId, recordID, appearance, posA, facing, "", speaker) {
                    this.m_raidMode = false;
                    return false;
                }
                this.SpawnRaidSide(escortRecords, posA, posB);
                this.m_spawnSide = 1;
                this.SpawnRaidSide(raiders, posB, posA);
                this.m_spawnSide = 0;

                this.m_ambushActive = true;
                this.m_ambushSawCombat = true;
                this.m_ambushStart = this.Now();
                this.m_ambushCalmSince = 0.0;
                this.m_stuckChecked = false;
                GRLog(label + ": Nemesis #" + IntToString(nemesisId) + ", " + IntToString(ArraySize(this.m_entityIDs)) + " NPC ("
                    + IntToString(ArraySize(this.m_raidForceIDs)) + " de " + force + ")");
                return true;
            }
        }
        GRLog(label + ": sin sitio cerca de V");
        return false;
    }

    private func SpawnRaidSide(records: String, at: Vector4, facing: Vector4) {
        if StrLen(records) == 0 {
            return;
        }
        let list: array<String> = StrSplit(records, ",");
        let orientation: Quaternion = EulerAngles.ToQuat(Vector4.ToRotation(facing - at));
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let i: Int32 = 0;
        while i < ArraySize(list) {
            let raw: Vector4 = at + new Vector4(RandRangeF(-2.0, 2.0) + Cast<Float>(i) * 0.6, RandRangeF(-2.0, 2.0), 0.0, 0.0);
            // Cada uno se revisa como el punto central: suelo del mismo piso, sin pared encima y oculto
            // para V. Si falla, en el punto central (que ya paso esas pruebas).
            let pos: Vector4 = GameInstance.GetNavigationSystem(this.GetGameInstance()).GetNearestNavmeshPointBelowOnlyHumanNavmesh(raw + new Vector4(0.0, 0.0, 1.0, 0.0), 1.0, 5);
            if Vector4.IsZero(pos) || AbsF(pos.Z - at.Z) > 1.0 || !this.IsClearSpot(pos)
                    || (IsDefined(player) && !this.IsHiddenFromPlayer(player, pos)) {
                pos = at;
            }
            this.SpawnAt(0, list[i], "", pos, orientation, "", "");
            i += 1;
        }
    }

    public func RecordRaidHitByV(id: EntityID) {
        if !this.m_raidMode {
            return;
        }
        let index: Int32 = this.IndexOf(id);
        if index < 0 {
            return;
        }
        if this.m_sides[index] == 0 {
            this.m_raidHitGang = true;
        } else {
            this.m_raidHitPolice = true;
        }
    }

    public func TakeRaidOutcome() -> String {
        let outcome: String = this.m_raidOutcome;
        this.m_raidOutcome = "";
        return outcome;
    }

    public func GiveMoney(amount: Int32) -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) || amount <= 0 {
            return false;
        }
        return GameInstance.GetTransactionSystem(this.GetGameInstance()).GiveItem(player, MarketSystem.Money(), amount);
    }

    public func IsRaidActive() -> Bool {
        return this.m_ambushActive && this.m_raidMode;
    }

    private func SideAlive(side: Int32) -> Int32 {
        let count: Int32 = 0;
        let i: Int32 = 0;
        while i < ArraySize(this.m_entityIDs) {
            if this.m_sides[i] == side {
                let npc: ref<ScriptedPuppet> = GameInstance.FindEntityByID(this.GetGameInstance(), this.m_entityIDs[i]) as ScriptedPuppet;
                if !IsDefined(npc) || !GRDetection.IsNeutralized(npc) {
                    count += 1;
                }
            }
            i += 1;
        }
        return count;
    }

    private func KeepPoliceFriendly() {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) || !IsDefined(player.GetAttitudeAgent()) {
            return;
        }
        let onV: Bool = false;
        let i: Int32 = 0;
        while i < ArraySize(this.m_entityIDs) {
            if this.m_sides[i] == 1 {
                let cop: ref<ScriptedPuppet> = GameInstance.FindEntityByID(this.GetGameInstance(), this.m_entityIDs[i]) as ScriptedPuppet;
                if IsDefined(cop) && IsDefined(cop.GetAttitudeAgent()) && !GRDetection.IsNeutralized(cop) {
                    if NotEquals(GameObject.GetAttitudeBetween(cop, player), EAIAttitude.AIA_Friendly) {
                        onV = true;
                    }
                    cop.GetAttitudeAgent().SetAttitudeTowards(player.GetAttitudeAgent(), EAIAttitude.AIA_Friendly);
                }
            }
            i += 1;
        }
        let heat: Int32 = Cast<Int32>(player.GetPreventionSystem().GetHeatStageAsInt());
        if heat != this.m_raidHeat || NotEquals(onV, this.m_raidPoliceOnV) {
            GRLog("Redada: busqueda=" + IntToString(heat) + " policia no amistosa con V=" + ToString(onV)
                + " (V golpeo banda=" + ToString(this.m_raidHitGang) + " policia=" + ToString(this.m_raidHitPolice) + ")");
            this.m_raidHeat = heat;
            this.m_raidPoliceOnV = onV;
        }
    }

    // Como ProvokeIdle, pero entre bandos: la hostilidad de SetRaidHostility se pone al aparecer y, si la
    // IA no estaba lista o el otro bando no habia cargado, policias y pandilleros se quedaban mirando.
    // Cada 3 s (maximo 10 veces), a cada uno fuera de combate se le marca como amenaza el enemigo vivo
    // mas cercano. Desde el tick, nunca desde eventos.
    private func ProvokeRaid(now: Float) {
        if this.m_provokeAmbush != this.m_ambushStart {
            this.m_provokeAmbush = this.m_ambushStart;
            this.m_provokeCount = 0;
            this.m_provokeAt = now;
        }
        if this.m_provokeCount >= 10 || now - this.m_provokeAt < 3.0 {
            return;
        }
        this.m_provokeAt = now;
        let provoked: Int32 = 0;
        let i: Int32 = 0;
        while i < ArraySize(this.m_entityIDs) {
            let npc: ref<ScriptedPuppet> = GameInstance.FindEntityByID(this.GetGameInstance(), this.m_entityIDs[i]) as ScriptedPuppet;
            if IsDefined(npc) && IsDefined(npc.GetAttitudeAgent()) && !GRDetection.IsNeutralized(npc) && !NPCPuppet.IsInCombat(npc) {
                let nearest: ref<ScriptedPuppet>;
                let best: Float = 9999.0;
                let j: Int32 = 0;
                while j < ArraySize(this.m_entityIDs) {
                    if this.m_sides[j] != this.m_sides[i] {
                        let enemy: ref<ScriptedPuppet> = GameInstance.FindEntityByID(this.GetGameInstance(), this.m_entityIDs[j]) as ScriptedPuppet;
                        if IsDefined(enemy) && IsDefined(enemy.GetAttitudeAgent()) && !GRDetection.IsNeutralized(enemy) {
                            npc.GetAttitudeAgent().SetAttitudeTowards(enemy.GetAttitudeAgent(), EAIAttitude.AIA_Hostile);
                            enemy.GetAttitudeAgent().SetAttitudeTowards(npc.GetAttitudeAgent(), EAIAttitude.AIA_Hostile);
                            let d: Float = Vector4.Distance(npc.GetWorldPosition(), enemy.GetWorldPosition());
                            if d < best {
                                best = d;
                                nearest = enemy;
                            }
                        }
                    }
                    j += 1;
                }
                if IsDefined(nearest) {
                    TargetTrackingExtension.InjectThreat(npc, nearest);
                    StimBroadcasterComponent.SendStimDirectly(nearest, gamedataStimType.CombatHit, npc);
                    provoked += 1;
                }
            }
            i += 1;
        }
        if provoked > 0 {
            this.m_provokeCount += 1;
            GRLog("Redada: " + IntToString(provoked) + " NPC fuera de combate, provocados contra el otro bando (" + IntToString(this.m_provokeCount) + "/10)");
        }
    }

    private func TickRaid(now: Float) {
        this.KeepPoliceFriendly();
        this.ProvokeRaid(now);
        let fighting: Bool = this.SideAlive(0) > 0 && this.SideAlive(1) > 0;
        if fighting {
            this.m_ambushCalmSince = 0.0;
        } else {
            if this.m_ambushCalmSince == 0.0 {
                this.m_ambushCalmSince = now;
            }
        }
        if (!fighting && now - this.m_ambushCalmSince > 20.0) || now - this.m_ambushStart > 180.0 {
            if this.SideAlive(0) == 0 && this.m_raidHitGang {
                this.m_raidOutcome = this.m_raidHitPolice ? "helpedPoliceHurtCops" : "helpedPolice";
            }
            GRLog("Fin de redada (V gang=" + ToString(this.m_raidHitGang) + " police=" + ToString(this.m_raidHitPolice) + ")");
            this.EndEncounter("Fin de redada");
        }
    }

    public func BeginStronghold() {
        this.m_raidMode = false;
        this.m_strongholdMode = true;
        this.m_vehicleState = 0;
        this.m_ambushActive = true;
        this.m_ambushStart = this.Now();
        this.m_ambushSawCombat = false;
    }

    public func IsStrongholdActive() -> Bool {
        return this.m_ambushActive && this.m_strongholdMode;
    }

    // Puesto alrededor del centro de la guarida, ajustado al navmesh y en el mismo piso.
    public func PostSpot(center: Vector4, angle: Float, radius: Float) -> Vector4 {
        let raw: Vector4 = center + new Vector4(CosF(angle) * radius, SinF(angle) * radius, 1.0, 0.0);
        let pos: Vector4 = GameInstance.GetNavigationSystem(this.GetGameInstance()).GetNearestNavmeshPointBelowOnlyHumanNavmesh(raw, 2.0, 5);
        if Vector4.IsZero(pos) || AbsF(pos.Z - center.Z) > 3.0 || !this.IsClearSpot(pos) {
            return Vector4.EmptyVector();
        }
        if radius > 0.5 && !this.IsConnected(center, pos) {
            return Vector4.EmptyVector();
        }
        return pos;
    }

    // Mirando hacia fuera de la guarida (vigilan los accesos).
    public func SpawnPosted(nemesisId: Int32, recordID: String, appearance: String, pos: Vector4, center: Vector4, speaker: String) -> Bool {
        let out: Vector4 = pos - center;
        if Vector4.Length(out) < 0.5 {
            out = new Vector4(RandRangeF(-1.0, 1.0), RandRangeF(-1.0, 1.0), 0.0, 0.0);
        }
        out.Z = 0.0;
        return this.SpawnAt(nemesisId, recordID, appearance, pos, EulerAngles.ToQuat(Vector4.ToRotation(out)), "", speaker);
    }

    public func CountStanding() -> Int32 {
        let alive: Int32 = 0;
        let i: Int32 = 0;
        while i < ArraySize(this.m_entityIDs) {
            let npc: ref<ScriptedPuppet> = GameInstance.FindEntityByID(this.GetGameInstance(), this.m_entityIDs[i]) as ScriptedPuppet;
            if !IsDefined(npc) || !GRDetection.IsNeutralized(npc) {
                alive += 1;
            }
            i += 1;
        }
        return alive;
    }

    public func IsAmbushActive() -> Bool {
        return this.m_ambushActive;
    }

    public func IsPoliceImmune() -> Bool {
        return this.m_policeImmune;
    }

    private func IsWeaponDrawn(player: ref<PlayerPuppet>) -> Bool {
        return IsDefined(GameInstance.GetTransactionSystem(this.GetGameInstance()).GetItemInSlot(player, t"AttachmentSlots.WeaponRight"));
    }

    private func TickImmunity() {
        if !this.m_policeImmune || this.IsRaidActive() {
            return;
        }
        let now: Float = this.Now();
        if this.m_immuneRaidEnd == 0.0 {
            this.m_immuneRaidEnd = now;
        }
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) || !this.IsWeaponDrawn(player) || now - this.m_immuneRaidEnd > 60.0 {
            this.m_policeImmune = false;
            GRLog("Redada: fin de la inmunidad ante la policia");
        }
    }

    public func Tick() {
        let twr: ref<GRTWRWatch> = GRTWRWatch.Get(this.GetGameInstance());
        if IsDefined(twr) {
            twr.Tick();
        }
        this.CheckNeutralized();
        this.CheckTaunts();
        this.TickImmunity();
        this.TickBossBar();
        this.TickLeftovers();
        if !this.m_ambushActive {
            return;
        }
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) {
            return;
        }
        let now: Float = this.Now();
        if this.m_vehicleState >= 1 && this.m_vehicleState <= 3 {
            this.TickVehicle(player, now);
            return;
        }
        if this.m_strongholdMode {
            return;
        }
        if !this.m_stuckChecked && now - this.m_ambushStart > 40.0 {
            this.m_stuckChecked = true;
            if this.IsStuck() {
                this.EndEncounter("Emboscada atascada (nadie se movio ni cayo en 40 s)");
                return;
            }
        }
        if this.m_raidMode {
            this.TickRaid(now);
            return;
        }
        this.ProvokeIdle(player, now);
        if player.IsInCombat() {
            this.m_ambushSawCombat = true;
            this.m_ambushCalmSince = 0.0;
            return;
        }
        if this.m_ambushCalmSince == 0.0 {
            this.m_ambushCalmSince = now;
        }

        let calm: Float = now - this.m_ambushCalmSince;
        if (this.m_ambushSawCombat && calm > 20.0) || now - this.m_ambushStart > 180.0 {
            this.EndEncounter("Fin de emboscada");
        }
    }

    // La hostilidad se pone una vez al aparecer; si la IA del NPC no estaba lista, el estimulo se pierde y
    // queda hostil pero quieto. Cada 3 s se vuelve a provocar a los que esten cerca y fuera de combate
    // (maximo 6 veces por emboscada). Desde el tick, nunca desde eventos.
    private func ProvokeIdle(player: ref<PlayerPuppet>, now: Float) {
        if this.m_provokeAmbush != this.m_ambushStart {
            this.m_provokeAmbush = this.m_ambushStart;
            this.m_provokeCount = 0;
            this.m_provokeAt = now;
        }
        if this.m_provokeCount >= 6 || now - this.m_provokeAt < 3.0 {
            return;
        }
        this.m_provokeAt = now;
        let provoked: Int32 = 0;
        // Uno que huye o se esconde esta neutral a proposito: no es un NPC "pasivo".
        let det: ref<GRDetection> = GRDetection.Get(this.GetGameInstance());
        let i: Int32 = 0;
        while i < ArraySize(this.m_entityIDs) {
            let npc: ref<ScriptedPuppet> = GameInstance.FindEntityByID(this.GetGameInstance(), this.m_entityIDs[i]) as ScriptedPuppet;
            if IsDefined(npc) && !GRDetection.IsNeutralized(npc) && !NPCPuppet.IsInCombat(npc)
                && !(IsDefined(det) && det.IsRunningAway(this.m_entityIDs[i]))
                && Vector4.Distance(npc.GetWorldPosition(), player.GetWorldPosition()) < 60.0
                && IsDefined(npc.GetAttitudeAgent()) && IsDefined(player.GetAttitudeAgent()) {
                npc.GetAttitudeAgent().SetAttitudeTowards(player.GetAttitudeAgent(), EAIAttitude.AIA_Hostile);
                TargetTrackingExtension.InjectThreat(npc, player);
                StimBroadcasterComponent.SendStimDirectly(player, gamedataStimType.CombatHit, npc);
                provoked += 1;
            }
            i += 1;
        }
        if provoked > 0 {
            this.m_provokeCount += 1;
            GRLog("Emboscada: " + IntToString(provoked) + " NPC fuera de combate, provocados de nuevo (" + IntToString(this.m_provokeCount) + "/6)");
        }
    }

    public func SetBossBar(bar: ref<BossHealthBarGameController>) {
        this.m_bossBar = bar;
    }

    private func TickBossBar() {
        if IsDefined(this.m_bossBar) {
            this.m_bossBar.GRCleanupBossBar(GetPlayer(this.GetGameInstance()));
        }
    }

    // Atascada: ningun NPC cayo ni se alejo mas de 3 m de donde aparecio (o ni siquiera llego a cargarse).
    private func IsStuck() -> Bool {
        let i: Int32 = 0;
        while i < ArraySize(this.m_entityIDs) {
            let npc: ref<ScriptedPuppet> = GameInstance.FindEntityByID(this.GetGameInstance(), this.m_entityIDs[i]) as ScriptedPuppet;
            if IsDefined(npc) {
                if GRDetection.IsNeutralized(npc) || Vector4.Distance(npc.GetWorldPosition(), this.m_spawnPositions[i]) > 3.0 {
                    return false;
                }
            }
            i += 1;
        }
        return true;
    }

    // Boton de debug "Quitar todos": borra todo ya, incluidos los sobrantes.
    public func DespawnAll() {
        let des: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
        for id in this.m_leftIDs {
            des.DeleteEntity(id);
        }
        ArrayClear(this.m_leftIDs);
        ArrayClear(this.m_leftNemesis);
        ArrayClear(this.m_leftSince);
        ArrayClear(this.m_leftSent);
        ArrayClear(this.m_leftNames);
        des.DeleteTagged(n"GangRetaliation");
        this.ResetEncounter();
    }

    // Fin de emboscada o redada sin borrar nada delante de V: todo pasa a sobrantes (ver TickLeftovers)
    // y la emboscada queda libre para la siguiente.
    private func EndEncounter(reason: String) {
        this.CheckNeutralized();
        let i: Int32 = 0;
        while i < ArraySize(this.m_entityIDs) {
            this.AddLeftover(this.m_entityIDs[i], this.m_nemesisIDs[i], this.m_speakers[i]);
            i += 1;
        }
        if EntityID.IsDefined(this.m_vehicleID) {
            this.AddLeftover(this.m_vehicleID, 0, "");
        }
        GRLog(reason + ": " + IntToString(ArraySize(this.m_leftIDs)) + " se borran cuando V no los vea");
        this.ResetEncounter();
    }

    public func AddLeftover(id: EntityID, nemesisId: Int32, name: String) {
        if !EntityID.IsDefined(id) || this.LeftoverIndex(id) >= 0 {
            return;
        }
        ArrayPush(this.m_leftIDs, id);
        ArrayPush(this.m_leftNemesis, nemesisId);
        ArrayPush(this.m_leftSince, this.Now());
        ArrayPush(this.m_leftSent, false);
        ArrayPush(this.m_leftNames, name);
    }

    // Huida con flash (V ciega): el spawn propio desaparece ya. Primero el icono y la barra de jefe, para
    // que no queden colgados; el evento Deleted (OnEntityEvent) lo saca de las listas sin marcarlo muerto.
    public func Vanish(id: EntityID) {
        this.HideMarkers(id);
        GameInstance.GetDynamicEntitySystem().DeleteEntity(id);
    }

    // Saca el icono y la barra de jefe de un spawn propio (al empezar a huir, antes de desaparecer).
    public func HideMarkers(id: EntityID) {
        let isNemesis: Bool = false;
        let index: Int32 = this.IndexOf(id);
        if index >= 0 {
            this.RemoveMappin(index);
            isNemesis = this.m_nemesisIDs[index] > 0;
        } else {
            let left: Int32 = this.LeftoverIndex(id);
            isNemesis = left >= 0 && this.m_leftNemesis[left] > 0;
        }
        if isNemesis {
            GRNotifyBossBar(GetPlayer(this.GetGameInstance()), null, true);
        }
    }

    // Lo uso GRDetection: un sobrante que deja de pelear porque el mod lo mando a irse no "escapo".
    public func IsLeftover(id: EntityID) -> Bool {
        return this.LeftoverIndex(id) >= 0;
    }

    private func LeftoverIndex(id: EntityID) -> Int32 {
        let i: Int32 = 0;
        while i < ArraySize(this.m_leftIDs) {
            if this.m_leftIDs[i] == id {
                return i;
            }
            i += 1;
        }
        return -1;
    }

    private func RemoveLeftover(i: Int32) {
        ArrayErase(this.m_leftIDs, i);
        ArrayErase(this.m_leftNemesis, i);
        ArrayErase(this.m_leftSince, i);
        ArrayErase(this.m_leftSent, i);
        ArrayErase(this.m_leftNames, i);
    }

    // V lo tiene en pantalla: dentro de un cono de 100 grados (50 a cada lado, en horizontal) y con
    // linea de vista (HasLineOfSight, la misma que usan la huida y la busqueda de sitio).
    private func PlayerSeesPos(player: ref<PlayerPuppet>, pos: Vector4) -> Bool {
        let toPos: Vector4 = pos - player.GetWorldPosition();
        toPos.Z = 0.0;
        if Vector4.GetAngleBetween(player.GetWorldForward(), toPos) > 50.0 {
            return false;
        }
        return this.HasLineOfSight(player, pos);
    }

    // Se va caminando, neutral con V (como quien se retira despues de la pelea).
    private func SendAway(npc: ref<ScriptedPuppet>, player: ref<PlayerPuppet>) {
        let puppet: ref<NPCPuppet> = npc as NPCPuppet;
        if !IsDefined(puppet) {
            return;
        }
        if IsDefined(npc.GetAttitudeAgent()) && IsDefined(player.GetAttitudeAgent())
            && NotEquals(GameObject.GetAttitudeBetween(npc, player), EAIAttitude.AIA_Friendly) {
            npc.GetAttitudeAgent().SetAttitudeTowards(player.GetAttitudeAgent(), EAIAttitude.AIA_Neutral);
        }
        GRMoveTo(puppet, GRAwayFrom(npc, player, 60.0), moveMovementType.Walk, 2.0);
    }

    // Cada segundo. Vivos: se van y se borran fuera de la vista (a mas de 30 m, o a los 120 s), o a
    // mas de 80 m; a los 300 s se borran igual (alguien trabado a la vista). Cadaveres: solo fuera de
    // la vista (a mas de 20 m, o a los 60 s). Auto: fuera de la vista y a mas de 30 m, nunca con V adentro.
    // Si se descargan solos, se sueltan. Los que huyen los maneja GRDetection: aca solo se borran.
    private func TickLeftovers() {
        if ArraySize(this.m_leftIDs) == 0 {
            return;
        }
        let gi: GameInstance = this.GetGameInstance();
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        if !IsDefined(player) {
            return;
        }
        let det: ref<GRDetection> = GRDetection.Get(gi);
        let ridden: wref<GameObject> = GetMountedVehicle(player);
        let now: Float = this.Now();
        let i: Int32 = ArraySize(this.m_leftIDs) - 1;
        while i >= 0 {
            let id: EntityID = this.m_leftIDs[i];
            let entity: ref<GameObject> = GameInstance.FindEntityByID(gi, id) as GameObject;
            let age: Float = now - this.m_leftSince[i];
            let remove: Bool = !IsDefined(entity);
            if IsDefined(entity) {
                let distance: Float = Vector4.Distance(entity.GetWorldPosition(), player.GetWorldPosition());
                let seen: Bool = this.PlayerSeesPos(player, entity.GetWorldPosition());
                let npc: ref<ScriptedPuppet> = entity as ScriptedPuppet;
                if IsDefined(npc) {
                    if GRDetection.IsNeutralized(npc) {
                        if this.m_leftNemesis[i] > 0 {
                            this.MarkDead(id);
                        }
                        remove = !seen && (distance > 20.0 || age > 60.0);
                    } else {
                        if !this.m_leftSent[i] && !(IsDefined(det) && det.IsRunningAway(id)) {
                            this.m_leftSent[i] = true;
                            this.SendAway(npc, player);
                        }
                        remove = (!seen && (distance > 30.0 || age > 120.0)) || distance > 80.0 || age > 300.0;
                    }
                } else {
                    let inside: Bool = IsDefined(ridden) && ridden.GetEntityID() == id;
                    remove = !inside && !seen && distance > 30.0;
                }
            }
            if remove {
                if this.m_leftNemesis[i] > 0 {
                    GRNotifyBossBar(player, null, true);
                    this.TakeLastHit(this.m_leftNemesis[i]);
                }
                GameInstance.GetDynamicEntitySystem().DeleteEntity(id);
                this.RemoveLeftover(i);
            }
            i -= 1;
        }
    }

    private func ResetEncounter() {
        let i: Int32 = 0;
        while i < ArraySize(this.m_entityIDs) {
            this.RemoveMappin(i);
            i += 1;
        }
        let taunts: ref<GRTaunts> = GRTaunts.Get(this.GetGameInstance());
        if IsDefined(taunts) {
            taunts.Reset();
        }
        ArrayClear(this.m_entityIDs);
        ArrayClear(this.m_spawnPositions);
        ArrayClear(this.m_nemesisIDs);
        ArrayClear(this.m_lines);
        ArrayClear(this.m_speakers);
        ArrayClear(this.m_mappins);
        ArrayClear(this.m_hasMappin);
        ArrayClear(this.m_sides);
        this.m_ambushActive = false;
        this.m_raidMode = false;
        this.m_strongholdMode = false;
        this.m_vehicleState = 0;
        // Si no, la emboscada siguiente a pie pasaria a sobrantes el auto de una anterior.
        let none: EntityID;
        this.m_vehicleID = none;
    }

    public func GetSpawnedCount() -> Int32 {
        return ArraySize(this.m_entityIDs);
    }

    // Rango por el nombre que manda CET ("Jefe ...", "Teniente ..."; los Soldados van sin prefijo).
    private func RankOfSpeaker(speaker: String) -> Int32 {
        let loc: ref<LocalizationSystem> = LocalizationSystem.GetInstance(this.GetGameInstance());
        let bossKeys: array<String> = ["GR-RankBoss", "GR-RankBossF"];
        for key in bossKeys {
            let label: String = loc.GetText(key);
            if StrLen(label) > 0 && StrBeginsWith(speaker, label + " ") {
                return 3;
            }
        }
        let lieutenant: String = loc.GetText("GR-RankLieutenant");
        if StrLen(lieutenant) > 0 && StrBeginsWith(speaker, lieutenant + " ") {
            return 2;
        }
        return 1;
    }

    // Nemesis mas duros: vida x ajuste del rango y, si esta activado, nivel de V + extra por rango.
    // Los modificadores viven en la entidad: al borrarla se van con ella.
    private func ApplyToughness(index: Int32, npc: ref<ScriptedPuppet>) {
        let gi: GameInstance = this.GetGameInstance();
        let settings: ref<GRSettings> = GRSettings.Get(gi);
        let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(gi);
        if !IsDefined(settings) || !IsDefined(stats) {
            return;
        }
        let rank: Int32 = this.RankOfSpeaker(this.m_speakers[index]);
        let id: StatsObjectID = Cast<StatsObjectID>(npc.GetEntityID());
        let health: Float = rank == 3 ? settings.healthBoss : (rank == 2 ? settings.healthLieutenant : settings.healthSoldier);
        if health > 1.0 {
            stats.AddModifier(id, RPGManager.CreateStatModifier(gamedataStatType.Health, gameStatModifierType.Multiplier, health));
        }
        let level: String = "district";
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        if settings.levelMatchV && IsDefined(player) {
            let playerId: StatsObjectID = Cast<StatsObjectID>(player.GetEntityID());
            let extra: Float = Cast<Float>((rank - 1) * settings.levelPerRank);
            let powerLevel: Float = stats.GetStatValue(playerId, gamedataStatType.PowerLevel) + extra;
            // Igual que NPCManager.ScaleToPlayer del juego: se quita lo anterior y se pone el valor final.
            stats.RemoveAllModifiers(id, gamedataStatType.PowerLevel);
            stats.AddModifier(id, RPGManager.CreateStatModifier(gamedataStatType.PowerLevel, gameStatModifierType.Additive, powerLevel));
            stats.RemoveAllModifiers(id, gamedataStatType.Level);
            stats.AddModifier(id, RPGManager.CreateStatModifier(gamedataStatType.Level, gameStatModifierType.Additive, stats.GetStatValue(playerId, gamedataStatType.Level) + extra));
            level = FloatToStringPrec(powerLevel, 0);
        }
        GRLog("Nemesis #" + IntToString(this.m_nemesisIDs[index]) + ": rango " + IntToString(rank) + ", vida x" + FloatToStringPrec(health, 2) + ", nivel " + level);
    }

    private cb func OnEntityEvent(event: ref<DynamicEntityEvent>) {
        let index: Int32 = this.IndexOf(event.GetEntityID());
        if index < 0 {
            let left: Int32 = this.LeftoverIndex(event.GetEntityID());
            if left >= 0 && Equals(event.GetEventType(), DynamicEntityEventType.Dead) {
                this.MarkDead(event.GetEntityID());
            }
            return;
        }
        let eventType: DynamicEntityEventType = event.GetEventType();

        if Equals(eventType, DynamicEntityEventType.Spawned) {
            let npc: ref<ScriptedPuppet> = GameInstance.GetDynamicEntitySystem().GetEntity(event.GetEntityID()) as ScriptedPuppet;
            let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
            if IsDefined(npc) && this.m_nemesisIDs[index] > 0 {
                this.ApplyToughness(index, npc);
            }
            if IsDefined(npc) && IsDefined(player) && this.m_raidMode {
                this.SetRaidHostility(index, npc);
                if this.m_nemesisIDs[index] > 0 && !this.m_hasMappin[index] {
                    this.AddMappin(index, npc);
                    ArrayPush(this.m_appearanceReports, IntToString(this.m_nemesisIDs[index]) + ":" + NameToString(npc.GetCurrentAppearanceName()));
                }
            } else if IsDefined(npc) && IsDefined(player) && this.m_strongholdMode {
                // Hostiles sin estimulo: atacan cuando ven a V, asi se puede entrar en sigilo.
                npc.GetAttitudeAgent().SetAttitudeTowards(player.GetAttitudeAgent(), EAIAttitude.AIA_Hostile);
                if this.m_nemesisIDs[index] > 0 && !this.m_hasMappin[index] {
                    this.AddMappin(index, npc);
                    ArrayPush(this.m_appearanceReports, IntToString(this.m_nemesisIDs[index]) + ":" + NameToString(npc.GetCurrentAppearanceName()));
                }
            } else if IsDefined(npc) && IsDefined(player) {
                // En vehiculo se vuelven hostiles al bajarse (StartVehicleFight), no al aparecer.
                if this.m_vehicleState == 0 {
                    npc.GetAttitudeAgent().SetAttitudeTowards(player.GetAttitudeAgent(), EAIAttitude.AIA_Hostile);
                    StimBroadcasterComponent.SendStimDirectly(player, gamedataStimType.CombatHit, npc);
                    if StrLen(this.m_lines[index]) > 0 {
                        GRSpeech.Say(npc, this.m_speakers[index], this.m_lines[index], 5.0);
                    }
                }
                if this.m_nemesisIDs[index] > 0 && !this.m_hasMappin[index] {
                    this.AddMappin(index, npc);
                    ArrayPush(this.m_appearanceReports, IntToString(this.m_nemesisIDs[index]) + ":" + NameToString(npc.GetCurrentAppearanceName()));
                    if GRIsBossBarNemesis(npc as NPCPuppet) {
                        GRNotifyBossBar(player, npc, false);
                    }
                }
            }
        }

        if Equals(eventType, DynamicEntityEventType.Dead) {
            this.MarkDead(event.GetEntityID());
        }

        if Equals(eventType, DynamicEntityEventType.Deleted) {
            if this.m_nemesisIDs[index] > 0 {
                GRNotifyBossBar(GetPlayer(this.GetGameInstance()), null, true);
                this.TakeLastHit(this.m_nemesisIDs[index]);
            }
            this.RemoveMappin(index);
            ArrayErase(this.m_entityIDs, index);
            ArrayErase(this.m_spawnPositions, index);
            ArrayErase(this.m_nemesisIDs, index);
            ArrayErase(this.m_lines, index);
            ArrayErase(this.m_speakers, index);
            ArrayErase(this.m_mappins, index);
            ArrayErase(this.m_hasMappin, index);
            ArrayErase(this.m_sides, index);
        }
    }

    private func SetRaidHostility(index: Int32, npc: ref<ScriptedPuppet>) {
        if !IsDefined(npc.GetAttitudeAgent()) {
            return;
        }
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if IsDefined(player) && IsDefined(player.GetAttitudeAgent()) {
            npc.GetAttitudeAgent().SetAttitudeTowards(player.GetAttitudeAgent(),
                this.m_sides[index] == 0 ? EAIAttitude.AIA_Hostile : EAIAttitude.AIA_Friendly);
        }
        let i: Int32 = 0;
        while i < ArraySize(this.m_entityIDs) {
            if this.m_sides[i] != this.m_sides[index] {
                let enemy: ref<ScriptedPuppet> = GameInstance.GetDynamicEntitySystem().GetEntity(this.m_entityIDs[i]) as ScriptedPuppet;
                if IsDefined(enemy) && IsDefined(enemy.GetAttitudeAgent()) {
                    npc.GetAttitudeAgent().SetAttitudeTowards(enemy.GetAttitudeAgent(), EAIAttitude.AIA_Hostile);
                    enemy.GetAttitudeAgent().SetAttitudeTowards(npc.GetAttitudeAgent(), EAIAttitude.AIA_Hostile);
                    StimBroadcasterComponent.SendStimDirectly(enemy, gamedataStimType.CombatHit, npc);
                    StimBroadcasterComponent.SendStimDirectly(npc, gamedataStimType.CombatHit, enemy);
                }
            }
            i += 1;
        }
    }

    public func GetDeathCount() -> Int32 {
        return ArraySize(this.m_deaths);
    }

    public func GetDeath(index: Int32) -> Int32 {
        return this.m_deaths[index];
    }

    public func GetDeathKind(index: Int32) -> String {
        return index < ArraySize(this.m_deathKinds) ? this.m_deathKinds[index] : "normal";
    }

    public func GetDeathCause(index: Int32) -> String {
        return index < ArraySize(this.m_deathCauses) ? this.m_deathCauses[index] : "v";
    }

    public func ClearDeaths() {
        ArrayClear(this.m_deaths);
        ArrayClear(this.m_deathKinds);
        ArrayClear(this.m_deathCauses);
    }

    public func GetAppearanceReportCount() -> Int32 {
        return ArraySize(this.m_appearanceReports);
    }

    public func GetAppearanceReport(index: Int32) -> String {
        return this.m_appearanceReports[index];
    }

    public func ClearAppearanceReports() {
        ArrayClear(this.m_appearanceReports);
    }
}

// El juego ya anota si V dano el vehiculo (lo usa para la reaccion de la policia a la explosion).
@addMethod(VehicleObject)
public func GRHitByPlayer() -> Bool {
    return this.m_hitByPlayer;
}

@wrapMethod(NPCPuppet)
protected func CompileScannerChunks() -> Bool {
    let result: Bool = wrappedMethod();
    let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGame());
    if IsDefined(spawner) {
        let name: String = spawner.GetNemesisName(this.GetEntityID());
        if StrLen(name) > 0 {
            let nameChunk: ref<ScannerName> = new ScannerName();
            nameChunk.Set(name);
            let scanner: ref<IBlackboard> = GameInstance.GetBlackboardSystem(this.GetGame()).Get(GetAllBlackboardDefs().UI_ScannerModules);
            scanner.SetVariant(GetAllBlackboardDefs().UI_ScannerModules.ScannerName, ToVariant(nameChunk), true);
        }
    }
    return result;
}
