//
//  ContentView.swift
//  Terminader
//
//  Created by Steven Huang on 9/19/23.
//

import SwiftUI

struct ContentView: View {
    @StateObject var model = ContentViewModel()
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
            }
            
            ToolbarItem(placement: .navigation) {
                Button {
                    model.goForward()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!model.canGoForward())
            }
            
            ToolbarItem {
                Button {
                    isGUI.toggle()
                } label: {
                    Image(systemName: isGUI ? "terminal" : "macwindow")
                }
            }
        }
        .navigationTitle("")
        .environmentObject(model)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
