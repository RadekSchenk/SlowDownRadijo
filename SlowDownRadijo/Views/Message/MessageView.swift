import SwiftUI

/// The "Vzkaz" tab: record a short voice message and upload it via
/// `VoiceMessageUploadService` to the `send-voice-message` Supabase Edge
/// Function, which relays it as an email — see `backend/README.md`.
struct MessageView: View {
    @ObservedObject var viewModel: VoiceMessageViewModel
    /// `viewModel` only re-renders this view when its own `@Published`
    /// properties change — it does NOT propagate changes from `recorder`
    /// (a separate `ObservableObject` it merely holds a reference to). Every
    /// per-tick update (elapsed time, waveform levels, playback progress)
    /// lives on `recorder`, so it must be observed here directly, or the UI
    /// only happens to refresh when something else forces a re-render.
    @ObservedObject private var recorder: VoiceMessageRecorder
    @ObservedObject private var loc = LocalizationManager.shared
    /// Still used by the "Zpět na rádio" button in `sentView` after a
    /// successful send — the header itself no longer has a back affordance
    /// (see `AppHeaderView` below), since Vzkaz is a primary tab now, not a
    /// pushed/dismissible screen.
    var onBack: () -> Void

    init(viewModel: VoiceMessageViewModel, onBack: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.recorder = viewModel.recorder
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 0) {
            AppHeaderView()
                // Matches the home screen's header offset exactly (see
                // `HomeView.heroSection`) — fixed 40pt from the true top
                // edge, not the system safe-area inset.
                .padding(.top, 40)

            Spacer(minLength: 0)

            content

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .top)
        .background(Theme.background.ignoresSafeArea())
        .alert(L10n.micUnavailableTitle, isPresented: $viewModel.permissionDeniedAlert) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(L10n.micUnavailableMessage)
        }
        .alert(L10n.uploadFailedTitle, isPresented: $viewModel.uploadFailedAlert) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(L10n.uploadFailedMessage)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .ready:
            readyView
        case .recording:
            recordingView
        case .recorded:
            recordedView
        case .sending:
            sendingView
        case .sent:
            sentView
        }
    }

    // MARK: - Ready

    private var readyView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            VStack(spacing: 10) {
                Text(L10n.sendMessage)
                    .font(Theme.Typography.Manrope.extraBold(size: 28, relativeTo: .title))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(L10n.sendMessageSubtitle)
                    .font(Theme.Typography.Manrope.medium(size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Theme.lavender)
                    .multilineTextAlignment(.center)
            }

            privacyReassuranceCallout

            Button(action: viewModel.startRecording) {
                RecordingVisualizerView(
                    primaryGlow: Theme.sunOrange,
                    secondaryGlow: Theme.brandPurple,
                    isPulsing: false,
                    ringRadii: [80, 105, 130, 155, 180]
                ) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: 0xF0814F), Theme.sunOrange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                        Image(systemName: "mic.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: Theme.sunOrange.opacity(0.3), radius: 12, y: 12)
                }
            }
            .buttonStyle(.plain)

            VStack(spacing: 6) {
                Text(L10n.startRecording)
                    .font(Theme.Typography.Manrope.bold(size: 18, relativeTo: .headline))
                    .foregroundStyle(Theme.textPrimary)
                Text(L10n.maxOneMinute)
                    .font(Theme.Typography.Manrope.medium(size: 12, relativeTo: .caption))
                    .foregroundStyle(Theme.gold)
            }

            HStack(spacing: 10) {
                Image(systemName: "paperplane.fill")
                Text(L10n.sendToRadio)
            }
            .font(Theme.Typography.Manrope.bold(size: 15, relativeTo: .subheadline))
            .foregroundStyle(.white.opacity(0.25))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color(hex: 0x231B44), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private var privacyReassuranceCallout: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "info")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.gold)
                .frame(width: 24, height: 24)
                .background(Theme.gold.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(L10n.privacyNote)
                .font(Theme.Typography.Manrope.medium(size: 12, relativeTo: .caption))
                .foregroundStyle(Theme.lavender)
        }
        .padding(12)
        .background(Theme.brandPurple.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.lavender.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Recording

    private var recordingView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            VStack(spacing: 10) {
                Text(L10n.recordingInProgress)
                    .font(Theme.Typography.Manrope.extraBold(size: 28, relativeTo: .title))
                    .foregroundStyle(Theme.textPrimary)
                Text(L10n.tapToStop)
                    .font(Theme.Typography.Manrope.medium(size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Theme.lavender)
            }

            Button(action: viewModel.stopRecording) {
                RecordingVisualizerView(
                    primaryGlow: Theme.sunOrange,
                    secondaryGlow: Theme.brandPurple,
                    isPulsing: true
                ) {
                    ZStack {
                        Circle().fill(Theme.sunOrange).frame(width: 110, height: 110)
                        RoundedRectangle(cornerRadius: 6).fill(.white).frame(width: 28, height: 28)
                    }
                    .shadow(color: Theme.sunOrange.opacity(0.5), radius: 10, y: 8)
                }
            }
            .buttonStyle(.plain)

            VStack(spacing: Theme.Spacing.md) {
                VStack(spacing: 4) {
                    Text(Self.formatted(viewModel.recorder.elapsed))
                        .font(Theme.Typography.Manrope.extraBold(size: 36, relativeTo: .largeTitle))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.default, value: viewModel.recorder.elapsed)
                    Text(L10n.maxOneMinute)
                        .font(Theme.Typography.Manrope.bold(size: 11, relativeTo: .caption2))
                        .foregroundStyle(Theme.gold)
                }

                WaveformBarsView(levels: viewModel.recorder.waveformLevels, activeCount: activeSegmentCount)
            }

            Button(L10n.cancelRecording, action: viewModel.cancelRecording)
                .font(Theme.Typography.Manrope.bold(size: 15, relativeTo: .subheadline))
                .foregroundStyle(Theme.lavender)
                .buttonStyle(.plain)
        }
    }

    private var activeSegmentCount: Int {
        let progress = min(viewModel.recorder.elapsed / VoiceMessageRecorder.maxDuration, 1)
        return min(
            Int(progress * Double(VoiceMessageRecorder.waveformSegmentCount)) + 1,
            VoiceMessageRecorder.waveformSegmentCount
        )
    }

    // MARK: - Recorded

    private var recordedView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: 0x28C840)).frame(width: 8, height: 8)
                    Text(L10n.recorded)
                        .font(Theme.Typography.Manrope.bold(size: 12, relativeTo: .caption))
                        .foregroundStyle(Color(hex: 0x28C840))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(hex: 0x28C840).opacity(0.13), in: Capsule())

                Text(L10n.messageRecorded)
                    .font(Theme.Typography.Manrope.extraBold(size: 28, relativeTo: .title))
                    .foregroundStyle(Theme.textPrimary)
                Text(L10n.listenOrRerecord)
                    .font(Theme.Typography.Manrope.medium(size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Theme.lavender)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: Theme.Spacing.md) {
                Button(action: viewModel.togglePlayback) {
                    Circle()
                        .fill(Theme.sunOrange)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: viewModel.recorder.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                        )
                }
                .buttonStyle(.plain)

                WaveformBarsView(levels: viewModel.recorder.waveformLevels, activeCount: playbackActiveSegmentCount)

                Text(Self.formatted(viewModel.recordingDuration))
                    .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .padding(Theme.Spacing.lg)
            .background(Color(hex: 0x231B44), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    .allowsHitTesting(false)
            )

            VStack(spacing: Theme.Spacing.md) {
                Button(action: viewModel.submit) {
                    HStack(spacing: 10) {
                        Image(systemName: "paperplane.fill")
                        Text(L10n.sendToRadio)
                    }
                    .font(Theme.Typography.Manrope.bold(size: 15, relativeTo: .subheadline))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Theme.sunOrange, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: viewModel.retry) {
                    Text(L10n.recordAgain)
                        .font(Theme.Typography.Manrope.bold(size: 15, relativeTo: .subheadline))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .strokeBorder(Theme.lavender, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var playbackActiveSegmentCount: Int {
        Int(viewModel.recorder.playbackProgress * Double(VoiceMessageRecorder.waveformSegmentCount))
    }

    // MARK: - Sending

    private var sendingView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            VStack(spacing: 10) {
                Text(L10n.sendingTitle)
                    .font(Theme.Typography.Manrope.extraBold(size: 28, relativeTo: .title))
                    .foregroundStyle(Theme.textPrimary)
                Text(L10n.sendingSubtitle)
                    .font(Theme.Typography.Manrope.medium(size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Theme.lavender)
                    .multilineTextAlignment(.center)
            }

            RecordingVisualizerView(
                primaryGlow: Theme.brandPurple,
                secondaryGlow: Theme.sunOrange,
                isPulsing: false,
                ringRadii: []
            ) {
                ZStack {
                    UploadSpinnerRing()
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "paperplane.fill")
                Text(L10n.sendingButtonLabel)
            }
            .font(Theme.Typography.Manrope.bold(size: 15, relativeTo: .subheadline))
            .foregroundStyle(.white.opacity(0.25))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color(hex: 0x231B44), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
    }

    // MARK: - Sent

    private var sentView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            VStack(spacing: 10) {
                Text(L10n.messageSent)
                    .font(Theme.Typography.Manrope.extraBold(size: 28, relativeTo: .title))
                    .foregroundStyle(Theme.textPrimary)
                Text(L10n.thankYouForMessage)
                    .font(Theme.Typography.Manrope.medium(size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Theme.lavender)
                    .multilineTextAlignment(.center)
            }

            RecordingVisualizerView(
                primaryGlow: Color(hex: 0x28C840),
                secondaryGlow: Theme.sunOrange,
                isPulsing: false
            ) {
                ZStack {
                    Circle().fill(Theme.sunOrange).frame(width: 110, height: 110)
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                }
                .shadow(color: Theme.sunOrange.opacity(0.3), radius: 12, y: 12)
            }

            VStack(spacing: Theme.Spacing.md) {
                Button(action: onBack) {
                    Text(L10n.backToRadio)
                        .font(Theme.Typography.Manrope.bold(size: 15, relativeTo: .subheadline))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Theme.sunOrange, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: viewModel.recordAnother) {
                    Text(L10n.recordAnotherMessage)
                        .font(Theme.Typography.Manrope.bold(size: 15, relativeTo: .subheadline))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .strokeBorder(Theme.lavender, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Shared bits

    private static func formatted(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
