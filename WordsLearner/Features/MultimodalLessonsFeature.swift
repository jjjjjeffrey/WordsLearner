//
//  MultimodalLessonsFeature.swift
//  WordsLearner
//

import ComposableArchitecture
import Foundation
import SQLiteData
import SwiftUI

@Reducer
struct MultimodalLessonsFeature {
    @ObservableState
    struct State: Equatable {
        var searchText: String = ""
        var showFailedOnly: Bool = false
        var selectedLessonID: UUID?
        var selectedFrames: [MultimodalLessonFrame] = []

        @ObservationStateIgnored
        @FetchAll(
            MultimodalLesson
                .order { $0.createdAt.desc() },
            animation: .default
        )
        var lessons: [MultimodalLesson] = []

        @Presents var alert: AlertState<Action.Alert>?

        var filteredLessons: [MultimodalLesson] {
            lessons.filter { lesson in
                let matchesStatus = !showFailedOnly || lesson.lessonStatus == .failed
                let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return matchesStatus }
                let matchesSearch =
                    lesson.word1.localizedCaseInsensitiveContains(text) ||
                    lesson.word2.localizedCaseInsensitiveContains(text) ||
                    lesson.userSentence.localizedCaseInsensitiveContains(text)
                return matchesStatus && matchesSearch
            }
        }
    }

    enum Action: Equatable {
        case lessonTapped(UUID)
        case selectedFramesLoaded([MultimodalLessonFrame])
        case deleteLessons(IndexSet)
        case clearAllButtonTapped
        case filterToggled
        case textChanged(String)
        case alert(PresentationAction<Alert>)

        enum Alert: Equatable {
            case clearAllConfirmed
        }
    }

    @Dependency(\.defaultDatabase) var database

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .lessonTapped(lessonID):
                state.selectedLessonID = lessonID
                return .run { [database] send in
                    let frames = try await database.read { db in
                        try MultimodalLessonFrame
                            .where { $0.lessonID == lessonID }
                            .order { $0.frameIndex.asc() }
                            .fetchAll(db)
                    }
                    await send(.selectedFramesLoaded(frames))
                }

            case let .selectedFramesLoaded(frames):
                state.selectedFrames = frames
                return .none

            case let .deleteLessons(indexSet):
                let lessons = state.filteredLessons
                return .run { [database] _ in
                    await withErrorReporting {
                        try await database.write { db in
                            let ids = indexSet.map { lessons[$0].id }
                            try MultimodalLesson
                                .where { $0.id.in(ids) }
                                .delete()
                                .execute(db)
                            try MultimodalLessonFrame
                                .where { $0.lessonID.in(ids) }
                                .delete()
                                .execute(db)
                        }
                    }
                }

            case .clearAllButtonTapped:
                state.alert = AlertState {
                    TextState("Clear All Multimodal History?")
                } actions: {
                    ButtonState(role: .destructive, action: .clearAllConfirmed) {
                        TextState("Clear All")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("This will delete all multimodal lessons. This action cannot be undone.")
                }
                return .none

            case .alert(.presented(.clearAllConfirmed)):
                state.alert = nil
                return .run { [database] _ in
                    await withErrorReporting {
                        try await database.write { db in
                            try MultimodalLessonFrame.delete().execute(db)
                            try MultimodalLesson.delete().execute(db)
                        }
                    }
                }

            case let .textChanged(text):
                state.searchText = text
                return .none

            case .filterToggled:
                state.showFailedOnly.toggle()
                return .none

            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

extension MultimodalLessonsFeature.State {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.searchText == rhs.searchText &&
            lhs.showFailedOnly == rhs.showFailedOnly &&
            lhs.selectedLessonID == rhs.selectedLessonID &&
            lhs.selectedFrames == rhs.selectedFrames &&
            lhs.alert == rhs.alert
    }
}
