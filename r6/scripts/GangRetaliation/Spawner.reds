module GangRetaliation

import Codeware.Localization.*

public class GRSpawner extends ScriptableSystem {
    private let m_entityIDs: array<EntityID>;

    private let m_nemesisIDs: array<Int32>;

    private let m_headRemovedIds: array<EntityID>;

    private let m_lines: array<String>;

    private let m_speakers: array<String>;

    private let m_mappins: array<NewMappinID>;
    private let m_hasMappin: array<Bool>;

    private let m_sides: array<Int32>;
    private let m_spawnSide: Int32;
    private let m_raidMode: Bool;
    private let m_strongholdMode: Bool;
    private let m_raidHitGang: Bool;
    private let m_raidHitPolice: Bool;
    private let m_raidOutcome: String;
    private let m_raidHeat: Int32;
    private let m_policeImmune: Bool;
    private let m_immuneRaidEnd: Float;
    private let m_raidPoliceOnV: Bool;
    private let m_raidForceIDs: array<EntityID>;
    private let m_godModeLogs: Int32;

    private let m_deaths: array<Int32>;
    private let m_deathKinds: array<String>;
    private let m_deathEntityIDs: array<EntityID>;
    private let m_deathSince: array<Float>;

    // Keeps a Nemesis's scanner name attached to their corpse's EntityID after MarkDead()
    // zeroes the m_nemesisIDs/m_leftNemesis slot that GetNemesisName() would otherwise read.
    private let m_deadNameIDs: array<EntityID>;
    private let m_deadNameValues: array<String>;

    private let m_finisherIds: array<Int32>;

    private let m_lastHitIds: array<Int32>;
    private let m_lastHitBy: array<String>;
    private let m_deathCauses: array<String>;

    private let m_appearanceReports: array<String>;

    private let m_ambushActive: Bool;
    private let m_ambushStart: Float;
    private let m_ambushSawCombat: Bool;
    private let m_ambushCalmSince: Float;

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

    private let m_vehicleID: EntityID;
    private let m_vehicleState: Int32;
    private let m_vehicleStateTime: Float;

    private let m_spotFound: Bool;
    private let m_spotFails: array<Int32>;
    private let m_trafficFails: array<Int32>;

    private let m_leftIDs: array<EntityID>;
    private let m_leftNemesis: array<Int32>;
    private let m_leftSince: array<Float>;
    private let m_leftSent: array<Bool>;
    private let m_leftUnseen: array<Float>;
    private let m_leftNames: array<String>;

    private let m_machineLoggedId: Int32;
    private let m_machineLoggedAt: Float;

    private let m_watch: array<ref<GRGuardWatch>>;
    private let m_wakeCounts: array<Int32>;
    private let m_wakeLogs: Int32;

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
        let left: Int32 = this.LeftoverIndex(id);
        return left >= 0 ? this.m_leftNemesis[left] : 0;
    }

    public func GetNemesisRank(id: EntityID) -> Int32 {
        let index: Int32 = this.IndexOf(id);
        if index >= 0 && index < ArraySize(this.m_speakers) {
            return this.RankOfSpeaker(this.m_speakers[index]);
        }
        let left: Int32 = this.LeftoverIndex(id);
        if left >= 0 && left < ArraySize(this.m_leftNames) {
            return this.RankOfSpeaker(this.m_leftNames[left]);
        }
        return 0;
    }

    public func GetNemesisLabel(id: EntityID) -> String {
        let index: Int32 = this.IndexOf(id);
        if index >= 0 && index < ArraySize(this.m_speakers) {
            return this.m_speakers[index];
        }
        let left: Int32 = this.LeftoverIndex(id);
        if left >= 0 && left < ArraySize(this.m_leftNames) {
            return this.m_leftNames[left];
        }
        return "";
    }

    public func IsNemesisSpawned(nemesisId: Int32) -> Bool {
        if nemesisId <= 0 {
            return false;
        }
        return ArrayContains(this.m_nemesisIDs, nemesisId) || ArrayContains(this.m_leftNemesis, nemesisId);
    }

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

    public func IsClearSpot(pos: Vector4) -> Bool {
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

    private func IsOpenSky(pos: Vector4) -> Bool {
        let result: TraceResult;
        return !GameInstance.GetSpatialQueriesSystem(this.GetGameInstance()).SyncRaycastByCollisionGroup(pos + new Vector4(0.0, 0.0, 2.0, 0.0), pos + new Vector4(0.0, 0.0, 40.0, 0.0), n"Static", result, true, false);
    }

    private func IsConnected(from: Vector4, to: Vector4) -> Bool {
        let path: ref<NavigationPath> = GameInstance.GetNavigationSystem(this.GetGameInstance()).CalculatePathOnlyHumanNavmesh(from, to, NavGenAgentSize.Human, 1.0);
        if !IsDefined(path) || ArraySize(path.path) < 2 {
            return false;
        }
        let last: Vector4 = path.path[ArraySize(path.path) - 1];
        return Vector4.Distance(last, to) < 3.0 && path.CalculateLength() < Vector4.Distance(from, to) * 2.0 + 10.0;
    }

    public func HasLineOfSight(player: ref<PlayerPuppet>, pos: Vector4) -> Bool {
        let result: TraceResult;
        let eyes: Vector4 = player.GetWorldPosition() + new Vector4(0.0, 0.0, 1.7, 0.0);
        return !GameInstance.GetSpatialQueriesSystem(this.GetGameInstance()).SyncRaycastByCollisionGroup(eyes, pos + new Vector4(0.0, 0.0, 1.5, 0.0), n"Static", result, true, false);
    }

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
            let own: Bool = vehicle.GetEntityID() == this.m_vehicleID || (EntityID.IsDefined(playerVehicleID) && vehicle.GetEntityID() == playerVehicleID);
            if !inBand || own || AbsF(pos.Z - playerPos.Z) > 6.0 {
                this.m_trafficFails[1] += 1;
            } else {
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
            if this.m_nemesisIDs[index] > 0 {
                return this.m_speakers[index];
            }
            return this.GetDeadName(id);
        }
        let left: Int32 = this.LeftoverIndex(id);
        if left >= 0 {
            if this.m_leftNemesis[left] > 0 {
                return this.m_leftNames[left];
            }
            return this.GetDeadName(id);
        }
        return this.GetDeadName(id);
    }

    private func RememberDeadName(id: EntityID, name: String) {
        if StrLen(name) == 0 {
            return;
        }
        let i: Int32 = 0;
        while i < ArraySize(this.m_deadNameIDs) {
            if this.m_deadNameIDs[i] == id {
                this.m_deadNameValues[i] = name;
                return;
            }
            i += 1;
        }
        ArrayPush(this.m_deadNameIDs, id);
        ArrayPush(this.m_deadNameValues, name);
    }

    private func GetDeadName(id: EntityID) -> String {
        let i: Int32 = 0;
        while i < ArraySize(this.m_deadNameIDs) {
            if this.m_deadNameIDs[i] == id {
                return this.m_deadNameValues[i];
            }
            i += 1;
        }
        return "";
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
                this.GiveDownShard(id, this.m_nemesisIDs[index]);
                this.RecordDeath(this.m_nemesisIDs[index], npc, id);
                this.m_nemesisIDs[index] = 0;
            }
            return;
        }
        let left: Int32 = this.LeftoverIndex(id);
        if left >= 0 && this.m_leftNemesis[left] > 0 {
            this.GiveDownShard(id, this.m_leftNemesis[left]);
            this.RecordDeath(this.m_leftNemesis[left], npc, id);
            this.m_leftNemesis[left] = 0;
        }
    }

    private func GiveDownShard(id: EntityID, nemesisId: Int32) {
        let intel: ref<GRIntelSystem> = GRIntelSystem.Get(this.GetGameInstance());
        if IsDefined(intel) {
            intel.OnNemesisDown(id, nemesisId, Max(1, this.GetNemesisRank(id)));
        }
    }

    private func RecordDeath(nemesisId: Int32, npc: ref<ScriptedPuppet>, id: EntityID) {
        let headRemoved: Bool = ArrayContains(this.m_headRemovedIds, id);
        let kind: String = this.DeathKind(nemesisId, npc);
        ArrayPush(this.m_deaths, nemesisId);
        ArrayPush(this.m_deathEntityIDs, id);
        ArrayPush(this.m_deathSince, this.Now());
        let cause: String = this.TakeLastHit(nemesisId);
        if NotEquals(cause, "v") && this.KilledByPlayer(npc as NPCPuppet) {
            GRLog("Nemesis #" + IntToString(nemesisId) + ": muerte indirecta (" + cause + "), atribuida a V");
            cause = "v";
        }
        if Equals(kind, "confirmed") && NotEquals(cause, "v") && !headRemoved {
            kind = "normal";
        }
        if headRemoved {
            kind = "confirmed";
        }
        ArrayPush(this.m_deathKinds, kind);
        ArrayPush(this.m_deathCauses, cause);
        ArrayRemove(this.m_finisherIds, nemesisId);
        ArrayRemove(this.m_headRemovedIds, id);
        GRLog("Nemesis #" + IntToString(nemesisId) + " muerto (" + kind + ", " + cause + ", decapitado=" + (headRemoved ? "si" : "no") + ")");
    }

    public func MarkHeadRemoved(id: EntityID) {
        let pendingIndex: Int32 = ArraySize(this.m_deathEntityIDs) - 1;
        while pendingIndex >= 0 {
            if Equals(this.m_deathEntityIDs[pendingIndex], id) {
                if NotEquals(this.m_deathKinds[pendingIndex], "confirmed") {
                    this.m_deathKinds[pendingIndex] = "confirmed";
                    GRLog("Nemesis #" + IntToString(this.m_deaths[pendingIndex]) + ": decapitacion llegada tras la muerte, actualizada a confirmada (no vuelve)");
                }
                return;
            }
            pendingIndex -= 1;
        }
        if !ArrayContains(this.m_headRemovedIds, id) {
            ArrayPush(this.m_headRemovedIds, id);
            GRLog("Decapitacion registrada (entidad en espera de muerte confirmada)");
        }
    }

    // Public wrapper for GRDetection.OnNPCDeath (Detection.reds): it already resolves a ScriptedPuppet from
    // the dying entity's ID, and needs this same broader V-attribution check (vehicle rams, ForceKill,
    // grapple, not just a direct hit) to decide whether a kill - not just a knockout - rolls for an intel
    // shard, 2026-11-19.
    public func WasKilledByPlayer(npc: ref<ScriptedPuppet>) -> Bool {
        return this.KilledByPlayer(npc as NPCPuppet);
    }

    private func KilledByPlayer(npc: ref<NPCPuppet>) -> Bool {
        if !IsDefined(npc) {
            return false;
        }
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
                } else {
                    if IsDefined(npc) {
                        this.StripGodMode(i, npc, false);
                    }
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

    public func IsPlayerSwimming() -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) {
            return false;
        }
        let swimming: Int32 = player.GetPlayerStateMachineBlackboard().GetInt(GetAllBlackboardDefs().PlayerStateMachine.Swimming);
        return swimming != EnumInt(gamePSMSwimming.Default);
    }

    public func IsQuestObjectiveNearby() -> Bool {
        let distance: Float = this.GetTrackedObjectiveDistance();
        return distance >= 0.0 && distance < 150.0;
    }

    public func GetExternalSquad() -> String {
        return GRIntegrations.GetExternalSquad(this.GetGameInstance());
    }

    public func GetHeatFactor() -> Float {
        return GRIntegrations.GetHeatFactor(this.GetGameInstance(), this.GetDistrictGangs());
    }

    public func DebugDD(action: Int32) -> String {
        switch action {
            case 0: return GRIntegrations.DebugCaptureRandomTurf();
            case 1: return GRIntegrations.DebugContestCurrentTurf();
            case 2: return GRIntegrations.DebugAddTerror();
            case 3: return GRIntegrations.DebugSurrenderAllTurfs();
            default: return "";
        }
    }

    public func DebugTWR(action: Int32) -> String {
        let watch: ref<GRTWRWatch> = GRTWRWatch.Get(this.GetGameInstance());
        return IsDefined(watch) ? watch.Debug(action) : "TWR watch not ready";
    }

    public func GetDDDebugInfo() -> String {
        let settings: ref<GRSettings> = GRSettings.Get(this.GetGameInstance());
        return GRIntegrations.GetDDDebugInfo(IsDefined(settings) ? settings.fleeHealthPercent : 35);
    }

    public static func IsTWRSquadActive() -> Bool {
        let des: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
        if !IsDefined(des) {
            return false;
        }
        let squad: array<ref<Entity>> = des.GetTagged(n"TheyWillRemember.Squad");
        for member in squad {
            let npc: ref<ScriptedPuppet> = member as ScriptedPuppet;
            if IsDefined(npc) && !GRDetection.IsNeutralized(npc) {
                return true;
            }
        }
        return false;
    }

    public func IsInScene() -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) {
            return false;
        }
        let tier: Int32 = player.GetPlayerStateMachineBlackboard().GetInt(GetAllBlackboardDefs().PlayerStateMachine.HighLevel);
        return tier >= 2 && tier <= 5;
    }

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
        // El encargo propio del Bounty Board (GigZone.reds, StreetStory gr_bounty_1) no cuenta como "objetivo de mision": su pin esta en el centro
        // de la zona de caza y bloqueaba al Nemesis (y las emboscadas) mientras V estuviera a menos de 150 m.
        if GRGigZone.IsGigObjective(gi, objective) {
            this.m_objectiveSource = "own gig (ignored)";
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

    public func GetTrackedObjectiveInfo() -> String {
        let quest: wref<JournalQuest> = this.GetTrackedQuest();
        let questType: String = IsDefined(quest) ? EnumValueToString("gameJournalQuestType", Cast<Int64>(EnumInt(quest.GetType()))) : "-";
        let distance: Float = this.GetTrackedObjectiveDistance();
        let where: String = distance < 0.0 ? "no pin" : IntToString(Cast<Int32>(distance)) + " m";
        return "objective: " + questType + ", " + where + " (" + IntToString(this.m_objectivePins) + " pins, " + this.m_objectiveSource + ")";
    }

    public func IsStoryQuestNearby() -> Bool {
        if !this.IsStoryQuestTracked() {
            return false;
        }
        let distance: Float = this.GetTrackedObjectiveDistance();
        return distance >= 0.0 && distance < 150.0;
    }

    public func IsStoryQuestTracked() -> Bool {
        let quest: wref<JournalQuest> = this.GetTrackedQuest();
        if !IsDefined(quest) {
            return false;
        }
        if GRGigZone.IsGigQuest(this.GetGameInstance(), quest) {
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
        if this.FindTrafficSpot(player, pos, orientation) {
            GRLog("Vehiculo: junto a un auto del trafico a " + FloatToString(Vector4.Distance(pos, player.GetWorldPosition())) + " m");
        } else {
            GRLog("Vehiculo: sin auto del trafico util (cargados=" + IntToString(this.m_trafficFails[0])
                + ", fuera de rango=" + IntToString(this.m_trafficFails[1]) + ", sin camino=" + IntToString(this.m_trafficFails[2])
                + ", sin hueco=" + IntToString(this.m_trafficFails[3]) + ", a la vista=" + IntToString(this.m_trafficFails[4]) + ")");
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
                    drive.maxSpeed = 40.0;
                    drive.minSpeed = 10.0;
                    drive.clearTrafficOnPath = true;
                    drive.driveDownTheRoadIndefinitely = false;
                    drive.needDriver = true;
                    let evt: ref<AICommandEvent> = new AICommandEvent();
                    evt.command = drive;
                    vehicle.QueueEvent(evt);
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
        if this.IsMachineNemesis(nemesisId, recordID, "A pie") {
            return false;
        }
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());

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

    public func GetRaidForce() -> String {
        return this.IsInDogtown() ? "Barghest" : "NCPD";
    }

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
            if this.IsBarghestRecord(recordID) {
                GRLog(label + ": Nemesis #" + IntToString(nemesisId) + " es de Barghest, no se genera");
                return false;
            }
            raiders = this.BarghestRaiders(policeRecords);
        }
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
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
        ArrayClear(this.m_watch);
        this.m_wakeLogs = 0;
    }

    public func IsStrongholdActive() -> Bool {
        return this.m_ambushActive && this.m_strongholdMode;
    }

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

    public func SpawnPosted(nemesisId: Int32, recordID: String, appearance: String, pos: Vector4, center: Vector4, speaker: String) -> Bool {
        let out: Vector4 = pos - center;
        if Vector4.Length(out) < 0.5 {
            out = new Vector4(RandRangeF(-1.0, 1.0), RandRangeF(-1.0, 1.0), 0.0, 0.0);
        }
        out.Z = 0.0;
        return this.SpawnAt(nemesisId, recordID, appearance, pos, EulerAngles.ToQuat(Vector4.ToRotation(out)), "", speaker);
    }

    public func GroundBelow(pos: Vector4, out groundZ: Float) -> Bool {
        let spatial: ref<SpatialQueriesSystem> = GameInstance.GetSpatialQueriesSystem(this.GetGameInstance());
        let from: Vector4 = pos + new Vector4(0.0, 0.0, 1.0, 0.0);
        let to: Vector4 = pos + new Vector4(0.0, 0.0, -3.0, 0.0);
        let found: Bool = false;
        let best: Float = 0.0;
        let hitStatic: TraceResult;
        if spatial.SyncRaycastByCollisionGroup(from, to, n"Static", hitStatic, true, false) && this.IsGroundHit(hitStatic.position.Z, from.Z, to.Z) {
            best = hitStatic.position.Z;
            found = true;
        }
        let hitTerrain: TraceResult;
        if spatial.SyncRaycastByCollisionGroup(from, to, n"Terrain", hitTerrain, true, false) && this.IsGroundHit(hitTerrain.position.Z, from.Z, to.Z)
            && (!found || hitTerrain.position.Z > best) {
            best = hitTerrain.position.Z;
            found = true;
        }
        let hitWorld: TraceResult;
        spatial.SyncRaycastByCollisionPreset(from, to, n"World Static", hitWorld);
        if TraceResult.IsValid(hitWorld) && this.IsGroundHit(hitWorld.position.Z, from.Z, to.Z) && (!found || hitWorld.position.Z > best) {
            best = hitWorld.position.Z;
            found = true;
        }
        if found {
            groundZ = best;
        }
        return found;
    }

    private func IsGroundHit(z: Float, top: Float, bottom: Float) -> Bool {
        return z <= top + 0.1 && z >= bottom - 0.1;
    }

    public func IsPostSeen(player: ref<PlayerPuppet>, pos: Vector4) -> Bool {
        let toPos: Vector4 = pos - player.GetWorldPosition();
        toPos.Z = 0.0;
        if Vector4.GetAngleBetween(player.GetWorldForward(), toPos) > 60.0 {
            return false;
        }
        return this.HasLineOfSight(player, pos);
    }

    private func WatchOf(id: EntityID) -> ref<GRGuardWatch> {
        for watch in this.m_watch {
            if watch.id == id {
                return watch;
            }
        }
        let created: ref<GRGuardWatch> = new GRGuardWatch();
        created.id = id;
        ArrayPush(this.m_watch, created);
        return created;
    }

    private func GuardLabel(index: Int32, npc: ref<ScriptedPuppet>) -> String {
        if this.m_nemesisIDs[index] > 0 {
            return "Nemesis #" + IntToString(this.m_nemesisIDs[index]) + " (" + this.m_speakers[index] + ")";
        }
        return "guardia [" + IntToString(index) + "] " + TDBID.ToStringDEBUG(npc.GetRecordID());
    }

    private func AIStateName(state: gamedataNPCHighLevelState) -> String {
        if Equals(state, gamedataNPCHighLevelState.Relaxed) { return "relajado"; }
        if Equals(state, gamedataNPCHighLevelState.Alerted) { return "alerta"; }
        if Equals(state, gamedataNPCHighLevelState.Combat) { return "combate"; }
        if Equals(state, gamedataNPCHighLevelState.Stealth) { return "sigilo"; }
        if Equals(state, gamedataNPCHighLevelState.Fear) { return "miedo"; }
        if Equals(state, gamedataNPCHighLevelState.Unconscious) { return "inconsciente"; }
        if Equals(state, gamedataNPCHighLevelState.Dead) { return "muerto"; }
        return "otro(" + IntToString(EnumInt(state)) + ")";
    }

    private func AttitudeName(attitude: EAIAttitude) -> String {
        if Equals(attitude, EAIAttitude.AIA_Hostile) { return "hostil"; }
        if Equals(attitude, EAIAttitude.AIA_Friendly) { return "AMIGO"; }
        return "NEUTRAL";
    }

    private func GuardStatus(npc: ref<ScriptedPuppet>, player: ref<PlayerPuppet>, settled: Bool) -> String {
        let pos: Vector4 = npc.GetWorldPosition();
        let groundZ: Float = 0.0;
        let text: String = "Z=" + FloatToStringPrec(pos.Z, 2);
        if this.GroundBelow(pos, groundZ) {
            text += " suelo=" + FloatToStringPrec(groundZ, 2) + " dif=" + FloatToStringPrec(pos.Z - groundZ, 2);
        } else {
            text += " suelo=SIN COLISION (3 m)";
        }
        text += " | estado=" + this.AIStateName(npc.GetHighLevelStateFromBlackboard()) + " combate=" + ToString(NPCPuppet.IsInCombat(npc))
            + " actitud=" + this.AttitudeName(GameObject.GetAttitudeBetween(npc, player));
        let senses: ref<SenseComponent> = npc.GetSensesComponent();
        if IsDefined(senses) {
            text += " | sensor=" + (senses.IsEnabled() ? "on" : "OFF");
            if settled {
                text += " detectaV=" + (senses.GetShouldStartDetectingPlayerCached() ? "si" : "NO");
            }
        } else {
            text += " | sensor=NO HAY";
        }
        let tracker: ref<TargetTrackerComponent> = npc.GetTargetTrackerComponent();
        text += " rastreador=" + (IsDefined(tracker) ? (tracker.IsEnabled() ? "on" : "OFF") : "NO HAY");
        if settled {
            text += " agresivo=" + ToString(npc.IsAggressive()) + " activo=" + ToString(npc.IsActive());
        }
        let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
        if IsDefined(ai) {
            text += " | LOD=" + IntToString(ai.GetLOD()) + " ticksIA=" + IntToString(Cast<Int32>(ai.GetUpdateTickCount()));
        } else {
            text += " | IA=NO HAY";
        }
        return text;
    }

    private func KeepSensesAwake(npc: ref<ScriptedPuppet>, player: ref<PlayerPuppet>) -> Bool {
        if ArraySize(this.m_wakeCounts) < 4 {
            this.m_wakeCounts = [0, 0, 0, 0];
        }
        let senses: ref<SenseComponent> = npc.GetSensesComponent();
        if !IsDefined(senses) {
            return false;
        }
        let blind: Bool = false;
        if !senses.IsEnabled() {
            senses.IgnoreLODChange(true);
            senses.Toggle(true);
            this.m_wakeCounts[0] += 1;
            blind = true;
        }
        let tracker: ref<TargetTrackerComponent> = npc.GetTargetTrackerComponent();
        if IsDefined(tracker) && !tracker.IsEnabled() {
            tracker.Toggle(true);
            this.m_wakeCounts[1] += 1;
        }
        if IsDefined(npc.GetAttitudeAgent()) && IsDefined(player.GetAttitudeAgent())
            && NotEquals(GameObject.GetAttitudeBetween(npc, player), EAIAttitude.AIA_Hostile) {
            npc.GetAttitudeAgent().SetAttitudeTowards(player.GetAttitudeAgent(), EAIAttitude.AIA_Hostile);
            this.m_wakeCounts[2] += 1;
            blind = true;
        }
        if !senses.GetShouldStartDetectingPlayerCached() {
            SenseComponent.RequestDetectionOverwriteReevaluation(npc, player);
            this.m_wakeCounts[3] += 1;
            blind = true;
        }
        return blind;
    }

    private func ScriptSight(npc: ref<ScriptedPuppet>, player: ref<PlayerPuppet>, distance: Float) -> Bool {
        let crouched: Bool = player.GetPlayerStateMachineBlackboard().GetInt(GetAllBlackboardDefs().PlayerStateMachine.Locomotion) == EnumInt(gamePSMLocomotionStates.Crouch);
        if distance > (crouched ? 5.0 : 12.0) {
            return false;
        }
        if ScriptedPuppet.IsBlinded(npc) || StatusEffectSystem.ObjectHasStatusEffectOfType(player, gamedataStatusEffectType.Cloaked) {
            return false;
        }
        if !IsDefined(npc.GetAttitudeAgent()) || !IsDefined(player.GetAttitudeAgent()) {
            return false;
        }
        let toPlayer: Vector4 = player.GetWorldPosition() - npc.GetWorldPosition();
        toPlayer.Z = 0.0;
        if Vector4.GetAngleBetween(npc.GetWorldForward(), toPlayer) > 60.0 || !this.HasLineOfSight(player, npc.GetWorldPosition()) {
            return false;
        }
        npc.GetAttitudeAgent().SetAttitudeTowards(player.GetAttitudeAgent(), EAIAttitude.AIA_Hostile);
        TargetTrackingExtension.InjectThreat(npc, player);
        StimBroadcasterComponent.SendStimDirectly(player, gamedataStimType.CombatHit, npc);
        return true;
    }

    private func TickGuards(player: ref<PlayerPuppet>) {
        let gi: GameInstance = this.GetGameInstance();
        let det: ref<GRDetection> = GRDetection.Get(gi);
        let playerPos: Vector4 = player.GetWorldPosition();
        this.m_wakeCounts = [0, 0, 0, 0];
        let i: Int32 = 0;
        while i < ArraySize(this.m_entityIDs) {
            let id: EntityID = this.m_entityIDs[i];
            let npc: ref<ScriptedPuppet> = GameInstance.FindEntityByID(gi, id) as ScriptedPuppet;
            if IsDefined(npc) && !GRDetection.IsNeutralized(npc) && !(IsDefined(det) && det.IsRunningAway(id)) {
                let distance: Float = Vector4.Distance(npc.GetWorldPosition(), playerPos);
                let watch: ref<GRGuardWatch> = this.WatchOf(id);
                let inCombat: Bool = NPCPuppet.IsInCombat(npc);
                if distance < 90.0 && !inCombat {
                    if this.KeepSensesAwake(npc, player) {
                        watch.blindTicks += 1;
                    } else {
                        watch.blindTicks = 0;
                    }
                    if watch.blindTicks >= 3 && watch.scriptSights < 3 && this.ScriptSight(npc, player, distance) {
                        watch.scriptSights += 1;
                        GRLog("Guarida: " + this.GuardLabel(i, npc) + " lleva " + IntToString(watch.blindTicks) + " s sin deteccion del motor: ve a V por script a "
                            + FloatToStringPrec(distance, 1) + " m (" + IntToString(watch.scriptSights) + "/3)");
                    }
                }
                if !watch.nearLogged {
                    if distance < 40.0 {
                        this.LogGuardNear(watch, i, npc, player, distance, inCombat);
                    }
                } else if !watch.rechecked {
                    this.RecheckGuard(watch, i, npc, player);
                }
            }
            i += 1;
        }
        let touched: Int32 = this.m_wakeCounts[0] + this.m_wakeCounts[1] + this.m_wakeCounts[2] + this.m_wakeCounts[3];
        if touched > 0 && this.m_wakeLogs < 10 {
            this.m_wakeLogs += 1;
            GRLog("Guarida: percepcion revisada (" + IntToString(this.m_wakeLogs) + "/10): sensor apagado " + IntToString(this.m_wakeCounts[0])
                + ", rastreador apagado " + IntToString(this.m_wakeCounts[1]) + ", no hostil " + IntToString(this.m_wakeCounts[2])
                + ", motor sin detectar a V " + IntToString(this.m_wakeCounts[3]));
        }
    }

    private func LogGuardNear(watch: ref<GRGuardWatch>, index: Int32, npc: ref<ScriptedPuppet>, player: ref<PlayerPuppet>, distance: Float, inCombat: Bool) {
        let label: String = this.GuardLabel(index, npc);
        watch.nearLogged = true;
        let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
        watch.nearTicks = IsDefined(ai) ? Cast<Int32>(ai.GetUpdateTickCount()) : 0;
        GRLog("Guarida: " + label + " con V a " + FloatToStringPrec(distance, 0) + " m | " + this.GuardStatus(npc, player, true));
        let pos: Vector4 = npc.GetWorldPosition();
        let groundZ: Float = 0.0;
        if !inCombat && this.GroundBelow(pos, groundZ) && pos.Z - groundZ > 0.5 {
            watch.moved = true;
            GameInstance.GetTeleportationFacility(this.GetGameInstance()).Teleport(npc, new Vector4(pos.X, pos.Y, groundZ, 1.0), Quaternion.ToEulerAngles(npc.GetWorldOrientation()));
            GRLog("Guarida: " + label + " FLOTANDO a " + FloatToStringPrec(pos.Z - groundZ, 2) + " m del suelo: se lo baja");
        }
    }

    private func RecheckGuard(watch: ref<GRGuardWatch>, index: Int32, npc: ref<ScriptedPuppet>, player: ref<PlayerPuppet>) {
        watch.rechecked = true;
        let ai: ref<AIHumanComponent> = npc.GetAIControllerComponent();
        let frozen: Bool = IsDefined(ai) && Cast<Int32>(ai.GetUpdateTickCount()) == watch.nearTicks;
        if frozen {
            ai.ForceTickNextFrame();
        }
        if frozen || watch.moved {
            GRLog("Guarida: " + this.GuardLabel(index, npc) + " un tick despues" + (frozen ? " | IA SIN AVANZAR (ticksIA igual): se fuerza un tick" : "")
                + (watch.moved ? " | tras bajarlo" : "") + " | " + this.GuardStatus(npc, player, true));
        }
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
        let bounties: ref<GRBounties> = GRBounties.Get(this.GetGameInstance());
        if IsDefined(bounties) {
            bounties.Tick();
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
            this.TickGuards(player);
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

    public func DespawnAll() {
        let des: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
        for id in this.m_leftIDs {
            des.DeleteEntity(id);
        }
        ArrayClear(this.m_leftIDs);
        ArrayClear(this.m_leftNemesis);
        ArrayClear(this.m_leftSince);
        ArrayClear(this.m_leftSent);
        ArrayClear(this.m_leftUnseen);
        ArrayClear(this.m_leftNames);
        ArrayClear(this.m_deadNameIDs);
        ArrayClear(this.m_deadNameValues);
        des.DeleteTagged(n"GangRetaliation");
        this.ResetEncounter();
    }

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
        ArrayPush(this.m_leftUnseen, 0.0);
        ArrayPush(this.m_leftNames, name);
    }

    public func Vanish(id: EntityID) {
        this.HideMarkers(id);
        GameInstance.GetDynamicEntitySystem().DeleteEntity(id);
    }

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
        ArrayErase(this.m_leftUnseen, i);
        ArrayErase(this.m_leftNames, i);
    }

    private func PlayerSeesPos(player: ref<PlayerPuppet>, pos: Vector4) -> Bool {
        let toPos: Vector4 = pos - player.GetWorldPosition();
        toPos.Z = 0.0;
        if Vector4.GetAngleBetween(player.GetWorldForward(), toPos) > 50.0 {
            return false;
        }
        return this.HasLineOfSight(player, pos);
    }

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
                if seen {
                    this.m_leftUnseen[i] = 0.0;
                } else {
                    this.m_leftUnseen[i] += 1.0;
                }
                let npc: ref<ScriptedPuppet> = entity as ScriptedPuppet;
                if IsDefined(npc) {
                    if GRDetection.IsNeutralized(npc) {
                        if this.m_leftNemesis[i] > 0 {
                            this.MarkDead(id);
                        }
                        let settings: ref<GRSettings> = GRSettings.Get(gi);
                        let corpseSeconds: Float = Cast<Float>(IsDefined(settings) ? settings.corpseRemovalSeconds : 30);
                        remove = !seen && (distance > 20.0 || age > corpseSeconds || this.m_leftUnseen[i] >= 15.0);
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
                    let settings: ref<GRSettings> = GRSettings.Get(gi);
                    let limitSeconds: Int32 = IsDefined(settings) ? settings.corpseRemovalSeconds : 30;
                    GRDebugLog(gi, "Guarida: cadaver de Nemesis #" + IntToString(this.m_leftNemesis[i]) + " eliminado - edad=" + FloatToStringPrec(age, 1)
                        + "s limite=" + IntToString(limitSeconds) + "s sin ver=" + FloatToStringPrec(this.m_leftUnseen[i], 1) + "s", "Spawner");
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
        ArrayClear(this.m_watch);
        this.m_ambushActive = false;
        this.m_raidMode = false;
        this.m_strongholdMode = false;
        this.m_vehicleState = 0;
        let none: EntityID;
        this.m_vehicleID = none;
    }

    public func GetSpawnedCount() -> Int32 {
        return ArraySize(this.m_entityIDs);
    }

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
            stats.RemoveAllModifiers(id, gamedataStatType.PowerLevel);
            stats.AddModifier(id, RPGManager.CreateStatModifier(gamedataStatType.PowerLevel, gameStatModifierType.Additive, powerLevel));
            stats.RemoveAllModifiers(id, gamedataStatType.Level);
            stats.AddModifier(id, RPGManager.CreateStatModifier(gamedataStatType.Level, gameStatModifierType.Additive, stats.GetStatValue(playerId, gamedataStatType.Level) + extra));
            level = FloatToStringPrec(powerLevel, 0);
        }
        GRLog("Nemesis #" + IntToString(this.m_nemesisIDs[index]) + ": rango " + IntToString(rank) + ", vida x" + FloatToStringPrec(health, 2) + ", nivel " + level);
    }

    private func StripGodMode(index: Int32, npc: ref<ScriptedPuppet>, withStat: Bool) {
        let gi: GameInstance = this.GetGameInstance();
        let god: ref<GodModeSystem> = GameInstance.GetGodModeSystem(gi);
        if !IsDefined(god) {
            return;
        }
        let id: EntityID = npc.GetEntityID();
        let inv: Bool = god.HasGodMode(id, gameGodModeType.Invulnerable);
        let imm: Bool = god.HasGodMode(id, gameGodModeType.Immortal);
        let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(gi);
        let statInv: Float = withStat && IsDefined(stats) ? stats.GetStatValue(Cast<StatsObjectID>(id), gamedataStatType.IsInvulnerable) : 0.0;
        if !inv && !imm && statInv <= 0.0 {
            return;
        }
        let sources: array<CName> = god.GetGodModeSources(id, gameGodModeType.Invulnerable);
        let immSources: array<CName> = god.GetGodModeSources(id, gameGodModeType.Immortal);
        for source in immSources {
            ArrayPush(sources, source);
        }
        let names: String = "";
        for source in sources {
            names += " " + NameToString(source);
            god.ClearGodMode(id, source);
        }
        if statInv > 0.0 {
            stats.RemoveAllModifiers(Cast<StatsObjectID>(id), gamedataStatType.IsInvulnerable);
        }
        if this.m_godModeLogs < 30 {
            this.m_godModeLogs += 1;
            let after: String = "inv=" + ToString(god.HasGodMode(id, gameGodModeType.Invulnerable))
                + " imm=" + ToString(god.HasGodMode(id, gameGodModeType.Immortal));
            if withStat && IsDefined(stats) {
                after += " stat=" + FloatToStringPrec(stats.GetStatValue(Cast<StatsObjectID>(id), gamedataStatType.IsInvulnerable), 1);
            }
            GRLog("Modo dios quitado: Nemesis #" + IntToString(this.m_nemesisIDs[index]) + " " + TDBID.ToStringDEBUG(npc.GetRecordID())
                + (withStat ? " (al aparecer)" : " (tick)") + " | antes inv=" + ToString(inv) + " imm=" + ToString(imm)
                + " stat=" + FloatToStringPrec(statInv, 1) + " fuentes=[" + names + " ] | despues " + after);
        }
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
            if IsDefined(npc) {
                this.StripGodMode(index, npc, true);
            }
            if IsDefined(npc) && IsDefined(player) && this.m_raidMode {
                this.SetRaidHostility(index, npc);
                if this.m_nemesisIDs[index] > 0 && !this.m_hasMappin[index] {
                    this.AddMappin(index, npc);
                    ArrayPush(this.m_appearanceReports, IntToString(this.m_nemesisIDs[index]) + ":" + NameToString(npc.GetCurrentAppearanceName()));
                }
            } else if IsDefined(npc) && IsDefined(player) && this.m_strongholdMode {
                if IsDefined(npc.GetAttitudeAgent()) && IsDefined(player.GetAttitudeAgent()) {
                    npc.GetAttitudeAgent().SetAttitudeTowards(player.GetAttitudeAgent(), EAIAttitude.AIA_Hostile);
                }
                this.KeepSensesAwake(npc, player);
                GRLog("Guarida: " + this.GuardLabel(index, npc) + " aparece con V a "
                    + FloatToStringPrec(Vector4.Distance(npc.GetWorldPosition(), player.GetWorldPosition()), 0) + " m | " + this.GuardStatus(npc, player, false));
                if this.m_nemesisIDs[index] > 0 && !this.m_hasMappin[index] {
                    this.AddMappin(index, npc);
                    ArrayPush(this.m_appearanceReports, IntToString(this.m_nemesisIDs[index]) + ":" + NameToString(npc.GetCurrentAppearanceName()));
                }
            } else if IsDefined(npc) && IsDefined(player) {
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

    // How long ago this death was recorded - lets Lua hold off resolving return/no-return for a fixed
    // window (processDeaths), so a decapitation landed after the kill (MarkHeadRemoved) still has a
    // chance to flip m_deathKinds[index] to "confirmed" before the outcome is locked in.
    public func GetDeathAge(index: Int32) -> Float {
        return index < ArraySize(this.m_deathSince) ? this.Now() - this.m_deathSince[index] : 999.0;
    }

    public func RemoveDeathAt(index: Int32) {
        ArrayErase(this.m_deaths, index);
        ArrayErase(this.m_deathKinds, index);
        ArrayErase(this.m_deathCauses, index);
        ArrayErase(this.m_deathEntityIDs, index);
        ArrayErase(this.m_deathSince, index);
    }

    public func ClearDeaths() {
        let bounties: ref<GRBounties> = GRBounties.Get(this.GetGameInstance());
        let stronghold: ref<GRStronghold> = GRStronghold.Get(this.GetGameInstance());
        if IsDefined(bounties) {
            let i: Int32 = 0;
            while i < ArraySize(this.m_deaths) {
                let inLair: Bool = IsDefined(stronghold) && stronghold.SpawnedInLair(this.m_deaths[i]);
                bounties.OnDeath(this.m_deaths[i], this.GetDeathKind(i), this.GetDeathCause(i), inLair);
                i += 1;
            }
        }
        ArrayClear(this.m_deaths);
        ArrayClear(this.m_deathKinds);
        ArrayClear(this.m_deathCauses);
        ArrayClear(this.m_deathEntityIDs);
        ArrayClear(this.m_deathSince);
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

public class GRGuardWatch {
    public let id: EntityID;
    public let blindTicks: Int32;
    public let scriptSights: Int32;
    public let nearLogged: Bool;
    public let nearTicks: Int32;
    public let rechecked: Bool;
    public let moved: Bool;
}

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
