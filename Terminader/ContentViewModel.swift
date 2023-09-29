//
//  ContentViewModel.swift
//  Terminader
//
//  Created by Steven Huang on 9/19/23.
//

import SwiftUI
import EonilFSEvents

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

/// Represents a single exchange of CLI command and resulting output.
class CLIOutput: Identifiable, Equatable, Hashable, Codable {
    /// Unique identifier
    var id = UUID()
    /// Date/time when command was issued
    var date: Date
    /// Command prompt at the time of issuance, mainly to mimic the look of a shell interface.
    var prompt: String = ""
    /// Command from the user.
    var command: String = ""
    /// Termination status of the application.
    var terminationStatus: Int32?
    
    init(prompt: String, command: String, terminationStatus: Int32? = nil) {
        self.date = Date.now
        self.prompt = prompt
        self.command = command
        self.terminationStatus = terminationStatus
    }
    
    static func == (lhs: CLIOutput, rhs: CLIOutput) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// A `CLIOutput` that contains only text, used to represent Markdown content or another plain text data format.
class CLITextOutput: CLIOutput {
    enum Format: Int, Decodable {
        case plain, markdown
    }
    
    /// String containing the output from the application, after certain ANSI escape sequences were parsed.
    var text: String
    var format: Format
    private enum CodingKeys: String, CodingKey { case text, format }
    
    init(prompt: String, command: String, terminationStatus: Int32? = nil, text: String, format: Format = .plain) {
        self.text = text
        self.format = format
        super.init(prompt: prompt, command: command, terminationStatus: terminationStatus)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.text = try container.decode(String.self, forKey: .text)
        self.format = try container.decode(Format.self, forKey: .format)
        try super.init(from: decoder)
    }
}

/// A `CLIOutput` that contains text that optionally renders ANSI escape sequences, used by legacy applications.
class CLIAttributedTextOutput: CLIOutput {
    /// String containing the output from the application, after certain ANSI escape sequences were parsed.
    var text: AttributedString
    private enum CodingKeys: String, CodingKey { case text }
    
    init(prompt: String, command: String, terminationStatus: Int32? = nil, text: AttributedString) {
        self.text = text
        super.init(prompt: prompt, command: command, terminationStatus: terminationStatus)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.text = try container.decode(AttributedString.self, forKey: .text)
        try super.init(from: decoder)
    }
}

/// A `CLIOutput` that contains an image.
class CLIImageOutput: CLIOutput {
    /// Data containing the image
    let imageData: Data?
    private enum CodingKeys: String, CodingKey { case imageData }
    
    init(prompt: String, command: String, terminationStatus: Int32? = nil, imageData: Data?) {
        self.imageData = imageData
        super.init(prompt: prompt, command: command, terminationStatus: terminationStatus)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.imageData = try container.decode(Data.self, forKey: .imageData)
        try super.init(from: decoder)
    }
}

/// Main model representing the filesystem and browsing context.
class ContentViewModel: ObservableObject {
    /// Filter for `stdoutConsole` and `stderrConsole`
    @Published var consoleFilter: String = "" {
        didSet {
            stdoutConsoleFilterDidChange()
            stderrConsoleFilterDidChange()
        }
    }
    /// Index of current directory into `navigationHistory`. This enables the user to browse back and forward.
    @Published var currentDirectoryIndex: Int {
        didSet {
            currentDirectoryDidChange()
            watchCurrentDirectory()
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
    private var unfilteredStdoutConsole: [CLIOutput] = [] {
        didSet {
            stdoutConsoleFilterDidChange()
        }
    }
    /// List of `CLIOutput`s representing the error output.
    @Published var stderrConsole: [CLIOutput] = []
    private var unfilteredStderrConsole: [CLIOutput] = [] {
        didSet {
            stderrConsoleFilterDidChange()
        }
    }
    
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
        watchCurrentDirectory()
    }
    
    deinit {
        EonilFSEvents.stopWatching(for: ObjectIdentifier(self))
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
        else {
            NSWorkspace.shared.open(file.url)
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
    
    /// Deselect everything.
    func deselectAll() {
        selectedFiles.removeAll()
    }
    
    private var stdoutData = Data()
    private var runningTasks: [ UUID : Process ] = [:]
    
    /// Execute a command.
    /// - Parameter prompt: Command prompt displayed at the time of command issuance.
    /// - Parameter command: Command entered by the user.
    func run(prompt: String, command: String) {
        var command = command.trimmingCharacters(in: .newlines)
        let originalCommand = command
        
        // FIXME: need to handle quotes and backslash escapes
        let commandParts = command.components(separatedBy: .whitespacesAndNewlines)
        
        let runAndOutput = { [self] (handler: ([String]) throws -> String?) in
            do {
                if let output = try handler(commandParts) {
                    unfilteredStdoutConsole.append(CLIAttributedTextOutput(prompt: prompt,
                                                                 command: command,
                                                                 terminationStatus: 0,
                                                                 text: AttributedString(output)))
                }
            } catch {
                unfilteredStdoutConsole.append(CLIAttributedTextOutput(prompt: prompt,
                                                             command: command,
                                                             terminationStatus: 1,
                                                             text: AttributedString(error.localizedDescription)))
                unfilteredStderrConsole.append(CLIAttributedTextOutput(prompt: prompt,
                                                             command: command,
                                                             terminationStatus: 1,
                                                             text: AttributedString(error.localizedDescription)))
            }
        }
        
        switch commandParts[0] {
        case "":
            break
        case "cd":
            chdir(commandParts)
        case "deselect":
            runAndOutput(deselect)
        case "history":
            runAndOutput(history)
        case "pwd":
            runAndOutput(pwd)
        case "select":
            runAndOutput(select)
        default:
            if let bundledCommand = Bundle.main.url(forAuxiliaryExecutable: commandParts[0]) {
                command = bundledCommand.path + command.dropFirst(commandParts[0].count)
            }
            if let script = Bundle.main.url(forResource: commandParts[0], withExtension: nil, subdirectory: "scripts") {
                command = script.path + command.dropFirst(commandParts[0].count)
            }
            
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
            
            stdoutData = Data()
            let newOutput = CLIAttributedTextOutput(prompt: prompt, command: originalCommand, text: AttributedString())
            unfilteredStdoutConsole.append(newOutput)
            
            masterFile.readabilityHandler = { [self] _ in
                // Accumulate everything in stdoutString for now, because the CLI wants to know
                // the termination reason to draw the colored borders correctly.
                let newData = masterFile.availableData
                stdoutData += newData
                
                DispatchQueue.main.async { [self] in
                    if let index = unfilteredStdoutConsole.firstIndex(of: newOutput),
                       let stdoutString = String(data: stdoutData, encoding: .utf8) {
                        if !stdoutString.hasPrefix("MIME-Version:") {
                            (unfilteredStdoutConsole[index] as? CLIAttributedTextOutput)?.text = AttributedString.create(fromANSI: stdoutString.trimmingCharacters(in: .whitespacesAndNewlines))
                            stdoutConsoleFilterDidChange()

                            // FIXME: tickle the UI so it'd update
                            stdoutConsole.append(CLIOutput(prompt: "", command: ""))
                            stdoutConsole.removeLast()
                        }
                    }
                }
            }
            
            task.terminationHandler = { [self] _ in
                masterFile.readabilityHandler = nil
                
                DispatchQueue.main.async { [self] in
                    // Nobody puts ANSI escape sequences into stderr, right?
                    // FIXME: probably should display partial output for stderr as well
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrString = String(data: stderrData, encoding: .utf8)!.trimmingCharacters(in: .newlines)
                    if !stderrString.isEmpty {
                        unfilteredStderrConsole.append(CLIAttributedTextOutput(prompt: prompt,
                                                                     command: originalCommand,
                                                                     terminationStatus: task.terminationStatus,
                                                                     text: AttributedString(stderrString)))
                    }
                    
                    if let index = unfilteredStdoutConsole.firstIndex(of: newOutput) {
                        var sol = 0
                        var isMIME = false
                        var isBase64 = false
                        var type: String?
                        while true {
                            let data = stdoutData.subdata(in: sol..<stdoutData.endIndex)
                            if let length = data.firstIndex(where: { $0 == 0x0A }),
                               let line = String(data: stdoutData.subdata(in: sol..<sol+length), encoding: .utf8)?.trimmingCharacters(in: .newlines) {
                                let parts = line.components(separatedBy: ":")
                                if parts.count >= 2 {
                                    switch parts[0] {
                                    case "MIME-Version":
                                        isMIME = true
                                    case "Content-Type":
                                        let subparts = parts[1].components(separatedBy: ";")
                                        if subparts.count >= 1 {
                                            type = subparts[0].trimmingCharacters(in: .whitespaces)
                                        }
                                    case "Content-Transfer-Encoding":
                                        isBase64 = (parts[1].trimmingCharacters(in: .whitespaces).caseInsensitiveCompare("base64") == .orderedSame)
                                    default:
                                        break
                                    }
                                }
                                sol += length + 1
                                if line.isEmpty {
                                    break
                                }
                            }
                            else {
                                break
                            }
                        }
                        if isMIME, let type {
                            if type.hasPrefix("image/") {
                                let body = {
                                    let rawData = stdoutData.subdata(in: sol..<stdoutData.endIndex)
                                    if isBase64,
                                       let rawString = String(data: rawData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                                       let decoded = Data(base64Encoded: rawString) {
                                        return decoded
                                    }
                                    else {
                                        return rawData
                                    }
                                }()
                                unfilteredStdoutConsole[index] = CLIImageOutput(prompt: prompt, command: originalCommand, imageData: body)
                            }
                            else if type.hasPrefix("text/"),
                                    let stdoutString = String(data: stdoutData.subdata(in: sol..<stdoutData.endIndex), encoding: .utf8) {
                                switch type {
                                case "text/markdown":
                                    unfilteredStdoutConsole[index] = CLITextOutput(prompt: prompt, command: originalCommand, text: stdoutString, format: .markdown)
                                case "text/plain":
                                    unfilteredStdoutConsole[index] = CLITextOutput(prompt: prompt, command: originalCommand, text: stdoutString)
                                default:
                                    break
                                }
                            }
                        }
                        else if let stdoutString = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .newlines) {
                            if task.terminationReason.rawValue != 0 && stdoutString.isEmpty && !stderrString.isEmpty {
                                // Special case: error termination reason and no stdout, so copy the stderr output instead
                                (unfilteredStdoutConsole[index] as? CLIAttributedTextOutput)?.text = AttributedString(stderrString)
                            }
                            else {
                                // Process stdout through our ANSI parser.
                                (unfilteredStdoutConsole[index] as? CLIAttributedTextOutput)?.text = AttributedString.create(fromANSI: stdoutString)
                            }
                        }
                        unfilteredStdoutConsole[index].terminationStatus = task.terminationStatus
                        stdoutConsoleFilterDidChange()
                        
                        // FIXME: tickle the UI so it'd update
                        stdoutConsole.append(CLIOutput(prompt: "", command: ""))
                        stdoutConsole.removeLast()
                    }
                }
            }
            
            do {
                try task.run()
                runningTasks[newOutput.id] = task
            } catch {
                fatalError("task failed to run")
            }
        }
    }
    
    func interrupt() {
        for task in runningTasks.values {
            task.terminate()
        }
    }
    
    func stop(_ id: UUID) {
        if let task = runningTasks[id] {
            task.terminate()
        }
    }
    
    /// Handles a change to consoleFilter by refiltering stdoutConsole.
    private func stdoutConsoleFilterDidChange() {
        stdoutConsole = unfilteredStdoutConsole.filter { output in
            if consoleFilter.isEmpty {
                return true
            }
            if output.command.localizedCaseInsensitiveContains(consoleFilter) {
                return true
            }
            if let textOutput = output as? CLIAttributedTextOutput,
               String(textOutput.text.characters).localizedCaseInsensitiveContains(consoleFilter) {
                return true
            }
            return false
        }
    }
    
    /// Handles a change to consoleFilter by refiltering stderrConsole.
    private func stderrConsoleFilterDidChange() {
        stderrConsole = unfilteredStderrConsole.filter { output in
            if consoleFilter.isEmpty {
                return true
            }
            if output.command.localizedCaseInsensitiveContains(consoleFilter) {
                return true
            }
            if let textOutput = output as? CLIAttributedTextOutput,
               String(textOutput.text.characters).localizedCaseInsensitiveContains(consoleFilter) {
                return true
            }
            return false
        }
    }
    
    // MARK: - Internal commands
    
    /// Internal command to change current directory
    /// - Parameter commandParts: Array of command-line parameters, including the command itself.
    private func chdir(_ commandParts: [String]) {
        let destination: URL? = {
            if commandParts.count == 1 || commandParts[1].isEmpty {
                return FileManager.default.homeDirectoryForCurrentUser
            }
            else {
                let destination = commandParts[1].hasPrefix("/") ? URL(filePath: commandParts[1]) : currentDirectory.url.appending(component: commandParts[1]).standardized
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
    
    /// Internal command to deselect specified files and directories.
    /// - Parameter commandParts: Array of command-line parameters, including the command itself. The '*' and '?' wildcard characters are honored.
    private func deselect(_ commandParts: [String]) throws -> String? {
        if commandParts.count == 1 {
            let selected = currentDirectoryFiles.filter { selectedFiles.contains($0) }
            if selected.isEmpty {
                return String(localized: "No items selected.")
            }
            else {
                return selected.reduce(String(localized: "Candidates:"), { $0.isEmpty ? $1.name : $0 + "\n" + $1.name })
            }
        }
        else {
            for part in commandParts.dropFirst(1) where !part.isEmpty {
                for currentDirectoryFile in currentDirectoryFiles {
                    if currentDirectoryFile.url.lastPathComponent.matchesWildcard(part) {
                        selectedFiles.remove(currentDirectoryFile)
                    }
                }
            }
        }
        return nil
    }
    
    /// Internal command to list command history.
    /// - Parameter commandParts: Array of command-line parameters, including the command itself.
    private func history(_ commandParts: [String]) throws -> String? {
        let count = unfilteredStdoutConsole.count
        guard count > 0 else {
            throw "no history"
        }
        
        var startIndex = max(count - 16, 0)
        var endIndex = count - 1
        if commandParts.count > 1 {
            startIndex = max(Int(commandParts[1]) ?? startIndex, 0)
        }
        if startIndex >= count {
            throw "no such event: \(startIndex)"
        }
        if commandParts.count > 2 {
            endIndex = Int(commandParts[2]) ?? endIndex
            if endIndex < startIndex || endIndex > unfilteredStdoutConsole.count {
                endIndex = count - 1
            }
        }
        
        var output: String = ""
        for index in startIndex...endIndex {
            output += "\(String(format: "%5d", index))  \(unfilteredStdoutConsole[index].command)" + ((index < endIndex) ? "\n" : "")
        }
        return output
    }
    
    /// Internal command to display or manipuate the current working directory.
    /// - Parameter commandParts: Array of command-line parameters, including the command itself.
    private func pwd(_ commandParts: [String]) throws -> String? {
        if commandParts.count > 1 {
            if commandParts[1].hasPrefix("b") {
                if canGoBack() {
                    goBack()
                }
                else {
                    throw "no back history"
                }
            }
            else if commandParts[1].hasPrefix("f") {
                if canGoForward() {
                    goForward()
                }
                else {
                    throw "no forward history"
                }
            }
        }
        return currentDirectory.url.path
    }
    
    /// Internal command to select specified files and directories.
    /// - Parameter commandParts: Array of command-line parameters, including the command itself. The '*' and '?' wildcard characters are honored.
    private func select(_ commandParts: [String]) throws -> String? {
        if commandParts.count == 1 {
            let unselected = currentDirectoryFiles.filter { !selectedFiles.contains($0) }
            if unselected.isEmpty {
                return String(localized: "All items already selected.")
            }
            else {
                return unselected.reduce(String(localized: "Candidates:"), { $0.isEmpty ? $1.name : $0 + "\n" + $1.name })
            }
        }
        else {
            for part in commandParts.dropFirst(1) where !part.isEmpty {
                for currentDirectoryFile in currentDirectoryFiles {
                    if currentDirectoryFile.url.lastPathComponent.matchesWildcard(part) {
                        selectedFiles.insert(currentDirectoryFile)
                    }
                }
            }
        }
        return nil
    }
    
    /// Stop watching current directory. The flag avoids an assertion in stopWatching() checking for
    /// callers that aren't actually watching.
    private var watchingDirectory = false
    private func stopWatchingDirectory() {
        if watchingDirectory {
            EonilFSEvents.stopWatching(for: ObjectIdentifier(self))
        }
    }
    
    /// Monitor current directory for changes.
    private func watchCurrentDirectory() {
        stopWatchingDirectory()
        do {
            try EonilFSEvents.startWatching(
                paths: [currentDirectory.url.path],
                for: ObjectIdentifier(self),
                with: { [self] event in
                    let url = URL(filePath: event.path)
                    let directory = url.deletingLastPathComponent()
                    if directory == currentDirectory.url {
                        currentDirectoryDidChange()
                    }
                })
            watchingDirectory = true
        } catch {
            fatalError("unable to watch current directory")
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
            
            // make sure selected files only contains files that still exist.
            // FIXME: can't just use intersection() because the currentDirectoryFiles have new ids
            var newSelectedFiles: Set<File> = []
            for item in selectedFiles {
                if let file = currentDirectoryFiles.first(where: { $0.url == item.url }) {
                    newSelectedFiles.insert(file)
                }
            }
            selectedFiles = newSelectedFiles
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

extension String: Error {}
extension String: LocalizedError {
    public var errorDescription: String? { return self }
}
