//
//  CLI.swift
//  CLI
//
//  Created by Huanan on 2025/5/7.
//

import ArgumentParser
import Foundation

@main
struct Tool: AsyncParsableCommand {
    static let configuration: CommandConfiguration = .init(
        abstract: "A Tool For Inston Operations",
        usage: nil,
        discussion: """
            Recommand [mint](github.com/yonaskolb/Mint) for better experience.
        """,
        subcommands: [Auth.self, Localize.self, Setup.self, IPAServer.self],
        defaultSubcommand: nil)
}
