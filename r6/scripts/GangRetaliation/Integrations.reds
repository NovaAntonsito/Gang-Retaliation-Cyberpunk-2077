module GangRetaliation

// Integraciones opcionales con They Will Remember (TWR) y Drug Dealer (DD).
// Sus NPCs se reconocen por tags del DynamicEntitySystem, sin importar nada: funciona sin esos mods.
// Solo el factor de calor lee sus sistemas, detras de @if(ModuleExists(...)).
// Todo esto se llama en el hilo principal (tick, HandleCall o CET), nunca desde un hook de golpe.

@if(ModuleExists("TheyWillRemember.Factions"))
import TheyWillRemember.Factions.*

@if(ModuleExists("DrugDealer.State"))
import DrugDealer.State.*

public abstract class GRIntegrations {
    // Escuadron externo cerca de V: mas lejos no es "esta pelea".
    public static func SquadRange() -> Float { return 120.0; }

    private static func HasTag(id: EntityID, tag: CName) -> Bool {
        let des: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
        return IsDefined(des) && des.IsTagged(id, tag);
    }

    // Todo lo que genera Drug Dealer lleva DrugDealer.EntitySpawn; los enemigos ademas Hostile o FootEnemy.
    public static func IsDDSpawn(id: EntityID) -> Bool {
        return GRIntegrations.HasTag(id, n"DrugDealer.EntitySpawn");
    }

    public static func IsDDHostile(id: EntityID) -> Bool {
        return GRIntegrations.HasTag(id, n"DrugDealer.Hostile") || GRIntegrations.HasTag(id, n"DrugDealer.FootEnemy");
    }

    // Soldados y aliados de V en Drug Dealer: nunca son Nemesis.
    public static func IsDDAlly(id: EntityID) -> Bool {
        return GRIntegrations.IsDDSpawn(id) && !GRIntegrations.IsDDHostile(id);
    }

    // Miembro vivo de un escuadron externo, a menos de SquadRange de V. Devuelve su banda o "".
    private static func NearestGang(tag: CName, player: ref<PlayerPuppet>) -> String {
        let des: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
        if !IsDefined(des) || !IsDefined(player) {
            return "";
        }
        let best: String = "";
        let bestDistance: Float = GRIntegrations.SquadRange();
        let members: array<ref<Entity>> = des.GetTagged(tag);
        for member in members {
            let npc: ref<ScriptedPuppet> = member as ScriptedPuppet;
            if IsDefined(npc) && !GRDetection.IsNeutralized(npc) {
                let gang: String = GRDetection.GetGang(npc);
                let distance: Float = Vector4.Distance(npc.GetWorldPosition(), player.GetWorldPosition());
                if StrLen(gang) > 0 && distance < bestDistance {
                    best = gang;
                    bestDistance = distance;
                }
            }
        }
        return best;
    }

    // "TWR|Banda" o "DD|Banda": el escuadron externo mas cercano a V. "" si no hay ninguno.
    // CET lo usa para que un Nemesis de esa banda se sume a la pelea.
    public static func GetExternalSquad(gi: GameInstance) -> String {
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        let gang: String = GRIntegrations.NearestGang(n"TheyWillRemember.Squad", player);
        if StrLen(gang) > 0 {
            return "TWR|" + gang;
        }
        gang = GRIntegrations.NearestGang(n"DrugDealer.Hostile", player);
        if StrLen(gang) == 0 {
            gang = GRIntegrations.NearestGang(n"DrugDealer.FootEnemy", player);
        }
        if StrLen(gang) > 0 {
            return "DD|" + gang;
        }
        return "";
    }

    // Una mision de Drug Dealer con enemigos vivos (redada, invasion, emboscada al laboratorio...).
    public static func IsDDJobActive(gi: GameInstance) -> Bool {
        let des: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
        if !IsDefined(des) {
            return false;
        }
        let tags: array<CName> = [n"DrugDealer.Hostile", n"DrugDealer.FootEnemy"];
        for tag in tags {
            let members: array<ref<Entity>> = des.GetTagged(tag);
            for member in members {
                let npc: ref<ScriptedPuppet> = member as ScriptedPuppet;
                if IsDefined(npc) && !GRDetection.IsNeutralized(npc) {
                    return true;
                }
            }
        }
        return false;
    }

    // Multiplicador de la probabilidad de emboscada (1.0 a 2.0).
    // gangs = bandas del distrito separadas por coma (GRSpawner.GetDistrictGangs).
    public static func GetHeatFactor(gi: GameInstance, gangs: String) -> Float {
        let factor: Float = GRIntegrations.TWRFactor(gi, gangs) * GRIntegrations.DDFactor(gi);
        return MinF(factor, 2.0);
    }

    // Indice de faccion de TWR (KillCounts.GetFactionIndex) para nuestros nombres de banda.
    private static func TWRIndex(gang: String) -> Int32 {
        switch gang {
            case "Maelstrom": return 0;
            case "TygerClaws": return 1;
            case "Animals": return 2;
            case "Scavengers": return 3;
            case "Valentinos": return 4;
            case "VoodooBoys": return 5;
            case "SixthStreet": return 6;
            case "Wraiths": return 11;
            case "Barghest": return 12;
            default: return -1;
        }
    }

    // Rencor de TWR: banda hostil +0.5; muertes recientes hasta +0.5 (k / (k + 20)). Maximo de las bandas.
    @if(ModuleExists("TheyWillRemember.Factions"))
    private static func TWRFactor(gi: GameInstance, gangs: String) -> Float {
        let attitudes: ref<AttitudeManager> = AttitudeManager.GetInstance(gi);
        let kills: ref<KillCounts> = KillCounts.GetInstance(gi);
        if !IsDefined(attitudes) || !IsDefined(kills) {
            return 1.0;
        }
        let best: Float = 1.0;
        let list: array<String> = StrSplit(gangs, ",");
        for gang in list {
            let index: Int32 = GRIntegrations.TWRIndex(gang);
            if index >= 0 {
                let k: Float = Cast<Float>(kills.GetKillCountByIndex(index));
                let f: Float = 1.0 + 0.5 * k / (k + 20.0);
                if attitudes.IsFactionHostileByIndex(index) {
                    f += 0.5;
                }
                best = MaxF(best, f);
            }
        }
        return best;
    }

    @if(!ModuleExists("TheyWillRemember.Factions"))
    private static func TWRFactor(gi: GameInstance, gangs: String) -> Float {
        return 1.0;
    }

    // Rango de traficante de V (0-12): +4% por rango, hasta x1.48.
    @if(ModuleExists("DrugDealer.State"))
    private static func DDFactor(gi: GameInstance) -> Float {
        let state: ref<PlayerStateSystem> = PlayerStateSystem.Get();
        if !IsDefined(state) {
            return 1.0;
        }
        return 1.0 + 0.04 * Cast<Float>(EnumInt(state.GetRank()));
    }

    @if(!ModuleExists("DrugDealer.State"))
    private static func DDFactor(gi: GameInstance) -> Float {
        return 1.0;
    }
}
