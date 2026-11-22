module GangRetaliationHistory.Localization

import Codeware.Localization.*

// Text for the Nemesis History screen, same mechanism and vocabulary as Gang Retaliation's own
// Localization.reds (Codeware ModLocalizationProvider; Spanish for es-es and es-mx). Where the main mod already
// has a key we reuse it instead of repeating it: GR-MenuDay, GR-MenuAlive, GR-MenuFallenShort, GR-MenuEmpty,
// GR-Rank*. The screen falls back to the English text below if a key is ever missing.
public class GRChronLocalizationProvider extends ModLocalizationProvider {
    public func GetPackage(language: CName) -> ref<ModLocalizationPackage> {
        switch language {
            case n"en-us": return new GRChronEnglish();
            case n"es-es": return new GRChronSpanish();
            case n"es-mx": return new GRChronSpanish();
            default: return null;
        }
    }

    public func GetFallback() -> CName {
        return n"en-us";
    }
}

public class GRChronEnglish extends ModLocalizationPackage {
    protected func DefineTexts() -> Void {
        this.Text("GRChron-Button", "NEMESIS HISTORY");
        this.Text("GRChron-Title", "Nemesis History");
        this.Text("GRChron-TabFull", "Full History");
        this.Text("GRChron-Today", "Current Day: %d");
        this.Text("GRChron-ViewHistory", "History");
        this.Text("GRChron-AllHistory", "All History");
        this.Text("GRChron-AllGangHistory", "All Gang History");
        this.Text("GRChron-AllGangs", "All gangs");
        this.Text("GRChron-EveryGang", "Every gang");
        this.Text("GRChron-Event1", "1 event");
        this.Text("GRChron-EventN", "%d events");
        this.Text("GRChron-AliveFallen", "%d alive  |  %d fallen");
        this.Text("GRChron-NoEventsHere", "No recorded events here yet.");
        this.Text("GRChron-NoHistory", "No history yet. It is recorded by the Gang Retaliation History mod while you play.");
        this.Text("GRChron-Hint", "A / D  switch tab     Esc  back");
        this.Text("GRChron-Now", "NOW");

        this.Text("GRChron-Kind-DEATH", "DEATH");
        this.Text("GRChron-Kind-RAID", "RAID");
        this.Text("GRChron-Kind-ARREST", "ARRESTED");
        this.Text("GRChron-Kind-RELEASED", "RELEASED");
        this.Text("GRChron-Kind-AMBUSH", "AMBUSH");
        this.Text("GRChron-Kind-BACKUP", "BACKUP");
        this.Text("GRChron-Kind-ESCAPED", "ESCAPED");
        this.Text("GRChron-Kind-PROMOTED", "PROMOTED");
        this.Text("GRChron-Kind-NEWFACE", "NEW FACE");
        this.Text("GRChron-Kind-FEUD", "FEUD");
        this.Text("GRChron-Kind-VACUUM", "POWER VACUUM");
        this.Text("GRChron-Kind-RETURNED", "RETURNED");
        this.Text("GRChron-Kind-TRAIT", "TRAIT");
        this.Text("GRChron-Kind-WAR", "WAR");
        this.Text("GRChron-Kind-TERRITORY", "TERRITORY");
        this.Text("GRChron-Kind-STRONGHOLD", "STRONGHOLD");
        this.Text("GRChron-Kind-INTEL", "INTEL");
        this.Text("GRChron-Kind-WEAPON", "WEAPON");
        this.Text("GRChron-Kind-NEWS", "NEWS");
    }
}

public class GRChronSpanish extends ModLocalizationPackage {
    protected func DefineTexts() -> Void {
        this.Text("GRChron-Button", "HISTORIAL DE NÉMESIS");
        this.Text("GRChron-Title", "HISTORIAL DE NÉMESIS");   // already capitals: StrUpper leaves accented letters alone
        this.Text("GRChron-TabFull", "Historial completo");
        this.Text("GRChron-Today", "Día actual: %d");
        this.Text("GRChron-ViewHistory", "Historial");
        this.Text("GRChron-AllHistory", "Todo el historial");
        this.Text("GRChron-AllGangHistory", "Historial de la banda");
        this.Text("GRChron-AllGangs", "Todas las bandas");
        this.Text("GRChron-EveryGang", "Todas las bandas");
        this.Text("GRChron-Event1", "1 evento");
        this.Text("GRChron-EventN", "%d eventos");
        this.Text("GRChron-AliveFallen", "%d vivos  |  %d caídos");
        this.Text("GRChron-NoEventsHere", "Todavía no hay eventos registrados aquí.");
        this.Text("GRChron-NoHistory", "Todavía no hay historial. Lo registra el mod Gang Retaliation History mientras juegas.");
        this.Text("GRChron-Hint", "A / D  cambiar pestaña     Esc  volver");
        this.Text("GRChron-Now", "AHORA");

        this.Text("GRChron-Kind-DEATH", "MUERTE");
        this.Text("GRChron-Kind-RAID", "REDADA");
        this.Text("GRChron-Kind-ARREST", "ARRESTADO");
        this.Text("GRChron-Kind-RELEASED", "LIBERADO");
        this.Text("GRChron-Kind-AMBUSH", "EMBOSCADA");
        this.Text("GRChron-Kind-BACKUP", "REFUERZOS");
        this.Text("GRChron-Kind-ESCAPED", "ESCAPE");
        this.Text("GRChron-Kind-PROMOTED", "ASCENSO");
        this.Text("GRChron-Kind-NEWFACE", "CARA NUEVA");
        this.Text("GRChron-Kind-FEUD", "LUCHA INTERNA");
        this.Text("GRChron-Kind-VACUUM", "VACÍO DE PODER");
        this.Text("GRChron-Kind-RETURNED", "REGRESO");
        this.Text("GRChron-Kind-TRAIT", "RASGO");
        this.Text("GRChron-Kind-WAR", "GUERRA");
        this.Text("GRChron-Kind-TERRITORY", "TERRITORIO");
        this.Text("GRChron-Kind-STRONGHOLD", "GUARIDA");
        this.Text("GRChron-Kind-INTEL", "INTEL");
        this.Text("GRChron-Kind-WEAPON", "ARMA");
        this.Text("GRChron-Kind-NEWS", "NOVEDAD");
    }
}
