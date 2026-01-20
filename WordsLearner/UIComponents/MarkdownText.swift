//
//  MarkdownText.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/13/25.
//

import SwiftUI
import Markdown


struct MarkdownText: View {
    private var attributedString: AttributedString = AttributedString()
    
    init(_ attributedString: AttributedString) {
        self.attributedString = attributedString
    }
    
    var body: some View {
        Text(attributedString)
            .textSelection(.enabled)
    }
}


