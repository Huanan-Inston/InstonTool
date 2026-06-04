//
//  LocalizeRemoteDownload.swift
//  CLI
//
//  Created by Huanan on 2026/5/13.
//

import Alamofire
import ArgumentParser
import DynamicJSON
import Foundation

enum RemoteLocalizationParser {
    static func localizations(
        from data: [String: [DownloadedStringValue]],
        keys: [String]
    ) -> [Localization] {
        var contentByLanguage: [String: [String: String]] = [:]
        for key in keys {
            for item in data[key] ?? [] {
                contentByLanguage[item.lancode, default: [:]][key] = item.value
            }
        }

        return contentByLanguage.map { lang, content in
            Localization(lang: lang, url: URL(fileURLWithPath: "/api/strings/batch-query"), content: content)
        }
    }
}

enum LocalizeRemoteKeyParser {
    static func loadKeys(rawKeys: [String], keysFile: URL?) throws -> [String] {
        var keys = normalize(rawKeys)
        if let keysFile {
            let content = try String(contentsOf: keysFile, encoding: .utf8)
            keys.append(contentsOf: normalize(content.components(separatedBy: .newlines)))
        }

        var seen: Set<String> = []
        return keys.filter { seen.insert($0).inserted }
    }

    private static func normalize(_ rawKeys: [String]) -> [String] {
        rawKeys
            .flatMap { $0.split(separator: ",") }
            .map { $0.trimmingWhitespacesAndNewlines() }
            .filter { !$0.isEmpty }
    }
}

extension Localize {
    struct Downloader {
        let credential: APIGateway.Credential

        func download(keys: [String], exact: Bool = true) async throws -> [UnmanagedLocalization] {
            let body: JSON = [
                "platform": 2,
                "skeys": keys.jsonValue ?? [],
                "is_exact": exact ? 1 : 0
            ]
            let result: StringsBatchQueryResponse = try await APIGateway.Client(credential: credential).request(endpoint: .strings_batch_query, body: body)
            return result.toUnmanagedLocalization()
        }
    }
}

extension StringsBatchQueryResponse {
    func toUnmanagedLocalization() -> [UnmanagedLocalization] {
        guard let data else {
            return []
        }

        var res: [UnmanagedLocalization] = []

        let langs = Set(data.values.flatMap { $0 }.map { $0.lancode })

        for lang in langs {
            let content = data.compactMapValues {
                $0.first { $0.lancode == lang }.map { $0.value }
            }

            res.append(UnmanagedLocalization(lang: lang, content: content))
        }

        return res
    }
}

struct StringsBatchQueryResponse: Decodable {
    let code: Int
    let msg: String?
    let data: [String: [DownloadedStringValue]]?
}

struct DownloadedStringValue: Decodable {
    let lancode: String
    let value: String
}
