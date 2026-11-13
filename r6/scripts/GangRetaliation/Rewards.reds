module GangRetaliation

// Armas de Jefe: cuando V mata a un Jefe se lleva su arma, una sola vez por Jefe. Es un arma base segun la
// banda, marcada iconica, escalada al nivel de V y con un bono elemental guardado en la partida.
// El nombre propio ("Carnage de Rex") no se guarda: sale del nombre del Jefe, que Lua pasa en cada sesion.
public class GRRewards extends ScriptableSystem {
    // Listas paralelas: m_nemesisIds[i] es el Jefe que dio el arma m_ids[i] (0 = sin Jefe, datos de la prueba vieja).
    private persistent let m_ids: array<ItemID>;
    private persistent let m_nemesisIds: array<Int32>;
    // Jefes que ya dieron su arma. No se vacia aunque el arma se borre despues.
    private persistent let m_given: array<Int32>;
    // Nivel de Aumento de cada arma, paralelo a m_ids: de 1 (I) a 5 (V). Un 0 (armas de antes del Aumento) cuenta como I.
    private persistent let m_levels: array<Int32>;

    // Nombres de los Jefes (Lua, cada sesion). redscript no deja guardar String en la partida.
    private let m_nameIds: array<Int32>;
    private let m_names: array<String>;

    // Resultado de PreviewBossWeapon (el arma que daria un Jefe vivo).
    private let m_pvElement: Int32;
    private let m_pvBonus: Int32;
    // Indice en la foto del arma que quedo del ultimo Fuse; solo vale justo despues de un Fuse que devolvio true.
    private let m_fusedIndex: Int32;

    // Foto de las armas de Jefe que V tiene ahora, para la vista Arsenal del menu (Snapshot). Listas paralelas; no se guardan.
    private let m_oIds: array<ItemID>;
    private let m_oNemesis: array<Int32>;
    private let m_oGangs: array<String>;
    private let m_oElements: array<Int32>;
    private let m_oBonus: array<Int32>;
    private let m_oBonusF: array<Float>;
    private let m_oLevels: array<Int32>;
    private let m_oDamage: array<Float>;
    private let m_oTiers: array<String>;
    private let m_oEquipped: array<Bool>;

    public static func Get(gi: GameInstance) -> ref<GRRewards> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRRewards") as GRRewards;
    }

    // Armas registradas (esten o no en el inventario). GRSystem lo loguea al restaurar la partida.
    public func GetRegisteredCount() -> Int32 {
        return ArraySize(this.m_ids);
    }

    // Diagnostico: lo que le llego a este sistema al cargar la partida, dicho por el mismo (el orden en que el
    // juego restaura cada sistema no se conoce: la cuenta que lee GRSystem podria ser de antes de restaurar este).
    private func OnRestored(saveVersion: Int32, gameVersion: Int32) {
        GRLog("Recompensas: partida restaurada, " + IntToString(ArraySize(this.m_ids)) + " arma(s) registrada(s), "
            + IntToString(ArraySize(this.m_given)) + " Jefe(s) que ya dieron arma");
    }

    public func ClearNames() -> Void {
        ArrayClear(this.m_nameIds);
        ArrayClear(this.m_names);
    }

    public func AddName(nemesisId: Int32, name: String) -> Void {
        let i: Int32 = 0;
        while i < ArraySize(this.m_nameIds) {
            if this.m_nameIds[i] == nemesisId && i < ArraySize(this.m_names) {
                this.m_names[i] = name;
                return;
            }
            i += 1;
        }
        // Si las listas quedaron desparejas (no deberia), se empieza de cero antes de agregar.
        if ArraySize(this.m_nameIds) != ArraySize(this.m_names) {
            this.ClearNames();
        }
        ArrayPush(this.m_nameIds, nemesisId);
        ArrayPush(this.m_names, name);
    }

    // True si ese Nemesis ya dio su arma: Lua lo usa para seguir pasando su nombre aunque haya bajado de rango.
    public func HasGiven(nemesisId: Int32) -> Bool {
        return ArrayContains(this.m_given, nemesisId);
    }

    // "" si el ItemID no es un arma de Jefe o no se conoce al Jefe (otra campana): queda el nombre del juego.
    // Lo llaman los wraps de la UI: tiene que ser barato para los items que no son nuestros.
    public func GetCustomName(id: ItemID) -> String {
        let count: Int32 = ArraySize(this.m_ids);
        let i: Int32 = 0;
        while i < count {
            if this.m_ids[i] == id {
                if i < ArraySize(this.m_nemesisIds) {
                    return this.NameForNemesis(this.m_nemesisIds[i], id);
                }
                return "";
            }
            i += 1;
        }
        return "";
    }

    // Da a V el arma del Jefe. Devuelve el nombre del arma, o "" si no dio nada (ya la habia dado, banda sin arma, fallo).
    // force = true saltea el "una sola vez por Jefe" (boton de desarrollo).
    public func GiveBossWeapon(nemesisId: Int32, gang: String, traitsCsv: String, escapes: Int32, force: Bool) -> String {
        if nemesisId <= 0 {
            return "";
        }
        if !force && ArrayContains(this.m_given, nemesisId) {
            return "";
        }
        let recordID: TweakDBID = this.WeaponForGang(gang);
        if !TDBID.IsValid(recordID) {
            GRLog("Recompensas: arma de Jefe #" + IntToString(nemesisId) + " sin arma para la banda \"" + gang + "\"");
            return "";
        }
        let gi: GameInstance = this.GetGameInstance();
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        if !IsDefined(player) {
            GRLog("Recompensas: arma de Jefe #" + IntToString(nemesisId) + " cancelada, no hay jugador");
            return "";
        }
        let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(gi);
        let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(gi);
        let id: ItemID = ItemID.FromTDBID(recordID);
        let given: Bool = ts.GiveItem(player, id, 1);
        let data: wref<gameItemData> = ts.GetItemData(player, id);
        if !IsDefined(data) {
            GRLog("Recompensas: arma de Jefe #" + IntToString(nemesisId) + " cancelada, GiveItem=" + this.BoolText(given)
                + " pero no hay itemData para " + this.DescribeId(id));
            return "";
        }
        let objID: StatsObjectID = data.GetStatsObjectID();

        let element: Int32 = this.RollElement(nemesisId, traitsCsv);
        let pct: Int32 = this.RollBonus(nemesisId, escapes);
        let bonusPct: Float = Cast<Float>(pct);

        // 1) Iconica antes que nada: Black Market Arsenal ignora las iconicas (RPGManager.IsItemIconic).
        let ok: Bool = stats.AddSavedModifier(objID, RPGManager.CreateStatModifier(gamedataStatType.IsItemIconic, gameStatModifierType.Additive, 1.0));

        // 2) Nivel de V, igual que el juego con las recompensas del punto de entrega (dropPointController.swift:178-187).
        let playerLevel: Float = stats.GetStatValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatType.PowerLevel);
        stats.RemoveAllModifiers(objID, gamedataStatType.PowerLevel, true);
        if !stats.AddSavedModifier(objID, RPGManager.CreateStatModifier(gamedataStatType.PowerLevel, gameStatModifierType.Additive, playerLevel)) {
            ok = false;
        }

        // 3) Bono elemental, calculado sobre el dano ya escalado.
        let baseName: String = this.BaseDamageName(data, stats);
        let baseValue: Float = this.BaseDamage(data, stats);
        let bonus: Float = baseValue * bonusPct / 100.0;
        if !stats.AddSavedModifier(objID, RPGManager.CreateStatModifier(this.ElementStat(element), gameStatModifierType.Additive, bonus)) {
            ok = false;
        }

        // 4) Probabilidad de aplicar el estado. Escala 0-100: el juego la divide por 100 y la compara con un azar 0-1
        //    (damageSystem.swift, ApplyStatusEffectByApplicationRate). Vale para disparos y golpes cuerpo a cuerpo.
        if !stats.AddSavedModifier(objID, RPGManager.CreateStatModifier(this.ElementRateStat(element), gameStatModifierType.Additive, bonusPct)) {
            ok = false;
        }

        this.SyncLists();
        ArrayPush(this.m_ids, id);
        ArrayPush(this.m_nemesisIds, nemesisId);
        ArrayPush(this.m_levels, 1);
        if !ArrayContains(this.m_given, nemesisId) {
            ArrayPush(this.m_given, nemesisId);
        }

        // Si Lua todavia no paso el nombre del Jefe, el aviso usa el nombre del arma base.
        let name: String = this.GetCustomName(id);
        if StrLen(name) == 0 {
            name = this.WeaponBaseName(id);
        }
        GRLog("Recompensas: arma de Jefe #" + IntToString(nemesisId) + " (" + gang + ") \"" + name + "\" " + this.DescribeId(id)
            + " elemento=" + this.ElementName(element) + " bono=" + IntToString(pct) + "% (+" + FloatToStringPrec(bonus, 2) + " sobre " + baseName + "="
            + FloatToStringPrec(baseValue, 2) + ") " + this.ElementRateName(element) + "=+" + IntToString(pct) + " escapes=" + IntToString(escapes)
            + " rasgos=\"" + traitsCsv + "\" forzada=" + this.BoolText(force) + " modificadores OK=" + this.BoolText(ok)
            + " | DESPUES " + this.DescribeStats(data, stats));
        return name;
    }

    // -------------------------------------------------------------------------
    // Aumento: fusionar una copia con el arma principal de la misma banda
    // -------------------------------------------------------------------------
    // mainIndex y copyIndex son indices de la foto (Snapshot); keepElement, el elemento que queda (el de una de las dos).
    // La copia se destruye; el arma principal sube un nivel (+5 % de dano por nivel) y su bono pasa a ser el mas alto
    // de los dos x 1,10 (tope 60). Devuelve false, con el motivo en el log, si no se puede. Al terminar rehace la foto.
    public func Fuse(mainIndex: Int32, copyIndex: Int32, keepElement: Int32) -> Bool {
        this.m_fusedIndex = -1;
        if !this.OwnedValid(mainIndex) || !this.OwnedValid(copyIndex) {
            GRLog("Recompensas: Aumento cancelado (indices fuera de la foto: " + IntToString(mainIndex) + " y " + IntToString(copyIndex)
                + " de " + IntToString(ArraySize(this.m_oIds)) + ")");
            return false;
        }
        let mainId: ItemID = this.m_oIds[mainIndex];
        let copyId: ItemID = this.m_oIds[copyIndex];
        if mainIndex == copyIndex || mainId == copyId {
            GRLog("Recompensas: Aumento cancelado (el arma y la copia son la misma) " + this.DescribeId(mainId));
            return false;
        }
        let gang: String = this.GangForRecord(ItemID.GetTDBID(mainId));
        let copyGang: String = this.GangForRecord(ItemID.GetTDBID(copyId));
        if StrLen(gang) == 0 || NotEquals(gang, copyGang) {
            GRLog("Recompensas: Aumento cancelado (no son de la misma banda: \"" + gang + "\" y \"" + copyGang + "\")");
            return false;
        }
        let gi: GameInstance = this.GetGameInstance();
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        if !IsDefined(player) {
            GRLog("Recompensas: Aumento cancelado (no hay jugador)");
            return false;
        }
        let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(gi);
        let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(gi);
        let mainData: wref<gameItemData> = ts.GetItemData(player, mainId);
        let copyData: wref<gameItemData> = ts.GetItemData(player, copyId);
        if !IsDefined(mainData) || !IsDefined(copyData) || !ts.HasItem(player, mainId) || !ts.HasItem(player, copyId) {
            GRLog("Recompensas: Aumento cancelado (V no tiene las dos armas) arma " + this.DescribeId(mainId) + " copia " + this.DescribeId(copyId));
            return false;
        }
        let equipment: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(player);
        if IsDefined(equipment) && equipment.IsEquipped(copyId) {
            GRLog("Recompensas: Aumento cancelado (la copia esta equipada) " + this.DescribeId(copyId));
            return false;
        }
        this.SyncLists();
        let mainReg: Int32 = this.RegistryIndex(mainId);
        let copyReg: Int32 = this.RegistryIndex(copyId);
        if mainReg < 0 || copyReg < 0 {
            GRLog("Recompensas: Aumento cancelado (arma sin registrar) arma " + this.DescribeId(mainId) + " copia " + this.DescribeId(copyId));
            return false;
        }
        let mainElement: Int32 = this.WeaponElement(mainData, stats);
        let copyElement: Int32 = this.WeaponElement(copyData, stats);
        if keepElement < 0 || keepElement > 2 || (keepElement != mainElement && keepElement != copyElement) {
            GRLog("Recompensas: Aumento cancelado (el elemento " + IntToString(keepElement) + " no es el de ninguna de las dos: arma="
                + this.ElementLabel(mainElement) + " copia=" + this.ElementLabel(copyElement) + ")");
            return false;
        }
        let oldLevel: Int32 = this.LevelAt(mainReg);
        let copyLevel: Int32 = this.LevelAt(copyReg);
        let oldBonus: Float = this.WeaponBonus(mainData, stats, mainElement);
        let copyBonus: Float = this.WeaponBonus(copyData, stats, copyElement);
        if this.IsMaxed(oldLevel, oldBonus) {
            GRLog("Recompensas: Aumento cancelado (al tope) " + this.DescribeId(mainId) + " nivel=" + IntToString(oldLevel)
                + " bono=" + FloatToStringPrec(oldBonus, 1) + "%");
            return false;
        }
        let newLevel: Int32 = this.FusedLevel(oldLevel, copyLevel);
        let newBonus: Float = this.FusedBonus(oldBonus, copyBonus);
        let before: String = this.DescribeStats(mainData, stats);
        let copyText: String = this.DescribeId(copyId) + " nivel=" + IntToString(copyLevel) + " elemento=" + this.ElementLabel(copyElement)
            + " bono=" + FloatToStringPrec(copyBonus, 1) + "%";

        // 1) La copia se destruye antes de tocar el arma: si el juego no la quita, no cambia nada (y no se puede repetir gratis).
        let removed: Bool = ts.RemoveItem(player, copyId, 1);
        if ts.HasItem(player, copyId) {
            GRLog("Recompensas: Aumento ERROR, no se pudo destruir la copia (RemoveItem=" + this.BoolText(removed) + "): sigue registrada y el arma no cambia. "
                + copyText);
            return false;
        }
        ArrayErase(this.m_ids, copyReg);
        ArrayErase(this.m_nemesisIds, copyReg);
        ArrayErase(this.m_levels, copyReg);
        if copyReg < mainReg {
            mainReg -= 1;
        }

        // 2) +5 % de dano por cada nivel que sube. AdditiveMultiplier se suma al multiplicador del stat (1 + suma).
        let objID: StatsObjectID = mainData.GetStatsObjectID();
        let ok: Bool = true;
        let physBefore: Float = this.ReadStat(mainData, stats, gamedataStatType.PhysicalDamage);
        if newLevel > oldLevel {
            if !stats.AddSavedModifier(objID, RPGManager.CreateStatModifier(gamedataStatType.PhysicalDamage, gameStatModifierType.AdditiveMultiplier,
                0.05 * Cast<Float>(newLevel - oldLevel))) {
                ok = false;
            }
        }
        let physAfter: Float = this.ReadStat(mainData, stats, gamedataStatType.PhysicalDamage);

        // 3) Elemento y bono con modificadores de diferencia (RemoveAllModifiers podria borrar stats del record).
        //    El elemento viejo, si cambia, se deja en 0; el que queda se lleva a sus valores nuevos.
        let baseName: String = this.BaseDamageName(mainData, stats);
        let baseValue: Float = this.BaseDamage(mainData, stats);
        let newDamage: Float = baseValue * newBonus / 100.0;
        if mainElement >= 0 && mainElement != keepElement {
            if !this.AddDifference(mainData, stats, this.ElementStat(mainElement), 0.0) {
                ok = false;
            }
            if !this.AddDifference(mainData, stats, this.ElementRateStat(mainElement), 0.0) {
                ok = false;
            }
        }
        if !this.AddDifference(mainData, stats, this.ElementStat(keepElement), newDamage) {
            ok = false;
        }
        if !this.AddDifference(mainData, stats, this.ElementRateStat(keepElement), newBonus) {
            ok = false;
        }
        this.m_levels[mainReg] = newLevel;

        GRLog("Recompensas: Aumento (" + gang + ") \"" + this.GetCustomName(mainId) + "\" " + this.DescribeId(mainId)
            + " | ANTES nivel=" + IntToString(oldLevel) + " elemento=" + this.ElementLabel(mainElement) + " bono=" + FloatToStringPrec(oldBonus, 1) + "%"
            + " | COPIA destruida " + copyText + " RemoveItem=" + this.BoolText(removed)
            + " | DESPUES nivel=" + IntToString(newLevel) + " elemento=" + this.ElementLabel(keepElement) + " bono=" + FloatToStringPrec(newBonus, 1) + "%"
            + " (dano elemental " + FloatToStringPrec(newDamage, 2) + " sobre " + baseName + "=" + FloatToStringPrec(baseValue, 2)
            + ", PhysicalDamage " + FloatToStringPrec(physBefore, 2) + " -> " + FloatToStringPrec(physAfter, 2) + ")"
            + " modificadores OK=" + this.BoolText(ok) + " quedan registradas=" + IntToString(ArraySize(this.m_ids))
            + " | ANTES " + before + " | DESPUES " + this.DescribeStats(mainData, stats));
        // Control del +5 % por nivel: si el motor no lo aplico como se espera, queda dicho en el log.
        if newLevel > oldLevel && physBefore > 0.0 {
            let expected: Float = physBefore * (1.0 + 0.05 * Cast<Float>(newLevel - 1)) / (1.0 + 0.05 * Cast<Float>(oldLevel - 1));
            if AbsF(physAfter - expected) > expected * 0.01 {
                GRLog("Recompensas: Aumento AVISO, PhysicalDamage esperado " + FloatToStringPrec(expected, 2) + " y quedo en "
                    + FloatToStringPrec(physAfter, 2) + " (revisar AdditiveMultiplier)");
            }
        }

        this.Snapshot();
        let i: Int32 = 0;
        while i < ArraySize(this.m_oIds) {
            if this.m_oIds[i] == mainId {
                this.m_fusedIndex = i;
            }
            i += 1;
        }
        return true;
    }

    // Indice en la foto del arma que quedo del ultimo Fuse que salio bien (menor que 0 = ninguna).
    public func GetFusedIndex() -> Int32 {
        return this.m_fusedIndex;
    }

    // Bono que deja un Aumento: el mas alto de los dos x 1,10, redondeado a un decimal, con tope 60.
    // Publicas las dos: el menu muestra el resultado antes de fusionar con la misma cuenta.
    public func FusedBonus(mainBonus: Float, copyBonus: Float) -> Float {
        return MinF(60.0, Cast<Float>(RoundF(MaxF(mainBonus, copyBonus) * 11.0)) / 10.0);
    }

    // Nivel que deja un Aumento: el mas alto de los dos + 1, hasta V.
    public func FusedLevel(mainLevel: Int32, copyLevel: Int32) -> Int32 {
        return Min(5, Max(mainLevel, copyLevel) + 1);
    }

    // Suma al stat lo que le falta (o le sobra) para valer target.
    private func AddDifference(data: wref<gameItemData>, stats: ref<StatsSystem>, stat: gamedataStatType, target: Float) -> Bool {
        let difference: Float = target - this.ReadStat(data, stats, stat);
        if AbsF(difference) < 0.0001 {
            return true;
        }
        return stats.AddSavedModifier(data.GetStatsObjectID(), RPGManager.CreateStatModifier(stat, gameStatModifierType.Additive, difference));
    }

    private func RegistryIndex(id: ItemID) -> Int32 {
        let i: Int32 = 0;
        while i < ArraySize(this.m_ids) {
            if this.m_ids[i] == id {
                return i;
            }
            i += 1;
        }
        return -1;
    }

    // Nivel de Aumento del arma registrada en index: de 1 a 5 (sin dato = 1).
    private func LevelAt(index: Int32) -> Int32 {
        if index < 0 || index >= ArraySize(this.m_levels) {
            return 1;
        }
        return Min(5, Max(1, this.m_levels[index]));
    }

    // Al tope: nivel V y bono 60 %. Un Aumento ya no le daria nada.
    private func IsMaxed(level: Int32, bonus: Float) -> Bool {
        return level >= 5 && bonus >= 59.95;
    }

    // Elemento del arma: su dano elemental mas alto. 0 = Electrico, 1 = Termico, 2 = Quimico, -1 = ninguno.
    private func WeaponElement(data: wref<gameItemData>, stats: ref<StatsSystem>) -> Int32 {
        let element: Int32 = -1;
        let best: Float = 0.0;
        let e: Int32 = 0;
        while e < 3 {
            let value: Float = this.ReadStat(data, stats, this.ElementStat(e));
            if value > best {
                best = value;
                element = e;
            }
            e += 1;
        }
        return element;
    }

    // Bono elemental en %: el ApplicationRate del elemento del arma (el mismo numero).
    private func WeaponBonus(data: wref<gameItemData>, stats: ref<StatsSystem>, element: Int32) -> Float {
        if element < 0 {
            return 0.0;
        }
        return this.ReadStat(data, stats, this.ElementRateStat(element));
    }

    // Dano sobre el que se calcula el bono elemental: PhysicalDamage o, si el arma no tiene, EffectiveDamagePerHit.
    private func BaseDamage(data: wref<gameItemData>, stats: ref<StatsSystem>) -> Float {
        let value: Float = this.ReadStat(data, stats, gamedataStatType.PhysicalDamage);
        if value <= 0.0 {
            value = this.ReadStat(data, stats, gamedataStatType.EffectiveDamagePerHit);
        }
        return value;
    }

    private func BaseDamageName(data: wref<gameItemData>, stats: ref<StatsSystem>) -> String {
        if this.ReadStat(data, stats, gamedataStatType.PhysicalDamage) <= 0.0 {
            return "EffectiveDamagePerHit";
        }
        return "PhysicalDamage";
    }

    // -------------------------------------------------------------------------
    // El arma que daria un Jefe vivo (panel del Jefe en el menu)
    // -------------------------------------------------------------------------
    // Semilla fija por Jefe: el mismo Jefe da siempre el mismo elemento y el mismo bono.
    private func SeedFor(nemesisId: Int32) -> Int32 {
        return ((nemesisId % 100000) * 7919 + 104729) % 1000003;
    }

    // El elemento usa seed / 21 y el bono seed % 21: asi uno no depende del otro.
    private func RollElement(nemesisId: Int32, traitsCsv: String) -> Int32 {
        return this.PickElement(traitsCsv, this.SeedFor(nemesisId) / 21);
    }

    // Bono en %: 20-40 segun el Jefe, +2 por cada vez que se le escapo a V, tope 60.
    private func RollBonus(nemesisId: Int32, escapes: Int32) -> Int32 {
        let pct: Int32 = 20 + (this.SeedFor(nemesisId) % 21) + 2 * Max(escapes, 0);
        if pct > 60 {
            pct = 60;
        }
        return pct;
    }

    // Calcula, sin dar nada, el elemento y el bono del arma que daria ese Jefe (los mismos que usara GiveBossWeapon).
    // Se leen con GetPreviewElement / GetPreviewBonus. False si la banda no tiene arma.
    public func PreviewBossWeapon(nemesisId: Int32, gang: String, traitsCsv: String, escapes: Int32) -> Bool {
        this.m_pvElement = -1;
        this.m_pvBonus = 0;
        if nemesisId <= 0 || !TDBID.IsValid(this.WeaponForGang(gang)) {
            return false;
        }
        this.m_pvElement = this.RollElement(nemesisId, traitsCsv);
        this.m_pvBonus = this.RollBonus(nemesisId, escapes);
        return true;
    }

    public func GetPreviewElement() -> Int32 {
        return this.m_pvElement;
    }

    public func GetPreviewBonus() -> Int32 {
        return this.m_pvBonus;
    }

    // Nombre del juego del arma base de la banda ("Carnage"), o "" si la banda no tiene.
    public func GetGangWeaponBaseName(gang: String) -> String {
        return this.RecordBaseName(this.WeaponForGang(gang));
    }

    // Tipo del arma base de la banda, ya traducido ("Escopeta"), o "".
    public func GetGangWeaponType(gang: String) -> String {
        let record: ref<Item_Record> = TweakDBInterface.GetItemRecord(this.WeaponForGang(gang));
        if !IsDefined(record) || !IsDefined(record.ItemType()) {
            return "";
        }
        return GetLocalizedText(UIItemsHelper.GetItemTypeKey(record.ItemType().Type()));
    }

    // Nombre propio que tendra el arma de ese Jefe ("Carnage de Rex").
    public func GetBossWeaponName(boss: String, gang: String) -> String {
        return this.FormatName(boss, this.GetGangWeaponBaseName(gang));
    }

    // -------------------------------------------------------------------------
    // Lectura para el menu (vista Arsenal)
    // -------------------------------------------------------------------------
    // Rehace la foto: solo las armas registradas que V tiene en el inventario. El menu la pide al abrir Arsenal.
    public func Snapshot() -> Void {
        ArrayClear(this.m_oIds);
        ArrayClear(this.m_oNemesis);
        ArrayClear(this.m_oGangs);
        ArrayClear(this.m_oElements);
        ArrayClear(this.m_oBonus);
        ArrayClear(this.m_oBonusF);
        ArrayClear(this.m_oLevels);
        ArrayClear(this.m_oDamage);
        ArrayClear(this.m_oTiers);
        ArrayClear(this.m_oEquipped);
        let gi: GameInstance = this.GetGameInstance();
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        if !IsDefined(player) {
            return;
        }
        let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(gi);
        let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(gi);
        let equipment: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(player);
        let i: Int32 = 0;
        while i < ArraySize(this.m_ids) {
            let id: ItemID = this.m_ids[i];
            let data: wref<gameItemData> = ts.GetItemData(player, id);
            if IsDefined(data) && ts.HasItem(player, id) {
                // Elemento: el dano elemental mas alto del arma; el bono % es su ApplicationRate (mismo numero).
                let element: Int32 = this.WeaponElement(data, stats);
                let bonus: Float = this.WeaponBonus(data, stats, element);
                let tier: String = GetLocalizedText(UIItemsHelper.QualityToTierString(RPGManager.GetItemQuality(data)));
                let plus: Int32 = RoundF(RPGManager.GetItemPlus(data));
                while plus > 0 {
                    tier += "+";
                    plus -= 1;
                }
                ArrayPush(this.m_oIds, id);
                ArrayPush(this.m_oNemesis, i < ArraySize(this.m_nemesisIds) ? this.m_nemesisIds[i] : 0);
                ArrayPush(this.m_oGangs, this.GangForRecord(ItemID.GetTDBID(id)));
                ArrayPush(this.m_oElements, element);
                ArrayPush(this.m_oBonus, RoundF(bonus));
                ArrayPush(this.m_oBonusF, bonus);
                ArrayPush(this.m_oLevels, this.LevelAt(i));
                ArrayPush(this.m_oDamage, this.ReadStat(data, stats, gamedataStatType.EffectiveDamagePerHit));
                ArrayPush(this.m_oTiers, tier);
                ArrayPush(this.m_oEquipped, IsDefined(equipment) && equipment.IsEquipped(id));
            }
            i += 1;
        }
    }

    public func GetOwnedCount() -> Int32 {
        return ArraySize(this.m_oIds);
    }

    private func OwnedValid(index: Int32) -> Bool {
        return index >= 0 && index < ArraySize(this.m_oIds);
    }

    // Clave de la banda ("Maelstrom"), o "" si el record no es de la tabla.
    public func GetOwnedGang(index: Int32) -> String {
        return this.OwnedValid(index) ? this.m_oGangs[index] : "";
    }

    // Nombre propio; si no se conoce al Jefe, el nombre del juego.
    public func GetOwnedName(index: Int32) -> String {
        if !this.OwnedValid(index) {
            return "";
        }
        let id: ItemID = this.m_oIds[index];
        let name: String = this.GetCustomName(id);
        return StrLen(name) > 0 ? name : this.WeaponBaseName(id);
    }

    public func GetOwnedBaseName(index: Int32) -> String {
        return this.OwnedValid(index) ? this.WeaponBaseName(this.m_oIds[index]) : "";
    }

    public func GetOwnedRecord(index: Int32) -> TweakDBID {
        return this.OwnedValid(index) ? ItemID.GetTDBID(this.m_oIds[index]) : TDBID.None();
    }

    // 0 = Electrico, 1 = Termico, 2 = Quimico, -1 = ninguno.
    public func GetOwnedElement(index: Int32) -> Int32 {
        return this.OwnedValid(index) ? this.m_oElements[index] : -1;
    }

    // Bono elemental en % (20-60).
    public func GetOwnedBonus(index: Int32) -> Int32 {
        return this.OwnedValid(index) ? this.m_oBonus[index] : 0;
    }

    // El mismo bono con su decimal (un Aumento lo deja en 41,8 %).
    public func GetOwnedBonusF(index: Int32) -> Float {
        return this.OwnedValid(index) ? this.m_oBonusF[index] : 0.0;
    }

    // Nivel de Aumento: de 1 (I) a 5 (V).
    public func GetOwnedLevel(index: Int32) -> Int32 {
        return this.OwnedValid(index) ? this.m_oLevels[index] : 1;
    }

    // True si un Aumento ya no le daria nada (nivel V y bono 60 %): Fuse lo rechaza.
    public func IsOwnedMaxed(index: Int32) -> Bool {
        return this.OwnedValid(index) && this.IsMaxed(this.m_oLevels[index], this.m_oBonusF[index]);
    }

    // Dano por golpe (EffectiveDamagePerHit).
    public func GetOwnedDamage(index: Int32) -> Float {
        return this.OwnedValid(index) ? this.m_oDamage[index] : 0.0;
    }

    // Texto del juego, ya traducido: "Tier 3+" / "Nivel 3+".
    public func GetOwnedTier(index: Int32) -> String {
        return this.OwnedValid(index) ? this.m_oTiers[index] : "";
    }

    public func IsOwnedEquipped(index: Int32) -> Bool {
        return this.OwnedValid(index) && this.m_oEquipped[index];
    }

    // Nombre del Jefe al que se la quito V, o "" si no se conoce (otra campana).
    public func GetOwnedBossName(index: Int32) -> String {
        if !this.OwnedValid(index) {
            return "";
        }
        let nemesisId: Int32 = this.m_oNemesis[index];
        let i: Int32 = 0;
        while i < ArraySize(this.m_nameIds) {
            if this.m_nameIds[i] == nemesisId && nemesisId > 0 && i < ArraySize(this.m_names) {
                return this.m_names[i];
            }
            i += 1;
        }
        return "";
    }

    // Proporcion (ancho / alto) del icono 2D del arma, para dibujarlo sin deformar.
    public func GetOwnedIconAspect(index: Int32) -> Float {
        return this.OwnedValid(index) ? this.IconAspect(ItemID.GetTDBID(this.m_oIds[index])) : 2.5;
    }

    // Cada icono del juego esta recortado a su arma. Medido en los atlas item_icons0-4 (texturas de 2048x2048):
    // ancho x alto en pixeles del recorte de cada una. Va junto a la tabla de WeaponForGang: si cambia un arma, cambia aca.
    private func IconAspect(recordID: TweakDBID) -> Float {
        if recordID == t"Items.Preset_Carnage_Default" {
            return 320.0 / 76.0;
        }
        if recordID == t"Items.Preset_Katana_Default" {
            return 320.0 / 31.0;
        }
        if recordID == t"Items.Preset_Overture_Default" {
            return 320.0 / 153.0;
        }
        if recordID == t"Items.Preset_Copperhead_Military" {
            return 320.0 / 90.0;
        }
        if recordID == t"Items.Preset_Hammer_Default" {
            return 320.0 / 91.0;
        }
        if recordID == t"Items.Preset_Yukimura_Default" {
            return 273.0 / 160.0;
        }
        if recordID == t"Items.Preset_Tactician_Default" {
            return 320.0 / 53.0;
        }
        if recordID == t"Items.Preset_Saratoga_Default" {
            return 320.0 / 149.0;
        }
        if recordID == t"Items.Preset_Ajax_Default" {
            return 320.0 / 119.0;
        }
        return 2.5;
    }

    // Banda a la que pertenece un record de arma (la tabla de WeaponForGang al reves).
    private func GangForRecord(recordID: TweakDBID) -> String {
        let gangs: array<String> = ["Maelstrom", "TygerClaws", "Valentinos", "SixthStreet", "Animals", "VoodooBoys", "Wraiths", "Scavengers", "Barghest"];
        let i: Int32 = 0;
        while i < ArraySize(gangs) {
            if this.WeaponForGang(gangs[i]) == recordID {
                return gangs[i];
            }
            i += 1;
        }
        return "";
    }

    // Una linea por arma registrada: de que Jefe es, si V la tiene y sus stats.
    public func DebugReport() -> Void {
        let gi: GameInstance = this.GetGameInstance();
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        let count: Int32 = ArraySize(this.m_ids);
        let givenText: String = "";
        let g: Int32 = 0;
        while g < ArraySize(this.m_given) {
            if g > 0 {
                givenText += ",";
            }
            givenText += IntToString(this.m_given[g]);
            g += 1;
        }
        GRLog("Recompensas: reporte, " + IntToString(count) + " arma(s) registrada(s), Jefes que ya dieron arma=[" + givenText
            + "], nombres de Jefe en memoria=" + IntToString(ArraySize(this.m_names)));
        if !IsDefined(player) {
            GRLog("Recompensas: reporte cancelado, no hay jugador");
            return;
        }
        let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(gi);
        let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(gi);
        let i: Int32 = 0;
        while i < count {
            let id: ItemID = this.m_ids[i];
            let nemesisId: Int32 = 0;
            if i < ArraySize(this.m_nemesisIds) {
                nemesisId = this.m_nemesisIds[i];
            }
            let has: Bool = ts.HasItem(player, id);
            let data: wref<gameItemData> = ts.GetItemData(player, id);
            let line: String = "Recompensas: reporte #" + IntToString(i) + " Jefe #" + IntToString(nemesisId) + " \"" + this.GetCustomName(id) + "\" "
                + this.DescribeId(id) + " nivel=" + IntToString(this.LevelAt(i)) + " V la tiene=" + this.BoolText(has) + " cantidad=" + IntToString(ts.GetItemQuantity(player, id));
            if IsDefined(data) {
                line += " | " + this.DescribeStats(data, stats);
            } else {
                line += " | sin itemData";
            }
            GRLog(line);
            i += 1;
        }
    }

    // Quita de V la ultima arma registrada. Si el juego no la quita y V la sigue teniendo, queda registrada para reintentar.
    // El Jefe sigue contando como "ya dio su arma".
    public func DebugRemoveLast() -> Void {
        let gi: GameInstance = this.GetGameInstance();
        this.SyncLists();
        let count: Int32 = ArraySize(this.m_ids);
        if count == 0 {
            GRLog("Recompensas: quitar, no hay armas registradas");
            return;
        }
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        if !IsDefined(player) {
            GRLog("Recompensas: quitar cancelado, no hay jugador");
            return;
        }
        let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(gi);
        let last: Int32 = count - 1;
        let id: ItemID = this.m_ids[last];
        let nemesisId: Int32 = this.m_nemesisIds[last];
        let hadIt: Bool = ts.HasItem(player, id);
        let removed: Bool = ts.RemoveItem(player, id, 1);
        let stillHas: Bool = ts.HasItem(player, id);
        let unregistered: Bool = !stillHas;
        if unregistered {
            ArrayErase(this.m_ids, last);
            ArrayErase(this.m_nemesisIds, last);
            ArrayErase(this.m_levels, last);
        }
        GRLog("Recompensas: quitar Jefe #" + IntToString(nemesisId) + " " + this.DescribeId(id) + " V la tenia=" + this.BoolText(hadIt)
            + " RemoveItem=" + this.BoolText(removed) + " V la sigue teniendo=" + this.BoolText(stillHas)
            + " sacada del registro=" + this.BoolText(unregistered) + " (quedan " + IntToString(ArraySize(this.m_ids)) + ")");
    }

    // Deja m_nemesisIds y m_levels del mismo largo que m_ids (las armas de la prueba vieja no tenian Jefe y las de
    // antes del Aumento no tenian nivel: se rellenan con 0).
    private func SyncLists() -> Void {
        while ArraySize(this.m_nemesisIds) < ArraySize(this.m_ids) {
            ArrayPush(this.m_nemesisIds, 0);
        }
        while ArraySize(this.m_nemesisIds) > ArraySize(this.m_ids) {
            ArrayPop(this.m_nemesisIds);
        }
        while ArraySize(this.m_levels) < ArraySize(this.m_ids) {
            ArrayPush(this.m_levels, 0);
        }
        while ArraySize(this.m_levels) > ArraySize(this.m_ids) {
            ArrayPop(this.m_levels);
        }
    }

    private func WeaponForGang(gang: String) -> TweakDBID {
        if Equals(gang, "Maelstrom") {
            return t"Items.Preset_Carnage_Default";
        }
        if Equals(gang, "TygerClaws") {
            return t"Items.Preset_Katana_Default";
        }
        if Equals(gang, "Valentinos") {
            return t"Items.Preset_Overture_Default";
        }
        if Equals(gang, "SixthStreet") {
            return t"Items.Preset_Copperhead_Military";
        }
        if Equals(gang, "Animals") {
            return t"Items.Preset_Hammer_Default";
        }
        if Equals(gang, "VoodooBoys") {
            return t"Items.Preset_Yukimura_Default";
        }
        if Equals(gang, "Wraiths") {
            return t"Items.Preset_Tactician_Default";
        }
        if Equals(gang, "Scavengers") {
            return t"Items.Preset_Saratoga_Default";
        }
        if Equals(gang, "Barghest") {
            return t"Items.Preset_Ajax_Default";
        }
        return TDBID.None();
    }

    // 0 = Electrico, 1 = Termico, 2 = Quimico. Sale de las fortalezas elementales del Jefe; si no tiene ninguna, de las tres.
    private func PickElement(traitsCsv: String, pick: Int32) -> Int32 {
        let options: array<Int32>;
        let keys: array<String> = StrSplit(traitsCsv, ",");
        let i: Int32 = 0;
        while i < ArraySize(keys) {
            let key: String = keys[i];
            if Equals(key, "insulated") && !ArrayContains(options, 0) {
                ArrayPush(options, 0);
            }
            if Equals(key, "fireproof") && !ArrayContains(options, 1) {
                ArrayPush(options, 1);
            }
            if Equals(key, "toxproof") && !ArrayContains(options, 2) {
                ArrayPush(options, 2);
            }
            i += 1;
        }
        if ArraySize(options) == 0 {
            ArrayPush(options, 0);
            ArrayPush(options, 1);
            ArrayPush(options, 2);
        }
        return options[pick % ArraySize(options)];
    }

    private func NameForNemesis(nemesisId: Int32, id: ItemID) -> String {
        if nemesisId <= 0 {
            return "";
        }
        let i: Int32 = 0;
        while i < ArraySize(this.m_nameIds) {
            if this.m_nameIds[i] == nemesisId {
                if i < ArraySize(this.m_names) && StrLen(this.m_names[i]) > 0 {
                    return this.FormatName(this.m_names[i], this.WeaponBaseName(id));
                }
                return "";
            }
            i += 1;
        }
        return "";
    }

    // Nombre del juego para el arma base ("Carnage"). Nativo: no pasa por nuestros wraps.
    private func WeaponBaseName(id: ItemID) -> String {
        return this.RecordBaseName(ItemID.GetTDBID(id));
    }

    private func RecordBaseName(recordID: TweakDBID) -> String {
        let record: ref<Item_Record> = TweakDBInterface.GetItemRecord(recordID);
        if !IsDefined(record) {
            return "";
        }
        return GetLocalizedItemNameByCName(record.DisplayName());
    }

    private func FormatName(boss: String, weapon: String) -> String {
        let format: String = "";
        let core: ref<GRSystem> = GRSystem.Get(this.GetGameInstance());
        if IsDefined(core) {
            format = core.GetText("GR-WeaponName");
        }
        // Si la localizacion no esta lista devuelve la clave: se usa el formato en ingles.
        if !StrContains(format, "{weapon}") || !StrContains(format, "{boss}") {
            format = "{boss}'s {weapon}";
        }
        let withWeapon: String = StrReplace(format, "{weapon}", weapon);
        return StrReplace(withWeapon, "{boss}", boss);
    }

    private func ElementStat(element: Int32) -> gamedataStatType {
        if element == 1 {
            return gamedataStatType.ThermalDamage;
        }
        if element == 2 {
            return gamedataStatType.ChemicalDamage;
        }
        return gamedataStatType.ElectricDamage;
    }

    private func ElementName(element: Int32) -> String {
        if element == 1 {
            return "ThermalDamage";
        }
        if element == 2 {
            return "ChemicalDamage";
        }
        return "ElectricDamage";
    }

    // Para el log: un arma puede no tener elemento.
    private func ElementLabel(element: Int32) -> String {
        if element < 0 || element > 2 {
            return "ninguno";
        }
        return this.ElementName(element);
    }

    private func ElementRateStat(element: Int32) -> gamedataStatType {
        if element == 1 {
            return gamedataStatType.BurningApplicationRate;
        }
        if element == 2 {
            return gamedataStatType.PoisonedApplicationRate;
        }
        return gamedataStatType.ElectrocutedApplicationRate;
    }

    private func ElementRateName(element: Int32) -> String {
        if element == 1 {
            return "BurningApplicationRate";
        }
        if element == 2 {
            return "PoisonedApplicationRate";
        }
        return "ElectrocutedApplicationRate";
    }

    // -------------------------------------------------------------------------
    // Tooltip del inventario
    // -------------------------------------------------------------------------
    // Linea con el bono elemental de un arma de Jefe ("+23% Dano termico"). null si el arma no es nuestra
    // (GetCustomName vacio) o no tiene elemento. El juego ya muestra la probabilidad del estado (los
    // ApplicationRate estan en UIMaps.Wea_*.tooltipStats), pero el dano elemental no esta en esa lista.
    // El numero es el mismo que muestra Arsenal (WeaponBonus).
    public func MakeTooltipStat(data: wref<gameItemData>) -> ref<GRElementStat> {
        if !IsDefined(data) || StrLen(this.GetCustomName(data.GetID())) == 0 {
            return null;
        }
        let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(this.GetGameInstance());
        let element: Int32 = this.WeaponElement(data, stats);
        if element < 0 {
            return null;
        }
        let bonus: Float = this.WeaponBonus(data, stats, element);
        if bonus <= 0.0 {
            return null;
        }
        let label: String = this.ElementDamageLabel(element);
        let stat: ref<GRElementStat> = new GRElementStat();
        stat.element = element;
        stat.rateType = this.ElementRateStat(element);
        // No puede ser ElectricDamage/ThermalDamage/ChemicalDamage: el tooltip las dibuja como rango "min-max".
        stat.Type = this.ElementPercentStat(element);
        stat.Value = bonus;
        // nombre, 1 decimal, con "%", con "+"; el resto apagado.
        stat.SetProperties(UIItemStatProperties.Make(label, 1, true, true, false, false, false, false, false, -1.0, false));
        // Una vez por arma cada vez que el inventario arma su tooltip.
        GRLog("Recompensas: tooltip +" + FloatToStringPrec(bonus, 1) + "% " + this.ElementName(element) + " en " + this.DescribeId(data.GetID()));
        return stat;
    }

    private func ElementPercentStat(element: Int32) -> gamedataStatType {
        if element == 1 {
            return gamedataStatType.ThermalDamagePercentBonus;
        }
        if element == 2 {
            return gamedataStatType.ChemicalDamagePercentBonus;
        }
        return gamedataStatType.ElectricDamagePercentBonus;
    }

    // "Dano termico", con las mismas claves que Arsenal. Si la localizacion no esta lista devuelve la clave: va en ingles.
    private func ElementDamageLabel(element: Int32) -> String {
        let key: String = "GR-MenuDmg-" + IntToString(element);
        let text: String = "";
        let core: ref<GRSystem> = GRSystem.Get(this.GetGameInstance());
        if IsDefined(core) {
            text = core.GetText(key);
        }
        if StrLen(text) > 0 && !Equals(text, key) {
            return text;
        }
        if element == 1 {
            return "Thermal damage";
        }
        if element == 2 {
            return "Chemical damage";
        }
        return "Electrical damage";
    }

    private func BoolText(value: Bool) -> String {
        if value {
            return "true";
        }
        return "false";
    }

    // Varias armas pueden compartir TDBID; seed y hash distinguen cada instancia.
    private func DescribeId(id: ItemID) -> String {
        return "id=" + TDBID.ToStringDEBUG(ItemID.GetTDBID(id)) + " seed=" + ToString(ItemID.GetRngSeed(id)) + " hash=" + ToString(ItemID.GetCombinedHash(id));
    }

    // Lo que dice el item; si da 0 (puede no estar inicializado), lo que dice el StatsSystem.
    private func ReadStat(data: wref<gameItemData>, stats: ref<StatsSystem>, stat: gamedataStatType) -> Float {
        let fromItem: Float = data.GetStatValueByType(stat);
        if fromItem > 0.0 {
            return fromItem;
        }
        return stats.GetStatValue(data.GetStatsObjectID(), stat);
    }

    // Cada stat se loguea dos veces (item/sistema): tienen que coincidir, tambien despues de guardar y cargar.
    private func DescribeStat(label: String, data: wref<gameItemData>, stats: ref<StatsSystem>, stat: gamedataStatType) -> String {
        return label + "=" + FloatToStringPrec(data.GetStatValueByType(stat), 2) + "/" + FloatToStringPrec(stats.GetStatValue(data.GetStatsObjectID(), stat), 2);
    }

    private func DescribeStats(data: wref<gameItemData>, stats: ref<StatsSystem>) -> String {
        return "stats item/sistema: " + this.DescribeStat("PowerLevel", data, stats, gamedataStatType.PowerLevel)
            + " " + this.DescribeStat("ItemLevel", data, stats, gamedataStatType.ItemLevel)
            + " " + this.DescribeStat("PhysicalDamage", data, stats, gamedataStatType.PhysicalDamage)
            + " " + this.DescribeStat("ElectricDamage", data, stats, gamedataStatType.ElectricDamage)
            + " " + this.DescribeStat("ThermalDamage", data, stats, gamedataStatType.ThermalDamage)
            + " " + this.DescribeStat("ChemicalDamage", data, stats, gamedataStatType.ChemicalDamage)
            + " " + this.DescribeStat("EffectiveDamagePerHit", data, stats, gamedataStatType.EffectiveDamagePerHit)
            + " " + this.DescribeStat("ElectrocutedApplicationRate", data, stats, gamedataStatType.ElectrocutedApplicationRate)
            + " " + this.DescribeStat("BurningApplicationRate", data, stats, gamedataStatType.BurningApplicationRate)
            + " " + this.DescribeStat("PoisonedApplicationRate", data, stats, gamedataStatType.PoisonedApplicationRate)
            + " IsItemIconic=" + this.BoolText(RPGManager.IsItemIconic(data));
    }
}

// Nombre propio de un arma de Jefe, o "" si no lo es o el sistema todavia no existe (menu principal).
public func GRRewardCustomName(id: ItemID) -> String {
    if !ItemID.IsValid(id) {
        return "";
    }
    let container: ref<ScriptableSystemsContainer> = GameInstance.GetScriptableSystemsContainer(GetGameInstance());
    if !IsDefined(container) {
        return "";
    }
    let rewards: ref<GRRewards> = container.Get(n"GangRetaliation.GRRewards") as GRRewards;
    if !IsDefined(rewards) {
        return "";
    }
    return rewards.GetCustomName(id);
}

// Inventario y tooltip nuevos. Se llama siempre al original primero para no cambiar su cache interna.
@wrapMethod(UIInventoryItem)
public final func GetName() -> String {
    let original: String = wrappedMethod();
    let custom: String = GRRewardCustomName(this.GetID());
    if StrLen(custom) > 0 {
        return custom;
    }
    return original;
}

// Botin, aviso de "objeto obtenido" y selector de cantidad pasan por aca.
@wrapMethod(UIItemsHelper)
public final static func GetItemName(itemRecord: ref<Item_Record>, itemData: wref<gameItemData>) -> String {
    let original: String = wrappedMethod(itemRecord, itemData);
    if !IsDefined(itemData) {
        return original;
    }
    let custom: String = GRRewardCustomName(itemData.GetID());
    if StrLen(custom) > 0 {
        return custom;
    }
    return original;
}

// Camino viejo de la UI (InventoryItemData): lo usan las ranuras de equipo del inventario y, con el mod
// Inventory Adjustments Hub, la etiqueta con el nombre del arma en la casilla.
@wrapMethod(InventoryItemData)
public final static func GetName(const self: script_ref<InventoryItemData>) -> String {
    let original: String = wrappedMethod(self);
    let custom: String = GRRewardCustomName(InventoryItemData.GetID(self));
    if StrLen(custom) > 0 {
        return custom;
    }
    return original;
}

// -------------------------------------------------------------------------
// Tooltip del inventario: bono elemental de las armas de Jefe
// -------------------------------------------------------------------------
// Linea extra del tooltip ("+23% Dano termico"). La clase propia sirve para reconocerla al pintarla.
public class GRElementStat extends UIInventoryItemStat {
    // 0 = Electrico, 1 = Termico, 2 = Quimico.
    public let element: Int32;
    // ApplicationRate de ese elemento: la linea va justo antes de la suya.
    public let rateType: gamedataStatType;
}

// La linea del tooltip para este item, o null si no es un arma de Jefe o el sistema todavia no existe.
public func GRRewardElementStat(data: wref<gameItemData>) -> ref<GRElementStat> {
    if !IsDefined(data) {
        return null;
    }
    let container: ref<ScriptableSystemsContainer> = GameInstance.GetScriptableSystemsContainer(GetGameInstance());
    if !IsDefined(container) {
        return null;
    }
    let rewards: ref<GRRewards> = container.Get(n"GangRetaliation.GRRewards") as GRRewards;
    if !IsDefined(rewards) {
        return null;
    }
    return rewards.MakeTooltipStat(data);
}

// Los mismos colores que el menu (GRNemesisMenuController.ElementColor). 0 = Electrico, 1 = Termico, 2 = Quimico.
public func GRElementColor(element: Int32) -> HDRColor {
    if element == 1 {
        return new HDRColor(1.0, 0.6, 0.239, 1.0);
    }
    if element == 2 {
        return new HDRColor(0.478, 0.851, 0.361, 1.0);
    }
    return new HDRColor(0.435, 0.659, 1.0, 1.0);
}

@addField(UIInventoryItemStatsManager)
private let m_grElementChecked: Bool;

// El tooltip siempre pregunta primero cuantas stats tiene: ahi se suma la nuestra, una sola vez por arma.
// No se engancha en FetchTooltipStats porque Inventory Adjustments Hub lo envuelve y, segun su ajuste,
// no llama al original (nuestro wrap podria no correr nunca).
@wrapMethod(UIInventoryItemStatsManager)
public final func SizeTooltipStats() -> Int32 {
    let size: Int32 = wrappedMethod();
    if this.m_grElementChecked {
        return size;
    }
    this.m_grElementChecked = true;
    let stat: ref<GRElementStat> = GRRewardElementStat(this.m_gameItemData);
    if !IsDefined(stat) {
        return size;
    }
    // Justo antes de la probabilidad de su estado; si esa linea no esta, al final.
    let at: Int32 = -1;
    let i: Int32 = 0;
    while i < size && i < ArraySize(this.TooltipStats) && at < 0 {
        if Equals(this.TooltipStats[i].Type, stat.rateType) {
            at = i;
        }
        i += 1;
    }
    if at < 0 {
        ArrayPush(this.TooltipStats, stat);
    } else {
        ArrayInsert(this.TooltipStats, at, stat);
    }
    return ArraySize(this.TooltipStats);
}

// Pinta nuestra linea con el color del elemento. Las filas del tooltip se crean de nuevo en cada
// actualizacion, asi que el color no queda pegado en otra stat.
@wrapMethod(ItemTooltipStatController)
public final func SetData(data: wref<UIInventoryItemStat>) -> Void {
    wrappedMethod(data);
    let ours: wref<GRElementStat> = data as GRElementStat;
    if !IsDefined(ours) {
        return;
    }
    let color: HDRColor = GRElementColor(ours.element);
    let name: wref<inkWidget> = inkTextRef.Get(this.m_statName);
    if IsDefined(name) {
        name.UnbindProperty(n"tintColor");
        name.SetTintColor(color);
    }
    let value: wref<inkWidget> = inkTextRef.Get(this.m_statValue);
    if IsDefined(value) {
        value.UnbindProperty(n"tintColor");
        value.SetTintColor(color);
    }
}
