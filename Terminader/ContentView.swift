//
//  ContentView.swift
//  Terminader
//
//  Created by Steven Huang on 9/19/23.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var model: ContentViewModel
    @State var isGUI: Bool = true
    
    var body: some View {
        NavigationSplitView {
            List {
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
            ToolbarItem(placement: .navigation) {
                Button {
                    model.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!model.canGoBack())
                .help("See folders you viewed previously")
            }
            
            ToolbarItem(placement: .navigation) {
                Button {
                    model.goForward()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!model.canGoForward())
            }
            
            ToolbarItem(placement: .navigation) {
                Picker("", selection: $model.selectedPathComponent) {
                    ForEach(0..<model.pathComponentsArray.count, id: \.self) { index in
                        // HACK: the trailing space prevents the picker from truncating the item
                        Text(model.pathComponentsArray[index].name + " ")
                    }
                }
            }
            
            ToolbarItem {
                Button {
                    isGUI.toggle()
                } label: {
                    Image(systemName: isGUI ? "terminal" : "macwindow")
                }
                .help(isGUI ? "Switch to Terminal" : "Switch to graphical interface")
            }
        }
        .navigationTitle("")
        .environmentObject(model)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(model: ContentViewModel())
    }
}
