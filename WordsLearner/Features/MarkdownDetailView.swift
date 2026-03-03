//
//  MarkdownDetailView.swift
//  WordsLearner
//
//  Created by Codex on 3/2/26.
//

import ComposableArchitecture
import SwiftUI

struct MarkdownDetailView: View {
    let store: StoreOf<MarkdownDetailFeature>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if store.attributedString.characters.isEmpty {
                    Text(store.markdown)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    MarkdownText(store.attributedString)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .navigationTitle("Markdown Analysis")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .background(AppColors.background)
    }
}

#Preview {
    NavigationStack {
        MarkdownDetailView(
            store: Store(
                initialState: MarkdownDetailFeature.State(
                    markdown: "## Title\n\n- one\n- two",
                    attributedString: AttributedString("## Title\n\n- one\n- two")
                )
            ) {
                MarkdownDetailFeature()
            }
        )
    }
}
