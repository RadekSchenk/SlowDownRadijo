import ActivityKit
import SwiftUI
import WidgetKit
#if canImport(AlarmKit)
import AlarmKit

/// The radio alarm on the Lock Screen and in the Dynamic Island while it's
/// snoozed (AlarmKit shows its countdown through this Live Activity; the
/// ringing alert itself is the system's). Figma "Budík s rádiem", B6.
@available(iOS 26.0, *)
struct RadioAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<RadioAlarmMetadata>.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "sunrise.fill")
                    .font(.title2)
                    .foregroundStyle(Color(red: 0.95, green: 0.76, blue: 0.36))
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.presentation.countdown?.title ?? context.attributes.presentation.alert.title)
                        .font(.headline)
                    Text("Slow Down Rádijo")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                countdown(context.state)
                    .font(.system(size: 34, weight: .bold).monospacedDigit())
            }
            .padding(16)
            .activityBackgroundTint(Color(red: 0.07, green: 0.05, blue: 0.15))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "sunrise.fill").foregroundStyle(Color(red: 0.95, green: 0.76, blue: 0.36))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context.state).font(.title2.monospacedDigit().bold())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.presentation.countdown?.title ?? context.attributes.presentation.alert.title)
                }
            } compactLeading: {
                Image(systemName: "sunrise.fill").foregroundStyle(Color(red: 0.95, green: 0.76, blue: 0.36))
            } compactTrailing: {
                countdown(context.state).monospacedDigit().frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "sunrise.fill")
            }
        }
    }

    @ViewBuilder
    private func countdown(_ state: AlarmPresentationState) -> some View {
        switch state.mode {
        case .countdown(let countdown):
            Text(timerInterval: Date.now...countdown.fireDate, countsDown: true)
        case .paused(let paused):
            let left = max(0, paused.totalCountdownDuration - paused.previouslyElapsedDuration)
            Text(Duration.seconds(left).formatted(.time(pattern: .minuteSecond)))
        case .alert(let alert):
            Text(String(format: "%d:%02d", alert.time.hour, alert.time.minute))
        @unknown default:
            EmptyView()
        }
    }
}
#endif
