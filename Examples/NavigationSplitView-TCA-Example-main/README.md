# Overview

A `NavigationSplitView` (in Vanilla SwiftUI) generally works by having `List(selection:content)` in the `Sidebar` and `Content` columns. The lists usually loop over some data and display a `NavigationLink(value:label:)` for each item.

This repository shows how to use a `NavigationSplitView` with TCA's Reducers.

## Example of NavigationSplitView usage in Vanilla SwiftUI  

```swift
import SwiftUI

@main
struct YourAwesomeApp: App {
    @State private var selectedSiteBarItem: SideBarItem?
    @State private var selectedDetailItem: DetailItem?
    
    let sidebarItems: [SideBarItem] = [/* ... */]
    let detailItems: [DetailItem] = [/* ... */]

    WindowGroup {
        NavigationSplitView {
            List(selection: $selectedSiteBarItem) {
                ForEach(sidebarItems) { sidebarItem in
                    NavigationLink(value: sidebarItem) {
                        Text(sidebarItem.name)
                    }
                }
            }
            .navigationTitle("Sidebar")
        } content: {
            if let selectedSiteBarItem {
                List(selection: $selectedDetailItem) {
                    ForEach(detailItems) { detailItem in
                        NavigationLink(value: detailItem) {
                            Text(detailItem.name)
                        }
                    }
                }
                .navigationTitle(sidebarItem.detailTitle)
            } else {
                Text("Choose an item from the sidebar")
            }
        } detail: {
            if let selectedDetailItem {
                DetailView(item: selectedDetailItem)
            } else {
                Text("Choose an item from the content")
            }
        }
    }
}
```

## How this example does it

In this example we have 4 Reducers:
The `AppReducer` is the root reducer of the app and holds the state for the other reducers. 
`SideBar`, `Content` and `Detail` reducer's' are for the respective parts of the `NavigationSplitView`

### AppReducer

The `AppReducer` listens for the selection of items (in this example genres and bands) and creates the sub-reducers state when something is selected.

```swift
import ComposableArchitecture

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
        Reduce { state, action in
            switch action {
            // If a genre is selected, populate the content reducer's state
            case .sidebar(\.binding.selectedGenre):
                if let genre = state.sidebarState.selectedGenre {
                    state.contentState = Content.State(genre: genre)
                } else {
                    state.contentState = nil
                }
                return .none

            // if a band is selected, populate the detail reducer's state
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
        .ifLet(\.contentState, action: \.content) { Content() }
        .ifLet(\.detailState, action: \.detail) { Detail() }

        // Sidebar state always exists in this example, so no `ifLet(...)`
        Scope(state: \.sidebarState, action: \.sidebar) {
            Sidebar()
        }
    }
} 
```

### AppView

The `AppView` simply scopes to the child reducers when possible and otherwise shows a default view when nothing is selected. On iOS you'd only see this Landscape Mode, on iPadOS you'd always see those default views.

```swift
import ComposableArchitecture
import SwiftUI

@main
struct AppView: App {
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
                } else {
                    Text("Choose an item from the sidebar")
                }
            } detail: {
                if let detailStore = store.scope(state: \.detailState, action: \.detail) {
                    DetailView(store: detailStore)
                } else {
                    Text("Choose an item from the content column")
                }
            }
        }
    }
}
```

### Sidebar and Content Reducer

`Both Sidebar` and `Content` reducer as well as their views are very similiar.
The reducers both hold their own data as well as what is currently selected in their state. 
The views only display a list based on their reducers state.
For the Readme I'll only show the `Sidebar` reducer's code here

**Sidebar Reducer**

```swift
import ComposableArchitecture

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
```

**Sidebar View**

```swift
import ComposeableArchitecture
import SwiftUI

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
```

## Final notes

At the time of writing this I'm still learning TCA, so my example likely has some flaws - if you find something to improve please let me know!

I wasn't able to find any up to date example, so after going over some older (more complicated) examples I decided to make my own minimalistic example, using the current version of TCA.
