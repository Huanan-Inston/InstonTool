//
//  APIGateway.swift
//  CLI
//
//  Created by Huanan on 2026/5/14.
//

import Foundation
import CryptoKit


private struct JWTHeader: Encodable {
    let alg = "HS256"
    let typ = "JWT"
}

private struct JWTPayload: Encodable {
    let iss: String
    let iat: Int
    let exp: Int
    let user: JWTUser
}

private struct JWTUser: Encodable {
    let developtoken: String
}


enum APIGateway {
    static func bearerToken(from credential: Credential) throws -> String {
        try makeJWT(access_key: credential.access_key, access_secret: credential.access_secret)
    }

    private static func makeJWT(access_key: String, access_secret: String) throws -> String {
        let issuedAt = Int(Date().timeIntervalSince1970)
        let header = JWTHeader()
        let payload = JWTPayload(
            iss: "issuer",
            iat: issuedAt,
            exp: issuedAt + 86_400,
            user: .init(developtoken: access_key)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let encodedHeader = base64URLEncoded(try encoder.encode(header))
        let encodedPayload = base64URLEncoded(try encoder.encode(payload))
        let signingInput = "\(encodedHeader).\(encodedPayload)"

        let signature = HMAC<SHA256>.authenticationCode(
            for: Data(signingInput.utf8),
            using: SymmetricKey(data: Data(access_secret.utf8))
        )
        return "\(signingInput).\(base64URLEncoded(Data(signature)))"
    }

    private static func base64URLEncoded(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension APIGateway {
    struct Credential {
        let access_key: String
        let access_secret: String
    }
}
