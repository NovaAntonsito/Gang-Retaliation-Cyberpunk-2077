// Gang Retaliation - fase 6: pantalla de Nemesis en el menu del juego
//
// - Boton "NEMESIS" en el menu principal (el mismo boton del juego que usa Dark Future).
// - Pantalla propia registrada en menu.inkmenu. El .inkwidget (GangRetaliation.archive) es solo
//   un lienzo vacio con GRNemesisMenuController; todo se dibuja aqui por script.
// - Cabecera [A] BANDA [D] con una pestana por banda (rombo rojo = alguien te conoce).
// - A la izquierda, el arbol Jefe -> Tenientes -> Soldados unido con lineas; debajo, los caidos.
// - A la derecha, el detalle del Nemesis seleccionado (clic en su tarjeta).
// - TAB cambia de vista: Bandas, Territorio y Arsenal (las armas de Jefe que V tiene, por banda; datos de GRRewards).
// Los datos los prepara CET (textos ya traducidos) y los deja en GRMenuData cada pocos segundos.

module GangRetaliation

// inkBorder es abstracta: hace falta una clase concreta (Dark Future hace lo mismo con la suya).
public final class GRBorder extends inkBorder {}

public class GRMenuEntry {
    public let gangKey: String;
    public let gang: String;
    public let rank: Int32;
    public let dead: Bool;
    public let name: String;
    public let title: String;
    // Ya se ha cruzado con V (puede emboscarle).
    public let known: Bool;
    public let renown: Int32;
    // Un rasgo por linea: "S|corto|largo" (S = + fortaleza, - debilidad, ? sin descubrir).
    public let traits: String;
    // Cuanto le falta para ascender, ya traducido.
    public let hint: String;
    public let encounters: Int32;
    public let escapes: Int32;
    public let ambushes: Int32;
    public let gigs: Int32;
    public let origin: String;
    // Como murio (vacio si sigue vivo).
    public let cause: String;
    // Id del Nemesis y claves de todos sus rasgos ("insulated,fireproof"), revelados o no: con eso GRRewards
    // calcula el arma que daria (seccion "Arma unica" del Jefe).
    public let id: Int32;
    public let traitKeys: String;
}

public class GRMenuData extends ScriptableSystem {
    private let m_entries: array<ref<GRMenuEntry>>;
    // Bandas en el orden en que CET las envia.
    private let m_gangs: array<String>;
    // Avisos de vacante por banda (Jefe y Teniente).
    private let m_vacancyGangs: array<String>;
    private let m_vacancyBoss: array<String>;
    private let m_vacancyLieutenant: array<String>;
    // Fase 8: territorio (paralelos por distrito), fuerza de las bandas y rumores.
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
    // Ultima banda vista, para volver a ella al abrir la pantalla.
    private let m_page: Int32;
    // Lo mismo para la vista Arsenal (sus 9 bandas fijas tienen su propia pagina).
    private let m_arsenalPage: Int32;

    public static func Get(gi: GameInstance) -> ref<GRMenuData> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRMenuData") as GRMenuData;
    }

    // API para CET
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

    // CET llama con pocos argumentos por llamada (con muchos, la llamada desde Lua crashea el juego):
    // Add crea la entrada y AddDetail / AddStats completan la ultima.
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

    // influence = "Banda|Nombre|valor,..." de mayor a menor; war = "Atacante|Defensor|fuerzaA|fuerzaD|dia|dias" o "".
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

// -----------------------------------------------------------------------------
// Pantalla
// -----------------------------------------------------------------------------
public class GRNemesisMenuController extends gameuiMenuGameController {
    private let m_data: ref<GRMenuData>;
    private let m_page: Int32;
    private let m_tree: wref<inkCanvas>;
    // Conexiones del arbol: se juntan los tramos y se pintan por capas al final (como trazos SVG apilados).
    private let m_links: wref<inkCanvas>;
    // Puntos de todas las conexiones seguidos; m_pathStart marca donde empieza cada una.
    private let m_pathPoints: array<Vector2>;
    private let m_pathStart: array<Int32>;
    private let m_pathColor: array<HDRColor>;
    private let m_detail: wref<inkCanvas>;
    private let m_detailContent: wref<inkVerticalPanel>;
    private let m_gangTitle: wref<inkText>;
    private let m_gangCount: wref<inkText>;
    private let m_marks: wref<inkHorizontalPanel>;
    private let m_summary: wref<inkText>;
    private let m_buttonHints: wref<ButtonHints>;
    // Tarjetas de la banda actual, en el orden de sus nombres "gr_card_N".
    private let m_cards: array<ref<GRMenuEntry>>;
    private let m_cardFrames: array<wref<inkImage>>;
    // Pestanas de banda: se crean una vez y se recolorean (no se rehacen dentro de su propio clic).
    private let m_tabTexts: array<wref<inkText>>;
    private let m_tabBars: array<wref<inkRectangle>>;
    private let m_tabThreats: array<wref<inkRectangle>>;
    // Nemesis seleccionado (por nombre; los datos se rehacen cada pocos segundos).
    private let m_selName: String;
    // Fase 8: 0 = bandas, 1 = territorio. Armas de Jefe: 2 = arsenal.
    private let m_view: Int32;
    private let m_viewArsenal: wref<inkText>;
    private let m_rewards: ref<GRRewards>;
    private let m_arsenal: wref<inkCanvas>;
    private let m_arsenalPage: Int32;
    // Tarjetas de arma de la banda actual, en el orden de sus nombres "gr_weapon_N": indice del arma en la foto
    // de GRRewards. La primera es siempre el arma principal.
    private let m_aCards: array<Int32>;
    private let m_aFrames: array<wref<inkImage>>;
    private let m_aDetail: wref<inkVerticalPanel>;
    // Arma seleccionada (indice en la foto de GRRewards; menor que 0 = ninguna).
    private let m_selWeapon: Int32;
    // Boton AUMENTO al pie del detalle del arsenal: se crea con el panel y solo cambia de texto y color.
    private let m_augBorder: wref<GRBorder>;
    private let m_augTitle: wref<inkText>;
    private let m_augSub: wref<inkText>;
    private let m_augReady: Bool;
    // Aumento: capa encima del arsenal. Sus botones se crean una vez (ningun widget se destruye dentro de su propio
    // clic); lo que se rehace es m_fContent, que no tiene nada interactivo.
    private let m_fusion: wref<inkCanvas>;
    private let m_fContent: wref<inkCanvas>;
    // Botones "gr_fuse_N": 0 y 1 = copia anterior / siguiente, 2 y 3 = elemento que queda, 4 = fusionar, 5 = volver.
    private let m_fButtons: array<wref<inkCanvas>>;
    private let m_fBorders: array<wref<GRBorder>>;
    private let m_fLabels: array<wref<inkText>>;
    // Relleno del boton de fusionar mientras se mantiene presionado.
    private let m_fProgress: wref<inkRectangle>;
    private let m_fOpen: Bool;
    // True despues de fusionar: se ve el resultado.
    private let m_fDone: Bool;
    // Indices en la foto de GRRewards: el arma principal, las copias que se pueden fusionar y cual esta elegida.
    private let m_fMain: Int32;
    private let m_fCopies: array<Int32>;
    private let m_fCopy: Int32;
    // Elemento que queda (menor que 0 = el del arma principal) y los que ofrecen los botones 2 y 3.
    private let m_fKeep: Int32;
    private let m_fChoices: array<Int32>;
    // Respaldo si el juego no manda el progreso de "mantener": dos clics (fusionar, confirmar).
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

    // Colores de la interfaz del juego (los mismos que Custom Perk Framework).
    private func Red() -> HDRColor {
        return new HDRColor(1.1761, 0.3809, 0.3476, 1.0);
    }

    private func Cyan() -> HDRColor {
        return new HDRColor(0.368627, 0.964706, 1.0, 1.0);
    }

    private func Gold() -> HDRColor {
        return new HDRColor(1.1192, 0.8441, 0.2565, 1.0);
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

    // Mayusculas sin acentos: StrUpper no pasa a mayuscula las letras acentuadas ("NéMESIS", "DAñO") y las
    // mayusculas con tilde se ven mal en la fuente del juego. La Ñ se queda.
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
        this.m_page = IsDefined(this.m_data) ? this.m_data.GetPage() : 0;
        this.m_arsenalPage = IsDefined(this.m_data) ? this.m_data.GetArsenalPage() : 0;
        this.m_rewards = GRRewards.Get(this.GetPlayerControlledObject().GetGame());
        this.m_selWeapon = -1;
        let root: ref<inkCompoundWidget> = this.GetRootCompoundWidget();

        this.CreateBackground(root);
        this.CreateHeader(root);
        this.CreateRankLabels(root);

        let tree: ref<inkCanvas> = new inkCanvas();
        tree.SetName(n"tree");
        tree.SetAnchor(inkEAnchor.Fill);
        tree.Reparent(root);
        this.m_tree = tree;

        this.CreateDetail(root);
        this.CreateTerritory(root);
        this.CreateArsenal(root);
        this.CreateViewSwitch(root);
        this.CreateFusion(root);

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

        this.RegisterToGlobalInputCallback(n"OnPostOnRelease", this, n"OnGRGlobalInput");
        this.Refresh();
        super.OnInitialize();
        this.BringToFront();
    }

    protected cb func OnUninitialize() -> Bool {
        this.UnregisterFromGlobalInputCallback(n"OnPostOnRelease", this, n"OnGRGlobalInput");
        if IsDefined(this.m_data) {
            this.m_data.SetPage(this.m_page);
            this.m_data.SetArsenalPage(this.m_arsenalPage);
        }
    }

    // -------------------------------------------------------------------------
    // Piezas fijas
    // -------------------------------------------------------------------------
    private func CreateBackground(root: ref<inkCompoundWidget>) {
        let background: ref<inkRectangle> = new inkRectangle();
        background.SetName(n"background");
        background.SetAnchor(inkEAnchor.Fill);
        // Deja libre la barra superior del juego (nivel, pestanas, dinero), que ahora queda por debajo.
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

    // Texto que salta de linea al llegar a width.
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

    // Marco fino que ocupa todo su padre.
    private func AddBorder(parent: ref<inkCompoundWidget>, color: HDRColor, thickness: Float, opacity: Float) {
        let border: ref<GRBorder> = new GRBorder();
        border.SetAnchor(inkEAnchor.Fill);
        border.SetThickness(thickness);
        border.SetTintColor(color);
        border.SetOpacity(opacity);
        border.Reparent(parent);
    }

    // Fondo liso que ocupa todo su padre.
    private func AddFill(parent: ref<inkCompoundWidget>, color: HDRColor, opacity: Float) {
        let bg: ref<inkRectangle> = new inkRectangle();
        bg.SetAnchor(inkEAnchor.Fill);
        bg.SetTintColor(color);
        bg.SetOpacity(opacity);
        bg.Reparent(parent);
    }

    // Linea horizontal fina de lado a lado (como la franja de la pantalla de ventajas).
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

    private func CreateHeader(root: ref<inkCompoundWidget>) {
        this.AddFullLine(root, 150.0);
        this.AddFullLine(root, 336.0);

        // Titulo a la izquierda y resumen a la derecha.
        let title: ref<inkText> = this.NewText(this.Up(this.T("GR-MenuTitle")), 64, this.Red(), n"Medium");
        title.SetAnchor(inkEAnchor.TopLeft);
        title.SetMargin(new inkMargin(120.0, 184.0, 0.0, 0.0));
        title.Reparent(root);

        let summary: ref<inkText> = this.NewText("", 40, this.Gold(), n"Medium");
        summary.SetAnchor(inkEAnchor.TopRight);
        summary.SetAnchorPoint(new Vector2(1.0, 0.0));
        summary.SetMargin(new inkMargin(0.0, 200.0, 120.0, 0.0));
        summary.Reparent(root);
        this.m_summary = summary;

        // [A]  BANDA  N  [D]
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

        // Una pestana por banda debajo; la actual en cian.
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

    // Etiquetas de nivel a la izquierda del arbol.
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

    // Panel de detalle a la derecha (marco fijo; el contenido se rehace en cada Fill).
    private func CreateDetail(root: ref<inkCompoundWidget>) {
        let detail: ref<inkCanvas> = new inkCanvas();
        detail.SetName(n"detail");
        detail.SetAnchor(inkEAnchor.TopLeft);
        detail.SetMargin(new inkMargin(2720.0, 400.0, 0.0, 0.0));
        detail.SetSize(new Vector2(1000.0, 1520.0));
        detail.Reparent(root);
        this.m_detail = detail;

        this.AddFill(detail, this.Panel(), 0.95);
        this.AddBorder(detail, this.Red(), 2.0, 0.45);

        let content: ref<inkVerticalPanel> = new inkVerticalPanel();
        content.SetAnchor(inkEAnchor.Fill);
        content.SetMargin(new inkMargin(56.0, 52.0, 56.0, 52.0));
        content.Reparent(detail);
        this.m_detailContent = content;
    }

    // -------------------------------------------------------------------------
    // Arbol
    // -------------------------------------------------------------------------
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

    // Codo de arriba a abajo con esquinas en chaflan a 45 grados: baja, gira, cruza, gira y baja.
    // Se guarda como una polilinea; se pinta despues en DrawLinks.
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

    // Un trazo recto (horizontal, vertical o a 45 grados) de grosor width.
    private func DrawStroke(x1: Float, y1: Float, x2: Float, y2: Float, width: Float, color: HDRColor, opacity: Float) {
        let rect: ref<inkRectangle> = new inkRectangle();
        rect.SetAnchor(inkEAnchor.TopLeft);
        rect.SetTintColor(color);
        rect.SetOpacity(opacity);
        let dx: Float = x2 - x1;
        let dy: Float = y2 - y1;
        if AbsF(dx) < 0.5 || AbsF(dy) < 0.5 {
            // Se alarga medio grosor por cada lado para cerrar las esquinas.
            rect.SetMargin(new inkMargin(MinF(x1, x2) - width / 2.0, MinF(y1, y2) - width / 2.0, 0.0, 0.0));
            rect.SetSize(new Vector2(AbsF(dx) + width, AbsF(dy) + width));
        } else {
            // Diagonal: rectangulo girado 45 grados sobre su centro.
            let length: Float = AbsF(dx) * 1.41421356 + width * 0.42;
            rect.SetSize(new Vector2(length, width));
            rect.SetMargin(new inkMargin((x1 + x2) / 2.0 - length / 2.0, (y1 + y2) / 2.0 - width / 2.0, 0.0, 0.0));
            rect.SetRenderTransformPivot(new Vector2(0.5, 0.5));
            rect.SetRotation(dx * dy > 0.0 ? 45.0 : -45.0);
        }
        rect.Reparent(this.m_links);
    }

    // Copia de la polilinea desplazada offset a un lado, con las esquinas en inglete
    // (cada vertice se mueve por la bisectriz de las normales de sus dos tramos).
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

    // Haz de 3 lineas finas paralelas, cada una con su halo tenue (como el boceto).
    // Lineas finas sueltas en vez de franjas anchas encimadas: asi las esquinas a 45 grados no dejan muescas.
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
                // Pasada 0: halo fino pegado a cada linea (una franja ancha dejaba bloques cuadrados en las esquinas).
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

    // Etiqueta con marco fino: TE CONOCE / SIN CONTACTO.
    // Tamano fijo calculado del texto: inkFlex no se ajustaba y el texto se montaba encima de lo siguiente.
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

    // 10 segmentos de renombre.
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

    // Rasgos de una entrada: lineas "S|corto|largo".
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

    // Tarjeta de un Nemesis centrada en (x, y). Clic = verlo en el panel de detalle.
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

        let content: ref<inkVerticalPanel> = new inkVerticalPanel();
        content.SetAnchor(inkEAnchor.Fill);
        content.SetMargin(new inkMargin(30.0, 18.0, 30.0, 12.0));
        content.Reparent(card);

        // RANGO  [TE CONOCE]
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

        // Rasgos cortos: 3 en las grandes, 2 en las de soldado.
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

    // Marco: cian si esta seleccionado, color de rango si te conoce, gris si no.
    private func StyleFrame(frame: wref<inkImage>, entry: ref<GRMenuEntry>, selected: Bool) {
        frame.SetTintColor(selected ? this.Cyan() : this.RankColor(entry.rank));
        frame.SetOpacity(selected || entry.known ? 1.0 : 0.55);
    }

    private func IsSelected(entry: ref<GRMenuEntry>) -> Bool {
        return Equals(entry.name, this.m_selName);
    }

    // Puesto sin ocupar en el arbol, con cuanto falta para cubrirlo.
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

    // x de cada elemento repartidos en [left, right].
    private func Spread(count: Int32, index: Int32, left: Float, right: Float) -> Float {
        if count <= 1 {
            return (left + right) / 2.0;
        }
        return left + (right - left) * Cast<Float>(index) / Cast<Float>(count - 1);
    }

    // Pestana de una banda; el rombo rojo marca que alguien de ella te conoce.
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

    // Caidos, en tarjetas pequenas al pie del arbol (como mucho 5; el resto se cuenta).
    private func AddFallen(fallen: array<ref<GRMenuEntry>>) {
        let block: ref<inkVerticalPanel> = new inkVerticalPanel();
        block.SetAnchor(inkEAnchor.TopLeft);
        block.SetMargin(new inkMargin(120.0, 1640.0, 0.0, 0.0));
        block.Reparent(this.m_tree);

        let header: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        header.Reparent(block);
        let label: ref<inkText> = this.NewText(this.Up(this.T("GR-MenuFallen")), 34, this.Light(), n"Medium");
        label.SetVAlign(inkEVerticalAlign.Center);
        label.Reparent(header);
        let line: ref<inkRectangle> = this.NewRect(2200.0, 2.0, this.Dim(), 1.0);
        line.SetVAlign(inkEVerticalAlign.Center);
        line.SetMargin(new inkMargin(28.0, 0.0, 0.0, 0.0));
        line.Reparent(header);

        if ArraySize(fallen) == 0 {
            let none: ref<inkText> = this.NewText(this.T("GR-MenuNoFallen"), 34, this.Light(), n"Regular");
            none.SetMargin(new inkMargin(0.0, 20.0, 0.0, 0.0));
            none.Reparent(block);
            return;
        }

        let row: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        row.SetMargin(new inkMargin(0.0, 20.0, 0.0, 0.0));
        row.Reparent(block);
        let shown: Int32 = Min(ArraySize(fallen), 5);
        let i: Int32 = 0;
        while i < shown {
            let entry: ref<GRMenuEntry> = fallen[i];
            let card: ref<inkCanvas> = new inkCanvas();
            card.SetSize(new Vector2(420.0, 110.0));
            card.SetMargin(new inkMargin(0.0, 0.0, 20.0, 0.0));
            card.Reparent(row);
            this.AddFill(card, this.Panel(), 0.95);
            this.AddBorder(card, this.Dim(), 2.0, 1.0);

            let content: ref<inkVerticalPanel> = new inkVerticalPanel();
            content.SetAnchor(inkEAnchor.Fill);
            content.SetMargin(new inkMargin(24.0, 14.0, 16.0, 10.0));
            content.Reparent(card);
            let name: ref<inkText> = this.NewText(entry.name, 38, this.Light(), n"Bold");
            name.SetOpacity(0.7);
            name.Reparent(content);
            let cause: ref<inkText> = this.NewText(this.RankName(entry.rank) + "  |  " + entry.cause, 28, this.Grey(), n"Regular");
            cause.Reparent(content);

            // Tachado rojo sobre el nombre.
            let strike: ref<inkRectangle> = this.NewRect(MinF(360.0, Cast<Float>(StrLen(entry.name)) * 17.0), 3.0, this.Red(), 0.8);
            strike.SetAnchor(inkEAnchor.TopLeft);
            strike.SetMargin(new inkMargin(24.0, 36.0, 0.0, 0.0));
            strike.Reparent(card);
            i += 1;
        }
        if ArraySize(fallen) > shown {
            let more: ref<inkText> = this.NewText("+" + IntToString(ArraySize(fallen) - shown), 40, this.Grey(), n"Medium");
            more.SetVAlign(inkEVerticalAlign.Center);
            more.Reparent(row);
        }
    }

    // Titulo de seccion del panel de detalle.
    private func AddSection(parent: ref<inkCompoundWidget>, text: String, top: Float) {
        let label: ref<inkText> = this.NewText(this.Up(text), 34, this.Light(), n"Bold");
        label.SetMargin(new inkMargin(0.0, top, 0.0, 12.0));
        label.Reparent(parent);
    }

    // Recuadro de una cifra del historial.
    private func AddStat(parent: ref<inkCompoundWidget>, value: Int32, label: String) {
        let box: ref<inkCanvas> = new inkCanvas();
        box.SetSize(new Vector2(208.0, 130.0));
        box.SetMargin(new inkMargin(0.0, 0.0, 14.0, 0.0));
        box.Reparent(parent);
        this.AddBorder(box, this.Dim(), 2.0, 1.0);
        let content: ref<inkVerticalPanel> = new inkVerticalPanel();
        content.SetAnchor(inkEAnchor.Fill);
        content.SetMargin(new inkMargin(20.0, 10.0, 10.0, 10.0));
        content.Reparent(box);
        this.NewText(IntToString(value), 64, this.Light(), n"Bold").Reparent(content);
        this.NewText(label, 24, this.Light(), n"Bold").Reparent(content);
    }

    private func FillDetail(entry: ref<GRMenuEntry>) {
        let panel: ref<inkVerticalPanel> = this.m_detailContent;
        panel.RemoveAllChildren();
        if !IsDefined(entry) {
            this.m_detail.SetVisible(false);
            return;
        }
        this.m_detail.SetVisible(true);
        let rankColor: HDRColor = this.RankColor(entry.rank);
        let width: Float = 888.0;

        this.NewText(this.RankName(entry.rank) + "  |  " + this.Up(entry.gang), 28, this.Cyan(), n"Bold").Reparent(panel);
        let name: ref<inkText> = this.NewWrappedText(entry.name, 66, rankColor, width);
        name.SetFontStyle(n"Bold");
        name.Reparent(panel);
        if StrLen(entry.title) > 0 {
            this.NewText("\"" + entry.title + "\"", 42, this.Light(), n"Regular").Reparent(panel);
        }

        // Contacto con V.
        let contact: ref<inkCompoundWidget> = this.NewTag(this.T(entry.known ? "GR-MenuKnown" : "GR-MenuUnknown"), 26, entry.known ? this.Red() : this.Grey());
        contact.SetHAlign(inkEHorizontalAlign.Left);
        contact.SetMargin(new inkMargin(0.0, 36.0, 0.0, 10.0));
        contact.Reparent(panel);
        this.NewWrappedText(this.T(entry.known ? "GR-MenuKnownNote" : "GR-MenuUnknownNote"), 36, this.Light(), width).Reparent(panel);

        // Renombre: barra con las marcas de ascenso rapido (4 = Teniente, 8 = Jefe).
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
        this.NewWrappedText(entry.hint, 36, this.Light(), width).Reparent(panel);

        // Rasgos completos.
        this.AddSection(panel, this.T("GR-MenuTraits"), 44.0);
        let traitLines: array<String> = this.TraitLines(entry);
        for line in traitLines {
            let parts: array<String> = StrSplit(line, "|");
            if ArraySize(parts) >= 3 {
                // Sin descubrir: el texto ya empieza por "???".
                let prefix: String = Equals(parts[0], "?") ? "" : parts[0] + "  ";
                let trait: ref<inkText> = this.NewWrappedText(prefix + parts[2], 38, this.TraitColor(parts[0]), width);
                trait.SetFontStyle(n"Medium");
                trait.SetMargin(new inkMargin(0.0, 0.0, 0.0, 8.0));
                trait.Reparent(panel);
            }
        }

        // Arma unica: la que V se lleva si mata a este Jefe.
        if entry.rank >= 3 && !entry.dead {
            this.AddBossWeapon(panel, entry, width);
        }

        // Historial.
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

    // Seccion "Arma unica" del panel de un Jefe vivo, entre dos lineas doradas: nombre, tipo y arma base, y el
    // elemento y el bono que tendria (GRRewards.PreviewBossWeapon). Mientras le quede algun rasgo sin revelar
    // (lineas "?": se revelan todos al escanearlo) solo se ve "???".
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

        // El mismo nombre que tendra el arma: GRRewards lo arma con el nombre del Jefe y su apodo.
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
        // Las conexiones van en su propio lienzo, el primero del arbol: quedan por debajo de las tarjetas.
        let links: ref<inkCanvas> = new inkCanvas();
        links.SetName(n"links");
        links.SetAnchor(inkEAnchor.Fill);
        links.Reparent(this.m_tree);
        this.m_links = links;
        ArrayClear(this.m_cards);
        ArrayClear(this.m_cardFrames);

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

        // Pestanas de banda (se rehacen solo si cambia el numero de bandas).
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

        // Miembros de la banda.
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
        // Sin seleccion valida: el Jefe, o el primero que haya.
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

        // Drug Dealer: zonas que V le quito a esta banda, bajo la linea de las pestanas (a la izquierda).
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

        let cx: Float = this.CenterX();
        let bossY: Float = this.TierY(3);
        let ltY: Float = this.TierY(2);
        let soldierY: Float = this.TierY(1);
        let bigW: Float = 600.0;
        let bigH: Float = 290.0;

        // Jefe (o puesto libre).
        if IsDefined(boss) {
            this.AddCard(boss, cx, bossY, bigW, bigH, false, this.IsSelected(boss));
        } else {
            this.AddVacant(cx, bossY, bigW, bigH, this.m_data.GetVacancy(gangKey, 3));
        }

        // Tenientes: siempre 2 plazas; las vacias se ven como puesto libre.
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

        // Soldados: la primera mitad cuelga del teniente izquierdo y el resto del derecho.
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

    // -------------------------------------------------------------------------
    // Cambiar de banda o de Nemesis
    // -------------------------------------------------------------------------
    // El menu principal (hub) se dibuja despues que esta pantalla, a pantalla completa y con su fondo:
    // la tapaba y la dejaba al ~40%. Las pantallas del juego quedan por delante del hub; esta se mueve
    // al final de la capa de menus para dibujarse encima, como ellas.
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

    // =========================================================================
    // Fase 8: vista de territorio
    // =========================================================================
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

    // Cambia la primera aparicion de token por value ("%s", "%d").
    private func Fmt(fmt: String, token: String, value: String) -> String {
        let i: Int32 = StrFindFirst(fmt, token);
        if i < 0 {
            return fmt;
        }
        let after: Int32 = i + StrLen(token);
        return StrLeft(fmt, i) + value + StrMid(fmt, after, StrLen(fmt) - after);
    }

    // [TAB] BANDAS | TERRITORIO, bajo el titulo. Clic en cualquiera de los dos tambien cambia.
    private func CreateViewSwitch(root: ref<inkCompoundWidget>) {
        let panel: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        panel.SetName(n"view_switch");
        panel.SetAnchor(inkEAnchor.TopLeft);
        panel.SetMargin(new inkMargin(120.0, 258.0, 0.0, 0.0));
        panel.SetFitToContent(true);
        panel.Reparent(root);

        let key: ref<inkCompoundWidget> = this.NewTag("TAB", 22, this.Cyan());
        key.SetMargin(new inkMargin(0.0, 0.0, 20.0, 0.0));
        key.Reparent(panel);

        let gangs: ref<inkText> = this.NewText(this.Up(this.T("GR-MenuViewGangs")), 32, this.Grey(), n"Bold");
        gangs.SetVAlign(inkEVerticalAlign.Center);
        gangs.SetInteractive(true);
        gangs.RegisterToCallback(n"OnRelease", this, n"OnGRViewGangsClick");
        gangs.Reparent(panel);
        this.m_viewGangs = gangs;

        let sep: ref<inkText> = this.NewText("  |  ", 32, this.Dim(), n"Medium");
        sep.SetVAlign(inkEVerticalAlign.Center);
        sep.Reparent(panel);

        let territory: ref<inkText> = this.NewText(this.Up(this.T("GR-MenuViewTerritory")), 32, this.Grey(), n"Bold");
        territory.SetVAlign(inkEVerticalAlign.Center);
        territory.SetInteractive(true);
        territory.RegisterToCallback(n"OnRelease", this, n"OnGRViewTerritoryClick");
        territory.Reparent(panel);
        this.m_viewTerritory = territory;

        let sep2: ref<inkText> = this.NewText("  |  ", 32, this.Dim(), n"Medium");
        sep2.SetVAlign(inkEVerticalAlign.Center);
        sep2.Reparent(panel);

        let arsenal: ref<inkText> = this.NewText(this.Up(this.T("GR-MenuViewArsenal")), 32, this.Grey(), n"Bold");
        arsenal.SetVAlign(inkEVerticalAlign.Center);
        arsenal.SetInteractive(true);
        arsenal.RegisterToCallback(n"OnRelease", this, n"OnGRViewArsenalClick");
        arsenal.Reparent(panel);
        this.m_viewArsenal = arsenal;
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

    // Muestra una vista u otra (no rehace nada).
    private func ShowView() {
        let gangs: Bool = this.m_view == 0;
        let arsenal: Bool = this.m_view == 2;
        // Bandas y Arsenal comparten el selector [A] BANDA N [D] y las pestanas.
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
            // La foto de las armas se toma al entrar en la vista: con el menu abierto solo las cambia un Aumento,
            // que la rehace. Bandas tambien la usa (el panel del Jefe dice si su arma seria copia de una de V).
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

    // TAB: bandas -> territorio -> arsenal -> bandas.
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

    // Texto en una posicion fija del lienzo de territorio.
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

    // Barra con un tramo por banda ("Banda|Nombre|valor,...").
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

    // Nombre visible de una banda dentro de la influencia del distrito.
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
        // Drug Dealer: zona que V le quito (o le disputa) a las bandas.
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

        // Leyenda: un color por banda.
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

        // Distrito seleccionado: el de antes, o el primero en guerra, o el primero.
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

        // Zonas en 4 columnas, cada una con sus distritos.
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
        let r: Int32 = 0;
        while r < ArraySize(seen) {
            let column: ref<inkVerticalPanel> = columns[r % 4];
            let heading: ref<inkText> = this.NewText(this.Up(seen[r]), 26, this.Light(), n"Bold");
            heading.SetMargin(new inkMargin(0.0, r >= 4 ? 22.0 : 0.0, 0.0, 10.0));
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

        // Panel de detalle a la derecha.
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

    // Fuerza de las bandas, en 3 columnas bajo los distritos.
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
        // Copias locales: indexar directamente el resultado de una funcion devolvia textos basura.
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

        // Influencia de cada banda.
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

        // Guerra: quien ataca y quien defiende, fuerzas y tendencia.
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

        // Rumores recientes.
        this.AddSection(panel, this.T("GR-MenuRumors"), 44.0);
        let days: array<String> = this.m_data.RumorDays();
        let texts: array<String> = this.m_data.RumorTexts();
        if ArraySize(texts) == 0 {
            this.NewWrappedText(this.T("GR-MenuNoRumors"), 28, this.Grey(), width).Reparent(panel);
        }
        i = 0;
        while i < Min(ArraySize(texts), 5) {
            let line: ref<inkHorizontalPanel> = new inkHorizontalPanel();
            line.SetMargin(new inkMargin(0.0, 0.0, 0.0, 10.0));
            line.Reparent(panel);
            let dayText: ref<inkText> = this.NewText(days[i], 22, this.Grey(), n"Bold");
            dayText.SetMargin(new inkMargin(0.0, 4.0, 18.0, 0.0));
            dayText.Reparent(line);
            this.NewWrappedText(texts[i], 28, this.Light(), 740.0).Reparent(line);
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

    // =========================================================================
    // Armas de Jefe: vista de arsenal
    // =========================================================================
    // Las 9 bandas que dan arma, siempre las mismas y en este orden (el de GangColor).
    private func ArsenalGangs() -> array<String> {
        return ["Maelstrom", "TygerClaws", "Valentinos", "SixthStreet", "Animals", "VoodooBoys", "Wraiths", "Scavengers", "Barghest"];
    }

    // Nombres propios de las bandas, los mismos que usa CET (names.lua): aqui no dependen de que haya Nemesis.
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

    // 0 = Electrico, 1 = Termico, 2 = Quimico.
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

    // "DANO QUIMICO"
    private func ElementText(element: Int32) -> String {
        if element < 0 || element > 2 {
            return "";
        }
        return this.Up(this.T("GR-MenuDmg-" + IntToString(element)));
    }

    // Pestana en Arsenal: sin rombo de amenaza y en gris tenue si V no tiene armas de esa banda.
    private func StyleArsenalTab(index: Int32, label: String, active: Bool, hasWeapons: Bool) {
        this.m_tabTexts[index].SetText(this.Up(label));
        this.m_tabTexts[index].SetTintColor(active ? this.Cyan() : (hasWeapons ? this.Grey() : this.Dim()));
        this.m_tabBars[index].SetSize(new Vector2(236.0, active ? 8.0 : 4.0));
        this.m_tabBars[index].SetTintColor(active ? this.Cyan() : this.DarkRed());
        this.m_tabThreats[index].SetVisible(false);
    }

    // Barra del bono elemental de 0 a 60 %: marcas en 20 y 40, y el tope (60) en rojo.
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

    // Escala bajo la barra: 0, 20 %, 40 % y 60 % (tope).
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

    // Icono 2D del arma dentro de box (ya colgado del arbol), entero y centrado, sin deformar: cada icono del juego
    // tiene su propia proporcion (la Katana es 10:1, la Yukimura 1.7:1) y GRRewards la conoce por record.
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

    // Pide al juego el icono 2D del arma (el del inventario). El icono llega despues; hasta entonces no se ve nada.
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

    // "+39 %" grande y "DANO QUIMICO" al lado, en el color del elemento.
    private func NewElementRow(weaponIndex: Int32, valueSize: Int32, labelSize: Int32) -> ref<inkHorizontalPanel> {
        return this.NewElementRowOf(this.m_rewards.GetOwnedElement(weaponIndex), this.m_rewards.GetOwnedBonusF(weaponIndex), valueSize, labelSize);
    }

    // Lo mismo con el elemento y el bono dados (resultado de un Aumento, arma de un Jefe vivo).
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

    // Marco: cian si esta seleccionada; si no, dorado el arma principal (la primera tarjeta) y gris las copias.
    private func StyleWeaponFrame(cardIndex: Int32, selected: Bool) {
        let frame: wref<inkImage> = this.m_aFrames[cardIndex];
        frame.SetTintColor(selected ? this.Cyan() : (cardIndex == 0 ? this.Gold() : this.Dim()));
        frame.SetOpacity(1.0);
    }

    // Tarjeta de un arma con la esquina superior izquierda en (x, y). big = arma principal. Clic = verla en el detalle.
    private func AddWeaponCard(weaponIndex: Int32, x: Float, y: Float, w: Float, h: Float, big: Bool) {
        let index: Int32 = ArraySize(this.m_aCards);
        ArrayPush(this.m_aCards, weaponIndex);
        let name: String = this.m_rewards.GetOwnedName(weaponIndex);
        let equipped: Bool = this.m_rewards.IsOwnedEquipped(weaponIndex);

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
            // Icono a la izquierda (caja de 1060x298) y, debajo, el arma base y la banda.
            let iconBox: ref<inkCanvas> = new inkCanvas();
            iconBox.SetAnchor(inkEAnchor.TopLeft);
            iconBox.SetMargin(new inkMargin(70.0, 190.0, 0.0, 0.0));
            iconBox.SetSize(new Vector2(1060.0, 298.0));
            iconBox.Reparent(card);
            this.AddWeaponIcon(iconBox, weaponIndex, 1060.0, 298.0);
            this.PlaceText(card, this.Up(this.m_rewards.GetOwnedBaseName(weaponIndex)) + "  |  " + this.Up(this.ArsenalGangLabel(this.m_rewards.GetOwnedGang(weaponIndex))),
                28, this.Dim(), n"Medium", 80.0, 560.0);

            // Columna derecha: etiqueta, nombre, elemento con su barra y nivel.
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

            // Icono chico (caja de 240x68) y EQUIPADA al lado.
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

        // Elemento: bono con su barra de 0 a 60 %.
        this.AddSection(panel, this.T("GR-MenuElement"), 44.0);
        this.NewElementRow(weaponIndex, 72, 30).Reparent(panel);
        let bar: ref<inkCanvas> = this.NewBonusBar(bonus, this.ElementColor(element), width, 22.0);
        bar.SetMargin(new inkMargin(0.0, 8.0, 0.0, 0.0));
        bar.Reparent(panel);
        this.NewBonusScale(width).Reparent(panel);

        // Nivel de Aumento: titulo, rombos y numero romano en una sola fila (el pie del panel es del boton AUMENTO).
        let augment: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        augment.SetMargin(new inkMargin(0.0, 30.0, 0.0, 0.0));
        augment.Reparent(panel);
        let augmentLabel: ref<inkText> = this.NewText(this.Up(this.T("GR-MenuAugLevel")), 34, this.Light(), n"Bold");
        augmentLabel.SetVAlign(inkEVerticalAlign.Center);
        augmentLabel.SetMargin(new inkMargin(0.0, 0.0, 24.0, 0.0));
        augmentLabel.Reparent(augment);
        this.NewLevelRow(this.m_rewards.GetOwnedLevel(weaponIndex), 26.0, 40, 28).Reparent(augment);

        // Probabilidad de aplicar el estado (el mismo numero que el bono).
        this.AddSection(panel, this.T("GR-MenuChance"), 32.0);
        this.NewText(this.BonusText(bonus) + " %", 72, this.Light(), n"Bold").Reparent(panel);
        if element >= 0 && element <= 2 {
            this.NewWrappedText(this.T("GR-MenuProc-" + IntToString(element)), 34, this.Light(), width).Reparent(panel);
        }

        // Dano por golpe y nivel del arma.
        let stats: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        stats.SetMargin(new inkMargin(0.0, 30.0, 0.0, 0.0));
        stats.Reparent(panel);
        this.AddStat(stats, RoundF(this.m_rewards.GetOwnedDamage(weaponIndex)), this.T("GR-MenuDamage"));
        // Calidad del juego ("NIVEL 3+"), con su etiqueta para que no se confunda con el nivel de Aumento.
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

        // Pestanas: las mismas de Bandas; solo se rehacen si cambia el numero (nunca dentro de su propio clic,
        // porque en esta vista siempre son 9).
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
        // Armas de la banda actual; la principal es la equipada o, si ninguna lo esta, la de mayor bono.
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

        // Arma principal: tarjeta grande.
        this.PlaceText(this.m_arsenal, this.Up(this.T("GR-MenuMainWeapon")), 30, this.Grey(), n"Bold", 120.0, 400.0);
        this.AddWeaponCard(main, 120.0, 450.0, 2480.0, 700.0, true);

        // Copias: hasta 8 tarjetas en 2 filas de 4.
        this.PlaceText(this.m_arsenal, this.Up(this.T("GR-MenuCopies")) + "  ·  " + IntToString(ArraySize(list) - 1), 30, this.Grey(), n"Bold", 120.0, 1210.0);
        let shown: Int32 = 0;
        for weapon in list {
            if weapon != main && shown < 8 {
                this.AddWeaponCard(weapon, 120.0 + Cast<Float>(shown % 4) * 640.0, 1260.0 + Cast<Float>(shown / 4) * 330.0, 600.0, 290.0, false);
                shown += 1;
            }
        }

        // Panel de detalle a la derecha (mismo marco que el de Bandas).
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

    // Arma principal de una banda en la foto de GRRewards: la equipada o, si ninguna lo esta, la de mayor bono.
    // Menor que 0 = V no tiene armas de esa banda.
    private func ArsenalMain(gangKey: String) -> Int32 {
        let main: Int32 = -1;
        let mainScore: Int32 = -1;
        let owned: Int32 = IsDefined(this.m_rewards) ? this.m_rewards.GetOwnedCount() : 0;
        let w: Int32 = 0;
        while w < owned {
            if Equals(this.m_rewards.GetOwnedGang(w), gangKey) {
                let score: Int32 = RoundF(this.m_rewards.GetOwnedBonusF(w) * 10.0) + (this.m_rewards.IsOwnedEquipped(w) ? 10000 : 0);
                if score > mainScore {
                    mainScore = score;
                    main = w;
                }
            }
            w += 1;
        }
        return main;
    }

    // "41,8" o "38": el bono con un decimal solo si lo tiene. El separador decimal sale del idioma.
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

    // Nivel de Aumento: 5 rombos (dorados hasta level), el numero romano y el dano que suma ("+10 % DANO").
    private func NewLevelRow(level: Int32, pipSize: Float, romanSize: Int32, noteSize: Int32) -> ref<inkHorizontalPanel> {
        let row: ref<inkHorizontalPanel> = new inkHorizontalPanel();
        let i: Int32 = 1;
        while i <= 5 {
            let pip: ref<inkRectangle> = this.NewRect(pipSize, pipSize, i <= level ? this.Gold() : this.Empty(), 1.0);
            pip.SetVAlign(inkEVerticalAlign.Center);
            // Girado 45 grados ocupa 1,41 veces su lado: el margen deja sitio a las puntas.
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

    // Copias que se pueden fusionar con main: las demas armas de su banda que V no lleva equipadas.
    private func FusableCopies(main: Int32) -> array<Int32> {
        let result: array<Int32>;
        if main < 0 || !IsDefined(this.m_rewards) {
            return result;
        }
        let gang: String = this.m_rewards.GetOwnedGang(main);
        let owned: Int32 = this.m_rewards.GetOwnedCount();
        let w: Int32 = 0;
        while w < owned {
            if w != main && Equals(this.m_rewards.GetOwnedGang(w), gang) && !this.m_rewards.IsOwnedEquipped(w) {
                ArrayPush(result, w);
            }
            w += 1;
        }
        return result;
    }

    // -------------------------------------------------------------------------
    // Aumento: boton del panel de detalle
    // -------------------------------------------------------------------------
    // Boton al pie del panel de detalle (lienzo de 1000x1520). El texto y el color los pone UpdateAugmentButton.
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

    // Encendido si el arma principal de la banda tiene copias sin equipar y no esta al tope; si no, apagado con el motivo.
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
        } else {
            if count == 0 {
                text = this.Fmt(this.T("GR-MenuAugNoCopies"), "%s", this.ArsenalGangLabel(this.m_rewards.GetOwnedGang(main)));
            } else {
                this.m_augReady = true;
                text = count == 1 ? this.T("GR-MenuAugReadyOne") : this.Fmt(this.T("GR-MenuAugReady"), "%d", IntToString(count));
            }
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

    // -------------------------------------------------------------------------
    // Aumento: capa de fusion
    // -------------------------------------------------------------------------
    // Panel de 3000x1500 centrado, encima de todo. Se crea una vez, oculto.
    private func CreateFusion(root: ref<inkCompoundWidget>) {
        let layer: ref<inkCanvas> = new inkCanvas();
        layer.SetName(n"fusion");
        layer.SetAnchor(inkEAnchor.Fill);
        layer.SetVisible(false);
        layer.Reparent(root);
        this.m_fusion = layer;

        // Fondo: oscurece la pantalla y, al ser interactivo, se queda con los clics que irian a lo de abajo.
        let scrim: ref<inkRectangle> = new inkRectangle();
        scrim.SetAnchor(inkEAnchor.Fill);
        scrim.SetMargin(new inkMargin(0.0, 150.0, 0.0, 0.0));
        scrim.SetTintColor(this.Dark());
        scrim.SetOpacity(0.6);
        scrim.SetInteractive(true);
        scrim.Reparent(layer);
        // Fondo opaco de toda el area de contenido (de la linea de la cabecera para abajo): detras de la capa no se ve nada.
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

        // Botones fijos, por encima del contenido. El orden es el de sus nombres "gr_fuse_N".
        this.AddFusionButton(panel, 1600.0, 312.0, 64.0, 64.0, 40);
        this.AddFusionButton(panel, 1772.0, 312.0, 64.0, 64.0, 40);
        this.AddFusionButton(panel, 520.0, 996.0, 440.0, 80.0, 34);
        this.AddFusionButton(panel, 988.0, 996.0, 440.0, 80.0, 34);
        this.AddFusionButton(panel, 850.0, 1280.0, 1300.0, 130.0, 48);
        this.AddFusionButton(panel, 80.0, 1305.0, 520.0, 80.0, 34);
        // Mantener presionado, como al fabricar: el juego manda el progreso de "craft_item" (clic izquierdo o F).
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

    // Relleno del boton de fusionar: 0 a 1.
    private func SetFuseProgress(progress: Float) {
        this.m_fProgress.SetSize(new Vector2(1300.0 * MinF(1.0, MaxF(0.0, progress)), 130.0));
    }

    // Elemento que quedaria ahora: el elegido o, si no se eligio, el del arma principal.
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
        let copies: array<Int32> = this.FusableCopies(main);
        if ArraySize(copies) == 0 {
            return;
        }
        this.m_fMain = main;
        this.m_fCopies = copies;
        // Si V tenia elegida una copia en el arsenal, la fusion empieza por esa.
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
        // El arsenal se oculta entero mientras la capa esta abierta (atenuado se seguia viendo, encimado con la capa).
        this.m_arsenal.SetVisible(false);
        this.m_fusion.SetVisible(true);
        this.RefreshFusion();
        if IsDefined(this.m_buttonHints) {
            this.m_buttonHints.AddButtonHint(n"back", this.T("GR-MenuAugBack"));
        }
        this.BringToFront();
        this.PlaySound(n"Button", n"OnPress");
    }

    // Cierra la capa y deja el arsenal como estaba. No destruye nada: el contenido se rehace al volver a abrir.
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

    // Tarjeta de 820x640 de la fusion, con la esquina en (x, 300) del panel: etiqueta, nombre, icono 2D, bono con su
    // elemento y nivel. Los tres ultimos se pasan aparte porque la tarjeta "Resultado" muestra los que quedarian.
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

    // Rehace el contenido de la capa (nada interactivo) y pone al dia los botones fijos.
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
            // Elementos entre los que se elige: dos si son distintos, uno si coinciden.
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

            // Tu arma + Copia que se destruye = Resultado.
            this.AddFuseCard(80.0, this.m_fMain, this.T("GR-MenuAugYours"), this.Grey(), this.Gold(), this.Gold(), mainElement, mainBonus, mainLevel);
            this.PlaceText(content, "+", 120, this.Dim(), n"Bold", 952.0, 545.0);
            this.AddFuseCard(1060.0, copy, this.T("GR-MenuAugCopy"), this.Red(), this.Dim(), this.Light(), copyElement, copyBonus, copyLevel);
            this.PlaceText(content, "=", 120, this.Dim(), n"Bold", 1932.0, 545.0);
            this.AddFuseCard(2040.0, this.m_fMain, this.T("GR-MenuAugResult"), this.Cyan(), this.Cyan(), this.Gold(), this.FusionKeep(), newBonus, newLevel);
            if copies > 1 {
                // "2/3" entre las dos flechas de la tarjeta de la copia.
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
            // Despues de fusionar: el arma como quedo, con su sello, y cuantas copias quedan.
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

        // Flechas: solo con varias copias; apagadas en los extremos.
        let nav: Bool = cards && copies > 1;
        let prevColor: HDRColor = this.m_fCopy > 0 ? this.Cyan() : this.Empty();
        let nextColor: HDRColor = this.m_fCopy < copies - 1 ? this.Cyan() : this.Empty();
        this.StyleFusionButton(0, nav, "<", prevColor, prevColor);
        this.StyleFusionButton(1, nav, ">", nextColor, nextColor);
        // Elemento que queda: el elegido con marco cian.
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

    // Fusiona la copia elegida. Lo llaman el "mantener presionado" y, de respaldo, el segundo clic.
    private func DoFuse() {
        if !this.m_fOpen || this.m_fDone || this.m_fCopy < 0 || this.m_fCopy >= ArraySize(this.m_fCopies) {
            return;
        }
        let ok: Bool = this.m_rewards.Fuse(this.m_fMain, this.m_fCopies[this.m_fCopy], this.FusionKeep());
        let fused: Int32 = this.m_rewards.GetFusedIndex();
        this.m_fConfirm = false;
        if !ok || fused < 0 {
            // No se pudo (el motivo queda en el log): la foto ya no valia. Se rehace y se vuelve al arsenal.
            this.m_rewards.Snapshot();
            this.CloseFusion();
            this.m_selWeapon = -1;
            this.FillArsenal();
            this.BringToFront();
            return;
        }
        // Fuse rehizo la foto: los indices cambiaron.
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
            // El juego si manda el progreso: el respaldo de dos clics ya no hace falta.
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

    // Clic en un boton de la capa ("gr_fuse_N").
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
            // Volver; despues de fusionar, si quedan copias, seguir con otra.
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
        // Boton de fusionar: al soltar se vacia el relleno. Si el juego manda el progreso de "mantener", fusiona
        // OnGRFuseHold; si nunca lo mando, el respaldo son dos clics (el primero pide confirmar).
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
        let gangs: array<String> = IsDefined(this.m_data) ? this.m_data.GetGangs() : [];
        // En Arsenal las pestanas son las 9 bandas fijas y la pagina es la suya.
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

    // ESC: con la capa de Aumento abierta la cierra y el menu sigue abierto; si no, lo de siempre (la clase base
    // cierra el menu). Mismo patron que la pantalla de fabricacion del juego.
    protected cb func OnBack(userData: ref<IScriptable>) -> Bool {
        if this.m_fOpen {
            this.CloseFusion();
        } else {
            super.OnBack(userData);
        }
    }

    protected cb func OnGRGlobalInput(evt: ref<inkPointerEvent>) -> Bool {
        // Con la capa de Aumento abierta no se cambia de vista ni de banda.
        if evt.IsHandled() || this.m_fOpen {
            return false;
        }
        // TAB (sort_list, como "Ordenar" en el Diario): bandas -> territorio -> arsenal.
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

// -----------------------------------------------------------------------------
// Registro de la pantalla en el menu del juego (igual que Dark Future)
// -----------------------------------------------------------------------------
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
    }
}

// -----------------------------------------------------------------------------
// Boton en el menu principal: el boton del juego, bajo Personaje / Estadisticas
// -----------------------------------------------------------------------------
@wrapMethod(MenuHubLogicController)
protected cb func OnInitialize() -> Bool {
    let result: Bool = wrappedMethod();
    this.GRAddNemesisButton();
    return result;
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
    // Dark Future pone su boton a 500 (670 con StealthRunner); este va justo debajo.
    let top: Float = 500.0;
    if GRHasDarkFuture() {
        top += 170.0;
    }
    if GRHasStealthRunner() {
        top += 170.0;
    }
    button.SetMargin(new inkMargin(0.0, top, 0.0, 0.0));

    let data: MenuData;
    data.disabled = false;
    data.fullscreenName = n"gangretaliation_nemesis_menu";
    data.identifier = 61;
    data.parentIdentifier = 2;
    data.label = GRSystem.Get(GetGameInstance()).GetText("GR-MenuButton");
    data.icon = n"ico_data_hub";
    let controller: ref<MenuItemController> = button.GetController() as MenuItemController;
    controller.Init(data);
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
