//
//  ProjHelper.swift
//  CLI
//
//  Created by Huanan on 2025/5/7.
//

import Foundation

enum ProjHelper {

    static let sourceFileValidSuffix = [".m", ".mm", ".h", ".swift"]

    static func getAllSourceFilesPath(
        _ path: URL,
        propertiesForKeys: [URLResourceKey] = [.isRegularFileKey, .nameKey]
    )
    throws -> [URL]
    {

        try getAllSourceFilesPath(path, propertiesForKeys: propertiesForKeys) { _, props in
            sourceFileValidSuffix.contains { props.name?.hasSuffix($0) ?? false }
        }
    }

    static func getAllSourceFilesPath(
        _ path: URL,
        propertiesForKeys: [URLResourceKey] = [.isRegularFileKey, .nameKey],
        predicate: (URL, URLResourceValues) -> Bool
    )
    throws -> [URL]
    {
        guard let dirEnum = FileManager.default.enumerator(at: path, includingPropertiesForKeys: propertiesForKeys) else {
            throw NSError()
        }

        let result = try dirEnum.compactMap({ $0 as? URL }).filter { item in
            let values = try item.resourceValues(forKeys: Set(propertiesForKeys))
            return values.isRegularFile == true && predicate(item, values)
        }

        return result
    }
}
