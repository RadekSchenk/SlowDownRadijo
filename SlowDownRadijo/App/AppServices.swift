import Foundation

/// The services the phone's screens and CarPlay share: one stream player,
/// one programme, one "what's on now". Built on first use — by the tab
/// interface (`RootTabView`) or, when the car connects with the app not
/// open on the phone, by `CarPlaySceneDelegate` — and never twice: a
/// second `RadioPlayerService` re-activated the audio session and added
/// remote-command targets, a second `ICYMetadataService` was never freed.
@MainActor
final class AppServices {
    static let shared = AppServices()

    lazy var schedule = ScheduleStore()
    lazy var player = RadioPlayerService()
    lazy var metadata = ICYMetadataService()
    lazy var historyStore = PlayHistoryStore()
    lazy var nowPlaying = NowPlayingViewModel(
        player: player,
        metadataService: metadata,
        scheduleStore: schedule,
        historyStore: historyStore
    )

    private init() {}
}
