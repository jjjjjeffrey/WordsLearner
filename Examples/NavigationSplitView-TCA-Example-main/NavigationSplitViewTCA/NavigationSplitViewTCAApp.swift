//
//  NavigationSplitViewTCAApp.swift
//  NavigationSplitViewTCA
//
//  Created by Michael Brünen on 09.12.25.
//

import ComposableArchitecture
import SwiftUI

// MARK: - App Reducer

@Reducer
struct AppReducer {
    @ObservableState
    struct State: Equatable {
        var sidebarState = Sidebar.State(sidebarData: SidebarData())
        var contentState: Content.State?
        var detailState: Detail.State?
    }

    enum Action:  Equatable {
        case sidebar(Sidebar.Action)
        case content(Content.Action)
        case detail(Detail.Action)
    }

    var body: some ReducerOf<Self> {
        Reduce<State, Action> { state, action in
            switch action {
            case .sidebar(\.binding.selectedGenre):
                guard let genre = state.sidebarState.selectedGenre else { return .none }
                if state.contentState != nil {
                    state.contentState?.genre = genre
                } else {
                    state.contentState = Content.State(genre: genre)
                }
                return .none

            case .content(\.binding.selectedBand):
                if let band = state.contentState?.selectedBand {
                    state.detailState = Detail.State(band: band)
                } else {
                    state.detailState = nil
                }
                return .none

            default:
                return .none
            }
        }
        ._printChanges()
        .ifLet(\.contentState, action: \.content) { Content() }
        .ifLet(\.detailState, action: \.detail) { Detail() }

        Scope(state: \.sidebarState, action: \.sidebar) {
            Sidebar()
        }
    }
}

// MARK: - App View

@main
struct NavigationSplitViewTCAApp: App {
    @Bindable var store = Store(initialState: AppReducer.State()) {
        AppReducer()
    }

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                SidebarView(store: store.scope(state: \.sidebarState, action: \.sidebar))
            } content: {
                if let contentStore = store.scope(state: \.contentState, action: \.content) {
                    ContentView(store: contentStore)
                }
            } detail: {
                if let detailStore = store.scope(state: \.detailState, action: \.detail) {
                    DetailView(store: detailStore)
                }
            }
        }
    }
}
