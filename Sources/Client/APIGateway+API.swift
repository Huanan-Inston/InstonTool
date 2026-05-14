//
//  APIGateway+API.swift
//  CLI
//
//  Created by Huanan on 2026/5/14.
//

import Alamofire
import Foundation

extension URL {
    static var drojian: URL {
        URL(string: "https://apigateway.drojian.dev")!
    }
}

extension APIGateway {
    struct API {
        let host: URL?
        let path: String
        let method: HTTPMethod

        init(host: URL? = .drojian, path: String, method: HTTPMethod = .post) {
            self.host = host
            self.path = path
            self.method = method
        }
    }
}

extension APIGateway.API {
    static let strings_batch_query = Self(path: "/api/strings/batch-query")
}
