//
//  CLIDetailView.swift
//  Terminader
//
//  Created by Steven Huang on 9/20/23.
//

import SwiftUI
import MarkdownUI

enum CLIPane: CaseIterable, Identifiable {
    case console, errors
    var id: CLIPane { self }
    var localizedString: LocalizedStringKey {
        switch self {
        case .console:
            return LocalizedStringKey(stringLiteral: "Console")
        case .errors:
            return LocalizedStringKey(stringLiteral: "Errors")
        }
    }
}

/// Renders the CLI (terminal) interface.
struct CLIDetailView: View {
    @EnvironmentObject private var model: ContentViewModel
    @State private var selectedPane = CLIPane.console
    @State private var command = ""
    @State private var badgeScale = 1.0
    @State private var badgeColor = Color.clear
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button { // MARK: Paste selection button
                    command = command.trimmingCharacters(in: .whitespaces)
                    for file in model.selectedFiles {
                        let path = file.url.path.replacingOccurrences(of: " ", with: "\\ ")
                        command += " " + path
                    }
                } label: {
                    Image(systemName: "arrow.down.doc")
                }
                .buttonStyle(.bordered)
                .disabled(model.selectedFiles.isEmpty)
                .overlay {
                    let badgeAnimation = {
                        badgeScale = 2
                        badgeColor = .orange
                        withAnimation(Animation.easeOut(duration: 0.5)) {
                            badgeScale = 1
                            badgeColor = Color(NSColor.controlTextColor)
                        }
                    }
                    
                    if 1...50 ~= model.selectedFiles.count {
                        Image(systemName: "\(model.selectedFiles.count).circle.fill")
                            .imageScale(.small)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .scaleEffect(badgeScale)
                            .foregroundColor(Color.white)
                            .colorMultiply(badgeColor)
                            .onAppear {
                                badgeAnimation()
                            }
                            .onChange(of: model.selectedFiles) { _, _ in
                                badgeAnimation()
                            }
                            .allowsHitTesting(false)
                    }
                    else if model.selectedFiles.count > 50 {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.small)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .scaleEffect(badgeScale)
                            .foregroundColor(Color.white)
                            .colorMultiply(badgeColor)
                            .onAppear {
                                badgeAnimation()
                            }
                            .onChange(of: model.selectedFiles) { _, _ in
                                badgeAnimation()
                            }
                            .allowsHitTesting(false)
                    }
                }
                .help("Paste selected items")
                
                Picker(doNotLocalize, selection: $selectedPane, content: { // MARK: Console/Error segmented control
                    ForEach(CLIPane.allCases, content: { pane in
                        Text(pane.localizedString)
                    })
                })
                .pickerStyle(.segmented)
                .labelsHidden()
                .clipped()
                
                SearchField(prompt: String(localized: "🔍 Search"), text: $model.consoleFilter)
                    .frame(width: 200)
            }
            .padding(8)
            
            switch selectedPane {
            case .console:
                ConsoleView(command: $command, console: $model.stdoutConsole)
            case .errors:
                ConsoleView(command: $command, console: $model.stderrConsole, isStderr: true)
            }
        }
    }
}

/// Renders a history of commands and their output, approximating a terminal emulator.
struct ConsoleView: View {
    @EnvironmentObject private var model: ContentViewModel
    /// Current command.
    @Binding var command: String
    @FocusState private var isFocused: Bool
    /// Console history.
    @Binding var console: [CLIOutput]
    /// Whether this is the error console (stderr).
    var isStderr = false
    
    private let terminalFont = Font.system(size: 12).monospaced()
    @Namespace private var bottomID
    
    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                ScrollView { // MARK: Command history
                    ForEach($console) { $consoleItem in
                        ConsoleItemView(isStderr: isStderr, isGrouped: true, consoleItem: $consoleItem, terminalFont: terminalFont)
                            .onChange(of: console) { _, _ in
                                DispatchQueue.main.async {
                                    proxy.scrollTo(bottomID)
                                }
                            }
                    }
                    
                    Text(verbatim: "")
                        .frame(height: 0)
                        .id(bottomID)
                }
                
                HStack(alignment: .top, spacing: 0) { // MARK: Command prompt text field
                    Text("\(model.currentDirectory.name) \(Image(systemName: "arrow.right.circle")) ")
                        .font(terminalFont)
                        .foregroundColor(.green)
                    
                    // Enable SUPPORT_IME if you need input methods (e.g., for CJK languages), but that'll
                    // cost you custom keyboard support.
                    #if !SUPPORT_IME
                    CommandPrompt(text: $command, onCommit: {
                        model.run(prompt: "\(model.currentDirectory.name) % ", command: command)
                    }, onControlKey: { key in
                        if key == "c" {
                            model.interrupt()
                        }
                    })
                    .focused($isFocused)
                    .focusEffectDisabled()
                    .font(terminalFont)
                    #else
                    TextEditor(text: $command)
                        .autocorrectionDisabled()
                        .scrollContentBackground(.hidden)
                        .scrollIndicators(.never)
                        .font(terminalFont)
                        .focused($isFocused)
                        .fixedSize(horizontal: false, vertical: true)
                        .onChange(of: command) { _, _ in
                            // FIXME: autocorrectionDisabled really should've disabled these replacements
                            command = command.replacingOccurrences(of: "—", with: "--")
                            command = command.replacingOccurrences(of: "”", with: "\"")
                            command = command.replacingOccurrences(of: "“", with: "\"")
                            
                            if command.last?.isNewline ?? false {
                                model.run(prompt: "\(model.currentDirectory.name) % ", command: command)
                                command = ""
                            }
                        }
                        .padding(0)
                    #endif // !SUPPORT_IME
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onAppear {
                isFocused = true
                proxy.scrollTo(bottomID)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }
}

#if !SUPPORT_IME
/// Renders a command and its output
struct ConsoleItemView: View {
    @EnvironmentObject private var model: ContentViewModel
    /// Whether the item was emitted to the error stream (stderr).
    var isStderr = false
    /// Whether the item should be rendered as a group (suitable for the CLI history console) or not (suitable for the pop-out window).
    var isGrouped = false
    /// Item to render.
    @Binding var consoleItem: CLIOutput
    /// Font to use.
    var terminalFont: Font
    @State private var isShowingMarkdownPopup = false
    @State private var markdownPopupURL: URL?
    
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        let color: Color = {
            if isStderr {
                return .orange
            }
            if let terminationStatus = consoleItem.terminationStatus {
                return terminationStatus == 0 ? .green : .red
            }
            return .cyan
        }()
        
        if isGrouped {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    Text(consoleItem.prompt) // MARK: Prompt and command
                    Text(consoleItem.command)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Text(consoleItem.date, style: .relative)
                        .monospacedDigit()
                        .padding(.leading, 16)
                    
                    if let terminationStatus = consoleItem.terminationStatus {
                        if terminationStatus != 0 { // MARK: Termination status
                            Image(systemName: "return.right")
                                .padding(.leading, 16)
                            Text(verbatim: "\(consoleItem.terminationStatus ?? 0)")
                        }
                    }
                    else {
                        Button { // MARK: Stop task
                            model.stop(consoleItem.id)
                        } label: {
                            Image(systemName: "exclamationmark.octagon")
                                .foregroundColor(Color(NSColor.textBackgroundColor))
                        }
                        .padding(.leading, 16)
                        .buttonStyle(.plain)
                   }
                    
                    Button { // MARK: Pop-out button
                        openWindow(value: consoleItem)
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.forward")
                            .foregroundColor(Color(NSColor.textBackgroundColor))
                    }
                    .padding(.leading, 16)
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
                .padding(.horizontal, 4)
                .foregroundColor(Color(NSColor.textBackgroundColor))
                .background(Rectangle().fill(color))
                
                if let textItem = consoleItem as? CLIAttributedTextOutput {
                    Text(textItem.text) // MARK: Command output
                        .lineLimit(nil)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(terminalFont)
                        .textSelection(.enabled) // FIXME: which causes line height change when clicked?
                        .padding(.horizontal, 4)
                        .padding(.bottom, 2)
                }
                else if let imageItem = consoleItem as? CLIImageOutput {
                    if let imageData = imageItem.imageData,
                       let image = NSImage(data: imageData) {
                        Image(nsImage: image)
                            .scaledToFit()
                            .frame(maxWidth: 1024, maxHeight: 1024)
                    }
                    else {
                        Image(systemName: "photo")
                            .imageScale(.large)
                    }
                }
                else if let textItem = consoleItem as? CLITextOutput {
                    Markdown(textItem.text)
                        .environment(\.openURL, OpenURLAction { url in
                            if url.isFileURL {
                                markdownPopupURL = url
                                isShowingMarkdownPopup = true
                                return .handled
                            }
                            return .systemAction
                        })
                        .popover(isPresented: $isShowingMarkdownPopup, attachmentAnchor: .point(.center)) {
                            if let markdownPopupURL {
                                List {
                                    Button("Open") {
                                        model.open(File(url: markdownPopupURL))
                                        isShowingMarkdownPopup = false
                                    }
                                    Button("Get Info") {
                                        openWindow(value: File(url: markdownPopupURL))
                                        isShowingMarkdownPopup = false
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .markdownTheme(.terminador)
                }
            }
            .background(RoundedRectangle(cornerRadius: 8).stroke(color))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.vertical, 1)
        }
        else {
            if let textItem = consoleItem as? CLIAttributedTextOutput {
                Text(textItem.text) // MARK: Command output for pop-out window
                    .lineLimit(nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(terminalFont)
                    .textSelection(.enabled)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)
            }
            else if let imageItem = consoleItem as? CLIImageOutput {
                if let imageData = imageItem.imageData,
                   let image = NSImage(data: imageData) {
                    Image(nsImage: image)
                }
                else {
                    Image(systemName: "photo")
                        .imageScale(.large)
                }
            }
            else if let textItem = consoleItem as? CLITextOutput {
                Markdown(textItem.text)
                    .environment(\.openURL, OpenURLAction { url in
                        print(url)
                        return .handled
                    })
            }
        }
    }
}
#endif // !SUPPORT_IME

@_documentation(visibility: private)
struct CLIDetailView_Previews: PreviewProvider {
    static var previews: some View {
        CLIDetailView()
            .environmentObject(ContentViewModel())
    }
}

extension Theme {
    static let terminador = Theme.basic
        .link {
            UnderlineStyle(.single)
        }
}
