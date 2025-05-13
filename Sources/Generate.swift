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
        let content = try template.render(["keys": keys.sorted()])
        try content.write(to: output, atomically: true, encoding: .utf8)
    }
}

struct Generate: AsyncParsableCommand {

    @Argument(help: .init("The file paths of the templates. ",
                          discussion: """
                          Notice file extension should be end with `.template`, and file name will be use as output file name.
                          Example: 
                            - 'OCL+Keys.h.template' -> '$OUTPUT/OCL+Keys.h'
                            - 'R.swift.template' -> '$OUTPUT/R.swift'
                          """),
              transform: { URL(fileURLWithPath: $0).standardizedFileURL })
    var templates: [URL]

    @Option(help: .init("The path of 'Strings'.",
                        discussion: "The path should be a folder, and contains several `*.lproj` folders."),
            transform: { URL(fileURLWithPath: $0).standardizedFileURL })
    var strings: URL

    @Option(name: [.short, .long], help: "The output folder for generated file", transform: { URL(fileURLWithPath: $0).standardizedFileURL })
    var output: URL

    func run() async throws {
        let localizations = try LocalizeHelper.getAllStringsPath(strings)
        print("[INFO]: Find \(localizations.count) Strings file.")

        let keys = try grabAllKeys(localizations)
        print("[INFO]: Find \(keys.count) keys form \(localizations.count) files, located in '\(strings.path())'.")

        for template in templates {
            let fileName = template.deletingPathExtension().lastPathComponent
            if !FileManager.default.fileExists(atPath: template.path()) {
                print("[WARN]: Template file not found.")
                continue
            }

            let path = output.appending(path: fileName)
            let templateContent = try String(contentsOf: template, encoding: .utf8)
            let file = GenerateStringsFile(output: path, keys: Array(keys), template: templateContent)
            try file.generate()
            print("[INFO]: File Generated. Save to \(path.path())")
        }
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
