module GangRetaliationHistory

import GangRetaliation.*
import Codeware.Localization.*

// Localized text with an English fallback: if Codeware hasn't loaded our package (or a key is missing),
// the screen still shows English instead of the raw key.
public func GRChronText(gi: GameInstance, key: String, fallback: String) -> String {
    let text: String = LocalizationSystem.GetInstance(gi).GetText(key);
    if StrLen(text) == 0 || Equals(text, key) {
        return fallback;
    }
    return text;
}

// "Nemesis History": its own screen under Journal in the hub menu.
// Everything here targets vanilla/global classes (MenuHubLogicController, ScriptableService,
// gameuiMenuGameController). redscript can't annotate Gang Retaliation's own classes, so this mod
// only READS the main mod's public GRMenuData (roster) and our own GRChronData (events).

// ---- 1) register the menu entry (same mechanism the main mod uses for its Nemeses screen) ----
class GRChronMenuService extends ScriptableService {
    private cb func OnLoad() {
        GameInstance.GetCallbackSystem()
            .RegisterCallback(n"Resource/Ready", this, n"OnMenuResourceReady")
            .AddTarget(ResourceTarget.Path(r"base\\gameplay\\gui\\fullscreen\\menu.inkmenu"));
    }

    private cb func OnMenuResourceReady(event: ref<ResourceEvent>) {
        let resource: ref<inkMenuResource> = event.GetResource() as inkMenuResource;
        let entry: inkMenuEntry;
        entry.depth = 0u;
        entry.spawnMode = inkSpawnMode.SingleAndMultiplayer;
        entry.isAffectedByFadeout = true;
        entry.menuWidget *= r"gangretaliationhistory\\gui\\history.inkwidget";
        entry.name = n"gangretaliationhistory_history_menu";
        ArrayPush(resource.menusEntries, entry);
    }
}

// ---- 2) switching to Gang Retaliation's Nemeses screen from the view switcher row ----
// The switcher (GANGS | TERRITORY | ARSENAL | HISTORY) sits on this screen. Clicking one of the first three asks the
// hub's scenario (MenuScenario_HubMenu), which asks Gang Retaliation for that page (GRMenuData.RequestView,
// used once, on the next open) and then opens the Nemeses menu by name. Needs the Gang Retaliation version that has RequestView.
@addMethod(MenuScenario_HubMenu)
private final func GRChronOpenNemeses(page: String) -> Bool {
    FTLog("[GangRetaliationHistory] hub scenario: opening gangretaliation_nemesis_menu, page " + page);
    GRMenuData.RequestView(GetGameInstance(), StringToName(page));
    return this.OnOpenMenu(n"gangretaliation_nemesis_menu", null);
}

@addMethod(MenuScenario_HubMenu)
protected cb func OnGRChronOpenGangs() -> Bool {
    return this.GRChronOpenNemeses("gangs");
}

@addMethod(MenuScenario_HubMenu)
protected cb func OnGRChronOpenTerritory() -> Bool {
    return this.GRChronOpenNemeses("territory");
}

@addMethod(MenuScenario_HubMenu)
protected cb func OnGRChronOpenArsenal() -> Bool {
    return this.GRChronOpenNemeses("arsenal");
}

// There is deliberately no hub button any more: this screen is the HISTORY entry of the Nemeses screen's view
// switcher, and Gang Retaliation opens it by its menu name, gangretaliationhistory_history_menu.

// ---- 3) the screen (its ink resource lives in GangRetaliationHistory.archive) ----
// Layout is in the 3840 x 2160 design space (same as the main mod's Nemeses screen).
public class GRChronHistoryController extends gameuiMenuGameController {
    private let m_gi: GameInstance;
    private let m_chronDispatcher: wref<inkMenuEventDispatcher>;
    private let m_data: ref<GRMenuData>;
    private let m_hist: ref<GRChronData>;
    private let m_root: wref<inkCompoundWidget>;

    private let m_gangKeys: array<String>;
    private let m_gangLabels: array<String>;
    private let m_gang: Int32;
    private let m_tab: Int32;       // 0 = Full History, n = gang n-1
    private let m_isFull: Bool;
    private let m_member: String;   // selected card: member name (gang tabs) or gang key (Full History); "" = the "All" card
    private let m_members: array<ref<GRMenuEntry>>;

    private let m_summary: wref<inkText>;
    private let m_tabTexts: array<wref<inkText>>;
    private let m_tabBars: array<wref<inkRectangle>>;

    private let m_cardRow: wref<inkHorizontalPanel>;
    private let m_cardFrames: array<wref<inkImage>>;
    private let m_cardFills: array<wref<inkImage>>;
    private let m_cardInner: array<wref<inkImage>>;
    private let m_cardNames: array<String>;
    private let m_listScroller: ref<inkScrollController>;
    private let m_listFraction: Float;

    private let m_headerHost: wref<inkCanvas>;
    private let m_timeline: wref<inkVerticalPanel>;
    private let m_timeScroller: ref<inkScrollController>;
    private let m_wait: ref<inkAnimProxy>;
    private let m_listGrip: wref<inkRectangle>;
    private let m_listDrag: wref<inkSliderController>;
    private let m_syncing: Bool;
    private let m_grips: array<wref<inkRectangle>>;

    // ---------------------------------------------------------------- colors (same scheme as the Nemeses screen)
    private func Red() -> HDRColor {
        return new HDRColor(1.1761, 0.3809, 0.3476, 1.0);
    }

    private func Cyan() -> HDRColor {
        return new HDRColor(0.368627, 0.964706, 1.0, 1.0);
    }

    private func Gold() -> HDRColor {
        return new HDRColor(1.1192, 0.8441, 0.2565, 1.0);
    }

    private func Orange() -> HDRColor {
        return new HDRColor(1.0, 0.549, 0.102, 1.0);
    }

    private func Grey() -> HDRColor {
        return new HDRColor(0.76, 0.76, 0.84, 1.0);
    }

    private func Light() -> HDRColor {
        return new HDRColor(1.0, 1.0, 1.04, 1.0);
    }

    private func Dim() -> HDRColor {
        return new HDRColor(0.38, 0.38, 0.46, 1.0);
    }

    private func Dark() -> HDRColor {
        return new HDRColor(0.054902, 0.054902, 0.090196, 1.0);
    }

    private func PanelColor() -> HDRColor {
        return new HDRColor(0.075, 0.075, 0.12, 1.0);
    }

    private func DarkRed() -> HDRColor {
        return new HDRColor(0.48, 0.2, 0.19, 1.0);
    }

    private func RankColor(rank: Int32) -> HDRColor {
        if rank >= 3 {
            return this.Gold();
        }
        if rank == 2 {
            return this.Red();
        }
        return this.Light();
    }

    private func GangColor(gang: String) -> HDRColor {
        if Equals(gang, "TygerClaws") {
            return new HDRColor(1.0, 0.37, 0.66, 1.0);
        }
        if Equals(gang, "Maelstrom") {
            return this.Red();
        }
        if Equals(gang, "Valentinos") {
            return this.Gold();
        }
        if Equals(gang, "SixthStreet") {
            return new HDRColor(0.31, 0.55, 1.0, 1.0);
        }
        if Equals(gang, "Animals") {
            return new HDRColor(0.48, 0.85, 0.36, 1.0);
        }
        if Equals(gang, "VoodooBoys") {
            return new HDRColor(0.69, 0.49, 1.0, 1.0);
        }
        if Equals(gang, "Wraiths") {
            return new HDRColor(1.0, 0.6, 0.24, 1.0);
        }
        if Equals(gang, "Scavengers") {
            return new HDRColor(0.56, 0.6, 0.68, 1.0);
        }
        if Equals(gang, "Barghest") {
            return new HDRColor(0.73, 0.69, 0.48, 1.0);
        }
        return this.Light();
    }

    private func KindColor(kind: String) -> HDRColor {
        if Equals(kind, "DEATH") || Equals(kind, "RAID") || Equals(kind, "ARREST") || Equals(kind, "AMBUSH") || Equals(kind, "BACKUP") || Equals(kind, "WAR") {
            return this.Red();
        }
        if Equals(kind, "PROMOTED") || Equals(kind, "NEWFACE") || Equals(kind, "TERRITORY") || Equals(kind, "STRONGHOLD") {
            return this.Gold();
        }
        if Equals(kind, "RETURNED") || Equals(kind, "TRAIT") || Equals(kind, "RELEASED") || Equals(kind, "WEAPON") || Equals(kind, "INTEL") {
            return this.Cyan();
        }
        if Equals(kind, "VACUUM") {
            return this.Orange();
        }
        return this.Grey();
    }

    private func KindLabel(kind: String) -> String {
        return this.T("GRChron-Kind-" + kind, this.KindLabelEn(kind));
    }

    private func KindLabelEn(kind: String) -> String {
        if Equals(kind, "DEATH") {
            return "DEATH";
        }
        if Equals(kind, "RAID") {
            return "RAID";
        }
        if Equals(kind, "ARREST") {
            return "ARRESTED";
        }
        if Equals(kind, "RELEASED") {
            return "RELEASED";
        }
        if Equals(kind, "AMBUSH") {
            return "AMBUSH";
        }
        if Equals(kind, "BACKUP") {
            return "BACKUP";
        }
        if Equals(kind, "ESCAPED") {
            return "ESCAPED";
        }
        if Equals(kind, "PROMOTED") {
            return "PROMOTED";
        }
        if Equals(kind, "NEWFACE") {
            return "NEW FACE";
        }
        if Equals(kind, "FEUD") {
            return "FEUD";
        }
        if Equals(kind, "VACUUM") {
            return "POWER VACUUM";
        }
        if Equals(kind, "RETURNED") {
            return "RETURNED";
        }
        if Equals(kind, "TRAIT") {
            return "TRAIT";
        }
        if Equals(kind, "WAR") {
            return "WAR";
        }
        if Equals(kind, "TERRITORY") {
            return "TERRITORY";
        }
        if Equals(kind, "STRONGHOLD") {
            return "STRONGHOLD";
        }
        if Equals(kind, "WEAPON") {
            return "WEAPON";
        }
        if Equals(kind, "INTEL") {
            return "INTEL";
        }
        return "NEWS";
    }

    private func RankName(rank: Int32) -> String {
        if !IsDefined(this.m_data) {
            return rank >= 3 ? "BOSS" : (rank == 2 ? "LIEUTENANT" : "SOLDIER");
        }
        if rank >= 3 {
            return StrUpper(this.m_data.Text("GR-RankBoss"));
        }
        if rank == 2 {
            return StrUpper(this.m_data.Text("GR-RankLieutenant"));
        }
        return StrUpper(this.m_data.Text("GR-RankSoldier"));
    }

    // ---------------------------------------------------------------- text
    private func T(key: String, fallback: String) -> String {
        return GRChronText(this.m_gi, key, fallback);
    }

    // replaces the first token (e.g. "%d") in a localized template
    private func Fmt(fmt: String, token: String, value: String) -> String {
        let i: Int32 = StrFindFirst(fmt, token);
        if i < 0 {
            return fmt;
        }
        let after: Int32 = i + StrLen(token);
        return StrLeft(fmt, i) + value + StrMid(fmt, after, StrLen(fmt) - after);
    }

    private func EventsText(count: Int32) -> String {
        if count == 1 {
            return this.T("GRChron-Event1", "1 event");
        }
        return this.Fmt(this.T("GRChron-EventN", "%d events"), "%d", IntToString(count));
    }

    private func DayText(day: Int32) -> String {
        return this.Fmt(this.T("GR-MenuDay", "DAY %d"), "%d", IntToString(day));
    }

    // ---------------------------------------------------------------- small widget helpers
    private func NewText(text: String, size: Int32, color: HDRColor, style: CName) -> ref<inkText> {
        let label: ref<inkText> = new inkText();
        label.SetText(text);
        label.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        label.SetFontStyle(style);
        label.SetFontSize(size);
        label.SetTintColor(color);
        return label;
    }

    private func Label(parent: ref<inkCompoundWidget>, text: String, size: Int32, color: HDRColor, style: CName, x: Float, y: Float) -> ref<inkText> {
        let label: ref<inkText> = this.NewText(text, size, color, style);
        label.SetAnchor(inkEAnchor.TopLeft);
        label.SetMargin(new inkMargin(x, y, 0.0, 0.0));
        label.Reparent(parent);
        return label;
    }

    private func NewRect(parent: ref<inkCompoundWidget>, x: Float, y: Float, w: Float, h: Float, color: HDRColor, opacity: Float) -> ref<inkRectangle> {
        let rect: ref<inkRectangle> = new inkRectangle();
        rect.SetAnchor(inkEAnchor.TopLeft);
        rect.SetMargin(new inkMargin(x, y, 0.0, 0.0));
        rect.SetSize(new Vector2(w, h));
        rect.SetTintColor(color);
        rect.SetOpacity(opacity);
        rect.Reparent(parent);
        return rect;
    }

    private func FullLine(top: Float) {
        let line: ref<inkRectangle> = new inkRectangle();
        line.SetAnchor(inkEAnchor.TopFillHorizontaly);
        line.SetMargin(new inkMargin(0.0, top, 0.0, 0.0));
        line.SetHeight(3.0);
        line.SetTintColor(this.Red());
        line.SetOpacity(0.55);
        line.Reparent(this.m_root);
    }

    // ---------------------------------------------------------------- lifecycle
    protected cb func OnInitialize() -> Bool {
        let gi: GameInstance = this.GetPlayerControlledObject().GetGame();
        this.m_gi = gi;
        this.m_data = GRMenuData.Get(gi);
        this.m_hist = GRChronData.Get(gi);
        this.m_root = this.GetRootCompoundWidget();
        this.m_member = "";
        this.m_gang = 0;
        this.m_tab = 0;
        this.m_isFull = true;

        this.LoadGangs();
        this.BuildFrame();
        this.BuildMemberList();
        this.BuildHistoryPanel();
        if ArraySize(this.m_gangKeys) > 0 {
            this.SelectTab(0);
        } else {
            this.Label(this.m_root, this.T("GR-MenuEmpty", "No Nemeses yet. Let a wounded ganger escape and they will remember you."), 36, this.Grey(), n"Medium", 120.0, 430.0);
        }

        this.RegisterToGlobalInputCallback(n"OnPostOnRelease", this, n"OnGRChronInput");
        let result: Bool = super.OnInitialize();
        return result;
    }

    protected cb func OnUninitialize() -> Bool {
        this.UnregisterFromGlobalInputCallback(n"OnPostOnRelease", this, n"OnGRChronInput");
        let result: Bool = super.OnUninitialize();
        return result;
    }

    private func LoadGangs() {
        ArrayClear(this.m_gangKeys);
        ArrayClear(this.m_gangLabels);
        if !IsDefined(this.m_data) {
            return;
        }
        let entries: array<ref<GRMenuEntry>> = this.m_data.GetEntries();
        let i: Int32 = 0;
        while i < ArraySize(entries) {
            let entry: ref<GRMenuEntry> = entries[i];
            if !ArrayContains(this.m_gangKeys, entry.gangKey) {
                let pos: Int32 = 0;
                while pos < ArraySize(this.m_gangLabels) && StrCmp(this.m_gangLabels[pos], entry.gang) < 0 {
                    pos += 1;
                }
                ArrayInsert(this.m_gangKeys, pos, entry.gangKey);
                ArrayInsert(this.m_gangLabels, pos, entry.gang);
            }
            i += 1;
        }
    }

    // The view switcher of the Nemeses screen (TAB key hint + GANGS | TERRITORY | ARSENAL), with HISTORY added
    // and highlighted, so this screen reads as part of it. The first three open the Nemeses screen; HISTORY is this screen.
    private func BuildViewSwitch() {
        let panel: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        panel.SetName(n"gr_chron_view_switch");
        panel.SetAnchor(inkEAnchor.TopLeft);
        panel.SetMargin(new inkMargin(120.0, 258.0, 0.0, 0.0));
        panel.SetFitToContent(true);
        panel.Reparent(this.m_root);

        let tag: ref<inkCanvas> = new inkCanvas();
        tag.SetSize(new Vector2(3.0 * 22.0 * 0.56 + 24.0, 34.0));
        tag.SetVAlign(inkEVerticalAlign.Center);
        tag.SetMargin(new inkMargin(0.0, 0.0, 20.0, 0.0));
        let frame: ref<GRBorder> = new GRBorder();
        frame.SetAnchor(inkEAnchor.Fill);
        frame.SetThickness(2.0);
        frame.SetTintColor(this.Cyan());
        frame.Reparent(tag);
        let key: ref<inkText> = this.NewText("TAB", 22, this.Cyan(), n"Bold");
        key.SetAnchor(inkEAnchor.CenterLeft);
        key.SetAnchorPoint(new Vector2(0.0, 0.5));
        key.SetMargin(new inkMargin(12.0, 0.0, 0.0, 0.0));
        key.Reparent(tag);
        tag.Reparent(panel);

        let names: array<String>;
        ArrayPush(names, StrUpper(this.T("GR-MenuViewGangs", "Gangs")));
        ArrayPush(names, StrUpper(this.T("GR-MenuViewTerritory", "Territory")));
        ArrayPush(names, StrUpper(this.T("GR-MenuViewArsenal", "Arsenal")));
        ArrayPush(names, StrUpper(this.T("GRChron-ViewHistory", "History")));
        let pages: array<String>;
        ArrayPush(pages, "gangs");
        ArrayPush(pages, "territory");
        ArrayPush(pages, "arsenal");
        let i: Int32 = 0;
        while i < 4 {
            if i > 0 {
                let sep: ref<inkText> = this.NewText("  |  ", 32, this.Dim(), n"Medium");
                sep.SetVAlign(inkEVerticalAlign.Center);
                sep.Reparent(panel);
            }
            let item: ref<inkText> = this.NewText(names[i], 32, i == 3 ? this.Cyan() : this.Grey(), n"Bold");
            item.SetVAlign(inkEVerticalAlign.Center);
            if i < 3 {
                item.SetName(StringToName("gr_chron_view_" + pages[i]));
                item.SetInteractive(true);
                item.RegisterToCallback(n"OnRelease", this, n"OnGRChronViewClick");
            }
            item.Reparent(panel);
            i += 1;
        }
    }

    // ---------------------------------------------------------------- fixed frame: title, summary, gang tabs
    private func BuildFrame() {
        let background: ref<inkRectangle> = new inkRectangle();
        background.SetName(n"gr_chron_background");
        background.SetAnchor(inkEAnchor.Fill);
        background.SetMargin(new inkMargin(0.0, 150.0, 0.0, 0.0));
        background.SetTintColor(this.Dark());
        background.SetOpacity(0.55);
        background.Reparent(this.m_root);

        this.FullLine(150.0);
        this.FullLine(336.0);
        this.Label(this.m_root, StrUpper(this.T("GRChron-Title", "Nemesis History")), 64, this.Red(), n"Medium", 120.0, 184.0);
        this.BuildViewSwitch();

        // today's in-game day, same count the timeline uses (GRSpawner:GetGameDay, whole days), above the summary
        let spawner: ref<GRSpawner> = GameInstance.GetScriptableSystemsContainer(this.m_gi).Get(n"GangRetaliation.GRSpawner") as GRSpawner;
        if IsDefined(spawner) {
            let today: ref<inkText> = this.NewText(this.Fmt(this.T("GRChron-Today", "Current Day: %d"), "%d", IntToString(Cast<Int32>(spawner.GetGameDay()))), 50, this.Cyan(), n"Bold");
            today.SetName(n"gr_chron_today");
            today.SetAnchor(inkEAnchor.TopRight);
            today.SetAnchorPoint(new Vector2(1.0, 0.0));
            today.SetMargin(new inkMargin(0.0, 154.0, 120.0, 0.0));
            today.Reparent(this.m_root);
        }

        let summary: ref<inkText> = this.NewText("", 32, this.Gold(), n"Medium");
        summary.SetAnchor(inkEAnchor.TopRight);
        summary.SetAnchorPoint(new Vector2(1.0, 0.0));
        summary.SetMargin(new inkMargin(0.0, 214.0, 120.0, 0.0));
        summary.Reparent(this.m_root);
        this.m_summary = summary;

        // Tabs: a 236 x 60 canvas per gang with the label centered in it (same construction as the Nemeses
        // screen); the whole row is centered in the space to the right of the view switcher (not the full
        // screen - with the switcher's real width at the left, "full-width center then clamp" always just
        // pinned the row to the clamp instead of actually centering it).
        let slot: Float = 250.0;
        let count: Int32 = ArraySize(this.m_gangKeys) + 1;   // + the Full History tab at the start
        let switcherRight: Float = 1180.0;   // left edge of the space available for the tab row
        let available: Float = 3840.0 - switcherRight;
        let rowWidth: Float = Cast<Float>(count) * slot - 14.0;
        let startX: Float = switcherRight + (available - rowWidth) / 2.0;
        if startX < switcherRight {
            startX = switcherRight;   // guard in case a future gang count overflows the available space
        }
        let i: Int32 = 0;
        while i < count {
            let tab: ref<inkCanvas> = new inkCanvas();
            tab.SetName(StringToName("gr_chron_tab_" + IntToString(i)));
            tab.SetAnchor(inkEAnchor.TopLeft);
            tab.SetMargin(new inkMargin(startX + Cast<Float>(i) * slot, 252.0, 0.0, 0.0));
            tab.SetSize(new Vector2(236.0, 60.0));
            tab.SetInteractive(true);
            tab.RegisterToCallback(n"OnRelease", this, n"OnGRChronTabClick");
            tab.Reparent(this.m_root);

            let text: ref<inkText> = this.NewText(i == 0 ? StrUpper(this.T("GRChron-TabFull", "Full History")) : StrUpper(this.m_gangLabels[i - 1]), 32, this.Grey(), n"Medium");
            text.SetAnchor(inkEAnchor.TopCenter);
            text.SetAnchorPoint(new Vector2(0.5, 0.0));
            text.Reparent(tab);
            ArrayPush(this.m_tabTexts, text);

            let bar: ref<inkRectangle> = new inkRectangle();
            bar.SetSize(new Vector2(236.0, 4.0));
            bar.SetTintColor(this.DarkRed());
            bar.SetAnchor(inkEAnchor.BottomLeft);
            bar.SetAnchorPoint(new Vector2(0.0, 1.0));
            bar.Reparent(tab);
            ArrayPush(this.m_tabBars, bar);
            i += 1;
        }

        this.Label(this.m_root, this.T("GRChron-Hint", "A / D  switch tab     Esc  back"), 28, this.Dim(), n"Medium", 120.0, 1960.0);
    }

    // ---------------------------------------------------------------- left: member cards (scrolls sideways)
    private func BuildMemberList() {
        let host: ref<inkCanvas> = new inkCanvas();
        host.SetName(n"gr_chron_list_host");
        host.SetAnchor(inkEAnchor.TopLeft);
        host.SetMargin(new inkMargin(120.0, 400.0, 0.0, 0.0));
        host.SetSize(new Vector2(1290.0, 1520.0));
        host.SetInteractive(true);
        host.Reparent(this.m_root);

        let scroll: ref<inkScrollArea> = new inkScrollArea();
        scroll.SetName(n"scroll");
        scroll.SetAnchor(inkEAnchor.Fill);
        scroll.SetMargin(new inkMargin(0.0, 0.0, 0.0, 40.0));
        scroll.SetUseInternalMask(true);
        scroll.SetConstrainContentPosition(true);
        scroll.Reparent(host);

        // The scroll controller has no horizontal scrollbar hook, so the two are linked by hand: scrolling
        // moves the grip (OnGRChronListScrolled) and dragging the grip scrolls (OnGRChronListDragged).
        let bar: ref<inkCanvas> = this.NewBar(host, 0.0, 1494.0, 1290.0, 8.0, true);
        bar.RegisterToCallback(n"OnSliderValueChanged", this, n"OnGRChronListDragged");
        scroll.RegisterToCallback(n"OnScrollChanged", this, n"OnGRChronListScrolled");

        let scroller: ref<inkScrollController> = new inkScrollController();
        scroller.ScrollArea = inkScrollAreaRef.Create(scroll);
        scroller.direction = inkEScrollDirection.Horizontal;
        scroller.scrollSpeedMouse = 75.0;
        scroller.scrollSpeedGamepad = 75.0;
        // false, not true: with useGlobalInput on, this reacts to the mouse wheel no matter where the
        // cursor is, so it and the timeline scroll below moved together on any wheel input. false scopes
        // wheel input to whichever scroll area is actually hovered.
        scroller.useGlobalInput = false;
        host.AttachController(scroller);
        this.m_listScroller = scroller;

        let row: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        row.SetName(n"gr_chron_card_row");
        row.SetFitToContent(true);
        row.Reparent(scroll);
        this.m_cardRow = row;
    }

    // alive first (rank desc, renown desc), then the dead (rank desc, renown desc)
    private func IsBefore(a: ref<GRMenuEntry>, b: ref<GRMenuEntry>) -> Bool {
        if a.dead && !b.dead {
            return false;
        }
        if !a.dead && b.dead {
            return true;
        }
        if a.rank != b.rank {
            return a.rank > b.rank;
        }
        return a.renown > b.renown;
    }

    private func OrderMembers() {
        ArrayClear(this.m_members);
        if !IsDefined(this.m_data) || ArraySize(this.m_gangKeys) == 0 {
            return;
        }
        let key: String = this.m_gangKeys[this.m_gang];
        let entries: array<ref<GRMenuEntry>> = this.m_data.GetEntries();
        let i: Int32 = 0;
        while i < ArraySize(entries) {
            let entry: ref<GRMenuEntry> = entries[i];
            if Equals(entry.gangKey, key) {
                let pos: Int32 = 0;
                while pos < ArraySize(this.m_members) && !this.IsBefore(entry, this.m_members[pos]) {
                    pos += 1;
                }
                ArrayInsert(this.m_members, pos, entry);
            }
            i += 1;
        }
    }

    private func BuildCards() {
        this.m_cardRow.RemoveAllChildren();
        ArrayClear(this.m_cardFrames);
        ArrayClear(this.m_cardFills);
        ArrayClear(this.m_cardInner);
        ArrayClear(this.m_cardNames);
        if this.m_isFull {
            ArrayClear(this.m_members);
        } else {
            this.OrderMembers();
        }

        let total: Int32 = (this.m_isFull ? ArraySize(this.m_gangKeys) : ArraySize(this.m_members)) + 1;
        let rows: Int32 = 7;
        let column: ref<inkVerticalPanel>;
        let i: Int32 = 0;
        while i < total {
            if i % rows == 0 {
                column = new inkVerticalPanel();
                column.SetFitToContent(true);
                column.SetMargin(new inkMargin(0.0, 0.0, 26.0, 0.0));
                column.Reparent(this.m_cardRow);
            }
            let card: ref<inkCanvas> = this.m_isFull ? this.MakeFullCard(i) : this.MakeCard(i);
            card.Reparent(column);
            i += 1;
        }

        // visible share of the sideways list (host is 1290 wide, one column is 604 + 26 gap)
        let columns: Int32 = (total + rows - 1) / rows;
        let contentWidth: Float = Cast<Float>(columns) * 630.0;
        this.m_listFraction = contentWidth > 1290.0 ? 1290.0 / contentWidth : 1.0;
        this.UpdateListHandle(0.0);
    }

    private func UpdateListHandle(position: Float) {
        this.m_listGrip.SetSize(new Vector2(MaxF(1290.0 * this.m_listFraction, 60.0), 8.0));
        this.m_listGrip.SetVisible(this.m_listFraction < 1.0);
        this.m_syncing = true;
        this.m_listDrag.Setup(0.0, 1.0, position);
        this.m_syncing = false;
    }

    protected cb func OnGRChronListScrolled(value: Vector2) -> Bool {
        if this.m_syncing {
            return true;
        }
        this.m_listScroller.UpdateScrollPositionFromScrollArea();
        this.UpdateListHandle(this.m_listScroller.position);
        return true;
    }

    protected cb func OnGRChronListDragged(slider: wref<inkSliderController>, progress: Float, value: Float) -> Bool {
        if !this.m_syncing {
            this.m_listScroller.SetScrollPosition(progress);
        }
        return true;
    }

    // the box every card shares: fill + outline (cut corner) + inset outline shown when selected
    private func NewCardShell(index: Int32, color: HDRColor) -> ref<inkCanvas> {
        let card: ref<inkCanvas> = new inkCanvas();
        card.SetName(StringToName("gr_chron_card_" + IntToString(index)));
        card.SetSize(new Vector2(604.0, 176.0));
        card.SetMargin(new inkMargin(0.0, 0.0, 0.0, 24.0));
        card.SetInteractive(true);

        // Same shapes the Nemeses screen uses: cell_bg is the fill, cell_fg the outline with the cut corner.
        let fill: ref<inkImage> = new inkImage();
        fill.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
        fill.SetTexturePart(n"cell_bg");
        fill.SetNineSliceScale(true);
        fill.SetAnchor(inkEAnchor.Fill);
        fill.SetTintColor(this.Dark());
        fill.SetOpacity(0.95);
        fill.Reparent(card);

        let frame: ref<inkImage> = new inkImage();
        frame.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
        frame.SetTexturePart(n"cell_fg");
        frame.SetNineSliceScale(true);
        frame.SetAnchor(inkEAnchor.Fill);
        frame.SetTintColor(color);
        frame.SetOpacity(1.0);
        frame.Reparent(card);

        // a second, inset outline marks the selected card
        let inner: ref<inkImage> = new inkImage();
        inner.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
        inner.SetTexturePart(n"cell_fg");
        inner.SetNineSliceScale(true);
        inner.SetAnchor(inkEAnchor.Fill);
        inner.SetMargin(new inkMargin(9.0, 9.0, 9.0, 9.0));
        inner.SetTintColor(color);
        inner.SetOpacity(1.0);
        inner.SetVisible(false);
        inner.Reparent(card);

        ArrayPush(this.m_cardInner, inner);
        ArrayPush(this.m_cardFrames, frame);
        ArrayPush(this.m_cardFills, fill);
        card.RegisterToCallback(n"OnRelease", this, n"OnGRChronCardClick");
        return card;
    }

    // gang tabs: "All Gang History" first, then the members
    private func MakeCard(index: Int32) -> ref<inkCanvas> {
        let isAll: Bool = index == 0;
        let member: ref<GRMenuEntry>;
        if !isAll {
            member = this.m_members[index - 1];
        }
        let color: HDRColor = this.Light();
        if !isAll {
            color = member.dead ? this.Dim() : this.RankColor(member.rank);
        }
        let card: ref<inkCanvas> = this.NewCardShell(index, color);

        if isAll {
            this.Label(card, this.T("GRChron-AllGangHistory", "All Gang History"), 50, this.Light(), n"Bold", 26.0, 30.0);
            this.Label(card, this.m_gangLabels[this.m_gang], 30, this.GangColor(this.m_gangKeys[this.m_gang]), n"Medium", 26.0, 106.0);
            ArrayPush(this.m_cardNames, "");
        } else {
            this.Label(card, this.RankName(member.rank), 26, color, n"Bold", 26.0, 14.0);
            this.Label(card, member.name, 46, color, n"Bold", 26.0, 48.0);
            let sub: String = member.dead ? member.cause : "\"" + member.title + "\"";
            this.Label(card, sub, 30, member.dead ? this.Dim() : this.Grey(), n"Regular", 26.0, 116.0);
            ArrayPush(this.m_cardNames, member.name);
        }
        return card;
    }

    // Full History tab: "All History" first, then one card per gang
    private func MakeFullCard(index: Int32) -> ref<inkCanvas> {
        let isAll: Bool = index == 0;
        let key: String = "";
        if !isAll {
            key = this.m_gangKeys[index - 1];
        }
        let color: HDRColor = isAll ? this.Light() : this.GangColor(key);
        let card: ref<inkCanvas> = this.NewCardShell(index, color);

        if isAll {
            this.Label(card, this.T("GRChron-AllHistory", "All History"), 50, this.Light(), n"Bold", 26.0, 30.0);
            this.Label(card, this.T("GRChron-EveryGang", "Every gang") + "  |  " + this.EventsText(this.CountEvents("")), 30, this.Grey(), n"Medium", 26.0, 106.0);
        } else {
            this.Label(card, StrUpper(this.EventsText(this.CountEvents(key))), 26, color, n"Bold", 26.0, 14.0);
            this.Label(card, this.m_gangLabels[index - 1], 46, color, n"Bold", 26.0, 48.0);
            this.Label(card, this.GangCounts(key), 30, this.Grey(), n"Regular", 26.0, 116.0);
        }
        ArrayPush(this.m_cardNames, key);
        return card;
    }

    // events that involve a gang ("" = every event)
    private func CountEvents(key: String) -> Int32 {
        if !IsDefined(this.m_hist) {
            return 0;
        }
        let total: Int32 = this.m_hist.Count();
        if StrLen(key) == 0 {
            return total;
        }
        let count: Int32 = 0;
        let i: Int32 = 0;
        while i < total {
            if StrContains(this.m_hist.Gangs(i), "|" + key + "|") {
                count += 1;
            }
            i += 1;
        }
        return count;
    }

    private func GangCounts(key: String) -> String {
        let alive: Int32 = 0;
        let fallen: Int32 = 0;
        if IsDefined(this.m_data) {
            let entries: array<ref<GRMenuEntry>> = this.m_data.GetEntries();
            let i: Int32 = 0;
            while i < ArraySize(entries) {
                if Equals(entries[i].gangKey, key) {
                    if entries[i].dead {
                        fallen += 1;
                    } else {
                        alive += 1;
                    }
                }
                i += 1;
            }
        }
        return this.Fmt(this.Fmt(this.T("GRChron-AliveFallen", "%d alive  |  %d fallen"), "%d", IntToString(alive)), "%d", IntToString(fallen));
    }

    private func GangLabelOf(key: String) -> String {
        let i: Int32 = 0;
        while i < ArraySize(this.m_gangKeys) {
            if Equals(this.m_gangKeys[i], key) {
                return this.m_gangLabels[i];
            }
            i += 1;
        }
        return key;
    }

    // first gang (tab order) named in an event's gang string, or -1
    private func FirstGangIndex(gangs: String) -> Int32 {
        let i: Int32 = 0;
        while i < ArraySize(this.m_gangKeys) {
            if StrContains(gangs, "|" + this.m_gangKeys[i] + "|") {
                return i;
            }
            i += 1;
        }
        return -1;
    }

    private func GangCountIn(gangs: String) -> Int32 {
        let count: Int32 = 0;
        let i: Int32 = 0;
        while i < ArraySize(this.m_gangKeys) {
            if StrContains(gangs, "|" + this.m_gangKeys[i] + "|") {
                count += 1;
            }
            i += 1;
        }
        return count;
    }

    private func StyleCards() {
        let i: Int32 = 0;
        while i < ArraySize(this.m_cardNames) {
            let selected: Bool = Equals(this.m_cardNames[i], this.m_member);
            this.m_cardInner[i].SetVisible(selected);
            this.m_cardFills[i].SetTintColor(selected ? this.PanelColor() : this.Dark());
            i += 1;
        }
    }

    // ---------------------------------------------------------------- right: history (scrolls vertically)
    private func BuildHistoryPanel() {
        let panel: ref<inkCanvas> = new inkCanvas();
        panel.SetName(n"gr_chron_panel");
        panel.SetAnchor(inkEAnchor.TopLeft);
        panel.SetMargin(new inkMargin(1470.0, 400.0, 0.0, 0.0));
        panel.SetSize(new Vector2(2250.0, 1520.0));
        panel.Reparent(this.m_root);

        let fill: ref<inkRectangle> = new inkRectangle();
        fill.SetAnchor(inkEAnchor.Fill);
        fill.SetTintColor(this.PanelColor());
        fill.SetOpacity(0.95);
        fill.Reparent(panel);

        let frame: ref<GRBorder> = new GRBorder();
        frame.SetAnchor(inkEAnchor.Fill);
        frame.SetThickness(3.0);
        frame.SetTintColor(this.DarkRed());
        frame.SetOpacity(1.0);
        frame.Reparent(panel);

        let header: ref<inkCanvas> = new inkCanvas();
        header.SetName(n"gr_chron_header");
        header.SetAnchor(inkEAnchor.TopLeft);
        header.SetSize(new Vector2(2250.0, 230.0));
        header.Reparent(panel);
        this.m_headerHost = header;

        this.NewRect(panel, 50.0, 232.0, 2150.0, 3.0, this.Grey(), 0.25);

        let host: ref<inkCanvas> = new inkCanvas();
        host.SetName(n"gr_chron_time_host");
        host.SetAnchor(inkEAnchor.TopLeft);
        host.SetMargin(new inkMargin(50.0, 252.0, 0.0, 0.0));
        host.SetSize(new Vector2(2150.0, 1240.0));
        host.SetInteractive(true);
        host.Reparent(panel);

        let scroll: ref<inkScrollArea> = new inkScrollArea();
        scroll.SetName(n"scroll");
        scroll.SetAnchor(inkEAnchor.Fill);
        scroll.SetMargin(new inkMargin(0.0, 0.0, 40.0, 0.0));
        scroll.SetUseInternalMask(true);
        scroll.SetConstrainContentPosition(true);
        scroll.Reparent(host);

        // Draggable scrollbar on the right edge; the scroll controller keeps it in sync with the content.
        let bar: ref<inkCanvas> = this.NewBar(host, 2136.0, 0.0, 10.0, 1240.0, false);

        let scroller: ref<inkScrollController> = new inkScrollController();
        scroller.ScrollArea = inkScrollAreaRef.Create(scroll);
        scroller.VerticalScrollBarRef = inkWidgetRef.Create(bar);
        scroller.direction = inkEScrollDirection.Vertical;
        scroller.scrollSpeedMouse = 90.0;
        scroller.scrollSpeedGamepad = 90.0;
        scroller.useGlobalInput = false;  // see the member-list scroller above - scope wheel to hover
        host.AttachController(scroller);
        this.m_timeScroller = scroller;

        let list: ref<inkVerticalPanel> = new inkVerticalPanel();
        list.SetName(n"gr_chron_timeline");
        list.SetFitToContent(true);
        list.SetHAlign(inkEHorizontalAlign.Fill);
        list.Reparent(scroll);
        this.m_timeline = list;
    }

    private func FindMember(name: String) -> ref<GRMenuEntry> {
        let i: Int32 = 0;
        while i < ArraySize(this.m_members) {
            if Equals(this.m_members[i].name, name) {
                return this.m_members[i];
            }
            i += 1;
        }
        return null;
    }

    private func EventMatches(i: Int32, gangKey: String) -> Bool {
        if !StrContains(this.m_hist.Gangs(i), "|" + gangKey + "|") {
            return false;
        }
        if StrLen(this.m_member) > 0 {
            return StrContains(this.m_hist.Names(i), "|" + this.m_member + "|");
        }
        return true;
    }

    private func EventVisible(i: Int32) -> Bool {
        if this.m_isFull {
            if StrLen(this.m_member) == 0 {
                return true;
            }
            return StrContains(this.m_hist.Gangs(i), "|" + this.m_member + "|");
        }
        return this.EventMatches(i, this.m_gangKeys[this.m_gang]);
    }

    private func BuildHistory() {
        this.m_headerHost.RemoveAllChildren();
        this.m_timeline.RemoveAllChildren();
        if ArraySize(this.m_gangKeys) == 0 {
            return;
        }
        let gangKey: String = this.m_isFull ? this.m_member : this.m_gangKeys[this.m_gang];
        let gangLabel: String = this.m_gangLabels[this.m_gang];
        if this.m_isFull {
            gangLabel = StrLen(this.m_member) == 0 ? this.T("GRChron-AllHistory", "All History") : this.GangLabelOf(this.m_member);
        }
        let member: ref<GRMenuEntry>;
        if !this.m_isFull {
            member = this.FindMember(this.m_member);
        }

        // count first, for the header line
        let count: Int32 = 0;
        let total: Int32 = IsDefined(this.m_hist) ? this.m_hist.Count() : 0;
        let i: Int32 = 0;
        while i < total {
            if this.EventVisible(i) {
                count += 1;
            }
            i += 1;
        }

        // header: tag line, `Name "Title"` on one line, count line
        let tag: String = IsDefined(member) ? this.RankName(member.rank) + "  |  " + StrUpper(gangLabel) : StrUpper(this.T("GRChron-AllGangHistory", "All Gang History")) + "  |  " + StrUpper(gangLabel);
        if this.m_isFull {
            tag = StrUpper(this.T("GRChron-TabFull", "Full History")) + "  |  " + (StrLen(this.m_member) == 0 ? StrUpper(this.T("GRChron-AllGangs", "All gangs")) : StrUpper(gangLabel));
        }
        this.Label(this.m_headerHost, tag, 30, this.Cyan(), n"Bold", 50.0, 26.0);

        let nameRow: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        nameRow.SetFitToContent(true);
        nameRow.SetAnchor(inkEAnchor.TopLeft);
        nameRow.SetMargin(new inkMargin(50.0, 64.0, 0.0, 0.0));
        nameRow.Reparent(this.m_headerHost);
        let nameColor: HDRColor = IsDefined(member) ? this.RankColor(member.rank) : this.GangColor(gangKey);
        let nameText: ref<inkText> = this.NewText(IsDefined(member) ? member.name : gangLabel, 68, nameColor, n"Bold");
        nameText.SetVAlign(inkEVerticalAlign.Bottom);
        nameText.Reparent(nameRow);
        if IsDefined(member) {
            let titleText: ref<inkText> = this.NewText("\"" + member.title + "\"", 46, this.Grey(), n"Regular");
            titleText.SetVAlign(inkEVerticalAlign.Bottom);
            titleText.SetMargin(new inkMargin(28.0, 0.0, 0.0, 6.0));
            titleText.Reparent(nameRow);
        }
        let countLine: String = this.EventsText(count);
        if IsDefined(member) && member.dead {
            countLine += "  |  " + member.cause;
        }
        this.Label(this.m_headerHost, countLine, 32, this.Grey(), n"Medium", 50.0, 160.0);

        // timeline, oldest to newest
        if count == 0 {
            let none: ref<inkText> = this.NewWrappedText(IsDefined(this.m_hist) && total > 0 ? this.T("GRChron-NoEventsHere", "No recorded events here yet.") : this.T("GRChron-NoHistory", "No history yet. It is recorded by the Gang Retaliation History mod while you play."), 34, this.Dim(), 1900.0);
            none.SetMargin(new inkMargin(0.0, 24.0, 0.0, 0.0));
            none.Reparent(this.m_timeline);
            return;
        }
        let lastDay: Int32 = -1;
        let lastShown: Int32 = 0;
        i = 0;
        while i < total {
            if this.EventVisible(i) {
                let day: Int32 = this.m_hist.Day(i);
                this.AddEventRow(day, day != lastDay, this.m_hist.Kind(i), this.m_hist.Text(i), this.m_hist.Gangs(i), this.m_isFull);
                lastDay = day;
                lastShown = day;
            }
            i += 1;
        }
        this.AddNowRow(lastShown);
    }

    private func NewWrappedText(text: String, size: Int32, color: HDRColor, width: Float) -> ref<inkText> {
        let label: ref<inkText> = this.NewText(text, size, color, n"Regular");
        label.SetWrapping(true, width);
        return label;
    }

    private func AddEventRow(day: Int32, showDay: Bool, kind: String, text: String, gangs: String, showGang: Bool) {
        if showDay {
            let spacer: ref<inkCanvas> = new inkCanvas();
            spacer.SetSize(new Vector2(10.0, 30.0));
            spacer.Reparent(this.m_timeline);
        }
        let color: HDRColor = this.KindColor(kind);

        let row: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        row.SetFitToContent(true);
        row.Reparent(this.m_timeline);

        let dayBox: ref<inkCanvas> = new inkCanvas();
        dayBox.SetSize(new Vector2(190.0, 10.0));
        dayBox.SetVAlign(inkEVerticalAlign.Fill);
        dayBox.Reparent(row);
        if showDay {
            this.Label(dayBox, this.DayText(day), 32, this.Cyan(), n"Bold", 0.0, 10.0);
        }

        let rail: ref<inkCanvas> = new inkCanvas();
        rail.SetSize(new Vector2(60.0, 10.0));
        rail.SetVAlign(inkEVerticalAlign.Fill);
        rail.Reparent(row);
        let line: ref<inkRectangle> = new inkRectangle();
        line.SetAnchor(inkEAnchor.LeftFillVerticaly);
        line.SetMargin(new inkMargin(26.0, 0.0, 0.0, 0.0));
        line.SetWidth(3.0);
        line.SetTintColor(this.Dim());
        line.SetOpacity(0.8);
        line.Reparent(rail);
        this.NewRect(rail, 19.0, 20.0, 18.0, 18.0, color, 1.0);

        let tagBox: ref<inkCanvas> = new inkCanvas();
        tagBox.SetSize(new Vector2(320.0, 10.0));
        tagBox.SetVAlign(inkEVerticalAlign.Fill);
        tagBox.Reparent(row);
        this.Label(tagBox, this.KindLabel(kind), 28, color, n"Bold", 0.0, 14.0);
        let tail: Float = 18.0;
        if showGang {
            // which gang(s) the event involves, under the tag (first gang + "+n")
            let first: Int32 = this.FirstGangIndex(gangs);
            if first >= 0 {
                let extra: Int32 = this.GangCountIn(gangs) - 1;
                let chip: String = StrUpper(this.m_gangLabels[first]) + (extra > 0 ? "  +" + IntToString(extra) : "");
                this.Label(tagBox, chip, 24, this.GangColor(this.m_gangKeys[first]), n"Medium", 0.0, 52.0);
                tail = 44.0;
            }
        }

        let message: ref<inkText> = this.NewWrappedText(text, 34, this.Light(), 1500.0);
        message.SetMargin(new inkMargin(0.0, 6.0, 0.0, tail));
        message.Reparent(row);
    }

    private func AddNowRow(day: Int32) {
        let spacer: ref<inkCanvas> = new inkCanvas();
        spacer.SetSize(new Vector2(10.0, 30.0));
        spacer.Reparent(this.m_timeline);
        let row: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        row.SetFitToContent(true);
        row.Reparent(this.m_timeline);
        let dayBox: ref<inkCanvas> = new inkCanvas();
        dayBox.SetSize(new Vector2(190.0, 40.0));
        dayBox.Reparent(row);
        this.Label(dayBox, this.T("GRChron-Now", "NOW"), 30, this.Dim(), n"Bold", 0.0, 4.0);
        let tail: ref<inkCanvas> = new inkCanvas();
        tail.SetSize(new Vector2(60.0, 40.0));
        tail.Reparent(row);
        this.NewRect(tail, 19.0, 10.0, 18.0, 18.0, this.Cyan(), 0.5);
        let text: ref<inkText> = this.NewText(this.DayText(day), 30, this.Dim(), n"Medium");
        text.SetMargin(new inkMargin(0.0, 4.0, 0.0, 0.0));
        text.Reparent(row);
    }

    // ---------------------------------------------------------------- selection + refresh
    private func SelectTab(index: Int32) {
        let count: Int32 = ArraySize(this.m_gangKeys) + 1;
        if count <= 1 {
            return;
        }
        this.m_tab = (index % count + count) % count;
        this.m_isFull = this.m_tab == 0;
        if !this.m_isFull {
            this.m_gang = this.m_tab - 1;
        }
        this.m_member = "";

        let i: Int32 = 0;
        while i < ArraySize(this.m_tabTexts) {
            let on: Bool = i == this.m_tab;
            this.m_tabTexts[i].SetTintColor(on ? this.Cyan() : this.Grey());
            this.m_tabBars[i].SetSize(new Vector2(236.0, on ? 8.0 : 4.0));
            this.m_tabBars[i].SetTintColor(on ? this.Cyan() : this.DarkRed());
            i += 1;
        }

        this.BuildCards();
        this.StyleCards();
        this.m_listScroller.SetScrollPosition(0.0);

        // summary: this gang's members, or every nemesis on the Full History tab
        let alive: Int32 = 0;
        let fallen: Int32 = 0;
        if this.m_isFull {
            if IsDefined(this.m_data) {
                let entries: array<ref<GRMenuEntry>> = this.m_data.GetEntries();
                i = 0;
                while i < ArraySize(entries) {
                    if entries[i].dead {
                        fallen += 1;
                    } else {
                        alive += 1;
                    }
                    i += 1;
                }
            }
        } else {
            i = 0;
            while i < ArraySize(this.m_members) {
                if this.m_members[i].dead {
                    fallen += 1;
                } else {
                    alive += 1;
                }
                i += 1;
            }
        }
        this.m_summary.SetText(this.T("GR-MenuAlive", "ALIVE") + " " + IntToString(alive) + "   |   " + this.T("GR-MenuFallenShort", "FALLEN") + " " + IntToString(fallen));

        this.RefreshHistory();
    }

    private func SelectMember(name: String) {
        this.m_member = name;
        this.StyleCards();
        this.RefreshHistory();
    }

    private func RefreshHistory() {
        this.BuildHistory();
        this.ScrollToBottomLater();
    }

    // Layout isn't finished in the frame the rows are added, so let a short no-op fade run on the root and
    // jump to the newest event when it ends.
    private func ScrollToBottomLater() {
        let fade: ref<inkAnimTransparency> = new inkAnimTransparency();
        fade.SetStartTransparency(1.0);
        fade.SetEndTransparency(1.0);
        fade.SetDuration(0.15);
        let def: ref<inkAnimDef> = new inkAnimDef();
        def.AddInterpolator(fade);
        this.m_wait = this.m_root.PlayAnimation(def);
        this.m_wait.RegisterToCallback(inkanimEventType.OnFinish, this, n"OnGRChronScrollBottom");
    }

    protected cb func OnGRChronScrollBottom(anim: ref<inkAnimProxy>) -> Bool {
        this.m_timeScroller.UpdateScrollPositionFromScrollArea();
        this.m_timeScroller.SetScrollPosition(1.0);
        return true;
    }

    // A thin track with a grabbable handle. Returns the track; its slider is attached as the controller.
    private func NewBar(parent: ref<inkCompoundWidget>, x: Float, y: Float, w: Float, h: Float, sideways: Bool) -> ref<inkCanvas> {
        let bar: ref<inkCanvas> = new inkCanvas();
        bar.SetAnchor(inkEAnchor.TopLeft);
        bar.SetMargin(new inkMargin(x, y, 0.0, 0.0));
        bar.SetSize(new Vector2(w, h));
        bar.SetInteractive(true);
        bar.Reparent(parent);

        this.NewRect(bar, 0.0, 0.0, w, h, this.DarkRed(), 0.5);

        let grip: ref<inkRectangle> = new inkRectangle();
        grip.SetAnchor(sideways ? inkEAnchor.LeftFillVerticaly : inkEAnchor.TopFillHorizontaly);
        grip.SetSize(sideways ? new Vector2(120.0, h) : new Vector2(w, 120.0));
        grip.SetTintColor(this.Red());
        grip.SetInteractive(true);
        grip.Reparent(bar);
        grip.RegisterToCallback(n"OnPress", this, n"OnGRChronGripPress");
        ArrayPush(this.m_grips, grip);

        let drag: ref<inkSliderController> = new inkSliderController();
        drag.slidingAreaRef = inkWidgetRef.Create(bar);
        drag.handleRef = inkWidgetRef.Create(grip);
        drag.direction = sideways ? inkESliderDirection.Horizontal : inkESliderDirection.Vertical;
        drag.autoSizeHandle = !sideways;
        drag.Setup(0.0, 1.0, 0.0);
        bar.AttachController(drag);
        if sideways {
            this.m_listGrip = grip;
            this.m_listDrag = drag;
        }
        return bar;
    }

    // ---------------------------------------------------------------- input
    // GANGS / TERRITORY / ARSENAL in the switcher: hand over to the Nemeses screen 
    // The hub's scenario (MenuScenario_HubMenu) receives the event below and opens the menu by name.
    protected cb func OnGRChronViewClick(evt: ref<inkPointerEvent>) -> Bool {
        if !evt.IsAction(n"click") {
            return false;
        }
        if !IsDefined(this.m_chronDispatcher) {
            FTLog("[GangRetaliationHistory] switcher: no menu event dispatcher, cannot open the Nemeses screen");
            return false;
        }
        let target: ref<inkWidget> = evt.GetTarget();
        let name: CName = IsDefined(target) ? target.GetName() : n"";
        let event: CName = n"OnGRChronOpenGangs";
        if Equals(name, n"gr_chron_view_territory") {
            event = n"OnGRChronOpenTerritory";
        } else if Equals(name, n"gr_chron_view_arsenal") {
            event = n"OnGRChronOpenArsenal";
        }
        this.PlaySound(n"Button", n"OnPress");
        this.m_chronDispatcher.SpawnEvent(event);
        return true;
    }

    // the menu system hands every menu controller its event dispatcher through this callback
    public cb func OnSetMenuEventDispatcher(menuEventDispatcher: wref<inkMenuEventDispatcher>) -> Bool {
        super.OnSetMenuEventDispatcher(menuEventDispatcher);
        this.m_chronDispatcher = menuEventDispatcher;
        return true;
    }

    protected cb func OnGRChronTabClick(evt: ref<inkPointerEvent>) -> Bool {
        if !evt.IsAction(n"click") {
            return false;
        }
        let target: CName = evt.GetCurrentTarget().GetName();
        let i: Int32 = 0;
        while i < ArraySize(this.m_gangKeys) + 1 {
            if Equals(target, StringToName("gr_chron_tab_" + IntToString(i))) {
                if i != this.m_tab {
                    this.SelectTab(i);
                    this.PlaySound(n"Button", n"OnPress");
                }
                return true;
            }
            i += 1;
        }
        return false;
    }

    protected cb func OnGRChronCardClick(evt: ref<inkPointerEvent>) -> Bool {
        if !evt.IsAction(n"click") {
            return false;
        }
        let target: CName = evt.GetCurrentTarget().GetName();
        let i: Int32 = 0;
        while i < ArraySize(this.m_cardNames) {
            if Equals(target, StringToName("gr_chron_card_" + IntToString(i))) {
                this.SelectMember(this.m_cardNames[i]);
                this.PlaySound(n"Button", n"OnPress");
                return true;
            }
            i += 1;
        }
        return false;
    }

    protected cb func OnGRChronGripPress(evt: ref<inkPointerEvent>) -> Bool {
        if evt.IsAction(n"click") {
            let grip: ref<inkRectangle> = evt.GetCurrentTarget() as inkRectangle;
            if IsDefined(grip) {
                grip.SetTintColor(this.Cyan());
            }
        }
        return false;
    }

    protected cb func OnGRChronInput(evt: ref<inkPointerEvent>) -> Bool {
        // any button release ends a drag: put the scrollbar handles back to red
        let g: Int32 = 0;
        while g < ArraySize(this.m_grips) {
            this.m_grips[g].SetTintColor(this.Red());
            g += 1;
        }
        if evt.IsHandled() {
            return false;
        }
        if evt.IsAction(n"sort_list") && IsDefined(this.m_chronDispatcher) {
            // TAB, same key as the Nemeses screen's view switch: HISTORY wraps back around to GANGS
            this.PlaySound(n"Button", n"OnPress");
            this.m_chronDispatcher.SpawnEvent(n"OnGRChronOpenGangs");
            evt.Handle();
            return true;
        }
        if evt.IsAction(n"option_switch_prev") {
            this.SelectTab(this.m_tab - 1);
            evt.Handle();
            return true;
        }
        if evt.IsAction(n"option_switch_next") {
            this.SelectTab(this.m_tab + 1);
            evt.Handle();
            return true;
        }
        return false;
    }
}
