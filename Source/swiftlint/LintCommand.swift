//
//  LintCommand.swift
//  SwiftLint
//
//  Created by JP Simard on 2015-05-16.
//  Copyright (c) 2015 Realm. All rights reserved.
//

import Commandant
import Foundation
import LlamaKit
import SourceKittenFramework
import SwiftLintFramework

let fileManager = NSFileManager.defaultManager()

struct LintCommand: CommandType {
    let verb = "lint"
    let function = "Print lint warnings and errors for the Swift files in the current directory " +
                   "(default command)"

    func run(mode: CommandMode) -> Result<(), CommandantError<()>> {
        return LintOptions.evaluate(mode).flatMap { options in
            return self.lint(options.path)
        }
    }

    private func lint(path: String) -> Result<(), CommandantError<()>> {
        let filesToLint = filesToLintAtPath(path)
        if filesToLint.count > 0 {

            if path == "" {
                println("Linting Swift files in current working directory")
            } else {
                println("Linting Swift files at path \(path)")
            }

            var numberOfViolations = 0, numberOfSeriousViolations = 0
            for (index, file) in enumerate(filesToLint) {
                println("Linting '\(file.lastPathComponent)' (\(index + 1)/\(filesToLint.count))")
                for violation in Linter(file: File(path: file)!).styleViolations {
                    println(violation)
                    numberOfViolations++
                    if violation.severity.isError {
                        numberOfSeriousViolations++
                    }
                }
            }
            let violationSuffix = (numberOfViolations != 1 ? "s" : "")
            let filesSuffix = (filesToLint.count != 1 ? "s." : ".")
            println(
                "Done linting!" +
                " Found \(numberOfViolations) violation\(violationSuffix)," +
                " \(numberOfSeriousViolations) serious" +
                " in \(filesToLint.count) file\(filesSuffix)"
            )
            if numberOfSeriousViolations <= 0 {
                return success()
            } else {
                // This represents failure of the content (i.e. violations in the files linted)
                // and not failure of the scanning process itself. The current command architecture
                // doesn't discriminate between these types.
                return failure(CommandantError<()>.CommandError(Box()))
            }
        }
        return failure(CommandantError<()>.UsageError(description: "No lintable files found at" +
            " path \(path)"))
    }

    private func filesToLintAtPath(path: String) -> [String] {
        let absolutePath = path.absolutePathRepresentation()
        var isDirectory: ObjCBool = false
        if fileManager.fileExistsAtPath(absolutePath, isDirectory: &isDirectory) {
            if isDirectory {
                return fileManager.allFilesRecursively(directory: absolutePath).filter {
                    $0.isSwiftFile()
                }
            } else if absolutePath.isSwiftFile() {
                return [absolutePath]
            }
        }
        return []
    }
}

struct LintOptions: OptionsType {
    let path: String

    static func create(path: String) -> LintOptions {
        return LintOptions(path: path)
    }

    static func evaluate(m: CommandMode) -> Result<LintOptions, CommandantError<()>> {
        return create
            <*> m <| Option(key: "path", defaultValue: "", usage: "the path to the file or" +
                        " directory to lint")
    }
}
