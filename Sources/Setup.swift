//
//  Setup.swift
//  CLI
//
//  Created by Huanan on 2025/5/7.
//

import ArgumentParser
import Foundation
import RegexBuilder

enum ProjHelper {

    static let sourceFileValidSuffix = [".m", ".mm", ".h", ".swift"]

    static func getAllSourceFilesPath(
        _ path: URL,
        propertiesForKeys: [URLResourceKey] = [.isRegularFileKey, .nameKey]
    )
        throws -> [URL]
    {

        try getAllSourceFilesPath(path, propertiesForKeys: propertiesForKeys) { _, props in
            sourceFileValidSuffix.contains { props.name?.hasSuffix($0) ?? false }
        }
    }

    static func getAllSourceFilesPath(
        _ path: URL,
        propertiesForKeys: [URLResourceKey] = [.isRegularFileKey, .nameKey],
        predicate: (URL, URLResourceValues) -> Bool
    )
        throws -> [URL]
    {
        guard let dirEnum = FileManager.default.enumerator(at: path, includingPropertiesForKeys: propertiesForKeys) else {
            throw NSError()
        }

        let result = try dirEnum.compactMap({ $0 as? URL }).filter { item in
            let values = try item.resourceValues(forKeys: Set(propertiesForKeys))
            return values.isRegularFile == true && predicate(item, values)
        }

        return result
    }
}


struct Setup: AsyncParsableCommand {

    @Argument(help: "The regex express to filer in the keys inside project")
    var pattern: [String] = []

    @Option(help: "The path of 'Strings'", transform: { URL(fileURLWithPath: $0).standardizedFileURL })
    var strings: URL

    @Option(name: .customLong("proj"), help: "The path to the project sources files", transform: { URL(fileURLWithPath: $0).standardizedFileURL })
    var projectFolder: URL = .init(string: "../..")!.standardizedFileURL

    @Option(name: .customLong("keys"), help: "The path of 'keys' to be read or saved", transform: { URL(fileURLWithPath: $0).standardizedFileURL })
    var assetsStore: URL = .init(string: "../Assets")!.standardizedFileURL

    @Option(help: "Suppress Logs")
    var quiet: Bool = false

    func run() async throws {
        let stringsFilesPath = try LocalizeHelper.getAllStringsPath(strings)

        let keys = try grabAllKeys(stringsFilesPath)
        try LocalizeHelper.saveKeysToStore(assetsStore.appending(path: "keys.all"), keys: keys)
        print("[INFO]: Find \(keys.count) keys inside Strings('\(strings.path())') with \(stringsFilesPath.count) files.")

        let sourceFiles = try ProjHelper.getAllSourceFilesPath(projectFolder)
        let used = try parserAllUsedKeys(sourceFiles, patterns: pattern)
        try LocalizeHelper.saveKeysToStore(assetsStore.appending(path: "keys.used"), keys: used)
        print("[INFO]: Find \(used.count) keys used in source files. \(sourceFiles.count) files found.")

        let missing = try LocalizeHelper.readKeysFromStore(assetsStore.appending(path: "keys.miss"))
        if missing.isEmpty {
            print("[WARN]: The 'Missing Keys' is empty. Consider adding missing keys into the file('Assets/keys.miss') and rerun the command.")
        } else {
            print("[INFO]: Find \(missing.count) Missing Keys. All will be ignored during the whole process.")
        }

        let valid = keys.intersection(used).subtracting(missing)
        try LocalizeHelper.saveKeysToStore(assetsStore.appending(path: "keys.used"), keys: valid)
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
                // let pattern = "(?<=L\\(@\")([_\\w]+)(?=\")"
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
