//
//  IPAListServer.swift
//  CLI
//
//  Created by Huanan on 2025/5/26.
//

import Foundation
import ArgumentParser
import os
import Jinja

struct IPAExport {
    let ipa: URL
    let distributionSummary: URL

    let buildAt: Date

    let sha256: String
    let info: IPAExportInfo
}

struct IPAExportInfo {
    let version: String
    let identifier: String
    let name: String
}

struct IPAManifest: Codable {
    let name: String
    let sha256: String
    let version: String
    let identifier: String
    let buildAt: Date

    let remote: URL
    let icon: String
}

extension IPAManifest {
    func asAny() -> [String: String] {
        let RFC3339DateFormatter = DateFormatter()
        RFC3339DateFormatter.locale = Locale(identifier: "en_US_POSIX")
        RFC3339DateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        RFC3339DateFormatter.timeZone = TimeZone.current

        return [
            "name": name,
            "sha256": sha256,
            "version": version,
            "identifier": identifier,
            "buildAt": RFC3339DateFormatter.string(from: buildAt),
            "remote": "itms-services://?action=download-manifest&url=\(remote.absoluteString)",
            "icon": icon,
            "remote_encoded": "itms-services://?action=download-manifest&url=\(remote.absoluteString)".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "",
        ]
    }
}


struct IPAServer: AsyncParsableCommand {

    @Option(help: .init("The path where all the exports folder located."),
            transform: { URL(fileURLWithPath: $0).standardizedFileURL })
    var exports: URL

    func run() async throws {
        let contents = try FileManager.default.contentsOfDirectory(at: exports, includingPropertiesForKeys: nil)

        guard let indexHtmlTemplateFilePath = contents.first(where: { $0.lastPathComponent == "index.html.template" }) else {
            print("[ERROR] Miss `index.html.template`")
            os.exit(1)
        }

        guard let appPlistTemplateFilePath = contents.first(where: { $0.lastPathComponent == "app_name.plist.template" }) else {
            print("[ERROR] Miss `app_name.plist.template`")
            os.exit(1)
        }

        while true {
            try await Task.sleep(for: .seconds(5))

            let contents = try FileManager.default.contentsOfDirectory(at: exports, includingPropertiesForKeys: nil)

            let manifests = try getIPAManifest()

            let ipaExportList: [IPAExport] = try contents.compactMap {
                try ipaExport(folder: $0)
            }

            let appPlistTemplateContent = try String(contentsOf: appPlistTemplateFilePath, encoding: .utf8)
            let appPlistTemplate = try Jinja.Template(appPlistTemplateContent)

            let meta = ["com.simplehealth.faceyoga": ["icon" : "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/ac/35/bd/ac35bdb3-be72-2818-ea74-01d192cc3075/AppIcon-0-0-1x_U007emarketing-0-7-0-0-85-220.png/460x0w.png"]]
            let newestManifests = try generateIPAPlistAndUploadIfNeeded(ipaExportList, using: appPlistTemplate, manifests: manifests, meta: meta)

            try saveIPAManifest(newestManifests)

            let indexHtmlTemplateContent = try String(contentsOf: indexHtmlTemplateFilePath, encoding: .utf8)
            let indexHtmlTemplate = try Jinja.Template(indexHtmlTemplateContent)

            if newestManifests.count != manifests.count {
                notify()
            }

            try generateIndexHtml(newestManifests, using: indexHtmlTemplate)
        }
    }

    func generateIndexHtml(_ manifests: [IPAManifest], using template: Jinja.Template) throws {
        let path = exports.appending(path: "index.html", directoryHint: .notDirectory)

        let rendered = try template.render([
            "manifests": manifests.sorted(by: { $0.buildAt > $1.buildAt} ) .map({ $0.asAny() })
        ])

        try rendered.write(to: path, atomically: true, encoding: .utf8)
    }


    func getIPAManifest() throws -> [IPAManifest] {
        let path = exports.appending(path: "manifests.lock", directoryHint: .notDirectory)

        guard let data = try? Data(contentsOf: path), data.count > 0 else {
            return []
        }

        let decoder = JSONDecoder()
        let manifests = try decoder.decode([IPAManifest].self, from: data)

        return manifests
    }

    func saveIPAManifest(_ manifests: [IPAManifest]) throws {
        let path = exports.appending(path: "manifests.lock", directoryHint: .notDirectory)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(manifests)

        try data.write(to: path)
    }

    func generateIPAPlistAndUploadIfNeeded(_ ipaExportList: [IPAExport], using template: Jinja.Template, manifests: [IPAManifest], meta: [String: [String: String]] = [:]) throws -> [IPAManifest] {
        try ipaExportList.map { ipaExport in
            if let matched = manifests.first(where: { $0.sha256 == ipaExport.sha256 }) {
                return matched
            }

            return try generateIPAPlistAndUpload(ipaExport, using: template, meta: meta[ipaExport.info.identifier] ?? [:])
        }
    }

    func generateIPAPlistAndUpload(_ ipaExport: IPAExport, using template: Jinja.Template, meta: [String: String] = [:]) throws -> IPAManifest {
        let icon = meta["icon"]
        let rendered = try renderAppPlist(ipaExport, template: template, icon: icon)

        let path = FileManager.default.temporaryDirectory
            .appending(path: "\(ipaExport.info.name)-\(ipaExport.sha256)", directoryHint: .notDirectory)
            .appendingPathExtension("plist")

        try rendered.write(to: path, atomically: true, encoding: .utf8)

        let remote = try uploadFile(path)

        return .init(name: ipaExport.info.name, sha256: ipaExport.sha256, version: ipaExport.info.version, identifier: ipaExport.info.identifier, buildAt:ipaExport.buildAt, remote: remote, icon: icon ?? "")
    }

    func notify() {
        let task = Process()
        let outputPipe = Pipe()

        task.executableURL = URL(filePath: "/usr/bin/osascript", directoryHint: .notDirectory, relativeTo: nil)
        task.arguments = [
            "display notification \"APP Manifests Updated\" with title \"Inston Tool\""
        ]

        task.standardOutput = outputPipe

        try? task.run()
    }

    func uploadFile(_ path: URL) throws -> URL {
        let filename = path.lastPathComponent

        let task = Process()
        let outputPipe = Pipe()

        task.executableURL = URL(filePath: "/Users/huanan/.local/share/mise/installs/gcloud/523.0.1/bin/gcloud", directoryHint: .notDirectory, relativeTo: nil)
        task.arguments = [
            "storage", "cp", path.path(percentEncoded: false), "gs://inston-tool"
        ]

        task.standardOutput = outputPipe

        try? task.run()
        task.waitUntilExit()

        guard task.terminationStatus == 0 else {
            throw ValidationError("Fail")
        }

        return URL(string: "https://storage.googleapis.com/inston-tool/\(filename)")!
    }

    func renderAppPlist(_ ipaExport: IPAExport, template: Jinja.Template, icon: String?) throws -> String {
        let ipaDownladPathComponents = ipaExport.ipa.relativePath(from: exports)
        let ipaDownladPath = ipaDownladPathComponents.map {
            $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0
        }.joined(separator: "/")

        return try template.render([
            "APP_IPA_DOWNLOAD_PATH": ipaDownladPath,
            "APP_ICON_PATH": icon ?? "",
            "APP_BUNDLE_IDENTIFIER": ipaExport.info.identifier,
            "APP_VERSION": ipaExport.info.version,
            "APP_NAME": ipaExport.info.name,
        ])
    }

    func ipaExport(folder: URL) throws -> IPAExport? {
        let values = try folder.resourceValues(forKeys: [.isDirectoryKey, .nameKey])
        guard values.isDirectory == true else {
            return nil
        }

        let subItems = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)

        guard let ipa = subItems.first(where: { $0.pathExtension == "ipa" }), let buildAt = try ipa.resourceValues(forKeys: [.creationDateKey]).creationDate else {
            return nil
        }

        guard let distributionSummary = subItems.first(where: { $0.lastPathComponent == "DistributionSummary.plist" }) else {
            return nil
        }

        guard let info = ipaInfo(distributionSummary: distributionSummary) else {
            return nil
        }

        let sha256 = getIPASha256(ipa).trimmingCharacters(in: .whitespacesAndNewlines)

        return IPAExport(ipa: ipa, distributionSummary: distributionSummary, buildAt: buildAt, sha256: sha256, info: info)
    }

    func getIPASha256(_ path: URL) -> String {
        let shasumTask = Process()
        let shasumoutputPipe = Pipe()

        let awkTask = Process()
        let outputPipe = Pipe()

        shasumTask.executableURL = URL(filePath: "/usr/bin/shasum", directoryHint: .notDirectory, relativeTo: nil)
        shasumTask.arguments = ["-a", "256", path.path(percentEncoded: false)]
        shasumTask.standardOutput = shasumoutputPipe

        awkTask.executableURL = URL(filePath: "/usr/bin/awk", directoryHint: .notDirectory, relativeTo: nil)
        awkTask.arguments = ["{print $1}"]
        awkTask.standardInput = shasumoutputPipe
        awkTask.standardOutput = outputPipe

        try? shasumTask.run()
        try? awkTask.run()
        awkTask.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: outputData, as: UTF8.self)
        return output
    }

    func ipaInfo(distributionSummary: URL) -> IPAExportInfo? {
        guard let data = try? Data(contentsOf: distributionSummary),
              let prop = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            return nil
        }

        guard let ipaName = prop.keys.first else {
            return nil
        }

        guard let appInfo = prop[ipaName] as? [[String: Any]], let appInfo = appInfo.first else {
            return nil
        }

        guard let name = appInfo["name"] as? String,
              let version = appInfo["versionNumber"] as? String,
              let entitlements = appInfo["entitlements"] as? [String: Any],
              let teamIdentifier = entitlements["com.apple.developer.team-identifier"] as? String,
              let applicationIdentifier = entitlements["application-identifier"] as? String
        else {
            return nil
        }

        let bundleIdentidier = applicationIdentifier.replacing(teamIdentifier + ".", with: "")

        return IPAExportInfo(version: version, identifier: bundleIdentidier, name: name.replacing(".app", with: ""))
    }

}

extension URL {
    func relativePath(from base: URL) -> [String] {
        let baseComponents = base.standardized.resolvingSymlinksInPath().pathComponents
        let targetComponents = self.standardized.resolvingSymlinksInPath().pathComponents

        // Find the first non-matching path component
        var index = 0
        while index < baseComponents.count,
              index < targetComponents.count,
              baseComponents[index] == targetComponents[index] {
            index += 1
        }

        // Add ".." for each remaining level in the base
        var relativeComponents = Array(repeating: "..", count: baseComponents.count - index)

        // Add the remaining target components
        relativeComponents.append(contentsOf: targetComponents[index...])

        return relativeComponents
    }
}
