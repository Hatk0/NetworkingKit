import Foundation

/// Fluent builder for constructing HTTP requests from endpoints.
///
/// `RequestBuilder` provides a convenient API for converting
/// endpoints into fully-formed HTTPRequest instances.
///
/// Example:
/// ```swift
/// let endpoint = GetUserEndpoint(userId: 123)
/// let request = try RequestBuilder(baseURL: baseURL)
///     .build(from: endpoint)
/// ```
public final class RequestBuilder: Sendable {
    private let baseURL: URL?
    private let defaultHeaders: [String: String]
    
    /// Initializes a new request builder.
    ///
    /// - Parameters:
    ///   - baseURL: The base URL for all requests
    ///   - defaultHeaders: Default headers to include
    public init(baseURL: URL? = nil, defaultHeaders: [String: String] = [:]) {
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
    }
    
    /// Builds an HTTPRequest from an endpoint.
    ///
    /// - Parameter endpoint: The endpoint to build from
    /// - Returns: A configured HTTPRequest
    /// - Throws: `NetworkError` if the request cannot be built
    public func build(from endpoint: any Endpoint) throws -> HTTPRequest {
        // Construct URL
        let url = try constructURL(from: endpoint)
        
        // Merge headers
        let headers = defaultHeaders.merging(endpoint.headers) { _, new in new }
        
        // Create base request
        var request = HTTPRequest(
            url: url,
            method: endpoint.method,
            headers: headers
        )
        
        // Encode query parameters
        if let queryParams = endpoint.queryParameters {
            request = try URLEncoding.default.encode(request, with: queryParams)
        }
        
        // Encode body parameters
        if let bodyParams = endpoint.bodyParameters {
            request = try endpoint.encoding.encode(request, with: bodyParams)
        }
        
        return request
    }
    
    private func constructURL(from endpoint: any Endpoint) throws -> URL {
        let path = endpoint.path
        
        // If endpoint path is a full URL, use it directly
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            guard let url = URL(string: path) else {
                throw NetworkError.invalidURL(path)
            }
            return url
        }
        
        // Otherwise, combine with base URL
        guard var combinedURL = baseURL else {
            throw NetworkError.invalidURL("No base URL configured and endpoint path is relative: \(path)")
        }
        let pathComponents = path.split(separator: "/", omittingEmptySubsequences: true)
        
        for component in pathComponents {
            combinedURL = combinedURL.appendingPathComponent(String(component))
        }
        
        return combinedURL
    }
}

// MARK: - Convenience Methods

extension RequestBuilder {
    /// Creates a GET request.
    public func get(
        _ path: String,
        queryParameters: [String: Any]? = nil,
        headers: [String: String] = [:]
    ) throws -> HTTPRequest {
        let endpoint = GetEndpoint(path: path, queryParameters: queryParameters)
        var request = try build(from: endpoint)
        request = request.headers(headers)
        return request
    }
    
    /// Creates a POST request.
    public func post(
        _ path: String,
        bodyParameters: [String: Any]? = nil,
        headers: [String: String] = [:]
    ) throws -> HTTPRequest {
        let endpoint = PostEndpoint(path: path, bodyParameters: bodyParameters)
        var request = try build(from: endpoint)
        request = request.headers(headers)
        return request
    }
    
    /// Creates a PUT request.
    public func put(
        _ path: String,
        bodyParameters: [String: Any]? = nil,
        headers: [String: String] = [:]
    ) throws -> HTTPRequest {
        let endpoint = PutEndpoint(path: path, bodyParameters: bodyParameters)
        var request = try build(from: endpoint)
        request = request.headers(headers)
        return request
    }
    
    /// Creates a PATCH request.
    public func patch(
        _ path: String,
        bodyParameters: [String: Any]? = nil,
        headers: [String: String] = [:]
    ) throws -> HTTPRequest {
        let endpoint = PatchEndpoint(path: path, bodyParameters: bodyParameters)
        var request = try build(from: endpoint)
        request = request.headers(headers)
        return request
    }
    
    /// Creates a DELETE request.
    public func delete(
        _ path: String,
        queryParameters: [String: Any]? = nil,
        headers: [String: String] = [:]
    ) throws -> HTTPRequest {
        let endpoint = DeleteEndpoint(path: path, queryParameters: queryParameters)
        var request = try build(from: endpoint)
        request = request.headers(headers)
        return request
    }
}
