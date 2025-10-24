import Foundation

extension XCStrings {
    enum ExtractionState: String, Codable, CodingKeyRepresentable, Hashable {
        /// automatically extracted strings
        case extracted_with_value
        /// manually added translations
        case manual
        /// translations converted from other formats.
        case migrated
    }
}

extension XCStrings {
    struct Language: RawRepresentable, Codable, Hashable, CodingKeyRepresentable {
        let value: Locale.Language

        init(value: Locale.Language) {
            self.value = value
        }

        // BCP-47
        // https://datatracker.ietf.org/doc/html/rfc5646#section-2.1
        var rawValue: String {
            self.value.minimalIdentifier
        }

        init(rawValue: String) {
            self.value = Locale.Language(identifier: rawValue)
        }
    }
}

extension XCStrings {
    enum TranslationState: String, Codable, CodingKeyRepresentable, Hashable {
        /// The translation is complete and ready for use
        case translated
        /// The translation exists but requires review
        case needs_review
        /// A new translation that hasn't been completed yet
        case new
        /// The source text has changed and the translation needs updating
        case stale
    }
}

extension XCStrings {
    enum Plural: String, Codable, CodingKeyRepresentable, Hashable {
        case zero
        case one
        case two
        case few
        case many
        case other
    }
}

extension XCStrings {
    enum Device: String, Codable, CodingKeyRepresentable, Hashable {
        case appletv
        case applevision
        case applewatch
        case ipad
        case iphone
        case ipod
        case mac
        case other
    }
}

extension XCStrings {
    enum Variations: Codable {
        case plural([Plural: Localization])
        case device([Device: Localization])

        enum CodingKeys: CodingKey {
            case plural
            case device
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: XCStrings.Variations.CodingKeys.self)

            guard let key = container.allKeys.first else {
                throw DecodingError.typeMismatch(XCStrings.Localization.self, DecodingError.Context(codingPath: container.codingPath, debugDescription: "Miss Key", underlyingError: nil))
            }

            switch key {
            case .plural:
                self = try .plural(container.decode([Plural: Localization].self, forKey: .plural))
            case .device:
                self = try .device(container.decode([Device: Localization].self, forKey: .device))
            }
        }
    }
}

extension XCStrings {
    struct StringUnit: Codable {
        let state: TranslationState
        let value: String
    }
}

extension XCStrings {
    enum Localization: Codable {
        case stringUnit(StringUnit)
        case variations(Variations)

        enum CodingKeys: CodingKey {
            case stringUnit
            case variations
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: XCStrings.Localization.CodingKeys.self)

            guard let key = container.allKeys.first else {
                throw DecodingError.typeMismatch(XCStrings.Localization.self, DecodingError.Context(codingPath: container.codingPath, debugDescription: "Miss Key", underlyingError: nil))
            }

            switch key {
            case .stringUnit:
                self = try .stringUnit(container.decode(StringUnit.self, forKey: .stringUnit))
            case .variations:
                self = try .variations(container.decode(Variations.self, forKey: .variations))
            }
        }
    }
}

extension XCStrings {
    struct XCString: Codable {
        let comment: String?
        let extractionState: ExtractionState //
        let generatesSymbol: Bool? // default true
        let localizations: [Language: XCStrings.Localization]?
    }
}

struct XCStrings: Codable {
    let version: String

    let sourceLanguage: Language

    let strings: [String: XCString]?
}
