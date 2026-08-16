import SwiftUI
import WidgetKit

@main
struct SlowDownRadijoWidgetBundle: WidgetBundle {
    var body: some Widget {
        NowPlayingWidget()
    }
}

struct NowPlayingWidget: Widget {
    private let kind = "NowPlayingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NowPlayingProvider()) { entry in
            NowPlayingWidgetView(entry: entry)
        }
        .configurationDisplayName("Právě hraje")
        .description("Aktuální pořad a poslední přehraná skladba na Slow Down Rádiu.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private let previewShow = Show(
    id: "weekend-aftertaste",
    name: "Weekend Aftertaste s Cube Positive",
    start: "20:00",
    end: "22:00",
    imageURL: nil,
    hostName: "Cube Positive",
    hostImageName: "HostDjCubePositive"
)

#Preview("Small", as: .systemSmall) {
    NowPlayingWidget()
} timeline: {
    NowPlayingEntry(date: .now, show: previewShow, latestArtist: "Thundercat", latestTitle: "Them Changes")
}

#Preview("Medium", as: .systemMedium) {
    NowPlayingWidget()
} timeline: {
    NowPlayingEntry(date: .now, show: previewShow, latestArtist: "Thundercat", latestTitle: "Them Changes")
    NowPlayingEntry(date: .now, show: nil, latestArtist: nil, latestTitle: nil)
}
