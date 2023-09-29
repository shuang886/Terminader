//
//  GUIDetailView.swift
//  Terminader
//
//  Created by Steven Huang on 9/20/23.
//

import SwiftUI
import WrappingHStack

/// Renders a graphical (Finder) interface, a grid of files and directories in the current directory.
struct GUIDetailView: View {
    @EnvironmentObject var model: ContentViewModel
    
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack {
            ScrollView {
                WrappingHStack(alignment: .topLeading, horizontalSpacing: 32, verticalSpacing: 32) { // MARK: Grid
                    ForEach(model.currentDirectoryFiles) { file in
                        VStack {
                            let (icon, color) = file.icon
                            Image(systemName: icon) // MARK: File/directory icon
                                .resizable()
                                .scaledToFit()
                                .fontWeight(.ultraLight)
                                .foregroundColor(color ?? Color(NSColor.textColor))
                                .frame(width: model.iconSize, height: model.iconSize)
                                .padding(4)
                                .background(RoundedRectangle(cornerRadius: 6).fill(model.selectedFiles.contains(file) ? Color(NSColor.controlColor) : .clear))
                            Text(file.name) // MARK: File/directory name
                                .truncationMode(.middle)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .padding(.horizontal, 4)
                                .background(RoundedRectangle(cornerRadius: 3).fill(model.selectedFiles.contains(file) ? .blue : .clear))
                                .frame(width: model.iconSize + 16)
                        }
                        .gesture(TapGesture(count: 2).onEnded { // double-click
                            model.open(file)
                        })
                        .simultaneousGesture(TapGesture().modifiers(.command).onEnded { // command-click
                            if model.selectedFiles.contains(file) {
                                model.deselect(file)
                            }
                            else {
                                model.select(file, add: true)
                            }
                        })
                        .gesture(TapGesture().onEnded { // single click
                            model.select(file)
                        })
                        .contextMenu {
                            Button("Open") {
                                model.open(file)
                            }
                            Button("Get Info") {
                                model.select(file)
                                for file in model.selectedFiles {
                                    openWindow(value: file)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .onTapGesture {
                model.deselectAll()
            }
            
            HStack { // MARK: Status bar
                Spacer()
                let availableSpace: String = {
                    if let space = model.availableSpace {
                        let formatter = MeasurementFormatter()
                        formatter.unitOptions = .naturalScale
                        return formatter.string(from: space)
                    }
                    return "0"
                }()
                if model.selectedFiles.isEmpty {
                    Text("\(model.currentDirectoryFiles.count) items, \(availableSpace) available")
                        .frame(alignment: .center)
                }
                else {
                    Text("\(model.selectedFiles.count) of \(model.currentDirectoryFiles.count) selected, \(availableSpace) available")
                        .frame(alignment: .center)
                }
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

@_documentation(visibility: private)
struct GUIDetailView_Previews: PreviewProvider {
    static var previews: some View {
        GUIDetailView()
    }
}
