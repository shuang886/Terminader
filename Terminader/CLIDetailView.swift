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

struct CLIDetailView: View {
    @EnvironmentObject private var model: ContentViewModel
    @State private var selectedPane = CLIPane.console
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedPane, content: {
                ForEach(CLIPane.allCases, content: { pane in
                    Text(pane.localizedString)
                })
            })
            .pickerStyle(.segmented)
            .labelsHidden()
            .clipped()
            .padding(4)
            
            switch selectedPane {
            case .console:
                ConsoleView(console: $model.stdoutConsole)
            case .errors:
                ConsoleView(console: $model.stderrConsole)
            }
        }
    }
}

struct ConsoleView: View {
    @EnvironmentObject private var model: ContentViewModel
    @State private var command: String = ""
    @FocusState private var isFocused: Bool
    @Binding var console: AttributedString
    
    private let terminalFont = Font.system(size: 12).monospaced()
    @Namespace private var bottomID
    
    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                ScrollView {
                    Text(console)
                        .lineLimit(nil)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(terminalFont)
                        .textSelection(.enabled)
                        .onChange(of: console) { _ in
                            DispatchQueue.main.async {
                                proxy.scrollTo(bottomID)
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

struct CLIDetailView_Previews: PreviewProvider {
    static var previews: some View {
        CLIDetailView()
            .environmentObject(ContentViewModel())
    }
}
