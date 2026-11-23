module GangRetaliation

public class GRRewards extends ScriptableSystem {
    private persistent let m_ids: array<ItemID>;
    private persistent let m_nemesisIds: array<Int32>;
    private persistent let m_given: array<Int32>;
    private persistent let m_levels: array<Int32>;
    private persistent let m_stashed: array<Int32>;
    private persistent let m_stElement: array<Int32>;
    private persistent let m_stBonus: array<Float>;
    private persistent let m_stDamage: array<Float>;
    private persistent let m_stQuality: array<Int32>;
    private persistent let m_stPlus: array<Int32>;

    private let m_nameIds: array<Int32>;
    private let m_names: array<String>;

    private let m_pvElement: Int32;
    private let m_pvBonus: Int32;
    private let m_fusedIndex: Int32;

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
    private let m_oStashed: array<Bool>;

    public static func Get(gi: GameInstance) -> ref<GRRewards> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRRewards") as GRRewards;
    }

    public func GetRegisteredCount() -> Int32 {
        return ArraySize(this.m_ids);
    }

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
        if ArraySize(this.m_nameIds) != ArraySize(this.m_names) {
            this.ClearNames();
        }
        ArrayPush(this.m_nameIds, nemesisId);
        ArrayPush(this.m_names, name);
    }

    public func HasGiven(nemesisId: Int32) -> Bool {
        return ArrayContains(this.m_given, nemesisId);
    }

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

        let ok: Bool = stats.AddSavedModifier(objID, RPGManager.CreateStatModifier(gamedataStatType.IsItemIconic, gameStatModifierType.Additive, 1.0));

        let playerLevel: Float = stats.GetStatValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatType.PowerLevel);
        stats.RemoveAllModifiers(objID, gamedataStatType.PowerLevel, true);
        if !stats.AddSavedModifier(objID, RPGManager.CreateStatModifier(gamedataStatType.PowerLevel, gameStatModifierType.Additive, playerLevel)) {
            ok = false;
        }

        let baseName: String = this.BaseDamageName(data, stats);
        let baseValue: Float = this.BaseDamage(data, stats);
        let bonus: Float = baseValue * bonusPct / 100.0;
        if !stats.AddSavedModifier(objID, RPGManager.CreateStatModifier(this.ElementStat(element), gameStatModifierType.Additive, bonus)) {
            ok = false;
        }

        if !stats.AddSavedModifier(objID, RPGManager.CreateStatModifier(this.ElementRateStat(element), gameStatModifierType.Additive, bonusPct)) {
            ok = false;
        }

        this.SyncLists();
        ArrayPush(this.m_ids, id);
        ArrayPush(this.m_nemesisIds, nemesisId);
        ArrayPush(this.m_levels, 1);
        this.PushStashEntry();
        if !ArrayContains(this.m_given, nemesisId) {
            ArrayPush(this.m_given, nemesisId);
        }

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

        let removed: Bool = ts.RemoveItem(player, copyId, 1);
        if ts.HasItem(player, copyId) {
            GRLog("Recompensas: Aumento ERROR, no se pudo destruir la copia (RemoveItem=" + this.BoolText(removed) + "): sigue registrada y el arma no cambia. "
                + copyText);
            return false;
        }
        ArrayErase(this.m_ids, copyReg);
        ArrayErase(this.m_nemesisIds, copyReg);
        ArrayErase(this.m_levels, copyReg);
        this.EraseStashEntry(copyReg);
        if copyReg < mainReg {
            mainReg -= 1;
        }

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

    public func GetFusedIndex() -> Int32 {
        return this.m_fusedIndex;
    }

    public func FusedBonus(mainBonus: Float, copyBonus: Float) -> Float {
        return MinF(60.0, Cast<Float>(RoundF(MaxF(mainBonus, copyBonus) * 11.0)) / 10.0);
    }

    public func FusedLevel(mainLevel: Int32, copyLevel: Int32) -> Int32 {
        return Min(5, Max(mainLevel, copyLevel) + 1);
    }

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

    private func LevelAt(index: Int32) -> Int32 {
        if index < 0 || index >= ArraySize(this.m_levels) {
            return 1;
        }
        return Min(5, Max(1, this.m_levels[index]));
    }

    private func IsMaxed(level: Int32, bonus: Float) -> Bool {
        return level >= 5 && bonus >= 59.95;
    }

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

    private func WeaponBonus(data: wref<gameItemData>, stats: ref<StatsSystem>, element: Int32) -> Float {
        if element < 0 {
            return 0.0;
        }
        return this.ReadStat(data, stats, this.ElementRateStat(element));
    }

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

    private func SeedFor(nemesisId: Int32) -> Int32 {
        return ((nemesisId % 100000) * 7919 + 104729) % 1000003;
    }

    private func RollElement(nemesisId: Int32, traitsCsv: String) -> Int32 {
        return this.PickElement(traitsCsv, this.SeedFor(nemesisId) / 21);
    }

    private func RollBonus(nemesisId: Int32, escapes: Int32) -> Int32 {
        let pct: Int32 = 20 + (this.SeedFor(nemesisId) % 21) + 2 * Max(escapes, 0);
        if pct > 60 {
            pct = 60;
        }
        return pct;
    }

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

    public func GetGangWeaponBaseName(gang: String) -> String {
        return this.RecordBaseName(this.WeaponForGang(gang));
    }

    public func GetGangWeaponType(gang: String) -> String {
        let record: ref<Item_Record> = TweakDBInterface.GetItemRecord(this.WeaponForGang(gang));
        if !IsDefined(record) || !IsDefined(record.ItemType()) {
            return "";
        }
        return GetLocalizedText(UIItemsHelper.GetItemTypeKey(record.ItemType().Type()));
    }

    public func GetBossWeaponName(boss: String, gang: String) -> String {
        return this.FormatName(boss, this.GetGangWeaponBaseName(gang));
    }

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
        ArrayClear(this.m_oStashed);
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
                ArrayPush(this.m_oStashed, false);
                if this.StashKindAt(i) > 0 {
                    this.m_stashed[i] = 0;
                    GRLog("Recompensas: alijo, V volvio a tener #" + IntToString(i) + " " + this.DescribeId(id) + ", se borra la marca de alijo");
                }
            } else {
                let kind: Int32 = this.StashKindAt(i);
                if kind > 0 && i < ArraySize(this.m_stElement) && i < ArraySize(this.m_stBonus) && i < ArraySize(this.m_stDamage)
                    && i < ArraySize(this.m_stQuality) && i < ArraySize(this.m_stPlus) {
                    let cachedElement: Int32 = this.m_stElement[i] - 1;
                    let cachedBonus: Float = this.m_stBonus[i];
                    let cachedTier: String = GetLocalizedText(UIItemsHelper.QualityToTierString(IntEnum<gamedataQuality>(this.m_stQuality[i])));
                    let cachedPlus: Int32 = this.m_stPlus[i];
                    while cachedPlus > 0 {
                        cachedTier += "+";
                        cachedPlus -= 1;
                    }
                    ArrayPush(this.m_oIds, id);
                    ArrayPush(this.m_oNemesis, i < ArraySize(this.m_nemesisIds) ? this.m_nemesisIds[i] : 0);
                    ArrayPush(this.m_oGangs, this.GangForRecord(ItemID.GetTDBID(id)));
                    ArrayPush(this.m_oElements, cachedElement);
                    ArrayPush(this.m_oBonus, RoundF(cachedBonus));
                    ArrayPush(this.m_oBonusF, cachedBonus);
                    ArrayPush(this.m_oLevels, this.LevelAt(i));
                    ArrayPush(this.m_oDamage, this.m_stDamage[i]);
                    ArrayPush(this.m_oTiers, cachedTier);
                    ArrayPush(this.m_oEquipped, false);
                    ArrayPush(this.m_oStashed, true);
                    GRLog("Recompensas: alijo, #" + IntToString(i) + " " + this.DescribeId(id) + " sale por cache (" + this.StashKindName(kind)
                        + ") elemento=" + this.ElementLabel(cachedElement) + " bono=" + FloatToStringPrec(cachedBonus, 1) + "% dano="
                        + FloatToStringPrec(this.m_stDamage[i], 1) + " calidad=" + cachedTier);
                }
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

    public func GetOwnedGang(index: Int32) -> String {
        return this.OwnedValid(index) ? this.m_oGangs[index] : "";
    }

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

    public func GetOwnedElement(index: Int32) -> Int32 {
        return this.OwnedValid(index) ? this.m_oElements[index] : -1;
    }

    public func GetOwnedBonus(index: Int32) -> Int32 {
        return this.OwnedValid(index) ? this.m_oBonus[index] : 0;
    }

    public func GetOwnedBonusF(index: Int32) -> Float {
        return this.OwnedValid(index) ? this.m_oBonusF[index] : 0.0;
    }

    public func GetOwnedLevel(index: Int32) -> Int32 {
        return this.OwnedValid(index) ? this.m_oLevels[index] : 1;
    }

    public func IsOwnedMaxed(index: Int32) -> Bool {
        return this.OwnedValid(index) && this.IsMaxed(this.m_oLevels[index], this.m_oBonusF[index]);
    }

    public func GetOwnedDamage(index: Int32) -> Float {
        return this.OwnedValid(index) ? this.m_oDamage[index] : 0.0;
    }

    public func GetOwnedTier(index: Int32) -> String {
        return this.OwnedValid(index) ? this.m_oTiers[index] : "";
    }

    public func IsOwnedEquipped(index: Int32) -> Bool {
        return this.OwnedValid(index) && this.m_oEquipped[index];
    }

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

    public func GetOwnedIconAspect(index: Int32) -> Float {
        return this.OwnedValid(index) ? this.IconAspect(ItemID.GetTDBID(this.m_oIds[index])) : 2.5;
    }

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
            this.EraseStashEntry(last);
        }
        GRLog("Recompensas: quitar Jefe #" + IntToString(nemesisId) + " " + this.DescribeId(id) + " V la tenia=" + this.BoolText(hadIt)
            + " RemoveItem=" + this.BoolText(removed) + " V la sigue teniendo=" + this.BoolText(stillHas)
            + " sacada del registro=" + this.BoolText(unregistered) + " (quedan " + IntToString(ArraySize(this.m_ids)) + ")");
    }

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
        this.SyncStashLists();
    }

    private func SyncStashLists() -> Void {
        let count: Int32 = ArraySize(this.m_ids);
        let ok: Bool = ArraySize(this.m_stashed) == count && ArraySize(this.m_stElement) == count && ArraySize(this.m_stBonus) == count
            && ArraySize(this.m_stDamage) == count && ArraySize(this.m_stQuality) == count && ArraySize(this.m_stPlus) == count;
        if ok {
            return;
        }
        while ArraySize(this.m_stashed) > count {
            ArrayPop(this.m_stashed);
        }
        while ArraySize(this.m_stElement) > count {
            ArrayPop(this.m_stElement);
        }
        while ArraySize(this.m_stBonus) > count {
            ArrayPop(this.m_stBonus);
        }
        while ArraySize(this.m_stDamage) > count {
            ArrayPop(this.m_stDamage);
        }
        while ArraySize(this.m_stQuality) > count {
            ArrayPop(this.m_stQuality);
        }
        while ArraySize(this.m_stPlus) > count {
            ArrayPop(this.m_stPlus);
        }
        while ArraySize(this.m_stashed) < count {
            ArrayPush(this.m_stashed, 0);
        }
        while ArraySize(this.m_stElement) < count {
            ArrayPush(this.m_stElement, 0);
        }
        while ArraySize(this.m_stBonus) < count {
            ArrayPush(this.m_stBonus, 0.0);
        }
        while ArraySize(this.m_stDamage) < count {
            ArrayPush(this.m_stDamage, 0.0);
        }
        while ArraySize(this.m_stQuality) < count {
            ArrayPush(this.m_stQuality, 0);
        }
        while ArraySize(this.m_stPlus) < count {
            ArrayPush(this.m_stPlus, 0);
        }
    }

    private func PushStashEntry() -> Void {
        ArrayPush(this.m_stashed, 0);
        ArrayPush(this.m_stElement, 0);
        ArrayPush(this.m_stBonus, 0.0);
        ArrayPush(this.m_stDamage, 0.0);
        ArrayPush(this.m_stQuality, 0);
        ArrayPush(this.m_stPlus, 0);
    }

    private func EraseStashEntry(index: Int32) -> Void {
        if index < 0 {
            return;
        }
        if index < ArraySize(this.m_stashed) {
            ArrayErase(this.m_stashed, index);
        }
        if index < ArraySize(this.m_stElement) {
            ArrayErase(this.m_stElement, index);
        }
        if index < ArraySize(this.m_stBonus) {
            ArrayErase(this.m_stBonus, index);
        }
        if index < ArraySize(this.m_stDamage) {
            ArrayErase(this.m_stDamage, index);
        }
        if index < ArraySize(this.m_stQuality) {
            ArrayErase(this.m_stQuality, index);
        }
        if index < ArraySize(this.m_stPlus) {
            ArrayErase(this.m_stPlus, index);
        }
    }

    private func StashKindAt(index: Int32) -> Int32 {
        if index < 0 || index >= ArraySize(this.m_stashed) {
            return 0;
        }
        return this.m_stashed[index];
    }

    private func StashKindName(kind: Int32) -> String {
        if kind == 2 {
            return "baul del auto";
        }
        return "alijo";
    }

    public func SyncStash(storage: ref<GameObject>, kind: Int32) -> Void {
        if !IsDefined(storage) || kind <= 0 {
            return;
        }
        let gi: GameInstance = this.GetGameInstance();
        let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(gi);
        let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(gi);
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        let items: array<wref<gameItemData>>;
        if !ts.GetItemList(storage, items) {
            GRLog("Recompensas: alijo, no se pudo leer la lista del " + this.StashKindName(kind) + " (GetItemList=false), no se cambia nada");
            return;
        }
        // Easter egg de Rogue: si la replica esta guardada aca, ya la tiene (no se vuelve a ofrecer).
        let record: TweakDBID = GRBounties.SilverhandRecord();
        let scan: Int32 = 0;
        while scan < ArraySize(items) {
            let scanned: wref<gameItemData> = items[scan];
            if IsDefined(scanned) && ItemID.GetTDBID(scanned.GetID()) == record {
                let bounties: ref<GRBounties> = GRBounties.Get(gi);
                if IsDefined(bounties) {
                    bounties.NoteSilverhandSeen(this.StashKindName(kind));
                }
            }
            scan += 1;
        }
        this.SyncLists();
        let found: Int32 = 0;
        let removed: Int32 = 0;
        let idsText: String = "";
        let itemCount: Int32 = ArraySize(items);
        let i: Int32 = 0;
        while i < ArraySize(this.m_ids) {
            let id: ItemID = this.m_ids[i];
            let data: wref<gameItemData>;
            let k: Int32 = 0;
            while k < itemCount && !IsDefined(data) {
                let candidate: wref<gameItemData> = items[k];
                if IsDefined(candidate) && candidate.GetID() == id {
                    data = candidate;
                }
                k += 1;
            }
            if IsDefined(data) {
                let element: Int32 = this.WeaponElement(data, stats);
                this.m_stashed[i] = kind;
                this.m_stElement[i] = element + 1;
                this.m_stBonus[i] = this.WeaponBonus(data, stats, element);
                this.m_stDamage[i] = this.ReadStat(data, stats, gamedataStatType.EffectiveDamagePerHit);
                let quality: gamedataQuality = RPGManager.GetItemQuality(data);
                this.m_stQuality[i] = EnumInt(quality);
                this.m_stPlus[i] = RoundF(RPGManager.GetItemPlus(data));
                found += 1;
                if StrLen(idsText) > 0 {
                    idsText += ", ";
                }
                idsText += "#" + IntToString(i) + " " + this.DescribeId(id);
            } else {
                let mine: Bool = this.m_stashed[i] == kind || (this.m_stashed[i] > 0 && IsDefined(player) && ts.HasItem(player, id));
                if mine && this.m_stashed[i] > 0 {
                    this.m_stashed[i] = 0;
                    removed += 1;
                }
            }
            i += 1;
        }
        GRLog("Recompensas: alijo sincronizado (" + this.StashKindName(kind) + ", " + IntToString(itemCount) + " objetos), "
            + IntToString(found) + " de " + IntToString(ArraySize(this.m_ids)) + " arma(s) registrada(s) estan ahi"
            + (removed > 0 ? ", " + IntToString(removed) + " ya no estan" : "") + (found > 0 ? ": " + idsText : ""));
    }

    public func IsOwnedStashed(index: Int32) -> Bool {
        return this.OwnedValid(index) && this.m_oStashed[index];
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
        stat.Type = this.ElementPercentStat(element);
        stat.Value = bonus;
        stat.SetProperties(UIItemStatProperties.Make(label, 1, true, true, false, false, false, false, false, -1.0, false));
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

    private func DescribeId(id: ItemID) -> String {
        return "id=" + TDBID.ToStringDEBUG(ItemID.GetTDBID(id)) + " seed=" + ToString(ItemID.GetRngSeed(id)) + " hash=" + ToString(ItemID.GetCombinedHash(id));
    }

    private func ReadStat(data: wref<gameItemData>, stats: ref<StatsSystem>, stat: gamedataStatType) -> Float {
        let fromItem: Float = data.GetStatValueByType(stat);
        if fromItem > 0.0 {
            return fromItem;
        }
        return stats.GetStatValue(data.GetStatsObjectID(), stat);
    }

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

@wrapMethod(UIInventoryItem)
public final func GetName() -> String {
    let original: String = wrappedMethod();
    let custom: String = GRRewardCustomName(this.GetID());
    if StrLen(custom) > 0 {
        return custom;
    }
    return original;
}

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

@wrapMethod(InventoryItemData)
public final static func GetName(const self: script_ref<InventoryItemData>) -> String {
    let original: String = wrappedMethod(self);
    let custom: String = GRRewardCustomName(InventoryItemData.GetID(self));
    if StrLen(custom) > 0 {
        return custom;
    }
    return original;
}

public class GRElementStat extends UIInventoryItemStat {
    public let element: Int32;
    public let rateType: gamedataStatType;
}

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

@wrapMethod(FullscreenVendorGameController)
private final func RemoveBB() -> Void {
    if IsDefined(this.m_storageUserData) && IsDefined(this.m_storageUserData.storageObject) {
        let storage: ref<GameObject> = this.m_storageUserData.storageObject;
        let kind: Int32 = 0;
        if storage.IsPlayerStash() {
            kind = 1;
        } else {
            let vehicle: ref<VehicleObject> = storage as VehicleObject;
            if IsDefined(vehicle) && vehicle.IsPlayerVehicle() {
                kind = 2;
            }
        }
        if kind > 0 {
            let rewards: ref<GRRewards> = GRRewards.Get(storage.GetGame());
            if IsDefined(rewards) {
                rewards.SyncStash(storage, kind);
            }
        }
    }
    wrappedMethod();
}

public class GRBounty {
    public let index: Int32;
    public let nemesisId: Int32;
    public let fixer: Int32;
    public let cond: Int32;
    public let pay: Int32;
    public let expire: Int32;
    public let state: Int32;
    public let bonus: Int32;
    public let bonusUsed: Bool;
    public let rank: Int32;
    public let gang: String;
    public let reason: Int32;
    public let paid: Int32;
    public let msg: Int32;
    public let offerDay: Int32;
    public let closeDay: Int32;
    public let xp: Int32;
    public let zone: Int32;
    public let special: Bool;
}

public class GRBountyZone {
    public let nemesisId: Int32;
    public let kind: Int32;
    public let center: NewMappinID;
    public let hasCenter: Bool;
    public let ring: array<NewMappinID>;
    public let circle: NewMappinID;
    public let hasCircle: Bool;
    public let circleChecked: Bool;
    public let centerBlocked: Bool;
    public let cx: Float;
    public let cy: Float;
    public let cz: Float;
    public let radius: Float;
}

public class GRBountyZoneMappinData extends MappinScriptData {
    public let nemesisId: Int32;
    public let center: Bool;
    public let boss: Bool;
    public let name: String;
    private let m_loggedMap: Bool;
    private let m_loggedMinimap: Bool;
    private let m_loggedTooltip: Bool;

    public static func Of(mappin: wref<IMappin>) -> wref<GRBountyZoneMappinData> {
        if !IsDefined(mappin) {
            return null;
        }
        return mappin.GetScriptData() as GRBountyZoneMappinData;
    }

    public func IconPart() -> CName {
        return this.center ? n"bounty_hunt" : n"undiscovered";
    }

    public func LogOnce(view: Int32) -> Void {
        if !this.center {
            return;
        }
        let what: String;
        if view == GRStrongholdMappinData.ViewMap() {
            if this.m_loggedMap {
                return;
            }
            this.m_loggedMap = true;
            what = "pin central en el mapa grande";
        } else if view == GRStrongholdMappinData.ViewMinimap() {
            if this.m_loggedMinimap {
                return;
            }
            this.m_loggedMinimap = true;
            what = "pin central en el minimapa";
        } else if view == GRStrongholdMappinData.ViewTooltip() {
            if this.m_loggedTooltip {
                return;
            }
            this.m_loggedTooltip = true;
            what = "tooltip propio en el mapa";
        } else {
            return;
        }
        GRLog("Zona #" + IntToString(this.nemesisId) + ": " + what);
    }
}

// Datos del mappin del circulo de la zona en el MINIMAPA (truco de dispositivos): hereda GameplayRoleMappinData para que el minimapa lo
// maneje con MinimapDeviceMappinController, que dibuja un circulo de radio m_range cuando m_showOnMiniMap + m_isCurrentTarget + textura valida.
public class GRZoneCircleData extends GameplayRoleMappinData {
    public let nemesisId: Int32;
    public let updates: Int32;
    public let poiHit: Int32;
    // V esta dentro del circulo (lo actualiza GRBounties.UpdateZone); el wrap de MinimapDeviceMappinController.Update tine el circulo segun esto.
    public let inside: Bool;
    // Modo de color (ver GRBounties.ZoneColorModeName): 0 sin cambio, 1 bind+tinte, 2 solo tinte, 3 solo bind, 4 solo estado Quest, 5 bind+tinte+estado Quest, 6 bind+tinte+raiz.
    public let colorMode: Int32;
    // Pedido de DevZoneColorMode: el proximo Update limpia lo aplicado por el modo anterior antes de aplicar el nuevo.
    public let colorDirty: Bool;

    // Cambia el estado dentro/fuera; en los modos con estado Quest (4 y 5) tambien el estado visual del minimapa (Quest = icono amarillo dentro / base fuera).
    public func SetInside(value: Bool) -> Void {
        this.inside = value;
        this.m_isQuest = value && GRZoneCircleData.UsesQuestState(this.colorMode);
    }

    public func SetColorMode(mode: Int32) -> Void {
        this.colorMode = mode;
        this.colorDirty = true;
        this.m_isQuest = this.inside && GRZoneCircleData.UsesQuestState(mode);
    }

    public static func UsesQuestState(mode: Int32) -> Bool {
        return mode == 4 || mode == 5;
    }

    // Modos que cambian el binding del tinte del circulo al estilo MainColors.* (lo que hace el propio juego con BindProperty).
    public static func UsesBind(mode: Int32) -> Bool {
        return mode == 1 || mode == 3 || mode == 5 || mode == 6;
    }

    // Modos que ademas fijan el valor del tinte con SetTintColor.
    public static func UsesTint(mode: Int32) -> Bool {
        return mode == 1 || mode == 2 || mode == 5 || mode == 6;
    }

    // Tinte original del circulo (el del juego), guardado la primera vez que el controlador lo actualiza, para restaurarlo al salir.
    public let baseTint: HDRColor;
    public let hasBase: Bool;
    public let tinted: Bool;
    public let rootTinted: Bool;
}

public class GRBounties extends ScriptableSystem {
    private persistent let m_ids: array<Int32>;
    private persistent let m_fixers: array<Int32>;
    private persistent let m_conds: array<Int32>;
    private persistent let m_pays: array<Int32>;
    private persistent let m_expires: array<Int32>;
    private persistent let m_states: array<Int32>;
    private persistent let m_bonuses: array<Int32>;
    private persistent let m_bonusUsed: array<Int32>;
    private persistent let m_ranks: array<Int32>;
    private persistent let m_gangs: array<Int32>;
    private persistent let m_reasons: array<Int32>;
    private persistent let m_paids: array<Int32>;
    private persistent let m_msgs: array<Int32>;
    private persistent let m_offerDays: array<Int32>;
    private persistent let m_closeDays: array<Int32>;
    private persistent let m_vDown: array<Int32>;
    private persistent let m_xps: array<Int32>;
    // Paralelo a m_ids: 1 = contrato ESPECIAL de Rogue (al cobrarlo se entrega la replica). 0 en contratos viejos (backfill en Repair).
    private persistent let m_specials: array<Int32>;
    private persistent let m_lastDay: Int32;
    // Easter egg de Rogue: true cuando el arma se entrego o cuando se vio que V ya la tiene (equipada, inventario o alijo). Una vez true no se vuelve a tirar.
    // Bool persistente: por defecto false, sirve tal cual para partidas viejas (no hace falta backfill en Repair).
    private persistent let m_silverhandGiven: Bool;
    // Zona de busqueda (paralelos a m_ids). m_zoneSets: 0 sin zona, 1 caza (punto real X/Y/Z + centro CX/CY absoluto),
    // 2 jefe en su guarida (CX/CY = desplazamiento del centro como fraccion del radio, sigue a la guarida).
    private persistent let m_zoneSets: array<Int32>;
    private persistent let m_zoneX: array<Float>;
    private persistent let m_zoneY: array<Float>;
    private persistent let m_zoneZ: array<Float>;
    private persistent let m_zoneCX: array<Float>;
    private persistent let m_zoneCY: array<Float>;

    private let m_zones: array<ref<GRBountyZone>>;
    // Modo de dibujo de la zona: 2 (por defecto) circulo nativo del minimapa + pin central de respaldo en el mapa grande cuando no lo marca el encargo;
    // 0 y 1 son modos dev con anillo de pines "?" (0 solo anillo, 1 anillo + circulo).
    // Se guarda modo+1 (0 = sin tocar = modo 2 por defecto).
    private let m_zoneModeP1: Int32;
    // Dev: true usa la definicion propia Mappins.GRZoneCircleMappinDefinition. Por defecto (false) el circulo usa Mappins.DeviceMappinDefinition del juego,
    // que es la unica que el minimapa toma comprobado (el icono del mundo 3D se oculta en GameplayMappinController.OnUpdate, Stronghold.reds).
    private let m_zoneCustom: Bool;
    // Dev: radio forzado del circulo del minimapa en metros (0 = radio real de la zona). Solo afecta al circulo, no al anillo.
    private let m_zoneForceRadius: Float;
    private let m_zoneTick: Int32;
    // Validacion del punto de caza contra la superficie (por id de Nemesis, nada se guarda: al cargar partida se revalida de cerca).
    // m_surfOk: validado con V cerca (m_zoneZ ya es la Z del suelo). m_surfTop: superficie mas alta medida (0 = sin datos). m_surfPoiZ: Z original del POI.
    private let m_surfIds: array<Int32>;
    private let m_surfOk: array<Bool>;
    private let m_surfTop: array<Float>;
    private let m_surfPoiZ: array<Float>;
    private let m_surfWait: Int32;
    // Dev: modo de color del circulo (DevZoneColorMode). Se guarda modo+1 (0 = sin tocar = GRBounties.ZoneColorModeDefault()).
    private let m_colorModeP1: Int32;

    // Encargo nativo del journal (GigZone.reds), 1 ranura. Nada de esto se guarda: al cargar partida se rearma solo
    // desde el primer contrato aceptado (sin aviso).
    private let m_gigShown: Int32;
    private let m_gigFor: Int32;
    private let m_gigStep: Int32;
    private let m_gigStepAt: Float;
    private let m_gigDue: Float;
    private let m_gigNotify: Bool;
    private let m_gigLoud: Bool;
    private let m_gigSuppress: Bool;
    private let m_gigChecked: Bool;
    private let m_gigX: Float;
    private let m_gigY: Float;
    // Chequeo de pines duplicados del encargo (GRGigZone.PinReport): hora del proximo chequeo y cuantos quedan tras mostrarse el encargo.
    private let m_gigPinAt: Float;
    private let m_gigPinChecks: Int32;

    // Dev: viaje por etapas de DevZoneGoForce (nada se guarda).
    private let m_goBusy: Bool;
    private let m_goReport: String;

    private let m_pending: array<String>;
    private let m_pendingFrom: array<String>;
    private let m_pendingSms: array<String>;
    private let m_pendingFixer: array<Int32>;
    private let m_pendingKind: array<Int32>;
    private let m_pendingId: array<Int32>;
    private let m_pendingAmount: array<Int32>;
    private let m_pendingXp: array<Int32>;
    private let m_pendingExtra: array<Int32>;
    private let m_notifyAt: Float;
    // Dev (DevSilverhandOffer): fuerza que la proxima oferta sea de un fixer (se guarda fixer+1, 0 = sin filtro) y que salga ESPECIAL. Nada se guarda.
    private let m_devFixerP1: Int32;
    private let m_devSpecial: Bool;

    public static func Get(gi: GameInstance) -> ref<GRBounties> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRBounties") as GRBounties;
    }

    public static func MaxOpen() -> Int32 {
        return 3;
    }

    public static func MaxOffers() -> Int32 {
        return 3;
    }

    public static func IsOpenState(state: Int32) -> Bool {
        return state == 0 || state == 3;
    }

    public static func LairCond() -> Int32 {
        return 3;
    }

    public static func BossChance() -> Int32 {
        return 12;
    }

    // Zona de caza: radio por contrato entre HuntRadiusMin y HuntRadiusMin + HuntRadiusSpan (70..80 m), estable al recargar (depende solo del id).
    public static func HuntRadiusMin() -> Float {
        return 70.0;
    }

    public static func HuntRadiusSpan() -> Int32 {
        return 10;
    }

    public static func HuntRadiusFor(nemesisId: Int32) -> Float {
        let step: Int32 = nemesisId % (GRBounties.HuntRadiusSpan() + 1);
        if step < 0 {
            step += GRBounties.HuntRadiusSpan() + 1;
        }
        return GRBounties.HuntRadiusMin() + Cast<Float>(step);
    }

    // Desplazamiento del centro del circulo respecto del punto real (el Nemesis queda adentro): entre OffsetMin y OffsetMax,
    // y nunca mas de OffsetFrac * radio (tambien se aplica a contratos viejos guardados con el desplazamiento de 30-110 m).
    public static func HuntOffsetMin() -> Float {
        return 10.0;
    }

    public static func HuntOffsetMax() -> Float {
        return 35.0;
    }

    public static func HuntOffsetFrac() -> Float {
        return 0.45;
    }

    // El Nemesis aparece cuando V esta dentro del circulo (+ HuntSpawnMargin m) Y a menos de HuntSpawnDistance m del punto real
    // (tope por navmesh/streaming: con el centro desplazado, el borde del circulo puede quedar a mas de 90 m del punto).
    public static func HuntSpawnDistance() -> Float {
        return 90.0;
    }

    public static func HuntSpawnMargin() -> Float {
        return 15.0;
    }

    // El circulo del minimapa solo se dibuja si el radio es <= este valor (los de 250/400 m del Jefe no se ven bien: solo anillo en el mapa grande).
    public static func MinimapCircleMaxRadius() -> Float {
        return 120.0;
    }

    // Pines del anillo del mapa grande segun el radio (con radio chico quedan mas juntos, se usan menos).
    public static func ZoneRingPins(radius: Float) -> Int32 {
        if radius > 300.0 {
            return 16;
        }
        if radius > 120.0 {
            return 14;
        }
        return 10;
    }

    // Color del circulo del minimapa mientras V esta DENTRO de la zona (tinte del widget effectAreaWidget): amarillo claro. Fuera queda el color base del juego.
    public static func ZoneCircleInsideColor() -> HDRColor {
        return new HDRColor(1.0, 0.92, 0.51, 1.0);
    }

    // Causa del "no cambia de color" (verificado en los archivos del juego): el widget effectArea de minimap_device_mappin.inkwidget tiene su tintColor
    // ENLAZADO (inkPropertyBinding) al estilo "Mappin.AreaColor" (= MainColors.White, solo el estado Explosion lo pone rojo). Un SetTintColor suelto lo pisa
    // el estilo en la proxima resolucion; el juego mismo cambia colores con widget.BindProperty(n"tintColor", n"MainColors.X"). Por eso se re-enlaza.
    public static func ZoneCircleInsideStyle() -> CName {
        return n"MainColors.ActiveYellow";
    }

    // Estilo original del circulo (el que trae el inkwidget), para restaurar al salir de la zona.
    public static func ZoneCircleBaseStyle() -> CName {
        return n"Mappin.AreaColor";
    }

    // Modo de color por defecto del circulo (se cambia en vivo con DevZoneColorMode): 5 = re-enlace del tinte + SetTintColor + estado Quest del mappin.
    // Nota: el estado Quest del estilo "Mappin" solo cambia IconColor/Opacity, NO AreaColor, asi que por si solo (modo 4) no tine el disco.
    public static func ZoneColorModeDefault() -> Int32 {
        return 5;
    }

    public static func ZoneColorModeName(mode: Int32) -> String {
        if mode == 0 {
            return "0 sin cambio de color";
        }
        if mode == 1 {
            return "1 re-enlace del tinte (BindProperty) + SetTintColor";
        }
        if mode == 2 {
            return "2 solo SetTintColor (el original, no se veia)";
        }
        if mode == 3 {
            return "3 solo re-enlace del tinte (BindProperty)";
        }
        if mode == 4 {
            return "4 solo estado Quest del mappin (m_isQuest)";
        }
        if mode == 6 {
            return "6 re-enlace + SetTintColor + tinte de la raiz del controlador";
        }
        return "5 re-enlace + SetTintColor + estado Quest (por defecto)";
    }

    // true = el pin central de zona no se ve en el MINIMAPA (ahi va solo el circulo); siguen visibles en el mapa grande.
    public static func HideZonePinsOnMinimap() -> Bool {
        return true;
    }

    public static func LairRadius(intel: Int32) -> Float {
        return intel >= 50 ? 250.0 : 400.0;
    }

    public static func XpFor(rank: Int32, escapes: Int32) -> Int32 {
        let base: Int32 = 350;
        if rank >= 3 {
            base = 1000;
        } else {
            if rank == 2 {
                base = 650;
            }
        }
        return base + 50 * Min(5, Max(0, escapes));
    }

    public static func CredFor(rank: Int32) -> Int32 {
        if rank >= 3 {
            return 900;
        }
        if rank == 2 {
            return 550;
        }
        return 300;
    }

    public static func GangKeys() -> array<String> {
        return ["Maelstrom", "TygerClaws", "Valentinos", "SixthStreet", "Animals", "VoodooBoys", "Wraiths", "Scavengers", "Barghest"];
    }

    public static func FixerOfGang(gang: String) -> Int32 {
        if Equals(gang, "Valentinos") {
            return 0;
        }
        if Equals(gang, "SixthStreet") {
            return 1;
        }
        if Equals(gang, "Maelstrom") || Equals(gang, "Scavengers") {
            return 2;
        }
        if Equals(gang, "TygerClaws") {
            return 3;
        }
        if Equals(gang, "VoodooBoys") {
            return 5;
        }
        if Equals(gang, "Wraiths") {
            return 6;
        }
        if Equals(gang, "Barghest") {
            return 7;
        }
        return 4;
    }

    public static func FixerName(fixer: Int32) -> String {
        let names: array<String> = ["Padre", "El Capitán", "Regina Jones", "Wakako Okada", "Rogue", "Mr. Hands", "Dakota Smith", "Mr. Hands"];
        if fixer >= 0 && fixer < ArraySize(names) {
            return names[fixer];
        }
        return "Rogue";
    }

    // Tienen que coincidir con FIXER_SLOTS / FIXER_KINDS de build_archive.py (ranuras en bloques de 4 tipos).
    public static func SmsSlots() -> Int32 {
        return 48;
    }

    public static func SmsKinds() -> Int32 {
        return 4;
    }

    // Easter egg (tipo 5): una ranura FIJA al final del hilo del contacto de Rogue (FIXER_EGG_SLOT en build_archive.py).
    // No entra en los bloques de SmsKinds, asi que NextKindSlot no la toca.
    public static func SmsEggKind() -> Int32 {
        return 5;
    }

    public static func SmsEggSlot() -> Int32 {
        return GRBounties.SmsSlots() + 1;
    }

    // Easter egg de Rogue: probabilidad (en %) de recibir la Malorian Arms 3516 al cobrar un contrato de Rogue. 0 lo desactiva.
    public static func SilverhandChancePercent() -> Int32 {
        return 6;
    }

    public static func SilverhandFixer() -> Int32 {
        return 4;
    }

    public static func SilverhandRecord() -> TweakDBID {
        return t"Items.Preset_Silverhand_3516";
    }

    public static func SmsThread() -> String {
        return "gr_bounty_board";
    }

    public static func SmsContacts() -> array<String> {
        return ["sebastian_padre_perez", "muamar_el_capitan_reyes", "regina_jones", "wakako_okada", "rogue", "mr_hands", "dakota_smith", "gr_fixers"];
    }

    public static func SmsFallbackContact() -> Int32 {
        return 7;
    }

    public static func FixerContact(fixer: Int32) -> Int32 {
        if fixer == 7 {
            return 5;
        }
        if fixer >= 0 && fixer < 7 {
            return fixer;
        }
        return 4;
    }

    public static func SmsKindName(kind: Int32) -> String {
        if kind == 1 {
            return "oferta";
        }
        if kind == 2 {
            return "aceptado";
        }
        if kind == 3 {
            return "cobrado";
        }
        if kind == GRBounties.SmsEggKind() {
            return "easter egg";
        }
        return "fallido";
    }

    private func SmsText(kind: Int32, nemesisId: Int32, amount: Int32, xp: Int32, extra: Int32) -> String {
        let sep: String = this.Text("GR-BountySep");
        let name: String = this.NameOf(nemesisId);
        let text: String;
        if kind == GRBounties.SmsEggKind() {
            return this.Text("GR-SilverhandSms");
        }
        if kind == 1 {
            let msgKey: String = "GR-BountyMsg-" + IntToString(extra / 10) + "-" + IntToString(Max(1, extra % 10));
            text = StrReplaceAll(this.Text("GR-BountySmsOffer"), "{msg}", StrReplaceAll(this.Text(msgKey), "{name}", name));
            return StrReplaceAll(text, "{pay}", GRBounties.Money(amount, sep));
        }
        if kind == 2 {
            let acceptKey: String = "GR-BountySmsAccept";
            if extra == 1 {
                acceptKey = "GR-BountySmsAcceptZone";
            } else if extra == 2 {
                acceptKey = "GR-BountySmsAcceptLair";
            } else if extra == 3 {
                acceptKey = "GR-BountySmsAcceptLairKnown";
            }
            return StrReplaceAll(this.Text(acceptKey), "{name}", name);
        }
        if kind == 3 {
            text = StrReplaceAll(this.Text("GR-BountySmsPaid"), "{name}", name);
            text = StrReplaceAll(text, "{pay}", GRBounties.Money(amount, sep));
            return StrReplaceAll(text, "{xp}", GRBounties.Group(xp, sep));
        }
        text = StrReplaceAll(this.Text("GR-BountySmsFailed"), "{name}", name);
        return StrReplaceAll(text, "{reason}", this.Text("GR-BountyReason-" + IntToString(extra)));
    }

    private func SendFixerSms(phone: ref<GRPhone>, fixer: Int32, kind: Int32, nemesisId: Int32, amount: Int32, xp: Int32, extra: Int32) -> Bool {
        let ids: array<String> = GRBounties.SmsContacts();
        let contact: Int32 = GRBounties.FixerContact(fixer);
        if !phone.IsContactActive(ids[contact]) {
            contact = GRBounties.SmsFallbackContact();
        }
        let contactId: String = ids[contact];
        if !phone.HasThread(contactId, GRBounties.SmsThread()) {
            GRLog("SMS fixer: falta contacts/" + contactId + "/" + GRBounties.SmsThread() + " en el journal (archive viejo?), solo aviso");
            return false;
        }
        let slot: Int32;
        if kind == GRBounties.SmsEggKind() {
            // Easter egg: ranura fija, solo existe en el hilo del contacto de Rogue (si no, devuelve false y sale el aviso).
            slot = contact == GRBounties.FixerContact(GRBounties.SilverhandFixer()) && phone.HasSlot(contactId, GRBounties.SmsThread(), GRBounties.SmsEggSlot()) ? GRBounties.SmsEggSlot() : 0;
        } else {
            slot = phone.NextKindSlot(contactId, GRBounties.SmsThread(), Max(1, Min(kind, GRBounties.SmsKinds())), GRBounties.SmsKinds(), GRBounties.SmsSlots());
        }
        if slot <= 0 {
            GRLog("SMS fixer: contacts/" + contactId + "/" + GRBounties.SmsThread() + " no tiene ranuras por tipo (archive viejo?), solo aviso");
            return false;
        }
        phone.ActivateSlot(contactId, GRBounties.SmsThread(), slot, contact == GRBounties.SmsFallbackContact());
        GRLog("SMS fixer: " + GRBounties.FixerName(fixer) + " sms_" + GRPhone.Pad(slot) + " (" + GRBounties.SmsKindName(kind) + " #" + IntToString(nemesisId) + ") en contacts/" + contactId);
        return true;
    }

    public static func CondKey(cond: Int32) -> String {
        if cond == 0 {
            return "derribo (legado)";
        }
        if cond == 1 {
            return "plazo";
        }
        if cond == GRBounties.LairCond() {
            return "guarida";
        }
        return "cualquiera";
    }

    public static func Group(amount: Int32, sep: String) -> String {
        let digits: String = IntToString(Abs(amount));
        let n: Int32 = StrLen(digits);
        let out: String = "";
        let i: Int32 = 0;
        while i < n {
            if i > 0 && (n - i) % 3 == 0 {
                out += sep;
            }
            out += StrMid(digits, i, 1);
            i += 1;
        }
        return out;
    }

    public static func Money(amount: Int32, sep: String) -> String {
        return "€$ " + GRBounties.Group(amount, sep);
    }

    public static func Xp(amount: Int32, sep: String) -> String {
        return GRBounties.Group(amount, sep) + " XP";
    }

    public static func HasWeakness(entry: ref<GRMenuEntry>) -> Bool {
        if !IsDefined(entry) || StrLen(entry.traitKeys) == 0 {
            return false;
        }
        let keys: array<String> = StrSplit(entry.traitKeys, ",");
        for key in keys {
            if GRTraits.IsWeakness(key) {
                return true;
            }
        }
        return false;
    }

    private func Text(key: String) -> String {
        let core: ref<GRSystem> = GRSystem.Get(this.GetGameInstance());
        return IsDefined(core) ? core.GetText(key) : key;
    }

    private func Today() -> Int32 {
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());
        return IsDefined(spawner) ? FloorF(spawner.GetGameDay()) : 0;
    }

    public func GetToday() -> Int32 {
        return this.Today();
    }

    private func Entries() -> array<ref<GRMenuEntry>> {
        let none: array<ref<GRMenuEntry>>;
        let data: ref<GRMenuData> = GRMenuData.Get(this.GetGameInstance());
        if !IsDefined(data) {
            return none;
        }
        return data.GetEntries();
    }

    public func FindEntry(nemesisId: Int32) -> ref<GRMenuEntry> {
        let entries: array<ref<GRMenuEntry>> = this.Entries();
        for entry in entries {
            if entry.id == nemesisId {
                return entry;
            }
        }
        return null;
    }

    private func NameOf(nemesisId: Int32) -> String {
        let entry: ref<GRMenuEntry> = this.FindEntry(nemesisId);
        if IsDefined(entry) && StrLen(entry.name) > 0 {
            return entry.name;
        }
        return this.Text("GR-BountyUnknown");
    }

    private func GangIndex(gang: String) -> Int32 {
        let keys: array<String> = GRBounties.GangKeys();
        let i: Int32 = 0;
        while i < ArraySize(keys) {
            if Equals(keys[i], gang) {
                return i + 1;
            }
            i += 1;
        }
        return 0;
    }

    private func Repair() {
        if ArraySize(this.m_xps) < ArraySize(this.m_ids) {
            let added: Int32 = 0;
            while ArraySize(this.m_xps) < ArraySize(this.m_ids) {
                let k: Int32 = ArraySize(this.m_xps);
                ArrayPush(this.m_xps, GRBounties.XpFor(k < ArraySize(this.m_ranks) ? this.m_ranks[k] : 1, 0));
                added += 1;
            }
            GRLog("Bounty: XP agregada a " + IntToString(added) + " contratos de una version anterior");
        }
        while ArraySize(this.m_specials) < ArraySize(this.m_ids) {
            ArrayPush(this.m_specials, 0);
        }
        if ArraySize(this.m_zoneSets) < ArraySize(this.m_ids) || ArraySize(this.m_zoneX) < ArraySize(this.m_ids) || ArraySize(this.m_zoneY) < ArraySize(this.m_ids)
            || ArraySize(this.m_zoneZ) < ArraySize(this.m_ids) || ArraySize(this.m_zoneCX) < ArraySize(this.m_ids) || ArraySize(this.m_zoneCY) < ArraySize(this.m_ids) {
            let zoneAdded: Int32 = ArraySize(this.m_ids) - ArraySize(this.m_zoneSets);
            while ArraySize(this.m_zoneSets) < ArraySize(this.m_ids) {
                ArrayPush(this.m_zoneSets, 0);
            }
            while ArraySize(this.m_zoneX) < ArraySize(this.m_ids) {
                ArrayPush(this.m_zoneX, 0.0);
            }
            while ArraySize(this.m_zoneY) < ArraySize(this.m_ids) {
                ArrayPush(this.m_zoneY, 0.0);
            }
            while ArraySize(this.m_zoneZ) < ArraySize(this.m_ids) {
                ArrayPush(this.m_zoneZ, 0.0);
            }
            while ArraySize(this.m_zoneCX) < ArraySize(this.m_ids) {
                ArrayPush(this.m_zoneCX, 0.0);
            }
            while ArraySize(this.m_zoneCY) < ArraySize(this.m_ids) {
                ArrayPush(this.m_zoneCY, 0.0);
            }
            if zoneAdded > 0 {
                GRLog("Bounty: zona de busqueda vacia agregada a " + IntToString(zoneAdded) + " contratos de una version anterior");
            }
        }
        let n: Int32 = ArraySize(this.m_ids);
        n = Min(n, ArraySize(this.m_fixers));
        n = Min(n, ArraySize(this.m_conds));
        n = Min(n, ArraySize(this.m_pays));
        n = Min(n, ArraySize(this.m_expires));
        n = Min(n, ArraySize(this.m_states));
        n = Min(n, ArraySize(this.m_bonuses));
        n = Min(n, ArraySize(this.m_bonusUsed));
        n = Min(n, ArraySize(this.m_ranks));
        n = Min(n, ArraySize(this.m_gangs));
        n = Min(n, ArraySize(this.m_reasons));
        n = Min(n, ArraySize(this.m_paids));
        n = Min(n, ArraySize(this.m_msgs));
        n = Min(n, ArraySize(this.m_offerDays));
        n = Min(n, ArraySize(this.m_closeDays));
        n = Min(n, ArraySize(this.m_vDown));
        n = Min(n, ArraySize(this.m_xps));
        n = Min(n, ArraySize(this.m_specials));
        n = Min(n, ArraySize(this.m_zoneSets));
        n = Min(n, ArraySize(this.m_zoneX));
        n = Min(n, ArraySize(this.m_zoneY));
        n = Min(n, ArraySize(this.m_zoneZ));
        n = Min(n, ArraySize(this.m_zoneCX));
        n = Min(n, ArraySize(this.m_zoneCY));
        if n == ArraySize(this.m_ids) && n == ArraySize(this.m_vDown) && n == ArraySize(this.m_closeDays) && n == ArraySize(this.m_states) && n == ArraySize(this.m_xps) && n == ArraySize(this.m_specials)
            && n == ArraySize(this.m_bonusUsed) && n == ArraySize(this.m_fixers) && n == ArraySize(this.m_conds) && n == ArraySize(this.m_pays)
            && n == ArraySize(this.m_expires) && n == ArraySize(this.m_bonuses) && n == ArraySize(this.m_ranks) && n == ArraySize(this.m_gangs)
            && n == ArraySize(this.m_reasons) && n == ArraySize(this.m_paids) && n == ArraySize(this.m_msgs) && n == ArraySize(this.m_offerDays)
            && n == ArraySize(this.m_zoneSets) && n == ArraySize(this.m_zoneX) && n == ArraySize(this.m_zoneY) && n == ArraySize(this.m_zoneZ)
            && n == ArraySize(this.m_zoneCX) && n == ArraySize(this.m_zoneCY) {
            return;
        }
        GRLog("Bounty: datos guardados desparejos, se recortan a " + IntToString(n) + " contratos");
        ArrayResize(this.m_ids, n);
        ArrayResize(this.m_fixers, n);
        ArrayResize(this.m_conds, n);
        ArrayResize(this.m_pays, n);
        ArrayResize(this.m_expires, n);
        ArrayResize(this.m_states, n);
        ArrayResize(this.m_bonuses, n);
        ArrayResize(this.m_bonusUsed, n);
        ArrayResize(this.m_ranks, n);
        ArrayResize(this.m_gangs, n);
        ArrayResize(this.m_reasons, n);
        ArrayResize(this.m_paids, n);
        ArrayResize(this.m_msgs, n);
        ArrayResize(this.m_offerDays, n);
        ArrayResize(this.m_closeDays, n);
        ArrayResize(this.m_vDown, n);
        ArrayResize(this.m_xps, n);
        ArrayResize(this.m_specials, n);
        ArrayResize(this.m_zoneSets, n);
        ArrayResize(this.m_zoneX, n);
        ArrayResize(this.m_zoneY, n);
        ArrayResize(this.m_zoneZ, n);
        ArrayResize(this.m_zoneCX, n);
        ArrayResize(this.m_zoneCY, n);
    }

    private func EraseAt(i: Int32) {
        ArrayErase(this.m_ids, i);
        ArrayErase(this.m_fixers, i);
        ArrayErase(this.m_conds, i);
        ArrayErase(this.m_pays, i);
        ArrayErase(this.m_expires, i);
        ArrayErase(this.m_states, i);
        ArrayErase(this.m_bonuses, i);
        ArrayErase(this.m_bonusUsed, i);
        ArrayErase(this.m_ranks, i);
        ArrayErase(this.m_gangs, i);
        ArrayErase(this.m_reasons, i);
        ArrayErase(this.m_paids, i);
        ArrayErase(this.m_msgs, i);
        ArrayErase(this.m_offerDays, i);
        ArrayErase(this.m_closeDays, i);
        ArrayErase(this.m_vDown, i);
        ArrayErase(this.m_xps, i);
        ArrayErase(this.m_specials, i);
        ArrayErase(this.m_zoneSets, i);
        ArrayErase(this.m_zoneX, i);
        ArrayErase(this.m_zoneY, i);
        ArrayErase(this.m_zoneZ, i);
        ArrayErase(this.m_zoneCX, i);
        ArrayErase(this.m_zoneCY, i);
    }

    private func Prune() {
        let closed: Int32 = 0;
        for state in this.m_states {
            if !GRBounties.IsOpenState(state) {
                closed += 1;
            }
        }
        let i: Int32 = 0;
        while closed > 30 && i < ArraySize(this.m_states) {
            if !GRBounties.IsOpenState(this.m_states[i]) {
                this.EraseAt(i);
                closed -= 1;
            } else {
                i += 1;
            }
        }
    }

    private func OpenIndex(nemesisId: Int32) -> Int32 {
        let n: Int32 = Min(ArraySize(this.m_ids), ArraySize(this.m_states));
        let i: Int32 = 0;
        while i < n {
            if this.m_ids[i] == nemesisId && GRBounties.IsOpenState(this.m_states[i]) {
                return i;
            }
            i += 1;
        }
        return -1;
    }

    private func CountState(wanted: Int32) -> Int32 {
        let count: Int32 = 0;
        for state in this.m_states {
            if state == wanted {
                count += 1;
            }
        }
        return count;
    }

    public func OpenCount() -> Int32 {
        return this.CountState(0) + this.CountState(3);
    }

    public func AcceptedCount() -> Int32 {
        return this.CountState(0);
    }

    public func OfferedCount() -> Int32 {
        return this.CountState(3);
    }

    private func FirstWithState(wanted: Int32) -> Int32 {
        let i: Int32 = 0;
        while i < ArraySize(this.m_states) {
            if this.m_states[i] == wanted {
                return i;
            }
            i += 1;
        }
        return -1;
    }

    private func Queue(text: String) {
        this.PushPending(text, -1, 0, 0, 0, 0, 0);
    }

    private func QueueSms(text: String, fixer: Int32, kind: Int32, nemesisId: Int32, amount: Int32, xp: Int32, extra: Int32) {
        this.PushPending(text, fixer, kind, nemesisId, amount, xp, extra);
    }

    private func PushPending(text: String, fixer: Int32, kind: Int32, nemesisId: Int32, amount: Int32, xp: Int32, extra: Int32) {
        ArrayPush(this.m_pending, text);
        ArrayPush(this.m_pendingFrom, kind > 0 ? GRBounties.FixerName(fixer) : "");
        ArrayPush(this.m_pendingSms, kind > 0 ? this.SmsText(kind, nemesisId, amount, xp, extra) : "");
        ArrayPush(this.m_pendingFixer, fixer);
        ArrayPush(this.m_pendingKind, kind);
        ArrayPush(this.m_pendingId, nemesisId);
        ArrayPush(this.m_pendingAmount, amount);
        ArrayPush(this.m_pendingXp, xp);
        ArrayPush(this.m_pendingExtra, extra);
    }

    private func PopPending() {
        if ArraySize(this.m_pending) > 0 {
            ArrayErase(this.m_pending, 0);
        }
        if ArraySize(this.m_pendingFrom) > 0 {
            ArrayErase(this.m_pendingFrom, 0);
        }
        if ArraySize(this.m_pendingSms) > 0 {
            ArrayErase(this.m_pendingSms, 0);
        }
        if ArraySize(this.m_pendingFixer) > 0 {
            ArrayErase(this.m_pendingFixer, 0);
        }
        if ArraySize(this.m_pendingKind) > 0 {
            ArrayErase(this.m_pendingKind, 0);
        }
        if ArraySize(this.m_pendingId) > 0 {
            ArrayErase(this.m_pendingId, 0);
        }
        if ArraySize(this.m_pendingAmount) > 0 {
            ArrayErase(this.m_pendingAmount, 0);
        }
        if ArraySize(this.m_pendingXp) > 0 {
            ArrayErase(this.m_pendingXp, 0);
        }
        if ArraySize(this.m_pendingExtra) > 0 {
            ArrayErase(this.m_pendingExtra, 0);
        }
    }

    private func FlushNotify() {
        if ArraySize(this.m_pending) == 0 {
            return;
        }
        let gi: GameInstance = this.GetGameInstance();
        let spawner: ref<GRSpawner> = GRSpawner.Get(gi);
        if !IsDefined(spawner) {
            return;
        }
        let now: Float = spawner.GetTime();
        if this.m_notifyAt - now > 10.0 {
            this.m_notifyAt = 0.0;
        }
        if now < this.m_notifyAt {
            return;
        }
        let det: ref<GRDetection> = GRDetection.Get(gi);
        if !IsDefined(det) || !det.CanNotify() {
            return;
        }
        let settings: ref<GRSettings> = GRSettings.Get(gi);
        let phone: ref<GRPhone> = GRPhone.Get(gi);
        let viaSms: Bool = false;
        let wantSms: Bool = ArraySize(this.m_pendingKind) > 0 && this.m_pendingKind[0] > 0 && ArraySize(this.m_pendingSms) > 0 && StrLen(this.m_pendingSms[0]) > 0
            && IsDefined(settings) && settings.bountySms && IsDefined(phone);
        if wantSms {
            viaSms = this.SendFixerSms(phone, this.m_pendingFixer[0], this.m_pendingKind[0], this.m_pendingId[0], this.m_pendingAmount[0], this.m_pendingXp[0], this.m_pendingExtra[0]);
            if !viaSms {
                viaSms = phone.SendSms(this.m_pendingFrom[0], this.m_pendingSms[0]);
            }
        }
        if !viaSms {
            det.Notify(this.m_pending[0]);
        }
        if ArraySize(this.m_pendingKind) > 0 && this.m_pendingKind[0] == 2 {
            this.OnAcceptSent(now);
        }
        this.PopPending();
        this.m_notifyAt = now + 4.0;
    }

    public func Tick() {
        let today: Int32 = this.Today();
        if this.m_lastDay != today + 1 {
            let entries: array<ref<GRMenuEntry>> = this.Entries();
            if ArraySize(entries) > 0 {
                this.m_lastDay = today + 1;
                this.Daily(today);
            }
        }
        let spawnerRef: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());
        if IsDefined(spawnerRef) {
            spawnerRef.DrainBountyDeaths(this);
        }
        this.RefreshZones();
        this.TickGig();
        this.FlushNotify();
    }

    private func Daily(today: Int32) {
        this.Repair();
        let i: Int32 = 0;
        while i < ArraySize(this.m_ids) {
            if GRBounties.IsOpenState(this.m_states[i]) {
                if today >= this.m_expires[i] {
                    this.Fail(i, 1, today);
                } else {
                    let entry: ref<GRMenuEntry> = this.FindEntry(this.m_ids[i]);
                    if IsDefined(entry) {
                        if !entry.dead {
                            this.m_vDown[i] = 0;
                        } else {
                            if this.m_vDown[i] == 0 {
                                this.Fail(i, 2, today);
                            }
                        }
                    }
                }
            }
            i += 1;
        }
        if this.OfferedCount() < GRBounties.MaxOffers() && this.OpenBossCount() == 0 {
            let bossRoll: Int32 = RandRange(0, 100);
            if bossRoll < GRBounties.BossChance() {
                GRLog("Bounty: tirada de contrato de Jefe del dia " + IntToString(today) + " (" + IntToString(bossRoll) + " < " + IntToString(GRBounties.BossChance()) + ") -> "
                    + this.OfferBoss(today));
            }
        }
        let offered: Int32 = this.OfferedCount();
        let counts: String = IntToString(this.AcceptedCount()) + "/" + IntToString(GRBounties.MaxOpen()) + " aceptados, " + IntToString(offered) + "/" + IntToString(GRBounties.MaxOffers()) + " ofertas";
        if offered >= GRBounties.MaxOffers() {
            GRLog("Bounty: revision del dia " + IntToString(today) + " sin oferta (ofertas pendientes llenas, " + counts + ")");
            return;
        }
        if RandRange(0, 100) >= 50 {
            GRLog("Bounty: revision del dia " + IntToString(today) + " sin oferta (" + counts + ")");
            return;
        }
        let result: String = this.Offer(today);
        if !StrBeginsWith(result, "ofrecido") {
            GRLog("Bounty: revision del dia " + IntToString(today) + " sin oferta (" + result + ")");
        }
    }

    private func Offer(today: Int32) -> String {
        let entries: array<ref<GRMenuEntry>> = this.Entries();
        let candidates: array<ref<GRMenuEntry>>;
        let weights: array<Int32>;
        let total: Int32 = 0;
        let strongholdRef: ref<GRStronghold> = GRStronghold.Get(this.GetGameInstance());
        for entry in entries {
            if !entry.dead && entry.known && entry.id > 0 && entry.rank < 3 && this.OpenIndex(entry.id) < 0 && IsDefined(strongholdRef) && strongholdRef.IsMember(entry.id) && strongholdRef.HasHuntCandidates(entry.gangKey)
                && (this.m_devFixerP1 == 0 || GRBounties.FixerOfGang(entry.gangKey) == this.m_devFixerP1 - 1) {
                let weight: Int32 = 1 + Max(0, entry.renown) + 2 * Max(0, entry.escapes) + 4 * Max(0, entry.rank - 1);
                ArrayPush(candidates, entry);
                ArrayPush(weights, weight);
                total += weight;
            }
        }
        if ArraySize(candidates) == 0 {
            return "sin candidatos: ningun Nemesis vivo (Soldado o Teniente) que conozca a V sin contrato";
        }
        let roll: Int32 = RandRange(0, total);
        let pick: ref<GRMenuEntry> = candidates[0];
        let found: Bool = false;
        let i: Int32 = 0;
        while i < ArraySize(candidates) && !found {
            if roll < weights[i] {
                pick = candidates[i];
                found = true;
            } else {
                roll -= weights[i];
            }
            i += 1;
        }
        // La condicion 0 ("derribar, no importa si vuelve") quedo igual a la 2 desde que cualquier derribo cobra: ya no se genera (los contratos viejos guardados con cond 0 siguen igual).
        let cond: Int32 = RandRange(0, 3) == 1 ? 1 : 2;
        let expire: Int32 = today + (cond == 1 ? RandRange(2, 4) : RandRange(4, 7));
        return this.PushOffer(pick, cond, expire, today);
    }

    private func OpenBossCount() -> Int32 {
        let count: Int32 = 0;
        let n: Int32 = Min(ArraySize(this.m_conds), ArraySize(this.m_states));
        let i: Int32 = 0;
        while i < n {
            if this.m_conds[i] == GRBounties.LairCond() && GRBounties.IsOpenState(this.m_states[i]) {
                count += 1;
            }
            i += 1;
        }
        return count;
    }

    private func OfferBoss(today: Int32) -> String {
        if this.OpenBossCount() > 0 {
            return "ya hay un contrato de Jefe abierto";
        }
        let stronghold: ref<GRStronghold> = GRStronghold.Get(this.GetGameInstance());
        if !IsDefined(stronghold) {
            return "sin sistema de guaridas";
        }
        let entries: array<ref<GRMenuEntry>> = this.Entries();
        let candidates: array<ref<GRMenuEntry>>;
        for entry in entries {
            if !entry.dead && entry.known && entry.id > 0 && entry.rank >= 3 && this.OpenIndex(entry.id) < 0 && stronghold.IsLairMember(entry.id) {
                ArrayPush(candidates, entry);
            }
        }
        let count: Int32 = ArraySize(candidates);
        if count == 0 {
            return "sin candidatos: ningun Jefe vivo que conozca a V, sin contrato y en su guarida";
        }
        let pick: ref<GRMenuEntry> = candidates[Min(RandRange(0, count), count - 1)];
        return this.PushOffer(pick, GRBounties.LairCond(), today + RandRange(5, 9), today);
    }

    private func PushOffer(pick: ref<GRMenuEntry>, cond: Int32, expire: Int32, today: Int32) -> String {
        let rank: Int32 = Max(1, pick.rank);
        let pay: Int32 = RandRange(12, 17) * 500;
        if rank >= 3 {
            pay = RandRange(56, 71) * 500;
        } else {
            if rank == 2 {
                pay = RandRange(28, 37) * 500;
            }
        }
        pay += 1500 * Max(0, pick.escapes);
        let bonus: Int32 = 0;
        if GRBounties.HasWeakness(pick) {
            bonus = Max(1, (pay / 8 + 250) / 500) * 500;
        }
        let fixer: Int32 = GRBounties.FixerOfGang(pick.gangKey);
        let xp: Int32 = GRBounties.XpFor(rank, pick.escapes);

        this.Repair();
        let special: Int32 = this.RollSpecial(fixer, pick);
        if special > 0 && bonus <= 0 {
            bonus = Max(1, (pay / 8 + 250) / 500) * 500;
        }
        ArrayPush(this.m_ids, pick.id);
        ArrayPush(this.m_fixers, fixer);
        ArrayPush(this.m_conds, cond);
        ArrayPush(this.m_pays, pay);
        ArrayPush(this.m_expires, expire);
        ArrayPush(this.m_states, 3);
        ArrayPush(this.m_bonuses, bonus);
        ArrayPush(this.m_bonusUsed, 0);
        ArrayPush(this.m_ranks, rank);
        ArrayPush(this.m_gangs, this.GangIndex(pick.gangKey));
        ArrayPush(this.m_reasons, 0);
        ArrayPush(this.m_paids, 0);
        ArrayPush(this.m_msgs, RandRange(1, 4));
        ArrayPush(this.m_offerDays, today);
        ArrayPush(this.m_closeDays, 0);
        ArrayPush(this.m_vDown, 0);
        ArrayPush(this.m_xps, xp);
        ArrayPush(this.m_specials, special);
        ArrayPush(this.m_zoneSets, 0);
        ArrayPush(this.m_zoneX, 0.0);
        ArrayPush(this.m_zoneY, 0.0);
        ArrayPush(this.m_zoneZ, 0.0);
        ArrayPush(this.m_zoneCX, 0.0);
        ArrayPush(this.m_zoneCY, 0.0);

        GRLog("Bounty: ofrecido #" + IntToString(pick.id) + " " + GRBounties.FixerName(fixer) + " €$" + IntToString(pay) + " " + IntToString(xp) + " XP cond=" + GRBounties.CondKey(cond)
            + " vence dia " + IntToString(expire) + (bonus > 0 ? " bono=" + IntToString(bonus) : " sin bono") + " (" + pick.name + ", rango " + IntToString(rank) + ")"
            + (special > 0 ? " ESPECIAL" : ""));
        let text: String = StrReplaceAll(this.Text("GR-BountyOffered"), "{fixer}", GRBounties.FixerName(fixer));
        text = StrReplaceAll(text, "{name}", pick.name);
        text = StrReplaceAll(text, "{pay}", GRBounties.Money(pay, this.Text("GR-BountySep")));
        this.QueueSms(text, fixer, 1, pick.id, pay, xp, cond * 10 + Max(1, this.m_msgs[ArraySize(this.m_msgs) - 1]));
        this.Prune();
        return "ofrecido #" + IntToString(pick.id) + " (" + pick.name + ")";
    }

    private func Pay(i: Int32, today: Int32) {
        let bonus: Int32 = this.m_bonusUsed[i] > 0 ? this.m_bonuses[i] : 0;
        let amount: Int32 = this.m_pays[i] + bonus;
        let xp: Int32 = this.m_xps[i];
        let cred: Int32 = GRBounties.CredFor(this.m_ranks[i]);
        let gi: GameInstance = this.GetGameInstance();
        let spawner: ref<GRSpawner> = GRSpawner.Get(gi);
        let given: Bool = IsDefined(spawner) && spawner.GiveMoney(amount);
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        let xpGiven: Bool = IsDefined(player);
        if xpGiven {
            RPGManager.AwardExperienceInstantly(player, xp, gamedataProficiencyType.Level);
            RPGManager.AwardExperienceInstantly(player, cred, gamedataProficiencyType.StreetCred);
        }
        this.m_states[i] = 1;
        this.m_paids[i] = amount;
        this.m_closeDays[i] = today;
        GRLog("Bounty: cobrado #" + IntToString(this.m_ids[i]) + " " + GRBounties.FixerName(this.m_fixers[i]) + " €$" + IntToString(amount)
            + " (base " + IntToString(this.m_pays[i]) + ", bono " + IntToString(bonus) + ", cond=" + GRBounties.CondKey(this.m_conds[i]) + ") + "
            + IntToString(xp) + " XP + " + IntToString(cred) + " Street Cred"
            + (given ? "" : " - ERROR: no se pudo dar el dinero") + (xpGiven ? "" : " - ERROR: no se pudo dar la experiencia (sin jugador)"));
        let sep: String = this.Text("GR-BountySep");
        let paidText: String = StrReplaceAll(this.Text("GR-BountyPaidMsg"), "{pay}", GRBounties.Money(amount, sep));
        paidText = StrReplaceAll(paidText, "{xp}", GRBounties.Group(xp, sep));
        this.QueueSms(paidText, this.m_fixers[i], 3, this.m_ids[i], amount, xp, 0);
        if i < ArraySize(this.m_specials) && this.m_specials[i] > 0 {
            this.PaySpecial(i);
        }
    }

    // ---- Easter egg de Rogue (contrato ESPECIAL) ----

    // Donde tiene V la replica: "equipada" (ranuras de la rueda de armas), "en el inventario" (cualquier copia con el mismo TweakDBID, con o sin mejoras) o "" si no la tiene.
    // Solo lectura. Las armas equipadas tambien estan en el inventario del jugador, pero se mira la rueda aparte para poder decirlo.
    private func SilverhandOwnedWhere() -> String {
        let gi: GameInstance = this.GetGameInstance();
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        if !IsDefined(player) {
            return "";
        }
        let record: TweakDBID = GRBounties.SilverhandRecord();
        let equipment: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(player);
        if IsDefined(equipment) {
            let slots: Int32 = equipment.GetNumberOfSlots(gamedataEquipmentArea.WeaponWheel, true);
            let k: Int32 = 0;
            while k < slots {
                let equipped: ItemID = equipment.GetItemInEquipSlot(gamedataEquipmentArea.WeaponWheel, k);
                if ItemID.IsValid(equipped) && ItemID.GetTDBID(equipped) == record {
                    return "equipada";
                }
                k += 1;
            }
        }
        let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(gi);
        let items: array<wref<gameItemData>>;
        if ts.GetItemList(player, items) {
            let n: Int32 = ArraySize(items);
            let j: Int32 = 0;
            while j < n {
                let data: wref<gameItemData> = items[j];
                if IsDefined(data) && ItemID.GetTDBID(data.GetID()) == record {
                    return "en el inventario";
                }
                j += 1;
            }
        }
        return "";
    }

    // "" = se puede entregar; si no, el motivo. Solo lectura (no toca el flag).
    private func SilverhandBlocked() -> String {
        if !IsDefined(GetPlayer(this.GetGameInstance())) {
            return "sin jugador";
        }
        let owned: String = this.SilverhandOwnedWhere();
        if StrLen(owned) > 0 {
            return "ya la tiene (" + owned + ")";
        }
        if this.m_silverhandGiven {
            return "ya se entrego (o se vio que la tenia) antes: flag m_silverhandGiven";
        }
        return "";
    }

    // Lo llama el sync del alijo (GRRewards.SyncStash) si la replica esta guardada ahi: desde entonces no se vuelve a ofrecer.
    public func NoteSilverhandSeen(place: String) {
        if !this.m_silverhandGiven {
            this.m_silverhandGiven = true;
            GRLog("Bounty: easter egg, V ya tiene la replica (" + place + "), no se volvera a ofrecer");
        }
    }

    private func HasOpenSpecial() -> Bool {
        let n: Int32 = Min(ArraySize(this.m_specials), ArraySize(this.m_states));
        let i: Int32 = 0;
        while i < n {
            if this.m_specials[i] > 0 && GRBounties.IsOpenState(this.m_states[i]) {
                return true;
            }
            i += 1;
        }
        return false;
    }

    // Tirada al OFRECER un contrato de Rogue: 1 = sale especial. Solo si la chance es > 0, el objetivo tiene una debilidad (si no, el opcional no se puede cumplir),
    // no hay otro especial abierto y V no tiene la replica ni se dio antes. En dev (m_devSpecial) se saltea la tirada y el requisito de debilidad.
    private func RollSpecial(fixer: Int32, pick: ref<GRMenuEntry>) -> Int32 {
        if fixer != GRBounties.SilverhandFixer() {
            return 0;
        }
        if !this.m_devSpecial && (GRBounties.SilverhandChancePercent() <= 0 || !GRBounties.HasWeakness(pick)) {
            return 0;
        }
        if this.HasOpenSpecial() {
            return 0;
        }
        let blocked: String = this.SilverhandBlocked();
        if StrLen(blocked) > 0 {
            if this.m_devSpecial {
                GRLog("Bounty: contrato especial no ofrecido: " + blocked);
            }
            return 0;
        }
        let roll: Int32 = RandRange(0, 100);
        let hit: Bool = this.m_devSpecial || roll < GRBounties.SilverhandChancePercent();
        GRLog("Bounty: tirada de contrato especial de Rogue " + IntToString(roll) + " (< " + IntToString(GRBounties.SilverhandChancePercent()) + (this.m_devSpecial ? ", forzado por dev" : "") + ") -> " + (hit ? "ESPECIAL" : "normal"));
        return hit ? 1 : 0;
    }

    // Entrega la replica (todo en el hilo principal). Devuelve "entregada" o el motivo por el que no. Pone el flag solo si de verdad quedo en el inventario.
    private func GiveSilverhand() -> String {
        let blocked: String = this.SilverhandBlocked();
        if StrLen(blocked) > 0 {
            if StrBeginsWith(blocked, "ya la tiene") {
                this.NoteSilverhandSeen(StrReplaceAll(StrReplaceAll(blocked, "ya la tiene (", ""), ")", ""));
            }
            return blocked;
        }
        let gi: GameInstance = this.GetGameInstance();
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(gi);
        let id: ItemID = ItemID.FromTDBID(GRBounties.SilverhandRecord());
        let given: Bool = ts.GiveItem(player, id, 1);
        let there: String = this.SilverhandOwnedWhere();
        if StrLen(there) == 0 {
            GRLog("Bounty: easter egg, ERROR: GiveItem=" + (given ? "true" : "false") + " pero la replica no aparece en el inventario, se reintentara en el proximo contrato");
            return "no se pudo entregar (GiveItem=" + (given ? "true" : "false") + ")";
        }
        this.m_silverhandGiven = true;
        GRLog("Bounty: easter egg, replica entregada (" + there + ")");
        this.QueueSms(this.Text("GR-SilverhandSms"), GRBounties.SilverhandFixer(), GRBounties.SmsEggKind(), 0, 0, 0, 0);
        this.Queue(this.Text("GR-SilverhandMsg"));
        return "entregada";
    }

    // Al cobrar un contrato especial: la marca se gasta siempre; la replica solo si se cumplieron TODOS los opcionales (hoy el unico es el bono de debilidad).
    private func PaySpecial(i: Int32) {
        this.m_specials[i] = 0;
        let allDone: Bool = this.m_bonuses[i] > 0 && this.m_bonusUsed[i] > 0;
        if !allDone {
            GRLog("Bounty: contrato especial #" + IntToString(this.m_ids[i]) + " cobrado sin cumplir los opcionales, sin replica y sin reintento");
            return;
        }
        GRLog("Bounty: contrato especial #" + IntToString(this.m_ids[i]) + " cobrado con todos los opcionales -> " + this.GiveSilverhand());
    }

    public func DevSilverhand() -> String {
        this.Repair();
        let result: String = this.GiveSilverhand();
        GRLog("Bounty: DevSilverhand -> " + result);
        return result;
    }

    public func DevSilverhandReset() -> String {
        let was: Bool = this.m_silverhandGiven;
        this.m_silverhandGiven = false;
        let result: String = "flag m_silverhandGiven bajado (estaba " + (was ? "true" : "false") + "); sigue valiendo 'ya la tiene' si la tiene equipada/en el inventario/alijo";
        GRLog("Bounty: DevSilverhandReset -> " + result);
        return result;
    }

    public func DevSilverhandInfo() -> String {
        this.Repair();
        let owned: String = this.SilverhandOwnedWhere();
        let blocked: String = this.SilverhandBlocked();
        let result: String = "arma: " + (StrLen(owned) > 0 ? "ya la tiene (" + owned + ")" : "no la tiene") + " | flag m_silverhandGiven=" + (this.m_silverhandGiven ? "true" : "false")
            + " | chance=" + IntToString(GRBounties.SilverhandChancePercent()) + "% | se puede dar: " + (StrLen(blocked) == 0 ? "si" : "no (" + blocked + ")");
        let phone: ref<GRPhone> = GRPhone.Get(this.GetGameInstance());
        if IsDefined(phone) {
            let ids: array<String> = GRBounties.SmsContacts();
            let contact: String = ids[GRBounties.FixerContact(GRBounties.SilverhandFixer())];
            result += " | SMS: contacto " + contact + (phone.IsContactActive(contact) ? " activo" : " NO activo (saldria el aviso en pantalla)")
                + ", ranura " + IntToString(GRBounties.SmsEggSlot()) + (phone.HasSlot(contact, GRBounties.SmsThread(), GRBounties.SmsEggSlot()) ? " existe" : " NO existe (archive viejo)");
        }
        let i: Int32 = 0;
        while i < ArraySize(this.m_specials) {
            if this.m_specials[i] > 0 && GRBounties.IsOpenState(this.m_states[i]) {
                result += " | contrato especial #" + IntToString(this.m_ids[i]) + " (" + this.NameOf(this.m_ids[i]) + ") " + (this.m_states[i] == 0 ? "aceptado" : "oferta")
                    + ", bono=" + IntToString(this.m_bonuses[i]) + (this.m_bonusUsed[i] > 0 ? " CUMPLIDO" : " sin cumplir");
            }
            i += 1;
        }
        GRLog("Bounty: DevSilverhandInfo -> " + result);
        return result;
    }

    // Ofrece un contrato de Rogue ESPECIAL (sin tirada ni requisito de debilidad), respetando "ya la tiene / ya se dio" y un solo especial abierto.
    public func DevSilverhandOffer() -> String {
        this.Repair();
        let result: String;
        let blocked: String = this.SilverhandBlocked();
        if StrLen(blocked) > 0 {
            result = "no se ofrece: " + blocked;
        } else if this.HasOpenSpecial() {
            result = "ya hay un contrato especial abierto";
        } else if this.OfferedCount() >= GRBounties.MaxOffers() {
            result = "ofertas pendientes llenas (" + IntToString(this.OfferedCount()) + "/" + IntToString(GRBounties.MaxOffers()) + ")";
        } else {
            this.m_devFixerP1 = GRBounties.SilverhandFixer() + 1;
            this.m_devSpecial = true;
            result = this.Offer(this.Today());
            this.m_devFixerP1 = 0;
            this.m_devSpecial = false;
            if StrBeginsWith(result, "ofrecido") {
                result += this.HasOpenSpecial() ? " [ESPECIAL con bono]" : " [sin marca especial]";
            }
        }
        GRLog("Bounty: DevSilverhandOffer -> " + result);
        return result;
    }

    // Marca el bono de debilidad como conseguido en el contrato especial abierto (para probar el cobro con replica).
    public func DevSilverhandBonus() -> String {
        this.Repair();
        let result: String = "no hay un contrato especial abierto";
        let i: Int32 = 0;
        while i < ArraySize(this.m_specials) {
            if this.m_specials[i] > 0 && GRBounties.IsOpenState(this.m_states[i]) {
                if this.m_bonuses[i] <= 0 {
                    this.m_bonuses[i] = 500;
                }
                this.m_bonusUsed[i] = 1;
                result = "bono cumplido en el contrato especial #" + IntToString(this.m_ids[i]) + " (" + this.NameOf(this.m_ids[i]) + ")";
            }
            i += 1;
        }
        GRLog("Bounty: DevSilverhandBonus -> " + result);
        return result;
    }

    private func Fail(i: Int32, reason: Int32, today: Int32) {
        let wasOffer: Bool = this.m_states[i] == 3;
        this.m_states[i] = 2;
        this.m_reasons[i] = reason;
        this.m_closeDays[i] = today;
        let why: String = "murio sin que V cumpliera el contrato";
        if reason == 1 {
            why = "vencio el plazo";
        }
        if reason == 3 {
            why = "V lo abatio sin haber aceptado el contrato";
        }
        GRLog("Bounty: fallido #" + IntToString(this.m_ids[i]) + " (" + why + (wasOffer ? ", era una oferta" : "") + ")");
        let text: String = StrReplaceAll(this.Text("GR-BountyFailedMsg"), "{name}", this.NameOf(this.m_ids[i]));
        text = StrReplaceAll(text, "{reason}", this.Text("GR-BountyReason-" + IntToString(reason)));
        this.QueueSms(text, this.m_fixers[i], 4, this.m_ids[i], 0, 0, reason);
    }

    private func Accept(i: Int32) {
        this.m_states[i] = 0;
        GRLog("Bounty: aceptado #" + IntToString(this.m_ids[i]) + " " + GRBounties.FixerName(this.m_fixers[i]) + " (" + this.NameOf(this.m_ids[i]) + ", "
            + IntToString(this.AcceptedCount()) + "/" + IntToString(GRBounties.MaxOpen()) + " aceptados)");
        let zone: Int32 = this.SetupZone(i, false);
        let text: String = StrReplaceAll(this.Text("GR-BountyAcceptedMsg"), "{name}", this.NameOf(this.m_ids[i]));
        this.QueueSms(text, this.m_fixers[i], 2, this.m_ids[i], this.m_pays[i], this.m_xps[i], zone);
        this.RefreshZones();
        this.ScheduleGig();
    }

    // ---- Zona de busqueda ----

    private func GangOf(i: Int32) -> String {
        let keys: array<String> = GRBounties.GangKeys();
        let gang: Int32 = i >= 0 && i < ArraySize(this.m_gangs) ? this.m_gangs[i] : 0;
        return gang > 0 && gang <= ArraySize(keys) ? keys[gang - 1] : "";
    }

    private func ZoneHint(i: Int32) -> Int32 {
        if i < 0 || i >= ArraySize(this.m_zoneSets) {
            return 0;
        }
        let kind: Int32 = this.m_zoneSets[i];
        if kind == 2 {
            let intel: ref<GRIntelSystem> = GRIntelSystem.Get(this.GetGameInstance());
            if IsDefined(intel) && intel.IsLocated(this.GangOf(i)) {
                return 3;
            }
        }
        return kind;
    }

    // Elige la zona al aceptar (o al cargar una partida con contratos aceptados sin zona). Devuelve la pista para el SMS:
    // 0 sin zona, 1 zona de caza, 2 circulo alrededor de la guarida, 3 guarida ya localizada (tiene su pin).
    private func SetupZone(i: Int32, silent: Bool) -> Int32 {
        if i < 0 || i >= ArraySize(this.m_zoneSets) {
            return 0;
        }
        let id: Int32 = this.m_ids[i];
        let gang: String = this.GangOf(i);
        let stronghold: ref<GRStronghold> = GRStronghold.Get(this.GetGameInstance());
        if this.m_conds[i] == GRBounties.LairCond() || this.m_ranks[i] >= 3 {
            if !IsDefined(stronghold) || !stronghold.HasSite(gang) {
                if !silent {
                    GRLog("Zona #" + IntToString(id) + ": Jefe sin guarida para '" + gang + "', sin zona (se reintenta)");
                }
                return 0;
            }
            let angle: Float = RandRangeF(0.0, 2.0 * Pi());
            let frac: Float = RandRangeF(0.25, 0.6);
            this.m_zoneSets[i] = 2;
            this.m_zoneX[i] = 0.0;
            this.m_zoneY[i] = 0.0;
            this.m_zoneZ[i] = 0.0;
            this.m_zoneCX[i] = CosF(angle) * frac;
            this.m_zoneCY[i] = SinF(angle) * frac;
            GRLog("Zona #" + IntToString(id) + " (" + this.NameOf(id) + "): circulo alrededor de la guarida de " + gang + ", centro desplazado "
                + IntToString(Cast<Int32>(frac * 100.0)) + "% del radio" + (this.ZoneHint(i) == 3 ? " (guarida ya localizada: sin circulo)" : ""));
            return this.ZoneHint(i);
        }
        let validated: Bool = false;
        let surfaceZ: Float = 0.0;
        let useZ: Float = 0.0;
        let spot: Vector4 = IsDefined(stronghold) ? stronghold.PickHuntSpot(gang, id, validated, surfaceZ, useZ) : Vector4.EmptyVector();
        if Vector4.IsZero(spot) {
            if !silent {
                GRLog("Zona #" + IntToString(id) + ": sin punto de caza para '" + gang + "' (sin candidatos con posicion), sin zona (se reintenta)");
            }
            return 0;
        }
        let angle2: Float = RandRangeF(0.0, 2.0 * Pi());
        let huntRadius: Float = GRBounties.HuntRadiusFor(id);
        let offset: Float = RandRangeF(GRBounties.HuntOffsetMin(), MaxF(GRBounties.HuntOffsetMin(), MinF(GRBounties.HuntOffsetMax(), huntRadius * GRBounties.HuntOffsetFrac())));
        this.m_zoneSets[i] = 1;
        this.m_zoneX[i] = spot.X;
        this.m_zoneY[i] = spot.Y;
        // Con el punto validado en superficie, la Z de la zona (pin del encargo, spawn) es la del suelo; si no, la del POI hasta revalidar de cerca.
        this.m_zoneZ[i] = validated ? useZ : spot.Z;
        this.SurfSet(id, validated, surfaceZ, spot.Z);
        this.m_zoneCX[i] = spot.X + CosF(angle2) * offset;
        this.m_zoneCY[i] = spot.Y + SinF(angle2) * offset;
        GRLog("Zona #" + IntToString(id) + " (" + this.NameOf(id) + "): punto de caza " + FloatToStringPrec(spot.X, 1) + ", " + FloatToStringPrec(spot.Y, 1) + ", "
            + FloatToStringPrec(this.m_zoneZ[i], 1) + (validated ? " (validado en superficie, POI Z=" + FloatToStringPrec(spot.Z, 1) + ")" : " (sin validar)")
            + " | centro del anillo a " + IntToString(Cast<Int32>(offset)) + " m del punto (radio " + IntToString(Cast<Int32>(huntRadius)) + " m)");
        return 1;
    }

    private func SurfFind(id: Int32) -> Int32 {
        return ArrayFindFirst(this.m_surfIds, id);
    }

    private func SurfSet(id: Int32, ok: Bool, top: Float, poiZ: Float) {
        let s: Int32 = this.SurfFind(id);
        if s < 0 {
            ArrayPush(this.m_surfIds, id);
            ArrayPush(this.m_surfOk, ok);
            ArrayPush(this.m_surfTop, top);
            ArrayPush(this.m_surfPoiZ, poiZ);
        } else {
            this.m_surfOk[s] = ok;
            this.m_surfTop[s] = top;
            this.m_surfPoiZ[s] = poiZ;
        }
    }

    // Revalida el punto de caza del contrato i contra la superficie (V cerca = hay colision cargada). Devuelve el resultado en texto (y lo deja en el log).
    //   sin datos -> sigue pendiente | cubierto (superficie a > 6 m sobre el POI) -> se descarta el POI y la zona se muda a otro punto | en superficie -> validado, la Z de la zona pasa a ser la del suelo.
    // Solo se marca validado con V a <= 150 m del punto (mas lejos la colision puede estar a medio cargar); "cubierto" se acepta a cualquier distancia (un impacto alto es real).
    private func RevalidateHunt(i: Int32) -> String {
        let gi: GameInstance = this.GetGameInstance();
        let id: Int32 = this.m_ids[i];
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        let stronghold: ref<GRStronghold> = GRStronghold.Get(gi);
        let pos: Vector4 = new Vector4(this.m_zoneX[i], this.m_zoneY[i], this.m_zoneZ[i], 1.0);
        let dist: Float = IsDefined(player) ? Vector4.Distance2D(player.GetWorldPosition(), pos) : -1.0;
        let top: Float = 0.0;
        let useZ: Float = pos.Z;
        let verdict: Int32 = GRSurfaceCheck(gi, pos, top, useZ);
        // Alcanzabilidad por navmesh desde V (V a <= 200 m): un punto detras de una pared/persiana (interior cerrado) no tiene camino.
        let reach: Int32 = -1;
        let pathLen: Float = 0.0;
        let straight: Float = 0.0;
        let roof: Bool = verdict == 1 && GRLowRoof(top, pos.Z);
        if verdict == 1 {
            reach = GRReachFromPlayer(gi, new Vector4(pos.X, pos.Y, useZ, 1.0), pathLen, straight);
        }
        let result: String;
        if verdict == 0 {
            result = "Caza #" + IntToString(id) + ": sin datos de suelo en el punto (V a " + IntToString(Cast<Int32>(dist)) + " m), sigue sin validar";
        } else if verdict == 2 {
            let label: String = IsDefined(stronghold) ? stronghold.CandidateLabel(pos) : "?";
            result = "Caza #" + IntToString(id) + ": POI " + label + " cubierto (superficie Z=" + FloatToStringPrec(top, 1) + ", POI Z=" + FloatToStringPrec(pos.Z, 1) + "), descartado";
            if IsDefined(stronghold) {
                stronghold.MarkCovered(pos);
            }
            // Zona nueva: se desarma esta (los pines se borran/mueven en el proximo RefreshZones) y se elige otro punto.
            this.m_zoneSets[i] = 0;
            this.SetupZone(i, true);
            if this.m_zoneSets[i] == 1 {
                result += " | zona movida a " + FloatToStringPrec(this.m_zoneX[i], 1) + ", " + FloatToStringPrec(this.m_zoneY[i], 1) + ", " + FloatToStringPrec(this.m_zoneZ[i], 1);
            } else {
                result += " | sin otro punto de caza disponible, sin zona (se reintenta)";
            }
        } else if reach == 2 {
            let label2: String = IsDefined(stronghold) ? stronghold.CandidateLabel(pos) : "?";
            result = "Caza #" + IntToString(id) + ": POI " + label2 + " inalcanzable (" + GRReachText(reach, pathLen, straight) + "), descartado";
            if IsDefined(stronghold) {
                stronghold.MarkCovered(pos);
            }
            this.m_zoneSets[i] = 0;
            this.SetupZone(i, true);
            if this.m_zoneSets[i] == 1 {
                result += " | zona movida a " + FloatToStringPrec(this.m_zoneX[i], 1) + ", " + FloatToStringPrec(this.m_zoneY[i], 1) + ", " + FloatToStringPrec(this.m_zoneZ[i], 1);
            } else {
                // Sin otro candidato: SetupZone no toco nada, se conserva la zona y el spawn se reubica dentro del circulo (GRStronghold.BeginHunt).
                this.m_zoneSets[i] = 1;
                this.m_zoneZ[i] = useZ;
                let s3: Int32 = this.SurfFind(id);
                this.SurfSet(id, true, top, s3 >= 0 ? this.m_surfPoiZ[s3] : pos.Z);
                result += " | sin otro punto de caza: se conserva la zona y el spawn se reubica en un punto alcanzable del circulo";
            }
        } else if reach == 0 && roof {
            let s4: Int32 = this.SurfFind(id);
            this.SurfSet(id, false, top, s4 >= 0 ? this.m_surfPoiZ[s4] : pos.Z);
            result = "Caza #" + IntToString(id) + ": techo bajo (superficie Z=" + FloatToStringPrec(top, 1) + ", POI Z=" + FloatToStringPrec(pos.Z, 1)
                + ") y sin datos de navmesh para confirmar que es alcanzable, sigue sin validar";
        } else if dist >= 0.0 && dist <= 150.0 {
            this.m_zoneZ[i] = useZ;
            let s: Int32 = this.SurfFind(id);
            this.SurfSet(id, true, top, s >= 0 ? this.m_surfPoiZ[s] : pos.Z);
            result = "Caza #" + IntToString(id) + ": punto validado en superficie (Z=" + FloatToStringPrec(useZ, 1) + ", superficie mas alta " + FloatToStringPrec(top, 1)
                + ", Z anterior " + FloatToStringPrec(pos.Z, 1) + (reach == 1 ? ", alcanzable: " + GRReachText(reach, pathLen, straight) : "") + ")";
        } else {
            let s2: Int32 = this.SurfFind(id);
            this.SurfSet(id, false, top, s2 >= 0 ? this.m_surfPoiZ[s2] : pos.Z);
            result = "Caza #" + IntToString(id) + ": hay colision pero V esta a " + IntToString(Cast<Int32>(dist)) + " m (> 150 m), sigue sin validar";
        }
        GRLog(result);
        return result;
    }

    // Lo llama GRStronghold.TryHunt (hilo principal, cada tick): revalida los puntos de caza aceptados sin validar con V a < 200 m. Limitado a 1 de cada 3 llamadas.
    public func CheckHuntSurface(from: Vector4) {
        if this.m_surfWait > 0 {
            this.m_surfWait -= 1;
            return;
        }
        this.m_surfWait = 2;
        let n: Int32 = Min(Min(ArraySize(this.m_ids), ArraySize(this.m_states)), Min(ArraySize(this.m_zoneSets), ArraySize(this.m_zoneZ)));
        n = Min(n, Min(ArraySize(this.m_zoneX), ArraySize(this.m_zoneY)));
        n = Min(n, ArraySize(this.m_conds));
        let i: Int32 = 0;
        while i < n {
            if this.m_states[i] == 0 && this.m_zoneSets[i] == 1 && this.m_conds[i] != GRBounties.LairCond() {
                let s: Int32 = this.SurfFind(this.m_ids[i]);
                let done: Bool = s >= 0 && this.m_surfOk[s];
                if !done && Vector4.Distance2D(from, new Vector4(this.m_zoneX[i], this.m_zoneY[i], 0.0, 1.0)) <= 200.0 {
                    this.RevalidateHunt(i);
                }
            }
            i += 1;
        }
    }

    // Dev: re-evalua el punto de caza del primer contrato aceptado con zona de caza (V cerca = suelo cargado) y mueve la zona si esta cubierto.
    // Por REDnode: api_read GRBounties.Get -> api_call self=<ref> fn=DevZoneRevalidate. Despues correr DevZoneInfo.
    public func DevZoneRevalidate() -> String {
        this.Repair();
        let result: String = "no hay contratos aceptados con zona de caza";
        let i: Int32 = 0;
        let found: Int32 = -1;
        while i < ArraySize(this.m_ids) && found < 0 {
            if this.m_states[i] == 0 && this.m_zoneSets[i] == 1 {
                found = i;
            }
            i += 1;
        }
        if found >= 0 {
            result = this.RevalidateHunt(found);
        }
        GRLog("Bounty: DevZoneRevalidate -> " + result);
        return result;
    }

    // Alcanzabilidad por navmesh del punto de caza del contrato i respecto de V, en texto (para DevZoneInfo / DevZoneReach).
    private func ReachText(i: Int32) -> String {
        let gi: GameInstance = this.GetGameInstance();
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        if !IsDefined(player) || i < 0 || i >= ArraySize(this.m_zoneX) || i >= ArraySize(this.m_zoneY) || i >= ArraySize(this.m_zoneZ) {
            return "alcanzable=sin datos (sin jugador)";
        }
        let pathLen: Float = 0.0;
        let straight: Float = 0.0;
        let reach: Int32 = GRReachCheck(gi, player.GetWorldPosition(), new Vector4(this.m_zoneX[i], this.m_zoneY[i], this.m_zoneZ[i], 1.0), pathLen, straight);
        let farNote: String = Vector4.Distance2D(player.GetWorldPosition(), new Vector4(this.m_zoneX[i], this.m_zoneY[i], 0.0, 1.0)) > 200.0 ? " [V a > 200 m: el navmesh puede estar a medio cargar]" : "";
        return "alcanzable=" + (reach == 1 ? "si" : (reach == 2 ? "no" : "sin datos")) + " (" + GRReachText(reach, pathLen, straight) + ")" + farNote;
    }

    // Dev: calcula bajo demanda si el punto de caza del primer contrato aceptado con zona de caza es alcanzable desde V por la navmesh.
    // Por REDnode: api_read GRBounties.Get -> api_call self=<ref> fn=DevZoneReach.
    public func DevZoneReach() -> String {
        this.Repair();
        let result: String = "no hay contratos aceptados con zona de caza";
        let i: Int32 = 0;
        let found: Int32 = -1;
        while i < ArraySize(this.m_ids) && found < 0 {
            if this.m_states[i] == 0 && this.m_zoneSets[i] == 1 {
                found = i;
            }
            i += 1;
        }
        if found >= 0 {
            result = "Caza #" + IntToString(this.m_ids[found]) + ": " + this.ReachText(found);
        }
        GRLog("Bounty: DevZoneReach -> " + result);
        return result;
    }

    // Circulo de la zona de caza del contrato aceptado nemesisId (centro y radio). false = sin zona de caza.
    public func HuntCircle(nemesisId: Int32, out cx: Float, out cy: Float, out radius: Float) -> Bool {
        let i: Int32 = this.AcceptedIndex(nemesisId);
        let cz: Float = 0.0;
        return i >= 0 && this.m_zoneSets[i] == 1 && this.ZoneTarget(i, cx, cy, cz, radius);
    }

    private func AcceptedIndex(nemesisId: Int32) -> Int32 {
        let n: Int32 = Min(ArraySize(this.m_ids), ArraySize(this.m_states));
        let i: Int32 = 0;
        while i < n {
            if this.m_ids[i] == nemesisId && this.m_states[i] == 0 {
                return i;
            }
            i += 1;
        }
        return -1;
    }

    private func FindZone(nemesisId: Int32) -> ref<GRBountyZone> {
        for zone in this.m_zones {
            if zone.nemesisId == nemesisId {
                return zone;
            }
        }
        return null;
    }

    // Donde tiene que estar el anillo ahora. false = no se muestra (sin zona, guarida localizada o sin guarida).
    private func ZoneTarget(i: Int32, out cx: Float, out cy: Float, out cz: Float, out radius: Float) -> Bool {
        if i < 0 || i >= ArraySize(this.m_zoneSets) {
            return false;
        }
        let kind: Int32 = this.m_zoneSets[i];
        if kind == 1 {
            radius = GRBounties.HuntRadiusFor(this.m_ids[i]);
            let dx: Float = this.m_zoneCX[i] - this.m_zoneX[i];
            let dy: Float = this.m_zoneCY[i] - this.m_zoneY[i];
            let len: Float = SqrtF(dx * dx + dy * dy);
            let maxOff: Float = radius * GRBounties.HuntOffsetFrac();
            if len > maxOff && len > 0.01 {
                dx = dx * maxOff / len;
                dy = dy * maxOff / len;
            }
            cx = this.m_zoneX[i] + dx;
            cy = this.m_zoneY[i] + dy;
            cz = this.m_zoneZ[i];
            return true;
        }
        if kind != 2 {
            return false;
        }
        let gang: String = this.GangOf(i);
        let intel: ref<GRIntelSystem> = GRIntelSystem.Get(this.GetGameInstance());
        if IsDefined(intel) && intel.IsLocated(gang) {
            return false;
        }
        let stronghold: ref<GRStronghold> = GRStronghold.Get(this.GetGameInstance());
        if !IsDefined(stronghold) {
            return false;
        }
        let lair: Vector4 = stronghold.GetGangSitePosition(gang);
        if Vector4.IsZero(lair) {
            return false;
        }
        radius = GRBounties.LairRadius(IsDefined(intel) ? intel.GetIntel(gang) : 0);
        cx = lair.X + this.m_zoneCX[i] * radius;
        cy = lair.Y + this.m_zoneCY[i] * radius;
        cz = lair.Z;
        return true;
    }

    private func RemovePins(system: ref<MappinSystem>, zone: ref<GRBountyZone>) {
        if zone.hasCenter {
            system.UnregisterMappin(zone.center);
            zone.hasCenter = false;
        }
        for pin in zone.ring {
            system.UnregisterMappin(pin);
        }
        ArrayClear(zone.ring);
        if zone.hasCircle {
            system.UnregisterMappin(zone.circle);
            zone.hasCircle = false;
        }
    }

    // Circulo nativo del minimapa: un mappin con GameplayRoleMappinData en el centro de la zona. Solo minimapa (no mapa grande ni mundo).
    private func AddCircle(system: ref<MappinSystem>, zone: ref<GRBountyZone>, id: Int32, cx: Float, cy: Float, cz: Float, radius: Float) {
        let data: MappinData;
        data.mappinType = this.m_zoneCustom ? t"Mappins.GRZoneCircleMappinDefinition" : t"Mappins.DeviceMappinDefinition";
        // Variante propia (WorldMap.GRZoneCircleVariant, intel.yaml), no gamedataMappinVariant.GenericRoleVariant: esa es
        // compartida por muchisimos mappins del juego, y al compartirla el filtro del mapa grande (casilla GANG RETALIATION,
        // WorldMap.GRStrongholdFilterGroup) terminaba enganchado a pins ajenos a este mod (tildar/destildar la casilla no
        // hacia nada, destildar todo dejaba pins de otros sistemas ocultos). Arreglado 2026-11-21.
        data.variant = gamedataMappinVariant.CPO_RemotePlayerVariant;
        data.active = true;
        let circle: ref<GRZoneCircleData> = new GRZoneCircleData();
        circle.nemesisId = id;
        circle.colorMode = this.ColorMode();
        circle.m_showOnMiniMap = true;
        circle.m_isCurrentTarget = true;
        circle.m_range = this.m_zoneForceRadius > 0.0 ? this.m_zoneForceRadius : radius;
        circle.m_textureID = t"MappinIcons.HuntForPsychoMappin";
        data.scriptData = circle;
        // Se corre 1 m en X/Y/Z respecto del pin central: con el mappin del circulo EXACTAMENTE en la misma posicion que el pin central
        // (modo 1) el sistema devolvia los datos del pin central para el circulo y el minimapa nunca creaba el controlador del circulo.
        zone.circle = system.RegisterMappin(data, new Vector4(cx + 1.0, cy + 1.0, cz + 1.0, 1.0));
        zone.hasCircle = true;
    }

    // Datos del pin de zona del mapa grande (central o de anillo).
    private func ZoneData(i: Int32, isCenter: Bool) -> MappinData {
        let data: MappinData;
        data.mappinType = t"Mappins.GRBountyZoneMappinDefinition";
        data.variant = gamedataMappinVariant.CPO_PingLootVariant;
        data.active = true;
        let mark: ref<GRBountyZoneMappinData> = new GRBountyZoneMappinData();
        mark.nemesisId = this.m_ids[i];
        mark.center = isCenter;
        mark.boss = this.m_zoneSets[i] == 2;
        mark.name = this.NameOf(this.m_ids[i]);
        data.scriptData = mark;
        return data;
    }

    private func AddCenter(system: ref<MappinSystem>, zone: ref<GRBountyZone>, i: Int32, cx: Float, cy: Float, cz: Float) {
        zone.center = system.RegisterMappin(this.ZoneData(i, true), new Vector4(cx, cy, cz, 1.0));
        zone.hasCenter = true;
    }

    // Pin central de RESPALDO en el mapa grande (modo 2, el de por defecto): solo cuando el encargo del journal (GigZone.reds) no marca este contrato,
    // o sea si no es el primer aceptado (el encargo tiene 1 sola ranura) o el encargo esta suprimido (dev) o no esta en el journal.
    // Mientras el encargo esta programado/mostrado para este contrato no hay pin (el encargo pone su propio pin y el GPS).
    private func NeedsCenterPin(i: Int32, zone: ref<GRBountyZone>) -> Bool {
        if zone.centerBlocked {
            return false;
        }
        if this.m_gigSuppress {
            return true;
        }
        let journal: ref<JournalManager> = GameInstance.GetJournalManager(this.GetGameInstance());
        if !IsDefined(journal) || !GRGigZone.Present(journal) {
            return true;
        }
        return this.FirstWithState(0) != i;
    }

    private func AddPins(system: ref<MappinSystem>, zone: ref<GRBountyZone>, i: Int32, cx: Float, cy: Float, cz: Float, radius: Float) {
        let id: Int32 = this.m_ids[i];
        let mode: Int32 = this.ZoneMode();
        // El circulo solo con radio <= MinimapCircleMaxRadius (el Jefe de 250/400 m no lleva circulo).
        if mode != 0 && radius <= GRBounties.MinimapCircleMaxRadius() {
            this.AddCircle(system, zone, id, cx, cy, cz, radius);
        }
        if mode != 2 {
            // Modos dev 0 y 1: pin central + anillo de pines "?" (por defecto NO se usa).
            this.AddCenter(system, zone, i, cx, cy, cz);
            let count: Int32 = GRBounties.ZoneRingPins(radius);
            let k: Int32 = 0;
            while k < count {
                let angle: Float = 2.0 * Pi() * Cast<Float>(k) / Cast<Float>(count);
                let pin: NewMappinID = system.RegisterMappin(this.ZoneData(i, false), new Vector4(cx + CosF(angle) * radius, cy + SinF(angle) * radius, cz, 1.0));
                system.SetMappinTrackingAlternative(pin, zone.center);
                ArrayPush(zone.ring, pin);
                k += 1;
            }
        } else if this.NeedsCenterPin(i, zone) {
            this.AddCenter(system, zone, i, cx, cy, cz);
        }
        zone.circleChecked = false;
        zone.kind = this.m_zoneSets[i];
        zone.cx = cx;
        zone.cy = cy;
        zone.cz = cz;
        zone.radius = radius;
    }

    // Cada Tick, por zona ya armada: pin central de respaldo (modo 2), verificacion del circulo y color del circulo segun V este adentro o afuera.
    private func UpdateZone(system: ref<MappinSystem>, zone: ref<GRBountyZone>, i: Int32) {
        if this.ZoneMode() == 2 {
            let need: Bool = this.NeedsCenterPin(i, zone);
            if need && !zone.hasCenter {
                this.AddCenter(system, zone, i, zone.cx, zone.cy, zone.cz);
                zone.circleChecked = false;
                GRLog("Zona #" + IntToString(zone.nemesisId) + ": pin central de respaldo en el mapa grande (el encargo no marca este contrato)");
            } else {
                if !need && zone.hasCenter {
                    system.UnregisterMappin(zone.center);
                    zone.hasCenter = false;
                    GRLog("Zona #" + IntToString(zone.nemesisId) + ": pin central de respaldo quitado (lo marca el encargo)");
                }
            }
        }
        if !zone.hasCircle {
            return;
        }
        let mappin: ref<IMappin> = system.GetMappin(zone.circle);
        let data: ref<GRZoneCircleData> = IsDefined(mappin) ? mappin.GetScriptData() as GRZoneCircleData : null;
        if !zone.circleChecked {
            zone.circleChecked = true;
            if IsDefined(data) {
                GRLog("Zona #" + IntToString(zone.nemesisId) + ": circulo del minimapa verificado (el sistema devuelve sus datos)");
            } else {
                if zone.hasCenter && !zone.centerBlocked && this.ZoneMode() == 2 {
                    // El pin central pisa al circulo: se prefiere el circulo (minimapa). Se quita el pin de respaldo y se rearma el circulo.
                    system.UnregisterMappin(zone.center);
                    zone.hasCenter = false;
                    zone.centerBlocked = true;
                    system.UnregisterMappin(zone.circle);
                    zone.hasCircle = false;
                    this.AddCircle(system, zone, zone.nemesisId, zone.cx, zone.cy, zone.cz, zone.radius);
                    zone.circleChecked = false;
                    GRLog("Zona #" + IntToString(zone.nemesisId) + ": el pin central de respaldo pisaba al circulo, se quita y se rearma el circulo");
                } else {
                    GRLog("Zona #" + IntToString(zone.nemesisId) + ": ERROR el sistema no devuelve los datos del circulo");
                }
            }
            return;
        }
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(data) || !IsDefined(player) {
            return;
        }
        let inside: Bool = Vector4.Distance2D(player.GetWorldPosition(), new Vector4(zone.cx, zone.cy, 0.0, 1.0)) <= data.m_range;
        if (inside && !data.inside) || (!inside && data.inside) {
            data.SetInside(inside);
            system.SetMappinScriptData(zone.circle, data);
            GRLog("Zona #" + IntToString(zone.nemesisId) + ": V " + (inside ? "entro al" : "salio del") + " circulo (radio " + IntToString(Cast<Int32>(data.m_range)) + " m)");
        }
    }

    // Hilo principal (Tick): arma, mueve y borra los pines de las zonas segun el estado de los contratos.
    // Los pines no se guardan: al cargar partida m_zones esta vacio y se rearman aca.
    private func RefreshZones() {
        this.Repair();
        let system: ref<MappinSystem> = GameInstance.GetMappinSystem(this.GetGameInstance());
        if !IsDefined(system) {
            return;
        }
        this.m_zoneTick += 1;
        let cx: Float;
        let cy: Float;
        let cz: Float;
        let radius: Float;
        let z: Int32 = ArraySize(this.m_zones) - 1;
        while z >= 0 {
            let zone: ref<GRBountyZone> = this.m_zones[z];
            let i: Int32 = this.AcceptedIndex(zone.nemesisId);
            let keep: Bool = i >= 0 && this.ZoneTarget(i, cx, cy, cz, radius);
            if !keep {
                this.RemovePins(system, zone);
                ArrayErase(this.m_zones, z);
                GRLog("Zona #" + IntToString(zone.nemesisId) + ": pines borrados (" + (i < 0 ? "contrato cerrado" : "guarida localizada o sin guarida") + ")");
            } else {
                if AbsF(zone.cx - cx) > 1.0 || AbsF(zone.cy - cy) > 1.0 || AbsF(zone.radius - radius) > 1.0 || AbsF(zone.cz - cz) > 4.0 {
                    this.RemovePins(system, zone);
                    this.AddPins(system, zone, i, cx, cy, cz, radius);
                    GRLog("Zona #" + IntToString(zone.nemesisId) + ": pines/circulo movidos (guarida mudada o mas intel), radio " + IntToString(Cast<Int32>(radius)) + " m");
                } else {
                    this.UpdateZone(system, zone, i);
                }
            }
            z -= 1;
        }
        let retry: Bool = this.m_zoneTick % 30 == 1;
        let n: Int32 = Min(ArraySize(this.m_ids), ArraySize(this.m_states));
        let k: Int32 = 0;
        while k < n {
            if this.m_states[k] == 0 {
                if this.m_zoneSets[k] == 0 && retry {
                    this.SetupZone(k, true);
                }
                if this.m_zoneSets[k] > 0 && !IsDefined(this.FindZone(this.m_ids[k])) && this.ZoneTarget(k, cx, cy, cz, radius) {
                    let created: ref<GRBountyZone> = new GRBountyZone();
                    created.nemesisId = this.m_ids[k];
                    this.AddPins(system, created, k, cx, cy, cz, radius);
                    ArrayPush(this.m_zones, created);
                    GRLog("Zona #" + IntToString(created.nemesisId) + ": " + (created.hasCenter ? "pin central + " + IntToString(ArraySize(created.ring)) + " pines en anillo" : "sin pines en el mapa grande")
                        + (created.hasCircle ? " + circulo del minimapa" : " (sin circulo)") + " (modo " + IntToString(this.ZoneMode()) + ", radio "
                        + IntToString(Cast<Int32>(radius)) + " m, " + (created.kind == 2 ? "guarida del Jefe" : "caza") + ")");
                }
            }
            k += 1;
        }
    }

    private func OnDetach() {
        let system: ref<MappinSystem> = GameInstance.GetMappinSystem(this.GetGameInstance());
        if IsDefined(system) {
            for zone in this.m_zones {
                this.RemovePins(system, zone);
            }
        }
        ArrayClear(this.m_zones);
    }

    // ---- Encargo nativo del journal (GigZone.reds) ----

    // Al aceptar: el encargo aparece GRGigZone.Delay() segundos despues de que salga el SMS de "aceptado" (OnAcceptSent).
    // Si el SMS tarda mas de 40 s en salir, aparece igual (red de seguridad).
    private func ScheduleGig() {
        this.m_gigSuppress = false;
        if this.m_gigShown > 0 || this.m_gigStep > 0 {
            return;
        }
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());
        if !IsDefined(spawner) {
            return;
        }
        this.m_gigNotify = true;
        this.m_gigDue = spawner.GetTime() + 40.0;
    }

    private func OnAcceptSent(now: Float) {
        if this.m_gigNotify && this.m_gigShown == 0 && this.m_gigStep == 0 {
            this.m_gigDue = now + GRGigZone.Delay();
            GRLog("Gig: SMS de aceptado enviado, el encargo aparece en " + IntToString(Cast<Int32>(GRGigZone.Delay())) + " s");
        }
    }

    // Nombre del Nemesis del encargo (para los textos de UI con {0}): el del primer contrato aceptado.
    public func GigName() -> String {
        let i: Int32 = this.FirstWithState(0);
        if i >= 0 && i < ArraySize(this.m_ids) {
            return this.NameOf(this.m_ids[i]);
        }
        return this.Text("GR-BountyUnknown");
    }

    public func GigState() -> String {
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());
        let now: Float = IsDefined(spawner) ? spawner.GetTime() : 0.0;
        let zone: ref<GRGigZone> = GRGigZone.Get();
        return "gig mostrado=" + (this.m_gigShown > 0 ? "#" + IntToString(this.m_gigShown - 1) : "no") + " paso=" + IntToString(this.m_gigStep)
            + " programado=" + (this.m_gigNotify && this.m_gigDue > 0.0 ? FloatToStringPrec(this.m_gigDue - now, 1) + " s" : "no")
            + " suprimido=" + GRGigZone.Flag(this.m_gigSuppress) + " modo=" + (IsDefined(zone) ? GRGigZone.ModeName(zone.GetMode()) : "?");
    }

    private func StopGig(reason: String) {
        let journal: ref<JournalManager> = GameInstance.GetJournalManager(this.GetGameInstance());
        let result: String = IsDefined(journal) ? GRGigZone.Deactivate(journal) : "sin journal";
        this.m_gigShown = 0;
        this.m_gigFor = 0;
        this.m_gigStep = 0;
        GRLog("Gig: bajado (" + reason + ") -> " + result);
    }

    // Hilo principal (Tick). Maquina de pasos, sin nada persistido:
    //   reposo -> Place (posicion cocinada + marcador, mappins apagados) -> 1 s -> activar quest + mappins -> 1 s -> seguir el objetivo.
    // Aceptado en vivo: espera el SMS + GRGigZone.Delay() y avisa ("NUEVO CURRO"). Tras cargar partida o mover la zona: sin aviso.
    private func TickGig() {
        let gi: GameInstance = this.GetGameInstance();
        let zone: ref<GRGigZone> = GRGigZone.Get();
        let journal: ref<JournalManager> = GameInstance.GetJournalManager(gi);
        let spawner: ref<GRSpawner> = GRSpawner.Get(gi);
        if !IsDefined(zone) || !IsDefined(journal) || !IsDefined(spawner) {
            return;
        }
        if !GRGigZone.Present(journal) {
            return;
        }
        let now: Float = spawner.GetTime();
        let accepted: Int32 = this.FirstWithState(0);
        if !this.m_gigChecked {
            this.m_gigChecked = true;
            if accepted < 0 && GRGigZone.IsQuestActive(journal) {
                GRLog("Gig: la partida guardo el encargo activo pero no hay contrato aceptado, se desactiva -> " + GRGigZone.Deactivate(journal));
            }
        }
        if accepted < 0 {
            if this.m_gigShown > 0 || this.m_gigStep > 0 {
                this.StopGig("ya no hay contrato aceptado (cobrado, fallido o vencido)");
            }
            this.m_gigNotify = false;
            this.m_gigDue = 0.0;
            return;
        }
        let id: Int32 = this.m_ids[accepted];
        if (this.m_gigShown > 0 || this.m_gigStep > 0) && this.m_gigFor != id + 1 {
            this.StopGig("cambio el primer contrato aceptado");
        }
        if this.m_gigSuppress {
            return;
        }
        let cx: Float;
        let cy: Float;
        let cz: Float;
        let radius: Float;
        if !this.ZoneTarget(accepted, cx, cy, cz, radius) {
            if this.m_gigShown > 0 || this.m_gigStep > 0 {
                this.StopGig("el contrato ya no tiene zona");
            }
            return;
        }
        if this.m_gigStep == 0 {
            if this.m_gigShown > 0 {
                if AbsF(this.m_gigX - cx) > 1.0 || AbsF(this.m_gigY - cy) > 1.0 {
                    this.StopGig("la zona se movio, se rearma");
                } else if this.m_gigPinChecks > 0 && now >= this.m_gigPinAt {
                    // Debe haber UN solo "!" de quest en el centro: se loguea cuantos pines vivos hay y se apagan los de quest sobrantes.
                    this.m_gigPinChecks -= 1;
                    this.m_gigPinAt = now + 5.0;
                    GRLog("Gig: pines vivos (chequeo, quedan " + IntToString(this.m_gigPinChecks) + ") | " + GRGigZone.PinReport(gi, new Vector4(this.m_gigX, this.m_gigY, cz, 1.0), true));
                }
                return;
            }
            if this.m_gigNotify && (this.m_gigDue <= 0.0 || now < this.m_gigDue) {
                return;
            }
            let player: ref<PlayerPuppet> = GetPlayer(gi);
            let fallback: Float = 0.0;
            if IsDefined(player) {
                let where: Vector4 = player.GetWorldPosition();
                fallback = where.Z;
            }
            let z: Float = GRGigZone.SafeZ(cz, fallback);
            let placed: String = zone.Place(gi, journal, cx, cy, z, radius);
            this.m_gigLoud = this.m_gigNotify;
            this.m_gigNotify = false;
            this.m_gigDue = 0.0;
            this.m_gigStep = 1;
            this.m_gigStepAt = now;
            this.m_gigFor = id + 1;
            this.m_gigX = cx;
            this.m_gigY = cy;
            GRLog("Gig: #" + IntToString(id) + " (" + this.NameOf(id) + ") colocado " + (this.m_gigLoud ? "con aviso" : "sin aviso") + " (Z zona " + FloatToStringPrec(cz, 1)
                + ", Z usada " + FloatToStringPrec(z, 1) + ") -> " + placed);
            return;
        }
        if this.m_gigStep == 1 && now - this.m_gigStepAt >= 1.0 {
            let activated: String = zone.ActivateAll(journal, this.m_gigLoud);
            this.m_gigStep = 2;
            this.m_gigStepAt = now;
            GRLog("Gig: activado -> " + activated);
        } else if this.m_gigStep == 2 && now - this.m_gigStepAt >= 1.0 {
            let tracked: String = GRGigZone.TrackObjective(journal);
            this.m_gigStep = 0;
            this.m_gigShown = this.m_gigFor;
            this.m_gigPinChecks = 3;
            this.m_gigPinAt = now + 3.0;
            GRLog("Gig: " + tracked + " | " + GRGigZone.MarkerInfo(gi) + " | " + GRGigZone.MappinReport(gi, journal));
        }
    }

    // Lo llama GRStronghold.Tick: el punto de caza aceptado mas cercano a V dentro de maxDist.
    public func NearestHunt(from: Vector4, maxDist: Float, out nemesisId: Int32, out spot: Vector4) -> Bool {
        let n: Int32 = Min(Min(ArraySize(this.m_ids), ArraySize(this.m_states)), Min(ArraySize(this.m_zoneSets), ArraySize(this.m_zoneZ)));
        n = Min(n, Min(ArraySize(this.m_zoneX), ArraySize(this.m_zoneY)));
        n = Min(n, ArraySize(this.m_conds));
        let best: Float = -1.0;
        let cx: Float;
        let cy: Float;
        let cz: Float;
        let radius: Float;
        let i: Int32 = 0;
        while i < n {
            if this.m_states[i] == 0 && this.m_zoneSets[i] == 1 && this.m_conds[i] != GRBounties.LairCond() {
                let pos: Vector4 = new Vector4(this.m_zoneX[i], this.m_zoneY[i], this.m_zoneZ[i], 1.0);
                let distance: Float = Vector4.Distance2D(from, pos);
                // Ademas de estar a <= maxDist del punto real, V tiene que estar dentro del circulo (+ margen): el Nemesis aparece al entrar a la zona.
                let inside: Bool = !this.ZoneTarget(i, cx, cy, cz, radius)
                    || Vector4.Distance2D(from, new Vector4(cx, cy, 0.0, 1.0)) <= radius + GRBounties.HuntSpawnMargin();
                if distance <= maxDist && inside && (best < 0.0 || distance < best) {
                    let entry: ref<GRMenuEntry> = this.FindEntry(this.m_ids[i]);
                    if !IsDefined(entry) || !entry.dead {
                        best = distance;
                        nemesisId = this.m_ids[i];
                        spot = pos;
                    }
                }
            }
            i += 1;
        }
        return best >= 0.0;
    }

    public func AcceptAt(index: Int32, nemesisId: Int32) -> String {
        this.Repair();
        if index < 0 || index >= ArraySize(this.m_ids) || this.m_ids[index] != nemesisId {
            return "contrato no encontrado";
        }
        if this.m_states[index] != 3 {
            return "el contrato #" + IntToString(nemesisId) + " no es una oferta";
        }
        if this.AcceptedCount() >= GRBounties.MaxOpen() {
            return "cupo lleno (" + IntToString(this.AcceptedCount()) + "/" + IntToString(GRBounties.MaxOpen()) + " aceptados)";
        }
        this.Accept(index);
        return "aceptado #" + IntToString(nemesisId) + " (" + this.NameOf(nemesisId) + ")";
    }

    public func OnDeath(nemesisId: Int32, kind: String, cause: String, inLair: Bool) {
        this.Repair();
        let i: Int32 = this.OpenIndex(nemesisId);
        if i < 0 {
            return;
        }
        let today: Int32 = this.Today();
        if NotEquals(cause, "v") {
            this.Fail(i, 2, today);
            return;
        }
        // Cualquier derribo hecho por V cobra (noqueo, muerte normal o confirmada): kind solo se usa en el log. El contrato de Jefe/guarida exige que caiga EN su guarida.
        let ok: Bool = true;
        if this.m_conds[i] == GRBounties.LairCond() {
            ok = ok && inLair;
            GRLog("Bounty: #" + IntToString(nemesisId) + " (contrato de guarida) abatido por V " + (inLair ? "EN su guarida" : "FUERA de su guarida") + " (" + kind + ")");
        }
        if ok {
            if this.m_states[i] == 3 {
                this.Fail(i, 3, today);
            } else {
                this.Pay(i, today);
            }
            return;
        }
        this.m_vDown[i] = 1;
        GRLog("Bounty: #" + IntToString(nemesisId) + " abatido por V (" + kind + ") sin cumplir cond=" + GRBounties.CondKey(this.m_conds[i]) + ", el contrato sigue abierto"
            + (this.m_states[i] == 3 ? " (oferta sin aceptar)" : ""));
    }

    public func OnWeaknessHit(nemesisId: Int32) {
        let n: Int32 = Min(Min(ArraySize(this.m_ids), ArraySize(this.m_states)), Min(ArraySize(this.m_bonuses), ArraySize(this.m_bonusUsed)));
        let i: Int32 = 0;
        while i < n {
            if this.m_ids[i] == nemesisId && this.m_states[i] == 0 && this.m_bonuses[i] > 0 && this.m_bonusUsed[i] == 0 {
                this.m_bonusUsed[i] = 1;
                GRLog("Bounty: bono de debilidad conseguido #" + IntToString(nemesisId) + " (+€$" + IntToString(this.m_bonuses[i]) + ")");
            }
            i += 1;
        }
    }

    public func DevOffer() -> String {
        this.Repair();
        let result: String;
        if this.OfferedCount() >= GRBounties.MaxOffers() {
            result = "ofertas pendientes llenas (" + IntToString(this.OfferedCount()) + "/" + IntToString(GRBounties.MaxOffers()) + ")";
        } else {
            result = this.Offer(this.Today());
        }
        GRLog("Bounty: DevOffer -> " + result);
        return result;
    }

    public func DevAccept() -> String {
        this.Repair();
        let result: String;
        let i: Int32 = this.FirstWithState(3);
        if i < 0 {
            result = "no hay ofertas pendientes";
        } else {
            result = this.AcceptAt(i, this.m_ids[i]);
        }
        GRLog("Bounty: DevAccept -> " + result);
        return result;
    }

    public func DevComplete() -> String {
        this.Repair();
        let result: String;
        let i: Int32 = this.FirstWithState(0);
        if i < 0 {
            i = this.FirstWithState(3);
            if i >= 0 {
                let accepted: String = this.AcceptAt(i, this.m_ids[i]);
                if !StrBeginsWith(accepted, "aceptado") {
                    i = -1;
                    result = "no se pudo aceptar la oferta: " + accepted;
                }
            } else {
                result = "no hay contratos abiertos";
            }
        }
        if i >= 0 {
            this.Pay(i, this.Today());
            result = "cobrado #" + IntToString(this.m_ids[i]) + " (" + this.NameOf(this.m_ids[i]) + ") €$" + IntToString(this.m_paids[i]) + ", " + IntToString(this.m_xps[i]) + " XP";
        }
        GRLog("Bounty: DevComplete -> " + result);
        return result;
    }

    public func DevFail() -> String {
        this.Repair();
        let result: String;
        let i: Int32 = 0;
        let found: Int32 = -1;
        while i < ArraySize(this.m_states) && found < 0 {
            if GRBounties.IsOpenState(this.m_states[i]) {
                found = i;
            }
            i += 1;
        }
        if found < 0 {
            result = "no hay contratos abiertos";
        } else {
            this.Fail(found, 1, this.Today());
            result = "fallido #" + IntToString(this.m_ids[found]) + " (" + this.NameOf(this.m_ids[found]) + ")";
        }
        GRLog("Bounty: DevFail -> " + result);
        return result;
    }

    public func DevBossOffer() -> String {
        this.Repair();
        let result: String;
        if this.OfferedCount() >= GRBounties.MaxOffers() {
            result = "ofertas pendientes llenas (" + IntToString(this.OfferedCount()) + "/" + IntToString(GRBounties.MaxOffers()) + ")";
        } else {
            result = this.OfferBoss(this.Today());
        }
        GRLog("Bounty: DevBossOffer -> " + result);
        return result;
    }

    // Estado de las zonas de los contratos aceptados (para probar por REDnode).
    public func DevZone() -> String {
        this.Repair();
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let result: String = "";
        let i: Int32 = 0;
        while i < ArraySize(this.m_ids) {
            if this.m_states[i] == 0 {
                let id: Int32 = this.m_ids[i];
                let zone: ref<GRBountyZone> = this.FindZone(id);
                let line: String = "#" + IntToString(id) + " " + this.NameOf(id) + " cond=" + GRBounties.CondKey(this.m_conds[i]) + " zona=" + IntToString(this.m_zoneSets[i])
                    + " pista=" + IntToString(this.ZoneHint(i));
                if IsDefined(zone) {
                    line += " pines=" + IntToString(ArraySize(zone.ring) + (zone.hasCenter ? 1 : 0)) + " radio=" + IntToString(Cast<Int32>(zone.radius));
                    if IsDefined(player) {
                        line += " V al centro " + IntToString(Cast<Int32>(Vector4.Distance2D(player.GetWorldPosition(), new Vector4(zone.cx, zone.cy, 0.0, 1.0)))) + " m";
                    }
                } else {
                    line += " sin pines";
                }
                if this.m_zoneSets[i] == 1 && IsDefined(player) {
                    line += ", al punto real " + IntToString(Cast<Int32>(Vector4.Distance2D(player.GetWorldPosition(), new Vector4(this.m_zoneX[i], this.m_zoneY[i], this.m_zoneZ[i], 1.0)))) + " m";
                }
                result += (StrLen(result) > 0 ? " | " : "") + line;
            }
            i += 1;
        }
        if StrLen(result) == 0 {
            result = "no hay contratos aceptados";
        }
        GRLog("Bounty: DevZone -> " + result);
        return result;
    }

    // Dev: modo de dibujo de la zona. 2 = circulo del minimapa + pin central de respaldo (por defecto), 0 = solo anillo de pines, 1 = anillo + circulo.
    // Borra y rearma los pines de las zonas existentes en el siguiente Tick (RefreshZones los vuelve a crear).
    public func DevZoneMode(mode: Int32) -> String {
        if mode < 0 || mode > 2 {
            return "modo invalido (0 anillo, 1 anillo + circulo minimapa, 2 circulo minimapa + pin de respaldo, por defecto)";
        }
        this.m_zoneModeP1 = mode + 1;
        this.ResetZones();
        let result: String = "modo de zona = " + IntToString(mode) + " (" + this.ZoneModeName() + ")";
        GRLog("Bounty: DevZoneMode -> " + result);
        return result;
    }

    // Dev: true (por defecto) = el circulo usa Mappins.DeviceMappinDefinition del juego; false = Mappins.GRZoneCircleMappinDefinition (propia, para probar).
    public func DevZoneVanilla(on: Bool) -> String {
        this.m_zoneCustom = !on;
        this.ResetZones();
        let result: String = "definicion del circulo = " + (on ? "Mappins.DeviceMappinDefinition (juego)" : "Mappins.GRZoneCircleMappinDefinition (propia)");
        GRLog("Bounty: DevZoneVanilla -> " + result);
        return result;
    }

    // Dev: fuerza el radio (metros) del circulo del minimapa y lo rearma al instante. DevZoneRadius(0.0) vuelve al radio real de la zona.
    public func DevZoneRadius(radius: Float) -> String {
        this.m_zoneForceRadius = radius > 0.0 ? radius : 0.0;
        this.ResetZones();
        let result: String = this.m_zoneForceRadius > 0.0 ? "radio del circulo forzado = " + IntToString(Cast<Int32>(this.m_zoneForceRadius)) + " m" : "radio del circulo = real de la zona";
        GRLog("Bounty: DevZoneRadius -> " + result);
        return result;
    }

    private func ZoneMode() -> Int32 {
        return this.m_zoneModeP1 == 0 ? 2 : this.m_zoneModeP1 - 1;
    }

    private func ColorMode() -> Int32 {
        return this.m_colorModeP1 == 0 ? GRBounties.ZoneColorModeDefault() : this.m_colorModeP1 - 1;
    }

    // Dev: modo de color del circulo del minimapa cuando V esta adentro (se aplica en vivo, sin rearmar el circulo). Probar DENTRO de la zona y comparar en pantalla:
    //   0 sin cambio | 1 re-enlace del tinte + SetTintColor | 2 solo SetTintColor | 3 solo re-enlace | 4 solo estado Quest | 5 (por defecto) 1 + estado Quest | 6 1 + tinte de la raiz.
    // Por REDnode: api_read GRBounties.Get -> api_call self=<ref> fn=DevZoneColorMode args=[n].
    public func DevZoneColorMode(mode: Int32) -> String {
        if mode < 0 || mode > 6 {
            return "modo invalido (0 nada, 1 bind+tinte, 2 solo tinte, 3 solo bind, 4 solo estado Quest, 5 bind+tinte+Quest por defecto, 6 bind+tinte+raiz)";
        }
        this.m_colorModeP1 = mode + 1;
        let system: ref<MappinSystem> = GameInstance.GetMappinSystem(this.GetGameInstance());
        let applied: Int32 = 0;
        if IsDefined(system) {
            for zone in this.m_zones {
                if zone.hasCircle {
                    let mappin: ref<IMappin> = system.GetMappin(zone.circle);
                    let data: ref<GRZoneCircleData> = IsDefined(mappin) ? mappin.GetScriptData() as GRZoneCircleData : null;
                    if IsDefined(data) {
                        data.SetColorMode(mode);
                        system.SetMappinScriptData(zone.circle, data);
                        applied += 1;
                    }
                }
            }
        }
        let result: String = "modo de color del circulo = " + GRBounties.ZoneColorModeName(mode) + " (aplicado a " + IntToString(applied) + " circulo(s); se nota con V dentro de la zona)";
        GRLog("Bounty: DevZoneColorMode -> " + result);
        return result;
    }

    private func ZoneModeName() -> String {
        if this.ZoneMode() == 0 {
            return "dev: solo anillo de pines";
        }
        if this.ZoneMode() == 2 {
            return "circulo del minimapa + pin central de respaldo en el mapa grande";
        }
        return "dev: anillo + circulo del minimapa";
    }

    private func ResetZones() {
        let system: ref<MappinSystem> = GameInstance.GetMappinSystem(this.GetGameInstance());
        if IsDefined(system) {
            for zone in this.m_zones {
                this.RemovePins(system, zone);
            }
        }
        ArrayClear(this.m_zones);
        this.RefreshZones();
    }

    // Dev: estado del circulo del minimapa por zona. Por REDnode: api_read GRBounties.Get -> api_call self=<ref> fn=DevZoneInfo.
    public func DevZoneInfo() -> String {
        this.Repair();
        let system: ref<MappinSystem> = GameInstance.GetMappinSystem(this.GetGameInstance());
        let result: String = "modo=" + IntToString(this.ZoneMode()) + " (" + this.ZoneModeName() + ") definicion=" + (this.m_zoneCustom ? "propia" : "juego")
            + " radio_circulo=" + (this.m_zoneForceRadius > 0.0 ? "FORZADO " + IntToString(Cast<Int32>(this.m_zoneForceRadius)) + " m" : "real")
            + " zonas=" + IntToString(ArraySize(this.m_zones));
        for zone in this.m_zones {
            let line: String = " | #" + IntToString(zone.nemesisId) + " radio=" + IntToString(Cast<Int32>(zone.radius)) + " centro=" + IntToString(Cast<Int32>(zone.cx)) + ","
                + IntToString(Cast<Int32>(zone.cy)) + " anillo=" + IntToString(ArraySize(zone.ring) + (zone.hasCenter ? 1 : 0)) + " circulo=" + (zone.hasCircle ? "registrado" : "no");
            if zone.kind == 1 {
                let s: Int32 = this.SurfFind(zone.nemesisId);
                line += " Z_punto=" + FloatToStringPrec(zone.cz, 1);
                if s >= 0 {
                    line += " Z_POI=" + FloatToStringPrec(this.m_surfPoiZ[s], 1) + " Z_superficie=" + (this.m_surfTop[s] != 0.0 ? FloatToStringPrec(this.m_surfTop[s], 1) : "sin datos")
                        + " validado=" + (this.m_surfOk[s] ? "si" : "no (pendiente, se revalida a < 200 m o con DevZoneRevalidate)");
                } else {
                    line += " Z_superficie=sin datos validado=no (pendiente, se revalida a < 200 m o con DevZoneRevalidate)";
                }
                line += " " + this.ReachText(this.AcceptedIndex(zone.nemesisId));
            }
            if zone.hasCircle && IsDefined(system) {
                let mappin: ref<IMappin> = system.GetMappin(zone.circle);
                if IsDefined(mappin) {
                    let pos: Vector4 = mappin.GetWorldPosition();
                    let data: ref<GRZoneCircleData> = mappin.GetScriptData() as GRZoneCircleData;
                    line += " mappin=existe activo=" + GRGigZone.Flag(mappin.IsActive()) + " pos=" + IntToString(Cast<Int32>(pos.X)) + "," + IntToString(Cast<Int32>(pos.Y));
                    if IsDefined(data) {
                        line += " m_range=" + IntToString(Cast<Int32>(data.m_range)) + " controlador_minimapa(updates)=" + IntToString(data.updates) + " cayo_en_POI=" + IntToString(data.poiHit);
                        line += " dentro=" + GRGigZone.Flag(data.inside) + " tinte(base_guardado=" + GRGigZone.Flag(data.hasBase) + ", aplicado=" + GRGigZone.Flag(data.tinted)
                            + ", raiz=" + GRGigZone.Flag(data.rootTinted) + ") color_modo=" + GRBounties.ZoneColorModeName(data.colorMode) + " m_isQuest=" + GRGigZone.Flag(data.m_isQuest);
                    } else {
                        line += " sin datos GRZoneCircleData";
                    }
                } else {
                    line += " mappin=NO existe en el sistema";
                }
            }
            result += line;
        }
        GRLog("Bounty: DevZoneInfo -> " + result);
        return result;
    }

    // Suelo bajo (x, y) para un teletransporte: prueba ventanas de rayo hacia abajo (alrededor de la Z del punto de caza si es valida,
    // despues alrededor de la Z de V, despues una ventana ancha) y se queda con la superficie mas alta de la primera ventana con impacto.
    // false = no hay colision cargada (zona sin streamear): en ese caso NO se debe teletransportar.
    private func GoGround(x: Float, y: Float, hint: Float, refZ: Float, out groundZ: Float, out window: String) -> Bool {
        let tops: array<Float>;
        let bottoms: array<Float>;
        let names: array<String>;
        if hint != 0.0 {
            ArrayPush(tops, hint + 4.0);
            ArrayPush(bottoms, hint - 40.0);
            ArrayPush(names, "punto");
        }
        ArrayPush(tops, refZ + 20.0);
        ArrayPush(bottoms, refZ - 60.0);
        ArrayPush(names, "V");
        ArrayPush(tops, refZ + 120.0);
        ArrayPush(bottoms, refZ - 120.0);
        ArrayPush(names, "ancha");
        let i: Int32 = 0;
        while i < ArraySize(tops) {
            if GRGroundBetween(this.GetGameInstance(), x, y, tops[i], bottoms[i], groundZ) {
                window = names[i];
                return true;
            }
            i += 1;
        }
        return false;
    }

    // Destino (a 130 m del punto de caza, hacia el centro del circulo) y Z del punto de caza (0 = invalida/desconocida).
    private func GoTarget(index: Int32, out target: Vector4, out hint: Float) {
        let spot: Vector4 = new Vector4(this.m_zoneX[index], this.m_zoneY[index], this.m_zoneZ[index], 1.0);
        let dir: Vector4 = new Vector4(this.m_zoneCX[index] - spot.X, this.m_zoneCY[index] - spot.Y, 0.0, 0.0);
        if Vector4.Length(dir) < 1.0 {
            dir = new Vector4(1.0, 0.0, 0.0, 0.0);
        }
        target = spot + Vector4.Normalize(dir) * 130.0;
        let safe: Float = GRGigZone.SafeZ(this.m_zoneZ[index], 0.0);
        target.Z = safe;
        hint = safe;
    }

    public func DevZoneGoStatus() -> String {
        return (this.m_goBusy ? "viaje en curso | " : "sin viaje en curso | ") + this.m_goReport;
    }

    // Termina el viaje por etapas y deja el motivo (para DevZoneGoStatus y el log).
    private func GoEnd(report: String) {
        this.m_goBusy = false;
        this.m_goReport = report;
        GRLog("Bounty: DevZoneGoForce -> " + report);
    }

    // Un paso del viaje: hasta 200 m hacia el destino, solo si hay suelo cargado; si no, reintenta (saltos mas cortos) y al final aborta sin mover a V.
    public func ZoneGoStep(step: ref<GRZoneGoStep>) {
        let gi: GameInstance = this.GetGameInstance();
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        if !IsDefined(player) {
            this.GoEnd("abortado: no hay jugador");
            return;
        }
        if VehicleComponent.IsMountedToVehicle(gi, player) {
            this.GoEnd("abortado: V esta en un vehiculo (bajarse y repetir)");
            return;
        }
        let here: Vector4 = player.GetWorldPosition();
        let target: Vector4 = new Vector4(step.tx, step.ty, step.hint, 1.0);
        let dist: Float = Vector4.Distance2D(here, target);
        let isLast: Bool = dist <= 200.0;
        let scales: array<Float> = [1.0, 1.0, 0.6, 0.3];
        let hop: Float = 200.0 * scales[step.tries];
        let nx: Float = step.tx;
        let ny: Float = step.ty;
        if !isLast {
            nx = here.X + (step.tx - here.X) / dist * hop;
            ny = here.Y + (step.ty - here.Y) / dist * hop;
        }
        let groundZ: Float = 0.0;
        let window: String = "";
        let ok: Bool = this.GoGround(nx, ny, isLast ? step.hint : 0.0, here.Z, groundZ, window);
        if !ok {
            step.tries += 1;
            if step.tries >= ArraySize(scales) {
                this.GoEnd("abortado en etapa " + IntToString(step.hops + 1) + ": sin suelo cargado en " + IntToString(Cast<Int32>(nx)) + "," + IntToString(Cast<Int32>(ny))
                    + " tras " + IntToString(step.tries) + " intentos. V se queda en " + IntToString(Cast<Int32>(here.X)) + "," + IntToString(Cast<Int32>(here.Y)) + "," + IntToString(Cast<Int32>(here.Z))
                    + " (a " + IntToString(Cast<Int32>(dist)) + " m del destino " + IntToString(Cast<Int32>(step.tx)) + "," + IntToString(Cast<Int32>(step.ty)) + ")");
            } else {
                this.m_goReport = "etapa " + IntToString(step.hops + 1) + ": sin suelo en " + IntToString(Cast<Int32>(nx)) + "," + IntToString(Cast<Int32>(ny)) + ", reintento " + IntToString(step.tries) + " en 2,5 s";
                GRLog("Bounty: DevZoneGoForce " + this.m_goReport);
                GameInstance.GetDelaySystem(gi).DelayCallback(step, 2.5, false);
            }
            return;
        }
        let dest: Vector4 = new Vector4(nx, ny, groundZ + 1.0, 1.0);
        GameInstance.GetTeleportationFacility(gi).Teleport(player, dest, Vector4.ToRotation(new Vector4(step.tx - nx, step.ty - ny, 0.0, 0.0)));
        step.hops += 1;
        step.tries = 0;
        let line: String = "etapa " + IntToString(step.hops) + ": V en " + IntToString(Cast<Int32>(nx)) + "," + IntToString(Cast<Int32>(ny)) + " Z=" + FloatToStringPrec(groundZ + 1.0, 2)
            + " (suelo " + FloatToStringPrec(groundZ, 2) + ", ventana " + window + ")";
        if isLast {
            this.GoEnd("llegada: " + line + " | destino " + IntToString(Cast<Int32>(step.tx)) + "," + IntToString(Cast<Int32>(step.ty)));
        } else {
            this.m_goReport = line + " | faltan ~" + IntToString(Cast<Int32>(dist - hop)) + " m, siguiente en 3 s";
            GRLog("Bounty: DevZoneGoForce " + this.m_goReport);
            GameInstance.GetDelaySystem(gi).DelayCallback(step, 3.0, false);
        }
    }

    // Lleva a V a 130 m del punto de caza del primer contrato aceptado (fuera del radio de aparicion, para acercarse a pie).
    // Seguro: solo teletransporta con suelo comprobado (rayo hacia abajo). Si el punto esta a mas de 500 m NO mueve a V y avisa (DevZoneGoForce va por etapas).
    public func DevZoneGo() -> String {
        return this.ZoneGo(false);
    }

    // Igual, pero si esta a mas de 300 m viaja por etapas de 200 m con suelo comprobado en cada una (3 s entre etapas para que cargue el mundo).
    // El resultado final queda en DevZoneGoStatus y en el log "Bounty: DevZoneGoForce".
    public func DevZoneGoForce() -> String {
        return this.ZoneGo(true);
    }

    private func ZoneGo(force: Bool) -> String {
        this.Repair();
        let gi: GameInstance = this.GetGameInstance();
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        let result: String = "no hay contratos aceptados con zona de caza";
        let i: Int32 = 0;
        let found: Int32 = -1;
        while i < ArraySize(this.m_ids) && found < 0 {
            if this.m_states[i] == 0 && this.m_zoneSets[i] == 1 {
                found = i;
            }
            i += 1;
        }
        if found >= 0 && IsDefined(player) {
            let label: String = "#" + IntToString(this.m_ids[found]) + " (" + this.NameOf(this.m_ids[found]) + ")";
            let target: Vector4;
            let hint: Float;
            this.GoTarget(found, target, hint);
            let here: Vector4 = player.GetWorldPosition();
            let dist: Float = Vector4.Distance2D(here, target);
            let place: String = "destino " + IntToString(Cast<Int32>(target.X)) + "," + IntToString(Cast<Int32>(target.Y)) + " (Z del punto " + (hint != 0.0 ? FloatToStringPrec(hint, 2) : "invalida") + ")";
            if this.m_goBusy {
                result = "ya hay un viaje en curso: " + this.m_goReport;
            } else if VehicleComponent.IsMountedToVehicle(gi, player) {
                result = "V esta en un vehiculo: bajarse y repetir (no se mueve a V)";
            } else if !force && dist > 500.0 {
                result = label + " esta a " + IntToString(Cast<Int32>(dist)) + " m de V (limite 500 m): ir caminando/en auto. V no se movio. Para ir por etapas con suelo comprobado: DevZoneGoForce | " + place;
            } else if dist <= 300.0 {
                let groundZ: Float = 0.0;
                let window: String = "";
                if this.GoGround(target.X, target.Y, hint, here.Z, groundZ, window) {
                    let dest: Vector4 = new Vector4(target.X, target.Y, groundZ + 1.0, 1.0);
                    GameInstance.GetTeleportationFacility(gi).Teleport(player, dest, Vector4.ToRotation(new Vector4(this.m_zoneX[found] - dest.X, this.m_zoneY[found] - dest.Y, 0.0, 0.0)));
                    result = "V llevada a 130 m del punto de caza de " + label + ": " + place + ", Z usada " + FloatToStringPrec(groundZ + 1.0, 2)
                        + " (suelo " + FloatToStringPrec(groundZ, 2) + ", ventana " + window + "). El Nemesis aparece dentro del circulo y a menos de " + IntToString(Cast<Int32>(GRBounties.HuntSpawnDistance())) + " m del punto";
                } else {
                    result = "sin suelo cargado en el destino de " + label + ": " + place + ". V no se movio (esperar a que cargue el mundo o usar DevZoneGoForce)";
                }
            } else {
                this.m_goBusy = true;
                this.m_goReport = "iniciado hacia " + place;
                let step: ref<GRZoneGoStep> = new GRZoneGoStep();
                step.gi = gi;
                step.tx = target.X;
                step.ty = target.Y;
                step.hint = hint;
                GameInstance.GetDelaySystem(gi).DelayCallback(step, 0.1, false);
                result = label + " esta a " + IntToString(Cast<Int32>(dist)) + " m: viaje por etapas de 200 m con suelo comprobado (unas " + IntToString(Cast<Int32>(dist / 200.0) + 1) + " etapas, 3 s cada una), "
                    + place + ". Ver DevZoneGoStatus o el log 'DevZoneGoForce'. Si no hay suelo cargado aborta sin dejar a V bajo el mapa";
            }
        }
        GRLog("Bounty: DevZoneGo -> " + result);
        return result;
    }

    // Prueba manual del encargo nativo, sin contrato: coloca la zona 120 m delante de V (Z de V) y activa el encargo 1 s despues, lo sigue 2 s despues.
    // El resultado de la activacion y del seguimiento va al log ("Cooked zona: DevGigOn ..."); correr DevGigInfo despues.
    public func DevGigOn() -> String {
        let gi: GameInstance = this.GetGameInstance();
        let zone: ref<GRGigZone> = GRGigZone.Get();
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        let journal: ref<JournalManager> = GameInstance.GetJournalManager(gi);
        let result: String;
        if !IsDefined(zone) || !IsDefined(player) || !IsDefined(journal) {
            result = "falta GRGigZone, el jugador o el journal";
        } else {
            this.m_gigSuppress = false;
            let here: Vector4 = player.GetWorldPosition();
            let ahead: Vector4 = player.GetWorldForward();
            let x: Float = here.X + ahead.X * 120.0;
            let y: Float = here.Y + ahead.Y * 120.0;
            let z: Float = GRGigZone.SafeZ(here.Z, 0.0);
            let placed: String = zone.Place(gi, journal, x, y, z, GRGigZone.Radius());
            let first: ref<GRGigZoneStep> = new GRGigZoneStep();
            first.gi = gi;
            first.step = 1;
            GameInstance.GetDelaySystem(gi).DelayCallback(first, 1.0, false);
            let second: ref<GRGigZoneStep> = new GRGigZoneStep();
            second.gi = gi;
            second.step = 2;
            GameInstance.GetDelaySystem(gi).DelayCallback(second, 2.0, false);
            result = "Z de V " + FloatToStringPrec(here.Z, 2) + " | " + placed + " | activa en 1 s y sigue en 2 s (log 'DevGigOn'), despues correr DevGigInfo";
        }
        GRLog("Bounty: DevGigOn -> " + result);
        return result;
    }

    // Mueve el circulo ~300 m hacia donde mira V. option 1 = A (posicion cocinada + mappin Inactive y Active 0,5 s despues),
    // option 2 = B (MappinSystem.SetMappinPosition sobre el mappin vivo del objetivo, sin tocar la entrada cocinada),
    // option 3 = C (solo el marcador de mundo, para ver si el mappin de entidad lo sigue).
    public func DevGigMove(option: Int32) -> String {
        let gi: GameInstance = this.GetGameInstance();
        let zone: ref<GRGigZone> = GRGigZone.Get();
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        let journal: ref<JournalManager> = GameInstance.GetJournalManager(gi);
        let result: String;
        let current: Vector3;
        if !IsDefined(zone) || !IsDefined(player) || !IsDefined(journal) {
            result = "falta GRGigZone, el jugador o el journal";
        } else if !zone.GetCookedPosition(current) {
            result = "la entrada cocinada no esta inyectada (correr DevGigInfo)";
        } else {
            let forward: Vector4 = player.GetWorldForward();
            let center: Vector3;
            center.X = current.X + forward.X * 300.0;
            center.Y = current.Y + forward.Y * 300.0;
            center.Z = current.Z;
            if option == 2 {
                let mappin: wref<IMappin> = GRGigZone.ObjectiveMappin(gi);
                if !IsDefined(mappin) {
                    result = "B: no hay mappin vivo del objetivo (DevGigOn primero)";
                } else {
                    let before: Vector4 = mappin.GetWorldPosition();
                    GameInstance.GetMappinSystem(gi).SetMappinPosition(mappin.GetNewMappinID(), new Vector4(center.X, center.Y, center.Z, 1.0));
                    result = "B: SetMappinPosition " + GRGigZone.Vec4(before) + " -> " + GRGigZone.Vec(center) + ", el mappin dice " + GRGigZone.Vec4(mappin.GetWorldPosition())
                        + " (cocinada sigue en " + GRGigZone.Vec(current) + ")";
                }
            } else if option == 3 {
                result = "C: " + GRGigZone.PlaceMarker(gi, new Vector4(center.X, center.Y, center.Z, 1.0)) + " (la cocinada sigue en " + GRGigZone.Vec(current) + ")";
            } else {
                zone.SetCookedPosition(center, 0.0);
                let off: String = GRGigZone.SetMappins(journal, gameJournalEntryState.Inactive, true, false);
                let call: ref<GRGigZoneStep> = new GRGigZoneStep();
                call.gi = gi;
                call.step = 3;
                GameInstance.GetDelaySystem(gi).DelayCallback(call, 0.5, false);
                result = "A: cocinada " + GRGigZone.Vec(current) + " -> " + GRGigZone.Vec(center) + ", " + off + ", se reactiva en 0,5 s (ver log 'DevGigMove A')";
            }
        }
        GRLog("Bounty: DevGigMove(" + IntToString(option) + ") -> " + result);
        return result;
    }

    public func DevGigOff() -> String {
        let journal: ref<JournalManager> = GameInstance.GetJournalManager(this.GetGameInstance());
        let result: String = IsDefined(journal) ? GRGigZone.Deactivate(journal) : "falta el journal";
        this.m_gigShown = 0;
        this.m_gigFor = 0;
        this.m_gigStep = 0;
        this.m_gigNotify = false;
        this.m_gigDue = 0.0;
        this.m_gigSuppress = true;
        GRLog("Bounty: DevGigOff -> " + result + " (el flujo real queda suprimido hasta aceptar otro contrato o DevGigOn)");
        return result + " (el flujo real queda suprimido hasta aceptar otro contrato o DevGigOn)";
    }

    // Elige con que mappin se prueba: 0 = solo posicion cocinada del .mappins, 1 = solo marcador de mundo (por defecto: un solo "!"), 2 = ambos (dos "!"),
    // 3 = experimento de area A (mappin estatico con referencia al nodo de area vanilla del psicopata), 4 = experimento de area B (referencia al marcador propio).
    // Si el encargo real esta mostrado, se baja y el Tick lo rearma solo (sin aviso) con el modo nuevo en ~2 s.
    public func DevGigMode(mode: Int32) -> String {
        let zone: ref<GRGigZone> = GRGigZone.Get();
        if !IsDefined(zone) {
            return "falta GRGigZone";
        }
        zone.SetMode(mode);
        let result: String = "modo " + GRGigZone.ModeName(zone.GetMode());
        if this.m_gigShown > 0 && !this.m_gigSuppress {
            this.StopGig("cambio de modo del encargo");
            result += " (encargo bajado, se rearma solo en el proximo Tick)";
        }
        GRLog("Bounty: DevGigMode -> " + result);
        return result;
    }

    // Secuencia completa de prueba: oferta (si no hay) -> aceptar -> SMS del fixer -> demora -> encargo (con aviso, mappin y seguimiento).
    public func DevGigAccept() -> String {
        this.Repair();
        let result: String;
        if this.AcceptedCount() >= GRBounties.MaxOpen() {
            result = "cupo lleno (" + IntToString(this.AcceptedCount()) + "/" + IntToString(GRBounties.MaxOpen()) + " aceptados), DevFail o DevComplete antes";
        } else {
            let note: String = "";
            let i: Int32 = this.FirstWithState(3);
            if i < 0 && this.OfferedCount() < GRBounties.MaxOffers() {
                note = this.Offer(this.Today()) + ", ";
                i = this.FirstWithState(3);
            }
            if i < 0 {
                result = note + "no hay ofertas pendientes y no se pudo crear una";
            } else {
                result = note + this.AcceptAt(i, this.m_ids[i]) + " | el SMS sale en el proximo aviso y el encargo " + IntToString(Cast<Int32>(GRGigZone.Delay())) + " s despues (DevGigInfo muestra la cuenta)";
            }
        }
        GRLog("Bounty: DevGigAccept -> " + result);
        return result;
    }

    // Dev: pines vivos cerca del centro del encargo mostrado (mundo 3D y mapa). trim = true apaga los mappins de quest activos sobrantes (deja uno).
    // Por REDnode: api_call self=<GRBounties> fn=DevGigPins args=[false] (solo mirar) o [true] (apagar sobrantes).
    public func DevGigPins(trim: Bool) -> String {
        let result: String = "no hay encargo mostrado (DevGigAccept primero)";
        if this.m_gigShown > 0 {
            result = GRGigZone.PinReport(this.GetGameInstance(), new Vector4(this.m_gigX, this.m_gigY, 0.0, 1.0), trim);
        }
        GRLog("Bounty: DevGigPins -> " + result);
        return result;
    }

    public func DevGigInfo() -> String {
        let gi: GameInstance = this.GetGameInstance();
        let zone: ref<GRGigZone> = GRGigZone.Get();
        let journal: ref<JournalManager> = GameInstance.GetJournalManager(gi);
        if !IsDefined(zone) || !IsDefined(journal) {
            return "falta GRGigZone o el journal";
        }
        let result: String = this.GigState() + " | estados q=" + GRGigZone.StateOf(journal, GRGigZone.QuestPath(), "gameJournalQuest")
            + " d=" + GRGigZone.StateOf(journal, GRGigZone.QuestPath() + "/description", "gameJournalQuestDescription")
            + " p=" + GRGigZone.StateOf(journal, GRGigZone.PhasePath(), "gameJournalQuestPhase")
            + " o=" + GRGigZone.StateOf(journal, GRGigZone.ObjectivePath(), "gameJournalQuestObjective")
            + " m(cocinado)=" + GRGigZone.StateOf(journal, GRGigZone.MappinPath(), "gameJournalQuestMapPin")
            + " m(marcador)=" + GRGigZone.StateOf(journal, GRGigZone.MarkerPath(), "gameJournalQuestMapPin")
            + " m(area_a)=" + GRGigZone.StateOf(journal, GRGigZone.AreaAPath(), "gameJournalQuestMapPin")
            + " m(area_b)=" + GRGigZone.StateOf(journal, GRGigZone.AreaBPath(), "gameJournalQuestMapPin");
        let objective: wref<JournalEntry> = journal.GetEntryByString(GRGigZone.ObjectivePath(), "gameJournalQuestObjective");
        result += ", seguido=" + GRGigZone.Flag(IsDefined(objective) && journal.IsEntryTracked(objective));
        result += " | hash " + ToString(zone.GetHash()) + " en recurso=" + GRGigZone.Flag(zone.IsInjected()) + " (cargas " + IntToString(zone.GetLoads())
            + (zone.WasLateInject() ? ", inyeccion tarde" : "") + ")";
        let cooked: Vector3;
        let hasCooked: Bool = zone.GetCookedPosition(cooked);
        if hasCooked {
            result += ", cocinada " + GRGigZone.Vec(cooked);
        }
        let system: Vector3;
        if GameInstance.GetMappinSystem(gi).GetQuestMappinPosition(zone.GetHash(), system) {
            result += ", GetQuestMappinPosition " + GRGigZone.Vec(system);
        } else {
            result += ", GetQuestMappinPosition sin datos";
        }
        result += ", " + GRGigZone.MarkerInfo(gi);
        result += " | " + GRGigZone.MappinReport(gi, journal);
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        if IsDefined(player) {
            let here: Vector4 = player.GetWorldPosition();
            result += " | V en " + GRGigZone.Vec4(here);
            if hasCooked {
                result += ", al centro cocinado " + IntToString(Cast<Int32>(Vector4.Distance2D(here, new Vector4(cooked.X, cooked.Y, cooked.Z, 1.0)))) + " m";
            }
        }
        if this.m_gigShown > 0 {
            result += " | " + GRGigZone.PinReport(gi, new Vector4(this.m_gigX, this.m_gigY, 0.0, 1.0), false);
        }
        result += " | nombre del gig '" + this.GigName() + "'";
        GRLog("Bounty: DevGigInfo -> " + result);
        return result;
    }

    public func GetContracts() -> array<ref<GRBounty>> {
        this.Repair();
        let out: array<ref<GRBounty>>;
        let keys: array<String> = GRBounties.GangKeys();
        let i: Int32 = 0;
        while i < ArraySize(this.m_ids) {
            let c: ref<GRBounty> = new GRBounty();
            c.index = i;
            c.nemesisId = this.m_ids[i];
            c.fixer = this.m_fixers[i];
            c.cond = this.m_conds[i];
            c.pay = this.m_pays[i];
            c.expire = this.m_expires[i];
            c.state = this.m_states[i];
            c.bonus = this.m_bonuses[i];
            c.bonusUsed = this.m_bonusUsed[i] > 0;
            c.rank = this.m_ranks[i];
            let gang: Int32 = this.m_gangs[i];
            c.gang = gang > 0 && gang <= ArraySize(keys) ? keys[gang - 1] : "";
            c.reason = this.m_reasons[i];
            c.paid = this.m_paids[i];
            c.msg = this.m_msgs[i];
            c.offerDay = this.m_offerDays[i];
            c.closeDay = this.m_closeDays[i];
            c.xp = this.m_xps[i];
            c.zone = c.state == 0 ? this.ZoneHint(i) : 0;
            c.special = this.m_specials[i] > 0;
            ArrayPush(out, c);
            i += 1;
        }
        return out;
    }
}

// Dev: paso de DevZoneGoForce (viaje por etapas con suelo comprobado).
public class GRZoneGoStep extends DelayCallback {
    public let gi: GameInstance;
    public let tx: Float;
    public let ty: Float;
    public let hint: Float;
    public let tries: Int32;
    public let hops: Int32;

    public func Call() {
        let bounties: ref<GRBounties> = GRBounties.Get(this.gi);
        if IsDefined(bounties) {
            bounties.ZoneGoStep(this);
        }
    }
}

// Suelo bajo (x, y): rayo de arriba hacia abajo entre las Z top y bottom; devuelve la superficie mas alta con colision cargada.
// false = no hay colision (zona sin streamear o fuera de la ventana): no teletransportar ahi.
public func GRGroundBetween(gi: GameInstance, x: Float, y: Float, top: Float, bottom: Float, out groundZ: Float) -> Bool {
    let spatial: ref<SpatialQueriesSystem> = GameInstance.GetSpatialQueriesSystem(gi);
    if !IsDefined(spatial) {
        return false;
    }
    let from: Vector4 = new Vector4(x, y, top, 1.0);
    let to: Vector4 = new Vector4(x, y, bottom, 1.0);
    let found: Bool = false;
    let best: Float = 0.0;
    let hitStatic: TraceResult;
    if spatial.SyncRaycastByCollisionGroup(from, to, n"Static", hitStatic, true, false) && hitStatic.position.Z <= top + 0.1 && hitStatic.position.Z >= bottom - 0.1 {
        best = hitStatic.position.Z;
        found = true;
    }
    let hitTerrain: TraceResult;
    if spatial.SyncRaycastByCollisionGroup(from, to, n"Terrain", hitTerrain, true, false) && hitTerrain.position.Z <= top + 0.1 && hitTerrain.position.Z >= bottom - 0.1
        && (!found || hitTerrain.position.Z > best) {
        best = hitTerrain.position.Z;
        found = true;
    }
    let hitWorld: TraceResult;
    spatial.SyncRaycastByCollisionPreset(from, to, n"World Static", hitWorld);
    if TraceResult.IsValid(hitWorld) && hitWorld.position.Z <= top + 0.1 && hitWorld.position.Z >= bottom - 0.1 && (!found || hitWorld.position.Z > best) {
        best = hitWorld.position.Z;
        found = true;
    }
    if found {
        groundZ = best;
    }
    return found;
}

// Una posicion (POI) esta en la SUPERFICIE o enterrada/cubierta? Rayo desde pos.Z+120 hasta pos.Z-40 (superficie mas alta con colision cargada).
// 0 = sin datos (colision sin streamear: no decidir nada) | 1 = accesible (techo bajo <= 6 m o sin techo) | 2 = cubierto (hay superficie a mas de 6 m por encima: subsuelo/estructura).
// topZ = la superficie mas alta encontrada. useZ = Z para pin/spawn: el suelo (si el POI tiene un techo bajo, se mide el suelo bajo ese techo; si no, la superficie).
public func GRSurfaceCheck(gi: GameInstance, pos: Vector4, out topZ: Float, out useZ: Float) -> Int32 {
    let top: Float = 0.0;
    if !GRGroundBetween(gi, pos.X, pos.Y, pos.Z + 120.0, pos.Z - 40.0, top) {
        return 0;
    }
    topZ = top;
    useZ = pos.Z;
    if top > pos.Z + 6.0 {
        return 2;
    }
    if top > pos.Z + 1.5 {
        let floorZ: Float = 0.0;
        if GRGroundBetween(gi, pos.X, pos.Y, pos.Z + 2.0, pos.Z - 40.0, floorZ) {
            useZ = floorZ;
        }
    } else {
        useZ = top;
    }
    return 1;
}

// Endurecimiento del techo bajo: devuelve true si hay estructura entre 1,5 y 6 m sobre el POI (tinglado o INTERIOR cerrado: no se distinguen por rayos).
// Un punto asi solo se da por validado si ademas pasa GRReachCheck == 1 (camino corto por navmesh desde V); sin datos de navmesh queda sin validar.
public func GRLowRoof(topZ: Float, poiZ: Float) -> Bool {
    return topZ > poiZ + 1.5 && topZ <= poiZ + 6.0;
}

// Alcanzabilidad por navmesh humano (CalculatePathOnlyHumanNavmesh, la misma API que usa el Spawner). Ambos extremos se ajustan al navmesh.
// 0 = sin datos (navmesh sin cargar, V o el punto fuera del navmesh: NO decidir nada) | 1 = alcanzable | 2 = inalcanzable (sin camino, camino parcial, o camino enorme).
// Criterio: el camino llega al punto y mide <= 2,5 x la recta + 15 m (y <= 350 m). pathLen = 0 si no hay camino.
public func GRReachCheck(gi: GameInstance, from: Vector4, to: Vector4, out pathLen: Float, out straight: Float) -> Int32 {
    pathLen = 0.0;
    straight = Vector4.Distance(from, to);
    let nav: ref<NavigationSystem> = GameInstance.GetNavigationSystem(gi);
    if !IsDefined(nav) {
        return 0;
    }
    let start: Vector4 = nav.GetNearestNavmeshPointBelowOnlyHumanNavmesh(from + new Vector4(0.0, 0.0, 1.0, 0.0), 2.0, 5);
    if Vector4.IsZero(start) {
        return 0;
    }
    let goal: Vector4 = nav.GetNearestNavmeshPointBelowOnlyHumanNavmesh(to + new Vector4(0.0, 0.0, 2.0, 0.0), 3.0, 6);
    if Vector4.IsZero(goal) {
        return 0;
    }
    if Vector4.Distance(start, goal) < 2.0 {
        pathLen = Vector4.Distance(start, goal);
        return 1;
    }
    let path: ref<NavigationPath> = nav.CalculatePathOnlyHumanNavmesh(start, goal, NavGenAgentSize.Human, 1.0);
    if !IsDefined(path) || ArraySize(path.path) < 2 {
        return 2;
    }
    let last: Vector4 = path.path[ArraySize(path.path) - 1];
    pathLen = path.CalculateLength();
    if Vector4.Distance(last, goal) > 3.0 {
        // Camino parcial: el navmesh entre V y el punto puede estar a medio cargar si esta lejos; cerca es una pared real.
        pathLen = 0.0;
        return straight > 120.0 ? 0 : 2;
    }
    if pathLen > straight * 2.5 + 15.0 || pathLen > 350.0 {
        return 2;
    }
    return 1;
}

public func GRReachText(reach: Int32, pathLen: Float, straight: Float) -> String {
    if reach == 0 {
        return "sin datos de navmesh";
    }
    return (pathLen > 0.0 ? "camino a " + IntToString(Cast<Int32>(pathLen)) + " m" : "sin camino") + ", recta " + IntToString(Cast<Int32>(straight)) + " m";
}

// Alcanzabilidad de un punto desde V, solo si V esta a <= 200 m en planta (mas lejos el navmesh puede estar a medio cargar). -1 = no se comprobo (sin jugador o lejos).
public func GRReachFromPlayer(gi: GameInstance, to: Vector4, out pathLen: Float, out straight: Float) -> Int32 {
    pathLen = 0.0;
    straight = 0.0;
    let player: ref<PlayerPuppet> = GetPlayer(gi);
    if !IsDefined(player) || Vector4.Distance2D(player.GetWorldPosition(), to) > 200.0 {
        return -1;
    }
    return GRReachCheck(gi, player.GetWorldPosition(), to, pathLen, straight);
}
