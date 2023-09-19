//
//  ContentView.swift
//  Terminader
//
//  Created by Steven Huang on 9/19/23.
//

import SwiftUI
import WrappingHStack

struct ContentView: View {
    @StateObject var model = ContentViewModel()
    
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
            VStack {
                ScrollView {
                    WrappingHStack(alignment: .topLeading, horizontalSpacing: 32, verticalSpacing: 32) {
                        ForEach(model.currentDirectoryFiles) { file in
                            VStack {
                                let (icon, color) = file.icon
                                Image(systemName: icon)
                                    .resizable()
                                    .foregroundColor(color ?? Color(NSColor.controlColor))
                                    .frame(width: model.iconSize, height: model.iconSize)
                                    .padding(4)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(model.selectedFiles.contains(file) ? Color(NSColor.controlColor) : .clear))
                                Text(file.name)
                                    .truncationMode(.middle)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                    .padding(.horizontal, 4)
                                    .background(RoundedRectangle(cornerRadius: 3).fill(model.selectedFiles.contains(file) ? .blue : .clear))
                                    .frame(width: model.iconSize + 16)
                            }
                            .gesture(TapGesture(count: 2).onEnded {
                                model.open(file)
                            })
                            .simultaneousGesture(TapGesture().onEnded {
                                model.select(file)
                            })
                        }
                    }
                    .padding()
                }
                HStack {
                    Spacer()
                    Text("\(model.currentDirectoryFiles.count.formatted()) items")
                        .frame(alignment: .center)
                    Spacer()
                    Slider(value: $model.iconSize, in: 32...512)
                        .frame(maxWidth: 100)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Rectangle().fill(.quaternary))
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
                    
                } label: {
                    Image(systemName: "terminal")
                }
            }
        }
        .navigationTitle("")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
