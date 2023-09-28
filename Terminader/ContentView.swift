//
//  ContentView.swift
//  Terminader
//
//  Created by Steven Huang on 9/19/23.
//

import SwiftUI

let doNotLocalize = ""

struct ContentView: View {
    @StateObject var model = ContentViewModel()
    /// Whether the window is in GUI mode or CLI mode.
    @State var isGUI: Bool = true
    
    var body: some View {
        NavigationSplitView {
            List { // MARK: Sidebar
                Section("Favorites") {
                    ForEach(model.favorites) { favorite in
                        Button {
                            model.open(favorite)
                        } label: {
                            Label(favorite.name, systemImage: favorite.sidebarIcon ?? "folder")
                                .frame(alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Section("iCloud") {
                    Label("iCloud Drive", systemImage: "cloud")
                        .frame(alignment: .leading)
                }
                Section("Locations") {
                    Label("Network", systemImage: "globe")
                        .frame(alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } detail: {
            if (isGUI) {
                GUIDetailView()
            }
            else {
                CLIDetailView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) { // MARK: Back button
                Button {
                    model.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!model.canGoBack())
                .help("See folders you viewed previously")
            }
            
            ToolbarItem(placement: .navigation) { // MARK: Forward button
                Button {
                    model.goForward()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!model.canGoForward())
            }
            
            ToolbarItem(placement: .navigation) { // MARK: Path components picker
                Picker(doNotLocalize, selection: $model.selectedPathComponent) {
                    ForEach(0..<model.pathComponentsArray.count, id: \.self) { index in
                        // FIXME: the trailing space prevents the picker from truncating the item
                        Text(model.pathComponentsArray[index].name + " ")
                    }
                }
            }
            
            ToolbarItem { // MARK: GUI/CLI (Terminal/Finder) toggle
                Button {
                    isGUI.toggle()
                } label: {
                    Image(systemName: isGUI ? "terminal" : "macwindow")
                }
                .help(isGUI ? "Switch to Terminal" : "Switch to graphical interface")
            }
        }
        .navigationTitle(Text(verbatim: ""))
        .environmentObject(model)
    }
}

@_documentation(visibility: private)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(model: ContentViewModel())
    }
}
