//
//  Operation.swift
//  
//
//  Created by Mathew Polzin on 7/4/19.
//

import Foundation

extension OpenAPI.PathItem {
    /// OpenAPI Spec "Operation Object"
    /// 
    /// See [OpenAPI Operation Object](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.0.3.md#operation-object).
    public struct Operation: Equatable, CodableVendorExtendable {
        public var tags: [String]?
        public var summary: String?
        public var description: String?
        public var externalDocs: OpenAPI.ExternalDocumentation?
        public var operationId: String?
        public var parameters: Parameter.Array
        public var requestBody: Either<JSONReference<OpenAPI.Request>, OpenAPI.Request>?
        public var responses: OpenAPI.Response.Map
//      public let callbacks:
        public var deprecated: Bool // default is false
        public var security: [OpenAPI.SecurityRequirement]? // must be optional because an empty array here overrides a populated array in `Document`
        public var servers: [OpenAPI.Server]?

        /// Dictionary of vendor extensions.
        ///
        /// These should be of the form:
        /// `[ "x-extensionKey": <anything>]`
        /// where the values are anything codable.
        public var vendorExtensions: [String: AnyCodable]

        public init(tags: [String]? = nil,
                    summary: String? = nil,
                    description: String? = nil,
                    externalDocs: OpenAPI.ExternalDocumentation? = nil,
                    operationId: String? = nil,
                    parameters: Parameter.Array = [],
                    requestBody: OpenAPI.Request? = nil,
                    responses: OpenAPI.Response.Map,
                    deprecated: Bool = false,
                    security: [OpenAPI.SecurityRequirement]? = nil,
                    servers: [OpenAPI.Server]? = nil,
                    vendorExtensions: [String: AnyCodable] = [:]) {
            self.tags = tags
            self.summary = summary
            self.description = description
            self.externalDocs = externalDocs
            self.operationId = operationId
            self.parameters = parameters
            self.requestBody = requestBody.map(Either.init)
            self.responses = responses
            self.deprecated = deprecated
            self.security = security
            self.servers = servers
            self.vendorExtensions = vendorExtensions
        }

        // variadic tags
        public init(tags: String...,
                    summary: String? = nil,
                    description: String? = nil,
                    externalDocs: OpenAPI.ExternalDocumentation? = nil,
                    operationId: String? = nil,
                    parameters: Parameter.Array,
                    requestBody: OpenAPI.Request? = nil,
                    responses: OpenAPI.Response.Map,
                    deprecated: Bool = false,
                    security: [OpenAPI.SecurityRequirement]? = nil,
                    servers: [OpenAPI.Server]? = nil,
                    vendorExtensions: [String: AnyCodable] = [:]) {
            self.init(
                tags: tags,
                summary: summary,
                description: description,
                externalDocs: externalDocs,
                operationId: operationId,
                parameters: parameters,
                requestBody: requestBody,
                responses: responses,
                deprecated: deprecated,
                security: security,
                servers: servers,
                vendorExtensions: vendorExtensions
            )
        }
    }
}

// MARK: - Codable

extension OpenAPI.PathItem.Operation: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try tags.encodeIfNotNil(to: &container, forKey: .tags)

        try summary.encodeIfNotNil(to: &container, forKey: .summary)

        try description.encodeIfNotNil(to: &container, forKey: .description)

        try externalDocs.encodeIfNotNil(to: &container, forKey: .externalDocs)

        try operationId.encodeIfNotNil(to: &container, forKey: .operationId)

        if !parameters.isEmpty {
            try container.encode(parameters, forKey: .parameters)
        }

        try requestBody.encodeIfNotNil(to: &container, forKey: .requestBody)

        try container.encode(responses, forKey: .responses)

        if deprecated {
            try container.encode(deprecated, forKey: .deprecated)
        }

        if let securityRequirements = security {
            try encodeSecurity(requirements: securityRequirements, to: &container, forKey: .security)
        }

        try servers.encodeIfNotNil(to: &container, forKey: .servers)

        try encodeExtensions(to: &container)
    }
}

extension OpenAPI.PathItem.Operation: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        do {
            tags = try container.decodeIfPresent([String].self, forKey: .tags)

            summary = try container.decodeIfPresent(String.self, forKey: .summary)

            description = try container.decodeIfPresent(String.self, forKey: .description)

            externalDocs = try container.decodeIfPresent(OpenAPI.ExternalDocumentation.self, forKey: .externalDocs)

            operationId = try container.decodeIfPresent(String.self, forKey: .operationId)

            parameters = try container.decodeIfPresent(OpenAPI.PathItem.Parameter.Array.self, forKey: .parameters) ?? []

            requestBody = try container.decodeIfPresent(Either<JSONReference<OpenAPI.Request>, OpenAPI.Request>.self, forKey: .requestBody)

            responses = try container.decode(OpenAPI.Response.Map.self, forKey: .responses)

            deprecated = try container.decodeIfPresent(Bool.self, forKey: .deprecated) ?? false

            security = try decodeSecurityRequirements(from: container, forKey: .security, given: nil)

            servers = try container.decodeIfPresent([OpenAPI.Server].self, forKey: .servers)

            vendorExtensions = try Self.extensions(from: decoder)
        } catch let error as OpenAPI.Error.Decoding.Request {

            throw OpenAPI.Error.Decoding.Operation(error)
        } catch let error as OpenAPI.Error.Decoding.Response {

            throw OpenAPI.Error.Decoding.Operation(error)
        } catch let error as DecodingError {

            throw OpenAPI.Error.Decoding.Operation(unwrapping: error)
        } catch let error as InconsistencyError {

            throw OpenAPI.Error.Decoding.Operation(error)
        } catch let error as EitherDecodeNoTypesMatchedError {

            throw OpenAPI.Error.Decoding.Operation(error)
        }
    }
}

extension OpenAPI.PathItem.Operation {
    internal enum CodingKeys: ExtendableCodingKey {
        case tags
        case summary
        case description
        case externalDocs
        case operationId
        case parameters
        case requestBody
        case responses
//      case callbacks
        case deprecated
        case security
        case servers

        case extended(String)

        static var allBuiltinKeys: [CodingKeys] {
            return [
                .tags,
                .summary,
                .description,
                .externalDocs,
                .operationId,
                .parameters,
                .requestBody,
                .responses,
//                .callbacks,
                .deprecated,
                .security,
                .servers
            ]
        }

        static func extendedKey(for value: String) -> CodingKeys {
            return .extended(value)
        }

        init?(stringValue: String) {
            switch stringValue {
            case "tags":
                self = .tags
            case "summary":
                self = .summary
            case "description":
                self = .description
            case "externalDocs":
                self = .externalDocs
            case "operationId":
                self = .operationId
            case "parameters":
                self = .parameters
            case "requestBody":
                self = .requestBody
            case "responses":
                self = .responses
            case "deprecated":
                self = .deprecated
            case "security":
                self = .security
            case "servers":
                self = .servers
            default:
                self = .extendedKey(for: stringValue)
            }
        }

        init?(intValue: Int) {
            return nil
        }

        var stringValue: String {
            switch self {
            case .tags:
                return "tags"
            case .summary:
                return "summary"
            case .description:
                return "description"
            case .externalDocs:
                return "externalDocs"
            case .operationId:
                return "operationId"
            case .parameters:
                return "parameters"
            case .requestBody:
                return "requestBody"
            case .responses:
                return "responses"
            case .deprecated:
                return "deprecated"
            case .security:
                return "security"
            case .servers:
                return "servers"
            case .extended(let key):
                return key
            }
        }

        var intValue: Int? {
            return nil
        }
    }
}
