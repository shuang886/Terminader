//
//  ContentViewModel.swift
//  Terminader
//
//  Created by Steven Huang on 9/19/23.
//

import SwiftUI

struct File: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    var name: String { url.localizedName ?? url.lastPathComponent }
    var icon: (String, Color?) { (url.isDirectory ?? false) ? ("folder.fill", .cyan) : ("doc", nil) }
    var sidebarIcon: String?
}

class ContentViewModel: ObservableObject {
    @Published var currentDirectoryIndex: Int {
        didSet {
            populateCurrentDirectoryFiles()
        }
    }
    @Published var currentDirectoryFiles: [File] = []
    @Published var favorites: [File] = []
    @Published var iconSize: CGFloat = 72
    @Published var navigationHistory: [File]
    @Published var selectedFiles: Set<File> = []
    @Published var console: AttributedString = ""
    
    var currentDirectory: File { navigationHistory[currentDirectoryIndex] }

    init() {
        self.navigationHistory = [ File(url: FileManager.default.homeDirectoryForCurrentUser) ]
        self.currentDirectoryIndex = 0
        
        self.favorites = [
            File(url: URL(filePath: NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true)[0]), sidebarIcon: "menubar.dock.rectangle"),
            File(url: URL(filePath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]), sidebarIcon: "doc"),
            File(url: URL(filePath: NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true)[0]), sidebarIcon: "arrow.down.circle"),
        ]
        
        populateCurrentDirectoryFiles()
    }
    
    func open(_ file: File) {
        if file.url.isDirectory ?? false {
            // remove forward history, if any
            navigationHistory.removeLast(navigationHistory.count - (currentDirectoryIndex + 1))
            
            navigationHistory.append(file)
            currentDirectoryIndex += 1
        }
    }
    
    func canGoBack() -> Bool
    {
        currentDirectoryIndex > 0
    }
    
    func goBack() {
        if canGoBack() {
            currentDirectoryIndex -= 1
        }
    }
    
    func canGoForward() -> Bool {
        currentDirectoryIndex < navigationHistory.count - 1
    }
    
    func goForward() {
        if canGoForward() {
            currentDirectoryIndex += 1
        }
    }
    
    func select(_ file: File, add: Bool = false) {
        if add {
            selectedFiles.insert(file)
        }
        else {
            selectedFiles = [file]
        }
    }
    
    func run(_ command: String) {
        console += AttributedString(command)
    }
    
    private func populateCurrentDirectoryFiles() {
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(at: currentDirectory.url, includingPropertiesForKeys: [])
            var files: [File] = []
            for url in directoryContents.filter({ !($0.isHidden ?? false) }) {
                files.append(File(url: url))
            }
            currentDirectoryFiles = files
        } catch {
        }
    }
}

extension URL {
    var isHidden: Bool? { (try? resourceValues(forKeys: [.isHiddenKey]))?.isHidden }
    var isDirectory: Bool? { (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory }
    var localizedName: String? { (try? resourceValues(forKeys: [.localizedNameKey]))?.localizedName }
    var typeIdentifier: String? { (try? resourceValues(forKeys: [.typeIdentifierKey]))?.typeIdentifier }
}
