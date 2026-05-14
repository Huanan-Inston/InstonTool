//
//  AuthTokenStore.swift
//  CLI
//
//  Created by Huanan on 2026/5/13.
//

import ArgumentParser
import Foundation

enum AuthTokenStore {
    private static let DROJIAN_ACCESS_KEY = "DROJIAN_ACCESS_KEY"
    private static let DROJIAN_ACCESS_SECRET = "DROJIAN_ACCESS_SECRET"

    static var authFile: URL {
        configHome
            .appending(path: "inston")
            .appending(path: "auth.json")
    }

    static func save(token: String, secret: String) throws {
        let folder = authFile.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        var payload = try loadAuthPayload()
        payload[DROJIAN_ACCESS_KEY] = token
        payload[DROJIAN_ACCESS_SECRET] = secret

        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: authFile, options: .atomic)
    }

    static func resolveCredential(access_key: String? = nil, access_secret: String? = nil) -> APIGateway.Credential? {
        if let access_key = access_key?.trimmingWhitespacesAndNewlines(),
           let access_secret = access_secret?.trimmingWhitespacesAndNewlines() {
            return .init(access_key: access_key, access_secret: access_secret)
        }

        if let access_key = ProcessInfo.processInfo.environment[DROJIAN_ACCESS_KEY]?.trimmingWhitespacesAndNewlines(),
           let access_secret = ProcessInfo.processInfo.environment[DROJIAN_ACCESS_SECRET]?.trimmingWhitespacesAndNewlines() {
            return .init(access_key: access_key, access_secret: access_secret)
        }

        if let payload = try? loadAuthPayload(),
           let access_key = payload[DROJIAN_ACCESS_KEY]?.trimmingWhitespacesAndNewlines(),
           let access_secret = payload[DROJIAN_ACCESS_SECRET]?.trimmingWhitespacesAndNewlines() {
            return .init(access_key: access_key, access_secret: access_secret)
        }

        return nil
    }

    private static var configHome: URL {
        if let path = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]?.trimmingWhitespacesAndNewlines() {
            return URL(fileURLWithPath: path).standardizedFileURL
        }

        return FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".config")
            .standardizedFileURL
    }

    private static func loadAuthPayload() throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: authFile.path()) else {
            return [:]
        }

        let data = try Data(contentsOf: authFile)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            return [:]
        }

        var result: [String: String] = [:]
        for (key, value) in dictionary {
            if let value = value as? String {
                result[key] = value
            }
        }
        return result
    }
}
