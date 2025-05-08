import ArgumentParser
import Foundation
import Yams

struct Localize: AsyncParsableCommand {

    @Option(help: "The path of 'Strings'", transform: { URL(fileURLWithPath: $0).standardizedFileURL })
    var strings: URL

    @Option(name: .customLong("assets"), help: "The path of 'keys' to be read or saved", transform: { URL(fileURLWithPath: $0).standardizedFileURL })
    var assetsStore: URL = .init(fileURLWithPath: "./scripts/Assets").standardizedFileURL

    @Option(name: .customLong("cfg"), help: "The path of configutation file", transform: { URL(fileURLWithPath: $0).standardizedFileURL })
    var cfgPath: URL = .init(fileURLWithPath: "./scripts/inston.yaml").standardizedFileURL

    @Option(name: .customLong("downloaded"), help: "The path of configutation file", transform: { URL(fileURLWithPath: $0).standardizedFileURL })
    var downloaded: URL = .init(fileURLWithPath: "./scripts/Assets/stringsdownload/").standardizedFileURL

    mutating func run() async throws {
        let cfg = try LocalizeConfiguration.load(cfgPath) ?? .default
        print("[INFO]: Read Configuration from file('\(cfgPath.path())'): ")
        print(cfg)

        let localizations = try LocalizeHelper.getAllStringsPath(strings)
        print("[INFO]: Find \(localizations.count) Strings file.")

        for localization in localizations {
            print("[INFO]: Processing Lang(\(localization.lang)). Path: \(localization.url.path())")
            let old = LocalizeHelper.getLocalization(localization)

            let newLang = cfg.mapLangName(apple: old.lang)
            let newURL = downloaded.appending(path: "\(newLang).strings")

            guard FileManager.default.fileExists(atPath: newURL.path()) else {
                print("[WARN]: Skiped for Lang(\(localization.lang)). Could not find downloaded file. Shuold at '\(newURL.path())'")
                continue
            }

            let newLocalization = Localization(lang: newLang, url: newURL, content: nil)
            let new = LocalizeHelper.getLocalization(newLocalization)

            let updated = LocalizeHelper.updateLocalization(old: old, new: new) { cfg.ignoreKeys.contains($0) }
            try LocalizeHelper.writeLocalization(updated)

            print("[INFO]: Finish Lang(\(localization.lang)).")
        }
    }
}
