module GangRetaliation

import Codeware.UI.VirtualResolutionWatcher



@addField(NameplateBarLogicController)
private let m_grFleeMark: wref<inkRectangle>;

@addMethod(NameplateBarLogicController)
public func GRSetFleeMark(fraction: Float, show: Bool) {
    if !IsDefined(this.m_grFleeMark) {
        if !show {
            return;
        }
        let wrapper: ref<inkCompoundWidget> = this.m_rootWidget.GetWidgetByPathName(n"wrapper") as inkCompoundWidget;
        if !IsDefined(wrapper) {
            return;
        }
        let mark: ref<inkRectangle> = new inkRectangle();
        mark.SetName(n"gr_flee_mark");
        mark.SetSize(new Vector2(2.0, 13.0));
        mark.SetHAlign(inkEHorizontalAlign.Left);
        mark.SetVAlign(inkEVerticalAlign.Center);
        mark.SetTintColor(GRHud.Yellow());
        mark.Reparent(wrapper);
        this.m_grFleeMark = mark;
    }
    let width: Float = 150.0;
    let bg: ref<inkWidget> = this.m_rootWidget.GetWidgetByPathName(n"wrapper/bg_black");
    if IsDefined(bg) && bg.GetWidth() > 0.0 {
        width = bg.GetWidth();
    }
    this.m_grFleeMark.SetMargin(new inkMargin(width * fraction - 1.0, 0.0, 0.0, 0.0));
    this.m_grFleeMark.SetVisible(show);
}

@addField(NameplateVisualsLogicController)
private let m_grCheckedID: EntityID;

@addField(NameplateVisualsLogicController)
private let m_grCheckedAt: Float;

@addField(NameplateVisualsLogicController)
private let m_grCanFlee: Bool;

@wrapMethod(NameplateVisualsLogicController)
public final func SetVisualData(puppet: ref<GameObject>, const incomingData: script_ref<NPCNextToTheCrosshair>, opt isNewNpc: Bool) -> Void {
    wrappedMethod(puppet, incomingData, isNewNpc);
    let prof: ref<GRProfiler> = GRProfiler.Get(puppet.GetGame());
    if IsDefined(prof) {
        prof.nameplates += 1;
        if prof.hooksOff {
            return;
        }
    }
    this.GRUpdateNameplate(this.m_cachedPuppet as ScriptedPuppet);
}

@addMethod(NameplateVisualsLogicController)
private func GRUpdateNameplate(npc: ref<ScriptedPuppet>) {
    if !IsDefined(npc) {
        if IsDefined(this.m_healthController) {
            this.m_healthController.GRSetFleeMark(0.0, false);
        }
        return;
    }
    let gi: GameInstance = npc.GetGame();
    let settings: ref<GRSettings> = GRSettings.Get(gi);
    if !IsDefined(settings) {
        return;
    }
    let scale: Float = ClampF(settings.nameplateScale, 1.0, 2.0);
    inkWidgetRef.SetScale(this.m_healthbarWidget, new Vector2(scale, scale));

    let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(gi));
    if npc.GetEntityID() != this.m_grCheckedID || now - this.m_grCheckedAt > 0.5 {
        let det: ref<GRDetection> = GRDetection.Get(gi);
        this.m_grCanFlee = IsDefined(det) && StrLen(det.GetFleeBlocker(npc)) == 0;
        this.m_grCheckedID = npc.GetEntityID();
        this.m_grCheckedAt = now;
    }
    if IsDefined(this.m_healthController) {
        this.m_healthController.GRSetFleeMark(GRIntegrations.GetFleePercent(settings.fleeHealthPercent) / 100.0, settings.fleeMarkEnabled && this.m_grCanFlee);
    }
}


public class GRThreatRow {
    public let root: ref<inkVerticalPanel>;
    public let gang: ref<inkRectangle>;
    public let tag: ref<inkText>;
    public let name: ref<inkText>;
    public let distance: ref<inkText>;
    public let fill: ref<inkRectangle>;
    public let mark: ref<inkRectangle>;
}

public class GRThreat {
    public let npc: wref<ScriptedPuppet>;
    public let health: Float;
    public let distance: Float;
    public let nemesisName: String;
    public let isTarget: Bool;
    public let canFlee: Bool;
}

public class GRHudTick extends DelayCallback {
    public let hud: wref<GRHud>;

    public func Call() -> Void {
        if IsDefined(this.hud) {
            this.hud.Tick();
        }
    }
}

@wrapMethod(DamageSystem)
private final func InvulnerabilityCheck(hitEvent: ref<gameHitEvent>, cache: ref<CacheData>) -> Void {
    wrappedMethod(hitEvent, cache);
    if IsDefined(hitEvent.target) && hitEvent.target.IsPlayer() {
        let hud: ref<GRHud> = GRHud.Get(hitEvent.target.GetGame());
        if IsDefined(hud) && hud.IsGodMode() {
            hitEvent.attackData.AddFlag(hitFlag.DealNoDamage, n"GRDebug");
        }
    }
}

public class GRHud extends ScriptableSystem {
    public static func Get(gi: GameInstance) -> ref<GRHud> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRHud") as GRHud;
    }

    private let m_box: ref<inkCanvas>;
    private let m_bg: ref<inkRectangle>;
    private let m_panel: ref<inkVerticalPanel>;
    private let m_watcher: ref<VirtualResolutionWatcher>;
    private let m_header: ref<inkHorizontalPanel>;
    private let m_headerH: Float;
    private let m_rowH: Float;
    private let m_moreH: Float;
    private let m_count: ref<inkText>;
    private let m_more: ref<inkText>;
    private let m_rows: array<ref<GRThreatRow>>;
    private let m_lastThreatAt: Float;
    private let m_session: Int32;
    private let m_radialListener: ref<CallbackHandle>;
    private let m_debugInfo: String;
    private let m_godAdd: String;

    private let c_maxRows: Int32 = 10;
    private let c_barWidth: Float = 380.0;
    private let c_padX: Float = 24.0;
    private let c_padY: Float = 18.0;

    private let m_debugBox: ref<inkCanvas>;
    private let m_debugPanel: ref<inkVerticalPanel>;
    private let m_debugRows: array<ref<inkText>>;
    private let m_debugLines: array<String>;
    private let c_debugMaxLines: Int32 = 8;
    private let c_debugLineChars: Int32 = 220;

    private let m_districtBox: ref<inkCanvas>;
    private let m_districtText: ref<inkText>;
    private let m_districtCheckAt: Float;

    public static func Yellow() -> HDRColor {
        return new HDRColor(1.0, 0.82, 0.4, 1.0);
    }

    private static func White() -> HDRColor {
        return new HDRColor(0.91, 0.93, 0.95, 1.0);
    }

    private static func Grey() -> HDRColor {
        return new HDRColor(0.6, 0.64, 0.7, 1.0);
    }

    private static func HealthRed() -> HDRColor {
        return new HDRColor(1.1761, 0.3809, 0.3476, 1.0);
    }

    private static func Amber() -> HDRColor {
        return new HDRColor(0.96, 0.65, 0.14, 1.0);
    }

    private static func Gold() -> HDRColor {
        return new HDRColor(0.89, 0.69, 0.29, 1.0);
    }

    public static func RankMappinColor(rank: Int32) -> HDRColor {
        if rank >= 3 {
            return GRHud.Gold();
        }
        if rank == 2 {
            return GRHud.HealthRed();
        }
        return GRHud.White();
    }

    private static func GangColor(gang: String) -> HDRColor {
        switch gang {
            case "Maelstrom": return new HDRColor(0.9, 0.28, 0.3, 1.0);
            case "TygerClaws": return new HDRColor(0.2, 0.85, 0.75, 1.0);
            case "Valentinos": return new HDRColor(0.95, 0.75, 0.25, 1.0);
            case "SixthStreet": return new HDRColor(0.35, 0.55, 1.0, 1.0);
            case "Animals": return new HDRColor(0.6, 0.85, 0.3, 1.0);
            case "VoodooBoys": return new HDRColor(0.55, 0.45, 1.0, 1.0);
            case "Wraiths": return new HDRColor(0.9, 0.55, 0.3, 1.0);
            case "Scavengers": return new HDRColor(0.75, 0.75, 0.75, 1.0);
            case "Barghest": return new HDRColor(0.65, 0.7, 0.45, 1.0);
            default: return new HDRColor(0.45, 0.5, 0.58, 1.0);
        }
    }

    private func OnPlayerAttach(request: ref<PlayerAttachRequest>) {
        this.m_session += 1;
        this.m_box = null;
        this.m_panel = null;
        ArrayClear(this.m_rows);
        let quickSlots: ref<IBlackboard> = GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().UI_QuickSlotsData);
        if IsDefined(quickSlots) && !IsDefined(this.m_radialListener) {
            this.m_radialListener = quickSlots.RegisterListenerBool(GetAllBlackboardDefs().UI_QuickSlotsData.UIRadialContextRequest, this, n"OnRadialContextChange");
        }
        this.ScheduleTick();
    }

    protected cb func OnRadialContextChange(open: Bool) -> Bool {
        if open && IsDefined(this.m_box) {
            this.m_box.SetVisible(false);
        }
    }

    private func IsRadialOpen() -> Bool {
        let quickSlots: ref<IBlackboard> = GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().UI_QuickSlotsData);
        return IsDefined(quickSlots) && quickSlots.GetBool(GetAllBlackboardDefs().UI_QuickSlotsData.UIRadialContextRequest);
    }

    private func ScheduleTick() {
        let tick: ref<GRHudTick> = new GRHudTick();
        tick.hud = this;
        let visible: Bool = IsDefined(this.m_box) && this.m_box.IsVisible();
        GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(tick, visible ? 0.1 : 0.25, false);
    }

    public func Tick() {
        let session: Int32 = this.m_session;
        let prof: ref<GRProfiler> = GRProfiler.Get(this.GetGameInstance());
        if IsDefined(prof) {
            prof.hudTicks += 1;
        }
        if !IsDefined(prof) || !prof.hooksOff {
            this.Update();
            this.CheckDistrictChange();
        }
        if session == this.m_session {
            this.ScheduleTick();
        }
    }

    // Small standalone panel, always showing the player's current district chain (leaf -> root) while
    // on-screen debug is on - a live readout, not a log, so it just overwrites in place as you walk
    // around. Positioned directly above the debug log box (same horizontal alignment). Handy for
    // checking the Badlands sub-area hierarchy without opening WolvenKit.
    private func EnsureDistrictPanel() -> Bool {
        if IsDefined(this.m_districtBox) {
            return true;
        }
        let window: ref<inkCompoundWidget> = GameInstance.GetInkSystem().GetLayer(n"inkHUDLayer").GetVirtualWindow();
        let hudRoot: ref<inkCompoundWidget> = IsDefined(window) ? window.GetWidgetByPathName(n"Root") as inkCompoundWidget : null;
        if !IsDefined(hudRoot) {
            return false;
        }
        let slot: ref<inkCanvas> = new inkCanvas();
        slot.SetName(n"GangRetaliationDistrictSlot");
        slot.SetSize(new Vector2(3840.0, 2160.0));
        slot.SetRenderTransformPivot(new Vector2(0.0, 0.0));
        slot.Reparent(hudRoot);
        let watcher: ref<VirtualResolutionWatcher> = new VirtualResolutionWatcher();
        watcher.Initialize(this.GetGameInstance());
        watcher.ScaleWidget(slot);

        // Anchored by its TOP edge (fixed margin-top) rather than tied to the log box's position, so
        // when the chain is long enough to wrap to a second line, the box grows downward from a fixed
        // point instead of needing to shift - with enough headroom above the log box (which starts
        // around y=760 in this 2160-tall virtual canvas) that even two lines never overlaps it.
        let box: ref<inkCanvas> = new inkCanvas();
        box.SetName(n"gr_district");
        box.SetAnchor(inkEAnchor.TopRight);
        box.SetAnchorPoint(new Vector2(1.0, 0.0));
        box.SetMargin(new inkMargin(0.0, 640.0, 70.0, 0.0));
        box.SetSize(new Vector2(1040.0, 50.0));
        box.SetVisible(false);

        let bg: ref<inkRectangle> = new inkRectangle();
        bg.SetAnchor(inkEAnchor.Fill);
        bg.SetTintColor(new HDRColor(0.02, 0.02, 0.03, 1.0));
        bg.SetOpacity(0.92);
        bg.Reparent(box);
        let border: ref<GRBorder> = new GRBorder();
        border.SetAnchor(inkEAnchor.Fill);
        border.SetThickness(2.0);
        border.SetTintColor(new HDRColor(0.4, 0.45, 0.5, 1.0));
        border.Reparent(box);

        let text: ref<inkText> = this.NewText(27, GRHud.White(), n"Medium");
        text.SetAnchor(inkEAnchor.TopLeft);
        text.SetMargin(new inkMargin(16.0, 12.0, 16.0, 12.0));
        text.SetWrappingAtPosition(995.0);
        text.SetText("");
        text.Reparent(box);

        box.Reparent(slot);
        this.m_districtBox = box;
        this.m_districtText = text;
        return true;
    }

    // Throttled to once a second (Tick itself runs every 0.1-0.25s) since GetDistrictChain() walks the
    // district tree and there is no need to re-check that every single tick.
    private func CheckDistrictChange() {
        let settings: ref<GRSettings> = GRSettings.Get(this.GetGameInstance());
        if !IsDefined(settings) || !settings.debugOnScreen || !settings.debugOnScreenCampaign {
            if IsDefined(this.m_districtBox) {
                this.m_districtBox.SetVisible(false);
            }
            return;
        }
        let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
        if now - this.m_districtCheckAt < 1.0 {
            return;
        }
        this.m_districtCheckAt = now;
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());
        if !IsDefined(spawner) || !this.EnsureDistrictPanel() {
            return;
        }
        let chain: String = spawner.GetDistrictChain();
        this.m_districtText.SetText(chain);
        this.m_districtBox.SetVisible(StrLen(chain) > 0);
        if StrLen(chain) > 0 {
            let textH: Float = this.m_districtText.GetDesiredSize().Y;
            this.m_districtBox.SetSize(new Vector2(1040.0, MaxF(50.0, textH + 24.0)));
        }
    }

    private func NewText(size: Int32, color: HDRColor, style: CName) -> ref<inkText> {
        let label: ref<inkText> = new inkText();
        label.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        label.SetFontStyle(style);
        label.SetFontSize(size);
        label.SetTintColor(color);
        return label;
    }

    private func T(key: String) -> String {
        let loc: ref<GRSystem> = GRSystem.Get(this.GetGameInstance());
        return IsDefined(loc) ? loc.GetText(key) : key;
    }

    private func EnsurePanel() -> Bool {
        if IsDefined(this.m_panel) {
            return true;
        }
        let window: ref<inkCompoundWidget> = GameInstance.GetInkSystem().GetLayer(n"inkHUDLayer").GetVirtualWindow();
        let hudRoot: ref<inkCompoundWidget> = IsDefined(window) ? window.GetWidgetByPathName(n"Root") as inkCompoundWidget : null;
        if !IsDefined(hudRoot) {
            return false;
        }
        let slot: ref<inkCanvas> = new inkCanvas();
        slot.SetName(n"GangRetaliationFullScreenSlot");
        slot.SetSize(new Vector2(3840.0, 2160.0));
        slot.SetRenderTransformPivot(new Vector2(0.0, 0.0));
        slot.Reparent(hudRoot);
        this.m_watcher = new VirtualResolutionWatcher();
        this.m_watcher.Initialize(this.GetGameInstance());
        this.m_watcher.ScaleWidget(slot);

        let box: ref<inkCanvas> = new inkCanvas();
        box.SetName(n"gr_threats");
        box.SetAnchor(inkEAnchor.TopLeft);
        box.SetRenderTransformPivot(new Vector2(0.0, 0.0));
        box.SetSize(new Vector2(this.c_barWidth + 2.0 * this.c_padX, 200.0));
        box.SetVisible(false);
        let bg: ref<inkRectangle> = new inkRectangle();
        bg.SetAnchor(inkEAnchor.Fill);
        bg.SetTintColor(new HDRColor(0.043, 0.055, 0.075, 1.0));
        bg.Reparent(box);
        this.m_bg = bg;
        let border: ref<GRBorder> = new GRBorder();
        border.SetAnchor(inkEAnchor.Fill);
        border.SetThickness(2.0);
        border.SetTintColor(new HDRColor(0.145, 0.176, 0.224, 1.0));
        border.Reparent(box);

        let panel: ref<inkVerticalPanel> = new inkVerticalPanel();
        panel.SetAnchor(inkEAnchor.TopLeft);
        panel.SetFitToContent(true);
        panel.SetMargin(new inkMargin(this.c_padX, this.c_padY, 0.0, 0.0));
        panel.SetChildMargin(new inkMargin(0.0, 0.0, 0.0, 12.0));

        let header: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        header.SetFitToContent(true);
        let title: ref<inkText> = this.NewText(30, GRHud.White(), n"Bold");
        title.SetText(this.T("GR-HudThreats"));
        title.SetMargin(new inkMargin(0.0, 0.0, 14.0, 0.0));
        title.Reparent(header);
        this.m_count = this.NewText(30, GRHud.HealthRed(), n"Bold");
        this.m_count.Reparent(header);
        header.Reparent(panel);
        this.m_header = header;

        let i: Int32 = 0;
        while i < this.c_maxRows {
            ArrayPush(this.m_rows, this.NewRow(panel));
            i += 1;
        }
        this.m_more = this.NewText(22, GRHud.Grey(), n"Medium");
        this.m_more.Reparent(panel);

        panel.Reparent(box);
        box.Reparent(slot);
        this.m_box = box;
        this.m_panel = panel;
        return true;
    }

    // A plain, silent, always-on scrolling panel - unlike GRDetection.Notify()'s SimpleScreenMessage
    // toasts, which have a built-in slide-in animation and stinger sound baked into the native widget
    // itself (no way to suppress just that), so they're wrong for a fast-moving line-by-line log view.
    // Push-based rather than ticked: a line is only ever written to the on-screen ring buffer at the
    // exact moment GRDetection.Debug() decides to log it, so there's no polling/refresh loop needed here.
    private func EnsureDebugPanel() -> Bool {
        if IsDefined(this.m_debugPanel) {
            return true;
        }
        let window: ref<inkCompoundWidget> = GameInstance.GetInkSystem().GetLayer(n"inkHUDLayer").GetVirtualWindow();
        let hudRoot: ref<inkCompoundWidget> = IsDefined(window) ? window.GetWidgetByPathName(n"Root") as inkCompoundWidget : null;
        if !IsDefined(hudRoot) {
            return false;
        }
        let slot: ref<inkCanvas> = new inkCanvas();
        slot.SetName(n"GangRetaliationDebugSlot");
        slot.SetSize(new Vector2(3840.0, 2160.0));
        slot.SetRenderTransformPivot(new Vector2(0.0, 0.0));
        slot.Reparent(hudRoot);
        let watcher: ref<VirtualResolutionWatcher> = new VirtualResolutionWatcher();
        watcher.Initialize(this.GetGameInstance());
        watcher.ScaleWidget(slot);

        let box: ref<inkCanvas> = new inkCanvas();
        box.SetName(n"gr_debug_log");
        box.SetAnchor(inkEAnchor.CenterRight);
        box.SetAnchorPoint(new Vector2(1.0, 0.5));
        box.SetMargin(new inkMargin(0.0, 0.0, 70.0, 0.0));
        box.SetSize(new Vector2(1040.0, 640.0));
        box.SetVisible(false);

        let bg: ref<inkRectangle> = new inkRectangle();
        bg.SetAnchor(inkEAnchor.Fill);
        bg.SetTintColor(new HDRColor(0.02, 0.02, 0.03, 1.0));
        bg.SetOpacity(0.92);
        bg.Reparent(box);
        let border: ref<GRBorder> = new GRBorder();
        border.SetAnchor(inkEAnchor.Fill);
        border.SetThickness(2.0);
        border.SetTintColor(new HDRColor(0.4, 0.45, 0.5, 1.0));
        border.Reparent(box);

        let panel: ref<inkVerticalPanel> = new inkVerticalPanel();
        panel.SetAnchor(inkEAnchor.TopLeft);
        panel.SetFitToContent(true);
        panel.SetMargin(new inkMargin(16.0, 12.0, 0.0, 0.0));
        panel.SetChildMargin(new inkMargin(0.0, 0.0, 0.0, 6.0));

        let i: Int32 = 0;
        while i < this.c_debugMaxLines {
            let row: ref<inkText> = this.NewText(27, GRHud.White(), n"Medium");
            row.SetText("");
            row.SetWrappingAtPosition(995.0);
            row.SetVisible(false);
            row.Reparent(panel);
            ArrayPush(this.m_debugRows, row);
            i += 1;
        }
        panel.Reparent(box);
        box.Reparent(slot);
        this.m_debugBox = box;
        this.m_debugPanel = panel;
        return true;
    }

    private func Pad2(v: Int32) -> String {
        return v < 10 ? "0" + IntToString(v) : IntToString(v);
    }

    // redscript has no native wall-clock accessor, only simulation time (GameInstance.GetSimTime) - so
    // this is an elapsed session clock (H:MM:SS since the engine started ticking), not real-world time of
    // day. That's fine for its purpose: letting two lines in a recorded video be compared to each other,
    // not matched up against gamelog.log (which is wall-clock and needs the game closed to flush anyway).
    private func ClockStamp() -> String {
        let totalSec: Int32 = Cast<Int32>(EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance())));
        let h: Int32 = totalSec / 3600 % 24;
        let m: Int32 = totalSec / 60 % 60;
        let s: Int32 = totalSec % 60;
        return this.Pad2(h) + ":" + this.Pad2(m) + ":" + this.Pad2(s);
    }

    // Called directly from GRDetection.Debug() (gated there on settings.debugOnScreen) rather than from
    // every individual call site - that already covers exactly the detection/flee/hide/disarm messages,
    // since those all funnel through the same Debug() choke point, without also pulling in unrelated
    // subsystems (stronghold scanning, intel rolls, etc.) that log through their own Debug() methods.
    public func PushDebugLine(msg: String) {
        if !this.EnsureDebugPanel() {
            return;
        }
        let line: String = this.ClockStamp() + "  " + msg;
        if StrLen(line) > this.c_debugLineChars {
            line = StrLeft(line, this.c_debugLineChars) + "...";
        }
        ArrayPush(this.m_debugLines, line);
        while ArraySize(this.m_debugLines) > this.c_debugMaxLines {
            ArrayErase(this.m_debugLines, 0);
        }
        this.RefreshDebugRows();
        this.m_debugBox.SetVisible(true);
    }

    // Shared between PushDebugLine (a new line arrived) and Update (the panel was just turned on and
    // should show whatever's already in m_debugLines without waiting for a new line).
    private func RefreshDebugRows() {
        let i: Int32 = 0;
        while i < ArraySize(this.m_debugRows) {
            if i < ArraySize(this.m_debugLines) {
                this.m_debugRows[i].SetText(this.m_debugLines[i]);
                this.m_debugRows[i].SetVisible(true);
            } else {
                this.m_debugRows[i].SetVisible(false);
            }
            i += 1;
        }
    }

    private func PlaceBox(settings: ref<GRSettings>) {
        let x: Float = settings.threatPanelX;
        let y: Float = settings.threatPanelY;
        this.m_box.SetTranslation(x, y);
        this.m_box.SetScale(new Vector2(settings.threatPanelScale, settings.threatPanelScale));
        this.m_bg.SetOpacity(settings.threatPanelOpacity);
        this.m_debugInfo = "panel: x=" + FloatToStringPrec(x, 0) + " y=" + FloatToStringPrec(y, 0)
            + " scale=" + FloatToStringPrec(settings.threatPanelScale, 2)
            + " opacity=" + FloatToStringPrec(settings.threatPanelOpacity, 2) + " rows=" + IntToString(settings.threatPanelRows);
    }

    public func GetDebugInfo() -> String {
        return StrLen(this.m_debugInfo) > 0 ? this.m_debugInfo : "panel: not shown yet";
    }

    public func ToggleGodMode() -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) {
            return false;
        }
        let god: ref<GodModeSystem> = GameInstance.GetGodModeSystem(this.GetGameInstance());
        let id: EntityID = player.GetEntityID();
        if this.IsGodMode() {
            god.ClearGodMode(id, n"GRDebug");
            this.m_godAdd = "cleared";
        } else {
            let inv: Bool = god.AddGodMode(id, gameGodModeType.Invulnerable, n"GRDebug");
            let imm: Bool = god.AddGodMode(id, gameGodModeType.Immortal, n"GRDebug");
            this.m_godAdd = "add inv=" + ToString(inv) + " imm=" + ToString(imm);
        }
        GRLog("Debug: modo dios " + (this.IsGodMode() ? "ON" : "OFF") + " (" + this.GetGodModeInfo() + ")");
        return this.IsGodMode();
    }

    public func GetGodModeInfo() -> String {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) {
            return "god: no player";
        }
        let god: ref<GodModeSystem> = GameInstance.GetGodModeSystem(this.GetGameInstance());
        let id: EntityID = player.GetEntityID();
        let sources: String = "";
        let inv: array<CName> = god.GetGodModeSources(id, gameGodModeType.Invulnerable);
        for source in inv {
            sources += NameToString(source) + " ";
        }
        return "god: inv=" + IntToString(Cast<Int32>(god.GetGodModeCount(id, gameGodModeType.Invulnerable)))
            + " imm=" + IntToString(Cast<Int32>(god.GetGodModeCount(id, gameGodModeType.Immortal)))
            + " src=[" + sources + "] on=" + ToString(this.IsGodMode()) + " | " + this.m_godAdd;
    }

    public func IsGodMode() -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) {
            return false;
        }
        let god: ref<GodModeSystem> = GameInstance.GetGodModeSystem(this.GetGameInstance());
        let inv: array<CName> = god.GetGodModeSources(player.GetEntityID(), gameGodModeType.Invulnerable);
        let imm: array<CName> = god.GetGodModeSources(player.GetEntityID(), gameGodModeType.Immortal);
        return ArrayContains(inv, n"GRDebug") || ArrayContains(imm, n"GRDebug");
    }

    private func NewRow(parent: ref<inkCompoundWidget>) -> ref<GRThreatRow> {
        let row: ref<GRThreatRow> = new GRThreatRow();
        row.root = new inkVerticalPanel();
        row.root.SetFitToContent(true);
        row.root.SetChildMargin(new inkMargin(0.0, 0.0, 0.0, 5.0));

        let line: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        line.SetFitToContent(true);
        row.gang = new inkRectangle();
        row.gang.SetSize(new Vector2(12.0, 12.0));
        row.gang.SetVAlign(inkEVerticalAlign.Center);
        row.gang.SetMargin(new inkMargin(0.0, 0.0, 10.0, 0.0));
        row.gang.Reparent(line);
        row.tag = this.NewText(20, GRHud.Gold(), n"Bold");
        row.tag.SetText(this.T("GR-HudNemesis"));
        row.tag.SetVAlign(inkEVerticalAlign.Center);
        row.tag.SetMargin(new inkMargin(0.0, 0.0, 10.0, 0.0));
        row.tag.Reparent(line);
        row.name = this.NewText(26, GRHud.White(), n"Medium");
        row.name.SetVAlign(inkEVerticalAlign.Center);
        row.name.SetMargin(new inkMargin(0.0, 0.0, 14.0, 0.0));
        row.name.Reparent(line);
        row.distance = this.NewText(22, GRHud.Grey(), n"Medium");
        row.distance.SetVAlign(inkEVerticalAlign.Center);
        row.distance.Reparent(line);
        line.Reparent(row.root);

        let bar: ref<inkCanvas> = new inkCanvas();
        bar.SetSize(new Vector2(this.c_barWidth, 8.0));
        let bg: ref<inkRectangle> = new inkRectangle();
        bg.SetSize(new Vector2(this.c_barWidth, 8.0));
        bg.SetTintColor(new HDRColor(0.16, 0.08, 0.09, 1.0));
        bg.Reparent(bar);
        row.fill = new inkRectangle();
        row.fill.SetSize(new Vector2(this.c_barWidth, 8.0));
        row.fill.Reparent(bar);
        row.mark = new inkRectangle();
        row.mark.SetSize(new Vector2(3.0, 16.0));
        row.mark.SetAnchor(inkEAnchor.CenterLeft);
        row.mark.SetAnchorPoint(new Vector2(0.5, 0.5));
        row.mark.SetTintColor(GRHud.Yellow());
        row.mark.Reparent(bar);
        bar.Reparent(row.root);

        row.root.SetVisible(false);
        row.root.Reparent(parent);
        return row;
    }

    private func Update() {
        let gi: GameInstance = this.GetGameInstance();
        let settings: ref<GRSettings> = GRSettings.Get(gi);
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        // PushDebugLine (called from GRDetection.Debug(), gated there on settings.debugOnScreen) is the only
        // thing that shows/hides the debug panel otherwise, so toggling the setting had no effect until the
        // next line arrived - turning it off wouldn't hide an already-visible panel, and turning it on
        // wouldn't show the backlog already sitting in m_debugLines. Handle both here on the existing tick.
        if IsDefined(settings) && settings.debugOnScreen {
            if this.EnsureDebugPanel() {
                this.RefreshDebugRows();
                this.m_debugBox.SetVisible(true);
            }
        } else {
            if IsDefined(this.m_debugBox) {
                this.m_debugBox.SetVisible(false);
            }
        }
        if !IsDefined(settings) || !IsDefined(player) || !settings.enabled || !settings.threatPanelEnabled || this.IsRadialOpen() {
            if IsDefined(this.m_box) {
                this.m_box.SetVisible(false);
            }
            return;
        }
        let threats: array<ref<GRThreat>> = this.CollectThreats(player);
        let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(gi));
        if ArraySize(threats) > 0 {
            this.m_lastThreatAt = now;
        }
        if ArraySize(threats) == 0 && now - this.m_lastThreatAt > 3.0 {
            if IsDefined(this.m_box) {
                this.m_box.SetVisible(false);
            }
            return;
        }
        if ArraySize(threats) == 0 || !this.EnsurePanel() {
            return;
        }
        this.PlaceBox(settings);
        this.m_box.SetVisible(true);
        this.m_count.SetText(IntToString(ArraySize(threats)));
        let flee: Float = GRIntegrations.GetFleePercent(settings.fleeHealthPercent);
        let shown: Int32 = Min(settings.threatPanelRows, ArraySize(this.m_rows));
        let i: Int32 = 0;
        while i < ArraySize(this.m_rows) {
            let row: ref<GRThreatRow> = this.m_rows[i];
            if i < shown && i < ArraySize(threats) {
                this.FillRow(row, threats[i], flee, settings.fleeMarkEnabled);
            } else {
                row.root.SetVisible(false);
            }
            i += 1;
        }
        let hidden: Int32 = ArraySize(threats) - shown;
        this.m_more.SetVisible(hidden > 0);
        if hidden > 0 {
            this.m_more.SetText(StrReplace(this.T("GR-HudMore"), "%d", IntToString(hidden)));
        }
        this.FitBox(Min(shown, ArraySize(threats)), hidden > 0);
    }

    private func FitBox(rows: Int32, more: Bool) {
        let gap: Float = 12.0;
        if this.m_header.GetDesiredSize().Y > 0.0 {
            this.m_headerH = this.m_header.GetDesiredSize().Y;
        }
        if this.m_rows[0].root.GetDesiredSize().Y > 0.0 {
            this.m_rowH = this.m_rows[0].root.GetDesiredSize().Y;
        }
        if this.m_more.GetDesiredSize().Y > 0.0 {
            this.m_moreH = this.m_more.GetDesiredSize().Y;
        }
        let headerH: Float = this.m_headerH;
        let rowH: Float = this.m_rowH;
        let content: Vector2 = this.m_panel.GetDesiredSize();
        if headerH <= 0.0 || rowH <= 0.0 {
            if content.X > 0.0 && content.Y > 0.0 {
                this.m_box.SetSize(new Vector2(content.X + 2.0 * this.c_padX, content.Y + 2.0 * this.c_padY));
            }
            return;
        }
        let moreH: Float = this.m_moreH > 0.0 ? this.m_moreH : 28.0;
        let height: Float = headerH + gap + Cast<Float>(rows) * (rowH + gap) + (more ? moreH + gap : 0.0);
        let width: Float = MaxF(content.X, this.c_barWidth);
        this.m_box.SetSize(new Vector2(width + 2.0 * this.c_padX, height + 2.0 * this.c_padY));
    }

    private func FillRow(row: ref<GRThreatRow>, threat: ref<GRThreat>, flee: Float, markEnabled: Bool) {
        let npc: ref<ScriptedPuppet> = threat.npc;
        let isNemesis: Bool = StrLen(threat.nemesisName) > 0;
        row.root.SetVisible(true);
        row.root.SetOpacity(threat.isTarget ? 1.0 : 0.8);
        row.gang.SetTintColor(GRHud.GangColor(GRDetection.GetGang(npc)));
        row.tag.SetVisible(isNemesis);
        let gang: String = GRDetection.GetGang(npc);
        let label: String = StrLen(gang) > 0 ? this.T("GR-Gang-" + gang) : GetLocalizedText(npc.GetDisplayName());
        row.name.SetText(isNemesis ? threat.nemesisName : label);
        row.name.SetTintColor(threat.isTarget ? GRHud.Yellow() : GRHud.White());
        row.distance.SetText(IntToString(Cast<Int32>(threat.distance)) + " m");
        let below: Bool = threat.canFlee && threat.health <= flee;
        row.fill.SetSize(new Vector2(this.c_barWidth * ClampF(threat.health, 0.0, 100.0) / 100.0, 8.0));
        row.fill.SetTintColor(below ? GRHud.Amber() : GRHud.HealthRed());
        row.mark.SetVisible(markEnabled && threat.canFlee);
        row.mark.SetMargin(new inkMargin(this.c_barWidth * flee / 100.0, 0.0, 0.0, 0.0));
    }

    private func CollectThreats(player: ref<PlayerPuppet>) -> array<ref<GRThreat>> {
        let result: array<ref<GRThreat>>;
        let gi: GameInstance = this.GetGameInstance();
        let tracker: ref<TargetTrackerComponent> = player.GetTargetTrackerComponent();
        if !IsDefined(tracker) {
            return result;
        }
        let tracked: array<TrackedLocation> = tracker.GetHostileThreats(true);
        let spawner: ref<GRSpawner> = GRSpawner.Get(gi);
        let det: ref<GRDetection> = GRDetection.Get(gi);
        let stats: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(gi);
        let lookAt: ref<GameObject> = GameInstance.GetTargetingSystem(gi).GetLookAtObject(player, false, false);
        for location in tracked {
            let npc: ref<ScriptedPuppet> = location.entity as ScriptedPuppet;
            if IsDefined(npc) && !GRDetection.IsNeutralized(npc) {
                let threat: ref<GRThreat> = new GRThreat();
                threat.npc = npc;
                threat.health = stats.GetStatPoolValue(Cast<StatsObjectID>(npc.GetEntityID()), gamedataStatPoolType.Health, true);
                threat.distance = Vector4.Distance(npc.GetWorldPosition(), player.GetWorldPosition());
                threat.nemesisName = IsDefined(spawner) ? spawner.GetNemesisName(npc.GetEntityID()) : "";
                threat.isTarget = IsDefined(lookAt) && lookAt.GetEntityID() == npc.GetEntityID();
                threat.canFlee = IsDefined(det) && StrLen(det.GetFleeBlocker(npc)) == 0;
                let i: Int32 = 0;
                while i < ArraySize(result) && !this.Before(threat, result[i]) {
                    i += 1;
                }
                ArrayInsert(result, i, threat);
            }
        }
        return result;
    }

    private func Before(a: ref<GRThreat>, b: ref<GRThreat>) -> Bool {
        if NotEquals(a.isTarget, b.isTarget) {
            return a.isTarget;
        }
        let aNemesis: Bool = StrLen(a.nemesisName) > 0;
        let bNemesis: Bool = StrLen(b.nemesisName) > 0;
        if NotEquals(aNemesis, bNemesis) {
            return aNemesis;
        }
        return a.distance < b.distance;
    }
}

public class GRProfiler extends ScriptableSystem {
    public let hooksOff: Bool;
    public let nameplates: Int32;
    public let hudTicks: Int32;
    public let hits: Int32;
    public let vehicles: Int32;

    public static func Get(gi: GameInstance) -> ref<GRProfiler> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRProfiler") as GRProfiler;
    }

    public func SetHooksOff(off: Bool) {
        this.hooksOff = off;
    }

    public func TakeCounts() -> String {
        let s: String = "nameplates=" + IntToString(this.nameplates) + " hudTicks=" + IntToString(this.hudTicks)
            + " hits=" + IntToString(this.hits) + " vehicles=" + IntToString(this.vehicles);
        this.nameplates = 0;
        this.hudTicks = 0;
        this.hits = 0;
        this.vehicles = 0;
        return s;
    }

    public func GetState() -> String {
        let gi: GameInstance = this.GetGameInstance();
        let s: String = "";
        let spawner: ref<GRSpawner> = GRSpawner.Get(gi);
        if IsDefined(spawner) {
            s += spawner.GRProfState() + " ";
        }
        let det: ref<GRDetection> = GRDetection.Get(gi);
        if IsDefined(det) {
            s += det.GRProfState() + " ";
        }
        let war: ref<GRWar> = GRWar.Get(gi);
        if IsDefined(war) {
            s += war.GRProfState() + " ";
        }
        let traffic: ref<GRTraffic> = GRTraffic.Get(gi);
        if IsDefined(traffic) {
            s += traffic.GRProfState();
        }
        return s;
    }
}
