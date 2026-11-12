import CarPlay
import Combine
import UIKit

/// Slow Down Rádijo on the car's screen (CarPlay Audio): one item, the live
/// stream — the show on air with its photo, and the song when the app
/// vouches for it (`NowPlayingViewModel.verifiedTrack`), with the playing
/// indicator while it plays. Tapping it starts the radio and opens the
/// system's Now Playing screen, which shows and controls the same stream
/// as the lock screen (`RadioPlayerService`'s now-playing info and remote
/// commands).
///
/// Works with the app closed on the phone: the services come from
/// `AppServices`, built here if the tab interface hasn't been.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var liveItem: CPListItem?
    private var cancellables = Set<AnyCancellable>()

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        MainActor.assumeIsolated {
            connect(interfaceController)
        }
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        MainActor.assumeIsolated {
            cancellables.removeAll()
            liveItem = nil
            self.interfaceController = nil
        }
    }

    @MainActor
    private func connect(_ interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        let services = AppServices.shared

        let item = CPListItem(text: L10n.carPlayLive, detailText: nil)
        item.playingIndicatorLocation = .trailing
        item.handler = { [weak self] _, completion in
            MainActor.assumeIsolated {
                if services.player.state != .playing {
                    services.player.play(trigger: .carPlay)
                }
                self?.showNowPlaying()
            }
            completion()
        }
        liveItem = item

        let list = CPListTemplate(title: "Slow Down Rádijo", sections: [CPListSection(items: [item])])
        interfaceController.setRootTemplate(list, animated: false, completion: nil)

        let nowPlaying = services.nowPlaying
        nowPlaying.$currentShow
            .combineLatest(nowPlaying.$verifiedTrack, nowPlaying.$showArtwork, nowPlaying.$playbackState)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] show, track, artwork, state in
                MainActor.assumeIsolated {
                    self?.update(show: show, track: track, artwork: artwork, state: state)
                }
            }
            .store(in: &cancellables)
    }

    @MainActor
    private func update(show: Show?, track: NowPlayingTrack?, artwork: UIImage?, state: PlaybackState) {
        guard let liveItem else { return }
        var detail = show?.displayTitle ?? AppServices.shared.nowPlaying.showName
        if let track {
            detail += " · \(track.artist) – \(track.title)"
        }
        liveItem.setDetailText(detail)
        liveItem.setImage(artwork ?? UIImage(named: "BrandLogo"))
        liveItem.isPlaying = state == .playing
    }

    @MainActor
    private func showNowPlaying() {
        guard let interfaceController else { return }
        let nowPlaying = CPNowPlayingTemplate.shared
        if interfaceController.topTemplate !== nowPlaying {
            interfaceController.pushTemplate(nowPlaying, animated: true, completion: nil)
        }
    }
}
