//
//  GUIDetailView.swift
//  Terminader
//
//  Created by Steven Huang on 9/20/23.
//

import SwiftUI
import WrappingHStack

struct GUIDetailView: View {
    @EnvironmentObject var model: ContentViewModel
    
    @Environment(\.openWindow) private var openWindow
    
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
                        .contextMenu {
                            Button("Get Info") {
                                openWindow(value: file)
                            }
                        }
                    }
                }
                .padding()
            }
            HStack {
                Spacer()
                let filesCount = model.currentDirectoryFiles.count.formatted()
                let availableSpace: String = {
                    if let space = model.availableSpace {
                        let formatter = MeasurementFormatter()
                        formatter.unitOptions = .naturalScale
                        let spaceString = formatter.string(from: space)
                        return ", \(spaceString) available"
                    }
                    return ""
                }()
                Text("\(filesCount) item(s)\(availableSpace)")
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

struct GUIDetailView_Previews: PreviewProvider {
    static var previews: some View {
        GUIDetailView()
    }
}
