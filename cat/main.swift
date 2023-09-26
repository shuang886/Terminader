//
//  main.swift
//  cat
//
//  Created by Steven Huang on 9/22/23.
//

import Foundation

func detectFileType(url: URL) -> String {
    // ask 'file' what type this is
    let task = Process()
    let pipe = Pipe()
    task.standardInput = nil
    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = ["-b", "-I", url.path]
    task.launchPath = "/usr/bin/file"
    task.launch()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!
    let outputLines = output.components(separatedBy: .newlines)
    return outputLines[0]
}

if CommandLine.argc >= 2 {
    let fileName = CommandLine.arguments[1]
    do {
        let fileURL = URL(filePath: fileName)
        var useBase64 = false
        
        let data = try Data(contentsOf: URL(filePath: fileName))
        print("MIME-Version: 1.0")
        let type = detectFileType(url: fileURL)
        print("Content-Type: \(type)")
        if type.hasPrefix("image/") {
            useBase64 = true
            print("Content-Transfer-Encoding: base64")
        }
        print("Content-Length: \(data.count)")
        print("")
        
        if useBase64 {
            print(data.base64EncodedString())
        }
        else {
            FileHandle.standardOutput.write(data)
        }
        exit(0)
    } catch {
        fputs(error.localizedDescription, stderr)
        exit(1)
    }
}
