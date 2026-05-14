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
        usage: """
        tool <SUBCOMMAND>
        tool auth --access_key <TOKEN> --access_secret <SECRET>
        tool setup "(?<=L\\(@\")([_\\w]+)(?=\")" --strings ./MapRunner/Strings
        tool localize --strings ./MapRunner/Strings --keys having_problem_tell_gpt --keys good_job
        tool localize --strings ./MapRunner/Strings --keys-file ./keys.txt
        tool localize --strings ./MapRunner/Strings --downloaded <dowload path>
        tool generate ./LangGen/OCL+Keys.h.template ./LangGen/OCL+Keys.m.template --output ./LangGen --strings ./MapRunner/Strings    

        Recommand [mint](github.com/yonaskolb/Mint) for better experience.
        example:
          - mint run Huanan-Inston/InstonTool auth --access_key <TOKEN> --access_secret <SECRET>
          - mint run Huanan-Inston/InstonTool localize --strings ./MapRunner/Strings --keys having_problem_tell_gpt --keys good_job
          - mint run Huanan-Inston/InstonTool localize --strings ./MapRunner/Strings
        """,
        subcommands: [Auth.self, Localize.self, Setup.self, Generate.self, IPAServer.self],
        defaultSubcommand: nil)
}
