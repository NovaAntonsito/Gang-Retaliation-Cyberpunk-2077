
module GangRetaliation

public final class GRBorder extends inkBorder {}

public class GRMenuEntry {
    public let gangKey: String;
    public let gang: String;
    public let rank: Int32;
    public let dead: Bool;
    public let name: String;
    public let title: String;
    public let known: Bool;
    public let renown: Int32;
    public let traits: String;
    public let hint: String;
    public let encounters: Int32;
    public let escapes: Int32;
    public let ambushes: Int32;
    public let gigs: Int32;
    public let origin: String;
    public let cause: String;
    public let id: Int32;
    public let traitKeys: String;
}

public class GRMenuData extends ScriptableSystem {
    private let m_entries: array<ref<GRMenuEntry>>;
    private let m_gangs: array<String>;
    private let m_vacancyGangs: array<String>;
    private let m_vacancyBoss: array<String>;
    private let m_vacancyLieutenant: array<String>;
    private let m_dKeys: array<String>;
    private let m_dLabels: array<String>;
    private let m_dRegions: array<String>;
    private let m_dOwners: array<String>;
    private let m_dInfluence: array<String>;
    private let m_dWars: array<String>;
    private let m_sGangs: array<String>;
    private let m_sLabels: array<String>;
    private let m_sValues: array<Int32>;
    private let m_sNotes: array<String>;
    private let m_rDays: array<String>;
    private let m_rTexts: array<String>;
    private let m_page: Int32;
    private let m_arsenalPage: Int32;
    private let m_pendingView: Int32;
    private let m_pendingBountyFocus: Int32;
    private let m_bountyMode: Bool;
    private let m_bountyLayoutLogged: Bool;

    public static func Get(gi: GameInstance) -> ref<GRMenuData> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRMenuData") as GRMenuData;
    }

    public static func RequestView(gi: GameInstance, view: CName) -> Bool {
        let index: Int32 = GRMenuData.ViewIndex(view);
        let data: ref<GRMenuData> = GRMenuData.Get(gi);
        if index < 0 || !IsDefined(data) {
            GRLog("Menu: API RequestView ignorada (vista desconocida: " + NameToString(view) + ")");
            return false;
        }
        data.m_pendingView = index + 1;
        return true;
    }

    public static func OpenView(from: ref<inkGameController>, view: CName) -> Bool {
        let menu: ref<gameuiMenuGameController> = from as gameuiMenuGameController;
        if !IsDefined(menu) {
            GRLog("Menu: API OpenView ignorada (from no es un gameuiMenuGameController)");
            return false;
        }
        let player: ref<GameObject> = menu.GetPlayerControlledObject();
        if !IsDefined(player) {
            return false;
        }
        let gi: GameInstance = player.GetGame();
        let settings: ref<GRSettings> = GRSettings.Get(gi);
        if IsDefined(settings) && !settings.enabled {
            GRLog("Menu: API OpenView ignorada (mod desactivado)");
            return false;
        }
        let dispatcher: wref<inkMenuEventDispatcher> = menu.GangRetaliationGetDispatcher();
        if !IsDefined(dispatcher) {
            GRLog("Menu: API OpenView ignorada (el controlador no tiene dispatcher: falta super.OnSetMenuEventDispatcher)");
            return false;
        }
        if !GRMenuData.RequestView(gi, view) {
            return false;
        }
        GRLog("Menu: API OpenView -> " + NameToString(view) + " (evento OnGangRetaliationApiOpenView)");
        dispatcher.SpawnEvent(n"OnGangRetaliationApiOpenView");
        return true;
    }

    public func SetBountyMode(on: Bool) {
        this.m_bountyMode = on;
    }

    public func ConsumeBountyLayoutLog() -> Bool {
        if this.m_bountyLayoutLogged {
            return false;
        }
        this.m_bountyLayoutLogged = true;
        return true;
    }

    public func ConsumeBountyMode() -> Bool {
        let on: Bool = this.m_bountyMode;
        this.m_bountyMode = false;
        return on;
    }

    public func ConsumePendingView() -> Int32 {
        let view: Int32 = this.m_pendingView - 1;
        this.m_pendingView = 0;
        return view;
    }

    // Lets clicking a Nemesis's bounty badge in the GANGS detail panel land on that same contract once
    // InitBounty (Menu.reds) opens - same +1/-1 "0 means none" encoding as m_pendingView above.
    public func RequestBountyFocus(nemesisId: Int32) {
        this.m_pendingBountyFocus = nemesisId + 1;
    }

    public func ConsumeBountyFocus() -> Int32 {
        let id: Int32 = this.m_pendingBountyFocus - 1;
        this.m_pendingBountyFocus = 0;
        return id;
    }

    private static func ViewIndex(view: CName) -> Int32 {
        if Equals(view, n"gangs") {
            return 0;
        }
        if Equals(view, n"territory") {
            return 1;
        }
        if Equals(view, n"arsenal") {
            return 2;
        }
        return -1;
    }

    public func Clear() {
        ArrayClear(this.m_entries);
        ArrayClear(this.m_gangs);
        ArrayClear(this.m_vacancyGangs);
        ArrayClear(this.m_vacancyBoss);
        ArrayClear(this.m_vacancyLieutenant);
        ArrayClear(this.m_dKeys);
        ArrayClear(this.m_dLabels);
        ArrayClear(this.m_dRegions);
        ArrayClear(this.m_dOwners);
        ArrayClear(this.m_dInfluence);
        ArrayClear(this.m_dWars);
        ArrayClear(this.m_sGangs);
        ArrayClear(this.m_sLabels);
        ArrayClear(this.m_sValues);
        ArrayClear(this.m_sNotes);
        ArrayClear(this.m_rDays);
        ArrayClear(this.m_rTexts);
    }

    public func Add(gangKey: String, gang: String, rank: Int32, dead: Bool, name: String, title: String, known: Bool, renown: Int32) {
        let entry: ref<GRMenuEntry> = new GRMenuEntry();
        entry.gangKey = gangKey;
        entry.gang = gang;
        entry.rank = rank;
        entry.dead = dead;
        entry.name = name;
        entry.title = title;
        entry.known = known;
        entry.renown = renown;
        ArrayPush(this.m_entries, entry);
        if !ArrayContains(this.m_gangs, gangKey) {
            ArrayPush(this.m_gangs, gangKey);
        }
    }

    public func AddDetail(traits: String, hint: String, origin: String, cause: String) {
        let last: Int32 = ArraySize(this.m_entries) - 1;
        if last < 0 {
            return;
        }
        let entry: ref<GRMenuEntry> = this.m_entries[last];
        entry.traits = traits;
        entry.hint = hint;
        entry.origin = origin;
        entry.cause = cause;
    }

    public func AddStats(encounters: Int32, escapes: Int32, ambushes: Int32, gigs: Int32) {
        let last: Int32 = ArraySize(this.m_entries) - 1;
        if last < 0 {
            return;
        }
        let entry: ref<GRMenuEntry> = this.m_entries[last];
        entry.encounters = encounters;
        entry.escapes = escapes;
        entry.ambushes = ambushes;
        entry.gigs = gigs;
    }

    public func AddIds(id: Int32, traitKeys: String) {
        let last: Int32 = ArraySize(this.m_entries) - 1;
        if last < 0 {
            return;
        }
        let entry: ref<GRMenuEntry> = this.m_entries[last];
        entry.id = id;
        entry.traitKeys = traitKeys;
    }

    public func SetVacancy(gangKey: String, boss: String, lieutenant: String) {
        ArrayPush(this.m_vacancyGangs, gangKey);
        ArrayPush(this.m_vacancyBoss, boss);
        ArrayPush(this.m_vacancyLieutenant, lieutenant);
    }

    public func GetVacancy(gangKey: String, rank: Int32) -> String {
        let i: Int32 = 0;
        while i < ArraySize(this.m_vacancyGangs) {
            if Equals(this.m_vacancyGangs[i], gangKey) {
                return rank >= 3 ? this.m_vacancyBoss[i] : this.m_vacancyLieutenant[i];
            }
            i += 1;
        }
        return "";
    }

    public func AddDistrict(key: String, label: String, region: String, owner: String, influence: String, war: String) {
        ArrayPush(this.m_dKeys, key);
        ArrayPush(this.m_dLabels, label);
        ArrayPush(this.m_dRegions, region);
        ArrayPush(this.m_dOwners, owner);
        ArrayPush(this.m_dInfluence, influence);
        ArrayPush(this.m_dWars, war);
    }

    public func AddGangStrength(gang: String, label: String, value: Int32, note: String) {
        ArrayPush(this.m_sGangs, gang);
        ArrayPush(this.m_sLabels, label);
        ArrayPush(this.m_sValues, value);
        ArrayPush(this.m_sNotes, note);
    }

    public func AddRumor(day: String, text: String) {
        ArrayPush(this.m_rDays, day);
        ArrayPush(this.m_rTexts, text);
    }

    public func DistrictKeys() -> array<String> { return this.m_dKeys; }
    public func DistrictLabels() -> array<String> { return this.m_dLabels; }
    public func DistrictRegions() -> array<String> { return this.m_dRegions; }
    public func DistrictOwners() -> array<String> { return this.m_dOwners; }
    public func DistrictInfluence() -> array<String> { return this.m_dInfluence; }
    public func DistrictWars() -> array<String> { return this.m_dWars; }
    public func StrengthGangs() -> array<String> { return this.m_sGangs; }
    public func StrengthLabels() -> array<String> { return this.m_sLabels; }
    public func StrengthValues() -> array<Int32> { return this.m_sValues; }
    public func StrengthNotes() -> array<String> { return this.m_sNotes; }
    public func RumorDays() -> array<String> { return this.m_rDays; }
    public func RumorTexts() -> array<String> { return this.m_rTexts; }

    public func GetGangs() -> array<String> {
        return this.m_gangs;
    }

    public func GetEntries() -> array<ref<GRMenuEntry>> {
        return this.m_entries;
    }

    public func GetPage() -> Int32 {
        return this.m_page;
    }

    public func SetPage(page: Int32) {
        this.m_page = page;
    }

    public func GetArsenalPage() -> Int32 {
        return this.m_arsenalPage;
    }

    public func SetArsenalPage(page: Int32) {
        this.m_arsenalPage = page;
    }

    public func Text(key: String) -> String {
        return GRSystem.Get(this.GetGameInstance()).GetText(key);
    }
}

public class GRNemesisMenuController extends gameuiMenuGameController {
    private let m_data: ref<GRMenuData>;
    private let m_grDispatcher: wref<inkMenuEventDispatcher>;
    private let m_page: Int32;
    private let m_tree: wref<inkCanvas>;
    private let m_links: wref<inkCanvas>;
    private let m_pathPoints: array<Vector2>;
    private let m_pathStart: array<Int32>;
    private let m_pathColor: array<HDRColor>;
    private let m_detail: wref<inkCanvas>;
    private let m_detailHeader: wref<inkVerticalPanel>;
    private let m_detailContent: wref<inkVerticalPanel>;
    private let m_detailGrip: wref<inkRectangle>;
    private let m_detailDrag: wref<inkSliderController>;
    private let m_detailScroller: wref<inkScrollController>;
    private let m_fallenGrip: wref<inkRectangle>;
    private let m_fallenDrag: wref<inkSliderController>;
    private let m_fallenScroller: wref<inkScrollController>;
    private let m_fallenSyncing: Bool;
    private let m_gangTitle: wref<inkText>;
    private let m_gangCount: wref<inkText>;
    private let m_marks: wref<inkHorizontalPanel>;
    private let m_summary: wref<inkText>;
    private let m_buttonHints: wref<ButtonHints>;
    private let m_cards: array<ref<GRMenuEntry>>;
    private let m_cardFrames: array<wref<inkImage>>;
    private let m_cardSelFrames: array<wref<inkImage>>;
    private let m_fallenCards: array<ref<GRMenuEntry>>;
    private let m_fallenBorders: array<wref<GRBorder>>;
    private let m_fallenExpanded: Bool;
    private let m_tabTexts: array<wref<inkText>>;
    private let m_tabBars: array<wref<inkRectangle>>;
    private let m_tabThreats: array<wref<inkRectangle>>;
    private let m_selName: String;
    private let m_detailTab: Int32;   // 0 Information, 1 History, 2 Gang History
    private let m_detailTabTexts: array<wref<inkText>>;
    private let m_detailTabBorders: array<wref<inkImage>>;
    private let m_detailDay: wref<inkText>;
    private let m_detailBountyIcon: wref<inkImage>;
    private let m_detailBountyNemesisId: Int32;
    private let m_navMenuItem: ref<MenuItemController>;
    private let m_headerNavTarget: CName;
    private let m_view: Int32;
    private let m_viewArsenal: wref<inkText>;
    private let m_rewards: ref<GRRewards>;
    private let m_arsenal: wref<inkCanvas>;
    private let m_arsenalPage: Int32;
    private let m_aCards: array<Int32>;
    private let m_aFrames: array<wref<inkImage>>;
    private let m_aDetail: wref<inkVerticalPanel>;
    private let m_selWeapon: Int32;
    private let m_augBorder: wref<GRBorder>;
    private let m_augTitle: wref<inkText>;
    private let m_augSub: wref<inkText>;
    private let m_augReady: Bool;
    private let m_fusion: wref<inkCanvas>;
    private let m_fContent: wref<inkCanvas>;
    private let m_fButtons: array<wref<inkCanvas>>;
    private let m_fBorders: array<wref<GRBorder>>;
    private let m_fLabels: array<wref<inkText>>;
    private let m_fProgress: wref<inkRectangle>;
    private let m_fOpen: Bool;
    private let m_fDone: Bool;
    private let m_fMain: Int32;
    private let m_fCopies: array<Int32>;
    private let m_fCopy: Int32;
    private let m_fKeep: Int32;
    private let m_fChoices: array<Int32>;
    private let m_fHoldSeen: Bool;
    private let m_fConfirm: Bool;
    private let m_gangSwitch: wref<inkHorizontalPanel>;
    private let m_rankLabels: array<wref<inkText>>;
    private let m_viewGangs: wref<inkText>;
    private let m_viewTerritory: wref<inkText>;
    private let m_territory: wref<inkCanvas>;
    private let m_tDetail: wref<inkVerticalPanel>;
    private let m_tKeys: array<String>;
    private let m_tBorders: array<wref<GRBorder>>;
    private let m_tAtWar: array<Bool>;
    private let m_selDistrict: String;
    private let m_intelGang: String;
    private let m_intelFill: wref<inkRectangle>;
    private let m_intelValue: wref<inkText>;
    private let m_intelLocated: wref<inkText>;
    private let m_bounty: Bool;
    private let m_bounties: ref<GRBounties>;
    private let m_bContracts: array<ref<GRBounty>>;
    private let m_bView: Int32;
    private let m_bFixer: Int32;
    private let m_bSel: Int32;
    private let m_bToday: Int32;
    private let m_bViewTexts: array<wref<inkText>>;
    private let m_bCards: array<Int32>;
    private let m_bFrames: array<wref<inkImage>>;
    private let m_bFixerNames: array<String>;
    private let m_bHint: Bool;

    private func Red() -> HDRColor {
        return new HDRColor(1.1761, 0.3809, 0.3476, 1.0);
    }

    private func Cyan() -> HDRColor {
        return new HDRColor(0.368627, 0.964706, 1.0, 1.0);
    }

    private func Gold() -> HDRColor {
        return new HDRColor(1.1192, 0.8441, 0.2565, 1.0);
    }

    // Magenta: etiqueta y linea del contrato ESPECIAL de Rogue (distinto del dorado del dinero y de las etiquetas de estado).
    private func Special() -> HDRColor {
        return new HDRColor(1.1, 0.42, 0.95, 1.0);
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

    private func Empty() -> HDRColor {
        return new HDRColor(0.15, 0.15, 0.2, 1.0);
    }

    private func DarkRed() -> HDRColor {
        return new HDRColor(0.48, 0.2, 0.19, 1.0);
    }

    private func Orange() -> HDRColor {
        return new HDRColor(1.0, 0.549, 0.102, 1.0);
    }

    private func Dark() -> HDRColor {
        return new HDRColor(0.054902, 0.054902, 0.090196, 1.0);
    }

    private func Panel() -> HDRColor {
        return new HDRColor(0.075, 0.075, 0.12, 1.0);
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

    private func T(key: String) -> String {
        return IsDefined(this.m_data) ? this.m_data.Text(key) : key;
    }

    private func Up(s: String) -> String {
        let out: String = StrUpper(s);
        out = StrReplaceAll(out, "á", "A");
        out = StrReplaceAll(out, "Á", "A");
        out = StrReplaceAll(out, "é", "E");
        out = StrReplaceAll(out, "É", "E");
        out = StrReplaceAll(out, "í", "I");
        out = StrReplaceAll(out, "Í", "I");
        out = StrReplaceAll(out, "ó", "O");
        out = StrReplaceAll(out, "Ó", "O");
        out = StrReplaceAll(out, "ú", "U");
        out = StrReplaceAll(out, "Ú", "U");
        out = StrReplaceAll(out, "ü", "U");
        out = StrReplaceAll(out, "Ü", "U");
        out = StrReplaceAll(out, "ñ", "Ñ");
        return out;
    }

    private func RankName(rank: Int32) -> String {
        if rank >= 3 {
            return this.Up(this.T("GR-RankBoss"));
        }
        if rank == 2 {
            return this.Up(this.T("GR-RankLieutenant"));
        }
        return this.Up(this.T("GR-RankSoldier"));
    }

    protected cb func OnInitialize() -> Bool {
        this.m_data = GRMenuData.Get(this.GetPlayerControlledObject().GetGame());
        if IsDefined(this.m_data) && this.m_data.ConsumeBountyMode() {
            this.m_bounty = true;
            this.InitBounty();
            super.OnInitialize();
            this.BringToFront();
            return true;
        }
        this.m_page = IsDefined(this.m_data) ? this.m_data.GetPage() : 0;
        this.m_arsenalPage = IsDefined(this.m_data) ? this.m_data.GetArsenalPage() : 0;
        this.m_rewards = GRRewards.Get(this.GetPlayerControlledObject().GetGame());
        this.m_bounties = GRBounties.Get(this.GetPlayerControlledObject().GetGame());
        this.m_selWeapon = -1;
        let pending: Int32 = IsDefined(this.m_data) ? this.m_data.ConsumePendingView() : -1;
        if pending >= 0 && pending <= 2 {
            this.m_view = pending;
            GRLog("Menu: vista pedida por API consumida -> " + IntToString(pending) + " (0 bandas, 1 territorio, 2 arsenal)");
        }
        let root: ref<inkCompoundWidget> = this.GetRootCompoundWidget();

        this.CreateBackground(root);
        this.CreateHeader(root, "GR-MenuTitle", "GR-BountyTitle", n"gangretaliation_bounty_menu");
        this.CreateRankLabels(root);

        let tree: ref<inkCanvas> = new inkCanvas();
        tree.SetName(n"tree");
        tree.SetAnchor(inkEAnchor.Fill);
        tree.Reparent(root);
        this.m_tree = tree;

        this.CreateDetail(root, true);
        this.CreateTerritory(root);
        this.CreateArsenal(root);
        this.CreateViewSwitch(root);
        this.CreateFusion(root);
        this.CreateHints(root);

        this.RegisterToGlobalInputCallback(n"OnPostOnRelease", this, n"OnGRGlobalInput");
        this.Refresh();
        super.OnInitialize();
        this.BringToFront();
    }

    private func CreateHints(root: ref<inkCompoundWidget>) {
        let hints: ref<inkCanvas> = new inkCanvas();
        hints.SetName(n"button_hints");
        hints.SetAnchor(inkEAnchor.BottomRight);
        hints.SetAnchorPoint(new Vector2(1.0, 1.0));
        hints.SetMargin(new inkMargin(0.0, 0.0, 100.0, 50.0));
        hints.Reparent(root);
        this.m_buttonHints = this.SpawnFromExternal(hints, r"base\\gameplay\\gui\\common\\buttonhints.inkwidget", n"Root").GetController() as ButtonHints;
        if IsDefined(this.m_buttonHints) {
            this.m_buttonHints.AddButtonHint(n"back", "Common-Access-Close");
            this.m_buttonHints.AddButtonHint(n"sort_list", this.T("GR-MenuHintView"));
        }
    }

    protected cb func OnUninitialize() -> Bool {
        this.UnregisterFromGlobalInputCallback(n"OnPostOnRelease", this, n"OnGRGlobalInput");
        if IsDefined(this.m_data) && !this.m_bounty {
            this.m_data.SetPage(this.m_page);
            this.m_data.SetArsenalPage(this.m_arsenalPage);
        }
    }

    protected cb func OnSetMenuEventDispatcher(menuEventDispatcher: wref<inkMenuEventDispatcher>) -> Bool {
        super.OnSetMenuEventDispatcher(menuEventDispatcher);
        this.m_grDispatcher = menuEventDispatcher;
        return true;
    }

    private func CreateBackground(root: ref<inkCompoundWidget>) {
        let background: ref<inkRectangle> = new inkRectangle();
        background.SetName(n"background");
        background.SetAnchor(inkEAnchor.Fill);
        background.SetMargin(new inkMargin(0.0, 150.0, 0.0, 0.0));
        background.SetTintColor(this.Dark());
        background.SetOpacity(0.35);
        background.Reparent(root);

        let vignette: ref<inkImage> = new inkImage();
        vignette.SetName(n"vignette");
        vignette.SetAtlasResource(r"base\\gameplay\\gui\\widgets\\notifications\\vignette.inkatlas");
        vignette.SetTexturePart(n"vignette_1");
        vignette.SetNineSliceScale(true);
        vignette.SetAnchor(inkEAnchor.Fill);
        vignette.SetTintColor(this.Red());
        vignette.SetMargin(new inkMargin(0.0, 150.0, 0.0, 0.0));
        vignette.SetOpacity(0.2);
        vignette.Reparent(root);
    }

    private func NewText(text: String, size: Int32, color: HDRColor, style: CName) -> ref<inkText> {
        let label: ref<inkText> = new inkText();
        label.SetText(text);
        label.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        label.SetFontStyle(style);
        label.SetFontSize(size);
        label.SetTintColor(color);
        return label;
    }

    private func NewWrappedText(text: String, size: Int32, color: HDRColor, width: Float) -> ref<inkText> {
        let label: ref<inkText> = this.NewText(text, size, color, n"Regular");
        label.SetWrapping(true, width);
        return label;
    }

    private func NewRect(width: Float, height: Float, color: HDRColor, opacity: Float) -> ref<inkRectangle> {
        let rect: ref<inkRectangle> = new inkRectangle();
        rect.SetSize(new Vector2(width, height));
        rect.SetTintColor(color);
        rect.SetOpacity(opacity);
        return rect;
    }

    // A vertical draggable scrollbar track + grip, line-for-line the same construction as Gang Retaliation
    // History's own working vertical bar (GangRetaliationHistory/History.reds:NewBar, sideways=false,
    // confirmed in game): a thin AddFill track *as a child of `bar`* behind a cyan-while-held grip, with
    // the inkSliderController handed to the inkScrollController via VerticalScrollBarRef for fully
    // automatic two-way sync - no manual OnScrollChanged/OnSliderValueChanged callbacks. Earlier sessions
    // tried this exact shape once before and saw it get worse, but that attempt still had the old manual
    // sync callbacks (OnGRDetailScrolled/OnGRDetailDragged) registered on top of it - two sync mechanisms
    // fighting each other, not a real difference from History. Those callbacks are gone now.
    private func NewBar(parent: ref<inkCompoundWidget>, x: Float, y: Float, w: Float, h: Float) -> ref<inkCanvas> {
        let bar: ref<inkCanvas> = new inkCanvas();
        bar.SetAnchor(inkEAnchor.TopLeft);
        bar.SetMargin(new inkMargin(x, y, 0.0, 0.0));
        bar.SetSize(new Vector2(w, h));
        bar.SetInteractive(true);
        bar.Reparent(parent);

        let track: ref<inkCanvas> = new inkCanvas();
        track.SetAnchor(inkEAnchor.Fill);
        track.Reparent(bar);
        this.AddFill(track, this.DarkRed(), 0.5);

        let grip: ref<inkRectangle> = new inkRectangle();
        grip.SetAnchor(inkEAnchor.TopFillHorizontaly);
        grip.SetSize(new Vector2(w, 120.0));
        grip.SetTintColor(this.Red());
        grip.SetInteractive(true);
        grip.Reparent(bar);
        grip.RegisterToCallback(n"OnPress", this, n"OnGRDetailGripPress");
        grip.RegisterToCallback(n"OnRelease", this, n"OnGRDetailGripRelease");
        this.m_detailGrip = grip;

        let drag: ref<inkSliderController> = new inkSliderController();
        drag.slidingAreaRef = inkWidgetRef.Create(bar);
        drag.handleRef = inkWidgetRef.Create(grip);
        drag.direction = inkESliderDirection.Vertical;
        drag.autoSizeHandle = true;
        drag.Setup(0.0, 1.0, 0.0);
        bar.AttachController(drag);
        this.m_detailDrag = drag;
        return bar;
    }

    protected cb func OnGRDetailGripPress(evt: ref<inkPointerEvent>) -> Bool {
        if evt.IsAction(n"click") && IsDefined(this.m_detailGrip) {
            this.m_detailGrip.SetTintColor(this.Cyan());
        }
        return false;
    }

    protected cb func OnGRDetailGripRelease(evt: ref<inkPointerEvent>) -> Bool {
        if IsDefined(this.m_detailGrip) {
            this.m_detailGrip.SetTintColor(this.Red());
        }
        return false;
    }

    private func AddBorder(parent: ref<inkCompoundWidget>, color: HDRColor, thickness: Float, opacity: Float) {
        let border: ref<GRBorder> = new GRBorder();
        border.SetAnchor(inkEAnchor.Fill);
        border.SetThickness(thickness);
        border.SetTintColor(color);
        border.SetOpacity(opacity);
        border.Reparent(parent);
    }

    private func AddFill(parent: ref<inkCompoundWidget>, color: HDRColor, opacity: Float) {
        let bg: ref<inkRectangle> = new inkRectangle();
        bg.SetAnchor(inkEAnchor.Fill);
        bg.SetTintColor(color);
        bg.SetOpacity(opacity);
        bg.Reparent(parent);
    }

    private func AddFullLine(root: ref<inkCompoundWidget>, top: Float) {
        let line: ref<inkRectangle> = new inkRectangle();
        line.SetAnchor(inkEAnchor.TopFillHorizontaly);
        line.SetMargin(new inkMargin(0.0, top, 0.0, 0.0));
        line.SetHeight(3.0);
        line.SetTintColor(this.Red());
        line.SetOpacity(0.55);
        line.Reparent(root);
    }

    private func NewKeyIcon(part: CName) -> ref<inkImage> {
        let icon: ref<inkImage> = new inkImage();
        icon.SetAtlasResource(r"base\\gameplay\\gui\\common\\input\\icons_keyboard.inkatlas");
        icon.SetTexturePart(part);
        icon.SetSize(new Vector2(64.0, 64.0));
        icon.SetVAlign(inkEVerticalAlign.Center);
        icon.SetTintColor(this.Cyan());
        icon.SetInteractive(true);
        return icon;
    }

    // navTitleKey/navTarget let the screen's own title button open the OTHER top-level GangRetaliation
    // menu scenario (NEMESES <-> BOUNTY BOARD) - a chamfered tile matching the Information tab's look,
    // right of the title text itself rather than hanging off the bottom of the view switcher.
    private func CreateHeader(root: ref<inkCompoundWidget>, titleKey: String, opt navTitleKey: String, opt navTarget: CName) {
        this.AddFullLine(root, 150.0);
        this.AddFullLine(root, 336.0);

        let titleRow: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        titleRow.SetAnchor(inkEAnchor.TopLeft);
        titleRow.SetMargin(new inkMargin(120.0, 168.0, 0.0, 0.0));
        titleRow.SetFitToContent(true);
        titleRow.Reparent(root);

        let title: ref<inkText> = this.NewText(this.Up(this.T(titleKey)), 64, this.Red(), n"Medium");
        title.Reparent(titleRow);

        if StrLen(navTitleKey) > 0 {
            let navBtn: ref<inkCanvas> = new inkCanvas();
            navBtn.SetName(n"gr_header_nav");
            navBtn.SetSize(new Vector2(320.0, 56.0));
            navBtn.SetMargin(new inkMargin(40.0, 0.0, 0.0, 0.0));
            navBtn.SetVAlign(inkEVerticalAlign.Center);
            navBtn.SetInteractive(true);
            navBtn.RegisterToCallback(n"OnRelease", this, n"OnGRHeaderNavClick");
            navBtn.Reparent(titleRow);
            this.m_headerNavTarget = navTarget;

            let navBg: ref<inkImage> = new inkImage();
            navBg.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
            navBg.SetTexturePart(n"cell_bg");
            navBg.SetNineSliceScale(true);
            navBg.SetAnchor(inkEAnchor.Fill);
            navBg.SetTintColor(this.Dark());
            navBg.SetOpacity(0.95);
            navBg.Reparent(navBtn);

            let navFrame: ref<inkImage> = new inkImage();
            navFrame.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
            navFrame.SetTexturePart(n"cell_fg");
            navFrame.SetNineSliceScale(true);
            navFrame.SetAnchor(inkEAnchor.Fill);
            navFrame.SetTintColor(this.Gold());
            navFrame.Reparent(navBtn);

            let navText: ref<inkText> = this.NewText(this.Up(this.T(navTitleKey)), 28, this.Gold(), n"Bold");
            navText.SetAnchor(inkEAnchor.Centered);
            navText.SetAnchorPoint(new Vector2(0.5, 0.5));
            navText.Reparent(navBtn);
        }

        let summary: ref<inkText> = this.NewText("", 40, this.Gold(), n"Medium");
        summary.SetAnchor(inkEAnchor.TopRight);
        summary.SetAnchorPoint(new Vector2(1.0, 0.0));
        summary.SetMargin(new inkMargin(0.0, 272.0, 120.0, 0.0));
        summary.Reparent(root);
        this.m_summary = summary;

        let header: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        header.SetName(n"gang_switch");
        header.SetAnchor(inkEAnchor.TopCenter);
        header.SetAnchorPoint(new Vector2(0.5, 0.0));
        header.SetMargin(new inkMargin(0.0, 168.0, 0.0, 0.0));
        header.SetFitToContent(true);
        header.SetChildMargin(new inkMargin(40.0, 0.0, 40.0, 0.0));
        header.Reparent(root);
        this.m_gangSwitch = header;

        let left: ref<inkImage> = this.NewKeyIcon(n"kb_a");
        left.Reparent(header);
        left.RegisterToCallback(n"OnRelease", this, n"OnGRPrevClick");

        let gangTitle: ref<inkText> = this.NewText("", 72, this.Cyan(), n"Medium");
        gangTitle.SetVAlign(inkEVerticalAlign.Center);
        gangTitle.Reparent(header);
        this.m_gangTitle = gangTitle;

        let gangCount: ref<inkText> = this.NewText("", 72, this.Cyan(), n"Bold");
        gangCount.SetVAlign(inkEVerticalAlign.Center);
        gangCount.Reparent(header);
        this.m_gangCount = gangCount;

        let right: ref<inkImage> = this.NewKeyIcon(n"kb_d");
        right.Reparent(header);
        right.RegisterToCallback(n"OnRelease", this, n"OnGRNextClick");

        let marks: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        marks.SetName(n"gang_tabs");
        marks.SetAnchor(inkEAnchor.TopCenter);
        marks.SetAnchorPoint(new Vector2(0.5, 0.0));
        marks.SetMargin(new inkMargin(0.0, 266.0, 0.0, 0.0));
        marks.SetFitToContent(true);
        marks.SetChildMargin(new inkMargin(6.0, 0.0, 6.0, 0.0));
        marks.Reparent(root);
        this.m_marks = marks;
    }

    private func CreateRankLabels(root: ref<inkCompoundWidget>) {
        let keys: array<String> = ["GR-MenuBoss", "GR-MenuLieutenants", "GR-MenuSoldiers"];
        let i: Int32 = 0;
        while i < 3 {
            let label: ref<inkText> = this.NewText(this.Up(this.T(keys[i])), 34, this.Light(), n"Medium");
            label.SetAnchor(inkEAnchor.TopLeft);
            label.SetAnchorPoint(new Vector2(0.0, 0.5));
            label.SetMargin(new inkMargin(120.0, this.TierY(3 - i), 0.0, 0.0));
            label.Reparent(root);
            ArrayPush(this.m_rankLabels, label);
            i += 1;
        }
    }

    // withTabs: the Nemeses screen's own GANGS detail panel gets the Information/History/Gang History
    // sub-tabs and the "Current Day" readout; the Bounty board reuses this same canvas (InitBounty) for
    // its own, unrelated contract detail and must NOT get them, so it calls this with the default (false).
    private func CreateDetail(root: ref<inkCompoundWidget>, opt withTabs: Bool) {
        let detail: ref<inkCanvas> = new inkCanvas();
        detail.SetName(n"detail");
        detail.SetAnchor(inkEAnchor.TopLeft);
        detail.SetMargin(new inkMargin(2720.0, 400.0, 0.0, 0.0));
        detail.SetSize(new Vector2(1000.0, 1520.0));
        detail.Reparent(root);
        this.m_detail = detail;

        this.AddFill(detail, this.Panel(), 0.95);
        this.AddBorder(detail, this.Red(), 2.0, 0.45);

        // Shared chrome for all 3 sub-tabs: Information/History/Gang History as bordered button tiles across
        // the top (same bordered-tile look as the game's own category-selector rows), eating into the
        // header's usual top margin so the box reads as shorter than before. The "Current Day" readout is
        // NOT part of the box - it lives on the screen itself, Cyan, top-right corner, directly above the
        // existing Gold summary line from CreateHeader (this.m_summary), matching where
        // GangRetaliationHistory's original standalone screen drew it.
        let topOffset: Float = 0.0;
        if withTabs {
            topOffset = 92.0;
            let tabRow: ref<inkCanvas> = new inkCanvas();
            tabRow.SetAnchor(inkEAnchor.TopLeft);
            tabRow.SetMargin(new inkMargin(56.0, 24.0, 0.0, 0.0));
            tabRow.SetSize(new Vector2(888.0, 56.0));
            tabRow.Reparent(detail);

            let day: ref<inkText> = this.NewText("", 48, this.Cyan(), n"Bold");
            day.SetAnchor(inkEAnchor.TopRight);
            day.SetAnchorPoint(new Vector2(1.0, 0.0));
            day.SetMargin(new inkMargin(0.0, 184.0, 120.0, 0.0));
            day.Reparent(root);
            this.m_detailDay = day;

            // Active-bounty badge for the Information/History sub-tabs (their headers match: rank | gang,
            // name, title) - hidden on Gang History, which has no single Nemesis to badge. Top aligned
            // with the rank|gang line (header's own margin-top below, 52 + topOffset = 144) rather than
            // the tab row above it. Reuses the exact icon GRBountyZoneMappinData.IconPart() puts on the
            // Bounty Board's own search-zone mappin ("bounty_hunt" - the vanilla Phantom Liberty wanted-
            // poster look), on its own atlas rather than the shapes one everything else here uses.
            // Clickable: opens the Bounty Board already focused on this Nemesis's contract (OpenGRMenu).
            let bountyIcon: ref<inkImage> = new inkImage();
            bountyIcon.SetAtlasResource(r"base\\gameplay\\gui\\common\\icons\\mappin_icons.inkatlas");
            bountyIcon.SetTexturePart(n"bounty_hunt");
            bountyIcon.SetAnchor(inkEAnchor.TopRight);
            bountyIcon.SetAnchorPoint(new Vector2(1.0, 0.0));
            bountyIcon.SetMargin(new inkMargin(0.0, 144.0, 16.0, 0.0));
            bountyIcon.SetSize(new Vector2(88.0, 88.0));
            bountyIcon.SetTintColor(this.Gold());
            bountyIcon.SetVisible(false);
            bountyIcon.SetInteractive(true);
            bountyIcon.RegisterToCallback(n"OnRelease", this, n"OnGRBountyBadgeClick");
            bountyIcon.Reparent(detail);
            this.m_detailBountyIcon = bountyIcon;
            this.m_detailBountyNemesisId = -1;

            let names: array<String>;
            ArrayPush(names, StrUpper(this.T("GR-DetailTabInfo")));
            ArrayPush(names, StrUpper(this.T("GR-DetailTabHistory")));
            ArrayPush(names, StrUpper(this.T("GR-DetailTabGangHistory")));
            let tabW: Float = 288.0;
            let tabGap: Float = 12.0;
            let x: Float = 0.0;
            let i: Int32 = 0;
            while i < 3 {
                let tab: ref<inkCanvas> = new inkCanvas();
                tab.SetName(StringToName("gr_detail_tab_" + IntToString(i)));
                tab.SetAnchor(inkEAnchor.TopLeft);
                tab.SetMargin(new inkMargin(x, 0.0, 0.0, 0.0));
                tab.SetSize(new Vector2(tabW, 56.0));
                tab.SetInteractive(true);
                tab.RegisterToCallback(n"OnRelease", this, n"OnGRDetailTabClick");
                tab.Reparent(tabRow);

                // Same chamfered cell_bg/cell_fg vanilla shapes AddCard uses for its own cards/selection
                // frame, so these read as the game's own cut-corner tiles instead of plain rectangles.
                let bg: ref<inkImage> = new inkImage();
                bg.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
                bg.SetTexturePart(n"cell_bg");
                bg.SetNineSliceScale(true);
                bg.SetAnchor(inkEAnchor.Fill);
                bg.SetTintColor(this.Dark());
                bg.SetOpacity(0.95);
                bg.Reparent(tab);

                let border: ref<inkImage> = new inkImage();
                border.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
                border.SetTexturePart(n"cell_fg");
                border.SetNineSliceScale(true);
                border.SetAnchor(inkEAnchor.Fill);
                border.SetTintColor(i == 0 ? this.Cyan() : this.DarkRed());
                border.SetOpacity(i == 0 ? 1.0 : 0.55);
                border.Reparent(tab);
                ArrayPush(this.m_detailTabBorders, border);

                let text: ref<inkText> = this.NewText(names[i], 24, i == 0 ? this.Cyan() : this.Grey(), n"Bold");
                text.SetAnchor(inkEAnchor.Centered);
                text.SetAnchorPoint(new Vector2(0.5, 0.5));
                text.Reparent(tab);
                ArrayPush(this.m_detailTabTexts, text);

                x += tabW + tabGap;
                i += 1;
            }
        }

        // Fixed, non-scrolling header: rank/gang line, name, title. Everything below it (contact tag
        // through Origin) scrolls instead of spilling past the card's bottom edge - contentHeight is a
        // fixed estimate of the header's own height (rank line + a single-line name + title; names in
        // the generator stay well under half this column's width, so 2-line wrapping isn't a real
        // concern here). A thin rule marks the header/scroll boundary, with an equal gap above and below
        // it so it sits centered in the space rather than hugging either side.
        let header: ref<inkVerticalPanel> = new inkVerticalPanel();
        header.SetAnchor(inkEAnchor.TopLeft);
        header.SetMargin(new inkMargin(56.0, 52.0 + topOffset, 0.0, 0.0));
        header.Reparent(detail);
        this.m_detailHeader = header;

        let contentHeight: Float = 162.0;
        let gap: Float = 20.0;
        let dividerY: Float = 52.0 + topOffset + contentHeight + gap;
        let headerHeight: Float = dividerY + 2.0 + gap - 52.0 - topOffset;
        let divider: ref<inkRectangle> = this.NewRect(888.0, 2.0, this.Dim(), 1.0);
        divider.SetAnchor(inkEAnchor.TopLeft);
        divider.SetMargin(new inkMargin(56.0, dividerY, 0.0, 0.0));
        divider.Reparent(detail);
        // host is wider than the 888px text column on purpose, reaching into the card's existing 56px
        // right inset - scroll reserves the rightmost 40px of that for the bar (same split
        // GangRetaliationHistory/History.reds's own working vertical bar uses), and every text widget
        // still wraps to its own explicit 888px width regardless of host's width. The bar itself is a
        // CHILD of host, not a sibling positioned on `detail` - that was the actual bug in the first two
        // attempts here: parented outside host, the slider's handle drifted out of the track while
        // scrolling/dragging even with autoSizeHandle corrected, and matching History's structure exactly
        // (bar inside the same canvas the scroll area lives in) is what fixed it.
        let hostHeight: Float = 1520.0 - 52.0 - topOffset - headerHeight - 52.0;
        let host: ref<inkCanvas> = new inkCanvas();
        host.SetAnchor(inkEAnchor.TopLeft);
        host.SetMargin(new inkMargin(56.0, 52.0 + topOffset + headerHeight, 0.0, 0.0));
        host.SetSize(new Vector2(928.0, hostHeight));
        host.SetInteractive(true);
        host.Reparent(detail);

        let scroll: ref<inkScrollArea> = new inkScrollArea();
        scroll.SetAnchor(inkEAnchor.Fill);
        scroll.SetMargin(new inkMargin(0.0, 0.0, 40.0, 0.0));
        scroll.SetUseInternalMask(true);
        scroll.SetConstrainContentPosition(true);
        scroll.Reparent(host);

        let bar: ref<inkCanvas> = this.NewBar(host, 914.0, 0.0, 10.0, hostHeight);

        let scroller: ref<inkScrollController> = new inkScrollController();
        scroller.ScrollArea = inkScrollAreaRef.Create(scroll);
        scroller.VerticalScrollBarRef = inkWidgetRef.Create(bar);
        scroller.direction = inkEScrollDirection.Vertical;
        scroller.scrollSpeedMouse = 90.0;
        scroller.scrollSpeedGamepad = 90.0;
        // false, not true: with useGlobalInput on, this controller reacts to the mouse wheel no matter
        // where the cursor is, so it and the fallen-row scroll below both moved together on any wheel
        // input. false scopes wheel input to whichever scroll area is actually hovered, same as any
        // normal scroll box.
        scroller.useGlobalInput = false;
        host.AttachController(scroller);
        this.m_detailScroller = scroller;

        let content: ref<inkVerticalPanel> = new inkVerticalPanel();
        content.SetFitToContent(true);
        content.SetHAlign(inkEHorizontalAlign.Fill);
        content.Reparent(scroll);
        this.m_detailContent = content;
    }

    private func TierY(rank: Int32) -> Float {
        if rank == 3 {
            return 590.0;
        }
        if rank == 2 {
            return 1010.0;
        }
        return 1420.0;
    }

    private func CenterX() -> Float {
        return 1480.0;
    }

    private func Connect(px: Float, py: Float, cx: Float, cy: Float, color: HDRColor) {
        ArrayPush(this.m_pathStart, ArraySize(this.m_pathPoints));
        ArrayPush(this.m_pathColor, color);
        let chamfer: Float = 36.0;
        let mid: Float = (py + cy) / 2.0;
        let dx: Float = cx - px;
        ArrayPush(this.m_pathPoints, new Vector2(px, py));
        if AbsF(dx) < chamfer * 2.0 + 1.0 {
            ArrayPush(this.m_pathPoints, new Vector2(px, mid));
            ArrayPush(this.m_pathPoints, new Vector2(cx, mid));
        } else {
            let dir: Float = dx > 0.0 ? 1.0 : -1.0;
            ArrayPush(this.m_pathPoints, new Vector2(px, mid - chamfer));
            ArrayPush(this.m_pathPoints, new Vector2(px + dir * chamfer, mid));
            ArrayPush(this.m_pathPoints, new Vector2(cx - dir * chamfer, mid));
            ArrayPush(this.m_pathPoints, new Vector2(cx, mid + chamfer));
        }
        ArrayPush(this.m_pathPoints, new Vector2(cx, cy));
    }

    private func DrawStroke(x1: Float, y1: Float, x2: Float, y2: Float, width: Float, color: HDRColor, opacity: Float) {
        let rect: ref<inkRectangle> = new inkRectangle();
        rect.SetAnchor(inkEAnchor.TopLeft);
        rect.SetTintColor(color);
        rect.SetOpacity(opacity);
        let dx: Float = x2 - x1;
        let dy: Float = y2 - y1;
        if AbsF(dx) < 0.5 || AbsF(dy) < 0.5 {
            rect.SetMargin(new inkMargin(MinF(x1, x2) - width / 2.0, MinF(y1, y2) - width / 2.0, 0.0, 0.0));
            rect.SetSize(new Vector2(AbsF(dx) + width, AbsF(dy) + width));
        } else {
            let length: Float = AbsF(dx) * 1.41421356 + width * 0.42;
            rect.SetSize(new Vector2(length, width));
            rect.SetMargin(new inkMargin((x1 + x2) / 2.0 - length / 2.0, (y1 + y2) / 2.0 - width / 2.0, 0.0, 0.0));
            rect.SetRenderTransformPivot(new Vector2(0.5, 0.5));
            rect.SetRotation(dx * dy > 0.0 ? 45.0 : -45.0);
        }
        rect.Reparent(this.m_links);
    }

    private func OffsetPath(points: array<Vector2>, offset: Float) -> array<Vector2> {
        let result: array<Vector2>;
        let n: Int32 = ArraySize(points);
        let i: Int32 = 0;
        while i < n {
            let nx: Float = 0.0;
            let ny: Float = 0.0;
            let firstX: Float = 0.0;
            let firstY: Float = 0.0;
            let haveFirst: Bool = false;
            if i > 0 {
                let dx: Float = points[i].X - points[i - 1].X;
                let dy: Float = points[i].Y - points[i - 1].Y;
                let len: Float = SqrtF(dx * dx + dy * dy);
                firstX = -dy / len;
                firstY = dx / len;
                haveFirst = true;
                nx += firstX;
                ny += firstY;
            }
            if i < n - 1 {
                let dx2: Float = points[i + 1].X - points[i].X;
                let dy2: Float = points[i + 1].Y - points[i].Y;
                let len2: Float = SqrtF(dx2 * dx2 + dy2 * dy2);
                if !haveFirst {
                    firstX = -dy2 / len2;
                    firstY = dx2 / len2;
                }
                nx += -dy2 / len2;
                ny += dx2 / len2;
            }
            let mlen: Float = SqrtF(nx * nx + ny * ny);
            let mx: Float = nx / mlen;
            let my: Float = ny / mlen;
            let scale: Float = offset / (mx * firstX + my * firstY);
            ArrayPush(result, new Vector2(points[i].X + mx * scale, points[i].Y + my * scale));
            i += 1;
        }
        return result;
    }

    private func DrawPolyline(points: array<Vector2>, width: Float, color: HDRColor, opacity: Float) {
        let i: Int32 = 1;
        while i < ArraySize(points) {
            this.DrawStroke(points[i - 1].X, points[i - 1].Y, points[i].X, points[i].Y, width, color, opacity);
            i += 1;
        }
    }

    private func DrawLinks() {
        let count: Int32 = ArraySize(this.m_pathStart);
        let offsets: array<Float> = [-13.0, 0.0, 13.0];
        let pass: Int32 = 0;
        while pass < 2 {
            let p: Int32 = 0;
            while p < count {
                let first: Int32 = this.m_pathStart[p];
                let last: Int32 = p + 1 < count ? this.m_pathStart[p + 1] : ArraySize(this.m_pathPoints);
                let points: array<Vector2>;
                let i: Int32 = first;
                while i < last {
                    ArrayPush(points, this.m_pathPoints[i]);
                    i += 1;
                }
                for offset in offsets {
                    let line: array<Vector2> = this.OffsetPath(points, offset);
                    if pass == 0 {
                        this.DrawPolyline(line, 10.0, this.m_pathColor[p], 0.22);
                    } else {
                        this.DrawPolyline(line, 4.0, this.m_pathColor[p], 1.0);
                    }
                }
                p += 1;
            }
            pass += 1;
        }
    }

    private func NewTag(text: String, size: Int32, color: HDRColor) -> ref<inkCompoundWidget> {
        let fontSize: Float = Cast<Float>(size);
        let tag: ref<inkCanvas> = new inkCanvas();
        tag.SetSize(new Vector2(Cast<Float>(StrLen(text)) * fontSize * 0.56 + 24.0, fontSize + 12.0));
        tag.SetVAlign(inkEVerticalAlign.Center);
        this.AddBorder(tag, color, 2.0, 1.0);
        let label: ref<inkText> = this.NewText(text, size, color, n"Bold");
        label.SetAnchor(inkEAnchor.CenterLeft);
        label.SetAnchorPoint(new Vector2(0.0, 0.5));
        label.SetMargin(new inkMargin(12.0, 0.0, 0.0, 0.0));
        label.Reparent(tag);
        return tag;
    }

    private func NewRenownBar(renown: Int32, color: HDRColor, width: Float, height: Float, gap: Float) -> ref<inkHorizontalPanel> {
        let bar: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        let pip: Float = (width - gap * 9.0) / 10.0;
        let i: Int32 = 0;
        while i < 10 {
            let segment: ref<inkRectangle> = this.NewRect(pip, height, i < renown ? color : this.Empty(), 1.0);
            segment.SetMargin(new inkMargin(0.0, 0.0, i < 9 ? gap : 0.0, 0.0));
            segment.Reparent(bar);
            i += 1;
        }
        return bar;
    }

    private func TraitLines(entry: ref<GRMenuEntry>) -> array<String> {
        if StrLen(entry.traits) == 0 {
            let none: array<String>;
            return none;
        }
        return StrSplit(entry.traits, "\n");
    }

    private func TraitColor(sign: String) -> HDRColor {
        if Equals(sign, "+") {
            return this.Cyan();
        }
        if Equals(sign, "-") {
            return this.Red();
        }
        return this.Grey();
    }

    private func AddCard(entry: ref<GRMenuEntry>, x: Float, y: Float, w: Float, h: Float, small: Bool, selected: Bool) {
        let index: Int32 = ArraySize(this.m_cards);
        ArrayPush(this.m_cards, entry);
        let rankColor: HDRColor = this.RankColor(entry.rank);

        let card: ref<inkCanvas> = new inkCanvas();
        card.SetName(StringToName("gr_card_" + IntToString(index)));
        card.SetAnchor(inkEAnchor.TopLeft);
        card.SetMargin(new inkMargin(x - w / 2.0, y - h / 2.0, 0.0, 0.0));
        card.SetSize(new Vector2(w, h));
        card.SetInteractive(true);
        card.RegisterToCallback(n"OnRelease", this, n"OnGRCardClick");
        card.Reparent(this.m_tree);

        // Selection highlight: the same chamfered cell_fg shape as the normal frame below, just enlarged a
        // few px past the card's own edges so it reads as a thicker cyan outline peeking out around it -
        // a plain rectangular GRBorder was tried first and looked wrong against this card's cut corner.
        let selFrame: ref<inkImage> = new inkImage();
        selFrame.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
        selFrame.SetTexturePart(n"cell_fg");
        selFrame.SetNineSliceScale(true);
        selFrame.SetAnchor(inkEAnchor.Fill);
        selFrame.SetMargin(new inkMargin(-3.0, -3.0, -3.0, -3.0));
        selFrame.SetTintColor(this.Cyan());
        selFrame.SetOpacity(selected ? 1.0 : 0.0);
        selFrame.Reparent(card);
        ArrayPush(this.m_cardSelFrames, selFrame);

        let bg: ref<inkImage> = new inkImage();
        bg.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
        bg.SetTexturePart(n"cell_bg");
        bg.SetNineSliceScale(true);
        bg.SetAnchor(inkEAnchor.Fill);
        bg.SetTintColor(this.Dark());
        bg.SetOpacity(0.95);
        bg.Reparent(card);

        let frame: ref<inkImage> = new inkImage();
        frame.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
        frame.SetTexturePart(n"cell_fg");
        frame.SetNineSliceScale(true);
        frame.SetAnchor(inkEAnchor.Fill);
        frame.Reparent(card);
        ArrayPush(this.m_cardFrames, frame);
        this.StyleFrame(frame, entry, selected);

        if IsDefined(this.m_bounties) && this.m_bounties.HasOpenBounty(entry.id) {
            // Same vanilla "wanted poster" icon the Bounty Board's own search-zone mappin uses
            // (GRBountyZoneMappinData.IconPart(), Rewards.reds) - see CreateDetail's Information-tab
            // badge for the matching one in the detail panel.
            let bountyIcon: ref<inkImage> = new inkImage();
            bountyIcon.SetAtlasResource(r"base\\gameplay\\gui\\common\\icons\\mappin_icons.inkatlas");
            bountyIcon.SetTexturePart(n"bounty_hunt");
            bountyIcon.SetAnchor(inkEAnchor.TopRight);
            bountyIcon.SetAnchorPoint(new Vector2(1.0, 0.0));
            bountyIcon.SetMargin(new inkMargin(0.0, small ? 10.0 : 14.0, small ? 10.0 : 14.0, 0.0));
            bountyIcon.SetSize(new Vector2(small ? 36.0 : 44.0, small ? 36.0 : 44.0));
            bountyIcon.SetTintColor(this.Gold());
            bountyIcon.Reparent(card);
        }

        let content: ref<inkVerticalPanel> = new inkVerticalPanel();
        content.SetAnchor(inkEAnchor.Fill);
        content.SetMargin(new inkMargin(30.0, 18.0, 30.0, 12.0));
        content.Reparent(card);

        let tags: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        tags.Reparent(content);
        let rank: ref<inkText> = this.NewText(this.RankName(entry.rank), 28, rankColor, n"Bold");
        rank.SetVAlign(inkEVerticalAlign.Center);
        rank.SetMargin(new inkMargin(0.0, 0.0, 16.0, 0.0));
        rank.Reparent(tags);
        let contact: ref<inkCompoundWidget> = this.NewTag(this.T(entry.known ? "GR-MenuKnown" : "GR-MenuUnknown"), 22, entry.known ? this.Red() : this.Grey());
        contact.Reparent(tags);

        let name: ref<inkText> = this.NewText(entry.name, small ? 40 : 48, rankColor, n"Bold");
        name.SetMargin(new inkMargin(0.0, 6.0, 0.0, 0.0));
        name.Reparent(content);
        if StrLen(entry.title) > 0 {
            let title: ref<inkText> = this.NewText("\"" + entry.title + "\"", 32, this.Light(), n"Regular");
            title.Reparent(content);
        }

        let bar: ref<inkHorizontalPanel> = this.NewRenownBar(entry.renown, rankColor, w - 60.0, 8.0, 6.0);
        bar.SetMargin(new inkMargin(0.0, 10.0, 0.0, 0.0));
        bar.Reparent(content);

        let chips: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        chips.SetMargin(new inkMargin(0.0, 10.0, 0.0, 0.0));
        chips.Reparent(content);
        let lines: array<String> = this.TraitLines(entry);
        let limit: Int32 = Min(ArraySize(lines), small ? 2 : 3);
        let i: Int32 = 0;
        while i < limit {
            let parts: array<String> = StrSplit(lines[i], "|");
            if ArraySize(parts) >= 2 {
                let prefix: String = Equals(parts[0], "?") ? "" : parts[0] + " ";
                let chip: ref<inkText> = this.NewText(prefix + parts[1], 28, this.TraitColor(parts[0]), n"Bold");
                chip.SetMargin(new inkMargin(0.0, 0.0, 22.0, 0.0));
                chip.Reparent(chips);
            }
            i += 1;
        }
    }

    private func StyleFrame(frame: wref<inkImage>, entry: ref<GRMenuEntry>, selected: Bool) {
        frame.SetTintColor(selected ? this.Cyan() : this.RankColor(entry.rank));
        frame.SetOpacity(selected || entry.known ? 1.0 : 0.55);
    }

    private func IsSelected(entry: ref<GRMenuEntry>) -> Bool {
        return Equals(entry.name, this.m_selName);
    }

    private func AddVacant(x: Float, y: Float, w: Float, h: Float, note: String) {
        let vacant: ref<inkCanvas> = new inkCanvas();
        vacant.SetAnchor(inkEAnchor.TopLeft);
        vacant.SetMargin(new inkMargin(x - w / 2.0, y - h / 2.0, 0.0, 0.0));
        vacant.SetSize(new Vector2(w, h));
        vacant.Reparent(this.m_tree);
        this.AddFill(vacant, this.Panel(), 0.8);
        this.AddBorder(vacant, this.Dim(), 3.0, 1.0);

        let content: ref<inkVerticalPanel> = new inkVerticalPanel();
        content.SetAnchor(inkEAnchor.Centered);
        content.SetAnchorPoint(new Vector2(0.5, 0.5));
        content.SetFitToContent(true);
        content.Reparent(vacant);
        let label: ref<inkText> = this.NewText(this.Up(this.T("GR-MenuVacant")), 44, this.Grey(), n"Medium");
        label.SetHAlign(inkEHorizontalAlign.Center);
        label.Reparent(content);
        let sub: ref<inkText> = this.NewText(StrLen(note) > 0 ? note : this.T("GR-MenuVacantWait"), 30, this.Grey(), n"Regular");
        sub.SetHAlign(inkEHorizontalAlign.Center);
        sub.Reparent(content);
    }

    private func Spread(count: Int32, index: Int32, left: Float, right: Float) -> Float {
        if count <= 1 {
            return (left + right) / 2.0;
        }
        return left + (right - left) * Cast<Float>(index) / Cast<Float>(count - 1);
    }

    private func AddTab(index: Int32) {
        let tab: ref<inkCanvas> = new inkCanvas();
        tab.SetName(StringToName("gr_tab_" + IntToString(index)));
        tab.SetSize(new Vector2(236.0, 60.0));
        tab.SetInteractive(true);
        tab.RegisterToCallback(n"OnRelease", this, n"OnGRTabClick");
        tab.Reparent(this.m_marks);

        let text: ref<inkText> = this.NewText("", 32, this.Grey(), n"Medium");
        text.SetAnchor(inkEAnchor.TopCenter);
        text.SetAnchorPoint(new Vector2(0.5, 0.0));
        text.Reparent(tab);
        ArrayPush(this.m_tabTexts, text);

        let bar: ref<inkRectangle> = this.NewRect(236.0, 4.0, this.DarkRed(), 1.0);
        bar.SetAnchor(inkEAnchor.BottomLeft);
        bar.SetAnchorPoint(new Vector2(0.0, 1.0));
        bar.Reparent(tab);
        ArrayPush(this.m_tabBars, bar);

        let mark: ref<inkRectangle> = this.NewRect(14.0, 14.0, this.Red(), 1.0);
        mark.SetAnchor(inkEAnchor.TopRight);
        mark.SetAnchorPoint(new Vector2(1.0, 0.0));
        mark.SetMargin(new inkMargin(0.0, 6.0, 8.0, 0.0));
        mark.SetRotation(45.0);
        mark.Reparent(tab);
        ArrayPush(this.m_tabThreats, mark);
    }

    private func StyleTab(index: Int32, label: String, active: Bool, threat: Bool) {
        this.m_tabTexts[index].SetText(this.Up(label));
        this.m_tabTexts[index].SetTintColor(active ? this.Cyan() : this.Grey());
        this.m_tabBars[index].SetSize(new Vector2(236.0, active ? 8.0 : 4.0));
        this.m_tabBars[index].SetTintColor(active ? this.Cyan() : this.DarkRed());
        this.m_tabThreats[index].SetVisible(threat);
    }

    private func AddFallen(fallen: array<ref<GRMenuEntry>>) {
        let block: ref<inkVerticalPanel> = new inkVerticalPanel();
        block.SetAnchor(inkEAnchor.TopLeft);
        block.SetMargin(new inkMargin(120.0, 1640.0, 0.0, 0.0));
        block.Reparent(this.m_tree);

        // Line length tracks the collapsed row's actual width (same 420-card/160-"+N" step math as below)
        // instead of a flat guess, so it reaches the end of the "+N" button when one is shown instead of
        // falling short of it.
        let collapsedCount: Int32 = Min(ArraySize(fallen), 5);
        let hasMore: Bool = ArraySize(fallen) > collapsedCount;
        let rowWidth: Float = ArraySize(fallen) == 0 ? 2200.0 : (Cast<Float>(collapsedCount) * 440.0 + (hasMore ? 180.0 : 0.0) - 20.0);

        let header: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        header.Reparent(block);
        let label: ref<inkText> = this.NewText(this.Up(this.T("GR-MenuFallen")), 34, this.Light(), n"Medium");
        label.SetVAlign(inkEVerticalAlign.Center);
        label.Reparent(header);
        let line: ref<inkRectangle> = this.NewRect(rowWidth, 2.0, this.Dim(), 1.0);
        line.SetVAlign(inkEVerticalAlign.Center);
        line.SetMargin(new inkMargin(28.0, 0.0, 0.0, 0.0));
        line.Reparent(header);

        ArrayClear(this.m_fallenCards);
        ArrayClear(this.m_fallenBorders);
        if ArraySize(fallen) == 0 {
            let none: ref<inkText> = this.NewText(this.T("GR-MenuNoFallen"), 34, this.Light(), n"Regular");
            none.SetMargin(new inkMargin(0.0, 20.0, 0.0, 0.0));
            none.Reparent(block);
            return;
        }

        let expanded: Bool = this.m_fallenExpanded && hasMore;

        if !expanded {
            let row: ref<inkHorizontalPanel> = new inkHorizontalPanel();
            row.SetMargin(new inkMargin(0.0, 20.0, 0.0, 0.0));
            row.Reparent(block);
            let i: Int32 = 0;
            while i < collapsedCount {
                this.AddFallenCard(row, fallen[i]);
                i += 1;
            }
            if ArraySize(fallen) > collapsedCount {
                this.AddFallenActionCard(row, "+" + IntToString(ArraySize(fallen) - collapsedCount), 40);
            }
            return;
        }

        // Expanded: every fallen nemesis, in a horizontally scrollable row, ending with a card to collapse
        // back. The scrollbar is always built, but only actually does anything once the row is wider than
        // the host - inkScrollArea clamps to nothing to scroll otherwise, so this covers "a scrollbar if
        // needed" without a separate branch. Card height is 190 (AddFallenCard); the scroll area is given
        // that much room plus a clear 20px gap before the bar sits below it, instead of right against it.
        let cardH: Float = 190.0;
        let barGap: Float = 20.0;
        let barH: Float = 8.0;
        let host: ref<inkCanvas> = new inkCanvas();
        host.SetAnchor(inkEAnchor.TopLeft);
        host.SetMargin(new inkMargin(0.0, 20.0, 0.0, 0.0));
        host.SetSize(new Vector2(2560.0, cardH + barGap + barH));
        host.SetInteractive(true);
        host.Reparent(block);

        let scroll: ref<inkScrollArea> = new inkScrollArea();
        scroll.SetAnchor(inkEAnchor.TopLeft);
        scroll.SetSize(new Vector2(2560.0, cardH));
        scroll.SetUseInternalMask(true);
        scroll.SetConstrainContentPosition(true);
        scroll.Reparent(host);

        let bar: ref<inkCanvas> = this.NewHBar(host, 0.0, cardH + barGap, 2560.0, barH);
        bar.RegisterToCallback(n"OnSliderValueChanged", this, n"OnGRFallenDragged");
        scroll.RegisterToCallback(n"OnScrollChanged", this, n"OnGRFallenScrolled");

        let scroller: ref<inkScrollController> = new inkScrollController();
        scroller.ScrollArea = inkScrollAreaRef.Create(scroll);
        scroller.direction = inkEScrollDirection.Horizontal;
        scroller.scrollSpeedMouse = 75.0;
        scroller.scrollSpeedGamepad = 75.0;
        scroller.useGlobalInput = false;  // see the detail panel's scroller above - scope wheel to hover
        host.AttachController(scroller);
        this.m_fallenScroller = scroller;

        let scrollRow: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        scrollRow.SetFitToContent(true);
        scrollRow.Reparent(scroll);
        let j: Int32 = 0;
        while j < ArraySize(fallen) {
            this.AddFallenCard(scrollRow, fallen[j]);
            j += 1;
        }
        this.AddFallenActionCard(scrollRow, "<", 48);
    }

    // A bordered/filled card matching AddFallenCard's look (so it reads as another button in the row, not
    // plain text) but narrower, holding just centered text - used for both the "+N" expand button and the
    // "<" collapse button at the end of the expanded row.
    private func AddFallenActionCard(parent: ref<inkCompoundWidget>, label: String, size: Int32) {
        let card: ref<inkCanvas> = new inkCanvas();
        card.SetSize(new Vector2(160.0, 190.0));
        card.SetMargin(new inkMargin(0.0, 0.0, 20.0, 0.0));
        card.SetInteractive(true);
        card.RegisterToCallback(n"OnRelease", this, n"OnGRFallenMoreClick");
        card.Reparent(parent);
        this.AddFill(card, this.Panel(), 0.95);
        this.AddBorder(card, this.Dim(), 2.0, 1.0);

        let text: ref<inkText> = this.NewText(label, size, this.Grey(), n"Bold");
        text.SetAnchor(inkEAnchor.Centered);
        text.SetAnchorPoint(new Vector2(0.5, 0.5));
        text.Reparent(card);
    }

    // One fallen-nemesis card, shared by the collapsed row and the expanded scrollable row. Clicking it
    // opens the same side detail panel a living nemesis card does (FillDetail/OnGRCardClick's pattern),
    // resolved through m_fallenCards by name instead of m_cards so the two click handlers never collide.
    private func AddFallenCard(parent: ref<inkCompoundWidget>, entry: ref<GRMenuEntry>) {
        let index: Int32 = ArraySize(this.m_fallenCards);
        ArrayPush(this.m_fallenCards, entry);

        let card: ref<inkCanvas> = new inkCanvas();
        card.SetName(StringToName("gr_fallen_" + IntToString(index)));
        card.SetSize(new Vector2(420.0, 190.0));
        card.SetMargin(new inkMargin(0.0, 0.0, 20.0, 0.0));
        card.SetInteractive(true);
        card.RegisterToCallback(n"OnRelease", this, n"OnGRFallenClick");
        card.Reparent(parent);
        this.AddFill(card, this.Panel(), 0.95);
        this.AddBorder(card, this.Dim(), 2.0, 1.0);

        let selBorder: ref<GRBorder> = new GRBorder();
        selBorder.SetAnchor(inkEAnchor.Fill);
        selBorder.SetThickness(3.0);
        selBorder.SetTintColor(this.Cyan());
        selBorder.SetOpacity(this.IsSelected(entry) ? 1.0 : 0.0);
        selBorder.Reparent(card);
        ArrayPush(this.m_fallenBorders, selBorder);

        let content: ref<inkVerticalPanel> = new inkVerticalPanel();
        content.SetAnchor(inkEAnchor.Fill);
        content.SetMargin(new inkMargin(24.0, 14.0, 16.0, 10.0));
        content.Reparent(card);
        let name: ref<inkText> = this.NewWrappedText(entry.name, 38, this.Light(), 380.0);
        name.SetFontStyle(n"Bold");
        name.SetOpacity(0.7);
        name.Reparent(content);
        let rank: ref<inkText> = this.NewText(this.RankName(entry.rank), 26, this.Grey(), n"Bold");
        rank.SetMargin(new inkMargin(0.0, 6.0, 0.0, 0.0));
        rank.Reparent(content);
        let cause: ref<inkText> = this.NewWrappedText(entry.cause, 24, this.Grey(), 380.0);
        cause.SetMargin(new inkMargin(0.0, 4.0, 0.0, 0.0));
        cause.Reparent(content);

        // Same character-count heuristic the original single-line strike used, just capped to the card's
        // inner width instead of a shorter constant - close enough for a wrapped first line too without
        // measuring actual rendered text width (not reliably available at construction time).
        let strikeWidth: Float = MinF(Cast<Float>(StrLen(entry.name)) * 17.0, 380.0);
        let strike: ref<inkRectangle> = this.NewRect(strikeWidth, 3.0, this.Red(), 0.8);
        strike.SetAnchor(inkEAnchor.TopLeft);
        strike.SetMargin(new inkMargin(24.0, 40.0, 0.0, 0.0));
        strike.Reparent(card);
    }

    // Horizontal draggable scrollbar, same construction as NewBar/CreateDetail's vertical one but there is
    // no VerticalScrollBarRef equivalent for horizontal scroll areas (also noted in
    // GangRetaliationHistory/History.reds's own NewBar) - synced by hand via OnGRFallenScrolled/Dragged.
    private func NewHBar(parent: ref<inkCompoundWidget>, x: Float, y: Float, w: Float, h: Float) -> ref<inkCanvas> {
        let bar: ref<inkCanvas> = new inkCanvas();
        bar.SetAnchor(inkEAnchor.TopLeft);
        bar.SetMargin(new inkMargin(x, y, 0.0, 0.0));
        bar.SetSize(new Vector2(w, h));
        bar.SetInteractive(true);
        bar.Reparent(parent);

        let track: ref<inkCanvas> = new inkCanvas();
        track.SetAnchor(inkEAnchor.Fill);
        track.Reparent(bar);
        this.AddFill(track, this.DarkRed(), 0.5);

        let grip: ref<inkRectangle> = new inkRectangle();
        grip.SetAnchor(inkEAnchor.LeftFillVerticaly);
        grip.SetSize(new Vector2(120.0, h));
        grip.SetTintColor(this.Red());
        grip.SetInteractive(true);
        grip.Reparent(bar);
        grip.RegisterToCallback(n"OnPress", this, n"OnGRFallenGripPress");
        grip.RegisterToCallback(n"OnRelease", this, n"OnGRFallenGripRelease");
        this.m_fallenGrip = grip;

        let drag: ref<inkSliderController> = new inkSliderController();
        drag.slidingAreaRef = inkWidgetRef.Create(bar);
        drag.handleRef = inkWidgetRef.Create(grip);
        drag.direction = inkESliderDirection.Horizontal;
        drag.autoSizeHandle = false;
        drag.Setup(0.0, 1.0, 0.0);
        bar.AttachController(drag);
        this.m_fallenDrag = drag;
        return bar;
    }

    protected cb func OnGRFallenGripPress(evt: ref<inkPointerEvent>) -> Bool {
        if evt.IsAction(n"click") && IsDefined(this.m_fallenGrip) {
            this.m_fallenGrip.SetTintColor(this.Cyan());
        }
        return false;
    }

    protected cb func OnGRFallenGripRelease(evt: ref<inkPointerEvent>) -> Bool {
        if IsDefined(this.m_fallenGrip) {
            this.m_fallenGrip.SetTintColor(this.Red());
        }
        return false;
    }

    protected cb func OnGRFallenScrolled(value: Vector2) -> Bool {
        if this.m_fallenSyncing || !IsDefined(this.m_fallenScroller) || !IsDefined(this.m_fallenDrag) {
            return true;
        }
        this.m_fallenScroller.UpdateScrollPositionFromScrollArea();
        this.m_fallenSyncing = true;
        this.m_fallenDrag.Setup(0.0, 1.0, this.m_fallenScroller.position);
        this.m_fallenSyncing = false;
        return true;
    }

    protected cb func OnGRFallenDragged(slider: wref<inkSliderController>, progress: Float, value: Float) -> Bool {
        if !this.m_fallenSyncing && IsDefined(this.m_fallenScroller) {
            this.m_fallenScroller.SetScrollPosition(progress);
        }
        return true;
    }

    protected cb func OnGRFallenMoreClick(evt: ref<inkPointerEvent>) -> Bool {
        if !evt.IsAction(n"click") {
            return false;
        }
        let collapsing: Bool = this.m_fallenExpanded;
        this.m_fallenExpanded = !this.m_fallenExpanded;
        if collapsing {
            // Shrinking the expanded list back down: if the current selection was a fallen nemesis (only
            // reachable while expanded), drop it so Fill()'s own fallback (prefers the living boss, then
            // a lieutenant, then a soldier) picks a sensible living nemesis instead of leaving the detail
            // panel pointed at a card that's about to disappear.
            let k: Int32 = 0;
            while k < ArraySize(this.m_fallenCards) {
                if Equals(this.m_fallenCards[k].name, this.m_selName) {
                    this.m_selName = "";
                }
                k += 1;
            }
        }
        this.Fill();
        this.BringToFront();
        this.PlaySound(n"Button", n"OnPress");
        return true;
    }

    protected cb func OnGRFallenClick(evt: ref<inkPointerEvent>) -> Bool {
        if !evt.IsAction(n"click") {
            return false;
        }
        let target: CName = evt.GetCurrentTarget().GetName();
        let i: Int32 = 0;
        while i < ArraySize(this.m_fallenCards) {
            if Equals(target, StringToName("gr_fallen_" + IntToString(i))) {
                this.m_selName = this.m_fallenCards[i].name;
                // Clear any living-card highlight (the fallen row isn't rebuilt by a plain selection
                // change, so this has to restyle in place, same as OnGRCardClick does for its own list).
                let j: Int32 = 0;
                while j < ArraySize(this.m_cardFrames) {
                    this.StyleFrame(this.m_cardFrames[j], this.m_cards[j], false);
                    this.m_cardSelFrames[j].SetOpacity(0.0);
                    j += 1;
                }
                j = 0;
                while j < ArraySize(this.m_fallenBorders) {
                    this.m_fallenBorders[j].SetOpacity(j == i ? 1.0 : 0.0);
                    j += 1;
                }
                this.FillDetail(this.m_fallenCards[i]);
                this.BringToFront();
                this.PlaySound(n"Button", n"OnPress");
                return true;
            }
            i += 1;
        }
        return false;
    }

    private func AddSection(parent: ref<inkCompoundWidget>, text: String, top: Float) {
        let label: ref<inkText> = this.NewText(this.Up(text), 34, this.Light(), n"Bold");
        label.SetMargin(new inkMargin(0.0, top, 0.0, 12.0));
        label.Reparent(parent);
    }

    private func AddStat(parent: ref<inkCompoundWidget>, value: Int32, label: String) {
        this.AddStatText(parent, IntToString(value), label, this.Light());
    }

    private func AddStatText(parent: ref<inkCompoundWidget>, value: String, label: String, color: HDRColor) {
        let box: ref<inkCanvas> = new inkCanvas();
        box.SetSize(new Vector2(208.0, 130.0));
        box.SetMargin(new inkMargin(0.0, 0.0, 14.0, 0.0));
        box.Reparent(parent);
        this.AddBorder(box, this.Dim(), 2.0, 1.0);
        let content: ref<inkVerticalPanel> = new inkVerticalPanel();
        content.SetAnchor(inkEAnchor.Fill);
        content.SetMargin(new inkMargin(20.0, 10.0, 10.0, 10.0));
        content.Reparent(box);
        this.NewText(value, 64, color, n"Bold").Reparent(content);
        this.NewText(label, 24, this.Light(), n"Bold").Reparent(content);
    }

    private func FillDetail(entry: ref<GRMenuEntry>) {
        this.UpdateDetailDay();
        if !IsDefined(entry) {
            this.m_detailHeader.RemoveAllChildren();
            this.m_detailContent.RemoveAllChildren();
            this.m_detail.SetVisible(false);
            return;
        }
        this.m_detail.SetVisible(true);
        if this.m_detailTab == 1 {
            this.FillDetailHistory(entry);
            return;
        }
        if this.m_detailTab == 2 {
            this.FillDetailGangHistory(entry);
            return;
        }
        this.FillDetailInfo(entry);
    }

    // Shared by Information and History (their headers match - rank | gang, name, title); Gang History
    // calls HideDetailBountyBadge instead since it has no single Nemesis to badge.
    private func ShowDetailBountyBadge(entry: ref<GRMenuEntry>) {
        if !IsDefined(this.m_detailBountyIcon) {
            return;
        }
        let open: Bool = IsDefined(this.m_bounties) && this.m_bounties.HasOpenBounty(entry.id);
        this.m_detailBountyIcon.SetVisible(open);
        this.m_detailBountyNemesisId = open ? entry.id : -1;
    }

    private func HideDetailBountyBadge() {
        if !IsDefined(this.m_detailBountyIcon) {
            return;
        }
        this.m_detailBountyIcon.SetVisible(false);
        this.m_detailBountyNemesisId = -1;
    }

    // sub-tab 0, Information: unchanged content from before the History merge.
    private func FillDetailInfo(entry: ref<GRMenuEntry>) {
        let header: ref<inkVerticalPanel> = this.m_detailHeader;
        let panel: ref<inkVerticalPanel> = this.m_detailContent;
        header.RemoveAllChildren();
        panel.RemoveAllChildren();
        let rankColor: HDRColor = this.RankColor(entry.rank);
        let width: Float = 888.0;

        this.ShowDetailBountyBadge(entry);

        this.NewText(this.RankName(entry.rank) + "  |  " + this.Up(entry.gang), 28, this.Cyan(), n"Bold").Reparent(header);
        if entry.dead {
            // White name + red strikethrough, matching the fallen-row card's own look (AddFallenCard).
            let nameWrap: ref<inkCanvas> = new inkCanvas();
            nameWrap.SetAnchor(inkEAnchor.TopLeft);
            nameWrap.SetSize(new Vector2(width, 80.0));
            nameWrap.Reparent(header);
            let deadName: ref<inkText> = this.NewWrappedText(entry.name, 66, this.Light(), width);
            deadName.SetFontStyle(n"Bold");
            deadName.Reparent(nameWrap);
            let strikeWidth: Float = MinF(Cast<Float>(StrLen(entry.name)) * 30.0, width);
            let strike: ref<inkRectangle> = this.NewRect(strikeWidth, 4.0, this.Red(), 0.8);
            strike.SetAnchor(inkEAnchor.TopLeft);
            strike.SetMargin(new inkMargin(0.0, 45.0, 0.0, 0.0));
            strike.Reparent(nameWrap);
        } else {
            let name: ref<inkText> = this.NewWrappedText(entry.name, 66, rankColor, width);
            name.SetFontStyle(n"Bold");
            name.Reparent(header);
        }
        if StrLen(entry.title) > 0 {
            this.NewText("\"" + entry.title + "\"", 42, this.Light(), n"Regular").Reparent(header);
        }

        let knownKey: String = entry.known ? (entry.dead ? "GR-MenuKnewYou" : "GR-MenuKnown") : "GR-MenuUnknown";
        let contact: ref<inkCompoundWidget> = this.NewTag(this.T(knownKey), 26, entry.known ? this.Red() : this.Grey());
        contact.SetHAlign(inkEHorizontalAlign.Left);
        contact.SetMargin(new inkMargin(0.0, 0.0, 0.0, 10.0));
        contact.Reparent(panel);
        if entry.dead {
            this.NewWrappedText(entry.cause, 36, this.Light(), width).Reparent(panel);
        } else {
            this.NewWrappedText(this.T(entry.known ? "GR-MenuKnownNote" : "GR-MenuUnknownNote"), 36, this.Light(), width).Reparent(panel);
        }

        let renownRow: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        renownRow.SetMargin(new inkMargin(0.0, 44.0, 0.0, 12.0));
        renownRow.Reparent(panel);
        let renownLabel: ref<inkText> = this.NewText(this.Up(this.T("GR-MenuRenown")), 30, this.Grey(), n"Bold");
        renownLabel.SetVAlign(inkEVerticalAlign.Center);
        renownLabel.SetMargin(new inkMargin(0.0, 0.0, 24.0, 0.0));
        renownLabel.Reparent(renownRow);
        let renownValue: ref<inkText> = this.NewText(IntToString(entry.renown), 52, rankColor, n"Bold");
        renownValue.SetVAlign(inkEVerticalAlign.Center);
        renownValue.Reparent(renownRow);

        this.NewRenownBar(entry.renown, rankColor, width, 20.0, 8.0).Reparent(panel);
        let marks: ref<inkCanvas> = new inkCanvas();
        marks.SetSize(new Vector2(width, 34.0));
        marks.SetMargin(new inkMargin(0.0, 6.0, 0.0, 0.0));
        marks.Reparent(panel);
        let pip: Float = (width - 8.0 * 9.0) / 10.0;
        let ltMark: ref<inkText> = this.NewText(this.Up(this.T("GR-RankLieutenant")), 22, this.Grey(), n"Medium");
        ltMark.SetAnchor(inkEAnchor.TopLeft);
        ltMark.SetMargin(new inkMargin(3.0 * (pip + 8.0), 0.0, 0.0, 0.0));
        ltMark.Reparent(marks);
        let bossMark: ref<inkText> = this.NewText(this.Up(this.T("GR-RankBoss")), 22, this.Grey(), n"Medium");
        bossMark.SetAnchor(inkEAnchor.TopLeft);
        bossMark.SetMargin(new inkMargin(7.0 * (pip + 8.0), 0.0, 0.0, 0.0));
        bossMark.Reparent(marks);
        if !entry.dead {
            this.NewWrappedText(entry.hint, 36, this.Light(), width).Reparent(panel);
        }

        this.AddSection(panel, this.T("GR-MenuTraits"), 44.0);
        let traitLines: array<String> = this.TraitLines(entry);
        for line in traitLines {
            let parts: array<String> = StrSplit(line, "|");
            if ArraySize(parts) >= 3 {
                let prefix: String = Equals(parts[0], "?") ? "" : parts[0] + "  ";
                let trait: ref<inkText> = this.NewWrappedText(prefix + parts[2], 38, this.TraitColor(parts[0]), width);
                trait.SetFontStyle(n"Medium");
                trait.SetMargin(new inkMargin(0.0, 0.0, 0.0, 8.0));
                trait.Reparent(panel);
            }
        }

        if entry.rank >= 3 && !entry.dead {
            this.AddBossWeapon(panel, entry, width);
        }

        let stats: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        stats.SetMargin(new inkMargin(0.0, 44.0, 0.0, 0.0));
        stats.Reparent(panel);
        this.AddStat(stats, entry.encounters, this.T("GR-MenuEncounters"));
        this.AddStat(stats, entry.escapes, this.T("GR-MenuEscapes"));
        this.AddStat(stats, entry.ambushes, this.T("GR-MenuAmbushes"));
        this.AddStat(stats, entry.gigs, this.T("GR-MenuGigs"));

        let origin: ref<inkText> = this.NewWrappedText(this.T("GR-MenuOrigin") + ": " + entry.origin, 32, this.Light(), width);
        origin.SetMargin(new inkMargin(0.0, 24.0, 0.0, 0.0));
        origin.Reparent(panel);
    }

    // ---------------------------------------------------------------- detail panel sub-tabs: History / Gang History
    protected cb func OnGRDetailTabClick(evt: ref<inkPointerEvent>) -> Bool {
        if !evt.IsAction(n"click") {
            return false;
        }
        let target: CName = evt.GetCurrentTarget().GetName();
        let i: Int32 = 0;
        while i < 3 {
            if Equals(target, StringToName("gr_detail_tab_" + IntToString(i))) {
                if i != this.m_detailTab {
                    this.m_detailTab = i;
                    this.StyleDetailTabs();
                    this.RefreshDetailPanel();
                    this.PlaySound(n"Button", n"OnPress");
                }
                return true;
            }
            i += 1;
        }
        return false;
    }

    private func StyleDetailTabs() {
        let i: Int32 = 0;
        while i < ArraySize(this.m_detailTabTexts) {
            let on: Bool = i == this.m_detailTab;
            this.m_detailTabTexts[i].SetTintColor(on ? this.Cyan() : this.Grey());
            this.m_detailTabBorders[i].SetTintColor(on ? this.Cyan() : this.DarkRed());
            this.m_detailTabBorders[i].SetOpacity(on ? 1.0 : 0.55);
            i += 1;
        }
    }

    // re-renders whichever sub-tab is active for the currently selected member, e.g. after a tab click -
    // selecting a different card already calls FillDetail(entry) directly, this is only for tab clicks.
    private func RefreshDetailPanel() {
        let entry: ref<GRMenuEntry> = this.FindEntryByName(this.m_selName);
        this.FillDetail(entry);
    }

    private func FindEntryByName(name: String) -> ref<GRMenuEntry> {
        let i: Int32 = 0;
        while i < ArraySize(this.m_cards) {
            if Equals(this.m_cards[i].name, name) {
                return this.m_cards[i];
            }
            i += 1;
        }
        i = 0;
        while i < ArraySize(this.m_fallenCards) {
            if Equals(this.m_fallenCards[i].name, name) {
                return this.m_fallenCards[i];
            }
            i += 1;
        }
        return null;
    }

    private func UpdateDetailDay() {
        if !IsDefined(this.m_detailDay) {
            return;
        }
        let spawner: ref<GRSpawner> = GameInstance.GetScriptableSystemsContainer(this.GetPlayerControlledObject().GetGame()).Get(n"GangRetaliation.GRSpawner") as GRSpawner;
        if IsDefined(spawner) {
            this.m_detailDay.SetText(this.Fmt(this.T("GRChron-Today"), "%d", IntToString(Cast<Int32>(spawner.GetGameDay()))));
        }
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
        return this.T("GRChron-Kind-" + kind);
    }

    private func DayText(day: Int32) -> String {
        return this.Fmt(this.T("GR-MenuDay"), "%d", IntToString(day));
    }

    private func EventsText(count: Int32) -> String {
        if count == 1 {
            return this.T("GRChron-Event1");
        }
        return this.Fmt(this.T("GRChron-EventN"), "%d", IntToString(count));
    }

    private func HistoryEventMatches(hist: ref<GRChronData>, i: Int32, memberFilter: String, gangFilter: String) -> Bool {
        if StrLen(memberFilter) > 0 {
            return StrContains(hist.Names(i), "|" + memberFilter + "|");
        }
        return StrContains(hist.Gangs(i), "|" + gangFilter + "|");
    }

    private func CountHistoryEvents(hist: ref<GRChronData>, memberFilter: String, gangFilter: String) -> Int32 {
        if !IsDefined(hist) {
            return 0;
        }
        let total: Int32 = hist.Count();
        let count: Int32 = 0;
        let i: Int32 = 0;
        while i < total {
            if this.HistoryEventMatches(hist, i, memberFilter, gangFilter) {
                count += 1;
            }
            i += 1;
        }
        return count;
    }

    // sub-tab 1, History: the selected member's own events (memberFilter = their name).
    private func FillDetailHistory(entry: ref<GRMenuEntry>) {
        let header: ref<inkVerticalPanel> = this.m_detailHeader;
        let panel: ref<inkVerticalPanel> = this.m_detailContent;
        header.RemoveAllChildren();
        panel.RemoveAllChildren();
        let gi: GameInstance = this.GetPlayerControlledObject().GetGame();
        let hist: ref<GRChronData> = GRChronData.Get(gi);
        this.ShowDetailBountyBadge(entry);

        this.NewText(this.RankName(entry.rank) + "  |  " + this.Up(entry.gang), 28, this.Cyan(), n"Bold").Reparent(header);
        if entry.dead {
            // Same white name + red strikethrough as the Information tab's fallen look (FillDetailInfo).
            let nameWrap: ref<inkCanvas> = new inkCanvas();
            nameWrap.SetAnchor(inkEAnchor.TopLeft);
            nameWrap.SetSize(new Vector2(888.0, 80.0));
            nameWrap.Reparent(header);
            let deadName: ref<inkText> = this.NewWrappedText(entry.name, 66, this.Light(), 888.0);
            deadName.SetFontStyle(n"Bold");
            deadName.Reparent(nameWrap);
            let strikeWidth: Float = MinF(Cast<Float>(StrLen(entry.name)) * 30.0, 888.0);
            let strike: ref<inkRectangle> = this.NewRect(strikeWidth, 4.0, this.Red(), 0.8);
            strike.SetAnchor(inkEAnchor.TopLeft);
            strike.SetMargin(new inkMargin(0.0, 45.0, 0.0, 0.0));
            strike.Reparent(nameWrap);
        } else {
            let name: ref<inkText> = this.NewWrappedText(entry.name, 66, this.RankColor(entry.rank), 888.0);
            name.SetFontStyle(n"Bold");
            name.Reparent(header);
        }
        if StrLen(entry.title) > 0 {
            this.NewText("\"" + entry.title + "\"", 42, this.Light(), n"Regular").Reparent(header);
        }

        let count: Int32 = this.CountHistoryEvents(hist, entry.name, "");
        let countLine: String = this.EventsText(count);
        if entry.dead {
            countLine += "  |  " + entry.cause;
        }
        // Below the divider, same as the Information tab's first content-panel child (the KNOWS YOU tag) -
        // not in header, which is sized for a fixed rank/name/title height shared with Information so the
        // divider lands in the same place on every sub-tab.
        let countText: ref<inkText> = this.NewText(countLine, 26, this.Grey(), n"Medium");
        countText.SetMargin(new inkMargin(0.0, 0.0, 0.0, 10.0));
        countText.Reparent(panel);

        this.BuildHistoryRows(panel, hist, entry.name, "");
    }

    // sub-tab 2, Gang History: every event tagged with the selected member's whole gang (gangFilter = gangKey).
    private func FillDetailGangHistory(entry: ref<GRMenuEntry>) {
        let header: ref<inkVerticalPanel> = this.m_detailHeader;
        let panel: ref<inkVerticalPanel> = this.m_detailContent;
        header.RemoveAllChildren();
        panel.RemoveAllChildren();
        let gi: GameInstance = this.GetPlayerControlledObject().GetGame();
        let hist: ref<GRChronData> = GRChronData.Get(gi);
        this.HideDetailBountyBadge();

        let gangColor: HDRColor = this.GangColor(entry.gangKey);
        let name: ref<inkText> = this.NewWrappedText(this.Up(entry.gang), 66, gangColor, 888.0);
        name.SetFontStyle(n"Bold");
        name.Reparent(header);

        let count: Int32 = this.CountHistoryEvents(hist, "", entry.gangKey);
        let countText: ref<inkText> = this.NewText(this.EventsText(count), 26, this.Grey(), n"Medium");
        countText.SetMargin(new inkMargin(0.0, 0.0, 0.0, 10.0));
        countText.Reparent(panel);

        this.BuildHistoryRows(panel, hist, "", entry.gangKey);
    }

    private func BuildHistoryRows(panel: ref<inkVerticalPanel>, hist: ref<GRChronData>, memberFilter: String, gangFilter: String) {
        if !IsDefined(hist) || hist.Count() == 0 {
            let none: ref<inkText> = this.NewWrappedText(this.T("GRChron-NoHistory"), 30, this.Dim(), 888.0);
            none.SetMargin(new inkMargin(0.0, 24.0, 0.0, 0.0));
            none.Reparent(panel);
            return;
        }
        let total: Int32 = hist.Count();
        let lastDay: Int32 = -1;
        let shown: Int32 = 0;
        // Newest first: the Day readout above already shows "now", so we walk the log backwards.
        let i: Int32 = total - 1;
        while i >= 0 {
            if this.HistoryEventMatches(hist, i, memberFilter, gangFilter) {
                let day: Int32 = hist.Day(i);
                this.AddHistoryRow(panel, day, day != lastDay, hist.Kind(i), this.RenderHistoryText(hist.Text(i)));
                lastDay = day;
                shown += 1;
            }
            i -= 1;
        }
        if shown == 0 {
            let noneHere: ref<inkText> = this.NewWrappedText(this.T("GRChron-NoEventsHere"), 30, this.Dim(), 888.0);
            noneHere.SetMargin(new inkMargin(0.0, 24.0, 0.0, 0.0));
            noneHere.Reparent(panel);
        }
    }

    // Territory's "Recent Rumors" row, styled to match AddHistoryRow (day/rail/dot/kind label/message) -
    // the day here is already a formatted string from GRMenuData.AddRumor (Lua passes "DAY %d" pre-built,
    // not a raw day number), unlike History's Int32 day, so this takes the string directly and always
    // shows it (there's no previous-row day to compare against, unlike History's showDay compaction) -
    // and kind is fixed to "WAR" since every rumor here already is one (AddRumor's only caller is the war
    // rumor feed), giving the same red dot/"WAR" label History already uses for war events.
    private func AddRumorRow(panel: ref<inkVerticalPanel>, dayStr: String, text: String, width: Float) {
        let color: HDRColor = this.KindColor("WAR");

        let row: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        row.SetMargin(new inkMargin(0.0, 0.0, 0.0, 16.0));
        row.Reparent(panel);

        let dayBox: ref<inkCanvas> = new inkCanvas();
        dayBox.SetSize(new Vector2(160.0, 10.0));
        dayBox.SetVAlign(inkEVerticalAlign.Fill);
        dayBox.Reparent(row);
        let dayLabel: ref<inkText> = this.NewText(dayStr, 32, this.Cyan(), n"Bold");
        dayLabel.SetAnchor(inkEAnchor.TopLeft);
        dayLabel.Reparent(dayBox);

        let rail: ref<inkCanvas> = new inkCanvas();
        rail.SetSize(new Vector2(40.0, 10.0));
        rail.SetVAlign(inkEVerticalAlign.Fill);
        rail.Reparent(row);
        let line: ref<inkRectangle> = new inkRectangle();
        line.SetAnchor(inkEAnchor.LeftFillVerticaly);
        line.SetMargin(new inkMargin(18.0, 0.0, 0.0, 0.0));
        line.SetWidth(2.0);
        line.SetTintColor(this.Dim());
        line.SetOpacity(0.8);
        line.Reparent(rail);
        let dot: ref<inkRectangle> = this.NewRect(14.0, 14.0, color, 1.0);
        dot.SetAnchor(inkEAnchor.TopLeft);
        dot.SetMargin(new inkMargin(13.0, 16.0, 0.0, 0.0));
        dot.Reparent(rail);

        let textCol: ref<inkVerticalPanel> = new inkVerticalPanel();
        textCol.SetFitToContent(true);
        textCol.Reparent(row);
        let message: ref<inkText> = this.NewWrappedText(text, 32, this.Light(), width - 200.0);
        message.Reparent(textCol);
    }

    private func AddHistoryRow(panel: ref<inkVerticalPanel>, day: Int32, showDay: Bool, kind: String, text: String) {
        if showDay {
            let spacer: ref<inkCanvas> = new inkCanvas();
            spacer.SetSize(new Vector2(10.0, 20.0));
            spacer.Reparent(panel);
        }
        let color: HDRColor = this.KindColor(kind);

        let row: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        row.SetFitToContent(true);
        row.Reparent(panel);

        let dayBox: ref<inkCanvas> = new inkCanvas();
        dayBox.SetSize(new Vector2(160.0, 10.0));
        dayBox.SetVAlign(inkEVerticalAlign.Fill);
        dayBox.Reparent(row);
        if showDay {
            let dayLabel: ref<inkText> = this.NewText(this.DayText(day), 32, this.Cyan(), n"Bold");
            dayLabel.SetAnchor(inkEAnchor.TopLeft);
            dayLabel.Reparent(dayBox);
        }

        let rail: ref<inkCanvas> = new inkCanvas();
        rail.SetSize(new Vector2(40.0, 10.0));
        rail.SetVAlign(inkEVerticalAlign.Fill);
        rail.Reparent(row);
        let line: ref<inkRectangle> = new inkRectangle();
        line.SetAnchor(inkEAnchor.LeftFillVerticaly);
        line.SetMargin(new inkMargin(18.0, 0.0, 0.0, 0.0));
        line.SetWidth(2.0);
        line.SetTintColor(this.Dim());
        line.SetOpacity(0.8);
        line.Reparent(rail);
        let dot: ref<inkRectangle> = this.NewRect(14.0, 14.0, color, 1.0);
        dot.SetAnchor(inkEAnchor.TopLeft);
        dot.SetMargin(new inkMargin(13.0, 16.0, 0.0, 0.0));
        dot.Reparent(rail);

        let textCol: ref<inkVerticalPanel> = new inkVerticalPanel();
        textCol.SetFitToContent(true);
        textCol.Reparent(row);
        let kindLabel: ref<inkText> = this.NewText(this.KindLabel(kind), 32, color, n"Bold");
        kindLabel.Reparent(textCol);
        let message: ref<inkText> = this.NewWrappedText(text, 32, this.Light(), 680.0);
        message.SetMargin(new inkMargin(0.0, 4.0, 0.0, 14.0));
        message.Reparent(textCol);
    }

    private func AddBossWeapon(panel: ref<inkCompoundWidget>, entry: ref<GRMenuEntry>, width: Float) {
        if !IsDefined(this.m_rewards) || this.m_rewards.HasGiven(entry.id) {
            return;
        }
        let base: String = this.m_rewards.GetGangWeaponBaseName(entry.gangKey);
        if StrLen(base) == 0 {
            return;
        }
        let scanned: Bool = true;
        let lines: array<String> = this.TraitLines(entry);
        for line in lines {
            if StrBeginsWith(line, "?") {
                scanned = false;
            }
        }
        let known: Bool = scanned && this.m_rewards.PreviewBossWeapon(entry.id, entry.gangKey, entry.traitKeys, entry.escapes);
        let ruleColor: HDRColor = this.Gold();

        let top: ref<inkRectangle> = this.NewRect(width, 2.0, ruleColor, 1.0);
        top.SetMargin(new inkMargin(0.0, 28.0, 0.0, 12.0));
        top.Reparent(panel);
        this.NewText(this.Up(this.T("GR-MenuUniqueWeapon")), 34, this.Gold(), n"Bold").Reparent(panel);

        let boss: String = entry.name;
        if StrLen(entry.title) > 0 {
            boss = entry.name + " \"" + entry.title + "\"";
        }
        let name: ref<inkText> = this.NewWrappedText(known ? this.m_rewards.GetBossWeaponName(boss, entry.gangKey) : "???", 40, known ? this.Light() : this.Dim(), width);
        name.SetFontStyle(n"Bold");
        name.Reparent(panel);
        let kind: String = this.m_rewards.GetGangWeaponType(entry.gangKey);
        this.NewText(StrLen(kind) > 0 ? kind + "  ·  " + base : base, 28, this.Grey(), n"Regular").Reparent(panel);

        if known {
            this.NewElementRowOf(this.m_rewards.GetPreviewElement(), Cast<Float>(this.m_rewards.GetPreviewBonus()), 48, 24).Reparent(panel);
            this.NewWrappedText(this.Fmt(this.T("GR-MenuBossWeaponGrows"), "%d", IntToString(entry.escapes)), 26, this.Light(), width).Reparent(panel);
            let mine: Int32 = this.ArsenalMain(entry.gangKey);
            if mine >= 0 {
                this.NewWrappedText(this.Fmt(this.T("GR-MenuBossWeaponCopy"), "%s", this.m_rewards.GetOwnedName(mine)), 26, this.Cyan(), width).Reparent(panel);
            }
        } else {
            if !scanned {
                this.NewWrappedText(this.T("GR-MenuBossWeaponScan"), 26, this.Grey(), width).Reparent(panel);
            }
        }

        let bottom: ref<inkRectangle> = this.NewRect(width, 2.0, ruleColor, 1.0);
        bottom.SetMargin(new inkMargin(0.0, 12.0, 0.0, 0.0));
        bottom.Reparent(panel);
    }

    private func Fill() {
        this.m_tree.RemoveAllChildren();
        ArrayClear(this.m_pathPoints);
        ArrayClear(this.m_pathStart);
        ArrayClear(this.m_pathColor);
        let links: ref<inkCanvas> = new inkCanvas();
        links.SetName(n"links");
        links.SetAnchor(inkEAnchor.Fill);
        links.Reparent(this.m_tree);
        this.m_links = links;
        ArrayClear(this.m_cards);
        ArrayClear(this.m_cardFrames);
        ArrayClear(this.m_cardSelFrames);

        let gangs: array<String> = IsDefined(this.m_data) ? this.m_data.GetGangs() : [];
        if ArraySize(gangs) == 0 {
            this.m_gangTitle.SetText(this.Up(this.T("GR-MenuTitle")));
            this.m_gangCount.SetText("");
            this.m_summary.SetText("");
            this.FillDetail(null);
            this.m_marks.RemoveAllChildren();
            ArrayClear(this.m_tabTexts);
            ArrayClear(this.m_tabBars);
            ArrayClear(this.m_tabThreats);
            let empty: ref<inkText> = this.NewText(this.T("GR-MenuEmpty"), 44, this.Grey(), n"Regular");
            empty.SetAnchor(inkEAnchor.Centered);
            empty.SetAnchorPoint(new Vector2(0.5, 0.5));
            empty.Reparent(this.m_tree);
            return;
        }
        let count: Int32 = ArraySize(gangs);
        this.m_page = ((this.m_page % count) + count) % count;
        let gangKey: String = gangs[this.m_page];
        let entries: array<ref<GRMenuEntry>> = this.m_data.GetEntries();

        let i: Int32 = 0;
        if ArraySize(this.m_tabTexts) != count {
            this.m_marks.RemoveAllChildren();
            ArrayClear(this.m_tabTexts);
            ArrayClear(this.m_tabBars);
            ArrayClear(this.m_tabThreats);
            while i < count {
                this.AddTab(i);
                i += 1;
            }
        }
        i = 0;
        while i < count {
            let label: String = gangs[i];
            let threat: Bool = false;
            for entry in entries {
                if Equals(entry.gangKey, gangs[i]) {
                    label = entry.gang;
                    if entry.known && !entry.dead {
                        threat = true;
                    }
                }
            }
            this.StyleTab(i, label, i == this.m_page, threat);
            i += 1;
        }

        let boss: ref<GRMenuEntry>;
        let lieutenants: array<ref<GRMenuEntry>>;
        let soldiers: array<ref<GRMenuEntry>>;
        let fallen: array<ref<GRMenuEntry>>;
        let selected: ref<GRMenuEntry>;
        let gangLabel: String = "";
        let known: Int32 = 0;
        for entry in entries {
            if Equals(entry.gangKey, gangKey) {
                gangLabel = entry.gang;
                if entry.dead {
                    ArrayPush(fallen, entry);
                    if Equals(entry.name, this.m_selName) {
                        selected = entry;
                    }
                } else {
                    if entry.known {
                        known += 1;
                    }
                    if Equals(entry.name, this.m_selName) {
                        selected = entry;
                    }
                    if entry.rank >= 3 && !IsDefined(boss) {
                        boss = entry;
                    } else {
                        if entry.rank >= 2 && ArraySize(lieutenants) < 2 {
                            ArrayPush(lieutenants, entry);
                        } else {
                            ArrayPush(soldiers, entry);
                        }
                    }
                }
            }
        }
        if !IsDefined(selected) {
            if IsDefined(boss) {
                selected = boss;
            } else {
                if ArraySize(lieutenants) > 0 {
                    selected = lieutenants[0];
                } else {
                    if ArraySize(soldiers) > 0 {
                        selected = soldiers[0];
                    }
                }
            }
        }
        this.m_selName = IsDefined(selected) ? selected.name : "";

        let alive: Int32 = ArraySize(lieutenants) + ArraySize(soldiers) + (IsDefined(boss) ? 1 : 0);
        this.m_gangTitle.SetText(this.Up(gangLabel));
        this.m_gangCount.SetText(IntToString(alive));
        this.m_summary.SetText(this.T("GR-MenuAlive") + " " + IntToString(alive) + "   |   " + this.T("GR-MenuFallenShort") + " " + IntToString(ArraySize(fallen))
            + "   |   " + this.T("GR-MenuKnowYouShort") + " " + IntToString(known));

        let lostTurfs: String = GRIntegrations.GetDDLostTurfs(gangKey);
        if StrLen(lostTurfs) > 0 {
            let lostLine: ref<inkHorizontalPanel> = new inkHorizontalPanel();
            lostLine.SetAnchor(inkEAnchor.TopLeft);
            lostLine.SetMargin(new inkMargin(120.0, 366.0, 0.0, 0.0));
            lostLine.SetFitToContent(true);
            lostLine.Reparent(this.m_tree);
            let lostLabel: ref<inkText> = this.NewText(this.Up(this.T("GR-MenuDDLost")), 30, this.Light(), n"Bold");
            lostLabel.SetMargin(new inkMargin(0.0, 0.0, 14.0, 0.0));
            lostLabel.Reparent(lostLine);
            this.NewText(lostTurfs, 30, this.Cyan(), n"Medium").Reparent(lostLine);
        }
        this.AddIntelBar(gangKey);

        let cx: Float = this.CenterX();
        let bossY: Float = this.TierY(3);
        let ltY: Float = this.TierY(2);
        let soldierY: Float = this.TierY(1);
        let bigW: Float = 600.0;
        let bigH: Float = 290.0;

        if IsDefined(boss) {
            this.AddCard(boss, cx, bossY, bigW, bigH, false, this.IsSelected(boss));
        } else {
            this.AddVacant(cx, bossY, bigW, bigH, this.m_data.GetVacancy(gangKey, 3));
        }

        let ltXs: array<Float> = [cx - 660.0, cx + 660.0];
        let ltCount: Int32 = ArraySize(lieutenants);
        i = 0;
        while i < 2 {
            this.Connect(cx + (i == 0 ? -28.0 : 28.0), bossY + bigH / 2.0, ltXs[i], ltY - bigH / 2.0, i < ltCount ? this.Gold() : this.Dim());
            if i < ltCount {
                this.AddCard(lieutenants[i], ltXs[i], ltY, bigW, bigH, false, this.IsSelected(lieutenants[i]));
            } else {
                this.AddVacant(ltXs[i], ltY, bigW, bigH, this.m_data.GetVacancy(gangKey, 2));
            }
            i += 1;
        }

        let soldierCount: Int32 = ArraySize(soldiers);
        if soldierCount == 0 {
            let noSoldiers: ref<inkText> = this.NewText(this.T("GR-MenuNoSoldiers"), 34, this.Grey(), n"Regular");
            noSoldiers.SetAnchor(inkEAnchor.TopLeft);
            noSoldiers.SetAnchorPoint(new Vector2(0.5, 0.5));
            noSoldiers.SetMargin(new inkMargin(cx, soldierY, 0.0, 0.0));
            noSoldiers.Reparent(this.m_tree);
        }
        if soldierCount > 0 {
            let gap: Float = 32.0;
            let soldierW: Float = MinF(440.0, (2200.0 - gap * Cast<Float>(soldierCount - 1)) / Cast<Float>(soldierCount));
            let soldierH: Float = 260.0;
            let left: Float = 380.0 + soldierW / 2.0;
            let right: Float = 2580.0 - soldierW / 2.0;
            let half: Int32 = (soldierCount + 1) / 2;
            i = 0;
            while i < soldierCount {
                let sx: Float = this.Spread(soldierCount, i, left, right);
                if soldierCount == 1 {
                    sx = cx;
                }
                let px: Float = ltXs[i < half ? 0 : 1];
                if sx < px - 1.0 {
                    px -= 28.0;
                } else {
                    if sx > px + 1.0 {
                        px += 28.0;
                    }
                }
                this.Connect(px, ltY + bigH / 2.0, sx, soldierY - soldierH / 2.0, this.Gold());
                this.AddCard(soldiers[i], sx, soldierY, soldierW, soldierH, true, this.IsSelected(soldiers[i]));
                i += 1;
            }
        }

        this.DrawLinks();
        this.AddFallen(fallen);
        this.FillDetail(selected);
    }

    private func BringToFront() {
        let root: ref<inkWidget> = this.GetRootWidget();
        root.SetName(n"GR_NemesisRoot");
        let layer: ref<inkLayerWrapper> = GameInstance.GetInkSystem().GetLayer(n"inkMenuLayer");
        if !IsDefined(layer) {
            return;
        }
        let window: ref<inkCompoundWidget> = layer.GetVirtualWindow();
        if !IsDefined(window) || window.GetNumChildren() == 0 {
            return;
        }
        let parent: ref<inkCompoundWidget> = window.GetWidgetByIndex(0) as inkCompoundWidget;
        if !IsDefined(parent) {
            return;
        }
        let count: Int32 = parent.GetNumChildren();
        let i: Int32 = 0;
        while i < count {
            let child: wref<inkWidget> = parent.GetWidgetByIndex(i);
            if IsDefined(child) && Equals(child.GetName(), n"GR_NemesisRoot") {
                if i != count - 1 {
                    parent.ReorderChild(child, count - 1);
                }
                return;
            }
            i += 1;
        }
        GRLog("Menu: no se encontro la pantalla en la capa de menus");
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

    private func Fmt(fmt: String, token: String, value: String) -> String {
        let i: Int32 = StrFindFirst(fmt, token);
        if i < 0 {
            return fmt;
        }
        let after: Int32 = i + StrLen(token);
        return StrLeft(fmt, i) + value + StrMid(fmt, after, StrLen(fmt) - after);
    }

    // Fills a localized template's "%s"/"%d" placeholders left to right from args, one placeholder per
    // array entry (unlike Fmt above, which only replaces a single named token once) - used to render
    // history events from their stored key+args at display time, so a language change shows up immediately
    // instead of being frozen at whatever language was active when the event happened.
    private func Substitute(template: String, args: array<String>) -> String {
        let out: String = template;
        let result: String = "";
        let argIndex: Int32 = 0;
        let guard: Int32 = 0;
        let searching: Bool = true;
        while searching && guard < 20 {
            guard += 1;
            let posS: Int32 = StrFindFirst(out, "%s");
            let posD: Int32 = StrFindFirst(out, "%d");
            let tokenPos: Int32 = -1;
            if posS >= 0 && (posD < 0 || posS < posD) {
                tokenPos = posS;
            } else {
                if posD >= 0 {
                    tokenPos = posD;
                }
            }
            if tokenPos < 0 || argIndex >= ArraySize(args) {
                searching = false;
            } else {
                result += StrLeft(out, tokenPos) + args[argIndex];
                argIndex += 1;
                out = StrMid(out, tokenPos + 2, StrLen(out) - tokenPos - 2);
            }
        }
        result += out;
        return result;
    }

    // Recovers "key|arg1|arg2|..." (as stored by History.record in GRChronData's text slot) back into the
    // rendered sentence shown in a history row, using whichever language is active right now - not whatever
    // was active when the event was recorded.
    private func RenderHistoryText(encoded: String) -> String {
        let parts: array<String> = StrSplit(encoded, "|");
        if ArraySize(parts) == 0 {
            return encoded;
        }
        let key: String = parts[0];
        let args: array<String> = [];
        let i: Int32 = 1;
        while i < ArraySize(parts) {
            ArrayPush(args, parts[i]);
            i += 1;
        }
        return this.Substitute(this.T(key), args);
    }

    // TAB  GANGS | TERRITORY | ARSENAL, one line - BOUNTIES moved to the title row (CreateHeader's
    // navTitleKey/navTarget) since hanging a 4th item off a 2nd line here read as orphaned.
    private func CreateViewSwitch(root: ref<inkCompoundWidget>) {
        let outer: ref<inkVerticalPanel> = new inkVerticalPanel();
        outer.SetName(n"view_switch");
        outer.SetAnchor(inkEAnchor.TopLeft);
        outer.SetMargin(new inkMargin(120.0, 242.0, 0.0, 0.0));
        outer.SetFitToContent(true);
        outer.Reparent(root);

        let row1: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        row1.SetFitToContent(true);
        row1.Reparent(outer);

        let key: ref<inkCompoundWidget> = this.NewTag("TAB", 22, this.Cyan());
        key.SetVAlign(inkEVerticalAlign.Center);
        key.SetMargin(new inkMargin(0.0, 0.0, 20.0, 0.0));
        key.Reparent(row1);

        let gangs: ref<inkText> = this.NewText(this.Up(this.T("GR-MenuViewGangs")), 32, this.Grey(), n"Bold");
        gangs.SetVAlign(inkEVerticalAlign.Center);
        gangs.SetInteractive(true);
        gangs.RegisterToCallback(n"OnRelease", this, n"OnGRViewGangsClick");
        gangs.Reparent(row1);
        this.m_viewGangs = gangs;

        let sep: ref<inkText> = this.NewText("  |  ", 32, this.Dim(), n"Medium");
        sep.SetVAlign(inkEVerticalAlign.Center);
        sep.Reparent(row1);

        let territory: ref<inkText> = this.NewText(this.Up(this.T("GR-MenuViewTerritory")), 32, this.Grey(), n"Bold");
        territory.SetVAlign(inkEVerticalAlign.Center);
        territory.SetInteractive(true);
        territory.RegisterToCallback(n"OnRelease", this, n"OnGRViewTerritoryClick");
        territory.Reparent(row1);
        this.m_viewTerritory = territory;

        let sep2: ref<inkText> = this.NewText("  |  ", 32, this.Dim(), n"Medium");
        sep2.SetVAlign(inkEVerticalAlign.Center);
        sep2.Reparent(row1);

        let arsenal: ref<inkText> = this.NewText(this.Up(this.T("GR-MenuViewArsenal")), 32, this.Grey(), n"Bold");
        arsenal.SetVAlign(inkEVerticalAlign.Center);
        arsenal.SetInteractive(true);
        arsenal.RegisterToCallback(n"OnRelease", this, n"OnGRViewArsenalClick");
        arsenal.Reparent(row1);
        this.m_viewArsenal = arsenal;
    }

    // Opens the OTHER top-level GangRetaliation menu scenario (NEMESES <-> BOUNTY BOARD) from wherever
    // we are right now, the same way the vanilla JOURNAL/character-menu buttons do (GRAddBountyButton/
    // GRAddNemesisButton) - a SelectMenuRequest naming a MenuItemController whose MenuData.fullscreenName
    // is the target, queued up to MenuScenario_HubMenu's own OnOpenMenu handler (wrapped below). Passing
    // focusNemesisId (>= 0) also stashes which Nemesis's bounty to auto-select once InitBounty opens
    // (see RequestBountyFocus/ConsumeBountyFocus on GRMenuData), for the detail-panel badge's own click.
    // m_navMenuItem keeps the holder alive past this function's scope in case QueueEvent is deferred.
    private func OpenGRMenu(target: CName, focusNemesisId: Int32) {
        let gi: GameInstance = this.GetPlayerControlledObject().GetGame();
        if focusNemesisId >= 0 && IsDefined(this.m_data) {
            this.m_data.RequestBountyFocus(focusNemesisId);
        }
        let data: MenuData = Equals(target, n"gangretaliation_bounty_menu") ? GRBountyMenuItem(gi) : GRNemesisMenuItem(gi);
        let holder: ref<MenuItemController> = new MenuItemController();
        holder.Init(data);
        this.m_navMenuItem = holder;
        let request: ref<SelectMenuRequest> = new SelectMenuRequest();
        request.m_eventData = holder;
        this.QueueEvent(request);
        this.PlaySound(n"Button", n"OnPress");
        GRLog("Menu: navegando a " + NameToString(target));
    }

    protected cb func OnGRHeaderNavClick(evt: ref<inkPointerEvent>) -> Bool {
        if !evt.IsAction(n"click") {
            return false;
        }
        this.OpenGRMenu(this.m_headerNavTarget, -1);
        return true;
    }

    protected cb func OnGRBountyBadgeClick(evt: ref<inkPointerEvent>) -> Bool {
        if !evt.IsAction(n"click") || this.m_detailBountyNemesisId < 0 {
            return false;
        }
        this.OpenGRMenu(n"gangretaliation_bounty_menu", this.m_detailBountyNemesisId);
        return true;
    }

    private func CreateTerritory(root: ref<inkCompoundWidget>) {
        let territory: ref<inkCanvas> = new inkCanvas();
        territory.SetName(n"territory");
        territory.SetAnchor(inkEAnchor.Fill);
        territory.SetVisible(false);
        territory.Reparent(root);
        this.m_territory = territory;
    }

    private func CreateArsenal(root: ref<inkCompoundWidget>) {
        let arsenal: ref<inkCanvas> = new inkCanvas();
        arsenal.SetName(n"arsenal");
        arsenal.SetAnchor(inkEAnchor.Fill);
        arsenal.SetVisible(false);
        arsenal.Reparent(root);
        this.m_arsenal = arsenal;
    }

    private func ShowView() {
        let gangs: Bool = this.m_view == 0;
        let arsenal: Bool = this.m_view == 2;
        this.m_gangSwitch.SetVisible(gangs || arsenal);
        this.m_marks.SetVisible(gangs || arsenal);
        this.m_tree.SetVisible(gangs);
        for label in this.m_rankLabels {
            label.SetVisible(gangs);
        }
        if !gangs {
            this.m_detail.SetVisible(false);
        }
        this.m_territory.SetVisible(this.m_view == 1);
        this.m_arsenal.SetVisible(arsenal);
        this.m_viewGangs.SetTintColor(gangs ? this.Cyan() : this.Grey());
        this.m_viewTerritory.SetTintColor(this.m_view == 1 ? this.Cyan() : this.Grey());
        this.m_viewArsenal.SetTintColor(arsenal ? this.Cyan() : this.Grey());
    }

    private func Refresh() {
        this.ShowView();
        if this.m_view == 1 {
            this.FillTerritory();
        } else {
            if IsDefined(this.m_rewards) {
                this.m_rewards.Snapshot();
            }
            if this.m_view == 2 {
                this.FillArsenal();
            } else {
                this.Fill();
            }
        }
    }

    private func SetView(view: Int32) {
        if this.m_fOpen {
            return;
        }
        this.m_view = view;
        this.Refresh();
        this.BringToFront();
        this.PlaySound(n"Button", n"OnPress");
    }

    private func ToggleView() {
        this.SetView((this.m_view + 1) % 3);
    }

    protected cb func OnGRViewGangsClick(evt: ref<inkPointerEvent>) -> Bool {
        if evt.IsAction(n"click") && this.m_view != 0 {
            this.SetView(0);
        }
    }

    protected cb func OnGRViewTerritoryClick(evt: ref<inkPointerEvent>) -> Bool {
        if evt.IsAction(n"click") && this.m_view != 1 {
            this.SetView(1);
        }
    }

    protected cb func OnGRViewArsenalClick(evt: ref<inkPointerEvent>) -> Bool {
        if evt.IsAction(n"click") && this.m_view != 2 {
            this.SetView(2);
        }
    }

    private func PlaceText(parent: ref<inkCompoundWidget>, text: String, size: Int32, color: HDRColor, style: CName, x: Float, y: Float) -> ref<inkText> {
        let label: ref<inkText> = this.NewText(text, size, color, style);
        label.SetAnchor(inkEAnchor.TopLeft);
        label.SetMargin(new inkMargin(x, y, 0.0, 0.0));
        label.Reparent(parent);
        return label;
    }

    private func PlaceRect(parent: ref<inkCompoundWidget>, x: Float, y: Float, w: Float, h: Float, color: HDRColor, opacity: Float) {
        let rect: ref<inkRectangle> = this.NewRect(w, h, color, opacity);
        rect.SetAnchor(inkEAnchor.TopLeft);
        rect.SetMargin(new inkMargin(x, y, 0.0, 0.0));
        rect.Reparent(parent);
    }

    private func NewInfluenceBar(influence: String, width: Float, height: Float) -> ref<inkHorizontalPanel> {
        let bar: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        let parts: array<String> = StrSplit(influence, ",");
        let gap: Float = 3.0;
        let usable: Float = width - gap * Cast<Float>(Max(0, ArraySize(parts) - 1));
        for part in parts {
            let fields: array<String> = StrSplit(part, "|");
            if ArraySize(fields) >= 3 {
                let value: Float = Cast<Float>(StringToInt(fields[2]));
                if value > 0.0 {
                    let seg: ref<inkRectangle> = this.NewRect(usable * value / 100.0, height, this.GangColor(fields[0]), 1.0);
                    seg.SetMargin(new inkMargin(0.0, 0.0, gap, 0.0));
                    seg.Reparent(bar);
                }
            }
        }
        return bar;
    }

    private func InfluenceLabel(influence: String, gang: String) -> String {
        let influenceParts: array<String> = StrSplit(influence, ",");
        for part in influenceParts {
            let fields: array<String> = StrSplit(part, "|");
            if ArraySize(fields) >= 2 && Equals(fields[0], gang) {
                return fields[1];
            }
        }
        return gang;
    }

    private func StyleDistrict(index: Int32, selected: Bool) {
        let border: wref<GRBorder> = this.m_tBorders[index];
        if selected {
            border.SetTintColor(this.Cyan());
            border.SetThickness(3.0);
            border.SetOpacity(1.0);
        } else {
            border.SetTintColor(this.m_tAtWar[index] ? this.Red() : this.Dim());
            border.SetThickness(2.0);
            border.SetOpacity(this.m_tAtWar[index] ? 0.85 : 0.7);
        }
    }

    private func AddDistrictRow(column: ref<inkVerticalPanel>, index: Int32, label: String, owner: String, influence: String, atWar: Bool) {
        let row: ref<inkCanvas> = new inkCanvas();
        row.SetName(StringToName("gr_dist_" + IntToString(index)));
        row.SetSize(new Vector2(601.0, 98.0));
        row.SetMargin(new inkMargin(0.0, 0.0, 0.0, 12.0));
        row.SetInteractive(true);
        row.RegisterToCallback(n"OnRelease", this, n"OnGRDistrictClick");
        row.Reparent(column);
        this.AddFill(row, this.Dark(), 0.9);

        let border: ref<GRBorder> = new GRBorder();
        border.SetAnchor(inkEAnchor.Fill);
        border.Reparent(row);
        ArrayPush(this.m_tBorders, border);
        ArrayPush(this.m_tAtWar, atWar);

        this.PlaceText(row, label, 34, this.Light(), n"Bold", 18.0, 6.0);
        if atWar {
            let tag: ref<inkCompoundWidget> = this.NewTag(this.T("GR-MenuAtWar"), 20, this.Red());
            tag.SetAnchor(inkEAnchor.TopRight);
            tag.SetAnchorPoint(new Vector2(1.0, 0.0));
            tag.SetMargin(new inkMargin(0.0, 12.0, 14.0, 0.0));
            tag.Reparent(row);
        }
        this.PlaceText(row, this.Up(this.InfluenceLabel(influence, owner)), 24, this.GangColor(owner), n"Bold", 18.0, 48.0);
        let ddState: Int32 = GRIntegrations.GetDDTurfState(this.m_tKeys[index]);
        if ddState >= 1 {
            let ddTag: ref<inkCompoundWidget> = this.NewTag(this.T(ddState == 2 ? "GR-MenuDDControlled" : "GR-MenuDDContested"), 18, ddState == 2 ? this.Cyan() : this.Gold());
            ddTag.SetAnchor(inkEAnchor.TopRight);
            ddTag.SetAnchorPoint(new Vector2(1.0, 0.0));
            ddTag.SetMargin(new inkMargin(0.0, 46.0, 14.0, 0.0));
            ddTag.Reparent(row);
        }
        let bar: ref<inkHorizontalPanel> = this.NewInfluenceBar(influence, 565.0, 8.0);
        bar.SetAnchor(inkEAnchor.TopLeft);
        bar.SetMargin(new inkMargin(18.0, 80.0, 0.0, 0.0));
        bar.Reparent(row);
    }

    // Fixed per-region column assignment for the Territory screen, user-chosen layout (not a rolling
    // index%4 - that scattered regions unpredictably once Eastern/Southern Badlands were added). Matches
    // against the already-localized display label GetAllDistricts()/DistrictLabel() produces (e.g. the
    // game's own "Santo Domingo", not a raw EnumName), plus this mod's own literal "Eastern Badlands"/
    // "Southern Badlands" region strings. Anything unmapped falls back to the last column rather than
    // being silently dropped.
    private func TerritoryColumnFor(region: String) -> Int32 {
        if Equals(region, "Watson") || Equals(region, "Westbrook") {
            return 0;
        }
        if Equals(region, "Heywood") || Equals(region, "Santo Domingo") || Equals(region, "Pacifica") {
            return 1;
        }
        if Equals(region, "Dogtown") {
            return 2;
        }
        return 3;
    }

    private func FillTerritory() {
        this.m_territory.RemoveAllChildren();
        ArrayClear(this.m_tKeys);
        ArrayClear(this.m_tBorders);
        ArrayClear(this.m_tAtWar);
        if !IsDefined(this.m_data) {
            return;
        }
        let keys: array<String> = this.m_data.DistrictKeys();
        let labels: array<String> = this.m_data.DistrictLabels();
        let regions: array<String> = this.m_data.DistrictRegions();
        let owners: array<String> = this.m_data.DistrictOwners();
        let influence: array<String> = this.m_data.DistrictInfluence();
        let wars: array<String> = this.m_data.DistrictWars();
        let count: Int32 = ArraySize(keys);

        let title: ref<inkText> = this.NewText(this.Up(this.T("GR-MenuViewTerritory")), 72, this.Cyan(), n"Medium");
        title.SetAnchor(inkEAnchor.TopCenter);
        title.SetAnchorPoint(new Vector2(0.5, 0.0));
        title.SetMargin(new inkMargin(0.0, 168.0, 0.0, 0.0));
        title.Reparent(this.m_territory);

        if count == 0 {
            this.m_summary.SetText("");
            let empty: ref<inkText> = this.NewText(this.T("GR-MenuNoTerritory"), 44, this.Grey(), n"Regular");
            empty.SetAnchor(inkEAnchor.Centered);
            empty.SetAnchorPoint(new Vector2(0.5, 0.5));
            empty.Reparent(this.m_territory);
            return;
        }

        let legend: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        legend.SetAnchor(inkEAnchor.TopCenter);
        legend.SetAnchorPoint(new Vector2(0.5, 0.0));
        legend.SetMargin(new inkMargin(0.0, 276.0, 0.0, 0.0));
        legend.SetFitToContent(true);
        legend.Reparent(this.m_territory);
        let sGangs: array<String> = this.m_data.StrengthGangs();
        let sLabels: array<String> = this.m_data.StrengthLabels();
        let i: Int32 = 0;
        while i < ArraySize(sGangs) {
            let swatch: ref<inkRectangle> = this.NewRect(22.0, 22.0, this.GangColor(sGangs[i]), 1.0);
            swatch.SetVAlign(inkEVerticalAlign.Center);
            swatch.SetMargin(new inkMargin(i > 0 ? 44.0 : 0.0, 0.0, 12.0, 0.0));
            swatch.Reparent(legend);
            let name: ref<inkText> = this.NewText(this.Up(sLabels[i]), 24, this.Light(), n"Medium");
            name.SetVAlign(inkEVerticalAlign.Center);
            name.Reparent(legend);
            i += 1;
        }

        let selected: Int32 = -1;
        let warCount: Int32 = 0;
        i = 0;
        while i < count {
            if StrLen(wars[i]) > 0 {
                warCount += 1;
                if selected < 0 {
                    selected = i;
                }
            }
            i += 1;
        }
        i = 0;
        while i < count {
            if Equals(keys[i], this.m_selDistrict) {
                selected = i;
            }
            i += 1;
        }
        if selected < 0 {
            selected = 0;
        }
        this.m_selDistrict = keys[selected];
        this.m_summary.SetText(this.T("GR-MenuWars") + " " + IntToString(warCount) + "   |   " + this.T("GR-MenuDistricts") + " " + IntToString(count));

        let columns: array<ref<inkVerticalPanel>>;
        let c: Int32 = 0;
        while c < 4 {
            let column: ref<inkVerticalPanel> = new inkVerticalPanel();
            column.SetAnchor(inkEAnchor.TopLeft);
            column.SetMargin(new inkMargin(120.0 + Cast<Float>(c) * 633.0, 380.0, 0.0, 0.0));
            column.Reparent(this.m_territory);
            ArrayPush(columns, column);
            c += 1;
        }
        let seen: array<String>;
        i = 0;
        while i < count {
            if !ArrayContains(seen, regions[i]) {
                ArrayPush(seen, regions[i]);
            }
            i += 1;
        }
        let columnRegionCount: array<Int32> = [0, 0, 0, 0];
        let r: Int32 = 0;
        while r < ArraySize(seen) {
            let colIndex: Int32 = this.TerritoryColumnFor(seen[r]);
            let column: ref<inkVerticalPanel> = columns[colIndex];
            let stackIndex: Int32 = columnRegionCount[colIndex];
            columnRegionCount[colIndex] = stackIndex + 1;
            let heading: ref<inkText> = this.NewText(this.Up(seen[r]), 26, this.Light(), n"Bold");
            heading.SetMargin(new inkMargin(0.0, stackIndex > 0 ? 22.0 : 0.0, 0.0, 10.0));
            heading.Reparent(column);
            i = 0;
            while i < count {
                if Equals(regions[i], seen[r]) {
                    ArrayPush(this.m_tKeys, keys[i]);
                    this.AddDistrictRow(column, ArraySize(this.m_tKeys) - 1, labels[i], owners[i], influence[i], StrLen(wars[i]) > 0);
                }
                i += 1;
            }
            r += 1;
        }
        i = 0;
        while i < ArraySize(this.m_tKeys) {
            this.StyleDistrict(i, Equals(this.m_tKeys[i], this.m_selDistrict));
            i += 1;
        }

        this.FillGangStrength();

        let detail: ref<inkCanvas> = new inkCanvas();
        detail.SetAnchor(inkEAnchor.TopLeft);
        detail.SetMargin(new inkMargin(2720.0, 392.0, 0.0, 0.0));
        detail.SetSize(new Vector2(1000.0, 1560.0));
        detail.Reparent(this.m_territory);
        this.AddFill(detail, this.Panel(), 0.95);
        this.AddBorder(detail, this.Red(), 2.0, 0.45);
        let content: ref<inkVerticalPanel> = new inkVerticalPanel();
        content.SetAnchor(inkEAnchor.Fill);
        content.SetMargin(new inkMargin(56.0, 48.0, 56.0, 48.0));
        content.Reparent(detail);
        this.m_tDetail = content;
        this.FillDistrictDetail(selected);
    }

    private func FillGangStrength() {
        let gangs: array<String> = this.m_data.StrengthGangs();
        let labels: array<String> = this.m_data.StrengthLabels();
        let values: array<Int32> = this.m_data.StrengthValues();
        let notes: array<String> = this.m_data.StrengthNotes();
        let top: Float = 1640.0;
        this.PlaceText(this.m_territory, this.Up(this.T("GR-MenuGangStrength")), 30, this.Light(), n"Bold", 120.0, top);
        this.PlaceRect(this.m_territory, 520.0, top + 18.0, 2000.0, 2.0, this.Dim(), 1.0);
        let max: Int32 = 1;
        for value in values {
            max = Max(max, value);
        }
        let i: Int32 = 0;
        while i < ArraySize(gangs) {
            let x: Float = 120.0 + Cast<Float>(i % 3) * 840.0;
            let y: Float = top + 62.0 + Cast<Float>(i / 3) * 84.0;
            this.PlaceText(this.m_territory, labels[i], 28, this.GangColor(gangs[i]), n"Bold", x, y);
            this.PlaceRect(this.m_territory, x + 230.0, y + 12.0, 460.0, 14.0, this.Empty(), 1.0);
            this.PlaceRect(this.m_territory, x + 230.0, y + 12.0, 460.0 * Cast<Float>(values[i]) / Cast<Float>(max), 14.0, this.GangColor(gangs[i]), 1.0);
            this.PlaceText(this.m_territory, IntToString(values[i]), 30, this.Light(), n"Bold", x + 710.0, y);
            let lost: String = GRIntegrations.GetDDLostTurfs(gangs[i]);
            let lostText: String = StrLen(lost) > 0 ? this.T("GR-MenuDDLost") + " " + lost : "";
            if StrLen(notes[i]) > 0 {
                let weak: String = this.T("GR-MenuWeakened") + "  " + notes[i];
                this.PlaceText(this.m_territory, StrLen(lostText) > 0 ? weak + "   |   " + lostText : weak, 20, this.Red(), n"Bold", x + 230.0, y + 34.0);
            } else {
                if StrLen(lostText) > 0 {
                    this.PlaceText(this.m_territory, lostText, 20, this.Cyan(), n"Bold", x + 230.0, y + 34.0);
                }
            }
            i += 1;
        }
    }

    private func FillDistrictDetail(index: Int32) {
        let panel: ref<inkVerticalPanel> = this.m_tDetail;
        panel.RemoveAllChildren();
        let keys: array<String> = this.m_data.DistrictKeys();
        let pos: Int32 = -1;
        let i: Int32 = 0;
        while i < ArraySize(keys) {
            if Equals(keys[i], this.m_tKeys[index]) {
                pos = i;
            }
            i += 1;
        }
        if pos < 0 {
            return;
        }
        let labels: array<String> = this.m_data.DistrictLabels();
        let regions: array<String> = this.m_data.DistrictRegions();
        let owners: array<String> = this.m_data.DistrictOwners();
        let influences: array<String> = this.m_data.DistrictInfluence();
        let wars: array<String> = this.m_data.DistrictWars();
        let label: String = labels[pos];
        let region: String = regions[pos];
        let owner: String = owners[pos];
        let influence: String = influences[pos];
        let war: String = wars[pos];
        let width: Float = 888.0;

        this.NewText(this.Up(this.T("GR-MenuDistrict")) + "  |  " + this.Up(region), 24, this.Cyan(), n"Bold").Reparent(panel);
        let name: ref<inkText> = this.NewWrappedText(label, 66, this.Light(), width);
        name.SetFontStyle(n"Bold");
        name.Reparent(panel);
        this.NewText(this.T("GR-MenuControls") + ": " + this.Up(this.InfluenceLabel(influence, owner)), 34, this.GangColor(owner), n"Bold").Reparent(panel);
        let ddState: Int32 = GRIntegrations.GetDDTurfState(keys[pos]);
        if ddState >= 1 {
            let ddKey: String = ddState == 2 ? "GR-MenuDDDetailControlled" : "GR-MenuDDDetailContested";
            let ddText: ref<inkText> = this.NewWrappedText(this.Fmt(this.T(ddKey), "%d", IntToString(GRIntegrations.GetDDTurfValue(keys[pos]))), 28, ddState == 2 ? this.Cyan() : this.Gold(), width);
            ddText.SetMargin(new inkMargin(0.0, 16.0, 0.0, 0.0));
            ddText.Reparent(panel);
        }

        this.AddSection(panel, this.T("GR-MenuInfluence"), 36.0);
        let influenceParts: array<String> = StrSplit(influence, ",");
        for part in influenceParts {
            let fields: array<String> = StrSplit(part, "|");
            if ArraySize(fields) >= 3 {
                let value: Int32 = StringToInt(fields[2]);
                let row: ref<inkCanvas> = new inkCanvas();
                row.SetSize(new Vector2(width, 46.0));
                row.Reparent(panel);
                this.PlaceText(row, fields[1], 30, this.GangColor(fields[0]), n"Bold", 0.0, 0.0);
                this.PlaceRect(row, 250.0, 12.0, 520.0, 18.0, this.Empty(), 1.0);
                this.PlaceRect(row, 250.0, 12.0, 520.0 * Cast<Float>(value) / 100.0, 18.0, this.GangColor(fields[0]), 1.0);
                this.PlaceText(row, IntToString(value) + "%", 30, this.Light(), n"Bold", 800.0, 0.0);
            }
        }

        let w: array<String> = StrSplit(war, "|");
        if ArraySize(w) >= 6 {
            let attacker: String = w[0];
            let defender: String = w[1];
            let sa: Int32 = StringToInt(w[2]);
            let sd: Int32 = StringToInt(w[3]);
            let aName: String = this.InfluenceLabel(influence, attacker);
            let dName: String = this.InfluenceLabel(influence, defender);
            let box: ref<inkCanvas> = new inkCanvas();
            box.SetSize(new Vector2(width, 360.0));
            box.SetMargin(new inkMargin(0.0, 36.0, 0.0, 0.0));
            box.Reparent(panel);
            this.AddFill(box, new HDRColor(0.1, 0.06, 0.09, 1.0), 0.95);
            this.AddBorder(box, this.Red(), 2.0, 1.0);
            this.PlaceText(box, this.T("GR-MenuAtWar"), 28, this.Red(), n"Bold", 28.0, 20.0);
            let day: ref<inkText> = this.NewText(this.Fmt(this.Fmt(this.T("GR-MenuWarDay"), "%d", w[4]), "%d", w[5]), 24, this.Light(), n"Medium");
            day.SetAnchor(inkEAnchor.TopRight);
            day.SetAnchorPoint(new Vector2(1.0, 0.0));
            day.SetMargin(new inkMargin(0.0, 24.0, 28.0, 0.0));
            day.Reparent(box);

            this.PlaceText(box, this.T("GR-MenuAttacks"), 20, this.Grey(), n"Bold", 28.0, 76.0);
            this.PlaceText(box, aName, 40, this.GangColor(attacker), n"Bold", 28.0, 100.0);
            this.PlaceText(box, this.T("GR-MenuStrength") + " " + IntToString(sa), 28, this.Light(), n"Regular", 28.0, 150.0);
            this.PlaceText(box, "VS", 28, this.Grey(), n"Bold", 426.0, 112.0);
            let rightTexts: array<String> = [this.T("GR-MenuDefends"), dName, this.T("GR-MenuStrength") + " " + IntToString(sd)];
            let rightSizes: array<Int32> = [20, 40, 28];
            let rightY: array<Float> = [76.0, 100.0, 150.0];
            let k: Int32 = 0;
            while k < 3 {
                let t: ref<inkText> = this.NewText(rightTexts[k], rightSizes[k], k == 1 ? this.GangColor(defender) : (k == 0 ? this.Grey() : this.Light()), k == 2 ? n"Regular" : n"Bold");
                t.SetAnchor(inkEAnchor.TopRight);
                t.SetAnchorPoint(new Vector2(1.0, 0.0));
                t.SetMargin(new inkMargin(0.0, rightY[k], 28.0, 0.0));
                t.Reparent(box);
                k += 1;
            }
            let share: Float = Cast<Float>(sa) / Cast<Float>(Max(1, sa + sd));
            this.PlaceRect(box, 28.0, 204.0, 832.0 * share, 14.0, this.GangColor(attacker), 1.0);
            this.PlaceRect(box, 28.0 + 832.0 * share + 4.0, 204.0, MaxF(0.0, 832.0 * (1.0 - share) - 4.0), 14.0, this.GangColor(defender), 1.0);
            let trend: String = sa > sd ? this.Fmt(this.T("GR-MenuWarGaining"), "%s", aName) : this.Fmt(this.T("GR-MenuWarHolding"), "%s", dName);
            let trendText: ref<inkText> = this.NewWrappedText(trend, 30, this.Light(), 832.0);
            trendText.SetAnchor(inkEAnchor.TopLeft);
            trendText.SetMargin(new inkMargin(28.0, 236.0, 0.0, 0.0));
            trendText.Reparent(box);
            let note: ref<inkText> = this.NewWrappedText(this.T("GR-MenuWarSkirmish"), 24, this.Grey(), 832.0);
            note.SetAnchor(inkEAnchor.TopLeft);
            note.SetMargin(new inkMargin(28.0, 286.0, 0.0, 0.0));
            note.Reparent(box);
        } else {
            let calm: ref<inkText> = this.NewWrappedText(this.T("GR-MenuNoWar"), 30, this.Light(), width);
            calm.SetMargin(new inkMargin(0.0, 36.0, 0.0, 0.0));
            calm.Reparent(panel);
        }

        this.AddSection(panel, this.T("GR-MenuRumors"), 44.0);
        let days: array<String> = this.m_data.RumorDays();
        let texts: array<String> = this.m_data.RumorTexts();
        if ArraySize(texts) == 0 {
            this.NewWrappedText(this.T("GR-MenuNoRumors"), 28, this.Grey(), width).Reparent(panel);
        }
        i = 0;
        while i < Min(ArraySize(texts), 5) {
            this.AddRumorRow(panel, days[i], texts[i], width);
            i += 1;
        }
    }

    protected cb func OnGRDistrictClick(evt: ref<inkPointerEvent>) -> Bool {
        if !evt.IsAction(n"click") {
            return false;
        }
        let target: CName = evt.GetCurrentTarget().GetName();
        let i: Int32 = 0;
        while i < ArraySize(this.m_tKeys) {
            if Equals(target, StringToName("gr_dist_" + IntToString(i))) {
                this.m_selDistrict = this.m_tKeys[i];
                let j: Int32 = 0;
                while j < ArraySize(this.m_tKeys) {
                    this.StyleDistrict(j, j == i);
                    j += 1;
                }
                this.FillDistrictDetail(i);
                this.BringToFront();
                this.PlaySound(n"Button", n"OnPress");
                return true;
            }
            i += 1;
        }
        return false;
    }

    private func ArsenalGangs() -> array<String> {
        return ["Maelstrom", "TygerClaws", "Valentinos", "SixthStreet", "Animals", "VoodooBoys", "Wraiths", "Scavengers", "Barghest"];
    }

    private func ArsenalGangLabel(gang: String) -> String {
        if Equals(gang, "TygerClaws") {
            return "Tyger Claws";
        }
        if Equals(gang, "SixthStreet") {
            return "6th Street";
        }
        if Equals(gang, "VoodooBoys") {
            return "Voodoo Boys";
        }
        if Equals(gang, "Scavengers") {
            return "Scavs";
        }
        return gang;
    }

    private func ElementColor(element: Int32) -> HDRColor {
        if element == 0 {
            return new HDRColor(0.435, 0.659, 1.0, 1.0);
        }
        if element == 1 {
            return new HDRColor(1.0, 0.6, 0.239, 1.0);
        }
        if element == 2 {
            return new HDRColor(0.478, 0.851, 0.361, 1.0);
        }
        return this.Grey();
    }

    private func ElementText(element: Int32) -> String {
        if element < 0 || element > 2 {
            return "";
        }
        return this.Up(this.T("GR-MenuDmg-" + IntToString(element)));
    }

    private func StyleArsenalTab(index: Int32, label: String, active: Bool, hasWeapons: Bool) {
        this.m_tabTexts[index].SetText(this.Up(label));
        this.m_tabTexts[index].SetTintColor(active ? this.Cyan() : (hasWeapons ? this.Grey() : this.Dim()));
        this.m_tabBars[index].SetSize(new Vector2(236.0, active ? 8.0 : 4.0));
        this.m_tabBars[index].SetTintColor(active ? this.Cyan() : this.DarkRed());
        this.m_tabThreats[index].SetVisible(false);
    }

    private func NewBonusBar(bonus: Float, color: HDRColor, width: Float, height: Float) -> ref<inkCanvas> {
        let bar: ref<inkCanvas> = new inkCanvas();
        bar.SetSize(new Vector2(width, height + 16.0));
        this.PlaceRect(bar, 0.0, 8.0, width, height, this.Empty(), 1.0);
        let share: Float = MinF(1.0, MaxF(0.0, bonus / 60.0));
        if share > 0.0 {
            this.PlaceRect(bar, 0.0, 8.0, width * share, height, color, 1.0);
        }
        this.PlaceRect(bar, width / 3.0 - 1.5, 0.0, 3.0, height + 16.0, this.Dim(), 1.0);
        this.PlaceRect(bar, width * 2.0 / 3.0 - 1.5, 0.0, 3.0, height + 16.0, this.Dim(), 1.0);
        this.PlaceRect(bar, width - 3.0, 0.0, 3.0, height + 16.0, this.Red(), 1.0);
        return bar;
    }

    private func NewBonusScale(width: Float) -> ref<inkCanvas> {
        let scale: ref<inkCanvas> = new inkCanvas();
        scale.SetSize(new Vector2(width, 34.0));
        this.PlaceText(scale, "0", 22, this.Dim(), n"Medium", 0.0, 4.0);
        let low: ref<inkText> = this.PlaceText(scale, "20 %", 22, this.Dim(), n"Medium", width / 3.0, 4.0);
        low.SetAnchorPoint(new Vector2(0.5, 0.0));
        let mid: ref<inkText> = this.PlaceText(scale, "40 %", 22, this.Dim(), n"Medium", width * 2.0 / 3.0, 4.0);
        mid.SetAnchorPoint(new Vector2(0.5, 0.0));
        let cap: ref<inkText> = this.PlaceText(scale, "60 %", 22, this.Red(), n"Medium", width, 4.0);
        cap.SetAnchorPoint(new Vector2(1.0, 0.0));
        return scale;
    }

    private func AddWeaponIcon(box: ref<inkCanvas>, weaponIndex: Int32, boxW: Float, boxH: Float) {
        let aspect: Float = MaxF(0.1, this.m_rewards.GetOwnedIconAspect(weaponIndex));
        let w: Float = boxW;
        let h: Float = boxW / aspect;
        if h > boxH {
            h = boxH;
            w = boxH * aspect;
        }
        let icon: ref<inkImage> = new inkImage();
        icon.SetAnchor(inkEAnchor.Centered);
        icon.SetAnchorPoint(new Vector2(0.5, 0.5));
        icon.SetSize(new Vector2(w, h));
        icon.Reparent(box);
        this.RequestWeaponIcon(icon, weaponIndex);
    }

    private func RequestWeaponIcon(icon: ref<inkImage>, weaponIndex: Int32) {
        let recordID: TweakDBID = this.m_rewards.GetOwnedRecord(weaponIndex);
        let record: ref<Item_Record> = TweakDBInterface.GetItemRecord(recordID);
        if !IsDefined(record) {
            return;
        }
        let player: wref<PlayerPuppet> = this.GetPlayerControlledObject() as PlayerPuppet;
        let iconName: String = UIInventoryItemsManager.ResolveItemIconName(recordID, record, player);
        if IsStringValid(iconName) {
            InkImageUtils.RequestSetImage(this, icon, iconName);
        }
    }

    private func NewElementRow(weaponIndex: Int32, valueSize: Int32, labelSize: Int32) -> ref<inkHorizontalPanel> {
        return this.NewElementRowOf(this.m_rewards.GetOwnedElement(weaponIndex), this.m_rewards.GetOwnedBonusF(weaponIndex), valueSize, labelSize);
    }

    private func NewElementRowOf(element: Int32, bonus: Float, valueSize: Int32, labelSize: Int32) -> ref<inkHorizontalPanel> {
        let color: HDRColor = this.ElementColor(element);
        let row: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        let value: ref<inkText> = this.NewText("+" + this.BonusText(bonus) + " %", valueSize, color, n"Bold");
        value.SetVAlign(inkEVerticalAlign.Center);
        value.Reparent(row);
        let label: ref<inkText> = this.NewText(this.ElementText(element), labelSize, color, n"Bold");
        label.SetVAlign(inkEVerticalAlign.Center);
        label.SetMargin(new inkMargin(Cast<Float>(labelSize) * 0.6, 0.0, 0.0, 0.0));
        label.Reparent(row);
        return row;
    }

    private func StyleWeaponFrame(cardIndex: Int32, selected: Bool) {
        let frame: wref<inkImage> = this.m_aFrames[cardIndex];
        frame.SetTintColor(selected ? this.Cyan() : (cardIndex == 0 ? this.Gold() : this.Dim()));
        frame.SetOpacity(1.0);
    }

    private func AddWeaponCard(weaponIndex: Int32, x: Float, y: Float, w: Float, h: Float, big: Bool) {
        let index: Int32 = ArraySize(this.m_aCards);
        ArrayPush(this.m_aCards, weaponIndex);
        let name: String = this.m_rewards.GetOwnedName(weaponIndex);
        let equipped: Bool = this.m_rewards.IsOwnedEquipped(weaponIndex);
        let stashed: Bool = this.m_rewards.IsOwnedStashed(weaponIndex);

        let card: ref<inkCanvas> = new inkCanvas();
        card.SetName(StringToName("gr_weapon_" + IntToString(index)));
        card.SetAnchor(inkEAnchor.TopLeft);
        card.SetMargin(new inkMargin(x, y, 0.0, 0.0));
        card.SetSize(new Vector2(w, h));
        card.SetInteractive(true);
        card.RegisterToCallback(n"OnRelease", this, n"OnGRWeaponClick");
        card.Reparent(this.m_arsenal);

        let bg: ref<inkImage> = new inkImage();
        bg.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
        bg.SetTexturePart(n"cell_bg");
        bg.SetNineSliceScale(true);
        bg.SetAnchor(inkEAnchor.Fill);
        bg.SetTintColor(this.Dark());
        bg.SetOpacity(0.95);
        bg.Reparent(card);

        let frame: ref<inkImage> = new inkImage();
        frame.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
        frame.SetTexturePart(n"cell_fg");
        frame.SetNineSliceScale(true);
        frame.SetAnchor(inkEAnchor.Fill);
        frame.Reparent(card);
        ArrayPush(this.m_aFrames, frame);
        this.StyleWeaponFrame(index, weaponIndex == this.m_selWeapon);

        if big {
            let iconBox: ref<inkCanvas> = new inkCanvas();
            iconBox.SetAnchor(inkEAnchor.TopLeft);
            iconBox.SetMargin(new inkMargin(70.0, 190.0, 0.0, 0.0));
            iconBox.SetSize(new Vector2(1060.0, 298.0));
            iconBox.Reparent(card);
            this.AddWeaponIcon(iconBox, weaponIndex, 1060.0, 298.0);
            this.PlaceText(card, this.Up(this.m_rewards.GetOwnedBaseName(weaponIndex)) + "  |  " + this.Up(this.ArsenalGangLabel(this.m_rewards.GetOwnedGang(weaponIndex))),
                28, this.Dim(), n"Medium", 80.0, 560.0);

            let column: ref<inkVerticalPanel> = new inkVerticalPanel();
            column.SetAnchor(inkEAnchor.TopLeft);
            column.SetMargin(new inkMargin(1240.0, 60.0, 0.0, 0.0));
            column.Reparent(card);
            if equipped {
                let tag: ref<inkCompoundWidget> = this.NewTag(this.T("GR-MenuEquipped"), 26, this.Cyan());
                tag.SetHAlign(inkEHorizontalAlign.Left);
                tag.SetMargin(new inkMargin(0.0, 0.0, 0.0, 18.0));
                tag.Reparent(column);
            }
            if stashed {
                let stashTag: ref<inkCompoundWidget> = this.NewTag(this.T("GR-MenuInStash"), 26, this.Grey());
                stashTag.SetHAlign(inkEHorizontalAlign.Left);
                stashTag.SetMargin(new inkMargin(0.0, 0.0, 0.0, 18.0));
                stashTag.Reparent(column);
            }
            let title: ref<inkText> = this.NewWrappedText(name, 80, this.Gold(), 1170.0);
            title.SetFontStyle(n"Bold");
            title.Reparent(column);
            let elementRow: ref<inkHorizontalPanel> = this.NewElementRow(weaponIndex, 110, 40);
            elementRow.SetMargin(new inkMargin(0.0, 30.0, 0.0, 8.0));
            elementRow.Reparent(column);
            this.NewBonusBar(this.m_rewards.GetOwnedBonusF(weaponIndex), this.ElementColor(this.m_rewards.GetOwnedElement(weaponIndex)), 1150.0, 22.0).Reparent(column);
            this.NewBonusScale(1150.0).Reparent(column);
            let level: ref<inkText> = this.NewText(this.Up(this.T("GR-MenuQuality")) + " " + this.Up(this.m_rewards.GetOwnedTier(weaponIndex)) + "   |   " + this.T("GR-MenuDamage") + " "
                + IntToString(RoundF(this.m_rewards.GetOwnedDamage(weaponIndex))), 34, this.Grey(), n"Bold");
            level.SetMargin(new inkMargin(0.0, 18.0, 0.0, 0.0));
            level.Reparent(column);
        } else {
            let content: ref<inkVerticalPanel> = new inkVerticalPanel();
            content.SetAnchor(inkEAnchor.Fill);
            content.SetMargin(new inkMargin(30.0, 18.0, 30.0, 12.0));
            content.Reparent(card);

            let top: ref<inkHorizontalPanel> = new inkHorizontalPanel();
            top.Reparent(content);
            let smallBox: ref<inkCanvas> = new inkCanvas();
            smallBox.SetSize(new Vector2(240.0, 68.0));
            smallBox.SetVAlign(inkEVerticalAlign.Center);
            smallBox.Reparent(top);
            this.AddWeaponIcon(smallBox, weaponIndex, 240.0, 68.0);
            if equipped {
                let smallTag: ref<inkCompoundWidget> = this.NewTag(this.T("GR-MenuEquipped"), 20, this.Cyan());
                smallTag.SetMargin(new inkMargin(16.0, 0.0, 0.0, 0.0));
                smallTag.Reparent(top);
            }
            if stashed {
                let smallStash: ref<inkCompoundWidget> = this.NewTag(this.T("GR-MenuInStash"), 20, this.Grey());
                smallStash.SetMargin(new inkMargin(16.0, 0.0, 0.0, 0.0));
                smallStash.Reparent(top);
            }
            let smallName: ref<inkText> = this.NewWrappedText(name, 36, this.Light(), 540.0);
            smallName.SetFontStyle(n"Bold");
            smallName.SetMargin(new inkMargin(0.0, 8.0, 0.0, 0.0));
            smallName.Reparent(content);
            this.NewElementRow(weaponIndex, 40, 24).Reparent(content);
        }
    }

    private func FillWeaponDetail(weaponIndex: Int32) {
        let panel: ref<inkVerticalPanel> = this.m_aDetail;
        panel.RemoveAllChildren();
        if weaponIndex < 0 || !IsDefined(this.m_rewards) {
            return;
        }
        let width: Float = 888.0;
        let element: Int32 = this.m_rewards.GetOwnedElement(weaponIndex);
        let bonus: Float = this.m_rewards.GetOwnedBonusF(weaponIndex);

        this.NewText(this.Up(this.T("GR-MenuUniqueWeapon")) + "  |  " + this.Up(this.ArsenalGangLabel(this.m_rewards.GetOwnedGang(weaponIndex))), 28, this.Cyan(), n"Bold").Reparent(panel);
        let name: ref<inkText> = this.NewWrappedText(this.m_rewards.GetOwnedName(weaponIndex), 66, this.Gold(), width);
        name.SetFontStyle(n"Bold");
        name.Reparent(panel);
        this.NewText(this.m_rewards.GetOwnedBaseName(weaponIndex), 36, this.Grey(), n"Regular").Reparent(panel);
        if this.m_rewards.IsOwnedEquipped(weaponIndex) {
            let tag: ref<inkCompoundWidget> = this.NewTag(this.T("GR-MenuEquipped"), 26, this.Cyan());
            tag.SetHAlign(inkEHorizontalAlign.Left);
            tag.SetMargin(new inkMargin(0.0, 24.0, 0.0, 0.0));
            tag.Reparent(panel);
        }
        if this.m_rewards.IsOwnedStashed(weaponIndex) {
            let stashTag: ref<inkCompoundWidget> = this.NewTag(this.T("GR-MenuInStash"), 26, this.Grey());
            stashTag.SetHAlign(inkEHorizontalAlign.Left);
            stashTag.SetMargin(new inkMargin(0.0, 24.0, 0.0, 0.0));
            stashTag.Reparent(panel);
        }

        this.AddSection(panel, this.T("GR-MenuElement"), 44.0);
        this.NewElementRow(weaponIndex, 72, 30).Reparent(panel);
        let bar: ref<inkCanvas> = this.NewBonusBar(bonus, this.ElementColor(element), width, 22.0);
        bar.SetMargin(new inkMargin(0.0, 8.0, 0.0, 0.0));
        bar.Reparent(panel);
        this.NewBonusScale(width).Reparent(panel);

        let augment: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        augment.SetMargin(new inkMargin(0.0, 30.0, 0.0, 0.0));
        augment.Reparent(panel);
        let augmentLabel: ref<inkText> = this.NewText(this.Up(this.T("GR-MenuAugLevel")), 34, this.Light(), n"Bold");
        augmentLabel.SetVAlign(inkEVerticalAlign.Center);
        augmentLabel.SetMargin(new inkMargin(0.0, 0.0, 24.0, 0.0));
        augmentLabel.Reparent(augment);
        this.NewLevelRow(this.m_rewards.GetOwnedLevel(weaponIndex), 26.0, 40, 28).Reparent(augment);

        this.AddSection(panel, this.T("GR-MenuChance"), 32.0);
        this.NewText(this.BonusText(bonus) + " %", 72, this.Light(), n"Bold").Reparent(panel);
        if element >= 0 && element <= 2 {
            this.NewWrappedText(this.T("GR-MenuProc-" + IntToString(element)), 34, this.Light(), width).Reparent(panel);
        }

        let stats: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        stats.SetMargin(new inkMargin(0.0, 30.0, 0.0, 0.0));
        stats.Reparent(panel);
        this.AddStat(stats, RoundF(this.m_rewards.GetOwnedDamage(weaponIndex)), this.T("GR-MenuDamage"));
        let quality: ref<inkVerticalPanel> = new inkVerticalPanel();
        quality.SetVAlign(inkEVerticalAlign.Center);
        quality.SetMargin(new inkMargin(20.0, 0.0, 0.0, 0.0));
        quality.Reparent(stats);
        this.NewText(this.Up(this.T("GR-MenuQuality")), 24, this.Light(), n"Bold").Reparent(quality);
        this.NewText(this.Up(this.m_rewards.GetOwnedTier(weaponIndex)), 44, this.Gold(), n"Bold").Reparent(quality);

        let boss: String = this.m_rewards.GetOwnedBossName(weaponIndex);
        if StrLen(boss) > 0 {
            let origin: ref<inkText> = this.NewWrappedText(this.T("GR-MenuOrigin") + ": " + this.Fmt(this.T("GR-MenuWeaponOrigin"), "%s", boss), 32, this.Light(), width);
            origin.SetMargin(new inkMargin(0.0, 20.0, 0.0, 0.0));
            origin.Reparent(panel);
        }
        this.UpdateAugmentButton();
    }

    private func FillArsenal() {
        this.m_arsenal.RemoveAllChildren();
        ArrayClear(this.m_aCards);
        ArrayClear(this.m_aFrames);
        let gangs: array<String> = this.ArsenalGangs();
        let count: Int32 = ArraySize(gangs);
        this.m_arsenalPage = ((this.m_arsenalPage % count) + count) % count;
        let gangKey: String = gangs[this.m_arsenalPage];
        let owned: Int32 = IsDefined(this.m_rewards) ? this.m_rewards.GetOwnedCount() : 0;

        let i: Int32 = 0;
        if ArraySize(this.m_tabTexts) != count {
            this.m_marks.RemoveAllChildren();
            ArrayClear(this.m_tabTexts);
            ArrayClear(this.m_tabBars);
            ArrayClear(this.m_tabThreats);
            while i < count {
                this.AddTab(i);
                i += 1;
            }
        }
        let list: array<Int32>;
        let main: Int32 = this.ArsenalMain(gangKey);
        i = 0;
        while i < count {
            let hasWeapons: Bool = false;
            let w: Int32 = 0;
            while w < owned {
                if Equals(this.m_rewards.GetOwnedGang(w), gangs[i]) {
                    hasWeapons = true;
                    if i == this.m_arsenalPage {
                        ArrayPush(list, w);
                    }
                }
                w += 1;
            }
            this.StyleArsenalTab(i, this.ArsenalGangLabel(gangs[i]), i == this.m_arsenalPage, hasWeapons);
            i += 1;
        }

        this.m_gangTitle.SetText(this.Up(this.ArsenalGangLabel(gangKey)));
        this.m_gangCount.SetText(IntToString(ArraySize(list)));
        this.m_summary.SetText(this.T("GR-MenuWeapons") + " " + IntToString(owned));

        if ArraySize(list) == 0 {
            this.m_selWeapon = -1;
            let empty: ref<inkText> = this.NewWrappedText(this.T("GR-MenuNoWeapons"), 44, this.Grey(), 2400.0);
            empty.SetAnchor(inkEAnchor.TopLeft);
            empty.SetMargin(new inkMargin(120.0, 470.0, 0.0, 0.0));
            empty.Reparent(this.m_arsenal);
            return;
        }
        if !ArrayContains(list, this.m_selWeapon) {
            this.m_selWeapon = main;
        }

        this.PlaceText(this.m_arsenal, this.Up(this.T("GR-MenuMainWeapon")), 30, this.Grey(), n"Bold", 120.0, 400.0);
        this.AddWeaponCard(main, 120.0, 450.0, 2480.0, 700.0, true);

        this.PlaceText(this.m_arsenal, this.Up(this.T("GR-MenuCopies")) + "  ·  " + IntToString(ArraySize(list) - 1), 30, this.Grey(), n"Bold", 120.0, 1210.0);
        let shown: Int32 = 0;
        for weapon in list {
            if weapon != main && shown < 8 {
                this.AddWeaponCard(weapon, 120.0 + Cast<Float>(shown % 4) * 640.0, 1260.0 + Cast<Float>(shown / 4) * 330.0, 600.0, 290.0, false);
                shown += 1;
            }
        }

        let detail: ref<inkCanvas> = new inkCanvas();
        detail.SetAnchor(inkEAnchor.TopLeft);
        detail.SetMargin(new inkMargin(2720.0, 400.0, 0.0, 0.0));
        detail.SetSize(new Vector2(1000.0, 1520.0));
        detail.Reparent(this.m_arsenal);
        this.AddFill(detail, this.Panel(), 0.95);
        this.AddBorder(detail, this.Red(), 2.0, 0.45);
        let content: ref<inkVerticalPanel> = new inkVerticalPanel();
        content.SetAnchor(inkEAnchor.Fill);
        content.SetMargin(new inkMargin(56.0, 52.0, 56.0, 52.0));
        content.Reparent(detail);
        this.m_aDetail = content;
        this.AddAugmentButton(detail);
        this.FillWeaponDetail(this.m_selWeapon);
    }

    private func ArsenalMain(gangKey: String) -> Int32 {
        let main: Int32 = -1;
        let mainScore: Int32 = -1;
        let owned: Int32 = IsDefined(this.m_rewards) ? this.m_rewards.GetOwnedCount() : 0;
        let w: Int32 = 0;
        while w < owned {
            if Equals(this.m_rewards.GetOwnedGang(w), gangKey) {
                let score: Int32 = RoundF(this.m_rewards.GetOwnedBonusF(w) * 10.0) + (this.m_rewards.IsOwnedEquipped(w) ? 10000 : 0)
                    + (this.m_rewards.IsOwnedStashed(w) ? 0 : 20000);
                if score > mainScore {
                    mainScore = score;
                    main = w;
                }
            }
            w += 1;
        }
        return main;
    }

    private func BonusText(bonus: Float) -> String {
        let rounded: Int32 = RoundF(bonus);
        if AbsF(bonus - Cast<Float>(rounded)) < 0.05 {
            return IntToString(rounded);
        }
        let separator: String = this.T("GR-MenuDecimal");
        if StrLen(separator) != 1 {
            separator = ".";
        }
        return StrReplace(FloatToStringPrec(bonus, 1), ".", separator);
    }

    private func Roman(level: Int32) -> String {
        let numerals: array<String> = ["I", "II", "III", "IV", "V"];
        return numerals[Min(5, Max(1, level)) - 1];
    }

    private func NewLevelRow(level: Int32, pipSize: Float, romanSize: Int32, noteSize: Int32) -> ref<inkHorizontalPanel> {
        let row: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        let i: Int32 = 1;
        while i <= 5 {
            let pip: ref<inkRectangle> = this.NewRect(pipSize, pipSize, i <= level ? this.Gold() : this.Empty(), 1.0);
            pip.SetVAlign(inkEVerticalAlign.Center);
            pip.SetMargin(new inkMargin(pipSize * 0.25, 0.0, pipSize * 0.35, 0.0));
            pip.SetRenderTransformPivot(new Vector2(0.5, 0.5));
            pip.SetRotation(45.0);
            pip.Reparent(row);
            i += 1;
        }
        let roman: ref<inkText> = this.NewText(this.Roman(level), romanSize, this.Gold(), n"Bold");
        roman.SetVAlign(inkEVerticalAlign.Center);
        roman.SetMargin(new inkMargin(pipSize * 0.6, 0.0, 0.0, 0.0));
        roman.Reparent(row);
        if level > 1 {
            let note: ref<inkText> = this.NewText("+" + IntToString((level - 1) * 5) + " % " + this.T("GR-MenuDamage"), noteSize, this.Grey(), n"Medium");
            note.SetVAlign(inkEVerticalAlign.Center);
            note.SetMargin(new inkMargin(Cast<Float>(noteSize) * 0.7, 0.0, 0.0, 0.0));
            note.Reparent(row);
        }
        return row;
    }

    private func FusableCopies(main: Int32) -> array<Int32> {
        let result: array<Int32>;
        if main < 0 || !IsDefined(this.m_rewards) {
            return result;
        }
        let gang: String = this.m_rewards.GetOwnedGang(main);
        let owned: Int32 = this.m_rewards.GetOwnedCount();
        let w: Int32 = 0;
        while w < owned {
            if w != main && Equals(this.m_rewards.GetOwnedGang(w), gang) && !this.m_rewards.IsOwnedEquipped(w) && !this.m_rewards.IsOwnedStashed(w) {
                ArrayPush(result, w);
            }
            w += 1;
        }
        return result;
    }

    private func HasStashedCopy(main: Int32) -> Bool {
        if main < 0 || !IsDefined(this.m_rewards) {
            return false;
        }
        let gang: String = this.m_rewards.GetOwnedGang(main);
        let owned: Int32 = this.m_rewards.GetOwnedCount();
        let w: Int32 = 0;
        while w < owned {
            if w != main && Equals(this.m_rewards.GetOwnedGang(w), gang) && this.m_rewards.IsOwnedStashed(w) {
                return true;
            }
            w += 1;
        }
        return false;
    }

    private func AddAugmentButton(detail: ref<inkCanvas>) {
        let button: ref<inkCanvas> = new inkCanvas();
        button.SetName(n"gr_augment");
        button.SetAnchor(inkEAnchor.TopLeft);
        button.SetMargin(new inkMargin(56.0, 1318.0, 0.0, 0.0));
        button.SetSize(new Vector2(888.0, 150.0));
        button.SetInteractive(true);
        button.RegisterToCallback(n"OnRelease", this, n"OnGRAugmentClick");
        button.Reparent(detail);
        this.AddFill(button, this.Dark(), 0.9);
        let border: ref<GRBorder> = new GRBorder();
        border.SetAnchor(inkEAnchor.Fill);
        border.SetThickness(3.0);
        border.Reparent(button);
        this.m_augBorder = border;
        this.m_augTitle = this.PlaceText(button, this.Up(this.T("GR-MenuAugment")), 58, this.Cyan(), n"Bold", 36.0, 12.0);
        this.m_augSub = this.PlaceText(button, "", 28, this.Light(), n"Medium", 36.0, 88.0);
    }

    private func UpdateAugmentButton() {
        this.m_augReady = false;
        if ArraySize(this.m_aCards) == 0 || !IsDefined(this.m_augBorder) || !IsDefined(this.m_rewards) {
            return;
        }
        let main: Int32 = this.m_aCards[0];
        let copies: array<Int32> = this.FusableCopies(main);
        let count: Int32 = ArraySize(copies);
        let text: String;
        if this.m_rewards.IsOwnedMaxed(main) {
            text = this.T("GR-MenuAugMaxed");
        } else if this.m_rewards.IsOwnedStashed(main) || (count == 0 && this.HasStashedCopy(main)) {
            text = this.T("GR-MenuAugStashed");
        } else if count == 0 {
            text = this.Fmt(this.T("GR-MenuAugNoCopies"), "%s", this.ArsenalGangLabel(this.m_rewards.GetOwnedGang(main)));
        } else {
            this.m_augReady = true;
            text = count == 1 ? this.T("GR-MenuAugReadyOne") : this.Fmt(this.T("GR-MenuAugReady"), "%d", IntToString(count));
        }
        this.m_augBorder.SetTintColor(this.m_augReady ? this.Cyan() : this.Dim());
        this.m_augTitle.SetTintColor(this.m_augReady ? this.Cyan() : this.Dim());
        this.m_augSub.SetText(text);
        this.m_augSub.SetTintColor(this.m_augReady ? this.Light() : this.Grey());
    }

    protected cb func OnGRAugmentClick(evt: ref<inkPointerEvent>) -> Bool {
        if !evt.IsAction(n"click") || this.m_fOpen || !this.m_augReady {
            return false;
        }
        this.OpenFusion();
        return true;
    }

    private func CreateFusion(root: ref<inkCompoundWidget>) {
        let layer: ref<inkCanvas> = new inkCanvas();
        layer.SetName(n"fusion");
        layer.SetAnchor(inkEAnchor.Fill);
        layer.SetVisible(false);
        layer.Reparent(root);
        this.m_fusion = layer;

        let scrim: ref<inkRectangle> = new inkRectangle();
        scrim.SetAnchor(inkEAnchor.Fill);
        scrim.SetMargin(new inkMargin(0.0, 150.0, 0.0, 0.0));
        scrim.SetTintColor(this.Dark());
        scrim.SetOpacity(0.6);
        scrim.SetInteractive(true);
        scrim.Reparent(layer);
        let backdrop: ref<inkRectangle> = new inkRectangle();
        backdrop.SetAnchor(inkEAnchor.Fill);
        backdrop.SetMargin(new inkMargin(0.0, 339.0, 0.0, 0.0));
        backdrop.SetTintColor(this.Panel());
        backdrop.SetOpacity(0.97);
        backdrop.Reparent(layer);

        let panel: ref<inkCanvas> = new inkCanvas();
        panel.SetAnchor(inkEAnchor.TopLeft);
        panel.SetMargin(new inkMargin(420.0, 380.0, 0.0, 0.0));
        panel.SetSize(new Vector2(3000.0, 1500.0));
        panel.Reparent(layer);
        this.AddFill(panel, this.Panel(), 0.97);
        this.AddBorder(panel, this.Red(), 2.0, 0.6);

        let content: ref<inkCanvas> = new inkCanvas();
        content.SetAnchor(inkEAnchor.Fill);
        content.Reparent(panel);
        this.m_fContent = content;

        this.AddFusionButton(panel, 1600.0, 312.0, 64.0, 64.0, 40);
        this.AddFusionButton(panel, 1772.0, 312.0, 64.0, 64.0, 40);
        this.AddFusionButton(panel, 520.0, 996.0, 440.0, 80.0, 34);
        this.AddFusionButton(panel, 988.0, 996.0, 440.0, 80.0, 34);
        this.AddFusionButton(panel, 850.0, 1280.0, 1300.0, 130.0, 48);
        this.AddFusionButton(panel, 80.0, 1305.0, 520.0, 80.0, 34);
        let fuse: wref<inkCanvas> = this.m_fButtons[4];
        fuse.RegisterToCallback(n"OnHold", this, n"OnGRFuseHold");
        fuse.RegisterToCallback(n"OnHoverOut", this, n"OnGRFuseHoverOut");
    }

    private func AddFusionButton(panel: ref<inkCompoundWidget>, x: Float, y: Float, w: Float, h: Float, fontSize: Int32) {
        let index: Int32 = ArraySize(this.m_fButtons);
        let button: ref<inkCanvas> = new inkCanvas();
        button.SetName(StringToName("gr_fuse_" + IntToString(index)));
        button.SetAnchor(inkEAnchor.TopLeft);
        button.SetMargin(new inkMargin(x, y, 0.0, 0.0));
        button.SetSize(new Vector2(w, h));
        button.SetInteractive(true);
        button.RegisterToCallback(n"OnRelease", this, n"OnGRFusionClick");
        button.Reparent(panel);
        this.AddFill(button, this.Dark(), 0.9);
        if index == 4 {
            let progress: ref<inkRectangle> = this.NewRect(0.0, h, this.Cyan(), 0.22);
            progress.SetAnchor(inkEAnchor.TopLeft);
            progress.Reparent(button);
            this.m_fProgress = progress;
        }
        let border: ref<GRBorder> = new GRBorder();
        border.SetAnchor(inkEAnchor.Fill);
        border.SetThickness(3.0);
        border.SetTintColor(this.Cyan());
        border.Reparent(button);
        let label: ref<inkText> = this.NewText("", fontSize, this.Cyan(), n"Bold");
        label.SetAnchor(inkEAnchor.Centered);
        label.SetAnchorPoint(new Vector2(0.5, 0.5));
        label.Reparent(button);
        ArrayPush(this.m_fButtons, button);
        ArrayPush(this.m_fBorders, border);
        ArrayPush(this.m_fLabels, label);
    }

    private func StyleFusionButton(index: Int32, visible: Bool, text: String, textColor: HDRColor, borderColor: HDRColor) {
        this.m_fButtons[index].SetVisible(visible);
        this.m_fBorders[index].SetTintColor(borderColor);
        this.m_fLabels[index].SetText(text);
        this.m_fLabels[index].SetTintColor(textColor);
    }

    private func SetFuseProgress(progress: Float) {
        this.m_fProgress.SetSize(new Vector2(1300.0 * MinF(1.0, MaxF(0.0, progress)), 130.0));
    }

    private func FusionKeep() -> Int32 {
        if this.m_fKeep >= 0 {
            return this.m_fKeep;
        }
        if ArraySize(this.m_fChoices) > 0 {
            return this.m_fChoices[0];
        }
        return -1;
    }

    private func OpenFusion() {
        if ArraySize(this.m_aCards) == 0 || !IsDefined(this.m_rewards) {
            return;
        }
        let main: Int32 = this.m_aCards[0];
        if this.m_rewards.IsOwnedStashed(main) {
            return;
        }
        let copies: array<Int32> = this.FusableCopies(main);
        if ArraySize(copies) == 0 {
            return;
        }
        this.m_fMain = main;
        this.m_fCopies = copies;
        this.m_fCopy = 0;
        let i: Int32 = 0;
        while i < ArraySize(copies) {
            if copies[i] == this.m_selWeapon {
                this.m_fCopy = i;
            }
            i += 1;
        }
        this.m_fKeep = -1;
        this.m_fDone = false;
        this.m_fConfirm = false;
        this.m_fOpen = true;
        this.m_arsenal.SetVisible(false);
        this.m_fusion.SetVisible(true);
        this.RefreshFusion();
        if IsDefined(this.m_buttonHints) {
            this.m_buttonHints.AddButtonHint(n"back", this.T("GR-MenuAugBack"));
        }
        this.BringToFront();
        this.PlaySound(n"Button", n"OnPress");
    }

    private func CloseFusion() {
        if !this.m_fOpen {
            return;
        }
        this.m_fOpen = false;
        this.m_fDone = false;
        this.m_fConfirm = false;
        this.m_fusion.SetVisible(false);
        this.m_arsenal.SetVisible(this.m_view == 2);
        if IsDefined(this.m_buttonHints) {
            this.m_buttonHints.AddButtonHint(n"back", "Common-Access-Close");
        }
        this.PlaySound(n"Button", n"OnPress");
    }

    private func AddFuseCard(x: Float, weaponIndex: Int32, label: String, labelColor: HDRColor, frameColor: HDRColor, nameColor: HDRColor, element: Int32, bonus: Float, level: Int32) -> ref<inkCanvas> {
        let card: ref<inkCanvas> = new inkCanvas();
        card.SetAnchor(inkEAnchor.TopLeft);
        card.SetMargin(new inkMargin(x, 300.0, 0.0, 0.0));
        card.SetSize(new Vector2(820.0, 640.0));
        card.Reparent(this.m_fContent);

        let bg: ref<inkImage> = new inkImage();
        bg.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
        bg.SetTexturePart(n"cell_bg");
        bg.SetNineSliceScale(true);
        bg.SetAnchor(inkEAnchor.Fill);
        bg.SetTintColor(this.Dark());
        bg.SetOpacity(0.95);
        bg.Reparent(card);
        let frame: ref<inkImage> = new inkImage();
        frame.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
        frame.SetTexturePart(n"cell_fg");
        frame.SetNineSliceScale(true);
        frame.SetAnchor(inkEAnchor.Fill);
        frame.SetTintColor(frameColor);
        frame.Reparent(card);

        this.PlaceText(card, this.Up(label), 30, labelColor, n"Bold", 44.0, 36.0);
        let name: ref<inkText> = this.NewWrappedText(this.m_rewards.GetOwnedName(weaponIndex), 44, nameColor, 732.0);
        name.SetFontStyle(n"Bold");
        name.SetAnchor(inkEAnchor.TopLeft);
        name.SetMargin(new inkMargin(44.0, 92.0, 0.0, 0.0));
        name.Reparent(card);

        let iconBox: ref<inkCanvas> = new inkCanvas();
        iconBox.SetAnchor(inkEAnchor.TopLeft);
        iconBox.SetMargin(new inkMargin(44.0, 210.0, 0.0, 0.0));
        iconBox.SetSize(new Vector2(560.0, 140.0));
        iconBox.Reparent(card);
        this.AddWeaponIcon(iconBox, weaponIndex, 560.0, 140.0);

        let elementRow: ref<inkHorizontalPanel> = this.NewElementRowOf(element, bonus, 72, 28);
        elementRow.SetAnchor(inkEAnchor.TopLeft);
        elementRow.SetMargin(new inkMargin(44.0, 366.0, 0.0, 0.0));
        elementRow.SetFitToContent(true);
        elementRow.Reparent(card);
        let bar: ref<inkCanvas> = this.NewBonusBar(bonus, this.ElementColor(element), 732.0, 22.0);
        bar.SetAnchor(inkEAnchor.TopLeft);
        bar.SetMargin(new inkMargin(44.0, 462.0, 0.0, 0.0));
        bar.Reparent(card);
        let levelRow: ref<inkHorizontalPanel> = this.NewLevelRow(level, 26.0, 34, 28);
        levelRow.SetAnchor(inkEAnchor.TopLeft);
        levelRow.SetMargin(new inkMargin(44.0, 540.0, 0.0, 0.0));
        levelRow.SetFitToContent(true);
        levelRow.Reparent(card);
        return card;
    }

    private func RefreshFusion() {
        let content: ref<inkCanvas> = this.m_fContent;
        content.RemoveAllChildren();
        let gang: String = this.ArsenalGangLabel(this.m_rewards.GetOwnedGang(this.m_fMain));
        let mainElement: Int32 = this.m_rewards.GetOwnedElement(this.m_fMain);
        let mainBonus: Float = this.m_rewards.GetOwnedBonusF(this.m_fMain);
        let mainLevel: Int32 = this.m_rewards.GetOwnedLevel(this.m_fMain);
        let copies: Int32 = ArraySize(this.m_fCopies);
        let cards: Bool = !this.m_fDone && copies > 0;

        this.PlaceText(content, this.Up(this.T("GR-MenuAugment")), 64, this.Red(), n"Bold", 80.0, 60.0);
        let which: ref<inkText> = this.NewText(this.Up(gang) + "  ·  " + this.Up(this.m_rewards.GetOwnedBaseName(this.m_fMain)), 32, this.Cyan(), n"Bold");
        which.SetAnchor(inkEAnchor.TopRight);
        which.SetAnchorPoint(new Vector2(1.0, 0.0));
        which.SetMargin(new inkMargin(0.0, 80.0, 80.0, 0.0));
        which.Reparent(content);
        this.PlaceText(content, this.T("GR-MenuAugmentHint"), 38, this.Light(), n"Regular", 80.0, 150.0);

        ArrayClear(this.m_fChoices);
        if cards {
            this.m_fCopy = Max(0, Min(this.m_fCopy, copies - 1));
            let copy: Int32 = this.m_fCopies[this.m_fCopy];
            let copyElement: Int32 = this.m_rewards.GetOwnedElement(copy);
            let copyBonus: Float = this.m_rewards.GetOwnedBonusF(copy);
            let copyLevel: Int32 = this.m_rewards.GetOwnedLevel(copy);
            if mainElement >= 0 {
                ArrayPush(this.m_fChoices, mainElement);
            }
            if copyElement >= 0 && copyElement != mainElement {
                ArrayPush(this.m_fChoices, copyElement);
            }
            if !ArrayContains(this.m_fChoices, this.m_fKeep) {
                this.m_fKeep = -1;
            }
            let best: Float = MaxF(mainBonus, copyBonus);
            let newBonus: Float = this.m_rewards.FusedBonus(mainBonus, copyBonus);
            let newLevel: Int32 = this.m_rewards.FusedLevel(mainLevel, copyLevel);

            this.AddFuseCard(80.0, this.m_fMain, this.T("GR-MenuAugYours"), this.Grey(), this.Gold(), this.Gold(), mainElement, mainBonus, mainLevel);
            this.PlaceText(content, "+", 120, this.Dim(), n"Bold", 952.0, 545.0);
            this.AddFuseCard(1060.0, copy, this.T("GR-MenuAugCopy"), this.Red(), this.Dim(), this.Light(), copyElement, copyBonus, copyLevel);
            this.PlaceText(content, "=", 120, this.Dim(), n"Bold", 1932.0, 545.0);
            this.AddFuseCard(2040.0, this.m_fMain, this.T("GR-MenuAugResult"), this.Cyan(), this.Cyan(), this.Gold(), this.FusionKeep(), newBonus, newLevel);
            if copies > 1 {
                let counter: ref<inkText> = this.PlaceText(content, IntToString(this.m_fCopy + 1) + "/" + IntToString(copies), 30, this.Grey(), n"Bold", 1718.0, 326.0);
                counter.SetAnchorPoint(new Vector2(0.5, 0.0));
            }

            this.PlaceText(content, this.Up(this.T("GR-MenuAugKeep")), 30, this.Grey(), n"Bold", 80.0, 1018.0);
            let bonusMath: String = StrReplace(this.T("GR-MenuAugMathBonus"), "{best}", this.BonusText(best));
            bonusMath = StrReplace(bonusMath, "{new}", this.BonusText(newBonus));
            if newBonus >= 59.95 {
                bonusMath += " (" + this.T("GR-MenuAugCap") + ")";
            }
            let levelMath: String = StrReplace(this.T("GR-MenuAugMathLevel"), "{from}", this.Roman(mainLevel));
            levelMath = StrReplace(levelMath, "{to}", this.Roman(newLevel));
            this.PlaceText(content, bonusMath + "   ·   " + levelMath, 34, this.Grey(), n"Medium", 80.0, 1110.0);
        } else {
            let result: ref<inkCanvas> = this.AddFuseCard(80.0, this.m_fMain, this.T("GR-MenuAugResult"), this.Cyan(), this.Cyan(), this.Gold(), mainElement, mainBonus, mainLevel);
            if this.m_fDone {
                let stamp: ref<inkCompoundWidget> = this.NewTag(this.T("GR-MenuAugStamp"), 34, this.Gold());
                stamp.SetAnchor(inkEAnchor.TopRight);
                stamp.SetAnchorPoint(new Vector2(1.0, 0.0));
                stamp.SetMargin(new inkMargin(0.0, 28.0, 36.0, 0.0));
                stamp.SetRotation(-4.0);
                stamp.Reparent(result);
            }
            this.PlaceText(content, this.Up(this.T("GR-MenuAugment")) + " " + this.Roman(mainLevel) + "   ·   +" + this.BonusText(mainBonus) + " %   ·   "
                + this.ElementText(mainElement), 44, this.Light(), n"Medium", 1000.0, 330.0);
            let left: String;
            if copies == 0 {
                left = this.Fmt(this.T("GR-MenuAugNoneLeft"), "%s", gang);
            } else {
                left = copies == 1 ? this.T("GR-MenuAugLeftOne") : this.Fmt(this.T("GR-MenuAugLeft"), "%d", IntToString(copies));
            }
            let leftText: ref<inkText> = this.NewWrappedText(left, 36, this.Grey(), 1800.0);
            leftText.SetAnchor(inkEAnchor.TopLeft);
            leftText.SetMargin(new inkMargin(1000.0, 420.0, 0.0, 0.0));
            leftText.Reparent(content);
        }

        let nav: Bool = cards && copies > 1;
        let prevColor: HDRColor = this.m_fCopy > 0 ? this.Cyan() : this.Empty();
        let nextColor: HDRColor = this.m_fCopy < copies - 1 ? this.Cyan() : this.Empty();
        this.StyleFusionButton(0, nav, "<", prevColor, prevColor);
        this.StyleFusionButton(1, nav, ">", nextColor, nextColor);
        let keep: Int32 = this.FusionKeep();
        let c: Int32 = 0;
        while c < 2 {
            if cards && c < ArraySize(this.m_fChoices) {
                let choice: Int32 = this.m_fChoices[c];
                this.StyleFusionButton(2 + c, true, this.Up(this.T("GR-MenuEl-" + IntToString(choice))), this.ElementColor(choice), choice == keep ? this.Cyan() : this.Dim());
            } else {
                this.StyleFusionButton(2 + c, false, "", this.Dim(), this.Dim());
            }
            c += 1;
        }
        this.StyleFusionButton(4, cards, this.T(this.m_fConfirm ? "GR-MenuAugConfirm" : "GR-MenuAugHold"), this.Cyan(), this.Cyan());
        this.SetFuseProgress(0.0);
        if cards {
            this.StyleFusionButton(5, true, this.Up(this.T("GR-MenuAugBack")), this.Cyan(), this.Cyan());
        } else {
            this.StyleFusionButton(5, true, this.T(copies > 0 ? "GR-MenuAugAgain" : "GR-MenuAugToArsenal"), this.Gold(), this.Gold());
        }
    }

    private func DoFuse() {
        if !this.m_fOpen || this.m_fDone || this.m_fCopy < 0 || this.m_fCopy >= ArraySize(this.m_fCopies) {
            return;
        }
        let ok: Bool = this.m_rewards.Fuse(this.m_fMain, this.m_fCopies[this.m_fCopy], this.FusionKeep());
        let fused: Int32 = this.m_rewards.GetFusedIndex();
        this.m_fConfirm = false;
        if !ok || fused < 0 {
            this.m_rewards.Snapshot();
            this.CloseFusion();
            this.m_selWeapon = -1;
            this.FillArsenal();
            this.BringToFront();
            return;
        }
        let copies: array<Int32> = this.FusableCopies(fused);
        this.m_fMain = fused;
        this.m_fCopies = copies;
        this.m_fCopy = 0;
        this.m_fKeep = -1;
        this.m_fDone = true;
        this.m_selWeapon = fused;
        this.FillArsenal();
        this.RefreshFusion();
        this.BringToFront();
        this.PlaySound(n"Item", n"OnCrafted");
    }

    protected cb func OnGRFuseHold(evt: ref<inkPointerEvent>) -> Bool {
        if !this.m_fOpen || this.m_fDone || !evt.IsAction(n"craft_item") {
            return false;
        }
        let progress: Float = evt.GetHoldProgress();
        if progress > 0.0 {
            this.m_fHoldSeen = true;
            if this.m_fConfirm {
                this.m_fConfirm = false;
                this.m_fLabels[4].SetText(this.T("GR-MenuAugHold"));
            }
        }
        this.SetFuseProgress(progress);
        if progress >= 1.0 {
            this.DoFuse();
        }
        return true;
    }

    protected cb func OnGRFuseHoverOut(evt: ref<inkPointerEvent>) -> Bool {
        this.SetFuseProgress(0.0);
    }

    protected cb func OnGRFusionClick(evt: ref<inkPointerEvent>) -> Bool {
        if !evt.IsAction(n"click") || !this.m_fOpen {
            return false;
        }
        let target: CName = evt.GetCurrentTarget().GetName();
        let index: Int32 = -1;
        let i: Int32 = 0;
        while i < ArraySize(this.m_fButtons) {
            if Equals(target, StringToName("gr_fuse_" + IntToString(i))) {
                index = i;
            }
            i += 1;
        }
        if index == 5 {
            if this.m_fDone && ArraySize(this.m_fCopies) > 0 {
                this.m_fDone = false;
                this.m_fCopy = 0;
                this.m_fKeep = -1;
                this.RefreshFusion();
                this.PlaySound(n"Button", n"OnPress");
            } else {
                this.CloseFusion();
            }
            return true;
        }
        if index < 0 || this.m_fDone {
            return false;
        }
        if index <= 1 {
            let next: Int32 = this.m_fCopy + (index == 0 ? -1 : 1);
            if next < 0 || next >= ArraySize(this.m_fCopies) {
                return false;
            }
            this.m_fCopy = next;
            this.m_fKeep = -1;
            this.m_fConfirm = false;
            this.RefreshFusion();
            this.PlaySound(n"Button", n"OnPress");
            return true;
        }
        if index <= 3 {
            if index - 2 >= ArraySize(this.m_fChoices) {
                return false;
            }
            this.m_fKeep = this.m_fChoices[index - 2];
            this.m_fConfirm = false;
            this.RefreshFusion();
            this.PlaySound(n"Button", n"OnPress");
            return true;
        }
        this.SetFuseProgress(0.0);
        if this.m_fHoldSeen {
            return true;
        }
        if !this.m_fConfirm {
            this.m_fConfirm = true;
            this.m_fLabels[4].SetText(this.T("GR-MenuAugConfirm"));
            this.PlaySound(n"Button", n"OnPress");
        } else {
            this.DoFuse();
        }
        return true;
    }

    protected cb func OnGRWeaponClick(evt: ref<inkPointerEvent>) -> Bool {
        if !evt.IsAction(n"click") || this.m_fOpen {
            return false;
        }
        let target: CName = evt.GetCurrentTarget().GetName();
        let i: Int32 = 0;
        while i < ArraySize(this.m_aCards) {
            if Equals(target, StringToName("gr_weapon_" + IntToString(i))) {
                this.m_selWeapon = this.m_aCards[i];
                let j: Int32 = 0;
                while j < ArraySize(this.m_aFrames) {
                    this.StyleWeaponFrame(j, j == i);
                    j += 1;
                }
                this.FillWeaponDetail(this.m_selWeapon);
                this.BringToFront();
                this.PlaySound(n"Button", n"OnPress");
                return true;
            }
            i += 1;
        }
        return false;
    }

    private func ChangePage(delta: Int32) {
        if this.m_bounty {
            this.BountyChangeFixer(delta);
            return;
        }
        if this.m_view == 1 || this.m_fOpen {
            return;
        }
        if this.m_view == 2 {
            this.m_arsenalPage += delta;
            this.m_selWeapon = -1;
            this.FillArsenal();
        } else {
            this.m_page += delta;
            this.m_selName = "";
            this.m_fallenExpanded = false;
            this.Fill();
        }
        this.BringToFront();
        this.PlaySound(n"Button", n"OnPress");
    }

    protected cb func OnGRPrevClick(evt: ref<inkPointerEvent>) -> Bool {
        if evt.IsAction(n"click") {
            this.ChangePage(-1);
        }
    }

    protected cb func OnGRNextClick(evt: ref<inkPointerEvent>) -> Bool {
        if evt.IsAction(n"click") {
            this.ChangePage(1);
        }
    }

    protected cb func OnGRTabClick(evt: ref<inkPointerEvent>) -> Bool {
        if !evt.IsAction(n"click") {
            return false;
        }
        let target: CName = evt.GetCurrentTarget().GetName();
        if this.m_bounty {
            let t: Int32 = 0;
            while t < ArraySize(this.m_bFixerNames) {
                if Equals(target, StringToName("gr_tab_" + IntToString(t))) && t != this.m_bFixer {
                    this.BountyChangeFixer(t - this.m_bFixer);
                    return true;
                }
                t += 1;
            }
            return false;
        }
        let gangs: array<String> = IsDefined(this.m_data) ? this.m_data.GetGangs() : [];
        let arsenalGangs: array<String> = this.ArsenalGangs();
        let count: Int32 = this.m_view == 2 ? ArraySize(arsenalGangs) : ArraySize(gangs);
        let page: Int32 = this.m_view == 2 ? this.m_arsenalPage : this.m_page;
        let i: Int32 = 0;
        while i < count {
            if Equals(target, StringToName("gr_tab_" + IntToString(i))) && i != page {
                this.ChangePage(i - page);
                return true;
            }
            i += 1;
        }
        return false;
    }

    private func AddIntelBar(gangKey: String) {
        let intel: ref<GRIntelSystem> = GRIntelSystem.Get(this.GetPlayerControlledObject().GetGame());
        this.m_intelGang = gangKey;
        if !IsDefined(intel) {
            return;
        }
        let box: ref<inkCanvas> = new inkCanvas();
        box.SetName(n"gr_intel");
        box.SetAnchor(inkEAnchor.TopLeft);
        box.SetMargin(new inkMargin(1880.0, 356.0, 0.0, 0.0));
        box.SetSize(new Vector2(760.0, 76.0));
        box.SetInteractive(true);
        box.RegisterToCallback(n"OnRelease", this, n"OnGRIntelClick");
        box.Reparent(this.m_tree);
        this.PlaceText(box, this.Up(this.T("GR-MenuIntel")), 28, this.Light(), n"Bold", 0.0, 0.0);
        let located: ref<inkText> = this.PlaceText(box, this.Up(this.T("GR-MenuIntelLocated")), 28, this.Gold(), n"Bold", 760.0, 0.0);
        located.SetAnchorPoint(new Vector2(1.0, 0.0));
        this.m_intelLocated = located;
        this.PlaceRect(box, 0.0, 48.0, 600.0, 16.0, this.Empty(), 1.0);
        let fill: ref<inkRectangle> = this.NewRect(0.0, 16.0, this.Cyan(), 1.0);
        fill.SetAnchor(inkEAnchor.TopLeft);
        fill.SetMargin(new inkMargin(0.0, 48.0, 0.0, 0.0));
        fill.Reparent(box);
        this.m_intelFill = fill;
        let value: ref<inkText> = this.PlaceText(box, "", 34, this.Cyan(), n"Bold", 760.0, 36.0);
        value.SetAnchorPoint(new Vector2(1.0, 0.0));
        this.m_intelValue = value;
        this.StyleIntelBar(intel.GetIntel(gangKey));
    }

    private func StyleIntelBar(value: Int32) {
        let located: Bool = value >= 100;
        let color: HDRColor = located ? this.Gold() : this.Cyan();
        this.m_intelFill.SetSize(new Vector2(600.0 * Cast<Float>(Min(Max(value, 0), 100)) / 100.0, 16.0));
        this.m_intelFill.SetTintColor(color);
        this.m_intelValue.SetText(IntToString(value) + " %");
        this.m_intelValue.SetTintColor(color);
        this.m_intelLocated.SetVisible(located);
    }

    protected cb func OnGRIntelClick(evt: ref<inkPointerEvent>) -> Bool {
        if !evt.IsAction(n"click") {
            return false;
        }
        let gi: GameInstance = this.GetPlayerControlledObject().GetGame();
        let settings: ref<GRSettings> = GRSettings.Get(gi);
        let intel: ref<GRIntelSystem> = GRIntelSystem.Get(gi);
        if !IsDefined(settings) || !settings.debugLog || !IsDefined(intel) {
            return false;
        }
        this.StyleIntelBar(intel.AddIntel(this.m_intelGang, 25, "boton de desarrollo"));
        this.PlaySound(n"Button", n"OnPress");
        return true;
    }

    protected cb func OnGRCardClick(evt: ref<inkPointerEvent>) -> Bool {
        if !evt.IsAction(n"click") {
            return false;
        }
        let target: CName = evt.GetCurrentTarget().GetName();
        let i: Int32 = 0;
        while i < ArraySize(this.m_cards) {
            if Equals(target, StringToName("gr_card_" + IntToString(i))) {
                this.m_selName = this.m_cards[i].name;
                let j: Int32 = 0;
                while j < ArraySize(this.m_cardFrames) {
                    this.StyleFrame(this.m_cardFrames[j], this.m_cards[j], j == i);
                    this.m_cardSelFrames[j].SetOpacity(j == i ? 1.0 : 0.0);
                    j += 1;
                }
                // Clear any fallen-row highlight too (that row isn't rebuilt by a plain selection change).
                j = 0;
                while j < ArraySize(this.m_fallenBorders) {
                    this.m_fallenBorders[j].SetOpacity(0.0);
                    j += 1;
                }
                this.FillDetail(this.m_cards[i]);
                this.BringToFront();
                this.PlaySound(n"Button", n"OnPress");
                return true;
            }
            i += 1;
        }
        return false;
    }

    private func InitBounty() {
        this.m_bounties = GRBounties.Get(this.GetPlayerControlledObject().GetGame());
        this.m_bSel = -1;
        let root: ref<inkCompoundWidget> = this.GetRootCompoundWidget();
        this.CreateBackground(root);
        this.CreateHeader(root, "GR-BountyTitle", "GR-MenuTitle", n"gangretaliation_nemesis_menu");

        let board: ref<inkCanvas> = new inkCanvas();
        board.SetName(n"bounty_board");
        board.SetAnchor(inkEAnchor.Fill);
        board.Reparent(root);
        this.m_tree = board;

        this.CreateDetail(root);
        this.CreateBountyViewSwitch(root);
        this.CreateHints(root);
        this.RegisterToGlobalInputCallback(n"OnPostOnRelease", this, n"OnGRGlobalInput");
        this.FillBounty();
        GRLog("Menu: tablero de recompensas abierto (" + IntToString(ArraySize(this.m_bContracts)) + " contratos)");

        // Landed here from a Nemesis's bounty badge click (OpenGRMenu/RequestBountyFocus) - jump straight
        // to that contract's detail instead of leaving nothing selected.
        let focusId: Int32 = IsDefined(this.m_data) ? this.m_data.ConsumeBountyFocus() : -1;
        if focusId >= 0 {
            for c in this.m_bContracts {
                if c.nemesisId == focusId && GRBounties.IsOpenState(c.state) {
                    this.m_bSel = c.index;
                    let j: Int32 = 0;
                    while j < ArraySize(this.m_bFrames) && j < ArraySize(this.m_bCards) {
                        this.StyleBountyFrame(this.m_bFrames[j], this.ContractAt(this.m_bCards[j]), this.m_bCards[j] == this.m_bSel);
                        j += 1;
                    }
                    this.FillBountyDetail(c);
                    break;
                }
            }
        }
    }

    private func CreateBountyViewSwitch(root: ref<inkCompoundWidget>) {
        let panel: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        panel.SetName(n"bounty_view_switch");
        panel.SetAnchor(inkEAnchor.TopLeft);
        panel.SetMargin(new inkMargin(120.0, 258.0, 0.0, 0.0));
        panel.SetFitToContent(true);
        panel.Reparent(root);

        let key: ref<inkCompoundWidget> = this.NewTag("TAB", 22, this.Cyan());
        key.SetMargin(new inkMargin(0.0, 0.0, 20.0, 0.0));
        key.Reparent(panel);

        let keys: array<String> = ["GR-BountyViewOpen", "GR-BountyViewPaid", "GR-BountyViewFailed"];
        let i: Int32 = 0;
        while i < ArraySize(keys) {
            if i > 0 {
                let sep: ref<inkText> = this.NewText("  |  ", 32, this.Dim(), n"Medium");
                sep.SetVAlign(inkEVerticalAlign.Center);
                sep.Reparent(panel);
            }
            let label: ref<inkText> = this.NewText(this.Up(this.T(keys[i])), 32, this.Grey(), n"Bold");
            label.SetName(StringToName("gr_bview_" + IntToString(i)));
            label.SetVAlign(inkEVerticalAlign.Center);
            label.SetInteractive(true);
            label.RegisterToCallback(n"OnRelease", this, n"OnGRBountyViewClick");
            label.Reparent(panel);
            ArrayPush(this.m_bViewTexts, label);
            i += 1;
        }
    }

    private func Money(amount: Int32) -> String {
        return GRBounties.Money(amount, this.T("GR-BountySep"));
    }

    private func BountyEntry(nemesisId: Int32) -> ref<GRMenuEntry> {
        if !IsDefined(this.m_data) {
            return null;
        }
        let entries: array<ref<GRMenuEntry>> = this.m_data.GetEntries();
        for entry in entries {
            if entry.id == nemesisId {
                return entry;
            }
        }
        return null;
    }

    private func BountyName(entry: ref<GRMenuEntry>) -> String {
        if IsDefined(entry) && StrLen(entry.name) > 0 {
            return entry.name;
        }
        return this.T("GR-BountyUnknown");
    }

    private func BountyGang(c: ref<GRBounty>, entry: ref<GRMenuEntry>) -> String {
        if IsDefined(entry) && StrLen(entry.gang) > 0 {
            return entry.gang;
        }
        return GRIntelSystem.GangLabel(c.gang);
    }

    private func BountyColor(c: ref<GRBounty>) -> HDRColor {
        return c.rank >= 3 ? this.Gold() : this.Red();
    }

    private func BountyDaysLeft(c: ref<GRBounty>) -> Int32 {
        return Max(1, c.expire - this.m_bToday);
    }

    private func DaysLeftText(days: Int32) -> String {
        if days == 1 {
            return this.T("GR-BountyDayLeft");
        }
        return StrReplaceAll(this.T("GR-BountyDaysLeft"), "{n}", IntToString(days));
    }

    private func BountyWeakList(entry: ref<GRMenuEntry>) -> String {
        let out: String = "";
        if !IsDefined(entry) {
            return out;
        }
        let lines: array<String> = this.TraitLines(entry);
        for line in lines {
            let parts: array<String> = StrSplit(line, "|");
            if ArraySize(parts) >= 2 && Equals(parts[0], "-") {
                out += StrLen(out) > 0 ? ", " + parts[1] : parts[1];
            }
        }
        return out;
    }

    private func ContractAt(index: Int32) -> ref<GRBounty> {
        for c in this.m_bContracts {
            if c.index == index {
                return c;
            }
        }
        return null;
    }

    private func StyleBountyFrame(frame: wref<inkImage>, c: ref<GRBounty>, selected: Bool) {
        if !IsDefined(c) {
            return;
        }
        frame.SetTintColor(selected ? this.Cyan() : this.BountyColor(c));
        frame.SetOpacity(selected || GRBounties.IsOpenState(c.state) ? 1.0 : 0.6);
    }

    private func BountyStateTag(c: ref<GRBounty>, size: Int32) -> ref<inkCompoundWidget> {
        if c.state == 3 {
            return this.NewTag(this.Up(this.T("GR-BountyOfferTag")), size, this.Cyan());
        }
        if c.state == 0 {
            return this.NewTag(this.Up(this.T("GR-BountyAcceptedTag")), size, this.Gold());
        }
        return null;
    }

    private func BountyReward(c: ref<GRBounty>) -> String {
        return this.Money(c.state == 1 ? c.paid : c.pay) + " · " + GRBounties.Xp(c.xp, this.T("GR-BountySep"));
    }

    private func FillBounty() {
        this.m_tree.RemoveAllChildren();
        ArrayClear(this.m_bCards);
        ArrayClear(this.m_bFrames);
        let all: array<ref<GRBounty>>;
        if IsDefined(this.m_bounties) {
            all = this.m_bounties.GetContracts();
            this.m_bToday = this.m_bounties.GetToday();
        }
        this.m_bContracts = all;

        let open: Int32 = 0;
        let accepted: Int32 = 0;
        let paid: Int32 = 0;
        let failed: Int32 = 0;
        let earned: Int32 = 0;
        for c in all {
            if GRBounties.IsOpenState(c.state) {
                open += 1;
            }
            if c.state == 0 {
                accepted += 1;
            }
            if c.state == 1 {
                paid += 1;
                earned += c.paid;
            }
            if c.state == 2 {
                failed += 1;
            }
        }
        this.m_summary.SetText(this.Up(this.T("GR-BountyViewOpen")) + " " + IntToString(open) + "   |   " + this.Up(this.T("GR-BountyViewPaid")) + " " + IntToString(paid)
            + "   |   " + this.Up(this.T("GR-BountyViewFailed")) + " " + IntToString(failed) + "   |   " + this.Money(earned));
        let v: Int32 = 0;
        while v < ArraySize(this.m_bViewTexts) {
            this.m_bViewTexts[v].SetTintColor(v == this.m_bView ? this.Cyan() : this.Grey());
            v += 1;
        }

        let inView: array<ref<GRBounty>>;
        if this.m_bView == 0 {
            for c in all {
                if c.state == 3 {
                    ArrayPush(inView, c);
                }
            }
            for c in all {
                if c.state == 0 {
                    ArrayPush(inView, c);
                }
            }
        } else {
            let k: Int32 = ArraySize(all) - 1;
            while k >= 0 {
                if all[k].state == this.m_bView {
                    ArrayPush(inView, all[k]);
                }
                k -= 1;
            }
        }

        let fixers: array<String>;
        ArrayPush(fixers, "");
        for c in inView {
            let name: String = GRBounties.FixerName(c.fixer);
            if !ArrayContains(fixers, name) {
                ArrayPush(fixers, name);
            }
        }
        let count: Int32 = ArraySize(fixers);
        this.m_bFixer = ((this.m_bFixer % count) + count) % count;
        this.m_bFixerNames = fixers;
        if ArraySize(this.m_tabTexts) != count {
            this.m_marks.RemoveAllChildren();
            ArrayClear(this.m_tabTexts);
            ArrayClear(this.m_tabBars);
            ArrayClear(this.m_tabThreats);
            let t: Int32 = 0;
            while t < count {
                this.AddTab(t);
                t += 1;
            }
        }
        let i: Int32 = 0;
        while i < count {
            let threat: Bool = false;
            if i > 0 {
                for c in all {
                    if GRBounties.IsOpenState(c.state) && Equals(GRBounties.FixerName(c.fixer), fixers[i]) {
                        threat = true;
                    }
                }
            }
            this.StyleTab(i, i == 0 ? this.T("GR-BountyAllFixers") : fixers[i], i == this.m_bFixer, threat);
            i += 1;
        }

        let filter: String = fixers[this.m_bFixer];
        let shown: array<ref<GRBounty>>;
        for c in inView {
            if StrLen(filter) == 0 || Equals(GRBounties.FixerName(c.fixer), filter) {
                ArrayPush(shown, c);
            }
        }
        this.m_gangTitle.SetText(this.Up(StrLen(filter) == 0 ? this.T("GR-BountyAllFixers") : filter));
        this.m_gangCount.SetText(IntToString(ArraySize(shown)));

        let selected: ref<GRBounty>;
        for c in shown {
            if c.index == this.m_bSel {
                selected = c;
            }
        }
        if !IsDefined(selected) && ArraySize(shown) > 0 {
            selected = shown[0];
        }
        this.m_bSel = IsDefined(selected) ? selected.index : -1;

        let left: Float = 120.0;
        let width: Float = 2500.0;
        let labelKey: String = "GR-BountyAcceptedContracts";
        let value: String = IntToString(accepted) + " / " + IntToString(GRBounties.MaxOpen());
        let valueColor: HDRColor = this.Cyan();
        if this.m_bView == 1 {
            labelKey = "GR-BountyPaidContracts";
            value = this.Money(earned);
            valueColor = this.Gold();
        }
        if this.m_bView == 2 {
            labelKey = "GR-BountyFailedContracts";
            value = IntToString(failed);
            valueColor = this.Red();
        }
        this.PlaceText(this.m_tree, this.Up(this.T(labelKey)), 34, this.Light(), n"Bold", left, 380.0);
        let valueText: ref<inkText> = this.PlaceText(this.m_tree, value, 34, valueColor, n"Bold", left + width, 380.0);
        valueText.SetAnchorPoint(new Vector2(1.0, 0.0));
        if this.m_bView == 0 {
            this.PlaceRect(this.m_tree, left, 432.0, width, 10.0, this.Empty(), 1.0);
            if accepted > 0 {
                this.PlaceRect(this.m_tree, left, 432.0, width * MinF(1.0, Cast<Float>(accepted) / Cast<Float>(GRBounties.MaxOpen())), 10.0, this.Cyan(), 1.0);
            }
        } else {
            this.PlaceRect(this.m_tree, left, 436.0, width, 2.0, this.Dim(), 1.0);
        }

        let cols: Int32 = 3;
        let rows: Int32 = this.m_bView == 0 ? 2 : 3;
        let cardW: Float = 800.0;
        let cardH: Float = 320.0;
        let top: Float = 480.0;
        if ArraySize(shown) == 0 {
            let empty: ref<inkText> = this.NewWrappedText(this.T("GR-BountyEmpty-" + IntToString(this.m_bView)), 40, this.Grey(), 2400.0);
            empty.SetAnchor(inkEAnchor.TopLeft);
            empty.SetMargin(new inkMargin(left, top + 40.0, 0.0, 0.0));
            empty.Reparent(this.m_tree);
        }
        let limit: Int32 = Min(ArraySize(shown), cols * rows);
        i = 0;
        while i < limit {
            let x: Float = left + Cast<Float>(i % cols) * (cardW + 50.0);
            let y: Float = top + Cast<Float>(i / cols) * (cardH + 40.0);
            this.AddBountyCard(shown[i], x, y, cardW, cardH, shown[i].index == this.m_bSel);
            i += 1;
        }
        if ArraySize(shown) > limit {
            this.PlaceText(this.m_tree, "+" + IntToString(ArraySize(shown) - limit), 40, this.Grey(), n"Medium", left, top + Cast<Float>(rows) * (cardH + 40.0));
        }

        if this.m_bView == 0 {
            this.AddBountyClosed(all);
        }
        this.FillBountyDetail(selected);
    }

    private func BountyStatus(c: ref<GRBounty>) -> String {
        let fixer: String = this.Up(GRBounties.FixerName(c.fixer));
        if c.state == 1 {
            return this.Up(this.T("GR-BountyPaid")) + " · " + fixer;
        }
        if c.state == 2 {
            return this.Up(this.T("GR-BountyReason-" + IntToString(c.reason)));
        }
        return this.Up(this.DaysLeftText(this.BountyDaysLeft(c))) + " · " + fixer;
    }

    private func BountyStatusColor(c: ref<GRBounty>) -> HDRColor {
        if c.state == 1 {
            return this.Gold();
        }
        if c.state == 2 || this.BountyDaysLeft(c) <= 2 {
            return this.Red();
        }
        return this.Grey();
    }

    private func AddBountyCard(c: ref<GRBounty>, x: Float, y: Float, w: Float, h: Float, selected: Bool) {
        let entry: ref<GRMenuEntry> = this.BountyEntry(c.nemesisId);
        let color: HDRColor = this.BountyColor(c);
        let index: Int32 = ArraySize(this.m_bCards);
        ArrayPush(this.m_bCards, c.index);

        let card: ref<inkCanvas> = new inkCanvas();
        card.SetName(StringToName("gr_bcard_" + IntToString(index)));
        card.SetAnchor(inkEAnchor.TopLeft);
        card.SetMargin(new inkMargin(x, y, 0.0, 0.0));
        card.SetSize(new Vector2(w, h));
        card.SetInteractive(true);
        card.RegisterToCallback(n"OnRelease", this, n"OnGRBountyCardClick");
        card.Reparent(this.m_tree);

        let bg: ref<inkImage> = new inkImage();
        bg.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
        bg.SetTexturePart(n"cell_bg");
        bg.SetNineSliceScale(true);
        bg.SetAnchor(inkEAnchor.Fill);
        bg.SetTintColor(this.Dark());
        bg.SetOpacity(0.95);
        bg.Reparent(card);

        let frame: ref<inkImage> = new inkImage();
        frame.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
        frame.SetTexturePart(n"cell_fg");
        frame.SetNineSliceScale(true);
        frame.SetAnchor(inkEAnchor.Fill);
        frame.Reparent(card);
        ArrayPush(this.m_bFrames, frame);
        this.StyleBountyFrame(frame, c, selected);

        let content: ref<inkVerticalPanel> = new inkVerticalPanel();
        content.SetAnchor(inkEAnchor.Fill);
        content.SetMargin(new inkMargin(30.0, 18.0, 30.0, 12.0));
        content.Reparent(card);

        let tags: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        tags.Reparent(content);
        let rank: ref<inkText> = this.NewText(this.RankName(c.rank), 28, color, n"Bold");
        rank.SetVAlign(inkEVerticalAlign.Center);
        rank.SetMargin(new inkMargin(0.0, 0.0, 16.0, 0.0));
        rank.Reparent(tags);
        this.NewTag(this.T("GR-MenuKnown"), 22, this.Red()).Reparent(tags);
        let stateTag: ref<inkCompoundWidget> = this.BountyStateTag(c, 22);
        if IsDefined(stateTag) {
            stateTag.SetMargin(new inkMargin(12.0, 0.0, 0.0, 0.0));
            stateTag.Reparent(tags);
        }
        if c.special && GRBounties.IsOpenState(c.state) {
            let specialTag: ref<inkCompoundWidget> = this.NewTag(this.Up(this.T("GR-BountySpecialTag")), 22, this.Special());
            specialTag.SetMargin(new inkMargin(12.0, 0.0, 0.0, 0.0));
            specialTag.Reparent(tags);
        }

        let name: ref<inkText> = this.NewText(this.BountyName(entry), 48, c.state == 2 ? this.Grey() : color, n"Bold");
        name.SetMargin(new inkMargin(0.0, 6.0, 0.0, 0.0));
        name.Reparent(content);
        if IsDefined(entry) && StrLen(entry.title) > 0 {
            this.NewText("\"" + entry.title + "\"", 32, this.Light(), n"Regular").Reparent(content);
        }

        let bar: ref<inkHorizontalPanel> = this.NewRenownBar(IsDefined(entry) ? entry.renown : 0, color, w - 60.0, 8.0, 6.0);
        bar.SetMargin(new inkMargin(0.0, 12.0, 0.0, 0.0));
        bar.Reparent(content);

        let row: ref<inkCanvas> = new inkCanvas();
        row.SetSize(new Vector2(w - 60.0, 52.0));
        row.SetMargin(new inkMargin(0.0, 12.0, 0.0, 0.0));
        row.Reparent(content);
        this.PlaceText(row, this.BountyReward(c), 42, c.state == 2 ? this.Grey() : this.Gold(), n"Bold", 0.0, 0.0);
        let statusRow: ref<inkCanvas> = new inkCanvas();
        statusRow.SetSize(new Vector2(w - 60.0, 34.0));
        statusRow.Reparent(content);
        let status: ref<inkText> = this.PlaceText(statusRow, this.BountyStatus(c), 26, this.BountyStatusColor(c), n"Bold", w - 60.0, 0.0);
        status.SetAnchorPoint(new Vector2(1.0, 0.0));
    }

    private func AddBountyClosed(all: array<ref<GRBounty>>) {
        let closed: array<ref<GRBounty>>;
        let k: Int32 = ArraySize(all) - 1;
        while k >= 0 {
            if !GRBounties.IsOpenState(all[k].state) {
                ArrayPush(closed, all[k]);
            }
            k -= 1;
        }

        let block: ref<inkVerticalPanel> = new inkVerticalPanel();
        block.SetAnchor(inkEAnchor.TopLeft);
        block.SetMargin(new inkMargin(120.0, 1640.0, 0.0, 0.0));
        block.Reparent(this.m_tree);

        let header: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        header.Reparent(block);
        let label: ref<inkText> = this.NewText(this.Up(this.T("GR-BountyClosed")), 34, this.Light(), n"Medium");
        label.SetVAlign(inkEVerticalAlign.Center);
        label.Reparent(header);
        let line: ref<inkRectangle> = this.NewRect(2200.0, 2.0, this.Dim(), 1.0);
        line.SetVAlign(inkEVerticalAlign.Center);
        line.SetMargin(new inkMargin(28.0, 0.0, 0.0, 0.0));
        line.Reparent(header);

        if ArraySize(closed) == 0 {
            let none: ref<inkText> = this.NewText(this.T("GR-BountyNoClosed"), 34, this.Light(), n"Regular");
            none.SetMargin(new inkMargin(0.0, 20.0, 0.0, 0.0));
            none.Reparent(block);
            return;
        }

        let row: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        row.SetMargin(new inkMargin(0.0, 20.0, 0.0, 0.0));
        row.Reparent(block);
        let shown: Int32 = Min(ArraySize(closed), 5);
        let i: Int32 = 0;
        while i < shown {
            let c: ref<GRBounty> = closed[i];
            let entry: ref<GRMenuEntry> = this.BountyEntry(c.nemesisId);
            let box: ref<inkCanvas> = new inkCanvas();
            box.SetSize(new Vector2(420.0, 140.0));
            box.SetMargin(new inkMargin(0.0, 0.0, 20.0, 0.0));
            box.Reparent(row);
            this.AddFill(box, this.Panel(), 0.95);
            this.AddBorder(box, this.Dim(), 2.0, 1.0);

            let content: ref<inkVerticalPanel> = new inkVerticalPanel();
            content.SetAnchor(inkEAnchor.Fill);
            content.SetMargin(new inkMargin(24.0, 12.0, 16.0, 10.0));
            content.Reparent(box);
            let name: ref<inkText> = this.NewText(this.BountyName(entry), 36, c.state == 2 ? this.Grey() : this.Light(), n"Bold");
            name.Reparent(content);
            this.NewText(this.RankName(c.rank) + " · " + this.Up(this.BountyGang(c, entry)), 24, this.Grey(), n"Bold").Reparent(content);
            let status: String = c.state == 1 ? this.Up(this.T("GR-BountyPaid")) + " " + this.Money(c.paid) + " · " + GRBounties.FixerName(c.fixer) : this.Up(this.T("GR-BountyFailed")) + " · " + this.T("GR-BountyReason-" + IntToString(c.reason));
            this.NewText(status, 24, c.state == 1 ? this.Gold() : this.Red(), n"Bold").Reparent(content);
            i += 1;
        }
        if ArraySize(closed) > shown {
            let more: ref<inkText> = this.NewText("+" + IntToString(ArraySize(closed) - shown), 40, this.Grey(), n"Medium");
            more.SetVAlign(inkEVerticalAlign.Center);
            more.Reparent(row);
        }
    }

    private func FillBountyDetail(c: ref<GRBounty>) {
        let header: ref<inkVerticalPanel> = this.m_detailHeader;
        let panel: ref<inkVerticalPanel> = this.m_detailContent;
        header.RemoveAllChildren();
        panel.RemoveAllChildren();
        if !IsDefined(c) {
            this.m_detail.SetVisible(false);
            this.UpdateBountyHint(false);
            return;
        }
        this.m_detail.SetVisible(true);
        let entry: ref<GRMenuEntry> = this.BountyEntry(c.nemesisId);
        let width: Float = 888.0;
        let color: HDRColor = this.BountyColor(c);
        let fixer: String = GRBounties.FixerName(c.fixer);
        let name: String = this.BountyName(entry);

        // Same split as FillDetail: contract line, name and title go in the fixed header (above the
        // divider CreateDetail draws); everything else scrolls inside the RedFalcon scroll area.
        this.NewText(this.Up(this.T("GR-BountyContract")) + "  |  " + this.Up(fixer + " · " + this.T("GR-BountyDistrict-" + IntToString(c.fixer))), 28, this.Cyan(), n"Bold").Reparent(header);
        let title: ref<inkText> = this.NewWrappedText(name, 66, c.state == 2 ? this.Grey() : color, width);
        title.SetFontStyle(n"Bold");
        title.Reparent(header);
        if IsDefined(entry) && StrLen(entry.title) > 0 {
            this.NewText("\"" + entry.title + "\"", 42, this.Light(), n"Regular").Reparent(header);
        }

        let rankRow: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        rankRow.Reparent(panel);
        let rankText: ref<inkText> = this.NewText(this.RankName(c.rank) + "  |  " + this.Up(this.BountyGang(c, entry)), 28, this.Red(), n"Bold");
        rankText.SetVAlign(inkEVerticalAlign.Center);
        rankText.SetMargin(new inkMargin(0.0, 0.0, 20.0, 0.0));
        rankText.Reparent(rankRow);
        this.NewTag(this.T("GR-MenuKnown"), 22, this.Red()).Reparent(rankRow);
        let stateTag: ref<inkCompoundWidget> = this.BountyStateTag(c, 22);
        if IsDefined(stateTag) {
            stateTag.SetMargin(new inkMargin(12.0, 0.0, 0.0, 0.0));
            stateTag.Reparent(rankRow);
        }
        if c.special && GRBounties.IsOpenState(c.state) {
            let specialTag: ref<inkCompoundWidget> = this.NewTag(this.Up(this.T("GR-BountySpecialTag")), 22, this.Special());
            specialTag.SetMargin(new inkMargin(12.0, 0.0, 0.0, 0.0));
            specialTag.Reparent(rankRow);
        }

        let msgRow: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        msgRow.SetMargin(new inkMargin(0.0, 28.0, 0.0, 0.0));
        msgRow.Reparent(panel);
        let msgBar: ref<inkRectangle> = this.NewRect(4.0, 10.0, this.Cyan(), 0.6);
        msgBar.SetVAlign(inkEVerticalAlign.Fill);
        msgBar.SetMargin(new inkMargin(0.0, 0.0, 20.0, 0.0));
        msgBar.Reparent(msgRow);
        let msgCol: ref<inkVerticalPanel> = new inkVerticalPanel();
        msgCol.Reparent(msgRow);
        this.NewText(this.Up(fixer) + ":", 24, this.Cyan(), n"Bold").Reparent(msgCol);
        let msgKey: String = "GR-BountyMsg-" + IntToString(c.cond) + "-" + IntToString(Max(1, c.msg));
        this.NewWrappedText(StrReplaceAll(this.T(msgKey), "{name}", name), 32, this.Light(), width - 30.0).Reparent(msgCol);

        let weak: String = this.BountyWeakList(entry);
        let bigRow: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        bigRow.SetMargin(new inkMargin(0.0, 28.0, 0.0, 0.0));
        bigRow.Reparent(panel);
        let amount: ref<inkText> = this.NewText(this.Money(c.state == 1 ? c.paid : c.pay), 64, c.state == 2 ? this.Grey() : this.Gold(), n"Bold");
        amount.SetVAlign(inkEVerticalAlign.Center);
        amount.SetMargin(new inkMargin(0.0, 0.0, 16.0, 0.0));
        amount.Reparent(bigRow);
        let xpText: ref<inkText> = this.NewText("· " + GRBounties.Xp(c.xp, this.T("GR-BountySep")), 44, c.state == 2 ? this.Grey() : this.Cyan(), n"Bold");
        xpText.SetVAlign(inkEVerticalAlign.Center);
        xpText.Reparent(bigRow);
        let note: String = "";
        let noteColor: HDRColor = this.Grey();
        if GRBounties.IsOpenState(c.state) && c.bonus > 0 && (StrLen(weak) > 0 || c.bonusUsed) {
            note = this.Up(StrReplaceAll(this.T("GR-BountyUpTo"), "{pay}", this.Money(c.pay + c.bonus)));
        }
        if c.state == 1 {
            note = this.Up(this.T("GR-BountyPaid"));
            noteColor = this.Gold();
        }
        if c.state == 2 {
            note = this.Up(this.T("GR-BountyFailed") + ": " + this.T("GR-BountyReason-" + IntToString(c.reason)));
            noteColor = this.Red();
        }
        if StrLen(note) > 0 {
            let noteText: ref<inkText> = this.NewText(note, 26, noteColor, n"Bold");
            noteText.SetMargin(new inkMargin(0.0, 4.0, 0.0, 0.0));
            noteText.Reparent(panel);
        }
        if c.state == 3 {
            this.AddBountyAcceptButton(panel, width);
        }
        this.UpdateBountyHint(c.state == 3);

        this.AddSection(panel, this.T("GR-BountyContract"), 28.0);
        let days: Int32 = Max(1, c.expire - c.offerDay);
        let cond: String = StrReplaceAll(this.T("GR-BountyCond-" + IntToString(c.cond)), "{name}", name);
        cond = StrReplaceAll(cond, "{days}", IntToString(days));
        this.NewWrappedText(cond, 34, this.Light(), width).Reparent(panel);
        if c.zone > 0 {
            let zoneText: ref<inkText> = this.NewWrappedText(StrReplaceAll(this.T("GR-BountyZoneHint-" + IntToString(c.zone)), "{name}", name), 30, this.Cyan(), width);
            zoneText.SetMargin(new inkMargin(0.0, 8.0, 0.0, 0.0));
            zoneText.Reparent(panel);
        }
        if c.special && GRBounties.IsOpenState(c.state) {
            let specialText: ref<inkText> = this.NewWrappedText(this.T("GR-BountySpecialLine") + (c.bonusUsed ? "  " + this.Up(this.T("GR-BountyBonusDone")) : ""), 30, this.Special(), width);
            specialText.SetFontStyle(n"Bold");
            specialText.SetMargin(new inkMargin(0.0, 10.0, 0.0, 0.0));
            specialText.Reparent(panel);
        }

        if c.bonus > 0 {
            let bonusRow: ref<inkHorizontalPanel> = new inkHorizontalPanel();
            bonusRow.SetMargin(new inkMargin(0.0, 12.0, 0.0, 0.0));
            bonusRow.Reparent(panel);
            let known: Bool = StrLen(weak) > 0 || c.bonusUsed;
            let bonusLabel: String = StrLen(weak) > 0 ? StrReplaceAll(this.T("GR-BountyBonusWeak"), "{list}", weak) : this.T("GR-BountyBonusHidden");
            let bonusText: ref<inkText> = this.NewWrappedText(bonusLabel, 32, this.Grey(), 660.0);
            bonusText.SetMargin(new inkMargin(0.0, 0.0, 20.0, 0.0));
            bonusText.Reparent(bonusRow);
            let bonusValue: String = known ? "+" + this.Money(c.bonus) : "???";
            if c.bonusUsed {
                bonusValue = bonusValue + "  " + this.Up(this.T("GR-BountyBonusDone"));
            }
            let bonusAmount: ref<inkText> = this.NewText(bonusValue, 30, c.bonusUsed ? this.Cyan() : (known ? this.Gold() : this.Dim()), n"Bold");
            bonusAmount.Reparent(bonusRow);
        }

        if IsDefined(entry) {
            this.AddSection(panel, this.T("GR-MenuTraits"), 28.0);
            let traitLines: array<String> = this.TraitLines(entry);
            for line in traitLines {
                let parts: array<String> = StrSplit(line, "|");
                if ArraySize(parts) >= 3 {
                    let prefix: String = Equals(parts[0], "?") ? "" : parts[0] + "  ";
                    let trait: ref<inkText> = this.NewWrappedText(prefix + parts[2], 34, this.TraitColor(parts[0]), width);
                    trait.SetFontStyle(n"Medium");
                    trait.SetMargin(new inkMargin(0.0, 0.0, 0.0, 6.0));
                    trait.Reparent(panel);
                }
            }
        }

        let goldRule: ref<inkRectangle> = this.NewRect(width, 2.0, this.Gold(), 0.6);
        goldRule.SetMargin(new inkMargin(0.0, 24.0, 0.0, 0.0));
        goldRule.Reparent(panel);

        let stats: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        stats.SetMargin(new inkMargin(0.0, 24.0, 0.0, 0.0));
        stats.Reparent(panel);
        this.AddStatText(stats, IsDefined(entry) ? IntToString(entry.encounters) : "-", this.T("GR-MenuEncounters"), this.Light());
        this.AddStatText(stats, IsDefined(entry) ? IntToString(entry.escapes) : "-", this.T("GR-MenuEscapes"), this.Light());
        this.AddStatText(stats, IsDefined(entry) ? IntToString(entry.ambushes) : "-", this.T("GR-MenuAmbushes"), this.Light());
        if GRBounties.IsOpenState(c.state) {
            let left: Int32 = this.BountyDaysLeft(c);
            this.AddStatText(stats, IntToString(left), this.T("GR-BountyDaysLeftStat"), left <= 2 ? this.Red() : this.Light());
        } else {
            this.AddStatText(stats, "-", this.T("GR-BountyDaysLeftStat"), this.Light());
        }
    }

    private func BountyAcceptedNow() -> Int32 {
        let count: Int32 = 0;
        for c in this.m_bContracts {
            if c.state == 0 {
                count += 1;
            }
        }
        return count;
    }

    private func AddBountyAcceptButton(panel: ref<inkCompoundWidget>, width: Float) {
        let accepted: Int32 = this.BountyAcceptedNow();
        let ready: Bool = accepted < GRBounties.MaxOpen();
        let button: ref<inkCanvas> = new inkCanvas();
        button.SetName(n"gr_baccept");
        button.SetSize(new Vector2(width, 96.0));
        button.SetMargin(new inkMargin(0.0, 20.0, 0.0, 0.0));
        button.SetInteractive(true);
        button.RegisterToCallback(n"OnRelease", this, n"OnGRBountyAcceptClick");
        button.Reparent(panel);
        this.AddFill(button, this.Dark(), 0.9);
        let border: ref<GRBorder> = new GRBorder();
        border.SetAnchor(inkEAnchor.Fill);
        border.SetThickness(3.0);
        border.SetTintColor(ready ? this.Cyan() : this.Dim());
        border.Reparent(button);
        let title: ref<inkText> = this.PlaceText(button, this.Up(this.T("GR-BountyAccept")), 44, ready ? this.Cyan() : this.Dim(), n"Bold", 32.0, 22.0);
        title.SetAnchorPoint(new Vector2(0.0, 0.0));
        if !ready {
            let full: String = StrReplaceAll(this.T("GR-BountyAcceptFull"), "{n}", IntToString(accepted));
            full = StrReplaceAll(full, "{max}", IntToString(GRBounties.MaxOpen()));
            let sub: ref<inkText> = this.PlaceText(button, full, 28, this.Red(), n"Bold", width - 32.0, 32.0);
            sub.SetAnchorPoint(new Vector2(1.0, 0.0));
        }
    }

    private func UpdateBountyHint(show: Bool) {
        if !IsDefined(this.m_buttonHints) {
            return;
        }
        if show {
            this.m_buttonHints.AddButtonHint(n"upgrade_perk", this.T("GR-BountyAccept"));
            this.m_bHint = true;
            return;
        }
        if this.m_bHint {
            this.m_buttonHints.RemoveButtonHint(n"upgrade_perk");
            this.m_bHint = false;
        }
    }

    private func AcceptSelectedBounty() -> Bool {
        let c: ref<GRBounty> = this.ContractAt(this.m_bSel);
        if !IsDefined(c) || c.state != 3 || !IsDefined(this.m_bounties) {
            return false;
        }
        if this.BountyAcceptedNow() >= GRBounties.MaxOpen() {
            GRLog("Menu: no se puede aceptar #" + IntToString(c.nemesisId) + " (cupo de aceptados lleno)");
            return false;
        }
        let result: String = this.m_bounties.AcceptAt(c.index, c.nemesisId);
        GRLog("Menu: aceptar contrato -> " + result);
        this.FillBounty();
        this.BringToFront();
        this.PlaySound(n"Button", n"OnPress");
        return true;
    }

    protected cb func OnGRBountyAcceptClick(evt: ref<inkPointerEvent>) -> Bool {
        if !evt.IsAction(n"click") || !this.m_bounty {
            return false;
        }
        return this.AcceptSelectedBounty();
    }

    private func SetBountyView(view: Int32) {
        this.m_bView = view;
        this.m_bFixer = 0;
        this.m_bSel = -1;
        this.FillBounty();
        this.BringToFront();
        this.PlaySound(n"Button", n"OnPress");
    }

    private func BountyChangeFixer(delta: Int32) {
        if ArraySize(this.m_bFixerNames) <= 1 {
            return;
        }
        this.m_bFixer += delta;
        this.m_bSel = -1;
        this.FillBounty();
        this.BringToFront();
        this.PlaySound(n"Button", n"OnPress");
    }

    protected cb func OnGRBountyViewClick(evt: ref<inkPointerEvent>) -> Bool {
        if !evt.IsAction(n"click") || !this.m_bounty {
            return false;
        }
        let target: CName = evt.GetCurrentTarget().GetName();
        let i: Int32 = 0;
        while i < 3 {
            if Equals(target, StringToName("gr_bview_" + IntToString(i))) && i != this.m_bView {
                this.SetBountyView(i);
                return true;
            }
            i += 1;
        }
        return false;
    }

    protected cb func OnGRBountyCardClick(evt: ref<inkPointerEvent>) -> Bool {
        if !evt.IsAction(n"click") || !this.m_bounty {
            return false;
        }
        let target: CName = evt.GetCurrentTarget().GetName();
        let i: Int32 = 0;
        while i < ArraySize(this.m_bCards) {
            if Equals(target, StringToName("gr_bcard_" + IntToString(i))) {
                this.m_bSel = this.m_bCards[i];
                let j: Int32 = 0;
                while j < ArraySize(this.m_bFrames) && j < ArraySize(this.m_bCards) {
                    this.StyleBountyFrame(this.m_bFrames[j], this.ContractAt(this.m_bCards[j]), j == i);
                    j += 1;
                }
                this.FillBountyDetail(this.ContractAt(this.m_bSel));
                this.BringToFront();
                this.PlaySound(n"Button", n"OnPress");
                return true;
            }
            i += 1;
        }
        return false;
    }

    protected cb func OnBack(userData: ref<IScriptable>) -> Bool {
        if this.m_fOpen {
            this.CloseFusion();
        } else {
            super.OnBack(userData);
        }
    }

    protected cb func OnGRGlobalInput(evt: ref<inkPointerEvent>) -> Bool {
        // Any button release ends a scrollbar drag: put both grips back to red no matter where the pointer
        // actually let go (same fix GangRetaliationHistory/History.reds's own OnGRChronInput already has).
        // Registering OnRelease on the grip itself only resets it when the release happens while still
        // over the grip, which drifts out of sync the moment a drag ends anywhere else.
        if IsDefined(this.m_detailGrip) {
            this.m_detailGrip.SetTintColor(this.Red());
        }
        if IsDefined(this.m_fallenGrip) {
            this.m_fallenGrip.SetTintColor(this.Red());
        }
        if evt.IsHandled() || this.m_fOpen {
            return false;
        }
        if this.m_bounty {
            if evt.IsAction(n"sort_list") {
                this.SetBountyView((this.m_bView + 1) % 3);
                evt.Handle();
                return true;
            }
            if evt.IsAction(n"option_switch_prev") {
                this.BountyChangeFixer(-1);
                evt.Handle();
                return true;
            }
            if evt.IsAction(n"option_switch_next") {
                this.BountyChangeFixer(1);
                evt.Handle();
                return true;
            }
            if evt.IsAction(n"upgrade_perk") {
                if this.AcceptSelectedBounty() {
                    evt.Handle();
                    return true;
                }
            }
            return false;
        }
        if evt.IsAction(n"sort_list") {
            this.ToggleView();
            evt.Handle();
            return true;
        }
        if evt.IsAction(n"option_switch_prev") {
            this.ChangePage(-1);
            evt.Handle();
            return true;
        }
        if evt.IsAction(n"option_switch_next") {
            this.ChangePage(1);
            evt.Handle();
            return true;
        }
        return false;
    }
}

class GRInsertNemesisMenu extends ScriptableService {
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
        entry.menuWidget *= r"gangretaliation\\gui\\nemesis.inkwidget";
        entry.name = n"gangretaliation_nemesis_menu";
        ArrayPush(resource.menusEntries, entry);
        let bounty: inkMenuEntry;
        bounty.depth = 0u;
        bounty.spawnMode = inkSpawnMode.SingleAndMultiplayer;
        bounty.isAffectedByFadeout = true;
        bounty.menuWidget *= r"gangretaliation\\gui\\nemesis.inkwidget";
        bounty.name = n"gangretaliation_bounty_menu";
        ArrayPush(resource.menusEntries, bounty);
    }
}

@wrapMethod(MenuHubLogicController)
protected cb func OnInitialize() -> Bool {
    let result: Bool = wrappedMethod();
    this.GRAddNemesisButton();
    this.GRAddBountyButton();
    return result;
}

@addMethod(MenuHubLogicController)
private final func GRAddBountyButton() {
    let settings: ref<GRSettings> = GRSettings.Get(GetGameInstance());
    if IsDefined(settings) && !settings.enabled {
        return;
    }
    let container: ref<inkCompoundWidget> = this.GetRootCompoundWidget().GetWidgetByPathName(n"mainMenu/buttonsContainer/panel_journal") as inkCompoundWidget;
    if !IsDefined(container) {
        GRLog("Menu: no se encontro la columna JOURNAL del menu principal");
        return;
    }
    let found: Bool = false;
    let highest: Float = 0.0;
    let layout: String = "";
    let count: Int32 = container.GetNumChildren();
    let i: Int32 = 0;
    while i < count {
        let child: wref<inkWidget> = container.GetWidgetByIndex(i);
        if IsDefined(child) && NotEquals(child.GetName(), n"GangRetaliation_Bounty") {
            let margin: inkMargin = child.GetMargin();
            layout += " " + NameToString(child.GetName()) + "=" + FloatToString(margin.top) + (child.IsVisible() ? "" : "(oculto)");
            if child.IsVisible() && (!found || margin.top < highest) {
                highest = margin.top;
                found = true;
            }
        }
        i += 1;
    }
    let top: Float = highest - 170.0;
    let data: ref<GRMenuData> = GRMenuData.Get(GetGameInstance());
    if !IsDefined(data) || data.ConsumeBountyLayoutLog() {
        GRLog("Menu: columna JOURNAL (margin.top):" + layout + " -> recompensas en top " + FloatToString(top) + " (arriba de todo)");
    }
    let button: ref<inkWidget> = this.SpawnFromLocal(container, n"menu_button");
    button.SetName(n"GangRetaliation_Bounty");
    button.SetMargin(new inkMargin(0.0, top, 0.0, 0.0));
    let controller: ref<MenuItemController> = button.GetController() as MenuItemController;
    controller.Init(GRBountyMenuItem(GetGameInstance()));
}

public func GRBountyMenuItem(gi: GameInstance) -> MenuData {
    let data: MenuData;
    data.disabled = false;
    data.fullscreenName = n"gangretaliation_bounty_menu";
    data.identifier = 63;
    data.parentIdentifier = 5;
    data.label = GRSystem.Get(gi).GetText("GR-BountyButton");
    data.icon = n"ico_data_hub";
    return data;
}

@wrapMethod(MenuScenario_HubMenu)
protected cb func OnOpenMenu(menuName: CName, opt userData: ref<IScriptable>) -> Bool {
    let data: ref<GRMenuData> = GRMenuData.Get(GetGameInstance());
    if IsDefined(data) {
        data.SetBountyMode(Equals(menuName, n"gangretaliation_bounty_menu"));
    }
    return wrappedMethod(menuName, userData);
}

@addMethod(MenuHubLogicController)
private final func GRAddNemesisButton() {
    let settings: ref<GRSettings> = GRSettings.Get(GetGameInstance());
    if IsDefined(settings) && !settings.enabled {
        return;
    }
    let container: ref<inkCompoundWidget> = this.GetRootCompoundWidget().GetWidgetByPathName(n"mainMenu/buttonsContainer/panel_character") as inkCompoundWidget;
    if !IsDefined(container) {
        GRLog("Menu: no se encontro el panel del menu principal");
        return;
    }
    let button: ref<inkWidget> = this.SpawnFromLocal(container, n"menu_button");
    button.SetName(n"GangRetaliation_Nemesis");
    let top: Float = 500.0;
    if GRHasDarkFuture() {
        top += 170.0;
    }
    if GRHasStealthRunner() {
        top += 170.0;
    }
    button.SetMargin(new inkMargin(0.0, top, 0.0, 0.0));

    let controller: ref<MenuItemController> = button.GetController() as MenuItemController;
    controller.Init(GRNemesisMenuItem(GetGameInstance()));
}

public func GRNemesisMenuItem(gi: GameInstance) -> MenuData {
    let data: MenuData;
    data.disabled = false;
    data.fullscreenName = n"gangretaliation_nemesis_menu";
    data.identifier = 61;
    data.parentIdentifier = 2;
    data.label = GRSystem.Get(gi).GetText("GR-MenuButton");
    data.icon = n"ico_data_hub";
    return data;
}


@addMethod(MenuScenario_HubMenu)
protected cb func OnGangRetaliationApiOpenView(userData: ref<IScriptable>) -> Bool {
    return this.OnOpenMenu(n"gangretaliation_nemesis_menu", null);
}

@addMethod(gameuiMenuGameController)
public final func GangRetaliationGetDispatcher() -> wref<inkMenuEventDispatcher> {
    return this.m_baseEventDispatcher;
}

@if(ModuleExists("DarkFuture.UI"))
public func GRHasDarkFuture() -> Bool {
    return true;
}

@if(!ModuleExists("DarkFuture.UI"))
public func GRHasDarkFuture() -> Bool {
    return false;
}

@if(ModuleExists("StealthRunner"))
public func GRHasStealthRunner() -> Bool {
    return true;
}

@if(!ModuleExists("StealthRunner"))
public func GRHasStealthRunner() -> Bool {
    return false;
}
