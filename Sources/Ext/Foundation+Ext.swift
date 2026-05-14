//
//  Foundation+Ext.swift
//  CLI
//
//  Created by Huanan on 2026/5/14.
//

extension StringProtocol {
    func trimmingWhitespacesAndNewlines() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
