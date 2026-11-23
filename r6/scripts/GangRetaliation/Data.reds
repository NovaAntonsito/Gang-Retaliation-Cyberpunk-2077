module GangRetaliation

// Holds the nemesis history events shown in the GANGS detail panel's History/Gang History sub-tabs.
// The CET side (init.lua) calls History.record(key, gangKeys, names, args) next to each notify() call
// and pushes the event here with Clear() + Add() - no text parsing, the args are already real variables
// at that point.
//
//   kind    short code: DEATH RAID ARREST RELEASED AMBUSH BACKUP ESCAPED PROMOTED NEWFACE FEUD
//           VACUUM RETURNED TRAIT WAR TERRITORY STRONGHOLD WEAPON INTEL NEWS
//   text    NOT a rendered sentence - "key|arg1|arg2|..." (the localization key, then its %s/%d
//           substitution args in order, pipe-delimited). Menu.reds's RenderHistoryText() looks up the
//           key's current-language template and substitutes the args fresh every time a history row is
//           built, so a language switch mid-save changes how old entries read too (render at display
//           time, not render-once-at-record-time).
//   gangs   "|Scavengers|Maelstrom|"   gang KEYS the event involves (delimited so StrContains is exact)
//   names   "|Yuri Zaitsev|Sergei Volkov|"   nemesis names the event involves
public class GRChronData extends ScriptableSystem {
    private let m_days: array<Int32>;
    private let m_kinds: array<String>;
    private let m_texts: array<String>;
    private let m_gangs: array<String>;
    private let m_names: array<String>;
    private let m_version: Int32;

    public static func Get(gi: GameInstance) -> ref<GRChronData> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRChronData") as GRChronData;
    }

    public func Clear() {
        ArrayClear(this.m_days);
        ArrayClear(this.m_kinds);
        ArrayClear(this.m_texts);
        ArrayClear(this.m_gangs);
        ArrayClear(this.m_names);
        this.m_version += 1;
    }

    public func Add(day: Int32, kind: String, text: String, gangs: String, names: String) {
        ArrayPush(this.m_days, day);
        ArrayPush(this.m_kinds, kind);
        ArrayPush(this.m_texts, text);
        ArrayPush(this.m_gangs, gangs);
        ArrayPush(this.m_names, names);
        this.m_version += 1;
    }

    public func Count() -> Int32 {
        return ArraySize(this.m_days);
    }

    public func Version() -> Int32 {
        return this.m_version;
    }

    public func Day(i: Int32) -> Int32 {
        return this.m_days[i];
    }

    public func Kind(i: Int32) -> String {
        return this.m_kinds[i];
    }

    public func Text(i: Int32) -> String {
        return this.m_texts[i];
    }

    public func Gangs(i: Int32) -> String {
        return this.m_gangs[i];
    }

    public func Names(i: Int32) -> String {
        return this.m_names[i];
    }
}
