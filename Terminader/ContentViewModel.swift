//
//  ContentViewModel.swift
//  Terminader
//
//  Created by Steven Huang on 9/19/23.
//

import SwiftUI

struct File: Identifiable, Codable, Hashable {
    let id = UUID()
    let url: URL
    var name: String { url.localizedName ?? url.lastPathComponent }
    var icon: (String, Color?) { (url.isDirectory ?? false) ? ("folder.fill", .cyan) : ("doc", nil) }
    var sidebarIcon: String?
}

class ContentViewModel: ObservableObject {
    @Published var currentDirectoryIndex: Int {
        didSet {
            currentDirectoryDidChange()
        }
    }
    @Published var currentDirectoryFiles: [File] = []
    @Published var favorites: [File] = []
    @Published var iconSize: CGFloat = 72
    @Published var navigationHistory: [File]
    @Published var pathComponentsArray: [File] = []
    @Published var selectedFiles: Set<File> = []
    @Published var selectedPathComponent: Int = 0 {
        didSet {
            if selectedPathComponent != 0 {
                open(pathComponentsArray[selectedPathComponent])
            }
        }
    }
    @Published var stdoutConsole: [CLIOutput] = []
    @Published var stderrConsole: [CLIOutput] = []
    
    var currentDirectory: File { navigationHistory[currentDirectoryIndex] }
    var availableSpace: Measurement<UnitInformationStorage>? {
        if let dictionary = try? FileManager.default.attributesOfFileSystem(forPath: currentDirectory.url.path),
           let freeSize = dictionary[FileAttributeKey.systemFreeSize] as? NSNumber {
            return Measurement(value: freeSize.doubleValue, unit: .bytes)
        }
        return nil
    }
    
    init() {
        self.navigationHistory = [ File(url: FileManager.default.homeDirectoryForCurrentUser) ]
        self.currentDirectoryIndex = 0
        
        self.favorites = [
            File(url: URL(filePath: NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true)[0]), sidebarIcon: "menubar.dock.rectangle"),
            File(url: URL(filePath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]), sidebarIcon: "doc"),
            File(url: URL(filePath: NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true)[0]), sidebarIcon: "arrow.down.circle"),
            File(url: URL(filePath: NSSearchPathForDirectoriesInDomains(.moviesDirectory, .userDomainMask, true)[0]), sidebarIcon: "film"),
            File(url: URL(filePath: NSSearchPathForDirectoriesInDomains(.musicDirectory, .userDomainMask, true)[0]), sidebarIcon: "music.note"),
            File(url: URL(filePath: NSSearchPathForDirectoriesInDomains(.picturesDirectory, .userDomainMask, true)[0]), sidebarIcon: "photo"),
            File(url: FileManager.default.homeDirectoryForCurrentUser, sidebarIcon: "house"),
        ]
        
        currentDirectoryDidChange()
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
    
    func run(prompt: String, command: String) {
        let promptCommand = prompt + command.trimmingCharacters(in: .newlines)
        
        // FIXME: need to handle quotes and backslash escapes
        let commandParts = command.components(separatedBy: .whitespacesAndNewlines)
        switch commandParts[0] {
        case "cd":
            chdir(commandParts)
        default:
            let task = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            
            task.standardOutput = stdoutPipe
            task.standardError = stderrPipe
            task.arguments = ["-c", command]
            task.launchPath = "/bin/zsh"
            task.standardInput = nil
            task.currentDirectoryURL = currentDirectory.url
            task.launch()
            
            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stdoutString = String(data: stdoutData, encoding: .utf8)!.trimmingCharacters(in: .newlines)
            stdoutConsole.append(CLITextOutput(prompt: promptCommand,
                                               terminationStatus: task.terminationStatus,
                                               text: AttributedString(stdoutString)))
            
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrString = String(data: stderrData, encoding: .utf8)!.trimmingCharacters(in: .newlines)
            if !stderrString.isEmpty {
                stderrConsole.append(CLITextOutput(prompt: promptCommand,
                                                   terminationStatus: task.terminationStatus,
                                                   text: AttributedString(stderrString)))
            }
        }
    }
    
    private func chdir(_ commandParts: [String]) {
        let destination: URL? = {
            if commandParts.count == 1 || commandParts[1].isEmpty {
                return FileManager.default.homeDirectoryForCurrentUser
            }
            else {
                let destination = currentDirectory.url.appending(component: commandParts[1])
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                    return destination
                }
                return nil
            }
        }()
        
        if let destination {
            open(File(url: destination))
        }
    }
    
    private func currentDirectoryDidChange() {
        do {
            // list the files in the new current directory
            let directoryContents = try FileManager.default.contentsOfDirectory(at: currentDirectory.url, includingPropertiesForKeys: [])
            currentDirectoryFiles = []
            for url in directoryContents.filter({ !($0.isHidden ?? false) }).sorted(by: { $0.path < $1.path }) {
                currentDirectoryFiles.append(File(url: url))
            }
            
            // break the path into components
            let rootDirectory = URL(filePath: NSOpenStepRootDirectory())
            var directory = currentDirectory
            pathComponentsArray = []
            while directory.url != rootDirectory {
                pathComponentsArray.append(directory)
                directory = File(url: directory.url.deletingLastPathComponent())
            }
            selectedPathComponent = 0
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
