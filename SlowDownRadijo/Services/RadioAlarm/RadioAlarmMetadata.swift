import Foundation
#if canImport(AlarmKit)
import AlarmKit

/// The radio alarm's AlarmKit metadata — nothing beyond the presentation.
/// Shared with the widget extension, whose Live Activity shows the snooze
/// countdown (`RadioAlarmLiveActivity`).
@available(iOS 26.0, *)
struct RadioAlarmMetadata: AlarmMetadata {}
#endif
