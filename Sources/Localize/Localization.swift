//
//  Localization.swift
//  CLI
//
//  Created by Huanan on 2025/5/7.
//

import Foundation

enum LocaleErr: Swift.Error {
    case custom(String)
}

struct LocalizationDestination {
    let lang: String
    let url: URL
}

struct UnmanagedLocalization {
    let lang: String
    let content: [String: String]
}

extension UnmanagedLocalization {
    func manage(_ destination: LocalizationDestination) -> Localization {
        Localization(lang: lang, url: destination.url, content: content)
    }
}

struct Localization {
    let lang: String
    let url: URL

    let content: [String: String]
}

extension  Localization {

    var destination: LocalizationDestination {
        LocalizationDestination(lang: lang, url: url)
    }
}


extension Localization {
    func detach() -> UnmanagedLocalization {
        UnmanagedLocalization(lang: lang, content: content)
    }
}

extension Localization {
    func update(_ new: UnmanagedLocalization, ignore: ((String) -> Bool)? = nil) -> Localization {
        var updated = content
        for (key, value) in new.content {
            if content.keys.contains(key), let oldValue = content[key], oldValue != value {
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

        return Localization(lang: lang, url: url, content: updated)
    }
}

enum LocalizeHelper {}

extension LocalizeHelper {

    static func getAllStringsPath(_ path: URL) throws -> [LocalizationDestination] {
        var result: [LocalizationDestination] = []

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

            result.append(LocalizationDestination(lang: lang, url: file))
        }

        return result
    }
    
    static func getAllStringsPathInLangNameFormat(_ path: URL) throws -> [LocalizationDestination] {
        var result: [LocalizationDestination] = []

        let langFiles = try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: [.isRegularFileKey, .nameKey])
        for langFile in langFiles {
            let values = try langFile.resourceValues(forKeys: [.isDirectoryKey, .nameKey])
            guard values.isDirectory == false && values.name!.hasSuffix("strings") else { continue }

            let lang = langFile.lastPathComponent
            result.append(LocalizationDestination(lang: lang.replacing(".strings", with: ""), url: langFile))
        }

        return result
    }
}

extension LocalizeHelper {
    static func getLocalization(_ localization: LocalizationDestination, cache: Bool = true) throws -> Localization {
        guard let data = try? Data(contentsOf: localization.url),
              let prop = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
        else {
            throw LocaleErr.custom("Failed to parse localization file: \(localization.url.path())")
        }
        return Localization(lang: localization.lang, url: localization.url, content: prop)
    }

    static func writeLocalization(_ localization: Localization) throws {
        var builder = ""
        for (key, value) in localization.content.sorted(using: KeyPathComparator(\.key)) {
            builder += "\(key.debugDescription)=\(value.debugDescription);\n"
        }

        try builder.write(to: localization.url, atomically: true, encoding: .utf8)
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
