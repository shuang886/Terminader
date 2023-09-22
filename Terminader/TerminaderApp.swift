//
//  TerminaderApp.swift
//  Terminader
//
//  Created by Steven Huang on 9/19/23.
//

import SwiftUI

@main
struct TerminaderApp: App {
    var body: some Scene {
        WindowGroup { // MARK: Main window
            ContentView()
        }
        
        WindowGroup(for: File.self) { file in // MARK: Get Info window
            let title = file.wrappedValue?.name ?? "Unknown"
            
            VStack {
                // FIXME: fill out
                Text("Info pane")
            }
            .navigationTitle("\(title) Info")
        }
        
        WindowGroup(for: CLIOutput.self) { output in // MARK: Command/output pop-out window
            if let consoleItem = output.wrappedValue {
                let terminalFont = Font.system(size: 16).monospaced()
                let status = consoleItem.terminationStatus ?? 0
                let dummy = CLIOutput(prompt: "", command: "")
                ScrollView {
                    Text(consoleItem.date, style: .relative)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .foregroundColor(.secondary)
                    ConsoleItemView(consoleItem: .bindOptional(output, dummy), terminalFont: terminalFont)
                }
                .navigationTitle(status != 0 ? "\(consoleItem.command) — \(status)" : consoleItem.command)
            }
        }
    }
}

extension Binding {
    static func bindOptional(_ source: Binding<Value?>, _ defaultValue: Value) -> Binding<Value> {
        self.init(
            get: { source.wrappedValue ?? defaultValue },
            set: { source.wrappedValue = $0 }
        )
    }
}

