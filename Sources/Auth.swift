//
//  Auth.swift
//  CLI
//
//  Created by Huanan on 2026/5/13.
//

import ArgumentParser
import Foundation

struct Auth: ParsableCommand {
    static let configuration: CommandConfiguration = .init(
        commandName: "auth",
        abstract: "Save APIGateway auth token."
    )

    @Option(name: .customLong("access_key"),
            help: "Develop token or Bearer JWT to save.")
    var access_key: String

    @Option(name: .customLong("access_secret"),
            help: "JWT signing secret to save.")
    var access_secret: String

    func run() throws {
        let access_key = access_key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !access_key.isEmpty else {
            throw ValidationError("'--access_key' cannot be empty.")
        }

        let secret = access_secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !secret.isEmpty else {
            throw ValidationError("'--secret' cannot be empty.")
        }

        try AuthTokenStore.save(token: access_key, secret: secret)
        print("[INFO]: Auth saved to '\(AuthTokenStore.authFile.path())'.")
    }
}
