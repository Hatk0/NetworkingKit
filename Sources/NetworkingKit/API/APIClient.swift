import Foundation

/// High-level API client for making type-safe HTTP requests.
///
/// `APIClient` provides a convenient interface for common networking
/// patterns with automatic request building, response decoding,
/// and error handling.
///
/// Example:
/// ```swift
/// struct User: Decodable {
///     let id: Int
///     let name: String
/// }
///
/// let client = APIClient(
///     baseURL: URL(string: "https://api.example.com")!,
///     httpClient: URLSessionHTTPClient()
/// )
///
/// let user: User = try await client.request(GetUserEndpoint(userId: 123))
/// ```
public final class APIClient: Sendable {
    
    private let httpClient: HTTPClient
    private let requestBuilder: RequestBuilder
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    /// Initializes a new API client.
    ///
    /// - Parameters:
    ///   - baseURL: Base URL for all requests
    ///   - httpClient: The HTTP client to use for requests
    ///   - defaultHeaders: Default headers to include in all requests
    ///   - decoder: JSON decoder (default: JSONDecoder())
    ///   - encoder: JSON encoder (default: JSONEncoder())
    public init(
        baseURL: URL?,
        httpClient: HTTPClient,
        defaultHeaders: [String: String] = [:],
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.httpClient = httpClient
        self.requestBuilder = RequestBuilder(baseURL: baseURL, defaultHeaders: defaultHeaders)
        self.decoder = decoder
        self.encoder = encoder
    }
    
    /// Executes a request and decodes the response.
    ///
    /// - Parameters:
    ///   - endpoint: The endpoint to request
    ///   - modifiers: Optional request modifiers
    /// - Returns: The decoded response
    /// - Throws: `NetworkError` if the request fails or decoding fails
    public func request<T: Decodable>(
        _ endpoint: any Endpoint,
        modifiers: [any RequestModifier] = []
    ) async throws -> T {
        var request = try requestBuilder.build(from: endpoint)
        
        // Apply modifiers
        for modifier in modifiers {
            request = try await modifier.modify(request)
        }
        
        let response = try await httpClient.execute(request)
        
        do {
            return try response.decode(T.self, using: decoder)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
    
    /// Executes a request without expecting a decoded response.
    ///
    /// Useful for requests that don't return data (e.g., DELETE).
    ///
    /// - Parameters:
    ///   - endpoint: The endpoint to request
    ///   - modifiers: Optional request modifiers
    /// - Throws: `NetworkError` if the request fails
    public func request(
        _ endpoint: any Endpoint,
        modifiers: [any RequestModifier] = []
    ) async throws {
        var request = try requestBuilder.build(from: endpoint)
        
        // Apply modifiers
        for modifier in modifiers {
            request = try await modifier.modify(request)
        }
        
        let _ = try await httpClient.execute(request)
    }
    
    /// Executes a request and returns the raw response.
    ///
    /// - Parameters:
    ///   - endpoint: The endpoint to request
    ///   - modifiers: Optional request modifiers
    /// - Returns: The raw HTTP response
    /// - Throws: `NetworkError` if the request fails
    public func requestRaw(
        _ endpoint: any Endpoint,
        modifiers: [any RequestModifier] = []
    ) async throws -> HTTPResponse {
        var request = try requestBuilder.build(from: endpoint)
        
        // Apply modifiers
        for modifier in modifiers {
            request = try await modifier.modify(request)
        }
        
        return try await httpClient.execute(request)
    }
}

// MARK: - Convenience Methods

extension APIClient {
    
    /// Performs a GET request with automatic decoding.
    public func get<T: Decodable>(
        _ path: String,
        queryParameters: [String: Any]? = nil,
        headers: [String: String] = [:],
        modifiers: [any RequestModifier] = []
    ) async throws -> T {
        let endpoint = GetEndpoint(path: path, queryParameters: queryParameters)
        return try await request(endpoint, modifiers: modifiers)
    }
    
    /// Performs a POST request with Codable body.
    public func post<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        headers: [String: String] = [:],
        modifiers: [any RequestModifier] = []
    ) async throws -> Response {
        let bodyData = try encoder.encode(body)
        let bodyParams = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        let endpoint = PostEndpoint(path: path, bodyParameters: bodyParams)
        return try await request(endpoint, modifiers: modifiers)
    }
    
    /// Performs a POST request without expecting a response.
    public func post<Body: Encodable>(
        _ path: String,
        body: Body,
        headers: [String: String] = [:],
        modifiers: [any RequestModifier] = []
    ) async throws {
        let bodyData = try encoder.encode(body)
        let bodyParams = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        let endpoint = PostEndpoint(path: path, bodyParameters: bodyParams)
        try await request(endpoint, modifiers: modifiers)
    }
    
    /// Performs a PUT request with Codable body.
    public func put<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        headers: [String: String] = [:],
        modifiers: [any RequestModifier] = []
    ) async throws -> Response {
        let bodyData = try encoder.encode(body)
        let bodyParams = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        let endpoint = PutEndpoint(path: path, bodyParameters: bodyParams)
        return try await request(endpoint, modifiers: modifiers)
    }
    
    /// Performs a PATCH request with Codable body.
    public func patch<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        headers: [String: String] = [:],
        modifiers: [any RequestModifier] = []
    ) async throws -> Response {
        let bodyData = try encoder.encode(body)
        let bodyParams = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        let endpoint = PatchEndpoint(path: path, bodyParameters: bodyParams)
        return try await request(endpoint, modifiers: modifiers)
    }
    
    /// Performs a DELETE request.
    public func delete(
        _ path: String,
        queryParameters: [String: Any]? = nil,
        headers: [String: String] = [:],
        modifiers: [any RequestModifier] = []
    ) async throws {
        let endpoint = DeleteEndpoint(path: path, queryParameters: queryParameters)
        try await request(endpoint, modifiers: modifiers)
    }
}

// MARK: - Upload/Download

extension APIClient {
    
    /// Uploads a file using multipart form data.
    public func upload<Response: Decodable>(
        _ path: String,
        fileData: Data,
        fileName: String,
        fieldName: String = "file",
        mimeType: String = "application/octet-stream",
        parameters: [String: Any]? = nil,
        modifiers: [any RequestModifier] = []
    ) async throws -> Response {
        let part = MultipartFormDataEncoding.Part(
            data: fileData,
            name: fieldName,
            fileName: fileName,
            mimeType: mimeType
        )
        
        let encoding = MultipartFormDataEncoding(parts: [part])
        
        var request = try requestBuilder.build(from: PostEndpoint(path: path))
        request = try encoding.encode(request, with: parameters)
        
        // Apply modifiers
        for modifier in modifiers {
            request = try await modifier.modify(request)
        }
        
        let response = try await httpClient.execute(request)
        
        do {
            return try response.decode(Response.self, using: decoder)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
}
