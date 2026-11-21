module GangRetaliation

import Codeware.Localization.*

public class GRTraits extends ScriptableSystem {
    private let m_nemesisIDs: array<Int32>;
    private let m_traits: array<array<String>>;

    private let m_reveals: array<String>;

    private let m_shown: array<String>;

    public static func Get(gi: GameInstance) -> ref<GRTraits> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRTraits") as GRTraits;
    }

    private func IndexOf(nemesisId: Int32) -> Int32 {
        let i: Int32 = 0;
        while i < ArraySize(this.m_nemesisIDs) {
            if this.m_nemesisIDs[i] == nemesisId {
                return i;
            }
            i += 1;
        }
        return -1;
    }

    public func SetTraits(nemesisId: Int32, csv: String) {
        let list: array<String> = StrSplit(csv, ",");
        let index: Int32 = this.IndexOf(nemesisId);
        if index >= 0 {
            this.m_traits[index] = list;
        } else {
            ArrayPush(this.m_nemesisIDs, nemesisId);
            ArrayPush(this.m_traits, list);
        }
    }

    public func GetTraits(nemesisId: Int32) -> array<String> {
        let out: array<String>;
        let index: Int32 = this.IndexOf(nemesisId);
        if index < 0 {
            return out;
        }
        let list: array<String> = this.m_traits[index];
        for t in list {
            if StrLen(t) > 0 {
                ArrayPush(out, t);
            }
        }
        return out;
    }

    public static func IsWeakness(key: String) -> Bool {
        return Equals(key, "fear_fire") || Equals(key, "weak_shock") || Equals(key, "weak_tox") || Equals(key, "weak_melee")
            || Equals(key, "weak_blast") || Equals(key, "weak_hack") || Equals(key, "glass_jaw");
    }

    private let m_scanLogged: Int32;

    public func LogScanTraits(nemesisId: Int32, count: Int32) {
        if nemesisId == this.m_scanLogged {
            return;
        }
        this.m_scanLogged = nemesisId;
        GRLog("Escaner: rasgos mostrados de Nemesis #" + IntToString(nemesisId) + " (" + IntToString(count) + " rasgos)");
    }

    public func ClearScanLog() {
        this.m_scanLogged = 0;
    }

    public func Has(nemesisId: Int32, trait: String) -> Bool {
        let index: Int32 = this.IndexOf(nemesisId);
        if index < 0 {
            return false;
        }
        for t in this.m_traits[index] {
            if Equals(t, trait) {
                return true;
            }
        }
        return false;
    }

    private func Reveal(nemesisId: Int32, what: String) {
        let key: String = IntToString(nemesisId) + ":" + what;
        for shown in this.m_shown {
            if Equals(shown, key) {
                return;
            }
        }
        ArrayPush(this.m_shown, key);
        ArrayPush(this.m_reveals, key);
    }

    public func RevealFromIntel(gang: String) {
        if StrLen(gang) == 0 {
            return;
        }
        ArrayPush(this.m_reveals, "0:intel:" + gang);
    }

    private static func DamageOf(hitEvent: ref<gameHitEvent>, type: gamedataDamageType) -> Float {
        let values: array<Float> = hitEvent.attackComputed.GetAttackValues();
        let index: Int32 = EnumInt(type);
        if index >= 0 && index < ArraySize(values) {
            return values[index];
        }
        return 0.0;
    }

    private func ScaleType(nemesisId: Int32, hitEvent: ref<gameHitEvent>, trait: String, mult: Float, type: gamedataDamageType) {
        if this.Has(nemesisId, trait) && GRTraits.DamageOf(hitEvent, type) > 0.0 {
            hitEvent.attackComputed.MultAttackValue(mult, type);
            this.Reveal(nemesisId, trait);
            GRTaunts.OnTrait(hitEvent, trait);
            this.BountyWeakness(nemesisId, trait);
        }
    }

    private func BountyWeakness(nemesisId: Int32, trait: String) {
        if !GRTraits.IsWeakness(trait) {
            return;
        }
        let bounties: ref<GRBounties> = GRBounties.Get(this.GetGameInstance());
        if IsDefined(bounties) {
            bounties.OnWeaknessHit(nemesisId);
        }
    }

    private func ScaleAll(nemesisId: Int32, hitEvent: ref<gameHitEvent>, trait: String, mult: Float) {
        if this.Has(nemesisId, trait) {
            hitEvent.attackComputed.MultAttackValue(mult);
            this.Reveal(nemesisId, trait);
            GRTaunts.OnTrait(hitEvent, trait);
            this.BountyWeakness(nemesisId, trait);
        }
    }

    private func ApplyDefense(nemesisId: Int32, hitEvent: ref<gameHitEvent>) {
        this.ScaleType(nemesisId, hitEvent, "fireproof", 0.25, gamedataDamageType.Thermal);
        this.ScaleType(nemesisId, hitEvent, "fear_fire", 2.0, gamedataDamageType.Thermal);
        this.ScaleType(nemesisId, hitEvent, "insulated", 0.25, gamedataDamageType.Electric);
        this.ScaleType(nemesisId, hitEvent, "weak_shock", 2.0, gamedataDamageType.Electric);
        this.ScaleType(nemesisId, hitEvent, "toxproof", 0.25, gamedataDamageType.Chemical);
        this.ScaleType(nemesisId, hitEvent, "weak_tox", 2.0, gamedataDamageType.Chemical);

        let attack: ref<AttackData> = hitEvent.attackData;
        let attackType: gamedataAttackType = attack.GetAttackType();
        if AttackData.IsMelee(attackType) {
            this.ScaleAll(nemesisId, hitEvent, "brawler", 0.5);
            this.ScaleAll(nemesisId, hitEvent, "weak_melee", 1.75);
        }
        if AttackData.IsExplosion(attackType) {
            this.ScaleAll(nemesisId, hitEvent, "blastproof", 0.4);
            this.ScaleAll(nemesisId, hitEvent, "weak_blast", 2.0);
        }
        if attack.HasFlag(hitFlag.QuickHack) {
            this.ScaleAll(nemesisId, hitEvent, "firewall", 0.3);
            this.ScaleAll(nemesisId, hitEvent, "weak_hack", 2.0);
        }
        if attack.HasFlag(hitFlag.Headshot) {
            this.ScaleAll(nemesisId, hitEvent, "hardhead", 0.5);
            this.ScaleAll(nemesisId, hitEvent, "glass_jaw", 1.75);
        }
        this.ScaleAll(nemesisId, hitEvent, "tough", 0.75);
    }

    public static func OnHit(hitEvent: ref<gameHitEvent>) {
        if !IsDefined(hitEvent) || !IsDefined(hitEvent.target) || !IsDefined(hitEvent.attackData) || !IsDefined(hitEvent.attackComputed) {
            return;
        }
        let instigator: wref<GameObject> = hitEvent.attackData.GetInstigator();
        if !IsDefined(instigator) {
            return;
        }
        let gi: GameInstance = hitEvent.target.GetGame();
        let spawner: ref<GRSpawner> = GRSpawner.Get(gi);
        let traits: ref<GRTraits> = GRTraits.Get(gi);
        if !IsDefined(spawner) || !IsDefined(traits) || !spawner.HasOwnSpawns() {
            return;
        }

        if instigator.IsPlayer() || Equals(GRTraits.HitSource(instigator, hitEvent.target as ScriptedPuppet), "v") {
            spawner.RecordRaidHitByV(hitEvent.target.GetEntityID());
        }

        if instigator.IsPlayer() {
            let targetId: Int32 = spawner.GetNemesisId(hitEvent.target.GetEntityID());
            if targetId > 0 {
                traits.ApplyDefense(targetId, hitEvent);

                let attack: ref<AttackData> = hitEvent.attackData;
                spawner.RecordPlayerHit(targetId, attack.HasFlag(hitFlag.Headshot) || AttackData.IsExplosion(attack.GetAttackType()));
            }
        } else {
            if hitEvent.target.IsPlayer() {
                let attackerId: Int32 = spawner.GetNemesisId(instigator.GetEntityID());
                if attackerId > 0 {
                    traits.ScaleAll(attackerId, hitEvent, "deadly", 1.3);
                }
            } else {
                let victimId: Int32 = spawner.GetNemesisId(hitEvent.target.GetEntityID());
                if victimId > 0 {
                    spawner.RecordHitBy(victimId, GRTraits.HitSource(instigator, hitEvent.target as ScriptedPuppet));
                }
            }
        }
    }

    public static func HitSource(instigator: wref<GameObject>, victim: ref<ScriptedPuppet>) -> String {
        let puppet: ref<ScriptedPuppet> = instigator as ScriptedPuppet;
        let record: wref<Character_Record> = IsDefined(puppet) ? puppet.GetRecord() : null;
        if IsDefined(record) && IsDefined(record.Affiliation()) && Equals(record.Affiliation().Type(), gamedataAffiliation.NCPD) {
            return "police";
        }
        let spawner: ref<GRSpawner> = GRSpawner.Get(instigator.GetGame());
        let raidForce: Bool = IsDefined(spawner) && spawner.IsRaidForce(instigator.GetEntityID());
        let player: ref<GameObject> = GetPlayer(instigator.GetGame());
        if !raidForce && IsDefined(player) && Equals(GameObject.GetAttitudeBetween(instigator, player), EAIAttitude.AIA_Friendly) {
            return "v";
        }
        if !IsDefined(puppet) {
            return "other";
        }
        let gang: String = GRDetection.GetGang(puppet);
        if StrLen(gang) > 0 && (!IsDefined(victim) || NotEquals(gang, GRDetection.GetGang(victim))) {
            return "gang:" + gang;
        }
        return "other";
    }

    public func OnScanned(npc: ref<ScriptedPuppet>) {
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());
        if !IsDefined(spawner) {
            return;
        }
        let nemesisId: Int32 = spawner.GetNemesisId(npc.GetEntityID());
        if nemesisId > 0 {
            this.Reveal(nemesisId, "scan");
        }
    }

    public func GetRevealCount() -> Int32 {
        return ArraySize(this.m_reveals);
    }

    public func GetReveal(index: Int32) -> String {
        return this.m_reveals[index];
    }

    public func ClearReveals() {
        ArrayClear(this.m_reveals);
    }
}

@wrapMethod(DamageSystem)
private final func CalculateSourceModifiers(hitEvent: ref<gameHitEvent>, cache: ref<CacheData>) -> Void {
    wrappedMethod(hitEvent, cache);
    let prof: ref<GRProfiler> = IsDefined(hitEvent.target) ? GRProfiler.Get(hitEvent.target.GetGame()) : null;
    if IsDefined(prof) {
        prof.hits += 1;
        if prof.hooksOff {
            return;
        }
    }
    GRTraits.OnHit(hitEvent);
}

@wrapMethod(ScriptedPuppet)
protected cb func OnScanningEvent(evt: ref<ScanningEvent>) -> Bool {
    let result: Bool = wrappedMethod(evt);
    if IsDefined(evt) && (Equals(evt.state, gameScanningState.Complete) || Equals(evt.state, gameScanningState.ShallowComplete)) {
        let traits: ref<GRTraits> = GRTraits.Get(this.GetGame());
        if IsDefined(traits) {
            traits.OnScanned(this);
        }
    }
    return result;
}


public abstract class GRScanTraits {
    public static func IsTraitsRoot(root: wref<inkWidget>) -> Bool {
        return IsDefined(root) && Equals(root.GetName(), n"GRScannerTraits");
    }

    public static func Fill(owner: ref<inkGameController>, root: wref<inkWidget>) {
        if !IsDefined(owner) || !IsDefined(root) {
            return;
        }
        let compound: ref<inkCompoundWidget> = root as inkCompoundWidget;
        let panel: ref<inkCompoundWidget>;
        if IsDefined(compound) {
            panel = compound.GetWidget(n"horiz_panel/LeftPanel") as inkCompoundWidget;
        }
        if !IsDefined(panel) {
            root.SetVisible(false);
            return;
        }
        let i: Int32 = panel.GetNumChildren() - 1;
        while i >= 0 {
            let child: wref<inkWidget> = panel.GetWidgetByIndex(i);
            if IsDefined(child) && NotEquals(child.GetName(), n"nameLabel") && NotEquals(child.GetName(), n"space") {
                panel.RemoveChildByIndex(i);
            }
            i -= 1;
        }

        let player: ref<GameObject> = owner.GetPlayerControlledObject();
        if !IsDefined(player) {
            root.SetVisible(false);
            return;
        }
        let gi: GameInstance = player.GetGame();
        let spawner: ref<GRSpawner> = GRSpawner.Get(gi);
        let traits: ref<GRTraits> = GRTraits.Get(gi);
        let bb: ref<IBlackboard> = owner.GetBlackboardSystem().Get(GetAllBlackboardDefs().UI_Scanner);
        if !IsDefined(spawner) || !IsDefined(traits) || !IsDefined(bb) {
            root.SetVisible(false);
            return;
        }
        let target: EntityID = bb.GetEntityID(GetAllBlackboardDefs().UI_Scanner.ScannedObject);
        let nemesisId: Int32 = 0;
        if EntityID.IsDefined(target) {
            nemesisId = spawner.GetNemesisId(target);
        }
        let keys: array<String>;
        if nemesisId > 0 {
            keys = traits.GetTraits(nemesisId);
        }
        if ArraySize(keys) == 0 {
            if nemesisId <= 0 {
                traits.ClearScanLog();
            }
            root.SetVisible(false);
            return;
        }

        let loc: ref<LocalizationSystem> = LocalizationSystem.GetInstance(gi);
        let title: ref<inkText> = panel.GetWidget(n"nameLabel") as inkText;
        if IsDefined(title) {
            title.SetText(loc.GetText("GR-ScanTraits"));
        }
        let ordered: array<String>;
        for key in keys {
            if GRTraits.IsWeakness(key) {
                ArrayPush(ordered, key);
            }
        }
        for key in keys {
            if !GRTraits.IsWeakness(key) {
                ArrayPush(ordered, key);
            }
        }
        for key in ordered {
            let item: wref<inkWidget> = owner.SpawnFromLocal(panel, n"ScannerAbilityItemWidget");
            if IsDefined(item) {
                let ctrl: ref<ScannerAbilityItemLogicController> = item.GetController() as ScannerAbilityItemLogicController;
                if IsDefined(ctrl) {
                    ctrl.GRSetupTrait(loc.GetText("GR-Trait-" + key), GRTraits.IsWeakness(key));
                }
            }
        }
        root.SetVisible(true);
        traits.LogScanTraits(nemesisId, ArraySize(keys));
    }
}

@addMethod(ScannerAbilityItemLogicController)
public func GRSetupTrait(text: String, weak: Bool) {
    inkTextRef.SetText(this.m_abilityNameText, text);
    if weak {
        inkImageRef.SetTexturePart(this.m_abilityIcon, n"ICONS_CanGuardBreak");
        let red: HDRColor = new HDRColor(1.1761, 0.3809, 0.3476, 1.0);
        inkWidgetRef.SetTintColor(this.m_abilityIcon, red);
        inkWidgetRef.SetTintColor(this.m_abilityNameText, red);
    } else {
        inkImageRef.SetTexturePart(this.m_abilityIcon, n"ICONS_HasSubdermalArmor");
    }
}

@addField(ScannerAbilitiesGameController)
let m_grScanCb: ref<CallbackHandle>;

@wrapMethod(ScannerAbilitiesGameController)
protected cb func OnInitialize() -> Bool {
    let result: Bool = wrappedMethod();
    let bb: ref<IBlackboard> = this.GetBlackboardSystem().Get(GetAllBlackboardDefs().UI_Scanner);
    if IsDefined(bb) {
        this.m_grScanCb = bb.RegisterDelayedListenerEntityID(GetAllBlackboardDefs().UI_Scanner.ScannedObject, this, n"OnGRScannedObjectChanged");
    }
    return result;
}

@wrapMethod(ScannerAbilitiesGameController)
protected cb func OnUninitialize() -> Bool {
    let result: Bool = wrappedMethod();
    if IsDefined(this.m_grScanCb) {
        let bb: ref<IBlackboard> = this.GetBlackboardSystem().Get(GetAllBlackboardDefs().UI_Scanner);
        if IsDefined(bb) {
            bb.UnregisterDelayedListener(GetAllBlackboardDefs().UI_Scanner.ScannedObject, this.m_grScanCb);
        }
        this.m_grScanCb = null;
    }
    return result;
}

@addMethod(ScannerAbilitiesGameController)
protected cb func OnGRScannedObjectChanged(value: EntityID) -> Bool {
    if GRScanTraits.IsTraitsRoot(this.GetRootWidget()) {
        GRScanTraits.Fill(this, this.GetRootWidget());
    }
    return true;
}

@wrapMethod(ScannerAbilitiesGameController)
protected cb func OnAbilitiesChanged(value: Variant) -> Bool {
    if GRScanTraits.IsTraitsRoot(this.GetRootWidget()) {
        this.ClearAllAsyncSpawnRequests();
        GRScanTraits.Fill(this, this.GetRootWidget());
        return true;
    }
    return wrappedMethod(value);
}

@wrapMethod(ScannerAbilitiesGameController)
protected cb func OnAbilitySpawned(widget: ref<inkWidget>, userData: ref<IScriptable>) -> Bool {
    let result: Bool = wrappedMethod(widget, userData);
    if GRScanTraits.IsTraitsRoot(this.GetRootWidget()) && IsDefined(widget) {
        inkCompoundRef.RemoveChild(this.m_ScannerAbilitiesRightPanel, widget);
    }
    return result;
}

@wrapMethod(scannerDetailsGameController)
private final func AsyncSpawnScannerModule(scannerWidgetLibraryName: CName) -> Void {
    wrappedMethod(scannerWidgetLibraryName);
    if Equals(scannerWidgetLibraryName, n"ScannerAbilitiesWidget") {
        ArrayPush(this.m_asyncSpawnRequests, this.AsyncSpawnFromLocal(inkWidgetRef.Get(this.m_scannerCountainer), n"ScannerAbilitiesWidget", this, n"OnGRTraitsSpawned"));
    }
}

@addMethod(scannerDetailsGameController)
protected cb func OnGRTraitsSpawned(widget: ref<inkWidget>, userData: ref<IScriptable>) -> Bool {
    if !IsDefined(widget) {
        return false;
    }
    widget.SetName(n"GRScannerTraits");
    let container: ref<inkCompoundWidget> = inkWidgetRef.Get(this.m_scannerCountainer) as inkCompoundWidget;
    if IsDefined(container) {
        let count: Int32 = container.GetNumChildren();
        let abilities: Int32 = -1;
        let mine: Int32 = -1;
        let i: Int32 = 0;
        while i < count {
            let c: wref<inkWidget> = container.GetWidgetByIndex(i);
            if IsDefined(c) {
                if Equals(c.GetName(), n"GRScannerTraits") {
                    mine = i;
                } else {
                    if Equals(c.GetName(), n"ScannerAbilities") {
                        abilities = i;
                    }
                }
            }
            i += 1;
        }
        if abilities >= 0 && mine > abilities + 1 {
            container.ReorderChild(widget, abilities + 1);
        }
    }
    GRScanTraits.Fill(this, widget);
    return true;
}
