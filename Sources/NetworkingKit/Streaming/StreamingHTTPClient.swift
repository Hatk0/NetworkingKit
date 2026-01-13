import Foundation

// MARK: - Streaming HTTP Client Protocol

/// Protocol for HTTP clients that support streaming responses.
///
/// This extends the standard HTTPClient with the ability to receive
/// response data as an async stream of chunks, enabling real-time
/// processing of large or streaming responses.
public protocol StreamingHTTPClient: Sendable {
    /// Executes a request and returns a stream of data chunks.
    ///
    /// Unlike regular `execute()`, this method returns data incrementally
    /// as it arrives from the server, which is essential for:
    /// - AI API streaming responses (token-by-token)
    /// - Large file downloads with progress
    /// - Server-Sent Events (SSE)
    ///
    /// - Parameter request: The HTTP request to execute
    /// - Returns: An async stream of data chunks
    func stream(_ request: HTTPRequest) -> AsyncThrowingStream<Data, Error>
}

// MARK: - URLSession Streaming Client

/// URLSession-based implementation of StreamingHTTPClient.
///
/// Uses URLSession's bytes API for efficient streaming without
/// loading the entire response into memory.
public final class URLSessionStreamingClient: StreamingHTTPClient, Sendable {
    private let session: URLSession
    private let configuration: NetworkConfiguration?
    
    /// Creates a streaming client with default configuration.
    public init() {
        self.session = .shared
        self.configuration = nil
    }
    
    /// Creates a streaming client with custom configuration.
    ///
    /// - Parameter configuration: Network configuration
    public init(configuration: NetworkConfiguration) {
        let config = configuration.sessionConfiguration
        self.session = URLSession(configuration: config)
        self.configuration = configuration
    }
    
    /// Creates a streaming client with a custom URLSession.
    ///
    /// - Parameter session: The URLSession to use
    public init(session: URLSession) {
        self.session = session
        self.configuration = nil
    }
    
    public func stream(_ request: HTTPRequest) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var urlRequest = request.toURLRequest()
                    
                    // Apply default headers from configuration
                    if let config = configuration {
                        for (key, value) in config.defaultHeaders {
                            if urlRequest.value(forHTTPHeaderField: key) == nil {
                                urlRequest.setValue(value, forHTTPHeaderField: key)
                            }
                        }
                    }
                    
                    // Log request if enabled
                    if let config = configuration, config.enableLogging {
                        logRequest(urlRequest, level: config.logLevel)
                    }
                    
                    // Use bytes API for streaming
                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    
                    // Validate response
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw NetworkError.invalidResponse
                    }
                    
                    // Check for error status codes
                    if !(200..<300).contains(httpResponse.statusCode) {
                        // For errors, collect all data first
                        var errorData = Data()
                        for try await byte in bytes {
                            errorData.append(byte)
                        }
                        throw NetworkError.httpError(
                            statusCode: httpResponse.statusCode,
                            data: errorData
                        )
                    }
                    
                    // Stream data in chunks
                    var buffer = Data()
                    let chunkSize = 1024 // 1KB chunks
                    
                    for try await byte in bytes {
                        buffer.append(byte)
                        
                        // Yield when we have a complete line (for SSE)
                        // or when buffer reaches chunk size
                        if byte == 10 || buffer.count >= chunkSize { // 10 = newline
                            continuation.yield(buffer)
                            buffer = Data()
                        }
                    }
                    
                    // Yield any remaining data
                    if !buffer.isEmpty {
                        continuation.yield(buffer)
                    }
                    
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: mapError(error))
                }
            }
        }
    }
    
    /// Maps errors to NetworkError.
    private func mapError(_ error: Error) -> Error {
        if let networkError = error as? NetworkError {
            return networkError
        }
        if let urlError = error as? URLError {
            return NetworkError.from(urlError: urlError)
        }
        return NetworkError.custom(error.localizedDescription)
    }
    
    /// Logs the request for debugging.
    private func logRequest(_ request: URLRequest, level: LogLevel) {
        guard level != .none else { return }
        
        print("🌊 [STREAM] \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")
        
        if level == .verbose {
            if let headers = request.allHTTPHeaderFields {
                for (key, value) in headers {
                    let displayValue = key.lowercased().contains("authorization") ? "[REDACTED]" : value
                    print("   \(key): \(displayValue)")
                }
            }
        }
    }
}

// MARK: - HTTPClient Extension

/// Extension to add streaming capability to any HTTPClient.
extension URLSessionHTTPClient: StreamingHTTPClient {
    public func stream(_ request: HTTPRequest) -> AsyncThrowingStream<Data, Error> {
        // Create a dedicated streaming client with the same configuration
        let streamingClient = URLSessionStreamingClient()
        return streamingClient.stream(request)
    }
}
