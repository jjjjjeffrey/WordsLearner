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
                updateAttributedString(content: content)
            }
            .onChange(of: content) { content in
                updateAttributedString(content: content)
            }
    }
    
    private func updateAttributedString(content: String) {
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

struct AttributedStringRenderer {
    
    #if os(macOS)
    private let baseFontSize: CGFloat = 18
    private let headingScale: CGFloat = 1.2
    #else
    private let baseFontSize: CGFloat = 16
    private let headingScale: CGFloat = 1.0
    #endif
    
    func render(_ document: Document) -> AttributedString {
        var result = AttributedString()
        
        for child in document.children {
            result.append(renderMarkup(child))
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
        
        switch heading.level {
        case 1:
            #if os(macOS)
            result.font = .system(size: 28 * headingScale, weight: .bold)
            #else
            result.font = .title.bold()
            #endif
            result.foregroundColor = .primary
        case 2:
            #if os(macOS)
            result.font = .system(size: 22 * headingScale, weight: .bold)
            #else
            result.font = .title2.bold()
            #endif
            result.foregroundColor = .primary
        case 3:
            #if os(macOS)
            result.font = .system(size: 18 * headingScale, weight: .bold)
            #else
            result.font = .title3.bold()
            #endif
            result.foregroundColor = .primary
        default:
            #if os(macOS)
            result.font = .system(size: 16 * headingScale, weight: .semibold)
            #else
            result.font = .headline.bold()
            #endif
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
        
        #if os(macOS)
        result.font = .system(size: baseFontSize)
        #else
        result.font = .body
        #endif
        
        result.append(AttributedString("\n\n"))
        return result
    }
    
    private func renderOrderedList(_ list: OrderedList) -> AttributedString {
        var result = AttributedString()
        
        for (index, item) in list.children.enumerated() {
            if let listItem = item as? ListItem {
                var itemText = AttributedString("\(index + 1). ")
                #if os(macOS)
                itemText.font = .system(size: baseFontSize, weight: .bold)
                #else
                itemText.font = .body.bold()
                #endif
                
                for child in listItem.children {
                    var childText = renderMarkup(child)
                    #if os(macOS)
                    childText.font = .system(size: baseFontSize)
                    #endif
                    itemText.append(childText)
                }
                
                result.append(itemText)
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
                #if os(macOS)
                itemText.font = .system(size: baseFontSize, weight: .bold)
                #else
                itemText.font = .body.bold()
                #endif
                
                for child in listItem.children {
                    var childText = renderMarkup(child)
                    #if os(macOS)
                    childText.font = .system(size: baseFontSize)
                    #endif
                    itemText.append(childText)
                }
                
                result.append(itemText)
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
        #if os(macOS)
        result.font = .system(size: baseFontSize - 1, design: .monospaced)
        #else
        result.font = .system(.body, design: .monospaced)
        #endif
        result.backgroundColor = AppColors.fieldBackground
        result.append(AttributedString("\n\n"))
        return result
    }
    
    private func renderBlockQuote(_ blockQuote: BlockQuote) -> AttributedString {
        var result = AttributedString("❝ ")
        
        for child in blockQuote.children {
            result.append(renderMarkup(child))
        }
        
        #if os(macOS)
        result.font = .system(size: baseFontSize, design: .default).italic()
        #else
        result.font = .body.italic()
        #endif
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
        
        #if os(macOS)
        result.font = .system(size: baseFontSize, weight: .bold)
        #else
        result.font = .body.bold()
        #endif
        return result
    }
    
    private func renderEmphasis(_ emphasis: Emphasis) -> AttributedString {
        var result = AttributedString()
        
        for child in emphasis.children {
            result.append(renderMarkup(child))
        }
        
        #if os(macOS)
        result.font = .system(size: baseFontSize, design: .default).italic()
        #else
        result.font = .body.italic()
        #endif
        return result
    }
    
    private func renderInlineCode(_ inlineCode: InlineCode) -> AttributedString {
        var result = AttributedString(inlineCode.code)
        #if os(macOS)
        result.font = .system(size: baseFontSize - 1, design: .monospaced)
        #else
        result.font = .system(.body, design: .monospaced)
        #endif
        result.backgroundColor = AppColors.fieldBackground
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
