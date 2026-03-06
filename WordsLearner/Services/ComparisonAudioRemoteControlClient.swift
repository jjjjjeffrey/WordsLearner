//
//  ComparisonAudioRemoteControlClient.swift
//  WordsLearner
//

import ComposableArchitecture
import Foundation
#if os(iOS)
import AVFoundation
import MediaPlayer
#endif

@DependencyClient
struct ComparisonAudioRemoteControlClient: Sendable {
    enum Command: Equatable, Sendable {
        case togglePlayPause
        case play
        case pause
        case previous
        case next
    }

    struct Metadata: Equatable, Sendable {
        var title: String
        var subtitle: String
        var durationSeconds: Double?
        var elapsedTimeSeconds: Double
        var isPlaying: Bool
    }

    var commands: @Sendable () async -> AsyncStream<Command> = {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
    var activateAudioSession: @Sendable () async -> Void = {}
    var updateNowPlaying: @Sendable (_ metadata: Metadata) async -> Void = { _ in }
    var clearNowPlaying: @Sendable () async -> Void = {}
}

extension ComparisonAudioRemoteControlClient: DependencyKey {
    static let liveValue: Self = {
        #if os(iOS)
        let controller = IOSRemoteAudioControlCenter.shared
        return Self(
            commands: {
                await controller.commands()
            },
            activateAudioSession: {
                await controller.activateAudioSession()
            },
            updateNowPlaying: { metadata in
                await controller.updateNowPlaying(metadata)
            },
            clearNowPlaying: {
                await controller.clearNowPlaying()
            }
        )
        #else
        return Self()
        #endif
    }()
}

extension ComparisonAudioRemoteControlClient: TestDependencyKey {
    static let previewValue = Self(
        commands: {
            AsyncStream { continuation in
                continuation.finish()
            }
        },
        activateAudioSession: {},
        updateNowPlaying: { _ in },
        clearNowPlaying: {}
    )

    static let testValue = previewValue
}

extension DependencyValues {
    var comparisonAudioRemoteControl: ComparisonAudioRemoteControlClient {
        get { self[ComparisonAudioRemoteControlClient.self] }
        set { self[ComparisonAudioRemoteControlClient.self] = newValue }
    }
}

#if os(iOS)
@MainActor
final class IOSRemoteAudioControlCenter {
    static let shared = IOSRemoteAudioControlCenter()

    private var continuations: [UUID: AsyncStream<ComparisonAudioRemoteControlClient.Command>.Continuation] = [:]
    private var didRegisterCommands = false

    func commands() -> AsyncStream<ComparisonAudioRemoteControlClient.Command> {
        registerRemoteCommandsIfNeeded()
        return AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor [weak self] in
                    self?.continuations.removeValue(forKey: id)
                }
            }
        }
    }

    func activateAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
        } catch {
        }
    }

    func updateNowPlaying(_ metadata: ComparisonAudioRemoteControlClient.Metadata) {
        registerRemoteCommandsIfNeeded()
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: metadata.title,
            MPMediaItemPropertyAlbumTitle: "WordsLearner",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: metadata.elapsedTimeSeconds,
            MPNowPlayingInfoPropertyPlaybackRate: metadata.isPlaying ? 1.0 : 0.0
        ]
        if !metadata.subtitle.isEmpty {
            info[MPMediaItemPropertyArtist] = metadata.subtitle
        }
        if let durationSeconds = metadata.durationSeconds {
            info[MPMediaItemPropertyPlaybackDuration] = durationSeconds
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func registerRemoteCommandsIfNeeded() {
        guard !didRegisterCommands else { return }
        didRegisterCommands = true

        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true

        center.playCommand.addTarget { [weak self] _ in
            self?.yield(.play)
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.yield(.pause)
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.yield(.togglePlayPause)
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.yield(.previous)
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.yield(.next)
            return .success
        }
    }

    private func yield(_ command: ComparisonAudioRemoteControlClient.Command) {
        for continuation in continuations.values {
            continuation.yield(command)
        }
    }
}
#endif
