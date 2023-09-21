//
//  ContentViewModel.swift
//  Terminader
//
//  Created by Steven Huang on 9/19/23.
//

import SwiftUI

struct File: Identifiable, Codable, Hashable {
    var id = UUID()
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
    
    func deselect(_ file: File) {
        selectedFiles.remove(file)
    }
    
    var stdoutString: String?
    
    func run(prompt: String, command: String) {
        let command = command.trimmingCharacters(in: .newlines)
        
        // FIXME: need to handle quotes and backslash escapes
        let commandParts = command.components(separatedBy: .whitespacesAndNewlines)
        switch commandParts[0] {
        case "cd":
            chdir(commandParts)
        case "select":
            select(commandParts)
        case "deselect":
            deselect(commandParts)
        default:
            let task = Process()
            let masterFD = posix_openpt(O_RDWR)
            grantpt(masterFD)
            unlockpt(masterFD)
            let masterFile = FileHandle(fileDescriptor: masterFD)
            let slavePath = String(cString: ptsname(masterFD))
            let slaveFile = FileHandle(forUpdatingAtPath: slavePath)
            let stderrPipe = Pipe()
            
            task.standardInput = slaveFile
            task.standardOutput = slaveFile
            task.standardError = stderrPipe
            task.arguments = ["-c", command]
            task.launchPath = "/bin/zsh"
            task.environment = [
                "TERM" : "xterm-256color",
                "CLICOLOR" : "1",
            ]
            task.currentDirectoryURL = currentDirectory.url
            
            stdoutString = ""
            masterFile.readabilityHandler = { [self] _ in
                let stdoutData = masterFile.availableData
                stdoutString! += String(data: stdoutData, encoding: .utf8) ?? ""
            }
            
            task.terminationHandler = { [self] _ in
                masterFile.readabilityHandler = nil
                
                DispatchQueue.main.async { [self] in
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrString = String(data: stderrData, encoding: .utf8)!.trimmingCharacters(in: .newlines)
                    if !stderrString.isEmpty {
                        stderrConsole.append(CLITextOutput(prompt: prompt,
                                                           command: command,
                                                           terminationStatus: task.terminationStatus,
                                                           text: AttributedString(stderrString)))
                    }
                    
                    stdoutString = stdoutString?.trimmingCharacters(in: .newlines)
                    if task.terminationReason.rawValue != 0 && stdoutString!.isEmpty && !stderrString.isEmpty {
                        // special case: error termination reason and no stdout, so copy the stderr output instead
                        stdoutConsole.append(CLITextOutput(prompt: prompt,
                                                           command: command,
                                                           terminationStatus: task.terminationStatus,
                                                           text: AttributedString(stderrString)))
                    }
                    else {
                        stdoutConsole.append(CLITextOutput(prompt: prompt,
                                                           command: command,
                                                           terminationStatus: task.terminationStatus,
                                                           text: AttributedString.create(fromANSI: stdoutString!)))
                    }
                }
            }
            
            do {
                try task.run()
            } catch {
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
    
    private func select(_ commandParts: [String]) {
        for part in commandParts.dropFirst(1) where !part.isEmpty {
            for currentDirectoryFile in currentDirectoryFiles {
                if currentDirectoryFile.url.lastPathComponent.matchesWildcard(part) {
                    selectedFiles.insert(currentDirectoryFile)
                }
            }
        }
    }
    
    private func deselect(_ commandParts: [String]) {
        for part in commandParts.dropFirst(1) where !part.isEmpty {
            for currentDirectoryFile in currentDirectoryFiles {
                if currentDirectoryFile.url.lastPathComponent.matchesWildcard(part) {
                    selectedFiles.remove(currentDirectoryFile)
                }
            }
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

extension String {
    func matchesWildcard(_ pattern: String) -> Bool {
        // Translated from https://www.geeksforgeeks.org/wildcard-pattern-matching/
        // Variable names kept to match source
        
        let text = self
        let n = text.endIndex
        let m = pattern.endIndex
        var startIndex: String.Index?
        var i = text.startIndex
        var j = pattern.startIndex
        var match = text.startIndex
        
        while i < n {
            if j < m && (pattern[j] == "?" || pattern[j] == text[i]) {
                // Characters match or '?' in pattern matches any character.
                i = text.index(after: i)
                j = pattern.index(after: j)
            }
            else if j < m && pattern[j] == "*" {
                // Wildcard character '*', mark the current position in the pattern and the text as a proper match.
                startIndex = j
                match = i
                j = pattern.index(after: j)
            }
            else if let startIndex {
                // No match, but a previous wildcard was found. Backtrack to the last '*' character position and try for a different match.
                j = pattern.index(after: startIndex)
                match = text.index(after: match)
                i = match
            }
            else {
                // If none of the above cases comply, the pattern does not match.
                return false
            }
        }
        
        // Consume any remaining '*' characters in the given pattern.
        while j < m && pattern[j] == "*" {
            j = pattern.index(after: j)
        }
        return j == m
    }
}

extension AttributedString {
    static func create(fromANSI string: String) -> AttributedString {
        var state = 0
        var output = AttributedString("")
        var chars: [Character] = []
        var fgColor: Int?
        var bgColor: Int?
        for char in string {
            switch state {
            case 0:
                if char == "\u{1B}" {
                    var attrString = AttributedString(chars)
                    attrString.foregroundColor = Color.create(fromANSI: fgColor)
                    attrString.backgroundColor = Color.create(fromANSI: bgColor)
                    output += attrString
                    chars = []
                    fgColor = nil
                    bgColor = nil
                    state = 1
                }
                else {
                    chars.append(char)
                }
            case 1:
                state = (char == "[") ? 2 : 0
            case 2:
                if char.isNumber {
                    fgColor = (fgColor ?? 0) * 10 + (char.wholeNumberValue ?? 0)
                }
                else if char == ";" {
                    state = 3
                }
                else {
                    state = 0
                }
            case 3:
                if char.isNumber {
                    bgColor = (bgColor ?? 0) * 10 + (char.wholeNumberValue ?? 0)
                }
                else {
                    state = 0
                }
            default:
                fatalError("invalid state")
            }
        }
        return output
    }
}

extension Color {
    static func create(fromANSI: Int?) -> Color? {
        guard let fromANSI else { return nil }
        switch fromANSI {
        case 39:      return Color(NSColor.textColor)
        case 49:      return Color(NSColor.textBackgroundColor)
        case 30, 40:  return Color("ANSIBlackColor")
        case 31, 41:  return Color("ANSIRedColor")
        case 32, 42:  return Color("ANSIGreenColor")
        case 33, 43:  return Color("ANSIYellowColor")
        case 34, 44:  return Color("ANSIBlueColor")
        case 35, 45:  return Color("ANSIMagentaColor")
        case 36, 46:  return Color("ANSICyanColor")
        case 37, 47:  return Color("ANSIWhiteColor")
        case 90, 100: return Color("ANSIBrightBlackColor")
        case 91, 101: return Color("ANSIBrightRedColor")
        case 92, 102: return Color("ANSIBrightGreenColor")
        case 93, 103: return Color("ANSIBrightYellowColor")
        case 94, 104: return Color("ANSIBrightBlueColor")
        case 95, 105: return Color("ANSIBrightMagentaColor")
        case 96, 106: return Color("ANSIBrightCyanColor")
        case 97, 107: return Color("ANSIBrightWhiteColor")
        default: return nil
        }
    }
}
