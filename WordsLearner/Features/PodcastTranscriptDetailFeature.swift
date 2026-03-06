//
//  PodcastTranscriptDetailFeature.swift
//  WordsLearner
//

import ComposableArchitecture
import Foundation

@Reducer
struct PodcastTranscriptDetailFeature {
    @ObservableState
    struct State: Equatable {
        var transcript: String
        var turns: [PodcastTranscriptTurnTiming]
    }

    enum Action: Equatable {}

    var body: some Reducer<State, Action> {
        EmptyReducer()
    }
}
