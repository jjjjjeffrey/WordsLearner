//
//  MarkdownDetailFeature.swift
//  WordsLearner
//
//  Created by Codex on 3/2/26.
//

import ComposableArchitecture
import Foundation

@Reducer
struct MarkdownDetailFeature {
    @ObservableState
    struct State: Equatable {
        var markdown: String
        var attributedString: AttributedString
    }

    enum Action: Equatable {}

    var body: some Reducer<State, Action> {
        EmptyReducer()
    }
}
