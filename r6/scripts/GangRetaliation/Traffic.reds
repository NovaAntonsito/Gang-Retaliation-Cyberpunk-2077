module GangRetaliation

// Vehiculos cargados alrededor de V (trafico y estacionados), para generar el auto de una emboscada
// pegado a uno que ya esta en la calle (idea de They Will Remember). TWR los encuentra con una entidad
// detectora propia (.ent); aca Codeware nos avisa cada vez que carga un vehiculo.
// El aviso puede llegar desde otro hilo: la lista se toca siempre con el candado.
public class GRTraffic extends ScriptableSystem {
    private let m_vehicles: array<wref<VehicleObject>>;
    private let m_lock: RWLock;

    public static func Get(gi: GameInstance) -> ref<GRTraffic> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRTraffic") as GRTraffic;
    }

    private func OnAttach() {
        let handler = GameInstance.GetCallbackSystem().RegisterCallback(n"Entity/Attached", this, n"OnVehicleAttached");
        if IsDefined(handler) {
            handler.AddTarget(EntityTarget.Type(n"vehicleBaseObject"));
        }
    }

    private func OnDetach() {
        GameInstance.GetCallbackSystem().UnregisterCallback(n"Entity/Attached", this);
    }

    private cb func OnVehicleAttached(event: ref<EntityLifecycleEvent>) {
        let vehicle: ref<VehicleObject> = event.GetEntity() as VehicleObject;
        if !IsDefined(vehicle) {
            return;
        }
        RWLock.Acquire(this.m_lock);
        // Los descargados quedan como wref vacias: se limpian aca para que la lista no crezca sin fin.
        if ArraySize(this.m_vehicles) > 120 {
            let alive: array<wref<VehicleObject>>;
            for v in this.m_vehicles {
                if IsDefined(v) {
                    ArrayPush(alive, v);
                }
            }
            this.m_vehicles = alive;
        }
        ArrayPush(this.m_vehicles, vehicle);
        RWLock.Release(this.m_lock);
    }

    // Copia (mezclada) de los vehiculos que siguen cargados.
    public func GetVehicles() -> array<ref<VehicleObject>> {
        let result: array<ref<VehicleObject>>;
        RWLock.AcquireShared(this.m_lock);
        for v in this.m_vehicles {
            if IsDefined(v) {
                ArrayPush(result, v);
            }
        }
        RWLock.ReleaseShared(this.m_lock);
        let i: Int32 = ArraySize(result) - 1;
        while i > 0 {
            let j: Int32 = RandRange(0, i + 1);
            let tmp: ref<VehicleObject> = result[i];
            result[i] = result[j];
            result[j] = tmp;
            i -= 1;
        }
        return result;
    }
}
