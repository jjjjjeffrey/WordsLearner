//
//  SidebarView.swift
//  NavigationSplitViewTCA
//
//  Created by Michael Brünen on 09.12.25.
//

import ComposableArchitecture
import SwiftUI

// MARK: - Sidebar Reducer

@Reducer
struct Sidebar {
    @ObservableState
    struct State: Equatable {
        var sidebarData: SidebarData
        var selectedGenre: ContentData?
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

struct SidebarView: View {
    @Bindable var store: StoreOf<Sidebar>

    var body: some View {
        VStack(alignment: .leading) {
            Text("Choose a genre")
                .font(.title)

            List(selection: $store.selectedGenre) {
                ForEach(store.sidebarData.items) { genre in
                    NavigationLink(value: genre) {
                        Text(genre.title)
                    }
                }
            }
            .listStyle(.plain)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationTitle(store.sidebarData.title)
    }
}

#Preview {
    NavigationStack {
        SidebarView(store: Store(initialState: Sidebar.State(sidebarData: SidebarData())) {
            Sidebar()
        })
    }
}
