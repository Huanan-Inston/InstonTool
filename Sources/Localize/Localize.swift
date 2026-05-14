import ArgumentParser
import Foundation
import Yams

struct Localize: AsyncParsableCommand {

    @Option(
        help: .init("The path of 'Strings'.", discussion: "The path should be a folder, and contains several `*.lproj` folders."),
        transform: { URL(fileURLWithPath: $0).standardizedFileURL })
    var strings: URL

    @Option(
        name: .customLong("cfg"), help: "The path of configutation file",
        transform: { URL(fileURLWithPath: $0).standardizedFileURL })
    var cfgPath: URL = .init(fileURLWithPath: "./scripts/inston.yaml").standardizedFileURL

    @Option(
        name: .customLong("downloaded"), help: "The path of configutation file",
        transform: { URL(fileURLWithPath: $0).standardizedFileURL })
    var downloaded: URL?

    @Option(
        name: .customLong("keys"),
        parsing: .upToNextOption,
        help:"The string keys to download before localizing. Supports multiple values and comma-separated values.")
    var keys: [String] = []

    @Option(
        name: .customLong("keys-file"),
        help: "The path of a keys file. One key per line.",
        transform: { URL(fileURLWithPath: $0).standardizedFileURL })
    var keysFile: URL?

    mutating func run() async throws {
        let cfg = try LocalizeConfiguration.load(cfgPath) ?? .default
        print("[INFO]: Read Configuration from file('\(cfgPath.path())'): ")
        print(cfg)

        let localizations = try LocalizeHelper.getAllStringsPath(strings)
        print("[INFO]: Find \(localizations.count) Strings file.")


        var newLocalizations: [UnmanagedLocalization] = []

        if !keys.isEmpty || keysFile != nil {
            let tmp = try? await fetchLocationsFromAPI()
            newLocalizations.append(contentsOf: tmp ?? [])
        }

        if let downloaded {
            let tmp = try? getLocationsFromDownloadFolder(downloaded)
            newLocalizations.append(contentsOf: tmp ?? [])
        }

        guard newLocalizations.count > 0 else {
            print("[ERROR]: No New Locations Founds")
            return
        }

        for destination in localizations {
            print("[INFO]: Processing Lang(\(destination.lang)). Path: \(destination.url.path())")

            do {
                let old = try LocalizeHelper.getLocalization(destination)

                let newLang = cfg.mapLangName(apple: old.lang)
                let new: UnmanagedLocalization? = newLocalizations.first { $0.lang == newLang }
                guard let new else {
                    continue
                }


                let updated = old.update(new) {
                    cfg.ignoreKeys?.contains($0) ?? false
                }
                try LocalizeHelper.writeLocalization(updated)
            } catch {
                print("[ERROR]: Failed to process Lang(\(destination.lang)). Error: \(error)")
            }

            print("[INFO]: Finish Lang(\(destination.lang)).")
        }
    }

    func fetchLocationsFromAPI() async throws -> [UnmanagedLocalization] {
        guard let credential = AuthTokenStore.resolveCredential() else {
            throw ValidationError("'--keys' or '--keys-file' was specified, but no valid credential was found. Please provide a valid token and secret, or set them in the environment variables or auth.json.")
        }

        let keys = try LocalizeRemoteKeyParser.loadKeys(rawKeys: keys, keysFile: keysFile)

        let downloader = Downloader(credential: credential)
        return try await downloader.download(keys: keys)
    }

    func getLocationsFromDownloadFolder(_ downloaded: URL) throws -> [UnmanagedLocalization] {
        let destications = try? LocalizeHelper.getAllStringsPathInLangNameFormat(downloaded)
        guard let destications else {
            print("[ERROR]: Failed to read downloaded localization files in path: \(downloaded.path()). Please check the path and try again.")
            return []
        }

        var newLocalizations: [UnmanagedLocalization] = []
        for destination in destications {
            let new = try LocalizeHelper.getLocalization(destination)
            newLocalizations.append(new.detach())
        }
        return newLocalizations
    }
}
