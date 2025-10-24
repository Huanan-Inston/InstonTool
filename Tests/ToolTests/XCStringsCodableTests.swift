//
//  XCStringsCodableTests.swift
//  CLI
//
//  Created by Huanan on 2025/10/24.
//

import Testing
@testable import Tool
import Foundation

@Test
func testXCStringsCodable() async throws {
    guard let fileURL = Bundle.module.url(forResource: "testing", withExtension: "json") else {
        Issue.record("Miss test file: \"Localizable.xcstrings\"")
        return
    }

    let data = try Data(contentsOf: fileURL)
//    print(String(data: data, encoding: .utf8)!)


//    let encoder = JSONEncoder()
//
//    let ss = XCStrings(version: "1.1", sourceLanguage: .init(rawValue: "en"), strings: [
//        .init(rawValue: "en"): XCStrings.LocalizedString(comment: nil, extractionState: .init(rawValue: "a"), generatesSymbol: false, localizations: [:])
//    ])
//
//    let encoded = try encoder.encode(ss)
//    print(String(data: encoded, encoding: .utf8))


//
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(XCStrings.self, from: data)
//
    print(decoded)

}
