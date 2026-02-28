//
//  MultimodalLessonsView.swift
//  WordsLearner
//

import ComposableArchitecture
import SQLiteData
import SwiftUI

struct MultimodalLessonsView: View {
    @Bindable var store: StoreOf<MultimodalLessonsFeature>

    var body: some View {
        Group {
            listContent
        }
        .navigationTitle("Multimodal History")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .searchable(text: Binding(
            get: { store.searchText },
            set: { store.send(.textChanged($0)) }
        ), prompt: "Search words or sentence")
        .background(AppColors.background)
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                historyActionsMenu
            }
            #else
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    filterButton
                    clearAllButton
                }
            }
            #endif
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private var listContent: some View {
        Group {
            #if os(iOS)
            iosList
            #else
            macOSScrollView
            #endif
        }
    }

    #if os(iOS)
    private var iosList: some View {
        List {
            if store.filteredLessons.isEmpty {
                emptyStateSection
            } else {
                ForEach(store.filteredLessons) { lesson in
                    lessonRow(lesson)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                if let index = store.filteredLessons.firstIndex(where: { $0.id == lesson.id }) {
                                    store.send(.deleteLessons(IndexSet(integer: index)))
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                .onDelete { indexSet in
                    store.send(.deleteLessons(indexSet))
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    #endif

    #if os(macOS)
    private var macOSScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if store.filteredLessons.isEmpty {
                    emptyStateView
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else {
                    ForEach(store.filteredLessons) { lesson in
                        lessonRow(lesson)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    if let index = store.filteredLessons.firstIndex(where: { $0.id == lesson.id }) {
                                        store.send(.deleteLessons(IndexSet(integer: index)))
                                    }
                                }
                            }
                    }
                }
            }
            .padding()
        }
    }
    #endif

    private func lessonRow(_ lesson: MultimodalLesson) -> some View {
        Button {
            store.send(.lessonTapped(lesson.id))
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(lesson.word1) vs \(lesson.word2)")
                        .font(.headline)
                        .foregroundColor(AppColors.primaryText)
                    Spacer()
                    statusBadge(lesson.lessonStatus)
                }

                Text(lesson.userSentence.isEmpty ? "No sentence provided" : lesson.userSentence)
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(2)
                if store.selectedLessonID == lesson.id {
                    Text("Selected. View details in the detail column.")
                        .font(.caption2)
                        .foregroundColor(AppColors.primary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.secondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(store.selectedLessonID == lesson.id ? AppColors.primary.opacity(0.5) : .clear, lineWidth: 1)
            )
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
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

    private var emptyStateSection: some View {
        Section {
            emptyStateView
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
        }
        .listRowBackground(Color.clear)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: store.searchText.isEmpty ? "photo.on.rectangle.angled" : "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(AppColors.secondaryText.opacity(0.5))

            Text(store.searchText.isEmpty ? "No Multimodal Lessons Yet" : "No Results Found")
                .font(.headline)
                .foregroundColor(AppColors.secondaryText)

            if !store.searchText.isEmpty {
                Text("Try different keywords")
                    .font(.caption)
                    .foregroundColor(AppColors.tertiaryText)
            }
        }
    }

    private var filterButton: some View {
        Button {
            store.send(.filterToggled)
        } label: {
            Label(
                store.showFailedOnly ? "Show All" : "Failed Only",
                systemImage: store.showFailedOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
            )
        }
    }

    private var clearAllButton: some View {
        Button {
            store.send(.clearAllButtonTapped)
        } label: {
            Label("Clear All", systemImage: "trash")
                .foregroundColor(AppColors.error)
        }
        .disabled(store.lessons.isEmpty)
    }

    #if os(iOS)
    private var historyActionsMenu: some View {
        Menu {
            filterButton
            Divider()
            clearAllButton
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Multimodal History Actions")
    }
    #endif

}

#Preview("Mixed Statuses") {
    withDependencies {
        try! $0.bootstrapDatabase(
            useTest: true,
            seed: { db in
                let now = Date()
                let readyID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
                let generatingID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
                let failedID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

                try db.seed {
                    MultimodalLesson(
                        id: readyID,
                        word1: "affect",
                        word2: "effect",
                        userSentence: "The new policy will affect the final effect.",
                        status: MultimodalLesson.Status.ready.rawValue,
                        storyboardJSON: "{}",
                        stylePreset: "simple_educational_illustration_v1",
                        voicePreset: "elevenlabs_default_v1",
                        imageModel: "google/gemini-2.5-flash-image",
                        audioModel: "eleven_multilingual_v2",
                        generatorVersion: "v1",
                        claritySelfRating: 4,
                        lessonDurationSeconds: 35,
                        errorMessage: nil,
                        createdAt: now.addingTimeInterval(-1_200),
                        updatedAt: now.addingTimeInterval(-1_100),
                        completedAt: now.addingTimeInterval(-1_100)
                    )
                    MultimodalLesson(
                        id: generatingID,
                        word1: "adapt",
                        word2: "adopt",
                        userSentence: "Schools adapt quickly and adopt new tools.",
                        status: MultimodalLesson.Status.generating.rawValue,
                        storyboardJSON: "{}",
                        stylePreset: "simple_educational_illustration_v1",
                        voicePreset: "elevenlabs_default_v1",
                        imageModel: "google/gemini-2.5-flash-image",
                        audioModel: "eleven_multilingual_v2",
                        generatorVersion: "v1",
                        claritySelfRating: nil,
                        lessonDurationSeconds: nil,
                        errorMessage: nil,
                        createdAt: now.addingTimeInterval(-600),
                        updatedAt: now.addingTimeInterval(-300),
                        completedAt: nil
                    )
                    MultimodalLesson(
                        id: failedID,
                        word1: "character",
                        word2: "characteristic",
                        userSentence: "Her character is strong; kindness is her key characteristic.",
                        status: MultimodalLesson.Status.failed.rawValue,
                        storyboardJSON: "{}",
                        stylePreset: "simple_educational_illustration_v1",
                        voicePreset: "elevenlabs_default_v1",
                        imageModel: "google/gemini-2.5-flash-image",
                        audioModel: "eleven_multilingual_v2",
                        generatorVersion: "v1",
                        claritySelfRating: nil,
                        lessonDurationSeconds: nil,
                        errorMessage: "Audio API key missing.",
                        createdAt: now.addingTimeInterval(-150),
                        updatedAt: now.addingTimeInterval(-120),
                        completedAt: nil
                    )

                    MultimodalLessonFrame(
                        id: UUID(),
                        lessonID: readyID,
                        frameIndex: 0,
                        frameRole: "scene",
                        title: "Scene Setup",
                        caption: "A policy meeting creates a change.",
                        narrationText: "A new rule is introduced in the company.",
                        imagePrompt: "Office meeting with documents and charts",
                        imageRelativePath: "MultimodalLessons/\(readyID.uuidString)/frame-0.png",
                        audioRelativePath: "MultimodalLessons/\(readyID.uuidString)/frame-0.mp3",
                        audioDurationSeconds: 8,
                        checkPrompt: nil,
                        expectedAnswer: nil,
                        createdAt: now.addingTimeInterval(-1_100),
                        updatedAt: now.addingTimeInterval(-1_100)
                    )
                    MultimodalLessonFrame(
                        id: UUID(),
                        lessonID: readyID,
                        frameIndex: 1,
                        frameRole: "contrast",
                        title: "Word Contrast",
                        caption: "\"Affect\" is action; \"effect\" is result.",
                        narrationText: "The policy affects behavior and causes an effect.",
                        imagePrompt: "Split panel action and result",
                        imageRelativePath: "MultimodalLessons/\(readyID.uuidString)/frame-1.png",
                        audioRelativePath: "MultimodalLessons/\(readyID.uuidString)/frame-1.mp3",
                        audioDurationSeconds: 9,
                        checkPrompt: "Which word means result?",
                        expectedAnswer: "effect",
                        createdAt: now.addingTimeInterval(-1_050),
                        updatedAt: now.addingTimeInterval(-1_050)
                    )
                }
            }
        )
    } operation: {
        NavigationStack {
            MultimodalLessonsView(
                store: Store(
                    initialState: MultimodalLessonsFeature.State(
                        selectedLessonID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                        selectedFrames: [
                            MultimodalLessonFrame(
                                id: UUID(),
                                lessonID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                                frameIndex: 0,
                                frameRole: "scene",
                                title: "Scene Setup",
                                caption: "A policy meeting creates a change.",
                                narrationText: "A new rule is introduced in the company.",
                                imagePrompt: "Office meeting with documents and charts",
                                imageRelativePath: "MultimodalLessons/11111111-1111-1111-1111-111111111111/frame-0.png",
                                audioRelativePath: "MultimodalLessons/11111111-1111-1111-1111-111111111111/frame-0.mp3",
                                audioDurationSeconds: 8,
                                checkPrompt: nil,
                                expectedAnswer: nil,
                                createdAt: Date(),
                                updatedAt: Date()
                            ),
                            MultimodalLessonFrame(
                                id: UUID(),
                                lessonID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                                frameIndex: 1,
                                frameRole: "contrast",
                                title: "Word Contrast",
                                caption: "\"Affect\" is action; \"effect\" is result.",
                                narrationText: "The policy affects behavior and causes an effect.",
                                imagePrompt: "Split panel action and result",
                                imageRelativePath: "MultimodalLessons/11111111-1111-1111-1111-111111111111/frame-1.png",
                                audioRelativePath: "MultimodalLessons/11111111-1111-1111-1111-111111111111/frame-1.mp3",
                                audioDurationSeconds: 9,
                                checkPrompt: "Which word means result?",
                                expectedAnswer: "effect",
                                createdAt: Date(),
                                updatedAt: Date()
                            )
                        ]
                    )
                ) {
                    MultimodalLessonsFeature()
                }
            )
        }
    }
}

#Preview("Failed Only Filter") {
    withDependencies {
        try! $0.bootstrapDatabase(
            useTest: true,
            seed: { db in
                let now = Date()
                try db.seed {
                    MultimodalLesson(
                        id: UUID(),
                        word1: "adapt",
                        word2: "adopt",
                        userSentence: "They adopt changes slowly.",
                        status: MultimodalLesson.Status.failed.rawValue,
                        storyboardJSON: "{}",
                        stylePreset: "simple_educational_illustration_v1",
                        voicePreset: "elevenlabs_default_v1",
                        imageModel: "google/gemini-2.5-flash-image",
                        audioModel: "eleven_multilingual_v2",
                        generatorVersion: "v1",
                        claritySelfRating: nil,
                        lessonDurationSeconds: nil,
                        errorMessage: "Generation timeout.",
                        createdAt: now.addingTimeInterval(-300),
                        updatedAt: now.addingTimeInterval(-280),
                        completedAt: nil
                    )
                    MultimodalLesson(
                        id: UUID(),
                        word1: "historic",
                        word2: "historical",
                        userSentence: "A historic moment in a historical timeline.",
                        status: MultimodalLesson.Status.ready.rawValue,
                        storyboardJSON: "{}",
                        stylePreset: "simple_educational_illustration_v1",
                        voicePreset: "elevenlabs_default_v1",
                        imageModel: "google/gemini-2.5-flash-image",
                        audioModel: "eleven_multilingual_v2",
                        generatorVersion: "v1",
                        claritySelfRating: 5,
                        lessonDurationSeconds: 41,
                        errorMessage: nil,
                        createdAt: now.addingTimeInterval(-600),
                        updatedAt: now.addingTimeInterval(-580),
                        completedAt: now.addingTimeInterval(-580)
                    )
                }
            }
        )
    } operation: {
        NavigationStack {
            MultimodalLessonsView(
                store: Store(
                    initialState: MultimodalLessonsFeature.State(
                        searchText: "adapt",
                        showFailedOnly: true
                    )
                ) {
                    MultimodalLessonsFeature()
                }
            )
        }
    }
}
