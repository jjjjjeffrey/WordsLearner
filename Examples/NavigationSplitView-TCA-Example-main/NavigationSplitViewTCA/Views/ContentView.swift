//
//  DetailView.swift
//  NavigationSplitViewTCA
//
//  Created by Michael Brünen on 09.12.25.
//

import ComposableArchitecture
import SwiftUI

// MARK: - Detail Reducer

@Reducer
struct Content {
    @ObservableState
    struct State: Equatable {
        var genre: ContentData
        var selectedBand: DetailData?
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            default:
                return .none
            }
        }
    }
}

struct ContentView: View {
    @Bindable var store: StoreOf<Content>

    var body: some View {
        VStack(alignment: .leading) {
            Text(store.genre.subtitle)
                .font(.title)

            List(selection: $store.selectedBand) {
                ForEach(store.genre.items) { band in
                    NavigationLink(value: band) {
                        Text(band.title)
                    }
                }
            }
            .listStyle(.plain)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationTitle(store.genre.title)
    }
}

#Preview {
    NavigationStack {
        ContentView(store: Store(initialState: Content.State(genre: .metal)) {
            Content()
        })
    }
}
