//
//  CommandPrompt.swift
//  Terminader
//
//  Created by Steven Huang on 9/29/23.
//

import SwiftUI

struct CommandPrompt: View {
    @Binding var text: String
    @State private var presentation = AttributedString()
    @State private var cursor: String.Index {
        didSet {
            updatePresentation()
        }
    }
    var onCommit: (() -> Void)?
    var onControlKey: ((String) -> Void)?
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    @State private var cursorOn = true
    @State private var history: [String] = []
    @State private var historyIndex: Int = 0
    @State private var savedText: String?
    
    init(text: Binding<String>, onCommit: (() -> Void)? = nil, onControlKey: ((String) -> Void)? = nil) {
        self._text = text
        self._cursor = State(initialValue: text.wrappedValue.startIndex)
        self.onCommit = onCommit
        self.onControlKey = onControlKey
    }
    
    var body: some View {
        Text(presentation)
            .focusEffectDisabled()
            .focusable()
            .onKeyPress { keyPress in
                // FIXME: for some reason, changing 'text' in the callback doesn't take effect immediately
                DispatchQueue.main.async {
                    switch keyPress.key {
                    case .clear:
                        break
                    case .delete, KeyEquivalent("\u{7F}"): // FIXME: why doesn't .delete work?
                        if cursor > text.startIndex {
                            let previous = text.index(before: cursor)
                            text.remove(at: previous)
                            cursor = previous
                        }
                    case .deleteForward:
                        if cursor < text.endIndex {
                            text.remove(at: cursor)
                            updatePresentation()
                        }
                    case .downArrow:
                        if historyIndex < history.endIndex {
                            historyIndex += 1
                            if historyIndex < history.endIndex {
                                text = history[historyIndex]
                            }
                            else {
                                text = savedText ?? ""
                                savedText = nil
                            }
                            cursor = text.endIndex
                        }
                        break
                    case .end, .escape, .home:
                        break
                    case .leftArrow:
                        if cursor > text.startIndex {
                            cursor = text.index(before: cursor)
                        }
                    case .pageDown, .pageUp:
                        break
                    case .return:
                        self.onCommit?()
                        
                        history.append(text)
                        historyIndex = history.endIndex
                        savedText = nil
                        text = ""
                        cursor = text.startIndex
                    case .rightArrow:
                        if cursor < text.endIndex {
                            cursor = text.index(after: cursor)
                        }
                    case .tab:
                        break
                    case .upArrow:
                        if historyIndex > history.startIndex {
                            if savedText == nil {
                                savedText = text
                            }
                            historyIndex -= 1
                            text = history[historyIndex]
                            cursor = text.endIndex
                        }
                    default:
                        if keyPress.modifiers.contains(.control) {
                            onControlKey?(keyPress.characters)
                        }
                        else {
                            text.insert(contentsOf: keyPress.characters, at: cursor)
                            cursor = text.index(after: cursor)
                        }
                    }
                }
                return .handled
            }
            .onAppear {
                updatePresentation()
            }
            .onReceive(timer) { _ in
                cursorOn.toggle()
                updatePresentation()
            }
    }
    
    private func updatePresentation() {
        presentation = AttributedString(text.prefix(upTo: cursor))
        
        var cursorCharacter = AttributedString((cursor < text.endIndex) ? String(text[cursor]) : " ")
        if cursorOn {
            cursorCharacter.foregroundColor = Color(NSColor.textBackgroundColor)
            cursorCharacter.backgroundColor = .yellow
        }
        presentation += cursorCharacter
        
        if cursor < text.endIndex {
            presentation += AttributedString(text.suffix(from: text.index(after: cursor)))
        }
    }
}

@_documentation(visibility: private)
struct CommandPrompt_Previews: PreviewProvider {
    @State private static var text = ""
    static var previews: some View {
        CommandPrompt(text: $text)
            .frame(width: 200)
    }
}
