//
//  CLIDetailView.swift
//  Terminader
//
//  Created by Steven Huang on 9/20/23.
//

import SwiftUI

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

class CLIOutput: Identifiable, Equatable, Hashable, Codable {
    var id = UUID()
    var prompt: String = ""
    var command: String = ""
    var terminationStatus: Int32 = 0
    
    init(prompt: String, command: String, terminationStatus: Int32) {
        self.prompt = prompt
        self.command = command
        self.terminationStatus = terminationStatus
    }
    
    static func == (lhs: CLIOutput, rhs: CLIOutput) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

class CLITextOutput: CLIOutput {
    var text: AttributedString
    private enum CodingKeys: String, CodingKey { case text }
    
    init(prompt: String, command: String, terminationStatus: Int32, text: AttributedString) {
        self.text = text
        super.init(prompt: prompt, command: command, terminationStatus: terminationStatus)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.text = try container.decode(AttributedString.self, forKey: .text)
        try super.init(from: decoder)
    }
}

struct CLIDetailView: View {
    @EnvironmentObject private var model: ContentViewModel
    @State private var selectedPane = CLIPane.console
    @State private var command = ""
    @State private var badgeScale = 1.0
    @State private var badgeColor = Color.clear
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    command = command.trimmingCharacters(in: .whitespaces)
                    for file in model.selectedFiles {
                        command += " " + file.url.path
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
                            .onChange(of: model.selectedFiles) { _ in
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
                            .onChange(of: model.selectedFiles) { _ in
                                badgeAnimation()
                            }
                            .allowsHitTesting(false)
                    }
                }
                .help("Paste selected items")
                
                Picker("", selection: $selectedPane, content: {
                    ForEach(CLIPane.allCases, content: { pane in
                        Text(pane.localizedString)
                    })
                })
                .pickerStyle(.segmented)
                .labelsHidden()
                .clipped()
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

struct ConsoleView: View {
    @EnvironmentObject private var model: ContentViewModel
    @Binding var command: String
    @FocusState private var isFocused: Bool
    @Binding var console: [CLIOutput]
    var isStderr = false
    
    private let terminalFont = Font.system(size: 12).monospaced()
    @Namespace private var bottomID
    
    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                ScrollView {
                    ForEach(console) { consoleItem in
                        ConsoleItemView(isStderr: isStderr, isGrouped: true, consoleItem: consoleItem, terminalFont: terminalFont)
                            .onChange(of: console) { _ in
                                DispatchQueue.main.async {
                                    proxy.scrollTo(bottomID)
                                }
                            }
                    }
                    
                    Text("")
                        .frame(height: 0)
                        .id(bottomID)
                }
                
                HStack(alignment: .top, spacing: 0) {
                    Text("\(model.currentDirectory.name) \(Image(systemName: "arrow.right.circle")) ")
                        .font(terminalFont)
                        .foregroundColor(.green)
                    
                    TextEditor(text: $command)
                        .autocorrectionDisabled()
                        .scrollContentBackground(.hidden)
                        .scrollIndicators(.never)
                        .font(terminalFont)
                        .focused($isFocused)
                        .fixedSize(horizontal: false, vertical: true)
                        .onChange(of: command) { _ in
                            if command.last?.isNewline ?? false {
                                model.run(prompt: "\(model.currentDirectory.name) % ", command: command)
                                command = ""
                            }
                        }
                        .padding(0)
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

struct ConsoleItemView: View {
    var isStderr = false
    var isGrouped = false
    var consoleItem: CLIOutput
    var terminalFont: Font
    
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        let color: Color = {
            if isStderr {
                return Color.orange
            }
            return consoleItem.terminationStatus != 0 ? Color.red : Color.cyan
        }()
        
        if let textItem = consoleItem as? CLITextOutput {
            if isGrouped {
                VStack {
                    HStack(alignment: .top, spacing: 0) {
                        Text(textItem.prompt)
                        Text(textItem.command)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        if textItem.terminationStatus != 0 {
                            Image(systemName: "return.right")
                            Text("\(textItem.terminationStatus)")
                        }
                        
                        Button {
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
                    
                    Text(textItem.text)
                        .lineLimit(nil)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(terminalFont)
                        .textSelection(.enabled)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 2)
                }
                .background(RoundedRectangle(cornerRadius: 8).stroke(color))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.vertical, 1)
            }
            else {
                Text(textItem.text)
                    .lineLimit(nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(terminalFont)
                    .textSelection(.enabled)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)
            }
        }
    }
}

struct CLIDetailView_Previews: PreviewProvider {
    static var previews: some View {
        CLIDetailView()
            .environmentObject(ContentViewModel())
    }
}
