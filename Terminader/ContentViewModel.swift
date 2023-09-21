//
//  ContentViewModel.swift
//  Terminader
//
//  Created by Steven Huang on 9/19/23.
//

import SwiftUI

/// Represents a file or directory in the filesystem.
struct File: Identifiable, Codable, Hashable {
    var id = UUID()
    let url: URL
    /// Human-readable name of the file.
    var name: String { url.localizedName ?? url.lastPathComponent }
    /// SF Symbol name to use for the main view.
    var icon: (String, Color?) { (url.isDirectory ?? false) ? ("folder.fill", .cyan) : ("doc", nil) }
    /// SF Symbol name to use for the sidebar view.
    var sidebarIcon: String?
}

/// Main model representing the filesystem and browsing context.
class ContentViewModel: ObservableObject {
    /// Index of current directory into `navigationHistory`. This enables the user to browse back and forward.
    @Published var currentDirectoryIndex: Int {
        didSet {
            currentDirectoryDidChange()
        }
    }
    /// Cached list of files in the current directory, regenerated whenever the current directory changes.
    @Published var currentDirectoryFiles: [File] = []
    /// List of directories to present in the Favorites section of the sidebar.
    @Published var favorites: [File] = []
    /// Size of file/directory icons in the main view.
    @Published var iconSize: CGFloat = 72
    /// Represents the user's browsing history.
    @Published var navigationHistory: [File]
    /// Ordered list of path components from the current directory down to (but does not include) the root directory.
    @Published var pathComponentsArray: [File] = []
    /// List of currently-selected files.
    @Published var selectedFiles: Set<File> = []
    /// Currently-selected item in `pathComponentsArray`. This will generally be 0 except right after the user
    /// selects a different item, in which case pathComponentsArray is immediately truncated to the new current
    /// directory and selectedPathComponent is reset to 0.
    @Published var selectedPathComponent: Int = 0 {
        didSet {
            if selectedPathComponent != 0 {
                open(pathComponentsArray[selectedPathComponent])
            }
        }
    }
    /// List of `CLIOutput`s representing the standard output.
    @Published var stdoutConsole: [CLIOutput] = []
    /// List of `CLIOutput`s representing the error output.
    @Published var stderrConsole: [CLIOutput] = []
    
    /// Convenience to get the current directory.
    var currentDirectory: File { navigationHistory[currentDirectoryIndex] }
    /// Free space in the disk volume of the current directory.
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
    
    /// Navigates to the specified directory. Any forward history would be lost.
    /// - Parameters: Directory to navigate to.
    func open(_ file: File) {
        if file.url.isDirectory ?? false {
            // remove forward history, if any
            navigationHistory.removeLast(navigationHistory.count - (currentDirectoryIndex + 1))
            
            navigationHistory.append(file)
            currentDirectoryIndex += 1
        }
    }
    
    /// Whether back history navigation exists.
    /// - Returns: Whether the user is able to go back.
    func canGoBack() -> Bool
    {
        currentDirectoryIndex > 0
    }
    
    /// Go back to the previous entry in the navigation history.
    func goBack() {
        if canGoBack() {
            currentDirectoryIndex -= 1
        }
    }
    
    /// Whether forward navigation history exists.
    /// - Returns: Whether the user is able to go forward.
    func canGoForward() -> Bool {
        currentDirectoryIndex < navigationHistory.count - 1
    }
    
    /// Go forward to the next entry in the navigation history.
    func goForward() {
        if canGoForward() {
            currentDirectoryIndex += 1
        }
    }
    
    /// Select a file or directory.
    /// - Parameter file: The file or directory to select.
    /// - Parameter add: Whether to replace the current selection or to add to it.
    func select(_ file: File, add: Bool = false) {
        if add {
            selectedFiles.insert(file)
        }
        else {
            selectedFiles = [file]
        }
    }
    
    /// Deselect a file or directory.
    /// - Parameter file: The file or directory to deselect.
    func deselect(_ file: File) {
        selectedFiles.remove(file)
    }
    
    private var stdoutString: String?
    
    /// Execute a command.
    /// - Parameter prompt: Command prompt displayed at the time of command issuance.
    /// - Parameter command: Command entered by the user.
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
            // https://stackoverflow.com/questions/55228685/opening-new-pseudo-terminal-device-file-in-macos-with-swift
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
                // Accumulate everything in stdoutString for now, because the CLI wants to know
                // the termination reason to draw the colored borders correctly.
                // FIXME: display partial output in the CLI, perhaps with a different border color
                let stdoutData = masterFile.availableData
                stdoutString! += String(data: stdoutData, encoding: .utf8) ?? ""
            }
            
            task.terminationHandler = { [self] _ in
                masterFile.readabilityHandler = nil
                
                DispatchQueue.main.async { [self] in
                    // Nobody puts ANSI escape sequences into stderr, right?
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
                        // Special case: error termination reason and no stdout, so copy the stderr output instead
                        stdoutConsole.append(CLITextOutput(prompt: prompt,
                                                           command: command,
                                                           terminationStatus: task.terminationStatus,
                                                           text: AttributedString(stderrString)))
                    }
                    else {
                        // Process stdout through our ANSI parser.
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
                fatalError("task failed to run")
            }
        }
    }
    
    /// Internal command to change current directory
    /// - Parameter commandParts: Array of command-line parameters, including the command itself.
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
    
    /// Internal command to select specified files and directories.
    /// - Parameter commandParts: Array of command-line parameters, including the command itself. The '*' and '?' wildcard characters are honored.
    private func select(_ commandParts: [String]) {
        for part in commandParts.dropFirst(1) where !part.isEmpty {
            for currentDirectoryFile in currentDirectoryFiles {
                if currentDirectoryFile.url.lastPathComponent.matchesWildcard(part) {
                    selectedFiles.insert(currentDirectoryFile)
                }
            }
        }
    }
    
    /// Internal command to deselect specified files and directories.
    /// - Parameter commandParts: Array of command-line parameters, including the command itself. The '*' and '?' wildcard characters are honored.
    private func deselect(_ commandParts: [String]) {
        for part in commandParts.dropFirst(1) where !part.isEmpty {
            for currentDirectoryFile in currentDirectoryFiles {
                if currentDirectoryFile.url.lastPathComponent.matchesWildcard(part) {
                    selectedFiles.remove(currentDirectoryFile)
                }
            }
        }
    }
    
    /// Handles a change to the current directory by republishing variables that reflect the new state.
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
            fatalError("file manager failed to read current directory")
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
    /// Returns whether the receiver matches a supplied wildcard pattern.
    /// - Parameter pattern: Wildcard pattern that may include the '*' or '?' characters.
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
