module GangRetaliation

import Codeware.Localization.*

public func GRLog(msg: String) {
    FTLog("[GangRetaliation] " + msg);
}

public class GRSystem extends ScriptableSystem {
    private persistent let m_campaignId: Int32;

    private let m_sessionToken: Int32;

    // true cuando OnRestored ya corrio en esta sesion (no se guarda).
    private let m_restoredSeen: Bool;

    public static func Get(gi: GameInstance) -> ref<GRSystem> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRSystem") as GRSystem;
    }

    private func OnAttach() {
        this.m_sessionToken = RandRange(1, 999999999);
        GRLog("Sistema cargado");
    }

    public func GetSessionToken() -> Int32 {
        return this.m_sessionToken;
    }

    // Solo llega al cargar una partida, con los campos persistent ya restaurados.
    // Manda el id guardado; si llego en 0, el respaldo del fact; solo si los dos estan en 0 se genera uno nuevo.
    // Los facts ya estan cargados aca: el juego los lee en sus propios OnRestored (CraftingSystem).
    private func OnRestored(saveVersion: Int32, gameVersion: Int32) {
        this.m_restoredSeen = true;
        let saved: Int32 = this.m_campaignId;
        let fact: Int32 = this.ReadCampaignFact();
        let source: String = "persistente";
        if saved == 0 {
            // GenerateCampaignId mira el fact antes de generar.
            this.GenerateCampaignId("OnRestored, la partida no traia id");
            source = fact > 0 ? "fact" : "nueva";
        } else {
            if fact != saved {
                source = fact > 0 ? "persistente, el fact decia otro" : "persistente, sin fact todavia";
            }
        }
        this.WriteCampaignFact();
        // Cuantas armas de Jefe trae la partida: dice si a GRRewards si le llegaron sus campos persistent.
        let rewardsText: String = "?";
        let rewards: ref<GRRewards> = GRRewards.Get(this.GetGameInstance());
        if IsDefined(rewards) {
            rewardsText = IntToString(rewards.GetRegisteredCount());
        }
        GRLog("Partida restaurada: campana " + IntToString(saved) + " fact " + IntToString(fact) + " rewards=" + rewardsText
            + " -> usa " + IntToString(this.m_campaignId) + " (" + source + ")");
    }

    // En el menu principal tambien llega un jugador: ahi no se crea campana (dejaba campanas basura).
    // En una carga el id es el del guardado (OnRestored): aca solo se genera en partida nueva.
    private func OnPlayerAttach(request: ref<PlayerAttachRequest>) {
        if !this.IsInGame() {
            return;
        }
        if this.m_campaignId == 0 {
            if !this.WasRestored() {
                this.GenerateCampaignId("OnPlayerAttach, partida nueva");
            } else {
                if !this.m_restoredSeen {
                    // Red de seguridad: partida cargada pero OnRestored no llego a este sistema
                    // (guardado de antes de instalar el mod). Sin esto el mod quedaria sin campana.
                    this.GenerateCampaignId("OnPlayerAttach, partida cargada sin OnRestored");
                }
            }
        }
        // Las partidas de antes del respaldo lo reciben aca: queda en el proximo guardado.
        this.WriteCampaignFact();
    }

    // Respaldo del id en un fact del juego ("gr_campaign_id"). Los facts los guarda el juego por su cuenta:
    // sobreviven aunque la partida se guarde en una sesion sin el mod, cosa que los campos persistent no.
    private func ReadCampaignFact() -> Int32 {
        let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
        if !IsDefined(quests) {
            return 0;
        }
        return quests.GetFact(n"gr_campaign_id");
    }

    private func WriteCampaignFact() {
        if this.m_campaignId == 0 {
            return;
        }
        let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
        if IsDefined(quests) && quests.GetFact(n"gr_campaign_id") != this.m_campaignId {
            quests.SetFact(n"gr_campaign_id", this.m_campaignId);
        }
    }

    public func IsInGame() -> Bool {
        let requests: wref<inkISystemRequestsHandler> = GameInstance.GetSystemRequestsHandler();
        return IsDefined(requests) && !requests.IsPreGame();
    }

    // Privada a proposito: CET no puede generar el id (lo pedia durante la carga y le ganaba al guardado).
    // Antes de generar mira el respaldo del fact: si lo hay, se usa ese y no se crea campana nueva.
    private func GenerateCampaignId(source: String) {
        if this.m_campaignId != 0 {
            return;
        }
        let fact: Int32 = this.ReadCampaignFact();
        if fact > 0 {
            this.m_campaignId = fact;
            GRLog("Campana recuperada del fact: " + IntToString(fact) + " (" + source + ")");
        } else {
            this.m_campaignId = RandRange(100000, 999999999);
            GRLog("Nueva campana: " + IntToString(this.m_campaignId) + " (" + source + ")");
            this.WriteCampaignFact();
        }
    }

    // No genera id: CET la pide durante la carga, antes de que la partida restaure el suyo.
    // Devuelve 0 hasta que OnRestored u OnPlayerAttach lo dejen listo; CET espera.
    public func GetCampaignId() -> Int32 {
        return this.m_campaignId;
    }

    public func GetText(key: String) -> String {
        return LocalizationSystem.GetInstance(this.GetGameInstance()).GetText(key);
    }
}
