import Foundation

/// Protocol for providing authentication credentials.
///
/// Implement this protocol to provide custom authentication logic.
public protocol AuthenticationProvider: Sendable {
    /// Returns the authentication header value.
    func authenticationHeader() async throws -> (key: String, value: String)?
    
    /// Called when authentication fails (e.g., 401 response).
    /// Returns true if the request should be retried.
    func reauthenticate() async throws -> Bool
}

// MARK: - Bearer Token Provider

/// Provides Bearer token authentication.
public struct BearerTokenProvider: AuthenticationProvider {
    private let tokenClosure: @Sendable () async throws -> String?
    
    /// Initializes with a token.
    public init(token: String) {
        self.tokenClosure = { token }
    }
    
    /// Initializes with an async token provider.
    public init(tokenProvider: @escaping @Sendable () async throws -> String?) {
        self.tokenClosure = tokenProvider
    }
    
    public func authenticationHeader() async throws -> (key: String, value: String)? {
        guard let token = try await tokenClosure() else {
            return nil
        }
        return ("Authorization", "Bearer \(token)")
    }
    
    public func reauthenticate() async throws -> Bool {
        // In a real app, refresh the token here
        false
    }
}

// MARK: - API Key Provider

/// Provides API key authentication.
public struct APIKeyProvider: AuthenticationProvider {
    private let key: String
    private let headerName: String
    
    /// Initializes with an API key.
    ///
    /// - Parameters:
    ///   - key: The API key
    ///   - headerName: The header name (default: "X-API-Key")
    public init(key: String, headerName: String = "X-API-Key") {
        self.key = key
        self.headerName = headerName
    }
    
    public func authenticationHeader() async throws -> (key: String, value: String)? {
        (headerName, key)
    }
    
    public func reauthenticate() async throws -> Bool {
        false
    }
}

// MARK: - Basic Auth Provider

/// Provides Basic authentication.
public struct BasicAuthProvider: AuthenticationProvider {
    private let username: String
    private let password: String
    
    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
    
    public func authenticationHeader() async throws -> (key: String, value: String)? {
        let credentials = "\(username):\(password)"
        let encodedCredentials = Data(credentials.utf8).base64EncodedString()
        return ("Authorization", "Basic \(encodedCredentials)")
    }
    
    public func reauthenticate() async throws -> Bool {
        false
    }
}

// MARK: - Authentication Middleware

/// Middleware for automatic authentication injection.
///
/// This middleware automatically adds authentication headers to requests
/// and handles 401 responses by attempting to reauthenticate.
public struct AuthenticationMiddleware: Middleware {
    private let provider: any AuthenticationProvider
    private let shouldRetryOn401: Bool
    
    /// Initializes authentication middleware.
    ///
    /// - Parameters:
    ///   - provider: The authentication provider
    ///   - shouldRetryOn401: Whether to retry on 401 responses (default: true)
    public init(provider: any AuthenticationProvider, shouldRetryOn401: Bool = true) {
        self.provider = provider
        self.shouldRetryOn401 = shouldRetryOn401
    }
    
    public func intercept(
        _ request: HTTPRequest,
        next: @Sendable (HTTPRequest) async throws -> HTTPResponse
    ) async throws -> HTTPResponse {
        // Add authentication header
        var authenticatedRequest = request
        if let (key, value) = try await provider.authenticationHeader() {
            authenticatedRequest = authenticatedRequest.headers([key: value])
        }
        
        // Execute request
        do {
            let response = try await next(authenticatedRequest)
            return response
        } catch let error as NetworkError {
            // Handle 401 Unauthorized
            if case .httpError(let statusCode, _) = error, statusCode == 401, shouldRetryOn401 {
                // Attempt to reauthenticate
                let shouldRetry = try await provider.reauthenticate()
                if shouldRetry {
                    // Retry with new credentials
                    var retryRequest = request
                    if let (key, value) = try await provider.authenticationHeader() {
                        retryRequest = retryRequest.headers([key: value])
                    }
                    return try await next(retryRequest)
                }
            }
            throw error
        }
    }
}

// MARK: - Convenience Extensions

extension AuthenticationMiddleware {
    /// Creates authentication middleware with a Bearer token.
    public static func bearer(token: String) -> AuthenticationMiddleware {
        AuthenticationMiddleware(provider: BearerTokenProvider(token: token))
    }
    
    /// Creates authentication middleware with an async Bearer token provider.
    public static func bearer(tokenProvider: @escaping @Sendable () async throws -> String?) -> AuthenticationMiddleware {
        AuthenticationMiddleware(provider: BearerTokenProvider(tokenProvider: tokenProvider))
    }
    
    /// Creates authentication middleware with an API key.
    public static func apiKey(_ key: String, headerName: String = "X-API-Key") -> AuthenticationMiddleware {
        AuthenticationMiddleware(provider: APIKeyProvider(key: key, headerName: headerName))
    }
    
    /// Creates authentication middleware with Basic auth.
    public static func basic(username: String, password: String) -> AuthenticationMiddleware {
        AuthenticationMiddleware(provider: BasicAuthProvider(username: username, password: password))
    }
}
