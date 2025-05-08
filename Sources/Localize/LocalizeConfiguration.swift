//
//  Untitled.swift
//  CLI
//
//  Created by Huanan on 2025/5/7.
//

import Yams
import Foundation

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

        guard let data = try? Data(contentsOf: path),
              !data.isEmpty else {
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
