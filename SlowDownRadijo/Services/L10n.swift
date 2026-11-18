import Foundation

/// All app UI copy, in the two supported languages. Real-world content —
/// show names, track titles, artist names, the station's own brand name —
/// is never translated here, only our own interface text.
///
/// Call sites read `L10n.someKey` (or `L10n.someFunc(...)` for strings with
/// a value inside them); each one re-evaluates against
/// `LocalizationManager.shared.language` on every access, so as long as the
/// calling view holds an `@ObservedObject` reference to that manager, it
/// re-renders automatically when the language changes.
enum L10n {
    private static var lang: AppLanguage { LocalizationManager.shared.language }

    static var isEnglish: Bool { lang == .en }

    // MARK: - Shared

    static var ok: String { "OK" }

    // MARK: - Tab bar / page titles

    static var tabRadio: String {
        switch lang {
        case .cs: return "Rádio"
        case .en: return "Radio"
        }
    }

    static var tabProgram: String {
        switch lang {
        case .cs: return "Program"
        case .en: return "Schedule"
        }
    }

    static var tabMessage: String {
        switch lang {
        case .cs: return "Vzkaz"
        case .en: return "Message"
        }
    }

    static var tabSupport: String {
        switch lang {
        case .cs: return "Podpora"
        case .en: return "Support"
        }
    }

    /// Short tab-bar label — kept distinct from `favoritesTitle` ("Oblíbené
    /// skladby"), which is the fuller on-page heading, matching how every
    /// other tab pairs a one-word tab label with its own page title.
    static var tabFavorites: String {
        switch lang {
        case .cs: return "Oblíbené"
        case .en: return "Favorites"
        }
    }

    // MARK: - Home

    static var onAir: String { "ON-AIR" }

    /// The live-stream item on the car's screen (`CarPlaySceneDelegate`).
    static var carPlayLive: String {
        switch lang {
        case .cs: return "Živé vysílání"
        case .en: return "Live"
        }
    }

    /// "Moderuje JARO COSSIGA" under the show title on the home screen (`HomeView.showRow`).
    static var hostedByKicker: String {
        switch lang {
        case .cs: return "Moderuje"
        case .en: return "Hosted by"
        }
    }

    /// Section heading above the now-playing card, mirroring "Co hrálo"'s
    /// own heading treatment.
    static var nowPlayingHeading: String {
        switch lang {
        case .cs: return "Právě hraje"
        case .en: return "Now playing"
        }
    }

    static var connecting: String {
        switch lang {
        case .cs: return "Připojování…"
        case .en: return "Connecting…"
        }
    }

    /// VoiceOver labels for the play/pause button.
    static var playRadio: String {
        switch lang {
        case .cs: return "Pustit rádio"
        case .en: return "Play radio"
        }
    }

    static var pauseRadio: String {
        switch lang {
        case .cs: return "Pozastavit rádio"
        case .en: return "Pause radio"
        }
    }

    static var coHralo: String {
        switch lang {
        case .cs: return "Co hrálo"
        case .en: return "Recently played"
        }
    }

    static var last24h: String {
        switch lang {
        case .cs: return "Posledních 24 hodin"
        case .en: return "Last 24 hours"
        }
    }

    static var historyBuildingUp: String {
        switch lang {
        case .cs: return "Appka si historii vysílání sestavuje sama, jak posloucháš — dej jí chvilku a první skladby se tu objeví."
        case .en: return "The app builds up play history on its own while you listen — give it a moment and the first tracks will show up here."
        }
    }

    /// Kicker line above a show's name at a "Co hrálo" show-boundary row
    /// (see `ShowDividerRow`) — "Starting" as in "this show started here".
    static var showStartingKicker: String {
        switch lang {
        case .cs: return "Začátek pořadu"
        case .en: return "Show start"
        }
    }

    static var historyEnd: String {
        switch lang {
        case .cs: return "To je vše za posledních 24 hodin"
        case .en: return "That's everything from the last 24 hours"
        }
    }

    static func showEndsIn(_ duration: String) -> String {
        switch lang {
        case .cs: return "Pořad končí za \(duration)"
        case .en: return "Show ends in \(duration)"
        }
    }

    static var showEndingNow: String {
        switch lang {
        case .cs: return "Pořad právě končí"
        case .en: return "The show is ending now"
        }
    }


    /// "1h 29 min" / "1h 29m"
    static func durationShort(hours: Int, minutes: Int) -> String {
        switch lang {
        case .cs:
            return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes) min"
        case .en:
            return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
        }
    }

    /// "38 min" / "38 min"
    static func minutesShort(_ minutes: Int) -> String {
        "\(minutes) min"
    }

    /// Time left to the minute: "27 min", "1 h 27 min" (EN "27m", "1h 27m").
    static func remaining(hours: Int, minutes: Int) -> String {
        switch lang {
        case .cs: return hours > 0 ? "\(hours) h \(minutes) min" : "\(minutes) min"
        case .en: return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
        }
    }

    /// A running countdown to the second: "9 min 56 s", "1 h 27 min 36 s",
    /// "56 s" (EN "9m 56s", "1h 27m 36s", "56s").
    static func countdown(hours: Int, minutes: Int, seconds: Int) -> String {
        switch lang {
        case .cs:
            if hours > 0 { return "\(hours) h \(minutes) min \(seconds) s" }
            return minutes > 0 ? "\(minutes) min \(seconds) s" : "\(seconds) s"
        case .en:
            if hours > 0 { return "\(hours)h \(minutes)m \(seconds)s" }
            return minutes > 0 ? "\(minutes)m \(seconds)s" : "\(seconds)s"
        }
    }

    // MARK: - Sleep timer

    static var sleepTimerTitle: String {
        switch lang {
        case .cs: return "Vypnout za"
        case .en: return "Turn off in"
        }
    }

    static var cancelTimer: String {
        switch lang {
        case .cs: return "Zrušit časovač"
        case .en: return "Cancel timer"
        }
    }

    /// Inline link under the progress bar, shown when no timer is running.
    /// VoiceOver on the output picker: where the radio plays ("Hraje na:
    /// JBL Charge 3"). A colon, so device names needn't be declined.
    static func playsOn(_ device: String) -> String {
        switch lang {
        case .cs: return "Hraje na: \(device)"
        case .en: return "Playing on: \(device)"
        }
    }

    static var setSleepTimer: String {
        switch lang {
        case .cs: return "Nastavit časovač vypnutí"
        case .en: return "Set a sleep timer"
        }
    }

    /// Same link, while a timer is counting down.
    static func turnsOffIn(_ duration: String) -> String {
        switch lang {
        case .cs: return "Vypnutí za \(duration)"
        case .en: return "Turns off in \(duration)"
        }
    }

    static func minutesOption(_ minutes: Int) -> String {
        switch lang {
        case .cs: return "\(minutes) minut"
        case .en: return "\(minutes) minutes"
        }
    }

    static var oneHour: String {
        switch lang {
        case .cs: return "1 hodina"
        case .en: return "1 hour"
        }
    }

    static var endOfShow: String {
        switch lang {
        case .cs: return "Konec pořadu"
        case .en: return "End of show"
        }
    }

    /// Heading of the sleep-timer sheet.
    static var sleepTimerSheetTitle: String {
        switch lang {
        case .cs: return "Časovač vypnutí"
        case .en: return "Sleep timer"
        }
    }

    /// Line under the heading while no timer is running.
    static var sleepTimerHint: String {
        switch lang {
        case .cs: return "Rádio po uplynutí času samo ztichne."
        case .en: return "The radio goes quiet on its own when time is up."
        }
    }

    /// Unit under the big number on a sleep-timer tile.
    static var minutesUnit: String { "min" }

    static var hoursUnit: String {
        switch lang {
        case .cs: return "hod"
        case .en: return "hr"
        }
    }

    /// "Konec pořadu" tile's trailing detail, e.g. "v 12:00".
    static func atTime(_ time: String) -> String {
        switch lang {
        case .cs: return "v \(time)"
        case .en: return "at \(time)"
        }
    }

    /// VoiceOver for "< 1 m" in the stats.
    static var statsUnderAMinute: String {
        switch lang {
        case .cs: return "méně než minuta"
        case .en: return "less than a minute"
        }
    }

    /// VoiceOver for the pulsing dot by "Dnes".
    static var statsCountingNow: String {
        switch lang {
        case .cs: return "právě se počítá"
        case .en: return "counting now"
        }
    }

    // MARK: - Show reminders

    /// Notification title when a followed show starts; the body is its name.
    static var showStartingTitle: String {
        switch lang {
        case .cs: return "Právě začíná"
        case .en: return "On air now"
        }
    }

    /// The notification's action button.
    static var listenAction: String {
        switch lang {
        case .cs: return "Poslouchat"
        case .en: return "Listen"
        }
    }

    static var tomorrow: String {
        switch lang {
        case .cs: return "zítra"
        case .en: return "tomorrow"
        }
    }

    /// "dnes v 09:00" / "zítra v 09:00" / "Út v 09:00".
    static func nextAiring(day: String, time: String) -> String {
        switch lang {
        case .cs: return "\(day) v \(time)"
        case .en: return "\(day) at \(time)"
        }
    }

    /// Toast after turning a show's reminder on.
    static func reminderOnToast(show: String, next: String?) -> String {
        switch lang {
        case .cs:
            let base = "Dáme ti vědět, až začne \(show)."
            return next.map { "\(base) Nejbližší: \($0)." } ?? base
        case .en:
            let base = "We'll let you know when \(show) starts."
            return next.map { "\(base) Next: \($0)." } ?? base
        }
    }

    static func reminderOffToast(show: String) -> String {
        switch lang {
        case .cs: return "Upozornění na \(show) vypnuto."
        case .en: return "\(show) reminders off."
        }
    }

    static var notificationsBlockedToast: String {
        switch lang {
        case .cs: return "Notifikace má appka v nastavení iOS vypnuté."
        case .en: return "Notifications are turned off for the app in iOS settings."
        }
    }

    static var openSettingsAction: String {
        switch lang {
        case .cs: return "Nastavení"
        case .en: return "Settings"
        }
    }

    /// VoiceOver label of the bell next to a show.
    static func reminderBellLabel(show: String) -> String {
        switch lang {
        case .cs: return "Upozornit na začátek pořadu \(show)"
        case .en: return "Remind me when \(show) starts"
        }
    }

    static var showRemindersTitle: String {
        switch lang {
        case .cs: return "Upozornění na pořady"
        case .en: return "Show reminders"
        }
    }

    static var showRemindersIntro: String {
        switch lang {
        case .cs: return "Pošleme ti upozornění ve chvíli, kdy vybraný pořad začíná. Zapnout ho jde i zvonečkem v seznamu Pořady."
        case .en: return "We'll notify you the moment a chosen show starts. You can also use the bell in the Shows list."
        }
    }

    /// Subtitle of the Settings row.
    static func showRemindersSummary(count: Int) -> String {
        switch lang {
        case .cs:
            switch count {
            case 0: return "Vypnuto"
            case 1: return "Zapnuto u 1 pořadu"
            default: return "Zapnuto u \(count) pořadů"
            }
        case .en:
            switch count {
            case 0: return "Off"
            case 1: return "On for 1 show"
            default: return "On for \(count) shows"
            }
        }
    }

    static var turnOffAllReminders: String {
        switch lang {
        case .cs: return "Vypnout všechna upozornění"
        case .en: return "Turn off all reminders"
        }
    }

    // MARK: - Program

    static var noProgramForDay: String {
        switch lang {
        case .cs: return "Pro tento den nemáme program."
        case .en: return "We don't have a schedule for this day."
        }
    }

    /// Heading for the compact schedule embedded on the home screen —
    /// deliberately not `tabProgram` ("Program"), which named the
    /// now-hidden standalone tab this section replaces.
    static var homeProgramHeading: String {
        switch lang {
        case .cs: return "Pořady"
        case .en: return "Shows"
        }
    }

    /// Day picker's label for today's chip, in place of its weekday
    /// abbreviation.
    static var today: String {
        switch lang {
        case .cs: return "Dnes"
        case .en: return "Today"
        }
    }

    static func showPreviousShows(count: Int) -> String {
        switch lang {
        case .cs: return "Zobrazit předchozí pořady (\(count))"
        case .en: return "Show previous shows (\(count))"
        }
    }

    static var hidePreviousShows: String {
        switch lang {
        case .cs: return "Skrýt předchozí pořady"
        case .en: return "Hide previous shows"
        }
    }

    /// Two-letter weekday abbreviation, independent of `schedule.json`'s
    /// (always-Czech) `dayName` field — `weekday` is `Calendar`'s
    /// Sunday-first numbering (1...7).
    static func shortDayName(weekday: Int) -> String {
        let table: [Int: [AppLanguage: String]] = [
            1: [.cs: "Ne", .en: "Su"],
            2: [.cs: "Po", .en: "Mo"],
            3: [.cs: "Út", .en: "Tu"],
            4: [.cs: "St", .en: "We"],
            5: [.cs: "Čt", .en: "Th"],
            6: [.cs: "Pá", .en: "Fr"],
            7: [.cs: "So", .en: "Sa"]
        ]
        return table[weekday]?[lang] ?? "?"
    }

    // MARK: - Podpora

    static var supportIntro: String {
        switch lang {
        case .cs: return "Slow Down Rádijo je nezávislé rádio bez reklam. Tvá podpora nám pomáhá udržet vysílání v chodu."
        case .en: return "Slow Down Rádijo is an independent, ad-free radio station. Your support helps keep us on air."
        }
    }

    static var support: String {
        switch lang {
        case .cs: return "Podpořit"
        case .en: return "Support"
        }
    }

    /// Heading over the single shared benefits list — all three platforms
    /// offer the same perks, so they're shown once rather than repeated
    /// under every card (see `SupportOption.sharedBenefits`).
    static var supportBenefitsTitle: String {
        switch lang {
        case .cs: return "Co získáš podporou"
        case .en: return "What you get"
        }
    }

    static var supportChooseTitle: String {
        switch lang {
        case .cs: return "Vyber si platformu"
        case .en: return "Choose a platform"
        }
    }

    static var perMonth: String {
        switch lang {
        case .cs: return "měsíc"
        case .en: return "month"
        }
    }

    static var benefitRecordings: String {
        switch lang {
        case .cs: return "Záznamy vysílání"
        case .en: return "Show recordings"
        }
    }

    static var benefitBehindTheScenes: String {
        switch lang {
        case .cs: return "Videa ze zákulisí"
        case .en: return "Behind-the-scenes videos"
        }
    }

    static var benefitContests: String {
        switch lang {
        case .cs: return "Soutěže pro podporovatele"
        case .en: return "Contests for supporters"
        }
    }

    static var benefitMerchDiscount: String {
        switch lang {
        case .cs: return "Sleva na merch"
        case .en: return "Discount on merch"
        }
    }

    // MARK: - Vzkaz (message)

    static var sendMessage: String {
        switch lang {
        case .cs: return "Pošli nám vzkaz"
        case .en: return "Send us a message"
        }
    }

    static var sendMessageSubtitle: String {
        switch lang {
        case .cs: return "Máš něco na srdci? Klepni na mikrofon a nahraj nám vzkaz — třeba zazní v éteru!"
        case .en: return "Got something on your mind? Tap the mic and record us a message — it might make it on air!"
        }
    }

    static var privacyNote: String {
        switch lang {
        case .cs: return "Po nahrání si vzkaz můžeš poslechnout a teprve pak ho odešleš. Dokud nepotvrdíš odeslání, nikam se nic neodešle."
        case .en: return "After recording you can listen back before sending — nothing goes anywhere until you confirm."
        }
    }

    static var startRecording: String {
        switch lang {
        case .cs: return "Začít nahrávat"
        case .en: return "Start recording"
        }
    }

    static var maxOneMinute: String {
        switch lang {
        case .cs: return "MAX. 1 MINUTA"
        case .en: return "MAX. 1 MINUTE"
        }
    }

    static var sendToRadio: String {
        switch lang {
        case .cs: return "Odeslat vzkaz do rádia"
        case .en: return "Send message to the radio"
        }
    }

    static var recordingInProgress: String {
        switch lang {
        case .cs: return "Nahráváš vzkaz"
        case .en: return "Recording your message"
        }
    }

    static var tapToStop: String {
        switch lang {
        case .cs: return "Klepnutím zastavíš nahrávání"
        case .en: return "Tap to stop recording"
        }
    }

    static var discardMessage: String {
        switch lang {
        case .cs: return "Zahodit vzkaz"
        case .en: return "Discard message"
        }
    }

    static var discardMessageConfirm: String {
        switch lang {
        case .cs: return "Zahodit nahraný vzkaz? Nikam se neodešle."
        case .en: return "Discard the recording? It won't be sent."
        }
    }

    static var cancelRecording: String {
        switch lang {
        case .cs: return "Zrušit nahrávání"
        case .en: return "Cancel recording"
        }
    }

    static var recorded: String {
        switch lang {
        case .cs: return "NAHRÁNO"
        case .en: return "RECORDED"
        }
    }

    static var sentBadge: String {
        switch lang {
        case .cs: return "ODESLÁNO"
        case .en: return "SENT"
        }
    }

    static var messageRecorded: String {
        switch lang {
        case .cs: return "Vzkaz nahraný"
        case .en: return "Message recorded"
        }
    }

    static var listenOrRerecord: String {
        switch lang {
        case .cs: return "Poslechnout si nahrávku nebo nahrát znovu"
        case .en: return "Listen back or record again"
        }
    }

    /// VoiceOver / TalkBack labels of the recorded message's play button.
    static var playRecording: String {
        switch lang {
        case .cs: return "Přehrát nahrávku"
        case .en: return "Play recording"
        }
    }

    static var pauseRecording: String {
        switch lang {
        case .cs: return "Pozastavit nahrávku"
        case .en: return "Pause recording"
        }
    }

    static var recordAgain: String {
        switch lang {
        case .cs: return "Nahrát znovu"
        case .en: return "Record again"
        }
    }

    static var messageSent: String {
        switch lang {
        case .cs: return "Vzkaz odeslán!"
        case .en: return "Message sent!"
        }
    }

    static var thankYouForMessage: String {
        switch lang {
        case .cs: return "Děkujeme za váš vzkaz. Redakce ho posoudí a možná zazní v éteru!"
        case .en: return "Thanks for your message. Our team will take a listen — it might make it on air!"
        }
    }

    static var backToRadio: String {
        switch lang {
        case .cs: return "Zpět na rádio"
        case .en: return "Back to radio"
        }
    }

    static var recordAnotherMessage: String {
        switch lang {
        case .cs: return "Nahrát další vzkaz"
        case .en: return "Record another message"
        }
    }

    static var micUnavailableTitle: String {
        switch lang {
        case .cs: return "Mikrofon není dostupný"
        case .en: return "Microphone unavailable"
        }
    }

    static var micUnavailableMessage: String {
        switch lang {
        case .cs: return "Povol appce přístup k mikrofonu v Nastavení, abys mohl nahrát vzkaz."
        case .en: return "Allow microphone access in Settings so you can record a message."
        }
    }

    static var sendingTitle: String {
        switch lang {
        case .cs: return "Odesílám vzkaz..."
        case .en: return "Sending your message..."
        }
    }

    static var sendingSubtitle: String {
        switch lang {
        case .cs: return "Prosím počkej, nahrávka se odesílá."
        case .en: return "Please wait, your recording is uploading."
        }
    }

    static var sendingButtonLabel: String {
        switch lang {
        case .cs: return "Odesílání..."
        case .en: return "Sending..."
        }
    }

    static var uploadFailedTitle: String {
        switch lang {
        case .cs: return "Odeslání se nepovedlo"
        case .en: return "Couldn't send message"
        }
    }

    static var uploadFailedMessage: String {
        switch lang {
        case .cs: return "Zkontroluj připojení k internetu a zkus to znovu."
        case .en: return "Check your internet connection and try again."
        }
    }

    // MARK: - Player errors

    static var streamInterrupted: String {
        switch lang {
        case .cs: return "Spojení se streamem přerušeno, zkouším se znovu připojit…"
        case .en: return "Stream connection lost, reconnecting…"
        }
    }

    // MARK: - Hub

    static var hubTitle: String {
        switch lang {
        case .cs: return "Menu"
        case .en: return "Menu"
        }
    }

    static var hubWhatsAppRow: String { "WhatsApp" }

    static var hubWhatsAppRowSubtitle: String {
        switch lang {
        case .cs: return "Napiš nám přímo"
        case .en: return "Message us directly"
        }
    }

    static var hubSettingsRow: String {
        switch lang {
        case .cs: return "Nastavení"
        case .en: return "Settings"
        }
    }

    static var hubSettingsRowSubtitle: String {
        switch lang {
        case .cs: return "Přehrávání, statistiky, soukromí"
        case .en: return "Playback, stats, privacy"
        }
    }

    static var hubNewsRow: String {
        switch lang {
        case .cs: return "Novinky"
        case .en: return "News"
        }
    }

    static var hubNewsRowSubtitle: String {
        switch lang {
        case .cs: return "Co se děje v rádiu"
        case .en: return "What's happening at the station"
        }
    }

    static var hubFeedbackRow: String {
        switch lang {
        case .cs: return "Zpětná vazba"
        case .en: return "Feedback"
        }
    }

    static var hubFeedbackRowSubtitle: String {
        switch lang {
        case .cs: return "Napiš nám, co si myslíš"
        case .en: return "Tell us what you think"
        }
    }

    static var close: String {
        switch lang {
        case .cs: return "Zavřít"
        case .en: return "Close"
        }
    }

    static var hubSocialTitle: String {
        switch lang {
        case .cs: return "Sledujte nás"
        case .en: return "Follow us"
        }
    }

    // MARK: - Favorites

    static var favoritesTitle: String {
        switch lang {
        case .cs: return "Oblíbené skladby"
        case .en: return "Favorite tracks"
        }
    }

    static var favoritesEmptyTitle: String {
        switch lang {
        case .cs: return "Zatím žádné oblíbené"
        case .en: return "No favorites yet"
        }
    }

    static var favoritesEmptyBody: String {
        switch lang {
        case .cs: return "Klepni na srdce u skladby v Co hrálo a uložíš si ji sem."
        case .en: return "Tap the heart on a track in Co hrálo to save it here."
        }
    }

    static var favoritesDeleteTitle: String {
        switch lang {
        case .cs: return "Smazat ze seznamu?"
        case .en: return "Remove from favorites?"
        }
    }

    static func favoritesDeleteMessage(trackTitle: String) -> String {
        switch lang {
        case .cs: return "Opravdu chceš smazat „\(trackTitle)“ z oblíbených skladeb?"
        case .en: return "Are you sure you want to remove “\(trackTitle)” from your favorites?"
        }
    }

    static var favoritesDeleteConfirm: String {
        switch lang {
        case .cs: return "Smazat"
        case .en: return "Remove"
        }
    }

    static var favoritesDeleteCancel: String {
        switch lang {
        case .cs: return "Zrušit"
        case .en: return "Cancel"
        }
    }

    static var favoritesIntroTitle: String {
        switch lang {
        case .cs: return "Skladba uložena"
        case .en: return "Track saved"
        }
    }

    static var favoritesIntroBody: String {
        switch lang {
        case .cs: return "Kdykoliv klepneš na srdce, skladba se uloží do záložky Oblíbené, kde se k ní můžeš kdykoliv vrátit."
        case .en: return "Whenever you tap the heart, the track is saved to the Favorites tab, where you can come back to it anytime."
        }
    }

    static var favoritesIntroDismiss: String {
        switch lang {
        case .cs: return "Rozumím"
        case .en: return "Got it"
        }
    }

    static var previewPlayAction: String {
        switch lang {
        case .cs: return "Přehrát ukázku"
        case .en: return "Play preview"
        }
    }

    static var previewLoadingAction: String {
        switch lang {
        case .cs: return "Načítání…"
        case .en: return "Loading…"
        }
    }

    static var previewStopAction: String {
        switch lang {
        case .cs: return "Zastavit ukázku"
        case .en: return "Stop preview"
        }
    }

    static var favoriteAddAction: String {
        switch lang {
        case .cs: return "Přidat do oblíbených"
        case .en: return "Add to favorites"
        }
    }

    static var favoriteRemoveAction: String {
        switch lang {
        case .cs: return "Odebrat z oblíbených"
        case .en: return "Remove from favorites"
        }
    }

    static var spotifyFindAction: String {
        switch lang {
        case .cs: return "Najít na Spotify"
        case .en: return "Find on Spotify"
        }
    }

    /// Under an earlier song on the home screen: "před 6 min".
    static func playedAgo(minutes: Int) -> String {
        let minutes = max(minutes, 1)
        let duration = remaining(hours: minutes / 60, minutes: minutes % 60)
        switch lang {
        case .cs: return "před \(duration)"
        case .en: return "\(duration) ago"
        }
    }

    /// After the last earlier song on the home screen.
    static var noEarlierSongs: String {
        switch lang {
        case .cs: return "Starší skladby z tohoto pořadu tu nemáme"
        case .en: return "No earlier songs from this show here"
        }
    }

    // MARK: - Settings

    static var settingsTitle: String {
        switch lang {
        case .cs: return "Nastavení"
        case .en: return "Settings"
        }
    }

    static var settingsAutoplayTitle: String {
        switch lang {
        case .cs: return "Automatické přehrávání"
        case .en: return "Autoplay"
        }
    }

    static var settingsAutoplayDescription: String {
        switch lang {
        case .cs: return "Appka spustí rádio hned po otevření, bez nutnosti klepnout na Přehrát."
        case .en: return "The app starts playing as soon as it opens, without tapping Play."
        }
    }

    static var settingsLanguageTitle: String {
        switch lang {
        case .cs: return "Jazyk"
        case .en: return "Language"
        }
    }

    static var settingsFeedbackTitle: String {
        switch lang {
        case .cs: return "Zpětná vazba"
        case .en: return "Feedback"
        }
    }

    static var settingsFeedbackIntro: String {
        switch lang {
        case .cs: return "Napiš nám, jak se ti appka používá — jak jsi spokojen, co ti v ní chybí nebo přebývá, nebo jestli ti něco nefunguje, jak by mělo."
        case .en: return "Tell us how the app's working for you — how satisfied you are, what's missing or unnecessary, or if something's not working right."
        }
    }

    static var settingsFeedbackPlaceholder: String {
        switch lang {
        case .cs: return "Tvoje zpráva…"
        case .en: return "Your message…"
        }
    }

    static var settingsFeedbackSend: String {
        switch lang {
        case .cs: return "Odeslat"
        case .en: return "Send"
        }
    }

    static var settingsFeedbackSending: String {
        switch lang {
        case .cs: return "Odesílám…"
        case .en: return "Sending…"
        }
    }

    static var settingsFeedbackSent: String {
        switch lang {
        case .cs: return "Díky! Zpráva byla odeslána."
        case .en: return "Thanks! Your message was sent."
        }
    }

    static var settingsFeedbackSendAnother: String {
        switch lang {
        case .cs: return "Napsat další zprávu"
        case .en: return "Write another message"
        }
    }

    static var settingsFeedbackFailed: String {
        switch lang {
        case .cs: return "Nepodařilo se odeslat. Zkontroluj připojení a zkus to znovu."
        case .en: return "Couldn't send. Check your connection and try again."
        }
    }

    static var settingsFeedbackTryAgain: String {
        switch lang {
        case .cs: return "Zkusit znovu"
        case .en: return "Try again"
        }
    }

    static func settingsAbout(version: String, build: String) -> String {
        switch lang {
        case .cs: return "Verze \(version) (\(build))"
        case .en: return "Version \(version) (\(build))"
        }
    }

    static var settingsStatsTitle: String {
        switch lang {
        case .cs: return "Statistiky poslechu"
        case .en: return "Listening stats"
        }
    }

    static var settingsStatsDescription: String {
        switch lang {
        case .cs: return "Měříme jen čas, kdy rádio hraje, pod anonymním ID – bez jména a e-mailu. Díky tomu uvidíš své statistiky a své místo mezi posluchači."
        case .en: return "We only measure how long the radio plays, under an anonymous ID – no name or e-mail. That's what powers your stats and your place among listeners."
        }
    }

    static var settingsAnalyticsTitle: String {
        switch lang {
        case .cs: return "Anonymní měření používání"
        case .en: return "Anonymous usage analytics"
        }
    }

    static var settingsAnalyticsDescription: String {
        switch lang {
        case .cs: return "Pomáhá nám zjistit, které části appky se používají a co zlepšit. Bez jména, e-mailu a reklamních ID."
        case .en: return "Helps us see which parts of the app get used and what to improve. No name, e-mail or advertising IDs."
        }
    }

    static var analyticsConsentTitle: String {
        switch lang {
        case .cs: return "Pomůžeš nám appku vylepšovat?"
        case .en: return "Help us make the app better?"
        }
    }

    static var analyticsConsentBody: String {
        switch lang {
        case .cs: return "Rádi bychom anonymně měřili, které funkce používáš. Žádné jméno, e-mail ani reklama. Volbu můžeš kdykoli změnit v Nastavení."
        case .en: return "We'd like to anonymously measure which features you use. No name, e-mail or ads. You can change this any time in Settings."
        }
    }

    static var analyticsConsentAllow: String {
        switch lang {
        case .cs: return "Povolit"
        case .en: return "Allow"
        }
    }

    static var analyticsConsentDecline: String {
        switch lang {
        case .cs: return "Ne, díky"
        case .en: return "No, thanks"
        }
    }

    static var settingsStatsDeleteTitle: String {
        switch lang {
        case .cs: return "Smazat moje statistiky"
        case .en: return "Delete my stats"
        }
    }

    static var settingsStatsDeleteDescription: String {
        switch lang {
        case .cs: return "Odstraní tvůj naměřený poslech z našeho serveru i z telefonu."
        case .en: return "Removes your measured listening from our server and from this phone."
        }
    }

    static var statsDeleteConfirmTitle: String {
        switch lang {
        case .cs: return "Smazat všechny tvoje statistiky?"
        case .en: return "Delete all your stats?"
        }
    }

    static var statsDeleteConfirmMessage: String {
        switch lang {
        case .cs: return "Nelze vrátit zpět. Měření případně začne znovu od nuly."
        case .en: return "This can't be undone. If measuring is on, it starts again from zero."
        }
    }

    static var statsDeleteConfirmAction: String {
        switch lang {
        case .cs: return "Smazat"
        case .en: return "Delete"
        }
    }

    static var statsDeleteCancel: String {
        switch lang {
        case .cs: return "Zrušit"
        case .en: return "Cancel"
        }
    }

    static var statsDeletedTitle: String {
        switch lang {
        case .cs: return "Statistiky smazány"
        case .en: return "Stats deleted"
        }
    }

    static var statsDeleteFailedTitle: String {
        switch lang {
        case .cs: return "Smazání se nepovedlo"
        case .en: return "Couldn't delete"
        }
    }

    static var statsDeleteFailedMessage: String {
        switch lang {
        case .cs: return "Zkus to znovu, až budeš připojený/á k internetu."
        case .en: return "Try again when you're online."
        }
    }

    // MARK: - Statistiky

    static var tabStats: String {
        switch lang {
        case .cs: return "Statistiky"
        case .en: return "Stats"
        }
    }

    static var statsTitle: String {
        switch lang {
        case .cs: return "Statistiky"
        case .en: return "Stats"
        }
    }

    static var statsSubtitle: String {
        switch lang {
        case .cs: return "Tvůj čas s rádiem. Od dnešních minut až po místo mezi ostatními posluchači."
        case .en: return "Your time with the radio. From today’s minutes to your place among the other listeners."
        }
    }

    static var statsTotal: String {
        switch lang {
        case .cs: return "Celkem"
        case .en: return "Total"
        }
    }

    static var statsTodayDescription: String {
        switch lang {
        case .cs: return "Tolik času jsi dnes strávil/a poslechem Slow Down rádia v appce."
        case .en: return "This is how long you listened to Slow Down Radio in the app today."
        }
    }

    static var statsTotalDescription: String {
        switch lang {
        case .cs: return "Součet tvého zaznamenaného poslechu v appce napříč všemi dny."
        case .en: return "The sum of your recorded listening in the app across all days."
        }
    }

    static var statsCommunityTitle: String {
        switch lang {
        case .cs: return "Celkem všichni Slow Down Riders"
        case .en: return "All Slow Down Riders combined"
        }
    }

    static var statsCommunityDescription: String {
        switch lang {
        case .cs: return "Součet veškerého poslechu v appce napříč všemi dny od všech."
        case .en: return "All listening in the app, across all days, from everyone."
        }
    }

    static var statsLeaderboardTitle: String {
        switch lang {
        case .cs: return "Žebříček posluchačů"
        case .en: return "Listener leaderboard"
        }
    }

    static var statsLeaderboardScope: String {
        switch lang {
        case .cs: return "Žebříček posluchačů v appce"
        case .en: return "Leaderboard of app listeners"
        }
    }

    static var statsRankOf: String {
        switch lang {
        case .cs: return "z"
        case .en: return "of"
        }
    }

    static func statsLeaderboardDescription(count: String) -> String {
        switch lang {
        case .cs: return "Tvoje místo mezi \(count) posluchači podle zaznamenaného času poslechu v appce."
        case .en: return "Your place among \(count) listeners, based on recorded listening time in the app."
        }
    }

    static var statsEncouragement: String {
        switch lang {
        case .cs: return "Díky, že ladíš s námi. Tady nejde o závod, ale o společný čas s hudbou."
        case .en: return "Thanks for tuning in with us. This isn’t a race — it’s time spent together with music."
        }
    }

    static var statsTimelineTitle: String {
        switch lang {
        case .cs: return "Tvůj poslech v čase"
        case .en: return "Your listening over time"
        }
    }

    static var statsWeekCaption: String {
        switch lang {
        case .cs: return "za 7 dní"
        case .en: return "last 7 days"
        }
    }

    static var statsShowsTitle: String {
        switch lang {
        case .cs: return "Čas s jednotlivými pořady"
        case .en: return "Time with each show"
        }
    }

    static func statsShowsContext(total: String) -> String {
        switch lang {
        case .cs: return "Za celou dobu · \(total)"
        case .en: return "All time · \(total)"
        }
    }

    static var statsTopShowKicker: String {
        switch lang {
        case .cs: return "NEJVÍC POSLECHU"
        case .en: return "MOST LISTENED"
        }
    }

    static var statsExplainTitle: String {
        switch lang {
        case .cs: return "Co čísla znamenají?"
        case .en: return "What do the numbers mean?"
        }
    }

    static var statsExplainBody: String {
        switch lang {
        case .cs: return "Dnes je čas poslechu během dnešního dne. Celkem zahrnuje veškerý zaznamenaný poslech v appce; dnešní čas je jeho součástí."
        case .en: return "Today is your listening time during today. Total includes all recorded listening in the app; today’s time is part of it."
        }
    }

    static var statsPrivacyNote: String {
        switch lang {
        case .cs: return "Měříme jen čas poslechu pod anonymním ID. Vypnout to jde v nastavení."
        case .en: return "We only measure listening time under an anonymous ID. You can turn it off in Settings."
        }
    }

    static var statsUnknownShow: String {
        switch lang {
        case .cs: return "Mimo program"
        case .en: return "Outside the schedule"
        }
    }

    static var statsEmptyChart: String {
        switch lang {
        case .cs: return "Zatím tu nic není."
        case .en: return "Nothing here yet."
        }
    }

    static var statsEmptyShows: String {
        switch lang {
        case .cs: return "Až si něco poslechneš, uvidíš tu své oblíbené pořady."
        case .en: return "Once you’ve listened to something, your favourite shows will show up here."
        }
    }

    static var statsRankNoListening: String {
        switch lang {
        case .cs: return "Pusť si rádio a zjistíš, kde ses mezi posluchači ocitl/a."
        case .en: return "Play the radio and you’ll see where you stand among the listeners."
        }
    }

    static var statsRankNeedsMinute: String {
        switch lang {
        case .cs: return "Pořadí se ti ukáže po první minutě poslechu."
        case .en: return "Your rank appears after your first minute of listening."
        }
    }

    static var statsRankCalculating: String {
        switch lang {
        case .cs: return "Pořadí se právě počítá…"
        case .en: return "Working out your rank…"
        }
    }

    static var statsRankFailed: String {
        switch lang {
        case .cs: return "Pořadí se teď nepodařilo načíst."
        case .en: return "Couldn’t load your rank right now."
        }
    }

    static var statsLeaderboardLocked: String {
        switch lang {
        case .cs: return "Žebříček se objeví, jakmile se v appce sejde dost posluchačů. Do té doby tu máš svůj vlastní čas s rádiem."
        case .en: return "The leaderboard appears once enough listeners have joined the app. Until then, here’s your own time with the radio."
        }
    }

    static var statsRetry: String {
        switch lang {
        case .cs: return "Zkusit znovu"
        case .en: return "Try again"
        }
    }

    static var statsOfflineNote: String {
        switch lang {
        case .cs: return "Offline – pořadí se aktualizuje po připojení."
        case .en: return "Offline – your rank updates once you’re back online."
        }
    }

    static var statsDisabledMessage: String {
        switch lang {
        case .cs: return "Statistiky jsou vypnuté. Nic se neměří ani neukládá."
        case .en: return "Stats are turned off. Nothing is measured or stored."
        }
    }

    static var statsEnableAction: String {
        switch lang {
        case .cs: return "Zapnout"
        case .en: return "Turn on"
        }
    }

    static var statsHomeTitle: String {
        switch lang {
        case .cs: return "Tvoje statistiky poslechu"
        case .en: return "Your listening stats"
        }
    }

    static var settingsPrivacyPolicy: String {
        switch lang {
        case .cs: return "Zásady ochrany osobních údajů"
        case .en: return "Privacy Policy"
        }
    }

    // MARK: - News

    static var newsTitle: String {
        switch lang {
        case .cs: return "Novinky"
        case .en: return "News"
        }
    }

    static var newsLoadFailed: String {
        switch lang {
        case .cs: return "Nepodařilo se načíst novinky."
        case .en: return "Couldn't load news."
        }
    }

    static var newsEmpty: String {
        switch lang {
        case .cs: return "Zatím žádné novinky."
        case .en: return "No news yet."
        }
    }

    static var newsWatchVideo: String {
        switch lang {
        case .cs: return "Sledovat video"
        case .en: return "Watch video"
        }
    }

    /// Formats a date using the app's own CZ/EN language setting rather
    /// than the device's system locale — everything else in the app
    /// already follows `LocalizationManager`, independent of Settings ▸
    /// Language, and dates shouldn't be the one exception.
    static func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: lang == .cs ? "cs_CZ" : "en_US")
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// The local notification's title when a new "Novinka" is detected —
    /// see `NewsNotificationManager`. Reads from whatever `lang` was set
    /// to at the moment the check ran, same as everything else here.
    static var newsNotificationTitle: String {
        switch lang {
        case .cs: return "Nová novinka na Slow Down Rádiu"
        case .en: return "New post on Slow Down Rádijo"
        }
    }

    // MARK: - Notifications

    static var notificationsNewPostTitle: String {
        switch lang {
        case .cs: return "Nová novinka"
        case .en: return "New post"
        }
    }

    static var notificationsNewPostDescription: String {
        switch lang {
        case .cs: return "Upozornit, když na rádiu vyjde nová novinka."
        case .en: return "Get notified when a new post is published."
        }
    }
}

// Lives here rather than in `Show.swift`, which the widget also compiles
// without `L10n`.
// MARK: - Profil and accounts (app 1.3)

extension L10n {
    static var tabProfile: String {
        switch lang {
        case .cs: return "Profil"
        case .en: return "Profile"
        }
    }

    static var profileTitle: String {
        switch lang {
        case .cs: return "Profil"
        case .en: return "Profile"
        }
    }

    static var cancel: String {
        switch lang {
        case .cs: return "Zrušit"
        case .en: return "Cancel"
        }
    }

    static var profileSignInTitle: String {
        switch lang {
        case .cs: return "Přihlas se a piš do chatu"
        case .en: return "Sign in to write in the chat"
        }
    }

    static var profileSignInBody: String {
        switch lang {
        case .cs: return "Poslouchat a číst chat můžeš i bez účtu. Přihlášení potřebuješ jen k psaní."
        case .en: return "You can listen and read the chat without an account. You only need to sign in to write."
        }
    }

    static var signInApple: String {
        switch lang {
        case .cs: return "Pokračovat s Apple"
        case .en: return "Continue with Apple"
        }
    }

    static var signInGoogle: String {
        switch lang {
        case .cs: return "Pokračovat s Google"
        case .en: return "Continue with Google"
        }
    }

    static var signInEmail: String {
        switch lang {
        case .cs: return "Pokračovat e‑mailem"
        case .en: return "Continue with e‑mail"
        }
    }

    static var profileOtherSection: String {
        switch lang {
        case .cs: return "Ostatní"
        case .en: return "More"
        }
    }

    static var chatRulesTitle: String {
        switch lang {
        case .cs: return "Pravidla chatu"
        case .en: return "Chat rules"
        }
    }

    static var emailSignInTitle: String {
        switch lang {
        case .cs: return "Přihlášení e‑mailem"
        case .en: return "Sign in with e‑mail"
        }
    }

    static var emailSignInBody: String {
        switch lang {
        case .cs: return "Pošleme ti 6místný kód. Heslo si pamatovat nemusíš."
        case .en: return "We’ll send you a 6‑digit code. No password to remember."
        }
    }

    static var emailFieldLabel: String { "E‑mail" }

    static var emailFieldPlaceholder: String {
        switch lang {
        case .cs: return "tvuj@email.cz"
        case .en: return "you@example.com"
        }
    }

    static var emailSendCode: String {
        switch lang {
        case .cs: return "Poslat kód"
        case .en: return "Send code"
        }
    }

    static var emailNewAccountNote: String {
        switch lang {
        case .cs: return "Pokud účet ještě nemáš, tímhle ho rovnou založíš."
        case .en: return "If you don’t have an account yet, this creates one."
        }
    }

    static var emailInvalidAddress: String {
        switch lang {
        case .cs: return "Tohle nevypadá jako e‑mailová adresa."
        case .en: return "That doesn’t look like an e‑mail address."
        }
    }

    static var emailCodeTitle: String {
        switch lang {
        case .cs: return "Zadej kód z e‑mailu"
        case .en: return "Enter the code from the e‑mail"
        }
    }

    static func emailCodeBody(_ email: String) -> String {
        switch lang {
        case .cs: return "Poslali jsme ho na \(email). Platí 10 minut. Funguje i odkaz přímo v e‑mailu."
        case .en: return "We sent it to \(email). It’s valid for 10 minutes. The link in the e‑mail works too."
        }
    }

    static func emailResendIn(_ time: String) -> String {
        switch lang {
        case .cs: return "Poslat znovu za \(time)"
        case .en: return "Resend in \(time)"
        }
    }

    static var emailResend: String {
        switch lang {
        case .cs: return "Poslat nový kód"
        case .en: return "Send a new code"
        }
    }

    static var emailChange: String {
        switch lang {
        case .cs: return "Změnit e‑mail"
        case .en: return "Change e‑mail"
        }
    }

    static var emailCodeInvalid: String {
        switch lang {
        case .cs: return "Kód nesedí nebo už vypršel."
        case .en: return "The code is wrong or has expired."
        }
    }

    static func signInFailed(_ provider: String) -> String {
        switch lang {
        case .cs: return "Přihlášení přes \(provider) se nepovedlo. Zkus to znovu."
        case .en: return "Signing in with \(provider) didn’t work. Please try again."
        }
    }

    static var signInUnavailable: String {
        switch lang {
        case .cs: return "Tohle přihlášení zatím není k dispozici."
        case .en: return "This sign‑in isn’t available yet."
        }
    }

    static var errorOffline: String {
        switch lang {
        case .cs: return "Nejsi připojený k internetu. Zkus to znovu."
        case .en: return "You’re offline. Please try again."
        }
    }

    static var errorTooManyRequests: String {
        switch lang {
        case .cs: return "Moc pokusů za sebou. Zkus to za chvíli."
        case .en: return "Too many attempts. Please try again in a moment."
        }
    }

    static var errorGeneric: String {
        switch lang {
        case .cs: return "Něco se nepovedlo. Zkus to znovu."
        case .en: return "Something went wrong. Please try again."
        }
    }

    static var signInMethodEmail: String { "e‑mail" }

    static func signedInWith(_ method: String) -> String {
        switch lang {
        case .cs: return "Přihlášený přes \(method)"
        case .en: return "Signed in with \(method)"
        }
    }

    static var profileChatSection: String { "Chat" }

    static var profileAccountSection: String {
        switch lang {
        case .cs: return "Účet"
        case .en: return "Account"
        }
    }

    static var profileNickname: String {
        switch lang {
        case .cs: return "Přezdívka"
        case .en: return "Nickname"
        }
    }

    static var profileHiddenUsers: String {
        switch lang {
        case .cs: return "Skrytí uživatelé"
        case .en: return "Hidden listeners"
        }
    }

    static var profileSignInMethod: String {
        switch lang {
        case .cs: return "Přihlášení"
        case .en: return "Signed in with"
        }
    }

    static var profileSignOut: String {
        switch lang {
        case .cs: return "Odhlásit se"
        case .en: return "Sign out"
        }
    }

    static var profileDeleteAccount: String {
        switch lang {
        case .cs: return "Smazat účet"
        case .en: return "Delete account"
        }
    }

    static var profileHostRole: String {
        switch lang {
        case .cs: return "Moderátor rádia"
        case .en: return "Radio host"
        }
    }

    static var profileHostName: String {
        switch lang {
        case .cs: return "Jméno v chatu"
        case .en: return "Name in the chat"
        }
    }

    static var profileHostNameValue: String {
        switch lang {
        case .cs: return "z programu rádia"
        case .en: return "from the programme"
        }
    }

    static var dayToday: String {
        switch lang {
        case .cs: return "dnes"
        case .en: return "today"
        }
    }

    static var dayTomorrow: String {
        switch lang {
        case .cs: return "zítra"
        case .en: return "tomorrow"
        }
    }

    static func mutedBanner(day: String, time: String) -> String {
        switch lang {
        case .cs: return "Psaní do chatu máš pozastavené do \(day) \(time)"
        case .en: return "Your chat writing is paused until \(day) \(time)"
        }
    }

    static var blockedBanner: String {
        switch lang {
        case .cs: return "Psaní do chatu máš zablokované"
        case .en: return "You’re blocked from writing in the chat"
        }
    }

    static var mutedBannerBody: String {
        switch lang {
        case .cs: return "Číst a poslouchat můžeš dál."
        case .en: return "You can still read and listen."
        }
    }

    static var nicknameSetupTitle: String {
        switch lang {
        case .cs: return "Ještě přezdívka"
        case .en: return "One more thing: a nickname"
        }
    }

    static var nicknameSetupBody: String {
        switch lang {
        case .cs: return "Pod tímhle jménem tě uvidí ostatní v chatu."
        case .en: return "Others in the chat will see you under this name."
        }
    }

    static var nicknamePlaceholder: String {
        switch lang {
        case .cs: return "např. vinylovy_tom"
        case .en: return "e.g. vinyl_tom"
        }
    }

    static var nicknameRules: String {
        switch lang {
        case .cs: return "3–20 znaků: písmena bez diakritiky, číslice, tečka a podtržítko. Změnit ji půjde jednou za 24 hodin."
        case .en: return "3–20 characters: letters without accents, digits, dot and underscore. You can change it once every 24 hours."
        }
    }

    static var nicknameDone: String {
        switch lang {
        case .cs: return "Hotovo"
        case .en: return "Done"
        }
    }

    static var nicknameAvailable: String {
        switch lang {
        case .cs: return "Přezdívka je volná"
        case .en: return "This nickname is free"
        }
    }

    static var nicknameTaken: String {
        switch lang {
        case .cs: return "Tahle přezdívka je obsazená"
        case .en: return "This nickname is taken"
        }
    }

    static var nicknameReserved: String {
        switch lang {
        case .cs: return "Tahle přezdívka je vyhrazená"
        case .en: return "This nickname is reserved"
        }
    }

    static var nicknameInvalid: String {
        switch lang {
        case .cs: return "3–20 znaků bez mezer a diakritiky"
        case .en: return "3–20 characters, no spaces or accents"
        }
    }

    static var nicknameEditInfo: String {
        switch lang {
        case .cs: return "Přezdívku můžeš měnit jednou za 24 hodin."
        case .en: return "You can change your nickname once every 24 hours."
        }
    }

    static var nicknameSave: String {
        switch lang {
        case .cs: return "Uložit"
        case .en: return "Save"
        }
    }

    static func nicknameConfirmTitle(_ name: String) -> String {
        switch lang {
        case .cs: return "Změnit na \(name)?"
        case .en: return "Change to \(name)?"
        }
    }

    static var nicknameConfirmBody: String {
        switch lang {
        case .cs: return "Další změna bude možná až za 24 hodin. Tvoje starší zprávy se přejmenují taky."
        case .en: return "The next change will be possible in 24 hours. Your earlier messages will be renamed too."
        }
    }

    static var nicknameConfirmAction: String {
        switch lang {
        case .cs: return "Změnit přezdívku"
        case .en: return "Change nickname"
        }
    }

    static func nicknameCooldown(day: String, time: String) -> String {
        switch lang {
        case .cs: return "Další změna bude možná \(day) v \(time)."
        case .en: return "The next change will be possible \(day) at \(time)."
        }
    }

    static var signOutConfirmTitle: String {
        switch lang {
        case .cs: return "Odhlásit se?"
        case .en: return "Sign out?"
        }
    }

    static var signOutConfirmBody: String {
        switch lang {
        case .cs: return "Chat budeš dál vidět. Psát půjde po novém přihlášení."
        case .en: return "You’ll still see the chat. To write, sign in again."
        }
    }

    static var deleteAccountConfirmTitle: String {
        switch lang {
        case .cs: return "Smazat účet natrvalo?"
        case .en: return "Delete your account for good?"
        }
    }

    static var deleteAccountConfirmBody: String {
        switch lang {
        case .cs: return "Smažeme přezdívku, přihlášení i statistiky poslechu. Tvoje zprávy v chatu zůstanou jako „Smazaný účet“. Vrátit to nepůjde."
        case .en: return "We’ll delete your nickname, sign‑in and listening stats. Your chat messages stay as “Deleted account”. This can’t be undone."
        }
    }

    static var deletedAccount: String {
        switch lang {
        case .cs: return "Smazaný účet"
        case .en: return "Deleted account"
        }
    }

    static var hiddenUsersBody: String {
        switch lang {
        case .cs: return "Jejich zprávy v chatu nevidíš. Oni o tom nevědí."
        case .en: return "You don’t see their messages in the chat. They don’t know."
        }
    }

    static var hiddenUsersEmpty: String {
        switch lang {
        case .cs: return "Nikoho jsi zatím neskryl."
        case .en: return "You haven’t hidden anyone."
        }
    }

    static var hiddenUsersShow: String {
        switch lang {
        case .cs: return "Zobrazit"
        case .en: return "Show"
        }
    }

    static var chatRulesIntro: String {
        switch lang {
        case .cs: return "Chat je společný prostor posluchačů a moderátorů Slow Down Rádija."
        case .en: return "The chat is a shared space for Slow Down Rádijo’s listeners and hosts."
        }
    }

    static var chatRule1: String {
        switch lang {
        case .cs: return "Buď na ostatní slušný. Žádné urážky, nenávist ani obtěžování."
        case .en: return "Be kind. No insults, hate or harassment."
        }
    }

    static var chatRule2: String {
        switch lang {
        case .cs: return "Nespamuj a nepiš reklamu. Odkazy jen k hudbě a vysílání."
        case .en: return "No spam or ads. Links only about music and the broadcast."
        }
    }

    static var chatRule3: String {
        switch lang {
        case .cs: return "Nesdílej cizí osobní údaje."
        case .en: return "Don’t share other people’s personal data."
        }
    }

    static var chatRule4: String {
        switch lang {
        case .cs: return "Moderátoři můžou zprávu smazat, autora ztlumit nebo zablokovat."
        case .en: return "Hosts can delete a message, mute its author or block them."
        }
    }

    static var chatRule5: String {
        switch lang {
        case .cs: return "Nevhodnou zprávu nahlas podržením prstu na ní."
        case .en: return "Report an inappropriate message by pressing and holding it."
        }
    }
}

// MARK: - Chat (app 1.3)

extension L10n {
    static var chatTitle: String {
        switch lang {
        case .cs: return "Chat"
        case .en: return "Chat"
        }
    }

    static var chatOpen: String {
        switch lang {
        case .cs: return "Otevřít chat"
        case .en: return "Open the chat"
        }
    }

    static var chatToday: String {
        switch lang {
        case .cs: return "Dnes"
        case .en: return "Today"
        }
    }

    static var chatYesterday: String {
        switch lang {
        case .cs: return "Včera"
        case .en: return "Yesterday"
        }
    }

    static var chatNoShow: String {
        switch lang {
        case .cs: return "Hudba bez moderace"
        case .en: return "Music, no host"
        }
    }

    static var chatPlaceholder: String {
        switch lang {
        case .cs: return "Napiš zprávu…"
        case .en: return "Write a message…"
        }
    }

    static var chatWritingAs: String {
        switch lang {
        case .cs: return "Píšeš jako"
        case .en: return "Writing as"
        }
    }

    static var chatSignInToSend: String {
        switch lang {
        case .cs: return "Pro odeslání se přihlas"
        case .en: return "Sign in to send"
        }
    }

    static var chatPinned: String {
        switch lang {
        case .cs: return "Připnuto"
        case .en: return "Pinned"
        }
    }

    static var chatDeletedByModerator: String {
        switch lang {
        case .cs: return "Zprávu odstranil moderátor"
        case .en: return "Removed by a moderator"
        }
    }

    static var chatQuietTitle: String {
        switch lang {
        case .cs: return "Dnes tu zatím ticho"
        case .en: return "Quiet here today"
        }
    }

    static var chatQuietBody: String {
        switch lang {
        case .cs: return "Začni ty — pozdrav ostatní nebo napiš, co posloucháš."
        case .en: return "Start it off — say hi or tell us what you're listening to."
        }
    }

    static var chatHomeQuiet: String {
        switch lang {
        case .cs: return "Dnes tu zatím ticho — pozdrav ostatní 👋"
        case .en: return "Quiet here today — say hi 👋"
        }
    }

    static var chatStarterHello: String {
        switch lang {
        case .cs: return "Ahoj 👋"
        case .en: return "Hi 👋"
        }
    }

    static var chatStarterWhatPlayed: String {
        switch lang {
        case .cs: return "Co to teď hrálo?"
        case .en: return "What was that track?"
        }
    }

    static var chatSending: String {
        switch lang {
        case .cs: return "Odesílám…"
        case .en: return "Sending…"
        }
    }

    static var chatNotSent: String {
        switch lang {
        case .cs: return "Neodesláno"
        case .en: return "Not sent"
        }
    }

    static var chatRetry: String {
        switch lang {
        case .cs: return "Zkusit znovu"
        case .en: return "Try again"
        }
    }

    static var chatJoinTitle: String {
        switch lang {
        case .cs: return "Připoj se do chatu"
        case .en: return "Join the chat"
        }
    }

    static var chatJoinBody: String {
        switch lang {
        case .cs: return "Číst může každý. Psát můžeš po přihlášení — zabere to pár vteřin a rozepsaná zpráva se pak odešle sama."
        case .en: return "Anyone can read. To write, sign in — it takes a few seconds and your message is sent right after."
        }
    }

    static var chatNotNow: String {
        switch lang {
        case .cs: return "Teď ne"
        case .en: return "Not now"
        }
    }

    static var chatJoinLegal: String {
        switch lang {
        case .cs: return "Pokračováním souhlasíš s Pravidly chatu a Zásadami ochrany soukromí."
        case .en: return "By continuing you agree to the Chat rules and the Privacy policy."
        }
    }

    static var chatCopy: String {
        switch lang {
        case .cs: return "Kopírovat"
        case .en: return "Copy"
        }
    }

    static var chatEmoji: String {
        switch lang {
        case .cs: return "Emoji"
        case .en: return "Emoji"
        }
    }

    static var chatSend: String {
        switch lang {
        case .cs: return "Odeslat"
        case .en: return "Send"
        }
    }

    static var chatClose: String {
        switch lang {
        case .cs: return "Zavřít"
        case .en: return "Close"
        }
    }

    static var chatLoadFailed: String {
        switch lang {
        case .cs: return "Chat se teď nepodařilo načíst."
        case .en: return "The chat couldn't load right now."
        }
    }

    static var chatShowRules: String {
        switch lang {
        case .cs: return "Pravidla chatu"
        case .en: return "Chat rules"
        }
    }

    static func chatSentAs(_ name: String) -> String {
        switch lang {
        case .cs: return "Odesláno jako \(name)"
        case .en: return "Sent as \(name)"
        }
    }

    static func chatNamesAndMore(_ names: String, _ count: Int) -> String {
        switch lang {
        case .cs: return "\(names) a \(count) další"
        case .en: return "\(names) and \(count) more"
        }
    }

    /// "↓ 3 nové zprávy" (plural; Android: `L10nLogic.chatNewMessages`).
    static func chatNewMessages(_ count: Int) -> String {
        switch lang {
        case .cs:
            if count == 1 { return "1 nová zpráva" }
            if (2...4).contains(count) { return "\(count) nové zprávy" }
            return "\(count) nových zpráv"
        case .en:
            return count == 1 ? "1 new message" : "\(count) new messages"
        }
    }
}

// MARK: - Chat moderation and DJ invites (app 1.3)

extension L10n {
    static var errorInviteOtherHost: String {
        switch lang {
        case .cs: return "Tvůj účet už je propojený s jiným moderátorem."
        case .en: return "Your account is already linked to another host."
        }
    }

    static var errorRestoreExpired: String {
        switch lang {
        case .cs: return "Zprávu už nejde vrátit."
        case .en: return "The message can't be restored any more."
        }
    }

    static var errorNotModerator: String {
        switch lang {
        case .cs: return "Na tohle nemáš oprávnění."
        case .en: return "You aren't allowed to do that."
        }
    }

    static var errorUserInvalid: String {
        switch lang {
        case .cs: return "Tohohle posluchače nejde ztlumit ani zablokovat."
        case .en: return "This listener can't be muted or blocked."
        }
    }

    static var errorMessageNotFound: String {
        switch lang {
        case .cs: return "Zpráva už v chatu není."
        case .en: return "The message is no longer in the chat."
        }
    }

    static var errorMuted: String {
        switch lang {
        case .cs: return "Psaní do chatu máš teď pozastavené."
        case .en: return "Your chat writing is paused right now."
        }
    }

    static var chatMenuPin: String {
        switch lang {
        case .cs: return "Připnout zprávu"
        case .en: return "Pin message"
        }
    }

    static var chatMenuUnpin: String {
        switch lang {
        case .cs: return "Odepnout zprávu"
        case .en: return "Unpin message"
        }
    }

    static var chatMenuCopy: String {
        switch lang {
        case .cs: return "Kopírovat text"
        case .en: return "Copy text"
        }
    }

    static var chatMenuDelete: String {
        switch lang {
        case .cs: return "Smazat zprávu"
        case .en: return "Delete message"
        }
    }

    static var chatMenuMute: String {
        switch lang {
        case .cs: return "Ztlumit…"
        case .en: return "Mute…"
        }
    }

    static var chatMenuUnmute: String {
        switch lang {
        case .cs: return "Zrušit ztlumení"
        case .en: return "Unmute"
        }
    }

    static var chatMenuBlock: String {
        switch lang {
        case .cs: return "Zablokovat…"
        case .en: return "Block…"
        }
    }

    static var chatMenuReport: String {
        switch lang {
        case .cs: return "Nahlásit zprávu"
        case .en: return "Report message"
        }
    }

    static var chatMuteBody: String {
        switch lang {
        case .cs: return "Dál bude poslouchat a číst chat, jen do něj nic nenapíše. Ostatní posluchači ztlumení neuvidí."
        case .en: return "They can still listen and read the chat, just not write. Other listeners won't see the mute."
        }
    }

    static var chatMuteHour: String {
        switch lang {
        case .cs: return "1 hodina"
        case .en: return "1 hour"
        }
    }

    static var chatMuteDay: String {
        switch lang {
        case .cs: return "24 hodin"
        case .en: return "24 hours"
        }
    }

    static var chatMuteWeek: String {
        switch lang {
        case .cs: return "7 dní"
        case .en: return "7 days"
        }
    }

    static var chatMuteActionHour: String {
        switch lang {
        case .cs: return "Ztlumit na 1 hodinu"
        case .en: return "Mute for 1 hour"
        }
    }

    static var chatMuteActionDay: String {
        switch lang {
        case .cs: return "Ztlumit na 24 hodin"
        case .en: return "Mute for 24 hours"
        }
    }

    static var chatMuteActionWeek: String {
        switch lang {
        case .cs: return "Ztlumit na 7 dní"
        case .en: return "Mute for 7 days"
        }
    }

    static var chatUndo: String {
        switch lang {
        case .cs: return "Vrátit"
        case .en: return "Undo"
        }
    }

    static var chatBlockBody: String {
        switch lang {
        case .cs: return "Do chatu už nenapíše, dokud blokaci nezruší správce rádia. Jeho dosavadní zprávy zůstanou — smazat je můžeš zvlášť."
        case .en: return "They won't be able to write until the radio's admin lifts the block. Their messages so far stay — you can delete them one by one."
        }
    }

    static var chatBlockAction: String {
        switch lang {
        case .cs: return "Zablokovat"
        case .en: return "Block"
        }
    }

    static var chatDeletedToast: String {
        switch lang {
        case .cs: return "Zpráva smazána"
        case .en: return "Message deleted"
        }
    }

    static var chatReportedToast: String {
        switch lang {
        case .cs: return "Díky. Zprávu uvidí moderátoři."
        case .en: return "Thanks. The moderators will see it."
        }
    }

    static var chatPinnedToast: String {
        switch lang {
        case .cs: return "Zpráva připnuta"
        case .en: return "Message pinned"
        }
    }

    static var chatUnpinnedToast: String {
        switch lang {
        case .cs: return "Zpráva odepnuta"
        case .en: return "Message unpinned"
        }
    }

    static var inviteKicker: String {
        switch lang {
        case .cs: return "Pozvánka pro moderátora"
        case .en: return "Host invite"
        }
    }

    static var inviteTitleGeneric: String {
        switch lang {
        case .cs: return "Propoj účet jako moderátor"
        case .en: return "Link your account as a host"
        }
    }

    static var inviteBody: String {
        switch lang {
        case .cs: return "V chatu pak budeš psát pod jménem z programu se štítkem DJ a můžeš připínat, mazat a ztlumovat zprávy."
        case .en: return "In the chat you'll then write under your name from the programme with a DJ tag, and you can pin, delete and mute."
        }
    }

    static var inviteSample: String {
        switch lang {
        case .cs: return "Dobré ráno! Co dnes posloucháte u kafe? ☕"
        case .en: return "Good morning! What are you listening to with your coffee? ☕"
        }
    }

    static var inviteOneUse: String {
        switch lang {
        case .cs: return "Pozvánka jde použít jen jednou."
        case .en: return "The invite works only once."
        }
    }

    static var inviteDoneBody: String {
        switch lang {
        case .cs: return "Tvůj účet je propojený. Takhle tě uvidí posluchači:"
        case .en: return "Your account is linked. This is how listeners will see you:"
        }
    }

    static var inviteDoneHint: String {
        switch lang {
        case .cs: return "Podržením prstu na zprávě ji připneš, smažeš nebo ztlumíš autora."
        case .en: return "Press and hold a message to pin it, delete it or mute its author."
        }
    }

    static var inviteOpenChat: String {
        switch lang {
        case .cs: return "Otevřít chat"
        case .en: return "Open the chat"
        }
    }

    static var inviteInvalidTitle: String {
        switch lang {
        case .cs: return "Pozvánka už neplatí"
        case .en: return "This invite has expired"
        }
    }

    static var inviteInvalidBody: String {
        switch lang {
        case .cs: return "Odkaz vypršel nebo už byl použitý. Napiš rádiu a pošleme ti nový."
        case .en: return "The link has expired or was already used. Write to the radio and we'll send a new one."
        }
    }

    static var inviteLinking: String {
        switch lang {
        case .cs: return "Propojuju účet…"
        case .en: return "Linking your account…"
        }
    }

    static var inviteClose: String {
        switch lang {
        case .cs: return "Zavřít"
        case .en: return "Close"
        }
    }

    static func chatMenuHide(_ name: String) -> String {
        switch lang {
        case .cs: return "Skrýt zprávy od \(name)"
        case .en: return "Hide messages from \(name)"
        }
    }

    static func chatMutedStatus(_ day: String, _ time: String, _ by: String) -> String {
        switch lang {
        case .cs: return "Ztlumený do \(day) \(time) · ztlumil \(by)"
        case .en: return "Muted until \(day) \(time) · by \(by)"
        }
    }

    static func chatBlockedStatus(_ by: String) -> String {
        switch lang {
        case .cs: return "Zablokovaný · zablokoval \(by)"
        case .en: return "Blocked · by \(by)"
        }
    }

    static func chatRemainingHours(_ hours: Int) -> String {
        switch lang {
        case .cs: return "zbývá \(hours) h"
        case .en: return "\(hours)h left"
        }
    }

    static func chatRemainingMinutes(_ minutes: Int) -> String {
        switch lang {
        case .cs: return "zbývá \(minutes) min"
        case .en: return "\(minutes)m left"
        }
    }

    static func chatMuteTitle(_ name: String) -> String {
        switch lang {
        case .cs: return "Ztlumit \(name)"
        case .en: return "Mute \(name)"
        }
    }

    static func chatMutedToast(_ name: String, _ day: String, _ time: String) -> String {
        switch lang {
        case .cs: return "\(name) je ztlumený do \(day) \(time)"
        case .en: return "\(name) is muted until \(day) \(time)"
        }
    }

    static func chatUnmutedToast(_ name: String) -> String {
        switch lang {
        case .cs: return "\(name) už není ztlumený"
        case .en: return "\(name) is no longer muted"
        }
    }

    static func chatBlockTitle(_ name: String) -> String {
        switch lang {
        case .cs: return "Zablokovat \(name)?"
        case .en: return "Block \(name)?"
        }
    }

    static func chatBlockedToast(_ name: String) -> String {
        switch lang {
        case .cs: return "\(name) je zablokovaný"
        case .en: return "\(name) is blocked"
        }
    }

    static func chatHiddenToast(_ name: String) -> String {
        switch lang {
        case .cs: return "Zprávy od \(name) už neuvidíš"
        case .en: return "You won't see messages from \(name)"
        }
    }

    static func inviteTitle(_ name: String) -> String {
        switch lang {
        case .cs: return "Propoj účet jako \(name)"
        case .en: return "Link your account as \(name)"
        }
    }

    static func inviteValidUntil(_ date: String) -> String {
        switch lang {
        case .cs: return "Pozvánka platí do \(date) a jde použít jen jednou."
        case .en: return "The invite is valid until \(date) and works only once."
        }
    }

    static func inviteDoneTitle(_ name: String) -> String {
        switch lang {
        case .cs: return "Hotovo, jsi \(name)"
        case .en: return "Done, you're \(name)"
        }
    }

}

// MARK: - Chat v3: Slowriders, dashboard, admin (app 1.3)

extension L10n {
    static var chatNicknameTitle: String {
        switch lang {
        case .cs: return "Tvoje přezdívka"
        case .en: return "Your nickname"
        }
    }

    static var chatNicknameBody: String {
        switch lang {
        case .cs: return "Pod tímhle jménem tě uvidí ostatní v chatu. Účet k tomu nepotřebuješ."
        case .en: return "Others in the chat will see you under this name. No account needed."
        }
    }

    static var chatNicknameRules: String {
        switch lang {
        case .cs: return "3–20 znaků: písmena bez diakritiky, číslice, tečka a podtržítko. Změnit ji půjde po registraci v Profilu."
        case .en: return "3–20 characters: letters without accents, digits, dot and underscore. You can change it after registering, in Profile."
        }
    }

    static var chatNicknameSend: String {
        switch lang {
        case .cs: return "Uložit a odeslat zprávu"
        case .en: return "Save and send"
        }
    }

    static var chatHaveAccount: String {
        switch lang {
        case .cs: return "Už máš účet?"
        case .en: return "Already have an account?"
        }
    }

    static var chatSignInLink: String {
        switch lang {
        case .cs: return "Přihlas se"
        case .en: return "Sign in"
        }
    }

    static var chatSignInTitle: String {
        switch lang {
        case .cs: return "Přihlas se"
        case .en: return "Sign in"
        }
    }

    static var chatSignInBody: String {
        switch lang {
        case .cs: return "Máš účet z jiného telefonu? Přihlas se a vrátí se ti přezdívka i statistiky poslechu."
        case .en: return "Have an account from another phone? Sign in to get your nickname and listening stats back."
        }
    }

    static var chatBackToNickname: String {
        switch lang {
        case .cs: return "Zpět k přezdívce"
        case .en: return "Back to the nickname"
        }
    }

    static var chatFirstMessageHint: String {
        switch lang {
        case .cs: return "Při první zprávě si zvolíš přezdívku"
        case .en: return "You'll pick a nickname with your first message"
        }
    }

    static var chatHostBadge: String {
        switch lang {
        case .cs: return "Moderátor"
        case .en: return "Host"
        }
    }

    static var welcomeSlowrider: String {
        switch lang {
        case .cs: return "Vítej mezi Slowriders!"
        case .en: return "Welcome to the Slowriders!"
        }
    }

    static var welcomeSlowriderNickname: String {
        switch lang {
        case .cs: return "Vítej mezi Slowriders! Přezdívku teď můžeš změnit."
        case .en: return "Welcome to the Slowriders! You can change your nickname now."
        }
    }

    static var benefitProfileTitle: String {
        switch lang {
        case .cs: return "Správu profilu"
        case .en: return "Your own profile"
        }
    }

    static var benefitProfileBody: String {
        switch lang {
        case .cs: return "Přezdívku v chatu si změníš, kdy budeš chtít."
        case .en: return "Change your chat nickname whenever you like."
        }
    }

    static var benefitStatsTitle: String {
        switch lang {
        case .cs: return "Statistiky u tebe, ne u telefonu"
        case .en: return "Stats that stay with you"
        }
    }

    static var benefitStatsBody: String {
        switch lang {
        case .cs: return "Poslech se ukládá k účtu, takže ti zůstane i na novém telefonu."
        case .en: return "Listening is saved to your account, so it moves with you to a new phone."
        }
    }

    static var benefitMoreTitle: String {
        switch lang {
        case .cs: return "Víc funkcí"
        case .en: return "More to come"
        }
    }

    static var benefitMoreBody: String {
        switch lang {
        case .cs: return "Další výhody pro Slowridery budou přibývat."
        case .en: return "More perks for Slowriders are on the way."
        }
    }

    static var slowriderTitle: String {
        switch lang {
        case .cs: return "Staň se Slowriderem"
        case .en: return "Become a Slowrider"
        }
    }

    static var slowriderBenefitsIntro: String {
        switch lang {
        case .cs: return "Poslouchat i psát do chatu můžeš bez účtu. Registrace ti k tomu přidá:"
        case .en: return "You can listen and write in the chat without an account. Registering adds:"
        }
    }

    static var slowriderRegister: String {
        switch lang {
        case .cs: return "Zaregistrovat se"
        case .en: return "Register"
        }
    }

    static var slowrideTitle: String {
        switch lang {
        case .cs: return "Tvůj Slowride"
        case .en: return "Your Slowride"
        }
    }

    static var slowrideMember: String {
        switch lang {
        case .cs: return "Slowriderem"
        case .en: return "Slowrider for"
        }
    }

    static var slowrideListened: String {
        switch lang {
        case .cs: return "Odposloucháno"
        case .en: return "Listened"
        }
    }

    static var slowrideChatMessages: String {
        switch lang {
        case .cs: return "Zprávy v chatu"
        case .en: return "Chat messages"
        }
    }

    static var slowrideVoiceMessages: String {
        switch lang {
        case .cs: return "Hlasové vzkazy"
        case .en: return "Voice messages"
        }
    }

    static var slowrideTopShows: String {
        switch lang {
        case .cs: return "Nejoblíbenější pořady"
        case .en: return "Favourite shows"
        }
    }

    static var registerNicknameTitle: String {
        switch lang {
        case .cs: return "Přezdívku změníš s účtem"
        case .en: return "Register to change your nickname"
        }
    }

    static var profileWritingWithoutAccount: String {
        switch lang {
        case .cs: return "Píšeš do chatu bez účtu"
        case .en: return "Writing in the chat without an account"
        }
    }

    static var profileDeleteData: String {
        switch lang {
        case .cs: return "Smazat moje údaje"
        case .en: return "Delete my data"
        }
    }

    static var deleteDataConfirmTitle: String {
        switch lang {
        case .cs: return "Smazat moje údaje?"
        case .en: return "Delete my data?"
        }
    }

    static var deleteDataConfirmBody: String {
        switch lang {
        case .cs: return "Smaže se přezdívka a statistiky poslechu z tohohle telefonu. Zprávy v chatu zůstanou jako „Smazaný účet“."
        case .en: return "Your nickname and the listening stats from this phone will be deleted. Chat messages stay as “Deleted account”."
        }
    }

    static var adminSection: String {
        switch lang {
        case .cs: return "Správa chatu"
        case .en: return "Chat admin"
        }
    }

    static var adminModerators: String {
        switch lang {
        case .cs: return "Moderátoři"
        case .en: return "Hosts"
        }
    }

    static var adminModeratorsBody: String {
        switch lang {
        case .cs: return "Moderátor s propojeným účtem píše v chatu pod jménem z programu se štítkem a může moderovat všechny své pořady."
        case .en: return "A host with a linked account writes under their name from the programme, with a tag, and can moderate all their shows."
        }
    }

    static var adminInviteModerator: String {
        switch lang {
        case .cs: return "Pozvat moderátora"
        case .en: return "Invite a host"
        }
    }

    static var adminLinked: String {
        switch lang {
        case .cs: return "Propojený"
        case .en: return "Linked"
        }
    }

    static var adminNoAccount: String {
        switch lang {
        case .cs: return "Bez účtu"
        case .en: return "No account"
        }
    }

    static var adminInviteBody: String {
        switch lang {
        case .cs: return "Vyber moderátora z programu; propojí se všechny jeho pořady. Odkaz platí 7 dní a jde použít jen jednou."
        case .en: return "Pick a host from the programme; all their shows are linked. The link works for 7 days, once."
        }
    }

    static var adminAlreadyLinked: String {
        switch lang {
        case .cs: return "Už propojený"
        case .en: return "Already linked"
        }
    }

    static var adminGuestHost: String {
        switch lang {
        case .cs: return "Host mimo program"
        case .en: return "Guest host"
        }
    }

    static var adminGuestHostBody: String {
        switch lang {
        case .cs: return "Zadáš jméno, pod kterým bude psát"
        case .en: return "You'll enter the name they write under"
        }
    }

    static var adminGuestNamePlaceholder: String {
        switch lang {
        case .cs: return "Jméno hosta"
        case .en: return "Guest's name"
        }
    }

    static var adminCreateInvite: String {
        switch lang {
        case .cs: return "Vytvořit pozvánku"
        case .en: return "Create an invite"
        }
    }

    static var adminInviteReady: String {
        switch lang {
        case .cs: return "Pozvánka je připravená"
        case .en: return "The invite is ready"
        }
    }

    static var adminShareLink: String {
        switch lang {
        case .cs: return "Sdílet odkaz"
        case .en: return "Share the link"
        }
    }

    static var adminCopyLink: String {
        switch lang {
        case .cs: return "Kopírovat odkaz"
        case .en: return "Copy the link"
        }
    }

    static var adminCopied: String {
        switch lang {
        case .cs: return "Zkopírováno"
        case .en: return "Copied"
        }
    }

    static var adminShows: String {
        switch lang {
        case .cs: return "Pořady"
        case .en: return "Shows"
        }
    }

    static var adminAccount: String {
        switch lang {
        case .cs: return "Účet"
        case .en: return "Account"
        }
    }

    static var adminWritesAs: String {
        switch lang {
        case .cs: return "V chatu píše jako"
        case .en: return "Writes in the chat as"
        }
    }

    static var adminSendNewInvite: String {
        switch lang {
        case .cs: return "Poslat novou pozvánku"
        case .en: return "Send a new invite"
        }
    }

    static var adminUnlink: String {
        switch lang {
        case .cs: return "Odpojit účet"
        case .en: return "Unlink the account"
        }
    }

    static var adminUnlinkNote: String {
        switch lang {
        case .cs: return "Po odpojení bude psát pod svou přezdívkou, bez štítku Moderátor a bez moderování."
        case .en: return "Once unlinked they write under their nickname, without the Host tag or moderation."
        }
    }

    static var adminAdmins: String {
        switch lang {
        case .cs: return "Správci"
        case .en: return "Admins"
        }
    }

    static var adminAdminsBody: String {
        switch lang {
        case .cs: return "Správce moderuje chat pod svou přezdívkou a může zrušit blokaci. Superadmin navíc zve moderátory a spravuje správce."
        case .en: return "An admin moderates under their nickname and can lift blocks. The superadmin also invites hosts and manages admins."
        }
    }

    static var adminYou: String {
        switch lang {
        case .cs: return "ty"
        case .en: return "you"
        }
    }

    static var adminSuperadmin: String {
        switch lang {
        case .cs: return "Superadmin"
        case .en: return "Superadmin"
        }
    }

    static var adminAddAdmin: String {
        switch lang {
        case .cs: return "Přidat správce"
        case .en: return "Add an admin"
        }
    }

    static var adminRemove: String {
        switch lang {
        case .cs: return "Odebrat"
        case .en: return "Remove"
        }
    }

    static var adminAddAdminBody: String {
        switch lang {
        case .cs: return "Správcem může být jen registrovaný Slowrider. Najdi ho podle přezdívky."
        case .en: return "Only a registered Slowrider can be an admin. Find them by nickname."
        }
    }

    static var adminSearchPlaceholder: String {
        switch lang {
        case .cs: return "Přezdívka"
        case .en: return "Nickname"
        }
    }

    static var adminAlreadyAdmin: String {
        switch lang {
        case .cs: return "Už je správce"
        case .en: return "Already an admin"
        }
    }

    static var adminNotRegistered: String {
        switch lang {
        case .cs: return "Píše bez účtu, nejde vybrat"
        case .en: return "Writes without an account, can't be chosen"
        }
    }

    static var adminMakeAdmin: String {
        switch lang {
        case .cs: return "Udělat správcem"
        case .en: return "Make admin"
        }
    }

    static var errorNotSuperadmin: String {
        switch lang {
        case .cs: return "Na tohle potřebuješ roli superadmina."
        case .en: return "This needs the superadmin role."
        }
    }

    static var errorHostInvalid: String {
        switch lang {
        case .cs: return "Tohle jméno moderátora nejde použít."
        case .en: return "This host name can't be used."
        }
    }

    static func slowriderCardBody(_ nickname: String) -> String {
        switch lang {
        case .cs: return "Přezdívka \(nickname) ti zůstane a změníš ji, kdy budeš chtít. Statistiky poslechu se uloží k účtu, takže je nepřijdeš ani s novým telefonem."
        case .en: return "You keep \(nickname) and can change it whenever you like. Your listening stats are saved to the account, so a new phone won't lose them."
        }
    }

    static func registerBody(_ nickname: String) -> String {
        switch lang {
        case .cs: return "Zaregistruj se a \(nickname) ti zůstane i se všemi zprávami. Hned potom ji můžeš změnit, bez čekání."
        case .en: return "Register and keep \(nickname) with all your messages. You can change it right after, no waiting."
        }
    }

    static func slowriderSinceLong(_ date: String) -> String {
        switch lang {
        case .cs: return "Jsi součástí Slowriders od \(date)"
        case .en: return "A Slowrider since \(date)"
        }
    }

    static func slowriderSince(_ date: String) -> String {
        switch lang {
        case .cs: return "Slowrider od \(date)"
        case .en: return "Slowrider since \(date)"
        }
    }

    static func adminInvitePending(_ date: String) -> String {
        switch lang {
        case .cs: return "Pozvánka čeká, platí do \(date)"
        case .en: return "Invite pending, valid until \(date)"
        }
    }

    static func adminInviteReadyBody(_ name: String) -> String {
        switch lang {
        case .cs: return "Pošli odkaz pro \(name), třeba přes WhatsApp. Po otevření se v appce přihlásí a účet se propojí."
        case .en: return "Send the link to \(name), e.g. on WhatsApp. Opening it, they sign in in the app and the account is linked."
        }
    }

    static func adminInviteValidity(_ date: String) -> String {
        switch lang {
        case .cs: return "Platí do \(date) · jen jednou"
        case .en: return "Valid until \(date) · once"
        }
    }

    static func adminInviteShareMessage(_ name: String) -> String {
        switch lang {
        case .cs: return "Pozvánka do chatu Slow Down Rádija pro \(name)"
        case .en: return "Slow Down Rádijo chat invite for \(name)"
        }
    }

    static func adminLinkedOn(_ date: String) -> String {
        switch lang {
        case .cs: return "propojený \(date)"
        case .en: return "linked \(date)"
        }
    }

    static func adminUnlinkConfirm(_ name: String) -> String {
        switch lang {
        case .cs: return "Odpojit účet \(name)?"
        case .en: return "Unlink \(name)?"
        }
    }

    static func adminAdminSince(_ date: String) -> String {
        switch lang {
        case .cs: return "Správce od \(date)"
        case .en: return "Admin since \(date)"
        }
    }

    static func adminRemoveAdmin(_ name: String) -> String {
        switch lang {
        case .cs: return "Odebrat \(name) ze správců?"
        case .en: return "Remove \(name) from admins?"
        }
    }

    /// "den" / "dny" / "dní" after a number (Android: `L10nLogic.slowrideDays`).
    static func slowrideDays(_ count: Int) -> String {
        switch lang {
        case .cs:
            if count == 1 { return "den" }
            if (2...4).contains(count) { return "dny" }
            return "dní"
        case .en:
            return count == 1 ? "day" : "days"
        }
    }
}

extension Show {
    /// The description in the app's language (English falls back to Czech).
    var localizedSummary: String? {
        L10n.isEnglish ? (summaryEn ?? summary) : summary
    }

    /// `name` with its Czech " s <host>" ("with") in English, e.g. "Beat
    /// Brunch with Jaro Cossiga". Shows with a `title` are exactly the ones
    /// whose `name` carries that suffix; the titles themselves stay as the
    /// station names them.
    var localizedName: String {
        guard L10n.isEnglish, title != nil, let range = name.range(of: " s ") else { return name }
        return name.replacingCharacters(in: range, with: " with ")
    }
}
