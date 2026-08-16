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

    static var spotify: String { "Spotify" }
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

    static var tabStatistics: String {
        switch lang {
        case .cs: return "Statistiky"
        case .en: return "Statistics"
        }
    }

    // MARK: - Statistics

    static var statisticsIntro: String {
        switch lang {
        case .cs: return "Data o vysílání, sbíraná na pozadí nezávisle na tom, kdy appku někdo poslouchá."
        case .en: return "Broadcast data, collected in the background independent of whether anyone's listening in the app."
        }
    }

    static var statisticsLoadFailed: String {
        switch lang {
        case .cs: return "Statistiky se nepodařilo načíst"
        case .en: return "Couldn't load statistics"
        }
    }

    static var diversityTitle: String {
        switch lang {
        case .cs: return "Šíře repertoáru"
        case .en: return "Repertoire diversity"
        }
    }

    static var diversitySubtitle: String {
        switch lang {
        case .cs: return "Unikátní interpreti za posledních 12 týdnů"
        case .en: return "Unique artists over the last 12 weeks"
        }
    }

    static var diversityLegendNew: String {
        switch lang {
        case .cs: return "Poprvé"
        case .en: return "First time"
        }
    }

    static var diversityLegendReturning: String {
        switch lang {
        case .cs: return "Už hráli"
        case .en: return "Played before"
        }
    }

    static var collectingDataNote: String {
        switch lang {
        case .cs: return "Sbírání dat právě začalo — čím déle appka poběží, tím zajímavější to bude."
        case .en: return "Data collection just started — the longer this runs, the more interesting it gets."
        }
    }

    static var repetitionTitle: String {
        switch lang {
        case .cs: return "Míra repetice"
        case .en: return "Repetition rate"
        }
    }

    static func repetitionDescription(_ percent: String) -> String {
        switch lang {
        case .cs: return "jen \(percent) % skladeb se za posledních 30 dní opakovalo"
        case .en: return "only \(percent)% of tracks repeated in the last 30 days"
        }
    }

    static var firstPlaysTitle: String {
        switch lang {
        case .cs: return "Poprvé na rádiu"
        case .en: return "First time on air"
        }
    }

    /// Two sentences: the weekly debut count, then the running total, so
    /// the weekly number has some scale to be read against ("12 new this
    /// week" means more once you know "340 total so far"). Czech needs
    /// three grammatical forms for the weekly count (1 / 2–4 / 5+, with the
    /// verb agreeing accordingly) — English just needs singular/plural. The
    /// total uses the same invariant existential construction regardless of
    /// count ("zaznělo už X skladeb"/"have aired"), since in practice it's
    /// essentially always well past the point where that distinction matters.
    static func firstPlaysWeekHeadline(count: Int, totalTracks: Int) -> String {
        switch lang {
        case .cs:
            let weekPhrase: String
            switch count {
            case 1: weekPhrase = "skladba tento týden hrála na rádiu úplně poprvé"
            case 2...4: weekPhrase = "skladby tento týden hrály na rádiu úplně poprvé"
            default: weekPhrase = "skladeb tento týden hrálo na rádiu úplně poprvé"
            }
            return "\(count) \(weekPhrase). Celkem v éteru zaznělo už \(totalTracks) skladeb."
        case .en:
            let weekNoun = count == 1 ? "track" : "tracks"
            let totalNoun = totalTracks == 1 ? "track" : "tracks"
            return "\(count) \(weekNoun) played on air for the very first time this week. "
                + "\(totalTracks) \(totalNoun) have aired in total so far."
        }
    }

    static var firstPlaysWeekEmpty: String {
        switch lang {
        case .cs: return "Tento týden zatím nic nového."
        case .en: return "Nothing new yet this week."
        }
    }

    // MARK: - Home

    static var onAir: String { "ON-AIR" }

    static var now: String {
        switch lang {
        case .cs: return "Nyní"
        case .en: return "Now"
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

    static func next(_ showName: String) -> String {
        switch lang {
        case .cs: return "Následuje: \(showName)"
        case .en: return "Next up: \(showName)"
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

    static var hubSettingsRow: String {
        switch lang {
        case .cs: return "Nastavení"
        case .en: return "Settings"
        }
    }

    static var hubSettingsRowSubtitle: String {
        switch lang {
        case .cs: return "Vzhled, jazyk"
        case .en: return "Appearance, language"
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

    static var hubNotificationsRow: String {
        switch lang {
        case .cs: return "Notifikace"
        case .en: return "Notifications"
        }
    }

    static var hubNotificationsRowSubtitle: String {
        switch lang {
        case .cs: return "Upozornění na nové novinky"
        case .en: return "Alerts for new posts"
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

    static var hubSocialTitle: String {
        switch lang {
        case .cs: return "Sledujte nás"
        case .en: return "Follow us"
        }
    }

    // MARK: - Favorites

    static var hubFavoritesRow: String {
        switch lang {
        case .cs: return "Oblíbené skladby"
        case .en: return "Favorite tracks"
        }
    }

    static var hubFavoritesRowSubtitle: String {
        switch lang {
        case .cs: return "Skladby, které sis uložil"
        case .en: return "Tracks you've saved"
        }
    }

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
        case .cs: return "Kdykoliv klepneš na srdce, skladba se uloží do Oblíbených skladeb v menu, kde se k ní můžeš kdykoliv vrátit."
        case .en: return "Whenever you tap the heart, the track is saved to Favorite tracks in the menu, where you can come back to it anytime."
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

    static var settingsAppearanceTitle: String {
        switch lang {
        case .cs: return "Vzhled"
        case .en: return "Appearance"
        }
    }

    static var settingsAppearanceSystem: String {
        switch lang {
        case .cs: return "Systém"
        case .en: return "System"
        }
    }

    static var settingsAppearanceLight: String {
        switch lang {
        case .cs: return "Světlý režim"
        case .en: return "Light mode"
        }
    }

    static var settingsAppearanceDark: String {
        switch lang {
        case .cs: return "Tmavý režim"
        case .en: return "Dark mode"
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

    static var notificationsTitle: String {
        switch lang {
        case .cs: return "Notifikace"
        case .en: return "Notifications"
        }
    }

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
