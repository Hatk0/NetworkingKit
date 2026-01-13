import Foundation

/// Represents an API endpoint with all necessary request information.
///
/// `Endpoint` is a protocol-oriented abstraction for defining API endpoints.
/// It encapsulates the path, method, headers, and parameters for a request.
///
/// Example:
/// ```swift
/// struct GetUserEndpoint: Endpoint {
///     let userId: Int
///
///     var path: String { "/users/\(userId)" }
///     var method: HTTPMethod { .get }
/// }
/// ```
public protocol Endpoint {
    /// The endpoint path relative to the base URL.
    var path: String { get }
    
    /// The HTTP method to use.
    var method: HTTPMethod { get }
    
    /// HTTP headers specific to this endpoint.
    var headers: [String: String] { get }
    
    /// URL query parameters.
    var queryParameters: [String: Any]? { get }
    
    /// Request body parameters.
    var bodyParameters: [String: Any]? { get }
    
    /// Parameter encoding strategy.
    var encoding: ParameterEncoding { get }
}

// MARK: - Default Implementations

extension Endpoint {
    /// Default headers (empty dictionary).
    public var headers: [String: String] {
        [:]
    }
    
    /// Default query parameters (nil).
    public var queryParameters: [String: Any]? {
        nil
    }
    
    /// Default body parameters (nil).
    public var bodyParameters: [String: Any]? {
        nil
    }
    
    /// Default encoding strategy based on HTTP method.
    public var encoding: ParameterEncoding {
        switch method {
        case .get, .delete, .head:
            return URLEncoding.default
        case .post, .put, .patch:
            return JSONEncoding.default
        case .options:
            return URLEncoding.default
        }
    }
}

// MARK: - Concrete Endpoint Types

/// A simple endpoint for GET requests.
public struct GetEndpoint: Endpoint {
    public let path: String
    public let queryParameters: [String: Any]?
    
    public var method: HTTPMethod { .get }
    
    public init(path: String, queryParameters: [String: Any]? = nil) {
        self.path = path
        self.queryParameters = queryParameters
    }
}

/// A simple endpoint for POST requests with JSON body.
public struct PostEndpoint: Endpoint {
    public let path: String
    public let bodyParameters: [String: Any]?
    
    public var method: HTTPMethod { .post }
    
    public init(path: String, bodyParameters: [String: Any]? = nil) {
        self.path = path
        self.bodyParameters = bodyParameters
    }
}

/// A simple endpoint for PUT requests with JSON body.
public struct PutEndpoint: Endpoint {
    public let path: String
    public let bodyParameters: [String: Any]?
    
    public var method: HTTPMethod { .put }
    
    public init(path: String, bodyParameters: [String: Any]? = nil) {
        self.path = path
        self.bodyParameters = bodyParameters
    }
}

/// A simple endpoint for PATCH requests with JSON body.
public struct PatchEndpoint: Endpoint {
    public let path: String
    public let bodyParameters: [String: Any]?
    
    public var method: HTTPMethod { .patch }
    
    public init(path: String, bodyParameters: [String: Any]? = nil) {
        self.path = path
        self.bodyParameters = bodyParameters
    }
}

/// A simple endpoint for DELETE requests.
public struct DeleteEndpoint: Endpoint {
    public let path: String
    public let queryParameters: [String: Any]?
    
    public var method: HTTPMethod { .delete }
    
    public init(path: String, queryParameters: [String: Any]? = nil) {
        self.path = path
        self.queryParameters = queryParameters
    }
}
