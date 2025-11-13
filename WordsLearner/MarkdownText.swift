//
//  MarkdownText.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/13/25.
//

import SwiftUI
import Markdown

struct MarkdownText: View {
    let content: String
    @State private var attributedString: AttributedString = AttributedString()
    
    init(_ content: String) {
        self.content = content
    }
    
    var body: some View {
        Text(attributedString)
            .textSelection(.enabled)
            .onAppear {
                updateAttributedString()
            }
            .onChange(of: content) { _ in
                updateAttributedString()
            }
    }
    
    private func updateAttributedString() {
        Task {
            let processed = await renderMarkdown(content)
            await MainActor.run {
                self.attributedString = processed
            }
        }
    }
    
    private func renderMarkdown(_ text: String) async -> AttributedString {
        let document = Document(parsing: text)
        let renderer = AttributedStringRenderer()
        return renderer.render(document)
    }
}

// Fixed renderer for AttributedString
struct AttributedStringRenderer {
    func render(_ document: Document) -> AttributedString {
        var result = AttributedString()
        
        for child in document.children {
            result.append(renderMarkup(child)) // Changed from renderBlock
        }
        
        return result
    }
    
    // Handle any Markup type, not just BlockMarkup
    private func renderMarkup(_ markup: any Markup) -> AttributedString {
        switch markup {
        // Block elements
        case let heading as Heading:
            return renderHeading(heading)
        case let paragraph as Paragraph:
            return renderParagraph(paragraph)
        case let listItem as ListItem:
            return renderListItem(listItem)
        case let orderedList as OrderedList:
            return renderOrderedList(orderedList)
        case let unorderedList as UnorderedList:
            return renderUnorderedList(unorderedList)
        case let codeBlock as CodeBlock:
            return renderCodeBlock(codeBlock)
        case let blockQuote as BlockQuote:
            return renderBlockQuote(blockQuote)
        
        // Inline elements
        case let text as Markdown.Text:
            return AttributedString(text.plainText)
        case let strong as Strong:
            return renderStrong(strong)
        case let emphasis as Emphasis:
            return renderEmphasis(emphasis)
        case let inlineCode as InlineCode:
            return renderInlineCode(inlineCode)
        case let link as Markdown.Link:
            return renderLink(link)
        
        // Fallback for any other markup
        default:
            return AttributedString()
        }
    }
    
    // MARK: - Block Renderers
    
    private func renderHeading(_ heading: Heading) -> AttributedString {
        var result = AttributedString()
        
        for child in heading.children {
            result.append(renderMarkup(child))
        }
        
        // Apply heading styles based on level
        switch heading.level {
        case 1:
            result.font = .title.bold()
            result.foregroundColor = .primary
        case 2:
            result.font = .title2.bold()
            result.foregroundColor = .primary
        case 3:
            result.font = .title3.bold()
            result.foregroundColor = .primary
        default:
            result.font = .headline.bold()
            result.foregroundColor = .primary
        }
        
        result.append(AttributedString("\n\n"))
        return result
    }
    
    private func renderParagraph(_ paragraph: Paragraph) -> AttributedString {
        var result = AttributedString()
        
        for child in paragraph.children {
            result.append(renderMarkup(child))
        }
        
        result.append(AttributedString("\n\n"))
        return result
    }
    
    private func renderOrderedList(_ list: OrderedList) -> AttributedString {
        var result = AttributedString()
        
        for (index, item) in list.children.enumerated() {
            if let listItem = item as? ListItem {
                var itemText = AttributedString("\(index + 1). ")
                itemText.font = .body.bold()
                
                for child in listItem.children {
                    itemText.append(renderMarkup(child))
                }
                
                result.append(itemText)
                result.append(AttributedString("\n"))
            }
        }
        
        result.append(AttributedString("\n"))
        return result
    }
    
    private func renderUnorderedList(_ list: UnorderedList) -> AttributedString {
        var result = AttributedString()
        
        for item in list.children {
            if let listItem = item as? ListItem {
                var itemText = AttributedString("• ")
                itemText.font = .body.bold()
                
                for child in listItem.children {
                    itemText.append(renderMarkup(child))
                }
                
                result.append(itemText)
                result.append(AttributedString("\n"))
            }
        }
        
        result.append(AttributedString("\n"))
        return result
    }
    
    private func renderListItem(_ listItem: ListItem) -> AttributedString {
        var result = AttributedString()
        
        for child in listItem.children {
            result.append(renderMarkup(child))
        }
        
        return result
    }
    
    private func renderCodeBlock(_ codeBlock: CodeBlock) -> AttributedString {
        var result = AttributedString(codeBlock.code)
        result.font = .system(.body, design: .monospaced)
        result.backgroundColor = Color(.systemGray6)
        result.append(AttributedString("\n\n"))
        return result
    }
    
    private func renderBlockQuote(_ blockQuote: BlockQuote) -> AttributedString {
        var result = AttributedString("❝ ")
        
        for child in blockQuote.children {
            result.append(renderMarkup(child))
        }
        
        result.font = .body.italic()
        result.foregroundColor = .secondary
        result.append(AttributedString("\n\n"))
        return result
    }
    
    // MARK: - Inline Renderers
    
    private func renderStrong(_ strong: Strong) -> AttributedString {
        var result = AttributedString()
        
        for child in strong.children {
            result.append(renderMarkup(child))
        }
        
        result.font = .body.bold()
        return result
    }
    
    private func renderEmphasis(_ emphasis: Emphasis) -> AttributedString {
        var result = AttributedString()
        
        for child in emphasis.children {
            result.append(renderMarkup(child))
        }
        
        result.font = .body.italic()
        return result
    }
    
    private func renderInlineCode(_ inlineCode: InlineCode) -> AttributedString {
        var result = AttributedString(inlineCode.code)
        result.font = .system(.body, design: .monospaced)
        result.backgroundColor = Color(.systemGray6)
        return result
    }
    
    private func renderLink(_ link: Markdown.Link) -> AttributedString {
        var result = AttributedString()
        
        for child in link.children {
            result.append(renderMarkup(child))
        }
        
        result.foregroundColor = .blue
        result.underlineStyle = .single
        
        if let destination = link.destination {
            result.link = URL(string: destination)
        }
        
        return result
    }
}



