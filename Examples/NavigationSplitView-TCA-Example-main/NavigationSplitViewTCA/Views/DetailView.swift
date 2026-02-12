//
//  ContentView.swift
//  NavigationSplitViewTCA
//
//  Created by Michael Brünen on 09.12.25.
//

import ComposableArchitecture
import SwiftUI

// MARK: - Detail Reducer

@Reducer
struct Detail {
    @ObservableState
    struct State: Equatable {
        var band: DetailData
    }

    enum Action: Equatable {
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            default:
                return .none
            }
        }
    }
}

struct DetailView: View {
    let store: StoreOf<Detail>

    var body: some View {
        VStack(alignment: .leading) {
            Text(store.band.subtitle)
                .font(.title)
            Text(store.band.description)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationTitle(store.band.title)
    }
}

#Preview {
    DetailView(store: Store(initialState: Detail.State(band: .blackSabbath)) {
        Detail()
    })
}
