////
////  BackgroundTaskRow.swift
////  WordsLearner
////
////  Created by Jeffrey on 11/25/25.
////
//import ComposableArchitecture
//import SwiftUI
//
//struct BackgroundTaskRow: View {
//    let task: WordComparatorFeature.BackgroundTask
//    let onRemove: () -> Void
//    
//    var body: some View {
//        HStack(spacing: 12) {
//            // Status indicator
//            statusIcon
//            
//            // Task info
//            VStack(alignment: .leading, spacing: 4) {
//                HStack(spacing: 6) {
//                    Text(task.word1)
//                        .font(.subheadline)
//                        .fontWeight(.semibold)
//                        .foregroundColor(AppColors.word1Color)
//                    
//                    Text("vs")
//                        .font(.caption2)
//                        .foregroundColor(AppColors.secondaryText)
//                    
//                    Text(task.word2)
//                        .font(.subheadline)
//                        .fontWeight(.semibold)
//                        .foregroundColor(AppColors.word2Color)
//                }
//                
//                Text(task.sentence)
//                    .font(.caption)
//                    .foregroundColor(AppColors.secondaryText)
//                    .lineLimit(1)
//                
//                if let error = task.error {
//                    Text(error)
//                        .font(.caption2)
//                        .foregroundColor(AppColors.error)
//                        .lineLimit(1)
//                }
//            }
//            
//            Spacer()
//            
//            // Remove button (only for completed or failed tasks)
//            if task.status == .completed || task.status == .failed {
//                Button {
//                    onRemove()
//                } label: {
//                    Image(systemName: "xmark.circle.fill")
//                        .foregroundColor(AppColors.secondaryText)
//                        .font(.title3)
//                }
//                .buttonStyle(PlainButtonStyle())
//            }
//        }
//        .padding(12)
//        .background(
//            RoundedRectangle(cornerRadius: 8)
//                .fill(backgroundColorForStatus)
//        )
//    }
//    
//    @ViewBuilder
//    private var statusIcon: some View {
//        switch task.status {
//        case .pending:
//            Image(systemName: "clock")
//                .foregroundColor(AppColors.secondaryText)
//        case .generating:
//            ProgressView()
//                .scaleEffect(0.8)
//        case .completed:
//            Image(systemName: "checkmark.circle.fill")
//                .foregroundColor(AppColors.success)
//        case .failed:
//            Image(systemName: "xmark.circle.fill")
//                .foregroundColor(AppColors.error)
//        }
//    }
//    
//    private var backgroundColorForStatus: Color {
//        switch task.status {
//        case .pending:
//            return AppColors.fieldBackground
//        case .generating:
//            return AppColors.info.opacity(0.1)
//        case .completed:
//            return AppColors.success.opacity(0.1)
//        case .failed:
//            return AppColors.error.opacity(0.1)
//        }
//    }
//}
////
////  ComparisonHistoryListFeature.swift
////  WordsLearner
////
////  Created by Jeffrey on 11/21/25.
////
//
//import ComposableArchitecture
//import Foundation
//import SQLiteData
//import SwiftUI
//
//@Reducer
//struct ComparisonHistoryListFeature {
//    @ObservableState
//    struct State: Equatable {
//        @ObservationStateIgnored
//        @FetchAll(
//            ComparisonHistory
//                .order { $0.date.desc() },
//            animation: .default
//        )
//        var allComparisons: [ComparisonHistory] = []
//        
//        var searchText: String = ""
//        
//        var filteredComparisons: [ComparisonHistory] {
//            if searchText.isEmpty {
//                return allComparisons
//            }
//            let lowercasedSearch = searchText.lowercased()
//            return allComparisons.filter {
//                $0.word1.lowercased().contains(lowercasedSearch) ||
//                $0.word2.lowercased().contains(lowercasedSearch) ||
//                $0.sentence.lowercased().contains(lowercasedSearch)
//            }
//        }
//        
//        @Presents var alert: AlertState<Action.Alert>?
//    }
//    
//    enum Action {
//        case comparisonTapped(ComparisonHistory)
//        case deleteComparisons(IndexSet)
//        case clearAllButtonTapped
//        case textChanged(String)
//        case alert(PresentationAction<Alert>)
//        case delegate(Delegate)
//        
//        enum Alert: Equatable {
//            case clearAllConfirmed
//        }
//        
//        enum Delegate: Equatable {
//            case comparisonSelected(ComparisonHistory)
//        }
//    }
//    
//    @Dependency(\.defaultDatabase) var database
//    
//    var body: some Reducer<State, Action> {
//        Reduce { state, action in
//            switch action {
//            case let .comparisonTapped(comparison):
//                return .send(.delegate(.comparisonSelected(comparison)))
//            case let .deleteComparisons(indexSet):
//                let comparisons = state.filteredComparisons
//                return .run { send in
//                    await withErrorReporting {
//                        try await database.write { db in
//                            let ids = indexSet.map { comparisons[$0].id }
//                            try ComparisonHistory
//                                .where { $0.id.in(ids) }
//                                .delete()
//                                .execute(db)
//                        }
//                    }
//                }
//                
//            case .clearAllButtonTapped:
//                state.alert = AlertState {
//                    TextState("Clear All History?")
//                } actions: {
//                    ButtonState(role: .destructive, action: .clearAllConfirmed) {
//                        TextState("Clear All")
//                    }
//                    ButtonState(role: .cancel) {
//                        TextState("Cancel")
//                    }
//                } message: {
//                    TextState("This will delete all comparison history. This action cannot be undone.")
//                }
//                return .none
//                
//            case .alert(.presented(.clearAllConfirmed)):
//                return .run { send in
//                    await withErrorReporting {
//                        try await database.write { db in
//                            try ComparisonHistory.delete().execute(db)
//                        }
//                    }
//                }
//            case .textChanged:
//                return .none
//                
//            case .delegate:
//                return .none
//                
//            case .alert:
//                return .none
//            }
//        }
//        .ifLet(\.$alert, action: \.alert)
//    }
//}
////
////  ComparisonHistoryListView.swift
////  WordsLearner
////
////  Created by Jeffrey on 11/21/25.
////
//
//import ComposableArchitecture
//import SwiftUI
//import SQLiteData
//
//struct ComparisonHistoryListView: View {
//    @Bindable var store: StoreOf<ComparisonHistoryListFeature>
//    
//    var body: some View {
//        Group {
//            #if os(iOS)
//            iosList
//            #else
//            macOSScrollView
//            #endif
//        }
//        .navigationTitle("All Comparisons")
//        #if os(iOS)
//        .navigationBarTitleDisplayMode(.large)
//        #endif
//        .searchable(text: $store.searchText.sending(\.textChanged), prompt: "Search words or sentence")
//        .toolbar {
//            #if os(iOS)
//            ToolbarItem(placement: .navigationBarTrailing) {
//                clearAllButton
//            }
//            #else
//            ToolbarItem(placement: .primaryAction) {
//                clearAllButton
//            }
//            #endif
//        }
//        .alert($store.scope(state: \.alert, action: \.alert))
//    }
//    
//    // MARK: - iOS List View
//    #if os(iOS)
//    private var iosList: some View {
//        List {
//            if store.filteredComparisons.isEmpty {
//                emptyStateSection
//            } else {
//                ForEach(store.filteredComparisons) { comparison in
//                    SharedComparisonRow(comparison: comparison) {
//                        store.send(.comparisonTapped(comparison))
//                    }
//                    .listRowInsets(EdgeInsets())
//                    .listRowBackground(Color.clear)
//                }
//                .onDelete { indexSet in
//                    store.send(.deleteComparisons(indexSet))
//                }
//            }
//        }
//        .listStyle(PlainListStyle())
//    }
//    #endif
//    
//    // MARK: - macOS Scroll View
//    #if os(macOS)
//    private var macOSScrollView: some View {
//        ScrollView {
//            LazyVStack(spacing: 8) {
//                if store.filteredComparisons.isEmpty {
//                    emptyStateView
//                        .frame(maxWidth: .infinity)
//                        .padding(.vertical, 60)
//                } else {
//                    ForEach(store.filteredComparisons) { comparison in
//                        SharedComparisonRow(comparison: comparison) {
//                            store.send(.comparisonTapped(comparison))
//                        }
//                        .contextMenu {
//                            Button("Delete", role: .destructive) {
//                                if let index = store.filteredComparisons.firstIndex(where: { $0.id == comparison.id }) {
//                                    store.send(.deleteComparisons(IndexSet(integer: index)))
//                                }
//                            }
//                        }
//                    }
//                }
//            }
//            .padding()
//        }
//    }
//    #endif
//    
//    // MARK: - Shared Components
//    private var emptyStateSection: some View {
//        Section {
//            emptyStateView
//                .frame(maxWidth: .infinity)
//                .padding(.vertical, 60
//
//)
//        }
//        .listRowBackground(Color.clear)
//    }
//    
//    private var emptyStateView: some View {
//        VStack(spacing: 16) {
//            Image(systemName: store.searchText.isEmpty ? "tray" : "magnifyingglass")
//                .font(.system(size: 50))
//                .foregroundColor(AppColors.secondaryText.opacity(0.5))
//            
//            Text(store.searchText.isEmpty ? "No History Yet" : "No Results Found")
//                .font(.headline)
//                .foregroundColor(AppColors.secondaryText)
//            
//            if !store.searchText.isEmpty {
//                Text("Try different keywords")
//                    .font(.caption)
//                    .foregroundColor(AppColors.tertiaryText)
//            }
//        }
//    }
//    
//    private var clearAllButton: some View {
//        Button {
//            store.send(.clearAllButtonTapped)
//        } label: {
//            Label("Clear All", systemImage: "trash")
//                .foregroundColor(AppColors.error)
//        }
//        .disabled(store.allComparisons.isEmpty)
//    }
//}
//
//#Preview {
//    let _ = prepareDependencies {
//        $0.defaultDatabase = .testDatabase
//    }
//    
//    NavigationStack {
//        ComparisonHistoryListView(
//            store: Store(initialState: ComparisonHistoryListFeature.State()) {
//                ComparisonHistoryListFeature()
//            }
//        )
//    }
//}
////
////  RecentComparisonsFeature.swift
////  WordsLearner
////
////  Created by Jeffrey on 11/21/25.
////
//
//import ComposableArchitecture
//import Foundation
//import SQLiteData
//import SwiftUI
//
//@Reducer
//struct RecentComparisonsFeature {
//    @ObservableState
//    struct State: Equatable {
//        @ObservationStateIgnored
//        @FetchAll(
//            ComparisonHistory
//                .order { $0.date.desc() }
//                .limit(10),
//            animation: .default
//        )
//        var recentComparisons: [ComparisonHistory] = []
//        
//        var searchText: String = ""
//        var isLoading: Bool = false
//    }
//    
//    enum Action: BindableAction {
//        case binding(BindingAction<State>)
//        case onAppear
//        case comparisonTapped(ComparisonHistory)
//        case deleteComparisons(IndexSet)
//        case clearAllButtonTapped
//        case clearAllConfirmed
//        case delegate(Delegate)
//        
//        enum Delegate: Equatable {
//            case comparisonSelected(ComparisonHistory)
//        }
//    }
//    
//    @Dependency(\.defaultDatabase) var database
//    
//    var body: some Reducer<State, Action> {
//        BindingReducer()
//        
//        Reduce { state, action in
//            switch action {
//            case .onAppear:
//                return .none
//                
//            case let .comparisonTapped(comparison):
//                return .send(.delegate(.comparisonSelected(comparison)))
//                
//            case let .deleteComparisons(indexSet):
//                return .run { [comparisons = state.recentComparisons] send in
//                    await withErrorReporting {
//                        try await database.write { db in
//                            let ids = indexSet.map { comparisons[$0].id }
//                            try ComparisonHistory
//                                .where { $0.id.in(ids) }
//                                .delete()
//                                .execute(db)
//                        }
//                    }
//                }
//                
//            case .clearAllButtonTapped:
//                // Will trigger alert in the view
//                return .none
//                
//            case .clearAllConfirmed:
//                return .run { send in
//                    await withErrorReporting {
//                        try await database.write { db in
//                            try ComparisonHistory.delete().execute(db)
//                        }
//                    }
//                }
//                
//            case .delegate:
//                return .none
//                
//            case .binding:
//                return .none
//            }
//        }
//    }
//}
////
////  RecentComparisonsView.swift
////  WordsLearner
////
////  Created by Jeffrey on 11/21/25.
////
//
//import ComposableArchitecture
//import SwiftUI
//import SQLiteData
//
//struct RecentComparisonsView: View {
//    @Bindable var store: StoreOf<RecentComparisonsFeature>
//    @State private var showingClearAlert = false
//    
//    var body: some View {
//        Group {
//            if !store.recentComparisons.isEmpty {
//                VStack(alignment: .leading, spacing: 16) {
//                    headerSection
//                    comparisonsList
//                }
//                .padding(.top)
//            } else {
//                emptyStateView
//            }
//        }
//        .onAppear {
//            store.send(.onAppear)
//        }
//        .alert("Clear All Comparisons?", isPresented: $showingClearAlert) {
//            Button("Cancel", role: .cancel) { }
//            Button("Clear All", role: .destructive) {
//                store.send(.clearAllConfirmed)
//            }
//        } message: {
//            Text("This will delete all comparison history. This action cannot be undone.")
//        }
//    }
//    
//    private var headerSection: some View {
//        HStack {
//            Label("Recent Comparisons", systemImage: "clock.arrow.circlepath")
//                .font(.headline)
//                .foregroundColor(AppColors.primaryText)
//            
//            Spacer()
//            
//            Menu {
//                Button(role: .destructive) {
//                    showingClearAlert = true
//                } label: {
//                    Label("Clear All", systemImage: "trash")
//                }
//            } label: {
//                Image(systemName: "ellipsis.circle")
//                    .foregroundColor(AppColors.secondaryText)
//            }
//        }
//        .padding(.horizontal, 4)
//    }
//    
//    private var comparisonsList: some View {
//        LazyVStack(spacing: platformSpacing()) {
//            ForEach(store.recentComparisons) { comparison in
//                SharedComparisonRow(comparison: comparison) {
//                    store.send(.comparisonTapped(comparison))
//                }
//            }
//        }
//    }
//    
//    private var emptyStateView: some View {
//        VStack(spacing: 16) {
//            Image(systemName: "clock.badge.questionmark")
//                .font(.system(size: 60))
//                .foregroundColor(AppColors.secondaryText.opacity(0.5))
//            
//            Text("No Recent Comparisons")
//                .font(.headline)
//                .foregroundColor(AppColors.secondaryText)
//            
//            Text("Your comparison history will appear here")
//                .font(.caption)
//                .foregroundColor(AppColors.tertiaryText)
//                .multilineTextAlignment(.center)
//        }
//        .frame(maxWidth: .infinity)
//        .padding(.vertical, 40)
//    }
//    
//    private func platformSpacing() -> CGFloat {
//        #if os(iOS)
//        return 12
//        #else
//        return 8
//        #endif
//    }
//}
//
//#Preview {
//    let _ = prepareDependencies {
//        $0.defaultDatabase = .testDatabase
//    }
//    
//    RecentComparisonsView(
//        store: Store(initialState: RecentComparisonsFeature.State()) {
//            RecentComparisonsFeature()
//        }
//    )
//}
////
////  ResponseDetailFeature.swift
////  WordsLearner
////
////  Created by Jeffrey on 11/18/25.
////
//
//import ComposableArchitecture
//import Foundation
//import SQLiteData
//
//@Reducer
//struct ResponseDetailFeature {
//    @ObservableState
//    struct State: Equatable {
//        let word1: String
//        let word2: String
//        let sentence: String
//        var streamingResponse: String = ""
//        var isStreaming: Bool = false
//        var errorMessage: String? = nil
//        var shouldStartStreaming: Bool = true
//    }
//    
//    enum Action {
//        case onAppear
//        case startStreaming
//        case streamChunkReceived(String)
//        case streamCompleted
//        case streamFailed(Error)
//        case shareButtonTapped
//        case comparisonSaved
//        case comparisonSaveFailed(Error)
//    }
//    
//    @Dependency(\.aiService) var aiService
//    @Dependency(\.date.now) var now
//    @Dependency(\.defaultDatabase) var database
//    
//    var body: some Reducer<State, Action> {
//        Reduce { state, action in
//            switch action {
//            case .onAppear:
//                guard state.shouldStartStreaming else { return .none }
//                return .send(.startStreaming)
//                
//            case .startStreaming:
//                state.isStreaming = true
//                state.errorMessage = nil
//                
//                let prompt = buildPrompt(
//                    word1: state.word1,
//                    word2: state.word2,
//                    sentence: state.sentence
//                )
//                
//                return .run { send in
//                    do {
//                        for try await chunk in aiService.streamResponse(prompt) {
//                            await send(.streamChunkReceived(chunk))
//                        }
//                        await send(.streamCompleted)
//                    } catch {
//                        await send(.streamFailed(error))
//                    }
//                }
//                
//            case let .streamChunkReceived(chunk):
//                state.streamingResponse += chunk
//                return .none
//                
//            case .streamCompleted:
//                state.isStreaming = false
//                let draft = ComparisonHistory.Draft(
//                    word1: state.word1,
//                    word2: state.word2,
//                    sentence: state.sentence,
//                    response: state.streamingResponse,
//                    date: now
//                )
//                return .run { send in
//                    do {
//                        try await database.write { db in
//                            try ComparisonHistory.insert {
//                                draft
//                            }
//                            .execute(db)
//                        }
//                        await send(.comparisonSaved)
//                    } catch {
//                        await send(.comparisonSaveFailed(error))
//                    }
//                }
//                
//            case .comparisonSaved:
//                return .none
//                
//            case let .comparisonSaveFailed(error):
//                state.errorMessage = "Failed to save comparison: \(error.localizedDescription)"
//                return .none
//                
//            case let .streamFailed(error):
//                state.isStreaming = false
//                state.errorMessage = error.localizedDescription
//                return .none
//                
//            case .shareButtonTapped:
//                let shareText = """
//                Word Comparison: \(state.word1) vs \(state.word2)
//                
//                Context: \(state.sentence)
//                
//                Analysis:
//                \(state.streamingResponse)
//                """
//                
//                PlatformShareService.share(text: shareText)
//                return .none
//            }
//        }
//    }
//}
//
//private func buildPrompt(word1: String, word2: String, sentence: String) -> String {
//    return """
//    Help me compare the target English vocabularies "\(word1)" and "\(word2)" by telling me some simple stories that reveal what their means naturally in that specific context. And what's the key difference between them. These stories should illustrate not only the literal meaning but also the figurative meaning, if applicable.
//    
//    I'm an English learner, so tell this story at an elementary third-grade level, using only simple words and sentences, and without slang, phrasal verbs, or complex grammar.
//    
//    After the story, give any background or origin information (if it's known or useful), and explain the meaning of the vocabulary clearly.
//    
//    Finally, give 10 numbered example sentences that show the phrase used today in each context, with different tenses and sentence types, including questions. Use **bold** formatting for the target vocabulary throughout.
//
//    If there are some situations we can use both of them without changing the meaning, and some other contexts which they can't be used interchangeably, please give me examples separately.
//
//    At the end, tell me that if I can use them interchangeably in this sentence "\(sentence)"
//    
//    IMPORTANT: Format your response using proper Markdown syntax:
//    - Use ## for main headings
//    - Use ### for subheadings  
//    - Use **text** for bold formatting
//    - Use numbered lists (1. 2. 3.) for examples
//    - Use - for bullet points when appropriate
//    """
//}
////
////  ResponseDetailView.swift
////  WordsLearner
////
////  Created by Jeffrey on 11/13/25.
////
//
//import ComposableArchitecture
//import SwiftUI
//
//struct ResponseDetailView: View {
//    let store: StoreOf<ResponseDetailFeature>
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            headerSection
//            
//            ScrollViewReader { proxy in
//                ScrollView {
//                    LazyVStack(alignment: .leading, spacing: 16) {
//                        comparisonInfoCard
//                        streamingResponseView
//                        Spacer(minLength: 100)
//                    }
//                    .padding()
//                }
//                .onChange(of: store.streamingResponse) { _ in
//                    withAnimation(.easeOut(duration: 0.3)) {
//                        proxy.scrollTo("bottom", anchor: .bottom)
//                    }
//                }
//            }
//        }
//        .navigationTitle("Comparison Result")
//        #if os(iOS)
//        .navigationBarTitleDisplayMode(.inline)
//        #endif
//        .toolbar {
//            #if os(iOS)
//            ToolbarItem(placement: .navigationBarTrailing) {
//                shareButton
//            }
//            #else
//            ToolbarItem(placement: .primaryAction) {
//                shareButton
//            }
//            #endif
//        }
//        .onAppear {
//            store.send(.onAppear)
//        }
//    }
//    
//    private var headerSection: some View {
//        VStack(spacing: 0) {
//            HStack(spacing: 0) {
//                VStack(spacing: 6) {
//                    Text(store.word1)
//                        .font(.title2)
//                        .fontWeight(.bold)
//                        .foregroundColor(.blue)
//                        .multilineTextAlignment(.center)
//                        .lineLimit(2)
//                    Text("Word 1")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                }
//                .frame(maxWidth: .infinity)
//                .padding(.vertical, 12)
//                .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.1)))
//                
//                VStack {
//                    Image(systemName: "arrow.left.and.right")
//                        .font(.title3)
//                        .foregroundColor(.gray)
//                    Text("vs")
//                        .font(.caption)
//                        .fontWeight(.semibold)
//                        .foregroundColor(.gray)
//                }
//                .frame(width: 50)
//                
//                VStack(spacing: 6) {
//                    Text(store.word2)
//                        .font(.title2)
//                        .fontWeight(.bold)
//                        .foregroundColor(.green)
//                        .multilineTextAlignment(.center)
//                        .lineLimit(2)
//                    Text("Word 2")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                }
//                .frame(maxWidth: .infinity)
//                .padding(.vertical, 12)
//                .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.1)))
//            }
//            .padding(.horizontal)
//            .padding(.top)
//            
//            if store.isStreaming {
//                VStack(spacing: 8) {
//                    Divider()
//                    HStack {
//                        ProgressView().scaleEffect(0.8)
//                        Text("Generating comparison...")
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                    }
//                    .padding(.bottom, 8)
//                }
//                .padding(.horizontal)
//            } else {
//                Rectangle().fill(Color.clear).frame(height: 8)
//            }
//        }
//        .frame(maxWidth: .infinity)
//        .background(AppColors.secondaryBackground)
//    }
//    
//    private var comparisonInfoCard: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            Label("Context Sentence", systemImage: "quote.bubble")
//                .font(.headline)
//            
//            Text(store.sentence)
//                .font(.body)
//                .padding()
//                .background(
//                    RoundedRectangle(cornerRadius: 8)
//                        .fill(AppColors.cardBackground)
//                )
//        }
//    }
//    
//    private var streamingResponseView: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            Label("AI Analysis", systemImage: "brain.head.profile")
//                .font(.headline)
//            
//            if store.streamingResponse.isEmpty && !store.isStreaming {
//                ContentUnavailableView(
//                    "No Response Yet",
//                    systemImage: "text.bubble",
//                    description: Text("The AI analysis will appear here")
//                )
//            } else {
//                MarkdownText(store.streamingResponse)
//                    .padding()
//                    .background(
//                        RoundedRectangle(cornerRadius: 12)
//                            .fill(AppColors.background)
//                            .shadow(color: AppColors.separator.opacity(0.3), radius: 2, x: 0, y: 1)
//                    )
//            }
//            
//            if let errorMessage = store.errorMessage {
//                Text(errorMessage)
//                    .foregroundColor(.red)
//                    .padding()
//            }
//            
//            Color.clear.frame(height: 1).id("bottom")
//        }
//    }
//    
//    private var shareButton: some View {
//        Button {
//            store.send(.shareButtonTapped)
//        } label: {
//            Image(systemName: "square.and.arrow.up")
//        }
//        .disabled(store.streamingResponse.isEmpty)
//    }
//}
//
//#Preview {
//    NavigationStack {
//        ResponseDetailView(
//            store: Store(
//                initialState: ResponseDetailFeature.State(
//                    word1: "character",
//                    word2: "characteristic",
//                    sentence: "This is a test sentence."
//                )
//            ) {
//                ResponseDetailFeature()
//            }
//        )
//    }
//}
//
//
//
////
////  SettingsFeature.swift
////  WordsLearner
////
////  Created by Jeffrey on 11/18/25.
////
//
//import ComposableArchitecture
//import SwiftUI
//
//@Reducer
//struct SettingsFeature {
//    @ObservableState
//    struct State: Equatable {
//        var apiKeyInput: String = ""
//        var isAPIKeyVisible: Bool = false
//        var hasValidAPIKey: Bool = false
//        var currentMaskedKey: String = ""
//        @Presents var alert: AlertState<Action.Alert>?
//    }
//    
//    enum Action: BindableAction {
//        case binding(BindingAction<State>)
//        case onAppear
//        case saveButtonTapped
//        case clearButtonTapped
//        case toggleVisibilityButtonTapped
//        case alert(PresentationAction<Alert>)
//        case delegate(Delegate)
//        
//        enum Alert: Equatable {}
//        
//        enum Delegate: Equatable {
//            case apiKeyChanged
//        }
//    }
//    
//    @Dependency(\.apiKeyManager) var apiKeyManager
//    @Dependency(\.dismiss) var dismiss
//    
//    var body: some Reducer<State, Action> {
//        BindingReducer()
//        
//        Reduce { state, action in
//            switch action {
//            case .onAppear:
//                let currentKey = apiKeyManager.getAPIKey()
//                state.hasValidAPIKey = !currentKey.isEmpty
//                if !currentKey.isEmpty {
//                    state.apiKeyInput = currentKey
//                    state.currentMaskedKey = maskAPIKey(currentKey)
//                }
//                return .none
//                
//            case .saveButtonTapped:
//                let trimmedKey = state.apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
//                
//                guard apiKeyManager.validateAPIKey(trimmedKey) else {
//                    state.alert = AlertState {
//                        TextState("Invalid API Key")
//                    } actions: {
//                        ButtonState(role: .cancel) {
//                            TextState("OK")
//                        }
//                    } message: {
//                        TextState("Please enter a valid API key")
//                    }
//                    return .none
//                }
//                
//                if apiKeyManager.saveAPIKey(trimmedKey) {
//                    state.hasValidAPIKey = true
//                    state.currentMaskedKey = maskAPIKey(trimmedKey)
//                    state.alert = AlertState {
//                        TextState("Success")
//                    } actions: {
//                        ButtonState(role: .cancel) {
//                            TextState("OK")
//                        }
//                    } message: {
//                        TextState("API key saved successfully")
//                    }
//                    return .send(.delegate(.apiKeyChanged))
//                } else {
//                    state.alert = AlertState {
//                        TextState("Error")
//                    } actions: {
//                        ButtonState(role: .cancel) {
//                            TextState("OK")
//                        }
//                    } message: {
//                        TextState("Failed to save API key. Please try again.")
//                    }
//                    return .none
//                }
//                
//            case .clearButtonTapped:
//                if apiKeyManager.deleteAPIKey() {
//                    state.apiKeyInput = ""
//                    state.hasValidAPIKey = false
//                    state.currentMaskedKey = ""
//                    state.alert = AlertState {
//                        TextState("Success")
//                    } actions: {
//                        ButtonState(role: .cancel) {
//                            TextState("OK")
//                        }
//                    } message: {
//                        TextState("API key cleared successfully")
//                    }
//                    return .send(.delegate(.apiKeyChanged))
//                }
//                return .none
//                
//            case .toggleVisibilityButtonTapped:
//                state.isAPIKeyVisible.toggle()
//                return .none
//                
//            case .alert:
//                return .none
//                
//            case .delegate:
//                return .none
//                
//            case .binding:
//                return .none
//            }
//        }
//        .ifLet(\.$alert, action: \.alert)
//    }
//}
//
//private func maskAPIKey(_ key: String) -> String {
//    guard key.count > 8 else { return "••••••••" }
//    let start = String(key.prefix(4))
//    let end = String(key.suffix(4))
//    return "\(start)••••••••\(end)"
//}
//
////
////  SettingsView.swift
////  WordsLearner
////
////  Created by Jeffrey on 11/13/25.
////
//
//import ComposableArchitecture
//import SwiftUI
//
//struct SettingsView: View {
//    @Bindable var store: StoreOf<SettingsFeature>
//    @Environment(\.dismiss) private var dismiss
//    
//    var body: some View {
//        #if os(macOS)
//        macOSView
//        #else
//        iOSView
//        #endif
//    }
//    
//    // MARK: - iOS View
//    #if os(iOS)
//    private var iOSView: some View {
//        NavigationStack {
//            Form {
//                Section {
//                    headerSection
//                } header: {
//                    Label("API Configuration", systemImage: "key.fill")
//                }
//                
//                Section {
//                    apiKeyInputSection
//                } header: {
//                    Text("AIHubMix API Key")
//                } footer: {
//                    Text("Your API key is stored securely in the device keychain and never shared.")
//                        .font(.caption)
//                }
//                
//                Section {
//                    statusSection
//                } header: {
//                    Text("Status")
//                }
//                
//                Section {
//                    helpSection
//                } header: {
//                    Text("Help")
//                }
//            }
//            .navigationTitle("Settings")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .cancellationAction) {
//                    Button("Cancel") { dismiss() }
//                }
//                
//                ToolbarItem(placement: .confirmationAction) {
//                    Button("Done") { dismiss() }
//                        .fontWeight(.semibold)
//                }
//            }
//        }
//        .onAppear { store.send(.onAppear) }
//        .alert($store.scope(state: \.alert, action: \.alert))
//    }
//    #endif
//    
//    // MARK: - macOS View
//    #if os(macOS)
//    private var macOSView: some View {
//        VStack(spacing: 0) {
//            headerBar
//            ScrollView {
//                VStack(spacing: 24) {
//                    headerSection
//                    apiKeySection
//                    statusSection
//                    helpSection
//                }
//                .frame(maxWidth: 600)
//                .padding(.horizontal, 40)
//                .padding(.vertical, 20)
//            }
//        }
//        .frame(minWidth: 600, minHeight: 500)
//        .onAppear { store.send(.onAppear) }
//        .alert($store.scope(state: \.alert, action: \.alert))
//    }
//    
//    private var headerBar: some View {
//        HStack {
//            Button("Cancel") { dismiss() }
//            Spacer()
//            Text("Settings").font(.headline)
//            Spacer()
//            Button("Done") { dismiss() }
//                .buttonStyle(.borderedProminent)
//        }
//        .padding()
//    }
//    
//    private var apiKeySection: some View {
//        GroupBox {
//            VStack(alignment: .leading, spacing: 16) {
//                VStack(alignment: .leading, spacing: 8) {
//                    Text("AIHubMix API Key").font(.headline)
//                    Text("Enter your API key to enable word comparison features")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                }
//                
//                HStack(spacing: 12) {
//                    Group {
//                        if store.isAPIKeyVisible {
//                            TextField("Enter your API key", text: $store.apiKeyInput)
//                        } else {
//                            SecureField("Enter your API key", text: $store.apiKeyInput)
//                        }
//                    }
//                    .textFieldStyle(.roundedBorder)
//                    
//                    Button { store.send(.toggleVisibilityButtonTapped) } label: {
//                        Image(systemName: store.isAPIKeyVisible ? "eye.slash" : "eye")
//                    }
//                }
//                
//                HStack(spacing: 12) {
//                    Button("Save") { store.send(.saveButtonTapped) }
//                        .buttonStyle(.borderedProminent)
//                        .disabled(store.apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
//                    
//                    Button("Clear") { store.send(.clearButtonTapped) }
//                        .buttonStyle(.bordered)
//                        .foregroundColor(.red)
//                    
//                    Spacer()
//                }
//            }
//            .padding(16)
//        }
//    }
//    #endif
//    
//    // MARK: - Shared Components
//    private var headerSection: some View {
//        VStack(alignment: .center, spacing: 12) {
//            Image(systemName: "key.radiowaves.forward")
//                .font(.system(size: 40))
//                .foregroundColor(AppColors.primary)
//            
//            Text("API Key Configuration")
//                .font(.title2)
//                .fontWeight(.semibold)
//            
//            Text("Enter your AIHubMix API key to enable word comparison features")
//                .font(.caption)
//                .foregroundColor(AppColors.secondaryText)
//                .multilineTextAlignment(.center)
//        }
//        .frame(maxWidth: .infinity)
//        .padding(.vertical)
//    }
//    
//    private var apiKeyInputSection: some View {
//        VStack(spacing: 12) {
//            HStack {
//                if store.isAPIKeyVisible {
//                    TextField("Enter your API key", text: $store.apiKeyInput)
//                        .textFieldStyle(.roundedBorder)
//                } else {
//                    SecureField("Enter your API key", text: $store.apiKeyInput)
//                        .textFieldStyle(.roundedBorder)
//                }
//                
//                Button { store.send(.toggleVisibilityButtonTapped) } label: {
//                    Image(systemName: store.isAPIKeyVisible ? "eye.slash" : "eye")
//                        .foregroundColor(AppColors.secondaryText)
//                }
//            }
//            
//            HStack(spacing: 12) {
//                Button("Save") { store.send(.saveButtonTapped) }
//                    .buttonStyle(.borderedProminent)
//                    .disabled(store.apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
//                
//                Button("Clear") { store.send(.clearButtonTapped) }
//                    .buttonStyle(.bordered)
//                    .foregroundColor(AppColors.error)
//                
//                Spacer()
//            }
//        }
//    }
//    
//    private var statusSection: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            HStack {
//                Circle()
//                    .fill(store.hasValidAPIKey ? AppColors.success : AppColors.error)
//                    .frame(width: 12, height: 12)
//                
//                Text(store.hasValidAPIKey ? "API Key Configured" : "No API Key")
//                    .font(.subheadline)
//                    .fontWeight(.medium)
//                
//                Spacer()
//            }
//            
//            if store.hasValidAPIKey && !store.currentMaskedKey.isEmpty {
//                Text("Current key: \(store.currentMaskedKey)")
//                    .font(.caption)
//                    .foregroundColor(AppColors.secondaryText)
//                    .fontDesign(.monospaced)
//            }
//        }
//    }
//    
//    private var helpSection: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            Link(destination: URL(string: "https://aihubmix.com")!) {
//                Label("Get API Key from AIHubMix", systemImage: "link")
//                    .foregroundColor(AppColors.primary)
//            }
//            
//            Link(destination: URL(string: "https://aihubmix.com/docs")!) {
//                Label("API Documentation", systemImage: "book")
//                    .foregroundColor(AppColors.primary)
//            }
//        }
//    }
//}
//
//#Preview {
//    SettingsView(
//        store: Store(initialState: SettingsFeature.State()) {
//            SettingsFeature()
//        }
//    )
//}
//
//
////
////  WordComparatorFeature.swift
////  WordsLearner
////
////  Created by Jeffrey on 11/18/25.
////
//
//import ComposableArchitecture
//import Foundation
//import SQLiteData
//
//@Reducer
//struct WordComparatorFeature {
//    
//    @Reducer
//    enum Path {
//        case detail(ResponseDetailFeature)
//        case historyList(ComparisonHistoryListFeature)
//    }
//    
//    struct BackgroundTask: Equatable, Identifiable {
//        let id: UUID
//        let word1: String
//        let word2: String
//        let sentence: String
//        var status: Status
//        var response: String = ""
//        var error: String?
//        
//        enum Status: Equatable {
//            case pending
//            case generating
//            case completed
//            case failed
//        }
//        
//        init(id: UUID = UUID(), word1: String, word2: String, sentence: String, status: Status = .pending) {
//            self.id = id
//            self.word1 = word1
//            self.word2 = word2
//            self.sentence = sentence
//            self.status = status
//        }
//    }
//    
//    @ObservableState
//    struct State: Equatable {
//        var word1: String = ""
//        var word2: String = ""
//        var sentence: String = ""
//        var hasValidAPIKey: Bool = false
//        
//        var recentComparisons = RecentComparisonsFeature.State()
//        
//        var path = StackState<Path.State>()
//        @Presents var settings: SettingsFeature.State?
//        
//        // Background generation state
//        var backgroundTasks: [BackgroundTask] = []
//        var currentGeneratingTaskId: UUID?
//        @Presents var alert: AlertState<Action.Alert>?
//        
//        var isGeneratingInBackground: Bool {
//            currentGeneratingTaskId != nil
//        }
//        
//        var pendingTasksCount: Int {
//            backgroundTasks.filter { $0.status == .pending }.count
//        }
//        
//        var canGenerate: Bool {
//            !word1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
//            !word2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
//            !sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
//        }
//    }
//    
//    enum Action: BindableAction {
//        case binding(BindingAction<State>)
//        case onAppear
//        case generateButtonTapped
//        case generateInBackgroundButtonTapped
//        case settingsButtonTapped
//        case historyListButtonTapped
//        case path(StackActionOf<Path>)
//        case settings(PresentationAction<SettingsFeature.Action>)
//        case apiKeyStatusChanged(Bool)
//        case recentComparisons(RecentComparisonsFeature.Action)
//        case alert(PresentationAction<Alert>)
//        case backgroundTaskAdded(BackgroundTask)
//        case processNextBackgroundTask
//        case backgroundTaskStarted(UUID)
//        case backgroundTaskCompleted(UUID, String)
//        case backgroundTaskFailed(UUID, Error)
//        case backgroundTaskSaved(UUID)
//        case removeBackgroundTask(UUID)
//        case clearCompletedTasks
//        case clearInputFields
//        
//        enum Alert: Equatable {
//            case taskAddedToQueue(Int)
//        }
//    }
//    
//    @Dependency(\.apiKeyManager) var apiKeyManager
//    @Dependency(\.defaultDatabase) var database
//    @Dependency(\.aiService) var aiService
//    @Dependency(\.date.now) var now
//    @Dependency(\.uuid) var uuid
//    
//    var body: some Reducer<State, Action> {
//        BindingReducer()
//        
//        Scope(state: \.recentComparisons, action: \.recentComparisons) {
//            RecentComparisonsFeature()
//        }
//        
//        Reduce { state, action in
//            switch action {
//            case .onAppear:
//                state.hasValidAPIKey = apiKeyManager.hasValidAPIKey()
//                return .none
//                
//            case .settingsButtonTapped:
//                state.settings = SettingsFeature.State()
//                return .none
//                
//            case .generateButtonTapped:
//                guard state.canGenerate && state.hasValidAPIKey else { return .none }
//                
//                let word1 = state.word1
//                let word2 = state.word2
//                let sentence = state.sentence
//                
//                state.path.append(.detail(
//                    ResponseDetailFeature.State(
//                        word1: word1,
//                        word2: word2,
//                        sentence: sentence
//                    )
//                ))
//                
//                return .send(.clearInputFields)
//                
//            case .generateInBackgroundButtonTapped:
//                guard state.canGenerate && state.hasValidAPIKey else { return .none }
//                
//                let task = BackgroundTask(
//                    id: uuid(),
//                    word1: state.word1,
//                    word2: state.word2,
//                    sentence: state.sentence
//                )
//                return .concatenate(
//                    [
//                        .send(.clearInputFields),
//                        .send(.backgroundTaskAdded(task))
//                    ]
//                )
//                
//            case .clearInputFields:
//                state.word1 = ""
//                state.word2 = ""
//                state.sentence = ""
//                return .none
//                
//            case let .backgroundTaskAdded(task):
//                state.backgroundTasks.append(task)
//                let queuePosition = state.pendingTasksCount
//                state.alert = AlertState {
//                    TextState("Task Added")
//                } actions: {
//                    ButtonState(role: .cancel, action: .taskAddedToQueue(queuePosition)) {
//                        TextState("OK")
//                    }
//                } message: {
//                    TextState("Comparison task added to queue. Position: \(queuePosition)")
//                }
//                
//                if state.currentGeneratingTaskId == nil {
//                    return .send(.processNextBackgroundTask)
//                }
//                return .none
//                
//            case .processNextBackgroundTask:
//                guard let nextTask = state.backgroundTasks.first(where: { $0.status == .pending }) else {
//                    state.currentGeneratingTaskId = nil
//                    return .none
//                }
//                
//                return .send(.backgroundTaskStarted(nextTask.id))
//                
//            case let .backgroundTaskStarted(taskId):
//                guard let taskIndex = state.backgroundTasks.firstIndex(where: { $0.id == taskId }) else {
//                    return .none
//                }
//                
//                state.backgroundTasks[taskIndex].status = .generating
//                state.currentGeneratingTaskId = taskId
//                
//                let task = state.backgroundTasks[taskIndex]
//                let prompt = buildPrompt(word1: task.word1, word2: task.word2, sentence: task.sentence)
//                
//                return .run { send in
//                    do {
//                        var fullResponse = ""
//                        for try await chunk in aiService.streamResponse(prompt) {
//                            fullResponse += chunk
//                        }
//                        await send(.backgroundTaskCompleted(taskId, fullResponse))
//                    } catch {
//                        await send(.backgroundTaskFailed(taskId, error))
//                    }
//                }
//                
//            case let .backgroundTaskCompleted(taskId, response):
//                guard let taskIndex = state.backgroundTasks.firstIndex(where: { $0.id == taskId }) else {
//                    return .none
//                }
//                
//                state.backgroundTasks[taskIndex].status = .completed
//                state.backgroundTasks[taskIndex].response = response
//                state.currentGeneratingTaskId = nil
//                
//                let task = state.backgroundTasks[taskIndex]
//                let draft = ComparisonHistory.Draft(
//                    word1: task.word1,
//                    word2: task.word2,
//                    sentence: task.sentence,
//                    response: response,
//                    date: now
//                )
//                
//                return .run { send in
//                    do {
//                        try await database.write { db in
//                            try ComparisonHistory.insert {
//                                draft
//                            }
//                            .execute(db)
//                        }
//                        await send(.backgroundTaskSaved(taskId))
//                    } catch {
//                        await send(.backgroundTaskFailed(taskId, error))
//                    }
//                }
//                
//            case let .backgroundTaskSaved(taskId):
//                return .run { send in
//                    try await Task.sleep(for: .milliseconds(500))
//                    await send(.processNextBackgroundTask)
//                }
//                
//            case let .backgroundTaskFailed(taskId, error):
//                guard let taskIndex = state.backgroundTasks.firstIndex(where: { $0.id == taskId }) else {
//                    return .none
//                }
//                
//                state.backgroundTasks[taskIndex].status = .failed
//                state.backgroundTasks[taskIndex].error = error.localizedDescription
//                state.currentGeneratingTaskId = nil
//                
//                return .send(.processNextBackgroundTask)
//                
//            case let .removeBackgroundTask(taskId):
//                state.backgroundTasks.removeAll { $0.id == taskId }
//                return .none
//                
//            case .clearCompletedTasks:
//                state.backgroundTasks.removeAll {
//                    $0.status == .completed || $0.status == .failed
//                }
//                return .none
//                
//            case .historyListButtonTapped:
//                state.path.append(.historyList(ComparisonHistoryListFeature.State()))
//                return .none
//                
//            case let .apiKeyStatusChanged(hasKey):
//                state.hasValidAPIKey = hasKey
//                return .none
//                
//            case .settings(.presented(.delegate(.apiKeyChanged))):
//                state.hasValidAPIKey = apiKeyManager.hasValidAPIKey()
//                return .none
//                
//            case let .recentComparisons(.delegate(.comparisonSelected(comparison))):
//                state.path.append(.detail(
//                    ResponseDetailFeature.State(
//                        word1: comparison.word1,
//                        word2: comparison.word2,
//                        sentence: comparison.sentence,
//                        streamingResponse: comparison.response,
//                        shouldStartStreaming: false
//                    )
//                ))
//                return .none
//                
//            case let .path(action):
//                switch action {
//                case .element(id: _, action: .historyList(.delegate(.comparisonSelected(let comparison)))):
//                    state.word1 = comparison.word1
//                    state.word2 = comparison.word2
//                    state.sentence = comparison.sentence
//                    state.path.append(.detail(
//                        ResponseDetailFeature.State(
//                            word1: comparison.word1,
//                            word2: comparison.word2,
//                            sentence: comparison.sentence,
//                            streamingResponse: comparison.response,
//                            shouldStartStreaming: false
//                        )
//                    ))
//                    return .none
//                    
//                default:
//                    return .none
//                }
//                
//            case .recentComparisons:
//                return .none
//                
//            case .path:
//                return .none
//                
//            case .settings:
//                return .none
//                
//            case .alert:
//                return .none
//                
//            case .binding:
//                return .none
//            }
//        }
//        .forEach(\.path, action: \.path)
//        .ifLet(\.$settings, action: \.settings) {
//            SettingsFeature()
//        }
//        .ifLet(\.$alert, action: \.alert)
//    }
//}
//
//extension WordComparatorFeature.Path.State: Equatable {}
//
//private func buildPrompt(word1: String, word2: String, sentence: String) -> String {
//    return """
//    Help me compare the target English vocabularies "\(word1)" and "\(word2)" by telling me some simple stories that reveal what their means naturally in that specific context. And what's the key difference between them. These stories should illustrate not only the literal meaning but also the figurative meaning, if applicable.
//    
//    I'm an English learner, so tell this story at an elementary third-grade level, using only simple words and sentences, and without slang, phrasal verbs, or complex grammar.
//    
//    After the story, give any background or origin information (if it's known or useful), and explain the meaning of the vocabulary clearly.
//    
//    Finally, give 10 numbered example sentences that show the phrase used today in each context, with different tenses and sentence types, including questions. Use **bold** formatting for the target vocabulary throughout.
//
//    If there are some situations we can use both of them without changing the meaning, and some other contexts which they can't be used interchangeably, please give me examples separately.
//
//    At the end, tell me that if I can use them interchangeably in this sentence "\(sentence)"
//    
//    IMPORTANT: Format your response using proper Markdown syntax:
//    - Use ## for main headings
//    - Use ### for subheadings  
//    - Use **text** for bold formatting
//    - Use numbered lists (1. 2. 3.) for examples
//    - Use - for bullet points when appropriate
//    """
//}
////
////  ContentView.swift
////  WordsLearner
////
////  Created by Jeffrey on 11/12/25.
////
//
//import ComposableArchitecture
//import SwiftUI
//import SQLiteData
//
//struct WordComparatorMainView: View {
//    @Bindable var store: StoreOf<WordComparatorFeature>
//    
//    var body: some View {
//        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
//            ScrollView {
//                VStack(spacing: 20) {
//                    headerView
//                    
//                    if !store.hasValidAPIKey {
//                        apiKeyWarningView
//                    }
//                    
//                    inputFieldsView
//                    generateButtonsView
//                    
//                    if !store.backgroundTasks.isEmpty {
//                        backgroundTasksQueueView
//                    }
//                    
//                    RecentComparisonsView(
//                        store: store.scope(
//                            state: \.recentComparisons,
//                            action: \.recentComparisons
//                        )
//                    )
//                }
//                .padding()
//            }
//            .navigationTitle("Word Comparator")
//            #if os(iOS)
//            .navigationBarTitleDisplayMode(.large)
//            #endif
//            .toolbar {
//                #if os(iOS)
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    HStack(spacing: 16) {
//                        historyButton
//                        settingsButton
//                    }
//                }
//                #else
//                ToolbarItem(placement: .primaryAction) {
//                    HStack(spacing: 12) {
//                        historyButton
//                        settingsButton
//                    }
//                }
//                #endif
//            }
//            .onAppear {
//                store.send(.onAppear)
//            }
//        } destination: { store in
//            switch store.case {
//            case let .detail(detailStore):
//                ResponseDetailView(store: detailStore)
//            case let .historyList(historyStore):
//                ComparisonHistoryListView(store: historyStore)
//            }
//        }
//        .sheet(
//            item: $store.scope(state: \.settings, action: \.settings)
//        ) { settingsStore in
//            SettingsView(store: settingsStore)
//        }
//        .alert($store.scope(state: \.alert, action: \.alert))
//    }
//    
//    private var historyButton: some View {
//        Button {
//            store.send(.historyListButtonTapped)
//        } label: {
//            Image(systemName: "clock")
//                .foregroundColor(.primary)
//        }
//    }
//    
//    private var settingsButton: some View {
//        Button {
//            store.send(.settingsButtonTapped)
//        } label: {
//            Image(systemName: "gear")
//                .foregroundColor(.primary)
//        }
//    }
//    
//    private var headerView: some View {
//        VStack(spacing: 8) {
//            Image(systemName: "text.book.closed")
//                .font(.system(size: 40))
//                .foregroundColor(.blue)
//            
//            Text("AI English Word Comparator")
//                .font(.title2)
//                .fontWeight(.semibold)
//            
//            Text("Compare similar English words with AI assistance")
//                .font(.caption)
//                .foregroundColor(.secondary)
//                .multilineTextAlignment(.center)
//        }
//        .padding(.top)
//    }
//    
//    private var apiKeyWarningView: some View {
//        VStack(spacing: 8) {
//            HStack {
//                Image(systemName: "exclamationmark.triangle.fill")
//                    .foregroundColor(.orange)
//                
//                Text("API Key Required")
//                    .font(.headline)
//                    .foregroundColor(.orange)
//            }
//            
//            Text("Please configure your AIHubMix API key in settings to use this app")
//                .font(.caption)
//                .foregroundColor(.secondary)
//                .multilineTextAlignment(.center)
//            
//            Button("Open Settings") {
//                store.send(.settingsButtonTapped)
//            }
//            .buttonStyle(.borderedProminent)
//            .controlSize(.small)
//        }
//        .padding()
//        .background(
//            RoundedRectangle(cornerRadius: 12)
//                .fill(AppColors.warning.opacity(0.1))
//        )
//    }
//    
//    private var inputFieldsView: some View {
//        VStack(spacing: 16) {
//            VStack(alignment: .leading, spacing: 8) {
//                Label("First Word", systemImage: "1.circle")
//                    .font(.headline)
//                
//                TextField("Enter first word (e.g., character)", text: $store.word1)
//                    .textFieldStyle(CustomTextFieldStyle())
//            }
//            
//            VStack(alignment: .leading, spacing: 8) {
//                Label("Second Word", systemImage: "2.circle")
//                    .font(.headline)
//                
//                TextField("Enter second word (e.g., characteristics)", text: $store.word2)
//                    .textFieldStyle(CustomTextFieldStyle())
//            }
//            
//            VStack(alignment: .leading, spacing: 8) {
//                Label("Context Sentence", systemImage: "text.quote")
//                    .font(.headline)
//                
//                TextField("Paste the sentence here", text: $store.sentence, axis: .vertical)
//                    .textFieldStyle(CustomTextFieldStyle())
//                    .lineLimit(3...6)
//            }
//        }
//        .padding(.horizontal, 4)
//    }
//    
//    private var generateButtonsView: some View {
//        HStack(spacing: 12) {
//            Button {
//                store.send(.generateButtonTapped)
//            } label: {
//                HStack {
//                    Image(systemName: "sparkles")
//                    Text("Generate")
//                        .fontWeight(.semibold)
//                }
//                .frame(maxWidth: .infinity)
//                .padding()
//                .background(
//                    RoundedRectangle(cornerRadius: 12)
//                        .fill((store.canGenerate && store.hasValidAPIKey) ? AppColors.primary : AppColors.separator)
//                )
//                .foregroundColor((store.canGenerate && store.hasValidAPIKey) ? .white : .gray)
//            }
//            .disabled(!store.canGenerate || !store.hasValidAPIKey)
//            
//            Button {
//                store.send(.generateInBackgroundButtonTapped)
//            } label: {
//                HStack(spacing: 6) {
//                    Image(systemName: "arrow.down.circle")
//                    
//                    #if os(iOS)
//                    if horizontalSizeClass == .regular {
//                        Text("Background")
//                            .fontWeight(.semibold)
//                    }
//                    #else
//                    Text("Background")
//                        .fontWeight(.semibold)
//                    #endif
//                    
//                    if store.pendingTasksCount > 0 {
//                        Text("(\(store.pendingTasksCount))")
//                            .font(.caption)
//                            .fontWeight(.bold)
//                    }
//                }
//                .frame(minWidth: platformButtonWidth())
//                .padding()
//                .background(
//                    RoundedRectangle(cornerRadius: 12)
//                        .fill((store.canGenerate && store.hasValidAPIKey) ?
//                              AppColors.secondary : AppColors.separator)
//                )
//                .foregroundColor((store.canGenerate && store.hasValidAPIKey) ?
//                                .white : .gray)
//            }
//            .disabled(!store.canGenerate || !store.hasValidAPIKey)
//        }
//    }
//    
//    private var backgroundTasksQueueView: some View {
//        VStack(spacing: 12) {
//            HStack {
//                Label("Background Tasks", systemImage: "list.bullet.rectangle")
//                    .font(.headline)
//                    .foregroundColor(AppColors.primaryText)
//                
//                Spacer()
//                
//                Button {
//                    store.send(.clearCompletedTasks)
//                } label: {
//                    Text("Clear Completed")
//                        .font(.caption)
//                        .foregroundColor(AppColors.primary)
//                }
//            }
//            
//            LazyVStack(spacing: 8) {
//                ForEach(store.backgroundTasks) { task in
//                    BackgroundTaskRow(
//                        task: task,
//                        onRemove: {
//                            store.send(.removeBackgroundTask(task.id))
//                        }
//                    )
//                }
//            }
//        }
//        .padding()
//        .background(
//            RoundedRectangle(cornerRadius: 12)
//                .fill(AppColors.cardBackground)
//                .shadow(color: AppColors.cardShadow.opacity(0.1), radius: 2, x: 0, y: 1)
//        )
//    }
//    
//    #if os(iOS)
//    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
//    #endif
//    
//    private func platformButtonWidth() -> CGFloat {
//        #if os(iOS)
//        return 50
//        #else
//        return 120
//        #endif
//    }
//}
//
//#Preview {
//    let _ = prepareDependencies {
//        $0.defaultDatabase = .testDatabase
//    }
//    
//    WordComparatorMainView(
//        store: Store(initialState: WordComparatorFeature.State()) {
//            WordComparatorFeature()
//        }
//    )
//}
//
////
////  APIKeyManager.swift
////  WordsLearner
////
////  Created by Jeffrey on 11/13/25.
////
//
//import Foundation
//import Security
//import Combine
//
//class APIKeyManager: ObservableObject {
//    @Published var hasValidAPIKey: Bool = false
//    
//    private let service = "EnglishWordComparatorApp"
//    private let account = "aihubmix-api-key"
//    
//    static let shared: APIKeyManager = .init()
//    
//    private init() {
//        hasValidAPIKey = !getAPIKey().isEmpty
//    }
//    
//    func saveAPIKey(_ key: String) -> Bool {
//        let keyData = key.data(using: .utf8)!
//        
//        // Delete any existing key first
//        deleteAPIKey()
//        
//        let query: [String: Any] = [
//            kSecClass as String: kSecClassGenericPassword,
//            kSecAttrService as String: service,
//            kSecAttrAccount as String: account,
//            kSecValueData as String: keyData,
//            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
//        ]
//        
//        let status = SecItemAdd(query as CFDictionary, nil)
//        let success = status == errSecSuccess
//        
//        if success {
//            hasValidAPIKey = !key.isEmpty
//        }
//        
//        return success
//    }
//    
//    func getAPIKey() -> String {
//        let query: [String: Any] = [
//            kSecClass as String: kSecClassGenericPassword,
//            kSecAttrService as String: service,
//            kSecAttrAccount as String: account,
//            kSecReturnData as String: kCFBooleanTrue!,
//            kSecMatchLimit as String: kSecMatchLimitOne
//        ]
//        
//        var result: AnyObject?
//        let status = SecItemCopyMatching(query as CFDictionary, &result)
//        
//        if status == errSecSuccess,
//           let data = result as? Data,
//           let apiKey = String(data: data, encoding: .utf8) {
//            return apiKey
//        }
//        
//        return ""
//    }
//    
//    func deleteAPIKey() -> Bool {
//        let query: [String: Any] = [
//            kSecClass as String: kSecClassGenericPassword,
//            kSecAttrService as String: service,
//            kSecAttrAccount as String: account
//        ]
//        
//        let status = SecItemDelete(query as CFDictionary)
//        let success = status == errSecSuccess || status == errSecItemNotFound
//        
//        if success {
//            hasValidAPIKey = false
//        }
//        
//        return success
//    }
//    
//    func validateAPIKey(_ key: String) -> Bool {
//        // Basic validation - you can make this more sophisticated
//        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
//               key.count > 10 && // Reasonable minimum length
//               !key.contains(" ") // API keys typically don't have spaces
//    }
//}
//
////
////  AppColors.swift
////  WordsLearner
////
////  Created by Jeffrey on 11/17/25.
////
//
//import SwiftUI
//
//struct AppColors {
//    
//    // MARK: - Primary Colors
//    static let primary = Color("Primary")
//    static let secondary = Color("Secondary")
//    static let accent = Color("Accent")
//    
//    // MARK: - Background Colors
//    static let background = Color("Background")
//    static let secondaryBackground = Color("SecondaryBackground")
//    static let tertiaryBackground = Color("TertiaryBackground")
//    static let cardBackground = Color("CardBackground")
//    
//    // MARK: - Text Colors
//    static let primaryText = Color("PrimaryText")
//    static let secondaryText = Color("SecondaryText")
//    static let tertiaryText = Color("TertiaryText")
//    
//    // MARK: - Semantic Colors
//    static let success = Color("Success")
//    static let warning = Color("Warning")
//    static let error = Color("Error")
//    static let info = Color("Info")
//    
//    // MARK: - Word Comparison Specific
//    static let word1Color = Color("Word1Color")
//    static let word2Color = Color("Word2Color")
//    static let word1Background = Color("Word1Background")
//    static let word2Background = Color("Word2Background")
//    
//    // MARK: - Interactive Elements
//    static let buttonBackground = Color("ButtonBackground")
//    static let buttonText = Color("ButtonText")
//    static let fieldBackground = Color("FieldBackground")
//    static let fieldBorder = Color("FieldBorder")
//    static let separator = Color("Separator")
//    
//    // MARK: - List & Card Colors
//    static let listRowBackground = Color("ListRowBackground")
//    static let cardShadow = Color("CardShadow")
//    static let hoverBackground = Color("HoverBackground")
//    
//    // MARK: - System Fallbacks (for compatibility)
//    static let systemGray6Fallback: Color = {
//        #if os(iOS)
//        return Color(.systemGray6)
//        #else
//        return Color(.windowBackgroundColor).opacity(0.6)
//        #endif
//    }()
//    
//    static let systemGray4Fallback: Color = {
//        #if os(iOS)
//        return Color(.systemGray4)
//        #else
//        return Color(.separatorColor)
//        #endif
//    }()
//    
//    static let systemBackgroundFallback: Color = {
//        #if os(iOS)
//        return Color(.systemBackground)
//        #else
//        return Color(.windowBackgroundColor)
//        #endif
//    }()
//    
//    // MARK: - Dynamic Colors for Cross-Platform
//    static let dynamicCardBackground: Color = {
//        #if os(iOS)
//        return cardBackground
//        #else
//        return cardBackground.opacity(0.8)
//        #endif
//    }()
//    
//    static let dynamicSeparator: Color = {
//        #if os(iOS)
//        return separator
//        #else
//        return separator.opacity(0.6)
//        #endif
//    }()
//}
//
//// MARK: - Color Extensions
//extension AppColors {
//    #if canImport(UIKit)
//    /// Creates a color with light and dark mode variants
//    static func adaptive(light: Color, dark: Color) -> Color {
//        Color(UIColor { traitCollection in
//            traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
//        })
//    }
//    #endif
//    
//    /// Creates a color with different variants for iOS and macOS
//    static func platform(ios: Color, mac: Color) -> Color {
//        #if os(iOS)
//        return ios
//        #else
//        return mac
//        #endif
//    }
//}
////
////  ComparisonHistory.swift
////  WordsLearner
////
////  Created by Jeffrey on 11/18/25.
////
//
//import Foundation
//import SQLiteData
//
//@Table
//nonisolated struct ComparisonHistory: Identifiable, Equatable {
//    let id: UUID
//    var word1: String
//    var word2: String
//    var sentence: String
//    var response: String
//    var date: Date
//}
//
//extension ComparisonHistory.Draft: Identifiable {}
////
////  CustomTextFieldStyle.swift
////  WordsLearner
////
////  Created by Jeffrey on 11/12/25.
////
//
//import SwiftUI
//
//struct CustomTextFieldStyle: TextFieldStyle {
//    func _body(configuration: TextField<Self._Label>) -> some View {
//        configuration
//            .padding()
//            .background(
//                RoundedRectangle(cornerRadius: 12)
//                    .fill(AppColors.fieldBackground)
//                    .stroke(AppColors.fieldBorder, lineWidth: 1)
//            )
//    }
//}
////
////  DatabaseConfiguration.swift
////  WordsLearner
////
////  Created by Jeffrey on 11/19/25.
////
//
//import Dependencies
//import Foundation
//import IssueReporting
//import OSLog
//import SQLiteData
//
//private let logger = Logger(subsystem: "WordsLearner", category: "Database")
//
//extension DependencyValues {
//    /// Bootstrap the app database
//    mutating func bootstrapDatabase() throws {
//        @Dependency(\.context) var context
//        
//        let database = try createAppDatabase()
//        
//        logger.debug(
//            """
//            App database:
//            open "\(database.path)"
//            """
//        )
//        
//        defaultDatabase = database
//        
//        // Optional: Configure sync engine for CloudKit
//        // defaultSyncEngine = try SyncEngine(
//        //     for: defaultDatabase,
//        //     tables: ComparisonHistory.self
//        // )
//    }
//}
//
///// Creates and configures the app database
//private func createAppDatabase() throws -> any DatabaseWriter {
//    @Dependency(\.context) var context
//    
//    var configuration = Configuration()
//    configuration.foreignKeysEnabled = true
//    
//    #if DEBUG
//    configuration.prepareDatabase { db in
//        db.trace(options: .profile) { event in
//            if context == .live {
//                logger.debug("\(event.expandedDescription)")
//            } else {
//                print("\(event.expandedDescription)")
//            }
//        }
//    }
//    #endif // DEBUG
//    
//    let database = try SQLiteData.defaultDatabase(configuration: configuration)
//    
//    var migrator = DatabaseMigrator()
//    
//    #if DEBUG
//    migrator.eraseDatabaseOnSchemaChange = true
//    #endif
//    
//    // Register migrations
//    migrator.registerMigration("v1.0 - Create comparisonHistories table") { db in
//        try #sql(
//            """
//            CREATE TABLE "comparisonHistories" (
//                "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
//                "word1" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
//                "word2" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
//                "sentence" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
//                "response" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
//                "date" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT CURRENT_TIMESTAMP
//            ) STRICT
//            """
//        )
//        .execute(db)
//        
//        // Create index for faster date-based queries
//        try #sql(
//            """
//            CREATE INDEX "idx_comparisonHistories_date" 
//            ON "comparisonHistories" ("date" DESC)
//            """
//        )
//        .execute(db)
//        
//        // Create index for word searches
//        try #sql(
//            """
//            CREATE INDEX "idx_comparisonHistories_words" 
//            ON "comparisonHistories" ("word1", "word2")
//            """
//        )
//        .execute(db)
//    }
//    
//    // Optional: Create Full-Text Search table for advanced search
//    migrator.registerMigration("v1.1 - Create FTS table") { db in
//        try #sql(
//            """
//            CREATE VIRTUAL TABLE "comparisonHistories_fts" USING fts5(
//                "word1",
//                "word2",
//                "sentence",
//                "response",
//                content="comparisonHistories",
//                content_rowid="rowid"
//            )
//            """
//        )
//        .execute(db)
//        
//        // Create triggers to keep FTS in sync
//        try ComparisonHistory.createTemporaryTrigger(
//            after: .insert { new in
//                #sql(
//                    """
//                    INSERT INTO comparisonHistories_fts(rowid, word1, word2, sentence, response)
//                    VALUES (\(new.rowid), \(new.word1), \(new.word2), \(new.sentence), \(new.response))
//                    """
//                )
//            }
//        )
//        .execute(db)
//        
//        try ComparisonHistory.createTemporaryTrigger(
//            after: .update { ($0.word1, $0.word2, $0.sentence, $0.response) }
//            forEachRow: { _, new in
//                #sql(
//                    """
//                    UPDATE comparisonHistories_fts 
//                    SET word1 = \(new.word1), 
//                        word2 = \(new.word2), 
//                        sentence = \(new.sentence), 
//                        response = \(new.response)
//                    WHERE rowid = \(new.rowid)
//                    """
//                )
//            }
//        )
//        .execute(db)
//        
//        try ComparisonHistory.createTemporaryTrigger(
//            after: .delete { old in
//                #sql("DELETE FROM comparisonHistories_fts WHERE rowid = \(old.rowid)")
//            }
//        )
//        .execute(db)
//    }
//    
//    // Future migrations can be added here
//    // migrator.registerMigration("v1.2 - Add favorites") { db in ... }
//    
//    try migrator.migrate(database)
//    
//    return database
//}
//
//// MARK: - Test Database
//
//extension DatabaseWriter where Self == DatabaseQueue {
//    /// Test database for previews and tests
//    static var testDatabase: Self {
//        let database = try! DatabaseQueue()
//        var migrator = DatabaseMigrator()
//        
//        migrator.registerMigration("Create test table") { db in
//            try #sql(
//                """
//                CREATE TABLE "comparisonHistories" (
//                    "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
//                    "word1" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
//                    "word2" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
//                    "sentence" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
//                    "response" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT '',
//                    "date" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT CURRENT_TIMESTAMP
//                ) STRICT
//                """
//            )
//            .execute(db)
//            
//            // Seed some test data
//            try ComparisonHistory.insert {
//                [
//                    ComparisonHistory.Draft(
//                        word1: "character",
//                        word2: "characteristic",
//                        sentence: "The character of this wine is unique.",
//                        response: "Test response...",
//                        date: Date()
//                    ),
//                    ComparisonHistory.Draft(
//                        word1: "affect",
//                        word2: "effect",
//                        sentence: "How does this affect the result?",
//                        response: "Another test response...",
//                        date: Date().addingTimeInterval(-3600)
//                    )
//                ]
//            }
//            .execute(db)
//        }
//        
//        try! migrator.migrate(database)
//        return database
//    }
//}
////
////  Dependencies.swift
////  WordsLearner
////
////  Created by Jeffrey on 11/18/25.
////
//
//import ComposableArchitecture
//import Foundation
//
//// MARK: - AI Service Dependency
//
//struct AIServiceClient {
//    var streamResponse: @Sendable (String) -> AsyncThrowingStream<String, Error>
//}
//
//extension AIServiceClient: DependencyKey {
//    static let liveValue = Self(
//        streamResponse: { prompt in
//            let apiKeyManager = APIKeyManager.shared
//            let apiKey = apiKeyManager.getAPIKey()
//            
//            return AsyncThrowingStream { continuation in
//                Task {
//                    do {
//                        guard !apiKey.isEmpty else {
//                            throw AIError.authenticationError
//                        }
//                        
//                        guard let url = URL(string: "https://aihubmix.com/v1/chat/completions") else {
//                            throw AIError.invalidURL
//                        }
//                        
//                        var request = URLRequest(url: url)
//                        request.httpMethod = "POST"
//                        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
//                        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
//                        
//                        let payload: [String: Any] = [
//                            "model": "gpt-4o-mini",
//                            "messages": [["role": "user", "content": prompt]],
//                            "stream": true,
//                            "temperature": 0.7
//                        ]
//                        
//                        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
//                        
//                        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
//                        
//                        guard let httpResponse = response as? HTTPURLResponse,
//                              httpResponse.statusCode == 200 else {
//                            throw AIError.networkError
//                        }
//                        
//                        for try await line in asyncBytes.lines {
//                            if line.hasPrefix("data: ") {
//                                let jsonString = String(line.dropFirst(6))
//                                
//                                if jsonString == "[DONE]" {
//                                    continuation.finish()
//                                    return
//                                }
//                                
//                                if let data = jsonString.data(using: .utf8),
//                                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
//                                   let choices = json["choices"] as? [[String: Any]],
//                                   let firstChoice = choices.first,
//                                   let delta = firstChoice["delta"] as? [String: Any],
//                                   let content = delta["content"] as? String {
//                                    continuation.yield(content)
//                                }
//                            }
//                        }
//                        
//                        continuation.finish()
//                    } catch {
//                        continuation.finish(throwing: error)
//                    }
//                }
//            }
//        }
//    )
//    
//    static let testValue = Self(
//        streamResponse: { _ in
//            AsyncThrowingStream { continuation in
//                continuation.yield("Test response")
//                continuation.finish()
//            }
//        }
//    )
//}
//
//extension DependencyValues {
//    var aiService: AIServiceClient {
//        get { self[AIServiceClient.self] }
//        set { self[AIServiceClient.self] = newValue }
//    }
//}
//
//// MARK: - API Key Manager Dependency
//
//struct APIKeyManagerClient {
//    var hasValidAPIKey: @Sendable () -> Bool
//    var getAPIKey: @Sendable () -> String
//    var saveAPIKey: @Sendable (String) -> Bool
//    var deleteAPIKey: @Sendable () -> Bool
//    var validateAPIKey: @Sendable (String) -> Bool
//}
//
//extension APIKeyManagerClient: DependencyKey {
//    static let liveValue = Self(
//        hasValidAPIKey: { !APIKeyManager.shared.getAPIKey().isEmpty },
//        getAPIKey: { APIKeyManager.shared.getAPIKey() },
//        saveAPIKey: { APIKeyManager.shared.saveAPIKey($0) },
//        deleteAPIKey: { APIKeyManager.shared.deleteAPIKey() },
//        validateAPIKey: { APIKeyManager.shared.validateAPIKey($0) }
//    )
//    
//    static let testValue = Self(
//        hasValidAPIKey: { true },
//        getAPIKey: { "test-api-key" },
//        saveAPIKey: { _ in true },
//        deleteAPIKey: { true },
//        validateAPIKey: { _ in true }
//    )
//}
//
//extension DependencyValues {
//    var apiKeyManager: APIKeyManagerClient {
//        get { self[APIKeyManagerClient.self] }
//        set { self[APIKeyManagerClient.self] = newValue }
//    }
//}
//
////
////  MarkdownText.swift
////  WordsLearner
////
////  Created by Jeffrey on 11/13/25.
////
//
//import SwiftUI
//import Markdown
//
//
//struct MarkdownText: View {
//    let content: String
//    @State private var attributedString: AttributedString = AttributedString()
//    
//    init(_ content: String) {
//        self.content = content
//    }
//    
//    var body: some View {
//        Text(attributedString)
//            .textSelection(.enabled)
//            .onAppear {
//                updateAttributedString()
//            }
//            .onChange(of: content) { _ in
//                updateAttributedString()
//            }
//    }
//    
//    private func updateAttributedString() {
//        Task {
//            let processed = await renderMarkdown(content)
//            await MainActor.run {
//                self.attributedString = processed
//            }
//        }
//    }
//    
//    private func renderMarkdown(_ text: String) async -> AttributedString {
//        let document = Document(parsing: text)
//        let renderer = AttributedStringRenderer()
//        return renderer.render(document)
//    }
//}
//
//struct AttributedStringRenderer {
//    
//    #if os(macOS)
//    private let baseFontSize: CGFloat = 18
//    private let headingScale: CGFloat = 1.2
//    #else
//    private let baseFontSize: CGFloat = 16
//    private let headingScale: CGFloat = 1.0
//    #endif
//    
//    func render(_ document: Document) -> AttributedString {
//        var result = AttributedString()
//        
//        for child in document.children {
//            result.append(renderMarkup(child))
//        }
//        
//        return result
//    }
//    
//    // Handle any Markup type, not just BlockMarkup
//    private func renderMarkup(_ markup: any Markup) -> AttributedString {
//        switch markup {
//        // Block elements
//        case let heading as Heading:
//            return renderHeading(heading)
//        case let paragraph as Paragraph:
//            return renderParagraph(paragraph)
//        case let listItem as ListItem:
//            return renderListItem(listItem)
//        case let orderedList as OrderedList:
//            return renderOrderedList(orderedList)
//        case let unorderedList as UnorderedList:
//            return renderUnorderedList(unorderedList)
//        case let codeBlock as CodeBlock:
//            return renderCodeBlock(codeBlock)
//        case let blockQuote as BlockQuote:
//            return renderBlockQuote(blockQuote)
//        
//        // Inline elements
//        case let text as Markdown.Text:
//            return AttributedString(text.plainText)
//        case let strong as Strong:
//            return renderStrong(strong)
//        case let emphasis as Emphasis:
//            return renderEmphasis(emphasis)
//        case let inlineCode as InlineCode:
//            return renderInlineCode(inlineCode)
//        case let link as Markdown.Link:
//            return renderLink(link)
//        
//        // Fallback for any other markup
//        default:
//            return AttributedString()
//        }
//    }
//    
//    // MARK: - Block Renderers
//    
//    private func renderHeading(_ heading: Heading) -> AttributedString {
//        var result = AttributedString()
//        
//        for child in heading.children {
//            result.append(renderMarkup(child))
//        }
//        
//        switch heading.level {
//        case 1:
//            #if os(macOS)
//            result.font = .system(size: 28 * headingScale, weight: .bold)
//            #else
//            result.font = .title.bold()
//            #endif
//            result.foregroundColor = .primary
//        case 2:
//            #if os(macOS)
//            result.font = .system(size: 22 * headingScale, weight: .bold)
//            #else
//            result.font = .title2.bold()
//            #endif
//            result.foregroundColor = .primary
//        case 3:
//            #if os(macOS)
//            result.font = .system(size: 18 * headingScale, weight: .bold)
//            #else
//            result.font = .title3.bold()
//            #endif
//            result.foregroundColor = .primary
//        default:
//            #if os(macOS)
//            result.font = .system(size: 16 * headingScale, weight: .semibold)
//            #else
//            result.font = .headline.bold()
//            #endif
//            result.foregroundColor = .primary
//        }
//        
//        result.append(AttributedString("\n\n"))
//        return result
//    }
//    
//    private func renderParagraph(_ paragraph: Paragraph) -> AttributedString {
//        var result = AttributedString()
//        
//        for child in paragraph.children {
//            result.append(renderMarkup(child))
//        }
//        
//        #if os(macOS)
//        result.font = .system(size: baseFontSize)
//        #else
//        result.font = .body
//        #endif
//        
//        result.append(AttributedString("\n\n"))
//        return result
//    }
//    
//    private func renderOrderedList(_ list: OrderedList) -> AttributedString {
//        var result = AttributedString()
//        
//        for (index, item) in list.children.enumerated() {
//            if let listItem = item as? ListItem {
//                var itemText = AttributedString("\(index + 1). ")
//                #if os(macOS)
//                itemText.font = .system(size: baseFontSize, weight: .bold)
//                #else
//                itemText.font = .body.bold()
//                #endif
//                
//                for child in listItem.children {
//                    var childText = renderMarkup(child)
//                    #if os(macOS)
//                    childText.font = .system(size: baseFontSize)
//                    #endif
//                    itemText.append(childText)
//                }
//                
//                result.append(itemText)
//            }
//        }
//        
//        result.append(AttributedString("\n"))
//        return result
//    }
//    
//    private func renderUnorderedList(_ list: UnorderedList) -> AttributedString {
//        var result = AttributedString()
//        
//        for item in list.children {
//            if let listItem = item as? ListItem {
//                var itemText = AttributedString("• ")
//                #if os(macOS)
//                itemText.font = .system(size: baseFontSize, weight: .bold)
//                #else
//                itemText.font = .body.bold()
//                #endif
//                
//                for child in listItem.children {
//                    var childText = renderMarkup(child)
//                    #if os(macOS)
//                    childText.font = .system(size: baseFontSize)
//                    #endif
//                    itemText.append(childText)
//                }
//                
//                result.append(itemText)
//            }
//        }
//        
//        result.append(AttributedString("\n"))
//        return result
//    }
//    
//    private func renderListItem(_ listItem: ListItem) -> AttributedString {
//        var result = AttributedString()
//        
//        for child in listItem.children {
//            result.append(renderMarkup(child))
//        }
//        
//        return result
//    }
//    
//    private func renderCodeBlock(_ codeBlock: CodeBlock) -> AttributedString {
//        var result = AttributedString(codeBlock.code)
//        #if os(macOS)
//        result.font = .system(size: baseFontSize - 1, design: .monospaced)
//        #else
//        result.font = .system(.body, design: .monospaced)
//        #endif
//        result.backgroundColor = AppColors.fieldBackground
//        result.append(AttributedString("\n\n"))
//        return result
//    }
//    
//    private func renderBlockQuote(_ blockQuote: BlockQuote) -> AttributedString {
//        var result = AttributedString("❝ ")
//        
//        for child in blockQuote.children {
//            result.append(renderMarkup(child))
//        }
//        
//        #if os(macOS)
//        result.font = .system(size: baseFontSize, design: .default).italic()
//        #else
//        result.font = .body.italic()
//        #endif
//        result.foregroundColor = .secondary
//        result.append(AttributedString("\n\n"))
//        return result
//    }
//    
//    // MARK: - Inline Renderers
//    
//    private func renderStrong(_ strong: Strong) -> AttributedString {
//        var result = AttributedString()
//        
//        for child in strong.children {
//            result.append(renderMarkup(child))
//        }
//        
//        #if os(macOS)
//        result.font = .system(size: baseFontSize, weight: .bold)
//        #else
//        result.font = .body.bold()
//        #endif
//        return result
//    }
//    
//    private func renderEmphasis(_ emphasis: Emphasis) -> AttributedString {
//        var result = AttributedString()
//        
//        for child in emphasis.children {
//            result.append(renderMarkup(child))
//        }
//        
//        #if os(macOS)
//        result.font = .system(size: baseFontSize, design: .default).italic()
//        #else
//        result.font = .body.italic()
//        #endif
//        return result
//    }
//    
//    private func renderInlineCode(_ inlineCode: InlineCode) -> AttributedString {
//        var result = AttributedString(inlineCode.code)
//        #if os(macOS)
//        result.font = .system(size: baseFontSize - 1, design: .monospaced)
//        #else
//        result.font = .system(.body, design: .monospaced)
//        #endif
//        result.backgroundColor = AppColors.fieldBackground
//        return result
//    }
//    
//    private func renderLink(_ link: Markdown.Link) -> AttributedString {
//        var result = AttributedString()
//        
//        for child in link.children {
//            result.append(renderMarkup(child))
//        }
//        
//        result.foregroundColor = .blue
//        result.underlineStyle = .single
//        
//        if let destination = link.destination {
//            result.link = URL(string: destination)
//        }
//        
//        return result
//    }
//}
////
////  PlatformShareService.swift
////  WordsLearner
////
////  Created by Jeffrey on 11/17/25.
////
//
//import SwiftUI
//
//#if os(iOS)
//import UIKit
//#elseif os(macOS)
//import AppKit
//#endif
//
//struct PlatformShareService {
//    
//    static func share(text: String, completion: ((Bool) -> Void)? = nil) {
//        #if os(iOS)
//        shareOnIOS(text: text, completion: completion)
//        #else
//        shareOnMacOS(text: text, completion: completion)
//        #endif
//    }
//    
//    #if os(iOS)
//    private static func shareOnIOS(text: String, completion: ((Bool) -> Void)?) {
//        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
//              let window = windowScene.windows.first,
//              let rootViewController = window.rootViewController else {
//            completion?(false)
//            return
//        }
//        
//        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
//        
//        // iPad 支持
//        if let popover = activityVC.popoverPresentationController {
//            popover.sourceView = window
//            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
//            popover.permittedArrowDirections = []
//        }
//        
//        activityVC.completionWithItemsHandler = { _, completed, _, _ in
//            completion?(completed)
//        }
//        
//        rootViewController.present(activityVC, animated: true)
//    }
//    #endif
//    
//    #if os(macOS)
//    private static func shareOnMacOS(text: String, completion: ((Bool) -> Void)?) {
//        let pasteboard = NSPasteboard.general
//        pasteboard.clearContents()
//        let success = pasteboard.setString(text, forType: .string)
//        
//        if success {
//            // 显示通知（可选）
//            showCopyNotification()
//        }
//        
//        completion?(success)
//    }
//    
//    private static func showCopyNotification() {
//        let notification = NSUserNotification()
//        notification.title = "Copied to Clipboard"
//        notification.informativeText = "Comparison content has been copied to clipboard"
//        notification.soundName = NSUserNotificationDefaultSoundName
//        
//        NSUserNotificationCenter.default.deliver(notification)
//    }
//    #endif
//}
//
//// SwiftUI View Modifier for easy sharing
//struct ShareViewModifier: ViewModifier {
//    let text: String
//    @State private var showingShareSuccess = false
//    
//    func body(content: Content) -> some View {
//        content
//            .onTapGesture {
//                PlatformShareService.share(text: text) { success in
//                    showingShareSuccess = success
//                }
//            }
//            #if os(macOS)
//            .alert("Copied!", isPresented: $showingShareSuccess) {
//                Button("OK") { }
//            } message: {
//                Text("Content has been copied to clipboard")
//            }
//            #endif
//    }
//}
//
//extension View {
//    func shareContent(_ text: String) -> some View {
//        modifier(ShareViewModifier(text: text))
//    }
//}
////
////  SharedComparisonRow.swift
////  WordsLearner
////
////  Created by Jeffrey on 11/24/25.
////
//
//import SwiftUI
//
//struct SharedComparisonRow: View {
//    let comparison: ComparisonHistory
//    let onTap: () -> Void
//    
//    @State private var isHovering = false
//    
//    var body: some View {
//        Button(action: onTap) {
//            HStack(spacing: 12) {
//                // Word comparison section
//                VStack(alignment: .leading, spacing: 8) {
//                    // Words row
//                    HStack(spacing: 8) {
//                        Text(comparison.word1)
//
//
//                            .font(.headline)
//                            .fontWeight(.semibold)
//                            .foregroundColor(AppColors.word1Color)
//                            .padding(.horizontal, 10)
//                            .padding(.vertical, 4)
//                            .background(
//                                RoundedRectangle(cornerRadius: 6)
//                                    .fill(AppColors.word1Background)
//                            )
//                        
//                        Text("vs")
//                            .font(.caption)
//                            .fontWeight(.medium)
//                            .foregroundColor(AppColors.secondaryText)
//                        
//                        Text(comparison.word2)
//                            .font(.headline)
//                            .fontWeight(.semibold)
//                            .foregroundColor(AppColors.word2Color)
//                            .padding(.horizontal, 10)
//                            .padding(.vertical, 4)
//                            .background(
//                                RoundedRectangle(cornerRadius: 6)
//                                    .fill(AppColors.word2Background)
//                            )
//                        
//                        Spacer()
//                    }
//                    
//                    // Sentence
//                    Text(comparison.sentence)
//                        .font(platformFont(.body, fallback: .subheadline))
//                        .foregroundColor(AppColors.secondaryText)
//                        .lineLimit(2)
//                        .multilineTextAlignment(.leading)
//                    
//                    // Date
//                    HStack(spacing: 4) {
//                        Image(systemName: "clock")
//                            .font(.caption2)
//                            .foregroundColor(AppColors.tertiaryText)
//                        
//                        Text(comparison.date.formatted(date: .abbreviated, time: .shortened))
//                            .font(.caption)
//                            .foregroundColor(AppColors.tertiaryText)
//                    }
//                }
//                
//                // Chevron
//                Image(systemName: "chevron.right")
//                    .font(.caption)
//                    .
//
//foregroundColor(AppColors.tertiaryText)
//                    .opacity(0.6)
//            }
//            .padding(platformPadding())
//            .background(
//                RoundedRectangle(cornerRadius: platformCornerRadius())
//                    .fill(backgroundColorForState())
//                    .shadow(
//                        color: AppColors.cardShadow.opacity(shadowOpacity()),
//                        radius: shadowRadius(),
//                        x: 0,
//                        y: shadowOffset()
//                    )
//            )
//            .overlay(
//                RoundedRectangle(cornerRadius: platformCornerRadius())
//                    .stroke(AppColors.separator.opacity(borderOpacity()), lineWidth: borderWidth())
//            )
//        }
//        .buttonStyle(PlainButtonStyle())
//        #if os(macOS)
//        .onHover { hovering in
//            withAnimation(.easeInOut(duration: 0.2)) {
//                isHovering = hovering
//            }
//        }
//        #endif
//    }
//    
//    // MARK: - Platform-specific helpers
//    
//    private func platformFont(_ ios: Font, fallback: Font) -> Font {
//        #if os(iOS)
//        return ios
//        #else
//        return fallback
//        #endif
//    }
//    
//    private func platformPadding() -> EdgeInsets {
//        #if os(iOS)
//        return EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
//        #else
//        return EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
//        #endif
//    }
//    
//    private func platformCornerRadius() -> CGFloat {
//        #if os(iOS)
//        return 12
//        #else
//        return 8
//        #endif
//    }
//    
//    private func backgroundColorForState() -> Color {
//        #if os(iOS)
//        return
//
// AppColors.dynamicCardBackground
//        #else
//        return isHovering ? AppColors.hoverBackground : AppColors.dynamicCardBackground
//        #endif
//    }
//    
//    private func shadowOpacity() -> Double {
//        #if os(iOS)
//        return 0.1
//        #else
//        return isHovering ? 0.2 : 0.05
//        #endif
//    }
//    
//    private func shadowRadius() -> CGFloat {
//        #if os(iOS)
//        return 2
//        #else
//        return isHovering ? 4 : 1
//        #endif
//    }
//    
//    private func shadowOffset() -> CGFloat {
//        #if os(iOS)
//        return 1
//        #else
//        return isHovering ? 2 : 0.5
//        #endif
//    }
//    
//    private func borderOpacity() -> Double {
//        #if os(iOS)
//        return 0.1
//        #else
//        return 0.2
//        #endif
//    }
//    
//    private func borderWidth() -> CGFloat {
//        #if os(iOS)
//        return 0
//        #else
//        return 0.5
//        #endif
//    }
//}
//
//#Preview {
//    let sampleComparison = ComparisonHistory(
//        id: UUID(),
//        word1: "character",
//        word2: "characteristic",
//        sentence: "The character of this wine is unique and shows the winery's attention to detail.",
//        response: "Sample response",
//        date: Date()
//    )
//    
//    VStack(spacing: 8) {
//        SharedComparisonRow(
//            comparison: ComparisonHistory(
//                id: UUID(),
//                word1: sampleComparison.word1,
//                word2: sampleComparison.word2,
//                sentence: sampleComparison.sentence,
//                response: sampleComparison.response,
//                date: sampleComparison.date
//            )
//        ) {
//            print("Tapped")
//        }
//        
//        SharedComparisonRow(
//            comparison: ComparisonHistory(
//                id: UUID(),
//                word1: "affect",
//                word2: "effect",
//                sentence: "How does this change affect the final result?",
//                response: "Another response",
//                date: Date().addingTimeInterval(-3600)
//            )
//        ) {
//            print("Tapped 2")
//        }
//    }
//    .padding()
//}
////
////  AIService.swift
////  WordsLearner
////
////  Created by Jeffrey on 11/12/25.
////
//
//import Foundation
//
//class StreamingAIService {
//    private let apiEndpoint = "https://aihubmix.com/v1/chat/completions"
//    private let apiKeyManager = APIKeyManager.shared
//    
//    func streamResponse(prompt: String) -> AsyncThrowingStream<String, Error> {
//        return AsyncThrowingStream { continuation in
//            Task {
//                do {
//                    let apiKey = apiKeyManager.getAPIKey()
//                    guard !apiKey.isEmpty else {
//                        throw AIError.authenticationError
//                    }
//                    
//                    guard let url = URL(string: apiEndpoint) else {
//                        throw AIError.invalidURL
//                    }
//                    
//                    var request = URLRequest(url: url)
//                    request.httpMethod = "POST"
//                    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
//                    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
//                    
//                    var payload: [String: Any] = [
//                        "model": "gpt-4o-mini",
//                        "messages": [
//                            [
//                                "role": "user",
//                                "content": prompt
//                            ]
//                        ],
//                        "stream": true,
//                        "temperature": 0.7
//                    ]
//                    
//                    request.httpBody = try JSONSerialization.data(withJSONObject: payload)
//                    
//                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
//                    
//                    guard let httpResponse = response as? HTTPURLResponse else {
//                        throw AIError.networkError
//                    }
//                    
//                    guard httpResponse.statusCode == 200 else {
//                        throw AIError.apiError(statusCode: httpResponse.statusCode)
//                    }
//                    
//                    for try await line in asyncBytes.lines {
//                        if line.hasPrefix("data: ") {
//                            let jsonString = String(line.dropFirst(6))
//                            
//                            if jsonString == "[DONE]" {
//                                continuation.finish()
//                                return
//                            }
//                            
//                            if let data = jsonString.data(using: .utf8),
//                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
//                               let choices = json["choices"] as? [[String: Any]],
//                               let firstChoice = choices.first,
//                               let delta = firstChoice["delta"] as? [String: Any],
//                               let content = delta["content"] as? String {
//                                
//                                continuation.yield(content)
//                            }
//                        }
//                    }
//                    
//                    continuation.finish()
//                    
//                } catch {
//                    continuation.finish(throwing: error)
//                }
//            }
//        }
//    }
//}
//
//
//
//// Enhanced error handling
//enum AIError: LocalizedError {
//    case invalidURL
//    case jsonEncodingError
//    case networkError
//    case authenticationError
//    case rateLimitError
//    case apiError(statusCode: Int)
//    case apiResponseError(message: String)
//    case parsingError
//    
//    var errorDescription: String? {
//        switch self {
//        case .invalidURL:
//            return "Invalid API URL configuration"
//        case .jsonEncodingError:
//            return "Failed to encode request data"
//        case .networkError:
//            return "Network connection failed"
//        case .authenticationError:
//            return "Authentication failed. Please check your API key."
//        case .rateLimitError:
//            return "Rate limit exceeded. Please try again later."
//        case .apiError(let statusCode):
//            return "API request failed with status code: \(statusCode)"
//        case .apiResponseError(let message):
//            return "API Error: \(message)"
//        case .parsingError:
//            return "Failed to parse AI response"
//        }
//    }
//}
//
////
////  WordsLearnerApp.swift
////  WordsLearner
////
////  Created by Jeffrey on 11/12/25.
////
//
//import SwiftUI
//import ComposableArchitecture
//
//@main
//struct EnglishWordComparatorApp: App {
//    init() {
//        // Bootstrap database on app launch
//        try! prepareDependencies {
//            try $0.bootstrapDatabase()
//        }
//    }
//    
//    var body: some Scene {
//        WindowGroup {
//            WordComparatorMainView(
//                store: Store(initialState: WordComparatorFeature.State()) {
//                    WordComparatorFeature()
//                }
//            )
//        }
//    }
//}
