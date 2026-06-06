//
//  SetupVideoView.swift
//  Braver Search
//

import AVFoundation
import SwiftUI
import UIKit

private enum SetupVideoAsset {
    static let name = "braver_search_setup"
    static let fileExtension = "mp4"
    static let previewHeight: CGFloat = 560
    static let phoneAspectRatio: CGFloat = 976.0 / 2122.0
}

private enum SetupVideoAnalyticsEvents {
    static let autoplayStarted = "setup_video_autoplay_started"
    static let playTapped = "setup_video_play_tapped"
    static let pauseTapped = "setup_video_pause_tapped"
    static let restartTapped = "setup_video_restart_tapped"
}

struct SetupVideoView: View {
    @StateObject private var playback = SetupVideoPlayback()
    @State private var hasTrackedAutoplay = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Watch Setup")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                Text("A quick walkthrough of the exact Safari switches to flip.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(IOSTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let player = playback.player {
                videoPlayer(player)
            } else {
                missingVideoFallback
            }
        }
    }

    private func videoPlayer(_ player: AVPlayer) -> some View {
        SetupPhoneVideoFrame {
            SetupVideoLayer(player: player)
        } controls: {
            videoControls
        }
        .onAppear {
            playback.play()
            trackAutoplayOnce()
        }
        .onDisappear {
            playback.pause()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Braver Search Safari setup video")
    }

    private var videoControls: some View {
        HStack(spacing: 10) {
            Button(action: togglePlayback) {
                Label(playback.isPlaying ? "Pause" : "Play", systemImage: playback.isPlaying ? "pause.fill" : "play.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)

            Button(action: restartPlayback) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Restart setup video")

            Spacer(minLength: 0)
        }
    }

    private var missingVideoFallback: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.black.opacity(0.4))
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 26, weight: .semibold))
                    Text("Setup video unavailable")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(IOSTheme.secondaryText)
            )
    }

    private func togglePlayback() {
        if playback.isPlaying {
            playback.pause()
            trackVideoEvent(SetupVideoAnalyticsEvents.pauseTapped)
        } else {
            playback.play()
            trackVideoEvent(SetupVideoAnalyticsEvents.playTapped)
        }
    }

    private func restartPlayback() {
        playback.restart()
        trackVideoEvent(SetupVideoAnalyticsEvents.restartTapped)
    }

    private func trackAutoplayOnce() {
        guard !hasTrackedAutoplay else {
            return
        }

        hasTrackedAutoplay = true
        trackVideoEvent(SetupVideoAnalyticsEvents.autoplayStarted)
    }

    private func trackVideoEvent(_ event: String) {
        IOSAppAnalytics.track(
            event,
            properties: [
                "surface": "ios_app",
                "video": SetupVideoAsset.name,
            ]
        )
    }
}

private struct SetupVideoLayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private final class PlayerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

private struct SetupPhoneVideoFrame<VideoContent: View, Controls: View>: View {
    let videoContent: VideoContent
    let controls: Controls

    init(
        @ViewBuilder videoContent: () -> VideoContent,
        @ViewBuilder controls: () -> Controls
    ) {
        self.videoContent = videoContent()
        self.controls = controls()
    }

    var body: some View {
        GeometryReader { geometry in
            let phoneHeight = min(
                SetupVideoAsset.previewHeight,
                geometry.size.width * 0.9 / SetupVideoAsset.phoneAspectRatio
            )
            let phoneWidth = phoneHeight * SetupVideoAsset.phoneAspectRatio

            ZStack(alignment: .bottom) {
                phoneShell
                    .frame(width: phoneWidth, height: phoneHeight)

                videoContent
                    .frame(width: phoneWidth - 18, height: phoneHeight - 18)
                    .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
                    .padding(9)

                VStack {
                    Capsule()
                        .fill(Color.black)
                        .frame(width: 72, height: 22)
                        .padding(.top, 17)

                    Spacer(minLength: 0)
                }
                .frame(width: phoneWidth, height: phoneHeight)
                .allowsHitTesting(false)

                controls
                    .frame(width: phoneWidth - 36, alignment: .leading)
                    .padding(.bottom, 18)
            }
            .frame(width: phoneWidth, height: phoneHeight)
            .overlay {
                sideButtons(width: phoneWidth, height: phoneHeight)
            }
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .frame(height: SetupVideoAsset.previewHeight)
    }

    private var phoneShell: some View {
        RoundedRectangle(cornerRadius: 48, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.02, blue: 0.025),
                        Color(red: 0.12, green: 0.12, blue: 0.14),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 48, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.36), radius: 18, y: 12)
    }

    private func sideButtons(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.white.opacity(0.18))
                .frame(width: 3, height: 54)
                .offset(x: (-width / 2) - 2, y: -height * 0.2)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.white.opacity(0.18))
                .frame(width: 3, height: 70)
                .offset(x: (width / 2) + 2, y: -height * 0.08)
        }
        .allowsHitTesting(false)
    }
}

private final class SetupVideoPlayback: ObservableObject {
    let player: AVPlayer?

    @Published private(set) var isPlaying = false

    private var endObserver: NSObjectProtocol?
    private var timeControlObserver: NSKeyValueObservation?

    init() {
        guard let url = Bundle.main.url(
            forResource: SetupVideoAsset.name,
            withExtension: SetupVideoAsset.fileExtension
        ) else {
            player = nil
            return
        }

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.actionAtItemEnd = .none
        player.isMuted = true
        self.player = player

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.restart()
        }

        timeControlObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                self?.isPlaying = player.timeControlStatus == .playing
            }
        }
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    func play() {
        player?.play()
        isPlaying = player != nil
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func restart() {
        player?.seek(to: .zero)
        play()
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        SetupVideoView()
            .padding()
    }
    .preferredColorScheme(.dark)
}
