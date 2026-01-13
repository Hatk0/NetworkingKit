import Foundation

/// Represents an HTTP response with data and metadata.
///
/// `HTTPResponse` encapsulates the response data, HTTP metadata, and provides
/// convenient accessors for common properties like status code and headers.
///
/// Example:
/// ```swift
/// let response = HTTPResponse(data: data, urlResponse: httpResponse)
/// if response.isSuccess {
///     print("Status: \(response.statusCode)")
/// }
/// ```
public struct HTTPResponse: Sendable {
    /// The response body data.
    public let data: Data
    
    /// The underlying URLResponse.
    public let urlResponse: URLResponse
    
    /// The HTTP status code.
    public let statusCode: Int
    
    /// HTTP response headers.
    public let headers: [String: String]
    
    /// Initializes a new HTTP response.
    ///
    /// - Parameters:
    ///   - data: The response body data
    ///   - urlResponse: The URLResponse from the network request
    /// - Throws: `NetworkError.invalidResponse` if urlResponse is not HTTPURLResponse
    public init(data: Data, urlResponse: URLResponse) throws {
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        self.data = data
        self.urlResponse = urlResponse
        self.statusCode = httpResponse.statusCode
        
        // Convert headers to [String: String] for easier access
        var headers: [String: String] = [:]
        for (key, value) in httpResponse.allHeaderFields {
            if let key = key as? String, let value = value as? String {
                headers[key] = value
            }
        }
        self.headers = headers
    }
}

// MARK: - Convenience Properties

extension HTTPResponse {
    
    /// Returns true if the status code indicates success (200-299).
    public var isSuccess: Bool {
        (200..<300).contains(statusCode)
    }
    
    /// Returns true if the status code indicates a client error (400-499).
    public var isClientError: Bool {
        (400..<500).contains(statusCode)
    }
    
    /// Returns true if the status code indicates a server error (500-599).
    public var isServerError: Bool {
        (500..<600).contains(statusCode)
    }
    
    /// The Content-Type header value, if present.
    public var contentType: String? {
        headers["Content-Type"] ?? headers["content-type"]
    }
    
    /// The Content-Length header value, if present.
    public var contentLength: Int? {
        guard let lengthString = headers["Content-Length"] ?? headers["content-length"] else {
            return nil
        }
        return Int(lengthString)
    }
    
    /// Returns true if the response is JSON.
    public var isJSON: Bool {
        contentType?.lowercased().contains("application/json") ?? false
    }
}

// MARK: - Data Decoding

extension HTTPResponse {
    
    /// Decodes the response data as JSON into the specified type.
    ///
    /// - Parameters:
    ///   - type: The Decodable type to decode into
    ///   - decoder: The JSONDecoder to use (default: JSONDecoder())
    /// - Returns: The decoded value
    /// - Throws: DecodingError if decoding fails
    public func decode<T: Decodable>(
        _ type: T.Type,
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> T {
        try decoder.decode(type, from: data)
    }
    
    /// Returns the response data as a UTF-8 string.
    public var stringValue: String? {
        String(data: data, encoding: .utf8)
    }
}
