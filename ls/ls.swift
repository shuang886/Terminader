//
//  main.swift
//  ls
//
//  Created by Steven Huang on 9/28/23.
//

import Foundation
import ArgumentParser
import System

@main
struct ls: ParsableCommand {
    @Flag(name: .short, help: "Include directory entries whose names begin with a dot (‘.’)")
    var all = false
    
    @Argument(help: "Files to list")
    var files: [String] = ["."]
    
    private var mimeHeaderPrinted = false
    private var tableHeaderPrinted = false
    
    mutating private func listHeader() {
        if !tableHeaderPrinted {
            print("""
            | Permissions | Links | Owner | Group | Size | Date | Name |
            | :---------: | ----: | ----- | ----- | ---: | ---: | ---- |
            """)
            tableHeaderPrinted = true
        }
    }
    
    private mutating func listFile(_ content: URL) throws {
        let fileManager = FileManager.default
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        let sizeFormatter = MeasurementFormatter()
        sizeFormatter.unitOptions = .naturalScale
        
        let empty = "-"
        let disallowed = "-"
        let readable = "r"
        let writable = "w"
        let executable = "x"
        
        let contentPath = content.path(percentEncoded: false)
        let attributes = try fileManager.attributesOfItem(atPath: contentPath)
        let type = attributes[.type] as? NSString
        let isDirectory = (type as? FileAttributeType) == .typeDirectory
        let typeCharacter = {
            if let attribute = type as? FileAttributeType {
                switch attribute {
                case .typeSymbolicLink:      return "l"
                case .typeRegular:           return "-"
                case .typeDirectory:         return "d"
                case .typeBlockSpecial:      return "b"
                case .typeCharacterSpecial:  return "c"
                case .typeSocket:            return "s"
                default:                     break
                }
            }
            return "?"
        }()
        let permissions = {
            if let posixPermissions = attributes[.posixPermissions] as? NSNumber {
                return FilePermissions(rawValue: posixPermissions.uint16Value)
            }
            return FilePermissions()
        }()
        let permissionsString =
            "`" +
            typeCharacter +
            (permissions.contains(.ownerRead) ? readable : disallowed) +
            (permissions.contains(.ownerWrite) ? writable : disallowed) +
            (permissions.contains(.ownerExecute) ? executable : disallowed) +
            (permissions.contains(.groupRead) ? readable : disallowed) +
            (permissions.contains(.groupWrite) ? writable : disallowed) +
            (permissions.contains(.groupExecute) ? executable : disallowed) +
            (permissions.contains(.otherRead) ? readable : disallowed) +
            (permissions.contains(.otherWrite) ? writable : disallowed) +
            (permissions.contains(.otherExecute) ? executable : disallowed) +
            "`"
        
        let links = (attributes[.referenceCount] as? NSNumber)?.uint64Value.formatted() ?? empty
        let owner = attributes[.ownerAccountName] ?? empty
        let group = attributes[.groupOwnerAccountName] ?? empty
        let date = {
            if let date = attributes[.modificationDate] as? Date {
                return dateFormatter.string(from: date)
            }
            return empty
        }()
        let size = {
            if let size = attributes[.size] as? NSNumber {
                let bytes = Measurement(value: size.doubleValue, unit: UnitInformationStorage.bytes)
                return sizeFormatter.string(from: bytes)
            }
            return empty
        }()
        let name = "[\(fileManager.displayName(atPath: contentPath))](\(content))" +
            (isDirectory ? "/" : "")
        
        listHeader()
        print("| \(permissionsString) | \(links) | \(owner) | \(group) | \(size) |  \(date) | \(name) |")
    }
    
    mutating func run() throws {
        let fileManager = FileManager.default
        let currentDirectory = URL(filePath: fileManager.currentDirectoryPath)
        
        do {
            for file in files {
                let url = file.hasPrefix("/") ? URL(filePath: file) : currentDirectory.appending(path: file).standardized
                let path = url.path(percentEncoded: false)
                
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
                    if !mimeHeaderPrinted {
                        print("""
                        MIME-Version: 1.0
                        Content-Type: text/markdown
                        
                        """)
                        mimeHeaderPrinted = true
                    }
                    
                    if isDirectory.boolValue {
                        print("\n### \(file):")
                        tableHeaderPrinted = false
                        var contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [])
                        if !all {
                            contents = contents.filter { !$0.lastPathComponent.hasPrefix(".") }
                        }
                        if !contents.isEmpty {
                            for content in contents {
                                try listFile(content)
                            }
                        }
                    }
                    else {
                        try listFile(url)
                    }
                }
                else {
                    let appName = (CommandLine.arguments[0] as NSString).lastPathComponent
                    fputs("\(appName): \(file): No such file or directory\n", stderr)
                }
            }
        } catch {
            ls.exit(withError: error)
        }
    }
}
