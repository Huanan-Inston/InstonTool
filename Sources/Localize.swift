import ArgumentParser
import Foundation
import Yams

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

func escapeString(_ val: String) -> String {

    let replacements: [(String, String)] = [
        ("\\", "\\\\"),
        ("\t", "\\t"),
        ("\n", "\\n"),
        ("\r", "\\r"),
        ("\"", "\\\"")
    ]

    var str = val
    for (template, replacement) in replacements {
        str = str.replacingOccurrences(of: template, with: replacement)
    }

    return "\"\(str)\""
}

extension LocalizeHelper {
    static func writeLocalization(_ localization: Localization) throws {
        guard let content = localization.content else {
            return
        }

        var builder = ""
        for (key, value) in content {
            builder += "\(escapeString(key))=\(escapeString(value));\n"
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
                    print("[INFO]: Key(\(key)) has conflict. Ignored.")
                    print("        cur: \(oldValue.debugDescription)")
                    print("        new: \(value.debugDescription)")
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
        guard let data = FileManager.default.contents(atPath: path.absoluteString) else {
            return .init()
        }

        guard let content = String(data: data, encoding: .utf8) else {
            return .init()
        }

        let keys = content.split(separator: "\n").map { String($0) }
        return .init(keys)
    }

    static func saveKeysToStore(_ path: URL, keys: Set<String>) throws {
        let content = keys.sorted().joined(separator: "\n")
        try content.write(toFile: path.absoluteString, atomically: true, encoding: .utf8)
    }
}

struct LocalizeConfiguration: Codable {
    enum CodingKeys: String, CodingKey {
        case langNameMap = "lang_name_map"
        case ignoreKeys = "ignore_keys"
    }

    /// FROM PROJECT LANG NAME TO INSTON's LANG NAME
    let langNameMap: [String: String]

    let ignoreKeys: [String]

    static let `default`: LocalizeConfiguration = .init(langNameMap: [:], ignoreKeys: [])
}

extension LocalizeConfiguration: CustomStringConvertible {
    var description: String {
        let encoder = Yams.YAMLEncoder()
        let string = try? encoder.encode(self)
        return string ?? "nil"
    }
}

extension LocalizeConfiguration {
    static func load(_ path: URL?) throws -> LocalizeConfiguration? {
        guard let path else {
            return nil
        }

        let data = try Data(contentsOf: path)
        guard !data.isEmpty else {
            return nil
        }

        let decoder = Yams.YAMLDecoder()
        let cfg = try decoder.decode(LocalizeConfiguration.self, from: data)
        return cfg
    }
}


extension LocalizeConfiguration {
    func mapLangName(apple: String) -> String {
        self.langNameMap[apple] ?? apple
    }
}

struct Localize: AsyncParsableCommand {

    @Option(help: "The path of 'Strings'", transform: { URL(fileURLWithPath: $0).standardizedFileURL })
    var strings: URL

    @Option(name: .customLong("keys"), help: "The path of 'keys' to be read or saved", transform: { URL(fileURLWithPath: $0).standardizedFileURL })
    var assetsStore: URL = .init(fileURLWithPath: "../Assets").standardizedFileURL

    @Option(name: .customLong("cfg"), help: "The path of configutation file", transform: { URL(fileURLWithPath: $0).standardizedFileURL })
    var cfgPath: URL?

    @Option(name: .customLong("downloaded"), help: "The path of configutation file", transform: { URL(fileURLWithPath: $0).standardizedFileURL })
    var downloaded: URL = .init(fileURLWithPath: "../Assets/stringsdownload/").standardizedFileURL

    mutating func run() async throws {
        let cfg = try LocalizeConfiguration.load(cfgPath) ?? .default
        print("[INFO]: Read Configuration from file('\(cfgPath?.path() ?? "nil")'): ")
        print(cfg)

        let stringsFilesPaths = try LocalizeHelper.getAllStringsPath(strings)
        print("[INFO]: Find \(stringsFilesPaths.count) Strings file.")

        for stringsFilesPath in stringsFilesPaths {
            print("[INFO]: Processing Lang(\(stringsFilesPath.lang)). Path: \(stringsFilesPath.url.path())")
            let old = LocalizeHelper.getLocalization(stringsFilesPath)

            let newLang = cfg.mapLangName(apple: old.lang)
            let newURL = downloaded.appending(path: "\(newLang).strings")

            guard FileManager.default.fileExists(atPath: newURL.path()) else {
                print("[WARN]: Skiped for Lang(\(stringsFilesPath.lang)). Could not find downloaded file. Shuold at '\(newURL.path())'")
                continue
            }

            let newLocalization = Localization(lang: newLang, url: newURL, content: nil)
            let new = LocalizeHelper.getLocalization(newLocalization)

            let updated = LocalizeHelper.updateLocalization(old: old, new: new) { cfg.ignoreKeys.contains($0) }
            try LocalizeHelper.writeLocalization(updated)

            print("[INFO]: Finish Lang(\(stringsFilesPath.lang)).")
        }
    }
}
