import Foundation

/// Represents an HTTP request with all necessary components.
///
/// `HTTPRequest` is a value type that encapsulates all information needed to
/// perform an HTTP request. It uses value semantics for immutability and thread safety.
///
/// Example:
/// ```swift
/// let request = HTTPRequest(
///     url: URL(string: "https://api.example.com/users")!,
///     method: .get,
///     headers: ["Authorization": "Bearer token"],
///     body: nil
/// )
/// ```
public struct HTTPRequest: Sendable {
    /// The target URL for the request.
    public let url: URL
    
    /// The HTTP method to use.
    public let method: HTTPMethod
    
    /// HTTP headers to include in the request.
    public let headers: [String: String]
    
    /// The request body data, if any.
    public let body: Data?
    
    /// Timeout interval for the request. Defaults to 60 seconds.
    public let timeoutInterval: TimeInterval
    
    /// Cache policy for the request.
    public let cachePolicy: URLRequest.CachePolicy
    
    /// Initializes a new HTTP request.
    ///
    /// - Parameters:
    ///   - url: The target URL
    ///   - method: HTTP method (default: .get)
    ///   - headers: HTTP headers (default: empty)
    ///   - body: Request body data (default: nil)
    ///   - timeoutInterval: Request timeout (default: 60 seconds)
    ///   - cachePolicy: Cache policy (default: .useProtocolCachePolicy)
    public init(
        url: URL,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeoutInterval: TimeInterval = 60.0,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeoutInterval = timeoutInterval
        self.cachePolicy = cachePolicy
    }
}

// MARK: - URLRequest Conversion

extension HTTPRequest {
    
    /// Converts this HTTPRequest to a URLRequest.
    ///
    /// This is used internally to bridge between our protocol-oriented
    /// architecture and URLSession's API.
    ///
    /// - Returns: A configured URLRequest instance
    public func toURLRequest() -> URLRequest {
        var urlRequest = URLRequest(
            url: url,
            cachePolicy: cachePolicy,
            timeoutInterval: timeoutInterval
        )
        
        urlRequest.httpMethod = method.rawValue
        urlRequest.httpBody = body
        
        // Set headers
        for (key, value) in headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        return urlRequest
    }
}

// MARK: - Builder Pattern

extension HTTPRequest {
    
    /// Returns a new request with the specified method.
    public func method(_ method: HTTPMethod) -> HTTPRequest {
        HTTPRequest(
            url: url,
            method: method,
            headers: headers,
            body: body,
            timeoutInterval: timeoutInterval,
            cachePolicy: cachePolicy
        )
    }
    
    /// Returns a new request with the specified headers merged.
    public func headers(_ newHeaders: [String: String]) -> HTTPRequest {
        HTTPRequest(
            url: url,
            method: method,
            headers: headers.merging(newHeaders) { _, new in new },
            body: body,
            timeoutInterval: timeoutInterval,
            cachePolicy: cachePolicy
        )
    }
    
    /// Returns a new request with the specified body.
    public func body(_ body: Data?) -> HTTPRequest {
        HTTPRequest(
            url: url,
            method: method,
            headers: headers,
            body: body,
            timeoutInterval: timeoutInterval,
            cachePolicy: cachePolicy
        )
    }
    
    /// Returns a new request with the specified timeout.
    public func timeout(_ interval: TimeInterval) -> HTTPRequest {
        HTTPRequest(
            url: url,
            method: method,
            headers: headers,
            body: body,
            timeoutInterval: interval,
            cachePolicy: cachePolicy
        )
    }
    
    /// Returns a new request with the specified cache policy.
    public func cachePolicy(_ policy: URLRequest.CachePolicy) -> HTTPRequest {
        HTTPRequest(
            url: url,
            method: method,
            headers: headers,
            body: body,
            timeoutInterval: timeoutInterval,
            cachePolicy: policy
        )
    }
}
