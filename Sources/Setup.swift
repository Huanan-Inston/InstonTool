//
//  Setup.swift
//  CLI
//
//  Created by Huanan on 2025/5/7.
//

import ArgumentParser
import Foundation
import RegexBuilder


struct Setup: AsyncParsableCommand {

    @Argument(help: "The regex express to filer in the keys inside project")
    var pattern: [String] = []

    @Option(help: "The path of 'Strings'", transform: { URL(fileURLWithPath: $0).standardizedFileURL })
    var strings: URL

    @Option(name: .customLong("proj"), help: "The path to the project sources files", transform: { URL(fileURLWithPath: $0).standardizedFileURL })
    var projectFolder: URL = .init(fileURLWithPath: ".").standardizedFileURL

    @Option(name: .customLong("assets"), help: "The path of 'keys' to be read or saved", transform: { URL(fileURLWithPath: $0).standardizedFileURL })
    var assetsStore: URL = .init(fileURLWithPath: "./scripts/Assets").standardizedFileURL

    @Option(help: "Suppress Logs")
    var quiet: Bool = false

    func run() async throws {
        let stringsFilesPath = try LocalizeHelper.getAllStringsPath(strings)

        let keys = try grabAllKeys(stringsFilesPath)
        try LocalizeHelper.saveKeysToStore(assetsStore.appending(path: AssetsHelper.AllKey), keys: keys)
        print("[INFO]: Find \(keys.count) keys form \(stringsFilesPath.count) files, located in '\(strings.path())'.")

        let sourceFiles = try ProjHelper.getAllSourceFilesPath(projectFolder)
        let used = try parserAllUsedKeys(sourceFiles, patterns: pattern)
        try LocalizeHelper.saveKeysToStore(assetsStore.appending(path: AssetsHelper.UsedKey), keys: used)
        print("[INFO]: Find \(used.count) keys used in source files. \(sourceFiles.count) files found.")

        let missing = try LocalizeHelper.readKeysFromStore(assetsStore.appending(path: AssetsHelper.MissKey))
        if missing.isEmpty {
            print("[WARN]: The 'Missing Keys' is empty. Consider adding missing keys into the file('Assets/keys.miss') and rerun the command.")
        } else {
            print("[INFO]: Find \(missing.count) Missing Keys. All will be ignored during the whole process.")
        }

        let valid = keys.intersection(used).subtracting(missing)
        try LocalizeHelper.saveKeysToStore(assetsStore.appending(path: AssetsHelper.Key), keys: valid)
        print("[INFO]: Find \(valid.count) valid keys. Saved to file('Assets/keys.used').")
    }

    func grabAllKeys(_ localizations: [Localization]) throws -> Set<String> {
        var keys: Set<String> = .init()
        for localization in localizations {
            let strings = LocalizeHelper.getLocalization(localization)
            if let content = strings.content {
                keys.formUnion(content.keys)
            }
        }
        return keys
    }

    func parserAllUsedKeys(_ sourceFiles: [URL], patterns: [String]) throws -> Set<String> {

        var keys: Set<String> = .init()
        for file in sourceFiles {
            guard let content = try? String(contentsOf: file, encoding: .utf8) else {
                continue
            }

            for pattern in pattern {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let matches = regex.matches(in: content, range: .init(content.startIndex ..< content.endIndex, in: content))
                for match in matches {
                    guard let range = Range<String.Index>.init(match.range, in: content) else {
                        continue
                    }

                    let key = String(content[range])
                    keys.insert(key)
                }
            }
        }

        return keys
    }

}
