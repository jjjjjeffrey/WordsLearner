//
//  ComparisonHistoryListFeature.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/21/25.
//

import ComposableArchitecture
import Foundation
import SQLiteData
import SwiftUI

@Reducer
struct ComparisonHistoryListFeature {
    @ObservableState
    struct State {
        @ObservationStateIgnored
        @Fetch(ComparisonsFetchKeyRequest(), animation: .default)
        var comparisons = ComparisonsFetchKeyRequest.Value()
        
        var searchText: String = ""
        var showUnreadOnly: Bool = false
        
        var filteredComparisons: [ComparisonHistory] {
            comparisons.comparisons
        }
        
        var allComparisons: [ComparisonHistory] {
            comparisons.allComparisons
        }
        
        @Presents var alert: AlertState<Action.Alert>?
        
#if os(macOS)
        var isExporting = false
        var isImporting = false
        var exportDocument: ComparisonHistoryExportDocument?
#endif
    }
    
    enum Action: Equatable {
        case comparisonTapped(ComparisonHistory)
        case deleteComparisons(IndexSet)
        case clearAllButtonTapped
        case textChanged(String)
        case filterToggled
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)
#if os(macOS)
        case exportButtonTapped
        case exportPrepared(ComparisonHistoryExportDocument)
        case exportFailed(String)
        case exportPresentationChanged(Bool)
        case exportFinished(String?)
        case importButtonTapped
        case importPresentationChanged(Bool)
        case importFilePicked([URL])
        case importCompleted(Int)
        case importFailed(String)
#endif
        
        enum Alert: Equatable {
            case clearAllConfirmed
        }
        
        enum Delegate: Equatable {
            case comparisonSelected(ComparisonHistory)
        }
    }
    
    @Dependency(\.defaultDatabase) var database
    
    enum CancelID {
        case comparisonTapped
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .comparisonTapped(comparison):
                return .run { send in
                    try await database.write { db in
                        try ComparisonHistory
                            .where { $0.id == comparison.id }
                            .update { $0.isRead = true }
                            .execute(db)
                    }
                    await send(.delegate(.comparisonSelected(comparison)))
                }
                .cancellable(id: CancelID.comparisonTapped)
            case let .deleteComparisons(indexSet):
                let comparisons = state.filteredComparisons
                return .run { send in
                    await withErrorReporting {
                        try await database.write { db in
                            let ids = indexSet.map { comparisons[$0].id }
                            try ComparisonHistory
                                .where { $0.id.in(ids) }
                                .delete()
                                .execute(db)
                        }
                    }
                }
                
            case .clearAllButtonTapped:
                state.alert = AlertState {
                    TextState("Clear All History?")
                } actions: {
                    ButtonState(role: .destructive, action: .clearAllConfirmed) {
                        TextState("Clear All")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("This will delete all comparison history. This action cannot be undone.")
                }
                return .none
                
            case .alert(.presented(.clearAllConfirmed)):
                state.alert = nil
                return .run { send in
                    await withErrorReporting {
                        try await database.write { db in
                            try ComparisonHistory.delete().execute(db)
                        }
                    }
                }
            case let .textChanged(text):
                state.searchText = text
                return loadComparisons(state)
            case .filterToggled:
                state.showUnreadOnly.toggle()
                return loadComparisons(state)
            case .delegate:
                return .none
                
            case .alert:
                return .none
                
#if os(macOS)
            case .exportButtonTapped:
                return .run { send in
                    do {
                        let histories = try await database.read { db in
                            try ComparisonHistory
                                .order { $0.date.desc() }
                                .fetchAll(db)
                        }
                        let records = histories.map(ComparisonHistoryExportRecord.init)
                        await send(.exportPrepared(
                            ComparisonHistoryExportDocument(records: records)
                        ))
                    } catch {
                        await send(.exportFailed(error.localizedDescription))
                    }
                }
                
            case let .exportPrepared(document):
                state.exportDocument = document
                state.isExporting = true
                return .none
                
            case let .exportFailed(message):
                state.alert = AlertState {
                    TextState("Export Failed")
                } actions: {
                    ButtonState(role: .cancel) {
                        TextState("OK")
                    }
                } message: {
                    TextState("Unable to export comparison history. \(message)")
                }
                return .none
                
            case let .exportPresentationChanged(isPresented):
                state.isExporting = isPresented
                if !isPresented {
                    state.exportDocument = nil
                }
                return .none
                
            case let .exportFinished(message):
                state.isExporting = false
                state.exportDocument = nil
                if let message {
                    state.alert = AlertState {
                        TextState("Export Failed")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("OK")
                        }
                    } message: {
                        TextState("Unable to export comparison history. \(message)")
                    }
                }
                return .none
                
            case .importButtonTapped:
                state.isImporting = true
                return .none
                
            case let .importPresentationChanged(isPresented):
                state.isImporting = isPresented
                return .none
                
            case let .importFilePicked(urls):
                state.isImporting = false
                guard let url = urls.first else {
                    return .send(.importFailed("No file selected."))
                }
                return .run { send in
                    do {
                        let data = try loadData(from: url)
                        let records = try decodeExportRecords(from: data)
                        try await database.write { db in
                            try ComparisonHistory.delete().execute(db)
                            for record in records {
                                try ComparisonHistory.insert {
                                    record.toDraft()
                                }
                                .execute(db)
                            }
                        }
                        await send(.importCompleted(records.count))
                    } catch {
                        await send(.importFailed(error.localizedDescription))
                    }
                }
                
            case let .importCompleted(count):
                state.alert = AlertState {
                    TextState("Import Complete")
                } actions: {
                    ButtonState(role: .cancel) {
                        TextState("OK")
                    }
                } message: {
                    TextState("Imported \(count) comparison records.")
                }
                return .none
                
            case let .importFailed(message):
                state.alert = AlertState {
                    TextState("Import Failed")
                } actions: {
                    ButtonState(role: .cancel) {
                        TextState("OK")
                    }
                } message: {
                    TextState("Unable to import comparison history. \(message)")
                }
                return .none
#endif
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
    
    private func loadComparisons(_ state: State) -> Effect<Action> {
        return .run { [
            comparisons = state.$comparisons,
            showUnreadOnly = state.showUnreadOnly,
            searchText = state.searchText
        ] send in
            await loadComparisons(comparisons, showUnreadOnly: showUnreadOnly, searchText: searchText)
        }
    }
    
    private func loadComparisons(
        _ fetch: Fetch<ComparisonsFetchKeyRequest.Value>,
        showUnreadOnly: Bool,
        searchText: String) async {
            await withErrorReporting {
                await withErrorReporting {
                    try await fetch.load(
                        ComparisonsFetchKeyRequest(
                            searchText: searchText,
                            showUnreadOnly: showUnreadOnly
                        ),
                        animation: Animation.default
                    )
                }
            }
        }
}

// Separate Equatable conformance to work around @Fetch property wrapper limitation
extension ComparisonHistoryListFeature.State: Equatable {
#if os(iOS)
    static func == (lhs: ComparisonHistoryListFeature.State, rhs: ComparisonHistoryListFeature.State) -> Bool {
        lhs.searchText == rhs.searchText &&
        lhs.showUnreadOnly == rhs.showUnreadOnly &&
        lhs.alert == rhs.alert
    }
#endif
    
#if os(macOS)
    static func == (lhs: ComparisonHistoryListFeature.State, rhs: ComparisonHistoryListFeature.State) -> Bool {
        lhs.searchText == rhs.searchText &&
        lhs.showUnreadOnly == rhs.showUnreadOnly &&
        lhs.alert == rhs.alert &&
        lhs.isExporting == rhs.isExporting &&
        lhs.isImporting == rhs.isImporting
        
    }
#endif
}

#if os(macOS)
nonisolated private func loadData(from url: URL) throws -> Data {
    let didAccess = url.startAccessingSecurityScopedResource()
    defer {
        if didAccess {
            url.stopAccessingSecurityScopedResource()
        }
    }
    return try Data(contentsOf: url)
}

nonisolated private func decodeExportRecords(from data: Data) throws -> [ComparisonHistoryExportRecord] {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode([ComparisonHistoryExportRecord].self, from: data)
}
#endif

struct ComparisonsFetchKeyRequest: FetchKeyRequest, Equatable {
    var searchText: String = ""
    var showUnreadOnly: Bool = false
    
    struct Value: Equatable {
        var comparisons: [ComparisonHistory] = []
        var allComparisons: [ComparisonHistory] = []
    }
    
    func fetch(_ db: Database) throws -> Value {
        // Always fetch all comparisons unfiltered for allComparisons
        let allComparisons = try ComparisonHistory.order { $0.date.desc() }.fetchAll(db)
        
        // Compose WHERE clause for filtered (search + unread)
        var query = ComparisonHistory.order { $0.date.desc() }
        if !searchText.isEmpty && showUnreadOnly {
            query = query.where {
                (!$0.isRead) &&
                ($0.word1.contains(searchText) || $0.word2.contains(searchText))
            }
        } else if !searchText.isEmpty {
            query = query.where {
                $0.word1.contains(searchText) || $0.word2.contains(searchText)
            }
        } else if showUnreadOnly {
            query = query.where { !$0.isRead }
        }
        let comparisons = try query.fetchAll(db)
        
        return Value(comparisons: comparisons, allComparisons: allComparisons)
    }
}
