//
//  MultimodalLessonDetailView.swift
//  WordsLearner
//

import AVFoundation
import ComposableArchitecture
import Combine
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct MultimodalLessonDetailView: View {
    @Bindable var store: StoreOf<MultimodalLessonsFeature>
    @Dependency(\.multimodalAssetStore) private var assetStore
    @StateObject private var audioPlayer = DetailFrameAudioPlayer()
    @State private var playAllQueue: [MultimodalLessonFrame] = []
    @State private var currentFramePosition = 0

    var body: some View {
        Group {
            if let lesson = selectedLesson {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerCard(lesson)
                        framesCard
                    }
                    .padding()
                }
                .background(AppColors.background)
                .navigationTitle("Lesson Detail")
            } else {
                ContentUnavailableView(
                    "No Lesson Selected",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Select a multimodal lesson from history to view frames and play narration.")
                )
            }
        }
        .onChange(of: store.selectedLessonID) { _, _ in
            stopPlayback()
            currentFramePosition = 0
        }
        .onChange(of: store.selectedFrames) { _, _ in
            stopPlayback()
            currentFramePosition = 0
        }
        .onDisappear {
            stopPlayback()
        }
    }

    private func headerCard(_ lesson: MultimodalLesson) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(lesson.word1) vs \(lesson.word2)")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                statusBadge(lesson.lessonStatus)
            }

            Text(lesson.userSentence.isEmpty ? "No sentence provided" : lesson.userSentence)
                .font(.subheadline)
                .foregroundColor(AppColors.secondaryText)

            if lesson.lessonStatus == .failed, let error = lesson.errorMessage, !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundColor(AppColors.error)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.secondaryBackground)
        )
    }

    private var framesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Frames")
                    .font(.headline)
                Spacer()
                Text(frameProgressText)
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
                Button {
                    startPlayAll()
                } label: {
                    Label(
                        playAllQueue.isEmpty && !audioPlayer.isPlaying ? "Play All" : "Playing...",
                        systemImage: playAllQueue.isEmpty && !audioPlayer.isPlaying ? "play.circle" : "waveform"
                    )
                }
                .disabled(!canPlayAll)

                if audioPlayer.isPlaying {
                    Button("Stop") {
                        stopPlayback()
                    }
                    .foregroundColor(AppColors.error)
                }
            }

            if orderedFrames.isEmpty {
                if selectedLesson?.lessonStatus == .generating {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Generating storyboard and narration...")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.primaryText)
                        }
                        Text("This lesson is still in progress. New frames will appear automatically.")
                            .font(.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                } else {
                    Text("No frames found for this lesson.")
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                }
            } else if let frame = currentFrame {
                let descriptor = describeFrameRole(frame.frameRole)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Frame \(frame.frameIndex + 1): \(frame.title)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primaryText)
                    frameRolePills(frame: frame, descriptor: descriptor)
                    frameImageView(frame)
                    Text(frame.narrationText)
                        .font(.title3)
                        .lineSpacing(4)
                        .foregroundColor(AppColors.primaryText)
                    if !frame.caption.isEmpty {
                        Text(frame.caption)
                            .font(.body)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    audioControlRow(frame)
                    frameNavigationRow
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.background)
                )
            } else {
                Text("No frame selected.")
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.secondaryBackground)
        )
    }

    private var frameNavigationRow: some View {
        HStack {
            Button("Previous") {
                moveToPreviousFrame(loop: true)
            }
            .disabled(orderedFrames.count <= 1)

            Spacer()

            Button("Next") {
                moveToNextFrame(loop: true)
            }
            .disabled(orderedFrames.count <= 1)
        }
    }

    @ViewBuilder
    private func frameImageView(_ frame: MultimodalLessonFrame) -> some View {
        if let image = lessonImage(for: frame) {
            image
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(minHeight: 280, maxHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.separator.opacity(0.35))
                .frame(minHeight: 220)
                .overlay {
                    Label("Image not found", systemImage: "photo")
                        .font(.body)
                        .foregroundColor(AppColors.secondaryText)
                }
        }
    }

    private func audioControlRow(_ frame: MultimodalLessonFrame) -> some View {
        HStack(spacing: 10) {
            let hasAudio = audioURL(for: frame) != nil
            Button {
                toggleFrameAudio(frame)
            } label: {
                Label(
                    audioPlayer.currentFrameID == frame.id && audioPlayer.isPlaying ? "Pause" : "Play Narration",
                    systemImage: audioPlayer.currentFrameID == frame.id && audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill"
                )
            }
            .disabled(!hasAudio)

            if !hasAudio {
                Text("Audio not found")
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            Spacer()
        }
    }

    private var selectedLesson: MultimodalLesson? {
        guard let selectedID = store.selectedLessonID else { return nil }
        return store.lessons.first(where: { $0.id == selectedID })
    }

    private var orderedFrames: [MultimodalLessonFrame] {
        store.selectedFrames.sorted(by: { $0.frameIndex < $1.frameIndex })
    }

    private var currentFrame: MultimodalLessonFrame? {
        guard !orderedFrames.isEmpty else { return nil }
        let safeIndex = min(max(currentFramePosition, 0), orderedFrames.count - 1)
        return orderedFrames[safeIndex]
    }

    private var frameProgressText: String {
        guard let frame = currentFrame else { return "0/0" }
        let overall = "\(min(currentFramePosition + 1, orderedFrames.count))/\(orderedFrames.count)"
        let descriptor = describeFrameRole(frame.frameRole)
        if descriptor.isFinalConclusion {
            return "\(overall) · Final Verdict"
        }
        guard let storyLabel = descriptor.storyLabel else { return overall }
        guard let roleIndex = descriptor.roleIndexInStory else { return "\(overall) · \(storyLabel)" }
        return "\(overall) · \(storyLabel) \(roleIndex + 1)/4"
    }

    private var canPlayAll: Bool {
        !orderedFrames.isEmpty && !audioPlayer.isPlaying
    }

    private func startPlayAll() {
        guard let startFrame = currentFrame else { return }
        guard let startIndex = orderedFrames.firstIndex(where: { $0.id == startFrame.id }) else { return }
        playAllQueue = Array(orderedFrames.dropFirst(startIndex + 1))
        playFrame(startFrame, continueQueue: true)
    }

    private func toggleFrameAudio(_ frame: MultimodalLessonFrame) {
        if audioPlayer.currentFrameID == frame.id && audioPlayer.isPlaying {
            stopPlayback()
            return
        }
        playAllQueue = []
        playFrame(frame, continueQueue: false)
    }

    private func playFrame(_ frame: MultimodalLessonFrame, continueQueue: Bool) {
        if let index = orderedFrames.firstIndex(where: { $0.id == frame.id }) {
            currentFramePosition = index
        }
        guard let url = audioURL(for: frame) else {
            if continueQueue {
                playNextInQueue()
            }
            return
        }
        audioPlayer.play(frameID: frame.id, url: url) {
            if continueQueue {
                playNextInQueue()
            }
        }
    }

    private func playNextInQueue() {
        guard let next = playAllQueue.first else {
            playAllQueue = []
            return
        }
        playAllQueue.removeFirst()
        playFrame(next, continueQueue: true)
    }

    private func stopPlayback() {
        playAllQueue = []
        audioPlayer.stop()
    }

    private func moveToNextFrame(loop: Bool) {
        guard !orderedFrames.isEmpty else { return }
        if currentFramePosition < orderedFrames.count - 1 {
            currentFramePosition += 1
        } else if loop {
            currentFramePosition = 0
        }
        if audioPlayer.isPlaying {
            stopPlayback()
        }
    }

    private func moveToPreviousFrame(loop: Bool) {
        guard !orderedFrames.isEmpty else { return }
        if currentFramePosition > 0 {
            currentFramePosition -= 1
        } else if loop {
            currentFramePosition = max(orderedFrames.count - 1, 0)
        }
        if audioPlayer.isPlaying {
            stopPlayback()
        }
    }

    private func audioURL(for frame: MultimodalLessonFrame) -> URL? {
        try? assetStore.resolve(frame.audioRelativePath)
    }

    private func lessonImage(for frame: MultimodalLessonFrame) -> Image? {
        guard let imageURL = try? assetStore.resolve(frame.imageRelativePath) else {
            return nil
        }
        #if os(macOS)
        guard let image = NSImage(contentsOf: imageURL) else { return nil }
        return Image(nsImage: image)
        #else
        guard let image = UIImage(contentsOfFile: imageURL.path) else { return nil }
        return Image(uiImage: image)
        #endif
    }

    private func statusBadge(_ status: MultimodalLesson.Status) -> some View {
        Text(statusLabel(status))
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(statusColor(status).opacity(0.15)))
            .foregroundColor(statusColor(status))
    }

    private func statusLabel(_ status: MultimodalLesson.Status) -> String {
        switch status {
        case .generating: return "Generating"
        case .ready: return "Ready"
        case .failed: return "Failed"
        }
    }

    private func statusColor(_ status: MultimodalLesson.Status) -> Color {
        switch status {
        case .generating: return AppColors.warning
        case .ready: return AppColors.success
        case .failed: return AppColors.error
        }
    }

    @ViewBuilder
    private func frameRolePills(frame: MultimodalLessonFrame, descriptor: FrameRoleDescriptor) -> some View {
        HStack(spacing: 6) {
            if let storyLabel = descriptor.storyLabel {
                frameRolePill(storyLabel, tint: AppColors.info)
            }
            if let roleLabel = descriptor.roleLabel {
                frameRolePill(roleLabel, tint: AppColors.secondaryText)
            }
            if descriptor.isFinalConclusion, let verdict = verdictLabel(for: frame.expectedAnswer) {
                frameRolePill(verdict, tint: verdictColor(for: frame.expectedAnswer))
            }
            Spacer()
        }
    }

    private func frameRolePill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(tint.opacity(0.15))
            )
            .foregroundColor(tint)
    }

    private func verdictLabel(for verdict: String?) -> String? {
        switch verdict?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "yes":
            return "Interchangeable"
        case "no":
            return "Not Interchangeable"
        case "depends":
            return "Depends"
        default:
            return nil
        }
    }

    private func verdictColor(for verdict: String?) -> Color {
        switch verdict?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "yes":
            return AppColors.success
        case "no":
            return AppColors.error
        case "depends":
            return AppColors.warning
        default:
            return AppColors.secondaryText
        }
    }

    private func describeFrameRole(_ frameRole: String) -> FrameRoleDescriptor {
        let trimmed = frameRole.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()
        if normalized == "final_conclusion" {
            return FrameRoleDescriptor(
                storyLabel: nil,
                roleLabel: "Final Conclusion",
                roleIndexInStory: nil,
                isFinalConclusion: true
            )
        }

        let parts = trimmed.split(separator: ":", maxSplits: 1).map(String.init)
        if parts.count == 2 {
            let storyID = parts[0]
            let roleRaw = parts[1].lowercased()
            return FrameRoleDescriptor(
                storyLabel: storyLabel(for: storyID),
                roleLabel: roleLabel(for: roleRaw),
                roleIndexInStory: roleIndex(for: roleRaw),
                isFinalConclusion: false
            )
        }

        guard !trimmed.isEmpty else {
            return FrameRoleDescriptor(
                storyLabel: nil,
                roleLabel: nil,
                roleIndexInStory: nil,
                isFinalConclusion: false
            )
        }

        return FrameRoleDescriptor(
            storyLabel: nil,
            roleLabel: humanizedRole(trimmed),
            roleIndexInStory: nil,
            isFinalConclusion: false
        )
    }

    private func storyLabel(for storyID: String) -> String {
        guard storyID.lowercased().hasPrefix("story_") else {
            return humanizedRole(storyID)
        }
        let suffix = String(storyID.dropFirst("story_".count))
        guard !suffix.isEmpty else { return "Story" }
        return "Story \(suffix.uppercased())"
    }

    private func roleLabel(for roleRaw: String) -> String {
        switch roleRaw {
        case "setup":
            return "Setup"
        case "conflict":
            return "Conflict"
        case "outcome":
            return "Outcome"
        case "language_lock_in":
            return "Language Lock-In"
        default:
            return humanizedRole(roleRaw)
        }
    }

    private func roleIndex(for roleRaw: String) -> Int? {
        switch roleRaw {
        case "setup":
            return 0
        case "conflict":
            return 1
        case "outcome":
            return 2
        case "language_lock_in":
            return 3
        default:
            return nil
        }
    }

    private func humanizedRole(_ text: String) -> String {
        text
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}

private struct FrameRoleDescriptor {
    let storyLabel: String?
    let roleLabel: String?
    let roleIndexInStory: Int?
    let isFinalConclusion: Bool
}

@MainActor
private final class DetailFrameAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var currentFrameID: UUID?
    @Published private(set) var isPlaying = false

    private var player: AVAudioPlayer?
    private var completion: (() -> Void)?

    func play(frameID: UUID, url: URL, completion: @escaping () -> Void) {
        stop()
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            self.player = player
            currentFrameID = frameID
            isPlaying = true
            self.completion = completion
            player.prepareToPlay()
            player.play()
        } catch {
            stop()
        }
    }

    func stop() {
        player?.stop()
        player = nil
        currentFrameID = nil
        isPlaying = false
        completion = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            let completion = self.completion
            self.stop()
            if flag {
                completion?()
            }
        }
    }
}
