import Foundation

/// Protocol for modifying requests before execution.
///
/// Request modifiers allow per-request customization without
/// modifying the endpoint definition.
///
/// Example:
/// ```swift
/// struct TimeoutModifier: RequestModifier {
///     let timeout: TimeInterval
///
///     func modify(_ request: HTTPRequest) async throws -> HTTPRequest {
///         request.timeout(timeout)
///     }
/// }
/// ```
public protocol RequestModifier: Sendable {
    /// Modifies the HTTP request.
    ///
    /// - Parameter request: The request to modify
    /// - Returns: The modified request
    /// - Throws: An error if modification fails
    func modify(_ request: HTTPRequest) async throws -> HTTPRequest
}

// MARK: - Common Modifiers

/// Modifies the request timeout.
public struct TimeoutModifier: RequestModifier {
    private let timeout: TimeInterval
    
    public init(timeout: TimeInterval) {
        self.timeout = timeout
    }
    
    public func modify(_ request: HTTPRequest) async throws -> HTTPRequest {
        request.timeout(timeout)
    }
}

/// Adds headers to the request.
public struct HeadersModifier: RequestModifier {
    private let headers: [String: String]
    
    public init(headers: [String: String]) {
        self.headers = headers
    }
    
    public func modify(_ request: HTTPRequest) async throws -> HTTPRequest {
        request.headers(headers)
    }
}

/// Modifies the cache policy.
public struct CachePolicyModifier: RequestModifier {
    private let policy: URLRequest.CachePolicy
    
    public init(policy: URLRequest.CachePolicy) {
        self.policy = policy
    }
    
    public func modify(_ request: HTTPRequest) async throws -> HTTPRequest {
        request.cachePolicy(policy)
    }
}

/// Adds an authorization header.
public struct AuthorizationModifier: RequestModifier {
    private let scheme: HeaderBuilder.AuthorizationScheme
    
    public init(scheme: HeaderBuilder.AuthorizationScheme) {
        self.scheme = scheme
    }
    
    public func modify(_ request: HTTPRequest) async throws -> HTTPRequest {
        request.headers(["Authorization": scheme.headerValue])
    }
    
    /// Creates a modifier with a Bearer token.
    public static func bearer(_ token: String) -> AuthorizationModifier {
        AuthorizationModifier(scheme: .bearer(token))
    }
    
    /// Creates a modifier with an API key.
    public static func apiKey(_ key: String) -> AuthorizationModifier {
        AuthorizationModifier(scheme: .apiKey(key))
    }
    
    /// Creates a modifier with Basic auth.
    public static func basic(username: String, password: String) -> AuthorizationModifier {
        AuthorizationModifier(scheme: .basic(username: username, password: password))
    }
}

/// Adds a custom modification closure.
public struct CustomModifier: RequestModifier {
    private let transform: @Sendable (HTTPRequest) async throws -> HTTPRequest
    
    public init(transform: @escaping @Sendable (HTTPRequest) async throws -> HTTPRequest) {
        self.transform = transform
    }
    
    public func modify(_ request: HTTPRequest) async throws -> HTTPRequest {
        try await transform(request)
    }
}

// MARK: - Modifier Composition

extension Array where Element == any RequestModifier {
    
    /// Applies all modifiers to the request.
    public func apply(to request: HTTPRequest) async throws -> HTTPRequest {
        var modifiedRequest = request
        for modifier in self {
            modifiedRequest = try await modifier.modify(modifiedRequest)
        }
        return modifiedRequest
    }
}
