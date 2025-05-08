//
//  Localization.swift
//  CLI
//
//  Created by Huanan on 2025/5/7.
//

import Foundation

struct Localization {
    let lang: String
    let url: URL

    // nil if not read from file yet.
    let content: [String: String]?
}

extension Localization {
    func with(content: [String: String]) -> Localization {
        .init(lang: lang, url: url, content: content)
    }
}

enum LocalizeHelper {}

extension LocalizeHelper {

    static func getAllStringsPath(
        _ path: URL
    )
    throws -> [Localization]
    {
        var result: [Localization] = []

        let folders = try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: [.isRegularFileKey, .nameKey])
        for folder in folders {
            let values = try folder.resourceValues(forKeys: [.isDirectoryKey, .nameKey])
            guard values.isDirectory == true else {
                continue
            }

            let lang = folder.deletingPathExtension().lastPathComponent
            let file = folder.appending(path: "Localizable.strings")

            guard FileManager.default.fileExists(atPath: file.path()) else {
                continue
            }

            result.append(Localization(lang: lang, url: file, content: nil))
        }

        return result
    }

    static func getLocalization(_ localization: Localization, cache: Bool = true) -> Localization {
        guard localization.content == nil else {
            return localization
        }

        guard let data = try? Data(contentsOf: localization.url),
              let prop = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
        else {
            return localization.with(content: [:])
        }
        return localization.with(content: prop)
    }
}

extension LocalizeHelper {
    static func writeLocalization(_ localization: Localization) throws {
        guard let content = localization.content else {
            return
        }

        var builder = ""
        for (key, value) in content.sorted(using: KeyPathComparator(\.key)) {
            builder += "\(key.debugDescription)=\(value.debugDescription);\n"
        }

        try builder.write(to: localization.url, atomically: true, encoding: .utf8)
    }
}

extension LocalizeHelper {
    static func updateLocalization(old: Localization, new: Localization, ignore: ((String) -> Bool)? = nil) -> Localization {
        guard let oldContent = old.content, let newContent = new.content else {
            return old
        }

        var updated = oldContent
        for (key, value) in newContent {
            if oldContent.keys.contains(key), let oldValue = oldContent[key], oldValue != value {
                let ignore = ignore?(key) ?? false
                if !ignore {
                    updated[key] = value
                    print("[WARN]: Key('\(key)') has conflict. Force Updated.")
                    print("        cur: \(oldValue.debugDescription)")
                    print("        new: \(value.debugDescription)")
                } else {
//                    print("[INFO]: Key(\(key)) has conflict. Ignored.")
//                    print("        cur: \(oldValue.debugDescription)")
//                    print("        new: \(value.debugDescription)")
                }
            } else {
                updated[key] = value
            }
        }

        return old.with(content: updated)
    }
}

extension LocalizeHelper {
    static func readKeysFromStore(_ path: URL) throws -> Set<String> {
        guard FileManager.default.fileExists(atPath: path.path()) else {
            return .init()
        }

        let content = try String(contentsOf: path, encoding: .utf8)
        let keys = content.split(separator: "\n").map { String($0) }
        return .init(keys)
    }

    static func saveKeysToStore(_ path: URL, keys: Set<String>) throws {
        let content = keys.sorted().joined(separator: "\n")
        try content.write(to: path, atomically: true, encoding: .utf8)
    }
}
