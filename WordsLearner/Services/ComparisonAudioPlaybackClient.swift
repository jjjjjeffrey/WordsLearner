//
//  ComparisonAudioPlaybackClient.swift
//  WordsLearner
//

import AVFoundation
import ComposableArchitecture
import Foundation

@DependencyClient
struct ComparisonAudioPlaybackClient: Sendable {
    struct Snapshot: Equatable, Sendable {
        var sourceID: String?
        var isPlaying: Bool
        var currentTimeSeconds: Double
    }

    enum Event: Equatable, Sendable {
        case started(sourceID: String, currentTimeSeconds: Double)
        case progressUpdated(sourceID: String, currentTimeSeconds: Double)
        case paused(sourceID: String, currentTimeSeconds: Double)
        case stopped
        case finished(sourceID: String)
    }

    var events: @Sendable () async -> AsyncStream<Event> = {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
    var snapshot: @Sendable () async -> Snapshot = { .init(sourceID: nil, isPlaying: false, currentTimeSeconds: 0) }
    var play: @Sendable (_ data: Data, _ sourceID: String, _ startTimeSeconds: Double) async -> Void = { _, _, _ in }
    var pause: @Sendable () async -> Void = {}
    var stop: @Sendable (_ clearPosition: Bool) async -> Void = { _ in }
    var seek: @Sendable (_ timeSeconds: Double) async -> Void = { _ in }
}

extension ComparisonAudioPlaybackClient: DependencyKey {
    static let liveValue: Self = {
        let player = ComparisonResponseAudioPlayer.shared
        return Self(
            events: {
                await player.events()
            },
            snapshot: {
                await player.snapshot
            },
            play: { data, sourceID, startTimeSeconds in
                await player.play(data: data, sourceID: sourceID, startTimeSeconds: startTimeSeconds)
            },
            pause: {
                await player.pause()
            },
            stop: { clearPosition in
                await player.stop(clearPosition: clearPosition)
            },
            seek: { timeSeconds in
                await player.seek(to: timeSeconds)
            }
        )
    }()

    static let previewValue = Self(
        events: {
            AsyncStream { continuation in continuation.finish() }
        },
        snapshot: { Snapshot(sourceID: nil, isPlaying: false, currentTimeSeconds: 0) },
        play: { _, _, _ in },
        pause: {},
        stop: { _ in },
        seek: { _ in }
    )

    static let testValue = previewValue
}

extension DependencyValues {
    var comparisonAudioPlayback: ComparisonAudioPlaybackClient {
        get { self[ComparisonAudioPlaybackClient.self] }
        set { self[ComparisonAudioPlaybackClient.self] = newValue }
    }
}

@MainActor
final class ComparisonResponseAudioPlayer: NSObject, AVAudioPlayerDelegate {
    static let shared = ComparisonResponseAudioPlayer()

    private(set) var snapshot = ComparisonAudioPlaybackClient.Snapshot(
        sourceID: nil,
        isPlaying: false,
        currentTimeSeconds: 0
    )

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?
    private var completionSourceID: String?
    private(set) var loadedSourceFingerprint: Int?
    private var eventContinuations: [UUID: AsyncStream<ComparisonAudioPlaybackClient.Event>.Continuation] = [:]

    func events() -> AsyncStream<ComparisonAudioPlaybackClient.Event> {
        AsyncStream { continuation in
            let id = UUID()
            eventContinuations[id] = continuation
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor [weak self] in
                    self?.eventContinuations.removeValue(forKey: id)
                }
            }
        }
    }

    func play(data: Data, sourceID: String, startTimeSeconds: Double) {
        let fingerprint = data.hashValue
        if let player, snapshot.sourceID == sourceID, loadedSourceFingerprint == fingerprint {
            completionSourceID = sourceID
            seek(to: startTimeSeconds)
            if !player.isPlaying {
                snapshot.isPlaying = true
                player.play()
                startProgressTimer()
            }
            yield(.started(sourceID: sourceID, currentTimeSeconds: snapshot.currentTimeSeconds))
            return
        }

        stop(clearPosition: true)

        do {
            let createdPlayer = try AVAudioPlayer(data: data)
            createdPlayer.delegate = self
            player = createdPlayer
            completionSourceID = sourceID
            loadedSourceFingerprint = fingerprint
            snapshot.sourceID = sourceID
            seek(to: startTimeSeconds)
            snapshot.isPlaying = true
            createdPlayer.prepareToPlay()
            createdPlayer.play()
            startProgressTimer()
            yield(.started(sourceID: sourceID, currentTimeSeconds: snapshot.currentTimeSeconds))
        } catch {
            stop(clearPosition: true)
        }
    }

    func play(data: Data, completion: @escaping () -> Void) {
        completionSourceID = "__legacy__"
        play(data: data, sourceID: "__legacy__", startTimeSeconds: snapshot.currentTimeSeconds)
    }

    func pause() {
        player?.pause()
        progressTimer?.invalidate()
        progressTimer = nil
        if let player {
            snapshot.currentTimeSeconds = player.currentTime
        }
        snapshot.isPlaying = false
        if let sourceID = snapshot.sourceID {
            yield(.paused(sourceID: sourceID, currentTimeSeconds: snapshot.currentTimeSeconds))
        }
    }

    func stop(clearPosition: Bool) {
        progressTimer?.invalidate()
        progressTimer = nil
        player?.stop()
        snapshot.isPlaying = false

        if clearPosition {
            player = nil
            completionSourceID = nil
            loadedSourceFingerprint = nil
            snapshot.sourceID = nil
            snapshot.currentTimeSeconds = 0
        } else if let player {
            snapshot.currentTimeSeconds = player.currentTime
        }

        yield(.stopped)
    }

    func seek(to timeSeconds: Double) {
        guard let player else {
            snapshot.currentTimeSeconds = max(0, timeSeconds)
            return
        }
        let clampedTime = max(0, min(timeSeconds, player.duration))
        player.currentTime = clampedTime
        snapshot.currentTimeSeconds = clampedTime
        if let sourceID = snapshot.sourceID {
            yield(.progressUpdated(sourceID: sourceID, currentTimeSeconds: clampedTime))
        }
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let player = self.player, let sourceID = self.snapshot.sourceID else { return }
                self.snapshot.currentTimeSeconds = player.currentTime
                self.yield(.progressUpdated(sourceID: sourceID, currentTimeSeconds: player.currentTime))
            }
        }
    }

    private func yield(_ event: ComparisonAudioPlaybackClient.Event) {
        for continuation in eventContinuations.values {
            continuation.yield(event)
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            let sourceID = completionSourceID
            stop(clearPosition: true)
            if flag, let sourceID {
                yield(.finished(sourceID: sourceID))
            }
        }
    }
}
