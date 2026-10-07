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

    // MARK: - Shared

    static var tagline: String {
        switch lang {
        case .cs: return "Tohle algoritmus neumí"
        case .en: return "This, algorithms can't do"
        }
    }

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

    /// Kicker line above the host's name in `HostBadge`.
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
        case .cs: return "Stejný týden · \(total)"
        case .en: return "Same week · \(total)"
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
