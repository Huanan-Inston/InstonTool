//
//  Generate.swift
//  CLI
//
//  Created by Huanan on 2025/5/8.
//

import ArgumentParser
import Foundation
import Jinja

struct GenerateStringsFile {
    let output: URL
    let keys: [String]
    let template: String
}

extension GenerateStringsFile {
    func generate() throws {
        let template = try Template(template)
        let content = try template.render(["keys": keys])
        try content.write(to: output, atomically: true, encoding: .utf8)
    }
}

struct Generate: AsyncParsableCommand {

    @Option(help: "The path of 'Strings'", transform: { URL(fileURLWithPath: $0).standardizedFileURL })
    var strings: URL

    @Option(name: [.short, .long], help: "The output path for generated strings file", transform: { URL(fileURLWithPath: $0).standardizedFileURL })
    var output: URL

    @Option(name: [.short, .long], help: "The template path", transform: { URL(fileURLWithPath: $0).standardizedFileURL })
    var template: URL

    func run() async throws {
        let localizations = try LocalizeHelper.getAllStringsPath(strings)
        print("[INFO]: Find \(localizations.count) Strings file.")

        let keys = try grabAllKeys(localizations)
        print("[INFO]: Find \(keys.count) keys form \(localizations.count) files, located in '\(strings.path())'.")

        let file = GenerateStringsFile(output: output, keys: Array(keys), template: """
        import Foundation
        
        struct L {
            let raw: String
        }
        
        extension L {
        func tr() -> NSLocalizedString {
            return NSLocalizedString(raw, comment: "")
        }
        
        extension L {
            {% for key in keys %}
            static let _{{ key }} = L(raw: "{{ key }}")
            {% endfor %}
        }
        """)

        try file.generate()
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

}
