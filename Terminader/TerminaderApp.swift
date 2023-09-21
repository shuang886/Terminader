//
//  TerminaderApp.swift
//  Terminader
//
//  Created by Steven Huang on 9/19/23.
//

import SwiftUI

@main
struct TerminaderApp: App {
    @StateObject var model = ContentViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
        
        WindowGroup(for: File.self) { file in
            let title = file.wrappedValue?.name ?? "Unknown"
            
            VStack {
                Text("Info pane")
            }
            .navigationTitle("\(title) Info")
        }
        
        WindowGroup(for: CLIOutput.self) { output in
            if let consoleItem = output.wrappedValue {
                let terminalFont = Font.system(size: 16).monospaced()
                ScrollView {
                    ConsoleItemView(consoleItem: consoleItem, terminalFont: terminalFont)
                }
                .navigationTitle("\(consoleItem.command) — \(consoleItem.terminationStatus)")
            }
        }
    }
}

