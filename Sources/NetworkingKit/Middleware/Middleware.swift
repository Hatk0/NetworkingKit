import Foundation

/// Protocol for intercepting and modifying HTTP requests and responses.
///
/// Middleware provides a powerful mechanism for implementing cross-cutting
/// concerns such as authentication, logging, retry logic, and caching.
///
/// Example:
/// ```swift
/// struct LoggingMiddleware: Middleware {
///     func intercept(_ request: HTTPRequest, next: (HTTPRequest) async throws -> HTTPResponse) async throws -> HTTPResponse {
///         print("Request: \(request.url)")
///         let response = try await next(request)
///         print("Response: \(response.statusCode)")
///         return response
///     }
/// }
/// ```
public protocol Middleware: Sendable {
    /// Intercepts a request before execution.
    ///
    /// - Parameters:
    ///   - request: The HTTP request to intercept
    ///   - next: The next middleware in the chain (or the actual HTTP execution)
    /// - Returns: The HTTP response
    /// - Throws: NetworkError if the request fails
    func intercept(
        _ request: HTTPRequest,
        next: @Sendable (HTTPRequest) async throws -> HTTPResponse
    ) async throws -> HTTPResponse
}

// MARK: - Middleware Chain

/// Chains multiple middleware together for sequential execution.
///
/// The middleware are executed in the order they are added,
/// with each middleware having the opportunity to modify the request
/// before passing it to the next middleware in the chain.
///
/// Example:
/// ```swift
/// let chain = MiddlewareChain(client: httpClient)
/// await chain.add(AuthenticationMiddleware(token: "abc"))
/// await chain.add(LoggingMiddleware())
/// await chain.add(RetryMiddleware())
/// ```
public actor MiddlewareChain: HTTPClient {
    private let client: HTTPClient
    private var middlewares: [any Middleware] = []
    
    /// Initializes a middleware chain with an underlying HTTP client.
    ///
    /// - Parameter client: The underlying HTTP client to execute requests
    public init(client: HTTPClient) {
        self.client = client
    }
    
    /// Adds a middleware to the end of the chain.
    ///
    /// - Parameter middleware: The middleware to add
    @discardableResult
    public func add(_ middleware: any Middleware) -> MiddlewareChain {
        middlewares.append(middleware)
        return self
    }
    
    /// Adds multiple middleware to the end of the chain.
    ///
    /// - Parameter middlewares: The middleware to add
    @discardableResult
    public func add(_ middlewares: [any Middleware]) -> MiddlewareChain {
        self.middlewares.append(contentsOf: middlewares)
        return self
    }
    
    public func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        // Build the middleware chain from end to beginning
        let finalHandler: @Sendable (HTTPRequest) async throws -> HTTPResponse = { [client] request in
            try await client.execute(request)
        }
        
        // Fold the middleware chain
        let handler = middlewares.reversed().reduce(finalHandler) { next, middleware in
            { request in
                try await middleware.intercept(request, next: next)
            }
        }
        
        return try await handler(request)
    }
}
