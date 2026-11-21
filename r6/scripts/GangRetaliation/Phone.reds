module GangRetaliation

public class GRPhone extends ScriptableSystem {
    private let m_queue: wref<JournalNotificationQueue>;

    public static func Get(gi: GameInstance) -> ref<GRPhone> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRPhone") as GRPhone;
    }

    public func SetQueue(queue: ref<JournalNotificationQueue>) {
        this.m_queue = queue;
    }

    public func SendThreat(from: String, fallbackText: String) -> Bool {
        return this.SendJournalSms("gr_unknown", "gr_threats", 1, 12, from, fallbackText);
    }

    public func SendReturn(from: String, fallbackText: String) -> Bool {
        return this.SendJournalSms("gr_unknown", "gr_threats", 13, 15, from, fallbackText);
    }

    public func SendTWR(first: Int32, fallbackText: String) -> Bool {
        return this.SendJournalSms("gr_unknown", "gr_threats", first, first + 2, "TWR", fallbackText);
    }

    public func SendBounty(deducted: Bool, fallbackText: String) -> Bool {
        if deducted {
            return this.SendJournalSms("gr_ncpd", "gr_bounty", 7, 9, "NCPD", fallbackText);
        }
        return this.SendJournalSms("gr_ncpd", "gr_bounty", 1, 6, "NCPD", fallbackText);
    }

    private func SendJournalSms(contactId: String, conversationId: String, first: Int32, last: Int32, from: String, fallbackText: String) -> Bool {
        let journal: ref<JournalManager> = GameInstance.GetJournalManager(this.GetGameInstance());
        let contact: String = "contacts/" + contactId;
        if !IsDefined(journal.GetEntryByString(contact, "gameJournalContact")) {
            GRLog("SMS: falta el journal del mod, solo aviso");
            return this.SendSms(from, fallbackText);
        }
        let next: Int32 = this.NextSlot(contactId, conversationId, first, last);
        this.ActivateSlot(contactId, conversationId, next, true);
        GRLog("SMS al telefono: sms_" + GRPhone.Pad(next) + " (" + from + ")");
        return true;
    }

    public func IsContactActive(contactId: String) -> Bool {
        let journal: ref<JournalManager> = GameInstance.GetJournalManager(this.GetGameInstance());
        let entry: wref<JournalEntry> = journal.GetEntryByString("contacts/" + contactId, "gameJournalContact");
        return IsDefined(entry) && Equals(journal.GetEntryState(entry), gameJournalEntryState.Active);
    }

    public func HasThread(contactId: String, conversationId: String) -> Bool {
        let journal: ref<JournalManager> = GameInstance.GetJournalManager(this.GetGameInstance());
        return IsDefined(journal.GetEntryByString("contacts/" + contactId + "/" + conversationId + "/sms_01", "gameJournalPhoneMessage"));
    }

    public func HasSlot(contactId: String, conversationId: String, slot: Int32) -> Bool {
        let journal: ref<JournalManager> = GameInstance.GetJournalManager(this.GetGameInstance());
        return IsDefined(journal.GetEntryByString("contacts/" + contactId + "/" + conversationId + "/sms_" + GRPhone.Pad(slot), "gameJournalPhoneMessage"));
    }

    public func NextSlot(contactId: String, conversationId: String, first: Int32, last: Int32) -> Int32 {
        let journal: ref<JournalManager> = GameInstance.GetJournalManager(this.GetGameInstance());
        let thread: String = "contacts/" + contactId + "/" + conversationId + "/sms_";
        let next: Int32 = 0;
        let i: Int32 = first;
        while i <= last && next == 0 {
            let entry: wref<JournalEntry> = journal.GetEntryByString(thread + GRPhone.Pad(i), "gameJournalPhoneMessage");
            if IsDefined(entry) && NotEquals(journal.GetEntryState(entry), gameJournalEntryState.Active) {
                next = i;
            }
            i += 1;
        }
        if next == 0 {
            i = first;
            while i <= last {
                journal.ChangeEntryState(thread + GRPhone.Pad(i), "gameJournalPhoneMessage", gameJournalEntryState.Inactive, JournalNotifyOption.DoNotNotify);
                i += 1;
            }
            next = first;
        }
        return next;
    }

    // Hilo con ranuras en bloques de 'kinds' tipos (la ranura i es del tipo ((i - 1) % kinds) + 1, ver build_archive.py).
    // Devuelve la primera ranura del tipo pedido despues de la ultima activa, asi los mensajes siempre quedan en orden.
    // Si no queda ninguna, vacia el hilo y empieza de nuevo. 0 = la ranura no existe en el journal (archive viejo).
    public func NextKindSlot(contactId: String, conversationId: String, kind: Int32, kinds: Int32, last: Int32) -> Int32 {
        let journal: ref<JournalManager> = GameInstance.GetJournalManager(this.GetGameInstance());
        let thread: String = "contacts/" + contactId + "/" + conversationId + "/sms_";
        let highest: Int32 = 0;
        let i: Int32 = 1;
        while i <= last {
            let entry: wref<JournalEntry> = journal.GetEntryByString(thread + GRPhone.Pad(i), "gameJournalPhoneMessage");
            if IsDefined(entry) && Equals(journal.GetEntryState(entry), gameJournalEntryState.Active) {
                highest = i;
            }
            i += 1;
        }
        let slot: Int32 = highest + 1;
        while slot <= last && ((slot - 1) % kinds) + 1 != kind {
            slot += 1;
        }
        if slot > last {
            i = 1;
            while i <= last {
                journal.ChangeEntryState(thread + GRPhone.Pad(i), "gameJournalPhoneMessage", gameJournalEntryState.Inactive, JournalNotifyOption.DoNotNotify);
                i += 1;
            }
            slot = kind;
            GRLog("SMS: hilo contacts/" + contactId + "/" + conversationId + " lleno, se vacia y empieza de nuevo");
        }
        if !IsDefined(journal.GetEntryByString(thread + GRPhone.Pad(slot), "gameJournalPhoneMessage")) {
            return 0;
        }
        return slot;
    }

    public func ActivateSlot(contactId: String, conversationId: String, slot: Int32, activateContact: Bool) {
        let journal: ref<JournalManager> = GameInstance.GetJournalManager(this.GetGameInstance());
        let contact: String = "contacts/" + contactId;
        let conversation: String = contact + "/" + conversationId;
        let path: String = conversation + "/sms_" + GRPhone.Pad(slot);
        if activateContact {
            journal.ChangeEntryState(contact, "gameJournalContact", gameJournalEntryState.Active, JournalNotifyOption.DoNotNotify);
        }
        journal.ChangeEntryState(conversation, "gameJournalPhoneConversation", gameJournalEntryState.Active, JournalNotifyOption.DoNotNotify);
        // Force a genuine Inactive->Active transition rather than setting Active directly - if the entry's
        // underlying state already reads Active (e.g. a reused slot, or just not a fresh transition), the
        // native UI doesn't register it as new. Matches Virtual Atelier Delivery's shipped
        // NotifyAboutLastHistoryItem(), which does the same Inactive-then-Active toggle.
        journal.ChangeEntryState(path, "gameJournalPhoneMessage", gameJournalEntryState.Inactive, JournalNotifyOption.DoNotNotify);
        journal.ChangeEntryState(path, "gameJournalPhoneMessage", gameJournalEntryState.Active, JournalNotifyOption.Notify);
        // gameJournalEntryState has no "unread" value of its own - read/unread is a separate flag,
        // JournalManager.SetEntryVisited(entry, Bool). Re-fetch the entry now that it's Active and
        // explicitly mark it unvisited (RedFalcon 2026-11-21: confirmed in game).
        let entry: wref<JournalEntry> = journal.GetEntryByString(path, "gameJournalPhoneMessage");
        if IsDefined(entry) {
            journal.SetEntryVisited(entry, false);
        }
    }

    public static func Pad(i: Int32) -> String {
        return (i < 10 ? "0" : "") + IntToString(i);
    }

    public func SendSms(from: String, text: String) -> Bool {
        if !IsDefined(this.m_queue) {
            GRLog("SMS: cola de avisos no disponible");
            return false;
        }
        let view: ref<PhoneMessageNotificationViewData> = new PhoneMessageNotificationViewData();
        view.title = from;
        view.SMSText = text;
        view.text = text;
        view.animation = n"notification_phone_MSG";
        view.soundEvent = n"PhoneSmsPopup";
        view.soundAction = n"OnOpen";
        let data: gameuiGenericNotificationData;
        data.time = 8.0;
        data.widgetLibraryItemName = n"notification_message";
        data.notificationData = view;
        this.m_queue.AddNewNotificationData(data);
        GRLog("SMS de " + from + ": " + text);
        return true;
    }
}

@wrapMethod(JournalNotificationQueue)
protected cb func OnPlayerAttach(playerPuppet: ref<GameObject>) -> Bool {
    let result: Bool = wrappedMethod(playerPuppet);
    if IsDefined(playerPuppet) {
        let phone: ref<GRPhone> = GRPhone.Get(playerPuppet.GetGame());
        if IsDefined(phone) {
            phone.SetQueue(this);
        }
    }
    return result;
}
