import Foundation

struct Show: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let start: String
    let end: String
    let imageURL: URL?
    /// Short language tag shown as a small badge next to the show title in
    /// the programme list (e.g. "EN") — `nil` for the vast majority of
    /// shows. Not currently populated in `schedule.json`; the station
    /// hasn't provided per-show language data yet.
    var language: String? = nil
    /// Host name + headshot shown next to ON-AIR on the Home tab for hosted
    /// shows — `nil` for rotation blocks like "The Best of Slow Down" that
    /// don't have a single host.
    var hostName: String? = nil
    /// Name of a bundled `Assets.xcassets` imageset (e.g. "HostDjPufaz"),
    /// not a remote URL — host photos ship inside the app.
    var hostImageName: String? = nil

    private enum CodingKeys: String, CodingKey {
        case id, name, start, end, imageURL, language, hostName, hostImageName
    }
}

struct ScheduleDay: Codable, Identifiable, Hashable {
    let weekday: Int
    let dayName: String
    let shows: [Show]

    var id: Int { weekday }
}

struct Schedule: Codable {
    let days: [ScheduleDay]
}
