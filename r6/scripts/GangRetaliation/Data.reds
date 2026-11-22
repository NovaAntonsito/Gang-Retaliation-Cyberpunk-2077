module GangRetaliationHistory

// Holds the nemesis history events for the History screen.
// The CET side (GangRetaliationHistory/init.lua) reads data/history.log, classifies and tags each
// line, then pushes it here with Clear() + Add(). redscript can't read files, so this is the bridge.
//
//   kind    short code: DEATH RAID ARREST RELEASED AMBUSH BACKUP ESCAPED PROMOTED NEWFACE FEUD
//           VACUUM RETURNED TRAIT WAR TERRITORY STRONGHOLD WEAPON INTEL NEWS
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
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliationHistory.GRChronData") as GRChronData;
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
