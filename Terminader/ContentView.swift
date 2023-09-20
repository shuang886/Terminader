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

struct GUIDetailView: View {
    @EnvironmentObject var model: ContentViewModel
    
    var body: some View {
        VStack {
            ScrollView {
                WrappingHStack(alignment: .topLeading, horizontalSpacing: 32, verticalSpacing: 32) {
                    ForEach(model.currentDirectoryFiles) { file in
                        VStack {
                            let (icon, color) = file.icon
                            Image(systemName: icon)
                                .resizable()
                                .scaledToFit()
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
}

struct CLIDetailView: View {
    @EnvironmentObject private var model: ContentViewModel
    @State private var command: String = ""
    @FocusState private var isFocused: Bool
    
    private let terminalFont = Font.system(size: 12).monospaced()
    @Namespace private var bottomID

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                ScrollView {
                    Text(model.console)
                        .lineLimit(0, reservesSpace: false)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(terminalFont)
                        .textSelection(.enabled)
                    
                    EmptyView()
                        .id(bottomID)
                }

                HStack(spacing: 0) {
                    Text("\(model.currentDirectory.name) \(Image(systemName: "arrow.right.circle")) ")
                        .font(terminalFont)
                    
                    TextEditor(text: $command)
                        .scrollContentBackground(.hidden)
                        .scrollIndicators(.never)
                        .font(terminalFont)
                        .focused($isFocused)
                        .fixedSize(horizontal: false, vertical: true)
                        .onChange(of: command) { _ in
                            if command.last?.isNewline ?? false {
                                model.run(command)
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
            .padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
