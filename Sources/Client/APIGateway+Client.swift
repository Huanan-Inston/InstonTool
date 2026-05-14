//
//  APIGateway+Client.swift
//  CLI
//
//  Created by Huanan on 2026/5/14.
//

import Alamofire
import Foundation

extension APIGateway {
    struct Client {
        var host: URL = URL(string: "https://apigateway.drojian.dev")!
        let credential: Credential
    }
}

extension APIGateway.Client {

    func request<Request:Encodable & Sendable, Response:Decodable & Sendable>(
        endpoint: APIGateway.API,
        body: Request,
        as type: Response.Type = Response.self
    ) async throws -> Response {
        let token = try APIGateway.bearerToken(from: credential)
        let host = endpoint.host ?? host
        let url = host.appending(path: endpoint.path)

        return try await AF.request(
            url,
            method: endpoint.method,
            parameters: body,
            encoder: URLEncodedFormParameterEncoder.default,
            headers: [.authorization(bearerToken: token)]
        ).serializingDecodable(Response.self).value
    }

}
