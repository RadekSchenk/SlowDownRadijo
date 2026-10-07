import SwiftUI

/// The "Vzkaz" tab: record a short voice message and upload it via
/// `VoiceMessageUploadService` to the `send-voice-message` Supabase Edge
/// Function, which relays it as an email — see `backend/README.md`.
///
/// Styled after the home screen: left-aligned, flat, `Theme.liveRed` as the
/// only action color, and the same circle-button + title row as its hero.
struct MessageView: View {
    @ObservedObject var viewModel: VoiceMessageViewModel
    /// `viewModel` only re-renders this view when its own `@Published`
    /// properties change — it does NOT propagate changes from `recorder`
    /// (a separate `ObservableObject` it merely holds a reference to). Every
    /// per-tick update (elapsed time, waveform levels, playback progress)
    /// lives on `recorder`, so it must be observed here directly.
    @ObservedObject private var recorder: VoiceMessageRecorder
    @ObservedObject private var loc = LocalizationManager.shared
    /// Used by the "Zpět na rádio" button after a successful send.
    var onBack: () -> Void

    private static let successGreen = Color(hex: 0x28C840)

    init(viewModel: VoiceMessageViewModel, onBack: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.recorder = viewModel.recorder
        self.onBack = onBack
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AppHeaderView()
                    .padding(.top, 40)

                content
                    .padding(.top, Theme.Spacing.sm)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, Theme.Spacing.xl)
        }
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

    // MARK: - States

    private var readyView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            header(title: L10n.sendMessage, subtitle: L10n.sendMessageSubtitle)

            privacyNote

            Button(action: viewModel.startRecording) {
                actionRow(title: L10n.startRecording, subtitle: L10n.maxOneMinute) {
                    accentIcon("mic.fill")
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var recordingView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            header(title: L10n.recordingInProgress, subtitle: L10n.tapToStop)

            Button(action: viewModel.stopRecording) {
                actionRow(title: Self.formatted(recorder.elapsed), subtitle: L10n.maxOneMinute) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(.white)
                        .frame(width: 18, height: 18)
                }
            }
            .buttonStyle(.plain)

            WaveformBarsView(levels: recorder.waveformLevels, activeCount: activeSegmentCount)

            textLink(L10n.cancelRecording, systemImage: "xmark", action: viewModel.cancelRecording)
        }
    }

    private var recordedView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                statusBadge(L10n.recorded)
                header(title: L10n.messageRecorded, subtitle: L10n.listenOrRerecord)
            }

            VStack(spacing: 0) {
                ListDivider()
                HStack(spacing: Theme.Spacing.md) {
                    Button(action: viewModel.togglePlayback) {
                        AccentCircle {
                            accentIcon(recorder.isPlaying ? "pause.fill" : "play.fill")
                                .offset(x: recorder.isPlaying ? 0 : 1)
                        }
                    }
                    .buttonStyle(.plain)

                    WaveformBarsView(levels: recorder.waveformLevels, activeCount: playbackActiveSegmentCount)

                    Text(Self.formatted(viewModel.recordingDuration))
                        .font(Theme.Typography.Manrope.bold(size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.mutedText)
                        .monospacedDigit()
                }
                .padding(.vertical, 20)
                ListDivider()
            }

            VStack(spacing: 12) {
                PrimaryActionButton(title: L10n.sendToRadio, systemImage: "paperplane.fill", action: viewModel.submit)
                SecondaryActionButton(title: L10n.recordAgain, action: viewModel.retry)
            }
        }
    }

    private var sendingView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            header(title: L10n.sendingTitle, subtitle: L10n.sendingSubtitle)

            actionRow(title: L10n.sendingButtonLabel, subtitle: nil) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            }
        }
    }

    private var sentView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            // Library P10 — success check.
            SuccessCheck()

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                statusBadge(L10n.sentBadge)
                header(title: L10n.messageSent, subtitle: L10n.thankYouForMessage)
            }

            VStack(spacing: 12) {
                PrimaryActionButton(title: L10n.backToRadio, action: onBack)
                SecondaryActionButton(title: L10n.recordAnotherMessage, action: viewModel.recordAnother)
            }
        }
    }

    // MARK: - Building blocks

    /// Section-heading scale from the home screen ("Pořady"), with the same
    /// muted subtitle as "Pořad končí za…".
    private func header(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.Typography.Manrope.extraBold(size: 24, relativeTo: .title2))
                .foregroundStyle(Theme.textPrimary)
            Text(subtitle)
                .font(Theme.Typography.Manrope.semibold(size: 16, relativeTo: .subheadline))
                .foregroundStyle(Theme.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Mirrors the home hero's play button + show title row.
    private func actionRow<Icon: View>(title: String, subtitle: String?, @ViewBuilder icon: () -> Icon) -> some View {
        let iconView = icon()
        return HStack(spacing: Theme.Spacing.md) {
            AccentCircle { iconView }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.Typography.Manrope.extraBold(size: 22, relativeTo: .title2))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.Manrope.semibold(size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Theme.mutedText)
                }
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private func accentIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.white)
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "info.circle")
                .font(.system(size: 14, weight: .semibold))
            Text(L10n.privacyNote)
                .font(Theme.Typography.Manrope.medium(size: 13, relativeTo: .footnote))
        }
        .foregroundStyle(Theme.mutedText)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.hairline(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// Same geometry as the home screen's `OnAirBadge`, in success green.
    private func statusBadge(_ label: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Self.successGreen)
                .frame(width: 10, height: 10)
            Text(label)
                .font(Theme.Typography.Manrope.extraBold(size: 14))
                .foregroundStyle(Self.successGreen)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Self.successGreen.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    /// Same treatment as the home screen's "Nastavit časovač vypnutí" link.
    private func textLink(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(Theme.Typography.Manrope.bold(size: 16, relativeTo: .footnote))
            }
            .foregroundStyle(Theme.textPrimary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var activeSegmentCount: Int {
        let progress = min(recorder.elapsed / VoiceMessageRecorder.maxDuration, 1)
        return min(
            Int(progress * Double(VoiceMessageRecorder.waveformSegmentCount)) + 1,
            VoiceMessageRecorder.waveformSegmentCount
        )
    }

    private var playbackActiveSegmentCount: Int {
        Int(recorder.playbackProgress * Double(VoiceMessageRecorder.waveformSegmentCount))
    }

    private static func formatted(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
