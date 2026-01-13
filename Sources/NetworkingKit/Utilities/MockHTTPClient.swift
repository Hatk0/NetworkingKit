import Foundation

/// Mock HTTP client for testing.
///
/// `MockHTTPClient` allows you to stub responses for testing
/// without making actual network requests.
///
/// Example:
/// ```swift
/// let mock = MockHTTPClient()
/// mock.stub(url: "https://api.example.com/users", response: usersData, statusCode: 200)
///
/// let client = APIClient(baseURL: baseURL, httpClient: mock)
/// let users: [User] = try await client.get("/users")
/// ```
public actor MockHTTPClient: HTTPClient {
    private var stubs: [String: Stub] = [:]
    private var requests: [HTTPRequest] = []
    
    /// Represents a stubbed response.
    public struct Stub: Sendable {
        public let data: Data
        public let statusCode: Int
        public let headers: [String: String]
        public let delay: TimeInterval?
        public let error: Error?
        
        public init(
            data: Data = Data(),
            statusCode: Int = 200,
            headers: [String: String] = [:],
            delay: TimeInterval? = nil,
            error: Error? = nil
        ) {
            self.data = data
            self.statusCode = statusCode
            self.headers = headers
            self.delay = delay
            self.error = error
        }
    }
    
    public init() {}
    
    /// Stubs a response for a specific URL.
    ///
    /// - Parameters:
    ///   - url: The URL to stub
    ///   - stub: The stub configuration
    public func stub(url: String, stub: Stub) {
        stubs[url] = stub
    }
    
    /// Stubs a response with convenience parameters.
    public func stub(
        url: String,
        data: Data = Data(),
        statusCode: Int = 200,
        headers: [String: String] = [:],
        delay: TimeInterval? = nil
    ) {
        stubs[url] = Stub(
            data: data,
            statusCode: statusCode,
            headers: headers,
            delay: delay
        )
    }
    
    /// Stubs a response with Codable object.
    public func stub<T: Encodable>(
        url: String,
        object: T,
        statusCode: Int = 200,
        encoder: JSONEncoder = JSONEncoder()
    ) throws {
        let data = try encoder.encode(object)
        stub(
            url: url,
            data: data,
            statusCode: statusCode,
            headers: ["Content-Type": "application/json"]
        )
    }
    
    /// Stubs an error for a specific URL.
    public func stubError(url: String, error: Error) {
        stubs[url] = Stub(error: error)
    }
    
    /// Returns all captured requests.
    public func capturedRequests() -> [HTTPRequest] {
        requests
    }
    
    /// Clears all stubs and captured requests.
    public func reset() {
        stubs.removeAll()
        requests.removeAll()
    }
    
    public func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        // Capture request
        requests.append(request)
        
        // Find stub
        guard let stub = stubs[request.url.absoluteString] else {
            throw NetworkError.custom("No stub found for URL: \(request.url.absoluteString)")
        }
        
        // Simulate delay if specified
        if let delay = stub.delay {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        // Return error if specified
        if let error = stub.error {
            throw error
        }
        
        // Create mock URLResponse
        guard let httpResponse = HTTPURLResponse(
            url: request.url,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: stub.headers
        ) else {
            throw NetworkError.invalidResponse
        }
        
        // Create and return HTTPResponse
        return try HTTPResponse(data: stub.data, urlResponse: httpResponse)
    }
}

// MARK: - Testing Helpers

extension MockHTTPClient {
    /// Verifies that a request was made to the specified URL.
    public func didRequest(url: String) -> Bool {
        requests.contains { $0.url.absoluteString == url }
    }
    
    /// Verifies that a request was made with the specified method.
    public func didRequest(url: String, method: HTTPMethod) -> Bool {
        requests.contains { $0.url.absoluteString == url && $0.method == method }
    }
    
    /// Returns the number of requests made to the specified URL.
    public func requestCount(for url: String) -> Int {
        requests.filter { $0.url.absoluteString == url }.count
    }
}
