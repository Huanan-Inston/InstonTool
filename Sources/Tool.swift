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
        abstract: "A Tool For Lazy Operations",
        subcommands: [Localize.self, Setup.self, Generate.self],
        defaultSubcommand: nil)
}
